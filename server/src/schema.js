/**
 * 数据库结构（方案 4.1/4.2 数据层）
 * 用户数据 / 技能数据 / 互换记录 / 评价数据 / 风控日志
 * 提供 sqlite 与 mysql 两套 DDL，逻辑表结构一致。
 */

export const SQLITE_DDL = `
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  nickname TEXT NOT NULL,
  avatar_symbol TEXT NOT NULL DEFAULT 'person.fill',
  avatar_url TEXT,
  bio TEXT NOT NULL DEFAULT '',
  location_label TEXT NOT NULL DEFAULT '',
  distance_km REAL,
  credit_score REAL NOT NULL DEFAULT 80,
  verification TEXT NOT NULL DEFAULT 'none',
  is_exposure_vip INTEGER NOT NULL DEFAULT 0,
  exposure_until TEXT,
  violation_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('teach','want')),
  name TEXT NOT NULL,
  level TEXT NOT NULL CHECK (level IN ('beginner','skilled','master')),
  exchange_type TEXT NOT NULL CHECK (exchange_type IN ('online','offline','both')),
  available_time TEXT NOT NULL DEFAULT '待协商'
);

CREATE TABLE IF NOT EXISTS agreements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  partner_id INTEGER NOT NULL,
  my_skill_name TEXT NOT NULL,
  learn_skill_name TEXT NOT NULL,
  exchange_type TEXT NOT NULL,
  scheduled_time TEXT NOT NULL,
  location TEXT,
  content TEXT NOT NULL,
  signed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exchange_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  partner_id INTEGER NOT NULL,
  my_skill_name TEXT NOT NULL,
  learn_skill_name TEXT NOT NULL,
  exchange_type TEXT NOT NULL,
  scheduled_time TEXT NOT NULL,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  evaluate_given INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS evaluations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id INTEGER NOT NULL,
  from_user_id INTEGER NOT NULL,
  to_user_id INTEGER NOT NULL,
  punctuality REAL NOT NULL,
  serious REAL NOT NULL,
  communication REAL NOT NULL,
  comment TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dynamics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  content TEXT NOT NULL,
  image_base64 TEXT,
  is_system_post INTEGER NOT NULL DEFAULT 0,
  order_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_a INTEGER NOT NULL,
  user_b INTEGER NOT NULL,
  last_message_text TEXT NOT NULL DEFAULT '',
  last_time TEXT NOT NULL,
  unread_a INTEGER NOT NULL DEFAULT 0,
  unread_b INTEGER NOT NULL DEFAULT 0,
  UNIQUE (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL,
  sender_id INTEGER NOT NULL,
  text TEXT NOT NULL,
  media_type TEXT,
  media_url TEXT,
  order_id TEXT,
  is_system_note INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  pet_type TEXT NOT NULL,
  breed TEXT NOT NULL DEFAULT '',
  age_months INTEGER NOT NULL,
  gender TEXT NOT NULL DEFAULT 'male',
  neutered INTEGER NOT NULL DEFAULT 0,
  weight_kg REAL,
  behaviors TEXT,
  home_reactions TEXT,
  photo_url TEXT,
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bookings (
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
`

export const MYSQL_DDL = `
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(64) NOT NULL,
  avatar_symbol VARCHAR(64) NOT NULL DEFAULT 'person.fill',
  avatar_url VARCHAR(255) NULL,
  bio VARCHAR(500) NOT NULL DEFAULT '',
  location_label VARCHAR(128) NOT NULL DEFAULT '',
  distance_km DOUBLE NULL,
  credit_score DOUBLE NOT NULL DEFAULT 80,
  verification VARCHAR(16) NOT NULL DEFAULT 'none',
  is_exposure_vip TINYINT(1) NOT NULL DEFAULT 0,
  exposure_until DATETIME NULL,
  violation_count INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS skills (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  kind ENUM('teach','want') NOT NULL,
  name VARCHAR(64) NOT NULL,
  level ENUM('beginner','skilled','master') NOT NULL,
  exchange_type ENUM('online','offline','both') NOT NULL,
  available_time VARCHAR(128) NOT NULL DEFAULT '待协商'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS agreements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  partner_id INT NOT NULL,
  my_skill_name VARCHAR(64) NOT NULL,
  learn_skill_name VARCHAR(64) NOT NULL,
  exchange_type VARCHAR(16) NOT NULL,
  scheduled_time VARCHAR(128) NOT NULL,
  location VARCHAR(255) NULL,
  content TEXT NOT NULL,
  signed_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exchange_records (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  partner_id INT NOT NULL,
  my_skill_name VARCHAR(64) NOT NULL,
  learn_skill_name VARCHAR(64) NOT NULL,
  exchange_type VARCHAR(16) NOT NULL,
  scheduled_time VARCHAR(128) NOT NULL,
  location VARCHAR(255) NULL,
  status ENUM('pending','ongoing','completed','cancelled') NOT NULL DEFAULT 'pending',
  evaluate_given TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS evaluations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  record_id INT NOT NULL,
  from_user_id INT NOT NULL,
  to_user_id INT NOT NULL,
  punctuality DOUBLE NOT NULL,
  serious DOUBLE NOT NULL,
  communication DOUBLE NOT NULL,
  comment VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS dynamics (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  content TEXT NOT NULL,
  image_base64 LONGTEXT NULL,
  is_system_post TINYINT(1) NOT NULL DEFAULT 0,
  order_id VARCHAR(32) NULL,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS conversations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_a INT NOT NULL,
  user_b INT NOT NULL,
  last_message_text VARCHAR(500) NOT NULL DEFAULT '',
  last_time DATETIME NOT NULL,
  unread_a INT NOT NULL DEFAULT 0,
  unread_b INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_pair (user_a, user_b)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  conversation_id INT NOT NULL,
  sender_id INT NOT NULL,
  text VARCHAR(1000) NOT NULL,
  media_type VARCHAR(16) NULL,
  media_url VARCHAR(255) NULL,
  order_id VARCHAR(32) NULL,
  is_system_note TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(64) NOT NULL,
  pet_type VARCHAR(16) NOT NULL,
  breed VARCHAR(64) NOT NULL DEFAULT '',
  age_months INT NOT NULL,
  gender VARCHAR(8) NOT NULL DEFAULT 'male',
  neutered TINYINT(1) NOT NULL DEFAULT 0,
  weight_kg DOUBLE NULL,
  behaviors VARCHAR(500) NULL,
  home_reactions VARCHAR(500) NULL,
  photo_url VARCHAR(255) NULL,
  notes VARCHAR(2000) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bookings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  provider_id INT NULL,
  pet_id INT NOT NULL,
  service_id VARCHAR(32) NOT NULL,
  service_name VARCHAR(64) NOT NULL,
  scheduled_time VARCHAR(128) NOT NULL,
  location VARCHAR(255) NULL,
  status ENUM('open','assigned','ongoing','completed','cancelled') NOT NULL DEFAULT 'open',
  price_yuan DOUBLE NULL,
  commission_rate DOUBLE NULL,
  commission_yuan DOUBLE NULL,
  worker_income DOUBLE NULL,
  open_to_feed TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
`
