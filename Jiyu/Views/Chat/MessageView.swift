import SwiftUI

/// 消息列表（方案 2.3.3 线上交换：内置 IM）
struct MessageView: View {
    @EnvironmentObject private var store: MockDataStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if store.conversations.isEmpty {
                    EmptyStateView(
                        icon: "message",
                        title: "暂无会话",
                        message: "在「技能匹配」中发起互换邀约，即可与匹配伙伴建立会话"
                    )
                } else {
                    ForEach(store.conversations) { convo in
                        NavigationLink(destination: ChatDetailView(conversation: convo)) {
                            conversationRow(convo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if store.isServerMode {
                try? await store.refreshAll()
            }
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        HStack(spacing: 12) {
            AvatarView(user: convo.partner, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(convo.partner.userName)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(Formatters.timeText(convo.lastTime))
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(convo.lastMessageText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            if convo.unreadCount > 0 {
                Text("\(convo.unreadCount)")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(Theme.danger))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider, lineWidth: 1))
    }
}

/// 聊天详情（线上交换 IM，方案 2.3.3）
/// - 从消息列表进入：直接使用已有会话
/// - 从匹配详情进入：先创建/获取会话，再加载历史消息
/// - 发送消息：服务端模式走 Socket.io 实时发送（服务端风控），演示模式本地风控
struct ChatDetailView: View {
    @EnvironmentObject private var store: MockDataStore

    /// 已有会话（消息列表进入）
    private let initialConversation: Conversation?
    /// 匹配详情进入（按伙伴创建/获取会话）
    private let partner: UserModel?

    @State private var conversation: Conversation?
    @State private var inputText = ""
    @State private var blockedBanner: String?
    @State private var isLoading = true
    @FocusState private var inputFocused: Bool

    init(conversation: Conversation) {
        self.initialConversation = conversation
        self.partner = nil
    }

    init(partner: UserModel) {
        self.initialConversation = nil
        self.partner = partner
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("正在加载会话…")
                Spacer()
            } else if let conversation {
                messagesList(conversation)
                if let blockedBanner {
                    blockedBannerView(blockedBanner)
                }
                inputBar(conversation)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Text("无法创建会话，请检查网络后重试")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Button("重试") {
                        Task {
                            isLoading = true
                            await loadConversation()
                        }
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.primary))
                }
                Spacer()
            }
        }
        .background(Theme.bg)
        .navigationTitle(conversation?.partner.userName ?? initialConversation?.partner.userName ?? partner?.userName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConversation()
        }
    }

    // MARK: - 加载

    private func loadConversation() async {
        defer { isLoading = false }
        if let initialConversation {
            conversation = initialConversation
        } else if let partner {
            conversation = await store.openConversation(with: partner)
        }
        if let conversation {
            store.markConversationRead(conversation.id)
            await store.loadMessages(conversationID: conversation.id)
        }
    }

    // MARK: - 视图

    private func messagesList(_ conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.messages(for: conversation.id)) { message in
                        messageBubble(message)
                    }
                }
                .padding(12)
            }
            .onAppear {
                scrollToBottom(proxy, conversation: conversation)
            }
            .onChange(of: store.messages(for: conversation.id).count) { _ in
                scrollToBottom(proxy, conversation: conversation)
            }
        }
    }

    private func blockedBannerView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.caption2)
                .foregroundStyle(Theme.warning)
            Spacer()
            Button {
                self.blockedBanner = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.warning.opacity(0.12)))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func inputBar(_ conversation: Conversation) -> some View {
        HStack(spacing: 10) {
            TextField("发送消息（严禁金钱交易内容）", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemGray6)))
                .focused($inputFocused)
            Button {
                send(conversation)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Theme.primary.opacity(0.4) : Theme.primary
                    ))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
        .background(Theme.cardBg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.senderIsMe {
                Spacer(minLength: 70)
            }
            if message.isSystemNote {
                Text(message.text)
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.warning.opacity(0.10)))
            } else {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.senderIsMe ? .white : Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(message.senderIsMe ? Theme.primary : Theme.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(message.senderIsMe ? Color.clear : Theme.divider, lineWidth: 1))
            }
            if !message.senderIsMe {
                Spacer(minLength: 70)
            }
        }
    }

    // MARK: - 发送

    private func send(_ conversation: Conversation) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            let result = await store.sendMessage(conversationID: conversation.id, text: text)
            switch result {
            case .blocked(let warning), .failed(let warning):
                blockedBanner = warning
            case .sent:
                break
            }
            if store.isServerMode {
                await store.loadMessages(conversationID: conversation.id)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, conversation: Conversation) {
        let list = store.messages(for: conversation.id)
        if let last = list.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
