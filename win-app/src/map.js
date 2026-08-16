/* ============================================================
 * 技遇 Windows 版 - 同城地图（Leaflet + OpenStreetMap，无第三方 Key）
 * 区级定位 + 用户真实定位（授权时）
 * ============================================================ */
'use strict'

const DISTRICT_CENTERS = {
  '海淀': [39.9603, 116.2981], '朝阳': [39.9215, 116.4431],
  '西城': [39.9153, 116.3660], '东城': [39.9175, 116.4188],
  '丰台': [39.8584, 116.2870], '通州': [39.9097, 116.6570],
  '昌平': [40.2208, 116.2312], '大兴': [39.7269, 116.3415]
}

function districtCoord(label) {
  const key = Object.keys(DISTRICT_CENTERS).find((k) => label.includes(k))
  if (!key) return null
  const [lat, lng] = DISTRICT_CENTERS[key]
  const hash = Math.abs([...label].reduce((a, c) => a + c.charCodeAt(0), 0))
  return [lat + (hash % 50) / 1000, lng + (Math.floor(hash / 50) % 50) / 1000]
}

async function showMap() {
  const matches = await fetchMatches({})
  const pins = matches.map((m) => ({ u: m.user, coord: districtCoord(m.user.locationLabel) })).filter((p) => p.coord)
  if (!pins.length) return toast('暂无带位置信息的匹配用户')

  openModal(`<div class="modal-title">🗺️ 同城地图（区级示意）</div>
    <div id="map"></div>
    <div style="display:flex;gap:8px;flex-wrap:wrap" id="map-chips"></div>`, async (box) => {
    // 注入 Leaflet（本地包，无需网络）
    if (!document.getElementById('leaflet-css')) {
      const link = document.createElement('link')
      link.id = 'leaflet-css'
      link.rel = 'stylesheet'
      link.href = '../node_modules/leaflet/dist/leaflet.css'
      document.head.appendChild(link)
    }
    const L = require('leaflet')

    const defaultCenter = [39.92, 116.40]
    const map = L.map('map').setView(defaultCenter, 10)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap',
      maxZoom: 18
    }).addTo(map)

    const markers = []
    pins.forEach((p) => {
      const marker = L.marker(p.coord, {
        icon: L.divIcon({
          className: '',
          html: `<div style="width:26px;height:26px;border-radius:50%;background:${p.u.isExposureVip ? '#f29e61' : 'linear-gradient(135deg,#33d1d9,#3f8cd9)'};color:#fff;display:flex;align-items:center;justify-content:center;font-size:12px;box-shadow:0 1px 4px rgba(0,0,0,.3)">${p.u.avatarSymbol || '•'}</div>`
        })
      }).addTo(map)
      marker.bindPopup(`<b>${p.u.userName}</b><br>${p.u.locationLabel}${p.u.distanceKm != null ? '<br>' + p.u.distanceKm.toFixed(1) + 'km' : ''}`)
      markers.push({ p, marker })
    })

    // 用户定位
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition((pos) => {
        const lat = pos.coords.latitude, lng = pos.coords.longitude
        L.marker([lat, lng], {
          icon: L.divIcon({ className: '', html: '<div style="width:26px;height:26px;border-radius:50%;background:#4dbf73;border:3px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.3)"></div>' })
        }).addTo(map).bindPopup('<b>我的位置</b>')
        map.setView([lat, lng], 11)
      }, () => { /* 拒绝定位则保持区级视图 */ })
    }

    box.querySelector('#map-chips').innerHTML = markers.map((m) =>
      `<button class="chip" data-idx="${m.p.u.id}">${esc(m.p.u.userName)}</button>`).join('')
    box.querySelectorAll('#map-chips .chip').forEach((c) => c.addEventListener('click', () => {
      const m = markers.find((x) => x.p.u.id === c.dataset.idx)
      if (m) map.setView(m.coord, 13)
    }))
  })
}
