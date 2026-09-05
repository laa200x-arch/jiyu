/**
 * 版本化数据库迁移（幂等，重复启动无副作用）
 * - 已应用项记录在 _migrations 表；新库按顺序全量执行，老库（曾用旧版 try/catch 迁移）会因
 *   「列已存在」自动跳过并补记版本，安全收敛到同一状态
 * - 新增迁移：只在 MIGRATIONS 末尾追加 { id, up }，禁止修改/重排历史项
 * - 日期统一 ISO-8601 文本，sqlite / mysql 双驱动行为一致
 */
import { logger } from './logger.js'

/** 执行单条 DDL；「列/索引已存在」静默跳过（兼容老库收敛），其余错误抛出 */
function execOk(db, sql) {
  try {
    db.exec(sql)
  } catch (e) {
    if (/duplicate column|already exists|duplicate field/i.test(String(e.message))) return
    throw e
  }
}

const MIGRATIONS = [
  {
    id: '2024-01-dynamics-image-base64',
    up: (db) => execOk(db, 'ALTER TABLE dynamics ADD COLUMN image_base64 TEXT')
  },
  {
    id: '2024-02-messages-media',
    up: (db) => {
      execOk(db, 'ALTER TABLE messages ADD COLUMN media_type TEXT')
      execOk(db, 'ALTER TABLE messages ADD COLUMN media_url TEXT')
    }
  },
  {
    id: '2024-03-bookings-pricing',
    up: (db) => {
      execOk(db, 'ALTER TABLE bookings ADD COLUMN price_yuan REAL')
      execOk(db, 'ALTER TABLE bookings ADD COLUMN commission_rate REAL')
      execOk(db, 'ALTER TABLE bookings ADD COLUMN commission_yuan REAL')
      execOk(db, 'ALTER TABLE bookings ADD COLUMN worker_income REAL')
    }
  },
  {
    id: '2024-04-bookings-open-to-feed',
    up: (db) => execOk(db, 'ALTER TABLE bookings ADD COLUMN open_to_feed INTEGER NOT NULL DEFAULT 0')
  },
  {
    id: '2024-05-bookings-services-json',
    up: (db) => execOk(db, 'ALTER TABLE bookings ADD COLUMN services_json TEXT')
  },
  {
    id: '2024-06-dynamics-order-id',
    up: (db) => execOk(db, 'ALTER TABLE dynamics ADD COLUMN order_id TEXT')
  },
  {
    id: '2024-07-messages-order-id',
    up: (db) => execOk(db, 'ALTER TABLE messages ADD COLUMN order_id TEXT')
  },
  {
    // 旧 bookings 表 provider_id 为 NOT NULL，需重建为可空（订单可发布待接单）；仅 sqlite
    id: '2024-08-bookings-provider-nullable',
    up: (db, driver) => {
      if (driver !== 'sqlite') return
      const cols = db.all('PRAGMA table_info(bookings)')
      const pid = cols.find((c) => c.name === 'provider_id')
      if (!pid || pid.notnull !== 1) return
      db.exec(`
        CREATE TABLE bookings_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          provider_id INTEGER,
          pet_id INTEGER NOT NULL,
          service_id TEXT NOT NULL,
          service_name TEXT NOT NULL,
          scheduled_time TEXT NOT NULL,
          location TEXT,
          status TEXT NOT NULL DEFAULT 'open',
          price_yuan REAL,
          commission_rate REAL,
          commission_yuan REAL,
          worker_income REAL,
          open_to_feed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        );
        INSERT INTO bookings_new (id, user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, created_at)
          SELECT id, user_id, provider_id, pet_id, service_id, service_name, scheduled_time, location, status, created_at FROM bookings;
        DROP TABLE bookings;
        ALTER TABLE bookings_new RENAME TO bookings;
      `)
    }
  },
  {
    id: '2024-09-users-avatar-url',
    up: (db) => execOk(db, 'ALTER TABLE users ADD COLUMN avatar_url TEXT')
  },
  {
    // 注册手机验证：一手机号一号（mysql 无 IF NOT EXISTS，靠 execOk 捕获已存在错误实现幂等）
    id: '2024-10-users-phone',
    up: (db, driver) => {
      execOk(db, 'ALTER TABLE users ADD COLUMN phone TEXT')
      execOk(db, driver === 'mysql'
        ? 'CREATE UNIQUE INDEX idx_users_phone ON users(phone)'
        : 'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone)')
    }
  }
]

export function runMigrations(db, driver) {
  db.exec(`CREATE TABLE IF NOT EXISTS _migrations (
    id TEXT PRIMARY KEY,
    applied_at TEXT NOT NULL
  )`)
  const applied = new Set(db.all('SELECT id FROM _migrations').map((r) => r.id))
  for (const m of MIGRATIONS) {
    if (applied.has(m.id)) continue
    try {
      m.up(db, driver)
      db.run('INSERT INTO _migrations (id, applied_at) VALUES (?,?)', [m.id, new Date().toISOString()])
      logger.info({ migration: m.id }, '[migrate] 已应用')
    } catch (e) {
      logger.error({ migration: m.id, err: e.message }, '[migrate] 应用失败，停止启动')
      throw e
    }
  }
}
