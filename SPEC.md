# SPEC: bl1nk-plugin

## Overview

`bl1nk-plugin` เป็นระบบ Workflow Automation ที่ออกแบบมาเพื่อรันบน Modal.com โดยเน้นความเร็ว (Low Latency), การจัดการ Context ที่มีประสิทธิภาพ (Token Optimization) และการจัดเก็บสถานะแบบ Git-style Versioning.

**ปรัชญาหลัก:** "คุยกับ Claude ครั้งเดียว → ได้ flow ที่รันอยู่จริง → ปิดแชทได้เลย" — bl1nk คือ State Runtime ของ Claude

## Entry Point

1. เปิดเว็บครั้งแรก → login → copy token → จบ
2. หลังจากนั้น Claude สั่ง deploy ผ่าน CLI ได้เลย
3. user รับแจ้งเตือนผ่าน Lark + Tauri push เท่านั้น

---

## Architecture

```
[Linear / Lark / GitHub]
        ↓ webhook
[Modal.com endpoint]       ← flow runner (serverless)
        ↓
[อ่าน flow def จาก SQLite/PG]
        ↓
[Claude API]               ← AI step / function node
        ↓
[Output → Lark message]
[Dream → memories table]   ← บีบอัด state สำหรับ session ถัดไป
```

**Stack:**
- Modal.com — webhook endpoint + flow runner + cron
- SQLite (local/dev) + PostgreSQL (production via Neon/Supabase)
- Shelve — secret management
- Lark + Tauri — notification layer

---

## Node Types (8 types v1 — locked)

| type | role | icon | color |
|---|---|---|---|
| trigger | รับ webhook/schedule จากภายนอก | bolt | #EAB308 |
| data | กำหนด schema/shape ของ payload | box | #3B82F6 |
| function | transform, filter, AI agent call | gear | #8B5CF6 |
| db | query/write database | table | #22C55E |
| storage | file, blob, R2 | folder | #6B7280 |
| cache | temp state ระหว่าง steps | timer | #F97316 |
| output | ส่งผลไปปลายทาง (fire & forget) | send | #14B8A6 |
| notify | แจ้งเตือน (Lark/Tauri) | bell | #EF4444 |

**Canvas behavior:**
- Magnetic arrows — nodes ดูดหากันเมื่อ output type match กับ input type
- Repulsion — nodes ที่ type ไม่ match ดันออกอัตโนมัติ
- Type matching มาจาก plugin manifest

---

## Plugin System

```yaml
# Plugin Manifest Structure
name: string        # plugin name (e.g., bl1nk-linear)
version: string     # semver
types: [string]     # supported data types
triggers: [string]   # webhook events this plugin listens for
actions: [string]   # actions this plugin can perform
```

**Built-in plugins (seed แล้ว):**
- bl1nk-core (nodes: webhook, schedule, schema, transform, ai_call, query, write, put, get_cache, set_cache, send, push)
- bl1nk-linear (triggers: issue.created/updated/closed)
- bl1nk-lark (events: im.message.receive_v1, drive.file.created_v1)
- bl1nk-github (events: issues, pull_request, push)

---

## Database Schema (13 tables)

### Backbone Tables (user ไม่เห็น)

```sql
-- users (auth)
id: TEXT PRIMARY KEY
email, api_key, created_at, updated_at

-- plugins (registry)
id: TEXT PRIMARY KEY
name, manifest (JSON), created_at

-- flows (metadata)
id: TEXT PRIMARY KEY
name, description, owner_id, tags, created_at, updated_at

-- flow_nodes (normalized)
id: TEXT PRIMARY KEY
flow_id, node_key, type, label, plugin_id, config, position, UNIQUE(flow_id, node_key)

-- flow_edges (normalized)
id: TEXT PRIMARY KEY
flow_id, edge_key, from_node, to_node, label, data_type, condition, UNIQUE(flow_id, edge_key)

-- flow_versions (git-style immutable)
id: TEXT PRIMARY KEY
flow_id, version_num, snapshot (JSON), created_at, message

-- flow_heads (HEAD pointer)
id: TEXT PRIMARY KEY
flow_id, head_version_id, updated_at

-- flow_deployments (active webhook receiver)
id: TEXT PRIMARY KEY
flow_id, version_id, status, deployed_at, UNIQUE(status) WHERE status='active'

-- node_types (registry)
id: TEXT PRIMARY KEY
plugin_id, name, category, schema, icon, color, UNIQUE(plugin_id, name)

-- flow_runs (execution log)
id: TEXT PRIMARY KEY
flow_id, version_id, triggered_by, status, started_at, finished_at, tokens_in, tokens_out, error, trace
```

