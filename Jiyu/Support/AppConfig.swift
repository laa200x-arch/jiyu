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

    init() {
        isLoggedIn = TokenStore.token != nil
    }

    func loginSucceeded() {
        isLoggedIn = true
    }

    func logout() {
        MockDataStore.shared.logout()
        isLoggedIn = false
    }
}
