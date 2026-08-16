# 技遇 · 技能互换平台（iOS + Windows 双端）

> **技遇** —— 纯公益技能互换平台：技能互换全程零金钱；另含宠物护理服务（巡六迁移），该模块为收费服务，平台收取 10% 佣金，其余归服务人员。

本项目由《技遇 全流程落地方案》落地为**完整可运行的三端工程**：

| 端 | 技术栈 | 状态 |
|---|---|---|
| **iOS**（`Jiyu.xcodeproj`） | SwiftUI + Swift 5.9，云端 CI 打包 | ✅ 可构建可安装（含全部功能） |
| **Windows**（`win-app/`） | Electron + 原生 JS，本机直接运行 | ✅ 可运行可打包 exe，35 项核心测试通过 |
| **服务器**（`server/`） | Node.js + Express + SQLite/MySQL + Socket.io | ✅ 已部署上线（43.157.17.88:3000） |

**三端完全互联**：iOS 与 Windows 共用同一服务器与账号体系，聊天记录、动态、互换、信用分实时同步。

---

## 一、快速开始

### Windows 版（本机直接跑，最快）

```bash
cd win-app
npm install
npm start            # 打开「技遇」桌面应用（已连接线上服务器）
```

### iOS 版

1. 将整个 `D:\AI\exchange` 目录拷贝到 Mac（本工程在 Windows 上编写，未在本机编译）。
2. 双击打开 `Jiyu.xcodeproj`（需要 **Xcode 15+**，部署目标 **iOS 16.0+**）。
3. 选择模拟器（iPhone 14 及以上机型），点击 **Run** 即可运行，无需配置任何账号。
   - 真机运行：在 Signing & Capabilities 中勾选 Automatically manage signing 并选择你的开发团队。

> ⚠️ iOS 工程已接入真实后端（登录页，演示账号 `aqing / 123456`）；Windows 版直接连接线上服务器，无需任何配置。

### 真机测试（在自己 iPhone 上运行）

**方式 A：有 Mac（免费，最推荐）**
1. Mac 安装 Xcode（App Store 免费），拷贝本目录到 Mac，打开 `Jiyu.xcodeproj`
2. 用数据线连接 iPhone，iPhone 上点「信任此电脑」
3. Xcode：Signing & Capabilities → 勾选 Automatically manage signing → Team 选择自己的 Apple ID（免费账号即可，Xcode 会提示 Add an Account）
4. 顶部运行目标从模拟器切换为你的 iPhone，点 Run → 首次安装需在 iPhone 设置 → 通用 → VPN与设备管理 → 信任开发者证书
5. 免费个人签名有效期 **7 天**，到期后在 Xcode 重新 Run 一次即可续期

