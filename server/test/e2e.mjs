/**
 * 端到端测试编排（npm test 入口）
 * 本地拉起临时服务器（测试端口 + 临时 sqlite 库 + 限流关闭）→ 依次运行 smoke / security / sms 单测 → 清理
 * 不依赖外部服务器，不触碰线上数据库
 */
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { rmSync } from 'node:fs'

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const PORT = process.env.TEST_PORT || 3199
const BASE = `http://127.0.0.1:${PORT}`
const dbFile = path.join(root, 'data', 'test-e2e.db')
const dbFiles = [dbFile, dbFile + '-shm', dbFile + '-wal']

for (const f of dbFiles) rmSync(f, { force: true })

const server = spawn(process.execPath, ['src/index.js'], {
  cwd: root,
  env: {
    ...process.env,
    PORT: String(PORT),
    DB_DRIVER: 'sqlite',
    SQLITE_PATH: dbFile,
    JWT_SECRET: 'test-secret-e2e-not-for-prod',
    AUTO_SEED: 'true',
    RATE_LIMIT_OFF: '1'
  },
  stdio: ['ignore', 'ignore', 'pipe']
})
server.stderr.on('data', (d) => process.stderr.write('[server] ' + d))

async function waitHealthy() {
  for (let i = 0; i < 50; i++) {
    try {
      const r = await fetch(`${BASE}/api/health`)
      if (r.ok) return true
    } catch { /* 未启动完成，继续等待 */ }
    await new Promise((r) => setTimeout(r, 200))
  }
  return false
}

function runNode(args) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, args, {
      cwd: root,
      env: { ...process.env, BASE_URL: BASE },
      stdio: 'inherit'
    })
    child.on('exit', (code) => resolve(code ?? 1))
  })
}

const healthy = await waitHealthy()
if (!healthy) {
  console.error('❌ 测试服务器启动失败（端口 ' + PORT + '）')
  server.kill()
  process.exit(1)
}

const codes = []
codes.push(await runNode(['test/smoke.mjs']))
codes.push(await runNode(['test/security.mjs']))
codes.push(await runNode(['test/sms.test.mjs']))

server.kill()
// 等 WAL 落盘后清理临时库
setTimeout(() => {
  for (const f of dbFiles) rmSync(f, { force: true })
}, 400)

const failed = codes.filter((c) => c !== 0).length
console.log(failed === 0 ? '\n✅ 全部测试通过' : `\n❌ ${failed} 个测试套件失败`)
process.exit(failed === 0 ? 0 : 1)
