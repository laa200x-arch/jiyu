import SwiftUI

/// 标准化交换协议（方案 2.3.4 / 5.4）
/// 发起互换前必须确认签署；包含约定内容 + 官方条款；线下需报备公共场所地点
struct AgreementView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    let partner: UserModel

    @State private var mySkillName = ""
    @State private var learnSkillName = ""
    @State private var exchangeType: ExchangeType = .both
    @State private var scheduledTime = ""
    @State private var location = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var existing: ExchangeAgreement? {
        store.agreement(with: partner.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let existing {
                        signedBanner(existing)
                    } else {
                        formSection
                    }
                    termsSection
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("互换协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("好的", role: .cancel) { dismiss() }
            } message: {
                Text(alertMessage)
            }
            .onAppear(perform: setupDefaults)
        }
    }

    // MARK: - 表单

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("约定互换内容")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if store.currentUser.mySkills.isEmpty {
                Text("请先在「我的 → 技能档案」添加「我擅长」的技能")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            } else {
                Picker("我提供（我擅长）", selection: $mySkillName) {
                    ForEach(store.currentUser.mySkills, id: \.id) { skill in
                        Text(skill.skillName).tag(skill.skillName)
                    }
                }
            }

            if partner.mySkills.isEmpty {
                Text("对方暂无可教技能")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            } else {
                Picker("我学习（对方擅长）", selection: $learnSkillName) {
                    ForEach(partner.mySkills, id: \.id) { skill in
                        Text(skill.skillName).tag(skill.skillName)
                    }
                }
            }

            Picker("交换方式", selection: $exchangeType) {
                ForEach(ExchangeType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("约定时间（如：本周六 14:00 / 每周三 20:00）", text: $scheduledTime)
                .textFieldStyle(.roundedBorder)

            if exchangeType != .online {
                TextField("线下地点（请填写公共场所，如：国贸图书馆三楼）", text: $location)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                submit()
            } label: {
                Text("确认签署协议")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.primary))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    // MARK: - 条款

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("平台官方条款（签署即认可）")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text(AgreementManager.agreementTemplate)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func signedBanner(_ agreement: ExchangeAgreement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("已签署 · \(Formatters.timeText(agreement.signedAt))", systemImage: "checkmark.shield.fill")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.success)
            Text("\(agreement.mySkillName) ↔ \(agreement.learnSkillName) · \(agreement.exchangeType.rawValue) · \(agreement.scheduledTime)")
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
            Text("互换记录可在「我的 → 我的互换」中查看。请按时履约，认真教学～")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.success.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.success.opacity(0.4), lineWidth: 1))
    }

    // MARK: - 逻辑

    private func setupDefaults() {
        if mySkillName.isEmpty {
            mySkillName = store.currentUser.mySkills.first?.skillName ?? ""
        }
        if learnSkillName.isEmpty {
            learnSkillName = partner.mySkills.first?.skillName ?? ""
        }
    }

    private func submit() {
        guard !mySkillName.isEmpty, !learnSkillName.isEmpty else {
            alertTitle = "无法签署"
            alertMessage = "请先选择互换的双方技能"
            showAlert = true
            return
        }
        guard !scheduledTime.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "无法签署"
            alertMessage = "请填写约定的互换时间"
            showAlert = true
            return
        }
        if exchangeType != .online,
           location.trimmingCharacters(in: .whitespaces).isEmpty {
            alertTitle = "无法签署"
            alertMessage = "线下交换请填写公共场所地点（平台安全规范）"
            showAlert = true
            return
        }

        Task {
            do {
                try await store.signAgreement(
                    partner: partner,
                    mySkillName: mySkillName,
                    learnSkillName: learnSkillName,
                    exchangeType: exchangeType,
                    scheduledTime: scheduledTime,
                    location: exchangeType == .online ? nil : location
                )
                alertTitle = "签署成功"
                alertMessage = "已与 \(partner.userName) 签署官方互换协议，互换记录已生成。请按时履约，认真教学～"
            } catch {
                alertTitle = "签署失败"
                alertMessage = (error as? LocalizedError)?.errorDescription ?? "请稍后重试"
            }
            showAlert = true
        }
    }
}
