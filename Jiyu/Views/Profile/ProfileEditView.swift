import SwiftUI

/// 技能档案编辑（方案 2.3.1：我擅长 / 我想学 增删改）
struct ProfileEditView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTeach = false
    @State private var showAddWant = false

    var body: some View {
        NavigationStack {
            Form {
                Section("我擅长（用于教学他人）") {
                    if store.currentUser.mySkills.isEmpty {
                        Text("暂无，点击下方添加")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(store.currentUser.mySkills) { skill in
                            HStack {
                                SkillTagView(skill: skill)
                                Spacer()
                                Text(skill.availableTime)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .onDelete { store.removeSkill(kind: .teach, at: $0) }
                    }
                    Button {
                        showAddTeach = true
                    } label: {
                        Label("添加「我擅长」技能", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.primary)
                    }
                }

                Section("我想学（用于匹配他人教学）") {
                    if store.currentUser.wantSkills.isEmpty {
                        Text("暂无，点击下方添加")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(store.currentUser.wantSkills) { skill in
                            HStack {
                                SkillTagView(skill: skill)
                                Spacer()
                                Text(skill.availableTime)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .onDelete { store.removeSkill(kind: .want, at: $0) }
                    }
                    Button {
                        showAddWant = true
                    } label: {
                        Label("添加「我想学」技能", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.primary)
                    }
                }

                Section {
                    Button("完成") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
            }
            .navigationTitle("技能档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddTeach) { AddSkillSheet(kind: .teach) }
            .sheet(isPresented: $showAddWant) { AddSkillSheet(kind: .want) }
        }
    }
}

/// 添加技能表单（名称建议 + 熟练度 + 交换方式 + 可教学时间）
struct AddSkillSheet: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    let kind: SkillKind

    @State private var skillName = ""
    @State private var level: SkillLevel = .beginner
    @State private var exchangeType: ExchangeType = .both
    @State private var availableTime = ""

    private let suggestions = ["摄影", "视频剪辑", "编程", "吉他", "日语", "绘画", "手绘", "英语口语", "街舞", "烘焙", "书法", "游泳"]

    var body: some View {
        NavigationStack {
            Form {
                Section("技能名称") {
                    TextField("如：吉他", text: $skillName)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { name in
                                Button {
                                    skillName = name
                                } label: {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(skillName == name ? .white : Theme.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(skillName == name ? Theme.primary : Theme.primary.opacity(0.10)))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("熟练度") {
                    Picker("熟练度", selection: $level) {
                        ForEach(SkillLevel.allCases) { l in
                            Text(l.rawValue).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("交换方式") {
                    Picker("交换方式", selection: $exchangeType) {
                        ForEach(ExchangeType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("可教学时间") {
                    TextField("如：周末全天 / 工作日晚上", text: $availableTime)
                }

                Section {
                    Button("保存") { save() }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .disabled(skillName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(kind == .teach ? "添加「我擅长」" : "添加「我想学」")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let name = skillName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let skill = SkillModel(
            skillName: name,
            skillLevel: level,
            exchangeType: exchangeType,
            availableTime: availableTime.trimmingCharacters(in: .whitespaces).isEmpty ? "待协商" : availableTime
        )
        store.addSkill(skill, kind: kind)
        dismiss()
    }
}
