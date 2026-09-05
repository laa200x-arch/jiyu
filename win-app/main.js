// 技遇 Windows 桌面版 - Electron 主进程
const { app, BrowserWindow, Notification, shell, ipcMain, dialog, Tray, Menu, nativeImage, nativeTheme, session, safeStorage } = require('electron')
const path = require('path')
const fs = require('fs')

// 强制浅色模式：应用仅设计浅色 UI，禁用系统暗黑模式反转（黑块/灰遮罩根因）
nativeTheme.themeSource = 'light'

let mainWindow = null
let tray = null

/* ---------- 渲染层配置镜像（CSP 注入用；与 src/config.js 保持同一组来源） ---------- */
const CSP_ORIGINS = [
  'http://43.157.17.88:3000',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:3199',
  'http://127.0.0.1:3199'
]
function buildCsp() {
  const origins = CSP_ORIGINS.join(' ')
  const wsOrigins = CSP_ORIGINS.map((u) => u.replace(/^http/, 'ws')).join(' ')
  return [
    `default-src 'self' ${origins} data: blob:`,
    `img-src 'self' ${origins} data: blob: https://*.tile.openstreetmap.org`, // 地图瓦片
    `media-src 'self' ${origins} blob:`,
    "style-src 'self' 'unsafe-inline'",
    "script-src 'self'",
    `connect-src 'self' ${origins} ${wsOrigins}`
  ].join('; ')
}
// CSP 由主进程按配置注入（原先硬编码在 index.html meta，现统一收敛到 CSP_ORIGINS）
function setupCsp() {
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    if (details.url.startsWith('file://')) {
      callback({ responseHeaders: { ...details.responseHeaders, 'Content-Security-Policy': [buildCsp()] } })
    } else {
      callback({ responseHeaders: details.responseHeaders })
    }
  })
}

/* ---------- 凭据加密存储（safeStorage：Windows 使用 DPAPI，凭据不再明文落盘） ---------- */
function secureFilePath() {
  return path.join(app.getPath('userData'), 'secure-store.json')
}
function readSecureFile() {
  try {
    return JSON.parse(fs.readFileSync(secureFilePath(), 'utf8'))
  } catch { return null }
}
ipcMain.handle('app-version', () => app.getVersion())
ipcMain.handle('secure-get', () => {
  const rec = readSecureFile()
  if (!rec) return null
  try {
    if (rec.encrypted && safeStorage.isEncryptionAvailable()) {
      return JSON.parse(safeStorage.decryptString(Buffer.from(rec.blob, 'base64')))
    }
    if (!rec.encrypted) return rec.blob // 旧明文记录
  } catch (e) {
    console.log('[secure] 读取失败:', e.message)
  }
  return null
})
ipcMain.handle('secure-save', (e, data) => {
  try {
    let rec
    if (safeStorage.isEncryptionAvailable()) {
      rec = { encrypted: true, blob: safeStorage.encryptString(JSON.stringify(data)).toString('base64') }
    } else {
      rec = { encrypted: false, blob: data } // 无 DPAPI 环境降级明文（与旧 localStorage 行为一致）
    }
    fs.writeFileSync(secureFilePath(), JSON.stringify(rec))
    return true
  } catch (e) {
    console.log('[secure] 保存失败:', e.message)
    return false
  }
})

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 900,
    minHeight: 640,
    title: '技遇 - 纯公益技能互换平台',
    autoHideMenuBar: true,
    webPreferences: {
      // 安全：禁用 Node 集成 + 开启上下文隔离，仅通过 preload 暴露最小 API（防 XSS→RCE）
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true
    }
  })

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'))

  // 新消息时任务栏闪烁提醒
  ipcMain.on('flash', () => {
    if (mainWindow) {
      mainWindow.flashFrame(true)
      setTimeout(() => { if (mainWindow) mainWindow.flashFrame(false) }, 4000)
    }
  })

  // 关闭窗口：先确认，确认后最小化到托盘（缩小窗口），再次确认才真正退出
  mainWindow.on('close', (e) => {
    if (!global.__jiyuQuitting) {
      e.preventDefault()
      const choice = dialog.showMessageBoxSync(mainWindow, {
        type: 'question',
        title: '退出技遇',
        message: '确定要退出技遇吗？',
        detail: '选择「退出」将完全退出应用；选择「最小化到托盘」将继续在后台接收消息。',
        buttons: ['退出应用', '最小化到托盘', '取消'],
        defaultId: 1,
        cancelId: 2
      })
      if (choice === 0) {
        global.__jiyuQuitting = true
        app.quit()
      } else if (choice === 1) {
        mainWindow.hide()
        createTray()
      }
    }
  })

  mainWindow.on('minimize', (e) => {
    // 最小化时也缩小到托盘（可选：取消注释则最小化即隐藏）
    // e.preventDefault(); mainWindow.hide(); createTray()
  })

  // 外部链接用系统浏览器打开（版本更新下载等）
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

