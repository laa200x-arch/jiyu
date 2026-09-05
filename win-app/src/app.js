/* ============================================================
 * 技遇 Windows 版 - 应用启动与导航
 * ============================================================ */
'use strict'

const views = App.views

function switchView(name) {
  App.views.current = name
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === name))
  if (name === 'login') {
    document.getElementById('app').classList.add('hidden')
    document.getElementById('login-page').classList.remove('hidden')
    views.renderLogin()
    return
  }
  document.getElementById('login-page').classList.add('hidden')
  document.getElementById('app').classList.remove('hidden')
  const map = { match: views.renderMatch, feed: views.renderFeed, message: views.renderMessage, pet: views.renderPet, mine: views.renderMine }
  map[name]()
}

function switchTab(name) {
  switchView(name)
}

/* ---------- 登录页事件 ---------- */
function bindLogin() {
  let isRegister = false
  const page = document.getElementById('login-page')

  // 忘记密码（手机号 + 验证码 + 新密码）
  page.querySelector('#forgot-btn').addEventListener('click', () => {
    views.openModal(`<div class="modal-title">🔑 忘记密码</div>
      <div class="field"><input id="fp-phone" type="tel" placeholder="已注册的手机号" maxlength="11"></div>
      <div class="field"><div style="display:flex;gap:8px">
        <input id="fp-code" type="text" placeholder="验证码" maxlength="6" style="flex:1">
        <button id="fp-send" class="btn btn-outline" style="white-space:nowrap">获取验证码</button>
      </div></div>
      <div class="field"><input id="fp-pass" type="password" placeholder="新密码（至少 6 位）"></div>
      <div id="fp-err" class="error-text hidden"></div>
      <button id="fp-submit" class="btn btn-primary btn-block">重置密码</button>
      <p class="hint">重置成功后请用新密码登录</p>`, (box) => {
      const phone = box.querySelector('#fp-phone')
      const code = box.querySelector('#fp-code')
      const pass = box.querySelector('#fp-pass')
      const err = box.querySelector('#fp-err')
      box.querySelector('#fp-send').addEventListener('click', async () => {
        const p = phone.value.trim()
        if (!/^1[3-9]\d{9}$/.test(p)) return show(err, '请输入正确的 11 位手机号')
        try {
          const r = await api('/api/auth/phone/forgot-code', { method: 'POST', body: { phone: p } })
          if (r.devCode) {
            code.value = r.devCode
            show(err, '✅ 验证码已发送（验证码已自动填入）')
          } else show(err, '✅ 验证码已发送到 ' + p + '（5 分钟内有效）')
        } catch (e) { show(err, e.message) }
      })
      box.querySelector('#fp-submit').addEventListener('click', async () => {
        const p = phone.value.trim()
        if (!/^1[3-9]\d{9}$/.test(p)) return show(err, '请输入正确的 11 位手机号')
        if (!code.value.trim()) return show(err, '请输入验证码')
        if (!pass.value || pass.value.length < 6) return show(err, '新密码至少 6 位')
        try {
          const r = await api('/api/auth/reset-password', { method: 'POST', body: { phone: p, code: code.value.trim(), newPassword: pass.value } })
          show(err, '✅ ' + (r.message || '密码已重置，请用新密码登录'))
          setTimeout(() => closeModal(), 1200)
        } catch (e) { show(err, e.message) }
      })
    })
  })

  page.querySelector('#login-toggle').addEventListener('click', () => {
    isRegister = !isRegister
    document.getElementById('login-toggle').textContent = isRegister ? '已有账号？去登录' : '没有账号？注册一个'
    document.getElementById('register-field').classList.toggle('hidden', !isRegister)
    document.getElementById('register-phone-field').classList.toggle('hidden', !isRegister)
    document.getElementById('register-code-field').classList.toggle('hidden', !isRegister)
    document.getElementById('login-submit').textContent = isRegister ? '注册并登录' : '登 录'
  })

  // 获取手机验证码（每个手机号仅可注册一个账号）
  page.querySelector('#send-code-btn').addEventListener('click', async () => {
    const phone = document.getElementById('login-phone').value.trim()
    const err = document.getElementById('login-error')
    const btn = document.getElementById('send-code-btn')
    if (!/^1[3-9]\d{9}$/.test(phone)) return show(err, '请输入正确的 11 位手机号')
    hide(err)
    btn.disabled = true
    try {
      const r = await api('/api/auth/phone/send-code', { method: 'POST', body: { phone } })
      if (r.devCode) {
        document.getElementById('login-code').value = r.devCode
        show(err, '✅ 验证码已发送（验证码已自动填入：' + r.devCode + '）')
      } else {
        show(err, '✅ 验证码已发送到 ' + phone + '（5 分钟内有效）')
      }
      // 60 秒倒计时
      let left = 60
      const timer = setInterval(() => {
        left--
        btn.textContent = left > 0 ? '重新发送(' + left + 's)' : '获取验证码'
        if (left <= 0) { clearInterval(timer); btn.disabled = false }
      }, 1000)
    } catch (e) {
      show(err, e.message)
      btn.disabled = false
    }
  })

  page.querySelector('#login-submit').addEventListener('click', async () => {
    const username = document.getElementById('login-username').value.trim()
    const password = document.getElementById('login-password').value
    const nickname = document.getElementById('login-nickname').value.trim()
    const phone = document.getElementById('login-phone').value.trim()
    const code = document.getElementById('login-code').value.trim()
    const err = document.getElementById('login-error')
    if (!username || !password) return show(err, '请输入用户名和密码')
    if (isRegister && !nickname) return show(err, '请输入昵称')
    // 手机号选填：填写了手机号则必须格式正确且完成验证
    if (isRegister && phone && !/^1[3-9]\d{9}$/.test(phone)) return show(err, '手机号格式不正确（选填，11 位大陆手机号）')
    if (isRegister && phone && !code) return show(err, '填写了手机号，请先获取并填写验证码')
    hide(err)
    const btn = document.getElementById('login-submit')
    btn.disabled = true
    btn.textContent = '登录中…'
    try {
      if (isRegister) await register(username, password, nickname, phone, code)
      else await login(username, password)
      afterEnterApp()
    } catch (e) {
      show(err, e.message)
    } finally {
      btn.disabled = false
      btn.textContent = isRegister ? '注册并登录' : '登 录'
    }
  })

  // 已保存账号：点击切换 / 删除
  page.addEventListener('click', async (e) => {
    const remove = e.target.closest('[data-remove]')
    if (remove) {
      e.stopPropagation()
      removeAccount(remove.dataset.remove)
      views.renderLogin()
      return
    }
    const acc = e.target.closest('.saved-account')
    if (!acc) return
    const account = App.state.savedAccounts.find((a) => a.username === acc.dataset.username)
    if (!account) return
    hide(document.getElementById('login-error'))
    try {
      await loginWithSaved(account)
      afterEnterApp()
    } catch (err) {
      if (err.status === 401) {
        removeAccount(account.username)
        views.renderLogin()
        show(document.getElementById('login-error'), '账号「' + account.nickname + '」登录已过期，请重新输入密码')
      } else {
        show(document.getElementById('login-error'), '网络异常，账号已保留，请重试')
      }
    }
  })

  document.getElementById('login-password').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('login-submit').click()
  })
}

