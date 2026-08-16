# FEATURE_MIGRATION_MATRIX — 旧巡六 → 技遇 功能迁移矩阵

> 原则：
> 1. **新项目优先，旧微信项目只是参考**——不得为了迁移把技遇改造成微信架构。
> 2. 迁移的是 **Function Parity**（功能与业务结果一致），不是 Pixel Parity（界面复刻）。
> 3. 旧 Storage / 旧 API 不需要兼容（微信已停用）；`history` 等数据进入对应 Repository，不建兼容层。
> 4. 分类：**KEEP**（完整迁移）/ **REDESIGN**（功能保留、重新设计 UX/架构）/ **MERGE**（并入技遇已有功能）/ **REMOVE**（仅微信平台价值）。
> 5. 因迁移困难擅自标 REMOVE 是被禁止的；REMOVE 仅限"纯微信平台价值或已被新产品形态覆盖且无业务损失"。
>
> 状态图例：⬜ 未开始 ｜ 🟨 部分 ｜ 🟩 完成
> 决策项：D-01~D-05（需业务拍板，见文末）

---

## 一、账号与登录域

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-01 微信登录 | 免密登录 | 技遇已有「用户名+密码」登录/注册（演示账号 aqing/123456） | 无需微信授权；沿用 LoginView | 沿用登录页 | 无 | 无 | **REMOVE**（微信授权）+ **MERGE**（登录能力已被覆盖） |
| F-02 手机号+验证码登录（60s 倒计时/条款/校验） | 手机号登录 | 无手机验证码通道 | 可作后续增强（预留 SMS 服务）；本期不迁移 | 同上 | 验证码校验规则可入 shared（若实现） | 需新增 SMS 发送/验证接口（若实现） | **REDESIGN**（可选，默认本期不做） |
| F-03 登录态持久化与启动恢复 | 无缝续登 | 技遇已有：TokenStore + autoLogin + /api/me 验证 + 多账号保存 | ✅ 已有 | ✅ 已有 | token 管理规则 | 已有 | **MERGE** |
| F-04 登出 | 账号退出 | 技遇已有 logout（清 token/断 socket/重置状态） | ✅ 已有 | ✅ 已有 | 无 | 无（token 无状态） | **MERGE** |
| F-05 用户信息获取/刷新 | 资料展示 | 技遇 GET /api/me + refreshAll() 全量刷新 | ✅ 已有 | ✅ 已有 | 无 | 已有 | **MERGE** |
| F-06 用户资料编辑入口 | 资料维护 | 技遇 ProfileEditView / showSkillEditor（bio/头像/技能） | ✅ 已有 | ✅ 已有 | 无 | 已有 | **MERGE**（宠物域扩展见宠物域） |

## 二、首页域

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-07 首页问候与登录徽章 | 首屏状态 | 技遇 MatchHomeView 头部/登录守卫 | 沿用 MatchHomeView；宠物护理作为新 Tab 或入口（见 TARGET_ARCHITECTURE 决策） | 沿用匹配首页 + 新增宠物服务入口 | 无 | 无 | **REDESIGN**（UI 平台化） |
| F-08 当前预约卡片（三态：未登录/无预约/进行中） | 进行中服务总览 | 无（宠物护理新域） | 新增"我的服务"卡片（进行中寄养/遛狗等） | 同 App | **CareBooking 状态机**（pending/ongoing/completed/cancelled） | 新接口：当前预约查询 | **KEEP**（宠物域内完整迁移，UI 重设计） |
| F-09 寻找服务 CTA | 服务入口 | 技遇"匹配"Tab 天然是服务入口 | 入口改为"宠物护理服务"频道 | 同 App | 无 | 无 | **REDESIGN** |
| F-10 未登录门禁与登录引导 | 转化 | 技遇全端登录守卫已实现 | ✅ 已有 | ✅ 已有 | 无 | 已有 | **MERGE** |

