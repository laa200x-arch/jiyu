import Foundation

/// 技能熟练度（方案 5.1）
enum SkillLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "入门"
    case skilled = "熟练"
    case master = "精通"

    var id: String { rawValue }
}

/// 交换方式（方案 5.1）
enum ExchangeType: String, Codable, CaseIterable, Identifiable {
    case online = "线上"
    case offline = "线下"
    case both = "线上+线下"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .online: return "video.fill"
        case .offline: return "mappin.and.ellipse"
        case .both: return "arrow.left.arrow.right"
        }
    }
}

/// 核心技能数据模型（方案 5.1）
/// 注意：id 由外部显式注入，避免 `let id = UUID()` 在 Codable 解码时每次重新生成导致身份错乱
struct SkillModel: Codable, Identifiable, Hashable {
    let id: UUID
    var skillName: String
    var skillLevel: SkillLevel
    var exchangeType: ExchangeType
    var availableTime: String

    init(
        id: UUID = UUID(),
        skillName: String,
        skillLevel: SkillLevel,
        exchangeType: ExchangeType,
        availableTime: String
    ) {
        self.id = id
        self.skillName = skillName
        self.skillLevel = skillLevel
        self.exchangeType = exchangeType
        self.availableTime = availableTime
    }
}

/// 档案认证级别（学生认证 via 学信网 / 实名认证，提升匹配可信度）
enum UserVerification: String, Codable, CaseIterable, Identifiable {
    case none = "未认证"
    case student = "学生认证"
    case realname = "实名认证"
    case full = "双重认证"

    var id: String { rawValue }
}

/// 用户核心模型（方案 5.1）
/// avatarSymbol：SF Symbol 占位；avatarUrl：自定义头像（服务器上传后返回的相对路径，优先显示）
struct UserModel: Codable, Identifiable, Hashable {
    let id: UUID
    var userName: String
    var avatarSymbol: String
    var avatarUrl: String?
    var bio: String
    var locationLabel: String
    var distanceKm: Double?          // 线下距离（同城匹配）
    var creditScore: Double          // 信用评分 0-100
    var verification: UserVerification
    var mySkills: [SkillModel]       // 我擅长的技能
    var wantSkills: [SkillModel]     // 我想学的技能
    var isExposureVip: Bool          // 是否曝光付费用户（盈利模块，仅曝光加权）
    var exposureUntil: Date?

    init(
        id: UUID = UUID(),
        userName: String,
        avatarSymbol: String,
        avatarUrl: String? = nil,
        bio: String,
        locationLabel: String,
        distanceKm: Double?,
        creditScore: Double,
        verification: UserVerification,
        mySkills: [SkillModel],
        wantSkills: [SkillModel],
        isExposureVip: Bool,
        exposureUntil: Date? = nil
    ) {
        self.id = id
        self.userName = userName
        self.avatarSymbol = avatarSymbol
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.locationLabel = locationLabel
        self.distanceKm = distanceKm
        self.creditScore = creditScore
        self.verification = verification
        self.mySkills = mySkills
        self.wantSkills = wantSkills
        self.isExposureVip = isExposureVip
        self.exposureUntil = exposureUntil
    }
}
