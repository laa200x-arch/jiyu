/**
 * 发布 Windows 安装包到 GitHub Releases
 * 用法：node tools/release-win.mjs --tag win-v1.1.0 --name "技遇 Windows v1.1.0" --exe "win-app/dist/技遇 Setup 1.0.0.exe" --body "更新内容…"
 * token 来源：环境变量 GH_TOKEN，或自动从 git credential manager 读取
 */
import { spawnSync } from 'node:child_process'
import { readFileSync, existsSync } from 'node:fs'
import { resolve, dirname } from 'node:path'

const REPO = 'laa200x-arch/jiyu'
const args = process.argv.slice(2)
const opt = (key, def = '') => {
  const i = args.indexOf('--' + key)
  return i >= 0 && args[i + 1] ? args[i + 1] : def
}

const tag = opt('tag')
const name = opt('name', tag)
const exePath = resolve(opt('exe'))
const body = opt('body', '技遇 Windows 桌面版更新')

if (!tag) { console.error('缺少 --tag 参数'); process.exit(1) }
if (!existsSync(exePath)) { console.error('安装包不存在:', exePath); process.exit(1) }

// 获取 token
let token = process.env.GH_TOKEN || ''
if (!token) {
  const r = spawnSync('git', ['credential', 'fill'], { input: 'protocol=https\nhost=github.com\n\n', encoding: 'utf8' })
  const m = (r.stdout || '').match(/^password=(.+)$/m)
  token = m ? m[1] : ''
}
if (!token) { console.error('无法获取 GitHub token（设置 GH_TOKEN 或配置 git 凭据）'); process.exit(1) }

const H = { Authorization: 'Bearer ' + token, 'User-Agent': 'jiyu-release', Accept: 'application/vnd.github+json' }

async function main() {
  // 1) 创建/更新 Release
  let release
  const existing = await fetch(`https://api.github.com/repos/${REPO}/releases/tags/${encodeURIComponent(tag)}`, { headers: H })
  if (existing.ok) {
    release = await existing.json()
    console.log('已存在 Release，复用:', release.html_url)
  } else {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases`, {
      method: 'POST',
      headers: { ...H, 'Content-Type': 'application/json' },
      body: JSON.stringify({ tag_name: tag, name, body, draft: false, prerelease: false })
    })
    if (!res.ok) { console.error('创建 Release 失败:', await res.text()); process.exit(1) }
    release = await res.json()
    console.log('已创建 Release:', release.html_url)
  }

  // 2) 上传安装包附件（使用 ASCII 文件名，避免 GitHub 丢弃非 ASCII 字符）
  const uploadBase = release.upload_url.replace('{?name,label}', '')
  const fileName = `Jiyu-Setup-${tag.replace(/^win-/, '')}.exe`
  const up = await fetch(`${uploadBase}?name=${encodeURIComponent(fileName)}`, {
    method: 'POST',
    headers: { ...H, 'Content-Type': 'application/octet-stream' },
    body: readFileSync(exePath)
  })
  if (!up.ok) { console.error('上传附件失败:', await up.text()); process.exit(1) }
  const asset = await up.json()
  console.log('✅ 安装包已上传:', asset.browser_download_url)

  // 3) 上传 latest.yml（electron-updater 自动更新元数据；electron-builder --win nsis 构建时生成在 dist/）
  //    关键：yml 里引用的是构建产物原始文件名（含中文），而 GitHub 附件必须 ASCII 名，
  //    需把 yml 中的文件名改写为上传后的 ASCII 名，否则 electron-updater 按原文件名下载会 404
  const ymlPath = resolve(dirname(exePath), 'latest.yml')
  if (existsSync(ymlPath)) {
    const originalName = exePath.split(/[\\/]/).pop()
    let yml = readFileSync(ymlPath, 'utf8')
    if (originalName !== fileName && yml.includes(originalName)) {
      yml = yml.split(originalName).join(fileName)
      console.log(`latest.yml 文件名改写: ${originalName} → ${fileName}`)
    }
    const upYml = await fetch(`${uploadBase}?name=latest.yml`, {
      method: 'POST',
      headers: { ...H, 'Content-Type': 'text/yaml' },
      body: yml
    })
    if (upYml.ok) console.log('✅ latest.yml 已上传（自动更新元数据）')
    else console.log('⚠️ latest.yml 上传失败（自动更新将回退到应用内版本弹窗）:', await upYml.text())
  } else {
    console.log('⚠️ 未找到 dist/latest.yml，本次 Release 不支持 electron-updater 自动检测（仅应用内弹窗提示）')
  }
  console.log('Release 页面:', release.html_url)
}

main().catch((e) => { console.error(e); process.exit(1) })
