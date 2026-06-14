-- ============================================================
-- bl1nk Migration 001 — Init (users + plugins)
-- ============================================================
-- รองรับ 2 engines: PostgreSQL และ SQLite
-- PostgreSQL: รัน section "-- [PG]" เท่านั้น
-- SQLite:     รัน section "-- [SQ]" เท่านั้น
-- ============================================================

-- ============================================================
-- [PG] PostgreSQL
-- ============================================================

-- [PG] CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- [PG] CREATE TABLE IF NOT EXISTS users (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   email       TEXT NOT NULL UNIQUE,
--   token_hash  TEXT NOT NULL,
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE TABLE IF NOT EXISTS plugins (
--   id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   name         TEXT NOT NULL UNIQUE,
--   version      TEXT NOT NULL,
--   manifest     JSONB NOT NULL DEFAULT '{}',
--   enabled      BOOLEAN NOT NULL DEFAULT true,
--   installed_at TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- ============================================================
-- [SQ] SQLite
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  email       TEXT NOT NULL UNIQUE,
  token_hash  TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS plugins (
  id           TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  name         TEXT NOT NULL UNIQUE,
  version      TEXT NOT NULL,
  manifest     TEXT NOT NULL DEFAULT '{}',
  enabled      INTEGER NOT NULL DEFAULT 1,
  installed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ============================================================
-- seed: bl1nk built-in plugins (core ที่ไม่ต้องติดตั้งเพิ่ม)
-- ============================================================

INSERT OR IGNORE INTO plugins (id, name, version, manifest, enabled) VALUES
  (
    lower(hex(randomblob(16))),
    'bl1nk-core',
    '0.1.0',
    '{"types":["trigger","data","function","db","storage","cache","output","notify"],"triggers":[],"actions":[]}',
    1
  ),
  (
    lower(hex(randomblob(16))),
    'bl1nk-linear',
    '0.1.0',
    '{"types":["issue","project","cycle"],"triggers":["issue.created","issue.updated","issue.closed"],"actions":["create_issue","update_status","add_comment"]}',
    1
  ),
  (
    lower(hex(randomblob(16))),
    'bl1nk-lark',
    '0.1.0',
    '{"types":["message","record","notification"],"triggers":["message.received","record.created","record.updated"],"actions":["send_message","create_record","update_record"]}',
    1
  ),
  (
    lower(hex(randomblob(16))),
    'bl1nk-github',
    '0.1.0',
    '{"types":["issue","pr","push","release"],"triggers":["issues.opened","pull_request.opened","push","release.published"],"actions":["create_issue","add_label","close_issue"]}',
    1
  );
