#!/usr/bin/env python3
"""Seed the sqlite database with mock users and synthetic content.

Creates `kiwifruit.db` next to this script using `schema.sql` then inserts
7 demo accounts (password stored as literal 'password') and reading history for recommendations.
"""
import os
import sqlite3
import uuid
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, 'kiwifruit.db')
SCHEMA_PATH = os.path.join(BASE_DIR, 'schema.sql')
EPUB_FOLDER = os.path.join(BASE_DIR, 'uploads', 'epubs')

def main():
    if os.path.exists(DB_PATH):
        print(f"Removing existing DB at {DB_PATH}")
        os.remove(DB_PATH)

    if os.path.exists(EPUB_FOLDER):
        import shutil
        shutil.rmtree(EPUB_FOLDER)
        print(f"Cleared epub uploads at {EPUB_FOLDER}")
    os.makedirs(EPUB_FOLDER, exist_ok=True)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Load schema
    with open(SCHEMA_PATH, 'r') as f:
        schema = f.read()
    cur.executescript(schema)

    # Create 5 users with simple password marker 'password'
    users = [
        ('alice', 'Alice Anderson', 'alice@example.com'),
        ('bob', 'Bob Brown', 'bob@example.com'),
        ('carol', 'Carol Carter', 'carol@example.com'),
        ('dave', 'Dave Dawson', 'dave@example.com'),
        ('eve', 'Eve Evans', 'eve@example.com'),
        ('frank', 'Frank Foster', 'frank@example.com'),
        ('grace', 'Grace Green', 'grace@example.com'),
    ]
    for u, fullname, email in users:
        cur.execute('INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)', (u, fullname, email, 'default.jpg', 'password'))

    # ------------------------------------------------------------------ #
    # Demo session_history for alice (AI /recommendations uses this context) #
    # ------------------------------------------------------------------ #
    # catalog_books is not seeded here; Discover recommendations are AI-driven.

    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    hist_time = now_utc.strftime('%Y-%m-%d %H:%M:%S')
    # Alice has completed sessions for Dune + 1984 — feeds personalization context to the AI
    cur.execute(
        'INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read, ended_at) VALUES (?, ?, ?, ?, ?, ?)',
        (uuid.uuid4().hex, 'alice', 'Dune', 3600, 42, hist_time),
    )
    cur.execute(
        'INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read, ended_at) VALUES (?, ?, ?, ?, ?, ?)',
        (uuid.uuid4().hex, 'alice', '1984', 1800, 20, hist_time),
    )

    conn.commit()
    conn.close()
    print(f"Seeded database created at: {DB_PATH}")
    print()
    print("Focus session test accounts:")
    print("  Login as: alice / password")
    print()
    print("Recommendations (Discover tab):")
    print("  alice has session_history for Dune + 1984; GET /recommendations (AI) uses history + preferences.")

if __name__ == '__main__':
    main()
