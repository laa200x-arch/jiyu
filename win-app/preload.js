// 技遇 Windows 版 - 预加载脚本（contextIsolation 下向渲染进程暴露的最小 API）
// 渲染进程只能访问 window.jiyu.*，无法直接使用 Node/Electron 能力
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('jiyu', {
  // 新消息时触发主进程任务栏闪烁
  flash: () => ipcRenderer.send('flash'),
  // 应用版本（package.json version，自动更新与版本弹窗比对用）
  getAppVersion: () => ipcRenderer.invoke('app-version'),
  // 凭据加密存储（safeStorage/DPAPI）：登录 token、多账号列表不再明文落盘
  getSecureData: () => ipcRenderer.invoke('secure-get'),
  saveSecureData: (data) => ipcRenderer.invoke('secure-save', data),
  // 手动检查更新（顶栏菜单入口）
  checkForUpdates: () => ipcRenderer.invoke('check-updates')
})
