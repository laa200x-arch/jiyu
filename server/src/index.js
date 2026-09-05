/**
 * 技遇后端入口（方案 4.1：Node.js + Express + Socket.io + MySQL/SQLite）
 */
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import http from 'node:http'
import path from 'node:path'
import { mkdirSync, unlinkSync } from 'node:fs'
import multer from 'multer'
import pinoHttp from 'pino-http'
import { config } from './config.js'
import { logger } from './logger.js'
import { initDb, closeDb } from './db.js'
import { SQLITE_DDL, MYSQL_DDL } from './schema.js'
import { runMigrations } from './migrations.js'
import { seed, ensureEveryoneHasDynamics, ensureSampleApps } from './seed.js'
import { requireAuth, serializeUser } from './middleware.js'
import { globalLimiter, uploadLimiter } from './rate-limit.js'
import { authRouter } from './routes/auth.js'
import { profileRouter } from './routes/profile.js'
import { matchRouter } from './routes/match.js'
import { socialRouter } from './routes/social.js'
import { chatRouter } from './routes/chat.js'
import { petsRouter } from './routes/pets.js'
import { appsRouter } from './routes/apps.js'
import { setupSocket } from './socket.js'
import { smsStatus } from './sms.js'

async function main() {
  logger.info(`[jiyu-server] 启动中... 数据库驱动: ${config.dbDriver}`)

  const db = await initDb()
  // 建表
  db.exec(config.dbDriver === 'mysql' ? MYSQL_DDL : SQLITE_DDL)
  // 版本化迁移（幂等；见 src/migrations.js）
  runMigrations(db, config.dbDriver)
  // 演示数据（动态区不再生成模拟动态）
  if (config.autoSeed) {
    await seed(db)
    ensureEveryoneHasDynamics(db)
  }
  // 示例小程序（贪吃蛇，幂等补齐）
  ensureSampleApps(db)

  const app = express()
  app.disable('x-powered-by')
  // 安全响应头（helmet，Express 官方安全清单标配）：
  // - CSP 关闭：本服务不向浏览器提供业务页面（仅小程序示例页 snake-app.html 需运行脚本），避免误伤
  // - CORP=cross-origin：Electron(file://) 客户端需跨源加载 /uploads 图片与头像
  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    strictTransportSecurity: false // 当前为纯 HTTP 部署，HSTS 无意义（启用 HTTPS 后应开启）
  }))
  // 全局限流（防刷/防 DoS 兜底；分接口收紧在各路由模块）
  app.use(globalLimiter)
  // HTTP 请求访问日志（健康检查不记，避免刷屏）
  app.use(pinoHttp({ logger, autoLogging: { ignore: (req) => req.url === '/api/health' } }))
  // CORS：白名单配置化（CORS_ORIGINS）。原生客户端（无 Origin / file:// / null）始终放行；
  // 浏览器来源仅放行白名单，防第三方站点调用接口
  app.use(cors({
    origin(origin, cb) {
      if (!origin) return cb(null, true) // 原生客户端/服务端请求
      if (origin === 'null' || origin.startsWith('file://')) return cb(null, true) // Electron 本地页面
      if (config.corsOrigins.length === 0 || config.corsOrigins.includes(origin)) return cb(null, true)
      return cb(null, false)
    }
  }))
  app.use(express.json({ limit: '5mb' }))

  // 健康检查
  app.get('/api/health', (req, res) => {
    res.json({ ok: true, service: 'jiyu-server', time: new Date().toISOString(), sms: smsStatus() })
  })

  // 版本检查（App 启动时轮询：仅当服务器 current 与客户端已提示版本不同时客户端才弹更新窗）
  app.get('/api/version', (req, res) => {
    res.json({ current: config.appVersion, updateMessage: config.updateMessage, downloadUrl: config.downloadUrl })
  })

  // 文件上传（聊天图片/视频，方案 2.3.3 资料传输）
  // 安全：MIME 白名单 + 扩展名白名单（拒绝 .html/.svg 等可执行内容，防存储型 XSS）
  const uploadDir = path.join(process.cwd(), 'uploads')
  mkdirSync(uploadDir, { recursive: true })
  const ALLOWED_MIME = new Set([
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'video/mp4', 'video/quicktime', 'video/webm'
  ])
  const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.mov', '.webm'])
  const upload = multer({
    storage: multer.diskStorage({
      destination: uploadDir,
      filename: (req, file, cb) => {
        const ext = (path.extname(file.originalname || '').toLowerCase().slice(0, 10)) || '.jpg'
        cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ALLOWED_EXT.has(ext) ? ext : '.bin'}`)
      }
    }),
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB 上限（视频）
    fileFilter: (req, file, cb) => {
      // 注意：必须显式 cb(null, true) 接受；仅 cb(null) 会被 multer 视为拒绝
      const ok = ALLOWED_MIME.has(String(file.mimetype || '').toLowerCase())
      if (!ok) return cb(new Error('仅支持图片(jpg/png/gif/webp)与视频(mp4/mov/webm)'))
      cb(null, true)
    }
  })
  app.post('/api/upload', requireAuth, uploadLimiter, upload.single('file'), (req, res) => {
    if (!req.file) return res.status(400).json({ error: '缺少文件' })
    // 头像等图片限制 2MB（视频仍 50MB）；超限删除已写入的文件
    const isImage = String(req.file.mimetype || '').startsWith('image/')
    if (isImage && req.file.size > 2 * 1024 * 1024) {
      try { unlinkSync(path.join(uploadDir, req.file.filename)) } catch {}
      return res.status(400).json({ error: '图片不能超过 2MB，请压缩后重试' })
    }
    res.status(201).json({ url: `/uploads/${req.file.filename}` })
  }, (err, req, res, next) => {
    res.status(400).json({ error: err.message || '上传失败' })
  })
  // 静态媒体目录：nosniff + attachment 下载头，杜绝 HTML/SVG 直接渲染执行
  app.use('/uploads', express.static(uploadDir, {
    maxAge: '7d',
    setHeaders: (res) => {
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.setHeader('Content-Disposition', 'attachment')
      res.setHeader('Cache-Control', 'public, max-age=604800')
    }
  }))

  // 我的资料（客户端自动登录/一键切换账号使用；挂载在 /api 而非 /api/auth）
  app.get('/api/me', requireAuth, (req, res) => {
    const row = db.get('SELECT * FROM users WHERE id = ?', [req.userId])
    if (!row) return res.status(404).json({ error: '用户不存在' })
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [req.userId])
    res.json({ user: serializeUser(row, { skills, includePhone: true }) })
  })

  // 路由
  app.use('/api/auth', authRouter(db))
  app.use('/api', profileRouter(db))
  app.use('/api', matchRouter(db))

  const httpServer = http.createServer(app)

  // 实时总线：聊天路由与 Socket 层共享 io 实例
  const chatBus = { io: null }
  const chat = chatRouter(db, chatBus)
  app.use('/api', chat.router)

  const io = setupSocket(httpServer, db, chat)
  chatBus.io = io

  // 社交路由（需要 io 推送）
  app.use('/api', socialRouter(db, io))
  // 宠物护理域（旧巡六迁移；io 用于申请/确认接单的私聊系统提示）
  app.use('/api', petsRouter(db, io))
  // 小程序市场
  app.use('/api', appsRouter(db))

  // 404
  app.use((req, res) => {
    res.status(404).json({ error: `接口不存在: ${req.method} ${req.path}` })
  })

  // 全局错误处理（body-parser 解析错误返回 400 而非 500）
  app.use((err, req, res, next) => {
    logger.error({ err, req: { method: req.method, url: req.url } }, 'unhandled error')
    const status = err.statusCode || err.status || 500
    const message = err.type === 'entity.parse.failed' ? '请求格式错误' : '服务器内部错误'
    res.status(status).json({ error: message })
  })

  httpServer.listen(config.port, () => {
    logger.info(`[jiyu-server] 已启动: http://localhost:${config.port} · 健康检查 /api/health`)
    const sms = smsStatus()
    logger.info(
      `[jiyu-server] 短信通道: ${sms.provider}${sms.configured ? '' : '（未配置完整，发送会失败/降级）'}` +
        `${sms.devFallback ? '，SMS_DEV_FALLBACK=1（失败降级 devCode，生产请置 0）' : '，SMS_DEV_FALLBACK=0（失败即报错）'}`
    )
  })

  const shutdown = () => {
    logger.info('[jiyu-server] 正在关闭...')
    try { io.close() } catch {}
    httpServer.close(async () => {
      await closeDb()
      process.exit(0)
    })
  }
  process.on('SIGINT', shutdown)
  process.on('SIGTERM', shutdown)
}

main().catch((err) => {
  logger.error({ err }, '[jiyu-server] 启动失败')
  process.exit(1)
})
