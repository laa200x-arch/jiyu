/* ============================================================
 * 技遇 Windows 版 - 视图层（登录/匹配/动态/消息/我的/弹窗）
 * ============================================================ */
'use strict'

/* ---------- 工具 ---------- */
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}
function fmtTime(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const p = (n) => String(n).padStart(2, '0')
  return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}
function levelClass(level) { return 'tag-' + level }
function avatarHtml(user, cls = 'avatar') {
  // 自定义头像优先显示图片
  if (user && user.avatarUrl) return `<img class="${cls} avatar-img" src="${mediaUrl(user.avatarUrl)}" alt="">`
  return `<div class="${cls}">${esc((user && user.avatarSymbol) || '👤')}</div>`
}
function skillTags(skills) {
  if (!skills || !skills.length) return '<span class="card-sub">暂无</span>'
  return skills.map((s) =>
    `<span class="tag ${levelClass(s.skillLevel)}">${esc(s.skillName)} · ${esc(s.skillLevel)}</span>`).join(' ')
}
function mediaUrl(u) { return u ? App.SERVER + u : '' }
function toast(msg) {
  const el = document.getElementById('toast')
  el.textContent = msg
  el.classList.remove('hidden')
  clearTimeout(toast._t)
  toast._t = setTimeout(() => el.classList.add('hidden'), 2600)
}
function openModal(html, onMount) {
  document.getElementById('modal-box').innerHTML = html
  document.getElementById('modal-mask').classList.remove('hidden')
  if (onMount) onMount(document.getElementById('modal-box'))
}
function closeModal() { document.getElementById('modal-mask').classList.add('hidden') }
function openFullscreen(html) {
  const mask = document.createElement('div')
  mask.className = 'fullscreen-mask'
  mask.innerHTML = html + '<button class="fullscreen-close" onclick="this.parentElement.remove()">✕</button>'
  document.body.appendChild(mask)
}

/* 图片压缩（最长边 1280，JPEG 0.7） */
function compressImage(file, maxSide = 1280) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const url = URL.createObjectURL(file)
    img.onload = () => {
      let { width, height } = img
      if (Math.max(width, height) > maxSide) {
        const scale = maxSide / Math.max(width, height)
        width = Math.round(width * scale); height = Math.round(height * scale)
      }
      const canvas = document.createElement('canvas')
      canvas.width = width; canvas.height = height
      canvas.getContext('2d').drawImage(img, 0, 0, width, height)
      URL.revokeObjectURL(url)
      canvas.toBlob((blob) => resolve(blob), 'image/jpeg', 0.7)
    }
    img.onerror = () => reject(new Error('图片读取失败'))
    img.src = url
  })
}

/* ---------- 登录页 ---------- */
function renderLogin() {
  const page = document.getElementById('login-page')
  page.classList.remove('hidden')
  document.getElementById('app').classList.add('hidden')
  const box = document.getElementById('saved-accounts')
  if (App.state.savedAccounts.length) {
    box.classList.remove('hidden')
    box.innerHTML = '<div style="width:100%;text-align:center;color:#737d87;font-size:11px;margin-bottom:4px">已保存账号（点击切换）</div>' +
      App.state.savedAccounts.map((a) => `
        <div class="saved-account" data-username="${esc(a.username)}">
          <span class="saved-remove" data-remove="${esc(a.username)}" title="删除">✕</span>
          <div class="saved-avatar">${esc(a.avatarSymbol || '👤')}</div>
          <div class="saved-name">${esc(a.nickname)}</div>
        </div>`).join('')
  } else {
    box.classList.add('hidden')
  }
}

/* ---------- 匹配视图 ---------- */
let matchFilters = { nearbyOnly: false, type: '', keyword: '' }
async function renderMatch() {
  const v = document.getElementById('view')
  v.innerHTML = `
    <div class="filter-bar">
      <button class="chip ${!matchFilters.type ? 'active' : ''}" data-type="">全部</button>
      <button class="chip ${matchFilters.type === 'online' ? 'active' : ''}" data-type="online">线上</button>
      <button class="chip ${matchFilters.type === 'offline' ? 'active' : ''}" data-type="offline">线下</button>
      <button class="chip ${matchFilters.type === 'both' ? 'active' : ''}" data-type="both">线上+线下</button>
      <button class="chip ${matchFilters.nearbyOnly ? 'active' : ''}" data-nearby="1">同城 10km</button>
      <input class="search-box" id="match-keyword" placeholder="搜索技能或昵称" value="${esc(matchFilters.keyword)}">
      <button class="btn btn-outline btn-sm" id="match-map-btn">🗺️ 同城地图</button>
    </div>
    <div id="match-list"></div>`
  v.querySelectorAll('.chip').forEach((c) => c.addEventListener('click', () => {
    if (c.dataset.type !== undefined) matchFilters.type = c.dataset.type
    if (c.dataset.nearby) matchFilters.nearbyOnly = !matchFilters.nearbyOnly
    renderMatch()
  }))
  v.querySelector('#match-keyword').addEventListener('input', (e) => {
    matchFilters.keyword = e.target.value
    clearTimeout(renderMatch._t)
    renderMatch._t = setTimeout(renderMatch, 400)
  })
  v.querySelector('#match-map-btn').addEventListener('click', () => showMap())
  const list = v.querySelector('#match-list')
  list.innerHTML = '<div class="empty">加载中…</div>'
  try {
    const matches = await fetchMatches({ nearbyOnly: matchFilters.nearbyOnly ? 1 : '', type: matchFilters.type, keyword: matchFilters.keyword })
    if (!matches.length) {
      list.innerHTML = '<div class="empty"><div class="empty-icon">✨</div>暂时没有匹配<br>完善「我擅长」和「我想学」技能档案，匹配率更高</div>'
      return
    }
    list.innerHTML = matches.map((m) => {
      const u = m.user
      return `
      <div class="card" data-match='${JSON.stringify({ id: u.id, mySkillsForThem: m.mySkillsForThem, theirSkillsForMe: m.theirSkillsForMe })}'>
        <div class="row">
          ${avatarHtml(u)}
          <div style="flex:1">
            <div class="row">
              <span class="convo-name">${esc(u.userName)}</span>
              ${u.isExposureVip ? '<span class="tag tag-vip">👑 曝光</span>' : ''}
              ${u.verification !== 'none' ? `<span class="tag tag-verified">✓ ${esc(u.verification)}</span>` : ''}
            </div>
            <div class="card-sub">${esc(u.bio)}</div>
          </div>
          <span class="tag tag-credit">🛡 信用 ${Math.round(u.creditScore)}</span>
        </div>
        <div class="match-reason">
          <span class="reason-title">⇄ 双向匹配成功</span><br>
          你教 TA：${esc(m.mySkillsForThem.join('、'))}<br>
          TA 教你：${esc(m.theirSkillsForMe.join('、'))}
        </div>
        <div class="row">
          <span class="card-sub">📍 ${esc(u.locationLabel)}${u.distanceKm != null ? ' · ' + u.distanceKm.toFixed(1) + 'km' : ''}</span>
          <span class="spacer"></span>
          <button class="btn btn-primary btn-sm">发起互换</button>
        </div>
      </div>`
    }).join('')
    list.querySelectorAll('.card').forEach((card) => card.addEventListener('click', (e) => {
      if (e.target.closest('button')) return
      const data = JSON.parse(card.dataset.match)
      showMatchDetail(data.id, data)
    }))
  } catch (e) {
    list.innerHTML = `<div class="empty">匹配加载失败：${esc(e.message)}</div>`
  }
}

/* 匹配详情 + 协议签署 */
async function showMatchDetail(userId, reason) {
  try {
    const u = await fetchUser(userId)
    const my = App.state.user
    openModal(`
      <div class="modal-title">${esc(u.userName)}</div>
      <div class="row" style="margin-bottom:12px">
        ${avatarHtml(u, 'avatar avatar-lg')}
        <div style="flex:1">
          <div class="row">
            <span class="convo-name">${esc(u.userName)}</span>
            ${u.isExposureVip ? '<span class="tag tag-vip">👑 曝光</span>' : ''}
            ${u.verification !== 'none' ? `<span class="tag tag-verified">✓ ${esc(u.verification)}</span>` : ''}
          </div>
          <div class="card-sub">${esc(u.bio)}</div>
          <div class="row" style="margin-top:4px">
            <span class="tag tag-credit">🛡 信用 ${Math.round(u.creditScore)}</span>
            <span class="card-sub">📍 ${esc(u.locationLabel)}</span>
          </div>
        </div>
      </div>
      <div class="match-reason">
        <span class="reason-title">🤝 为什么匹配到你</span><br>
        你教 TA：${esc(reason.mySkillsForThem.join('、'))}<br>
        TA 教你：${esc(reason.theirSkillsForMe.join('、'))}
      </div>
      <div class="card-sub" style="margin:8px 0 4px">TA 擅长（可以教你）</div>
      <div class="skill-grid" style="margin-bottom:10px">${skillTags(u.mySkills)}</div>
      <div class="card-sub" style="margin:8px 0 4px">TA 想学（你来教）</div>
      <div class="skill-grid" style="margin-bottom:14px">${skillTags(u.wantSkills)}</div>
      <div class="modal-actions">
        <button class="btn btn-outline" id="md-chat">💬 私信沟通</button>
        <button class="btn btn-primary" id="md-sign">📝 发起互换（签署协议）</button>
      </div>
    `, (box) => {
      box.querySelector('#md-chat').addEventListener('click', () => { closeModal(); startChatWithUser(u) })
      box.querySelector('#md-sign').addEventListener('click', () => { closeModal(); showAgreementForm(u) })
    })
  } catch (e) { toast('加载失败：' + e.message) }
}

