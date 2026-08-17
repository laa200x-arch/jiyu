/**
 * 零金钱交易风控模块（方案 2.3.6）
 * - 内置关键词风控：聊天/动态/个人主页文本前置拦截
 * - 可插拔 AI 审核：配置百度 AI API Key 后启用图像/增强文本审核
 * - 处罚阶梯：首次警告 → 二次限流 → 三次封禁
 */

// 违禁交易关键词库（与 iOS 端保持一致，并追加常见变体）
export const FORBIDDEN_WORDS = [
  '收费', '付费', '转账', '红包', '接单', '有偿', '多少钱', '价格',
  '交易', '购买', '出售', '收款', '支付宝', '微信收款', '打钱',
  '付款', '付钱', '定金', '尾款', '佣金', '刷单', '代购', '卖课',
  '赚钱', '利润', '提现', '充值', '红包码', '收款码', '卖艺', '卖技能'
]

/**
 * 宠物护理订单协商词（结构化收费业务，允许在订单相关私聊中出现）
 * 仅放行「协商服务」所需的最小词集；转账/红包/收款码等真实金钱交易词仍严格拦截
 */
export const PET_ORDER_ALLOWED_WORDS = ['接单', '价格', '多少钱', '收费', '付费', '佣金']

export function checkTextRisk(text = '', { allowPetOrderWords = false } = {}) {
  const words = allowPetOrderWords
    ? FORBIDDEN_WORDS.filter((w) => !PET_ORDER_ALLOWED_WORDS.includes(w))
    : FORBIDDEN_WORDS
  const matched = words.filter((w) => text.includes(w))
  if (matched.length === 0) {
    return { isIllegal: false, matchedWords: [], warning: '内容合规' }
  }
  return {
    isIllegal: true,
    matchedWords: matched,
    warning: allowPetOrderWords
      ? `宠物订单协商仅允许讨论服务安排；仍严禁转账/红包/收款码等线下金钱交易。命中词：${matched.join('、')}`
      : `平台严禁任何金钱交易，仅支持纯技能无偿互换。命中词：${matched.join('、')}`
  }
}

/**
 * 百度 AI 内容审核（图片为主）。未配置 API Key 时返回合规（占位）。
 * 生产接入：调用百度内容审核接口，识别转账截图/价格海报/付费二维码。
 */
export async function checkImageRisk(imageUrl) {
  // TODO(生产): 接入百度 AI 内容审核 SDK（access_token + image audit API）
  return { isIllegal: false, matchedWords: [], warning: '图片合规' }
}

/**
 * 违规处罚等级（方案 2.3.6：首次警告/二次限流/三次封禁）
 */
export function penaltyLevelFor(violationCount) {
  if (violationCount <= 0) return 'none'
  if (violationCount === 1) return 'warned'
  if (violationCount === 2) return 'limited'
  return 'banned'
}
