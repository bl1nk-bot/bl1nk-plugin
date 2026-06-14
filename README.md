# bl1nk-plugin

> **Workflow automation system ที่ deploy แล้วรันจริง — ปิดแชท Claude ได้เลย**

`bl1nk` คือ Automation Hub รับ webhook จาก Lark / Linear / GitHub → process ผ่าน AI (Claude) → ส่งผลไปปลายทาง ทำงานบน [Modal.com](https://modal.com) แบบ serverless

**ปรัชญา:** คุยกับ Claude ครั้งเดียว → ได้ flow ที่รันอยู่จริง → ปิดแชทได้เลย  
Claude เป็นแค่ **ปากทางเข้า** — ไม่ใช่ตัว product

---

## ✨ Features

- 🪝 **Webhook-first** — รับ payload จาก Linear / Lark / GitHub / generic
- 🧠 **AI steps** — inline Claude call ภายใน flow (ai_call node)
- 🔀 **Visual flow graph** — nodes + edges, 8 categories (trigger / data / function / db / storage / cache / output / notify)
- 💾 **Git-style versioning** — `save` = commit, `deploy` = publish, `rollback` ได้
- 🗜️ **Memory compression** — `memories` table บีบอัด state ให้ Claude session ถัดไปใช้ context น้อยลง
- 📊 **Token ledger** — `context_ledger` บันทึก tokens จริงทุก run
- 🔌 **Plugin system** — เพิ่ม integration ใหม่ด้วย manifest + webhook pattern

---

## 📐 Architecture

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
- **Modal.com** — webhook endpoint + flow runner + cron
- **SQLite** (local/dev) + **PostgreSQL** (production) — schema เดียวกัน
- **Shelve** — secret management
- **Lark + Tauri** — notification layer

---

## 🚀 Status

🟡 **Early-stage spike** — Phase A (schema) เสร็จ, Phase B–E กำลังดำเนินการ

ดูสถานะล่าสุด: [`TODO.md`](TODO.md) + [`HANDOFF.md`](HANDOFF.md)

| Phase | งาน | สถานะ |
|---|---|---|
| A | Schema + repo structure + webhook patterns | ✅ เสร็จ |
| B | Modal runner + image | 🔄 กำลังทำ (B1 modal_runner.py รอ review) |
| C | Scripts (bootstrap / validate / dry-run / deploy) | ❌ ยังไม่เริ่ม |
| D | SKILL.md (Claude role definitions) | ❌ ยังไม่เริ่ม |
| E | End-to-end demo (Linear → AI → Lark) | ❌ ยังไม่เริ่ม |

---

## 🧪 Quick test (เมื่อ deploy แล้ว)

```bash
# mock: ไม่ต้องมี Linear จริง
curl -X POST https://[modal-url]/webhook \
  -H "Content-Type: application/json" \
  -d '{"action": "issue.created", "data": {"id": "LNR-123", "title": "Test issue"}}'

# ดู result ใน Lark + เช็ค memories table
sqlite3 /data/bl1nk.db "SELECT summary FROM memories ORDER BY created_at DESC LIMIT 1;"
```

---

## 📂 Project Structure

```
bl1nk-plugin/
├── .claude-plugin/         ← plugin manifest
├── .mcp.json               ← MCP server config
├── schema/
│   ├── migrations/         ← 001_init → 005_surface (PostgreSQL + SQLite)
│   └── types/
│       └── nodes.yaml      ← 8 node categories
├── scripts/
│   ├── bootstrap.sh        ← shelve + migrations + modal deploy
│   ├── validate_flow.py    ← type check, edge matching
│   ├── dry_run.py          ← simulate ทุก node
│   └── deploy_flow.py      ← INSERT flow → version → activate
├── templates/
│   ├── modal_runner.py     ← ⭐ Modal webhook + node executor
│   ├── images/base.py      ← Modal image (locked deps)
│   └── webhook_patterns/   ← linear / lark / github / generic
├── skills/                 ← Claude role SKILL.md (5 files)
├── CLAUDE.md               ← AI assistant guidance
├── HANDOFF.md              ← ล่าสุด: session handoff v2 (2026-06-14)
├── PLAN.md                 ← Phase A–E breakdown
├── SPEC.md                 ← Architecture & API spec
└── TODO.md                 ← Authoritative checklist
```

---

## 📖 Documentation

| File | เนื้อหา |
|---|---|
| [`SPEC.md`](SPEC.md) | High-level architecture, node types, flow YAML, API spec |
| [`PLAN.md`](PLAN.md) | Phase breakdown (A–E) + งานในแต่ละ phase |
| [`TODO.md`](TODO.md) | Checklist สถานะปัจจุบัน — เริ่มงานต่อจากที่นี่ |
| [`HANDOFF.md`](HANDOFF.md) | Session handoff ล่าสุด (2026-06-14) — สำหรับ session ใหม่ |
| [`CLAUDE.md`](CLAUDE.md) | Guidance สำหรับ AI assistants ที่เข้ามาทำงานใน repo |
| `schema/migrations/` | ไฟล์ SQL — อ่านตามลำดับ 001 → 005 |

---

## 🔌 Built-in plugins

- **bl1nk-core** — 12 node types (webhook, schedule, schema, transform, ai_call, query, write, put, get_cache, set_cache, send, push)
- **bl1nk-linear** — triggers: `issue.created` / `issue.updated` / `issue.closed`
- **bl1nk-lark** — events: `im.message.receive_v1`, `drive.file.created_v1`
- **bl1nk-github** — events: `issues`, `pull_request`, `push`

---

## 🛠️ Development

ตอนนี้ยังไม่มี `requirements.txt` หรือ test suite — spike phase

Dependencies ที่ใช้ (ดูจาก `templates/images/base.py`):
- Python: `modal`, `pyyaml`, `requests`, `pydantic`, `python-dotenv`
- System: `sqlite3`, `libsqlite3-dev`

---

## 📜 License

TBD
