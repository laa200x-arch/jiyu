import SwiftUI

/// 启动加载页（有持久化 Token 时先显示，恢复账号数据后再进主界面）
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .frame(width: 76, height: 76)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            Text("技遇")
                .font(.title)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            ProgressView("正在恢复登录…")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

#Preview {
    LaunchView()
}
