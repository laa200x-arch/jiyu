import Foundation

/// 后端 API 错误
enum APIError: LocalizedError, Equatable {
    case server(message: String)
    case network
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .network: return "网络连接失败，请检查网络或服务器状态"
        case .unauthorized: return "登录已过期，请重新登录"
        }
    }
}

/// 后端 API 客户端（方案 4.1：Express 后端，REST）
final class APIClient {
    static let shared = APIClient()

    private let base = AppConfig.serverBase
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    private var token: String? { TokenStore.token }

    // MARK: - JSON 解码（ISO8601 含/不含毫秒）

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: raw) ?? plain.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "无法解析日期: \(raw)"
            ))
        }
        return decoder
    }()

    static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return fractional.date(from: string) ?? plain.date(from: string)
    }

    // MARK: - 基础请求

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        query: [String: String]? = nil
    ) async throws -> T {
        var urlString = "\(base)\(path)"
        if let query, !query.isEmpty {
            var components = URLComponents(string: urlString)!
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components.url!.absoluteString
        }
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "请求失败（HTTP \(http.statusCode)）"
            throw APIError.server(message: message)
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    // MARK: - 认证

    func login(username: String, password: String) async throws -> ServerUser {
        let response: TokenResponse = try await request("/api/auth/login", method: "POST",
            body: ["username": username, "password": password])
        TokenStore.token = response.token
        return response.user
    }

    func register(username: String, password: String, nickname: String) async throws -> ServerUser {
        let response: TokenResponse = try await request("/api/auth/register", method: "POST",
            body: ["username": username, "password": password, "nickname": nickname])
        TokenStore.token = response.token
        return response.user
    }

    // MARK: - 用户与匹配

    func fetchMe() async throws -> ServerUser {
        let response: UserResponse = try await request("/api/me")
        return response.user
    }

    func fetchUsers() async throws -> [ServerUser] {
        let response: UsersResponse = try await request("/api/users")
        return response.users
    }

    /// 拉取指定用户最新资料（资料页打开时刷新快照）
    func fetchUser(id: String) async throws -> ServerUser {
        let response: UserResponse = try await request("/api/users/\(id)")
        return response.user
    }

    func fetchMatches(nearbyOnly: Bool = false, type: String? = nil, keyword: String = "") async throws -> [ServerMatch] {
        var query: [String: String] = [:]
        if nearbyOnly { query["nearbyOnly"] = "1" }
        if let type, !type.isEmpty { query["type"] = type }
        if !keyword.isEmpty { query["keyword"] = keyword }
        let response: MatchesResponse = try await request("/api/match", query: query)
        return response.matches
    }

    // MARK: - 聊天

    func fetchConversations() async throws -> [ServerConversation] {
        let response: ConversationsResponse = try await request("/api/conversations")
        return response.conversations
    }

    func openConversation(partnerId: String) async throws -> ServerConversation {
        let response: ConversationResponse = try await request("/api/conversations/open", method: "POST",
            body: ["partnerId": partnerId])
        return response.conversation
    }

    /// 拉取会话历史消息（分页：默认最近 50 条；before 加载更早）
    /// 返回 (消息, 是否还有更早)
    func fetchMessages(conversationId: String, limit: Int = 50, before: String? = nil) async throws -> ([ServerMessage], Bool) {
        var query: [String: String] = ["limit": String(limit)]
        if let before { query["before"] = before }
        let response: MessagesResponse = try await request(
            "/api/conversations/\(conversationId)/messages",
            query: query
        )
        return (response.messages, response.hasMore ?? false)
    }

    func markConversationRead(conversationId: String) async throws {
        let _: OkResponse = try await request("/api/conversations/\(conversationId)/read", method: "POST")
    }

    /// REST 发送消息（Socket 失败时的兜底通道，服务端同一套风控；支持媒体消息）
    func sendMessage(conversationId: String, text: String, mediaType: String? = nil, mediaUrl: String? = nil) async throws -> MessageSendResponse {
        var body: [String: Any] = ["conversationId": conversationId, "text": text]
        if let mediaType { body["mediaType"] = mediaType }
        if let mediaUrl { body["mediaUrl"] = mediaUrl }
        return try await request("/api/messages", method: "POST", body: body)
    }

    /// 上传媒体文件（聊天图片/视频），返回相对路径（如 /uploads/xxx.jpg）
    func uploadMedia(data: Data, fileName: String, mimeType: String) async throws -> String {
        var request = URLRequest(url: URL(string: "\(base)/api/upload")!)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            let message = (try? JSONDecoder().decode([String: String].self, from: responseData))?["error"]
                ?? "上传失败（HTTP \(http.statusCode)）"
            throw APIError.server(message: message)
        }
        struct UploadResponse: Decodable { let url: String }
        return try Self.decoder.decode(UploadResponse.self, from: responseData).url
    }

    // MARK: - 动态

    func fetchDynamics() async throws -> [ServerDynamic] {
        let response: DynamicsResponse = try await request("/api/dynamics")
        return response.dynamics
    }

    func postDynamic(content: String, imageBase64: String? = nil) async throws {
        var body: [String: Any] = ["content": content]
        if let imageBase64 { body["imageBase64"] = imageBase64 }
        let _: OkResponse = try await request("/api/dynamics", method: "POST", body: body)
    }

    // MARK: - 协议与互换

    func fetchAgreements() async throws -> [ServerAgreement] {
        let response: AgreementsResponse = try await request("/api/agreements")
        return response.agreements
    }

    func signAgreement(
        partnerId: String,
        mySkillName: String,
        learnSkillName: String,
        exchangeType: ExchangeType,
        scheduledTime: String,
        location: String?
    ) async throws -> ServerExchangeRecord {
        var body: [String: Any] = [
            "partnerId": partnerId,
            "mySkillName": mySkillName,
            "learnSkillName": learnSkillName,
            "exchangeType": exchangeType.serverCode,
            "scheduledTime": scheduledTime
        ]
        if let location { body["location"] = location }
        let response: RecordResponse = try await request("/api/agreements", method: "POST", body: body)
        guard let record = response.record else { throw APIError.server(message: "服务器未返回互换记录") }
        return record
    }

    func fetchExchanges() async throws -> [ServerExchangeRecord] {
        let response: RecordsResponse = try await request("/api/exchanges")
        return response.records
    }

    func completeExchange(id: String) async throws {
        let _: OkResponse = try await request("/api/exchanges/\(id)/complete", method: "POST")
    }

    func submitEvaluation(
        recordId: String,
        punctuality: Double,
        serious: Double,
        communication: Double,
        comment: String
    ) async throws -> Double? {
        let response: EvaluationResponse = try await request("/api/evaluations", method: "POST", body: [
            "recordId": recordId,
            "punctuality": punctuality,
            "serious": serious,
            "communication": communication,
            "comment": comment
        ])
        return response.newCreditScore
    }

    // MARK: - 档案

    /// 更新资料（支持自定义头像 URL）
    func updateProfile(bio: String? = nil, avatarUrl: String? = nil) async throws -> ServerUser {
        var body: [String: Any] = [:]
        if let bio { body["bio"] = bio }
        if let avatarUrl { body["avatarUrl"] = avatarUrl }
        let response: UserResponse = try await request("/api/me/profile", method: "PUT", body: body)
        return response.user
    }

    func deleteDynamic(id: String) async throws {
        let _: OkResponse = try await request("/api/dynamics/delete", method: "POST", body: ["id": id])
    }
    func setVerification(_ verification: UserVerification) async throws -> ServerUser {
        let response: UserResponse = try await request("/api/me/verification", method: "PUT",
            body: ["verification": verification.serverCode])
        return response.user
    }

    func applyExposure(packageId: String) async throws -> ServerUser {
        let response: UserResponse = try await request("/api/me/exposure", method: "PUT",
            body: ["packageId": packageId])
        return response.user
    }

    func cancelExposure() async throws -> ServerUser {
        let response: UserResponse = try await request("/api/me/exposure", method: "DELETE")
        return response.user
    }

    func addSkill(kind: String, skill: SkillModel) async throws -> ServerSkill {
        let response: SkillResponse = try await request("/api/me/skills", method: "POST", body: [
            "kind": kind,
            "skill": [
                "skillName": skill.skillName,
                "skillLevel": skill.skillLevel.serverCode,
                "exchangeType": skill.exchangeType.serverCode,
                "availableTime": skill.availableTime
            ]
        ])
        guard let serverSkill = response.skill else { throw APIError.server(message: "服务器未返回技能") }
        return serverSkill
    }

    func removeSkill(kind: String, id: String) async throws {
        let _: OkResponse = try await request("/api/me/skills/\(kind)/\(id)", method: "DELETE")
    }

    // MARK: - 宠物护理域（旧巡六迁移）

    func fetchCareServices() async throws -> ([ServerCareService], CareOptions) {
        let response: CareServicesResponse = try await request("/api/care-services")
        return (response.services, response.options)
    }

    func fetchPets() async throws -> [ServerPet] {
        let response: PetsResponse = try await request("/api/pets")
        return response.pets
    }

    func addPet(_ body: [String: Any]) async throws -> ServerPet {
        let response: PetResponse = try await request("/api/pets", method: "POST", body: body)
        return response.pet
    }

    func deletePet(id: String) async throws {
        let _: OkResponse = try await request("/api/pets/\(id)", method: "DELETE")
    }

    func fetchBookings() async throws -> [ServerBooking] {
        let response: BookingsResponse = try await request("/api/bookings")
        return response.bookings
    }

    func createBooking(_ body: [String: Any]) async throws {
        let _: OkResponse = try await request("/api/bookings", method: "POST", body: body)
    }

    func completeBooking(id: String) async throws {
        let _: OkResponse = try await request("/api/bookings/\(id)/complete", method: "POST")
    }

    /// 接单（动态区订单；服务端校验信用 ≥75 且已完成认证）
    func acceptBooking(id: String) async throws {
        let _: OkResponse = try await request("/api/bookings/\(id)/accept", method: "POST")
    }

    // MARK: - 版本检查

    func fetchVersion() async throws -> ServerVersion {
        try await request("/api/version")
    }
}
