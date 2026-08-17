# 技遇后端服务（Node.js + Express + MySQL/SQLite + Socket.io）

纯公益技能互换平台的服务端，对应方案 4.1/4.2 技术栈。
**已通过 32 项端到端冒烟测试**（`npm test`）。

## 快速开始（本地，零配置）

```bash
cd server
npm install
npm start          # 默认 SQLite，自动建表 + 填充演示数据
```

- 服务地址：`http://localhost:3000`
- 健康检查：`http://localhost:3000/api/health`
- 演示账号：`aqing / 123456`（阿青），另有 10 个演示用户（林晓/周可/米粒…，密码均 `123456`）

```bash
npm test           # 运行 32 项端到端冒烟测试（需服务已启动）
npm run seed -- --force   # 重建演示数据
```

## 生产部署（MySQL，方案 4.1）

### 方式一：Docker Compose（推荐）

```bash
cd server
cp .env.example .env        # 改 DB_DRIVER=mysql
docker compose up -d mysql
npm install && npm start    # 或：docker compose up -d --build
```

### 方式二：阿里云 ECS 手动部署

```bash
# 1. 安装 Node 20+ 与 MySQL 8
# 2. 建库建账号
mysql -uroot -p -e "CREATE DATABASE jiyu DEFAULT CHARSET utf8mb4; CREATE USER 'jiyu'@'%' IDENTIFIED BY 'jiyu123456'; GRANT ALL ON jiyu.* TO 'jiyu'@'%'; FLUSH PRIVILEGES;"
# 3. 上传 server/ 目录，配置 .env（DB_DRIVER=mysql + JWT_SECRET 随机串）
# 4. 用 PM2 守护进程
npm install
npx pm2 start src/index.js --name jiyu
npx pm2 save && npx pm2 startup
# 5. 安全组放行 3000 端口（或经 Nginx 反代 + HTTPS）
```

## 安全与合规（已加固）

- **手机号隐私**：`GET /api/users` 及他人档案不再返回 `phone` 字段，仅本人接口（登录/注册/`/api/me`）可见
- **宠物订单风控豁免**：宠物订单相关私聊（消息携带 orderId）放行「接单/价格/佣金」等协商词，仍拦截转账/红包/收款码等真实金钱交易词（`risk.js` 分级词库）
- **登录防爆破**：连续失败 5 次锁定 15 分钟（按用户名+IP）
- **上传白名单**：仅 jpg/png/gif/webp/mp4/mov/webm；`/uploads` 响应 `X-Content-Type-Options: nosniff` + `Content-Disposition: attachment`，杜绝存储型 XSS
- **JWT 密钥**：`NODE_ENV=production` 时强制随机 `JWT_SECRET`，默认值直接拒绝启动
- **CORS**：`CORS_ORIGINS` 白名单配置化，原生客户端（无 Origin/file://）放行，浏览器来源仅限白名单
- **过期 VIP**：`exposure_until` 过期后自动视为普通用户（匹配排序/展示一致）
- **明文 HTTP 提示**：线上仍为 `http://43.157.17.88:3000`，正式对外建议配置域名 + HTTPS（证书 + Nginx 反代），并将客户端 `AppConfig.serverBase`/`api.js` 的 BASE 切到 https

> ⚠️ 上线前必改：`.env` 中 `JWT_SECRET` 换成长随机串；配置百度 AI Key 启用图像风控；曝光购买走苹果 IAP 服务端校验。

## 短信验证码（注册手机验证）

通道可插拔（`src/sms.js`，零 SDK 依赖，签名手写实现）：

| `SMS_PROVIDER` | 说明 | 所需环境变量 |
|---|---|---|
| `console`（默认） | 测试通道：验证码直接返回 `devCode` 并自动填入客户端 | 无 |
| `aliyun` | 阿里云短信（RPC v1.0 签名） | `ALIYUN_ACCESS_KEY_ID` / `ALIYUN_ACCESS_KEY_SECRET` / `ALIYUN_SMS_SIGN_NAME` / `ALIYUN_SMS_TEMPLATE_CODE`（模板须含 `${code}`） |
| `tencent` | 腾讯云短信（TC3-HMAC-SHA256 签名） | `TENCENT_SECRET_ID` / `TENCENT_SECRET_KEY` / `TENCENT_SMS_SDK_APP_ID` / `TENCENT_SMS_SIGN_NAME` / `TENCENT_SMS_TEMPLATE_ID`（正文须含 `{1}`）；`TENCENT_SMS_REGION` 可选默认 ap-guangzhou |

