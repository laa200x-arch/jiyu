import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

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
    @State private var editorID = 0
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var playingItem: IdentifiableURL?
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
        .fullScreenCover(item: $playingItem) { item in
            VideoPlayerView(url: item.url)
                .ignoresSafeArea()
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
        HStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isUploading ? Theme.textSecondary : Theme.primary)
            }
            .disabled(isUploading)
            TextField("发送消息（严禁金钱交易内容）", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemGray6)))
                .focused($inputFocused)
                .id(editorID) // 发送后强制重建输入框，修复多行输入框清空不生效的问题
            Button {
                send(conversation)
            } label: {
                if isUploading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.primary.opacity(0.4) : Theme.primary
                        ))
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
        }
        .padding(10)
        .background(Theme.cardBg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
        .onChange(of: pickerItem) { _ in
            handleMediaSelection(conversation)
        }
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
                VStack(alignment: message.senderIsMe ? .trailing : .leading, spacing: 6) {
                    if let mediaType = message.mediaType, let mediaUrl = message.mediaUrl {
                        mediaBubble(mediaType: mediaType, mediaUrl: mediaUrl)
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.subheadline)
                            .foregroundStyle(message.senderIsMe ? .white : Theme.textPrimary)
                    }
                }
                .padding(message.text.isEmpty ? 2 : 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(message.senderIsMe ? Theme.primary : Theme.cardBg)
                )
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(message.senderIsMe ? Color.clear : Theme.divider, lineWidth: 1))
            }
            if !message.senderIsMe {
                Spacer(minLength: 70)
            }
        }
    }

    /// 媒体消息气泡（图片显示 / 视频点击播放）
    @ViewBuilder
    private func mediaBubble(mediaType: String, mediaUrl: String) -> some View {
        if let url = URL(string: AppConfig.serverBase + mediaUrl) {
            if mediaType == "image" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                            .frame(width: 120, height: 90)
                    } else {
                        ProgressView()
                            .frame(width: 120, height: 90)
                    }
                }
                .frame(maxWidth: 190)
            } else if mediaType == "video" {
                Button {
                    playingItem = IdentifiableURL(url: url)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 190, height: 110)
                        VStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                            Text("点击播放视频")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 发送

    private func send(_ conversation: Conversation) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        inputText = ""
        editorID += 1 // 强制重建输入框，确保文字清空
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

    /// 相册选择 → 上传媒体 → 发送媒体消息
    private func handleMediaSelection(_ conversation: Conversation) {
        guard let pickerItem else { return }
        Task {
            isUploading = true
            defer {
                isUploading = false
                self.pickerItem = nil
            }
            guard let data = try? await pickerItem.loadTransferable(type: Data.self) else {
                blockedBanner = "读取文件失败，请重试"
                return
            }
            let type = pickerItem.supportedContentTypes.first
            let result: MessageSendResult
            if let type, type.conforms(to: .image) {
                // 图片：压缩后上传
                let scaled = downscaleImage(data)
                guard let jpeg = scaled.jpegData(compressionQuality: 0.7) else {
                    blockedBanner = "图片处理失败"
                    return
                }
                guard let url = try? await APIClient.shared.uploadMedia(
                    data: jpeg, fileName: "image.jpg", mimeType: "image/jpeg"
                ) else {
                    blockedBanner = "图片上传失败，请检查网络"
                    return
                }
                result = await store.sendMediaMessage(
                    conversationID: conversation.id, mediaType: "image", mediaUrl: url
                )
            } else {
                // 视频：原样上传（服务端限制 50MB）
                guard let url = try? await APIClient.shared.uploadMedia(
                    data: data, fileName: "video.mp4", mimeType: "video/mp4"
                ) else {
                    blockedBanner = "视频上传失败，请检查网络或文件大小"
                    return
                }
                result = await store.sendMediaMessage(
                    conversationID: conversation.id, mediaType: "video", mediaUrl: url
                )
            }
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

    /// 压缩图片至最长边 1280px（控制上传体积）
    private func downscaleImage(_ data: Data) -> UIImage {
        guard let image = UIImage(data: data) else { return UIImage() }
        let maxSide: CGFloat = 1280
        let size = image.size
        guard max(size.width, size.height) > maxSide else { return image }
        let scale = maxSide / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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

/// 视频播放器包装（AVKit）
private struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// 可播放 URL（fullScreenCover item 需要 Identifiable）
private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
