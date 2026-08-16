# LEGACY_AUDIT — 旧微信小程序「巡六 · 宠物护理服务」全面审计

> 定位：**Legacy Reference Implementation（遗留参考实现）**，非目标平台。
> 本审计的目的：提取功能、业务逻辑、算法、数据模型、页面流程、状态变化、用户操作流程；
> 不复制微信平台代码，不建立微信兼容层。
>
> 审计日期：2026-08（基于当前磁盘源码）
> 源码位置：`D:\新建文件夹\xunliu`

---

## 1. 项目概况

| 项 | 值 |
|---|---|
| 项目名 | 巡六（xunliu） |
| 描述 | 宠物护理服务平台（寄养 / 上门看护 / 探访 / 日间托管 / 遛狗 / 训练 / 零食商店） |
| 形态 | 微信小程序（原生 WXML/WXSS + TypeScript） |
| AppID | `wx1234567890abcdef`（占位） |
| 构建 | Webpack 5 + ts-loader，输出 `dist/`，微信开发者工具导入 |
| 依赖 | 仅 `tslib`（运行时）；`@types/wechat-miniprogram`、webpack 系（开发） |
| 数据 | 全部为 Mock + 尚未对接的 API 契约（`https://api.xunliu.com` 占位） |

**重要结论：旧项目是"界面完整 + 业务半成品"状态。**
绝大部分后端逻辑停留在契约定义（`api-contracts.ts`）与 Mock 数据层，未真正联调。
因此迁移的真正价值在：**领域模型设计、宠物档案向导、服务目录与定价模型、预约/聊天/消息的交互流程、表单校验、格式化算法**。

---

## 2. 技术栈

- 语言：TypeScript 5.3+
- 框架：微信小程序原生（`App` / `Page` / `Component` 全局构造器）
- 样式：WXSS（类 CSS，含 `rpx`、`wx:if` 等）
- 模板：WXML
- 构建：Webpack 5 + `copy-webpack-plugin` + `ts-loader`
- 类型：`@types/wechat-miniprogram`（全局 `wx` 命名空间）
- 无 UI 组件库、无状态管理库（全局状态在 `app.globalData`）

---

## 3. 目录结构

```
src/
├── app.ts / app.json / app.wxss      # 应用入口、5 Tab 配置、全局样式
├── pages/
│   ├── index/        # 首页：问候、登录徽章、当前预约卡、找服务 CTA
│   ├── services/     # 服务目录：过夜/当日/其他 三分类，7 种服务
│   ├── messages/     # 消息列表：主要/未读/待处理/即将到来 四筛选
│   ├── pets/         # 宠物：列表 + 六步添加向导（types.ts 含全部领域配置）
│   └── profile/      # 我的：登录面板、菜单、分享；login 页：微信/手机号登录
├── components/
│   ├── navigation-bar/   # 自定义底部导航（5 Tab）
│   ├── service-card/     # 服务卡片（name/desc/icon，tap 事件）
│   └── message-item/     # 消息行（头像/最后一条/时间，tap 事件）
├── utils/
│   ├── request.ts        # wx.request 封装：JWT、Loading、401/403/500/网络错误
│   ├── storage.ts        # wx.getStorageSync 封装：typed keys
│   ├── formatter.ts      # 日期/相对时间/手机号脱敏/货币/年龄计算
│   └── api-contracts.ts  # ★ 全部后端 API 契约（DTO 定义，最有复用价值的文件）
├── mock/                  # services / messages / pets / user 四套 Mock
└── assets/icons/          # SVG/PNG 图标
```

---

## 4. 页面审计

### 4.1 首页 `pages/index`
- 功能：欢迎语 + 用户名（未登录显示"未登录"）、登录状态徽章、我的预约卡片、寻找服务主按钮。
- 状态：`username`、`isLoggedIn`、`hasAppointment`、`currentAppointment`。
- 流程：`onShow` → 刷新预约状态；未登录 → 点击卡片/用户区跳登录页；已登录 → `GET /api/v1/appointments/current`。
- 预约卡三态：未登录（提示登录）/ 已登录无预约（空态引导）/ 有预约（pending=待服务、active=服务中、时间区间、查看详情）。
- ⚠️ 引用了不存在的图片：`bell.png`、`help.png`、`empty-appointment.png`、`clock.png`、`search.png`。

