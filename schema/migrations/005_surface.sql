-- ============================================================
-- bl1nk Migration 005 — Surface Tables (user-facing)
-- ต้องรัน 001–004 ก่อน
-- ============================================================
-- memories:       "Claude จำอะไรของฉันไป"
-- context_ledger: "1 loop กิน context เท่าไหร่"
-- flow_insights:  "Claude แนะนำให้ปรับ flow ยังไง"
-- ============================================================

-- ============================================================
-- [PG] PostgreSQL
-- ============================================================

-- [PG] CREATE TABLE IF NOT EXISTS memories (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   run_id      UUID REFERENCES flow_runs(id),
--   summary     TEXT NOT NULL,
--   raw_size    INTEGER NOT NULL DEFAULT 0,
--   compressed_size INTEGER NOT NULL DEFAULT 0,
--   compression_ratio NUMERIC(5,2) GENERATED ALWAYS AS
--               (CASE WHEN compressed_size > 0
--                THEN ROUND(raw_size::numeric / compressed_size, 2)
--                ELSE 0 END) STORED,
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE TABLE IF NOT EXISTS context_ledger (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   run_id      UUID NOT NULL REFERENCES flow_runs(id),
--   tokens_in   INTEGER NOT NULL DEFAULT 0,
--   tokens_out  INTEGER NOT NULL DEFAULT 0,
--   tokens_saved INTEGER NOT NULL DEFAULT 0,
--   model       TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
--   recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_insights (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   run_id      UUID REFERENCES flow_runs(id),
--   type        TEXT NOT NULL CHECK (type IN ('optimize','warning','suggestion','error')),
--   message     TEXT NOT NULL,
--   node_key    TEXT,
--   impact      TEXT CHECK (impact IN ('high','medium','low')),
--   applied     BOOLEAN NOT NULL DEFAULT false,
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE INDEX IF NOT EXISTS idx_memories_flow ON memories(flow_id, created_at DESC);
-- [PG] CREATE INDEX IF NOT EXISTS idx_ledger_flow ON context_ledger(flow_id, recorded_at DESC);
-- [PG] CREATE INDEX IF NOT EXISTS idx_insights_flow ON flow_insights(flow_id, created_at DESC);
-- [PG] CREATE INDEX IF NOT EXISTS idx_insights_applied ON flow_insights(applied) WHERE applied = false;

-- ============================================================
-- [SQ] SQLite
-- ============================================================

CREATE TABLE IF NOT EXISTS memories (
  id               TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id          TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  run_id           TEXT REFERENCES flow_runs(id),
  summary          TEXT NOT NULL,
  raw_size         INTEGER NOT NULL DEFAULT 0,
  compressed_size  INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- computed column สำหรับ SQLite → คำนวณตอน query
-- SELECT *, ROUND(CAST(raw_size AS REAL) / NULLIF(compressed_size, 0), 2) AS compression_ratio FROM memories;

CREATE TABLE IF NOT EXISTS context_ledger (
  id           TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id      TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  run_id       TEXT NOT NULL REFERENCES flow_runs(id),
  tokens_in    INTEGER NOT NULL DEFAULT 0,
  tokens_out   INTEGER NOT NULL DEFAULT 0,
  tokens_saved INTEGER NOT NULL DEFAULT 0,
  model        TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
  recorded_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS flow_insights (
  id         TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id    TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  run_id     TEXT REFERENCES flow_runs(id),
  type       TEXT NOT NULL CHECK (type IN ('optimize','warning','suggestion','error')),
  message    TEXT NOT NULL,
  node_key   TEXT,
  impact     TEXT CHECK (impact IN ('high','medium','low')),
  applied    INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_memories_flow   ON memories(flow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_flow     ON context_ledger(flow_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_insights_flow   ON flow_insights(flow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_insights_active ON flow_insights(applied) WHERE applied = 0;
