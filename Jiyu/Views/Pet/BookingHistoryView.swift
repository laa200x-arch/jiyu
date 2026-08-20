import SwiftUI

/// 历史订单记录（宠物页「历史订单」进入）
/// 状态筛选（全部/待接单/已接单/服务中/已完成/已取消）+ 金额明细 + 点击查看详情
struct BookingHistoryView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var filter = ""
    @State private var bookings: [ServerBooking] = []
    @State private var isLoading = true

    private let filters: [(key: String, label: String)] = [
        ("", "全部"), ("open", "待接单"), ("assigned", "已接单"),
        ("ongoing", "服务中"), ("completed", "已完成"), ("cancelled", "已取消")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 状态筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.key) { f in
                            Button {
                                filter = f.key
                                applyFilter()
                            } label: {
                                Text(f.label)
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(filter == f.key ? .white : Theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(filter == f.key ? Theme.primary : Theme.inputBg))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView("加载中…")
                        Spacer()
                    } else if bookings.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("📜").font(.largeTitle)
                            Text(filter.isEmpty ? "暂无订单记录" : "该状态下暂无订单")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(bookings) { booking in
                                NavigationLink(destination: OrderDetailView(orderId: booking.id)) {
                                    historyRow(booking)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Theme.bg)
                    }
                }
            }
            .background(Theme.bg)
            .navigationTitle("历史订单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await store.refreshPetData()
                applyFilter()
                isLoading = false
            }
        }
    }

    private func historyRow(_ booking: ServerBooking) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(booking.serviceName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let pet = booking.pet {
                    Text("· \(pet.name)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text(statusName(booking.status))
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(statusColor(booking.status))
            }
            Text("🕐 \(booking.scheduledTime) · 📍 \(booking.location ?? "—")")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text("💰 ¥\(yuanText(booking.priceYuan)) · 佣金 ¥\(yuanText(booking.commissionYuan)) · 服务人员 ¥\(yuanText(booking.workerIncome))")
                .font(.caption2)
                .bold()
                .foregroundStyle(Theme.warning)
        }
        .padding(.vertical, 4)
    }

    private func applyFilter() {
        bookings = store.bookings
            .filter { filter.isEmpty || $0.status == filter }
            .sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
    }

    private func statusName(_ s: String) -> String {
        ["open": "待接单", "assigned": "已接单", "ongoing": "服务中", "completed": "已完成", "cancelled": "已取消"][s] ?? s
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "open": return Theme.warning
        case "assigned": return Theme.primary
        case "completed": return Theme.success
        case "cancelled": return Theme.danger
        default: return Theme.primary
        }
    }

    private func yuanText(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}
