# bl1nk Plugin — Handoff Report v2
> session: 2026-06-14 | ส่งต่อ session ใหม่เพื่อสร้าง plugin จริง

---

## 1. Spike เป้าหมาย

> **พิสูจน์ว่า: user พิมพ์ใน Claude app → bl1nk plugin deploy flow จริงบน Modal → ปิดแชทแล้ว flow ยังรันอยู่**

spike สำเร็จเมื่อ:
- สร้าง Linear issue → Lark ได้รับ message สรุปอัตโนมัติ
- ไม่ต้องเปิด Claude หรือ dashboard อีก

---

## 2. Product Context

**bl1nk คืออะไร:**
- Automation Hub รับ webhook จาก Lark, Linear, GitHub
- Process ผ่าน AI (Claude) → ส่งผลไปปลายทาง
- ปรัชญา: bottom-up — system ทำงานก่อน UI surface ทีหลัง
- Thin client (web/CLI/Tauri) + Thick network (Modal serverless)

**จุดว้าว:**
- Claude เป็นแค่ปากทางเข้า ไม่ใช่ตัว product
- flow มีชีวิตอยู่หลังปิดแชท
- memories บีบอัด state ให้ Claude session ถัดไปใช้ context น้อยลง

---

## 3. bl1nk Plugin Structure (Claude Code Plugin format)

```
bl1nk-plugin/
├── .claude-plugin/
│   └── plugin.json          ← manifest
├── .mcp.json                ← MCP server config (tools ทั้งหมด)
├── skills/
│   ├── flow-composer/
│   │   └── SKILL.md         ← แปลงบทสนทนา → flow.yaml → call create_flow
│   ├── flow-critic/
│   │   └── SKILL.md         ← วิเคราะห์ dry_run → ชี้แนะ → call deploy
│   ├── flow-debugger/
│   │   └── SKILL.md         ← อ่าน run logs → หา error → แนะนำแก้
│   ├── memory-reader/
│   │   └── SKILL.md         ← ดึง memories → inject context session ถัดไป
│   └── prompt-engineer/
│       └── SKILL.md         ← จูน AI node prompt → ประหยัด tokens
├── schema/
│   ├── migrations/          ← ✅ เสร็จแล้ว (001–005)
│   └── types/
│       └── nodes.yaml       ← 8 node types definition
├── templates/
│   ├── modal_runner.py      ← ⭐ B1 (ยังไม่มี)
│   ├── webhook_patterns/    ← A3 (ยังไม่มี)
│   │   ├── linear.yaml
│   │   ├── lark.yaml
│   │   ├── github.yaml
│   │   └── generic.yaml
│   └── images/
│       └── base.py          ← Modal image definition
└── scripts/
    ├── bootstrap.sh         ← C1 (ยังไม่มี)
    ├── validate_flow.py     ← C2 (ยังไม่มี)
    ├── dry_run.py           ← C2 (ยังไม่มี)
    └── deploy_flow.py       ← C3 (ยังไม่มี)
```

---

## 4. plugin.json

```json
{
  "name": "bl1nk",
  "displayName": "bl1nk — Automation Hub",
  "version": "0.1.0",
  "description": "Deploy automation flows from Claude. Webhook-first, Modal-powered, runs after chat ends.",
  "author": { "name": "bl1nk" },
  "skills": "./skills/",
  "mcpServers": "./.mcp.json",
  "userConfig": {
    "modal_token_id":     { "description": "Modal Token ID",     "sensitive": true },
    "modal_token_secret": { "description": "Modal Token Secret", "sensitive": true },
    "lark_bot_token":     { "description": "Lark Bot Token",     "sensitive": true },
    "linear_api_key":     { "description": "Linear API Key",     "sensitive": true }
  }
}
```

---

## 5. .mcp.json — MCP Server (tools ทั้งหมด)

```json
{
  "mcpServers": {
    "bl1nk": {
      "command": "python3",
      "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/mcp_server.py"],
      "env": {
        "BL1NK_DB":           "${CLAUDE_PLUGIN_DATA}/bl1nk.db",
        "MODAL_TOKEN_ID":     "${user_config.modal_token_id}",
        "MODAL_TOKEN_SECRET": "${user_config.modal_token_secret}",
        "LARK_BOT_TOKEN":     "${user_config.lark_bot_token}",
        "LINEAR_API_KEY":     "${user_config.linear_api_key}"
      }
    }
  }
}
```

### Tools ที่ MCP server expose (JSON in/out ทุกตัว)

| tool | input | output |
|---|---|---|
| `create_flow` | `{name, yaml}` | `{flow_id, version}` |
| `deploy_flow` | `{flow_id}` | `{webhook_url, deployment_id}` |
| `dry_run_flow` | `{flow_id, payload}` | `{steps[], estimated_tokens}` |
| `get_flow_status` | `{flow_id}` | `{status, last_run, runs_today}` |
| `list_flows` | `{}` | `{flows[]}` |
| `get_memories` | `{flow_id}` | `{memories[], total_tokens_saved}` |
| `rollback_flow` | `{flow_id, version_num}` | `{ok, active_version}` |

---

## 6. Node Types (8 types — ล็อคแล้ว)

| type | บทบาท | color |
|---|---|---|
| trigger | รับ webhook/schedule จากภายนอก | #EAB308 |
| data | กำหนด schema ของ payload | #3B82F6 |
| function | transform, filter, AI call | #8B5CF6 |
| db | query/write database | #22C55E |
| storage | file, blob | #6B7280 |
| cache | temp state ระหว่าง steps | #F97316 |
| output | ส่งผลไปปลายทาง | #14B8A6 |
| notify | แจ้งเตือน Lark/Tauri | #EF4444 |

