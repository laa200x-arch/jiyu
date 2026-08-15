import Foundation

/// 标准化交换协议模板 + 签署逻辑（方案 2.3.4 / 5.4）
/// 平台内置官方免费协议，互换前双方必须确认签署；
/// 无法律效力，但具备平台约束效力（扣分、限流、封禁）。
class AgreementManager {
    static let shared = AgreementManager()

    /// 官方标准化无交易互换协议
    static let agreementTemplate = """
    【技遇平台官方技能互换协议】
    1. 本次技能互换为纯个人兴趣无偿交换，双方确认无任何金钱、物资、有偿交易行为。
    2. 双方自愿交换技能教学资源，约定教学时长、教学时间、线上/线下方式。
    3. 双方承诺认真教学、守时履约，杜绝敷衍教学、无故爽约。
    4. 线下交换请选择公共场所，注意人身与财产安全，平台仅提供信息匹配服务。
    5. 若任意一方出现交易违规、爽约、敷衍行为，平台有权扣分、限流、封禁账号。
    6. 本协议为平台约束性规则，双方确认签署即认可全部条款。
    """

    /// 生成带双方约定信息的协议
    func buildAgreement(
        partnerID: UUID,
        partnerName: String,
        mySkillName: String,
        learnSkillName: String,
        exchangeType: ExchangeType,
        scheduledTime: String,
        location: String?
    ) -> ExchangeAgreement {
        let locationLine = location.map { "· 线下地点：\($0)" }
            ?? "· 线上教学：平台内 IM / 屏幕共享完成"
        let content = AgreementManager.agreementTemplate + """

        本次互换约定：
        · 互换内容：\(mySkillName) ↔ \(learnSkillName)
        · 交换方式：\(exchangeType.rawValue)
        · 约定时间：\(scheduledTime)
        \(locationLine)
        """
        return ExchangeAgreement(
            id: UUID(),
            partnerID: partnerID,
            partnerName: partnerName,
            mySkillName: mySkillName,
            learnSkillName: learnSkillName,
            exchangeType: exchangeType,
            scheduledTime: scheduledTime,
            location: location,
            content: content,
            signedAt: Date()
        )
    }

    /// 发起互换前置校验（方案 5.4）：必须先签署协议
    func canStartExchange(agreement: ExchangeAgreement?) -> Bool {
        agreement != nil
    }
}
