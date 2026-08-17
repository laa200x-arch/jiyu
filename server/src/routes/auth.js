/**
 * 认证路由：注册（手机验证可选）/ 登录 / 我的资料 / 忘记密码
 */
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { signToken, requireAuth, serializeUser } from '../middleware.js'
import { sendSms, SMS_OPTIONS } from '../sms.js'

const isValidPhone = (p) => /^1[3-9]\d{9}$/.test(String(p || '').trim())

// 登录防爆破限流（内存）：同一 用户名+IP 连续失败 5 次 → 锁定 15 分钟
const LOGIN_MAX_ATTEMPTS = 5
const LOGIN_LOCK_MS = 15 * 60 * 1000
const loginAttempts = new Map()
function checkLoginLock(username, ip) {
  const key = `${String(username).toLowerCase()}:${ip}`
  const rec = loginAttempts.get(key)
  const nowT = Date.now()
  if (rec && rec.lockUntil && rec.lockUntil > nowT) {
    return { locked: true, remainSec: Math.ceil((rec.lockUntil - nowT) / 1000), key }
  }
  if (rec && rec.lockUntil && rec.lockUntil <= nowT) loginAttempts.delete(key)
  return { locked: false, key }
}
function recordLoginFailure(key) {
  const nowT = Date.now()
  const rec = loginAttempts.get(key) || { count: 0, lockUntil: 0 }
  rec.count += 1
  if (rec.count >= LOGIN_MAX_ATTEMPTS) {
    rec.lockUntil = nowT + LOGIN_LOCK_MS
    rec.count = 0
  }
  loginAttempts.set(key, rec)
  return rec
}
function clearLoginFailures(key) {
  loginAttempts.delete(key)
}

