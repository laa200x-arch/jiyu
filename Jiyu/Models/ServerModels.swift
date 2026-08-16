import Foundation

// ============================================================
// 服务端数据模型（Server DTO）
// 服务端 JSON 为 camelCase，字段与 Swift 模型对齐，可直接解码；
// 服务端 id 为数字字符串，经 UUID(serverID:) 确定性映射为本地 UUID。
// ============================================================

// MARK: - 服务端枚举编码（服务端英文代码 ↔ 客户端中文展示）

extension SkillLevel {
    var serverCode: String {
        switch self {
        case .beginner: return "beginner"
        case .skilled: return "skilled"
        case .master: return "master"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "skilled": self = .skilled
        case "master": self = .master
        default: self = .beginner
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(serverCode)
    }
}

extension ExchangeType {
    var serverCode: String {
        switch self {
        case .online: return "online"
        case .offline: return "offline"
        case .both: return "both"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "offline": self = .offline
        case "online": self = .online
        default: self = .both
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(serverCode)
    }
}

extension UserVerification {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "student": self = .student
        case "realname": self = .realname
        case "full": self = .full
        default: self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(serverCode)
    }

    var serverCode: String {
        switch self {
        case .none: return "none"
        case .student: return "student"
        case .realname: return "realname"
        case .full: return "full"
        }
    }
}

extension ExchangeStatus {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "pending": self = .pending
        case "ongoing": self = .ongoing
        case "cancelled": self = .cancelled
        default: self = .completed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(serverCode)
    }

    var serverCode: String {
        switch self {
        case .pending: return "pending"
        case .ongoing: return "ongoing"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        }
    }
}

// MARK: - 服务端 id ↔ 本地 UUID 确定性映射

extension UUID {
    /// 服务端数字 id → 稳定 UUID（"00000000-0000-0000-0000-" + 12 位**前导**补零）
    /// 注意：不能用 String.padding（它是在末尾补字符），必须手动前导补零
    init(serverID: String) {
        let digits = serverID.filter { $0.isNumber }
        let trimmed = digits.count > 12 ? String(digits.suffix(12)) : digits
        let padded = String(repeating: "0", count: max(0, 12 - trimmed.count)) + trimmed
        self = UUID(uuidString: "00000000-0000-0000-0000-\(padded)") ?? UUID()
    }

    /// 本地 UUID → 服务端数字 id（仅对 serverID 映射的 UUID 有效）
    var serverIDString: String? {
        let s = uuidString
        guard s.hasPrefix("00000000-0000-0000-0000-") else { return nil }
        let digits = String(s.suffix(12))
        let number = Int(digits) ?? 0
        return String(number)
    }
}

// MARK: - DTO（与服务端 JSON 一一对应）

struct ServerSkill: Decodable {
    let id: String
    let skillName: String
    let skillLevel: SkillLevel
    let exchangeType: ExchangeType
    let availableTime: String
}

struct ServerUser: Decodable {
    let id: String
    let username: String
    let userName: String
    let avatarSymbol: String
    let bio: String
    let locationLabel: String
    let distanceKm: Double?
    let creditScore: Double
    let verification: UserVerification
    let isExposureVip: Bool
    let exposureUntil: String?
    let mySkills: [ServerSkill]
    let wantSkills: [ServerSkill]
}

struct ServerMatch: Decodable {
    let user: ServerUser
    let mySkillsForThem: [String]
    let theirSkillsForMe: [String]
}

struct ServerConversation: Decodable {
    let id: String
    let partner: ServerUser
    let lastMessageText: String
    let lastTime: Date
    let unreadCount: Int
}

struct ServerMessage: Decodable {
    let id: String
    let senderIsMe: Bool
    let text: String
    let mediaType: String?
    let mediaUrl: String?
    let time: Date
    let isSystemNote: Bool
}

struct ServerDynamic: Decodable {
    let id: String
    let userId: String
    let authorName: String
    let avatarSymbol: String
    let content: String
    let imageBase64: String?
    let time: Date
    let isSystemPost: Bool
}

struct ServerExchangeRecord: Decodable {
    let id: String
    let partner: ServerUser
    let mySkillName: String
    let learnSkillName: String
    let exchangeType: ExchangeType
    let scheduledTime: String
    let location: String?
    let status: ExchangeStatus
    let evaluateGiven: Bool
    let createdAt: Date
}

