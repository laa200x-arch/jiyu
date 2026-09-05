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
    database: env.MYSQL_DATABASE || 'jiyu',
    poolSize: Number(env.MYSQL_POOL_SIZE || 10)
  },
  jwtSecret,
  jwtExpires: env.JWT_EXPIRES || '7d',
  // 客户端版本检查（/api/version）：发布新版时更新这三个值（或用环境变量覆盖）
  appVersion: env.APP_VERSION || '1.1.2',
  updateMessage: env.UPDATE_MESSAGE ||
    'v1.1.2 更新：修复宠物订单风控误拦截；新增忘记密码；评价文字展示与违规申诉；安全加固（手机号隐私 / Electron 隔离 / 上传白名单）',
  downloadUrl: env.DOWNLOAD_URL || 'https://github.com/laa200x-arch/jiyu/releases/tag/win-v1.1.2',
  baiduAI: {
    apiKey: env.BAIDU_AI_API_KEY || '',
    secretKey: env.BAIDU_AI_SECRET_KEY || ''
  },
  // CORS 白名单（逗号分隔；空 = 默认放行无 Origin 的原生客户端与本地调试）
  // 生产建议配置为你的前端域名，例如 CORS_ORIGINS=https://jiyu.example.com
  corsOrigins: (env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean),
  autoSeed: env.AUTO_SEED !== 'false'
}
