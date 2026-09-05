/* ============================================================
 * 技遇 Windows 版 - 全局配置（服务器地址唯一来源）
 * - 默认连线上服务器；本地联调可用 localStorage['jiyu.server'] 覆盖
 *   （DevTools 控制台：localStorage.setItem('jiyu.server','http://localhost:3199') 后重启）
 * - CSP 在主进程按此配置注入（见 main.js），此处仅声明默认值供渲染层使用
 * ============================================================ */
'use strict';

(function () {
  let stored = null
  try { stored = localStorage.getItem('jiyu.server') } catch { /* 非浏览器环境 */ }
  const server = (stored || '').trim() || 'http://43.157.17.88:3000'
  window.APP_CONFIG = {
    server,
    // 主进程注入 CSP 时包含的来源（默认线上 + 本地联调端口，无需网络变更即可切换）
    cspOrigins: [
      'http://43.157.17.88:3000',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://localhost:3199',
      'http://127.0.0.1:3199'
    ]
  }
})()
