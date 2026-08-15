import Foundation

/// 风控检测结果
struct RiskCheckResult {
    let isIllegal: Bool
    let matchedWords: [String]
    let warning: String
}

/// 违规处罚等级（方案 2.3.6：首次警告 / 二次限流 / 三次封禁）
enum PenaltyLevel: String {
    case none = "正常"
    case warned = "首次警告"
    case limited = "二次限流"
    case banned = "三次封禁"
}

/// 零金钱交易风控体系（方案 2.3.6，核心壁垒）
/// - 文本 AI 风控：拦截收费/付费/转账/红包/接单/有偿等关键词
/// - 图片风控：识别转账截图、价格海报、付费二维码（正式版接入百度 AI 审核 SDK）
/// - 违规处罚：首次警告 → 二次限流 → 三次永久封禁
class TradeRiskControlManager {
    static let shared = TradeRiskControlManager()

    /// 违禁交易关键词库（含常见变体）
    private let forbiddenWords: [String] = [
        "收费", "付费", "转账", "红包", "接单", "有偿", "多少钱", "价格",
        "交易", "购买", "出售", "收款", "支付宝", "微信收款", "打钱",
        "付款", "付钱", "定金", "尾款", "佣金", "刷单", "代购", "卖课",
        "赚钱", "利润", "提现", "充值", "红包码", "收款码", "卖艺", "卖技能"
    ]

    /// 文本风控检测（方案 5.3）
    func checkTextRisk(text: String) -> RiskCheckResult {
        let matched = forbiddenWords.filter { text.localizedCaseInsensitiveContains($0) }
        if matched.isEmpty {
            return RiskCheckResult(isIllegal: false, matchedWords: [], warning: "内容合规")
        }
        return RiskCheckResult(
            isIllegal: true,
            matchedWords: matched,
            warning: "平台严禁任何金钱交易，仅支持纯技能无偿互换。命中词：\(matched.joined(separator: "、"))"
        )
    }

    /// 聊天消息前置拦截（方案 5.3）：违规返回 nil，消息不发
    func filterChatMessage(originalText: String) -> String? {
        let result = checkTextRisk(text: originalText)
        return result.isIllegal ? nil : originalText
    }

    /// 个人主页 / 动态文本检测：自动屏蔽「收费、接单」等词汇
    func checkProfileText(text: String) -> RiskCheckResult {
        checkTextRisk(text: text)
    }

    /// 图片风控占位：识别转账截图 / 价格海报 / 付费二维码
    /// 正式版：接入百度 AI 内容审核 SDK（图像审核接口），此处仅返回是否合规
    func checkImageRisk(imageIdentifier: String) -> Bool {
        // TODO(生产): 调用 BaiduAIContentModeration.checkImage(imageIdentifier)
        false // 占位：默认合规
    }

    /// 违规次数 → 处罚等级
    func penaltyLevel(for violationCount: Int) -> PenaltyLevel {
        switch violationCount {
        case 0: return .none
        case 1: return .warned
        case 2: return .limited
        default: return .banned
        }
    }
}