### 4.2 服务 `pages/services`
- 功能：服务分类网格（过夜：寄养/上门看护；当日：上门探访/日间托管/遛狗；其他：训练/零食商店）。
- 服务项字段：`id / name / desc / icon / type`；Mock 中另有 `category / price / pricePerDay|pricePerVisit|pricePerWalk|pricePerSession / rating / reviews`。
- 流程：点服务 → 登录门禁 → `service-detail?id&type&name`；点"附近看护人" → `nearby-caregivers`（登录门禁）；点"社区/论坛" → `community/forum`。
- 加载：`GET /api/v1/services`（仅 console.log，未真正渲染 API 数据）。

### 4.3 消息 `pages/messages`
- 功能：会话列表 + 四筛选（主要/未读/待处理/即将到来）。
- 数据：`GET /api/v1/chat/rooms` → `rooms[]`，字段 `roomId/targetId/targetName/targetAvatar/lastMessage/lastMessageTime/unreadCount/messageType`。
- 筛选逻辑：main=全部；unread=`unreadCount>0`；pending=`messageType==='pending'`；upcoming=`messageType==='upcoming'`。
- 流程：点会话 → `chat-detail?roomId&targetId&targetName`；空态 → 找看护人按钮。

### 4.4 宠物 `pages/pets` + `pet-add` + `types`
- 列表：`GET /api/v1/user/pets`，失败回退本地缓存 `userPets`；空态引导；点宠物 → `pet-detail?petId`。
- **添加向导（核心领域逻辑，六步）**：
  1. `petType`：狗/猫（选完自动进下一步）
  2. `basicInfo`：姓名/品种/年龄(月,0–180 封顶)/性别/绝育(是/否/不确定)/猫额外选体重(小/中/大/超大)
  3. `behaviors`：行为多选（狗 8 项 / 猫 10 项，含 emoji 图标），可跳过
  4. `homeReaction`：家中反应多选（4 项通用），可跳过
  5. `photo`：选图/拍照（压缩、相册/相机），可跳过
  6. `notes`：给看护人的备注（2000 字上限），可跳过
- 校验：`validateBasicInfo`（姓名/品种/年龄/性别/绝育/猫体重必填）。
- 提交：`POST /api/v1/user/pets`，成功 toast + 返回；取消走 `showModal` 二次确认。
- 进度条：`currentStep / (STEP_FLOW.length-1)`。
- 交互细节：行为/反应标签 toggle、步进校验只在 basicInfo 拦、每步滚动到顶部。

### 4.5 个人中心 `pages/profile` + `login`
- 我的：用户卡片（未登录态/登录态）、分享（`wx.showShareMenu`）、菜单（资料/我的宠物/支付/设置/成为看护人/帮助/邀请有礼/优惠码）、推荐区。
- 菜单门禁：未登录点击 → toast + 跳登录。
- 登录页：微信登录（`wx.login` + `open-type="getPhoneNumber"`）+ 手机号登录（11 位校验、验证码 60s 倒计时、6 位校验、条款勾选、+86 前缀）。
- ⚠️ 登录全部为 Mock：微信 code 被忽略直接伪造用户；手机号验证码不真实验证；`saveLoginInfo` 未写 token、未置 `globalData.isLoggedIn`（见 BUG-1）。

---

## 5. 组件审计

| 组件 | 属性 | 事件 | 业务意图 |
|---|---|---|---|
| navigation-bar | selected:number | tap→switchTab | 底部 5 Tab 导航 |
| service-card | name/desc/icon/serviceId | tap 上抛 {serviceId,name} | 服务项展示与点击 |
| message-item | messageId/userName/avatar/lastMessage/time | tap 上抛 | 会话行展示与点击 |

均为纯展示型组件，无业务逻辑；新架构中由 App/Windows 的通用组件替换。

---

## 6. 工具层审计

