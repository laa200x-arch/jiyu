# TARGET_ARCHITECTURE — 目标架构：技遇（技能/服务互换平台）+ 宠物护理服务域

> 本文档定义「旧巡六迁移 + 新项目扩展」后的目标架构。
> **新项目优先**：一切设计以技遇现有三端体系为基座，旧微信项目只提供业务语义参考。
> 禁止：WxAdapter / WechatCompatibility / MiniProgramBridge / FakeWxAPI 等任何兼容层。

---

## 1. 目标产品形态

```
技遇（Jiyu）—— 纯公益技能/服务互换平台
├── 核心域：技能互换（现状：匹配 / 协议 / 聊天 / 评价 / 信用 / 风控 / 曝光）
└── 新服务域：宠物护理（旧巡六迁移）
     ├── 宠物档案（Pet Profile）：结构化档案 + 六步向导 + 行为字典
     ├── 宠物服务目录（Care Services）：寄养/上门看护/探访/日托/遛狗/训练
     ├── 服务提供者（Caregiver）：宠物护理技能声明 + 可照顾类型/时段
     ├── 护理预约（Care Booking）：互换协议载体（零金钱）
     └── 服务匹配：宠物护理需求 ↔ 看护人技能（复用双向匹配）
```

**一句话**：宠物护理作为"可互换的服务技能"接入技遇现有的
匹配 → 协议 → 聊天 → 评价 → 信用 → 风控 全链路，三端数据完全互通。

---

## 2. 总体架构

```
                    ┌─────────────────────────────┐
                    │        Contract Layer        │  ← 单一事实来源
                    │  OpenAPI / JSON Schema DTOs  │     （三端共享）
                    │  枚举 / 状态机 / 错误码定义    │
                    └──────────────┬──────────────┘
                                   │ 生成 / 镜像
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼────────┐        ┌────────▼────────┐        ┌────────▼────────┐
│   iOS App      │        │  Windows App    │        │    Backend      │
│  (SwiftUI)     │        │  (Electron)     │        │  (Node+Express  │
│                │        │                 │        │   +SQLite/MySQL │
│  薄客户端：      │        │  薄客户端：       │        │   +Socket.io)   │
│  - 视图/交互    │        │  - 视图/交互     │        │                 │
│  - 本地缓存     │        │  - 本地缓存      │        │  业务规则权威：   │
│  - 算法镜像     │        │  - 复用 TS 包    │        │  - 匹配/风控/信用 │
│  (parity)      │        │  (shared-core)  │        │  - 状态机/校验   │
└───────┬────────┘        └────────┬────────┘        │  - 宠物域 API    │
        │                          │                 └────────┬────────┘
        └──────────── REST / Socket.io (JWT) ──────────────────┘
                        （数据互通：账号/档案/预约/消息/信用）
```

### 2.1 Shared Core 的现实策略（Swift ≠ JS 的关键决策）

技遇两端语言不同（iOS=Swift，Windows=JS），"共享代码"分两层实现：

| 层 | 载体 | 共享方式 | 示例 |
|---|---|---|---|
| **契约层**（必须共享） | OpenAPI / JSON Schema 文档（建议入库 `shared/contracts/`） | 三端按契约生成/镜像 DTO 与枚举；`serialize*` 与 Swift Codable 对齐（技遇已有此实践） | PetDTO、CareBookingDTO、状态枚举 |
| **算法层**（尽量共享） | TypeScript 包 `shared-core/`（server + win-app 直接复用） | Swift 侧写**镜像实现** + **parity test**（同一输入→同一输出，CI 双跑） | 宠物校验、向导配置、格式化、预约状态机、行为字典 |

> 技遇现有经验可直接复用：`serializeUser/serializeSkill`（snake_case DB → camelCase JSON）与 iOS `ServerModels.swift`（camelCase Codable）已经是一套"手写契约对齐"实践；升级为机器可读的 OpenAPI 即可。

### 2.2 算法权威原则（收敛双轨）

