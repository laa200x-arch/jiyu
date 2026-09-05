/* 安全与功能修复综合验证（本地服务器；可用 BASE_URL 指定目标） */
const BASE = process.env.BASE_URL || 'http://localhost:3000'
let passed = 0, failed = 0
const check = (name, cond, extra = '') => {
  if (cond) { passed++; console.log(`  ✅ ${name}`) }
  else { failed++; console.log(`  ❌ ${name} ${extra}`) }
}
const post = async (p, b, token) => {
  const r = await fetch(BASE + p, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: JSON.stringify(b) })
  return { status: r.status, data: await r.json().catch(() => ({})) }
}
const get = async (p, token) => {
  const r = await fetch(BASE + p, { headers: token ? { Authorization: 'Bearer ' + token } : {} })
  return { status: r.status, data: await r.json().catch(() => ({})) }
}

// 登录
const login = await post('/api/auth/login', { username: 'aqing', password: '123456' })
check('登录成功', login.status === 200 && !!login.data.token)
const token = login.data.token
const me = login.data.user

console.log('\n[1] 手机号隐私')
const users = await get('/api/users', token)
check('/api/users 不含任何手机号', users.status === 200 && users.data.users.every((u) => !('phone' in u)), JSON.stringify(users.data.users[0]).slice(0, 200))
const me2 = await get('/api/me', token)
check('/api/me 本人含手机号', 'phone' in me2.data.user || me2.data.user.phone === null)

console.log('\n[2] 宠物订单消息豁免')
const conv = await post('/api/conversations/open', { partnerId: '2' }, token)
const convId = conv.data.conversation.id
// 无订单引用：「接单」应被拦
const r1 = await post('/api/messages', { conversationId: convId, text: '我可以接单吗' }, token)
check('无订单引用「接单」被拦截', r1.status === 201 && r1.data.blocked === true, JSON.stringify(r1.data))
// 有订单引用：需要先有个订单。直接造一个订单（派单人=aqing 自己不行，openToFeed 需要 pet）
// 用第二个用户登录造订单？简化：先注册/用现有用户 2 造宠物+订单
const login2 = await post('/api/auth/login', { username: 'linxiao', password: '123456' })
check('登录用户2', login2.status === 200 && !!login2.data.token)
const token2 = login2.data.token
const pets = await get('/api/pets', token2)
let petId
if (pets.data.pets && pets.data.pets.length) petId = pets.data.pets[0].id
else {
  const mk = await post('/api/pets', { name: '测试汪', petType: 'dog', breed: '金毛', ageMonths: 24, gender: 'male', neutered: true, weightKg: 20 }, token2)
  petId = mk.data.pet?.id
}
const b = await post('/api/bookings', { petId, serviceId: 'walk', providerId: null, scheduledTime: '明天 10:00', location: '朝阳公园', openToFeed: true }, token2)
check('创建宠物订单', b.status === 201, JSON.stringify(b.data))
const orderId = b.data.booking.id
// 双方会话：aqing(1) 与 linxiao(2)
const conv12 = await post('/api/conversations/open', { partnerId: '2' }, token) // aqing 视角
// aqing 给 linxiao 发订单相关消息（引用订单）：接单/价格应放行
const r2 = await post('/api/messages', { conversationId: convId, text: '我可以接单，价格按平台标准没问题', orderId }, token)
check('订单引用「接单/价格」放行', r2.status === 201 && !r2.data.blocked, JSON.stringify(r2.data))
// 订单引用 + 转账：仍应拦截
const r3 = await post('/api/messages', { conversationId: convId, text: '私下转账给你吧', orderId }, token)
check('订单引用「转账」仍拦截', r3.status === 201 && r3.data.blocked === true, JSON.stringify(r3.data))

