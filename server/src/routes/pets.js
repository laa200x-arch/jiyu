/**
 * 宠物护理域（旧巡六迁移，方案 D-01：纯互换语义，零金钱）
 * - 宠物档案 CRUD（含旧版校验规则：姓名/品种/年龄 0-180 月/性别/绝育/猫体重必填/备注 ≤2000）
 * - 服务目录（7 种，过夜/当日/其他 三类，无价格）
 * - 看护预约（互换语义：宠物护理 ↔ 技能，无金钱交易）
 */
import { Router } from 'express'
import { requireAuth } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

// 服务目录（7 种，含定价；平台佣金率 10%，其余归服务人员）
export const CARE_SERVICES = [
  { id: 'overnight', name: '宠物寄养过夜', category: 'overnight', desc: '家庭式寄养，含每日喂养与遛弯', duration: '1 晚起', priceYuan: 45 },
  { id: 'overnight-care', name: '家庭式过夜看护', category: 'overnight', desc: '上门或接送到家过夜陪伴', duration: '1 晚起', priceYuan: 50 },
  { id: 'daycare', name: '当日寄养', category: 'day', desc: '白天托管，晚间接回', duration: '8:00-20:00', priceYuan: 35 },
  { id: 'walk', name: '遛狗', category: 'day', desc: '每日 1-2 次户外遛弯', duration: '30-60 分钟/次', priceYuan: 20 },
  { id: 'feeding', name: '上门喂食', category: 'day', desc: '上门喂食换水，可视频确认', duration: '20 分钟/次', priceYuan: 15 },
  { id: 'bath', name: '宠物洗澡', category: 'other', desc: '温和洗护 + 吹干', duration: '约 1 小时', priceYuan: 30 },
  { id: 'groom', name: '美容护理', category: 'other', desc: '修剪/梳毛/指甲护理', duration: '约 1.5 小时', priceYuan: 40 }
]

// 平台佣金率（宠物服务收费模式；其余归服务人员）
export const COMMISSION_RATE = 0.1

// 接单资历门槛（"有资历的人可以接单"：信用 ≥75 且已完成任意认证）
export const ACCEPT_REQUIREMENT = { minCredit: 75 }

// 宠物档案字典（F-23：狗 8 行为 / 猫 10 行为 / 家中反应 4 / 体重分级 4）
export const PET_OPTIONS = {
  dogBehaviors: ['活泼好动', '安静温顺', '粘人', '护食', '对狗友好', '对猫友好', '怕生', '爱叫'],
  catBehaviors: ['亲人', '高冷', '胆小', '活泼', '爱叫', '抓家具', '埋食', '对狗友好', '对陌生人有戒心', '夜间活跃'],
  homeReactions: ['家人不在时焦虑', '拆家', '定点排泄良好', '作息规律'],
  weightOptions: ['<5kg', '5-10kg', '10-25kg', '>25kg']
}