- **业务规则单一权威 = 服务端**：匹配排序、风控、信用分、状态机、宠物校验以 `server/` 实现为准。
- 客户端（iOS/Windows）只做：展示、交互、本地缓存、离线兜底（用同一规则的镜像实现）。
- 现有缺口须收敛：iOS 本地 SkillMatchManager 计算匹配 → 改为调用 `GET /api/match`（见决策 D-05）。

---

## 3. 宠物护理领域设计

### 3.1 数据模型（新增表，与现有 8 表同风格：无 FK、ISO-8601、snake_case）

```sql
-- 宠物档案（F-20~F-26 迁移）
CREATE TABLE IF NOT EXISTS pets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,              -- → users.id
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('dog','cat','rabbit','bird','other')),
  breed TEXT NOT NULL DEFAULT '',
  age_months INTEGER NOT NULL DEFAULT 0,  -- 0–180（旧校验封顶迁移）
  gender TEXT NOT NULL CHECK (gender IN ('male','female')),
  spayed_neutered TEXT NOT NULL DEFAULT 'unsure' CHECK (spayed_neutered IN ('yes','no','unsure')),
  weight_class TEXT,                      -- cat: small/medium/large/xl
  behaviors_json TEXT NOT NULL DEFAULT '[]',     -- 行为字典 id 数组（shared 常量）
  home_reactions_json TEXT NOT NULL DEFAULT '[]',-- 家中反应 id 数组
  photo_url TEXT,                         -- /uploads/...（ImageImportService 上传）
  notes TEXT NOT NULL DEFAULT '',         -- ≤2000 字（旧限制迁移）
  vaccine_status INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

-- 宠物服务目录（F-11/F-12 迁移；价格字段按 D-01 决策，默认无现金定价）
CREATE TABLE IF NOT EXISTS care_services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,              -- boarding/inhome-care/visit/daycare/dog-walking/training
  name TEXT NOT NULL,                     -- 寄养/上门看护/上门探访/日间托管/遛狗/狗狗训练
  category TEXT NOT NULL CHECK (category IN ('overnight','day','other')),
  description TEXT NOT NULL DEFAULT '',
  icon TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 护理预约（F-08 迁移；状态机对齐 exchange_records 风格）
CREATE TABLE IF NOT EXISTS care_bookings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL,              -- 宠物主人
  caregiver_id INTEGER NOT NULL,          -- 看护人
  pet_id INTEGER NOT NULL,                -- → pets.id
  service_code TEXT NOT NULL,             -- → care_services.code
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','ongoing','completed','cancelled')),
  location TEXT,                          -- 线下公共场所（协议语义复用）
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

-- 服务提供者扩展（F-30 REDESIGN；与 users 1:1）
CREATE TABLE IF NOT EXISTS caregiver_profiles (
  user_id INTEGER PRIMARY KEY,            -- → users.id（成为看护人即建档）
  accepted_pet_types TEXT NOT NULL DEFAULT '[]',  -- ['dog','cat']
  availability_json TEXT NOT NULL DEFAULT '{}',   -- {monday:'9:00-18:00',...}
  certifications TEXT NOT NULL DEFAULT '[]',      -- ['Pet CPR','First Aid']
  bio TEXT NOT NULL DEFAULT ''
);
```

> 行为/反应字典（狗 8 项、猫 10 项、家中反应 4 项）与向导步骤配置（STEP_FLOW）
> 作为 **shared-core 常量**（客户端主导），服务端如需下发可升级为 `care_configs` 表（低优先级）。

### 3.2 新增 REST API（风格与现有完全一致：JWT、camelCase、{error} 错误）

| 方法 | 路径 | 用途 | 对应旧功能 |
|---|---|---|---|
| GET | /api/pets | 我的宠物列表 | F-20 |
| POST | /api/pets | 添加宠物（服务端镜像校验 F-24） | F-21 |
| GET | /api/pets/:id | 宠物详情 | F-26 |
| PUT/DELETE | /api/pets/:id | 更新/删除（新能力，旧只有增查） | — |
| GET | /api/care-services | 服务目录 | F-11/F-12 |
| GET | /api/caregivers | 护理服务提供者列表（含档案扩展字段） | F-14 |
| PUT | /api/me/caregiver-profile | 开通/更新看护人档案 | F-30 |
| GET | /api/care-bookings/current | 当前进行中预约（首页卡） | F-08 |
| GET | /api/care-bookings | 预约历史 | F-08 |
| POST | /api/care-bookings | 创建护理预约（协议载体） | 预约下单 |
| POST | /api/care-bookings/:id/complete / cancel | 状态流转 | 状态机 |
| POST | /api/care-bookings/:id/evaluate | 服务评价（复用信用分重算） | 评价 |

