/**
 * 演示数据种子（与 iOS 端 MockDataStore 示例数据一致）
 * 运行：npm run seed  或 首次启动时 AUTO_SEED=true 自动填充
 * 所有演示账号密码均为：123456
 */
import bcrypt from 'bcryptjs'
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

  // 演示动态（方案 2.3.6 动态区）
  const systemUserId = userIds['aqing']
  const dynamics = [
    ['平台', 'shield.lefthalf.filled', '温馨提示：技遇是纯技能无偿互换平台，严禁任何金钱交易。发现违规内容可举报，平台将给予警告、限流、封禁处理。', 1],
    ['阿青', 'face.smiling', '和 周可 完成了「吉他 ↔ 视频剪辑」互换，互相教得很认真！已互评五星～', 0],
    ['周可', 'guitars.fill', '本周六下午在五道口广场组织吉他弹唱小聚，纯兴趣交流，欢迎来玩～', 0],
    ['米粒', 'music.note', '日语五十音入门笔记整理好了，需要的同学评论区扣 1', 0],
    ['林晓', 'camera.fill', '这周六在国贸图书馆带新人学摄影构图，还有两个名额', 0]
  ]
  for (let i = 0; i < dynamics.length; i++) {
    const [nickname, , content, isSystem] = dynamics[i]
    const row = db.get('SELECT id FROM users WHERE nickname = ?', [nickname])
    db.run(`INSERT INTO dynamics (user_id, content, is_system_post, created_at) VALUES (?,?,?,?)`,
      [row?.id ?? systemUserId, content, isSystem, daysAgo(i)])
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
 * 为还没有动态的用户自动补充动态（幂等，不影响已有数据）
 * 让动态区覆盖"所有人的动态"
 */
export function ensureEveryoneHasDynamics(db) {
  const users = db.all('SELECT id, nickname, avatar_symbol FROM users')
  const samples = {
    阿青: '想找编程搭子一起写个小项目，用剪辑技能互换～',
    林晓: '周六下午国贸图书馆带新人学摄影构图，还有两个名额',
    陈默: '整理了 50 个常用日语动词卡片，想换英语口语练习',
    苏晴: '周末在文创园画水彩，欢迎来一起画（纯兴趣，颜料自备）',
    王野: '剪了一支校园 Vlog，想学剪辑的同学可以交流',
    周可: '本周三晚线上吉他入门互换，还剩一个名额',
    高远: '下周末去郊外拍星空，求同好结伴，我可以教摄影基础',
    韩雪: '想找摄影搭子，我用编程知识交换',
    白一凡: '速写练习第 21 天，坚持就是胜利',
    米粒: '日语五十音图口诀整理好了，需要的同学评论区扣 1',
    阿哲: '自学编程一年了，最近想找人互换剪辑和日语'
  }
  let added = 0
  for (const user of users) {
    const count = db.get('SELECT COUNT(*) AS c FROM dynamics WHERE user_id = ?', [user.id]).c
    const sample = samples[user.nickname]
    if (count === 0 && sample) {
      db.run(
        `INSERT INTO dynamics (user_id, content, is_system_post, created_at) VALUES (?,?,?,?)`,
        [user.id, sample, 0, new Date().toISOString()]
      )
      added++
    }
  }
  if (added > 0) console.log(`[seed] 为 ${added} 位用户补充了动态`)
  return added
}
