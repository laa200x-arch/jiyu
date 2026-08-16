// 技遇 Windows 桌面版 - Electron 主进程
const { app, BrowserWindow, Notification, shell } = require('electron')
const path = require('path')

let mainWindow = null

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 760,
    minWidth: 900,
    minHeight: 640,
    title: '技遇 - 纯公益技能互换平台',
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      // 允许页面直接连接服务器与使用系统能力（本地单机应用）
      webSecurity: true
    }
  })

  mainWindow.loadFile(path.join(__dirname, 'src', 'index.html'))

  // 外部链接用系统浏览器打开（版本更新下载等）
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

app.whenReady().then(createWindow)

app.on('window-all-closed', () => {
  app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})
