-- ============================================================
-- bl1nk Migration 002 — Flows + Graph (nodes + edges)
-- ต้องรัน 001_init.sql ก่อน
-- ============================================================

-- ============================================================
-- [PG] PostgreSQL
-- ============================================================

-- [PG] CREATE TABLE IF NOT EXISTS flows (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   name        TEXT NOT NULL,
--   description TEXT,
--   owner_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
--   tags        TEXT[] DEFAULT '{}',
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
--   updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_nodes (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   node_key    TEXT NOT NULL,
--   type        TEXT NOT NULL CHECK (type IN ('trigger','data','function','db','storage','cache','output','notify')),
--   label       TEXT NOT NULL,
--   plugin_id   UUID REFERENCES plugins(id),
--   config      JSONB NOT NULL DEFAULT '{}',
--   position    JSONB NOT NULL DEFAULT '{"x":0,"y":0}',
--   UNIQUE(flow_id, node_key)
-- );

-- [PG] CREATE TABLE IF NOT EXISTS flow_edges (
--   id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--   flow_id     UUID NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
--   edge_key    TEXT NOT NULL,
--   from_node   TEXT NOT NULL,
--   to_node     TEXT NOT NULL,
--   label       TEXT,
--   data_type   TEXT NOT NULL,
--   condition   TEXT,
--   UNIQUE(flow_id, edge_key)
-- );

-- [PG] CREATE INDEX IF NOT EXISTS idx_flow_nodes_flow_id ON flow_nodes(flow_id);
-- [PG] CREATE INDEX IF NOT EXISTS idx_flow_edges_flow_id ON flow_edges(flow_id);
-- [PG] CREATE INDEX IF NOT EXISTS idx_flows_owner ON flows(owner_id);

-- ============================================================
-- [SQ] SQLite
-- ============================================================

CREATE TABLE IF NOT EXISTS flows (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  name        TEXT NOT NULL,
  description TEXT,
  owner_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tags        TEXT NOT NULL DEFAULT '[]',
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS flow_nodes (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id     TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  node_key    TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('trigger','data','function','db','storage','cache','output','notify')),
  label       TEXT NOT NULL,
  plugin_id   TEXT REFERENCES plugins(id),
  config      TEXT NOT NULL DEFAULT '{}',
  position    TEXT NOT NULL DEFAULT '{"x":0,"y":0}',
  UNIQUE(flow_id, node_key)
);

CREATE TABLE IF NOT EXISTS flow_edges (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  flow_id     TEXT NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  edge_key    TEXT NOT NULL,
  from_node   TEXT NOT NULL,
  to_node     TEXT NOT NULL,
  label       TEXT,
  data_type   TEXT NOT NULL,
  condition   TEXT,
  UNIQUE(flow_id, edge_key)
);

CREATE INDEX IF NOT EXISTS idx_flow_nodes_flow_id ON flow_nodes(flow_id);
CREATE INDEX IF NOT EXISTS idx_flow_edges_flow_id ON flow_edges(flow_id);
CREATE INDEX IF NOT EXISTS idx_flows_owner ON flows(owner_id);

-- ============================================================
-- auto-update updated_at trigger
-- ============================================================

CREATE TRIGGER IF NOT EXISTS flows_updated_at
  AFTER UPDATE ON flows
  FOR EACH ROW
  BEGIN
    UPDATE flows SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
    WHERE id = OLD.id;
  END;
