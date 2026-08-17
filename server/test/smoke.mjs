/**
 * 技遇后端端到端冒烟测试
 * 运行：node test/smoke.mjs  （需先启动服务：npm start）
 * 覆盖：登录 / 匹配算法 / 距离过滤 / 文本风控(消息+动态) / 协议签署 / 互换完成 / 信用分重算 / 曝光 / Socket 实时消息
 */
import { io as createClient } from 'socket.io-client'

const BASE = process.env.BASE_URL || 'http://localhost:3000'

let passed = 0
let failed = 0
function check(name, cond, extra = '') {
  if (cond) {
    passed++
    console.log(`  ✅ ${name}${extra ? ` — ${extra}` : ''}`)
  } else {
    failed++
    console.log(`  ❌ ${name}${extra ? ` — ${extra}` : ''}`)
  }
}

async function api(path, { method = 'GET', token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers.Authorization = `Bearer ${token}`
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined
  })
  const data = await res.json().catch(() => ({}))
  return { status: res.status, data }
}

console.log('══════ 技遇后端冒烟测试 ══════\n')

// 1. 健康检查
{
  const { status, data } = await api('/api/health')
  check('健康检查', status === 200 && data.ok === true)
}

// 2. 登录演示账号 阿青
let aqing = null
let linxiao = null
{
  const { status, data } = await api('/api/auth/login', { method: 'POST', body: { username: 'aqing', password: '123456' } })
  check('登录 aqing', status === 200 && !!data.token, `user=${data.user?.userName}`)
  aqing = data
}

// 3. 错误密码应被拒绝
{
  const { status } = await api('/api/auth/login', { method: 'POST', body: { username: 'aqing', password: 'wrongpass' } })
  check('错误密码被拒绝', status === 401)
}

// 4. 双向匹配（核心算法）：预期至少包含 林晓/米粒/周可（VIP/高信用优先）
{
  const { status, data } = await api('/api/match', { token: aqing.token })
  check('双向匹配接口', status === 200 && data.matches.length > 0, `共 ${data.matches.length} 位匹配`)
  const names = data.matches.map((m) => m.user.userName)
  check('匹配含 林晓', names.includes('林晓'))
  check('匹配含 周可', names.includes('周可'))
  check('匹配含 米粒', names.includes('米粒'))
  check('匹配含 韩雪', names.includes('韩雪'))
  // 匹配理由双向性：每个结果必须同时有"我教对方"和"对方教我"
  const allBidirectional = data.matches.every(
    (m) => m.mySkillsForThem.length > 0 && m.theirSkillsForMe.length > 0
  )
  check('匹配均为双向对等', allBidirectional)
  // VIP 优先：林晓(90, VIP) 应排首位
  check('VIP 曝光用户优先', data.matches[0]?.user?.userName === '林晓')
  linxiao = data.matches.find((m) => m.user.userName === '林晓')
}

// 5. 同城 10km 过滤：陈默(12km)/阿哲(20km) 应被排除
{
  const { status, data } = await api('/api/match?nearbyOnly=1', { token: aqing.token })
  const names = data.matches.map((m) => m.user.userName)
  check('同城10km过滤', status === 200 && !names.includes('陈默') && !names.includes('阿哲'),
    `剩余 ${names.length} 位`)
}

// 6. 关键词过滤
{
  const { status, data } = await api('/api/match?keyword=日语', { token: aqing.token })
  const names = data.matches.map((m) => m.user.userName)
  check('关键词「日语」过滤', status === 200 && names.includes('米粒') && names.includes('陈默'))
}

