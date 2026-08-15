import Foundation

/// 官方标准化互换协议（方案 5.4：平台内置、签署后具备平台约束效力）
struct ExchangeAgreement: Codable, Identifiable, Hashable {
    let id: UUID
    let partnerID: UUID
    let partnerName: String
    let mySkillName: String
    let learnSkillName: String
    let exchangeType: ExchangeType
    let scheduledTime: String
    let location: String?
    let content: String
    let signedAt: Date
}

/// 互换进度状态
enum ExchangeStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "待开始"
    case ongoing = "进行中"
    case completed = "已完成"
    case cancelled = "已取消"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .ongoing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

/// 互换记录（协议签署后生成）
struct ExchangeRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let partner: UserModel
    let mySkillName: String
    let learnSkillName: String
    let exchangeType: ExchangeType
    let scheduledTime: String
    let location: String?
    var status: ExchangeStatus
    var evaluateGiven: Bool
    let createdAt: Date
}
