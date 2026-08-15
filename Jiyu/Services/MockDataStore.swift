import SwiftUI

/// 技能档案类型：我擅长 / 我想学
enum SkillKind {
    case teach
    case want
}

/// 消息发送结果（用于 UI 展示风控拦截）
enum MessageSendResult: Equatable {
    case sent
    case blocked(warning: String)
}

/// 全局数据层（方案 4.2 数据层）
/// 当前为本地 Mock 实现；正式版替换为 Node.js + Express + MySQL 后端的 APIClient，
/// 同步接入 Socket.io 实时消息、高德定位、百度 AI 风控。
final class MockDataStore: ObservableObject {
    static let shared = MockDataStore()

    // MARK: - 发布数据

    @Published var currentUser: UserModel
    @Published var allUsers: [UserModel]
    @Published var conversations: [Conversation]
    @Published var agreements: [ExchangeAgreement]
    @Published var exchangeRecords: [ExchangeRecord]
    @Published var dynamics: [DynamicModel]
    @Published var currentExposurePackage: ExposurePackage?

    private var messagesByConversation: [UUID: [ChatMessage]] = [:]
    private var evaluationsByUser: [UUID: [EvaluateModel]] = [:]

    // MARK: - 初始化

    private init() {
        currentUser = Self.makeCurrentUser()
        allUsers = Self.makeOtherUsers()
        conversations = []
        agreements = []
        exchangeRecords = []
        dynamics = []
        seedData()
    }

    // MARK: - 双向匹配（方案 2.3.2）

    func matches(filters: MatchFilters = .standard) -> [SkillMatchResult] {
        SkillMatchManager.shared.match(currentUser: currentUser, allUsers: allUsers, filters: filters)
    }

    // MARK: - 内置 IM（方案 2.3.3）

    func messages(for conversationID: UUID) -> [ChatMessage] {
        messagesByConversation[conversationID] ?? []
    }

    /// 获取与某用户的会话；不存在则自动创建
    func openConversation(with partner: UserModel) -> Conversation {
        if let existing = conversations.first(where: { $0.partner.id == partner.id }) {
            return existing
        }
        let convo = Conversation(
            id: UUID(),
            partner: partner,
            lastMessageText: "你们已建立会话，打个招呼吧～",
            lastTime: Date(),
            unreadCount: 0
        )
        conversations.insert(convo, at: 0)
        messagesByConversation[convo.id] = [
            ChatMessage(
                senderIsMe: false,
                text: "你们已建立会话。提醒：请先签署官方互换协议，再开始教学；平台严禁任何金钱交易。",
                isSystemNote: true
            )
        ]
        return convo
    }

