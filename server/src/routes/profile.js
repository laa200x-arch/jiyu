/**
 * 个人档案路由（方案 2.3.1）：资料 / 技能增删 / 认证 / 曝光
 */
import { Router } from 'express'
import { requireAuth, serializeUser, serializeSkill } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

export function profileRouter(db) {
  const router = Router()
  router.use(requireAuth)

  function userWithSkills(id) {
    const row = db.get('SELECT * FROM users WHERE id = ?', [id])
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [id])
    return serializeUser(row, { skills })
  }

  // 更新资料（主页文本同样过风控：禁止出现价格/接单等词，方案 2.3.1；支持头像 URL）
  router.put('/me/profile', (req, res) => {
    const { bio, locationLabel, distanceKm, avatarUrl } = req.body || {}
    if (bio !== undefined) {
      const risk = checkTextRisk(bio)
      if (risk.isIllegal) return res.status(403).json({ error: risk.warning, matchedWords: risk.matchedWords })
    }
    db.run(
      `UPDATE users SET bio = COALESCE(?, bio), location_label = COALESCE(?, location_label),
        distance_km = COALESCE(?, distance_km), avatar_url = COALESCE(?, avatar_url) WHERE id = ?`,
      [bio ?? null, locationLabel ?? null, distanceKm ?? null, avatarUrl ?? null, req.userId]
    )
    res.json({ user: userWithSkills(req.userId) })
  })

  // 添加技能
  router.post('/me/skills', (req, res) => {
    const { kind, skill } = req.body || {}
    if (!['teach', 'want'].includes(kind) || !skill?.skillName) {
      return res.status(400).json({ error: 'kind(teach/want) 与 skill.skillName 必填' })
    }
    const risk = checkTextRisk(skill.skillName)
    if (risk.isIllegal) return res.status(403).json({ error: risk.warning })
    const r = db.run(
      `INSERT INTO skills (user_id, kind, name, level, exchange_type, available_time) VALUES (?,?,?,?,?,?)`,
      [req.userId, kind, skill.skillName, skill.skillLevel || 'beginner',
        skill.exchangeType || 'both', skill.availableTime || '待协商']
    )
    res.status(201).json({
      skill: serializeSkill(db.get('SELECT * FROM skills WHERE id = ?', [r.lastInsertRowid]))
    })
  })

  // 删除技能
  router.delete('/me/skills/:kind/:id', (req, res) => {
    const r = db.run('DELETE FROM skills WHERE id = ? AND user_id = ? AND kind = ?',
      [req.params.id, req.userId, req.params.kind])
    if (r.changes === 0) return res.status(404).json({ error: '技能不存在' })
    res.json({ ok: true })
  })

  // 认证（学生/实名，方案 2.3.1；正式版对接学信网与实名服务商）
  router.put('/me/verification', (req, res) => {
    const { verification } = req.body || {}
    if (!['none', 'student', 'realname', 'full'].includes(verification)) {
      return res.status(400).json({ error: 'verification 取值不合法' })
    }
    db.run('UPDATE users SET verification = ? WHERE id = ?', [verification, req.userId])
    res.json({ user: userWithSkills(req.userId) })
  })

  // 曝光服务（方案 3.1：模拟开通；正式版由 iOS 端 IAP 回调后调用）
  const packages = {
    day: { days: 1, priceYuan: 3, weight: 1.0 },
    week: { days: 7, priceYuan: 12, weight: 1.5 },
    month: { days: 30, priceYuan: 30, weight: 2.0 }
  }
  router.put('/me/exposure', (req, res) => {
    const { packageId } = req.body || {}
    const pkg = packages[packageId]
    if (!pkg) return res.status(400).json({ error: 'packageId 必填：day/week/month' })
    const until = new Date(Date.now() + pkg.days * 86400000).toISOString()
    db.run('UPDATE users SET is_exposure_vip = 1, exposure_until = ? WHERE id = ?', [until, req.userId])
    res.json({ user: userWithSkills(req.userId) })
  })
  router.delete('/me/exposure', (req, res) => {
    db.run('UPDATE users SET is_exposure_vip = 0, exposure_until = NULL WHERE id = ?', [req.userId])
    res.json({ user: userWithSkills(req.userId) })
  })

  // 用户列表（公开档案，用于匹配与展示）
  router.get('/users', (req, res) => {
    const rows = db.all('SELECT * FROM users ORDER BY id ASC')
    res.json({ users: rows.map((row) => {
      const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [row.id])
      return serializeUser(row, { skills })
    }) })
  })

  router.get('/users/:id', (req, res) => {
    const row = db.get('SELECT * FROM users WHERE id = ?', [req.params.id])
    if (!row) return res.status(404).json({ error: '用户不存在' })
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [row.id])
    res.json({ user: serializeUser(row, { skills }) })
  })

  return router
}
