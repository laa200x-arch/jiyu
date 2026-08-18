import SwiftUI
import WebKit

/// 小程序市场（消息页「🛒 小程序」进入）：搜索 + 列表 + 沙箱运行
struct MiniAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [MiniApp] = []
    @State private var keyword = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var runningApp: MiniApp?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("搜索小程序（名称 / 描述 / 作者）", text: $keyword)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .onChange(of: keyword) { _ in
                            loadTask?.cancel()
                            let kw = keyword
                            loadTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                if !Task.isCancelled { await load(kw: kw) }
                            }
                        }
                    if !keyword.isEmpty {
                        Button { keyword = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 列表
                Group {
                    if isLoading {
                        Spacer()
                        ProgressView("加载中…")
                        Spacer()
                    } else if let errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("⚠️").font(.largeTitle)
                            Text(errorMessage).font(.subheadline).foregroundStyle(Theme.danger)
                            Button("重试") { Task { await load() } }
                                .font(.subheadline).bold().foregroundStyle(Theme.primary)
                        }
                        Spacer()
                    } else if apps.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("🎮").font(.largeTitle)
                            Text(keyword.isEmpty ? "暂无小程序\n在 Windows 端点击「发布」上传你的作品" : "没有找到「\(keyword)」相关小程序")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(apps, id: \.id) { app in
                                Button {
                                    runningApp = app
                                } label: {
                                    appRow(app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listStyle(.plain)
                    }
                }

                // 格式说明
                Text("格式：单文件自包含 HTML · ≤ 512KB · 沙箱运行")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            }
            .background(Theme.bg)
            .navigationTitle("🛒 小程序市场")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(item: $runningApp) { app in
                MiniAppRunView(app: app)
            }
        }
    }

    private func appRow(_ app: MiniApp) -> some View {
        HStack(spacing: 12) {
            Text(app.icon)
                .font(.system(size: 30))
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.primary.opacity(0.08)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    Text("v\(app.version)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(app.description.isEmpty ? "暂无简介" : app.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text("\(app.sizeKb)KB · \(app.downloads) 次运行 · \(app.authorName)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 6)
    }

    private func load(kw: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            apps = try await APIClient.shared.fetchApps(keyword: kw ?? keyword)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? (error as? APIError)?.errorDescription ?? "加载失败"
        }
    }
}

/// 小程序运行页（WKWebView 沙箱加载 HTML 内容）
struct MiniAppRunView: View {
    @Environment(\.dismiss) private var dismiss
    let app: MiniApp
    @State private var htmlContent: String?

    var body: some View {
        NavigationStack {
            Group {
                if let htmlContent {
                    MiniAppWebView(html: htmlContent)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("▶ \(app.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                if htmlContent == nil {
                    do {
                        let detail = try await APIClient.shared.fetchAppDetail(id: app.id)
                        htmlContent = detail.htmlContent
                    } catch {
                        htmlContent = "<body style='font-family:sans-serif;text-align:center;padding-top:80px;color:#888'>加载失败，请稍后重试</body>"
                    }
                }
            }
        }
    }
}

/// WKWebView 桥接（SwiftUI）
struct MiniAppWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
