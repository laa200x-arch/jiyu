import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import AVFoundation

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
    @State private var viewingImageItem: IdentifiableURL?
    // 拍照
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showPhotoConfirm = false
    // 语音
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingAudioURL: URL?
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
        .fullScreenCover(item: $viewingImageItem) { item in
            ImageViewer(url: item.url)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                capturedImage = image
                showPhotoConfirm = true
            }
            .ignoresSafeArea()
        }
        .overlay {
            if showPhotoConfirm, let capturedImage {
                photoConfirmView(capturedImage)
            }
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
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundStyle(isUploading ? Theme.textSecondary : Theme.primary)
            }
            .disabled(isUploading)
            Menu {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                Button {
                    toggleRecording()
                } label: {
                    Label(isRecording ? "停止录音并发送" : "语音消息", systemImage: "mic.fill")
                }
            } label: {
                Image(systemName: isRecording ? "stop.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isRecording ? Theme.danger : Theme.primary)
            }
            .disabled(isUploading)
            if isRecording {
                HStack(spacing: 5) {
                    Circle().fill(Theme.danger).frame(width: 8, height: 8)
                    Text("录音中")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.danger.opacity(0.10)))
            }
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

    /// 媒体消息气泡（图片点击放大 / 视频点击播放 / 语音点击播放）
    @ViewBuilder
    private func mediaBubble(mediaType: String, mediaUrl: String) -> some View {
        if let url = URL(string: AppConfig.serverBase + mediaUrl) {
            if mediaType == "image" {
                Button {
                    viewingImageItem = IdentifiableURL(url: url)
                } label: {
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
                }
                .buttonStyle(.plain)
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
            } else if mediaType == "audio" {
                Button {
                    toggleAudioPlay(url: url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: playingAudioURL == url ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
                        Text("语音消息")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.85))
                    )
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

    // MARK: - 语音消息

    /// 点击语音按钮：未录音则开始录音，录音中则停止并发送
    private func toggleRecording() {
        if isRecording {
            stopAndSendRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            audioRecorder = recorder
            isRecording = true
        } catch {
            blockedBanner = "无法开始录音，请检查麦克风权限"
        }
    }

    private func stopAndSendRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        let url = recorder.url
        Task {
            guard let conversation else { return }
            guard let data = try? Data(contentsOf: url) else {
                blockedBanner = "录音读取失败"
                return
            }
            isUploading = true
            defer { isUploading = false }
            guard let mediaURL = try? await APIClient.shared.uploadMedia(
                data: data, fileName: "voice.m4a", mimeType: "audio/mp4"
            ) else {
                blockedBanner = "语音上传失败，请检查网络"
                return
            }
            let result = await store.sendMediaMessage(
                conversationID: conversation.id, mediaType: "audio", mediaUrl: mediaURL
            )
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

    /// 播放/停止语音（AVAudioPlayer 需本地数据，先下载）
    private func toggleAudioPlay(url: URL) {
        if playingAudioURL == url, let player = audioPlayer, player.isPlaying {
            player.stop()
            playingAudioURL = nil
            audioPlayer = nil
            return
        }
        Task {
            guard let data = try? Data(contentsOf: url) else {
                blockedBanner = "语音加载失败"
                return
            }
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            if let player = try? AVAudioPlayer(data: data) {
                audioPlayer?.stop()
                player.play()
                audioPlayer = player
                playingAudioURL = url
            } else {
                blockedBanner = "语音播放失败"
            }
        }
    }

    // MARK: - 拍照发送（发送前确认）

    private func photoConfirmView(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                Text("确认发送这张照片？")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 14) {
                    Button {
                        capturedImage = nil
                        showPhotoConfirm = false
                        showCamera = true // 重拍
                    } label: {
                        Text("重拍")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                    Button {
                        sendCapturedPhoto()
                    } label: {
                        Text("发送")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Theme.primary))
                    }
                }
                .padding(.horizontal, 20)
                Button {
                    capturedImage = nil
                    showPhotoConfirm = false
                } label: {
                    Text("取消")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
        }
    }

    private func sendCapturedPhoto() {
        guard let image = capturedImage else { return }
        capturedImage = nil
        showPhotoConfirm = false
        Task {
            guard let conversation else { return }
            guard let jpeg = downscaledJPEG(image) else {
                blockedBanner = "照片处理失败"
                return
            }
            isUploading = true
            defer { isUploading = false }
            guard let mediaURL = try? await APIClient.shared.uploadMedia(
                data: jpeg, fileName: "photo.jpg", mimeType: "image/jpeg"
            ) else {
                blockedBanner = "照片上传失败，请检查网络"
                return
            }
            let result = await store.sendMediaMessage(
                conversationID: conversation.id, mediaType: "image", mediaUrl: mediaURL
            )
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

    /// 压缩图片至最长边 1280px 并转 JPEG（控制上传体积）
    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1280
        let size = image.size
        var target = image
        if max(size.width, size.height) > maxSide {
            let scale = maxSide / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            target = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return target.jpegData(compressionQuality: 0.7)
    }

    /// 压缩图片至最长边 1280px（相册图片）
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

/// 视频播放器包装（AVKit，进入即自动播放）
private struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
        controller.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// 相机拍照（UIImagePickerController 包装）
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

/// 全屏图片查看器（黑底 + 捏合缩放 + 关闭）
private struct ImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                        )
                } else if phase.error != nil {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("图片加载失败")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

/// 可播放 URL（fullScreenCover item 需要 Identifiable）
private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
