import SwiftUI

/// 技遇 —— 纯公益、无金钱交易的技能互换 iOS 平台
/// 入口：注入全局数据层 MockDataStore（正式版替换为 APIClient 网络层）
@main
struct JiyuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MockDataStore.shared)
        }
    }
}
