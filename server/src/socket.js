/**
 * Socket.io 实时层（方案 4.1：即时通讯 Socket.io）
 * - 鉴权：客户端连接后发送 auth 事件 {token}
 * - 每个用户加入房间 user:<id>
 * - chat:send  → 服务端风控 → 落库 → 广播 chat:message（双方）
 * - match:push → 协议签署/匹配事件实时推送
 */
import jwt from 'jsonwebtoken'
import { Server } from 'socket.io'
import { config } from './config.js'

export function setupSocket(httpServer, db, chatApi) {
  const io = new Server(httpServer, {
    // 与 REST 相同的白名单逻辑：原生客户端（无 Origin / file:// / null）放行，浏览器来源仅放行 CORS_ORIGINS
    cors: {
      origin(origin, cb) {
        if (!origin) return cb(null, true)
        if (origin === 'null' || origin.startsWith('file://')) return cb(null, true)
        if (config.corsOrigins.length === 0 || config.corsOrigins.includes(origin)) return cb(null, true)
        return cb(null, false)
      },
      methods: ['GET', 'POST']
    }
  })

  // 聊天事件限流：每用户滑动窗口 20 条 / 10 秒（超限 ack 报错，不断开连接）
  const CHAT_WINDOW_MS = 10_000
  const CHAT_MAX_PER_WINDOW = 20
  const recentSends = new Map() // userId → 时间戳数组
  function chatAllowed(userId) {
    const nowT = Date.now()
    const arr = (recentSends.get(userId) || []).filter((t) => nowT - t < CHAT_WINDOW_MS)
    if (arr.length >= CHAT_MAX_PER_WINDOW) {
      recentSends.set(userId, arr)
      return false
    }
    arr.push(nowT)
    recentSends.set(userId, arr)
    return true
  }

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token
    if (!token) return next(new Error('未提供 token'))
    try {
      const payload = jwt.verify(token, config.jwtSecret)
      socket.userId = Number(payload.sub)
      next()
    } catch {
      next(new Error('token 无效或已过期'))
    }
  })

  io.on('connection', (socket) => {
    const userId = socket.userId
    socket.join(`user:${userId}`)
    console.log(`[socket] 用户 ${userId} 已连接 (${socket.id})`)

    // 实时发送消息（走与 REST 相同风控与落库；支持 orderId 订单引用）
    socket.on('chat:send', (payload, ack) => {
      if (!chatAllowed(userId)) {
        console.warn(`[socket] user=${userId} chat:send 触发限流（>20 条/10s）`)
        if (ack) ack({ ok: false, error: '消息发送过于频繁，请稍后再试' })
        return
      }
      const conversationId = payload?.conversationId
      const text = payload?.text || ''
      const mediaType = payload?.mediaType || null
      const mediaUrl = payload?.mediaUrl || null
      const orderId = payload?.orderId || null
      console.log(`[socket] user=${userId} chat:send conv=${conversationId} text="${String(text).slice(0, 20)}" media=${mediaType || 'none'} order=${orderId || 'none'}`)
      const result = chatApi.saveMessage(userId, conversationId, { text, mediaType, mediaUrl, orderId })
      console.log(`[socket] user=${userId} chat:send 结果: ${result.error || (result.blocked ? 'blocked' : 'ok')}`)
      if (ack) ack({ ok: !result.error && !result.blocked, ...result })
    })

    socket.on('disconnect', () => {
      recentSends.delete(userId)
      console.log(`[socket] 用户 ${userId} 断开`)
    })
  })

  return io
}
