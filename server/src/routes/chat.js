/**
 * 聊天路由（方案 2.3.3 线上交换：内置 IM）
 * REST 兜底接口；实时消息走 Socket.io（见 socket.js）
 */
import { Router } from 'express'
import { requireAuth, serializeUser, serializeMessage } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

export function chatRouter(db, bus = { io: null }) {
  const router = Router()
  router.use(requireAuth)
  const now = () => new Date().toISOString()

  const partnerOf = (convo, userId) => {
    const partnerId = convo.user_a === userId ? convo.user_b : convo.user_a
    const row = db.get('SELECT * FROM users WHERE id = ?', [partnerId])
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [partnerId])
    return serializeUser(row, { skills })
  }

  // 会话列表
  router.get('/conversations', (req, res) => {
    const rows = db.all(
      `SELECT * FROM conversations WHERE user_a = ? OR user_b = ? ORDER BY last_time DESC`,
      [req.userId, req.userId]
    )
    res.json({
      conversations: rows.map((row) => {
        const isA = row.user_a === req.userId
        return {
          id: String(row.id),
          partner: partnerOf(row, req.userId),
          lastMessageText: row.last_message_text,
          lastTime: row.last_time,
          unreadCount: isA ? row.unread_a : row.unread_b
        }
      })
    })
  })

  // 打开/创建与某用户的会话
  router.post('/conversations/open', (req, res) => {
    const { partnerId } = req.body || {}
    console.log(`[chat] user=${req.userId} openConversation partner=${partnerId}`)
    if (!partnerId) return res.status(400).json({ error: 'partnerId 必填' })
    const partner = db.get('SELECT * FROM users WHERE id = ?', [partnerId])
    if (!partner) return res.status(404).json({ error: '用户不存在' })
    const a = Math.min(req.userId, Number(partnerId))
    const b = Math.max(req.userId, Number(partnerId))
    let row = db.get('SELECT * FROM conversations WHERE user_a = ? AND user_b = ?', [a, b])
    if (!row) {
      const r = db.run(
        'INSERT INTO conversations (user_a, user_b, last_message_text, last_time, unread_a, unread_b) VALUES (?,?,?,?,?,?)',
        [a, b, '你们已建立会话，打个招呼吧～', now(), 0, 0]
      )
      db.run(
        `INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`,
        [r.lastInsertRowid, b, '你们已建立会话。提醒：请先签署官方互换协议，再开始教学；平台严禁任何金钱交易。', 1, now()]
      )
      row = db.get('SELECT * FROM conversations WHERE id = ?', [r.lastInsertRowid])
    }
    res.json({
      conversation: {
        id: String(row.id),
        partner: partnerOf(row, req.userId),
        lastMessageText: row.last_message_text,
        lastTime: row.last_time,
        unreadCount: 0
      }
    })
  })

  // 历史消息
  router.get('/conversations/:id/messages', (req, res) => {
    const convo = db.get('SELECT * FROM conversations WHERE id = ?', [req.params.id])
    if (!convo || (convo.user_a !== req.userId && convo.user_b !== req.userId)) {
      return res.status(404).json({ error: '会话不存在' })
    }
    const rows = db.all('SELECT * FROM messages WHERE conversation_id = ? ORDER BY id ASC', [convo.id])
    res.json({
      messages: rows.map((row) => serializeMessage({
        ...row,
        sender_is_me: row.sender_id === req.userId
      }))
    })
  })

  // 已读
  router.post('/conversations/:id/read', (req, res) => {
    const convo = db.get('SELECT * FROM conversations WHERE id = ?', [req.params.id])
    if (!convo) return res.status(404).json({ error: '会话不存在' })
    if (convo.user_a === req.userId) db.run('UPDATE conversations SET unread_a = 0 WHERE id = ?', [convo.id])
    if (convo.user_b === req.userId) db.run('UPDATE conversations SET unread_b = 0 WHERE id = ?', [convo.id])
    res.json({ ok: true })
  })

  // 发送消息（REST 兜底，与 Socket.io 同一套风控与落库逻辑）
  router.post('/messages', (req, res) => {
    const { conversationId, text, mediaType, mediaUrl } = req.body || {}
    const result = saveMessage(req.userId, conversationId, { text, mediaType, mediaUrl })
    if (result.error) return res.status(result.status || 400).json({ error: result.error, blocked: result.blocked })
    res.status(201).json({
      message: result.message,
      blocked: result.blocked || false,
      warning: result.warning || undefined
    })
  })

  /**
   * 消息落库核心（风控拦截 + 会话预览更新 + 实时广播）
   * 支持文本与媒体消息（mediaType: image/video，mediaUrl: 上传后的相对路径）
   * 供 REST 与 Socket.io 共用
   */
  function saveMessage(senderId, conversationId, { text = '', mediaType = null, mediaUrl = null } = {}) {
    const content = String(text || '').trim()
    if (!content && !mediaUrl) return { error: '消息不能为空', status: 400 }
    const convo = db.get('SELECT * FROM conversations WHERE id = ?', [conversationId])
    if (!convo) return { error: '会话不存在', status: 404 }
    if (convo.user_a !== senderId && convo.user_b !== senderId) {
      return { error: '无权访问该会话', status: 403 }
    }
    const preview = content || (mediaType === 'video' ? '[视频]' : mediaType === 'audio' ? '[语音]' : '[图片]')
    const risk = checkTextRisk(content)
    if (risk.isIllegal) {
      // 原文不发送，追加系统提示（方案 2.3.6）
      const note = `⚠️ 该消息含违禁词：${risk.matchedWords.join('、')}，已被平台风控拦截。技遇仅支持纯技能无偿互换。`
      const r = db.run(
        `INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`,
        [convo.id, senderId, note, 1, now()]
      )
      updatePreviewAndBroadcast(convo, senderId, note, r.lastInsertRowid, null, null)
      return {
        blocked: true,
        warning: risk.warning,
        message: serializeMessage({
          id: r.lastInsertRowid, conversation_id: convo.id, sender_id: senderId,
          text: note, is_system_note: 1, created_at: now(), sender_is_me: true
        })
      }
    }
    const r = db.run(
      `INSERT INTO messages (conversation_id, sender_id, text, media_type, media_url, is_system_note, created_at) VALUES (?,?,?,?,?,?,?)`,
      [convo.id, senderId, content, mediaType, mediaUrl, 0, now()]
    )
    updatePreviewAndBroadcast(convo, senderId, preview, r.lastInsertRowid, mediaType, mediaUrl)
    return {
      message: serializeMessage({
        id: r.lastInsertRowid, conversation_id: convo.id, sender_id: senderId,
        text: content, media_type: mediaType, media_url: mediaUrl,
        is_system_note: 0, created_at: now(), sender_is_me: true
      })
    }
  }

  function updatePreviewAndBroadcast(convo, senderId, text, messageId, mediaType = null, mediaUrl = null) {
    const nowIso = now()
    if (convo.user_a === senderId) {
      db.run('UPDATE conversations SET last_message_text = ?, last_time = ?, unread_b = unread_b + 1 WHERE id = ?',
        [text, nowIso, convo.id])
    } else {
      db.run('UPDATE conversations SET last_message_text = ?, last_time = ?, unread_a = unread_a + 1 WHERE id = ?',
        [text, nowIso, convo.id])
    }
    const payload = {
      id: String(messageId),
      conversationId: String(convo.id),
      text,
      mediaType: mediaType || undefined,
      mediaUrl: mediaUrl || undefined,
      time: nowIso,
      senderId: String(senderId)
    }
    bus.io?.to(`user:${convo.user_a}`).emit('chat:message', payload)
    bus.io?.to(`user:${convo.user_b}`).emit('chat:message', payload)
  }

  return { router, saveMessage }
}
