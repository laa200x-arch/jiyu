/* ============================================================
 * 技遇 Windows 版 - 核心层（REST 封装 + 状态 + Socket.io）
 * 纯 JS（无 DOM 依赖），可在 Node 中直接测试
 * ============================================================ */
'use strict'

// Node 测试环境兼容（无 localStorage）
const storage = globalThis.localStorage || {
  _d: {},
  getItem(k) { return this._d[k] ?? null },
  setItem(k, v) { this._d[k] = String(v) },
  removeItem(k) { delete this._d[k] }
}

const App = {
  SERVER: 'http://43.157.17.88:3000',
  state: {
    token: storage.getItem('jiyu.token') || null,
    user: null,              // 当前用户（服务端格式）
    users: [],               // 全部用户
    conversations: [],       // 会话列表
    messages: {},            // conversationId -> [message]
    hasMore: {},             // conversationId -> bool
    dynamics: [],
    records: [],             // 互换记录
    agreements: [],
    syncHistory: storage.getItem('jiyu.syncHistory') !== '0',
    syncChosen: storage.getItem('jiyu.syncChosen') === '1',
    activeConversation: null,
    savedAccounts: JSON.parse(storage.getItem('jiyu.accounts') || '[]'),
    socket: null
  },
  views: {} // 由 views.js 注册
}

/* ---------- 基础请求 ---------- */
async function api(path, { method = 'GET', body, query } = {}) {
  let url = App.SERVER + path
  if (query) {
    const qs = new URLSearchParams()
    for (const [k, v] of Object.entries(query)) if (v !== undefined && v !== null && v !== '') qs.set(k, v)
    const s = qs.toString()
    if (s) url += (url.includes('?') ? '&' : '?') + s
  }
  const headers = { 'Content-Type': 'application/json' }
  if (App.state.token) headers['Authorization'] = 'Bearer ' + App.state.token
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(data.error || ('请求失败（HTTP ' + res.status + '）'))
    err.status = res.status
    throw err
  }
  return data
}

/* ---------- 认证 ---------- */
async function login(username, password) {
  const data = await api('/api/auth/login', { method: 'POST', body: { username, password } })
  await afterLogin(data)
}
async function register(username, password, nickname) {
  const data = await api('/api/auth/register', { method: 'POST', body: { username, password, nickname } })
  await afterLogin(data)
}
async function loginWithSaved(account) {
  App.state.token = account.token
  storage.setItem('jiyu.token', account.token)
  try {
    const data = await api('/api/me')
    await afterLogin({ token: account.token, user: data.user })
  } catch (e) {
    if (e.status === 401) {
      App.state.token = null
      storage.removeItem('jiyu.token')
    }
    throw e
  }
}
async function autoLogin() {
  if (!App.state.token) return false
  try {
    const data = await api('/api/me')
    await afterLogin({ token: App.state.token, user: data.user })
    return true
  } catch (e) {
    if (e.status === 401) {
      App.state.token = null
      storage.removeItem('jiyu.token')
    }
    return false
  }
}
async function afterLogin({ token, user }) {
  App.state.token = token
  storage.setItem('jiyu.token', token)
  App.state.user = user
  saveAccount({ username: user.username, nickname: user.userName, avatarSymbol: user.avatarSymbol, token })
  await refreshAll()
  connectSocket()
}
function logout() {
  App.state.token = null
  storage.removeItem('jiyu.token')
  if (App.state.socket) { App.state.socket.disconnect(); App.state.socket = null }
  App.state.user = null
  App.state.users = []
  App.state.conversations = []
  App.state.messages = {}
  App.state.dynamics = []
  App.state.records = []
  App.state.agreements = []
}

/* ---------- 多账号 ---------- */
function saveAccount(account) {
  let list = App.state.savedAccounts.filter((a) => a.username !== account.username)
  list.unshift(account)
  App.state.savedAccounts = list
  storage.setItem('jiyu.accounts', JSON.stringify(list))
}
function removeAccount(username) {
  App.state.savedAccounts = App.state.savedAccounts.filter((a) => a.username !== username)
  storage.setItem('jiyu.accounts', JSON.stringify(App.state.savedAccounts))
}

