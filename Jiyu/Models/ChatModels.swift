import Foundation

/// 会话（内置 IM，方案 2.3.3 线上交换）
struct Conversation: Codable, Identifiable, Hashable {
    let id: UUID
    let partner: UserModel
    var lastMessageText: String
    var lastTime: Date
    var unreadCount: Int
}

/// 聊天消息
/// - senderIsMe: 是否本人发送
/// - isSystemNote: 系统提示（如风控拦截提示），非普通消息气泡
struct ChatMessage: Codable, Identifiable, Hashable {
    let id: UUID
    var senderIsMe: Bool
    var text: String
    var time: Date
    var isSystemNote: Bool

    init(
        id: UUID = UUID(),
        senderIsMe: Bool,
        text: String,
        time: Date = Date(),
        isSystemNote: Bool = false
    ) {
        self.id = id
        self.senderIsMe = senderIsMe
        self.text = text
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

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        authorName: String,
        avatarSymbol: String,
        content: String,
        imageBase64: String? = nil,
        time: Date = Date(),
        isSystemPost: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.authorName = authorName
        self.avatarSymbol = avatarSymbol
        self.content = content
        self.imageBase64 = imageBase64
        self.time = time
        self.isSystemPost = isSystemPost
    }
}
