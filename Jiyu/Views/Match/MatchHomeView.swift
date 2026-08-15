import SwiftUI

/// 首页 · 智能双向匹配（方案 2.3.2，核心亮点）
/// 支持：交换方式过滤、同城 10km 过滤、关键词搜索；VIP 曝光优先 + 高信用优先排序
struct MatchHomeView: View {
    @EnvironmentObject private var store: MockDataStore
    @State private var keyword = ""
    @State private var typeFilter: ExchangeType?
    @State private var nearbyOnly = false

    private var results: [SkillMatchResult] {
        store.matches(filters: MatchFilters(
            exchangeType: typeFilter,
            nearbyOnly: nearbyOnly,
            minCredit: 0,
            keyword: keyword
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                filterChips
                searchBar

                if results.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "暂时没有匹配",
                        message: "完善「我擅长」和「我想学」技能档案，并保持高信用分，匹配率会更高"
                    )
                } else {
                    ForEach(results) { result in
                        NavigationLink(destination: MatchDetailView(result: result)) {
                            MatchCardView(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.bg)
        .navigationTitle("技能匹配")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("以技换技 · 双向对等")
                .font(.title2)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text("用自己的特长兑换他人专长，零成本提升自我。全程无任何金钱交易。")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("全部", active: typeFilter == nil) { typeFilter = nil }
                ForEach(ExchangeType.allCases) { type in
                    chip(type.rawValue, active: typeFilter == type) { typeFilter = type }
                }
                chip("同城 10km", active: nearbyOnly) { nearbyOnly.toggle() }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("搜索技能或昵称", text: $keyword)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.divider, lineWidth: 1))
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? .white : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Theme.primary : Theme.cardBg))
                .overlay(Capsule().stroke(Theme.divider, lineWidth: active ? 0 : 1))
        }
    }
}

/// 匹配卡片（方案 2.3.2：匹配理由 + 信用 + 距离 + 曝光标识）
struct MatchCardView: View {
    let result: SkillMatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(user: result.user, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(result.user.userName)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if result.user.isExposureVip {
                            Label("曝光", systemImage: "crown.fill")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.secondary))
                        }
                        if result.user.verification != .none {
                            Label(result.user.verification.rawValue, systemImage: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    Text(result.user.bio)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                CreditBadgeView(score: result.user.creditScore)
            }

            // 双向匹配理由
            VStack(alignment: .leading, spacing: 5) {
                Label("双向匹配成功", systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Theme.primary)
                Text("你教 TA：\(result.mySkillsForThem.joined(separator: "、"))")
                Text("TA 教你：\(result.theirSkillsForMe.joined(separator: "、"))")
            }
            .font(.caption)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.primary.opacity(0.07)))

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    if let distance = result.user.distanceKm {
                        Text("\(result.user.locationLabel) · \(String(format: "%.1f", distance))km")
                    } else {
                        Text(result.user.locationLabel)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("发起互换")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.primary))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        MatchHomeView()
            .environmentObject(MockDataStore.shared)
    }
}
