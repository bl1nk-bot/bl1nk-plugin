-- ============================================================
-- bl1nk Migration 004 — Plugin Types + Run Logs
-- ต้องรัน 001 + 002 + 003 ก่อน
-- ============================================================

-- ============================================================
-- [PG] PostgreSQL
-- ============================================================

-- [PG] CREATE TABLE IF NOT EXISTS node_types (
--   id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   plugin_id UUID NOT NULL REFERENCES plugins(id) ON DELETE CASCADE,
--   name      TEXT NOT NULL,
--   category  TEXT NOT NULL CHECK (category IN
--             ('trigger','data','function','db','storage','cache','output','notify')),
--   schema    JSONB NOT NULL DEFAULT '{}',
--   icon      TEXT,
--   color     TEXT,
--   UNIQUE(plugin_id, name)
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_runs (
--   id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id      UUID NOT NULL REFERENCES flows(id),
--   version_id   UUID NOT NULL REFERENCES flow_versions(id),
--   triggered_by TEXT NOT NULL,
--   status       TEXT NOT NULL DEFAULT 'running'
--                CHECK (status IN ('running','success','failed')),
--   started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
--   finished_at  TIMESTAMPTZ,
--   tokens_in    INTEGER DEFAULT 0,
--   tokens_out   INTEGER DEFAULT 0,
--   error        TEXT,
--   trace        JSONB
-- );

-- [PG] CREATE INDEX IF NOT EXISTS idx_runs_flow ON flow_runs(flow_id, started_at DESC);
-- [PG] CREATE INDEX IF NOT EXISTS idx_runs_status ON flow_runs(status);

-- ============================================================
-- [SQ] SQLite
-- ============================================================

CREATE TABLE IF NOT EXISTS node_types (
  id        TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  plugin_id TEXT NOT NULL REFERENCES plugins(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  category  TEXT NOT NULL CHECK (category IN
            ('trigger','data','function','db','storage','cache','output','notify')),
  schema    TEXT NOT NULL DEFAULT '{}',
  icon      TEXT,
  color     TEXT,
  UNIQUE(plugin_id, name)
);

CREATE TABLE IF NOT EXISTS flow_runs (
  id           TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id      TEXT NOT NULL REFERENCES flows(id),
  version_id   TEXT NOT NULL REFERENCES flow_versions(id),
  triggered_by TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'running'
               CHECK (status IN ('running','success','failed')),
  started_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  finished_at  TEXT,
  tokens_in    INTEGER DEFAULT 0,
  tokens_out   INTEGER DEFAULT 0,
  error        TEXT,
  trace        TEXT
);

CREATE INDEX IF NOT EXISTS idx_runs_flow ON flow_runs(flow_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_runs_status ON flow_runs(status);

-- ============================================================
-- seed: node_types สำหรับ bl1nk-core
-- ============================================================

INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'webhook',   'trigger',  '{"input":null,"output":{"event":{"type":"string"},"payload":{"type":"object"}}}',                                                                                              'bolt',    '#EAB308' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'schedule',  'trigger',  '{"input":null,"output":{"triggered_at":{"type":"string"}}}',                                                                                                                    'clock',   '#EAB308' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'schema',    'data',     '{"input":{"type":"any"},"output":{"type":"object"}}',                                                                                                                          'box',     '#3B82F6' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'transform', 'function', '{"input":{"type":"any"},"output":{"type":"any"}}',                                                                                                                             'gear',    '#8B5CF6' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'ai_call',   'function', '{"input":{"prompt":{"type":"string"}},"output":{"result":{"type":"string"},"tokens_in":{"type":"number"},"tokens_out":{"type":"number"}}}',                                    'robot',   '#8B5CF6' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'query',     'db',       '{"input":{"sql":{"type":"string"}},"output":{"rows":{"type":"array"}}}',                                                                                                       'table',   '#22C55E' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'write',     'db',       '{"input":{"table":{"type":"string"},"data":{"type":"object"}},"output":{"id":{"type":"string"}}}',                                                                             'table',   '#22C55E' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'put',       'storage',  '{"input":{"key":{"type":"string"},"data":{"type":"any"}},"output":{"url":{"type":"string"}}}',                                                                                 'folder',  '#6B7280' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'get_cache', 'cache',    '{"input":{"key":{"type":"string"}},"output":{"value":{"type":"any"},"hit":{"type":"boolean"}}}',                                                                               'timer',   '#F97316' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'set_cache', 'cache',    '{"input":{"key":{"type":"string"},"value":{"type":"any"},"ttl":{"type":"number"}},"output":null}',                                                                             'timer',   '#F97316' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'send',      'output',   '{"input":{"target":{"type":"string"},"payload":{"type":"object"}},"output":null}',                                                                                             'send',    '#14B8A6' FROM plugins WHERE name='bl1nk-core';
INSERT OR IGNORE INTO node_types (id, plugin_id, name, category, schema, icon, color)
SELECT lower(hex(randomblob(16))), id, 'push',      'notify',   '{"input":{"message":{"type":"string"},"channel":{"type":"string"}},"output":null}',                                                                                            'bell',    '#EF4444' FROM plugins WHERE name='bl1nk-core';
