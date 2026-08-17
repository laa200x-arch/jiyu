/**
 * 鉴权中间件（JWT）
 */
import jwt from 'jsonwebtoken'
import { config } from './config.js'

export function signToken(userId) {
  return jwt.sign({ sub: String(userId) }, config.jwtSecret, { expiresIn: config.jwtExpires })
}

export function requireAuth(req, res, next) {
  const header = req.headers.authorization || ''
  const token = header.startsWith('Bearer ') ? header.slice(7) : null
  if (!token) return res.status(401).json({ error: '未登录' })
  try {
    const payload = jwt.verify(token, config.jwtSecret)
    req.userId = Number(payload.sub)
    next()
  } catch {
    return res.status(401).json({ error: '登录已过期，请重新登录' })
  }
}

/**
 * 用户序列化：数据库字段 → iOS 端 Codable 对齐的 camelCase JSON
 * （字段名与 Swift 端 UserModel 完全一致，便于客户端直接解码）
 * @param {object} row 用户行
 * @param {object} opts
 * @param {Array|null} opts.skills 技能行数组
 * @param {boolean} opts.includePhone 是否返回手机号（隐私：仅本人相关接口可传 true）
 */
export function serializeUser(row, { skills = null, includePhone = false } = {}) {
  if (!row) return null
  // 曝光 VIP 过期校验：exposure_until 已过则视为普通用户（排序/展示一致）
  const vipActive = !!row.is_exposure_vip &&
    (!row.exposure_until || new Date(row.exposure_until).getTime() > Date.now())
  const user = {
    id: String(row.id),
    username: row.username,
    userName: row.nickname,
    avatarSymbol: row.avatar_symbol,
    avatarUrl: row.avatar_url || null,
    bio: row.bio,
    locationLabel: row.location_label,
    distanceKm: row.distance_km,
    creditScore: row.credit_score,
    verification: row.verification,
    isExposureVip: vipActive,
    exposureUntil: row.exposure_until || null,
    mySkills: skills ? skills.filter((s) => s.kind === 'teach').map(serializeSkill) : [],
    wantSkills: skills ? skills.filter((s) => s.kind === 'want').map(serializeSkill) : []
  }
  if (includePhone) user.phone = row.phone || null
  return user
}

export function serializeSkill(row) {
  return {
    id: String(row.id),
    skillName: row.name,
    skillLevel: row.level,
    exchangeType: row.exchange_type,
    availableTime: row.available_time
  }
}

export function serializeConversation(row) {
  return {
    id: String(row.id),
    partner: serializeUser(row),
    lastMessageText: row.last_message_text,
    lastTime: row.last_time,
    unreadCount: row.unread_count
  }
}

export function serializeMessage(row) {
  return {
    id: String(row.id),
    senderIsMe: row.sender_is_me,
    text: row.text,
    mediaType: row.media_type || null,
    mediaUrl: row.media_url || null,
    orderId: row.order_id || null,
    time: row.created_at,
    isSystemNote: !!row.is_system_note
  }
}

export function serializeRecord(row) {
  return {
    id: String(row.id),
    partner: serializeUser(row),
    mySkillName: row.my_skill_name,
    learnSkillName: row.learn_skill_name,
    exchangeType: row.exchange_type,
    scheduledTime: row.scheduled_time,
    location: row.location || null,
    status: row.status,
    evaluateGiven: !!row.evaluate_given,
    createdAt: row.created_at
  }
}