    func markConversationRead(_ conversationID: UUID) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].unreadCount = 0
    }

    /// 发送消息（前置风控拦截，方案 2.3.6）
    @discardableResult
    func sendMessage(conversationID: UUID, text: String) -> MessageSendResult {
        let risk = TradeRiskControlManager.shared.checkTextRisk(text: text)

        if risk.isIllegal {
            // 原文不发送，追加系统提示
            let note = ChatMessage(
                senderIsMe: false,
                text: "⚠️ 该消息含违禁词（\(risk.matchedWords.joined(separator: "、"))），已被平台风控拦截。技遇仅支持纯技能无偿互换。",
                isSystemNote: true
            )
            appendMessage(conversationID, note)
            updateConversationPreview(conversationID, text: note.text, time: note.time)
            return .blocked(warning: risk.warning)
        }

        let msg = ChatMessage(senderIsMe: true, text: text)
        appendMessage(conversationID, msg)
        updateConversationPreview(conversationID, text: text, time: msg.time)
        return .sent
    }

    // MARK: - 协议 & 互换（方案 2.3.4）

    func agreement(with partnerID: UUID) -> ExchangeAgreement? {
        agreements.first { $0.partnerID == partnerID }
    }

    /// 签署协议并生成互换记录
    @discardableResult
    func signAgreement(
        partner: UserModel,
        mySkillName: String,
        learnSkillName: String,
        exchangeType: ExchangeType,
        scheduledTime: String,
        location: String?
    ) -> ExchangeRecord {
        let agreement = AgreementManager.shared.buildAgreement(
            partnerID: partner.id,
            partnerName: partner.userName,
            mySkillName: mySkillName,
            learnSkillName: learnSkillName,
            exchangeType: exchangeType,
            scheduledTime: scheduledTime,
            location: location
        )
        agreements.insert(agreement, at: 0)

        let record = ExchangeRecord(
            id: UUID(),
            partner: partner,
            mySkillName: mySkillName,
            learnSkillName: learnSkillName,
            exchangeType: exchangeType,
            scheduledTime: scheduledTime,
            location: location,
            status: .pending,
            evaluateGiven: false,
            createdAt: Date()
        )
        exchangeRecords.insert(record, at: 0)

        // 签署后自动建立会话，便于沟通教学细节
        openConversation(with: partner)
        return record
    }

    /// 标记互换完成（进入互评阶段）
    func completeExchange(recordID: UUID) {
        guard let idx = exchangeRecords.firstIndex(where: { $0.id == recordID }) else { return }
        exchangeRecords[idx].status = .completed
    }

    // MARK: - 双向评价 & 信用分（方案 2.3.5 / 5.5）

    func evaluations(for userID: UUID) -> [EvaluateModel] {
        evaluationsByUser[userID] ?? []
    }

    /// 提交评价：重新计算对方信用分并同步到用户列表
    func submitEvaluation(recordID: UUID, evaluate: EvaluateModel) {
        guard let idx = exchangeRecords.firstIndex(where: { $0.id == recordID }) else { return }
        let record = exchangeRecords[idx]
        exchangeRecords[idx].evaluateGiven = true
        exchangeRecords[idx].status = .completed

        var list = evaluationsByUser[record.partner.id] ?? []
        list.append(evaluate)
        evaluationsByUser[record.partner.id] = list

        let newScore = CreditScoreManager.shared.calculateCreditScore(evaluateList: list)
        if let userIdx = allUsers.firstIndex(where: { $0.id == record.partner.id }) {
            allUsers[userIdx].creditScore = newScore
        }
    }

    // MARK: - 曝光服务（方案 3.1）

    func applyExposure(package: ExposurePackage?) {
        if let package {
            ExposureService.shared.activate(package, for: &currentUser)
            currentExposurePackage = package
        } else {
            ExposureService.shared.deactivate(for: &currentUser)
            currentExposurePackage = nil
        }
    }

    // MARK: - 档案认证（方案 2.3.1）

    func setVerification(_ verification: UserVerification) {
        currentUser.verification = verification
    }

    // MARK: - 技能档案编辑（方案 2.3.1）

    func addSkill(_ skill: SkillModel, kind: SkillKind) {
        switch kind {
        case .teach: currentUser.mySkills.append(skill)
        case .want: currentUser.wantSkills.append(skill)
        }
    }

    func removeSkill(kind: SkillKind, at offsets: IndexSet) {
        switch kind {
        case .teach: currentUser.mySkills.remove(atOffsets: offsets)
        case .want: currentUser.wantSkills.remove(atOffsets: offsets)
        }
    }

    // MARK: - 互换动态（方案 2.3.6 动态区风控）

    /// 发布动态，前置文本风控
    @discardableResult
    func postDynamic(content: String) -> MessageSendResult {
        let risk = TradeRiskControlManager.shared.checkProfileText(text: content)
        guard !risk.isIllegal else { return .blocked(warning: risk.warning) }
        dynamics.insert(
            DynamicModel(
                authorName: currentUser.userName,
                avatarSymbol: currentUser.avatarSymbol,
                content: content,
                time: Date(),
                isSystemPost: false
            ),
            at: 0
        )
        return .sent
    }

    // MARK: - 私有工具

    private func appendMessage(_ conversationID: UUID, _ message: ChatMessage) {
        var list = messagesByConversation[conversationID] ?? []
        list.append(message)
        messagesByConversation[conversationID] = list
    }

    private func updateConversationPreview(_ conversationID: UUID, text: String, time: Date) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].lastMessageText = text
        conversations[idx].lastTime = time
        conversations[idx].unreadCount = 0
    }

    // MARK: - 示例数据

    private static func skill(_ name: String, _ level: SkillLevel, _ type: ExchangeType, _ time: String) -> SkillModel {
        SkillModel(skillName: name, skillLevel: level, exchangeType: type, availableTime: time)
    }

    private static func user(
        _ id: String, _ name: String, _ avatar: String, _ bio: String, _ location: String,
        _ distance: Double?, _ credit: Double, _ verification: UserVerification, _ vip: Bool,
        teach: [SkillModel], want: [SkillModel]
    ) -> UserModel {
        UserModel(
            id: UUID(uuidString: id)!,
            userName: name,
            avatarSymbol: avatar,
            bio: bio,
            locationLabel: location,
            distanceKm: distance,
            creditScore: credit,
            verification: verification,
            mySkills: teach,
            wantSkills: want,
            isExposureVip: vip
        )
    }

    private static func makeCurrentUser() -> UserModel {
        user(
            "00000000-0000-0000-0000-000000000001",
            "阿青", "face.smiling", "大二学生 · 想用剪辑和摄影换吉他/编程", "海淀 · 中关村",
            nil, 82, .full, false,
            teach: [
                skill("视频剪辑", .master, .both, "周末全天"),
                skill("摄影", .skilled, .both, "周末"),
                skill("英语口语", .skilled, .online, "工作日晚上")
            ],
            want: [
                skill("吉他", .beginner, .online, "工作日晚上"),
                skill("编程", .beginner, .both, "周末"),
                skill("日语", .beginner, .online, "工作日晚上")
            ]
        )
    }

    private static func makeOtherUsers() -> [UserModel] {
        [
            user("00000000-0000-0000-0000-000000000002", "林晓", "camera.fill",
                 "独立摄影爱好者 · 人像/街拍", "朝阳 · 国贸图书馆", 3.2, 90, .full, true,
                 teach: [skill("摄影", .master, .both, "周末全天")],
                 want: [skill("视频剪辑", .beginner, .online, "周末"), skill("手绘", .beginner, .offline, "周末")]),
            user("00000000-0000-0000-0000-000000000003", "陈默", "book.fill",
                 "日语 N1 · 动漫爱好者", "朝阳 · 798 文创空间", 12.0, 78, .student, false,
                 teach: [skill("日语", .skilled, .online, "工作日晚上")],
                 want: [skill("摄影", .beginner, .both, "周末")]),
            user("00000000-0000-0000-0000-000000000004", "苏晴", "paintbrush.fill",
                 "插画师 · 手绘达人", "海淀 · 中关村图书大厦", 6.5, 85, .realname, false,
                 teach: [skill("绘画", .master, .offline, "周末")],
                 want: [skill("视频剪辑", .beginner, .online, "工作日晚上")]),
            user("00000000-0000-0000-0000-000000000005", "王野", "film.fill",
                 "B 站剪辑 UP 主", "西城 · 天桥艺术中心", 8.0, 88, .realname, false,
                 teach: [skill("视频剪辑", .skilled, .both, "晚上")],
                 want: [skill("绘画", .beginner, .offline, "周末")]),
            user("00000000-0000-0000-0000-000000000006", "周可", "guitars.fill",
                 "乐队吉他手 · 民谣", "海淀 · 五道口", 1.5, 92, .full, false,
                 teach: [skill("吉他", .master, .both, "每周三晚")],
                 want: [skill("视频剪辑", .beginner, .online, "每周三晚"), skill("编程", .beginner, .both, "周末")]),
            user("00000000-0000-0000-0000-000000000007", "高远", "camera.aperture",
                 "风光摄影 · 旅行", "东城 · 东四共享空间", 15.0, 75, .none, false,
                 teach: [skill("摄影", .skilled, .both, "周末")],
                 want: [skill("编程", .beginner, .online, "工作日晚上")]),
            user("00000000-0000-0000-0000-000000000008", "韩雪", "chevron.left.forwardslash.chevron.right",
                 "全栈工程师 · 开源贡献者", "海淀 · 西二旗咖啡馆", 5.8, 76, .realname, false,
                 teach: [skill("编程", .master, .both, "工作日晚上")],
                 want: [skill("摄影", .beginner, .both, "周末")]),
            user("00000000-0000-0000-0000-000000000009", "白一凡", "pencil.and.outline",
                 "美院学生 · 速写手绘", "海淀 · 清华园", 4.0, 84, .student, false,
                 teach: [skill("手绘", .skilled, .offline, "周末")],
                 want: [skill("英语口语", .skilled, .online, "工作日晚上")]),
            user("00000000-0000-0000-0000-00000000000A", "米粒", "music.note",
                 "日语专业 · 声乐爱好者", "朝阳 · 三里屯书店", 8.2, 88, .full, true,
                 teach: [skill("日语", .skilled, .online, "工作日晚上")],
                 want: [skill("英语口语", .beginner, .online, "工作日晚上")]),
            user("00000000-0000-0000-0000-00000000000B", "阿哲", "laptopcomputer",
                 "自学编程一年 · 想组学习搭子", "丰台 · 科技园", 20.0, 70, .none, false,
                 teach: [skill("编程", .skilled, .online, "晚上")],
                 want: [skill("视频剪辑", .beginner, .online, "晚上")])
        ]
    }

    private func seedData() {
        let linXiao = allUsers[0]   // 林晓
        let zhouKe = allUsers[4]    // 周可
        let miLi = allUsers[8]      // 米粒

        // 会话与消息（含一条风控拦截系统提示，演示方案 2.3.6）
        let convo1 = Conversation(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                                  partner: linXiao, lastMessageText: "好的，周六见！",
                                  lastTime: Date(timeIntervalSinceNow: -3600), unreadCount: 1)
        let convo2 = Conversation(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                                  partner: zhouKe, lastMessageText: "成交！本周三开始？",
                                  lastTime: Date(timeIntervalSinceNow: -86400 * 2), unreadCount: 0)
        let convo3 = Conversation(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                                  partner: miLi, lastMessageText: "周末晚上有空吗？",
                                  lastTime: Date(timeIntervalSinceNow: -7200), unreadCount: 2)
        conversations = [convo1, convo3, convo2]

        messagesByConversation[convo1.id] = [
            ChatMessage(senderIsMe: false, text: "你好！看到你想学摄影，我可以带你入门～", time: Date(timeIntervalSinceNow: -86400 * 2)),
            ChatMessage(senderIsMe: true, text: "太棒了！我正想用视频剪辑和你交换摄影", time: Date(timeIntervalSinceNow: -86400 * 2 + 600)),
            ChatMessage(senderIsMe: false, text: "没问题！周六下午两点国贸图书馆见？", time: Date(timeIntervalSinceNow: -86400)),
            ChatMessage(senderIsMe: false, text: "⚠️ 该消息含违禁词（价格），已被平台风控拦截。技遇仅支持纯技能无偿互换。", time: Date(timeIntervalSinceNow: -86400 + 300), isSystemNote: true),
            ChatMessage(senderIsMe: false, text: "好的，周六见！", time: Date(timeIntervalSinceNow: -3600))
        ]
        messagesByConversation[convo2.id] = [
            ChatMessage(senderIsMe: false, text: "吉他入门没问题，每周三晚线上 1 小时，你教我剪辑就行", time: Date(timeIntervalSinceNow: -86400 * 4)),
            ChatMessage(senderIsMe: true, text: "成交！本周三开始？", time: Date(timeIntervalSinceNow: -86400 * 2))
        ]
        messagesByConversation[convo3.id] = [
            ChatMessage(senderIsMe: false, text: "五十音图我教你，你教我英语口语，双向互换～", time: Date(timeIntervalSinceNow: -86400)),
            ChatMessage(senderIsMe: true, text: "可以！先加个好友", time: Date(timeIntervalSinceNow: -86400 + 600)),
            ChatMessage(senderIsMe: false, text: "周末晚上有空吗？", time: Date(timeIntervalSinceNow: -7200))
        ]

        // 互换记录（方案 2.3.3：交换时长自定义）
        let record1 = ExchangeRecord(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            partner: linXiao, mySkillName: "视频剪辑", learnSkillName: "摄影",
            exchangeType: .both, scheduledTime: "本周六 14:00", location: "国贸图书馆",
            status: .ongoing, evaluateGiven: false, createdAt: Date(timeIntervalSinceNow: -86400 * 2)
        )
        let record2 = ExchangeRecord(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            partner: zhouKe, mySkillName: "视频剪辑", learnSkillName: "吉他",
            exchangeType: .online, scheduledTime: "每周三 20:00", location: nil,
            status: .completed, evaluateGiven: false, createdAt: Date(timeIntervalSinceNow: -86400 * 10)
        )
        exchangeRecords = [record1, record2]

        // 已签署协议
        agreements = [
            AgreementManager.shared.buildAgreement(
                partnerID: linXiao.id, partnerName: linXiao.userName,
                mySkillName: "视频剪辑", learnSkillName: "摄影",
                exchangeType: .both, scheduledTime: "本周六 14:00", location: "国贸图书馆"
            ),
            AgreementManager.shared.buildAgreement(
                partnerID: zhouKe.id, partnerName: zhouKe.userName,
                mySkillName: "视频剪辑", learnSkillName: "吉他",
                exchangeType: .online, scheduledTime: "每周三 20:00", location: nil
            )
        ]

        // 动态区
        dynamics = [
            DynamicModel(authorName: "平台", avatarSymbol: "shield.lefthalf.filled",
                         content: "温馨提示：技遇是纯技能无偿互换平台，严禁任何金钱交易。发现违规内容可举报，平台将给予警告、限流、封禁处理。",
                         time: Date(timeIntervalSinceNow: -1800), isSystemPost: true),
            DynamicModel(authorName: "阿青", avatarSymbol: "face.smiling",
                         content: "和 周可 完成了「吉他 ↔ 视频剪辑」互换，互相教得很认真！已互评五星～",
                         time: Date(timeIntervalSinceNow: -86400), isSystemPost: false),
            DynamicModel(authorName: "周可", avatarSymbol: "guitars.fill",
                         content: "本周六下午在五道口广场组织吉他弹唱小聚，纯兴趣交流，欢迎来玩～",
                         time: Date(timeIntervalSinceNow: -86400 * 2), isSystemPost: false),
            DynamicModel(authorName: "米粒", avatarSymbol: "music.note",
                         content: "日语五十音入门笔记整理好了，需要的同学评论区扣 1",
                         time: Date(timeIntervalSinceNow: -86400 * 3), isSystemPost: false),
            DynamicModel(authorName: "林晓", avatarSymbol: "camera.fill",
                         content: "这周六在国贸图书馆带新人学摄影构图，还有两个名额",
                         time: Date(timeIntervalSinceNow: -86400 * 4), isSystemPost: false)
        ]
    }
}
