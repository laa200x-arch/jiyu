import Foundation

/// 信用评价 & 信用分计算体系（方案 2.3.5 / 5.5）
/// - 互换结束双向互评：教学认真度 / 守时度 / 沟通体验 / 技能实用性
/// - 信用分 0-100，影响匹配优先级与曝光权重
/// - 差评/投诉可申诉，平台人工审核
class CreditScoreManager {
    static let shared = CreditScoreManager()

    /// 初始基础分
    private let initialScore = 80.0

    /// 综合信用分（0-100）：三维度均值 × 20（方案 5.5）
    func calculateCreditScore(evaluateList: [EvaluateModel]) -> Double {
        guard !evaluateList.isEmpty else { return initialScore }

        var totalScore: Double = 0
        for item in evaluateList {
            let avg = (item.punctuality + item.serious + item.communication) / 3
            totalScore += avg
        }
        let finalScore = (totalScore / Double(evaluateList.count)) * 20
        return min(max(finalScore, 0), 100)
    }

    /// 违规扣分（方案 5.5）
    func deductScore(currentScore: Double, deduct: Double = 10) -> Double {
        max(currentScore - deduct, 0)
    }

    /// 信用等级（用于榜单与徽章）
    func creditLevel(for score: Double) -> String {
        switch score {
        case 90...100: return "S"
        case 80..<90: return "A"
        case 70..<80: return "B"
        default: return "C"
        }
    }
}
