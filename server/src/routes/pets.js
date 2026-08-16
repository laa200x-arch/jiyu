/**
 * 宠物护理域（旧巡六迁移，方案 D-01：纯互换语义，零金钱）
 * - 宠物档案 CRUD（含旧版校验规则：姓名/品种/年龄 0-180 月/性别/绝育/猫体重必填/备注 ≤2000）
 * - 服务目录（7 种，过夜/当日/其他 三类，无价格）
 * - 看护预约（互换语义：宠物护理 ↔ 技能，无金钱交易）
 */
import { Router } from 'express'
import { requireAuth } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

// 服务目录（F-11/F-12：目录 KEEP，定价 REDESIGN 为互换语义）
export const CARE_SERVICES = [
  { id: 'overnight', name: '宠物寄养过夜', category: 'overnight', desc: '家庭式寄养，含每日喂养与遛弯', duration: '1 晚起' },
  { id: 'overnight-care', name: '家庭式过夜看护', category: 'overnight', desc: '上门或接送到家过夜陪伴', duration: '1 晚起' },
  { id: 'daycare', name: '当日寄养', category: 'day', desc: '白天托管，晚间接回', duration: '8:00-20:00' },
  { id: 'walk', name: '遛狗', category: 'day', desc: '每日 1-2 次户外遛弯', duration: '30-60 分钟/次' },
  { id: 'feeding', name: '上门喂食', category: 'day', desc: '上门喂食换水，可视频确认', duration: '20 分钟/次' },
  { id: 'bath', name: '宠物洗澡', category: 'other', desc: '温和洗护 + 吹干', duration: '约 1 小时' },
  { id: 'groom', name: '美容护理', category: 'other', desc: '修剪/梳毛/指甲护理', duration: '约 1.5 小时' }
]

// 宠物档案字典（F-23：狗 8 行为 / 猫 10 行为 / 家中反应 4 / 体重分级 4）
export const PET_OPTIONS = {
  dogBehaviors: ['活泼好动', '安静温顺', '粘人', '护食', '对狗友好', '对猫友好', '怕生', '爱叫'],
  catBehaviors: ['亲人', '高冷', '胆小', '活泼', '爱叫', '抓家具', '埋食', '对狗友好', '对陌生人有戒心', '夜间活跃'],
  homeReactions: ['家人不在时焦虑', '拆家', '定点排泄良好', '作息规律'],
  weightOptions: ['<5kg', '5-10kg', '10-25kg', '>25kg']
}

export function petsRouter(db) {
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

  // 我的看护预约（我发起 + 我做看护人）
  router.get('/bookings', (req, res) => {
    const rows = db.all('SELECT * FROM bookings WHERE user_id = ? OR provider_id = ? ORDER BY id DESC', [req.userId, req.userId])
    res.json({
      bookings: rows.map((row) => ({
        id: String(row.id),
        userId: String(row.user_id),
        providerId: String(row.provider_id),
        petId: String(row.pet_id),
        serviceId: row.service_id,
        serviceName: row.service_name,
        scheduledTime: row.scheduled_time,
        location: row.location || null,
        status: row.status,
        createdAt: row.created_at,
        pet: (() => {
          const p = db.get('SELECT * FROM pets WHERE id = ?', [row.pet_id])
          return p ? serializePet(p) : null
        })(),
        initiator: (() => {
          const u = db.get('SELECT id, nickname, avatar_symbol, avatar_url, credit_score, location_label FROM users WHERE id = ?', [row.user_id])
          return u ? { id: String(u.id), userName: u.nickname, avatarSymbol: u.avatar_symbol, avatarUrl: u.avatar_url || null, creditScore: u.credit_score, locationLabel: u.location_label } : null
        })(),
        provider: (() => {
          const u = db.get('SELECT id, nickname, avatar_symbol, avatar_url, credit_score, location_label FROM users WHERE id = ?', [row.provider_id])
          return u ? { id: String(u.id), userName: u.nickname, avatarSymbol: u.avatar_symbol, avatarUrl: u.avatar_url || null, creditScore: u.credit_score, locationLabel: u.location_label } : null
        })()
      }))
    })
  })

  // 发起看护预约（互换语义，零金钱；线下需公共场所）
  router.post('/bookings', (req, res) => {
    const { petId, serviceId, providerId, scheduledTime, location } = req.body || {}
    if (!petId || !serviceId || !providerId || !scheduledTime) {
      return res.status(400).json({ error: 'petId/serviceId/providerId/scheduledTime 必填' })
    }
    if (Number(providerId) === req.userId) return res.status(400).json({ error: '不能预约自己' })
    const pet = db.get('SELECT * FROM pets WHERE id = ? AND user_id = ?', [petId, req.userId])
    if (!pet) return res.status(404).json({ error: '宠物不存在' })
    const service = CARE_SERVICES.find((s) => s.id === serviceId)
    if (!service) return res.status(404).json({ error: '服务不存在' })
    const provider = db.get('SELECT id FROM users WHERE id = ?', [providerId])
    if (!provider) return res.status(404).json({ error: '看护人不存在' })
    if (!location) return res.status(400).json({ error: '请填写服务地点（公共场所）' })

    const r = db.run(
      `INSERT INTO bookings (user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, created_at)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [req.userId, providerId, petId, serviceId, service.name, scheduledTime, location, 'pending', now()]
    )
    const row = db.get('SELECT * FROM bookings WHERE id = ?', [r.lastInsertRowid])
    res.status(201).json({ booking: { id: String(row.id), status: 'pending' } })
  })

  // 标记预约完成
  router.post('/bookings/:id/complete', (req, res) => {
    const r = db.run('UPDATE bookings SET status = ? WHERE id = ? AND (user_id = ? OR provider_id = ?)',
      ['completed', req.params.id, req.userId, req.userId])
    if (r.changes === 0) return res.status(404).json({ error: '预约不存在' })
    res.json({ ok: true })
  })

  return router
}
