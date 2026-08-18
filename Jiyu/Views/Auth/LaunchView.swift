import SwiftUI

/// 启动加载页（有持久化 Token 时先显示，恢复账号数据后再进主界面）
/// 含品牌弹入动画（与 Windows 端启动动画风格一致）
struct LaunchView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: Theme.primary.opacity(0.35), radius: 16, y: 8)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
            }
            Text("技遇")
                .font(.title)
                .bold()
                .foregroundStyle(Theme.textPrimary)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            ProgressView("正在恢复登录…")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.05)) {
                appeared = true
            }
        }
    }
}

#Preview {
    LaunchView()
}