console.log('\n[3] 忘记密码')
const randPhone = `13${String(Math.floor(1e9 + Math.random() * 9e9)).slice(-9)}`
// 未注册手机号 → 404
const f1 = await post('/api/auth/phone/forgot-code', { phone: randPhone })
check('未注册手机号 forgot-code 404', f1.status === 404, JSON.stringify(f1.data))
// 注册一个带手机号的新用户
const reg = await post('/api/auth/phone/send-code', { phone: randPhone })
const code1 = reg.data.devCode
const uname = 'fpuser' + Date.now()
const reg2 = await post('/api/auth/register', { username: uname, password: '123456', nickname: '找回密码测试', phone: randPhone, code: code1 })
check('注册带手机号用户', reg2.status === 201, JSON.stringify(reg2.data))
// 60 秒限频（注册时刚发过验证码），等待后重发
console.log('  … 等待 61 秒避开 60 秒限频…')
await new Promise((r) => setTimeout(r, 61_000))
const f2 = await post('/api/auth/phone/forgot-code', { phone: randPhone })
check('已注册手机号 forgot-code 201', f2.status === 201 && !!f2.data.devCode, JSON.stringify(f2.data))
const reset = await post('/api/auth/reset-password', { phone: randPhone, code: f2.data.devCode, newPassword: 'newpass888' })
check('重置密码成功', reset.status === 200 && reset.data.ok, JSON.stringify(reset.data))
const loginNew = await post('/api/auth/login', { username: uname, password: 'newpass888' })
check('新密码可登录', loginNew.status === 200 && !!loginNew.data.token)
const loginOld = await post('/api/auth/login', { username: uname, password: '123456' })
check('旧密码失效', loginOld.status === 401)

console.log('\n[4] 登录限流（用不存在的用户名，避免影响其他测试账号）')
let locked = false
for (let i = 0; i < 6; i++) {
  const r = await post('/api/auth/login', { username: 'notexistuser', password: 'wrongpass' })
  if (r.status === 429) { locked = true; break }
}
check('连续 5 次失败后锁定 429', locked)

console.log('\n[5] 评价申诉')
const evals = await get('/api/evaluations/received', token)
check('收到的评价接口可用', evals.status === 200 && Array.isArray(evals.data.evaluations))
// 如果 aqing 有收到的评价，测试申诉；否则造一条
let appealTarget = evals.data.evaluations[0]
if (!appealTarget) {
  // 简化：跳过（冒烟测试会造评价？没有）。改为验证权限：对不存在评价申诉 404
  const app1 = await post('/api/evaluations/999999/appeal', { reason: '测试' }, token)
  check('不存在的评价申诉 404', app1.status === 404)
} else {
  const app = await post(`/api/evaluations/${appealTarget.id}/appeal`, { reason: '评价不实，请求复核' }, token)
  check('申诉提交', app.status === 201, JSON.stringify(app.data))
  const app2 = await post(`/api/evaluations/${appealTarget.id}/appeal`, { reason: '重复申诉' }, token)
  check('重复申诉被拒', app2.status === 400)
  const ev2 = await get('/api/evaluations/received', token)
  check('申诉状态回显', ev2.data.evaluations.find((e) => e.id === appealTarget.id)?.myAppealStatus === 'pending')
}

console.log('\n[6] 上传 MIME 白名单')
const bad = await fetch(BASE + '/api/upload', { method: 'POST', headers: { Authorization: 'Bearer ' + token }, body: (() => { const fd = new FormData(); fd.append('file', new Blob(['<script>alert(1)</script>'], { type: 'text/html' }), 'x.html'); return fd })() })
check('上传 .html 被拒', bad.status === 400, `status=${bad.status}`)
const good = await fetch(BASE + '/api/upload', { method: 'POST', headers: { Authorization: 'Bearer ' + token }, body: (() => { const fd = new FormData(); fd.append('file', new Blob([new Uint8Array([0x89, 0x50, 0x4e, 0x47])], { type: 'image/png' }), 'a.png'); return fd })() })
const goodData = await good.json().catch(() => ({}))
check('上传 .png 成功', good.status === 201 && !!goodData.url, `status=${good.status} body=${JSON.stringify(goodData)}`)
if (goodData.url) {
  const st = await fetch(BASE + goodData.url)
  check('媒体响应 nosniff+attachment', st.headers.get('x-content-type-options') === 'nosniff' && (st.headers.get('content-disposition') || '').includes('attachment'))
}

console.log('\n[7] VIP 过期')
const me3 = await get('/api/me', token)
check('本人档案含 exposureUntil 字段', 'exposureUntil' in me3.data.user)
// 造一个过期 VIP（直接改库不可行；通过接口开通是未来时间）——检查开通后为 VIP
const exp = await fetch(BASE + '/api/me/exposure', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify({ packageId: 'day' }) })
const expData = await exp.json()
check('开通曝光后 VIP=true', expData.user?.isExposureVip === true)

console.log(`\n══════ 综合验证：${passed} 通过 / ${failed} 失败 ══════`)
process.exit(failed > 0 ? 1 : 0)
