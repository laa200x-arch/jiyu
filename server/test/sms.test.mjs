/**
 * 短信模块单元测试（不依赖服务器，mock fetch 验证请求与签名）
 * 运行：node test/sms.test.mjs（或 npm run test:unit）
 */
import assert from 'node:assert/strict'
import crypto from 'node:crypto'
import {
  genCode,
  smsProvider,
  smsDevFallback,
  smsStatus,
  sendSms,
  sendAliyunSms,
  sendTencentSms
} from '../src/sms.js'

let passed = 0
let failed = 0
function check(name, cond, extra) {
  if (cond) {
    passed++
    console.log(`  ✓ ${name}`)
  } else {
    failed++
    console.error(`  ✗ ${name}${extra ? ' → ' + JSON.stringify(extra) : ''}`)
  }
}

const realFetch = globalThis.fetch

/** 捕获最近一次 fetch 调用的参数 */
function mockFetch(handler) {
  let lastCall = null
  globalThis.fetch = async (url, opts) => {
    lastCall = { url, opts, handler }
    return handler(url, opts)
  }
  return () => lastCall
}

const jsonResponse = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })

const ENV_KEYS = [
  'SMS_PROVIDER', 'SMS_DEV_FALLBACK',
  'ALIYUN_ACCESS_KEY_ID', 'ALIYUN_ACCESS_KEY_SECRET', 'ALIYUN_SMS_SIGN_NAME', 'ALIYUN_SMS_TEMPLATE_CODE',
  'TENCENT_SECRET_ID', 'TENCENT_SECRET_KEY', 'TENCENT_SMS_SDK_APP_ID', 'TENCENT_SMS_SIGN_NAME',
  'TENCENT_SMS_TEMPLATE_ID', 'TENCENT_SMS_REGION'
]
const savedEnv = {}
function saveEnv() {
  for (const k of ENV_KEYS) savedEnv[k] = process.env[k]
}
function resetEnv() {
  for (const k of ENV_KEYS) {
    if (savedEnv[k] === undefined) delete process.env[k]
    else process.env[k] = savedEnv[k]
  }
}
function setEnv(obj) {
  resetEnv()
  for (const [k, v] of Object.entries(obj)) process.env[k] = v
}

/* ---------------- 基础工具 ---------------- */

{
  console.log('\n[1] genCode')
  for (let i = 0; i < 200; i++) {
    const c = genCode()
    if (!/^\d{6}$/.test(c)) {
      check('genCode 恒为 6 位数字', false, c)
      break
    }
  }
  check('genCode 200 次全部为 6 位数字', true)
  const set = new Set(Array.from({ length: 500 }, () => genCode()))
  check('genCode 500 次无重复（随机性）', set.size === 500, { size: set.size })
}

/* ---------------- console 测试通道 ---------------- */

{
  console.log('\n[2] console 测试通道')
  setEnv({ SMS_PROVIDER: 'console', SMS_DEV_FALLBACK: '1' })
  const r = await sendSms('13800138000', '123456')
  check('console 通道 ok=true', r.ok === true)
  check('console 通道返回 devCode', r.devCode === '123456', r)
}

/* ---------------- 阿里云通道 ---------------- */

{
  console.log('\n[3] 阿里云通道（成功路径）')
  setEnv({
    SMS_PROVIDER: 'aliyun',
    SMS_DEV_FALLBACK: '0',
    ALIYUN_ACCESS_KEY_ID: 'test-ak-id',
    ALIYUN_ACCESS_KEY_SECRET: 'test-ak-secret',
    ALIYUN_SMS_SIGN_NAME: '技遇',
    ALIYUN_SMS_TEMPLATE_CODE: 'SMS_123456'
  })
  const getLast = mockFetch(() => jsonResponse({ Code: 'OK', Message: 'OK' }))
  const r = await sendAliyunSms('13800138000', '654321')
  check('发送成功返回 true', r === true)
  const call = getLast()
  check('请求发往 dysmsapi.aliyuncs.com', call.url.startsWith('https://dysmsapi.aliyuncs.com/?'), call.url)
  check('GET 方法', call.opts?.method === 'GET')

  const qs = new URLSearchParams(call.url.split('?')[1])
  check('Action=SendSms', qs.get('Action') === 'SendSms')
  check('Version=2017-05-25', qs.get('Version') === '2017-05-25')
  check('PhoneNumbers 正确', qs.get('PhoneNumbers') === '13800138000')
  check('SignName 正确', decodeURIComponent(qs.get('SignName')) === '技遇')
  check('TemplateCode 正确', qs.get('TemplateCode') === 'SMS_123456')
  const tmpl = JSON.parse(qs.get('TemplateParam'))
  check('TemplateParam 含 code', tmpl.code === '654321', tmpl)
  check('SignatureNonce 存在', Boolean(qs.get('SignatureNonce')))

  // 独立复算签名：验证发出的请求确实携带正确算法算出的签名
  const keys = [...new URLSearchParams(call.url.split('?')[1]).keys()].filter((k) => k !== 'Signature').sort()
  check('参数按 key 排序', keys.join(',') === [...keys].sort().join(','), keys)
  const percentEncode = (s) =>
    encodeURIComponent(s).replace(/\+/g, '%20').replace(/\*/g, '%2A').replace(/%7E/g, '~')
  const canonical = keys
    .map((k) => `${percentEncode(k)}=${percentEncode(qs.get(k))}`)
    .join('&')
  const stringToSign = `GET&${percentEncode('/')}&${percentEncode(canonical)}`
  const expectSig = crypto
    .createHmac('sha1', 'test-ak-secret&')
    .update(stringToSign)
    .digest('base64')
  check('Signature 与独立复算一致', qs.get('Signature') === expectSig, {
    got: qs.get('Signature'),
    want: expectSig
  })
}

