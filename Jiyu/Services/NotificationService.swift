import Foundation
import UserNotifications

/// 本地通知（消息/邀约推送）
/// 说明：真·远程推送（APNs）需要 $99 开发者账号；当前方案为 App 运行期间
/// （前台/后台短窗口）收到实时消息或互换邀约时立即弹本地通知，零成本。
enum NotificationService {
    /// 请求通知权限（登录成功后调用）
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 立即弹一条本地通知
    static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
