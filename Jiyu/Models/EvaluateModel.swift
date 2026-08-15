import Foundation

/// 评价维度模型（方案 5.5：守时度 / 教学认真度 / 沟通体验，各 1-5 分）
struct EvaluateModel: Codable, Identifiable, Hashable {
    let id: UUID
    var punctuality: Double
    var serious: Double
    var communication: Double
    var comment: String
    var evaluatedAt: Date

    init(
        id: UUID = UUID(),
        punctuality: Double = 5,
        serious: Double = 5,
        communication: Double = 5,
        comment: String = "",
        evaluatedAt: Date = Date()
    ) {
        self.id = id
        self.punctuality = punctuality
        self.serious = serious
        self.communication = communication
        self.comment = comment
        self.evaluatedAt = evaluatedAt
    }
}