export function authRouter(db) {
  const router = Router()
  const now = () => new Date().toISOString()

  function userWithSkills(id, includePhone = false) {
    const row = db.get('SELECT * FROM users WHERE id = ?', [id])
    if (!row) return null
    const skills = db.all('SELECT * FROM skills WHERE user_id = ?', [id])
    return serializeUser(row, { skills, includePhone })
  }

  /** 生成并落库验证码（发送前调用；返回 code 供 sendSms 使用） */
  function issueCode(phone, purpose) {
    const code = String(Math.floor(100000 + Math.random() * 900000))
    const expiresAt = new Date(Date.now() + SMS_OPTIONS.codeTtlMs).toISOString()
    db.run('DELETE FROM phone_codes WHERE phone = ?', [phone])
    db.run(
      'INSERT INTO phone_codes (phone, code, purpose, used, attempts, expires_at, created_at) VALUES (?,?,?,?,?,?,?)',
      [phone, code, purpose, 0, 0, expiresAt, now()]
    )
    return code
  }

  /** 发送验证码通用实现（注册 / 忘记密码共用限频） */
  function sendCode(req, res, { purpose, mustExist }) {
    const { phone } = req.body || {}
    const phoneTrim = String(phone || '').trim()
    if (!isValidPhone(phoneTrim)) return res.status(400).json({ error: '手机号格式不正确（11 位大陆手机号）' })
    const user = db.get('SELECT id FROM users WHERE phone = ?', [phoneTrim])
    if (mustExist && !user) return res.status(404).json({ error: '该手机号未注册账号，无法找回密码' })
    if (!mustExist && user) return res.status(409).json({ error: '该手机号已注册账号，请直接登录或换一个手机号' })
    const recent = db.get('SELECT * FROM phone_codes WHERE phone = ? ORDER BY id DESC LIMIT 1', [phoneTrim])
    if (recent && Date.now() - new Date(recent.created_at).getTime() < SMS_OPTIONS.resendIntervalMs) {
      return res.status(429).json({ error: '发送过于频繁，请 60 秒后再试' })
    }
    const code = issueCode(phoneTrim, purpose)
    sendSms(phoneTrim, code).then((r) => {
      if (!r.ok) {
        db.run('DELETE FROM phone_codes WHERE phone = ?', [phoneTrim])
        return res.status(502).json({ error: '短信发送失败，请稍后重试' })
      }
      res.status(201).json({ ok: true, message: '验证码已发送（5 分钟内有效）', ...(r.devCode ? { devCode: r.devCode } : {}) })
    })
  }

  // 发送注册验证码（每个手机号仅可注册一个账号；注册手机号为选填）
  router.post('/phone/send-code', (req, res) => {
    sendCode(req, res, { purpose: 'register', mustExist: false })
  })

  // 忘记密码：向已注册手机号发送重置验证码
  router.post('/phone/forgot-code', (req, res) => {
    sendCode(req, res, { purpose: 'reset', mustExist: true })
  })

  /** 验证码校验（注册/重置共用）：通过则标记已用 */
  function verifyCode(phone, code, purpose) {
    const record = db.get('SELECT * FROM phone_codes WHERE phone = ? ORDER BY id DESC LIMIT 1', [phone])
    if (!record || record.purpose !== purpose) return { error: '请先获取手机验证码' }
    if (record.used) return { error: '验证码已使用，请重新获取' }
    if (new Date(record.expires_at).getTime() < Date.now()) return { error: '验证码已过期，请重新获取' }
    if (record.code !== String(code || '').trim()) {
      db.run('UPDATE phone_codes SET attempts = attempts + 1 WHERE id = ?', [record.id])
      if (record.attempts + 1 >= SMS_OPTIONS.maxAttempts) {
        db.run('UPDATE phone_codes SET used = 1 WHERE id = ?', [record.id])
        return { error: '验证码错误次数过多，请重新获取' }
      }
      return { error: '验证码错误' }
    }
    db.run('UPDATE phone_codes SET used = 1 WHERE id = ?', [record.id])
    return { ok: true }
  }

  // 重置密码（忘记密码：手机号 + 验证码 + 新密码）
  router.post('/reset-password', async (req, res) => {
    const { phone, code, newPassword } = req.body || {}
    const phoneTrim = String(phone || '').trim()
    if (!isValidPhone(phoneTrim)) return res.status(400).json({ error: '手机号格式不正确（11 位大陆手机号）' })
    if (!newPassword || String(newPassword).length < 6) {
      return res.status(400).json({ error: '新密码至少 6 位' })
    }
    const user = db.get('SELECT id FROM users WHERE phone = ?', [phoneTrim])
    if (!user) return res.status(404).json({ error: '该手机号未注册账号' })
    const check = verifyCode(phoneTrim, code, 'reset')
    if (check.error) return res.status(400).json({ error: check.error })
    const hash = await bcrypt.hash(String(newPassword), 10)
    db.run('UPDATE users SET password_hash = ? WHERE id = ?', [hash, user.id])
    res.json({ ok: true, message: '密码已重置，请使用新密码登录' })
  })

  // 注册（手机验证可选：不填手机号直接注册；填写手机号则强制校验「一手机号一号 + 验证码」）
  router.post('/register', async (req, res) => {
    const { username, password, nickname, avatarSymbol = 'person.fill', phone, code } = req.body || {}
    if (!username || !password || !nickname) {
      return res.status(400).json({ error: 'username/password/nickname 必填' })
    }
    if (String(username).length < 3 || String(password).length < 6) {
      return res.status(400).json({ error: '用户名至少 3 位，密码至少 6 位' })
    }
    const phoneTrim = String(phone || '').trim()
    if (phoneTrim) {
      if (!isValidPhone(phoneTrim)) return res.status(400).json({ error: '手机号格式不正确（11 位大陆手机号）' })
      const exists = db.get('SELECT id FROM users WHERE phone = ?', [phoneTrim])
      if (exists) return res.status(409).json({ error: '该手机号已注册账号（每个手机号仅可注册一个账号）' })
      const check = verifyCode(phoneTrim, code, 'register')
      if (check.error) return res.status(400).json({ error: check.error })
    }

    const usernameExists = db.get('SELECT id FROM users WHERE username = ?', [username])
    if (usernameExists) return res.status(409).json({ error: '用户名已存在' })

    const hash = await bcrypt.hash(String(password), 10)
    const r = db.run(
      `INSERT INTO users (username, password_hash, nickname, avatar_symbol, phone, created_at)
       VALUES (?,?,?,?,?,?)`,
      [username, hash, nickname, avatarSymbol, phoneTrim || null, now()]
    )
    const user = userWithSkills(r.lastInsertRowid, true)
    res.status(201).json({ token: signToken(r.lastInsertRowid), user })
  })

  // 登录（防爆破限流：连续失败 5 次锁定 15 分钟）
  router.post('/login', async (req, res) => {
    const { username, password } = req.body || {}
    const ip = req.ip || req.socket?.remoteAddress || 'unknown'
    const lock = checkLoginLock(String(username || ''), ip)
    if (lock.locked) {
      return res.status(429).json({ error: `尝试次数过多，请 ${lock.remainSec} 秒后再试` })
    }
    const row = db.get('SELECT * FROM users WHERE username = ?', [username])
    if (!row) {
      recordLoginFailure(lock.key)
      return res.status(401).json({ error: '用户名或密码错误' })
    }
    const ok = await bcrypt.compare(String(password || ''), row.password_hash)
    if (!ok) {
      const rec = recordLoginFailure(lock.key)
      if (rec.lockUntil) {
        return res.status(429).json({ error: '登录失败次数过多，账号已锁定 15 分钟' })
      }
      return res.status(401).json({ error: '用户名或密码错误' })
    }
    clearLoginFailures(lock.key)
    res.json({ token: signToken(row.id), user: userWithSkills(row.id, true) })
  })

  // 我的资料
  router.get('/me', requireAuth, (req, res) => {
    res.json({ user: userWithSkills(req.userId, true) })
  })

  return router
}