**Canvas:** magnetic arrows (type match = ดูด), repulsion (type ไม่ match = ดัน) — type มาจาก plugin manifest

---

## 7. Database (ล็อคแล้ว — migrations เสร็จ)

**Backbone tables (13 tables):**
```
users, plugins, flows, flow_nodes, flow_edges,
flow_versions, flow_heads, flow_deployments,
node_types, flow_runs
```

**Surface tables (user-facing):**
```
memories        → "Claude จำอะไรของฉันไป"
context_ledger  → "1 loop กิน context เท่าไหร่"
flow_insights   → "Claude แนะนำให้ปรับ flow ยังไง"
```

**Versioning:** git-style — save=commit, deploy=publish, rollback ได้
**Engine:** SQLite (local) + PostgreSQL (production) — ใช้ schema เดียวกัน

---

## 8. bl1nk.flow.yaml format

```yaml
version: "1"
id: "flow_abc123"
name: "linear-to-lark"

nodes:
  - id: "n1"
    type: trigger
    plugin: "bl1nk-linear"
    config: { event: "issue.created" }
    position: { x: 0, y: 0 }

  - id: "n2"
    type: function
    plugin: "bl1nk-core"
    config:
      node_type: "ai_call"
      prompt: "สรุป issue นี้ใน 2 ประโยค: {{payload.title}}"
      model: "claude-sonnet-4-6"
    position: { x: 200, y: 0 }

  - id: "n3"
    type: notify
    plugin: "bl1nk-lark"
    config:
      action: "send_message"
      chat_id: "{{env.LARK_CHAT_ID}}"
      message: "{{n2.result}}"
    position: { x: 400, y: 0 }

edges:
  - { id: "e1", from: "n1", to: "n2", data_type: "issue" }
  - { id: "e2", from: "n2", to: "n3", data_type: "string" }

settings:
  timeout_ms: 30000
  retry: 1
  on_error: notify
```

---

## 9. สถานะงาน

### ✅ เสร็จแล้ว

```
schema/migrations/
├── 001_init.sql        ✅ users + plugins (seed 4 plugins)
├── 002_flows.sql       ✅ flows + nodes + edges
├── 003_versions.sql    ✅ versions + deployments (git-style)
├── 004_plugins.sql     ✅ node_types (seed 12 types) + flow_runs
└── 005_surface.sql     ✅ memories + context_ledger + flow_insights
```
ทดสอบผ่าน SQLite ทั้ง 5 ไฟล์ต่อเนื่องกัน — PostgreSQL version อยู่ใน comment พร้อม uncomment

---

### ❌ ยังต้องทำ (เรียงตาม priority)

#### B1 — `templates/modal_runner.py` ⭐ เริ่มก่อน
single-file Modal app:
```python
import modal

app = modal.App("bl1nk")

# image: sqlite3, anthropic, httpx, pyyaml
# @app.web_endpoint(method="POST") webhook_handler
#   → identify plugin/trigger
#   → load flow from SQLite
#   → run nodes (8 types minimal)
#   → write to memories/context_ledger
# @app.function() node_executor (per node type)
# @app.function(schedule=...) health_check
```
checkpoint: `curl -X POST [modal-url]/webhook -d '{"test":true}'` → response กลับ

#### B2 — `scripts/mcp_server.py`
Python MCP server expose 7 tools ด้านบน (stdio transport)
- รัน `bl1nk.db` ผ่าน sqlite3 built-in
- call Modal API สำหรับ deploy/status

#### A3 — `templates/webhook_patterns/*.yaml`
mock payloads + field mapping สำหรับ linear, lark, github, generic
ใช้ทดสอบ dry_run โดยไม่ต้องมี service จริง

#### C1 — `scripts/bootstrap.sh`
```bash
shelve pull                          # pull secrets ทั้งหมด
for f in schema/migrations/*.sql; do
  sqlite3 "$BL1NK_DB" < $f
done
modal deploy templates/modal_runner.py
echo "✅ webhook: $(modal app url bl1nk)/webhook"
```

#### C2 — `scripts/validate_flow.py` + `dry_run.py`
validate: type check, edge matching, ต้องมี trigger+output
dry_run: simulate ทุก node กับ mock payload, return estimated tokens

#### D1 — `skills/*/SKILL.md` (5 files) ⭐ ทำสุดท้าย
เขียนหลัง modal_runner ทำงานได้จริง
สำคัญ: ห้าม skill เขียน Modal code เอง — ใช้ template เท่านั้น

---

## 10. แบ่งงานตาม agent

| agent | งาน |
|---|---|
| **Claude** | B1 modal_runner.py, B2 mcp_server.py, D1 SKILL.md ทั้ง 5 |
| **opencode/kilocode** | A3 webhook patterns, C1 bootstrap.sh |
| **hermes/agy** | C2 validate_flow.py + dry_run.py, nodes.yaml |

กติกา: แนบ migrations ทั้ง 5 ไฟล์ + HANDOFF นี้ไปกับทุก session — ห้ามให้ agent คิด schema เองใหม่

---

## 11. Test command สุดท้าย (demo)

```bash
# mock: ไม่ต้องมี Linear จริง
curl -X POST https://[modal-url]/webhook \
  -H "Content-Type: application/json" \
  -d @templates/webhook_patterns/linear.yaml

# ดู result ใน Lark + เช็ค memories table
sqlite3 bl1nk.db "SELECT summary FROM memories ORDER BY created_at DESC LIMIT 1;"
```