### 3.3 与现有模块的整合点

| 现有模块 | 整合方式 |
|---|---|
| **双向匹配** | 看护人把"宠物寄养/遛狗"等声明为 teach 技能（或技能带 `serviceCode` 标记）；宠物主把"需要宠物照顾"声明为 want 技能 → 现有匹配算法天然命中；/api/match 增加服务类型过滤（F-14） |
| **互换协议** | 护理预约 = 协议的一种服务形态：复用 6 条官方模板（纯公益条款），预约时间/地点填入 scheduledTime/location；care_booking 与 exchange_record 可并表（约定时落 exchange_records 以复用评价/信用链路，或独立表+共享评价接口） |
| **聊天** | 预约前后双方直接走现有 IM（caregiver ↔ owner 会话）——零新后端 |
| **评价/信用** | 护理服务完成后走现有三维度评价 → 服务端重算看护人信用分；宠物主人同样被评（守时/沟通） |
| **风控** | 词库已覆盖金钱类；宠物域补充："宠物食品买卖/药物交易"等违规词（可选扩展）；图片审核上线后对宠物照片/服务环境照同样审核 |
| **动态区** | 宠物服务案例/寻宠启事作为话题动态发布（复用风控） |
| **通知** | 预约确认/提醒走现有 match:push + 本地通知（chat:message 通道扩展 booking 事件） |
| **曝光** | 看护人可用曝光提升匹配排序（复用现有机制） |

### 3.4 状态机（旧预约语义 → 新架构）

```
旧（巡六契约）：pending → in-service → completed / cancelled
新（技遇）   ：pending → ongoing   → completed / cancelled   ← 直接对齐现有 exchange_records.status
首页"当前预约"= status IN ('pending','ongoing') 的最新一条（F-08 语义）
```

---

## 4. 零金钱语义下的宠物服务（D-01 推荐方案）

- 宠物护理服务**不标价**：寄养/遛狗等作为"我提供"的服务技能，换取对方的技能/服务（双向对等）。
- 协议模板措辞沿用纯公益条款（可加一条"宠物护理期间的安全与责任"补充条款）。
- 若未来需要商业化（如付费托管），走合规路径：**曝光式服务费 + 苹果 IAP / Windows 支付通道 + 服务端订单**，不得在聊天/档案中出现价格（风控词库继续拦截）。
- 旧 mock 中的价格字段（pricePerDay 等）**不进入**新数据模型（作为 legacy 参考保留在归档）。

---

## 5. 数据互通设计（App ↔ Windows 同一产品）

| 数据 | 权威存储 | 同步机制 | 旧巡六对应 |
|---|---|---|---|
| 账号/Token | server users + JWT | REST 登录 + TokenStore 本地 | F-03 |
| 用户档案/信用 | server users | /api/me + 快照同步（技遇已有 syncUserSnapshot） | F-05 |
| 宠物档案 | server pets | /api/pets CRUD + 本地缓存（PetRepository） | F-20~F-26 |
| 服务目录 | server care_services | /api/care-services（缓存刷新） | F-11/F-12 |
| 护理预约 | server care_bookings | REST + socket booking 事件推送 | F-08 |
| 消息/会话 | server conversations/messages | Socket.io 实时 + REST 分页（已有） | F-16~F-19 |
| 评价/信用分 | server evaluations/users | REST（已有） | 评价 |
| 本地偏好 | 各端本地 | 各端独立（技遇现状） | F-34 |

**核心保证**：App 创建宠物/预约 → Server 保存 → Windows 登录同一账号 → 看到并继续编辑 → App 刷新看到最新状态。（技遇三端同服模式已满足，宠物域沿用同一通道。）

---

## 6. 平台适配矩阵（同一功能，两端不同实现）