### 6.1 request.ts（网络层 → 重构为 ApiClient）
- `wx.request` 封装：baseUrl 前缀、JWT `Authorization: Bearer <token>` 注入、全局 Loading 计数、10s 超时。
- 响应约定：`{code, message, data}`；`code===0` 成功返回 `data`；`401` 清 token + 跳登录；`403` 提示无权限；`500` 提示服务器异常；其他显示 `message`；网络失败提示"网络连接失败"。
- 方法：get/post/put/delete、`setBaseUrl`。
- **业务意图**：统一鉴权、统一错误提示、Loading 管理 → 新项目由 `ApiClient`（shared-core）+ 各端错误 UI 承担。

### 6.2 storage.ts（本地存储 → 重构为 Repository）
- typed keys：`userInfo / userPets / serviceHistory / messages / bookings / preferences`。
- 封装 `getStorage/setStorage/removeStorage/clearStorage/getStorageInfo`，try-catch 兜底。
- **业务意图**：用户设置、宠物数据、历史记录的本地缓存 → 新项目拆分为 `SettingsRepository / PetRepository / HistoryRepository`（Local Cache + Backend）。

### 6.3 formatter.ts（纯算法 → 可直接迁移到 shared-core）
- `formatDate(timestamp, 'YYYY-MM-DD HH:mm:ss')` 模板替换
- `formatTime`：相对时间（刚刚 / N分钟前 / N小时前 / N天前 / MM-DD HH:mm）
- `formatPhone`：`138****1234` 脱敏
- `capitalizeFirst`、`truncateText`、`formatCurrency`、`calculateAge`（生日→年龄）

### 6.4 api-contracts.ts（★ 全项目最有复用价值的文件）
完整定义了后端契约（统一响应 `{code,message,data}`，code: 0/401/403/500）：

| 域 | 接口 | 请求/响应要点 |
|---|---|---|
| 认证 | `WxLoginRequest/Response` | code+encryptedData+iv → token+userInfo+loginTime（微信专属，须重设计） |
| 用户 | `GET /api/v1/user/info`；`UpdateUserInfoRequest` | userId/username/phone/avatar/email/createdAt |
| 宠物 | `GET /api/v1/user/pets`；`POST /api/v1/user/pets`（AddPetRequest/Response） | 见 §7 数据模型 |
| 预约 | `GET /api/v1/appointments/current`；`GET /api/v1/appointments/history`；`POST /api/v1/appointments` | 状态机 pending→in-service→completed/cancelled |
| 聊天 | `GET /api/v1/chat/rooms`；`GET /api/v1/chat/messages`；`POST /api/v1/chat/messages` | ChatRoom/ChatMessage（sent/delivered/read；text/image/file） |
| 服务 | `GET /api/v1/services`；`GET /api/v1/caregivers` | ServiceInfo/Caregiver（含 price、availability、rating） |
| 通知 | `GET /api/v1/notifications` | message/appointment/review/system 四类 |
| 错误 | `ErrorResponse` | code/message/details |

---

## 7. 数据结构审计（领域模型提取）

| 模型 | 字段 | 迁移建议 |
|---|---|---|
| **User（用户）** | userId, username, phone, avatar, email?, loginMethod?, loginTime?, createdAt | MERGE → 技遇 UserModel（新增 pet-care 侧扩展） |
| **Pet（宠物）** ★ | petId, name, type(dog/cat/rabbit/bird/other), breed, age(月), gender, avatar, vaccineStatus, description?, createdAt | 迁移到 shared-core `Pet` 模型；旧向导用 `PetFormData`（type/name/breed/age/性别/绝育/体重/behaviors[]/homeReactions[]/photo/notes） |
| **Behaviors/HomeReactions（行为字典）** ★ | 狗 8 项、猫 10 项、家中反应 4 项（id/label/text/icon） | 纯配置数据 → shared-core constants（本地化文本保留中文 text 字段） |
| **Appointment（预约）** ★ | appointmentId, caregiverId/Name/Avatar, serviceType, petId/petName, startTime/endTime, status, notes? | 迁移为 `CareBooking`（宠物护理预约），状态机保留 |
| **ServiceInfo（服务目录）** ★ | serviceId, name, type(7 种), description, icon | 迁移为宠物服务目录配置（新平台作为"技能/服务"的一种） |
| **Caregiver（看护人）** ★ | caregiverId, name, avatar, rating, totalReviews, bio?, availability, price, certifications? | 对应技遇"服务提供者/用户档案+信用分"体系，扩充宠物护理字段 |
| **ChatRoom / ChatMessage（会话/消息）** | roomId, target*, lastMessage*, unreadCount, messageType(main/unread/pending/upcoming); messageId/senderId/content/timestamp/status/type | MERGE → 技遇现有会话/消息体系（消息类型枚举扩充） |
| **Notification** | notificationId, type(message/appointment/review/system), title, content, read, createdAt | MERGE → 技遇通知体系 |
| **UserPreferences** | notifications/language/currency | 对应技遇用户设置 |

