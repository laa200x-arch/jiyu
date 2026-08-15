import SwiftUI

/// 设计系统（方案 2.1：浅青蓝主色 + 暖白/浅灰/淡橙辅助色，iOS 原生极简风格）
enum Theme {
    /// 主色：浅青蓝（代表成长、交换）
    static let primary = Color(red: 0.20, green: 0.70, blue: 0.80)
    /// 辅助色：淡橙（曝光/亮点）
    static let secondary = Color(red: 0.95, green: 0.62, blue: 0.38)
    /// 暖白背景
    static let bg = Color(red: 0.98, green: 0.98, blue: 0.97)
    /// 卡片底色
    static let cardBg = Color.white
    static let textPrimary = Color(red: 0.13, green: 0.16, blue: 0.19)
    static let textSecondary = Color(red: 0.45, green: 0.50, blue: 0.55)
    static let divider = Color(red: 0.92, green: 0.93, blue: 0.94)
    static let success = Color(red: 0.30, green: 0.75, blue: 0.45)
    static let warning = Color(red: 0.95, green: 0.62, blue: 0.30)
    static let danger = Color(red: 0.90, green: 0.35, blue: 0.35)

    /// 品牌渐变（头像/横幅）
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.78, blue: 0.85),
            Color(red: 0.25, green: 0.55, blue: 0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 熟练度 → 颜色（入门=橙 / 熟练=青蓝 / 精通=紫）
    static func levelColor(_ level: SkillLevel) -> Color {
        switch level {
        case .beginner: return secondary
        case .skilled: return primary
        case .master: return Color(red: 0.55, green: 0.40, blue: 0.90)
        }
    }
}

/// 通用时间格式
enum Formatters {
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    static func timeText(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