// 7. 消息风控：发送「多少钱」应被拦截并追加系统提示
let blockedMessage = null
{
  const convs = await api('/api/conversations', { token: aqing.token })
  const conv = convs.data.conversations[0]
  const { status, data } = await api('/api/messages', {
    method: 'POST', token: aqing.token,
    body: { conversationId: conv.id, text: '这个课程多少钱？' }
  })
  check('违禁消息被拦截', status === 201 && data.blocked === true, data.warning?.slice(0, 30) + '…')
  const msgs = await api(`/api/conversations/${conv.id}/messages`, { token: aqing.token })
  const last = msgs.data.messages[msgs.data.messages.length - 1]
  check('拦截后追加系统提示', last?.isSystemNote === true && last.text.includes('违禁词'))
  blockedMessage = last
}

// 8. 正常消息可发送
{
  const convs = await api('/api/conversations', { token: aqing.token })
  const conv = convs.data.conversations[0]
  const { status, data } = await api('/api/messages', {
    method: 'POST', token: aqing.token,
    body: { conversationId: conv.id, text: '周六下午两点图书馆见，我教你剪辑基础' }
  })
  check('正常消息发送成功', status === 201 && data.blocked !== true)
}

// 9. 动态风控：发布含「收费」动态应被拒
{
  const { status } = await api('/api/dynamics', {
    method: 'POST', token: aqing.token,
    body: { content: '承接视频剪辑，收费 50 元' }
  })
  check('违规动态被拦截', status === 403)
}
{
  const { status } = await api('/api/dynamics', {
    method: 'POST', token: aqing.token,
    body: { content: '周末组队去公园拍秋景，欢迎摄影搭子～' }
  })
  check('合规动态发布成功', status === 201)
}

// 10. 协议签署 → 互换记录生成 + 匹配推送
{
  const partner = linxiao?.user
  if (partner) {
    const { status, data } = await api('/api/agreements', {
      method: 'POST', token: aqing.token,
      body: {
        partnerId: partner.id, mySkillName: '视频剪辑', learnSkillName: '摄影',
        exchangeType: 'both', scheduledTime: '本周日 15:00', location: '国贸图书馆'
      }
    })
    check('签署协议', status === 201 && !!data.record, `status=${status}`)
    check('生成互换记录(pending)', data.record?.status === 'pending')
  } else {
    check('签署协议', false, '缺少匹配用户')
  }
}

// 11. 互换完成 + 评价 + 信用分重算
{
  const { data } = await api('/api/exchanges', { token: aqing.token })
  const rec = data.records.find((r) => r.status === 'pending')
  if (rec) {
    const done = await api(`/api/exchanges/${rec.id}/complete`, { method: 'POST', token: aqing.token })
    check('互换标记完成', done.status === 200)
    const evalRes = await api('/api/evaluations', {
      method: 'POST', token: aqing.token,
      body: { recordId: rec.id, punctuality: 5, serious: 5, communication: 5, comment: '教得超认真！' }
    })
    check('提交评价成功', evalRes.status === 200)
    const recs = await api('/api/exchanges', { token: aqing.token })
    const updated = recs.data.records.find((r) => r.id === rec.id)
    check('互换状态→completed 且已评价', updated?.status === 'completed' && updated?.evaluateGiven === true)
  } else {
    check('互换完成+评价', false, '无待开始的互换记录')
  }
}

// 12. 曝光服务（方案 3.1 模拟开通）
{
  const { status, data } = await api('/api/me/exposure', {
    method: 'PUT', token: aqing.token, body: { packageId: 'week' }
  })
  check('开通曝光(周卡)', status === 200 && data.user.isExposureVip === true)
  const del = await api('/api/me/exposure', { method: 'DELETE', token: aqing.token })
  check('取消曝光', del.status === 200 && del.data.user.isExposureVip === false)
}

// 13. 技能增删（方案 2.3.1）
{
  const add = await api('/api/me/skills', {
    method: 'POST', token: aqing.token,
    body: { kind: 'want', skill: { skillName: '街舞', skillLevel: 'beginner', exchangeType: 'offline', availableTime: '周末' } }
  })
  check('添加技能', add.status === 201 && !!add.data.skill.id)
  const del = await api(`/api/me/skills/want/${add.data.skill.id}`, { method: 'DELETE', token: aqing.token })
  check('删除技能', del.status === 200)
}

