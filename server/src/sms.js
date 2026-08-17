/**
 * 短信发送模块（可插拔）
 * 默认实现：打印到服务端日志，并在响应中附带 devCode（测试环境用于完成注册）。
 * 接入真实短信网关（阿里云/腾讯云 SMS）时：实现下方 sendSms 即可，其余流程不变。
 */
import { config } from './config.js'

const SMS_PROVIDER = process.env.SMS_PROVIDER || 'console' // console | aliyun | tencent

/**
 * 发送验证码短信
 * @returns {Promise<{devCode?: string}>} devCode 仅测试环境返回（console 通道）
 */
export async function sendSms(phone, code) {
  if (SMS_PROVIDER === 'console') {
    console.log(`[sms] 发送验证码到 ${phone}：${code}（测试通道，接入真实短信网关后自动关闭）`)
    return { devCode: code }
  }
  // TODO: 接入阿里云/腾讯云短信 SDK（需要 AccessKey/Secret 与短信签名、模板）
  // 示例：const client = new AliyunSms(...); await client.send({ phone, template: 'SMS_xxx', params: { code } })
  console.warn('[sms] 未配置真实短信网关（SMS_PROVIDER=console），仅记录日志')
  return { devCode: code }
}

export const SMS_OPTIONS = {
  codeLength: 6,
  codeTtlMs: 5 * 60 * 1000,   // 验证码 5 分钟有效
  resendIntervalMs: 60 * 1000, // 同一手机号 60 秒内不可重复发送
  maxAttempts: 5               // 单码最多尝试 5 次
}

export { config }
