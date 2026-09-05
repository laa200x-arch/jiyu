/**
 * 接口限流（express-rate-limit，成熟项目标配）
 * 全局限流兜底 + 敏感接口单独收紧（防爆破 / 防刷短信 / 防刷消息 / 防刷上传）
 * 默认按 req.ip 统计（当前为无反向代理直连部署；若置于 nginx 后需配置 app.set('trust proxy')）
 */
import rateLimit from 'express-rate-limit'

// 测试/压测开关：RATE_LIMIT_OFF=1 时全部放行（e2e 用临时服务器可重复执行，不因 IP 配额误伤）
const off = process.env.RATE_LIMIT_OFF === '1'

const make = ({ windowMs, limit, message }) => off
  ? (req, res, next) => next()
  : rateLimit({
      windowMs,
      limit,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      handler: (req, res) => res.status(429).json({ error: message || '操作过于频繁，请稍后再试' })
    })

/** 全局兜底：每 IP 每分钟 300 次（健康检查不计入） */
export const globalLimiter = off
  ? (req, res, next) => next()
  : rateLimit({
      windowMs: 60_000,
      limit: 300,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      skip: (req) => req.path === '/api/health',
      handler: (req, res) => res.status(429).json({ error: '操作过于频繁，请稍后再试' })
    })

/** 登录：每 IP 每分钟 10 次（叠加应用层「用户名+IP 连续失败锁定」） */
export const loginLimiter = make({ windowMs: 60_000, limit: 10, message: '登录尝试过于频繁，请 1 分钟后再试' })

/** 短信验证码：每 IP 每分钟 5 次（叠加应用层「单手机号 60 秒限频」） */
export const smsLimiter = make({ windowMs: 60_000, limit: 5, message: '验证码发送过于频繁，请稍后再试' })

/** 发消息（REST 兜底）：每 IP 每分钟 90 次（Socket 通道在 socket.js 单独限流） */
export const messageLimiter = make({ windowMs: 60_000, limit: 90, message: '消息发送过于频繁，请稍后再试' })

/** 上传：每 IP 每分钟 30 次 */
export const uploadLimiter = make({ windowMs: 60_000, limit: 30, message: '上传过于频繁，请稍后再试' })
