/**
 * 结构化日志（pino，成熟项目标配）
 * - 生产环境 / 非 TTY（CI、进程管理器）：单行 JSON，便于采集与检索
 * - 本地 TTY 开发：pino-pretty 着色易读
 * - 级别可用 LOG_LEVEL 覆盖（trace/debug/info/warn/error）
 */
import pino from 'pino'

const usePretty = Boolean(process.stdout?.isTTY) && process.env.NODE_ENV !== 'production'

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  ...(usePretty
    ? { transport: { target: 'pino-pretty', options: { translateTime: 'SYS:HH:MM:ss', ignore: 'pid,hostname' } } }
    : {})
})