/* 协议签署表单 */
function showAgreementForm(u) {
  const my = App.state.user
  openModal(`
    <div class="modal-title">互换协议 · 与 ${esc(u.userName)}</div>
    <div class="form-field"><label>我提供（我擅长）</label>
      <select id="ag-my">${my.mySkills.map((s) => `<option value="${esc(s.skillName)}">${esc(s.skillName)}</option>`).join('') || '<option value="">请先添加技能</option>'}</select>
    </div>
    <div class="form-field"><label>我学习（对方擅长）</label>
      <select id="ag-learn">${u.mySkills.map((s) => `<option value="${esc(s.skillName)}">${esc(s.skillName)}</option>`).join('') || '<option value="">对方暂无可教技能</option>'}</select>
    </div>
    <div class="form-row">
      <div class="form-field"><label>交换方式</label>
        <select id="ag-type"><option value="both">线上+线下</option><option value="online">线上</option><option value="offline">线下</option></select>
      </div>
      <div class="form-field"><label>约定时间</label><input id="ag-time" placeholder="如：本周六 14:00"></div>
    </div>
    <div class="form-field"><label>线下地点（公共场所，线上可留空）</label><input id="ag-location" placeholder="如：国贸图书馆三楼"></div>
    <div class="card" style="background:#f7f9fa">
      <div class="card-sub" style="line-height:1.8">【技遇平台官方技能互换协议】<br>
      1. 本次技能互换为纯个人兴趣无偿交换，无任何金钱、物资、有偿交易。<br>
      2. 双方承诺认真教学、守时履约，杜绝敷衍教学、无故爽约。<br>
      3. 线下交换请选择公共场所，注意人身与财产安全。<br>
      4. 违反协议将受扣分、限流、封禁处理。</div>
    </div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" id="ag-submit">确认签署</button>
    </div>
  `, (box) => {
    box.querySelector('#ag-submit').addEventListener('click', async () => {
      const type = box.querySelector('#ag-type').value
      const location = box.querySelector('#ag-location').value.trim()
      if (type !== 'online' && !location) return toast('线下交换请填写公共场所地点')
      try {
        await signAgreement({
          partnerId: u.id,
          mySkillName: box.querySelector('#ag-my').value,
          learnSkillName: box.querySelector('#ag-learn').value,
          exchangeType: type,
          scheduledTime: box.querySelector('#ag-time').value.trim() || '待协商',
          location: type === 'online' ? undefined : location
        })
        closeModal()
        toast(`✅ 已与 ${u.userName} 签署协议，互换记录已生成`)
        if (App.state.views.onDataChanged) App.state.views.onDataChanged()
      } catch (e) { toast('签署失败：' + e.message) }
    })
  })
}

/* ---------- 动态视图 ---------- */
async function renderFeed() {
  const v = document.getElementById('view')
  v.innerHTML = `
    <div class="row" style="margin-bottom:14px">
      <span class="section-title" style="margin:0;flex:1">互换动态</span>
      <button class="btn btn-primary btn-sm" id="feed-compose">✏️ 发布动态</button>
    </div>
    <div id="feed-list"></div>`
  v.querySelector('#feed-compose').addEventListener('click', showFeedCompose)
  const list = v.querySelector('#feed-list')
  list.innerHTML = '<div class="empty">加载中…</div>'
  try {
    await refreshAll()
    if (!App.state.dynamics.length) {
      list.innerHTML = '<div class="empty"><div class="empty-icon">📢</div>暂无动态</div>'
      return
    }
    list.innerHTML = App.state.dynamics.map((d) => {
      // 订单卡片：优先用动态自带字段（第三方也能看到），回退查自己的订单列表
      const own = d.orderId ? App.state.bookings.find((b) => b.id === d.orderId) : null
      const orderStatus = d.orderStatus || (own ? own.status : null)
      const orderPrice = d.orderPriceYuan ?? (own ? own.priceYuan : null)
      const orderService = d.orderService || (own ? own.serviceName : '')
      const isOwnOrder = d.orderId && String(d.userId) === String(App.state.user.id)
      const canAccept = d.orderId && orderStatus === 'open' && !isOwnOrder
        && (App.state.user.creditScore >= 75 && App.state.user.verification !== 'none')
      const orderBlock = d.orderId ? `
            <div class="feed-order-bar" data-order-detail="${esc(d.orderId)}" style="margin-top:10px;display:flex;align-items:center;gap:12px;flex-wrap:wrap;cursor:pointer" title="查看订单详情">
              <span class="tag tag-vip">💰 收费订单 ¥${orderPrice} · 佣金 10%</span>
              <span class="card-sub">${esc(orderService)}</span>
              <span class="spacer"></span>
              ${orderStatus === 'open'
                ? (canAccept
                    ? `<button class="btn btn-primary btn-sm" data-accept="${esc(d.orderId)}">接单</button>`
                    : (isOwnOrder
                        ? '<span class="card-sub">等待接单中…</span>'
                        : '<span class="card-sub" title="接单需信用≥75且完成认证">🔒 有资历者接单</span>'))
                : `<span class="tag tag-verified">已接单</span>`}
            </div>` : ''
      return `
      <div class="card feed-item">
        ${avatarHtml({ avatarSymbol: d.avatarSymbol }, 'avatar avatar-sm')}
        <div class="feed-body">
          <div class="feed-head">
            <span class="feed-author" data-author="${esc(d.userId)}">${esc(d.authorName)}</span>
            ${!d.isSystemPost ? '<span class="card-sub">›</span>' : ''}
            <span class="feed-time">${fmtTime(d.time)}</span>
          </div>
          <div class="feed-content">${esc(d.content)}</div>
          ${d.imageBase64 ? `<img class="feed-image" src="data:image/jpeg;base64,${d.imageBase64}" onclick="openFullscreen('<img src=&quot;data:image/jpeg;base64,${d.imageBase64}&quot;>')">` : ''}
          ${orderBlock}
        </div>
      </div>`
    }).join('')
    list.querySelectorAll('.feed-author').forEach((el) => el.addEventListener('click', async () => {
      const uid = el.dataset.author
      if (!uid || el.textContent === '平台') return
      try {
        const u = await fetchUser(uid)
        showUserProfile(u)
      } catch (e) { toast('加载失败') }
    }))
    // 订单接单
    list.querySelectorAll('[data-accept]').forEach((b) => b.addEventListener('click', async () => {
      if (!confirm('确认接下这笔订单？服务完成后费用按订单结算（平台收取 10% 佣金）')) return
      try {
        await acceptBooking(b.dataset.accept)
        toast('✅ 接单成功，可在「宠物 → 我的订单」查看')
        renderFeed()
      } catch (e) { toast('接单失败：' + e.message) }
    }))
    // 订单详情（查看狗狗信息/位置距离/私聊）
    list.querySelectorAll('[data-order-detail]').forEach((el) => el.addEventListener('click', (e) => {
      if (e.target.closest('[data-accept]')) return
      showOrderDetail(el.dataset.orderDetail)
    }))
  } catch (e) {
    list.innerHTML = `<div class="empty">加载失败：${esc(e.message)}</div>`
  }
}