## 三、宠物护理服务目录域

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-11 服务分类网格（过夜/当日/其他） | 服务浏览 | 无（技能互换无服务目录概念） | 宠物服务频道内分类浏览（可并入匹配筛选） | 同 App | 服务目录数据模型 | 新表 care_services + 查询接口 | **KEEP**（数据模型完整迁移） |
| F-12 7 种服务定义 + 定价模型（pricePerDay/Visit/Walk/Session） | 服务目录数据 | 无；且**价格与技遇零金钱政策冲突** | 定价模型改为"服务互换"语义（见 D-01） | 同 App | 服务目录常量 + 定价/互换配置 | care_services 表（价格字段可空/改互换配置） | **KEEP（目录）+ REDESIGN（定价）** 依赖决策 D-01 |
| F-13 服务详情页 | 服务介绍 | 技遇 MatchDetailView（资料+匹配理由）可承载 | 宠物服务详情 = 服务介绍 + 看护人档案 + 发起互换 | 同 App | 无 | 无（复用已有） | **REDESIGN** |
| F-14 附近看护人列表 | 找看护人 | 技遇匹配 + 同城 10km + 地图 + 信用体系**天然支持** | 用匹配列表展示"宠物护理服务提供者"（filter: 服务类型） | 同 App + 地图 | 匹配筛选参数 | /api/match 扩展 serviceType 过滤（或复用技能名） | **REDESIGN**（复用技遇匹配体系） |
| F-15 社区/论坛入口 | 社区 | 技遇动态区（全员动态/发布/风控） | 宠物话题动态可复用动态区 | 同 App | 无 | 已有 | **REDESIGN**（→ 动态区） |

## 四、消息域

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-16 会话列表 + 未读数 | 消息总览 | 技遇完整会话体系（conversations + unread_a/b + 徽标） | ✅ 已有 | ✅ 已有 | 会话 DTO | 已有 | **MERGE** |
| F-17 消息四分类筛选（主要/未读/待处理/即将到来） | 消息管理 | 技遇有未读筛选能力（badge/红点）；无"待处理/即将到来"维度 | 筛选维度可映射：待处理=关联互换记录状态；即将到来=预约时间临近 | 同 App | 消息分类规则（pending/upcoming 语义） | 会话列表可扩展消息类型标记 | **REDESIGN**（语义保留，规则重构） |
| F-18 会话详情聊天（文本/图片/文件） | 1对1聊天 | 技遇 IM **超集**（文本/图片/视频/语音/拍照 + 实时 + 分页 + 风控） | ✅ 已有 | ✅ 已有 | 消息 DTO | 已有 | **MERGE** |
| F-19 消息空态引导 | 空状态 | 技遇已有 EmptyStateView / 空态文案 | ✅ 已有 | ✅ 已有 | 无 | 无 | **MERGE** |

## 五、宠物域（★ 本次迁移的核心新增域）

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-20 宠物列表（含缓存兜底） | 宠物管理 | 无（新域） | 新增"我的宠物"列表（匹配 Tab 或我的 Tab 入口） | 同 App | **Pet 模型 + 列表查询** | 新表 pets + GET /api/pets | **KEEP** |
| F-21 添加宠物（POST） | 宠物档案创建 | 无 | 新增宠物添加表单（复用向导） | 同 App | 创建 DTO/校验 | POST /api/pets | **KEEP** |
| F-22 六步添加向导（类型→信息→行为→家中反应→照片→备注） | 结构化宠物档案 | 无（技遇技能编辑是单步表单） | SwiftUI 多步向导（可参考技遇 AddSkillSheet 风格） | Electron 分步表单 | **向导步骤配置 STEP_FLOW**（步骤/必填/可跳过） | 无（前端编排） | **KEEP**（配置与编排进 shared） |
| F-23 宠物类型差异化字典（狗 8 行为/猫 10 行为 + 体重分级 + 家中反应 4 项） | 档案质量 | 无 | 选项数据来自 shared 常量 | 同 App | **BEHAVIOR_OPTIONS / HOME_REACTION_OPTIONS / WEIGHT_OPTIONS 常量**（中文文案保留） | 无（客户端常量；如需服务端下发可存配置表） | **KEEP**（纯配置，直接迁移） |
| F-24 宠物档案校验规则（姓名/品种/年龄/性别/绝育/猫体重必填；年龄 0–180 月；备注 2000 字） | 数据完整性 | 无 | 调用 shared 校验 | 同 App | **validateBasicInfo / isFormComplete / 年龄封顶 / 长度限制** | 服务端同样校验（防御） | **KEEP**（校验逻辑入 shared + 服务端镜像） |
| F-25 宠物照片选择/移除 | 档案配图 | 技遇已有图片上传通道（/api/upload + 压缩） | **ImageImportService**（相册/相机 + 压缩上传）——不建 WxImagePicker | **File Picker + 压缩上传** | 图片导入/压缩参数（1280px/jpeg0.7 沿用技遇规范） | 已有 /api/upload | **REDESIGN**（按意图重做：用户选图→上传） |
| F-26 宠物详情页 | 档案查看 | 无 | 新增宠物详情（档案 + 服务历史） | 同 App | 无 | GET /api/pets/:id | **KEEP** |