/* ---------- 自动更新（electron-updater + GitHub Releases，成熟 Electron 项目标配） ---------- */
let updaterInited = false
function initUpdater() {
  if (updaterInited) return require('electron-updater').autoUpdater
  updaterInited = true
  const { autoUpdater } = require('electron-updater')
  autoUpdater.autoDownload = false // 询问用户后再下载
  autoUpdater.on('update-available', (info) => {
    if (!mainWindow) return
    const choice = dialog.showMessageBoxSync(mainWindow, {
      type: 'info',
      title: '发现新版本',
      message: `新版本 v${info.version} 可用`,
      detail: '是否下载更新？下载完成后重启应用即可完成安装。',
      buttons: ['下载更新', '稍后再说'],
      defaultId: 0,
      cancelId: 1
    })
    if (choice === 0) autoUpdater.downloadUpdate().catch((e) => console.log('[updater] 下载失败:', e.message))
  })
  autoUpdater.on('update-downloaded', () => {
    if (!mainWindow) return
    const choice = dialog.showMessageBoxSync(mainWindow, {
      type: 'info',
      title: '更新已就绪',
      message: '更新下载完成，是否立即重启安装？',
      buttons: ['立即重启', '稍后自行重启'],
      defaultId: 0,
      cancelId: 1
    })
    if (choice === 0) { global.__jiyuQuitting = true; autoUpdater.quitAndInstall() }
  })
  autoUpdater.on('error', (e) => console.log('[updater] 检查失败:', e.message))
  return autoUpdater
}
function setupAutoUpdater() {
  if (!app.isPackaged) return // 开发模式不检查
  try {
    initUpdater().checkForUpdates().catch((e) => console.log('[updater] 启动检查失败:', e.message))
  } catch (e) {
    console.log('[updater] 初始化失败:', e.message)
  }
}
// 手动检查更新（顶栏菜单入口）
ipcMain.handle('check-updates', async () => {
  if (!app.isPackaged) return { ok: false, message: '开发模式不支持自动更新（打包安装后可用）' }
  try {
    const autoUpdater = initUpdater()
    const r = await autoUpdater.checkForUpdates()
    return { ok: true, hasUpdate: r.updateInfo.version !== app.getVersion(), latest: r.updateInfo.version, mine: app.getVersion() }
  } catch (e) {
    return { ok: false, message: '检查失败：' + (e.message || '网络异常（GitHub 访问受限时属正常）') }
  }
})

// 系统托盘（缩小窗口后驻留，继续接收消息）
function createTray() {
  if (tray) return
  const icon = nativeImage.createEmpty()
  tray = new Tray(icon)
  tray.setToolTip('技遇 - 纯公益技能互换平台')
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: '打开技遇', click: () => { showWindow() } },
    { type: 'separator' },
    { label: '退出应用', click: () => { global.__jiyuQuitting = true; app.quit() } }
  ]))
  tray.on('click', () => showWindow())
}

function showWindow() {
  if (!mainWindow) return
  mainWindow.show()
  mainWindow.focus()
}

app.whenReady().then(() => {
  setupCsp()
  createWindow()
  setupAutoUpdater()
})

app.on('window-all-closed', () => {
  // 托盘驻留时不退出；仅当明确退出时
  if (global.__jiyuQuitting) app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})
