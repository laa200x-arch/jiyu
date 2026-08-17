import SwiftUI
import PhotosUI

/// 编辑资料（统一入口：头像 / 账号 / 我擅长 / 我想学）
struct ProfileEditView: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTeach = false
    @State private var showAddWant = false
    @State private var nickname = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack(spacing: 14) {
                        AvatarView(user: store.currentUser, size: 56)
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            if isUploadingAvatar {
                                ProgressView()
                            } else {
                                Label("更换头像", systemImage: "camera.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                        .disabled(isUploadingAvatar)
                    }
                }

                Section("账号信息") {
                    TextField("昵称", text: $nickname)
                    TextField("简介", text: $bio, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("所在城市（如：广州·天河）", text: $location)
                    Button("保存账号信息") { saveAccount() }
                        .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let savedMessage {
                    Section {
                        Text(savedMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }

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
                        .onDelete { offsets in
                            Task {
                                await store.removeSkill(kind: .teach, at: offsets)
                            }
                        }
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
                        .onDelete { offsets in
                            Task {
                                await store.removeSkill(kind: .want, at: offsets)
                            }
                        }
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
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddTeach) { AddSkillSheet(kind: .teach) }
            .sheet(isPresented: $showAddWant) { AddSkillSheet(kind: .want) }
            .onAppear {
                nickname = store.currentUser.userName
                bio = store.currentUser.bio
                location = store.currentUser.locationLabel
            }
            .onChange(of: avatarItem) { _ in
                handleAvatarSelection()
            }
        }
    }

    /// 保存账号信息（昵称/简介/位置）
    private func saveAccount() {
        Task {
            do {
                try await store.updateProfile(
                    nickname: nickname.trimmingCharacters(in: .whitespaces),
                    bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    locationLabel: location.trimmingCharacters(in: .whitespaces)
                )
                errorMessage = nil
                savedMessage = "账号信息已保存"
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "保存失败"
            }
        }
    }

    /// 相册选择头像 → 压缩上传 → 更新
    private func handleAvatarSelection() {
        guard let avatarItem else { return }
        Task {
            isUploadingAvatar = true
            defer {
                isUploadingAvatar = false
                self.avatarItem = nil
            }
            guard let data = try? await avatarItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = downscaledJPEG(image) else {
                errorMessage = "头像读取失败，请重试"
                return
            }
            guard let url = try? await APIClient.shared.uploadMedia(data: jpeg, fileName: "avatar.jpg", mimeType: "image/jpeg") else {
                errorMessage = "头像上传失败，请检查网络"
                return
            }
            await store.updateAvatar(url: url)
            savedMessage = "头像已更新"
        }
    }

    /// 压缩头像至最长边 512px
    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 512
        let size = image.size
        var target = image
        if max(size.width, size.height) > maxSide {
            let scale = maxSide / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            target = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        return target.jpegData(compressionQuality: 0.8)
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
        Task {
            await store.addSkill(skill, kind: kind)
            dismiss()
        }
    }
}
