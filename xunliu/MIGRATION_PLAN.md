# MIGRATION_PLAN — 旧巡六 → 技遇 迁移实施计划

> 执行铁律：
> 1. **新项目优先，微信项目只是参考**（Legacy → New，禁止 New ←→ Legacy）。
> 2. 每次只迁移合理范围；每阶段都有可验证的产出与测试。
> 3. 旧微信代码绝不复制进新项目——先理解意图，再在新架构重新实现。
> 4. 禁止微信兼容层（WxAdapter 等任何形式）。
> 5. 迁移期间发现旧逻辑 Bug：不偷偷修，记录 `LEGACY BUG`（旧行为/正确行为/修改原因/影响）。

---

## 0. 前置：决策清单（必须先拍板，D-01~D-05）

| ID | 决策 | 推荐 | 阻塞的阶段 |
|---|---|---|---|
| D-01 | 宠物服务定价模型 | 按服务互换（零金钱），不标价 | Phase 5/6（数据模型） |
| D-02 | 邀请/优惠码 | 默认不做（或改非金钱激励） | Phase 8/9（个人中心） |
| D-03 | 社区形态 | 复用动态区，不另建论坛 | Phase 8/9 |
| D-04 | 宠物护理入口形态 | 匹配 Tab 加服务类型筛选 + 我的 Tab 宠物管理（不新增第 5 Tab） | Phase 8/9 |
| D-05 | iOS 匹配双轨收敛 | 服务端权威 /api/match | Phase 4/7 |

---

## 1. 阶段总览（对应用户定义的 Phase 0–12）

| 阶段 | 名称 | 核心产出 | 状态 |
|---|---|---|---|
| Phase 0 | 双项目扫描 | 本套审计文档（已完成） | 🟩 |
| Phase 1 | Legacy Feature Inventory | LEGACY_AUDIT.md §20（36 项） | 🟩 |
| Phase 2 | 新项目架构理解 | NEW_PROJECT_AUDIT.md | 🟩 |
| Phase 3 | Feature Migration Matrix | FEATURE_MIGRATION_MATRIX.md | 🟩 |
| Phase 4 | Shared Core 定义 | TARGET_ARCHITECTURE.md + shared/ 骨架 | 🟨 文档完成，代码待建 |
| Phase 5 | 迁移纯业务逻辑 | shared-core（宠物字典/校验/向导配置/格式化/状态机） | ⬜ |
| Phase 6 | 迁移数据模型 | server 新表（pets/care_services/care_bookings/caregiver_profiles）+ DTO | ⬜ |
| Phase 7 | 迁移 Backend / API | pets.js / care.js 路由 + 风控扩展 + 测试 | ⬜ |
| Phase 8 | 迁移 App（iOS）功能 | 宠物域 SwiftUI 视图 + 模型 + API 接入 | ⬜ |
| Phase 9 | 迁移 Windows 功能 | 宠物域 Electron 视图 + API 接入 | ⬜ |
| Phase 10 | 跨端数据同步 | 预约/宠物/消息三端互通验证 | ⬜ |
| Phase 11 | 测试 Feature Parity | parity tests + 冒烟扩展 | ⬜ |
| Phase 12 | 删除 Legacy 依赖 | 全局扫描 wx./WXML/WXSS/mini-program/wechat 确认零残留 | ⬜ |

---

## 2. 阶段明细

