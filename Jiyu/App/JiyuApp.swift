import SwiftUI

/// 技遇 —— 纯公益、无金钱交易的技能互换 iOS 平台
/// 入口：未登录 → 登录页；已登录（token 持久化）→ 主框架
@main
struct JiyuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    ContentView()
                        .environmentObject(MockDataStore.shared)
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .task {
                // 有持久化 Token 时自动登录并拉取账号数据
                if appState.isLoggedIn {
                    await MockDataStore.shared.autoLogin()
                }
            }
        }
    }
}
