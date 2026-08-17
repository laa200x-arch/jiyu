/**
 * 短信发送模块（可插拔，零第三方 SDK 依赖）
 * - console ：测试通道（仅打印日志并返回 devCode，用于本地联调）
 * - aliyun  ：阿里云短信（真实发送到国内手机号，RPC 签名 v1.0）
 * - tencent ：腾讯云短信（真实发送到国内手机号，TC3-HMAC-SHA256 签名）
 *
 * 环境变量：
 *   SMS_PROVIDER             = console | aliyun | tencent（默认 console）
 *   SMS_DEV_FALLBACK         = 1 | 0（真实通道发送失败时是否降级返回 devCode，默认 1；
 *                             测试期不阻断注册；【生产必须置 0】，否则验证码会泄漏给客户端）
 *
 *   阿里云（SMS_PROVIDER=aliyun）：
 *     ALIYUN_ACCESS_KEY_ID       阿里云 AccessKey ID
 *     ALIYUN_ACCESS_KEY_SECRET   阿里云 AccessKey Secret
 *     ALIYUN_SMS_SIGN_NAME       短信签名（需在阿里云短信控制台审核通过）
 *     ALIYUN_SMS_TEMPLATE_CODE   短信模板 Code（模板须含 ${code} 变量）
 *
 *   腾讯云（SMS_PROVIDER=tencent）：
 *     TENCENT_SECRET_ID          腾讯云 SecretId
 *     TENCENT_SECRET_KEY         腾讯云 SecretKey
 *     TENCENT_SMS_SDK_APP_ID     短信应用 SmsSdkAppId（短信控制台创建应用后获得）
 *     TENCENT_SMS_SIGN_NAME      短信签名（需审核通过）
 *     TENCENT_SMS_TEMPLATE_ID    短信模板 ID（模板正文须含 {1} 占位符）
 *     TENCENT_SMS_REGION         地域（可选，默认 ap-guangzhou）
 */
import crypto from 'node:crypto'

/** 当前短信通道（惰性读取，便于测试时切换环境变量） */
export function smsProvider() {
  return process.env.SMS_PROVIDER || 'console'
}

/** 真实通道发送失败时是否降级返回 devCode（生产必须置 0） */
export function smsDevFallback() {
  return (process.env.SMS_DEV_FALLBACK ?? '1') !== '0'
}

/** 生成 6 位验证码 */
export function genCode(length = 6) {
  return String(Math.floor(Math.pow(10, length - 1) + Math.random() * 9 * Math.pow(10, length - 1)))
}

/**
 * 短信通道配置状态（用于健康检查/启动日志）
 * @returns {{provider: string, configured: boolean, devFallback: boolean}}
 */
export function smsStatus() {
  const p = smsProvider()
  let configured = true
  if (p === 'aliyun') {
    configured = Boolean(
      process.env.ALIYUN_ACCESS_KEY_ID &&
        process.env.ALIYUN_ACCESS_KEY_SECRET &&
        process.env.ALIYUN_SMS_SIGN_NAME &&
        process.env.ALIYUN_SMS_TEMPLATE_CODE
    )
  } else if (p === 'tencent') {
    configured = Boolean(
      process.env.TENCENT_SECRET_ID &&
        process.env.TENCENT_SECRET_KEY &&
        process.env.TENCENT_SMS_SDK_APP_ID &&
        process.env.TENCENT_SMS_SIGN_NAME &&
        process.env.TENCENT_SMS_TEMPLATE_ID
    )
  }
  return { provider: p, configured, devFallback: smsDevFallback() }
}

/**
 * 发送验证码短信
 * @returns {Promise<{ok: boolean, devCode?: string, error?: string}>}
 *   - console 通道：ok=true 且附 devCode（测试用）
 *   - 真实通道发送成功：ok=true，不返回 devCode
 *   - 真实通道失败：SMS_DEV_FALLBACK=1 时降级 ok=true + devCode（测试期）；=0 时 ok=false
 */
export async function sendSms(phone, code) {
  const provider = smsProvider()
  if (provider === 'aliyun' || provider === 'tencent') {
    try {
      const ok = provider === 'aliyun' ? await sendAliyunSms(phone, code) : await sendTencentSms(phone, code)
      if (ok) {
        console.log(`[sms] 已通过${provider === 'aliyun' ? '阿里云' : '腾讯云'}短信发送验证码到 ${phone}`)
        return { ok: true }
      }
      const error = `短信发送失败（provider=${provider}）`
      if (smsDevFallback()) {
        console.warn(`[sms] ${error}，SMS_DEV_FALLBACK=1 降级返回 devCode（生产请置 0）`)
        return { ok: true, devCode: code, error }
      }
      console.error(`[sms] ${error}`)
      return { ok: false, error }
    } catch (e) {
      console.error(`[sms] ${provider} 短信发送异常:`, e.message)
      if (smsDevFallback()) return { ok: true, devCode: code, error: e.message }
      return { ok: false, error: e.message }
    }
  }
  // console 测试通道
  console.log(`[sms] 测试通道：验证码 ${code} 已"发送"到 ${phone}（配置 SMS_PROVIDER=aliyun|tencent 接入真实短信）`)
  return { ok: true, devCode: code }
}

