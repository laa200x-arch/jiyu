import SwiftUI

/// 匹配详情（方案 2.3.2/2.3.4）
/// 查看对方技能档案 → 私信沟通 → 签署官方协议发起互换邀约
struct MatchDetailView: View {
    @EnvironmentObject private var store: MockDataStore
    let result: SkillMatchResult

    @State private var showAgreementSheet = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var hasAgreement: Bool {
        store.agreement(with: result.user.id) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                reasonCard
                skillsCard(title: "TA 擅长（可以教你）", skills: result.user.mySkills)
                skillsCard(title: "TA 想学（你来教）", skills: result.user.wantSkills)

                if hasAgreement {
                    Label("✅ 已与 TA 签署官方互换协议，请按时履约", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.success.opacity(0.10)))
                }

                VStack(spacing: 10) {
                    Button {
                        if hasAgreement {
                            alertTitle = "提示"
                            alertMessage = "你已与 \(result.user.userName) 签署互换协议，可在「我的 → 我的互换」中查看进度。"
                            showAlert = true
                        } else {
                            showAgreementSheet = true
                        }
                    } label: {
                        Text(hasAgreement ? "已签署协议" : "发起互换邀约")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(hasAgreement ? Theme.success : Theme.primary))
                    }

                    NavigationLink {
                        ChatDetailView(partner: result.user)
                    } label: {
                        Text("私信沟通")
                            .font(.headline)
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Theme.cardBg))
                            .overlay(Capsule().stroke(Theme.primary, lineWidth: 1))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(result.user.userName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAgreementSheet) {
            AgreementView(partner: result.user)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            AvatarView(user: result.user, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(result.user.userName)
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    if result.user.isExposureVip {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.secondary)
                    }
                }
                Text(result.user.bio)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    CreditBadgeView(score: result.user.creditScore)
                    if result.user.verification != .none {
                        Label(result.user.verification.rawValue, systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🤝 为什么匹配到你")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text("你教 TA：\(result.mySkillsForThem.joined(separator: "、"))")
            Text("TA 教你：\(result.theirSkillsForMe.joined(separator: "、"))")
            Text("互换时长建议：单次 1 小时 / 2 小时 / 长期互换，由双方协商确定")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.caption)
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.primary.opacity(0.07)))
    }

    private func skillsCard(title: String, skills: [SkillModel]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            if skills.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(skills) { skill in
                    HStack {
                        SkillTagView(skill: skill)
                        Spacer()
                        Text(skill.availableTime)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }
}