## 六、个人中心域

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-27 个人中心（用户卡+菜单） | 账户中心 | 技遇 MineView（头像/信用/技能/互换/曝光/设置/工具） | ✅ 已有；扩展"我的宠物"入口 | ✅ 已有 | 无 | 已有 | **MERGE** |
| F-28 微信分享 | 社交传播 | 无微信平台 | **REMOVE**；替代：App 内分享到动态区（可选） | 同上 | 无 | 无 | **REMOVE** |
| F-29 支付入口 | 付费服务 | 技遇定位纯公益零金钱；曝光为模拟付费 | 宠物服务若收费与定位冲突（D-01）；若按互换则无支付 | 同 App | 无 | 无 | **REMOVE（默认）/ REDESIGN（若 D-01 放开收费，需 IAP+订单）** |
| F-30 成为看护人入口 | 供给侧 | 技遇技能档案"我擅长"天然承载（把宠物服务声明为技能/服务） | 新增"服务提供者档案"：可接受宠物类型/可照顾时段/认证/简介 | 同 App | **CaregiverProfile 扩展模型**（acceptedPetTypes/availability/certifications） | users 表扩展列 或 caregivers 表；匹配读取 | **REDESIGN**（融入技遇档案+信用体系） |
| F-31 邀请有礼/优惠码 | 拉新促活 | 无 | 非核心；可后续做"邀请码"（非金钱激励，如信用加权） | 同 App | 无 | 可选 /api/invites | **REDESIGN（可选）/ REMOVE（默认）** 依赖 D-02 |

## 七、数据与工具层

| Legacy Feature | Business Purpose | New Project Existing | App | Windows | Shared Core | Backend | Status |
|---|---|---|---|---|---|---|---|
| F-32 统一请求封装（JWT/Loading/错误处理/超时） | 网络层 | 技遇 APIClient（Swift）/ api.js（JS）均已实现同能力 | ✅ 已有 | ✅ 已有 | 错误码约定（401/403/500 语义对齐） | 已有 | **MERGE**（不复刻旧封装） |
| F-33 API 契约 DTO 全集 | 接口契约 | 技遇 serializeUser/serializeSkill/…（camelCase 对齐 iOS Codable） | 新增宠物域 DTO | 同 App | **宠物域 DTO 契约**（Pet/Booking/CareService）加入契约文档 | 新端点返回同风格 | **KEEP（宠物域契约）+ MERGE（已有契约）** |
| F-34 本地存储封装（typed keys） | 持久化 | 技遇 TokenStore/UserDefaults/localStorage | 新增宠物缓存（PetRepository） | 同 App | 存储键约定 | 无 | **MERGE**（读旧 Storage 无必要——微信已停用，无数据迁移需求） |
| F-35 格式化工具（相对时间/日期/手机号脱敏/货币/年龄） | 展示算法 | 技遇 Theme 有部分时间格式化；无手机号脱敏/相对时间（中文） | 复用 shared 算法 | 同 App | **formatTime/formatDate/formatPhone/calculateAge…**（TS + Swift 双实现 + parity test） | 无 | **KEEP**（直接迁移为 shared-core 算法） |
| F-36 Mock 数据（4 套） | 开发数据 | 技遇 seed.js + MockDataStore 已覆盖 | 宠物域示例数据进入 seed | 同 App | 宠物示例数据 | seed 扩展 | **REMOVE**（旧 mock 仅参考，不进入新系统） |

## 八、微信平台专属（P 类，全部 REMOVE）

| 项 | 旧代码 | 真实业务意图 | 处置 |
|---|---|---|---|
| P-01 | wx.login / open-type="getPhoneNumber" | 免密登录 | REMOVE（账号体系 MERGE 技遇） |
| P-02 | wx.showShareMenu | 分享 | REMOVE（无微信平台） |
| P-03 | WXML / WXSS / Page / Component / 页面生命周期 | UI 与组件机制 | REMOVE（App 用 SwiftUI、Windows 用 Electron DOM） |
| P-04 | wx.getStorageSync / wx.request / wx.chooseImage / wx.showToast / 路由系列 | 本地存储/网络/选图/反馈/导航 | REMOVE（分别由 Repository / ApiClient / ImageImportService / 各端 UI 原语承担） |

---

## 九、汇总统计

