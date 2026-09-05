/**
 * 数据层（方案 4.2）
 * 双驱动：
 *   - sqlite：Node 内置 node:sqlite，零依赖零配置，本地开发/演示
 *   - mysql ：mysql2，生产环境（方案 4.1：MySQL 用户数据）
 * 对外统一提供：exec(sql)、run(sql, params)、get(sql, params)、all(sql, params)
 * 注意：日期统一存 ISO-8601 文本，两个驱动行为一致。
 */
import { DatabaseSync } from 'node:sqlite'
import { mkdirSync } from 'node:fs'
import { dirname } from 'node:path'
import { config } from './config.js'

let db
let rawSqlite

function initSqlite() {
  const file = config.sqlitePath
  if (file !== ':memory:') mkdirSync(dirname(file), { recursive: true })
  rawSqlite = new DatabaseSync(file)
  rawSqlite.exec('PRAGMA journal_mode = WAL')
  rawSqlite.exec('PRAGMA foreign_keys = ON')
  const d = rawSqlite
  return {
    exec: (sql) => d.exec(sql),
    run: (sql, params = []) => {
      const r = d.prepare(sql).run(...params)
      return { lastInsertRowid: Number(r.lastInsertRowid), changes: r.changes }
    },
    get: (sql, params = []) => d.prepare(sql).get(...params) ?? null,
    all: (sql, params = []) => d.prepare(sql).all(...params)
  }
}

async function initMysql() {
  const mysql = await import('mysql2/promise')
  // 连接池（成熟项目标配）：复用连接避免每请求建连，支持并发
  const pool = mysql.createPool({
    host: config.mysql.host,
    port: config.mysql.port,
    user: config.mysql.user,
    password: config.mysql.password,
    database: config.mysql.database,
    charset: 'utf8mb4',
    timezone: '+00:00',
    connectionLimit: config.mysql.poolSize,
    waitForConnections: true
  })
  db = pool
  return {
    exec: (sql) => pool.query(sql).then(() => ({})),
    run: async (sql, params = []) => {
      const [r] = await pool.execute(sql, params)
      return { lastInsertRowid: Number(r.insertId), changes: r.affectedRows }
    },
    get: async (sql, params = []) => {
      const [rows] = await pool.execute(sql, params)
      return rows[0] ?? null
    },
    all: async (sql, params = []) => {
      const [rows] = await pool.execute(sql, params)
      return rows
    }
  }
}

export async function initDb() {
  if (config.dbDriver === 'mysql') {
    return initMysql()
  }
  return initSqlite()
}

export async function closeDb() {
  try { await db?.end?.() } catch { /* ignore */ } // mysql 池
  try { rawSqlite?.close?.() } catch { /* ignore */ } // sqlite 句柄
}