{
  console.log('\n[4] 阿里云通道（失败路径 + 降级开关）')
  setEnv({
    SMS_PROVIDER: 'aliyun',
    SMS_DEV_FALLBACK: '0',
    ALIYUN_ACCESS_KEY_ID: 'test-ak-id',
    ALIYUN_ACCESS_KEY_SECRET: 'test-ak-secret',
    ALIYUN_SMS_SIGN_NAME: '技遇',
    ALIYUN_SMS_TEMPLATE_CODE: 'SMS_123456'
  })
  mockFetch(() => jsonResponse({ Code: 'isv.SMS_SIGNATURE_ILLEGAL', Message: '签名不合法' }))
  const r1 = await sendSms('13800138000', '654321')
  check('服务端报错时 ok=false', r1.ok === false, r1)
  check('fallback=0 不返回 devCode', r1.devCode === undefined, r1)
  check('带错误信息', typeof r1.error === 'string' && r1.error.length > 0, r1)

  // fallback=1：降级返回 devCode
  process.env.SMS_DEV_FALLBACK = '1'
  const r2 = await sendSms('13800138000', '654321')
  check('fallback=1 失败时 ok=true', r2.ok === true, r2)
  check('fallback=1 失败时返回 devCode', r2.devCode === '654321', r2)

  // 配置缺失
  delete process.env.ALIYUN_SMS_SIGN_NAME
  mockFetch(() => jsonResponse({ Code: 'OK' }))
  const r3 = await sendSms('13800138000', '654321')
  check('配置缺失 + fallback=1 → 降级返回 devCode', r3.ok === true && r3.devCode === '654321', r3)
  process.env.SMS_DEV_FALLBACK = '0'
  const r4 = await sendSms('13800138000', '654321')
  check('配置缺失 + fallback=0 → ok=false', r4.ok === false, r4)
}

/* ---------------- 腾讯云通道 ---------------- */

{
  console.log('\n[5] 腾讯云通道（成功路径 + TC3 签名）')
  setEnv({
    SMS_PROVIDER: 'tencent',
    SMS_DEV_FALLBACK: '0',
    TENCENT_SECRET_ID: 'test-secret-id',
    TENCENT_SECRET_KEY: 'test-secret-key',
    TENCENT_SMS_SDK_APP_ID: '1400123456',
    TENCENT_SMS_SIGN_NAME: '技遇',
    TENCENT_SMS_TEMPLATE_ID: '1234567',
    TENCENT_SMS_REGION: 'ap-guangzhou'
  })
  const getLast = mockFetch(() =>
    jsonResponse({ Response: { SendStatusSet: [{ Code: 'Ok', PhoneNumber: '+8613800138000' }], RequestId: 'req-1' } })
  )
  const r = await sendTencentSms('13800138000', '654321')
  check('发送成功返回 true', r === true)
  const call = getLast()
  check('请求发往 sms.tencentcloudapi.com', String(call.url).startsWith('https://sms.tencentcloudapi.com/'), call.url)
  check('POST 方法', call.opts?.method === 'POST')

  const headers = call.opts.headers
  check('X-TC-Action=SendSms', headers['X-TC-Action'] === 'SendSms')
  check('X-TC-Version=2021-01-11', headers['X-TC-Version'] === '2021-01-11')
  check('X-TC-Timestamp 为当前秒级时间戳', Math.abs(Number(headers['X-TC-Timestamp']) - Math.floor(Date.now() / 1000)) <= 5)
  check('X-TC-Region=ap-guangzhou', headers['X-TC-Region'] === 'ap-guangzhou')
  check('Content-Type 正确', headers['Content-Type'] === 'application/json; charset=utf-8')

  const auth = headers.Authorization
  check('Authorization 以 TC3-HMAC-SHA256 开头', auth.startsWith('TC3-HMAC-SHA256 '), auth)
  check('Credential 含 SecretId 与日期', /Credential=test-secret-id\/\d{4}-\d{2}-\d{2}\/sms\/tc3_request/.test(auth), auth)
  check('SignedHeaders=content-type;host', auth.includes('SignedHeaders=content-type;host'), auth)
  const sig = auth.match(/Signature=([0-9a-f]{64})/)?.[1]
  check('Signature 为 64 位 hex', Boolean(sig), auth)

  // 独立复算 TC3 签名：从捕获的请求重推 canonical request，验证与发送的签名一致
  const payload = JSON.parse(call.opts.body)
  check('PhoneNumberSet 带 +86 前缀', payload.PhoneNumberSet[0] === '+8613800138000', payload)
  check('SmsSdkAppId 正确', payload.SmsSdkAppId === '1400123456')
  check('SignName 正确', payload.SignName === '技遇')
  check('TemplateId 正确', payload.TemplateId === '1234567')
  check('TemplateParamSet=[code]', JSON.stringify(payload.TemplateParamSet) === JSON.stringify(['654321']), payload)

  const sha256hex = (s) => crypto.createHash('sha256').update(s).digest('hex')
  const hmac = (k, s) => crypto.createHmac('sha256', k).update(s).digest()
  const date = auth.match(/Credential=test-secret-id\/(\d{4}-\d{2}-\d{2})\/sms\/tc3_request/)[1]
  const canonicalRequest = [
    'POST', '/', '',
    'content-type:application/json; charset=utf-8\nhost:sms.tencentcloudapi.com\n',
    'content-type;host',
    sha256hex(JSON.stringify(payload))
  ].join('\n')
  const stringToSign = [
    'TC3-HMAC-SHA256',
    headers['X-TC-Timestamp'],
    `${date}/sms/tc3_request`,
    sha256hex(canonicalRequest)
  ].join('\n')
  const secretDate = hmac('TC3test-secret-key', date)
  const secretService = hmac(secretDate, 'sms')
  const secretSigning = hmac(secretService, 'tc3_request')
  const expectSig = crypto.createHmac('sha256', secretSigning).update(stringToSign).digest('hex')
  check('TC3 签名与独立复算一致', sig === expectSig, { got: sig, want: expectSig })
}