| 分类 | 数量 | 功能 |
|---|---|---|
| **MERGE（并入技遇已有）** | 14 | F-03, F-04, F-05, F-06, F-10, F-16, F-18, F-19, F-27, F-32, F-33(部分), F-34, F-01(登录能力部分), F-02(可选) |
| **KEEP（完整迁移，宠物域为主）** | 10 | F-08, F-11, F-12(目录部分), F-20, F-21, F-22, F-23, F-24, F-26, F-33(宠物域部分), F-35 |
| **REDESIGN（保留意图、重设计）** | 10 | F-07, F-09, F-13, F-14, F-15, F-17, F-25, F-30, F-02, F-12(定价部分), F-31(可选) |
| **REMOVE（微信平台/已被覆盖）** | 6 | F-01(微信部分), F-28, F-29(默认), F-31(默认), F-36, P-01~P-04 |
| **决策项（需业务拍板）** | 5 | D-01 定价模型、D-02 邀请/优惠码、D-03 社区形态、D-04 入口形态、D-05 服务端权威化 |

> 说明：同一功能可同时落入多个分类（如 F-12 目录 KEEP + 定价 REDESIGN），故计数有重叠。

---

## 十、决策项（D-01 ~ D-05，迁移前需拍板）

| ID | 问题 | 背景 | 推荐 | 影响 |
|---|---|---|---|---|
| **D-01** | 宠物护理服务的"定价"如何处理？ | 旧巡六按天/次收费（¥45/天 等）；技遇定位**纯公益零金钱**（违禁词库甚至拦截"收费/价格"） | **按服务互换语义重构**：宠物照顾作为"我提供"的技能，换取对方"我提供"的技能（我照顾你的猫 ↔ 你教我摄影）；不做现金定价。若未来要收费，走曝光式"服务费+IAP"合规路径 | 决定 care_services 表结构（无价格字段）与协议模板措辞 |
| **D-02** | 邀请有礼/优惠码做不做？ | 旧菜单有入口但未实现；涉及金钱激励与零金钱冲突 | 默认不做；如要做，改为非金钱激励（邀请双方信用加权/曝光加权） | 决定是否新增 /api/invites |
| **D-03** | 社区/论坛形态 | 旧有"社区/论坛"入口（未实现） | 直接复用技遇**动态区**（宠物话题内容发布 + 风控）；不另建论坛 | 无额外后端 |
| **D-04** | 宠物护理入口形态 | App/Windows 现有 4 Tab（匹配/动态/消息/我的） | **推荐：在"匹配"Tab 增加服务类型筛选（全部/技能/宠物护理），并在"我的"增加宠物管理**；不新增第 5 Tab（避免 Tab 膨胀）。若宠物域成为战略重点，可加第 5 Tab（App 底部导航 / Windows 顶栏） | 决定 UI 结构与导航 |
| **D-05** | iOS 本地匹配算法双轨是否收敛 | iOS 用本地 SkillMatchManager（/api/match 闲置），服务端算法不一致时 UI 不生效 | **收敛为服务端权威**：iOS 调用 /api/match，本地算法仅作离线兜底或删除 | 决定是否删 iOS 本地匹配实现、统一排序/过滤 |

---

## 十一、业务逻辑直接复用清单（→ Shared Core）

以下旧代码逻辑**可原样提取语义**（非复制 wx 代码）进入 shared-core：

1. `pet-add/types.ts`：`STEP_FLOW` 向导步骤配置、`BEHAVIOR_OPTIONS`（狗 8/猫 10）、`HOME_REACTION_OPTIONS`（4）、`WEIGHT_OPTIONS`（4）、`validateBasicInfo`、`isFormComplete` —— 纯配置+纯函数，无 wx 依赖。
2. `utils/formatter.ts`：`formatTime`（相对时间中文）、`formatDate`、`formatPhone`（脱敏）、`calculateAge` —— 纯算法。
3. `utils/api-contracts.ts`：宠物/预约/服务 DTO 字段语义 —— 转写为技遇风格 DTO（camelCase，id 字符串化）加入契约。
4. 预约状态机语义：`pending → in-service → completed / cancelled` —— 与技遇 `exchange_records.status`（pending/ongoing/completed/cancelled）对齐映射。
5. 消息分类语义：main/unread/pending/upcoming —— 映射到技遇会话+互换/预约状态。

## 十二、应该重构（不直接迁移）清单

1. 请求封装（F-32）→ 并入技遇 APIClient/api.js，不复刻。
2. 存储封装（F-34）→ Repository 模式（PetRepository 等），本地缓存 + 后端，不建 StorageAdapter。
3. 图片选择（F-25）→ ImageImportService（App 相册/相机、Windows File Picker），不建 ImagePickerAdapter / WxImagePicker。
4. 登录（F-01/F-02）→ 技遇账号体系；不迁移微信 code/加密数据解密逻辑。
5. 页面 UI（F-07/F-09/F-11/F-13/F-17 等）→ 按 App/Windows 平台语言重设计，不追求像素级复刻。
6. 定价（F-12）→ 见 D-01。
7. 找看护人（F-14）→ 复用技遇匹配/地图/信用体系。