export function petsRouter(db, bus = { io: null }) {
  const router = Router()
  router.use(requireAuth)
  const now = () => new Date().toISOString()

  const serializePet = (row) => ({
    id: String(row.id),
    userId: String(row.user_id),
    name: row.name,
    petType: row.pet_type,
    breed: row.breed,
    ageMonths: row.age_months,
    gender: row.gender,
    neutered: !!row.neutered,
    weightKg: row.weight_kg,
    behaviors: row.behaviors ? JSON.parse(row.behaviors) : [],
    homeReactions: row.home_reactions ? JSON.parse(row.home_reactions) : [],
    photoUrl: row.photo_url || null,
    notes: row.notes,
    createdAt: row.created_at
  })

  /** 宠物校验（F-24 规则镜像） */
  function validatePet(body) {
    const { name, petType, breed, ageMonths, gender, neutered, weightKg, notes } = body || {}
    if (!name || !String(name).trim()) return '宠物姓名必填'
    if (!['dog', 'cat', 'other'].includes(petType)) return '宠物类型必填（dog/cat/other）'
    if (!breed || !String(breed).trim()) return '品种必填'
    const age = Number(ageMonths)
    if (!Number.isFinite(age) || age < 0 || age > 180) return '年龄需在 0-180 月之间'
    if (!['male', 'female'].includes(gender)) return '性别必填'
    if (neutered === undefined || neutered === null) return '是否绝育必填'
    if (petType === 'cat' && (weightKg === undefined || weightKg === null || Number(weightKg) <= 0)) return '猫咪体重必填'
    if (notes && String(notes).length > 2000) return '备注不能超过 2000 字'
    const risk = checkTextRisk(String(name || '') + String(breed || ''))
    if (risk.isIllegal) return risk.warning
    return null
  }

  // 服务目录
  router.get('/care-services', (req, res) => {
    res.json({ services: CARE_SERVICES, options: PET_OPTIONS })
  })

  // 我的宠物列表
  router.get('/pets', (req, res) => {
    const rows = db.all('SELECT * FROM pets WHERE user_id = ? ORDER BY id DESC', [req.userId])
    res.json({ pets: rows.map(serializePet) })
  })

  // 添加宠物
  router.post('/pets', (req, res) => {
    const error = validatePet(req.body)
    if (error) return res.status(400).json({ error })
    const { name, petType, breed, ageMonths, gender, neutered, weightKg, behaviors, homeReactions, photoUrl, notes } = req.body
    const r = db.run(
      `INSERT INTO pets (user_id, name, pet_type, breed, age_months, gender, neutered, weight_kg, behaviors, home_reactions, photo_url, notes, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [req.userId, String(name).trim(), petType, String(breed).trim(), Number(ageMonths), gender,
        neutered ? 1 : 0, weightKg ?? null,
        behaviors && behaviors.length ? JSON.stringify(behaviors) : null,
        homeReactions && homeReactions.length ? JSON.stringify(homeReactions) : null,
        photoUrl || null, String(notes || '').trim(), now()]
    )
    res.status(201).json({ pet: serializePet(db.get('SELECT * FROM pets WHERE id = ?', [r.lastInsertRowid])) })
  })

  // 宠物详情
  router.get('/pets/:id', (req, res) => {
    const row = db.get('SELECT * FROM pets WHERE id = ? AND user_id = ?', [req.params.id, req.userId])
    if (!row) return res.status(404).json({ error: '宠物不存在' })
    res.json({ pet: serializePet(row) })
  })

  // 删除宠物
  router.delete('/pets/:id', (req, res) => {
    const r = db.run('DELETE FROM pets WHERE id = ? AND user_id = ?', [req.params.id, req.userId])
    if (r.changes === 0) return res.status(404).json({ error: '宠物不存在' })
    res.json({ ok: true })
  })

  /** 订单序列化（列表与详情共用；viewerId 用于计算下单人与查看者的距离、返回本人申请状态） */
  function serializeBooking(row, viewerId = null) {
    const initiator = db.get('SELECT id, nickname, avatar_symbol, avatar_url, credit_score, location_label, distance_km FROM users WHERE id = ?', [row.user_id])
    const provider = row.provider_id ? db.get('SELECT id, nickname, avatar_symbol, avatar_url, credit_score, location_label, distance_km FROM users WHERE id = ?', [row.provider_id]) : null
    const distanceKm = initiator ? (Number(viewerId) === row.user_id ? 0 : initiator.distance_km ?? null) : null
    // 申请列表：仅派单人（下单人）可见；申请者只返回自己的申请状态
    const applications = Number(viewerId) === row.user_id
      ? db.all(
          `SELECT a.*, u.nickname, u.avatar_symbol, u.avatar_url, u.credit_score, u.verification, u.location_label
           FROM booking_applications a JOIN users u ON u.id = a.user_id
           WHERE a.booking_id = ? ORDER BY a.id`,
          [row.id]
        ).map((a) => ({
          id: String(a.id),
          userId: String(a.user_id),
          userName: a.nickname,
          avatarSymbol: a.avatar_symbol,
          avatarUrl: a.avatar_url || null,
          creditScore: a.credit_score,
          verification: a.verification,
          locationLabel: a.location_label,
          message: a.message || null,
          status: a.status,
          createdAt: a.created_at
        }))
      : null
    const mine = viewerId != null
      ? db.get('SELECT * FROM booking_applications WHERE booking_id = ? AND user_id = ?', [row.id, viewerId])
      : null
    return {
      id: String(row.id),
      userId: String(row.user_id),
      providerId: row.provider_id ? String(row.provider_id) : null,
      petId: String(row.pet_id),
      serviceId: row.service_id,
      serviceName: row.service_name,
      scheduledTime: row.scheduled_time,
      location: row.location || null,
      status: row.status,
      priceYuan: row.price_yuan,
      commissionRate: row.commission_rate,
      commissionYuan: row.commission_yuan,
      workerIncome: row.worker_income,
      openToFeed: !!row.open_to_feed,
      createdAt: row.created_at,
      pet: (() => {
        const p = db.get('SELECT * FROM pets WHERE id = ?', [row.pet_id])
        return p ? serializePet(p) : null
      })(),
      initiator: initiator ? { id: String(initiator.id), userName: initiator.nickname, avatarSymbol: initiator.avatar_symbol, avatarUrl: initiator.avatar_url || null, creditScore: initiator.credit_score, locationLabel: initiator.location_label, distanceKm: initiator.distance_km } : null,
      provider: provider ? { id: String(provider.id), userName: provider.nickname, avatarSymbol: provider.avatar_symbol, avatarUrl: provider.avatar_url || null, creditScore: provider.credit_score, locationLabel: provider.location_label, distanceKm: provider.distance_km } : null,
      distanceKm,
      applications,
      myApplication: mine ? { id: String(mine.id), status: mine.status, message: mine.message || null, createdAt: mine.created_at } : null
    }
  }

  // 我的看护订单（我发布 + 我接单）
  router.get('/bookings', (req, res) => {
    const rows = db.all('SELECT * FROM bookings WHERE user_id = ? OR provider_id = ? ORDER BY id DESC', [req.userId, req.userId])
    res.json({ bookings: rows.map((row) => serializeBooking(row, req.userId)) })
  })

  // 订单详情（动态区公开可见：接单人可查看宠物信息、位置、距离；登录即可）
  router.get('/bookings/:id', (req, res) => {
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '订单不存在' })
    res.json({ booking: serializeBooking(row, req.userId) })
  })

  // 发起看护订单（收费模式：价格 = 服务定价；平台佣金 10%，其余归服务人员）
  // 两种方式：providerId 指定认识的看护人；或 openToFeed 发布到互换动态让有资历的人接单
  router.post('/bookings', (req, res) => {
    const { petId, serviceId, providerId, scheduledTime, location, openToFeed } = req.body || {}
    if (!petId || !serviceId || !scheduledTime) {
      return res.status(400).json({ error: 'petId/serviceId/scheduledTime 必填' })
    }
    if (!providerId && !openToFeed) {
      return res.status(400).json({ error: '请选择看护人，或发布到动态区等待接单' })
    }
    if (providerId && Number(providerId) === req.userId) return res.status(400).json({ error: '不能下单给自己' })
    const pet = db.get('SELECT * FROM pets WHERE id = ? AND user_id = ?', [petId, req.userId])
    if (!pet) return res.status(404).json({ error: '宠物不存在' })
    const service = CARE_SERVICES.find((s) => s.id === serviceId)
    if (!service) return res.status(404).json({ error: '服务不存在' })
    if (providerId) {
      const provider = db.get('SELECT id FROM users WHERE id = ?', [providerId])
      if (!provider) return res.status(404).json({ error: '看护人不存在' })
    }
    if (!location) return res.status(400).json({ error: '请填写服务地点（公共场所）' })

    // 金额结算：平台佣金 = 价格 × 佣金率；服务人员所得 = 价格 - 佣金
    const price = service.priceYuan
    const commission = Math.round(price * COMMISSION_RATE * 100) / 100
    const workerIncome = Math.round((price - commission) * 100) / 100
    const status = openToFeed ? 'open' : 'assigned'

    const r = db.run(
      `INSERT INTO bookings (user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, price_yuan, commission_rate, commission_yuan, worker_income, open_to_feed, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [req.userId, providerId || null, petId, serviceId, service.name, scheduledTime, location, status,
        price, COMMISSION_RATE, commission, workerIncome, openToFeed ? 1 : 0, now()]
    )
    const orderId = r.lastInsertRowid

    // 发布到互换动态：生成订单卡片（结构化数据，不经过文本风控）
    if (openToFeed) {
      db.run(
        `INSERT INTO dynamics (user_id, content, image_base64, is_system_post, order_id, created_at) VALUES (?,?,?,?,?,?)`,
        [req.userId, `【宠物护理订单】${service.name} · ${pet.name} · ¥${price}/次 · ${scheduledTime}`, null, 0, String(orderId), now()]
      )
    }
    res.status(201).json({ booking: { id: String(orderId), status, priceYuan: price, commissionYuan: commission, workerIncome } })
  })

  // 接单申请（"有资历的人可以接单"：信用 ≥75 且已完成认证；不能申请自己的单；仅 open 状态）
  // 申请后由派单人在私聊/订单详情中确认接单人（confirm）
  router.post('/bookings/:id/apply', (req, res) => {
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '订单不存在' })
    if (row.user_id === req.userId) return res.status(400).json({ error: '不能申请自己的订单' })
    if (row.status !== 'open') return res.status(400).json({ error: '该订单已接单或已关闭' })
    const me = db.get('SELECT * FROM users WHERE id = ?', [req.userId])
    if (!me) return res.status(404).json({ error: '用户不存在' })
    if (me.credit_score < ACCEPT_REQUIREMENT.minCredit || me.verification === 'none') {
      return res.status(403).json({ error: `接单需要信用 ≥${ACCEPT_REQUIREMENT.minCredit} 且完成实名/学生认证（有资历要求）` })
    }
    const existing = db.get('SELECT * FROM booking_applications WHERE booking_id = ? AND user_id = ?', [row.id, req.userId])
    if (existing) return res.status(400).json({ error: '已提交过申请，等待派单人确认' })
    const message = String(req.body?.message || '').trim().slice(0, 200) || null
    const r = db.run(
      `INSERT INTO booking_applications (booking_id, user_id, message, status, created_at) VALUES (?,?,?,?,?)`,
      [row.id, req.userId, message, 'pending', now()]
    )
    // 通知派单人：自动建立会话并追加系统提示（在私聊中协商并确认接单人）
    notifyInChat(row.user_id, req.userId, row, `📋 ${me.nickname} 申请接下你的「${row.service_name}」订单（¥${row.price_yuan}），可在私聊中协商并确认接单人`)
    res.status(201).json({ application: { id: String(r.lastInsertRowid), status: 'pending' } })
  })

  // 派单人确认接单人（在私聊/订单详情中确定；其余待处理申请自动拒绝）
  router.post('/bookings/:id/applications/:appId/confirm', (req, res) => {
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '订单不存在' })
    if (row.user_id !== req.userId) return res.status(403).json({ error: '只有派单人可以确认接单人' })
    const app = db.get('SELECT * FROM booking_applications WHERE id = ? AND booking_id = ?', [req.params.appId, row.id])
    if (!app) return res.status(404).json({ error: '申请不存在' })
    if (app.status !== 'pending') return res.status(400).json({ error: '该申请已处理' })
    if (row.status !== 'open') return res.status(400).json({ error: '该订单已接单或已关闭' })
    db.run(`UPDATE booking_applications SET status = 'accepted' WHERE id = ?`, [app.id])
    db.run(`UPDATE booking_applications SET status = 'rejected' WHERE booking_id = ? AND id != ? AND status = 'pending'`, [row.id, app.id])
    db.run('UPDATE bookings SET provider_id = ?, status = ? WHERE id = ?', [app.user_id, 'assigned', row.id])
    const applicant = db.get('SELECT * FROM users WHERE id = ?', [app.user_id])
    notifyInChat(app.user_id, row.user_id, row, `✅ 派单人已确认你为「${row.service_name}」订单的接单人（¥${row.price_yuan}），请按时提供宠物护理服务`)
    notifyInChat(row.user_id, app.user_id, row, `✅ 你已确认 ${applicant?.nickname || '对方'} 接下「${row.service_name}」订单，服务完成后可标记完成`)
    res.json({ ok: true, booking: { id: String(row.id), status: 'assigned', providerId: String(app.user_id) } })
  })

  // 派单人拒绝申请
  router.post('/bookings/:id/applications/:appId/reject', (req, res) => {
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '订单不存在' })
    if (row.user_id !== req.userId) return res.status(403).json({ error: '只有派单人可以处理申请' })
    const app = db.get('SELECT * FROM booking_applications WHERE id = ? AND booking_id = ?', [req.params.appId, row.id])
    if (!app) return res.status(404).json({ error: '申请不存在' })
    if (app.status !== 'pending') return res.status(400).json({ error: '该申请已处理' })
    db.run(`UPDATE booking_applications SET status = 'rejected' WHERE id = ?`, [app.id])
    res.json({ ok: true })
  })

  // 直接接单（兼容旧接口；新流程请用 apply + confirm）
  router.post('/bookings/:id/accept', (req, res) => {
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '订单不存在' })
    if (row.user_id === req.userId) return res.status(400).json({ error: '不能接自己的订单' })
    if (row.status !== 'open') return res.status(400).json({ error: '该订单已接单或已关闭' })
    const me = db.get('SELECT * FROM users WHERE id = ?', [req.userId])
    if (!me) return res.status(404).json({ error: '用户不存在' })
    if (me.credit_score < ACCEPT_REQUIREMENT.minCredit || me.verification === 'none') {
      return res.status(403).json({ error: `接单需要信用 ≥${ACCEPT_REQUIREMENT.minCredit} 且完成实名/学生认证（有资历要求）` })
    }
    db.run('UPDATE bookings SET provider_id = ?, status = ? WHERE id = ?', [req.userId, 'assigned', row.id])
    res.json({ ok: true, booking: { id: String(row.id), status: 'assigned' } })
  })

  // 标记订单完成（结算：服务费/佣金/服务人员所得）
  router.post('/bookings/:id/complete', (req, res) => {
    const r = db.run('UPDATE bookings SET status = ? WHERE id = ? AND (user_id = ? OR provider_id = ?)',
      ['completed', req.params.id, req.userId, req.userId])
    if (r.changes === 0) return res.status(404).json({ error: '订单不存在' })
    res.json({ ok: true })
  })

  /**
   * 私聊系统提示（申请/确认接单自动写入会话）
   * 自动建立/复用 双方会话，追加系统消息并实时广播（双方可见）
   */
  function notifyInChat(recipientId, actorId, booking, text) {
    const a = Math.min(recipientId, actorId)
    const b = Math.max(recipientId, actorId)
    let convo = db.get('SELECT * FROM conversations WHERE user_a = ? AND user_b = ?', [a, b])
    if (!convo) {
      const r = db.run(
        'INSERT INTO conversations (user_a, user_b, last_message_text, last_time, unread_a, unread_b) VALUES (?,?,?,?,?,?)',
        [a, b, text, now(), 0, 0]
      )
      convo = db.get('SELECT * FROM conversations WHERE id = ?', [r.lastInsertRowid])
    }
    const r = db.run(
      'INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)',
      [convo.id, actorId, text, 1, now()]
    )
    if (convo.user_a === recipientId) {
      db.run('UPDATE conversations SET last_message_text = ?, last_time = ?, unread_a = unread_a + 1 WHERE id = ?',
        [text, now(), convo.id])
    } else {
      db.run('UPDATE conversations SET last_message_text = ?, last_time = ?, unread_b = unread_b + 1 WHERE id = ?',
        [text, now(), convo.id])
    }
    const payload = {
      id: String(r.lastInsertRowid),
      conversationId: String(convo.id),
      text,
      time: now(),
      senderId: String(actorId),
      isSystemNote: true
    }
    bus.io?.to(`user:${a}`).emit('chat:message', payload)
    bus.io?.to(`user:${b}`).emit('chat:message', payload)
  }

  return router
}