// 14. Socket.io 实时消息（双客户端）
{
  const s1 = createClient(BASE, { forceNew: true, auth: { token: aqing.token } })
  const partner = linxiao?.user
  let received = []
  await new Promise((resolve) => s1.on('connect', resolve))
  s1.on('chat:message', (m) => received.push(m))

  const open = await api('/api/conversations/open', {
    method: 'POST', token: aqing.token, body: { partnerId: partner.id }
  })
  console.log('  … socket: open 状态', open.status)
  const convId = open.data.conversation?.id

  // 第二个客户端：林晓
  const lin = await api('/api/auth/login', { method: 'POST', body: { username: 'linxiao', password: '123456' } })
  console.log('  … socket: 林晓登录', lin.status)
  const s2 = createClient(BASE, { forceNew: true, auth: { token: lin.data.token } })
  s2.on('connect_error', (e) => console.log('  … socket: s2 connect_error →', e.message))
  let linReceived = []
  await new Promise((resolve) => s2.on('connect', resolve))
  s2.on('chat:message', (m) => linReceived.push(m))

  // 阿青通过 socket 发合规消息
  await new Promise((resolve) => {
    s1.emit('chat:send', { conversationId: convId, text: '通过 Socket 发送的实时消息' }, (ack) => {
      check('Socket 消息发送成功', ack?.ok === true)
      resolve()
    })
  })
  await new Promise((r) => setTimeout(r, 500))
  check('双方实时收到消息', received.some((m) => m.text === '通过 Socket 发送的实时消息')
    && linReceived.some((m) => m.text === '通过 Socket 发送的实时消息'))

  // 阿青通过 socket 发违禁消息 → blocked
  await new Promise((resolve) => {
    s1.emit('chat:send', { conversationId: convId, text: '私下转账给你' }, (ack) => {
      check('Socket 违禁消息被拦截', ack?.blocked === true)
      resolve()
    })
  })
  await new Promise((r) => setTimeout(r, 500))
  check('双方收到拦截系统提示', received.some((m) => m.text.includes('已被平台风控拦截')))

  s1.close()
  s2.close()
}

// 15. 注册新用户（手机验证：一手机号一号）
{
  const uname = `smokeuser${Date.now()}`
  const randPhone = () => `13${String(Math.floor(1e9 + Math.random() * 9e9)).slice(-9)}`
  const phoneA = randPhone()
  const codeRes = await api('/api/auth/phone/send-code', { method: 'POST', body: { phone: phoneA } })
  check('发送注册验证码（console 通道返回 devCode）', codeRes.status === 201 && !!codeRes.data?.devCode)
  const { status, data } = await api('/api/auth/register', {
    method: 'POST',
    body: { username: uname, password: '123456', nickname: '冒烟测试', phone: phoneA, code: codeRes.data.devCode }
  })
  check('注册新用户（含手机验证码）', status === 201 && !!data.token)
  const dupPhone = await api('/api/auth/register', {
    method: 'POST',
    body: { username: uname, password: '123456', nickname: '重复', phone: phoneA, code: codeRes.data.devCode }
  })
  check('同一手机号二次注册被拒绝', dupPhone.status === 409)
  const phoneB = randPhone()
  const codeB = await api('/api/auth/phone/send-code', { method: 'POST', body: { phone: phoneB } })
  const dup = await api('/api/auth/register', {
    method: 'POST',
    body: { username: uname, password: '123456', nickname: '重复', phone: phoneB, code: codeB.data.devCode }
  })
  check('重复用户名被拒绝', dup.status === 409)
}

console.log(`\n══════ 结果：${passed} 通过 / ${failed} 失败 ══════`)
process.exit(failed > 0 ? 1 : 0)