struct ServerAgreement: Decodable {
    let id: String
    let partnerId: String
    let partnerName: String
    let mySkillName: String
    let learnSkillName: String
    let exchangeType: ExchangeType
    let scheduledTime: String
    let location: String?
    let content: String
    let signedAt: Date
}

// MARK: - 响应包装

struct ServerVersion: Decodable {
    let current: String
    let updateMessage: String
    let downloadUrl: String
}

struct TokenResponse: Decodable { let token: String; let user: ServerUser }
struct UserResponse: Decodable { let user: ServerUser }
struct UsersResponse: Decodable { let users: [ServerUser] }
struct MatchesResponse: Decodable { let matches: [ServerMatch] }
struct ConversationsResponse: Decodable { let conversations: [ServerConversation] }
struct ConversationResponse: Decodable { let conversation: ServerConversation }
struct MessagesResponse: Decodable { let messages: [ServerMessage] }
struct DynamicsResponse: Decodable { let dynamics: [ServerDynamic] }
struct RecordsResponse: Decodable { let records: [ServerExchangeRecord] }
struct AgreementsResponse: Decodable { let agreements: [ServerAgreement] }
struct MessageSendResponse: Decodable {
    let message: ServerMessage?
    let blocked: Bool?
    let warning: String?
}
struct SkillResponse: Decodable { let skill: ServerSkill? }
struct EvaluationResponse: Decodable {
    let newCreditScore: Double?
    let evaluations: Int?
}
struct RecordResponse: Decodable { let record: ServerExchangeRecord? }
struct OkResponse: Decodable { let ok: Bool? }

// MARK: - DTO → 本地模型映射

extension SkillModel {
    init(server: ServerSkill) {
        self.init(
            id: UUID(serverID: server.id),
            skillName: server.skillName,
            skillLevel: server.skillLevel,
            exchangeType: server.exchangeType,
            availableTime: server.availableTime
        )
    }
}

extension UserModel {
    init(server: ServerUser) {
        self.init(
            id: UUID(serverID: server.id),
            userName: server.userName,
            avatarSymbol: server.avatarSymbol,
            bio: server.bio,
            locationLabel: server.locationLabel,
            distanceKm: server.distanceKm,
            creditScore: server.creditScore,
            verification: server.verification,
            mySkills: server.mySkills.map { SkillModel(server: $0) },
            wantSkills: server.wantSkills.map { SkillModel(server: $0) },
            isExposureVip: server.isExposureVip,
            exposureUntil: server.exposureUntil.flatMap { APIClient.parseDate($0) }
        )
    }
}

extension Conversation {
    init(server: ServerConversation) {
        self.init(
            id: UUID(serverID: server.id),
            partner: UserModel(server: server.partner),
            lastMessageText: server.lastMessageText,
            lastTime: server.lastTime,
            unreadCount: server.unreadCount
        )
    }
}

extension ChatMessage {
    init(server: ServerMessage) {
        self.init(
            id: UUID(serverID: server.id),
            senderIsMe: server.senderIsMe,
            text: server.text,
            mediaType: server.mediaType,
            mediaUrl: server.mediaUrl,
            time: server.time,
            isSystemNote: server.isSystemNote
        )
    }
}

extension DynamicModel {
    init(server: ServerDynamic) {
        self.init(
            id: UUID(serverID: server.id),
            userId: UUID(serverID: server.userId),
            authorName: server.authorName,
            avatarSymbol: server.avatarSymbol,
            content: server.content,
            imageBase64: server.imageBase64,
            time: server.time,
            isSystemPost: server.isSystemPost
        )
    }
}

extension ExchangeRecord {
    init(server: ServerExchangeRecord) {
        self.init(
            id: UUID(serverID: server.id),
            partner: UserModel(server: server.partner),
            mySkillName: server.mySkillName,
            learnSkillName: server.learnSkillName,
            exchangeType: server.exchangeType,
            scheduledTime: server.scheduledTime,
            location: server.location,
            status: server.status,
            evaluateGiven: server.evaluateGiven,
            createdAt: server.createdAt
        )
    }
}

extension ExchangeAgreement {
    init(server: ServerAgreement) {
        self.init(
            id: UUID(serverID: server.id),
            partnerID: UUID(serverID: server.partnerId),
            partnerName: server.partnerName,
            mySkillName: server.mySkillName,
            learnSkillName: server.learnSkillName,
            exchangeType: server.exchangeType,
            scheduledTime: server.scheduledTime,
            location: server.location,
            content: server.content,
            signedAt: server.signedAt
        )
    }
}