- `SMS_DEV_FALLBACK=1`（默认）：真实通道发送失败时降级返回 devCode，测试期不阻断注册
- ⚠️ **生产必须 `SMS_DEV_FALLBACK=0`**：发送失败返回 502 并作废验证码，客户端需稍后重试
- `GET /api/health` 返回 `sms: {provider, configured, devFallback}`，启动日志也会打印短信通道状态

## 架构

```
server/
├── src/
│   ├── index.js        # 入口：Express + HTTP + Socket.io 组装
│   ├── config.js       # 环境配置（.env）
│   ├── db.js           # 双驱动：node:sqlite（内置）/ mysql2（生产）
│   ├── schema.js       # 两套 DDL（8 张表）
│   ├── seed.js         # 演示数据（与 iOS 示例一致）
│   ├── risk.js         # 零金钱交易风控（词库 + 可插拔百度 AI）
│   ├── middleware.js   # JWT 鉴权 + 用户/会话序列化（字段与 iOS Codable 对齐）
│   ├── socket.js       # Socket.io：鉴权 / 房间 / chat:send / match:push
│   └── routes/
│       ├── auth.js     # 注册/登录/我的
│       ├── profile.js  # 资料/技能增删/认证/曝光/用户列表
│       ├── match.js    # 双向匹配算法（VIP→信用→距离排序）
│       ├── social.js   # 协议/互换/评价/动态（含风控与实时推送）
│       └── chat.js     # 会话/消息（REST + Socket 共用落库与风控）
└── test/smoke.mjs      # 32 项端到端测试
```

## API 一览

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | /api/auth/register | 注册 `{username,password,nickname}` → `{token,user}`（手机号选填：填写则强制一手机号一号+验证码） |
| POST | /api/auth/login | 登录 → `{token,user}`（连续失败 5 次锁定 15 分钟防爆破） |
| POST | /api/auth/phone/send-code | 发送注册验证码（手机号选填场景保留） |
| POST | /api/auth/phone/forgot-code | 忘记密码：向已注册手机号发送重置验证码 |
| POST | /api/auth/reset-password | 重置密码 `{phone, code, newPassword}` |
| GET | /api/me | 我的完整档案（含技能） |
| PUT | /api/me/profile | 更新 bio/locationLabel/distanceKm（文本过风控） |
| POST | /api/me/skills | 添加技能 `{kind:'teach'\|'want', skill:{skillName,skillLevel,exchangeType,availableTime}}` |
| DELETE | /api/me/skills/:kind/:id | 删除技能 |
| PUT | /api/me/verification | 认证 `{verification:'student'\|'realname'\|'full'}` |
| PUT/DELETE | /api/me/exposure | 开通/取消曝光 `{packageId:'day'\|'week'\|'month'}` |
| GET | /api/users | 全部用户（公开档案） |
| GET | /api/match | 双向匹配 `?nearbyOnly=1&type=online&keyword=日语&minCredit=80` |
| GET/POST | /api/agreements | 协议列表 / 签署（生成互换记录 + match:push 推送） |
| GET | /api/exchanges | 我的互换记录 |
| POST | /api/exchanges/:id/complete | 标记完成 |
| POST | /api/evaluations | 提交评价 `{recordId,punctuality,serious,communication,comment}` → 信用分重算 |
| GET | /api/evaluations/received | 我收到的评价（含文字评价与申诉状态） |
| POST | /api/evaluations/:id/appeal | 对收到的评价发起申诉 `{reason}`（V1.1 违规申诉） |
| GET | /api/dynamics | 动态列表 |
| POST | /api/dynamics | 发布动态（违禁词 → 403 拦截） |
| GET | /api/conversations | 会话列表（含未读数） |
| POST | /api/conversations/open | 打开/创建与某用户的会话 |
| GET | /api/conversations/:id/messages | 历史消息 |
| POST | /api/conversations/:id/read | 标记已读 |
| POST | /api/messages | 发送消息（违禁词 → 拦截 + 系统提示） |

### Socket.io 事件

| 事件 | 方向 | 说明 |
|---|---|---|
| `auth`（握手 auth.token） | 客户端→服务端 | JWT 鉴权，加入房间 `user:<id>` |
| `chat:send` `{conversationId,text}` | 客户端→服务端 | 发送消息（同 REST 风控），ack 返回 `{ok,blocked,warning}` |
| `chat:message` `{conversationId,text,time,senderId}` | 服务端→双方 | 实时消息广播（含拦截系统提示） |
| `match:push` | 服务端→被邀约方 | 签署协议后实时推送互换邀约 |

## 接口字段对齐说明

所有 JSON 响应使用 camelCase，字段名与 iOS 端 Swift `Codable` 模型**完全一致**
（`userName/avatarSymbol/creditScore/mySkills/wantSkills/isExposureVip/skillName/...`），
客户端可直接 `JSONDecoder` 解码，无需映射层。