/* 订单详情（宠物信息 / 位置距离 / 金额 / 私聊下单人或看护人） */
async function showOrderDetail(orderId) {
  let b
  try { b = await fetchBooking(orderId) }
  catch (e) { return toast('订单加载失败：' + e.message) }
  const pet = b.pet
  const isMeInvolved = b.userId === App.state.user.id || b.providerId === App.state.user.id
  const petInfo = pet ? `
    <div class="order-detail-block">
      <div class="card-sub" style="margin-bottom:6px">🐕 宠物信息</div>
      <div class="order-detail-line"><b>${esc(pet.name)}</b> · ${pet.petType === 'dog' ? '狗' : pet.petType === 'cat' ? '猫' : '其他'} · ${esc(pet.breed)} · ${pet.ageMonths} 月</div>
      <div class="card-sub">${pet.neutered ? '已绝育' : '未绝育'} · ${pet.gender === 'male' ? '公' : '母'}${pet.weightKg ? ' · ' + pet.weightKg + 'kg' : ''}</div>
      ${pet.behaviors && pet.behaviors.length ? `<div class="card-sub">行为：${esc(pet.behaviors.join('、'))}</div>` : ''}
      ${pet.homeReactions && pet.homeReactions.length ? `<div class="card-sub">家中反应：${esc(pet.homeReactions.join('、'))}</div>` : ''}
      ${pet.notes ? `<div class="card-sub">📝 ${esc(pet.notes)}</div>` : ''}
    </div>` : ''
  const initiatorBlock = b.initiator ? `
    <div class="order-detail-block">
      <div class="card-sub" style="margin-bottom:6px">👤 下单人</div>
      <div class="row">
        ${avatarHtml(b.initiator, 'avatar avatar-sm')}
        <div style="flex:1">
          <div class="order-detail-line"><b>${esc(b.initiator.userName)}</b>（信用 ${Math.round(b.initiator.creditScore)}）</div>
          <div class="card-sub">${esc(b.initiator.locationLabel || '未填位置')}${b.distanceKm != null ? ' · 距离你约 ' + b.distanceKm + ' km' : ''}</div>
        </div>
      </div>
    </div>` : ''
  const providerBlock = b.provider ? `
    <div class="order-detail-block">
      <div class="card-sub" style="margin-bottom:6px">🧑‍⚕️ 看护人</div>
      <div class="row">
        ${avatarHtml(b.provider, 'avatar avatar-sm')}
        <div style="flex:1">
          <div class="order-detail-line"><b>${esc(b.provider.userName)}</b>（信用 ${Math.round(b.provider.creditScore)}）</div>
          <div class="card-sub">${esc(b.provider.locationLabel || '未填位置')}${b.provider.distanceKm != null ? ' · 距离你约 ' + b.provider.distanceKm + ' km' : ''}</div>
        </div>
      </div>
    </div>` : (b.status === 'open' ? '<div class="order-detail-block card-sub">⏳ 待接单：信用 ≥75 且完成认证的用户可接单</div>' : '')
  openModal(`
    <div class="modal-title">订单详情 · ${esc(b.serviceName)}</div>
    <div class="row" style="margin-bottom:10px">
      <span class="tag tag-vip">💰 ¥${b.priceYuan}/次</span>
      <span class="exchange-status ${b.status}">${orderStatusText(b.status)}</span>
      <span class="spacer"></span>
      <span class="card-sub">${esc(b.scheduledTime)}</span>
    </div>
    <div class="order-detail-block">
      <div class="card-sub" style="margin-bottom:6px">📍 服务地点</div>
      <div class="order-detail-line">${esc(b.location || '线上')}</div>
    </div>
    <div class="order-detail-block">
      <div class="card-sub" style="margin-bottom:6px">💰 金额结算</div>
      <div class="order-detail-line">服务费 ¥${b.priceYuan} · 平台佣金 ¥${b.commissionYuan}（10%） · 服务人员得 ¥${b.workerIncome}</div>
    </div>
    ${petInfo}
    ${initiatorBlock}
    ${providerBlock}
    <div class="modal-actions" style="flex-wrap:wrap">
      ${b.initiator && b.initiator.id !== App.state.user.id ? `<button class="btn btn-primary" id="od-chat-initiator">💬 私聊下单人</button>` : ''}
      ${b.provider && b.provider.id !== App.state.user.id ? `<button class="btn btn-primary" id="od-chat-provider">💬 私聊看护人</button>` : ''}
      <button class="btn btn-outline" onclick="closeModal()">关闭</button>
    </div>
  `, (box) => {
    const chatWith = async (user) => {
      closeModal()
      try {
        const conv = await openConversation(user.id)
        App.state.orderDraft = b
        await renderMessage()
        showChat(conv)
        switchTab('message')
      } catch (e) { toast('无法创建会话：' + e.message) }
    }
    const bi = box.querySelector('#od-chat-initiator')
    if (bi) bi.addEventListener('click', () => chatWith(b.initiator))
    const bp = box.querySelector('#od-chat-provider')
    if (bp) bp.addEventListener('click', () => chatWith(b.provider))
  })
}

/* 用户资料（动态作者/私信入口） */
function showUserProfile(u) {
  openModal(`
    <div class="modal-title">${esc(u.userName)}</div>
    <div class="row" style="margin-bottom:12px">
      ${avatarHtml(u, 'avatar avatar-lg')}
      <div style="flex:1">
        <div class="row">
          <span class="convo-name">${esc(u.userName)}</span>
          ${u.isExposureVip ? '<span class="tag tag-vip">👑 曝光</span>' : ''}
          ${u.verification !== 'none' ? `<span class="tag tag-verified">✓ ${esc(u.verification)}</span>` : ''}
        </div>
        <div class="card-sub">${esc(u.bio)}</div>
        <div class="row" style="margin-top:4px">
          <span class="tag tag-credit">🛡 信用 ${Math.round(u.creditScore)}</span>
          <span class="card-sub">📍 ${esc(u.locationLabel)}</span>
        </div>
      </div>
    </div>
    <div class="card-sub" style="margin:8px 0 4px">我擅长（可以教你）</div>
    <div class="skill-grid" style="margin-bottom:10px">${skillTags(u.mySkills)}</div>
    <div class="card-sub" style="margin:8px 0 4px">我想学（你来教）</div>
    <div class="skill-grid" style="margin-bottom:14px">${skillTags(u.wantSkills)}</div>
    <div class="modal-actions">
      <button class="btn btn-primary" id="up-chat">💬 私信沟通</button>
    </div>
  `, (box) => {
    box.querySelector('#up-chat').addEventListener('click', () => { closeModal(); startChatWithUser(u) })
  })
}

/* 发布动态（文字 + 图片） */
function showFeedCompose() {
  openModal(`
    <div class="modal-title">发布动态</div>
    <div class="form-field"><textarea id="fd-content" placeholder="分享你的技能、活动、作品…"></textarea></div>
    <div class="row" style="margin-bottom:10px">
      <label class="btn btn-outline btn-sm" style="cursor:pointer">🖼 添加图片<input type="file" id="fd-image" accept="image/*" hidden></label>
      <span id="fd-image-name" class="card-sub"></span>
    </div>
    <div class="card-sub" style="color:#f29e4d;margin-bottom:10px">⚠️ 禁止发布收费、交易、接单等商业信息，内容将自动经过平台风控审核</div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" id="fd-submit">发布</button>
    </div>
  `, (box) => {
    let imageBase64 = null
    box.querySelector('#fd-image').addEventListener('change', async (e) => {
      const file = e.target.files[0]
      if (!file) return
      try {
        const blob = await compressImage(file)
        const reader = new FileReader()
        reader.onload = () => {
          imageBase64 = String(reader.result).split(',')[1]
          box.querySelector('#fd-image-name').textContent = '✓ ' + file.name + '（已压缩）'
        }
        reader.readAsDataURL(blob)
      } catch (err) { toast(err.message) }
    })
    box.querySelector('#fd-submit').addEventListener('click', async () => {
      const content = box.querySelector('#fd-content').value.trim()
      if (!content && !imageBase64) return toast('请输入内容或选择图片')
      try {
        await postDynamic(content, imageBase64)
        closeModal()
        toast('✅ 发布成功')
        renderFeed()
      } catch (e) { toast('发布失败：' + e.message) }
    })
  })
}

/* ---------- 消息视图 ---------- */
async function renderMessage() {
  const v = document.getElementById('view')
  v.innerHTML = `
    <div class="chat-layout">
      <div class="chat-list-panel" id="convo-list"></div>
      <div class="chat-main" id="chat-main">
        <div class="chat-head" id="chat-head"><span class="card-sub">选择左侧会话开始聊天</span></div>
        <div class="chat-messages" id="chat-messages"></div>
        <div class="chat-input" id="chat-input"></div>
      </div>
    </div>`
  await renderConvoList()
}

async function renderConvoList() {
  const list = document.getElementById('convo-list')
  if (!list) return
  try { await refreshAll() } catch (e) { /* 保留现有 */ }
  const unreadTotal = App.state.conversations.reduce((s, c) => s + (c.unreadCount || 0), 0)
  const badge = document.getElementById('msg-badge')
  if (unreadTotal > 0) { badge.textContent = unreadTotal; badge.classList.remove('hidden') }
  else badge.classList.add('hidden')
  if (!App.state.conversations.length) {
    list.innerHTML = '<div class="empty">暂无会话<br>在「技能匹配」中发起互换邀约</div>'
    return
  }
  list.innerHTML = App.state.conversations.map((c) => `
    <div class="card convo-item" data-cid="${c.id}">
      <div class="row">
        ${avatarHtml(c.partner)}
        <div style="flex:1;min-width:0">
          <div class="row">
            <span class="convo-name">${esc(c.partner.userName)}</span>
            <span class="spacer"></span>
            <span class="convo-time">${fmtTime(c.lastTime)}</span>
          </div>
          <div class="convo-last">${esc(c.lastMessageText)}</div>
        </div>
        ${c.unreadCount > 0 ? `<span class="unread-dot">${c.unreadCount}</span>` : ''}
      </div>
    </div>`).join('')
  list.querySelectorAll('.convo-item').forEach((el) => el.addEventListener('click', () => {
    const conv = App.state.conversations.find((c) => c.id === el.dataset.cid)
    if (conv) showChat(conv)
  }))
}

/* 聊天面板 */
async function showChat(conv) {
  App.state.activeConversation = conv.id
  conv.unreadCount = 0
  markRead(conv.id)
  renderConvoList()
  const head = document.getElementById('chat-head')
  const msgs = document.getElementById('chat-messages')
  const input = document.getElementById('chat-input')
  head.innerHTML = `${avatarHtml(conv.partner, 'avatar avatar-sm')} <span>${esc(conv.partner.userName)}</span>`
  msgs.innerHTML = '<div class="empty">加载中…</div>'
  input.innerHTML = buildChatInput(conv)
  bindChatInput(conv)

  if (App.state.syncHistory) {
    try {
      const list = (await loadMessages(conv.id)).messages
      App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
    } catch (e) { /* ignore */ }
  } else {
    App.state.messages[conv.id] = App.state.messages[conv.id] || []
  }
  renderMessages(conv)
}