---

## 8. Storage 键审计

| Key | 写入位置 | 业务含义 | 迁移目标 |
|---|---|---|---|
| `token` | （契约，未真正写入） | JWT | 技遇 TokenStore（已有） |
| `userInfo` | login.ts, app.ts | 当前用户缓存 | 技遇账号体系（已有） |
| `userPets` | app.ts, pets.ts 读兜底 | 宠物列表缓存 | PetRepository（Local Cache + API） |
| `currentAppointment` | app.ts | 当前预约缓存 | CareBooking 查询（在线优先） |
| `serviceHistory`/`messages`/`bookings`/`preferences` | storage.ts 类型定义 | 历史/消息/订单/设置 | HistoryRepository / SettingsRepository |

---

## 9. wx API 使用审计（→ 真实业务意图）

| wx API | 出现位置 | 真实业务意图 | 新项目实现 |
|---|---|---|---|
| `wx.getStorageSync / setStorageSync / removeStorageSync / clearStorageSync / getStorageInfo` | 全局 | 用户设置、宠物、预约的**本地持久化** | `SettingsRepository` / `PetRepository` / `HistoryRepository`（本地缓存 + 后端 API） |
| `wx.request` | request.ts | **网络请求**（REST + JWT） | `ApiClient`（shared-core，fetch/axios + socket 兜底） |
| `wx.showLoading / hideLoading` | request.ts | 全局加载指示 | 各端 UI 加载态组件 |
| `wx.showToast / showModal` | 多处 | 操作反馈、确认弹窗 | 各端 UI（App 原生 / Windows 对话框） |
| `wx.navigateTo / navigateBack / switchTab / reLaunch / pageScrollTo` | 多处 | **页面路由与导航** | 各端导航体系（App 路由 / Windows 视图切换） |
| `wx.chooseImage` | pet-add.ts | **用户选择宠物照片** | `ImageImportService`（App: 相册/相机；Windows: File Picker）+ 上传接口 |
| `wx.login` + `open-type="getPhoneNumber"` | login.ts | 微信授权登录 | ❌ 删除 → 技遇账号体系（用户名+密码 / 演示账号） |
| `wx.showShareMenu` | profile.ts | 分享到微信 | ❌ 删除（无微信平台） |
| `getApp() / getCurrentPages()` | 多处 | 全局状态/页面栈 | 各端全局状态管理（技遇 @Published / 全局 store） |
| `wx.pageScrollTo` | pet-add.ts | 步进滚动置顶 | 各端滚动 API |

---

## 10. 网络请求审计

| 端点（契约） | 方法 | 使用页面 | 状态 |
|---|---|---|---|
| `/api/v1/user/info` | GET/PUT | app.ts / profile | 契约已定义，未联调 |
| `/api/v1/user/pets` | GET/POST | pets / pet-add | 契约已定义，未联调 |
| `/api/v1/appointments/current` | GET | index | 契约已定义，未联调 |
| `/api/v1/appointments/history`、`/api/v1/appointments` | GET/POST | 契约 | 仅契约 |
| `/api/v1/chat/rooms` | GET | messages | 契约已定义，未联调 |
| `/api/v1/chat/messages`、`/api/v1/chat/messages` | GET/POST | 契约（chat-detail 页面未实现） | 仅契约 |
| `/api/v1/services` | GET | services | 调用但结果未渲染 |
| `/api/v1/caregivers`、`/api/v1/notifications` | GET | 契约 | 仅契约 |

