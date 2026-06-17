#!/bin/bash
set -eo pipefail

# Phase C1: bootstrap.sh
# อัตโนมัติ: ตั้งค่า DB -> รัน Migrations -> Deploy Modal

# Local SQLite DB for dev/dry-run only.
# The Modal runner uses /data/bl1nk.db on a Modal Volume (mounted by Modal, not
# accessible from here). Modal Volume migrations must be run separately via:
#   modal run templates/modal_runner.py::migrate   (TODO: Phase C)
DB_PATH="./bl1nk.db"
MIGRATIONS_DIR="./schema/migrations"

echo "🚀 Starting bl1nk-plugin bootstrap..."

# 1. Initialize SQLite Database and Run Migrations
echo "📦 Applying migrations to $DB_PATH..."
shopt -s nullglob
migrations=("$MIGRATIONS_DIR"/*.sql)
if [ "${#migrations[@]}" -eq 0 ]; then
    echo "❌ No migration files found in $MIGRATIONS_DIR" >&2
    exit 1
fi

for sql_file in "${migrations[@]}"; do
    echo "  -> Running $sql_file..."
    sqlite3 "$DB_PATH" < "$sql_file"
done

# 2. Deploy to Modal
echo "☁️ Deploying bl1nk-runner to Modal..."
# ตรวจสอบว่ามี modal หรือไม่
if command -v modal &> /dev/null; then
    modal deploy templates/modal_runner.py
else
    echo "⚠️ Modal CLI not found. Skipping deploy."
fi

echo "✅ Bootstrap complete!"
echo "Webhook URL can be found in your Modal dashboard."
