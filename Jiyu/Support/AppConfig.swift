import Foundation

/// 应用配置（部署环境）
enum AppConfig {
    /// 后端服务地址（正式版建议配置 HTTPS 域名，此处为演示服务器）
    static let serverBase = "http://43.157.17.88:3000"
    static let serverURL = URL(string: serverBase)!
}

/// 登录状态（token 驱动）
@MainActor
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool
    /// 启动恢复中（有 token 时先显示加载页，避免闪现演示数据）
    @Published var isLaunching: Bool

    init() {
        let hasToken = TokenStore.token != nil
        isLoggedIn = hasToken
        isLaunching = hasToken
    }

    func loginSucceeded() {
        isLoggedIn = true
        isLaunching = false
    }

    func finishLaunch() {
        isLaunching = false
    }

    /// 仅切换到登录页（不清 token/账号，用于网络异常时保留重试机会）
    func showLogin() {
        isLoggedIn = false
        isLaunching = false
    }

    func logout() {
        MockDataStore.shared.logout()
        isLoggedIn = false
        isLaunching = false
    }
}
