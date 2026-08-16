import SwiftUI

/// 技能标签（名称 + 熟练度 + 交换方式）
struct SkillTagView: View {
    let skill: SkillModel
    var showLevel: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: skill.exchangeType.systemImage)
                .font(.system(size: 9))
            Text(showLevel ? "\(skill.skillName) · \(skill.skillLevel.rawValue)" : skill.skillName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(Theme.levelColor(skill.skillLevel))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.levelColor(skill.skillLevel).opacity(0.12)))
    }
}

/// 信用分徽章（0-100，颜色随等级变化）
struct CreditBadgeView: View {
    let score: Double

    var body: some View {
        let level = CreditScoreManager.shared.creditLevel(for: score)
        HStack(spacing: 3) {
            Image(systemName: "shield.checkered")
            Text("信用 \(Int(score)) · \(level)")
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var color: Color {
        if score >= 90 { return Theme.success }
        if score >= 80 { return Theme.primary }
        if score >= 70 { return Theme.secondary }
        return Theme.danger
    }
}

/// 用户头像（自定义头像优先显示图片，否则 SF Symbol + 品牌渐变底）
struct AvatarView: View {
    let user: UserModel
    var size: CGFloat = 48

    var body: some View {
        if let avatarUrl = user.avatarUrl,
           let url = URL(string: AppConfig.serverBase + avatarUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Theme.gradient)
                .frame(width: size, height: size)
            Image(systemName: user.avatarSymbol)
                .font(.system(size: size * 0.42))
                .foregroundStyle(.white)
        }
    }
}

/// 空状态占位
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(Theme.primary.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
