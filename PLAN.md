# PLAN: bl1nk Spike

## Phase A — เตรียมฐาน
- A1. แก้ Migration — เพิ่ม 3 surface tables (005_surface.sql)
- A2. โครง repo plugin (schema/, scripts/, templates/)
- A3. Webhook patterns (linear, lark, github, generic)

## Phase B — ชิ้นที่ต้องเทสจริง
- B1. modal_runner.py (webhook endpoint + flow loader + node executor)
- B2. Modal image definitions (base image locked dependencies)

## Phase C — Scripts
- C1. bootstrap.sh (shelve pull → migrations → modal deploy)
- C2. validate_flow.py + dry_run.py (schema check + mock execution)
- C3. deploy_flow.py (INSERT flow → version snapshot → activate)

## Phase D — SKILL.md
- D1. เขียน SKILL.md (Composer, Critic, Prompt Engineer roles)

## Phase E — End-to-End Test
- E1. Demo flow จริง (Linear → AI → Lark + Memory)
