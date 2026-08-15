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

function initSqlite() {
  const file = config.sqlitePath
  if (file !== ':memory:') mkdirSync(dirname(file), { recursive: true })
  db = new DatabaseSync(file)
  db.exec('PRAGMA journal_mode = WAL')
  db.exec('PRAGMA foreign_keys = ON')
  return {
    exec: (sql) => db.exec(sql),
    run: (sql, params = []) => {
      const r = db.prepare(sql).run(...params)
      return { lastInsertRowid: Number(r.lastInsertRowid), changes: r.changes }
    },
    get: (sql, params = []) => db.prepare(sql).get(...params) ?? null,
    all: (sql, params = []) => db.prepare(sql).all(...params)
  }
}

async function initMysql() {
  const mysql = await import('mysql2/promise')
  const conn = await mysql.createConnection({
    host: config.mysql.host,
    port: config.mysql.port,
    user: config.mysql.user,
    password: config.mysql.password,
    database: config.mysql.database,
    charset: 'utf8mb4',
    timezone: '+00:00'
  })
  db = conn
  return {
    exec: (sql) => conn.query(sql).then(() => ({})),
    run: async (sql, params = []) => {
      const [r] = await conn.execute(sql, params)
      return { lastInsertRowid: Number(r.insertId), changes: r.affectedRows }
    },
    get: async (sql, params = []) => {
      const [rows] = await conn.execute(sql, params)
      return rows[0] ?? null
    },
    all: async (sql, params = []) => {
      const [rows] = await conn.execute(sql, params)
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

export function closeDb() {
  try { db?.close?.() } catch { /* ignore */ }
}
