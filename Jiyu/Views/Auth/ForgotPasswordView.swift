import SwiftUI

/// 忘记密码（仅限已绑定手机号的账号：手机号 + 验证码 + 新密码）
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phone = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("已注册的手机号", text: $phone)
                        .keyboardType(.numberPad)
                    HStack(spacing: 8) {
                        TextField("验证码", text: $code)
                            .keyboardType(.numberPad)
                        Button {
                            sendCode()
                        } label: {
                            Text(countdown > 0 ? "重新发送(\(countdown)s)" : "获取验证码")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(countdown > 0 ? Theme.textSecondary : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(countdown > 0 ? Theme.divider : Theme.primary))
                        }
                        .disabled(countdown > 0 || isLoading)
                    }
                    SecureField("新密码（至少 6 位）", text: $newPassword)
                } footer: {
                    Text("仅支持已绑定手机号的账号找回密码；验证码 5 分钟内有效")
                        .font(.caption2)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(isError ? Theme.danger : Theme.success)
                    }
                }

                Section {
                    Button {
                        reset()
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("重置密码")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                    }
                    .disabled(isLoading || newPassword.count < 6)
                }
            }
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var trimmedPhone: String { phone.trimmingCharacters(in: .whitespaces) }

    private func isValidPhone(_ p: String) -> Bool {
        guard p.count == 11, p.hasPrefix("1") else { return false }
        return p.allSatisfy(\.isNumber)
    }

    private func sendCode() {
        guard isValidPhone(trimmedPhone) else {
            message = "请输入正确的 11 位手机号"
            isError = true
            return
        }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let (text, devCode) = try await APIClient.shared.sendForgotCode(phone: trimmedPhone)
                if let devCode {
                    code = devCode
                    message = "✅ \(text)（测试通道验证码已自动填入）"
                } else {
                    message = "✅ \(text)"
                }
                isError = false
                countdown = 60
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                    if countdown <= 1 { countdown = 0; timer.invalidate() } else { countdown -= 1 }
                }
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? (error as? APIError)?.errorDescription ?? "验证码发送失败"
                isError = true
            }
        }
    }

    private func reset() {
        guard isValidPhone(trimmedPhone) else {
            message = "请输入正确的 11 位手机号"
            isError = true
            return
        }
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            message = "请输入验证码"
            isError = true
            return
        }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await APIClient.shared.resetPassword(phone: trimmedPhone, code: code.trimmingCharacters(in: .whitespaces), newPassword: newPassword)
                message = "✅ 密码已重置，请返回使用新密码登录"
                isError = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? (error as? APIError)?.errorDescription ?? "重置失败"
                isError = true
            }
        }
    }
}