### Phase 4 — Shared Core 定义与骨架
- **任务**：
  1. 在 `D:\AI\exchange\shared\contracts\` 建立 OpenAPI/JSON Schema（宠物域 + 现有域 DTO 补全）。
  2. 在 `shared/core-ts/` 建 TS 包（`pet-domain` / `formatters` / `booking`），用 npm workspace 或直接路径依赖接入 server 与 win-app。
  3. 定义 parity test 框架（同一 JSON 输入 → TS 与 Swift 输出一致；CI 双跑）。
- **产出**：shared 包骨架 + 契约文档 + parity 测试脚手架。
- **验收**：`npm test` 在 server 中跑通 shared-core 单测；Swift 侧镜像骨架可编译。
- **参考**：TARGET_ARCHITECTURE.md §2、§9。

### Phase 5 — 迁移纯业务逻辑（无 UI、无平台依赖，最高优先级）
- **任务**（从 LEGACY_AUDIT §12 提取，全部为纯函数/配置）：
  1. `pet-add/types.ts` → shared：`PetFormData`、`STEP_FLOW`、`BEHAVIOR_OPTIONS`（狗 8/猫 10）、`HOME_REACTION_OPTIONS`、`WEIGHT_OPTIONS`、`validateBasicInfo`、`isFormComplete`、年龄封顶 180、备注 2000。
  2. `formatter.ts` → shared：`formatTime/formatDate/formatPhone/calculateAge/capitalizeFirst/truncateText`。
  3. 预约状态机语义 → shared：pending/ongoing/completed/cancelled 流转定义。
  4. 消息分类语义（main/unread/pending/upcoming）→ 映射规则文档。
- **产出**：shared/core-ts 可运行模块 + 单测；Swift 镜像（Core/PetProfileWizard.swift 等）+ parity tests。
- **验收**：parity tests 全绿；`formatTime(1622505000000)` 等旧输入输出与旧行为一致（作为 Behavior Reference）。
- **LEGACY BUG 注意**：旧登录态 BUG-1/BUG-2 不迁移（新账号体系规避）；旧向导逻辑本身无 Bug。

### Phase 6 — 迁移数据模型
- **任务**：
  1. `schema.js` 追加 4 张表：pets / care_services / care_bookings / caregiver_profiles（SQLite + MySQL 双 DDL，见 TARGET_ARCHITECTURE §3.1）。
  2. `middleware.js` 追加 `serializePet / serializeCareBooking / serializeCareService / serializeCaregiverProfile`（camelCase，与契约一致）。
  3. `seed.js` 追加宠物域演示数据（2 只宠物、7 个服务目录项、2 个看护人档案）。
- **产出**：新表 + 序列化器 + 种子数据。
- **验收**：`npm run seed` 后 SQLite 内可查 4 张新表数据。
- **D-01 生效点**：care_services 无价格字段。

### Phase 7 — 迁移 Backend / API
- **任务**：
  1. `routes/pets.js`：GET/POST /api/pets、GET /api/pets/:id、PUT/DELETE（服务端镜像校验：名称/品种/年龄 0–180/备注 2000/绝育/猫体重）。
  2. `routes/care.js`：GET /api/care-services、GET /api/caregivers、PUT /api/me/caregiver-profile、GET /api/care-bookings(/current)、POST /api/care-bookings、POST /:id/complete、POST /:id/cancel。
  3. `/api/match` 扩展：`serviceType` 过滤（看护人 teach 技能含服务标记）——复用现有双向匹配（F-14 REDESIGN 落点）。
  4. 风控扩展：`risk.js` 追加宠物域违禁词（如"宠物买卖/狗粮代购/疫苗收费"等，按业务定）；把三级处罚接入（风控命中 → violation_count+1 → 按等级限流/封禁）——顺手补审计缺口 #1。
  5. 通知：预约创建/完成 → 复用 match:push 事件（type:'care-booking'）。
- **产出**：宠物域 REST 全链路 + socket 事件扩展。
- **验收**：扩展 smoke.mjs（新增宠物域 8–10 组断言：宠物 CRUD 校验、服务目录、创建预约→完成→评价→信用分重算），`npm test` 全绿。

### Phase 8 — 迁移 App（iOS）功能
- **任务**：
  1. `Models/PetModels.swift`（契约镜像）+ `ServerModels` 扩展。
  2. `Core/PetProfileWizard.swift`（shared 镜像：步骤/字典/校验）。
  3. `Views/Pet/`：宠物列表、六步添加向导、宠物详情、护理预约表单、看护人列表（复用 MatchHomeView 加筛选）。
  4. `MockDataStore.swift`：petList / careBookings 状态 + 新端点调用。
  5. `MineView` 增加"我的宠物"入口；匹配页增加服务类型筛选（D-04）。
  6. 收敛匹配双轨（D-05）：MatchHomeView 改用 /api/match。
- **产出**：iOS 宠物域功能完整可用。
- **验收**：模拟器走通"添加宠物 → 找看护人 → 发起护理互换 → 签署 → 评价"全流程。

### Phase 9 — 迁移 Windows 功能
- **任务**：
  1. `api.js` 追加宠物域端点封装。
  2. `views.js` 追加：宠物管理视图、六步向导（分步表单）、护理预约、看护人筛选。
  3. 地图扩展：caregiver 打点（如开启）。
- **产出**：Windows 宠物域功能完整可用。
- **验收**：`test-core.js` 扩展宠物域断言（真实服务器或本地库），全绿。

### Phase 10 — 跨端数据同步
- **任务**：三端同账号场景验证（App 建宠物 → Windows 可见可编辑 → App 刷新一致；预约状态变化实时推送）。
- **验收**：三端互通清单全过（对照 TARGET_ARCHITECTURE §5 数据互通表）。

### Phase 11 — 测试 Feature Parity
- **任务**：按 FEATURE_MIGRATION_MATRIX 的 KEEP 项逐条做"同输入 → 同输出"对照：
  - 宠物校验：旧 `validateBasicInfo` 用例 → shared 实现 → Swift/TS 输出一致。
  - 格式化：`formatTime` 时间戳样本 → 三端一致。
  - 状态机：预约流转 → 三端一致。
- **产出**：parity 测试套件。
- **验收**：全绿；发现旧逻辑 Bug 时按"LEGACY BUG"流程记录。

### Phase 12 — 删除 Legacy 依赖
- **任务**：全仓库扫描 `wx.` / `WXML` / `WXSS` / `mini-program` / `wechat` / `weixin` / `@types/wechat-miniprogram`，确认新项目零残留（legacy 目录单独归档即可）。
- **验收**：扫描结果为空（除归档区与文档历史说明）。

---

## 3. Definition of Done（迁移完成判定）

- [ ] 旧微信 36 项有效功能全部登记（✅ LEGACY_AUDIT §20）
- [ ] 所有 KEEP 功能完成迁移（宠物域核心）
- [ ] App 功能完整（宠物域 + 现有域）
- [ ] Windows 功能完整（宠物域 + 现有域）
- [ ] App / Windows 数据互通（宠物/预约/消息/信用）
- [ ] Shared Core 无重复业务逻辑（TS 包 + Swift 镜像 + parity tests）
- [ ] Backend 正常（宠物域 API + 扩展冒烟测试全绿）
- [ ] 完整测试通过（server smoke + win-app test-core + iOS parity）
- [ ] 新项目不依赖 wx.* / 微信运行环境（Phase 12 扫描通过）

---

## 4. 每次实施规则模板（后续每个迁移增量按此输出）

```
### Feature
本次迁移的功能（引用矩阵 ID）。