> 结论：旧项目后端从未真正存在。**不需要迁移任何旧 API 实现**，只需把契约语义融入新后端（技遇 server 已有三端 API）。

---

## 11. 文件处理审计

- 仅 `wx.chooseImage`（宠物照片）：`count:1`、`sizeType:['compressed']`、`sourceType:['album','camera']`。
- 契约中消息支持 `image/file` 类型（`mediaUrl`），页面未实现。
- **业务意图**：用户导入宠物照片并上传 → `ImageImportService` + `POST /api/v1/user/pets`（base64 或 multipart）。
- 无下载、无 FileSystemManager 使用。

---

## 12. 算法 / 校验审计（可迁移的纯逻辑）

| 算法/规则 | 位置 | 说明 |
|---|---|---|
| 相对时间格式化 | formatter.formatTime | 刚刚/N分钟前/N小时前/N天前/MM-DD HH:mm |
| 日期模板格式化 | formatter.formatDate | YYYY/MM/DD/HH/mm/ss 替换 |
| 手机号脱敏 | formatter.formatPhone | 前 3 + `****` + 后 4 |
| 年龄计算 | formatter.calculateAge | 生日→周岁（跨月日修正） |
| 货币格式化 | formatter.formatCurrency | `$xx.xx` |
| 宠物档案校验 | types.validateBasicInfo | 姓名/品种/年龄/性别/绝育/猫体重 |
| 年龄输入封顶 | pet-add.onAgeChange | 0–180 个月（15 岁） |
| 备注长度限制 | pet-add | 2000 字符截断 |
| 验证码倒计时 | login | 60s 倒计时（前端 Mock） |
| 服务定价模型 | mock/services.json | pricePerDay / pricePerVisit / pricePerWalk / pricePerSession |
| 向导进度计算 | pet-add | step/总步数百分比 |

---

## 13. 用户状态审计

- 全局状态（app.globalData）：`isLoggedIn / userInfo / currentPetList / currentAppointment / isLoading`。
- 启动恢复：读 `token`+`userInfo` → 置登录态 → 异步拉宠物/预约。
- 登出：清 4 个 storage 键 + 重置全局 + reLaunch 登录页。
- 各页面自行读取 globalData 与 storage 兜底（重复逻辑，无统一 selector）。
- **新架构**：技遇已有 `@Published` 全局状态（iOS）与渲染进程全局 store（Windows）；宠物域状态（petList、booking）应作为独立 domain store 并入。

---

## 14. 核心业务逻辑审计（按域）

1. **账号域**：微信/手机号登录（Mock）→ 登录态恢复 → 登出。微信专属部分 REMOVE，账号体系 MERGE 技遇。
2. **宠物域（★ 最有迁移价值）**：宠物档案 CRUD + 六步向导 + 类型差异化字典 + 校验。全部迁移。
3. **服务域**：服务目录（7 服务 × 定价模型）+ 服务详情 + 附近看护人 + 社区入口。目录迁移；"附近看护人/社区" 是未实现入口，按技遇匹配/动态体系 REDESIGN。
4. **预约域**：当前预约查询 + 状态机（pending/in-service/completed/cancelled）+ 历史预约契约。迁移为 CareBooking。
5. **消息域**：会话列表 + 四分类筛选 + 未读数 + 空态。MERGE 技遇聊天（会话/消息/未读/实时同步已存在）。
6. **通知域**：仅契约。MERGE 技遇通知。
7. **个人中心域**：资料/宠物/支付/设置/成为看护人/帮助/邀请/优惠码菜单。支付、邀请、优惠码、零食商店涉及真实金钱——与技遇"纯公益零金钱"定位冲突，须 REDESIGN（见矩阵）。

---

## 15. 第三方依赖审计

| 依赖 | 类型 | 处置 |
|---|---|---|
| tslib | runtime | 无关紧要 |
| @types/wechat-miniprogram | dev | 删除（wx 类型依赖） |
| webpack / ts-loader / copy-webpack-plugin / glob | dev | 保留思路，新项目用各自构建链 |
| 无 UI 库 / 无 HTTP 库 / 无状态库 | — | 无遗留第三方债务 |

