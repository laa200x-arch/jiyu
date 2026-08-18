import SwiftUI
import PhotosUI

/// 个人中心（方案 2.3.1/2.3.5/3.1）
/// 技能档案 / 认证 / 信用分 / 曝光服务 / 我的互换（协议+评价入口）/ 我的动态 / 协议与风控规则
struct MineView: View {
    @EnvironmentObject private var store: MockDataStore
    @EnvironmentObject private var appState: AppState

    @State private var showEdit = false
    @State private var showProfile = false
    @State private var showExposure = false
    @State private var showProtocol = false
    @State private var showRules = false
    @State private var showMyDynamics = false
    @State private var showMyEvaluations = false
    @State private var showEvaluate: ExchangeRecord?
    @State private var showLogoutConfirm = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @AppStorage("jiyu.syncHistory") private var syncHistory = true

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileHeader
                skillsDualCard
                exposureCard
                exchangeSection
                settingsSection
                toolsSection
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) { ProfileEditView() }
        .sheet(isPresented: $showProfile) { NavigationStack { UserProfileView(user: store.currentUser) } }
        .sheet(isPresented: $showExposure) { ExposureView() }
        .sheet(isPresented: $showProtocol) { ProtocolReadView() }
        .sheet(isPresented: $showRules) { RiskRulesView() }
        .sheet(isPresented: $showMyDynamics) { MyDynamicsView() }
        .sheet(isPresented: $showMyEvaluations) { ReceivedEvaluationsView() }
        .sheet(item: $showEvaluate) { record in
            EvaluateView(record: record)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 头部

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: store.currentUser, size: 62)
                    // 自定义头像（相机图标按钮 → 相册选择 → 上传）
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        if isUploadingAvatar {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Theme.primary))
                        }
                    }
                    .disabled(isUploadingAvatar)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(store.currentUser.userName)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(Theme.textPrimary)
                        if store.currentUser.isExposureVip {
                            Label("曝光会员", systemImage: "crown.fill")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(Theme.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.secondary.opacity(0.14)))
                        }
                    }
                    Text("@\(store.currentUser.userName)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                creditRing
            }

            HStack(spacing: 10) {
                Button { showEdit = true } label: {
                    Label("编辑资料", systemImage: "pencil")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.primary))
                }
                Button { showProfile = true } label: {
                    Label("查看主页", systemImage: "person")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(Theme.primary, lineWidth: 1.2))
                }
            }

            HStack(spacing: 8) {
                verificationButton(.student, label: "学生认证")
                verificationButton(.realname, label: "实名认证")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
        .onChange(of: avatarItem) { _ in
            handleAvatarSelection()
        }
    }

    /// 相册选择头像 → 压缩上传 → 更新资料
    private func handleAvatarSelection() {
        guard let avatarItem else { return }
        Task {
            isUploadingAvatar = true
            defer {
                isUploadingAvatar = false
                self.avatarItem = nil
            }
            guard let data = try? await avatarItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = downscaledJPEG(image) else {
                alertTitle = "提示"
                alertMessage = "头像读取失败，请重试"
                showAlert = true
                return
            }
            guard let url = try? await APIClient.shared.uploadMedia(
                data: jpeg, fileName: "avatar.jpg", mimeType: "image/jpeg"
            ) else {
                alertTitle = "提示"
                alertMessage = "头像上传失败，请检查网络"
                showAlert = true
                return
            }
            await store.updateAvatar(url: url)
            alertTitle = "成功"
            alertMessage = "头像已更新"
            showAlert = true
        }
    }

    /// 压缩图片至最长边 512px 并转 JPEG（头像）
    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 512
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
        return target.jpegData(compressionQuality: 0.8)
    }

    private var creditRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.divider, lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(CGFloat(store.currentUser.creditScore) / 100, 1))
                .stroke(Theme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(store.currentUser.creditScore))")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Text("信用分")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private func verificationButton(_ verification: UserVerification, label: String) -> some View {
        let active = store.currentUser.verification == verification
            || store.currentUser.verification == .full
        return Button {
            if active {
                alertTitle = "提示"
                alertMessage = "你已完成\(label)"
                showAlert = true
            } else {
                Task {
                    await store.setVerification(verification)
                }
                alertTitle = "认证成功"
                alertMessage = "已通过\(label)\n认证档案将提升匹配可信度"
                showAlert = true
            }
        } label: {
            Text(active ? "✓ \(label)" : label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(active ? Theme.success : Theme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Theme.success.opacity(0.12) : Theme.primary.opacity(0.10)))
        }
    }

    // MARK: - 技能档案

    /// 技能双卡（我擅长 | 我想学，左右分栏）
    private var skillsDualCard: some View {
        HStack(alignment: .top, spacing: 0) {
            skillHalf(title: "我擅长", subtitle: "（用于教他人）", icon: "video.fill",
                      skills: store.currentUser.mySkills, accent: Theme.primary)
            Divider()
                .frame(height: 110)
                .padding(.horizontal, 12)
            skillHalf(title: "我想学", subtitle: "（用于匹配）", icon: "paintpalette.fill",
                      skills: store.currentUser.wantSkills, accent: Theme.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func skillHalf(title: String, subtitle: String, icon: String, skills: [SkillModel], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("编辑") { showEdit = true }
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accent))
                if let first = skills.first {
                    Text("\(first.skillName) · \(levelText(first.skillLevel))")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text("尚未添加")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if skills.isEmpty {
                Text("去「编辑」完善技能档案")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(skills.map { $0.skillName }.joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func levelText(_ level: SkillLevel) -> String {
        switch level {
        case .beginner: return "Beginner"
        case .skilled: return "熟练"
        case .master: return "精通"
        }
    }

    private func skillSection(title: String, skills: [SkillModel], action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("管理", action: action)
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }
            if skills.isEmpty {
                Text("还没有添加技能，点击「管理」完善档案，匹配率更高")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                    ForEach(skills) { skill in
                        SkillTagView(skill: skill)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    // MARK: - 曝光服务（方案 3.1 盈利模块）

    private var exposureCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.currentUser.isExposureVip ? "crown.fill" : "crown")
                .font(.system(size: 22))
                .foregroundStyle(Theme.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.currentUser.isExposureVip ? "曝光已生效" : "技能曝光服务")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Text(store.currentUser.isExposureVip
                     ? "置顶加权进行中 · \(store.currentExposurePackage?.name ?? "")"
                     : "主页置顶 + 精准匹配加权，不影响纯公益属性")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button(store.currentUser.isExposureVip ? "管理" : "开通") {
                showExposure = true
            }
            .font(.caption)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.secondary))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.secondary.opacity(0.35), lineWidth: 1))
    }

    // MARK: - 我的互换（协议 + 评价）

    private var exchangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我的互换")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("官方协议") { showProtocol = true }
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }

            if store.exchangeRecords.isEmpty {
                Text("暂无互换记录，去「技能匹配」发起第一次互换吧")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(store.exchangeRecords) { record in
                    exchangeRow(record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func exchangeRow(_ record: ExchangeRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(record.mySkillName) ↔ \(record.learnSkillName)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Label(record.status.rawValue, systemImage: record.status.systemImage)
                    .font(.caption2)
                    .foregroundStyle(statusColor(record.status))
            }
            HStack(spacing: 10) {
                Label(record.partner.userName, systemImage: "person")
                Label(record.scheduledTime, systemImage: "calendar")
                if let location = record.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                } else {
                    Label("线上", systemImage: "video")
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)

            HStack {
                Spacer()
                if record.status == .completed {
                    if record.evaluateGiven {
                        Label("已评价", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.success)
                    } else {
                        Button("去评价") { showEvaluate = record }
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.primary))
                    }
                } else if record.status == .pending || record.status == .ongoing {
                    Button("标记完成") {
                        Task {
                            await store.completeExchange(recordID: record.id)
                        }
                    }
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.primary.opacity(0.10)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))
    }

    private func statusColor(_ status: ExchangeStatus) -> Color {
        switch status {
        case .pending: return Theme.warning
        case .ongoing: return Theme.primary
        case .completed: return Theme.success
        case .cancelled: return Theme.danger
        }
    }

    // MARK: - 设置（聊天记录同步）

    private var settingsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.primary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("聊天记录同步")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("不同设备登录同一账号可同步历史聊天；关闭后仅显示新消息")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $syncHistory)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    // MARK: - 工具

    private var toolsSection: some View {
        VStack(spacing: 0) {
            toolRow(icon: "doc.text", title: "官方互换协议") { showProtocol = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "exclamationmark.shield.fill", title: "风控规则（零金钱交易）") { showRules = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "square.and.pencil", title: "我的动态（历史）") { showMyDynamics = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "star.fill", title: "收到的评价") { showMyEvaluations = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "info.circle", title: "关于技遇") {
                alertTitle = "关于技遇"
                alertMessage = "技遇 —— 纯公益、无金钱交易的技能互换平台。以技能换技能，用自己的特长兑换他人专长，零成本提升自我。"
                showAlert = true
            }
            Divider().padding(.leading, 40)
            toolRow(icon: "arrow.left.arrow.right.circle", title: "切换账号 / 退出登录") {
                showLogoutConfirm = true
            }
        }
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
        .confirmationDialog("退出当前账号？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("退出登录（\(store.currentUser.userName)）", role: .destructive) {
                appState.logout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后将返回登录页，可选择其他账号登录")
        }
    }

    private func toolRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 官方协议只读视图
struct ProtocolReadView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(AgreementManager.agreementTemplate)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("官方互换协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

/// 风控规则说明
struct RiskRulesView: View {
    @Environment(\.dismiss) private var dismiss

    private let rules = """
    技遇零金钱交易风控规则
    ─────────────────────
    1. 平台全程禁止任何金钱、物资、有偿交易，禁止出现收费、付费、转账、红包、接单、有偿等违禁词。
    2. 个人主页、动态、私聊内容均经过文本 AI 风控自动拦截；转账截图、价格海报、付费二维码等图片将被屏蔽并警告。
    3. 平台人工巡检私聊与动态区，杜绝隐性交易。
    4. 违规处罚：首次警告 → 二次限流 → 三次永久封禁。
    5. 敷衍教学、无故爽约、诱导交易可发起投诉，平台人工审核并扣减信用分。
    """

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(rules)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("风控规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