function renderMessages(conv) {
  const msgs = document.getElementById('chat-messages')
  const list = App.state.messages[conv.id] || []
  if (!list.length) {
    msgs.innerHTML = '<div class="empty">暂无消息，发条消息开始交换吧～</div>'
    return
  }
  msgs.innerHTML =
    (App.state.hasMore[conv.id] ? '<button class="load-earlier" id="load-earlier">↑ 加载更早消息</button>' : '') +
    list.map((m) => messageHtml(m)).join('')
  // 填充订单引用卡片
  msgs.querySelectorAll('.msg-order-card[data-order-id]').forEach((el) => {
    fillOrderCard(el, el.dataset.orderId)
  })
  const btn = msgs.querySelector('#load-earlier')
  if (btn) btn.addEventListener('click', async () => {
    const list2 = (await loadMessages(conv.id, list[0].id)).messages
    const earlier = list2.map((m) => normalizeMessage(m, m.senderIsMe))
    App.state.messages[conv.id] = earlier.concat(list)
    renderMessages(conv)
  })
  msgs.scrollTop = msgs.scrollHeight
}

function messageHtml(m) {
  if (m.isSystemNote) {
    return `<div class="msg-note">${esc(m.text)}</div>`
  }
  let media = ''
  if (m.mediaType === 'image' && m.mediaUrl) {
    media = `<img class="msg-image" src="${mediaUrl(m.mediaUrl)}" onclick="openFullscreen('<img src=&quot;${mediaUrl(m.mediaUrl)}&quot;>')">`
  } else if (m.mediaType === 'video' && m.mediaUrl) {
    media = `<div class="msg-media-card" onclick="openFullscreen('<video src=&quot;${mediaUrl(m.mediaUrl)}&quot; controls autoplay></video>')">▶ 播放视频</div>`
  } else if (m.mediaType === 'audio' && m.mediaUrl) {
    media = `<div class="msg-media-card" onclick="playAudio('${mediaUrl(m.mediaUrl)}')">🔊 语音消息</div>`
  }
  const orderCard = m.orderId
    ? `<div class="msg-order-card" data-order-id="${esc(m.orderId)}"><span class="card-sub">订单卡片加载中…</span></div>`
    : ''
  const bubble = media + orderCard + (m.text ? `<div>${esc(m.text)}</div>` : '')
  return `<div class="msg ${m.senderIsMe ? 'me' : 'them'}"><div class="msg-bubble">${bubble}</div></div>`
}

/* 异步填充聊天里的订单卡片（fetchBooking → 缓存 → 渲染） */
async function fillOrderCard(el, orderId) {
  try {
    const b = await fetchBooking(orderId)
    el.innerHTML = `
      <div class="order-card-head">🐾 宠物护理订单</div>
      <div class="order-card-line">${esc(b.serviceName)} · <b style="color:#d97b2e">¥${b.priceYuan}</b></div>
      <div class="card-sub">${esc(b.pet ? b.pet.name : '')} · ${orderStatusText(b.status)} · 佣金 10%</div>`
    el.addEventListener('click', () => showOrderDetail(orderId))
  } catch (e) {
    el.innerHTML = '<span class="card-sub">订单卡片加载失败</span>'
  }
}

function playAudio(url) {
  openFullscreen(`<audio src="${url}" controls autoplay style="width:60vw"></audio>`)
}

function buildChatInput(conv) {
  return `
    <div class="chat-tools">
      <button class="icon-btn" id="ci-order" title="引用订单卡片">🧾</button>
      <button class="icon-btn" id="ci-image" title="发送图片">🖼</button>
      <button class="icon-btn" id="ci-video" title="发送视频">🎬</button>
      <button class="icon-btn" id="ci-camera" title="拍照发送">📷</button>
      <button class="icon-btn" id="ci-voice" title="语音消息">🎤</button>
      <input type="file" id="ci-image-file" accept="image/*" hidden>
      <input type="file" id="ci-video-file" accept="video/*" hidden>
      <span id="ci-recording" class="recording-indicator hidden"><span class="recording-dot"></span>录音中…</span>
    </div>
    <div id="ci-order-chip" class="order-chip hidden"></div>
    <textarea id="ci-text" placeholder="发送消息（严禁金钱交易内容）" rows="1"></textarea>
    <button class="btn btn-primary" id="ci-send" disabled>发送</button>`
}

function renderOrderChip(conv) {
  const chip = document.getElementById('ci-order-chip')
  if (!chip) return
  const draft = App.state.orderDraft
  if (!draft) { chip.classList.add('hidden'); chip.innerHTML = ''; return }
  chip.classList.remove('hidden')
  chip.innerHTML = `
    <span>🧾 引用订单：${esc(draft.serviceName)} · ¥${draft.priceYuan}（${esc(draft.pet ? draft.pet.name : '')}）</span>
    <button class="icon-btn" id="ci-order-remove" title="移除引用">✕</button>`
  chip.querySelector('#ci-order-remove').addEventListener('click', () => {
    App.state.orderDraft = null
    renderOrderChip(conv)
    document.getElementById('ci-send').disabled = !document.getElementById('ci-text').value.trim()
  })
}

/* 引用订单选择器（列出我相关订单；从订单详情进入时已自动带上草稿） */
function showOrderPicker(conv) {
  const orders = App.state.bookings
  if (!orders.length) return toast('暂无相关订单（下单或接单），先到「宠物」Tab 发起一笔订单吧')
  openModal(`
    <div class="modal-title">引用订单</div>
    <div class="card-sub" style="margin-bottom:12px">选择一笔与你相关的订单（我发布或我接单）</div>
    ${orders.map((b) => `
      <div class="card order-pick" data-oid="${esc(b.id)}" style="margin-bottom:8px;cursor:pointer">
        <div class="row">
          <div style="flex:1;min-width:0">
            <div class="row"><span class="convo-name">${esc(b.serviceName)}</span><span class="spacer"></span><span class="tag tag-vip">¥${b.priceYuan}</span></div>
            <div class="card-sub">${esc(b.pet ? b.pet.name : '')} · ${orderStatusText(b.status)} · 🕐 ${esc(b.scheduledTime)}</div>
          </div>
        </div>
      </div>`).join('')}
    <div class="modal-actions"><button class="btn btn-outline" onclick="closeModal()">取消</button></div>
  `, (box) => {
    box.querySelectorAll('.order-pick').forEach((el) => el.addEventListener('click', () => {
      const b = App.state.bookings.find((x) => x.id === el.dataset.oid)
      if (!b) return
      App.state.orderDraft = b
      closeModal()
      renderOrderChip(conv)
      document.getElementById('ci-send').disabled = false
    }))
  })
}

function bindChatInput(conv) {
  const text = document.getElementById('ci-text')
  const sendBtn = document.getElementById('ci-send')
  const recording = document.getElementById('ci-recording')
  const fileImage = document.getElementById('ci-image-file')
  const fileVideo = document.getElementById('ci-video-file')
  renderOrderChip(conv)
  text.addEventListener('input', () => { sendBtn.disabled = !text.value.trim() && !App.state.orderDraft })
  text.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send() }
  })
  sendBtn.addEventListener('click', send)
  document.getElementById('ci-order').addEventListener('click', () => showOrderPicker(conv))

  document.getElementById('ci-image').addEventListener('click', () => fileImage.click())
  document.getElementById('ci-video').addEventListener('click', () => fileVideo.click())
  fileImage.addEventListener('change', async (e) => {
    const file = e.target.files[0]
    if (!file) return
    try {
      sendBtn.textContent = '上传中…'
      const blob = await compressImage(file)
      const url = await uploadMedia(await blob.arrayBuffer(), 'image.jpg', 'image/jpeg')
      sendBtn.textContent = '发送'
      await sendMedia(conv, 'image', url)
    } catch (err) { sendBtn.textContent = '发送'; toast('图片发送失败：' + err.message) }
    e.target.value = ''
  })
  fileVideo.addEventListener('change', async (e) => {
    const file = e.target.files[0]
    if (!file) return
    if (file.size > 50 * 1024 * 1024) return toast('视频超过 50MB 限制')
    try {
      sendBtn.textContent = '上传中…'
      const url = await uploadMedia(await file.arrayBuffer(), 'video.mp4', 'video/mp4')
      sendBtn.textContent = '发送'
      await sendMedia(conv, 'video', url)
    } catch (err) { sendBtn.textContent = '发送'; toast('视频发送失败：' + err.message) }
    e.target.value = ''
  })

  document.getElementById('ci-camera').addEventListener('click', () => startCamera(conv))
  document.getElementById('ci-voice').addEventListener('click', () => toggleVoice(conv, recording))

  async function send() {
    const content = text.value.trim()
    const orderDraft = App.state.orderDraft
    if (!content && !orderDraft) return
    text.value = ''
    App.state.orderDraft = null
    renderOrderChip(conv)
    sendBtn.disabled = true
    // Socket 实时发送，失败 REST 兜底
    const ack = await socketSend(conv.id, content, orderDraft ? orderDraft.id : null)
    if (ack.blocked) {
      showBlocked(ack.warning)
      const list = (await loadMessages(conv.id)).messages
      App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
      renderMessages(conv)
    } else if (!ack.ok) {
      try {
        const r = await sendMessageRest(conv.id, content, null, null, orderDraft ? orderDraft.id : null)
        if (r.blocked) showBlocked(r.warning)
        const list = (await loadMessages(conv.id)).messages
        App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
        renderMessages(conv)
      } catch (err) { toast('发送失败：' + err.message) }
    } else {
      const list = (await loadMessages(conv.id)).messages
      App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
      renderMessages(conv)
    }
  }

  async function sendMedia(conv2, mediaType, url) {
    try {
      const r = await sendMessageRest(conv2.id, '', mediaType, url)
      if (r.blocked) { showBlocked(r.warning); return }
      const list = (await loadMessages(conv2.id)).messages
      App.state.messages[conv2.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
      renderMessages(conv2)
    } catch (err) { toast('发送失败：' + err.message) }
  }

  function showBlocked(warning) {
    const msgs = document.getElementById('chat-messages')
    const banner = document.createElement('div')
    banner.className = 'blocked-banner'
    banner.textContent = '⛔ ' + (warning || '内容违规，已被拦截')
    msgs.parentElement.insertBefore(banner, msgs)
    setTimeout(() => banner.remove(), 4000)
  }
}

