// 技遇 Windows 版 - 预加载脚本（contextIsolation 下向渲染进程暴露的最小 API）
// 渲染进程只能访问 window.jiyu.*，无法直接使用 Node/Electron 能力
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('jiyu', {
  // 新消息时触发主进程任务栏闪烁
  flash: () => ipcRenderer.send('flash')
})
