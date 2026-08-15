import SwiftUI

/// 个人中心（方案 2.3.1/2.3.5/3.1）
/// 技能档案 / 认证 / 信用分 / 曝光服务 / 我的互换（协议+评价入口）/ 协议与风控规则
struct MineView: View {
    @EnvironmentObject private var store: MockDataStore

    @State private var showEdit = false
    @State private var showExposure = false
    @State private var showProtocol = false
    @State private var showRules = false
    @State private var showEvaluate: ExchangeRecord?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileHeader
                skillSection(title: "我擅长", skills: store.currentUser.mySkills, action: { showEdit = true })
                skillSection(title: "我想学", skills: store.currentUser.wantSkills, action: { showEdit = true })
                exposureCard
                exchangeSection
                toolsSection
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) { ProfileEditView() }
        .sheet(isPresented: $showExposure) { ExposureView() }
        .sheet(isPresented: $showProtocol) { ProtocolReadView() }
        .sheet(isPresented: $showRules) { RiskRulesView() }
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
                AvatarView(user: store.currentUser, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(store.currentUser.userName)
                            .font(.title3)
                            .bold()
                            .foregroundStyle(Theme.textPrimary)
                        if store.currentUser.isExposureVip {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    Text(store.currentUser.bio)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(store.currentUser.locationLabel)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                creditRing
            }

            HStack(spacing: 8) {
                verificationButton(.student, label: "学生认证")
                verificationButton(.realname, label: "实名认证")
                if store.currentUser.verification != .none {
                    Label(store.currentUser.verification.rawValue, systemImage: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
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
                store.setVerification(verification)
                alertTitle = "认证成功"
                alertMessage = "已通过\(label)（模拟）\n认证档案将提升匹配可信度"
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
                    Button("标记完成") { store.completeExchange(recordID: record.id) }
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

    // MARK: - 工具

    private var toolsSection: some View {
        VStack(spacing: 0) {
            toolRow(icon: "doc.text", title: "官方互换协议") { showProtocol = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "exclamationmark.shield.fill", title: "风控规则（零金钱交易）") { showRules = true }
            Divider().padding(.leading, 40)
            toolRow(icon: "info.circle", title: "关于技遇") {
                alertTitle = "关于技遇"
                alertMessage = "技遇 —— 纯公益、无金钱交易的技能互换平台。以技能换技能，用自己的特长兑换他人专长，零成本提升自我。"
                showAlert = true
            }
        }
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
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
