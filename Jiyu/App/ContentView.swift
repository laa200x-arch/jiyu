import SwiftUI

/// 应用主框架：4 大 Tab（技能匹配 / 互换动态 / 消息 / 我的）
/// 设计原则：去商业化、去交易化 —— 全页面无价格、无付费商品、无充值入口
struct ContentView: View {
    @State private var tabIndex = 0
    @State private var updateInfo: ServerVersion?

    var body: some View {
        TabView(selection: $tabIndex) {
            NavigationStack {
                MatchHomeView()
            }
            .tabItem {
                Label("技能匹配", systemImage: "sparkles")
            }
            .tag(0)

            NavigationStack {
                ExchangeDynamicView()
            }
            .tabItem {
                Label("互换动态", systemImage: "rectangle.stack")
            }
            .tag(1)

            NavigationStack {
                MessageView()
            }
            .tabItem {
                Label("消息", systemImage: "message")
            }
            .tag(2)

            NavigationStack {
                MineView()
            }
            .tabItem {
                Label("我的", systemImage: "person")
            }
            .tag(3)
        }
        .tint(Theme.primary)
        .task {
            await checkForUpdate()
        }
        .alert(
            "发现新版本 \(updateInfo?.current ?? "")",
            isPresented: Binding(
                get: { updateInfo != nil },
                set: { if !$0 { updateInfo = nil } }
            )
        ) {
            Button("去下载") {
                if let urlString = updateInfo?.downloadUrl,
                   let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("稍后再说", role: .cancel) {
                updateInfo = nil
            }
        } message: {
            Text(updateInfo?.updateMessage ?? "")
        }
    }

    /// 版本更新检查（方案：服务器 /api/version，有新版本则弹窗提示）
    private func checkForUpdate() async {
        guard TokenStore.token != nil else { return }
        guard let version = try? await APIClient.shared.fetchVersion() else { return }
        let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        if version.current != localVersion {
            updateInfo = version
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MockDataStore.shared)
}
