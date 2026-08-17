import SwiftUI

/// 登录 / 注册（服务端模式入口）
/// 支持：已保存账号一键切换（免输密码）、注册、手动删除账号
struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var username = "aqing"
    @State private var password = "123456"
    @State private var nickname = ""
    @State private var phone = ""
    @State private var smsCode = ""
    @State private var codeCountdown = 0
    @State private var isRegister = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedAccounts: [SavedAccount] = []

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

            if !savedAccounts.isEmpty {
                savedAccountsSection
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
                    TextField("手机号（选填，填写则需验证码）", text: $phone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    HStack(spacing: 8) {
                        TextField("手机验证码", text: $smsCode)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Button {
                            sendCode()
                        } label: {
                            Text(codeCountdown > 0 ? "重新发送(\(codeCountdown)s)" : "获取验证码")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(codeCountdown > 0 ? Theme.textSecondary : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(codeCountdown > 0 ? Theme.divider : Theme.primary))
                        }
                        .disabled(codeCountdown > 0 || isLoading)
                    }
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
        .task {
            savedAccounts = TokenStore.savedAccounts()
        }
    }

    // MARK: - 已保存账号

    private var savedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已保存的账号（点击切换，无需密码）")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(savedAccounts) { account in
                        savedAccountCard(account)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 24)
    }

    private func savedAccountCard(_ account: SavedAccount) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(Theme.gradient)
                        .frame(width: 54, height: 54)
                    Image(systemName: account.avatarSymbol)
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                Button {
                    deleteAccount(account)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.danger.opacity(0.85))
                        .background(Circle().fill(.white))
                }
            }
            Text(account.nickname)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 76)
        .onTapGesture {
            loginWithSaved(account)
        }
        .accessibilityLabel("切换到账号 \(account.nickname)")
    }

    private func loginWithSaved(_ account: SavedAccount) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await MockDataStore.shared.loginWithSavedAccount(account)
                appState.loginSucceeded()
            } catch let error as APIError {
                if error == .unauthorized {
                    // token 真失效：移除该账号，提示重新输入密码
                    TokenStore.removeAccount(username: account.username)
                    savedAccounts = TokenStore.savedAccounts()
                    errorMessage = "账号「\(account.nickname)」登录已过期，请重新输入密码"
                } else {
                    // 网络异常：保留账号，可稍后重试
                    errorMessage = "网络异常，账号已保留，请检查网络后重试"
                }
            } catch {
                errorMessage = "登录失败，请重试"
            }
        }
    }

    private func deleteAccount(_ account: SavedAccount) {
        TokenStore.removeAccount(username: account.username)
        savedAccounts = TokenStore.savedAccounts()
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
        // 手机号选填：填写了手机号则必须格式正确且完成验证
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        if isRegister && !trimmedPhone.isEmpty && !isValidPhone(trimmedPhone) {
            errorMessage = "手机号格式不正确（选填，11 位大陆手机号）"
            return
        }
        if isRegister && !trimmedPhone.isEmpty && smsCode.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "填写了手机号，请先获取并填写验证码"
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
                        nickname: nickname.trimmingCharacters(in: .whitespaces),
                        phone: phone.trimmingCharacters(in: .whitespaces),
                        code: smsCode.trimmingCharacters(in: .whitespaces)
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

    /// 获取注册验证码（一手机号一号；测试通道自动填入 devCode）
    private func sendCode() {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        guard isValidPhone(trimmed) else {
            errorMessage = "请输入正确的 11 位手机号"
            return
        }
        Task {
            do {
                let (message, devCode) = try await APIClient.shared.sendSmsCode(phone: trimmed)
                if let devCode {
                    smsCode = devCode
                    errorMessage = "✅ \(message)（测试通道验证码已自动填入）"
                } else {
                    errorMessage = "✅ \(message)"
                }
                startCountdown()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? (error as? APIError)?.errorDescription
                    ?? "验证码发送失败，请重试"
            }
        }
    }

    private func startCountdown() {
        codeCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if codeCountdown <= 1 {
                codeCountdown = 0
                timer.invalidate()
            } else {
                codeCountdown -= 1
            }
        }
    }

    private func isValidPhone(_ p: String) -> Bool {
        let trimmed = p.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 11, trimmed.hasPrefix("1") else { return false }
        return trimmed.allSatisfy(\.isNumber)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
