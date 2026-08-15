import SwiftUI

/// 互换动态（方案 2.3.3/2.3.6）
/// 动态区同样受文本风控：发布含金钱交易词的内容会被拦截
struct ExchangeDynamicView: View {
    @EnvironmentObject private var store: MockDataStore

    @State private var showCompose = false
    @State private var draft = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.dynamics) { item in
                    dynamicCard(item)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("互换动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            composeSheet
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func dynamicCard(_ item: DynamicModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.isSystemPost ? Theme.secondary.opacity(0.25) : Theme.gradient)
                    .frame(width: 42, height: 42)
                Image(systemName: item.avatarSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(item.isSystemPost ? Theme.secondary : .white)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.authorName)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(Formatters.timeText(item.time))
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(item.content)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private var composeSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("发布动态")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                TextEditor(text: $draft)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.divider, lineWidth: 1))
                Label("禁止发布任何收费、交易、接单等商业信息，发布内容将自动经过平台风控审核",
                      systemImage: "exclamationmark.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                Button {
                    publish()
                } label: {
                    Text("发布")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(
                            draft.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Theme.primary.opacity(0.4) : Theme.primary
                        ))
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(16)
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCompose = false }
                }
            }
        }
    }

    private func publish() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let result = store.postDynamic(content: content)
        if case .blocked(let warning) = result {
            alertTitle = "风控拦截"
            alertMessage = warning
            showAlert = true
        } else {
            draft = ""
            showCompose = false
        }
    }
}
