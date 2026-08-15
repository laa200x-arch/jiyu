import SwiftUI

/// 登录 / 注册（服务端模式入口）
struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var username = "aqing"
    @State private var password = "123456"
    @State private var nickname = ""
    @State private var isRegister = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .frame(width: 84, height: 84)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("技遇")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Text("纯公益 · 无金钱交易的技能互换平台")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 12) {
                TextField("用户名", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("密码（至少 6 位）", text: $password)
                    .textFieldStyle(.roundedBorder)
                if isRegister {
                    TextField("昵称", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                submit()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                } else {
                    Text(isRegister ? "注册并登录" : "登 录")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
            }
            .background(Capsule().fill(Theme.primary))
            .disabled(isLoading)
            .padding(.horizontal, 32)

            Button {
                isRegister.toggle()
                errorMessage = nil
            } label: {
                Text(isRegister ? "已有账号？去登录" : "没有账号？注册一个")
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
            }

            Spacer()

            VStack(spacing: 3) {
                Text("演示账号：aqing / 123456（服务器已预置 11 位用户）")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Text("服务地址：\(AppConfig.serverBase)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
    }

    private func submit() {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !password.isEmpty else {
            errorMessage = "请输入用户名和密码"
            return
        }
        if isRegister && nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "请输入昵称"
            return
        }
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                if isRegister {
                    try await MockDataStore.shared.register(
                        username: name,
                        password: password,
                        nickname: nickname.trimmingCharacters(in: .whitespaces)
                    )
                } else {
                    try await MockDataStore.shared.login(username: name, password: password)
                }
                appState.loginSucceeded()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? (error as? APIError)?.errorDescription
                    ?? "登录失败，请重试"
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