/* ---------- 全量刷新 ---------- */
async function refreshAll() {
  const [users, convs, dyns, recs, agrs] = await Promise.all([
    api('/api/users'), api('/api/conversations'), api('/api/dynamics'),
    api('/api/exchanges'), api('/api/agreements')
  ])
  App.state.users = users.users
  App.state.conversations = convs.conversations
  App.state.dynamics = dyns.dynamics
  App.state.records = recs.records
  App.state.agreements = agrs.agreements
}

/* ---------- 匹配 ---------- */
async function fetchMatches(filters = {}) {
  const data = await api('/api/match', { query: filters })
  return data.matches
}

/* ---------- 用户 ---------- */
async function fetchUser(id) {
  const data = await api('/api/users/' + id)
  return data.user
}
async function updateProfile(bio) {
  const data = await api('/api/me/profile', { method: 'PUT', body: { bio } })
  App.state.user = data.user
}
async function addSkill(kind, skill) {
  const data = await api('/api/me/skills', { method: 'POST', body: { kind, skill } })
  const s = data.skill
  if (kind === 'teach') App.state.user.mySkills.push(s)
  else App.state.user.wantSkills.push(s)
  return s
}
async function removeSkill(kind, id) {
  await api('/api/me/skills/' + kind + '/' + id, { method: 'DELETE' })
  App.state.user[kind === 'teach' ? 'mySkills' : 'wantSkills'] =
    App.state.user[kind === 'teach' ? 'mySkills' : 'wantSkills'].filter((s) => s.id !== String(id))
}
async function setVerification(verification) {
  const data = await api('/api/me/verification', { method: 'PUT', body: { verification } })
  App.state.user = data.user
}
async function applyExposure(packageId) {
  const data = await api('/api/me/exposure', { method: 'PUT', body: { packageId } })
  App.state.user = data.user
}
async function cancelExposure() {
  const data = await api('/api/me/exposure', { method: 'DELETE' })
  App.state.user = data.user
}

/* ---------- 协议 / 互换 / 评价 ---------- */
async function signAgreement(payload) {
  const data = await api('/api/agreements', { method: 'POST', body: payload })
  App.state.records.unshift(data.record)
  App.state.agreements.unshift({ ...payload, partnerName: data.agreement ? '' : '', signedAt: new Date().toISOString() })
  return data.record
}
async function completeExchange(id) {
  await api('/api/exchanges/' + id + '/complete', { method: 'POST' })
  const rec = App.state.records.find((r) => r.id === String(id))
  if (rec) rec.status = 'completed'
}
async function submitEvaluation(recordId, body) {
  const data = await api('/api/evaluations', { method: 'POST', body: { recordId, ...body } })
  const rec = App.state.records.find((r) => r.id === String(recordId))
  if (rec) { rec.evaluateGiven = true; rec.status = 'completed' }
  const partner = App.state.users.find((u) => u.id === rec.partner.id)
  if (partner) partner.creditScore = data.newCreditScore
  return data
}

/* ---------- 动态 ---------- */
async function postDynamic(content, imageBase64) {
  return api('/api/dynamics', { method: 'POST', body: { content, imageBase64 } })
}

/* ---------- 聊天（REST） ---------- */
async function openConversation(partnerId) {
  const data = await api('/api/conversations/open', { method: 'POST', body: { partnerId } })
  const conv = data.conversation
  if (!App.state.conversations.some((c) => c.id === conv.id)) App.state.conversations.unshift(conv)
  return conv
}
async function loadMessages(conversationId, before) {
  const data = await api('/api/conversations/' + conversationId + '/messages', { query: { before } })
  App.state.hasMore[conversationId] = !!data.hasMore
  return { messages: data.messages, hasMore: !!data.hasMore }
}
async function markRead(conversationId) {
  try { await api('/api/conversations/' + conversationId + '/read', { method: 'POST' }) } catch (e) { /* ignore */ }
}
async function sendMessageRest(conversationId, text, mediaType, mediaUrl) {
  return api('/api/messages', { method: 'POST', body: { conversationId, text, mediaType, mediaUrl } })
}