/* ================= 阿里云短信（RPC 签名 v1.0） ================= */

function percentEncode(str) {
  return encodeURIComponent(str)
    .replace(/\+/g, '%20')
    .replace(/\*/g, '%2A')
    .replace(/%7E/g, '~')
}

export async function sendAliyunSms(phone, code) {
  const accessKeyId = process.env.ALIYUN_ACCESS_KEY_ID || ''
  const accessKeySecret = process.env.ALIYUN_ACCESS_KEY_SECRET || ''
  const signName = process.env.ALIYUN_SMS_SIGN_NAME || ''
  const templateCode = process.env.ALIYUN_SMS_TEMPLATE_CODE || ''
  if (!accessKeyId || !accessKeySecret || !signName || !templateCode) {
    console.warn('[sms] 阿里云短信未配置完整（AccessKey/签名/模板）')
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

  const res = await fetch(url, { method: 'GET', signal: AbortSignal.timeout(8000) })
  const body = await res.json().catch(() => ({}))
  if (body.Code !== 'OK') {
    console.error('[sms] 阿里云短信返回错误:', JSON.stringify(body))
    return false
  }
  return true
}

/* ================= 腾讯云短信（TC3-HMAC-SHA256 签名） ================= */

function sha256Hex(str) {
  return crypto.createHash('sha256').update(str).digest('hex')
}

function hmacSha256(key, str) {
  return crypto.createHmac('sha256', key).update(str).digest()
}

export async function sendTencentSms(phone, code) {
  const secretId = process.env.TENCENT_SECRET_ID || ''
  const secretKey = process.env.TENCENT_SECRET_KEY || ''
  const sdkAppId = process.env.TENCENT_SMS_SDK_APP_ID || ''
  const signName = process.env.TENCENT_SMS_SIGN_NAME || ''
  const templateId = process.env.TENCENT_SMS_TEMPLATE_ID || ''
  if (!secretId || !secretKey || !sdkAppId || !signName || !templateId) {
    console.warn('[sms] 腾讯云短信未配置完整（SecretId/SecretKey/SdkAppId/签名/模板）')
    return false
  }

  const host = 'sms.tencentcloudapi.com'
  const service = 'sms'
  const region = process.env.TENCENT_SMS_REGION || 'ap-guangzhou'
  const timestamp = Math.floor(Date.now() / 1000)
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10) // UTC 日期 YYYY-MM-DD

  const payload = {
    PhoneNumberSet: [`+86${phone}`],
    SmsSdkAppId: sdkAppId,
    SignName: signName,
    TemplateId: templateId,
    TemplateParamSet: [code]
  }
  const payloadJson = JSON.stringify(payload)

  // 1) 规范请求串
  const canonicalRequest = [
    'POST',
    '/',
    '',
    `content-type:application/json; charset=utf-8\nhost:${host}\n`,
    'content-type;host',
    sha256Hex(payloadJson)
  ].join('\n')

  // 2) 待签名字符串
  const stringToSign = [
    'TC3-HMAC-SHA256',
    String(timestamp),
    `${date}/${service}/tc3_request`,
    sha256Hex(canonicalRequest)
  ].join('\n')

  // 3) 派生密钥并签名
  const secretDate = hmacSha256(`TC3${secretKey}`, date)
  const secretService = hmacSha256(secretDate, service)
  const secretSigning = hmacSha256(secretService, 'tc3_request')
  const signature = crypto.createHmac('sha256', secretSigning).update(stringToSign).digest('hex')

  const authorization =
    `TC3-HMAC-SHA256 Credential=${secretId}/${date}/${service}/tc3_request, ` +
    `SignedHeaders=content-type;host, Signature=${signature}`

  const res = await fetch(`https://${host}/`, {
    method: 'POST',
    headers: {
      Authorization: authorization,
      'Content-Type': 'application/json; charset=utf-8',
      'X-TC-Action': 'SendSms',
      'X-TC-Version': '2021-01-11',
      'X-TC-Timestamp': String(timestamp),
      'X-TC-Region': region
    },
    body: payloadJson,
    signal: AbortSignal.timeout(8000)
  })
  const body = await res.json().catch(() => ({}))
  const sendStatus = body?.Response?.SendStatusSet?.[0]
  if (sendStatus && sendStatus.Code === 'Ok') return true
  console.error('[sms] 腾讯云短信返回错误:', JSON.stringify(body))
  return false
}

export const SMS_OPTIONS = {
  codeLength: 6,
  codeTtlMs: 5 * 60 * 1000,   // 验证码 5 分钟有效
  resendIntervalMs: 60 * 1000, // 同一手机号 60 秒内不可重复发送
  maxAttempts: 5               // 单码最多尝试 5 次
}
