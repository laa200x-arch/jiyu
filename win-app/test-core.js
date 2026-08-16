/* 技遇 Windows 版 - 核心逻辑测试（Node 直连服务器）
 * 运行：node test-core.js
 */
const { App, login, logout, refreshAll, fetchMatches, openConversation, loadMessages, sendMessageRest, uploadMedia, postDynamic, fetchUser } = require('./src/api.js')

let passed = 0, failed = 0
const check = (name, cond, extra = '') => {
  if (cond) { passed++; console.log('  ✅', name, extra) }
  else { failed++; console.log('  ❌', name, extra) }
}

async function main() {
  console.log('══════ 技遇 Windows 版核心逻辑测试 ══════\n')

  // 1. 登录
  try {
    await login('aqing', '123456')
    check('登录 aqing', !!App.state.token, `user=${App.state.user.userName}`)
  } catch (e) { check('登录 aqing', false, e.message) }

  // 2. 全量数据
  try {
    await refreshAll()
    check('用户列表', App.state.users.length > 0, `${App.state.users.length} 位`)
    check('会话列表', Array.isArray(App.state.conversations))
    check('动态列表', App.state.dynamics.length > 0, `${App.state.dynamics.length} 条`)
    check('互换记录', Array.isArray(App.state.records))
  } catch (e) { check('全量刷新', false, e.message) }

  // 3. 匹配
  try {
    const matches = await fetchMatches({})
    check('双向匹配', matches.length > 0, `${matches.length} 位`)
    const allBi = matches.every((m) => m.mySkillsForThem.length > 0 && m.theirSkillsForMe.length > 0)
    check('匹配均为双向对等', allBi)
  } catch (e) { check('匹配', false, e.message) }

  // 4. 用户资料
  try {
    const u = await fetchUser(App.state.users[1].id)
    check('用户资料', !!u.userName, u.userName)
  } catch (e) { check('用户资料', false, e.message) }

  // 5. 会话与消息（与 linxiao）
  try {
    const linxiao = App.state.users.find((u) => u.userName === '林晓')
    const conv = await openConversation(linxiao.id)
    check('打开会话', !!conv.id, `会话 ${conv.id} · ${conv.partner.userName}`)
    const { messages: msgs, hasMore } = await loadMessages(conv.id)
    check('历史消息', msgs.length > 0, `${msgs.length} 条`)
    check('hasMore 字段', typeof hasMore === 'boolean')
    // 发送文本
    const r = await sendMessageRest(conv.id, 'Windows 版测试消息 ' + Date.now())
    check('发送文本消息', !r.blocked)
    // 发送违禁词 → 拦截
    const r2 = await sendMessageRest(conv.id, '多少钱')
    check('违禁词拦截', r2.blocked === true, r2.warning ? r2.warning.slice(0, 24) + '…' : '')
  } catch (e) { check('会话/消息', false, e.message) }

  // 6. 上传媒体
  try {
    const fakePng = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
    const url = await uploadMedia(fakePng, 'test.png', 'image/png')
    check('上传媒体', url.startsWith('/uploads/'), url)
  } catch (e) { check('上传媒体', false, e.message) }

  // 7. 动态发布（合规 + 违规）
  try {
    const ok = await postDynamic('Windows 版测试动态：周末组队学摄影 📷')
    check('发布合规动态', !!ok)
  } catch (e) { check('发布合规动态', false, e.message) }
  try {
    await postDynamic('承接视频剪辑，收费 50 元')
    check('违规动态被拦截', false)
  } catch (e) {
    check('违规动态被拦截', e.message.includes('金钱交易'), e.message.slice(0, 30))
  }

  // 8. 协议签署 + 互换完成 + 评价
  try {
    const partner = App.state.users.find((u) => u.userName === '周可')
    const rec = await (async () => {
      const data = await require('./src/api.js').api('/api/agreements', {
        method: 'POST',
        body: {
          partnerId: partner.id, mySkillName: '视频剪辑', learnSkillName: '吉他',
          exchangeType: 'online', scheduledTime: '本周三 20:00'
        }
      })
      return data.record
    })()
    check('签署协议', !!rec.id, `记录 ${rec.id}`)
    await require('./src/api.js').api('/api/exchanges/' + rec.id + '/complete', { method: 'POST' })
    const ev = await require('./src/api.js').api('/api/evaluations', {
      method: 'POST',
      body: { recordId: rec.id, punctuality: 5, serious: 5, communication: 5, comment: 'Windows 测试' }
    })
    check('提交评价', typeof ev.newCreditScore === 'number', `新信用分 ${ev.newCreditScore}`)
  } catch (e) { check('协议/互换/评价', false, e.message) }

  // 9. 版本检查
  try {
    const v = await require('./src/api.js').fetchVersion()
    check('版本接口', !!v.current, v.current)
  } catch (e) { check('版本接口', false, e.message) }

  // 10. 自定义头像（上传 + 更新资料）
  try {
    const fakePng = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
    const url = await uploadMedia(fakePng, 'avatar-test.png', 'image/png')
    const api2 = require('./src/api.js')
    const data = await api2.api('/api/me/profile', { method: 'PUT', body: { avatarUrl: url } })
    check('更新头像', data.user.avatarUrl === url, url)
    // 头像回显
    const me = await api2.api('/api/me')
    check('头像持久化', me.user.avatarUrl === url)
  } catch (e) { check('自定义头像', false, e.message) }

  // 11. 我的动态历史（发布 → 列表过滤 → 删除）
  try {
    const api2 = require('./src/api.js')
    const content = '动态历史测试 ' + Date.now()
    await postDynamic(content)
    await refreshAll()
    const mine = App.state.dynamics.filter((d) => String(d.userId) === String(App.state.user.id))
    const mineContent = mine.filter((d) => d.content === content)
    check('我的动态历史', mineContent.length === 1, `共 ${mine.length} 条`)
    // 删除
    await api2.api('/api/dynamics/delete', { method: 'POST', body: { id: mineContent[0].id } })
    await refreshAll()
    const after = App.state.dynamics.filter((d) => String(d.userId) === String(App.state.user.id) && d.content === content)
    check('删除动态', after.length === 0)
  } catch (e) { check('我的动态历史', false, e.message) }

  logout()
  console.log(`\n══════ 结果：${passed} 通过 / ${failed} 失败 ══════`)
  process.exit(failed > 0 ? 1 : 0)
}

main().catch((e) => { console.error('测试异常:', e); process.exit(1) })
