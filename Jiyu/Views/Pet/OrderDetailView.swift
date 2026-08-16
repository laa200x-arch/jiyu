import SwiftUI

/// 宠物护理订单详情（动态区订单卡片 / 聊天订单引用 点击进入）
/// 展示：服务与金额结算、状态、宠物信息、下单人/看护人（信用与距离）、服务地点
/// 支持「私聊下单人/看护人」：进入聊天并自动带上订单引用卡片
struct OrderDetailView: View {
    @EnvironmentObject private var store: MockDataStore
    let orderId: String

    @State private var booking: ServerBooking?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let booking {
                detail(booking)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.warning)
                    Text("订单加载失败")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Button("重试") {
                        Task { await load() }
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.primary))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("加载订单…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.bg)
        .navigationTitle("订单详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        loadFailed = false
        if let booking = await store.bookingDetail(id: orderId) {
            self.booking = booking
        } else {
            loadFailed = true
        }
    }

    // MARK: - 详情

    private func detail(_ b: ServerBooking) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                serviceHeader(b)
                amountBlock(b)
                locationBlock(b)
                if let pet = b.pet {
                    infoBlock("🐕 宠物信息") { petInfo(pet) }
                }
                if let initiator = b.initiator {
                    userBlock("👤 下单人", user: initiator, distanceKm: b.distanceKm)
                }
                if let provider = b.provider {
                    userBlock("🧑‍⚕️ 看护人", user: provider, distanceKm: provider.distanceKm)
                } else if b.status == "open" {
                    infoBlock("⏳ 待接单") {
                        Text("信用 ≥75 且完成实名/学生认证的用户可在动态区接单（平台佣金 10%，其余归服务人员）")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                chatButtons(b)
            }
            .padding(16)
        }
    }

    private func serviceHeader(_ b: ServerBooking) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(b.serviceName)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("🕐 \(b.scheduledTime)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(statusName(b.status))
                .font(.caption)
                .bold()
                .foregroundStyle(statusColor(b.status))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func amountBlock(_ b: ServerBooking) -> some View {
        infoBlock("💰 金额结算") {
            Text("服务费 ¥\(yuan(b.priceYuan)) · 平台佣金 ¥\(yuan(b.commissionYuan))（10%） · 服务人员得 ¥\(yuan(b.workerIncome))")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.warning)
        }
    }

    private func locationBlock(_ b: ServerBooking) -> some View {
        infoBlock("📍 服务地点") {
            Text(b.location ?? "线上")
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func infoBlock(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func petInfo(_ pet: ServerPet) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(pet.name)（\(pet.petType == "dog" ? "🐕 狗" : pet.petType == "cat" ? "🐈 猫" : "🐾 其他") · \(pet.breed) · \(pet.ageMonths) 月）")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text("\(pet.neutered ? "已绝育" : "未绝育") · \(pet.gender == "male" ? "公" : "母")\(pet.weightKg != nil ? " · \(String(format: "%.1f", pet.weightKg!))kg" : "")")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if let behaviors = pet.behaviors, !behaviors.isEmpty {
                Text("行为：\(behaviors.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }
            if let reactions = pet.homeReactions, !reactions.isEmpty {
                Text("家中反应：\(reactions.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            if !pet.notes.isEmpty {
                Text("📝 \(pet.notes)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func userBlock(_ title: String, user: BookingUser, distanceKm: Double?) -> some View {
        infoBlock(title) {
            HStack(spacing: 10) {
                AvatarView(
                    user: UserModel(
                        id: UUID(serverID: user.id) ?? UUID(),
                        userName: user.userName,
                        avatarSymbol: user.avatarSymbol,
                        avatarUrl: user.avatarUrl,
                        bio: "",
                        locationLabel: user.locationLabel ?? "",
                        distanceKm: distanceKm,
                        creditScore: user.creditScore,
                        verification: .none,
                        mySkills: [],
                        wantSkills: [],
                        isExposureVip: false
                    ),
                    size: 38
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.userName)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    Text("信用 \(Int(user.creditScore))\(user.locationLabel != nil ? " · \(user.locationLabel!)" : "")\(distanceKm != nil ? " · 距离你约 \(yuan(distanceKm!)) km" : "")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func chatButtons(_ b: ServerBooking) -> some View {
        HStack(spacing: 12) {
            if let initiator = b.initiator, initiator.id != (store.currentUser.id.serverIDString ?? "") {
                chatLink("💬 私聊下单人", user: store.userModel(from: initiator))
            }
            if let provider = b.provider, provider.id != (store.currentUser.id.serverIDString ?? "") {
                chatLink("💬 私聊看护人", user: store.userModel(from: provider))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chatLink(_ title: String, user: UserModel) -> some View {
        NavigationLink {
            ChatDetailView(partner: user)
                .onAppear {
                    // 自动带上订单引用卡片（聊天输入框显示引用条）
                    if let booking { store.orderDraft = booking }
                }
        } label: {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(Theme.primary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 工具

    private func yuan(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    private func statusName(_ s: String) -> String {
        ["open": "待接单", "assigned": "已接单", "ongoing": "进行中", "completed": "已完成", "cancelled": "已取消"][s] ?? s
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "open": return Theme.warning
        case "assigned", "ongoing": return Theme.primary
        case "completed": return Theme.success
        default: return Theme.danger
        }
    }
}
