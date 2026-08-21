/**
 * 双向智能匹配路由（方案 2.3.2 / 5.2，平台核心）
 * 匹配逻辑：我擅长的 ∩ 对方想学的 且 对方擅长的 ∩ 我想学的
 * 排序：曝光 VIP 优先 → 信用分高优先 → 距离近优先
 */
import { Router } from 'express'
import { requireAuth, serializeUser } from '../middleware.js'

export function matchRouter(db) {
  const router = Router()
  router.use(requireAuth)

  const normalize = (s) => String(s || '').trim().toLowerCase()

  const skillsMatch = (a, b) => {
    const x = normalize(a)
    const y = normalize(b)
    if (x === y) return true
    if (x.length < 2 || y.length < 2) return false
    return x.includes(y) || y.includes(x)
  }

  router.get('/match', (req, res) => {
    const me = db.get('SELECT * FROM users WHERE id = ?', [req.userId])
    if (!me) return res.status(404).json({ error: '用户不存在' })
    const myTeach = db.all('SELECT * FROM skills WHERE user_id = ? AND kind = ?', [me.id, 'teach'])
    const myLearn = db.all('SELECT * FROM skills WHERE user_id = ? AND kind = ?', [me.id, 'want'])

    const nearbyOnly = req.query.nearbyOnly === '1' || req.query.nearbyOnly === 'true'
    const type = req.query.type || ''
    const keyword = normalize(req.query.keyword || '')
    const minCredit = Number(req.query.minCredit || 0)

    const others = db.all('SELECT * FROM users WHERE id != ?', [me.id])
    const results = []

    for (const target of others) {
      if (target.credit_score < minCredit) continue
      if (nearbyOnly) {
        if (target.distance_km == null || target.distance_km > 10) continue
      }
      const targetTeach = db.all('SELECT * FROM skills WHERE user_id = ? AND kind = ?', [target.id, 'teach'])
      const targetLearn = db.all('SELECT * FROM skills WHERE user_id = ? AND kind = ?', [target.id, 'want'])

      if (type) {
        const supports = targetTeach.some((s) => s.exchange_type === type || s.exchange_type === 'both')
        if (!supports) continue
      }
      if (keyword) {
        const haystack = [...targetTeach.map((s) => s.name), ...targetLearn.map((s) => s.name), target.nickname]
          .join('').toLowerCase()
        if (!haystack.includes(keyword)) continue
      }

      // 双向对等匹配核心校验
      const teachForThem = myTeach
        .filter((s) => targetLearn.some((t) => skillsMatch(s.name, t.name)))
        .map((s) => s.name)
      const learnFromThem = targetTeach
        .filter((s) => myLearn.some((t) => skillsMatch(s.name, t.name)))
        .map((s) => s.name)

      if (teachForThem.length === 0 || learnFromThem.length === 0) continue

      const skills = [...targetTeach, ...targetLearn]
      results.push({
        user: serializeUser(target, { skills }),
        mySkillsForThem: teachForThem,
        theirSkillsForMe: learnFromThem
      })
    }

    // 排序：VIP 曝光优先 → 距离近优先（信用分已从用户视角移除）
    results.sort((a, b) => {
      if (a.user.isExposureVip !== b.user.isExposureVip) return a.user.isExposureVip ? -1 : 1
      return (a.user.distanceKm ?? Infinity) - (b.user.distanceKm ?? Infinity)
    })

    res.json({ matches: results, total: results.length })
  })

  return router
}
