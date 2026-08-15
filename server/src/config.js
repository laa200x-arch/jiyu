import 'dotenv/config'

const env = process.env

export const config = {
  port: Number(env.PORT || 3000),
  dbDriver: env.DB_DRIVER || 'sqlite',
  sqlitePath: env.SQLITE_PATH || './data/jiyu.db',
  mysql: {
    host: env.MYSQL_HOST || '127.0.0.1',
    port: Number(env.MYSQL_PORT || 3306),
    user: env.MYSQL_USER || 'jiyu',
    password: env.MYSQL_PASSWORD || 'jiyu123456',
    database: env.MYSQL_DATABASE || 'jiyu'
  },
  jwtSecret: env.JWT_SECRET || 'jiyu-dev-secret-change-me',
  jwtExpires: env.JWT_EXPIRES || '7d',
  baiduAI: {
    apiKey: env.BAIDU_AI_API_KEY || '',
    secretKey: env.BAIDU_AI_SECRET_KEY || ''
  },
  autoSeed: env.AUTO_SEED !== 'false'
}
