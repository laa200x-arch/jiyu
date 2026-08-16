import SwiftUI

/// 我的动态历史（个人发布过的全部动态，可删除）
struct MyDynamicsView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.myDynamics().isEmpty {
                        EmptyStateView(
                            icon: "square.and.pencil",
                            title: "还没有发布过动态",
                            message: "去「互换动态」发布第一条吧"
                        )
                    } else {
                        ForEach(store.myDynamics()) { item in
                            dynamicCard(item)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("我的动态（\(store.myDynamics().count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func dynamicCard(_ item: DynamicModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Formatters.timeText(item.time))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    Task {
                        await store.deleteDynamic(id: item.id)
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.caption2)
                        .foregroundStyle(Theme.danger)
                }
            }
            Text(item.content)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
            if let imageBase64 = item.imageBase64,
               let imageData = Data(base64Encoded: imageBase64),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }
}
