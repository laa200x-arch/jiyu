import 'dotenv/config'

const env = process.env

// 安全：生产环境必须配置随机 JWT_SECRET（默认值可被伪造 token）
const jwtSecret = env.JWT_SECRET || 'jiyu-dev-secret-change-me'
const isProd = env.NODE_ENV === 'production'
if (isProd && (!env.JWT_SECRET || env.JWT_SECRET === 'jiyu-dev-secret-change-me')) {
  throw new Error('[config] 生产环境必须设置随机 JWT_SECRET（禁止使用默认值），请配置 .env 后重启')
}

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
  jwtSecret,
  jwtExpires: env.JWT_EXPIRES || '7d',
  baiduAI: {
    apiKey: env.BAIDU_AI_API_KEY || '',
    secretKey: env.BAIDU_AI_SECRET_KEY || ''
  },
  // CORS 白名单（逗号分隔；空 = 默认放行无 Origin 的原生客户端与本地调试）
  // 生产建议配置为你的前端域名，例如 CORS_ORIGINS=https://jiyu.example.com
  corsOrigins: (env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean),
  autoSeed: env.AUTO_SEED !== 'false'
}
