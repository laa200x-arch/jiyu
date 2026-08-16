# NEW_PROJECT_AUDIT — 新项目「技遇 Jiyu」三端体系全面审计

> 定位：**最终产品**（Target System）。迁移以「新项目优先」为最高原则：
> 旧微信小程序只是参考，不得把新项目改造成旧微信架构，不得引入微信兼容层。
>
> 审计日期：2026-08（基于磁盘源码 + 三份子代理深度扫描报告）
> 仓库位置：`D:\AI\exchange`

---

## 1. 产品定位

**技遇（Jiyu）** —— 纯公益、无金钱交易的「技能/服务互换」平台：
以技能换技能（我擅长 × 我想学 双向对等匹配），覆盖线上/线下双场景交换，
内置 IM 聊天、标准化互换协议、双向信用评价、零金钱交易风控、曝光增值服务。

**本次迁移的商业定位（用户确认）**：把旧「巡六」的宠物护理服务领域
**融入技遇平台，作为一个服务域（Pet Care Service Domain）**：
宠物护理（寄养/遛狗/日托/探访/训练等）作为可互换的"服务技能"接入现有的
匹配 / 协议 / 聊天 / 评价 / 风控 / 信用体系。

| 端 | 技术栈 | 状态 |
|---|---|---|
| iOS（`Jiyu/`） | SwiftUI + Swift 5.9（iOS 16+），Xcode 15+ | 可构建可安装，35 个 Swift 文件 |
| Windows（`win-app/`） | Electron 31 + 原生 JS + Leaflet + socket.io-client | 可运行可打包 exe（portable/nsis） |
| 服务端（`server/`） | Node.js 20 + Express 4 + SQLite/MySQL + Socket.io 4 | 已部署 43.157.17.88:3000，32 项冒烟测试 |
| 方案文档 | `docs/方案文档.md` | 原始落地方案（180 行） |

三端完全互联：共用同一服务器与账号体系，聊天/动态/互换/信用分实时同步。

---

## 2. 技术栈与目录结构

```
D:\AI\exchange\
├── Jiyu.xcodeproj/          # Xcode 工程
├── Jiyu/                    # iOS 端（SwiftUI）
│   ├── App/                 # 入口 + 4 Tab 主框架 + 启动路由
│   ├── Support/             # AppConfig(含 AppState) / Theme / TokenStore
│   ├── Models/              # SkillModel / ServerModels / AgreementModel / EvaluateModel / ChatModels
│   ├── Core/                # SkillMatchManager / TradeRiskControlManager / CreditScoreManager / AgreementManager / ExposureService
│   ├── Services/            # APIClient / RealtimeClient / NotificationService / MockDataStore
│   └── Views/               # Auth / Match / Feed / Chat / Agreement / Evaluate / Profile / Components
├── server/                  # 服务端（Node.js ESM）
│   ├── src/                 # index / config / db / schema / middleware / risk / socket
│   │   └── routes/          # auth / profile / match / chat / social
│   ├── test/smoke.mjs       # 32 项端到端冒烟测试
│   └── data/jiyu.db         # SQLite 开发库
├── win-app/                 # Windows 端（Electron）
│   ├── main.js              # 主进程（窗口/IPC flash/外链）
│   ├── src/                 # api.js(核心层) / views.js(视图层 1021 行) / app.js(启动导航) / map.js / index.html / style.css
│   └── test-core.js         # 23 项核心测试（直连真实服务器）
└── docs/方案文档.md          # 产品方案存档
```

---

## 3. 服务端审计（server/）

### 3.1 技术要点
- Express 4 + Socket.io 4；**无 ORM**，统一 `exec/run/get/all` 封装，SQLite（开发，`node:sqlite`）/ MySQL（生产，mysql2）双驱动，DDL 两套逻辑一致。
- JWT 鉴权（HS256，7 天，无服务端存储/无黑名单/无刷新）；bcrypt 密码哈希。
- multer 文件上传（`/api/upload`，50MB 上限，静态托管 `/uploads`）。
- 幂等 ALTER 迁移 4 列（avatar_url / image_base64 / media_type / media_url）。
- 演示账号 aqing/123456 + 10 位种子用户；`AUTO_SEED` 可控。

