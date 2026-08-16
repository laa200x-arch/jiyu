# 技遇 Windows 桌面版

纯公益技能互换平台 Windows 客户端，与 iOS 版**功能一致、共用同一服务器**（任何设备数据实时同步）。

## 快速开始

```bash
cd win-app
npm install          # 安装依赖（Electron + socket.io + Leaflet）
npm start            # 启动应用（需要显示器）
```

> 首次运行如遇沙箱报错：`npm start -- --no-sandbox` 或设置环境变量 `ELECTRON_DISABLE_SANDBOX=1`。

## 打包独立 exe

```bash
npm run pack         # 生成单文件便携版 exe（dist/ 目录）
npm run dist         # 生成安装版 exe
```

国内网络建议设置镜像加速：
```bash
$env:ELECTRON_MIRROR = 'https://npmmirror.com/mirrors/electron/'
$env:ELECTRON_BUILDER_BINARIES_MIRROR = 'https://npmmirror.com/mirrors/electron-builder-binaries/'
```

## 功能清单（与 iOS 版一致）

| 模块 | 说明 |
|---|---|
| 账号 | 登录/注册、**多账号保存一键切换**（手动删除前保留）、启动自动登录、token 失效自动清理 |
| 匹配 | 双向对等匹配、线上/线下/同城 10km/关键词筛选、VIP 曝光优先、**同城地图**（Leaflet） |
| 互换 | 官方协议签署（线下必须公共场所）、互换记录、标记完成、**双向评价 + 信用分重算** |
| 动态 | 全员动态、**图文发布**（图片自动压缩）、作者资料页、一键私信 |
| 消息 | 实时聊天（Socket.io）、**文本/图片/视频/语音/拍照**（发送前确认）、风控拦截提示、**加载更早消息分页**、**聊天记录同步开关**、桌面通知 |
| 我的 | 技能档案增删、学生/实名认证（模拟）、曝光服务（模拟开通）、聊天记录同步设置、切换账号 |
| 风控 | 全程服务端零金钱交易风控（文本拦截 + 系统提示） |
| 版本 | 启动检查服务器版本并提示更新 |

## 目录结构

```
win-app/
├── main.js            # Electron 主进程
├── src/
│   ├── index.html     # 页面骨架
│   ├── style.css      # 青蓝主题（与 iOS 一致）
│   ├── api.js         # 核心层：REST + 状态 + Socket（纯 JS 可测）
│   ├── views.js       # 视图层：登录/匹配/动态/消息/我的/弹窗
│   ├── map.js         # 同城地图（Leaflet + OSM）
│   └── app.js         # 启动与导航
└── test-core.js       # 核心逻辑测试（Node 直连服务器，19 项全过）
```

## 测试

```bash
node test-core.js      # 19 项端到端测试（真实服务器）
```

## 与 iOS 版的差异说明

| 能力 | iOS | Windows |
|---|---|---|
| 地图 | MapKit（区级示意） | Leaflet + OpenStreetMap（区级示意） |
| 拍照 | 系统相机 + 确认 | getUserMedia 摄像头 + 确认 |
| 语音 | AAC m4a | WebM（浏览器录音） |
| 通知 | 本地通知 | 系统桌面通知 |
| 实时通道 | Socket.io | Socket.io（同一服务端） |

所有数据（账号/聊天/动态/互换/信用分）存储于同一服务器（http://43.157.17.88:3000），**iOS 与 Windows 完全互联互通**。