{
  console.log('\n[6] 腾讯云通道（失败路径）')
  setEnv({
    SMS_PROVIDER: 'tencent',
    SMS_DEV_FALLBACK: '0',
    TENCENT_SECRET_ID: 'test-secret-id',
    TENCENT_SECRET_KEY: 'test-secret-key',
    TENCENT_SMS_SDK_APP_ID: '1400123456',
    TENCENT_SMS_SIGN_NAME: '技遇',
    TENCENT_SMS_TEMPLATE_ID: '1234567'
  })
  mockFetch(() => jsonResponse({ Response: { Error: { Code: 'AuthFailure.SignatureFailure', Message: '签名失败' } } }))
  const r1 = await sendSms('13800138000', '654321')
  check('腾讯云报错 → ok=false', r1.ok === false, r1)
  check('fallback=0 不返回 devCode', r1.devCode === undefined, r1)

  // 配置缺失
  delete process.env.TENCENT_SMS_TEMPLATE_ID
  mockFetch(() => jsonResponse({ Response: { SendStatusSet: [{ Code: 'Ok' }] } }))
  const r2 = await sendSms('13800138000', '654321')
  check('配置缺失 + fallback=0 → ok=false（不发请求）', r2.ok === false, r2)
}

/* ---------------- smsStatus / 降级开关 ---------------- */

{
  console.log('\n[7] smsStatus 与降级开关')
  setEnv({ SMS_PROVIDER: 'console' })
  let st = smsStatus()
  check('console: provider=console, configured=true', st.provider === 'console' && st.configured === true, st)

  setEnv({
    SMS_PROVIDER: 'aliyun',
    SMS_DEV_FALLBACK: '0',
    ALIYUN_ACCESS_KEY_ID: 'a', ALIYUN_ACCESS_KEY_SECRET: 'b', ALIYUN_SMS_SIGN_NAME: 'c', ALIYUN_SMS_TEMPLATE_CODE: 'd'
  })
  st = smsStatus()
  check('aliyun 配置完整: configured=true', st.provider === 'aliyun' && st.configured === true && st.devFallback === false, st)

  setEnv({ SMS_PROVIDER: 'aliyun', SMS_DEV_FALLBACK: '0' })
  st = smsStatus()
  check('aliyun 配置缺失: configured=false', st.configured === false, st)

  setEnv({ SMS_PROVIDER: 'tencent', SMS_DEV_FALLBACK: '1' })
  st = smsStatus()
  check('tencent 配置缺失: configured=false, devFallback=true', st.provider === 'tencent' && st.configured === false && st.devFallback === true, st)

  process.env.SMS_DEV_FALLBACK = '0'
  check('smsDevFallback: 显式 0 → false', smsDevFallback() === false)
  delete process.env.SMS_DEV_FALLBACK
  check('smsDevFallback: 未设置 → 默认 true', smsDevFallback() === true)
}

/* ---------------- 收尾 ---------------- */

resetEnv()
globalThis.fetch = realFetch
console.log(`\n══════ 短信单元测试：${passed} 通过 / ${failed} 失败 ══════`)
process.exit(failed > 0 ? 1 : 0)