---

## 16. 异常处理审计

- 网络请求：401（清 token+跳登录）/403/500/业务错误/网络失败 各有 toast；request 层统一。
- 页面级：宠物列表失败 → 本地缓存兜底；预约失败 → 空态；消息失败 → 空态。
- 表单：提交失败 toast"添加失败，请重试"；取消二次确认。
- 存储：try-catch 包裹，失败仅 console.error。
- 缺失：无全局错误上报、无重试、无离线队列。

---

## 17. 用户操作流程（主流程提取）

```
【首启】启动 → 读本地登录态 → 首页问候/预约卡
【找服务】首页CTA → 服务Tab → 选服务 → (登录门禁) → 服务详情 → (预约流程，未实现)
【添加宠物】宠物Tab → 添加 → 六步向导(类型→信息→行为→家中反应→照片→备注) → 提交 → 返回列表
【聊天】消息Tab → 会话列表(四筛选) → 会话详情(未实现聊天页)
【登录】个人中心 → 登录 → 微信/手机号+验证码(条款) → 保存 → 返回
【个人中心】菜单(资料/宠物/支付/设置/成为看护人/帮助/邀请/优惠码) → 子页(大多未实现)
```

---

## 18. 业务逻辑 vs 平台逻辑分类（迁移分级）

| 层级 | 内容 | 处置 |
|---|---|---|
| **A. Domain Logic（尽量迁移）** | 宠物模型与字典、校验规则、服务目录与定价模型、预约状态机、相对时间/脱敏/年龄算法、消息分类规则、DTO 契约语义 | → shared-core |
| **B. Application Logic（重新适配）** | 登录态恢复/登出流程、页面门禁、缓存兜底策略、错误提示文案、向导步骤编排 | → 各端应用层 + shared-core 规则 |
| **C. Platform Logic（重新实现）** | wx.request/storage/chooseImage/路由/toast/modal | → ApiClient / Repository / ImageImportService / 各端 UI 原语 |
| **D. UI Logic（重新设计）** | 全部 WXML/WXSS 页面与组件 | → App(SwiftUI) / Windows(Electron) 各自实现；不追求像素级复刻 |

---

## 19. LEGACY BUG 记录（测试基准差异点）

| ID | 位置 | 旧行为 | 正确行为 | 影响 | 建议 |
|---|---|---|---|---|---|
| BUG-1 | login.ts `saveLoginInfo` | 登录成功仅写 `userInfo` storage 与 `globalData.userInfo`，**未写 token、未置 `globalData.isLoggedIn=true`** | 应完成登录态切换（token + isLoggedIn） | 登录后全局仍视为未登录，宠物/预约/消息全部不可用，首页仍显示"未登录" | 新项目登录流程直接走技遇现有账号体系，天然规避 |
| BUG-2 | login.ts `loginWithWeChatCode` | 忽略 `wx.login` 返回的 code，直接伪造 `user_+Date.now()` 用户 | 应把 code 交后端换取会话 | 微信登录无真实鉴权 | 微信登录整体 REMOVE |
| BUG-3 | index.wxml | 引用不存在的 `bell.png/help.png/empty-appointment.png/clock.png/search.png` | 使用真实资源或删除 | 图片裂图 | 新 UI 重新设计，无需修复 |
| BUG-4 | app.ts / api-contracts | `fetchUserInfo` 用 GET `/user/info` 但契约缺该响应字段细节；认证契约仍为微信 WxLogin | 统一用户接口语义 | 契约不一致 | 迁移时以技遇现有 `/api/me` 为准 |
| BUG-5 | messages.ts `applyFilter` | "主要消息"筛选实现为返回全部 | 语义不明（无独立"主要"定义），应明确规则或改"全部" | 轻微语义偏差 | 新消息体系按技遇会话/未读/状态重设计 |

---

## 20. 功能清单（Feature Inventory，供迁移矩阵引用）

