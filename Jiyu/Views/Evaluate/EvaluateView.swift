import SwiftUI

/// 双向互评（方案 2.3.5 / 5.5）
/// 教学认真度 / 守时度 / 沟通体验 五星评价 + 留言；提交后重新计算对方信用分
struct EvaluateView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    let record: ExchangeRecord

    @State private var serious = 5
    @State private var punctuality = 5
    @State private var communication = 5
    @State private var comment = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("互换内容") {
                    LabeledContent("互换伙伴", value: record.partner.userName)
                    LabeledContent("互换内容", value: "\(record.mySkillName) ↔ \(record.learnSkillName)")
                    LabeledContent("交换方式", value: record.exchangeType.rawValue)
                }

                Section("教学认真度") {
                    starRow(binding: $serious)
                }
                Section("守时度") {
                    starRow(binding: $punctuality)
                }
                Section("沟通体验") {
                    starRow(binding: $communication)
                }

                Section("评价留言") {
                    TextField("说说本次互换体验（可选）", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Text(record.evaluateGiven ? "已评价" : "提交评价")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(record.evaluateGiven)
                }

                Section {
                    Text("差评 / 爽约 / 诱导交易可发起投诉，平台将人工审核并按规则处理。")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle("双向互评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("感谢评价", isPresented: $showSuccess) {
                Button("好的") { dismiss() }
            } message: {
                Text("评价已提交，\(record.partner.userName) 的信用分已更新。你的信用分也会随着对方的互评而更新。")
            }
        }
    }

    private func starRow(binding: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    binding.wrappedValue = index
                } label: {
                    Image(systemName: index <= binding.wrappedValue ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(index <= binding.wrappedValue ? Theme.secondary : Theme.divider)
                }
            }
            Spacer()
            Text("\(binding.wrappedValue) 分")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func submit() {
        Task {
            await store.submitEvaluation(
                recordID: record.id,
                evaluate: EvaluateModel(
                    punctuality: Double(punctuality),
                    serious: Double(serious),
                    communication: Double(communication),
                    comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            showSuccess = true
        }
    }
}
