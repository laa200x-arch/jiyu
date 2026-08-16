import Foundation
import SocketIO

/// 实时消息客户端（方案 4.1：Socket.io）
/// - 连接鉴权：connectPayload + connectParams 双通道（服务端兼容两种）
/// - chat:message 事件 → onMessage 回调（主线程派发）
/// - chat:send 发送消息，ack 返回服务端风控结果
final class RealtimeClient {
    static let shared = RealtimeClient()

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    struct SocketMessagePayload {
        let id: String
        let conversationId: String
        let text: String
        let mediaType: String?
        let mediaUrl: String?
        let orderId: String?
        let time: Date
        let senderId: String
    }

    /// 收到新消息（服务端 chat:message 广播）
    var onMessage: ((SocketMessagePayload) -> Void)?

    /// 收到互换邀约推送（服务端 match:push，参数：对方昵称、消息内容）
    var onMatchPush: ((String, String) -> Void)?

    var isConnected: Bool { socket?.status == .connected }

    private init() {}

    func connect(token: String) {
        disconnect()
        let newManager = SocketIO.SocketManager(
            socketURL: AppConfig.serverURL,
            config: [.log(false), .compress, .connectParams(["token": token])]
        )
        let newSocket = newManager.defaultSocket

        newSocket.on(clientEvent: .connect) { [weak self] _, _ in
            print("[realtime] 已连接")
            self?.handleConnect()
        }
        newSocket.on(clientEvent: .disconnect) { _, _ in
            print("[realtime] 已断开")
        }
        newSocket.on("chat:message") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            self?.handleIncoming(payload)
        }
        newSocket.on("match:push") { [weak self] data, _ in
            guard let payload = data.first as? [String: Any] else { return }
            let from = (payload["from"] as? [String: Any])?["userName"] as? String ?? "技遇"
            let message = payload["message"] as? String ?? "你收到一条新的互换邀约"
            DispatchQueue.main.async {
                self?.onMatchPush?(from, message)
            }
        }
        newSocket.connect(withPayload: ["token": token])

        manager = newManager
        socket = newSocket
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
    }

    /// 发送消息（服务端同 REST 风控），completion(ok, blocked, warning)
    /// orderId：引用宠物护理订单卡片（可空）
    func send(conversationId: String, text: String, orderId: String? = nil, completion: @escaping (Bool, Bool, String?) -> Void) {
        guard let socket, socket.status == .connected else {
            completion(false, false, "实时通道未连接")
            return
        }
        var payload: [String: Any] = ["conversationId": conversationId, "text": text]
        if let orderId { payload["orderId"] = orderId }
        socket.emitWithAck("chat:send", payload)
            .timingOut(after: 5) { data in
                let ack = data.first as? [String: Any]
                let ok = ack?["ok"] as? Bool ?? false
                let blocked = ack?["blocked"] as? Bool ?? false
                let warning = ack?["warning"] as? String
                completion(ok, blocked, warning)
            }
    }

    // MARK: - 私有

    private func handleConnect() {
        // 连接成功后可在此刷新未读数等
    }

    private func handleIncoming(_ payload: [String: Any]) {
        guard
            let id = payload["id"] as? String,
            let conversationId = payload["conversationId"] as? String,
            let text = payload["text"] as? String,
            let senderId = payload["senderId"] as? String
        else { return }
        let time = (payload["time"] as? String).flatMap { APIClient.parseDate($0) } ?? Date()
        let message = SocketMessagePayload(
            id: id,
            conversationId: conversationId,
            text: text,
            mediaType: payload["mediaType"] as? String,
            mediaUrl: payload["mediaUrl"] as? String,
            orderId: payload["orderId"] as? String,
            time: time,
            senderId: senderId
        )
        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(message)
        }
    }
}
