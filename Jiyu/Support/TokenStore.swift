import Foundation

/// 已保存的登录账号（切换账号时免输密码；手动删除前一直保留）
struct SavedAccount: Codable, Identifiable, Hashable {
    let username: String
    let nickname: String
    let avatarSymbol: String
    var token: String

    var id: String { username }
}

/// JWT 令牌与账号列表本地持久化（UserDefaults）
enum TokenStore {
    private static let tokenKey = "jiyu.jwt.token"
    private static let accountsKey = "jiyu.saved.accounts"

    static var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    // MARK: - 多账号

    static func savedAccounts() -> [SavedAccount] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let list = try? JSONDecoder().decode([SavedAccount].self, from: data) else {
            return []
        }
        return list
    }

    /// 保存/更新账号（同用户名覆盖并置顶）
    static func saveAccount(_ account: SavedAccount) {
        var list = savedAccounts()
        list.removeAll { $0.username == account.username }
        list.insert(account, at: 0)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    /// 手动删除账号
    static func removeAccount(username: String) {
        var list = savedAccounts()
        list.removeAll { $0.username == username }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }
}
