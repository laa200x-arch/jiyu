/**
 * 认证路由：注册 / 登录 / 我的资料
 */
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { signToken, requireAuth, serializeUser } from '../middleware.js'

export function authRouter(db) {
  const router = Router()
  const now = () => new Date().toISOString()

  function userWithSkills(id) {
    const row = db.get('SELECT * FROM users WHERE id = ?', [id])
    if (!row) return null
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [id])
    return serializeUser(row, { skills })
  }

  // 注册
  router.post('/register', async (req, res) => {
    const { username, password, nickname, avatarSymbol = 'person.fill' } = req.body || {}
    if (!username || !password || !nickname) {
      return res.status(400).json({ error: 'username/password/nickname 必填' })
    }
    if (String(username).length < 3 || String(password).length < 6) {
      return res.status(400).json({ error: '用户名至少 3 位，密码至少 6 位' })
    }
    const exists = db.get('SELECT id FROM users WHERE username = ?', [username])
    if (exists) return res.status(409).json({ error: '用户名已存在' })

    const hash = await bcrypt.hash(String(password), 10)
    const r = db.run(
      `INSERT INTO users (username, password_hash, nickname, avatar_symbol, created_at)
       VALUES (?,?,?,?,?)`,
      [username, hash, nickname, avatarSymbol, now()]
    )
    const user = userWithSkills(r.lastInsertRowid)
    res.status(201).json({ token: signToken(r.lastInsertRowid), user })
  })

  // 登录
  router.post('/login', async (req, res) => {
    const { username, password } = req.body || {}
    const row = db.get('SELECT * FROM users WHERE username = ?', [username])
    if (!row) return res.status(401).json({ error: '用户名或密码错误' })
    const ok = await bcrypt.compare(String(password || ''), row.password_hash)
    if (!ok) return res.status(401).json({ error: '用户名或密码错误' })
    res.json({ token: signToken(row.id), user: userWithSkills(row.id) })
  })

  // 我的资料
  router.get('/me', requireAuth, (req, res) => {
    res.json({ user: userWithSkills(req.userId) })
  })

  return router
}
