/**
 * 技遇后端入口（方案 4.1：Node.js + Express + Socket.io + MySQL/SQLite）
 */
import express from 'express'
import cors from 'cors'
import http from 'node:http'
import path from 'node:path'
import { mkdirSync } from 'node:fs'
import multer from 'multer'
import { config } from './config.js'
import { initDb, closeDb } from './db.js'
import { SQLITE_DDL, MYSQL_DDL } from './schema.js'
import { seed, ensureEveryoneHasDynamics } from './seed.js'
import { requireAuth, serializeUser } from './middleware.js'
import { authRouter } from './routes/auth.js'
import { profileRouter } from './routes/profile.js'
import { matchRouter } from './routes/match.js'
import { socialRouter } from './routes/social.js'
import { chatRouter } from './routes/chat.js'
import { petsRouter } from './routes/pets.js'
import { setupSocket } from './socket.js'

async function main() {
  console.log(`[jiyu-server] 启动中... 数据库驱动: ${config.dbDriver}`)

  const db = await initDb()
  // 建表
  db.exec(config.dbDriver === 'mysql' ? MYSQL_DDL : SQLITE_DDL)
  // 轻量迁移：为已存在的 dynamics 表补充 image_base64 列（重复执行无副作用）
  try {
    db.exec('ALTER TABLE dynamics ADD COLUMN image_base64 TEXT')
  } catch { /* 列已存在 */ }
  // 轻量迁移：messages 表补充媒体字段
  try { db.exec('ALTER TABLE messages ADD COLUMN media_type TEXT') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE messages ADD COLUMN media_url TEXT') } catch { /* 列已存在 */ }
  // 轻量迁移：宠物订单收费字段 + 动态订单卡片
  try { db.exec('ALTER TABLE bookings ADD COLUMN price_yuan REAL') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE bookings ADD COLUMN commission_rate REAL') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE bookings ADD COLUMN commission_yuan REAL') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE bookings ADD COLUMN worker_income REAL') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE bookings ADD COLUMN open_to_feed INTEGER NOT NULL DEFAULT 0') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE dynamics ADD COLUMN order_id TEXT') } catch { /* 列已存在 */ }
  try { db.exec('ALTER TABLE messages ADD COLUMN order_id TEXT') } catch { /* 列已存在 */ }
  // 迁移：旧 bookings 表 provider_id 为 NOT NULL，需重建为可空（订单可发布待接单）
  if (config.dbDriver === 'sqlite') {
    try {
      const cols = db.all('PRAGMA table_info(bookings)')
      const pid = cols.find((c) => c.name === 'provider_id')
      if (pid && pid.notnull === 1) {
        db.exec(`
          CREATE TABLE bookings_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            provider_id INTEGER,
            pet_id INTEGER NOT NULL,
            service_id TEXT NOT NULL,
            service_name TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            location TEXT,
            status TEXT NOT NULL DEFAULT 'open',
            price_yuan REAL,
            commission_rate REAL,
            commission_yuan REAL,
            worker_income REAL,
            open_to_feed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          );
          INSERT INTO bookings_new (id, user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, created_at)
            SELECT id, user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, created_at FROM bookings;
          DROP TABLE bookings;
          ALTER TABLE bookings_new RENAME TO bookings;
        `)
        console.log('[migrate] bookings 表已重建（provider_id 可空，支持发布待接单）')
      }
    } catch (e) { /* 新表无需迁移 */ }
  }
  // 轻量迁移：users 表补充头像 URL 列
  try { db.exec('ALTER TABLE users ADD COLUMN avatar_url TEXT') } catch { /* 列已存在 */ }
  // 轻量迁移：users 表补充手机号列（注册手机验证，一手机号一号）
  try { db.exec('ALTER TABLE users ADD COLUMN phone TEXT') } catch { /* 列已存在 */ }
  try { db.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone)') } catch { /* 索引已存在 */ }
  // 演示数据
  if (config.autoSeed) {
    await seed(db)
    ensureEveryoneHasDynamics(db)
  }

  const app = express()
  app.use(cors())
  app.use(express.json({ limit: '5mb' }))

  // 健康检查
  app.get('/api/health', (req, res) => {
    res.json({ ok: true, service: 'jiyu-server', time: new Date().toISOString() })
  })

  // 版本检查（App 启动时轮询：有新版本则提示下载）
  app.get('/api/version', (req, res) => {
    res.json({
      current: '1.1',
      updateMessage: '新版本已发布：新增同城地图、动态图片上传、账号切换、消息推送、自动登录修复',
      downloadUrl: 'https://github.com/laa200x-arch/jiyu/releases'
    })
  })

  // 文件上传（聊天图片/视频，方案 2.3.3 资料传输）
  const uploadDir = path.join(process.cwd(), 'uploads')
  mkdirSync(uploadDir, { recursive: true })
  const upload = multer({
    storage: multer.diskStorage({
      destination: uploadDir,
      filename: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase().slice(0, 10)
        cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`)
      }
    }),
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB 上限（视频）
  })
  app.post('/api/upload', requireAuth, upload.single('file'), (req, res) => {
    if (!req.file) return res.status(400).json({ error: '缺少文件' })
    res.status(201).json({ url: `/uploads/${req.file.filename}` })
  })
  app.use('/uploads', express.static(uploadDir, { maxAge: '7d' }))

  // 我的资料（客户端自动登录/一键切换账号使用；挂载在 /api 而非 /api/auth）
  app.get('/api/me', requireAuth, (req, res) => {
    const row = db.get('SELECT * FROM users WHERE id = ?', [req.userId])
    if (!row) return res.status(404).json({ error: '用户不存在' })
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [req.userId])
    res.json({ user: serializeUser(row, { skills }) })
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

  // 404
  app.use((req, res) => {
    res.status(404).json({ error: `接口不存在: ${req.method} ${req.path}` })
  })

  // 全局错误处理（body-parser 解析错误返回 400 而非 500）
  app.use((err, req, res, next) => {
    console.error('[error]', err)
    const status = err.statusCode || err.status || 500
    const message = err.type === 'entity.parse.failed' ? '请求格式错误' : '服务器内部错误'
    res.status(status).json({ error: message })
  })

  httpServer.listen(config.port, () => {
    console.log(`[jiyu-server] 已启动: http://localhost:${config.port}`)
    console.log(`[jiyu-server] 健康检查: http://localhost:${config.port}/api/health`)
  })

  const shutdown = () => {
    console.log('\n[jiyu-server] 正在关闭...')
    try { io.close() } catch {}
    httpServer.close(() => {
      closeDb()
      process.exit(0)
    })
  }
  process.on('SIGINT', shutdown)
  process.on('SIGTERM', shutdown)
}

main().catch((err) => {
  console.error('[jiyu-server] 启动失败:', err)
  process.exit(1)
})