### 3.2 数据库（8 张表，无外键，关系由应用层维护）

| 表 | 关键字段 | 说明 |
|---|---|---|
| users | username, password_hash, nickname, avatar_symbol, avatar_url, bio, location_label, distance_km, credit_score(默认80), verification(none/student/realname/full), is_exposure_vip, exposure_until, violation_count, created_at | 用户（含信用分/认证/曝光） |
| skills | user_id, kind(teach/want), name, level(beginner/skilled/master), exchange_type(online/offline/both), available_time | 技能档案（我擅长/我想学） |
| agreements | user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, content(6条官方模板+约定), signed_at | 互换协议 |
| exchange_records | user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, status(pending/ongoing/completed/cancelled), evaluate_given, created_at | 互换记录 |
| evaluations | record_id, from_user_id, to_user_id, punctuality, serious, communication, comment | 三维度评价 |
| dynamics | user_id, content, image_base64, is_system_post | 动态区（图片 base64 内嵌） |
| conversations | user_a(<user_b), user_b, last_message_text, last_time, unread_a, unread_b, UNIQUE(user_a,user_b) | 会话 |
| messages | conversation_id, sender_id, text, media_type(image/video/audio), media_url, is_system_note, created_at | 消息 |

### 3.3 REST API 全清单（22 个端点）