| 能力 | App（SwiftUI） | Windows（Electron） |
|---|---|---|
| 宠物添加向导 | 多步 SwiftUI 视图（步骤配置来自 shared） | 分步表单/模态（步骤配置来自 shared TS 包） |
| 宠物照片 | 相册/相机 + 压缩（技遇既有 media 逻辑） | File Picker + 压缩（技遇既有逻辑） |
| 护理预约卡（首页） | 首页卡片（三态） | 顶栏/工作区卡片 |
| 看护人列表 | 匹配列表 + 服务类型筛选 | 匹配列表 + 筛选 chips + 地图 |
| 宠物管理入口 | 我的 Tab（或匹配 Tab 筛选，D-04） | 我的页双栏网格 + 工具列表 |

> UI 不求与旧微信一致：App 适合底部导航 + 全屏流程；Windows 适合 Sidebar/分栏 + 卡片网格（技遇已有双栏/网格设计可直接扩展）。

---

## 7. 工程缺口补齐清单（迁移期间顺手修复，源自审计）

| # | 缺口 | 修复方案 | 优先级 |
|---|---|---|---|
| 1 | 三级处罚未落地（violation_count 无写入） | 风控命中时递增 + 按等级限流/封禁（服务端中间件） | 高（宠物域上线前） |
| 2 | 图片风控占位 | 接百度 AI 审核（宠物照片/动态图/聊天图）或先做尺寸/类型校验 | 中 |
| 3 | iOS 本地匹配双轨 | 收敛为 /api/match（D-05） | 高 |
| 4 | 曝光 weight 未用/过期不失效 | 排序用 weight；过期自动降权 | 低 |
| 5 | 协议+互换记录双写无事务 | 事务包裹（sqlite transaction） | 中 |
| 6 | token 安全 | iOS Keychain、Windows 加密存储（safeStorage）、HTTPS | 高（上线前） |
| 7 | 距离静态手填 | 定位真实化（高德/OSM 逆地理，客户端上报坐标） | 中（宠物同城场景需要） |
| 8 | 测试写生产数据 | 测试环境隔离（本地库 + 独立测试账号） | 中 |
| 9 | 评价维度（三维 vs 方案四维） | 按业务确认后对齐 | 低 |
| 10 | 互换无"取消"UI（枚举有 cancelled） | 补取消入口 + 状态流转 | 低 |

---

## 8. 明确禁止事项（红线）

1. 禁止建立任何微信兼容层（WxAdapter / WechatCompatibility / MiniProgramBridge / FakeWxAPI / ImagePickerAdapter）。
2. 禁止把 WXML/WXSS/Page/Component 生命周期机制带入新项目。
3. 禁止迁移 wx.getStorageSync 等平台调用——按业务意图落地为 Repository / ApiClient / ImageImportService。
4. 禁止把旧项目后端契约（/api/v1/...）当作兼容负担——旧后端从未存在，语义直接融入新端点。
5. 禁止为旧微信用户做长期数据迁移系统（微信已停用；如确有需要，一次性导出脚本即可，不进入产品代码）。
6. 禁止在迁移过程中把技遇改造成旧微信架构（Legacy → New，不是 New ←→ Legacy）。

---

## 9. 目录落地建议（新项目内新增结构）

```
D:\AI\exchange\
├── shared/                       # 新增：跨端共享（建议）
│   ├── contracts/                #   OpenAPI / JSON Schema（宠物域 + 现有域）
│   └── core-ts/                  #   TS 共享包（server + win-app 依赖）
│       ├── pet-domain/           #     宠物模型/字典/向导配置/校验
│       ├── formatters/           #     相对时间/脱敏/年龄…
│       └── booking/              #     预约状态机
├── server/src/routes/pets.js     # 新增：宠物域路由
├── server/src/routes/care.js     # 新增：服务目录/看护人/预约
├── Jiyu/Models/PetModels.swift   # 新增：宠物域模型（契约镜像）
├── Jiyu/Core/PetProfileWizard.swift # 新增：向导编排（shared 镜像）
├── win-app/src/pet-views.js      # 新增：宠物域视图
└── docs/迁移文档/                  # 本套审计文档的归档副本
```
