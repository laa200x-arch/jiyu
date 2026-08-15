import Foundation

/// 曝光增值套餐（方案 3.1，平台核心盈利点）
/// 仅用于：技能主页置顶 + 匹配加权 + 精准人群推送 —— 不参与任何技能交易
struct ExposurePackage: Identifiable, Hashable {
    let id: String
    let name: String
    let days: Int
    let priceYuan: Int
    let weight: Double
    let description: String

    static let day = ExposurePackage(
        id: "exposure-day", name: "日卡", days: 1, priceYuan: 3,
        weight: 1.0, description: "24 小时技能主页置顶 + 匹配加权"
    )
    static let week = ExposurePackage(
        id: "exposure-week", name: "周卡", days: 7, priceYuan: 12,
        weight: 1.5, description: "7 天置顶 + 精准人群推送 + 匹配加权"
    )
    static let month = ExposurePackage(
        id: "exposure-month", name: "月卡", days: 30, priceYuan: 30,
        weight: 2.0, description: "30 天置顶 + 优先匹配优质用户 + 信用榜单展示"
    )
    static let all: [ExposurePackage] = [.day, .week, .month]
}

/// 曝光增值服务
/// 注意：本版本为「模拟开通」演示盈利模块，不产生真实扣费。
/// 正式版需接入苹果 IAP（曝光属虚拟服务，按 App Store 审核规范必须走内购）与后端订单系统。
class ExposureService {
    static let shared = ExposureService()

    /// 模拟开通曝光套餐
    func activate(_ package: ExposurePackage, for user: inout UserModel) {
        user.isExposureVip = true
        user.exposureUntil = Calendar.current.date(byAdding: .day, value: package.days, to: Date())
    }

    /// 取消曝光
    func deactivate(for user: inout UserModel) {
        user.isExposureVip = false
        user.exposureUntil = nil
    }
}
