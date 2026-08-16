import SwiftUI

/// 用户资料页（通用：动态作者 / 匹配用户均可进入）
/// 展示：头像 / 昵称 / 信用 / 认证 / VIP / 距离 / 我擅长 / 我想学
/// 操作：私信沟通（一键进入聊天）
/// 打开时自动从服务器拉取最新资料（技能档案实时更新）
struct UserProfileView: View {
    @EnvironmentObject private var store: MockDataStore
    let initialUser: UserModel
    @State private var user: UserModel

    init(user: UserModel) {
        self.initialUser = user
        _user = State(initialValue: user)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                skillsCard(title: "我擅长（可以教你）", skills: user.mySkills)
                skillsCard(title: "我想学（你来教）", skills: user.wantSkills)

                NavigationLink {
                    ChatDetailView(partner: user)
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
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle(user.userName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if store.isServerMode {
                user = await store.refreshUser(user)
            }
        }
        .task {
            if store.isServerMode {
                user = await store.refreshUser(user)
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(user.userName)
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    if user.isExposureVip {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Theme.secondary)
                    }
                }
                Text(user.bio)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    CreditBadgeView(score: user.creditScore)
                    if user.verification != .none {
                        Label(user.verification.rawValue, systemImage: "checkmark.seal.fill")
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

    private var locationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse")
            if let distance = user.distanceKm {
                Text("\(user.locationLabel) · \(String(format: "%.1f", distance))km")
            } else {
                Text(user.locationLabel)
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                    ForEach(skills) { skill in
                        SkillTagView(skill: skill)
                    }
                }
            }
            locationRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }
}
