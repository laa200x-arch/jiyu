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

  // 12. 宠物护理域（旧巡六迁移 → 收费订单模式）
  try {
    const petsApi = require('./src/api.js')
    const svc = await petsApi.api('/api/care-services')
    check('服务目录（含定价）', svc.services.length === 7 && svc.services[0].priceYuan === 45, `7 种 · 过夜 ¥45 · 遛狗 ¥20`)
    // 添加宠物
    const pet = await petsApi.api('/api/pets', { method: 'POST', body: {
      name: '测试宠物', petType: 'cat', breed: '英短', ageMonths: 18,
      gender: 'female', neutered: true, weightKg: 4.2,
      behaviors: ['亲人', '胆小'], homeReactions: ['作息规律'], notes: '测试'
    } })
    check('添加宠物', !!pet.pet.id, pet.pet.name)
    // 校验：猫缺体重
    try {
      await petsApi.api('/api/pets', { method: 'POST', body: { name: 'x', petType: 'cat', breed: 'x', ageMonths: 12, gender: 'female', neutered: false } })
      check('宠物校验（猫体重必填）', false)
    } catch (e) { check('宠物校验（猫体重必填）', e.message.includes('体重'), e.message.slice(0, 20)) }
    // 发起订单（指定看护人）
    const bk = await petsApi.api('/api/bookings', { method: 'POST', body: {
      petId: pet.pet.id, serviceId: 'overnight', providerId: 2,
      scheduledTime: '本周六 18:00', location: '小区门口'
    } })
    check('发起订单（指定看护人）', !!bk.booking && bk.booking.status === 'assigned')
    check('金额结算（佣金10%）', bk.booking.priceYuan === 45 && bk.booking.workerIncome === 40.5, `¥${bk.booking.priceYuan} 佣金¥${bk.booking.commissionYuan} 所得¥${bk.booking.workerIncome}`)
    // 发布订单到动态（openToFeed）
    const bk2 = await petsApi.api('/api/bookings', { method: 'POST', body: {
      petId: pet.pet.id, serviceId: 'walk', scheduledTime: '本周日 10:00', location: '小区门口', openToFeed: true
    } })
    check('发布订单到动态（待接单）', bk2.booking.status === 'open' && bk2.booking.priceYuan === 20)
    // 动态区出现订单卡片
    await refreshAll()
    const orderDyn = App.state.dynamics.find((d) => d.orderId === bk2.booking.id)
    check('动态订单卡片', !!orderDyn && orderDyn.content.includes('遛狗'), orderDyn?.content?.slice(0, 20))
    // 接单资历校验（新注册用户未认证应被拒）
    const smoke = await petsApi.api('/api/auth/register', { method: 'POST', body: { username: 'noskill' + Date.now(), password: '123456', nickname: '无资历' } })
    petsApi.App.state.token = smoke.token
    const smokePet = await petsApi.api('/api/pets', { method: 'POST', body: {
      name: '测试小狗', petType: 'dog', breed: '土狗', ageMonths: 24, gender: 'male', neutered: false
    } })
    check('新用户可建档养宠', !!smokePet.pet.id)
    try {
      await petsApi.api('/api/bookings/' + bk2.booking.id + '/accept', { method: 'POST' })
      check('无资历接单被拒', false)
    } catch (e) { check('无资历接单被拒', e.message.includes('资历') || e.message.includes('信用'), e.message.slice(0, 24)) }
    petsApi.logout()
    // 有资历者接单（linxiao 信用90已认证）
    await petsApi.login('linxiao', '123456')
    const acc = await petsApi.api('/api/bookings/' + bk2.booking.id + '/accept', { method: 'POST' })
    check('有资历者接单成功', acc.booking.status === 'assigned')
    petsApi.logout()
    // 订单列表（我发布 + 我接单）
    await petsApi.login('aqing', '123456')
    const list = await petsApi.api('/api/bookings')
    check('订单列表', list.bookings.length > 0 && list.bookings[0].pet, list.bookings[0]?.serviceName)
    // 清理：删除两只测试宠物
    await petsApi.api('/api/pets/' + pet.pet.id, { method: 'DELETE' })
    const after = await petsApi.api('/api/pets')
    check('删除宠物', !after.pets.some((p) => p.id === pet.pet.id))
    petsApi.logout()
    await petsApi.login(smoke.user.username, '123456')
    await petsApi.api('/api/pets/' + smokePet.pet.id, { method: 'DELETE' })
    petsApi.logout()
  } catch (e) { check('宠物护理域', false, e.message) }

  // 13. 订单详情 + 聊天引用订单
  try {
    const petsApi = require('./src/api.js')
    await petsApi.login('aqing', '123456')
    const conv = await petsApi.api('/api/conversations/open', { method: 'POST', body: { partnerId: 2 } })
    const convId = conv.conversation.id
    const pet = await petsApi.api('/api/pets', { method: 'POST', body: {
      name: '详情测试狗', petType: 'dog', breed: '柯基', ageMonths: 30, gender: 'male', neutered: false, notes: '喜欢玩球'
    } })
    const bk = await petsApi.api('/api/bookings', { method: 'POST', body: {
      petId: pet.pet.id, serviceId: 'walk', providerId: 2, scheduledTime: '本周六 9:00', location: '公园门口'
    } })
    // 订单详情（宠物信息 + 距离）
    const detail = await petsApi.api('/api/bookings/' + bk.booking.id)
    const db_ = detail.booking
    check('订单详情（宠物/距离/下单人）',
      !!db_.pet && db_.pet.name === '详情测试狗' && db_.pet.behaviors && db_.pet.notes.includes('玩球') &&
      db_.distanceKm === 0 && db_.initiator.userName === '阿青' && db_.provider.userName === '林晓',
      `pet=${db_.pet?.name} distance=${db_.distanceKm} init=${db_.initiator?.userName}`)
    // 聊天引用订单（文本 + 订单卡片）
    const ref = await petsApi.api('/api/messages', { method: 'POST', body: { conversationId: convId, text: '看看这个订单', orderId: bk.booking.id } })
    check('聊天引用订单', ref.message.orderId === bk.booking.id && ref.message.text === '看看这个订单')
    // 引用无关订单被拒：注册临时用户 C 建订单，aqing 引用 → 403
    const c = await petsApi.api('/api/auth/register', { method: 'POST', body: { username: 'tempc' + Date.now(), password: '123456', nickname: '临时C' } })
    petsApi.App.state.token = c.token
    const cPet = await petsApi.api('/api/pets', { method: 'POST', body: {
      name: 'C狗', petType: 'dog', breed: 'x', ageMonths: 12, gender: 'male', neutered: false
    } })
    const cBk = await petsApi.api('/api/bookings', { method: 'POST', body: {
      petId: cPet.pet.id, serviceId: 'feeding', scheduledTime: '周一', location: '小区', openToFeed: true
    } })
    petsApi.logout()
    await petsApi.login('aqing', '123456')
    try {
      await petsApi.api('/api/messages', { method: 'POST', body: { conversationId: convId, text: '', orderId: cBk.booking.id } })
      check('引用无关订单被拒', false)
    } catch (e) { check('引用无关订单被拒', e.message.includes('引用') || e.message.includes('相关'), e.message.slice(0, 20)) }
    // 历史消息回读带 orderId
    const { messages } = await loadMessages(convId)
    check('历史回读订单引用', messages.some((m) => m.orderId === bk.booking.id))
    // 清理
    await petsApi.api('/api/pets/' + pet.pet.id, { method: 'DELETE' })
    petsApi.logout()
    await petsApi.login(c.user.username, '123456')
    await petsApi.api('/api/pets/' + cPet.pet.id, { method: 'DELETE' })
    petsApi.logout()
  } catch (e) { check('订单详情/引用', false, e.message) }

  logout()
  console.log(`\n══════ 结果：${passed} 通过 / ${failed} 失败 ══════`)
  process.exit(failed > 0 ? 1 : 0)
}

main().catch((e) => { console.error('测试异常:', e); process.exit(1) })