function show(el, msg) { el.textContent = msg; el.classList.remove('hidden') }
function hide(el) { el.classList.add('hidden') }

/* ---------- 登录成功后的进入流程 ---------- */
function afterEnterApp() {
  document.getElementById('topbar-user-name').textContent = App.state.user.userName
  const av = document.getElementById('topbar-avatar')
  av.innerHTML = avatarHtml(App.state.user, 'avatar avatar-sm')
  switchView('match')
  // 版本检查
  checkVersion()
  // 首次选择聊天记录同步
  if (!App.state.syncChosen && App.state.user) {
    App.state.syncChosen = true
    localStorage.setItem('jiyu.syncChosen', '1')
    openModal(`<div class="modal-title">同步聊天记录</div>
      <div class="card-sub" style="line-height:1.8">不同设备登录同一账号时，可同步之前的聊天记录。<br>你可以随时在「我的 → 聊天记录同步」中修改。</div>
      <div class="modal-actions">
        <button class="btn btn-primary" id="sync-yes">自动加载历史记录（推荐）</button>
        <button class="btn btn-outline" id="sync-no">不自动加载，仅新消息</button>
      </div>`, (box) => {
      box.querySelector('#sync-yes').addEventListener('click', () => { App.state.syncHistory = true; localStorage.setItem('jiyu.syncHistory', '1'); closeModal() })
      box.querySelector('#sync-no').addEventListener('click', () => { App.state.syncHistory = false; localStorage.setItem('jiyu.syncHistory', '0'); closeModal() })
    })
  }
}

