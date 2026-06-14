-- ============================================================
-- bl1nk Migration 003 — Versions + Deployments (git-style)
-- ต้องรัน 001 + 002 ก่อน
-- ============================================================

-- ============================================================
-- [PG] PostgreSQL
-- ============================================================

-- [PG] CREATE TABLE IF NOT EXISTS flow_versions (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   version_num INTEGER NOT NULL,
--   message     TEXT,
--   snapshot    JSONB NOT NULL,
--   author_id   UUID NOT NULL REFERENCES users(id),
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
--   UNIQUE(flow_id, version_num)
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_heads (
--   flow_id    UUID PRIMARY KEY REFERENCES flows(id) ON DELETE CASCADE,
--   version_id UUID NOT NULL REFERENCES flow_versions(id),
--   branch     TEXT NOT NULL DEFAULT 'main',
--   updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_deployments (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   version_id  UUID NOT NULL REFERENCES flow_versions(id),
--   deployed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
--   deployed_by UUID NOT NULL REFERENCES users(id),
--   status      TEXT NOT NULL DEFAULT 'active'
--              CHECK (status IN ('active','inactive','failed')),
--   webhook_url TEXT,
--   UNIQUE (flow_id, status) WHERE status = 'active'
-- );

-- [PG] CREATE INDEX IF NOT EXISTS idx_versions_flow ON flow_versions(flow_id, version_num DESC);
-- [PG] CREATE INDEX IF NOT EXISTS idx_deployments_flow ON flow_deployments(flow_id);

-- ============================================================
-- [SQ] SQLite
-- ============================================================

CREATE TABLE IF NOT EXISTS flow_versions (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id     TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  version_num INTEGER NOT NULL,
  message     TEXT,
  snapshot    TEXT NOT NULL DEFAULT '{}',
  author_id   TEXT NOT NULL REFERENCES users(id),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  UNIQUE(flow_id, version_num)
);

CREATE TABLE IF NOT EXISTS flow_heads (
  flow_id    TEXT PRIMARY KEY REFERENCES flows(id) ON DELETE CASCADE,
  version_id TEXT NOT NULL REFERENCES flow_versions(id),
  branch     TEXT NOT NULL DEFAULT 'main',
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS flow_deployments (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id     TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  version_id  TEXT NOT NULL REFERENCES flow_versions(id),
  deployed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  deployed_by TEXT NOT NULL REFERENCES users(id),
  status      TEXT NOT NULL DEFAULT 'active'
              CHECK (status IN ('active','inactive','failed')),
  webhook_url TEXT
);

-- SQLite ไม่รองรับ partial unique index → ใช้ trigger แทน
CREATE TRIGGER IF NOT EXISTS enforce_single_active_deployment
  BEFORE INSERT ON flow_deployments
  FOR EACH ROW
  WHEN NEW.status = 'active'
  BEGIN
    UPDATE flow_deployments
    SET status = 'inactive'
    WHERE flow_id = NEW.flow_id AND status = 'active';
  END;

CREATE INDEX IF NOT EXISTS idx_versions_flow ON flow_versions(flow_id, version_num DESC);
CREATE INDEX IF NOT EXISTS idx_deployments_flow ON flow_deployments(flow_id);
