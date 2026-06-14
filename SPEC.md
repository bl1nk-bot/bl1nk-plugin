# SPEC: bl1nk-plugin

## Overview
`bl1nk-plugin` เป็นระบบ Workflow Automation ที่ออกแบบมาเพื่อรันบน Modal.com โดยเน้นความเร็ว (Low Latency), การจัดการ Context ที่มีประสิทธิภาพ (Token Optimization) และการจัดเก็บสถานะแบบ Git-style Versioning.

## Core Components
1. **Schema Engine**: รองรับ SQLite (Local/Modal Volume) และ PostgreSQL.
2. **Modal Runner**: ตัวรันหลักที่ควบคุมการทำงานของ Nodes ต่างๆ บน Modal infrastructure.
3. **Plugin System**: ระบบที่อนุญาตให้เพิ่มขยายความสามารถผ่าน Plugins (Linear, Lark, GitHub, etc.).
4. **Surface Logic**: ระบบบันทึก Memory, Token Usage และ Insights เพื่อให้ AI (Claude) นำไปปรับปรุง Flow ได้.

## Key Features
- **Git-style Versioning**: ทุกการเปลี่ยนแปลงใน Flow จะถูกบันทึกเป็น Snapshot.
- **Token Saver**: ใช้ `memories` และ `context_ledger` เพื่อลดการใช้ Token ของ LLM.
- **Multi-Plugin Support**: รองรับการเชื่อมต่อกับเครื่องมือภายนอกแบบ Dynamic.
