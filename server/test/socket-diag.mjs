// Socket 连接最小诊断
import { io } from 'socket.io-client'

const BASE = 'http://localhost:3000'

// 登录两个账号
const login = async (username) => {
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password: '123456' })
  })
  return (await res.json()).token
}

const token1 = await login('aqing')
const token2 = await login('linxiao')
console.log('tokens ok:', !!token1, !!token2)

const s1 = io(BASE, { auth: { token: token1 } })
const s2 = io(BASE, { auth: { token: token2 } })

let done = 0
const mark = (name) => () => { console.log('EVENT:', name); if (++done === 4) process.exit(0) }
s1.on('connect', mark('s1 connect'))
s1.on('connect_error', (e) => console.log('s1 connect_error:', e.message))
s2.on('connect', mark('s2 connect'))
s2.on('connect_error', (e) => console.log('s2 connect_error:', e.message))

setTimeout(() => { console.log('TIMEOUT — s1.connected =', s1.connected, ', s2.connected =', s2.connected); process.exit(1) }, 8000)
