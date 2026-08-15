import SwiftUI

/// 曝光增值服务（方案 3.1，平台核心盈利点）
/// 日/周/月套餐，仅曝光加权；本版本为模拟开通，正式版接入苹果 IAP 与后端订单
struct ExposureView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirmPackage: ExposurePackage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.secondary)
                        Text("技能曝光 · 增值服务")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("仅用于技能主页置顶、精准人群推送与匹配加权，不参与任何技能交易，不改变平台纯公益属性")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 8)

                    ForEach(ExposurePackage.all) { pkg in
                        packageCard(pkg)
                    }

                    if store.currentExposurePackage != nil {
                        Button(role: .destructive) {
                            Task {
                                await store.applyExposure(package: nil)
                            }
                        } label: {
                            Text("取消曝光")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }

                    Text("注意：曝光服务为虚拟增值服务，正式上线时按 App Store 规范需通过苹果内购（IAP）支付。")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("曝光服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("确认开通", isPresented: Binding(
                get: { confirmPackage != nil },
                set: { if !$0 { confirmPackage = nil } }
            )) {
                Button("模拟开通（本版本不扣费）") {
                    if let pkg = confirmPackage {
                        Task {
                            await store.applyExposure(package: pkg)
                        }
                    }
                    confirmPackage = nil
                }
                Button("取消", role: .cancel) { confirmPackage = nil }
            } message: {
                Text(confirmPackage.map {
                    "\($0.name) · \($0.days) 天：\($0.description)。正式版价格为 ¥\($0.priceYuan)，经苹果内购支付。"
                } ?? "")
            }
        }
    }

    private func packageCard(_ pkg: ExposurePackage) -> some View {
        let isCurrent = store.currentExposurePackage?.id == pkg.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pkg.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(pkg.days) 天 · 匹配加权 ×\(String(format: "%.1f", pkg.weight))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if isCurrent {
                    Label("生效中", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(Theme.success)
                } else {
                    Text("¥\(pkg.priceYuan)")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(Theme.secondary)
                }
            }
            Text(pkg.description)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
            Button {
                if isCurrent { return }
                confirmPackage = pkg
            } label: {
                Text(isCurrent ? "已开通" : "开通 \(pkg.name)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(isCurrent ? Theme.success : Theme.secondary))
            }
            .disabled(isCurrent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
            isCurrent ? Theme.success : Theme.divider, lineWidth: 1))
    }
}
