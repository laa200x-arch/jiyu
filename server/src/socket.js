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
    cors: { origin: '*', methods: ['GET', 'POST'] }
  })

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

    // 实时发送消息（走与 REST 相同风控与落库）
    socket.on('chat:send', ({ conversationId, text }, ack) => {
      const result = chatApi.saveMessage(userId, conversationId, text)
      if (ack) ack({ ok: !result.error && !result.blocked, ...result })
    })

    socket.on('disconnect', () => {
      console.log(`[socket] 用户 ${userId} 断开`)
    })
  })

  return io
}