### Surface Tables (user ดู)

```sql
-- memories (Claude จำอะไร)
id: TEXT PRIMARY KEY
flow_id, run_id, summary, raw_size, compressed_size, created_at

-- context_ledger (Token usage)
id: TEXT PRIMARY KEY
flow_id, run_id, tokens_in, tokens_out, tokens_saved, model, recorded_at

-- flow_insights (Critic บันทึก)
id: TEXT PRIMARY KEY
flow_id, run_id, type CHECK (optimize|warning|suggestion|error), message, node_key, impact, applied, created_at
```

---

## Flow YAML Format

```yaml
version: "1"
id: "flow_abc123"          # immutable, system-generated
name: "linear-to-lark"
description: "สรุป Linear issue ส่ง Lark"

nodes:
  - id: "n1"
    type: trigger
    label: "Linear Webhook"
    plugin: "bl1nk-linear"
    config:
      event: "issue.created"
    position: { x: 0, y: 0 }

  - id: "n2"
    type: function
    label: "AI Summarize"
    plugin: "bl1nk-core"
    config:
      node_type: "ai_call"
      prompt: "สรุป issue นี้ใน 2 ประโยค: {{payload.title}}"
      model: "claude-sonnet-4-6"
    position: { x: 200, y: 0 }

  - id: "n3"
    type: notify
    label: "Send to Lark"
    plugin: "bl1nk-lark"
    config:
      action: "send_message"
      chat_id: "{{env.LARK_CHAT_ID}}"
      message: "{{n2.result}}"
    position: { x: 400, y: 0 }

edges:
  - id: "e1"
    from: "n1"
    to: "n2"
    data_type: "issue"
    label: "issue payload"

  - id: "e2"
    from: "n2"
    to: "n3"
    data_type: "string"
    label: "summary"

settings:
  timeout_ms: 30000
  retry: 1
  on_error: notify
```

---

## Modal Runner API Spec

### Endpoints

`POST /webhook`
- Accept: JSON payload
- Header: `X-Bl1nk-Flow-ID` (optional, defaults to active deployment)
- Returns: `{"status": "success", "run_id": "...", "output": {...}}`

### Functions

```
flow_loader(flow_id) → {nodes: [...], edges: [...]}
node_executor(type, config, input) → output
health_check() → {"status": "healthy", "active_flows": N}
```

### Execution Flow

1. webhook receives payload
2. identify plugin/trigger from headers/payload
3. load active flow from flow_deployments
4. deserialize flow_versions.snapshot
5. topological sort nodes (currently linear in spike)
6. execute each node by type
7. record to flow_runs + context_ledger
8. return response

---

## Webhook Patterns

Each webhook pattern defines how to normalize external payloads:

```yaml
service: <name>
events: [...]              # event types
payload_example: {...}       # mock payload for dry-run
mapping:                     # dot-path lookups
  id: "data.id"
  summary: "data.title"
```

Patterns: `linear.yaml`, `lark.yaml`, `github.yaml`, `generic.yaml`

---

## Versioning Strategy

- save: INSERT flow_versions (version_num + 1, snapshot JSONB)
- deploy: INSERT flow_deployments + UPDATE flow_heads
- rollback: UPDATE flow_heads → version เก่า + INSERT deployment

---

## CLI Commands

```bash
bl1nk flow create "ชื่อ flow"
bl1nk flow save "commit message"
bl1nk flow deploy
bl1nk flow rollback --to <version_num>
bl1nk flow log
bl1nk flow dry-run --payload webhook_patterns/linear.yaml
bl1nk webhook listen --port 4000
```

---

## Demo Target (End-to-End)

1. Linear issue.created → Lark เด้งสรุปอัตโนมัติ
2. ปิดแชท Claude → flow ยังทำงาน (Modal ไม่หยุด)
3. memories table มี compressed summary หลัง run
4. context_ledger บันทึก tokens จริง
5. `bl1nk flow log` แสดง run history

Mock test: `curl -X POST [modal-url]/webhook -d @webhook_patterns/linear.yaml`
