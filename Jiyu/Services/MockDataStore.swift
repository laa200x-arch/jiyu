import SwiftUI

/// 技能档案类型：我擅长 / 我想学
enum SkillKind {
    case teach
    case want
}

/// 消息发送结果（用于 UI 展示风控拦截 / 发送失败）
enum MessageSendResult: Equatable {
    case sent
    case blocked(warning: String)
    case failed(warning: String)
}

/// 全局数据层（方案 4.2 数据层）
/// 双模式：
///   - 服务端模式（登录后）：数据来自 Node.js + Express 后端（APIClient），
///     实时消息走 Socket.io（RealtimeClient），风控由服务端执行
///   - 演示模式（未登录/离线）：内置示例数据，纯本地运行
@MainActor
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

    /// 当前打开中的会话（用于实时消息未读计数）
    var activeConversationID: UUID?

    /// 服务端用户 id（非空 = 服务端模式）
    private(set) var serverUserID: String?

    /// 会话消息缓存（@Published：消息加载完成后驱动聊天界面重绘）
    @Published private var messagesByConversation: [UUID: [ChatMessage]] = [:]
    /// 会话是否还有更早消息（分页加载）
    @Published private var hasMoreByConversation: [UUID: Bool] = [:]
    private var evaluationsByUser: [UUID: [EvaluateModel]] = [:]

    var isServerMode: Bool { serverUserID != nil }

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

    // MARK: - 登录 / 会话（服务端模式）

    func login(username: String, password: String) async throws {
        do {
            let user = try await APIClient.shared.login(username: username, password: password)
            try await activateServerSession(user)
        } catch {
            // 登录失败：清除可能残留的旧 token，避免重启后"误自动登录"
            TokenStore.token = nil
            serverUserID = nil
            throw error
        }
    }

    func register(username: String, password: String, nickname: String) async throws {
        do {
            let user = try await APIClient.shared.register(username: username, password: password, nickname: nickname)
            try await activateServerSession(user)
        } catch {
            TokenStore.token = nil
            serverUserID = nil
            throw error
        }
    }

    /// 用已保存账号的 token 直接登录（切换账号免输密码）
    /// 401（token 真失效）→ 清 token 抛错；网络异常 → 保留 token 与账号（登录页可重试）
    func loginWithSavedAccount(_ account: SavedAccount) async throws {
        TokenStore.token = account.token
        do {
            let user = try await APIClient.shared.fetchMe()
            try await activateServerSession(user)
        } catch let error as APIError {
            if error == .unauthorized {
                TokenStore.token = nil
            }
            throw error
        }
    }

    /// 自动登录：App 启动时若存在持久化 Token，从服务器拉取该账号数据
    /// - 返回 true：会话有效，已恢复账号数据
    /// - 返回 false：回登录页（401 清 token；网络异常保留 token 与账号，可重试）
    @discardableResult
    func autoLogin() async -> Bool {
        guard TokenStore.token != nil else { return false }
        do {
            let user = try await APIClient.shared.fetchMe()
            try await activateServerSession(user)
            return true
        } catch let error as APIError {
            serverUserID = nil
            RealtimeClient.shared.disconnect()
            if error == .unauthorized {
                // token 真失效：清除
                TokenStore.token = nil
            }
            return false
        } catch {
            serverUserID = nil
            RealtimeClient.shared.disconnect()
            return false
        }
    }

    private func activateServerSession(_ user: ServerUser) async throws {
        serverUserID = user.id
        currentUser = UserModel(server: user)
        // 保存账号到本机（切换账号时免输密码，手动删除前一直保留）
        if let token = TokenStore.token {
            TokenStore.saveAccount(SavedAccount(
                username: user.username,
                nickname: user.userName,
                avatarSymbol: user.avatarSymbol,
                token: token
            ))
        }
        try await refreshAll()
        NotificationService.requestPermission()
        RealtimeClient.shared.onMessage = { [weak self] payload in
            Task { @MainActor in
                self?.handleSocketMessage(payload)
            }
        }
        RealtimeClient.shared.onMatchPush = { [weak self] from, message in
            Task { @MainActor in
                NotificationService.post(title: "\(from) 发来互换邀约", body: message)
                try? await self?.refreshAll()
            }
        }
        if let token = TokenStore.token {
            RealtimeClient.shared.connect(token: token)
        }
    }

    func logout() {
        TokenStore.token = nil
        serverUserID = nil
        RealtimeClient.shared.disconnect()
        // 重置为演示数据
        currentUser = Self.makeCurrentUser()
        allUsers = Self.makeOtherUsers()
        conversations = []
        agreements = []
        exchangeRecords = []
        dynamics = []
        messagesByConversation = [:]
        seedData()
    }

    /// 全量刷新（登录后 / 下拉刷新）
    func refreshAll() async throws {
        async let users = APIClient.shared.fetchUsers()
        async let convs = APIClient.shared.fetchConversations()
        async let dyns = APIClient.shared.fetchDynamics()
        async let recs = APIClient.shared.fetchExchanges()
        async let agrs = APIClient.shared.fetchAgreements()
        allUsers = try await users.map { UserModel(server: $0) }
        conversations = try await convs.map { Conversation(server: $0) }
        dynamics = try await dyns.map { DynamicModel(server: $0) }
        exchangeRecords = try await recs.map { ExchangeRecord(server: $0) }
        agreements = try await agrs.map { ExchangeAgreement(server: $0) }
    }

    /// 拉取指定用户最新资料并同步本地快照（动态资料页/匹配详情打开时调用）
    func refreshUser(_ user: UserModel) async -> UserModel {
        guard isServerMode, let serverID = user.id.serverIDString else { return user }
        guard let fresh = try? await APIClient.shared.fetchUser(id: serverID) else { return user }
        let updated = UserModel(server: fresh)
        syncUserSnapshot(updated)
        return updated
    }

    /// 同步用户快照到 allUsers / currentUser / 会话 partner
    private func syncUserSnapshot(_ updated: UserModel) {
        if let idx = allUsers.firstIndex(where: { $0.id == updated.id }) {
            allUsers[idx] = updated
        }
        if updated.id == currentUser.id {
            currentUser = updated
        }
        for i in conversations.indices where conversations[i].partner.id == updated.id {
            conversations[i].partner = updated
        }
    }

    /// 更新档案后同步本地快照（技能增删/认证/曝光）
    private func syncCurrentUserInAllUsers() {
        syncUserSnapshot(currentUser)
    }

    // MARK: - 双向匹配（方案 2.3.2，本地算法与服务端一致）

    func matches(filters: MatchFilters = .standard) -> [SkillMatchResult] {
        SkillMatchManager.shared.match(currentUser: currentUser, allUsers: allUsers, filters: filters)
    }

    // MARK: - 内置 IM（方案 2.3.3）

    func messages(for conversationID: UUID) -> [ChatMessage] {
        messagesByConversation[conversationID] ?? []
    }

    /// 获取与某用户的会话（服务端模式：优先走服务器，失败返回 nil 由界面提示重试；演示模式：本地创建）
    func openConversation(with partner: UserModel) async -> Conversation? {
        if let existing = conversations.first(where: { $0.partner.id == partner.id }) {
            return existing
        }
        if isServerMode, let partnerServerID = partner.id.serverIDString {
            do {
                let server = try await APIClient.shared.openConversation(partnerId: partnerServerID)
                let convo = Conversation(server: server)
                if !conversations.contains(where: { $0.id == convo.id }) {
                    conversations.insert(convo, at: 0)
                }
                return convo
            } catch {
                print("[store] openConversation 失败: \(error)")
                return nil
            }
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

    /// 拉取会话历史消息（服务端模式，默认最近 50 条）
    func loadMessages(conversationID: UUID) async {
        guard isServerMode, let serverID = conversationID.serverIDString else { return }
        do {
            let (serverMessages, hasMore) = try await APIClient.shared.fetchMessages(conversationId: serverID)
            messagesByConversation[conversationID] = serverMessages.map { ChatMessage(server: $0) }
            hasMoreByConversation[conversationID] = hasMore
        } catch {
            // 保留现有消息
        }
    }

    /// 会话是否还有更早消息（聊天页显示「加载更早消息」按钮）
    func hasMoreMessages(for conversationID: UUID) -> Bool {
        hasMoreByConversation[conversationID] ?? false
    }

    /// 加载更早消息（分页，插入到现有消息之前）
    func loadEarlierMessages(conversationID: UUID) async {
        guard isServerMode, let serverID = conversationID.serverIDString else { return }
        let existing = messagesByConversation[conversationID] ?? []
        guard let oldest = existing.first, let oldestServerID = oldest.id.serverIDString else { return }
        do {
            let (serverMessages, hasMore) = try await APIClient.shared.fetchMessages(
                conversationId: serverID, before: oldestServerID
            )
            let earlier = serverMessages.map { ChatMessage(server: $0) }
            messagesByConversation[conversationID] = earlier + existing
            hasMoreByConversation[conversationID] = hasMore
        } catch {
            // 保留现有消息
        }
    }

    func markConversationRead(_ conversationID: UUID) {
        activeConversationID = conversationID
        guard let idx = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[idx].unreadCount = 0
        if isServerMode, let serverID = conversationID.serverIDString {
            Task {
                try? await APIClient.shared.markConversationRead(conversationId: serverID)
            }
        }
    }

    /// 发送消息（前置风控拦截，方案 2.3.6）
    /// 服务端模式：Socket.io 实时发送（服务端风控），失败自动 REST 兜底保证必达
    @discardableResult
    func sendMessage(conversationID: UUID, text: String) async -> MessageSendResult {
        if isServerMode {
            guard let serverID = conversationID.serverIDString else {
                return .failed(warning: "会话未同步，请返回消息列表重新进入")
            }
            // 1) Socket 实时发送
            let socketResult = await sendViaSocket(serverID: serverID, text: text)
            switch socketResult {
            case .sent:
                return .sent
            case .blocked(let warning):
                return .blocked(warning: warning)
            case .failed:
                break // 连接类失败 → REST 兜底
            }
            // 2) REST 兜底（服务端同一套风控与落库，消息必达服务器）
            do {
                let response = try await APIClient.shared.sendMessage(conversationId: serverID, text: text)
                if response.blocked == true {
                    return .blocked(warning: response.warning ?? "内容违规，已被拦截")
                }
                return .sent
            } catch {
                return .failed(warning: (error as? LocalizedError)?.errorDescription ?? "发送失败，请重试")
            }
        }

        // 演示模式：本地风控
        let risk = TradeRiskControlManager.shared.checkTextRisk(text: text)
        if risk.isIllegal {
            let note = ChatMessage(
                senderIsMe: false,
                text: "⚠️ 该消息含违禁词：\(risk.matchedWords.joined(separator: "、"))，已被平台风控拦截。技遇仅支持纯技能无偿互换。",
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

    /// 发送媒体消息（图片/视频，方案 2.3.3 资料传输）
    /// 媒体走 REST 通道（先上传文件再发消息），文本走 Socket 实时
    func sendMediaMessage(conversationID: UUID, mediaType: String, mediaUrl: String, text: String = "") async -> MessageSendResult {
        guard isServerMode, let serverID = conversationID.serverIDString else {
            return .failed(warning: "会话未同步，请返回消息列表重新进入")
        }
        do {
            let response = try await APIClient.shared.sendMessage(
                conversationId: serverID,
                text: text,
                mediaType: mediaType,
                mediaUrl: mediaUrl
            )
            if response.blocked == true {
                return .blocked(warning: response.warning ?? "内容违规，已被拦截")
            }
            return .sent
        } catch {
            return .failed(warning: (error as? LocalizedError)?.errorDescription ?? "发送失败，请重试")
        }
    }

    /// Socket 实时发送（失败返回 .failed，由调用方决定 REST 兜底）
    private func sendViaSocket(serverID: String, text: String) async -> MessageSendResult {
        await withCheckedContinuation { continuation in
            RealtimeClient.shared.send(conversationId: serverID, text: text) { ok, blocked, warning in
                Task { @MainActor in
                    if blocked {
                        continuation.resume(returning: .blocked(warning: warning ?? "内容违规，已被拦截"))
                    } else if ok {
                        continuation.resume(returning: .sent)
                    } else {
                        continuation.resume(returning: .failed(warning: warning ?? "发送失败，请重试"))
                    }
                }
            }
        }
    }

    /// 实时消息处理（服务端 chat:message 广播 + 本地通知）
    private func handleSocketMessage(_ payload: RealtimeClient.SocketMessagePayload) {
        let convID = UUID(serverID: payload.conversationId)
        let isMe = payload.senderId == serverUserID
        let message = ChatMessage(
            id: UUID(serverID: payload.id),
            senderIsMe: isMe,
            text: payload.text,
            mediaType: payload.mediaType,
            mediaUrl: payload.mediaUrl,
            time: payload.time,
            isSystemNote: false
        )
        appendMessage(convID, message)
        guard let idx = conversations.firstIndex(where: { $0.id == convID }) else { return }
        conversations[idx].lastMessageText = payload.text
        conversations[idx].lastTime = payload.time
        if !isMe && activeConversationID != convID {
            conversations[idx].unreadCount += 1
            // 本地通知（对方发来新消息）
            NotificationService.post(
                title: "\(conversations[idx].partner.userName) 发来消息",
                body: payload.text
            )
        }
    }

    // MARK: - 协议 & 互换（方案 2.3.4）

    func agreement(with partnerID: UUID) -> ExchangeAgreement? {
        agreements.first { $0.partnerID == partnerID }
    }

    /// 签署协议并生成互换记录（服务端模式：服务端校验 + 实时推送对方）
    @discardableResult
    func signAgreement(
        partner: UserModel,
        mySkillName: String,
        learnSkillName: String,
        exchangeType: ExchangeType,
        scheduledTime: String,
        location: String?
    ) async throws -> ExchangeRecord {
        if isServerMode, let partnerServerID = partner.id.serverIDString {
            let server = try await APIClient.shared.signAgreement(
                partnerId: partnerServerID,
                mySkillName: mySkillName,
                learnSkillName: learnSkillName,
                exchangeType: exchangeType,
                scheduledTime: scheduledTime,
                location: location
            )
            let record = ExchangeRecord(server: server)
            if !exchangeRecords.contains(where: { $0.id == record.id }) {
                exchangeRecords.insert(record, at: 0)
            }
            return record
        }

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
        _ = await openConversation(with: partner)
        return record
    }

    /// 标记互换完成（进入互评阶段）
    func completeExchange(recordID: UUID) async {
        if isServerMode, let serverID = recordID.serverIDString {
            try? await APIClient.shared.completeExchange(id: serverID)
        }
        guard let idx = exchangeRecords.firstIndex(where: { $0.id == recordID }) else { return }
        exchangeRecords[idx].status = .completed
    }

    // MARK: - 双向评价 & 信用分（方案 2.3.5 / 5.5）

    func evaluations(for userID: UUID) -> [EvaluateModel] {
        evaluationsByUser[userID] ?? []
    }

    /// 提交评价：服务端重算信用分并同步
    func submitEvaluation(recordID: UUID, evaluate: EvaluateModel) async {
        if isServerMode, let serverID = recordID.serverIDString {
            if let newScore = try? await APIClient.shared.submitEvaluation(
                recordId: serverID,
                punctuality: evaluate.punctuality,
                serious: evaluate.serious,
                communication: evaluate.communication,
                comment: evaluate.comment
            ) {
                if let idx = exchangeRecords.firstIndex(where: { $0.id == recordID }) {
                    let partnerID = exchangeRecords[idx].partner.id
                    if let userIdx = allUsers.firstIndex(where: { $0.id == partnerID }) {
                        allUsers[userIdx].creditScore = newScore
                    }
                }
            }
        }
        guard let idx = exchangeRecords.firstIndex(where: { $0.id == recordID }) else { return }
        let record = exchangeRecords[idx]
        exchangeRecords[idx].evaluateGiven = true
        exchangeRecords[idx].status = .completed

        var list = evaluationsByUser[record.partner.id] ?? []
        list.append(evaluate)
        evaluationsByUser[record.partner.id] = list

        if !isServerMode {
            let newScore = CreditScoreManager.shared.calculateCreditScore(evaluateList: list)
            if let userIdx = allUsers.firstIndex(where: { $0.id == record.partner.id }) {
                allUsers[userIdx].creditScore = newScore
            }
        }
    }

    // MARK: - 曝光服务（方案 3.1）

    func applyExposure(package: ExposurePackage?) async {
        if isServerMode {
            do {
                if let package {
                    let user = try await APIClient.shared.applyExposure(packageId: package.id)
                    currentUser = UserModel(server: user)
                } else {
                    let user = try await APIClient.shared.cancelExposure()
                    currentUser = UserModel(server: user)
                }
                currentExposurePackage = package
                syncCurrentUserInAllUsers()
                return
            } catch {
                // 服务端失败回退本地
            }
        }
        if let package {
            ExposureService.shared.activate(package, for: &currentUser)
            currentExposurePackage = package
        } else {
            ExposureService.shared.deactivate(for: &currentUser)
            currentExposurePackage = nil
        }
        syncCurrentUserInAllUsers()
    }

    // MARK: - 档案认证（方案 2.3.1）

    func setVerification(_ verification: UserVerification) async {
        if isServerMode {
            if let user = try? await APIClient.shared.setVerification(verification) {
                currentUser = UserModel(server: user)
                syncCurrentUserInAllUsers()
                return
            }
        }
        currentUser.verification = verification
        syncCurrentUserInAllUsers()
    }

    // MARK: - 技能档案编辑（方案 2.3.1）

    func addSkill(_ skill: SkillModel, kind: SkillKind) async {
        if isServerMode {
            if let serverSkill = try? await APIClient.shared.addSkill(
                kind: kind == .teach ? "teach" : "want",
                skill: skill
            ) {
                let local = SkillModel(server: serverSkill)
                switch kind {
                case .teach: currentUser.mySkills.append(local)
                case .want: currentUser.wantSkills.append(local)
                }
                syncCurrentUserInAllUsers()
                return
            }
        }
        switch kind {
        case .teach: currentUser.mySkills.append(skill)
        case .want: currentUser.wantSkills.append(skill)
        }
        syncCurrentUserInAllUsers()
    }

    func removeSkill(kind: SkillKind, at offsets: IndexSet) async {
        let skills = kind == .teach ? currentUser.mySkills : currentUser.wantSkills
        let removedIDs = offsets.compactMap { skills.indices.contains($0) ? skills[$0].id.serverIDString : nil }
        if isServerMode {
            for serverID in removedIDs {
                try? await APIClient.shared.removeSkill(kind: kind == .teach ? "teach" : "want", id: serverID)
            }
        }
        switch kind {
        case .teach: currentUser.mySkills.remove(atOffsets: offsets)
        case .want: currentUser.wantSkills.remove(atOffsets: offsets)
        }
        syncCurrentUserInAllUsers()
    }

    // MARK: - 互换动态（方案 2.3.6 动态区风控）

    /// 我的动态历史（个人发布过的全部动态）
    func myDynamics() -> [DynamicModel] {
        guard let myID = serverUserID else { return [] }
        return dynamics.filter { $0.userId?.serverIDString == myID }
    }

    /// 删除自己的动态
    func deleteDynamic(id: UUID) async {
        guard isServerMode, let serverID = id.serverIDString else { return }
        do {
            try await APIClient.shared.deleteDynamic(id: serverID)
            dynamics.removeAll { $0.id == id }
        } catch {
            print("[store] 删除动态失败: \(error)")
        }
    }

    /// 更新自定义头像（上传已完成后调用）
    func updateAvatar(url: String) async {
        if isServerMode {
            if let user = try? await APIClient.shared.updateProfile(avatarUrl: url) {
                currentUser = UserModel(server: user)
                syncCurrentUserInAllUsers()
                return
            }
        }
        currentUser.avatarUrl = url
        syncCurrentUserInAllUsers()
    }

    /// 未读消息总数（消息 Tab 红点）
    var unreadTotal: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    /// 发布动态（服务端模式：服务端风控，支持图片）
    @discardableResult
    func postDynamic(content: String, imageBase64: String? = nil) async -> MessageSendResult {
        if isServerMode {
            do {
                try await APIClient.shared.postDynamic(content: content, imageBase64: imageBase64)
                dynamics.insert(
                    DynamicModel(
                        authorName: currentUser.userName,
                        avatarSymbol: currentUser.avatarSymbol,
                        content: content,
                        imageBase64: imageBase64,
                        time: Date(),
                        isSystemPost: false
                    ),
                    at: 0
                )
                return .sent
            } catch {
                return .blocked(warning: (error as? LocalizedError)?.errorDescription ?? "发布失败")
            }
        }
        let risk = TradeRiskControlManager.shared.checkProfileText(text: content)
        guard !risk.isIllegal else { return .blocked(warning: risk.warning) }
        dynamics.insert(
            DynamicModel(
                authorName: currentUser.userName,
                avatarSymbol: currentUser.avatarSymbol,
                content: content,
                imageBase64: imageBase64,
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

    // MARK: - 演示数据

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
                skill("日语", .beginner, .online, "工作日晚上"),
                skill("摄影", .beginner, .both, "周末")
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
            ChatMessage(senderIsMe: false, text: "⚠️ 该消息含违禁词：价格，已被平台风控拦截。技遇仅支持纯技能无偿互换。", time: Date(timeIntervalSinceNow: -86400 + 300), isSystemNote: true),
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