| ID | 功能 | 业务意图 | 页面/来源 |
|---|---|---|---|
| F-01 | 微信登录 | 免密登录 | profile/login |
| F-02 | 手机号+验证码登录（倒计时/条款/校验） | 账号登录 | profile/login |
| F-03 | 登录态持久化与启动恢复 | 无缝续登 | app.ts |
| F-04 | 登出（清缓存+重置+跳转） | 账号退出 | app.ts |
| F-05 | 用户信息获取/刷新 | 资料展示 | app.ts, profile |
| F-06 | 用户资料编辑入口 | 资料维护 | profile 菜单（user-info 页未实现） |
| F-07 | 首页问候与登录徽章 | 首屏状态 | index |
| F-08 | 当前预约卡片（三态） | 进行中预约总览 | index |
| F-09 | 寻找服务 CTA | 服务入口 | index |
| F-10 | 未登录门禁与登录引导 | 转化 | index/services/pets/profile |
| F-11 | 服务分类网格（过夜/当日/其他） | 服务浏览 | services |
| F-12 | 7 种服务定义 + 定价模型 | 服务目录数据 | services + mock |
| F-13 | 服务详情页 | 服务介绍 | services（service-detail 未实现） |
| F-14 | 附近看护人列表 | 找看护人 | services（nearby 未实现） |
| F-15 | 社区/论坛入口 | 社区 | services（forum 未实现） |
| F-16 | 会话列表 + 未读数 | 消息总览 | messages |
| F-17 | 消息四分类筛选 | 消息管理 | messages |
| F-18 | 会话详情聊天（契约） | 1对1聊天 | chat-detail（未实现） |
| F-19 | 消息空态引导 | 空状态 | messages |
| F-20 | 宠物列表（含缓存兜底） | 宠物管理 | pets |
| F-21 | 添加宠物（POST） | 宠物档案创建 | pet-add |
| F-22 | 六步添加向导 | 结构化宠物档案 | pet-add + types |
| F-23 | 宠物类型差异化字典（狗/猫行为+体重） | 档案质量 | types.ts |
| F-24 | 宠物档案校验规则 | 数据完整性 | types.ts |
| F-25 | 宠物照片选择/移除 | 档案配图 | pet-add |
| F-26 | 宠物详情页 | 档案查看 | pets（pet-detail 未实现） |
| F-27 | 个人中心（用户卡+菜单） | 账户中心 | profile |
| F-28 | 分享（微信） | 社交传播 | profile |
| F-29 | 支付入口 | 付费 | profile 菜单（payment 未实现） |
| F-30 | 成为看护人入口 | 供给侧 | profile 菜单（未实现） |
| F-31 | 邀请有礼/优惠码 | 拉新促活 | profile 菜单（未实现） |
| F-32 | 统一请求封装（JWT/Loading/错误） | 网络层 | utils/request |
| F-33 | API 契约 DTO 全集 | 接口契约 | utils/api-contracts |
| F-34 | 本地存储封装（typed keys） | 持久化 | utils/storage |
| F-35 | 格式化工具集 | 展示算法 | utils/formatter |
| F-36 | Mock 数据（4 套） | 开发数据 | mock/ |

> 微信平台专属（P 类，删除）：P-01 微信登录授权、P-02 微信分享、P-03 WXML/WXSS 组件与路由机制、P-04 wx.* 全部调用。

---

## 21. 迁移价值结论（摘要）

1. **直接迁移（Domain）**：宠物模型与字典（F-22~F-25）、校验规则、服务目录+定价模型（F-12）、预约状态机语义（F-08）、格式化算法（F-35）、消息分类规则（F-17）、全部 DTO 契约语义（F-33）。
2. **合并进技遇（MERGE）**：账号（F-01~F-06 → 技遇账号）、会话/消息/未读（F-16~F-19 → 技遇 IM）、通知、用户设置。
3. **重新设计（REDESIGN）**：找看护人（F-14 → 技遇匹配/档案体系）、社区（F-15 → 技遇动态区）、服务详情/预约下单（→ 技遇互换协议+服务卡片）、支付/邀请/优惠码/零食商店（金钱相关，与"零金钱"定位冲突，需业务决策）。
4. **删除（REMOVE）**：全部 wx.* 平台调用、微信登录/分享、WXML/WXSS 页面与组件。
5. **旧后端不存在**：无旧 API 兼容负担，只需融合契约语义到技遇 server。
