import SwiftUI
import PhotosUI

/// 互换动态（方案 2.3.3/2.3.6）
/// 动态区同样受文本风控：发布含金钱交易词的内容会被拦截；支持上传本地图片
struct ExchangeDynamicView: View {
    @EnvironmentObject private var store: MockDataStore

    @State private var showCompose = false
    @State private var draft = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageBase64: String?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.dynamics) { item in
                    dynamicCard(item)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("互换动态")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if store.isServerMode {
                try? await store.refreshAll()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        if store.isServerMode {
                            try? await store.refreshAll()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            composeSheet
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func dynamicCard(_ item: DynamicModel) -> some View {
        let card = HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.isSystemPost
                          ? AnyShapeStyle(Theme.secondary.opacity(0.25))
                          : AnyShapeStyle(Theme.gradient))
                    .frame(width: 42, height: 42)
                Image(systemName: item.avatarSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(item.isSystemPost ? Theme.secondary : .white)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.authorName)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    if !item.isSystemPost {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    }
                    Spacer()
                    Text(Formatters.timeText(item.time))
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(item.content)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                if let imageBase64 = item.imageBase64,
                   let imageData = Data(base64Encoded: imageBase64),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if item.orderId != nil {
                    NavigationLink(destination: OrderDetailView(orderId: item.orderId!)) {
                        orderBlock(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))

        // 非系统动态：点击查看作者资料（支持私聊）；订单卡片含交互按钮，不整体跳转
        if item.isSystemPost || item.orderId != nil {
            return AnyView(card)
        }
        if let author = author(of: item) {
            return AnyView(
                NavigationLink(destination: UserProfileView(user: author)) {
                    card
                }
                .buttonStyle(.plain)
            )
        }
        return AnyView(card)
    }

    // MARK: 宠物护理订单卡片（动态区：接单申请入口）

    private func orderBlock(_ item: DynamicModel) -> some View {
        let isOwn = item.userId == store.currentUser.id
        let isOpen = item.orderStatus == "open"
        let qualified = store.currentUser.verification != .none
        let myApp = item.myApplicationStatus
        let appCount = item.applicationCount ?? 0
        return HStack(spacing: 12) {
            Text("💰 收费订单 ¥\(yuanText(item.orderPriceYuan ?? 0)) · 佣金 10%")
                .font(.caption)
                .bold()
                .foregroundStyle(Theme.warning)
            if let service = item.orderService {
                Text(service)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if isOpen {
                if isOwn {
                    Text(appCount > 0 ? "等待接单中…（\(appCount) 人申请）" : "等待接单中…")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                } else if myApp == "pending" {
                    Text("⏳ 已申请，等待派单人确认")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(Theme.primary)
                } else if myApp == "rejected" {
                    Text("❌ 申请已被拒绝")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                } else if qualified {
                    Button {
                        applyOrder(item)
                    } label: {
                        Text("接单申请")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.primary))
                    }
                } else {
                    Text("🔒 有资历者接单")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text("已接单")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(Theme.success)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warning.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.35), lineWidth: 1))
    }

    private func yuanText(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    /// 提交接单申请（派单人在私聊/订单详情中确认）
    private func applyOrder(_ item: DynamicModel) {
        guard let orderId = item.orderId else { return }
        Task {
            do {
                try await store.applyBooking(id: orderId)
                alertTitle = "申请已提交"
                alertMessage = "等待派单人确认，可在私聊中与派单人协商；确认后你即为接单人"
                showAlert = true
            } catch {
                alertTitle = "申请失败"
                alertMessage = (error as? LocalizedError)?.errorDescription ?? "请重试"
                showAlert = true
            }
        }
    }

    /// 从用户列表解析动态作者（找不到则返回 nil，卡片不可点击）
    private func author(of item: DynamicModel) -> UserModel? {
        if let userId = item.userId,
           let user = store.allUsers.first(where: { $0.id == userId }) {
            return user
        }
        return store.allUsers.first(where: { $0.userName == item.authorName })
    }

    private var composeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                composeHeader
                composeEditor
                photoPickerRow
                composeWarning
                publishButton
                Spacer()
            }
            .padding(16)
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCompose = false }
                }
            }
            .onChange(of: pickerItem) { _ in
                handlePickerChange()
            }
        }
    }

    private var composeHeader: some View {
        Text("发布动态")
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
    }

    private var composeEditor: some View {
        TextEditor(text: $draft)
            .frame(minHeight: 140)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.divider, lineWidth: 1))
    }

    private var photoPickerRow: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                    Text(selectedImage == nil ? "添加图片" : "更换图片")
                }
                .font(.caption)
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.primary.opacity(0.10)))
            }
            if let selectedImage {
                selectedImageThumb(selectedImage)
                Button {
                    pickerItem = nil
                    self.selectedImage = nil
                    imageBase64 = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func selectedImageThumb(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var composeWarning: some View {
        Label("禁止发布任何收费、交易、接单等商业信息，发布内容将自动经过平台风控审核",
              systemImage: "exclamationmark.shield.fill")
            .font(.caption2)
            .foregroundStyle(Theme.warning)
    }

    private var publishButton: some View {
        Button {
            publish()
        } label: {
            Text("发布")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(
                    draft.trimmingCharacters(in: .whitespaces).isEmpty && selectedImage == nil
                        ? Theme.primary.opacity(0.4) : Theme.primary
                ))
        }
        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty && selectedImage == nil)
    }

    /// 相册选择回调：压缩图片并生成 base64
    private func handlePickerChange() {
        guard let pickerItem else { return }
        Task {
            if let data = try? await pickerItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let scaled = downscale(image)
                selectedImage = scaled
                imageBase64 = scaled.jpegData(compressionQuality: 0.7)?.base64EncodedString()
            }
        }
    }

    /// 压缩图片至最长边 1024px（控制上传体积）
    private func downscale(_ image: UIImage) -> UIImage {
        let maxSide: CGFloat = 1024
        let size = image.size
        guard max(size.width, size.height) > maxSide else { return image }
        let scale = maxSide / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func publish() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || selectedImage != nil else { return }
        Task {
            let result = await store.postDynamic(content: content, imageBase64: imageBase64)
            if case .blocked(let warning) = result {
                alertTitle = "风控拦截"
                alertMessage = warning
                showAlert = true
            } else {
                draft = ""
                pickerItem = nil
                selectedImage = nil
                imageBase64 = nil
                showCompose = false
            }
        }
    }
}
