/**
 * 社交路由：协议 / 互换记录 / 双向评价 / 动态（方案 2.3.4 / 2.3.5 / 2.3.6）
 */
import { Router } from 'express'
import { requireAuth, serializeUser, serializeRecord } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

export function socialRouter(db, io) {
  const router = Router()
  router.use(requireAuth)
  const now = () => new Date().toISOString()

  const userWithSkills = (id) => {
    const row = db.get('SELECT * FROM users WHERE id = ?', [id])
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [id])
    return serializeUser(row, { skills })
  }

  // ── 协议（方案 2.3.4：签署前校验 → 生成协议 + 互换记录 + 实时推送对方）──

  const template = `【技遇平台官方技能互换协议】
1. 本次技能互换为纯个人兴趣无偿交换，双方确认无任何金钱、物资、有偿交易行为。
2. 双方自愿交换技能教学资源，约定教学时长、教学时间、线上/线下方式。
3. 双方承诺认真教学、守时履约，杜绝敷衍教学、无故爽约。
4. 线下交换请选择公共场所，注意人身与财产安全，平台仅提供信息匹配服务。
5. 若任意一方出现交易违规、爽约、敷衍行为，平台有权扣分、限流、封禁账号。
6. 本协议为平台约束性规则，双方确认签署即认可全部条款。`

  router.get('/agreements', (req, res) => {
    const rows = db.all(`
      SELECT a.*, u.nickname AS partner_name
      FROM agreements a JOIN users u ON u.id = a.partner_id
      WHERE a.user_id = ? ORDER BY a.id DESC`, [req.userId])
    res.json({
      agreements: rows.map((row) => ({
        id: String(row.id),
        partnerId: String(row.partner_id),
        partnerName: row.partner_name,
        mySkillName: row.my_skill_name,
        learnSkillName: row.learn_skill_name,
        exchangeType: row.exchange_type,
        scheduledTime: row.scheduled_time,
        location: row.location || null,
        content: row.content,
        signedAt: row.signed_at
      }))
    })
  })

  router.post('/agreements', (req, res) => {
    const { partnerId, mySkillName, learnSkillName, exchangeType, scheduledTime, location } = req.body || {}
    if (!partnerId || !mySkillName || !learnSkillName || !scheduledTime) {
      return res.status(400).json({ error: 'partnerId/mySkillName/learnSkillName/scheduledTime 必填' })
    }
    if (exchangeType !== 'online' && !location) {
      return res.status(400).json({ error: '线下交换必须填写公共场所地点（平台安全规范）' })
    }
    const partner = db.get('SELECT * FROM users WHERE id = ?', [partnerId])
    if (!partner) return res.status(404).json({ error: '对方用户不存在' })

    const content = `${template}\n\n本次互换约定：\n· 互换内容：${mySkillName} ↔ ${learnSkillName}\n· 交换方式：${exchangeType}\n· 约定时间：${scheduledTime}\n· ${location ? `线下地点：${location}` : '线上教学：平台内 IM / 屏幕共享完成'}`
    const r = db.run(
      `INSERT INTO agreements (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, content, signed_at)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [req.userId, partnerId, mySkillName, learnSkillName, exchangeType, scheduledTime, location ?? null, content, now()]
    )
    const record = db.run(
      `INSERT INTO exchange_records (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, status, evaluate_given, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [req.userId, partnerId, mySkillName, learnSkillName, exchangeType, scheduledTime, location ?? null, 'pending', 0, now()]
    )
    // 实时推送对方（方案 2.3.2 匹配推送）
    const me = userWithSkills(req.userId)
    io?.to(`user:${partnerId}`).emit('match:push', {
      type: 'agreement',
      from: me,
      message: `${me.userName} 向你发起了技能互换邀约：${mySkillName} ↔ ${learnSkillName}`
    })
    const recordRow = db.get('SELECT * FROM exchange_records WHERE id = ?', [record.lastInsertRowid])
    res.status(201).json({
      agreement: { id: String(r.lastInsertRowid), ...req.body, signedAt: now(), content },
      record: serializeRecord({ ...recordRow, partner: partner })
    })
  })

  // ── 互换记录（方案 2.3.3：单次/多次自定义时长）──

  router.get('/exchanges', (req, res) => {
    const rows = db.all('SELECT * FROM exchange_records WHERE user_id = ? ORDER BY id DESC', [req.userId])
    res.json({
      records: rows.map((row) => {
        const partner = db.get('SELECT * FROM users WHERE id = ?', [row.partner_id])
        return serializeRecord({ ...row, partner })
      })
    })
  })

  router.post('/exchanges/:id/complete', (req, res) => {
    const r = db.run('UPDATE exchange_records SET status = ? WHERE id = ? AND user_id = ?',
      ['completed', req.params.id, req.userId])
    if (r.changes === 0) return res.status(404).json({ error: '互换记录不存在' })
    res.json({ ok: true })
  })

  // ── 双向评价 & 信用分（方案 2.3.5 / 5.5）──

  router.post('/evaluations', (req, res) => {
    const { recordId, punctuality, serious, communication, comment = '' } = req.body || {}
    const record = db.get('SELECT * FROM exchange_records WHERE id = ? AND user_id = ?', [recordId, req.userId])
    if (!record) return res.status(404).json({ error: '互换记录不存在' })
    if (record.evaluate_given) return res.status(400).json({ error: '该互换已评价' })

    db.run(
      `INSERT INTO evaluations (record_id, from_user_id, to_user_id, punctuality, serious, communication, comment, created_at)
       VALUES (?,?,?,?,?,?,?,?)`,
      [recordId, req.userId, record.partner_id, punctuality ?? 5, serious ?? 5, communication ?? 5, comment, now()]
    )
    db.run('UPDATE exchange_records SET evaluate_given = 1, status = ? WHERE id = ?', ['completed', recordId])

    // 信用分重算：Σ(三维度均值) / 数量 × 20，0-100，无评价时初始 80
    const evals = db.all('SELECT * FROM evaluations WHERE to_user_id = ?', [record.partner_id])
    let score = 80
    if (evals.length > 0) {
      const total = evals.reduce((sum, e) => sum + (e.punctuality + e.serious + e.communication) / 3, 0)
      score = Math.min(Math.max((total / evals.length) * 20, 0), 100)
    }
    db.run('UPDATE users SET credit_score = ? WHERE id = ?', [score, record.partner_id])
    res.json({ newCreditScore: score, evaluations: evals.length })
  })

  router.get('/evaluations/:userId', (req, res) => {
    const rows = db.all('SELECT * FROM evaluations WHERE to_user_id = ? ORDER BY id DESC', [req.params.userId])
    res.json({ evaluations: rows })
  })

  // ── 动态（方案 2.3.6：发布内容前置风控）──

  router.get('/dynamics', (req, res) => {
    const rows = db.all(`
      SELECT d.*, u.nickname, u.avatar_symbol
      FROM dynamics d JOIN users u ON u.id = d.user_id
      ORDER BY d.id DESC LIMIT 100`)
    res.json({
      dynamics: rows.map((row) => ({
        id: String(row.id),
        authorName: row.nickname,
        avatarSymbol: row.avatar_symbol,
        content: row.content,
        time: row.created_at,
        isSystemPost: !!row.is_system_post
      }))
    })
  })

  router.post('/dynamics', (req, res) => {
    const content = String(req.body?.content || '').trim()
    if (!content) return res.status(400).json({ error: '内容不能为空' })
    const risk = checkTextRisk(content)
    if (risk.isIllegal) {
      return res.status(403).json({ error: risk.warning, matchedWords: risk.matchedWords, blocked: true })
    }
    db.run('INSERT INTO dynamics (user_id, content, is_system_post, created_at) VALUES (?,?,?,?)',
      [req.userId, content, 0, now()])
    res.status(201).json({ ok: true })
  })

  return router
}
