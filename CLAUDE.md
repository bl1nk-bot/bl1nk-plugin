# CLAUDE.md

Guidance for AI assistants (Claude Code and others) working in this repository.

## Project Overview

`bl1nk-plugin` is the scaffold for a **workflow automation system** (n8n/Zapier-style)
designed to run on **Modal.com**. Per `SPEC.md`, the core ideas are:

- **Schema Engine**: dual support for SQLite (local/Modal Volume) and PostgreSQL.
- **Modal Runner**: executes flow graphs (nodes + edges) as serverless Modal functions.
- **Plugin System**: extensibility via plugins (Linear, Lark, GitHub, generic webhooks, etc.).
- **Surface Logic**: `memories`, `context_ledger`, and `flow_insights` tables let Claude
  track token usage and suggest flow optimizations ("git-style versioning" for flows).

## Current State — Read Before Working

This repo is an **early-stage spike** (single commit: "initial project structure and
migrations"). Several files are intentional **empty placeholders** waiting on later
phases — do not assume they're broken or accidentally truncated:

| File | Status |
|---|---|
| `schema/migrations/001_init.sql` … `005_surface.sql` | Implemented |
| `templates/webhook_patterns/{generic,GitHub,lark,linear}.yaml` | Implemented |
| `templates/modal_runner.py` | Base implementation exists, **flagged for review/fix** (Phase B1) |
| `templates/images/base.py` | Implemented (Modal image w/ locked deps) |
| `scripts/bootstrap.sh` | **Stub** — only `#!/bin/bash`, Phase C1 not started |
| `scripts/validate_flow.py`, `scripts/dry_run.py`, `scripts/deploy_flow.py` | **Empty**, Phase C2/C3 not started |
| `schema/types/nodes.yaml` | **Empty**, node type definitions not yet extracted from migrations |
| `SKILL.md` | **Empty**, Phase D1 (Composer/Critic/Prompt Engineer roles) not started |

See `TODO.md` for the authoritative checklist and `PLAN.md` for phase ordering
(Phases A–E). When asked to "continue the spike", check these two files first to find
the next unchecked item.

**Latest session handoff:** `@HANDOFF.md` (v2, 2026-06-14) — detailed report of spike
goal, work status, and next steps. New sessions should read it alongside `TODO.md`
before starting work.

## Repository Structure

```bash
schema/
  migrations/        # Numbered SQL migrations, run in order (001 → 005)
  types/
    nodes.yaml        # (empty) intended canonical node-type definitions
scripts/
  bootstrap.sh        # (stub) shelve pull → migrations → modal deploy
  validate_flow.py    # (empty) schema validation for flow JSON
  dry_run.py          # (empty) mock execution of a flow without side effects
  deploy_flow.py      # (empty) INSERT flow → version snapshot → activate deployment
templates/
  modal_runner.py      # Modal stub: webhook endpoint + ModalRunner class (node executor)
  images/base.py        # Locked Modal image definition (apt/pip deps)
  webhook_patterns/      # YAML descriptors mapping external webhook payloads to flow inputs
    generic.yaml
    GitHub.yaml
    lark.yaml
    linear.yaml
PLAN.md   # Phase breakdown (A–E) for the spike
SPEC.md   # High-level architecture/feature spec
TODO.md   # Checklist tracking PLAN.md phases
SKILL.md  # (empty) intended for Claude role definitions (Composer/Critic/Prompt Engineer)
```

## Database Schema Conventions

All migrations live in `schema/migrations/` and are numbered `NNN_description.sql`,
applied strictly in order — later migrations assume earlier ones ran.

**Dual-engine pattern**: every migration file contains both a PostgreSQL section and a
SQLite section in the same file:

```sql
-- ============================================================
-- [PG] PostgreSQL
-- ============================================================
-- [PG] CREATE TABLE ... (entire block commented out with `-- [PG]` prefix)

-- ============================================================
-- [SQ] SQLite
-- ============================================================
CREATE TABLE ...   -- active SQLite statements, uncommented
```

- The `-- [PG]` prefixed lines are the Postgres equivalent, kept commented out. SQLite
  is currently the "live" engine. When adding a table/column, **write both blocks** —

  update the `[PG]` comment block AND the active `[SQ]` SQL, keeping them structurally
  equivalent (types differ: `UUID`/`JSONB`/`TIMESTAMPTZ`/`TEXT[]` in PG vs
  `TEXT`/`TEXT`/`TEXT`/`TEXT` JSON-encoded in SQLite).
- **IDs**: SQLite uses `TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16))))` as a
  UUID-like identifier; Postgres uses `UUID PRIMARY KEY DEFAULT uuid_generate_v4()`.
- **Timestamps**: SQLite stores ISO-8601 strings via
  `strftime('%Y-%m-%dT%H:%M:%SZ', 'now')`; Postgres uses `TIMESTAMPTZ DEFAULT now()`.
- **Booleans/JSON**: SQLite has no native bool/JSON types — use `INTEGER` (0/1) and
  `TEXT` (JSON-encoded strings) respectively; Postgres uses `BOOLEAN`/`JSONB`.
- SQLite lacks partial unique indexes and generated columns, so equivalent constraints
  are implemented via `TRIGGER`s (see `enforce_single_active_deployment` in
  `003_versions.sql`) or computed at query time (see the comment in `005_surface.sql`
  about `compression_ratio`).

### Migration Map

1. **001_init.sql** — `users`, `plugins` (+ seeds 4 built-in plugins: `bl1nk-core`,
   `bl1nk-linear`, `bl1nk-lark`, `bl1nk-GitHub`).
2. **002_flows.sql** — `flows`, `flow_nodes`, `flow_edges` (the flow graph itself).
3. **003_versions.sql** — `flow_versions`, `flow_heads`, `flow_deployments`
   (git-style snapshot/versioning + single-active-deployment enforcement).
4. **004_plugins.sql** — `node_types` (+ seeds the 12 `bl1nk-core` node types: webhook,
   schedule, schema, transform, ai_call, query, write, put, get_cache, set_cache, send,
   push), `flow_runs` (execution/run logs with token counters).
5. **005_surface.sql** — `memories`, `context_ledger`, `flow_insights` — the
   "user-facing surface" Claude uses to remember context, track token usage, and
   suggest flow improvements.

## Node Type System

Every node/edge belongs to one of **8 categories** (enforced via `CHECK` constraints on
`flow_nodes.type` and `node_types.category`):

```text
trigger | data | function | db | storage | cache | output | notify
```

Each `node_types` row defines a JSON `schema` with `input`/`output` shapes, plus `icon`
and `color` (hex) for UI rendering. Plugin manifests (`plugins.manifest`, JSON) declare
`types`, `triggers`, and `actions` the plugin supports.

## Webhook Pattern Files

`templates/webhook_patterns/*.yaml` describe how to normalize an external service's
webhook payload into flow-friendly fields. Each file follows this shape:

```yaml
service: <name>
events: [...]            # event types this pattern applies to
payload_example: {...}   # representative raw payload from the service
mapping:                  # dot-path lookups into payload_example
  id: "data.id"
  summary: "data.title"
  ...
```

When adding a new integration, add a new `templates/webhook_patterns/<service>.yaml`
following this same structure (see `linear.yaml`, `GitHub.yaml`, `lark.yaml` for
examples; `generic.yaml` is the fallback/catch-all pattern using `events: ["*"]`).

## Modal Runner (`templates/modal_runner.py`)

- Defines a `modal.Stub("bl1nk-runner")`, a `webhook` endpoint (`@modal.web_endpoint`),
  and a `ModalRunner` class (`@stub.cls`) backed by a SQLite DB on a Modal `Volume`
  (`/data/bl1nk.db`).
- `run_active_flow`: loads the single `active` `flow_deployments` row, deserializes its
  `flow_versions.snapshot` (JSON `{nodes, edges}`), then executes nodes **in list
  order** (note: real implementation needs topological sort per `PLAN.md` B1 — this is
  one of the known gaps).
- `execute_node` dispatches by `node.type` to `_node_*` handlers, one per category
  (`_node_data`, `_node_function`, `_node_db`, `_node_storage`, `_node_cache`,
  `_node_output`, `_node_notify`). Most are currently mock/stub implementations
  returning placeholder values — fleshing these out is part of Phase B1.
- Run lifecycle is tracked via `_init_run` (insert into `flow_runs`, status=`running`)
  and `_finalize_run` (update status to `success`/`failed`, store `trace` as JSON).

`templates/images/base.py` defines the locked Modal image (`bl1nk_image`): Debian slim
+ `sqlite3`/`libsqlite3-dev` (apt) + `pyyaml`, `requests`, `pydantic`, `python-dotenv`
(pip). Keep `modal_runner.py`'s inline `image` definition in sync with this file, or
better, import `bl1nk_image` from here instead of redefining it.

## Development Workflow / Phases (from `PLAN.md`)

- **Phase A** — base repo structure, `005_surface.sql`, webhook patterns (done/partial).
- **Phase B** — `modal_runner.py` (needs review/fix) + locked Modal image (done).
- **Phase C** — `bootstrap.sh`, `validate_flow.py` + `dry_run.py`, `deploy_flow.py` (all
  pending — currently empty/stub files).
- **Phase D** — `SKILL.md` defining Claude's Composer / Critic / Prompt Engineer roles
  (pending — currently empty).
- **Phase E** — end-to-end demo flow (Linear → AI → Lark + Memory) (pending).

Always cross-check `TODO.md` for the current checkbox state before starting new work,
and update it (`[ ]` → `[x]` or `[/]` for in-progress) as part of completing a task.

## Conventions & Style Notes

- Documentation (`PLAN.md`, `SPEC.md`, SQL comments) mixes **Thai and English**.
  Preserve the existing language of a file/section when editing; it's fine to add new
  Thai or English comments matching the surrounding style.
- SQL migration files: section headers use `-- ====...====` banner comments; keep this
  style for new migrations.
- No test suite, linter, or package manifest exists yet — there is nothing to run for
  CI/lint/test as of this writing. If you add Python scripts under `scripts/` or
  `templates/`, they depend on `modal`, `pyyaml`, `requests`, `pydantic`,
  `python-dotenv` (per `templates/images/base.py`), but no `requirements.txt`/
  `pyproject.toml` exists — consider adding one if dependencies become real.
- `.gitignore` already excludes local SQLite DB files (`*.db*`), `.env*`, Modal cache
  (`.modal/`), and standard Python/OS artifacts.
