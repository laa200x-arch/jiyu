import Foundation

/// 会话（内置 IM，方案 2.3.3 线上交换）
struct Conversation: Codable, Identifiable, Hashable {
    let id: UUID
    var partner: UserModel
    var lastMessageText: String
    var lastTime: Date
    var unreadCount: Int
}

/// 聊天消息
/// - senderIsMe: 是否本人发送
/// - isSystemNote: 系统提示（如风控拦截提示），非普通消息气泡
/// - mediaType/mediaUrl: 媒体消息（image/video，上传后返回的相对路径）
struct ChatMessage: Codable, Identifiable, Hashable {
    let id: UUID
    var senderIsMe: Bool
    var text: String
    var mediaType: String?
    var mediaUrl: String?
    var time: Date
    var isSystemNote: Bool

    init(
        id: UUID = UUID(),
        senderIsMe: Bool,
        text: String,
        mediaType: String? = nil,
        mediaUrl: String? = nil,
        time: Date = Date(),
        isSystemNote: Bool = false
    ) {
        self.id = id
        self.senderIsMe = senderIsMe
        self.text = text
        self.mediaType = mediaType
        self.mediaUrl = mediaUrl
        self.time = time
        self.isSystemNote = isSystemNote
    }
}

/// 互换动态（动态区，发布内容同样受文本风控）
struct DynamicModel: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID?
    var authorName: String
    var avatarSymbol: String
    var content: String
    var imageBase64: String?
    var time: Date
    var isSystemPost: Bool
    // 宠物护理订单卡片（非订单动态为 nil）
    var orderId: String?
    var orderStatus: String?
    var orderPriceYuan: Double?
    var orderService: String?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        authorName: String,
        avatarSymbol: String,
        content: String,
        imageBase64: String? = nil,
        time: Date = Date(),
        isSystemPost: Bool = false,
        orderId: String? = nil,
        orderStatus: String? = nil,
        orderPriceYuan: Double? = nil,
        orderService: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.authorName = authorName
        self.avatarSymbol = avatarSymbol
        self.content = content
        self.imageBase64 = imageBase64
        self.time = time
        self.isSystemPost = isSystemPost
        self.orderId = orderId
        self.orderStatus = orderStatus
        self.orderPriceYuan = orderPriceYuan
        self.orderService = orderService
    }
}
