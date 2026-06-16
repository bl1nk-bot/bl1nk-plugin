#!/bin/bash
set -e

# Phase C1: bootstrap.sh
# อัตโนมัติ: ตั้งค่า DB -> รัน Migrations -> Deploy Modal

DB_PATH="./bl1nk.db"
MIGRATIONS_DIR="./schema/migrations"
MIGRATIONS_DIR="./schema/migrations"

echo "🚀 Starting bl1nk-plugin bootstrap..."

# 1. Initialize SQLite Database and Run Migrations
echo "📦 Applying migrations to $DB_PATH..."
for sql_file in $(ls $MIGRATIONS_DIR/*.sql | sort); do
    echo "  -> Running $sql_file..."
    sqlite3 $DB_PATH < "$sql_file"
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
