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
    let avatarUrl: String?
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
    let orderId: String?
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
    // 宠物护理订单卡片（非订单动态为 nil）
    let orderId: String?
    let orderStatus: String?
    let orderPriceYuan: Double?
    let orderService: String?
    // 我的接单申请状态（pending/rejected/accepted；未申请为 nil）+ 待确认申请数
    let myApplicationStatus: String?
    let applicationCount: Int?
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

// MARK: - 宠物护理域 DTO（旧巡六迁移 → 收费订单模式）

struct ServerCareService: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let desc: String
    let duration: String
    let priceYuan: Double
}

struct CareOptions: Decodable {
    let dogBehaviors: [String]
    let catBehaviors: [String]
    let homeReactions: [String]
    let weightOptions: [String]
}

struct CareServicesResponse: Decodable {
    let services: [ServerCareService]
    let options: CareOptions
}

struct ServerPet: Decodable, Identifiable {
    let id: String
    let name: String
    let petType: String
    let breed: String
    let ageMonths: Int
    let gender: String
    let neutered: Bool
    let weightKg: Double?
    let behaviors: [String]?
    let homeReactions: [String]?
    let photoUrl: String?
    let notes: String
}

struct PetsResponse: Decodable { let pets: [ServerPet] }
struct PetResponse: Decodable { let pet: ServerPet }

/// 订单里的用户摘要（看护人/下单人；服务端只返回这几个字段，不能复用完整 ServerUser）
struct BookingUser: Decodable {
    let id: String
    let userName: String
    let avatarSymbol: String
    let avatarUrl: String?
    let creditScore: Double
    let locationLabel: String?
    let distanceKm: Double?
}

/// 接单申请（派单人可见列表：申请者信息 + 状态）
struct BookingApplication: Decodable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let avatarSymbol: String
    let avatarUrl: String?
    let creditScore: Double
    let verification: String
    let locationLabel: String?
    let message: String?
    let status: String
    let createdAt: String
}

/// 我自己的申请（申请者视角）
struct MyApplication: Decodable {
    let id: String
    let status: String
    let message: String?
    let createdAt: String
}

struct ServerBooking: Decodable, Identifiable {
    let id: String
    let userId: String
    let providerId: String?
    let petId: String
    let serviceId: String
    let serviceName: String
    let scheduledTime: String
    let location: String?
    var status: String
    let priceYuan: Double
    let commissionYuan: Double
    let workerIncome: Double
    let openToFeed: Bool
    let distanceKm: Double?
    let pet: ServerPet?
    let initiator: BookingUser?
    let provider: BookingUser?
    let applications: [BookingApplication]?
    let myApplication: MyApplication?
}

struct BookingsResponse: Decodable { let bookings: [ServerBooking] }
struct BookingResponse: Decodable { let booking: ServerBooking }

// MARK: - 响应包装

struct ServerVersion: Decodable {
    let current: String
    let updateMessage: String
    let downloadUrl: String
}

struct TokenResponse: Decodable { let token: String; let user: ServerUser }

/// 发送手机验证码响应（测试通道附带 devCode）
struct SmsCodeResponse: Decodable {
    let ok: Bool?
    let message: String
    let devCode: String?
}
struct UserResponse: Decodable { let user: ServerUser }
struct UsersResponse: Decodable { let users: [ServerUser] }
struct MatchesResponse: Decodable { let matches: [ServerMatch] }
struct ConversationsResponse: Decodable { let conversations: [ServerConversation] }
struct ConversationResponse: Decodable { let conversation: ServerConversation }
struct MessagesResponse: Decodable {
    let messages: [ServerMessage]
    let hasMore: Bool?
}
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
/// 收到的评价（含文字评价与我的申诉状态，V1.1）
struct ReceivedEvaluation: Decodable {
    let id: String
    let fromUserId: String
    let fromName: String
    let fromAvatar: String
    let punctuality: Double
    let serious: Double
    let communication: Double
    let comment: String
    let myAppealStatus: String?
    let createdAt: String
}
struct EvaluationsResponse: Decodable { let evaluations: [ReceivedEvaluation] }
struct RecordResponse: Decodable { let record: ServerExchangeRecord? }
struct OkResponse: Decodable { let ok: Bool? }

/// 小程序（市场条目；详情接口附带 htmlContent 供沙箱运行）
struct MiniApp: Decodable {
    let id: String
    let userId: String
    let authorName: String
    let name: String
    let description: String
    let icon: String
    let version: String
    let sizeKb: Int
    let downloads: Int
    let htmlContent: String?
}
struct MiniAppsResponse: Decodable { let apps: [MiniApp] }
struct MiniAppResponse: Decodable { let app: MiniApp }
extension MiniApp: Identifiable {}

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
            avatarUrl: server.avatarUrl,
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
            orderId: server.orderId,
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
            isSystemPost: server.isSystemPost,
            orderId: server.orderId,
            orderStatus: server.orderStatus,
            orderPriceYuan: server.orderPriceYuan,
            orderService: server.orderService,
            myApplicationStatus: server.myApplicationStatus,
            applicationCount: server.applicationCount
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
