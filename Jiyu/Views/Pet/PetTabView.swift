import SwiftUI
import PhotosUI

/// 宠物护理 Tab（Apple 风格：大标题 + 圆角卡片 + 横滑宠物档案）
struct PetTabView: View {
    @EnvironmentObject private var store: MockDataStore

    @State private var showAdd = false
    @State private var editingPet: ServerPet?
    @State private var bookingService: ServerCareService?
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 大标题（Apple Large Title）
                VStack(alignment: .leading, spacing: 6) {
                    Text("宠物")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Theme.textPrimary)
                    Text("创建宠物档案，为它预约专业看护服务（收费订单 · 平台佣金 10%）")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                myPetsSection
                servicesSection
                bookingsSection
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshPetData()
        }
        .sheet(isPresented: $showAdd) {
            PetAddSheet()
        }
        .sheet(item: $editingPet) { pet in
            PetAddSheet(pet: pet)
        }
        .sheet(item: $bookingService) { service in
            BookingSheet(service: service)
        }
        .sheet(isPresented: $showHistory) {
            BookingHistoryView()
        }
    }

    // MARK: 我的宠物

    private var myPetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我的宠物")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.primary)
                }
            }
            if store.pets.isEmpty {
                VStack(spacing: 12) {
                    Text("🐾")
                        .font(.system(size: 44))
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(LinearGradient(colors: [Theme.primary.opacity(0.10), Theme.secondary.opacity(0.08)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    Text("添加你的第一位宠物")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("建立完整档案（照片 / 年龄 / 体重 / 性格），让看护人更了解你的宝贝")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showAdd = true
                    } label: {
                        Text("添加宠物")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(Theme.primary))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 22).fill(Theme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.divider, lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.pets) { pet in
                            petCard(pet)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func petCard(_ pet: ServerPet) -> some View {
        Button {
            editingPet = pet
        } label: {
            HStack(spacing: 12) {
                if let photoUrl = pet.photoUrl, let url = URL(string: AppConfig.serverBase + photoUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            petTypeIcon(pet)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    petTypeIcon(pet)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(pet.petType == "dog" ? "狗" : pet.petType == "cat" ? "猫" : "其他") · \(pet.breed) · \(pet.ageMonths) 月 · \(pet.gender == "male" ? "公" : "母") · \(pet.neutered ? "已绝育" : "未绝育")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    if let behaviors = pet.behaviors, !behaviors.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(behaviors.prefix(3), id: \.self) { b in
                                Text(b)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Theme.primary.opacity(0.10)))
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func petTypeIcon(_ pet: ServerPet) -> some View {
        Text(pet.petType == "dog" ? "🐕" : pet.petType == "cat" ? "🐈" : "🐾")
            .font(.system(size: 30))
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Theme.primary.opacity(0.10), Theme.secondary.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    // MARK: 服务目录

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("护理服务目录（收费 · 佣金 10%）")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            ForEach(store.careServices) { service in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.name)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(categoryName(service.category)) · \(service.desc) · \(service.duration)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                        Text("¥\(yuanText(service.priceYuan))/次（平台佣金 ¥\(yuanText(service.priceYuan * 0.1))，服务人员得 ¥\(yuanText(service.priceYuan * 0.9))）")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(Theme.warning)
                    }
                    Spacer()
                    Button {
                        bookingService = service
                    } label: {
                        Text("发起订单")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.primary))
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func categoryName(_ c: String) -> String {
        ["overnight": "过夜", "day": "当日", "other": "其他"][c] ?? c
    }

    /// 金额显示：整数不带小数点（45 → "45"，40.5 → "40.5"）
    private func yuanText(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    // MARK: 我的订单

    private var bookingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("我的订单（我发布 + 我接单）")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    Label("历史订单", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.primary)
                }
            }
            if store.bookings.isEmpty {
                Text("暂无订单，从服务目录发起第一笔订单吧（可指定看护人，或发布到动态区等有资历的人接单）")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(store.bookings) { booking in
                    bookingCard(booking)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func bookingCard(_ booking: ServerBooking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(booking.serviceName)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
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
            Text("🕐 \(booking.scheduledTime) · 📍 \(booking.location ?? "线上")")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text("💰 ¥\(yuanText(booking.priceYuan)) · 平台佣金 ¥\(yuanText(booking.commissionYuan)) · 服务人员得 ¥\(yuanText(booking.workerIncome))")
                .font(.caption2)
                .bold()
                .foregroundStyle(Theme.warning)
            if let provider = booking.provider {
                Text("看护人：\(provider.userName)（信用 \(Int(provider.creditScore))）")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            } else if booking.status == "open" {
                Text("等待接单申请：有资历用户申请后，你在私聊/订单详情中确认接单人")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            if booking.status == "assigned" || booking.status == "ongoing" {
                HStack {
                    Spacer()
                    Button("标记完成") {
                        Task {
                            await store.completeBooking(id: booking.id)
                        }
                    }
                    .font(.caption)
                    .bold()
                    .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))
    }

    private func statusName(_ s: String) -> String {
        ["open": "待接单", "assigned": "已接单", "ongoing": "进行中", "completed": "已完成", "cancelled": "已取消"][s] ?? s
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "open": return Theme.warning
        case "assigned", "ongoing": return Theme.primary
        case "completed": return Theme.success
        default: return Theme.danger
        }
    }
}

/// 添加/编辑宠物（Apple 风格：大标题 + 分层卡片 + 年龄滑块 + 选择网格 + 照片 + Sticky 保存）
struct PetAddSheet: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    /// 编辑模式：传入已有宠物档案
    let pet: ServerPet?

    @State private var name: String
    @State private var petType: String
    @State private var breed: String
    @State private var ageMonths: Double
    @State private var gender: String
    @State private var neuteredChoice: String
    @State private var weightBucket: String
    @State private var weightText: String
    @State private var selectedBehaviors: Set<String>
    @State private var selectedReactions: Set<String>
    @State private var notes: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoUrl: String?
    @State private var isUploadingPhoto = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(pet: ServerPet? = nil) {
        self.pet = pet
        _name = State(initialValue: pet?.name ?? "")
        _petType = State(initialValue: pet?.petType ?? "dog")
        _breed = State(initialValue: pet?.breed ?? "")
        _ageMonths = State(initialValue: Double(pet?.ageMonths ?? 24))
        _gender = State(initialValue: pet?.gender ?? "male")
        _neuteredChoice = State(initialValue: pet == nil ? "yes" : (pet!.neutered ? "yes" : "no"))
        let w = pet?.weightKg
        _weightBucket = State(initialValue: w == nil ? "" : (w! < 5 ? "<5" : w! <= 10 ? "5-10" : w! <= 25 ? "10-25" : ">25"))
        _weightText = State(initialValue: w == nil ? "" : String(format: "%.1f", w!))
        _selectedBehaviors = State(initialValue: Set(pet?.behaviors ?? []))
        _selectedReactions = State(initialValue: Set(pet?.homeReactions ?? []))
        _notes = State(initialValue: pet?.notes ?? "")
        _photoUrl = State(initialValue: pet?.photoUrl)
    }

    private var isEditing: Bool { pet != nil }

    private var behaviorOptions: [String] {
        guard let options = store.careOptions else { return [] }
        return petType == "dog" ? options.dogBehaviors : petType == "cat" ? options.catBehaviors : options.dogBehaviors
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 大标题
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "编辑宠物" : "添加宠物")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.5)
                            .foregroundStyle(Theme.textPrimary)
                        Text(isEditing ? "更新 \(pet?.name ?? "") 的档案信息" : "创建完整档案，让看护人更了解你的宝贝")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 基本信息
                    appleSection("基本信息") {
                        VStack(spacing: 14) {
                            Picker("类型", selection: $petType) {
                                Text("🐕 狗").tag("dog")
                                Text("🐈 猫").tag("cat")
                                Text("🐾 其他").tag("other")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: petType) { _ in selectedBehaviors = [] }
                            appleField("宠物名称 *") {
                                TextField("如：豆豆", text: $name)
                            }
                            appleField("品种 *") {
                                TextField("如：柯基 / 英短", text: $breed)
                            }
                        }
                    }

                    // 年龄（滑块）
                    appleSection("年龄") {
                        VStack(spacing: 8) {
                            HStack {
                                Text(ageText)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                Spacer()
                                Text("\(Int(ageMonths)) 个月")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Slider(value: $ageMonths, in: 0...180, step: 1)
                                .tint(Theme.primary)
                            HStack {
                                Text("0 月（幼崽）")
                                Spacer()
                                Text("180 月（15 岁）")
                            }
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    // 性别（双列）
                    appleSection("性别") {
                        HStack(spacing: 10) {
                            choiceCard("♂ 公", selected: gender == "male") { gender = "male" }
                            choiceCard("♀ 母", selected: gender == "female") { gender = "female" }
                        }
                    }

                    // 绝育（三列）
                    appleSection("绝育状态") {
                        HStack(spacing: 10) {
                            choiceCard("已绝育", selected: neuteredChoice == "yes") { neuteredChoice = "yes" }
                            choiceCard("未绝育", selected: neuteredChoice == "no") { neuteredChoice = "no" }
                            choiceCard("不确定", selected: neuteredChoice == "unknown") { neuteredChoice = "unknown" }
                        }
                    }

                    // 体重（四列 + 精确输入）
                    appleSection("体重") {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                weightCard("<5kg", sub: "小型", selected: weightBucket == "<5") { pickWeight("<5") }
                                weightCard("5-10kg", sub: "中型", selected: weightBucket == "5-10") { pickWeight("5-10") }
                                weightCard("10-25kg", sub: "大型", selected: weightBucket == "10-25") { pickWeight("10-25") }
                                weightCard(">25kg", sub: "巨型", selected: weightBucket == ">25") { pickWeight(">25") }
                            }
                            appleField("精确体重（kg，猫必填）") {
                                TextField("如：5.5", text: $weightText)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }

                    // 照片
                    appleSection("宠物照片") {
                        HStack(spacing: 14) {
                            if let photoUrl, let url = URL(string: AppConfig.serverBase + photoUrl) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        photoPlaceholder
                                    }
                                }
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            } else {
                                photoPlaceholder
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label(isUploadingPhoto ? "上传中…" : "上传照片", systemImage: "camera")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundStyle(Theme.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(Theme.primary.opacity(0.10)))
                                }
                                .disabled(isUploadingPhoto)
                                Text("建议正方形照片，展示更佳")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .onChange(of: photoItem) { _ in
                        uploadPhoto()
                    }

                    // 行为
                    appleSection("行为特点") {
                        chipFlow(behaviorOptions, selected: $selectedBehaviors)
                    }

                    // 家中反应
                    appleSection("有人进入你家时") {
                        chipFlow(store.careOptions?.homeReactions ?? [], selected: $selectedReactions)
                    }

                    // 备注
                    appleSection("其他备注") {
                        TextField("如：喜欢玩球，怕打雷，对陌生人有戒心…", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    // 危险区（编辑模式）
                    if isEditing, let pet {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("危险区")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(Theme.danger)
                                .textCase(.uppercase)
                            Text("删除后将无法恢复，该宠物的预约记录仍会保留。")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            Button {
                                Task {
                                    await store.deletePet(id: pet.id)
                                    dismiss()
                                }
                            } label: {
                                Text("删除宠物")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(Theme.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.danger.opacity(0.10)))
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.danger.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.danger.opacity(0.25), lineWidth: 1))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            .background(Theme.bg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            // Sticky 底部保存栏
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isEditing ? "保存修改" : "保存宠物")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.primary))
                    .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
                }
                .disabled(isSaving || isUploadingPhoto)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // 固定浅色背景（不用系统 Material，防止暗黑模式反转成灰色遮罩）
                .background(Theme.bg.opacity(0.98))
            }
        }
    }

    private var ageText: String {
        let m = Int(ageMonths)
        if m < 12 { return "\(m) 个月" }
        let y = m / 12
        let r = m % 12
        return r == 0 ? "\(y) 岁" : "\(y) 岁 \(r) 个月"
    }

    private var photoPlaceholder: some View {
        Image(systemName: "camera")
            .font(.system(size: 26))
            .foregroundStyle(.tertiary)
            .frame(width: 84, height: 84)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.inputBg))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])))
            .foregroundStyle(.quaternary)
    }

    private func appleSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 6)
            VStack(spacing: 14) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private func appleField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            content()
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(Theme.inputBg))
        }
    }

    private func choiceCard(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(selected ? Theme.primary : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(selected ? Theme.primary.opacity(0.10) : Theme.inputBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(selected ? Theme.primary : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func weightCard(_ title: String, sub: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(sub)
                    .font(.caption2)
                    .opacity(0.7)
            }
            .foregroundStyle(selected ? Theme.primary : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(selected ? Theme.primary.opacity(0.10) : Theme.inputBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(selected ? Theme.primary : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipFlow(_ options: [String], selected: Binding<Set<String>>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { item in
                Button {
                    if selected.wrappedValue.contains(item) { selected.wrappedValue.remove(item) }
                    else { selected.wrappedValue.insert(item) }
                } label: {
                    Text(item)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selected.wrappedValue.contains(item) ? Theme.primary : Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(selected.wrappedValue.contains(item) ? Theme.primary.opacity(0.10) : Theme.inputBg)
                        )
                        .overlay(
                            Capsule().stroke(selected.wrappedValue.contains(item) ? Theme.primary : .clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pickWeight(_ bucket: String) {
        weightBucket = bucket
        weightText = bucket == "<5" ? "3" : bucket == "5-10" ? "7.5" : bucket == "10-25" ? "17" : "30"
    }

    private func uploadPhoto() {
        guard let photoItem else { return }
        Task {
            isUploadingPhoto = true
            defer { isUploadingPhoto = false }
            guard let data = try? await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = compressImage(image) else {
                errorMessage = "照片读取失败，请重试"
                return
            }
            guard jpeg.count <= 1024 * 1024 else {
                errorMessage = "照片过大（压缩后仍超过 1MB），请更换更小的图片"
                return
            }
            do {
                photoUrl = try await APIClient.shared.uploadMedia(data: jpeg, fileName: "pet.jpg", mimeType: "image/jpeg")
                errorMessage = nil
            } catch {
                errorMessage = "照片上传失败，请检查网络"
            }
        }
    }

    /// 压缩至最长边 1024px JPEG
    private func compressImage(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let size = image.size
        var target = image
        if max(size.width, size.height) > maxSide {
            let scale = maxSide / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            target = UIGraphicsImageRenderer(size: newSize).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return target.jpegData(compressionQuality: 0.75)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespaces)
        let age = Int(ageMonths)
        guard !trimmedName.isEmpty, !trimmedBreed.isEmpty, age >= 0, age <= 180 else {
            errorMessage = "请填写名称、品种，年龄需在 0-180 月之间"
            return
        }
        if petType == "cat", (Double(weightText) ?? 0) <= 0 {
            errorMessage = "猫咪体重必填"
            return
        }
        isSaving = true
        Task {
            do {
                var body: [String: Any] = [
                    "name": trimmedName,
                    "petType": petType,
                    "breed": trimmedBreed,
                    "ageMonths": age,
                    "gender": gender,
                    "neutered": neuteredChoice == "yes",
                    "behaviors": Array(selectedBehaviors),
                    "homeReactions": Array(selectedReactions),
                    "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
                if let weight = Double(weightText), weight > 0 { body["weightKg"] = weight }
                if let photoUrl { body["photoUrl"] = photoUrl }
                if isEditing, let pet {
                    try await store.updatePet(id: pet.id, body)
                } else {
                    try await store.addPet(body)
                }
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "保存失败"
                isSaving = false
            }
        }
    }
}

/// 发起订单（两种方式：指定认识的看护人 / 发布到动态区让有资历的人接单）
struct BookingSheet: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    /// 进入时默认选中的服务（从服务目录点入）
    let service: ServerCareService

    /// 0 = 指定看护人；1 = 发布到动态区（有资历者接单）
    @State private var orderMode = 0
    @State private var petID: String?
    @State private var providerID: String?
    @State private var scheduleDate = Date()
    @State private var location = ""
    @State private var errorMessage: String?
    /// 服务选择：serviceId → 是否选中；价格：serviceId → 自定义价（nil 用默认）
    @State private var selectedServices: Set<String>
    @State private var customPrices: [String: String]

    init(service: ServerCareService) {
        self.service = service
        _selectedServices = State(initialValue: [service.id])
        _customPrices = State(initialValue: [:])
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }

    /// 结算：合计 / 佣金 10% / 服务人员所得
    private var bill: (total: Double, commission: Double, worker: Double, count: Int) {
        var total = 0.0
        var count = 0
        for s in store.careServices where selectedServices.contains(s.id) {
            if let custom = customPrices[s.id], let v = Double(custom), v > 0 {
                total += v
            } else {
                total += s.priceYuan
            }
            count += 1
        }
        let rounded = (total * 100).rounded() / 100
        let commission = (rounded * 0.1 * 100).rounded() / 100
        return (rounded, commission, ((rounded - commission) * 100).rounded() / 100, count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("选择服务（可多选，价格可自定义）")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(store.careServices) { s in
                        HStack(spacing: 10) {
                            Image(systemName: selectedServices.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedServices.contains(s.id) ? Theme.primary : .gray)
                                .onTapGesture {
                                    if selectedServices.contains(s.id) { selectedServices.remove(s.id) }
                                    else { selectedServices.insert(s.id) }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name)
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(s.duration) · 默认 ¥\(yuanText(s.priceYuan))")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            HStack(spacing: 2) {
                                Text("¥")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("\(yuanText(s.priceYuan))", text: Binding(
                                    get: { customPrices[s.id] ?? "" },
                                    set: { customPrices[s.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                                .font(.subheadline)
                                .disabled(!selectedServices.contains(s.id))
                                .opacity(selectedServices.contains(s.id) ? 1 : 0.4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.inputBg))
                        }
                        .padding(.vertical, 2)
                    }
                    // 账单自动计算
                    VStack(spacing: 6) {
                        billRow("已选服务", "\(bill.count) 项")
                        billRow("服务费合计", "¥\(String(format: "%.2f", bill.total))", bold: true)
                        billRow("平台佣金（10%）", "¥\(String(format: "%.2f", bill.commission))")
                        billRow("服务人员所得", "¥\(String(format: "%.2f", bill.worker))", color: Theme.success)
                        Divider()
                        HStack {
                            Text("应付合计")
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Text("¥\(String(format: "%.2f", bill.total))")
                                .font(.headline)
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
                } header: {
                    Text("服务 *")
                }

                Section("宠物 *") {
                    Picker("选择宠物", selection: $petID) {
                        ForEach(store.pets) { pet in
                            Text("\(pet.name)（\(pet.breed)）").tag(Optional(pet.id))
                        }
                    }
                }

                Section("约定时间 *") {
                    DatePicker("约定时间", selection: $scheduleDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel) // 苹果滑动选择器：过去时间灰色不可选，默认最新时间
                        .labelsHidden()
                        .frame(maxHeight: 160)
                    Text("\(dateFormatter.string(from: scheduleDate))")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.primary)
                }

                Section("地点 *") {
                    TextField("公共场所，如：小区门口/图书馆旁", text: $location)
                }

                Section("下单方式 *") {
                    Picker("下单方式", selection: $orderMode) {
                        Text("指定认识的看护人").tag(0)
                        Text("发布到动态区等接单").tag(1)
                    }
                    .pickerStyle(.segmented)
                    if orderMode == 0 {
                        Picker("选择看护人", selection: $providerID) {
                            ForEach(store.allUsers.filter { $0.id != store.currentUser.id }) { u in
                                Text("\(u.userName)（信用 \(Int(u.creditScore))）").tag(Optional(u.id.serverIDString))
                            }
                        }
                    } else {
                        Text("订单将发布到互换动态区，信用 ≥75 且完成认证的有资历用户可接单")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    Button(orderMode == 0 ? "发起订单" : "发布订单") { submit() }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .disabled(bill.count == 0)
                }
            }
            .navigationTitle("发起订单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func billRow(_ label: String, _ value: String, bold: Bool = false, color: Color = Theme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(bold ? .subheadline : .caption)
                .bold()
                .foregroundStyle(color)
        }
    }

    private func yuanText(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    private func submit() {
        guard let petID else {
            errorMessage = "请选择宠物（可先添加宠物档案）"
            return
        }
        guard bill.count > 0 else {
            errorMessage = "请至少选择一个服务"
            return
        }
        let place = location.trimmingCharacters(in: .whitespaces)
        guard !place.isEmpty else {
            errorMessage = "请填写服务地点（公共场所）"
            return
        }
        if orderMode == 0, providerID == nil {
            errorMessage = "请选择看护人"
            return
        }
        // 服务列表：选中项 + 自定义价格（校验）
        var services: [[String: Any]] = []
        for s in store.careServices where selectedServices.contains(s.id) {
            var item: [String: Any] = ["serviceId": s.id]
            if let custom = customPrices[s.id]?.trimmingCharacters(in: .whitespaces), !custom.isEmpty {
                guard let v = Double(custom), v >= 0, v <= 10000 else {
                    errorMessage = "「\(s.name)」自定义价格不合法"
                    return
                }
                item["customPrice"] = v
            }
            services.append(item)
        }
        var body: [String: Any] = [
            "petId": petID,
            "services": services,
            "scheduledTime": dateFormatter.string(from: scheduleDate),
            "location": place
        ]
        if orderMode == 0, let providerID {
            body["providerId"] = providerID
        } else {
            body["openToFeed"] = true
        }
        Task {
            do {
                try await store.createBooking(body)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "发起失败"
            }
        }
    }
}
