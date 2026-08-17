import SwiftUI
import UIKit

/// 收到的评价（文字评价展示 + 违规申诉入口，V1.1）
struct ReceivedEvaluationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var evaluations: [ReceivedEvaluation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中…")
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Text("⚠️").font(.largeTitle)
                        Text(errorMessage).font(.subheadline).foregroundStyle(Theme.danger)
                        Button("重试") { load() }
                            .font(.subheadline).bold().foregroundStyle(Theme.primary)
                    }
                } else if evaluations.isEmpty {
                    VStack(spacing: 10) {
                        Text("⭐").font(.largeTitle)
                        Text("还没有收到评价\n完成互换并互相评价后展示在这里")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        Section {
                            Text("共 \(evaluations.count) 条评价 · 平均 \(averageScore, specifier: "%.1f") 分")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(evaluations, id: \.id) { eval in
                            evaluationRow(eval)
                        }
                    }
                }
            }
            .navigationTitle("收到的评价")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { load() }
        }
    }

    private var averageScore: Double {
        guard !evaluations.isEmpty else { return 0 }
        return evaluations.reduce(0) { $0 + ($1.punctuality + $1.serious + $1.communication) / 3 } / Double(evaluations.count)
    }

    private func evaluationRow(_ eval: ReceivedEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(eval.fromName)
                    .font(.subheadline).bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("守时 \(Int(eval.punctuality)) · 认真 \(Int(eval.serious)) · 沟通 \(Int(eval.communication))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            if !eval.comment.isEmpty {
                Text(eval.comment)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            } else {
                Text("（无文字评价）")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack {
                Text(APIClient.parseDate(eval.createdAt).map { Formatters.timeText($0) } ?? "")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let status = eval.myAppealStatus {
                    Label("申诉中（\(status)）", systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                } else {
                    Button("申诉这条评价") { appeal(eval) }
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func appeal(_ eval: ReceivedEvaluation) {
        var reason = ""
        let alert = UIAlertController(title: "申诉这条评价", message: "申诉理由（评价不实 / 内容违规等），平台 1-3 个工作日内审核：", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "请输入申诉理由" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "提交", style: .default) { _ in
            reason = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !reason.isEmpty else { return }
            Task {
                do {
                    try await APIClient.shared.appealEvaluation(id: eval.id, reason: reason)
                    load()
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? (error as? APIError)?.errorDescription ?? "申诉失败"
                }
            }
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }

    private func load() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                evaluations = try await APIClient.shared.fetchReceivedEvaluations()
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? (error as? APIError)?.errorDescription ?? "加载失败"
            }
        }
    }
}
