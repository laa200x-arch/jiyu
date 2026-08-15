import Foundation

/// JWT 令牌本地持久化（UserDefaults）
enum TokenStore {
    private static let key = "jiyu.jwt.token"

    static var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