/* 从资料/匹配发起聊天 */
async function startChatWithUser(u) {
  try {
    const conv = await openConversation(u.id)
    await renderMessage()
    showChat(conv)
    switchTab('message')
  } catch (e) { toast('无法创建会话：' + e.message) }
}

/* ---------- 语音（MediaRecorder） ---------- */
let recorder = null
let recorderChunks = []
async function toggleVoice(conv, indicator) {
  if (recorder && recorder.state === 'recording') {
    recorder.stop()
    indicator.classList.add('hidden')
    return
  }
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    recorder = new MediaRecorder(stream)
    recorderChunks = []
    recorder.ondataavailable = (e) => recorderChunks.push(e.data)
    recorder.onstop = async () => {
      stream.getTracks().forEach((t) => t.stop())
      const blob = new Blob(recorderChunks, { type: 'audio/webm' })
      recorder = null
      if (blob.size < 1000) return toast('录音太短')
      try {
        const url = await uploadMedia(await blob.arrayBuffer(), 'voice.webm', 'audio/webm')
        const r = await sendMessageRest(conv.id, '', 'audio', url)
        if (r.blocked) toast('内容违规')
        const list = (await loadMessages(conv.id)).messages
        App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
        renderMessages(conv)
      } catch (err) { toast('语音发送失败：' + err.message) }
    }
    recorder.start()
    indicator.classList.remove('hidden')
  } catch (e) {
    toast('无法使用麦克风：' + e.message)
  }
}

/* ---------- 拍照（摄像头 + 发送前确认） ---------- */
async function startCamera(conv) {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    const mask = document.createElement('div')
    mask.className = 'camera-preview'
    mask.innerHTML = `
      <video autoplay playsinline></video>
      <div class="camera-actions">
        <button class="btn btn-outline" id="cam-close">取消</button>
        <button class="btn btn-primary" id="cam-capture">📸 拍照</button>
      </div>`
    document.body.appendChild(mask)
    const video = mask.querySelector('video')
    video.srcObject = stream
    mask.querySelector('#cam-close').addEventListener('click', () => { stream.getTracks().forEach((t) => t.stop()); mask.remove() })
    mask.querySelector('#cam-capture').addEventListener('click', () => {
      const canvas = document.createElement('canvas')
      canvas.width = video.videoWidth; canvas.height = video.videoHeight
      canvas.getContext('2d').drawImage(video, 0, 0)
      stream.getTracks().forEach((t) => t.stop())
      // 发送前确认
      mask.innerHTML = `
        <img src="${canvas.toDataURL('image/jpeg', 0.9)}">
        <div class="camera-actions">
          <button class="btn btn-outline" id="cam-retake">重拍</button>
          <button class="btn btn-primary" id="cam-send">发送</button>
          <button class="btn btn-danger" id="cam-cancel">取消</button>
        </div>`
      mask.querySelector('#cam-retake').addEventListener('click', () => { mask.remove(); startCamera(conv) })
      mask.querySelector('#cam-cancel').addEventListener('click', () => mask.remove())
      mask.querySelector('#cam-send').addEventListener('click', async () => {
        mask.remove()
        try {
          const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.7))
          const url = await uploadMedia(await blob.arrayBuffer(), 'photo.jpg', 'image/jpeg')
          const r = await sendMessageRest(conv.id, '', 'image', url)
          if (r.blocked) toast('内容违规')
          const list = (await loadMessages(conv.id)).messages
          App.state.messages[conv.id] = list.map((m) => normalizeMessage(m, m.senderIsMe))
          renderMessages(conv)
        } catch (err) { toast('照片发送失败：' + err.message) }
      })
    })
  } catch (e) {
    toast('无法使用摄像头：' + e.message)
  }
}

/* ---------- 我的视图 ---------- */
function renderMine() {
  const u = App.state.user
  const v = document.getElementById('view')
  v.innerHTML = `
    <div class="two-col">
      <div>
        <div class="card">
          <div class="profile-head">
            ${avatarHtml(u, 'avatar avatar-lg')}
            <div class="profile-info">
              <div class="row"><span class="profile-name">${esc(u.userName)}</span>
                ${u.isExposureVip ? '<span class="tag tag-vip">👑 曝光</span>' : ''}
              </div>
              <div class="profile-bio">${esc(u.bio)}</div>
              <div class="row">
                <span class="tag tag-credit">🛡 信用 ${Math.round(u.creditScore)}</span>
                ${u.verification !== 'none' ? `<span class="tag tag-verified">✓ ${esc(u.verification)}</span>` : ''}
                <span class="card-sub">📍 ${esc(u.locationLabel)}</span>
              </div>
            </div>
            <div class="credit-ring"><span class="num">${Math.round(u.creditScore)}</span><span class="label">信用分</span></div>
          </div>
          <div class="row" style="margin-top:12px">
            <button class="btn btn-outline btn-sm" id="change-avatar">🖼 更换头像</button>
            <button class="btn btn-outline btn-sm" id="verify-student">🎓 学生认证</button>
            <button class="btn btn-outline btn-sm" id="verify-realname">🪪 实名认证</button>
            <button class="btn btn-outline btn-sm" id="exposure-btn">👑 曝光服务</button>
            <button class="btn btn-outline btn-sm" id="edit-skills">✏️ 技能档案</button>
            <input type="file" id="avatar-file" accept="image/*" hidden>
          </div>
        </div>

        <div class="card">
          <div class="card-title">我擅长（用于教学他人）</div>
          <div class="skill-grid">${skillTags(u.mySkills)}</div>
          <div class="card-title" style="margin-top:14px">我想学（用于匹配）</div>
          <div class="skill-grid">${skillTags(u.wantSkills)}</div>
        </div>

        <div class="card">
          <div class="row">
            <div style="flex:1">
              <div class="card-title" style="margin-bottom:2px">聊天记录同步</div>
              <div class="card-sub">不同设备登录同一账号可同步历史聊天</div>
            </div>
            <input type="checkbox" id="sync-toggle" ${App.state.syncHistory ? 'checked' : ''} style="width:18px;height:18px">
          </div>
        </div>
      </div>

      <div>
        <div class="card">
          <div class="card-title">我的互换</div>
          <div id="mine-records"></div>
        </div>

        <div class="card">
          <div class="card-title">工具</div>
          <div class="tool-row" id="tool-mydynamics"><span class="tool-icon">📝</span>我的动态（历史）</div>
          <div class="tool-row" id="tool-protocol"><span class="tool-icon">📄</span>官方互换协议</div>
          <div class="tool-row" id="tool-rules"><span class="tool-icon">🛡</span>风控规则（零金钱交易）</div>
          <div class="tool-row" id="tool-about"><span class="tool-icon">ℹ️</span>关于技遇</div>
          <div class="tool-row" id="tool-logout"><span class="tool-icon">⇄</span>切换账号 / 退出登录</div>
        </div>
      </div>
    </div>`

  v.querySelector('#verify-student').addEventListener('click', () => doVerify('student'))
  v.querySelector('#verify-realname').addEventListener('click', () => doVerify('realname'))
  v.querySelector('#exposure-btn').addEventListener('click', showExposure)
  v.querySelector('#edit-skills').addEventListener('click', showSkillEditor)
  v.querySelector('#change-avatar').addEventListener('click', () => avatarFile.click())
  v.querySelector('#avatar-file').addEventListener('change', async (e) => {
    const file = e.target.files[0]
    if (!file) return
    try {
      const blob = await compressImage(file)
      const url = await uploadMedia(await blob.arrayBuffer(), 'avatar.jpg', 'image/jpeg')
      await updateProfile({ avatarUrl: url })
      toast('✅ 头像已更新')
      renderMine()
    } catch (err) { toast('头像上传失败：' + err.message) }
    e.target.value = ''
  })
  v.querySelector('#tool-mydynamics').addEventListener('click', showMyDynamics)
  v.querySelector('#sync-toggle').addEventListener('change', (e) => {
    App.state.syncHistory = e.target.checked
    localStorage.setItem('jiyu.syncHistory', App.state.syncHistory ? '1' : '0')
    toast(App.state.syncHistory ? '已开启聊天记录同步' : '已关闭聊天记录同步（仅显示新消息）')
  })
  v.querySelector('#tool-protocol').addEventListener('click', () => showStaticText('官方互换协议', agreementText()))
  v.querySelector('#tool-rules').addEventListener('click', () => showStaticText('风控规则', rulesText()))
  v.querySelector('#tool-about').addEventListener('click', () => showStaticText('关于技遇', '技遇 —— 纯公益、无金钱交易的技能互换平台。以技能换技能，零成本提升自我。'))
  v.querySelector('#tool-logout').addEventListener('click', () => {
    if (confirm('退出当前账号？退出后可在登录页一键切换其他账号')) {
      logout()
      switchView('login')
    }
  })

  const records = document.getElementById('mine-records')
  if (!App.state.records.length) {
    records.innerHTML = '<div class="card-sub">暂无互换记录，去「技能匹配」发起第一次互换吧</div>'
  } else {
    records.innerHTML = App.state.records.map((r) => `
      <div class="list" style="margin-bottom:10px">
        <li>
          <div class="row">
            <div style="flex:1">
              <div class="convo-name">${esc(r.mySkillName)} ⇄ ${esc(r.learnSkillName)} <span class="card-sub">· ${esc(r.partner.userName)}</span></div>
              <div class="card-sub">🕐 ${esc(r.scheduledTime)}${r.location ? ' · 📍 ' + esc(r.location) : ' · 💻 线上'}</div>
            </div>
            <span class="exchange-status ${r.status}">${statusText(r.status)}</span>
          </div>
          <div class="row" style="margin-top:6px">
            <span class="spacer"></span>
            ${r.status === 'completed'
              ? (r.evaluateGiven
                  ? '<span class="tag tag-verified">✓ 已评价</span>'
                  : `<button class="btn btn-primary btn-sm" data-eval="${r.id}">去评价</button>`)
              : `<button class="btn btn-outline btn-sm" data-complete="${r.id}">标记完成</button>`}
          </div>
        </li>
      </div>`).join('')
    records.querySelectorAll('[data-complete]').forEach((b) => b.addEventListener('click', async () => {
      await completeExchange(b.dataset.complete)
      renderMine()
    }))
    records.querySelectorAll('[data-eval]').forEach((b) => b.addEventListener('click', () => {
      const rec = App.state.records.find((r) => r.id === b.dataset.eval)
      if (rec) showEvaluate(rec)
    }))
  }
}

