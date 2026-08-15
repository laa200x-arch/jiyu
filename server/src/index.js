/**
 * 技遇后端入口（方案 4.1：Node.js + Express + Socket.io + MySQL/SQLite）
 */
import express from 'express'
import cors from 'cors'
import http from 'node:http'
import { config } from './config.js'
import { initDb, closeDb } from './db.js'
import { SQLITE_DDL, MYSQL_DDL } from './schema.js'
import { seed } from './seed.js'
import { authRouter } from './routes/auth.js'
import { profileRouter } from './routes/profile.js'
import { matchRouter } from './routes/match.js'
import { socialRouter } from './routes/social.js'
import { chatRouter } from './routes/chat.js'
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
  // 演示数据
  if (config.autoSeed) await seed(db)

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
