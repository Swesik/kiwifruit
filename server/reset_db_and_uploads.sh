#!/usr/bin/env bash
# Reset the SQLite DB and uploads folder to a minimal seeded state
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
DB="$ROOT/kiwifruit.db"
SCHEMA="$ROOT/schema.sql"
UPLOADS="$ROOT/uploads"

echo "Stopping any running server... (you may need to stop it manually)"

# Remove DB and recreate
if [ -f "$DB" ]; then
  echo "Removing existing DB: $DB"
  rm -f "$DB"
fi

echo "Creating fresh DB from schema"
sqlite3 "$DB" < "$SCHEMA"

# Clean uploads and seed with default images
if [ -d "$UPLOADS" ]; then
  echo "Cleaning uploads folder: $UPLOADS"
  rm -rf "$UPLOADS"
fi
mkdir -p "$UPLOADS"

# Seed a default avatar placeholder
cat > "$UPLOADS/default.jpg" <<'EOF'

# (placeholder) You can replace these files with actual production images.
EOF

# Seed sample accounts
python3 - <<PY
import sqlite3
conn = sqlite3.connect('$DB')
cur = conn.cursor()

# Insert sample users
cur.execute("INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)", ('prod_user', 'Prod User', 'prod@example.com', 'default.jpg', ''))
cur.execute("INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)", ('alice', 'Alice Example', 'alice@example.com', 'default.jpg', ''))

conn.commit()
print('Seeded users: prod_user, alice')
conn.close()
PY

echo "Reset complete. Start the server with: python3 app.py   (default port 5000)"
