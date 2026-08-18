/**
 * 演示数据种子（与 iOS 端 MockDataStore 示例数据一致）
 * 运行：npm run seed  或 首次启动时 AUTO_SEED=true 自动填充
 * 所有演示账号密码均为：123456
 */
import bcrypt from 'bcryptjs'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { pathToFileURL } from 'node:url'
import { config } from './config.js'
import { initDb } from './db.js'
import { SQLITE_DDL, MYSQL_DDL } from './schema.js'

const now = () => new Date().toISOString()
const daysAgo = (d) => new Date(Date.now() - d * 86400000).toISOString()

const PASSWORD = '123456'

export const DEMO_USERS = [
  {
    username: 'aqing', nickname: '阿青', avatarSymbol: 'face.smiling',
    bio: '大二学生 · 想用剪辑和摄影换吉他/编程', locationLabel: '海淀 · 中关村',
    distanceKm: null, creditScore: 82, verification: 'full', isExposureVip: false,
    teach: [['视频剪辑', 'master', 'both', '周末全天'], ['摄影', 'skilled', 'both', '周末'], ['英语口语', 'skilled', 'online', '工作日晚上']],
    want: [['吉他', 'beginner', 'online', '工作日晚上'], ['编程', 'beginner', 'both', '周末'], ['日语', 'beginner', 'online', '工作日晚上'], ['摄影', 'beginner', 'both', '周末']]
  },
  {
    username: 'linxiao', nickname: '林晓', avatarSymbol: 'camera.fill',
    bio: '独立摄影爱好者 · 人像/街拍', locationLabel: '朝阳 · 国贸图书馆',
    distanceKm: 3.2, creditScore: 90, verification: 'full', isExposureVip: true,
    teach: [['摄影', 'master', 'both', '周末全天']],
    want: [['视频剪辑', 'beginner', 'online', '周末'], ['手绘', 'beginner', 'offline', '周末']]
  },
  {
    username: 'chenmo', nickname: '陈默', avatarSymbol: 'book.fill',
    bio: '日语 N1 · 动漫爱好者', locationLabel: '朝阳 · 798 文创空间',
    distanceKm: 12.0, creditScore: 78, verification: 'student', isExposureVip: false,
    teach: [['日语', 'skilled', 'online', '工作日晚上']],
    want: [['摄影', 'beginner', 'both', '周末']]
  },
  {
    username: 'suqing', nickname: '苏晴', avatarSymbol: 'paintbrush.fill',
    bio: '插画师 · 手绘达人', locationLabel: '海淀 · 中关村图书大厦',
    distanceKm: 6.5, creditScore: 85, verification: 'realname', isExposureVip: false,
    teach: [['绘画', 'master', 'offline', '周末']],
    want: [['视频剪辑', 'beginner', 'online', '工作日晚上']]
  },
  {
    username: 'wangye', nickname: '王野', avatarSymbol: 'film.fill',
    bio: 'B 站剪辑 UP 主', locationLabel: '西城 · 天桥艺术中心',
    distanceKm: 8.0, creditScore: 88, verification: 'realname', isExposureVip: false,
    teach: [['视频剪辑', 'skilled', 'both', '晚上']],
    want: [['绘画', 'beginner', 'offline', '周末']]
  },
  {
    username: 'zhouke', nickname: '周可', avatarSymbol: 'guitars.fill',
    bio: '乐队吉他手 · 民谣', locationLabel: '海淀 · 五道口',
    distanceKm: 1.5, creditScore: 92, verification: 'full', isExposureVip: false,
    teach: [['吉他', 'master', 'both', '每周三晚']],
    want: [['视频剪辑', 'beginner', 'online', '每周三晚'], ['编程', 'beginner', 'both', '周末']]
  },
  {
    username: 'gaoyuan', nickname: '高远', avatarSymbol: 'camera.aperture',
    bio: '风光摄影 · 旅行', locationLabel: '东城 · 东四共享空间',
    distanceKm: 15.0, creditScore: 75, verification: 'none', isExposureVip: false,
    teach: [['摄影', 'skilled', 'both', '周末']],
    want: [['编程', 'beginner', 'online', '工作日晚上']]
  },
  {
    username: 'hanxue', nickname: '韩雪', avatarSymbol: 'chevron.left.forwardslash.chevron.right',
    bio: '全栈工程师 · 开源贡献者', locationLabel: '海淀 · 西二旗咖啡馆',
    distanceKm: 5.8, creditScore: 76, verification: 'realname', isExposureVip: false,
    teach: [['编程', 'master', 'both', '工作日晚上']],
    want: [['摄影', 'beginner', 'both', '周末']]
  },
  {
    username: 'baiyifan', nickname: '白一凡', avatarSymbol: 'pencil.and.outline',
    bio: '美院学生 · 速写手绘', locationLabel: '海淀 · 清华园',
    distanceKm: 4.0, creditScore: 84, verification: 'student', isExposureVip: false,
    teach: [['手绘', 'skilled', 'offline', '周末']],
    want: [['英语口语', 'skilled', 'online', '工作日晚上']]
  },
  {
    username: 'mili', nickname: '米粒', avatarSymbol: 'music.note',
    bio: '日语专业 · 声乐爱好者', locationLabel: '朝阳 · 三里屯书店',
    distanceKm: 8.2, creditScore: 88, verification: 'full', isExposureVip: true,
    teach: [['日语', 'skilled', 'online', '工作日晚上']],
    want: [['英语口语', 'beginner', 'online', '工作日晚上']]
  },
  {
    username: 'azhe', nickname: '阿哲', avatarSymbol: 'laptopcomputer',
    bio: '自学编程一年 · 想组学习搭子', locationLabel: '丰台 · 科技园',
    distanceKm: 20.0, creditScore: 70, verification: 'none', isExposureVip: false,
    teach: [['编程', 'skilled', 'online', '晚上']],
    want: [['视频剪辑', 'beginner', 'online', '晚上']]
  }
]