### Legacy Behavior
旧版本怎么工作（含输入/输出/状态/副作用）。

### New Design
新项目如何实现（契约/接口/存储/UI 要点）。

### Shared Logic
哪些逻辑 App / Windows 共用（shared-core 模块）。

### App
App 改动（文件 + 功能）。

### Windows
Windows 改动（文件 + 功能）。

### Backend
Backend 改动（表/路由/事件/风控）。

### Files Changed
修改文件清单。

### Tests
测试结果（parity / smoke / 手工场景）。

### Remaining
尚未迁移内容（引用矩阵状态）。
```

---

## 5. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 零金钱政策与旧定价冲突（D-01 未决） | 先按"服务互换"建模，价格字段留空；决策后可平滑加字段 |
| Swift/TS 算法双实现漂移 | parity test 进 CI；算法以 shared TS 为源，Swift 镜像由同一用例驱动 |
| iOS 匹配双轨未收敛导致行为不一致 | Phase 8 强制收敛（D-05） |
| 宠物照片/图片审核缺失 | 先做尺寸/类型校验，再排队接百度 AI 审核 |
| 测试污染生产数据（win-app 现状） | 本地库 + 独立测试账号，smoke/test-core 指向测试环境 |
| 迁移范围蔓延（把技遇改造成微信风格） | 坚持红线清单（TARGET_ARCHITECTURE §8）；每次实施按模板评审 |

---

## 6. 首个实施增量建议（Phase 4+5 合并的第一批）

> 推荐第一个迁移增量 = **宠物域 shared-core 纯逻辑包**（无 UI、无平台风险、立即可验证）：

1. 建 `shared/core-ts`（package.json + tsconfig + 单测）。
2. 迁移 `types.ts`（PetFormData/STEP_FLOW/字典/校验）与 `formatter.ts`。
3. Swift 镜像 + 第一个 parity test（宠物校验 + formatTime）。
4. 输出按 §4 模板提交评审。
