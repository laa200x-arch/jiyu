import SwiftUI
import PhotosUI

/// 宠物护理 Tab（旧巡六迁移 → 收费订单：服务定价 + 平台佣金 10%，其余归服务人员）
struct PetTabView: View {
    @EnvironmentObject private var store: MockDataStore

    @State private var showAdd = false
    @State private var bookingService: ServerCareService?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                myPetsSection
                servicesSection
                bookingsSection
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("宠物护理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshPetData()
        }
        .sheet(isPresented: $showAdd) {
            PetAddSheet()
        }
        .sheet(item: $bookingService) { service in
            BookingSheet(service: service)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("🐾 宠物护理")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Text("收费订单 · 平台佣金 10%，其余归服务人员")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                showAdd = true
            } label: {
                Label("添加宠物", systemImage: "plus")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.primary))
            }
        }
    }

    // MARK: 我的宠物

    private var myPetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的宠物")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            if store.pets.isEmpty {
                Text("还没有宠物档案，点击「添加宠物」创建（含行为/体重/照片等完整档案）")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.pets) { pet in
                            petCard(pet)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
    }

    private func petCard(_ pet: ServerPet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pet.name)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    Task {
                        await store.deletePet(id: pet.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
            Text("\(pet.petType == "dog" ? "🐕 狗" : pet.petType == "cat" ? "🐈 猫" : "🐾 其他") · \(pet.breed) · \(pet.ageMonths) 月")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text("\(pet.neutered ? "已绝育" : "未绝育") · \(pet.gender == "male" ? "公" : "母")\(pet.weightKg != nil ? " · \(String(format: "%.1f", pet.weightKg!))kg" : "")")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            if let behaviors = pet.behaviors, !behaviors.isEmpty {
                Text(behaviors.joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(Theme.primary)
            }
            if !pet.notes.isEmpty {
                Text("📝 \(pet.notes)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 210, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))
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
            Text("我的订单（我发布 + 我接单）")
                .font(.subheadline)
                .bold()
                .foregroundStyle(Theme.textPrimary)
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

/// 添加宠物表单（类型/品种/年龄/性别/绝育/体重/行为/家中反应/备注 + 校验）
struct PetAddSheet: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var petType = "dog"
    @State private var breed = ""
    @State private var ageText = ""
    @State private var gender = "male"
    @State private var neutered = true
    @State private var weightText = ""
    @State private var selectedBehaviors: Set<String> = []
    @State private var selectedReactions: Set<String> = []
    @State private var notes = ""
    @State private var errorMessage: String?

    private var behaviorOptions: [String] {
        guard let options = store.careOptions else { return [] }
        return petType == "dog" ? options.dogBehaviors : options.catBehaviors
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("宠物名称 *", text: $name)
                    Picker("类型 *", selection: $petType) {
                        Text("🐕 狗").tag("dog")
                        Text("🐈 猫").tag("cat")
                        Text("🐾 其他").tag("other")
                    }
                    TextField("品种 *", text: $breed)
                    HStack {
                        TextField("年龄（月，0-180）*", text: $ageText)
                            .keyboardType(.numberPad)
                        Picker("性别", selection: $gender) {
                            Text("公").tag("male")
                            Text("母").tag("female")
                        }
                        .pickerStyle(.segmented)
                    }
                    Toggle("已绝育", isOn: $neutered)
                    HStack {
                        Text("体重 kg（猫必填）")
                        Spacer()
                        TextField("如：5.5", text: $weightText)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("行为特点") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(behaviorOptions, id: \.self) { b in
                                chip(b, selected: selectedBehaviors.contains(b)) {
                                    if selectedBehaviors.contains(b) { selectedBehaviors.remove(b) }
                                    else { selectedBehaviors.insert(b) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("家中反应") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.careOptions?.homeReactions ?? [], id: \.self) { r in
                                chip(r, selected: selectedReactions.contains(r)) {
                                    if selectedReactions.contains(r) { selectedReactions.remove(r) }
                                    else { selectedReactions.insert(r) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("备注") {
                    TextField("如：喜欢玩球，怕打雷（≤2000 字）", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    Button("保存宠物") { save() }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
            }
            .navigationTitle("添加宠物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundStyle(selected ? .white : Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.primary : Theme.primary.opacity(0.10)))
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespaces)
        let age = Int(ageText) ?? -1
        guard !trimmedName.isEmpty, !trimmedBreed.isEmpty, age >= 0, age <= 180 else {
            errorMessage = "请填写名称、品种，年龄需在 0-180 月之间"
            return
        }
        if petType == "cat", (Double(weightText) ?? 0) <= 0 {
            errorMessage = "猫咪体重必填"
            return
        }
        Task {
            do {
                var body: [String: Any] = [
                    "name": trimmedName,
                    "petType": petType,
                    "breed": trimmedBreed,
                    "ageMonths": age,
                    "gender": gender,
                    "neutered": neutered,
                    "behaviors": Array(selectedBehaviors),
                    "homeReactions": Array(selectedReactions),
                    "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
                if let weight = Double(weightText), weight > 0 { body["weightKg"] = weight }
                try await store.addPet(body)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "保存失败"
            }
        }
    }
}

/// 发起订单（两种方式：指定认识的看护人 / 发布到动态区让有资历的人接单）
struct BookingSheet: View {
    @EnvironmentObject private var store: MockDataStore
    @Environment(\.dismiss) private var dismiss

    let service: ServerCareService

    /// 0 = 指定看护人；1 = 发布到动态区（有资历者接单）
    @State private var orderMode = 0
    @State private var petID: String?
    @State private var providerID: String?
    @State private var scheduledTime = ""
    @State private var location = ""
    @State private var errorMessage: String?

    private var commission: Double {
        (service.priceYuan * 0.1 * 100).rounded() / 100
    }

    private var workerIncome: Double {
        ((service.priceYuan - commission) * 100).rounded() / 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("服务") {
                    LabeledContent("服务", value: service.name)
                    Text("¥\(yuanText(service.priceYuan))/次 · 平台佣金 ¥\(yuanText(commission)) · 服务人员得 ¥\(yuanText(workerIncome))")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Theme.warning)
                }
                Section("宠物 *") {
                    Picker("选择宠物", selection: $petID) {
                        ForEach(store.pets) { pet in
                            Text("\(pet.name)（\(pet.breed)）").tag(Optional(pet.id))
                        }
                    }
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
                Section("约定") {
                    TextField("约定时间 *（如：本周六 18:00）", text: $scheduledTime)
                    TextField("地点 *（公共场所）", text: $location)
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
                }
            }
            .navigationTitle("发起订单 · \(service.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
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
        let time = scheduledTime.trimmingCharacters(in: .whitespaces)
        let place = location.trimmingCharacters(in: .whitespaces)
        guard !time.isEmpty, !place.isEmpty else {
            errorMessage = "请填写约定时间与地点"
            return
        }
        if orderMode == 0, providerID == nil {
            errorMessage = "请选择看护人"
            return
        }
        var body: [String: Any] = [
            "petId": petID,
            "serviceId": service.id,
            "scheduledTime": time,
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
