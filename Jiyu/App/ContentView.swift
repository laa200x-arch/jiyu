import SwiftUI

/// 应用主框架：4 大 Tab（技能匹配 / 互换动态 / 消息 / 我的）
/// 设计原则：去商业化、去交易化 —— 全页面无价格、无付费商品、无充值入口
struct ContentView: View {
    @State private var tabIndex = 0

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
    }
}

#Preview {
    ContentView()
        .environmentObject(MockDataStore.shared)
}
