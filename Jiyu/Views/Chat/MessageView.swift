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
/// 消息发送前置风控：命中金钱交易词 → 拦截 + 系统提示
struct ChatDetailView: View {
    @EnvironmentObject private var store: MockDataStore
    let conversation: Conversation

    @State private var inputText = ""
    @State private var blockedBanner: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
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
                    store.markConversationRead(conversation.id)
                    scrollToBottom(proxy)
                }
                .onChange(of: store.messages(for: conversation.id).count) { _ in
                    scrollToBottom(proxy)
                }
            }

            if let blockedBanner {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(Theme.warning)
                    Text(blockedBanner)
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

            inputBar
        }
        .background(Theme.bg)
        .navigationTitle(conversation.partner.userName)
        .navigationBarTitleDisplayMode(.inline)
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

    private var inputBar: some View {
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
                send()
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

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let result = store.sendMessage(conversationID: conversation.id, text: text)
        inputText = ""
        if case .blocked(let warning) = result {
            blockedBanner = warning
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        let list = store.messages(for: conversation.id)
        if let last = list.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
