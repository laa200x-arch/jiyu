import Foundation

/// 匹配筛选条件（方案 2.3.2：距离、时间、技能类型、熟练度、信用分）
struct MatchFilters: Equatable {
    var exchangeType: ExchangeType? = nil   // 交换方式过滤
    var nearbyOnly: Bool = false            // 同城线下（≤10km）
    var minCredit: Double = 0               // 最低信用分
    var keyword: String = ""                // 技能/昵称搜索

    static let standard = MatchFilters()
}

/// 一次双向匹配结果：包含可互换的技能交集说明
struct SkillMatchResult: Identifiable, Hashable {
    let user: UserModel
    let mySkillsForThem: [String]   // 我擅长 ∩ 对方想学（我教对方）
    let theirSkillsForMe: [String]  // 对方擅长 ∩ 我想学（对方教我）

    var id: UUID { user.id }

    var summary: String {
        "你教：\(mySkillsForThem.joined(separator: "、"))｜TA教你：\(theirSkillsForMe.joined(separator: "、"))"
    }
}

/// 双向技能匹配算法（方案 5.2，平台核心）
/// 核心逻辑：A 擅长的 ∩ B 想学的 不为空 且 B 擅长的 ∩ A 想学的 不为空
/// 排序：VIP 曝光优先 → 信用分高优先 → 距离近优先
class SkillMatchManager {
    static let shared = SkillMatchManager()

    func match(
        currentUser: UserModel,
        allUsers: [UserModel],
        filters: MatchFilters = .standard
    ) -> [SkillMatchResult] {
        var results: [SkillMatchResult] = []

        for target in allUsers where target.id != currentUser.id {
            // 信用分过滤
            if target.creditScore < filters.minCredit { continue }
            // 同城线下过滤（仅保留有距离且 ≤10km 的用户）
            if filters.nearbyOnly {
                guard let distance = target.distanceKm, distance <= 10 else { continue }
            }
            // 交换方式过滤：对方至少有一项技能支持该方式
            if let required = filters.exchangeType {
                let supports = target.mySkills.contains {
                    $0.exchangeType == required || $0.exchangeType == .both
                }
                if !supports { continue }
            }
            // 关键词搜索
            if !filters.keyword.isEmpty {
                let haystack = (target.mySkills.map(\.skillName)
                    + target.wantSkills.map(\.skillName)
                    + [target.userName]).joined()
                if !haystack.localizedCaseInsensitiveContains(filters.keyword) { continue }
            }

            // ── 双向对等匹配核心校验 ──
            let theirLearnNorm = Set(target.wantSkills.map { normalized($0.skillName) })
            let myLearnNorm = Set(currentUser.wantSkills.map { normalized($0.skillName) })

            // 我教对方：我擅长的技能中，存在对方想学的
            let teachForThem = currentUser.mySkills
                .filter { skill in theirLearnNorm.contains { matches(skill.skillName, $0) } }
                .map(\.skillName)
            // 对方教我：对方擅长的技能中，存在我想学的
            let learnFromThem = target.mySkills
                .filter { skill in myLearnNorm.contains { matches(skill.skillName, $0) } }
                .map(\.skillName)

            guard !teachForThem.isEmpty, !learnFromThem.isEmpty else { continue }

            results.append(SkillMatchResult(
                user: target,
                mySkillsForThem: teachForThem,
                theirSkillsForMe: learnFromThem
            ))
        }

        // 排序：VIP 曝光用户优先 + 高分用户优先 + 距离近优先
        results.sort { a, b in
            if a.user.isExposureVip != b.user.isExposureVip { return a.user.isExposureVip }
            if a.user.creditScore != b.user.creditScore {
                return a.user.creditScore > b.user.creditScore
            }
            return (a.user.distanceKm ?? .infinity) < (b.user.distanceKm ?? .infinity)
        }

        return results
    }

    // MARK: - 工具

    private func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 模糊匹配：完全相等，或互为子串（如「视频剪辑」↔「剪辑」），长度 ≥2 防误判
    private func matches(_ a: String, _ b: String) -> Bool {
        let x = normalized(a)
        let y = normalized(b)
        if x == y { return true }
        guard x.count >= 2, y.count >= 2 else { return false }
        return x.contains(y) || y.contains(x)
    }
}