function statusText(s) {
  return { pending: '待开始', ongoing: '进行中', completed: '已完成', cancelled: '已取消' }[s] || s
}

async function doVerify(kind) {
  try {
    await setVerification(kind)
    toast('✅ 已通过' + (kind === 'student' ? '学生认证' : '实名认证') + '（模拟）')
    renderMine()
  } catch (e) { toast(e.message) }
}

/* 技能编辑 */
function showSkillEditor() {
  const u = App.state.user
  openModal(`
    <div class="modal-title">技能档案</div>
    <div class="card-sub" style="margin-bottom:6px">我擅长</div>
    <div id="se-teach" class="skill-grid" style="margin-bottom:12px">${skillTags(u.mySkills)}</div>
    <div class="card-sub" style="margin-bottom:6px">我想学</div>
    <div id="se-want" class="skill-grid" style="margin-bottom:14px">${skillTags(u.wantSkills)}</div>
    <div class="form-row">
      <div class="form-field"><label>技能名称</label><input id="se-name" placeholder="如：吉他"></div>
      <div class="form-field"><label>熟练度</label>
        <select id="se-level"><option value="beginner">入门</option><option value="skilled">熟练</option><option value="master">精通</option></select>
      </div>
      <div class="form-field"><label>交换方式</label>
        <select id="se-type"><option value="both">线上+线下</option><option value="online">线上</option><option value="offline">线下</option></select>
      </div>
    </div>
    <div class="form-field"><label>可教学时间</label><input id="se-time" placeholder="如：周末全天"></div>
    <div class="modal-actions">
      <button class="btn btn-outline" id="se-add-teach">＋ 加入「我擅长」</button>
      <button class="btn btn-primary" id="se-add-want">＋ 加入「我想学」</button>
    </div>
  `, (box) => {
    const read = () => ({
      skillName: box.querySelector('#se-name').value.trim(),
      skillLevel: box.querySelector('#se-level').value,
      exchangeType: box.querySelector('#se-type').value,
      availableTime: box.querySelector('#se-time').value.trim() || '待协商'
    })
    const add = async (kind) => {
      const skill = read()
      if (!skill.skillName) return toast('请输入技能名称')
      try {
        await addSkill(kind, skill)
        closeModal(); renderMine()
      } catch (e) { toast(e.message) }
    }
    box.querySelector('#se-add-teach').addEventListener('click', () => add('teach'))
    box.querySelector('#se-add-want').addEventListener('click', () => add('want'))
  })
}

/* 曝光服务 */
function showExposure() {
  const pkg = [
    { id: 'day', name: '日卡', days: 1, price: 3, desc: '24 小时主页置顶 + 匹配加权' },
    { id: 'week', name: '周卡', days: 7, price: 12, desc: '7 天置顶 + 精准人群推送' },
    { id: 'month', name: '月卡', days: 30, price: 30, desc: '30 天置顶 + 优先匹配优质用户' }
  ]
  openModal(`
    <div class="modal-title">👑 技能曝光 · 增值服务</div>
    <div class="card-sub" style="margin-bottom:12px">仅用于主页置顶与匹配加权，不参与技能交易（演示版本模拟开通，不产生真实扣费）</div>
    ${pkg.map((p) => `
      <div class="card" style="display:flex;align-items:center;gap:12px">
        <div style="flex:1">
          <div class="convo-name">${p.name} <span class="card-sub">${p.days} 天</span></div>
          <div class="card-sub">${p.desc}</div>
        </div>
        <button class="btn btn-primary btn-sm" data-pkg="${p.id}">开通（模拟）</button>
      </div>`).join('')}
    ${App.state.user.isExposureVip ? '<div style="text-align:center;margin-top:10px"><button class="btn btn-danger btn-sm" id="exp-cancel">取消曝光</button></div>' : ''}
  `, (box) => {
    box.querySelectorAll('[data-pkg]').forEach((b) => b.addEventListener('click', async () => {
      try {
        await applyExposure(b.dataset.pkg)
        closeModal(); toast('✅ 曝光已生效（模拟）'); renderMine()
      } catch (e) { toast(e.message) }
    }))
    const c = box.querySelector('#exp-cancel')
    if (c) c.addEventListener('click', async () => {
      await cancelExposure(); closeModal(); renderMine()
    })
  })
}

/* 评价 */
function showEvaluate(rec) {
  let stars = { punctuality: 5, serious: 5, communication: 5 }
  openModal(`
    <div class="modal-title">双向互评 · ${esc(rec.partner.userName)}</div>
    <div class="card-sub" style="margin-bottom:10px">${esc(rec.mySkillName)} ⇄ ${esc(rec.learnSkillName)} · ${esc(rec.scheduledTime)}</div>
    ${starRow('serious', '教学认真度')}
    ${starRow('punctuality', '守时度')}
    ${starRow('communication', '沟通体验')}
    <div class="form-field"><label>评价留言</label><textarea id="ev-comment" placeholder="说说本次互换体验（可选）"></textarea></div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" id="ev-submit">提交评价</button>
    </div>
  `, (box) => {
    box.querySelectorAll('.star').forEach((s) => s.addEventListener('click', () => {
      const key = s.dataset.star
      const val = Number(s.dataset.val)
      stars[key] = val
      box.querySelectorAll(`[data-star="${key}"]`).forEach((el) => el.classList.toggle('on', Number(el.dataset.val) <= val))
    }))
    box.querySelector('#ev-submit').addEventListener('click', async () => {
      try {
        await submitEvaluation(rec.id, {
          punctuality: stars.punctuality, serious: stars.serious,
          communication: stars.communication,
          comment: box.querySelector('#ev-comment').value.trim()
        })
        closeModal(); toast('✅ 评价已提交，信用分已更新'); renderMine()
      } catch (e) { toast(e.message) }
    })
  })
}
function starRow(key, label) {
  return `<div class="row" style="margin:8px 0"><span class="card-sub" style="width:90px">${label}</span>
    ${[1, 2, 3, 4, 5].map((n) => `<span class="star on" data-star="${key}" data-val="${n}">★</span>`).join('')}
    <span class="spacer"></span></div>`
}

