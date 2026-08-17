// 技遇 Windows 桌面版 - Electron 主进程
const { app, BrowserWindow, Notification, shell, ipcMain, dialog, Tray, Menu, nativeImage } = require('electron')
const path = require('path')

let mainWindow = null
let tray = null

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

app.whenReady().then(createWindow)

app.on('window-all-closed', () => {
  // 托盘驻留时不退出；仅当明确退出时
  if (global.__jiyuQuitting) app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})