**方式 B：没有 Mac（免费，Windows + 云端打包）**
1. 在 GitHub 创建仓库，推送到 GitHub（三条命令见下方「推送命令」）
2. 仓库 Actions 页 → 左侧 **Build IPA** → **Run workflow**（约 5-10 分钟），完成后下载 Artifacts 里的 `Jiyu-unsigned.ipa`
3. Windows 安装 [Sideloadly](https://sideloadly.io/)（免费）→ iPhone 数据线连接电脑并「信任」
4. Sideloadly 中拖入 .ipa → 输入你的 Apple ID → Start（首次需在 iPhone 设置里开启 **开发者模式**：设置 → 隐私与安全性 → 开发者模式）
5. 免费签名同样 7 天有效，到期重装一次即可

**方式 C：TestFlight 内测（正式分发，需 $99/年开发者账号）**
1. Mac + Xcode：Product → Archive → Distribute App → App Store Connect
2. 在 App Store Connect 添加 TestFlight 测试员，最多 100 人，90 天有效期

### 推送命令（触发云端打包）

```bash
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git branch -M main
git push -u origin main
```

## 二、方案落地对照表

| 方案章节 | 模块 | 落地文件 |
|---|---|---|
| 2.1 设计风格 | 浅青蓝主色 / 暖白 / 淡橙 / 极简 iOS 风格 | `Jiyu/Support/Theme.swift` |
| 2.2 五大模块 | 技能主页 / 双向匹配 / 线上线下交换 / 协议评价 / 风控 | 全部视图 |
| 2.3.1 技能档案 | 我擅长 / 我想学 / 熟练度 / 交换方式 / 学生+实名认证 | `Models/SkillModel.swift`、`ProfileEditView.swift`、`MineView.swift` |
| 2.3.2 双向匹配 | 双向交集算法 / 距离 / 类型 / 信用过滤 / VIP 加权排序 | `Core/SkillMatchManager.swift`、`MatchHomeView.swift` |
| 2.3.3 双场景交换 | 内置 IM 聊天 + 风控拦截 / 同城距离 / 线下地点报备 | `Views/Chat/*`、`ExchangeDynamicView.swift` |
| 2.3.4 互换协议 | 官方协议模板 / 签署前置校验 / 线下公共场所强制填写 | `Core/AgreementManager.swift`、`AgreementView.swift` |
| 2.3.5 信用评价 | 三维度互评 / 信用分 0-100 / 初始 80 分 | `Core/CreditScoreManager.swift`、`EvaluateView.swift` |
| 2.3.6 零金钱风控 | 违禁词拦截 / 消息前置过滤 / 动态区风控 / 三级处罚 | `Core/TradeRiskControlManager.swift` |
| 3.1 曝光盈利 | 日/周/月套餐、匹配加权、主页置顶（模拟开通） | `Core/ExposureService.swift`、`ExposureView.swift` |
| 4.2 分层架构 | 表现层 / 业务层 / 数据层 分层 | `App+Views / Core / Services` 目录 |

## 三、工程结构

```
exchange/
├── Jiyu.xcodeproj/            # Xcode 工程（objectVersion 56，Xcode 14+ 兼容）
├── Jiyu/
│   ├── App/                   # 入口与主框架
│   │   ├── JiyuApp.swift      # @main 入口
│   │   └── ContentView.swift  # 5 Tab：匹配/动态/消息/宠物/我的
│   ├── Support/               # 设计系统
│   │   └── Theme.swift        # 颜色/渐变/时间格式
│   ├── Models/                # 数据模型（方案 5.1）
│   │   ├── SkillModel.swift   # SkillLevel / ExchangeType / SkillModel / UserModel
│   │   ├── AgreementModel.swift  # 协议 & 互换记录
│   │   ├── EvaluateModel.swift   # 评价维度
│   │   └── ChatModels.swift   # 会话 / 消息 / 动态
│   ├── Core/                  # 业务层（方案 5.2-5.5）
│   │   ├── SkillMatchManager.swift     # 双向匹配算法
│   │   ├── TradeRiskControlManager.swift # 零金钱交易风控
│   │   ├── CreditScoreManager.swift    # 信用分计算
│   │   ├── AgreementManager.swift      # 协议模板与签署
│   │   └── ExposureService.swift       # 曝光增值服务
│   ├── Services/              # 数据层
│   │   └── MockDataStore.swift # 全局数据（已接真实后端：登录/动态/聊天/宠物均走服务器 API）
│   ├── Views/                 # 表现层（SwiftUI）
│   │   ├── Match/             # 匹配首页 / 匹配详情
│   │   ├── Feed/              # 互换动态（含发布风控）
│   │   ├── Chat/              # 会话列表 / 聊天（风控拦截）
│   │   ├── Profile/           # 我的 / 技能档案编辑 / 曝光服务
│   │   ├── Agreement/         # 互换协议签署
│   │   ├── Evaluate/          # 双向互评
│   │   └── Components/        # 通用组件
│   └── Assets.xcassets/       # AppIcon（已生成）/ AccentColor
├── server/                    # 后端服务（Node.js + Express + MySQL/SQLite + Socket.io）
│   ├── src/                   # 路由/匹配算法/风控/聊天/推送（32 项测试全部通过）
│   ├── test/smoke.mjs         # 端到端冒烟测试
│   └── README.md              # 启动/部署/API 文档
├── win-app/                   # Windows 桌面版（Electron，与 iOS 功能一致）
│   ├── src/                   # 登录/匹配/动态/消息/我的 + 同城地图 + 拍照/语音
│   ├── test-core.js           # 核心逻辑测试（35 项全过，真实服务器）
│   └── README.md              # 运行/打包/功能文档
├── docs/
│   └── 方案文档.md            # 原始落地方案全文
└── README.md
```

## 四、核心算法说明

### 4.1 双向匹配（方案 5.2）
```
我擅长的技能 ∩ 对方想学的技能 ≠ ∅  且  对方擅长的技能 ∩ 我想学的技能 ≠ ∅  → 匹配
```
- 支持**模糊匹配**：如「视频剪辑」↔「剪辑」互为子串即可命中
- 排序规则：**曝光 VIP 优先 → 信用分高优先 → 距离近优先**
- 示例数据内置 6 组可匹配用户与 4 组不可匹配用户，用于验证算法正确性

### 4.2 交易风控（方案 5.3）
- 30+ 违禁词库（收费/付费/转账/红包/接单/有偿/收款码…），命中即拦截
- 聊天消息**前置过滤**：违规消息不发，仅追加系统提示
- 动态发布、个人主页文本同样走风控
- 图片风控预留 `checkImageRisk` 接口（正式版接百度 AI 审核 SDK）
- 处罚阶梯：首次警告 → 二次限流 → 三次封禁
- **例外**：宠物护理订单（巡六迁移）为收费服务，金额是结构化字段（服务定价/佣金/服务人员所得），不经过文本风控；技能互换仍严格零金钱

### 4.3 信用分（方案 5.5）
```
综合信用分 = Σ(守时度 + 认真度 + 沟通体验)/3 × 20，范围 0-100，无评价时初始 80
```

### 4.4 宠物护理收费订单（巡六迁移）
| 项目 | 说明 |
|---|---|
| 服务目录 | 7 种：寄养过夜 ¥45 / 过夜看护 ¥50 / 当日寄养 ¥35 / 遛狗 ¥20 / 上门喂食 ¥15 / 洗澡 ¥30 / 美容 ¥40 |
| 下单方式 | **发起订单**：① 直接指定认识的看护人；② 发布到互换动态区，等待有资历的人接单 |
| 接单资历 | 信用 ≥ 75 且已完成实名/学生认证（不能接自己的单） |
| 金额结算 | 平台佣金 = 价格 × 10%，其余归服务人员（如 ¥45 → 佣金 ¥4.5 → 服务人员 ¥40.5） |
| 支付渠道 | ⚠️ 当前为结构化记账（服务定价/佣金/所得字段），真实支付网关（微信/支付宝/Apple IAP）为 TODO |
| 订单状态 | open（待接单）→ assigned（已接单）→ completed（已完成）|

## 五、可演示流程

1. **匹配**：打开「技能匹配」→ 看到 6 位双向匹配用户（VIP 用户排前）→ 切换「同城 10km」过滤远距离用户
2. **互换**：进入详情 → 「发起互换邀约」→ 选择技能/时间/地点 → 签署官方协议 → 生成互换记录
3. **聊天**：「私信沟通」→ 输入含「价格」等违禁词的消息 → 被风控拦截并显示系统提示
4. **评价**：「我的 → 我的互换」→ 标记完成 → 去评价（五星三维度）→ 对方信用分更新
5. **盈利演示**：「我的 → 技能曝光服务」→ 模拟开通日/周/月卡 → 匹配列表 VIP 优先展示

## 六、正式版接入清单（TODO）

- [ ] 后端：Node.js + Express + MySQL（用户/技能/互换/评价/风控日志表），替换 `MockDataStore`
- [ ] 实时消息：Socket.io 替换本地 `messagesByConversation`
- [ ] 定位：高德地图 iOS SDK，真实距离计算与线下地点报备
- [ ] 实名/学生认证：学信网接口 + 实名认证服务商
- [ ] 图片风控：百度 AI 内容审核 SDK（`TradeRiskControlManager.checkImageRisk`）
- [ ] 曝光购买：苹果 IAP（曝光属虚拟服务，按 App Store 审核规范必须走内购）
- [ ] 图片资源：头像/动态图片上传（替换 SF Symbol 占位）
- [ ] 宠物订单真实支付：微信支付/支付宝/Apple IAP（当前为结构化记账）
- [ ] 版本迭代：V1.1 同城线下活动报名、信用榜单、违规申诉；V1.2 技能社群、达人认证

## 七、上架合规要点（方案七）

- 技能互换全程无金钱交易、无商品售卖、无用户资金往来 → 规避苹果内购交易违规风险
- 宠物护理收费订单走结构化金额（服务定价 + 平台佣金），支付通道正式版必须通过 StoreKit/合规支付渠道接入
- 盈利点：宠物服务佣金（10%）+ 曝光服务费（IAP）+ 线下活动组织服务费（技术/服务费）→ 合规可过审
- `Info.plist` 已内置定位/相册/相机权限文案、用户协议与风控规则入口
- 线上支付接口在正式版中必须通过 StoreKit 实现，严禁接入第三方支付

## 八、技术栈

Swift 5.9 · SwiftUI（iOS 16+）· Xcode 15+ · 全原生，无第三方依赖（Mock 阶段）
