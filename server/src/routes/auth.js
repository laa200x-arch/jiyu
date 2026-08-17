/**
 * 认证路由：注册（手机验证）/ 登录 / 我的资料
 */
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { signToken, requireAuth, serializeUser } from '../middleware.js'
import { sendSms, SMS_OPTIONS } from '../sms.js'

const isValidPhone = (p) => /^1[3-9]\d{9}$/.test(String(p || '').trim())

export function authRouter(db) {
  const router = Router()
  const now = () => new Date().toISOString()

  function userWithSkills(id) {
    const row = db.get('SELECT * FROM users WHERE id = ?', [id])
    if (!row) return null
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [id])
    return serializeUser(row, { skills })
  }

  // 发送注册验证码（每个手机号仅可注册一个账号）
  router.post('/phone/send-code', (req, res) => {
    const { phone, purpose = 'register' } = req.body || {}
    const phoneTrim = String(phone || '').trim()
    if (!isValidPhone(phoneTrim)) return res.status(400).json({ error: '手机号格式不正确（11 位大陆手机号）' })
    const exists = db.get('SELECT id FROM users WHERE phone = ?', [phoneTrim])
    if (exists) return res.status(409).json({ error: '该手机号已注册账号，请直接登录或换一个手机号' })
    const recent = db.get('SELECT * FROM phone_codes WHERE phone = ? ORDER BY id DESC LIMIT 1', [phoneTrim])
    if (recent && Date.now() - new Date(recent.created_at).getTime() < SMS_OPTIONS.resendIntervalMs) {
      return res.status(429).json({ error: '发送过于频繁，请 60 秒后再试' })
    }
    const code = String(Math.floor(100000 + Math.random() * 900000))
    const expiresAt = new Date(Date.now() + SMS_OPTIONS.codeTtlMs).toISOString()
    db.run('DELETE FROM phone_codes WHERE phone = ?', [phoneTrim])
    db.run(
      'INSERT INTO phone_codes (phone, code, purpose, used, attempts, expires_at, created_at) VALUES (?,?,?,?,?,?,?)',
      [phoneTrim, code, purpose, 0, 0, expiresAt, now()]
    )
    sendSms(phoneTrim, code).then((r) => {
      res.status(201).json({ ok: true, message: '验证码已发送（5 分钟内有效）', ...(r.devCode ? { devCode: r.devCode } : {}) })
    })
  })

  // 注册（手机验证：每个手机号仅可注册一个账号）
  router.post('/register', async (req, res) => {
    const { username, password, nickname, avatarSymbol = 'person.fill', phone, code } = req.body || {}
    if (!username || !password || !nickname) {
      return res.status(400).json({ error: 'username/password/nickname 必填' })
    }
    if (String(username).length < 3 || String(password).length < 6) {
      return res.status(400).json({ error: '用户名至少 3 位，密码至少 6 位' })
    }
    const phoneTrim = String(phone || '').trim()
    if (!isValidPhone(phoneTrim)) return res.status(400).json({ error: '请填写手机号（11 位大陆手机号）' })
    const exists = db.get('SELECT id FROM users WHERE phone = ?', [phoneTrim])
    if (exists) return res.status(409).json({ error: '该手机号已注册账号（每个手机号仅可注册一个账号）' })
    // 验证码校验
    const record = db.get('SELECT * FROM phone_codes WHERE phone = ? ORDER BY id DESC LIMIT 1', [phoneTrim])
    if (!record || record.purpose !== 'register') return res.status(400).json({ error: '请先获取手机验证码' })
    if (record.used) return res.status(400).json({ error: '验证码已使用，请重新获取' })
    if (new Date(record.expires_at).getTime() < Date.now()) {
      return res.status(400).json({ error: '验证码已过期，请重新获取' })
    }
    if (record.code !== String(code || '').trim()) {
      db.run('UPDATE phone_codes SET attempts = attempts + 1 WHERE id = ?', [record.id])
      if (record.attempts + 1 >= SMS_OPTIONS.maxAttempts) {
        db.run('UPDATE phone_codes SET used = 1 WHERE id = ?', [record.id])
        return res.status(400).json({ error: '验证码错误次数过多，请重新获取' })
      }
      return res.status(400).json({ error: '验证码错误' })
    }
    db.run('UPDATE phone_codes SET used = 1 WHERE id = ?', [record.id])

    const usernameExists = db.get('SELECT id FROM users WHERE username = ?', [username])
    if (usernameExists) return res.status(409).json({ error: '用户名已存在' })

    const hash = await bcrypt.hash(String(password), 10)
    const r = db.run(
      `INSERT INTO users (username, password_hash, nickname, avatar_symbol, phone, created_at)
       VALUES (?,?,?,?,?,?)`,
      [username, hash, nickname, avatarSymbol, phoneTrim, now()]
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