/* 静态文本 */
function showStaticText(title, text) {
  openModal(`<div class="modal-title">${title}</div><div class="card-sub" style="line-height:1.9;white-space:pre-wrap">${esc(text)}</div>
    <div class="modal-actions"><button class="btn btn-primary" onclick="closeModal()">关闭</button></div>`)
}
function agreementText() {
  return '【技遇平台官方技能互换协议】\n1. 本次技能互换为纯个人兴趣无偿交换，双方确认无任何金钱、物资、有偿交易行为。\n2. 双方自愿交换技能教学资源，约定教学时长、教学时间、线上/线下方式。\n3. 双方承诺认真教学、守时履约，杜绝敷衍教学、无故爽约。\n4. 线下交换请选择公共场所，注意人身与财产安全，平台仅提供信息匹配服务。\n5. 若任意一方出现交易违规、爽约、敷衍行为，平台有权扣分、限流、封禁账号。\n6. 本协议为平台约束性规则，双方确认签署即认可全部条款。'
}
function rulesText() {
  return '技遇零金钱交易风控规则\n1. 平台全程禁止任何金钱、物资、有偿交易。\n2. 文本/图片内容自动风控拦截，违禁词命中即拦截。\n3. 平台人工巡检私聊与动态区。\n4. 违规处罚：首次警告 → 二次限流 → 三次永久封禁。\n5. 敷衍教学、爽约、诱导交易可投诉，人工审核并扣减信用分。'
}

/* 我的动态历史（个人发布的全部动态） */
function showMyDynamics() {
  const mine = App.state.dynamics.filter((d) => String(d.userId) === String(App.state.user.id))
  openModal(`
    <div class="modal-title">我的动态（${mine.length}）</div>
    ${mine.length
      ? mine.map((d) => `
        <div class="card" style="margin-bottom:8px">
          <div class="row">
            <span class="feed-time" style="margin-left:0">${fmtTime(d.time)}</span>
            <span class="spacer"></span>
            <button class="btn btn-danger btn-sm" data-del="${d.id}" title="删除这条动态">删除</button>
          </div>
          <div class="feed-content" style="margin-top:6px">${esc(d.content)}</div>
          ${d.imageBase64 ? `<img class="feed-image" src="data:image/jpeg;base64,${d.imageBase64}" onclick="openFullscreen('<img src=&quot;data:image/jpeg;base64,${d.imageBase64}&quot;>')">` : ''}
        </div>`).join('')
      : '<div class="empty"><div class="empty-icon">📝</div>你还没有发布过动态<br>去「互换动态」发布第一条吧</div>'}
  `, (box) => {
    box.querySelectorAll('[data-del]').forEach((b) => b.addEventListener('click', async () => {
      if (!confirm('删除这条动态？')) return
      try {
        await api('/api/dynamics/delete', { method: 'POST', body: { id: b.dataset.del } })
        App.state.dynamics = App.state.dynamics.filter((d) => String(d.id) !== b.dataset.del)
        toast('已删除')
        closeModal()
        showMyDynamics()
      } catch (e) { toast('删除失败：' + e.message) }
    }))
  })
}

/* 新消息应用内弹窗（右下角，点击跳转会话） */
function showNewMessagePopup(msg, conv) {
  // 避免同一会话连续弹窗堆叠
  const existing = document.querySelector(`.notify-popup[data-cid="${conv.id}"]`)
  if (existing) existing.remove()
  const box = document.createElement('div')
  box.className = 'notify-popup'
  box.dataset.cid = conv.id
  box.innerHTML = `
    ${avatarHtml(conv.partner, 'avatar avatar-sm')}
    <div style="flex:1;min-width:0">
      <div class="convo-name">${esc(conv.partner.userName)}</div>
      <div class="convo-last">${esc(msg.text || (msg.mediaType === 'video' ? '[视频]' : msg.mediaType === 'audio' ? '[语音]' : '[图片]'))}</div>
    </div>
    <span class="unread-dot" style="align-self:center">新</span>`
  box.addEventListener('click', () => {
    box.remove()
    switchView('message')
    showChat(conv)
  })
  document.body.appendChild(box)
  setTimeout(() => box.remove(), 6000)
}

/* ============================================================
 * 宠物护理域（旧巡六迁移：宠物档案 + 服务目录 + 互换预约）
 * ============================================================ */
let careOptions = { dogBehaviors: [], catBehaviors: [], homeReactions: [], weightOptions: [] }

async function renderPet() {
  const v = document.getElementById('view')
  v.innerHTML = `
    <div class="row" style="margin-bottom:12px">
      <span class="section-title" style="margin:0;flex:1">🐾 宠物护理（互换语义 · 零金钱）</span>
      <button class="btn btn-primary btn-sm" id="pet-add">＋ 添加宠物</button>
    </div>
    <div class="card">
      <div class="card-title">我的宠物</div>
      <div id="pet-list" class="skill-grid"></div>
    </div>
    <div class="card">
      <div class="card-title">护理服务目录 <span class="card-sub">以技能互换换取看护</span></div>
      <div class="filter-bar" style="margin-bottom:10px">
        <button class="chip active" data-cat="">全部</button>
        <button class="chip" data-cat="overnight">过夜</button>
        <button class="chip" data-cat="day">当日</button>
        <button class="chip" data-cat="other">其他</button>
      </div>
      <div id="service-list"></div>
    </div>
    <div class="card">
      <div class="card-title">我的预约</div>
      <div id="booking-list"></div>
    </div>`
  v.querySelector('#pet-add').addEventListener('click', showPetAdd)
  v.querySelectorAll('.chip').forEach((c) => c.addEventListener('click', () => {
    v.querySelectorAll('.chip').forEach((x) => x.classList.remove('active'))
    c.classList.add('active')
    renderServices(c.dataset.cat)
  }))

  await Promise.all([
    fetchCareServices().then((r) => { careOptions = r.options; renderServices('') }),
    fetchPets().then(renderPets),
    fetchBookings().then(renderBookings)
  ])
}

function renderPets() {
  const el = document.getElementById('pet-list')
  if (!App.state.pets.length) {
    el.innerHTML = '<span class="card-sub">还没有宠物档案，点击右上角「添加宠物」创建</span>'
    return
  }
  el.innerHTML = App.state.pets.map((p) => `
    <div class="card" style="width:200px;margin:0">
      <div class="row">
        ${p.photoUrl ? `<img class="avatar avatar-img" src="${mediaUrl(p.photoUrl)}">` : `<div class="avatar">${p.petType === 'dog' ? '🐕' : p.petType === 'cat' ? '🐈' : '🐾'}</div>`}
        <div style="flex:1;min-width:0">
          <div class="convo-name">${esc(p.name)}</div>
          <div class="card-sub">${esc(p.petType === 'dog' ? '🐕 狗' : p.petType === 'cat' ? '🐈 猫' : '🐾 其他')} · ${esc(p.breed)} · ${p.ageMonths} 月${p.weightKg ? ' · ' + p.weightKg + 'kg' : ''}</div>
          <div class="card-sub">${p.neutered ? '已绝育' : '未绝育'} · ${p.gender === 'male' ? '公' : '母'}</div>
        </div>
        <button class="btn btn-danger btn-sm" data-delpet="${p.id}" title="删除">✕</button>
      </div>
      ${p.behaviors && p.behaviors.length ? '<div style="margin-top:8px">' + p.behaviors.map((b) => `<span class="tag tag-skilled">${esc(b)}</span>`).join(' ') + '</div>' : ''}
      ${p.notes ? `<div class="card-sub" style="margin-top:6px">📝 ${esc(p.notes)}</div>` : ''}
    </div>`).join('')
  el.querySelectorAll('[data-delpet]').forEach((b) => b.addEventListener('click', async () => {
    if (!confirm('删除宠物 ' + App.state.pets.find((p) => p.id === b.dataset.delpet)?.name + '？')) return
    try { await deletePet(b.dataset.delpet); renderPets() } catch (e) { toast(e.message) }
  }))
}

function renderServices(category) {
  const el = document.getElementById('service-list')
  if (!el) return
  const services = App.state.careServices || []
  const list = category ? services.filter((s) => s.category === category) : services
  el.innerHTML = list.length ? list.map((s) => `
    <div class="card" style="display:flex;align-items:center;gap:12px;margin-bottom:8px">
      <div style="flex:1">
        <div class="convo-name">${esc(s.name)} <span class="tag tag-verified">${esc(catName(s.category))}</span></div>
        <div class="card-sub">${esc(s.desc)} · ${esc(s.duration)}</div>
      </div>
      <div style="text-align:center">
        <div style="font-weight:700;color:#d97b2e">¥${s.priceYuan}</div>
        <div class="card-sub" style="font-size:10px">平台佣金 10%</div>
      </div>
      <button class="btn btn-primary btn-sm" data-service='${JSON.stringify(s)}'>发起订单</button>
    </div>`).join('')
    : '<div class="card-sub">该分类暂无服务</div>'
  el.querySelectorAll('[data-service]').forEach((b) => b.addEventListener('click', () => {
    showBookingForm(JSON.parse(b.dataset.service))
  }))
}
function catName(c) { return { overnight: '过夜', day: '当日', other: '其他' }[c] || c }