export async function seed(db, { force = false } = {}) {
  const count = db.get('SELECT COUNT(*) AS c FROM users').c
  if (count > 0 && !force) {
    console.log('[seed] 已有数据，跳过（--force 可重建）')
    return false
  }
  if (force) {
    db.exec(`
      DELETE FROM messages; DELETE FROM conversations; DELETE FROM evaluations;
      DELETE FROM exchange_records; DELETE FROM agreements; DELETE FROM dynamics;
      DELETE FROM skills; DELETE FROM users;
      DELETE FROM sqlite_sequence WHERE name IN ('users','skills','agreements','exchange_records','evaluations','dynamics','conversations','messages');
    `)
  }

  const hash = await bcrypt.hash(PASSWORD, 10)
  const userIds = {}
  for (const u of DEMO_USERS) {
    const r = db.run(
      `INSERT INTO users (username, password_hash, nickname, avatar_symbol, bio, location_label, distance_km, credit_score, verification, is_exposure_vip, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
      [u.username, hash, u.nickname, u.avatarSymbol, u.bio, u.locationLabel,
        u.distanceKm, u.creditScore, u.verification, u.isExposureVip ? 1 : 0, now()]
    )
    userIds[u.username] = r.lastInsertRowid
    for (const [name, level, type, time] of u.teach) {
      db.run(`INSERT INTO skills (user_id, kind, name, level, exchange_type, available_time) VALUES (?,?,?,?,?,?)`,
        [r.lastInsertRowid, 'teach', name, level, type, time])
    }
    for (const [name, level, type, time] of u.want) {
      db.run(`INSERT INTO skills (user_id, kind, name, level, exchange_type, available_time) VALUES (?,?,?,?,?,?)`,
        [r.lastInsertRowid, 'want', name, level, type, time])
    }
  }

  // 演示动态：已移除（动态区保持真实用户内容，不再填充模拟动态）

  // 示例小程序：贪吃蛇游戏（单文件自包含 HTML，符合小程序格式规范）
  try {
    const __dirname = dirname(fileURLToPath(import.meta.url))
    const snakeHtml = readFileSync(join(__dirname, 'snake-app.html'), 'utf8')
    const existing = db.get('SELECT id FROM apps WHERE name = ?', ['贪吃蛇'])
    if (!existing) {
      db.run(
        `INSERT INTO apps (user_id, name, description, icon, html_content, version, size_kb, downloads, created_at)
         VALUES (?,?,?,?,?,?,?,?,?)`,
        [userIds['aqing'], '贪吃蛇', '经典街机贪吃蛇：方向键/滑动控制，吃食物成长，速度随长度提升。示例小程序。',
          '🐍', snakeHtml, '1.0.0', Math.ceil(Buffer.byteLength(snakeHtml, 'utf8') / 1024), 0, now()]
      )
    }
  } catch (e) {
    console.warn('[seed] 示例小程序插入失败:', e.message)
  }

  // 演示会话与消息（含一条风控拦截系统提示）
  const linXiao = userIds['linxiao']
  const zhouKe = userIds['zhouke']
  const miLi = userIds['mili']
  const me = userIds['aqing']
  const c1 = db.run(`INSERT INTO conversations (user_a, user_b, last_message_text, last_time, unread_a, unread_b) VALUES (?,?,?,?,?,?)`,
    [me, linXiao, '好的，周六见！', daysAgo(0.04), 0, 1])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c1.lastInsertRowid, linXiao, '你好！看到你想学摄影，我可以带你入门～', 0, daysAgo(2)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c1.lastInsertRowid, me, '太棒了！我正想用视频剪辑和你交换摄影', 0, daysAgo(1.99)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c1.lastInsertRowid, linXiao, '没问题！周六下午两点国贸图书馆见？', 0, daysAgo(1)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c1.lastInsertRowid, linXiao, '⚠️ 该消息含违禁词：价格，已被平台风控拦截。技遇仅支持纯技能无偿互换。', 1, daysAgo(0.99)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c1.lastInsertRowid, linXiao, '好的，周六见！', 0, daysAgo(0.04)])
  const c2 = db.run(`INSERT INTO conversations (user_a, user_b, last_message_text, last_time, unread_a, unread_b) VALUES (?,?,?,?,?,?)`,
    [me, zhouKe, '成交！本周三开始？', daysAgo(2), 0, 0])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c2.lastInsertRowid, zhouKe, '吉他入门没问题，每周三晚线上 1 小时，你教我剪辑就行', 0, daysAgo(4)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c2.lastInsertRowid, me, '成交！本周三开始？', 0, daysAgo(2)])
  const c3 = db.run(`INSERT INTO conversations (user_a, user_b, last_message_text, last_time, unread_a, unread_b) VALUES (?,?,?,?,?,?)`,
    [me, miLi, '周末晚上有空吗？', daysAgo(0.08), 0, 2])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c3.lastInsertRowid, miLi, '五十音图我教你，你教我英语口语，双向互换～', 0, daysAgo(1)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c3.lastInsertRowid, me, '可以！先加个好友', 0, daysAgo(0.99)])
  db.run(`INSERT INTO messages (conversation_id, sender_id, text, is_system_note, created_at) VALUES (?,?,?,?,?)`, [c3.lastInsertRowid, miLi, '周末晚上有空吗？', 0, daysAgo(0.08)])

  // 演示协议 + 互换记录（方案 2.3.4/2.3.5）
  db.run(`INSERT INTO agreements (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, content, signed_at) VALUES (?,?,?,?,?,?,?,?,?)`,
    [me, linXiao, '视频剪辑', '摄影', 'both', '本周六 14:00', '国贸图书馆', '技遇平台官方技能互换协议（演示数据）', daysAgo(2)])
  db.run(`INSERT INTO exchange_records (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, status, evaluate_given, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [me, linXiao, '视频剪辑', '摄影', 'both', '本周六 14:00', '国贸图书馆', 'ongoing', 0, daysAgo(2)])
  db.run(`INSERT INTO agreements (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, content, signed_at) VALUES (?,?,?,?,?,?,?,?,?)`,
    [me, zhouKe, '视频剪辑', '吉他', 'online', '每周三 20:00', null, '技遇平台官方技能互换协议（演示数据）', daysAgo(10)])
  db.run(`INSERT INTO exchange_records (user_id, partner_id, my_skill_name, learn_skill_name, exchange_type, scheduled_time, location, status, evaluate_given, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [me, zhouKe, '视频剪辑', '吉他', 'online', '每周三 20:00', null, 'completed', 0, daysAgo(10)])

  console.log(`[seed] 完成：${DEMO_USERS.length} 个演示用户（密码均为 123456）`)
  return true
}

// ── CLI 入口：npm run seed [--force] ──
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const db = await initDb()
  db.exec(config.dbDriver === 'mysql' ? MYSQL_DDL : SQLITE_DDL)
  await seed(db, { force: process.argv.includes('--force') })
}

/**
 * 动态区不再生成任何模拟动态（需求：去除互动动态中的模拟动态）
 * 保留函数签名以兼容启动调用，但样本表已清空，仅返回 0
 */
export function ensureEveryoneHasDynamics(db) {
  return 0
}

/**
 * 确保示例小程序存在（每次启动检查补齐，幂等）：
 * 预置「贪吃蛇」游戏小程序，作为小程序市场的格式示例
 */
export function ensureSampleApps(db) {
  try {
    const __dirname = dirname(fileURLToPath(import.meta.url))
    const snakeHtml = readFileSync(join(__dirname, 'snake-app.html'), 'utf8')
    const existing = db.get('SELECT id FROM apps WHERE name = ?', ['贪吃蛇'])
    if (existing) return 0
    const owner = db.get('SELECT id FROM users WHERE username = ?', ['aqing'])
    if (!owner) return 0
    db.run(
      `INSERT INTO apps (user_id, name, description, icon, html_content, version, size_kb, downloads, created_at)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [owner.id, '贪吃蛇', '经典街机贪吃蛇：方向键/滑动控制，吃食物成长，速度随长度提升。示例小程序。',
        '🐍', snakeHtml, '1.0.0', Math.ceil(Buffer.byteLength(snakeHtml, 'utf8') / 1024), 0, new Date().toISOString()]
    )
    console.log('[seed] 已预置示例小程序：贪吃蛇')
    return 1
  } catch (e) {
    console.warn('[seed] 示例小程序插入失败:', e.message)
    return 0
  }
}
