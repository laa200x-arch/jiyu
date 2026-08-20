import SwiftUI

/// 设计系统（紫色主题：主色紫罗兰 + 暖橙强调 + 浅紫灰背景，现代卡片风）
/// 参考：主色 #6C5CE7 / 背景 #F5F6FC / 卡片纯白 / 强调橙 / 成功绿 / 大圆角胶囊
enum Theme {
    /// 主色：紫罗兰（主按钮、选中态、认证图标、信用环）
    static let primary = Color(red: 0.42, green: 0.36, blue: 0.91)   // #6C5CE7
    /// 深紫（渐变/头像底）
    static let primaryDeep = Color(red: 0.45, green: 0.34, blue: 0.98) // #7257FA
    /// 辅助色：暖橙（曝光/亮点/兴趣标签）
    static let secondary = Color(red: 0.96, green: 0.62, blue: 0.04)  // #F59E0B
    /// 页面背景（统一纯白，避免任何灰底/暗灰观感）
    static let bg = Color.white
    /// 卡片底色（纯白）
    static let cardBg = Color.white
    /// 输入框/未选中按钮固定浅灰（不使用 systemGray 语义色，防止暗黑模式反转成黑块）
    static let inputBg = Color(red: 0.949, green: 0.953, blue: 0.969)   // #F2F3F7
    static let textPrimary = Color(red: 0.12, green: 0.16, blue: 0.22)   // #1F2937
    static let textSecondary = Color(red: 0.42, green: 0.45, blue: 0.50) // #6B7280
    static let divider = Color(red: 0.93, green: 0.94, blue: 0.97)      // #EEF0F6
    static let success = Color(red: 0.13, green: 0.77, blue: 0.37)      // #22C55E
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)      // #F59E0B
    static let danger = Color(red: 0.94, green: 0.27, blue: 0.27)       // #EF4444

    /// 品牌渐变（头像/横幅）
    static let gradient = LinearGradient(
        colors: [primaryDeep, primary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 熟练度 → 颜色（入门=橙 / 熟练=紫 / 精通=深紫）
    static func levelColor(_ level: SkillLevel) -> Color {
        switch level {
        case .beginner: return secondary
        case .skilled: return primary
        case .master: return primaryDeep
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