/* 添加宠物（F-21~F-24：结构化档案 + 校验） */
function showPetAdd() {
  openModal(`
    <div class="modal-title">添加宠物</div>
    <div class="form-row">
      <div class="form-field"><label>宠物名称 *</label><input id="p-name" placeholder="如：豆豆"></div>
      <div class="form-field"><label>类型 *</label>
        <select id="p-type"><option value="dog">🐕 狗</option><option value="cat">🐈 猫</option><option value="other">🐾 其他</option></select>
      </div>
      <div class="form-field"><label>品种 *</label><input id="p-breed" placeholder="如：柯基"></div>
    </div>
    <div class="form-row">
      <div class="form-field"><label>年龄（月，0-180）*</label><input id="p-age" type="number" min="0" max="180" placeholder="如：24"></div>
      <div class="form-field"><label>性别 *</label>
        <select id="p-gender"><option value="male">公</option><option value="female">母</option></select>
      </div>
      <div class="form-field"><label>绝育 *</label>
        <select id="p-neutered"><option value="1">已绝育</option><option value="0">未绝育</option></select>
      </div>
      <div class="form-field"><label>体重 kg（猫必填）</label><input id="p-weight" type="number" step="0.1" placeholder="如：5.5"></div>
    </div>
    <div class="form-field"><label>行为特点</label><div id="p-behaviors" class="skill-grid"></div></div>
    <div class="form-field"><label>家中反应</label><div id="p-reactions" class="skill-grid"></div></div>
    <div class="form-row">
      <div class="form-field"><label>照片</label><input type="file" id="p-photo" accept="image/*"></div>
      <div class="form-field"><label>备注（≤2000 字）</label><input id="p-notes" placeholder="如：喜欢玩球，怕打雷"></div>
    </div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" id="p-save">保存宠物</button>
    </div>
  `, (box) => {
    const renderBehavior = () => {
      const type = box.querySelector('#p-type').value
      const opts = type === 'dog' ? careOptions.dogBehaviors : type === 'cat' ? careOptions.catBehaviors : careOptions.dogBehaviors
      box.querySelector('#p-behaviors').innerHTML = opts.map((b) =>
        `<span class="chip" data-b="${esc(b)}">${esc(b)}</span>`).join('')
      box.querySelector('#p-reactions').innerHTML = careOptions.homeReactions.map((b) =>
        `<span class="chip" data-r="${esc(b)}">${esc(b)}</span>`).join('')
      box.querySelectorAll('.chip').forEach((c) => c.addEventListener('click', () => c.classList.toggle('active')))
    }
    renderBehavior()
    box.querySelector('#p-type').addEventListener('change', renderBehavior)

    let photoUrl = null
    box.querySelector('#p-photo').addEventListener('change', async (e) => {
      const file = e.target.files[0]
      if (!file) return
      try {
        const blob = await compressImage(file)
        photoUrl = await uploadMedia(await blob.arrayBuffer(), 'pet.jpg', 'image/jpeg')
        toast('✓ 照片已上传')
      } catch (err) { toast(err.message) }
    })

    box.querySelector('#p-save').addEventListener('click', async () => {
      const body = {
        name: box.querySelector('#p-name').value.trim(),
        petType: box.querySelector('#p-type').value,
        breed: box.querySelector('#p-breed').value.trim(),
        ageMonths: Number(box.querySelector('#p-age').value),
        gender: box.querySelector('#p-gender').value,
        neutered: box.querySelector('#p-neutered').value === '1',
        weightKg: box.querySelector('#p-weight').value ? Number(box.querySelector('#p-weight').value) : undefined,
        behaviors: [...box.querySelectorAll('#p-behaviors .chip.active')].map((c) => c.dataset.b),
        homeReactions: [...box.querySelectorAll('#p-reactions .chip.active')].map((c) => c.dataset.r),
        photoUrl,
        notes: box.querySelector('#p-notes').value.trim()
      }
      try {
        await addPet(body)
        closeModal()
        toast('✅ 宠物档案已创建')
        renderPets()
      } catch (e) { toast('保存失败：' + e.message) }
    })
  })
}

/* 发起看护订单（两种模式：指定认识的看护人 / 发布到动态让有资历的人接单） */
function showBookingForm(service) {
  const pets = App.state.pets
  if (!pets.length) return toast('请先添加宠物档案')
  const providers = App.state.users.filter((u) => u.id !== App.state.user.id)
  openModal(`
    <div class="modal-title">发起订单 · ${esc(service.name)}</div>
    <div class="card-sub" style="margin-bottom:12px">服务价 <b style="color:#d97b2e">¥${service.priceYuan}</b> · 平台佣金 10% · 其余归服务人员</div>
    <div class="form-field"><label>宠物 *</label>
      <select id="b-pet">${pets.map((p) => `<option value="${p.id}">${esc(p.name)}（${esc(p.breed)}）</option>`).join('')}</select>
    </div>
    <div class="form-field"><label>接单方式 *</label>
      <select id="b-mode">
        <option value="direct">指定认识的看护人</option>
        <option value="feed">发布到互换动态，让有资历的人接单</option>
      </select>
    </div>
    <div class="form-field" id="b-provider-wrap"><label>看护人 *（信用分供参考）</label>
      <select id="b-provider">${providers.map((u) => `<option value="${u.id}">${esc(u.userName)}（信用 ${Math.round(u.creditScore)} · ${esc(u.locationLabel)}）</option>`).join('')}</select>
    </div>
    <div class="form-row">
      <div class="form-field"><label>约定时间 *</label><input id="b-time" placeholder="如：本周六 18:00"></div>
      <div class="form-field"><label>地点 *（公共场所）</label><input id="b-location" placeholder="如：小区门口/图书馆旁"></div>
    </div>
    <div class="card-sub" style="color:#f29e4d">⚠️ 宠物服务可收费，价格与佣金以订单为准；其他技能互换仍坚持零金钱</div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" id="b-submit">发布订单</button>
    </div>
  `, (box) => {
    const modeWrap = box.querySelector('#b-provider-wrap')
    box.querySelector('#b-mode').addEventListener('change', (e) => {
      modeWrap.style.display = e.target.value === 'direct' ? '' : 'none'
    })
    box.querySelector('#b-submit').addEventListener('click', async () => {
      const scheduledTime = box.querySelector('#b-time').value.trim()
      const location = box.querySelector('#b-location').value.trim()
      const mode = box.querySelector('#b-mode').value
      if (!scheduledTime || !location) return toast('请填写时间与地点（公共场所）')
      const body = {
        petId: box.querySelector('#b-pet').value,
        serviceId: service.id,
        scheduledTime,
        location
      }
      if (mode === 'direct') {
        body.providerId = box.querySelector('#b-provider').value
      } else {
        body.openToFeed = true
      }
      try {
        await createBooking(body)
        closeModal()
        toast(mode === 'direct' ? '✅ 订单已发给看护人' : '✅ 订单已发布到动态区，等待有资历的人接单')
        renderBookings()
        if (mode === 'feed') renderFeed()
      } catch (e) { toast('发布失败：' + e.message) }
    })
  })
}

function renderBookings() {
  const el = document.getElementById('booking-list')
  if (!el) return
  if (!App.state.bookings.length) {
    el.innerHTML = '<div class="card-sub">暂无订单，从服务目录发起第一笔订单吧</div>'
    return
  }
  el.innerHTML = App.state.bookings.map((b) => {
    const isMine = String(b.userId) === String(App.state.user.id)
    return `
    <div class="card" style="margin-bottom:8px">
      <div class="row">
        <div style="flex:1">
          <div class="convo-name">${esc(b.serviceName)} <span class="tag tag-verified">${esc(b.pet ? b.pet.name : '')}</span></div>
          <div class="card-sub">🕐 ${esc(b.scheduledTime)} · 📍 ${esc(b.location)}</div>
          <div class="card-sub">${isMine ? '看护人：' + esc(b.provider ? b.provider.userName : '待接单…') : '下单人：' + esc(b.initiator ? b.initiator.userName : '—')}</div>
          ${b.priceYuan != null ? `<div class="card-sub">💰 服务费 <b style="color:#d97b2e">¥${b.priceYuan}</b> · 平台佣金 ¥${b.commissionYuan} · 服务人员所得 ¥${b.workerIncome}</div>` : ''}
        </div>
        <span class="exchange-status ${b.status}">${orderStatusText(b.status)}</span>
      </div>
      ${(b.status === 'assigned' || b.status === 'ongoing') && (isMine || String(b.providerId) === String(App.state.user.id))
        ? `<div class="row" style="margin-top:8px"><span class="spacer"></span><button class="btn btn-outline btn-sm" data-done="${b.id}">标记完成</button></div>`
        : ''}
    </div>`
  }).join('')
  el.querySelectorAll('[data-done]').forEach((b) => b.addEventListener('click', async () => {
    await completeBooking(b.dataset.done)
    renderBookings()
  }))
}
function orderStatusText(s) {
  return { open: '待接单', assigned: '已接单', ongoing: '服务中', completed: '已完成', cancelled: '已取消' }[s] || s
}

/* 注册视图入口（供 app.js 调用） */
App.views = {
  renderMatch, renderFeed, renderMessage, renderMine, renderPet, renderLogin,
  onMessage: (cid) => { if (App.state.activeConversation === cid) renderMessages(App.state.conversations.find((c) => c.id === cid)) },
  onConversationUpdate: () => renderConvoList(),
  onNewMessage: showNewMessagePopup,
  onDataChanged: () => { if (App.state.views.current === 'feed') renderFeed() }
}
App.views.current = 'match'
