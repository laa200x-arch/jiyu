// 校验 project.pbxproj：括号平衡 / ID 引用完整性 / 磁盘文件一致性
const fs = require('fs')
const path = require('path')

const root = 'D:/AI/exchange'
const pbx = fs.readFileSync(path.join(root, 'Jiyu.xcodeproj', 'project.pbxproj'), 'utf8')
let errors = []

// 1) 括号平衡（去注释与字符串）
const stripped = pbx.replace(/\/\*[\s\S]*?\*\//g, '').replace(/"([^"\\]|\\.)*"/g, '""')
let depth = 0
for (const ch of stripped) {
  if (ch === '{') depth++
  if (ch === '}') depth--
  if (depth < 0) { errors.push('brace depth < 0'); break }
}
if (depth !== 0) errors.push(`brace depth mismatch: ${depth}`)
else console.log('✓ braces balanced')

// 2) ID 引用完整性
const idRe = /^\s*([0-9A-F]{24})\s*(\/\*.*?\*\/)?\s*=\s*\{/gm
const defined = new Set()
let m
while ((m = idRe.exec(pbx)) !== null) defined.add(m[1])
const refRe = /([0-9A-F]{24})\s*(\/\*[^*]*?\*\/)?\s*[,;)]/g
const used = new Set()
while ((m = refRe.exec(pbx)) !== null) used.add(m[1])
const undefinedRefs = [...used].filter((id) => !defined.has(id))
if (undefinedRefs.length) errors.push(`undefined refs: ${undefinedRefs.join(', ')}`)
else console.log(`✓ all ${used.size} referenced IDs defined (${defined.size} unique objects)`)

// 3) 包引用存在
for (const [id, name] of [['A00000000000000000000901', 'packageRef'], ['A00000000000000000000902', 'productDep']]) {
  if (!defined.has(id)) errors.push(`missing ${name}`)
}
console.log('✓ SocketIO package references present')

// 4) 磁盘 Swift 文件与工程引用一致
const jiyuDir = path.join(root, 'Jiyu')
function walk(dir) {
  let out = []
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name)
    if (e.isDirectory()) out = out.concat(walk(full))
    else if (e.name.endsWith('.swift')) out.push(path.relative(jiyuDir, full).replace(/\\/g, '/'))
  }
  return out
}
const disk = walk(jiyuDir)
const missing = disk.filter((f) => !pbx.includes(path.basename(f)))
if (missing.length) errors.push(`disk files missing in pbxproj: ${missing.join(', ')}`)
else console.log(`✓ all ${disk.length} Swift files on disk referenced`)

console.log('---')
if (errors.length) {
  console.log('✗ ERRORS:'); errors.forEach((e) => console.log('  - ' + e)); process.exit(1)
} else {
  console.log('✅ pbxproj validation PASSED')
}
