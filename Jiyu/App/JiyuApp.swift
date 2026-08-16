import SwiftUI

/// 技遇 —— 纯公益、无金钱交易的技能互换 iOS 平台
/// 入口：未登录 → 登录页；已登录（token 持久化）→ 主框架
@main
struct JiyuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLaunching {
                    LaunchView()
                } else if appState.isLoggedIn {
                    ContentView()
                        .environmentObject(MockDataStore.shared)
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .task {
                // 有持久化 Token：先显示加载页，恢复账号数据后再进主界面
                // 恢复失败 → 回登录页（401 清 token；网络异常保留 token 便于重试）
                if appState.isLaunching {
                    let sessionOK = await MockDataStore.shared.autoLogin()
                    appState.finishLaunch()
                    if !sessionOK {
                        appState.showLogin()
                    }
                }
            }
        }
    }
}