/* ---------- 文件上传 ---------- */
async function uploadMedia(data, fileName, mimeType) {
  const form = new FormData()
  form.append('file', new Blob([data], { type: mimeType }), fileName)
  const res = await fetch(App.SERVER + '/api/upload', {
    method: 'POST',
    headers: App.state.token ? { Authorization: 'Bearer ' + App.state.token } : {},
    body: form
  })
  const json = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(json.error || '上传失败')
  return json.url
}

/* ---------- Socket.io 实时 ---------- */
function connectSocket() {
  if (typeof io === 'undefined') {
    console.log('[socket] 跳过（非浏览器环境）')
    return
  }
  if (App.state.socket) { App.state.socket.disconnect(); App.state.socket = null }
  const socket = io(App.SERVER, { transports: ['websocket', 'polling'], auth: { token: App.state.token } })
  socket.on('connect', () => console.log('[socket] 已连接'))
  socket.on('disconnect', () => console.log('[socket] 断开'))
  socket.on('chat:message', (msg) => {
    const conv = App.state.conversations.find((c) => c.id === msg.conversationId)
    const isMe = msg.senderId === App.state.user.id
    const list = App.state.messages[msg.conversationId] || []
    if (!list.some((m) => m.id === msg.id)) {
      App.state.messages[msg.conversationId] = [...list, normalizeMessage(msg, isMe)]
      if (App.state.views.onMessage) App.state.views.onMessage(msg.conversationId)
    }
    if (conv) {
      conv.lastMessageText = msg.text || (msg.mediaType === 'video' ? '[视频]' : msg.mediaType === 'audio' ? '[语音]' : '[图片]')
      conv.lastTime = msg.time
      if (!isMe && App.state.activeConversation !== msg.conversationId) conv.unreadCount = (conv.unreadCount || 0) + 1
      if (App.state.views.onConversationUpdate) App.state.views.onConversationUpdate()
      if (!isMe && !document.hidden && App.state.activeConversation !== msg.conversationId) {
        try { new Notification('技遇 · ' + conv.partner.userName + ' 发来消息', { body: msg.text || '[媒体消息]' }) } catch (e) {}
      }
    }
  })
  socket.on('match:push', (payload) => {
    try { new Notification('技遇 · 互换邀约', { body: payload.message || '你收到一条新的互换邀约' }) } catch (e) {}
    refreshAll().then(() => { if (App.state.views.onConversationUpdate) App.state.views.onConversationUpdate() })
  })
  App.state.socket = socket
}
function socketSend(conversationId, text) {
  return new Promise((resolve) => {
    const socket = App.state.socket
    if (!socket || !socket.connected) return resolve({ ok: false, blocked: false, error: '未连接' })
    socket.emit('chat:send', { conversationId, text }, (ack) => resolve(ack || {}))
  })
}
function normalizeMessage(msg, isMe) {
  return {
    id: msg.id, senderIsMe: isMe, text: msg.text || '',
    mediaType: msg.mediaType || null, mediaUrl: msg.mediaUrl || null,
    time: msg.time, isSystemNote: !!msg.isSystemNote
  }
}

/* ---------- 版本检查 ---------- */
async function fetchVersion() {
  try { return await api('/api/version') } catch (e) { return null }
}

/* Node 环境导出（测试用） */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { App, api, login, register, loginWithSaved, autoLogin, logout, refreshAll, fetchMatches, fetchUser, openConversation, loadMessages, sendMessageRest, uploadMedia, postDynamic, signAgreement, completeExchange, submitEvaluation, fetchVersion }
}