| 方法 | 路径 | 认证 | 用途 |
|---|---|---|---|
| GET | /api/health | 无 | 健康检查 |
| GET | /api/version | 无 | 版本更新检查（current=1.1） |
| POST | /api/upload | 需 | multipart 文件上传（≤50MB）→ {url} |
| GET | /uploads/* | 无 | 静态文件 |
| POST | /api/auth/register | 无 | 注册（username≥3/password≥6，bcrypt，409 重名） |
| POST | /api/auth/login | 无 | 登录（401 不区分用户/密码错误） |
| GET | /api/me（= /api/auth/me） | 需 | 我的档案（含技能） |
| PUT | /api/me/profile | 需 | 更新 bio/locationLabel/distanceKm/avatarUrl（bio 过风控） |
| POST | /api/me/skills | 需 | 添加技能 {kind, skill{skillName, skillLevel, exchangeType, availableTime}}（名称过风控） |
| DELETE | /api/me/skills/:kind/:id | 需 | 删除技能（归属校验） |
| PUT | /api/me/verification | 需 | 认证等级设置（模拟，无审核） |
| PUT/DELETE | /api/me/exposure | 需 | 曝光开通/取消（day/week/month，模拟付费） |
| GET | /api/users、/api/users/:id | 需 | 用户列表/单用户（公开档案） |
| GET | /api/match | 需 | **双向匹配**（nearbyOnly/type/keyword/minCredit 过滤） |
| GET | /api/conversations | 需 | 会话列表（含 partner 快照与 unreadCount） |
| POST | /api/conversations/open | 需 | 打开/创建会话（自动欢迎语+协议提醒系统消息） |
| GET | /api/conversations/:id/messages | 需 | 历史消息（limit≤200，before 游标分页，hasMore） |
| POST | /api/conversations/:id/read | 需 | 标记已读 |
| POST | /api/messages | 需 | 发消息（REST 兜底，与 Socket 共用 saveMessage） |
| GET | /api/agreements | 需 | 协议列表 |
| POST | /api/agreements | 需 | 签署协议（线下必填地点；写协议+互换记录+match:push 推送） |
| GET | /api/exchanges | 需 | 互换记录 |
| POST | /api/exchanges/:id/complete | 需 | 标记互换完成 |
| POST | /api/evaluations | 需 | 提交评价 → 服务端重算对方信用分 |
| GET | /api/evaluations/:userId | 需 | 评价列表（⚠️ 返回原始 snake_case 行） |
| GET | /api/dynamics | 需 | 动态流（LIMIT 200） |
| POST | /api/dynamics | 需 | 发布动态（文本风控 403 + imageBase64 ≤3MB） |
| POST | /api/dynamics/delete | 需 | 删除自己的动态 |

### 3.4 Socket.io 事件
| 事件 | 方向 | 说明 |
|---|---|---|
| handshake auth.token | C→S | JWT 校验，失败 connect_error |
| chat:send | C→S | 发消息（服务端风控→落库→广播），ack {ok, blocked, warning} |
| chat:message | S→C | 双房间广播（发送方也收，靠 senderId 区分）；含风控系统提示 |
| match:push | S→C | 协议签署后推送对方（type:'agreement'） |

### 3.5 核心业务逻辑
- **双向匹配**：teachForThem ∩ want 且 learnFromThem ∩ want 均非空；模糊子串匹配（长度≥2）；过滤（minCredit→同城≤10km→交换方式→关键词）；排序（VIP→信用降→距离升）。
- **风控**：31 个违禁词（收费/付费/转账/红包/接单/有偿/多少钱/价格…）；聊天前置过滤（原文不落库，改插系统提示并广播）；动态/技能名/bio 同样过滤；三级处罚（警告→限流→封禁）**仅定义未接入**；图片风控占位。
- **信用分**：初始 80；`Σ(三维均值)/条数 × 20`，clamp [0,100]。
- **聊天必达**：Socket 优先 + REST 兜底共用 saveMessage；未读数双向维护；游标分页。
- **曝光**：day 3元/week 12元/month 30元（weight 定义未参与排序；模拟付费无 IAP）。

### 3.6 审计缺口（迁移时需补齐）
1. 三级处罚闭环未落地（violation_count 无写入路径）
2. 图像风控占位（checkImageRisk 恒合规）
3. 曝光 weight 未用、过期不失效、无 IAP 校验
4. token 无状态（无黑名单/刷新）
5. 事务一致性：协议+互换记录双写在事务外；evaluations 无唯一约束
6. N+1 查询、dynamics 无游标、无索引
7. 安全：cors 全开、无 rate limit、无 helmet、上传不校验 MIME、JWT_SECRET 默认值
8. 距离为手填静态值（无真实定位）

---

## 4. iOS 端审计（Jiyu/，35 个 Swift 文件）

### 4.1 架构分层
- **App/**：`JiyuApp`(@main 三态路由 Launch/Login/ContentView) + `ContentView`(4 Tab：技能匹配/互换动态/消息/我的，消息 Tab 带未读角标)
- **Support/**：`AppConfig`(服务器地址 + AppState @MainActor ObservableObject)、`Theme`(设计系统)、`TokenStore`(JWT + 多账号 UserDefaults)
- **Models/**：SkillModel(UserModel/SkillModel/枚举)、ServerModels(服务端 DTO + id 确定性映射 UUID↔数字)、AgreementModel、EvaluateModel(三维度)、ChatModels(Conversation/ChatMessage/DynamicModel)
- **Core/**（纯算法，无 UI/网络）：
  - SkillMatchManager：双向匹配 + 模糊子串 + 过滤 + 排序（与服务端算法一致）
  - TradeRiskControlManager：31 违禁词 + filterChatMessage 前置过滤 + checkImageRisk 占位 + penaltyLevel
  - CreditScoreManager：信用分公式 + 违规扣分 + 等级（S/A/B/C）
  - AgreementManager：6 条官方模板 + 签署生成
  - ExposureService：三套餐定义 + 模拟开通
- **Services/**：APIClient(22+ 端点封装)、RealtimeClient(Socket.io)、NotificationService(本地通知)、MockDataStore(全局数据中枢 ObservableObject 单例)
- **Views/**：Auth(Match/Feed/Chat/Agreement/Evaluate/Profile/Components)

### 4.2 状态管理
- 双全局 ObservableObject：`AppState`(登录态路由) + `MockDataStore`(全部业务 @Published 状态)
- 登录 → activateServerSession → refreshAll()(5 端点并行) → 挂接 RealtimeClient → connect
- Socket 新消息 → 写缓存 + 更新会话预览 + 未读+1 + 本地通知
- 评价 → 服务端返回 newCreditScore → 更新对方缓存
- unreadTotal → 消息 Tab badge
- **双模式**：`isServerMode = serverUserID != nil`；演示模式（9 组示例用户）实际被登录守卫隔离，UI 不可达，属离线兜底。

### 4.3 关键发现
- ⚠️ **匹配算法双轨**：iOS UI 用**本地 SkillMatchManager**（基于 GET /api/users 快照）计算匹配，`/api/match` 封装闲置 → 服务端排序/过滤不生效。迁移时应收敛（服务端权威或明确双轨对齐）。
- ⚠️ 曝光 weight 仅展示；评价维度（三维）与方案文档（四维）不一致；协议时间为自由文本；互换无"取消"UI。
- ⚠️ token 明文 UserDefaults（非 Keychain）；baseURL HTTP 明文。
- 媒体：图片 1280px/jpeg0.7 压缩上传；视频原样上传；语音 AAC m4a 录音；动态图片 base64(1024px)；头像 512px。

---

## 5. Windows 端审计（win-app/，Electron）

### 5.1 架构
- 主进程 main.js（52 行）：窗口 1100×760、`nodeIntegration:true + contextIsolation:false`、IPC `flash` 任务栏闪烁、外链转系统浏览器。
- 渲染进程：index.html 加载 socket.io → api.js(核心层 REST+socket+App.state) → views.js(视图层 1021 行) → map.js(Leaflet) → app.js(启动导航)。
- **分层清晰**（核心层与视图层解耦，api.js 可在 Node 测试）——值得保留的设计。
- CSP 定向放行服务器 HTTP/WS 与 data/blob。

### 5.2 视图清单
- 主视图：登录页（含已保存账号一键切换）、技能匹配（chips 筛选+搜索+地图入口）、互换动态、消息（左右分栏聊天）、我的（双栏网格）。
- 弹窗：匹配详情/协议签署/发布动态/用户资料卡/技能编辑/曝光服务/双向评价/静态文本(协议+风控规则)/我的动态历史/同步记录首启弹窗/版本更新。
- 浮层：全屏查看（图片/视频/语音）、拍照预览（发送前确认）、新消息弹窗、风控拦截横幅、同城地图、Toast。
- 媒体：图片压缩 1280px、视频≤50MB、拍照 getUserMedia、语音 WebM 录制、上传走 /api/upload。
- 地图：Leaflet + OSM 瓦片，8 个北京区级中心 + 哈希偏移伪坐标（非真实定位），真实定位可选授权。

### 5.3 本地存储
- localStorage：`jiyu.token`(明文)、`jiyu.accounts`(多账号含 token 明文)、`jiyu.syncHistory`、`jiyu.syncChosen`。
- 聊天缓存仅内存（跨设备历史从服务器拉取，受同步开关控制）。

### 5.4 测试
- test-core.js：11 组 23 个断言，直连真实服务器（⚠️ 会写真实数据：发消息/发动态/签协议/评价/改头像）。
- README 声称 19 项与代码 23 项不符（文档滞后）。

---

## 6. 三端功能对齐现状（New Project Feature Inventory）

| # | 业务功能 | Server | iOS | Windows | 通道 |
|---|---|---|---|---|---|
| 1 | 注册/登录（用户名+密码） | ✅ | ✅ | ✅ | REST |
| 2 | 多账号保存/一键切换/自动登录 | — | ✅ | ✅ | 本地 + /api/me |
| 3 | 用户档案（bio/头像/地点/距离/信用/认证/曝光） | ✅ | ✅ | ✅ | REST |
| 4 | 技能档案 CRUD（teach/want） | ✅ | ✅ | ✅ | REST |
| 5 | 双向匹配（交集+模糊+过滤+排序） | ✅ | ⚠️本地算法 | ✅(透传服务端) | REST |
| 6 | 同城 10km 过滤 / 地图 | 数据字段 | MapKit 区级示意 | Leaflet 区级示意 | 部分本地 |
| 7 | 互换协议签署（官方模板+线下地点校验） | ✅ | ✅ | ✅ | REST + match:push |
| 8 | 互换记录/状态流转/完成 | ✅ | ✅ | ✅ | REST |
| 9 | 双向评价+信用分重算 | ✅ | ✅ | ✅ | REST |
| 10 | 动态发布/删除/列表（图片 base64） | ✅ | ✅ | ✅ | REST |
| 11 | 会话列表/打开/已读/未读 | ✅ | ✅ | ✅ | REST |
| 12 | 聊天历史分页/同步开关 | ✅ | ✅ | ✅ | REST |
| 13 | 文本消息（Socket 实时 + REST 兜底 + 风控） | ✅ | ✅ | ✅ | Socket/REST |
| 14 | 媒体消息（图片/视频/语音/拍照） | ✅ | ✅ | ✅ | upload + REST |
| 15 | 实时推送（chat:message/match:push + 本地通知 + 桌面通知 + 任务栏闪烁） | ✅ | ✅ | ✅ | Socket + 本地 |
| 16 | 文本风控（31 词 + 系统提示 + 三级处罚定义） | ✅ | ✅ | ✅ | 服务端权威 |
| 17 | 认证（学生/实名，模拟） | ✅(模拟) | ✅(模拟) | ✅(模拟) | REST |
| 18 | 曝光套餐（日/周/月，模拟付费） | ✅(模拟) | ✅(模拟) | ✅(模拟) | REST |
| 19 | 文件上传（≤50MB） | ✅ | ✅ | ✅ | REST |
| 20 | 版本检查/更新提示 | ✅ | ✅ | ✅ | REST |
| 21 | 健康检查/种子数据/双 DB 驱动 | ✅ | — | — | — |
| 22 | 图片风控 / 处罚闭环 / IAP / 推送 APNs | ❌占位/❌ | ❌ | ❌ | 待补齐 |

---

## 7. 对新项目的总体结论（供迁移决策）

1. **架构形态适合继续扩展**：Server-Centric（业务规则服务端权威）+ 双端薄客户端，与新领域（宠物护理）接入模式一致——加新表/新路由/新 DTO/新视图即可，无需改骨架。
2. **共享核心的现实约束**：iOS 是 Swift，Windows/Server 是 JS。真正的"shared-core"分两层：
   - **契约层**（跨三端可共享）：DTO/端点/状态机/枚举 的单一事实来源（OpenAPI/JSON Schema），Swift 与 TS 各自生成/镜像。
   - **算法层**：TS 共享包可被 server + win-app 直接复用；Swift 需镜像实现 + **parity test**（同一输入 → 同一输出）保证一致性。宠物向导配置/校验/格式化算法均可这样落地。
3. **必须收敛的双轨**：iOS 本地匹配算法 vs 服务端 /api/match —— 迁移宠物域时统一为服务端权威，客户端仅缓存。
4. **零金钱政策对宠物域的影响**：旧巡六的定价模型（¥45/天 等）与技遇"纯公益零金钱"冲突 → 宠物服务按"服务互换"语义重构（我提供宠物照顾 ↔ 你教我技能），或作为业务决策另行放开（见矩阵与计划中的决策项）。
5. **需补齐的工程缺口**：风控处罚闭环、图片审核、曝光计费校验、事务一致性、token 安全（Keychain/HTTPS）、定位真实化、测试隔离。

---

## 8. 关键文件索引（迁移时改动目标）

| 层 | 文件 |
|---|---|
| Server | `server/src/schema.js`（新表）、`server/src/routes/*`（新路由 pet.js/booking.js）、`server/src/middleware.js`（新 serialize*）、`server/src/risk.js`（宠物域词表扩展） |
| iOS | `Jiyu/Models/*`（Pet 模型）、`Jiyu/Core/*`（宠物校验/向导镜像）、`Jiyu/Services/MockDataStore.swift`（新状态）、`Jiyu/Views/*`（宠物视图） |
| Windows | `win-app/src/api.js`（新端点）、`win-app/src/views.js`（宠物视图）、`win-app/src/style.css` |
| 共享 | 新建契约仓库（OpenAPI）或 `shared/` TS 包 + Swift 镜像 + parity tests |
