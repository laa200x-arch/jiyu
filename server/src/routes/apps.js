/**
 * 小程序市场路由（消息页下拉进入）
 * - 格式：单个自包含 HTML 文件（内联 CSS/JS，无外部依赖/网络请求，≤ 5MB）
 * - 发布：登录用户上传 name + description + htmlContent
 * - 浏览：列表（关键字搜索）+ 详情（htmlContent 供沙箱运行）
 * - 排行：小程序内通过 postMessage 上报分数，宿主调用排行榜 API（top 20）
 */
import { Router } from 'express'
import { requireAuth } from '../middleware.js'
import { checkTextRisk } from '../risk.js'

const MAX_APP_KB = 5 * 1024 // 小程序 HTML 上限（5MB）

export function appsRouter(db) {
  const router = Router()
  router.use(requireAuth)
  const now = () => new Date().toISOString()

  const serializeApp = (row, { withContent = false } = {}) => {
    const app = {
      id: String(row.id),
      userId: String(row.user_id),
      authorName: row.author_name,
      authorAvatar: row.author_avatar || null,
      name: row.name,
      description: row.description,
      icon: row.icon || '🎮',
      version: row.version,
      sizeKb: row.size_kb,
      downloads: row.downloads,
      createdAt: row.created_at
    }
    if (withContent) app.htmlContent = row.html_content
    return app
  }

  // 小程序列表（?keyword= 按名称/描述/作者搜索）
  router.get('/apps', (req, res) => {
    const keyword = String(req.query.keyword || '').trim()
    const rows = keyword
      ? db.all(
          `SELECT a.*, u.nickname AS author_name, u.avatar_url AS author_avatar
           FROM apps a JOIN users u ON u.id = a.user_id
           WHERE a.name LIKE ? OR a.description LIKE ? OR u.nickname LIKE ?
           ORDER BY a.id DESC LIMIT 100`,
          [`%${keyword}%`, `%${keyword}%`, `%${keyword}%`]
        )
      : db.all(
          `SELECT a.*, u.nickname AS author_name, u.avatar_url AS author_avatar
           FROM apps a JOIN users u ON u.id = a.user_id
           ORDER BY a.id DESC LIMIT 100`
        )
    res.json({ apps: rows.map((row) => serializeApp(row)) })
  })

  // 小程序详情（含 htmlContent，客户端沙箱运行）
  router.get('/apps/:id', (req, res) => {
    const row = db.get(
      `SELECT a.*, u.nickname AS author_name, u.avatar_url AS author_avatar
       FROM apps a JOIN users u ON u.id = a.user_id WHERE a.id = ?`,
      [req.params.id]
    )
    if (!row) return res.status(404).json({ error: '小程序不存在' })
    db.run('UPDATE apps SET downloads = downloads + 1 WHERE id = ?', [row.id])
    res.json({ app: serializeApp(row, { withContent: true }) })
  })

  // 发布小程序（格式：单文件自包含 HTML）
  router.post('/apps', (req, res) => {
    const { name, description = '', icon = '🎮', htmlContent } = req.body || {}
    const nameTrim = String(name || '').trim()
    const html = String(htmlContent || '').trim()
    if (!nameTrim) return res.status(400).json({ error: '小程序名称必填' })
    if (nameTrim.length > 30) return res.status(400).json({ error: '名称不能超过 30 字' })
    if (!html) return res.status(400).json({ error: '请上传小程序 HTML 文件内容' })
    const sizeKb = Math.ceil(Buffer.byteLength(html, 'utf8') / 1024)
    if (sizeKb > MAX_APP_KB) {
      return res.status(400).json({ error: `小程序不能超过 ${MAX_APP_KB}KB（当前 ${sizeKb}KB），请精简后重试` })
    }
    // 自包含校验：禁止外部脚本/样式/网络请求（安全沙箱运行）
    if (/<script[^>]*\bsrc\s*=/i.test(html) || /<link\b/i.test(html) || /<iframe\b/i.test(html)) {
      return res.status(400).json({ error: '小程序必须为单文件自包含：禁止外链脚本/样式/内嵌 iframe' })
    }
    const risk = checkTextRisk(nameTrim + ' ' + description)
    if (risk.isIllegal) return res.status(403).json({ error: risk.warning, matchedWords: risk.matchedWords })

    const r = db.run(
      `INSERT INTO apps (user_id, name, description, icon, html_content, version, size_kb, downloads, created_at)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [req.userId, nameTrim, String(description || '').trim().slice(0, 200), icon.slice(0, 8),
        html, '1.0.0', sizeKb, 0, now()]
    )
    const row = db.get(
      `SELECT a.*, u.nickname AS author_name, u.avatar_url AS author_avatar
       FROM apps a JOIN users u ON u.id = a.user_id WHERE a.id = ?`,
      [r.lastInsertRowid]
    )
    res.status(201).json({ app: serializeApp(row) })
  })

  // 删除自己的小程序
  router.delete('/apps/:id', (req, res) => {
    const r = db.run('DELETE FROM apps WHERE id = ? AND user_id = ?', [req.params.id, req.userId])
    if (r.changes === 0) return res.status(404).json({ error: '小程序不存在或无权删除' })
    res.json({ ok: true })
  })

  // 提交分数（小程序内 postMessage → 宿主调用；仅保留个人最高分）
  router.post('/apps/:id/score', (req, res) => {
    const app = db.get('SELECT id FROM apps WHERE id = ?', [req.params.id])
    if (!app) return res.status(404).json({ error: '小程序不存在' })
    const score = Number(req.body?.score)
    const playerName = String(req.body?.playerName || '').trim().slice(0, 20) || '匿名'
    if (!Number.isFinite(score) || score < 0 || score > 999999999) {
      return res.status(400).json({ error: '分数不合法' })
    }
    const risk = checkTextRisk(playerName)
    if (risk.isIllegal) return res.status(403).json({ error: risk.warning })
    // 同用户同小程序只保留最高分（未登录按 playerName 去重）
    const key = req.userId ? `user:${req.userId}` : `name:${playerName}`
    const existing = db.get('SELECT * FROM app_scores WHERE app_id = ? AND player_name = ?', [app.id, playerName])
    if (existing) {
      if (score > existing.score) {
        db.run('UPDATE app_scores SET score = ?, created_at = ? WHERE id = ?', [score, now(), existing.id])
      }
    } else {
      db.run(
        'INSERT INTO app_scores (app_id, user_id, player_name, score, created_at) VALUES (?,?,?,?,?)',
        [app.id, req.userId || null, playerName, score, now()]
      )
    }
    res.json({ ok: true })
  })

  // 排行榜（top 20）
  router.get('/apps/:id/scores', (req, res) => {
    const app = db.get('SELECT id FROM apps WHERE id = ?', [req.params.id])
    if (!app) return res.status(404).json({ error: '小程序不存在' })
    const rows = db.all(
      'SELECT player_name, score, created_at FROM app_scores WHERE app_id = ? ORDER BY score DESC, id ASC LIMIT 20',
      [app.id]
    )
    res.json({
      scores: rows.map((row, i) => ({
        rank: i + 1,
        playerName: row.player_name,
        score: row.score,
        createdAt: row.created_at
      }))
    })
  })

  return router
}
