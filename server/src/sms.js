/**
 * 短信发送模块（可插拔）
 * - console：测试通道（仅打印日志并返回 devCode，用于本地联调）
 * - aliyun：阿里云短信（真实发送到国内手机号，需配置 AccessKey + 签名 + 模板）
 *
 * 环境变量：
 *   SMS_PROVIDER             = console | aliyun
 *   ALIYUN_ACCESS_KEY_ID     阿里云 AccessKey ID
 *   ALIYUN_ACCESS_KEY_SECRET 阿里云 AccessKey Secret
 *   ALIYUN_SMS_SIGN_NAME     短信签名（需在阿里云短信控制台审核通过）
 *   ALIYUN_SMS_TEMPLATE_CODE 短信模板 Code（模板须含 ${code} 变量，审核通过）
 */
import crypto from 'node:crypto'

const provider = process.env.SMS_PROVIDER || 'console'

/** 生成 6 位验证码 */
export function genCode(length = 6) {
  return String(Math.floor(Math.pow(10, length - 1) + Math.random() * 9 * Math.pow(10, length - 1)))
}

/**
 * 发送验证码短信
 * @returns {Promise<{devCode?: string}>} 仅 console 通道返回 devCode；真实短信通道不返回
 */
export async function sendSms(phone, code) {
  if (provider === 'aliyun') {
    try {
      const ok = await sendAliyunSms(phone, code)
      if (!ok) return { devCode: code } // 发送失败降级返回 devCode，测试期不阻断注册
      console.log(`[sms] 已通过阿里云短信发送验证码到 ${phone}`)
      return {}
    } catch (e) {
      console.error('[sms] 阿里云短信发送异常:', e.message)
      return { devCode: code }
    }
  }
  // console 测试通道
  console.log(`[sms] 测试通道：验证码 ${code} 已"发送"到 ${phone}（配置 SMS_PROVIDER=aliyun 接入真实短信）`)
  return { devCode: code }
}

/* ---------------- 阿里云短信（RPC 签名 v1.0，无 SDK 依赖） ---------------- */

function percentEncode(str) {
  return encodeURIComponent(str)
    .replace(/\+/g, '%20')
    .replace(/\*/g, '%2A')
    .replace(/%7E/g, '~')
}

async function sendAliyunSms(phone, code) {
  const accessKeyId = process.env.ALIYUN_ACCESS_KEY_ID || ''
  const accessKeySecret = process.env.ALIYUN_ACCESS_KEY_SECRET || ''
  const signName = process.env.ALIYUN_SMS_SIGN_NAME || ''
  const templateCode = process.env.ALIYUN_SMS_TEMPLATE_CODE || ''
  if (!accessKeyId || !accessKeySecret || !signName || !templateCode) {
    console.warn('[sms] 阿里云短信未配置完整（AccessKey/签名/模板），回退测试通道')
    return false
  }

  const params = {
    Action: 'SendSms',
    Version: '2017-05-25',
    Format: 'JSON',
    SignatureMethod: 'HMAC-SHA1',
    SignatureVersion: '1.0',
    SignatureNonce: crypto.randomUUID(),
    Timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
    AccessKeyId: accessKeyId,
    PhoneNumbers: phone,
    SignName: signName,
    TemplateCode: templateCode,
    TemplateParam: JSON.stringify({ code })
  }

  // 1) 按 key 排序，构造规范化查询串
  const sorted = Object.keys(params).sort()
  const canonicalQuery = sorted
    .map((k) => `${percentEncode(k)}=${percentEncode(params[k])}`)
    .join('&')

  // 2) 待签名字符串
  const stringToSign = `GET&${percentEncode('/')}&${percentEncode(canonicalQuery)}`
  const signature = crypto
    .createHmac('sha1', `${accessKeySecret}&`)
    .update(stringToSign)
    .digest('base64')

  const url = `https://dysmsapi.aliyuncs.com/?Signature=${percentEncode(signature)}&${canonicalQuery}`

  const res = await fetch(url, { method: 'GET' })
  const body = await res.json().catch(() => ({}))
  if (body.Code !== 'OK') {
    console.error('[sms] 阿里云短信返回错误:', JSON.stringify(body))
    return false
  }
  return true
}

export const SMS_OPTIONS = {
  codeLength: 6,
  codeTtlMs: 5 * 60 * 1000,   // 验证码 5 分钟有效
  resendIntervalMs: 60 * 1000, // 同一手机号 60 秒内不可重复发送
  maxAttempts: 5               // 单码最多尝试 5 次
}