async function checkVersion() {
  const v = await fetchVersion()
  if (!v || !v.current) return
  // 本机版本：Electron 下取 package.json version；无法获取时跳过（无法可靠比较）
  let mine = null
  try {
    if (window.jiyu && window.jiyu.getAppVersion) mine = await window.jiyu.getAppVersion()
  } catch (e) { /* ignore */ }
  if (!mine) return
  if (v.current !== mine) {
    // 无新版本（本机已提示过该版本）不再弹窗；服务器 current 变化后才会再次提示
    if (localStorage.getItem('jiyu.updateShown') === String(v.current)) return
    localStorage.setItem('jiyu.updateShown', String(v.current))
    openModal(`<div class="modal-title">发现新版本 ${esc(v.current)}</div>
      <div class="card-sub" style="line-height:1.8">${esc(v.updateMessage)}</div>
      <div class="modal-actions">
        <button class="btn btn-primary" id="ver-goto">去下载</button>
        <button class="btn btn-outline" data-close>稍后再说</button>
      </div>`, (box) => {
      box.querySelector('#ver-goto').addEventListener('click', () => {
        const win = window.open('', '_blank')
        if (win) win.location = v.downloadUrl
      })
    })
  }
}

/* ---------- Tab 切换 ---------- */
function bindTabs() {
  document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => {
    switchView(t.dataset.view)
  }))
  // 顶栏：用户下拉菜单
  document.getElementById('user-menu').addEventListener('click', (e) => {
    e.stopPropagation()
    document.getElementById('user-dropdown').classList.toggle('hidden')
  })
  document.addEventListener('click', () => {
    document.getElementById('user-dropdown').classList.add('hidden')
  })
  document.getElementById('logout-btn').addEventListener('click', () => {
    if (confirm('退出当前账号？退出后可在登录页一键切换其他账号')) {
      logout()
      switchView('login')
    }
  })
  // 顶栏：消息铃铛 → 跳转消息
  document.getElementById('bell-btn').addEventListener('click', () => switchView('message'))
  // 侧边栏：小程序市场推广卡 → 消息页并打开市场
  document.getElementById('promo-btn').addEventListener('click', () => {
    switchView('message')
    setTimeout(() => showMiniApps(), 150)
  })
}

/* ---------- 启动 ---------- */
async function bootstrap() {
  // 启动动画：最短展示 900ms 后淡出
  const splash = document.getElementById('splash')
  const t0 = Date.now()
  bindLogin()
  bindTabs()
  bindModalMask()
  bindGlobalDelegates()
  // 登录页服务地址提示跟随配置（src/config.js 唯一来源）
  const hint = document.getElementById('server-hint')
  if (hint && window.APP_CONFIG) hint.textContent = '服务地址：' + window.APP_CONFIG.server + '（体验账号 aqing / 123456）'
  // Electron 加密凭据回填（safeStorage；清缓存后凭据不丢）
  await restoreSecure()
  // 请求桌面通知权限（消息推送）
  if ('Notification' in window && Notification.permission === 'default') {
    try { Notification.requestPermission() } catch (e) { /* ignore */ }
  }
  let entered = false
  const enter = () => {
    if (entered) return
    entered = true
    const wait = Math.max(0, 900 - (Date.now() - t0))
    setTimeout(() => {
      splash.classList.add('splash-out')
      setTimeout(() => splash.remove(), 500)
    }, wait)
  }
  if (App.state.token) {
    // 有持久化 Token：尝试自动登录
    const ok = await autoLogin()
    if (ok) {
      afterEnterApp()
      enter()
      return
    }
  }
  switchView('login')
  enter()
}

document.addEventListener('DOMContentLoaded', bootstrap)
