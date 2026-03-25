#!/usr/bin/env python3
"""Seed the sqlite database with mock users and synthetic content.

Creates `kiwifruit.db` next to this script using `schema.sql` then inserts
5 demo users (password stored as literal 'password') and a few posts,
likes, comments, and follows so the app has visible shared data.

Focus session testing
---------------------
Log in as alice (password: password).
alice follows bob, so she will see bob's active session in the Focus tab "Join" section:
  - Bob is reading "Dune" (started ~45 min ago) — Carol joined 25 min ago and is inside.
    The session badge shows 45 min (bob's time — always the longest since he started first).
    Carol has no separate session; she is a participant inside bob's session.
alice can tap the row to join. Her own timer starts at 0 regardless of bob's elapsed time.
"""
import os
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone

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

    # Add a few posts for different users
    posts = []
    now = datetime.now(timezone.utc).replace(tzinfo=None).strftime('%Y-%m-%d %H:%M:%S')
    sample_captions = [
        'Sunset over the hill',
        'My lunch today',
        'Hiking adventures',
        'Coffee time',
        'City skyline'
    ]
    for i, (u, _, _) in enumerate(users):
        filename = f'post{i+1}.jpg'
        cur.execute('INSERT INTO posts (filename, owner, caption, created) VALUES (?, ?, ?, ?)', (filename, u, sample_captions[i % len(sample_captions)], now))
        posts.append(cur.lastrowid)

    # Likes: give each post some likes from other users
    for pid in posts:
        for liker, _, _ in users:
            # make some variety: only some users like some posts
            if (hash(f"{pid}-{liker}") % 3) == 0:
                try:
                    cur.execute('INSERT INTO likes (owner, postid, created) VALUES (?, ?, ?)', (liker, pid, now))
                except sqlite3.IntegrityError:
                    pass

    # Comments: add a couple of comments per post
    for pid in posts:
        for j, (u, _, _) in enumerate(users):
            if j % 2 == 0:
                cur.execute('INSERT INTO comments (owner, postid, text, created) VALUES (?, ?, ?, ?)', (u, pid, f'Nice post {pid} by {u}', now))

    # Following relationships
    follows = [('alice', 'bob'), ('alice', 'carol'), ('alice', 'dave'), ('alice', 'eve'), ('bob', 'alice'), ('carol', 'dave'), ('eve', 'alice'), ('grace', 'bob')]
    for f in follows:
        try:
            cur.execute('INSERT INTO following (follower, followee, created) VALUES (?, ?, ?)', (f[0], f[1], now))
        except sqlite3.IntegrityError:
            pass

    # ------------------------------------------------------------------ #
    # Active reading sessions for focus-session testing                   #
    # ------------------------------------------------------------------ #
    # bob's session: started 45 min ago. carol joined 25 min later (20 min ago).
    # The Join feed shows the LONGEST elapsed time — bob's 45 min — because
    # host_elapsed_seconds is always the max (host started first by definition).
    # Carol has no separate session; she is inside bob's session as a participant.
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    bob_session_id = uuid.uuid4().hex
    bob_started = (now_utc - timedelta(minutes=45)).strftime('%Y-%m-%d %H:%M:%S')
    carol_joined = (now_utc - timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')
    cur.execute(
        'INSERT INTO reading_sessions (session_id, host, book_title, started_at, status) VALUES (?, ?, ?, ?, ?)',
        (bob_session_id, 'bob', 'Dune', bob_started, 'active')
    )
    cur.execute(
        'INSERT INTO session_participants (session_id, username, joined_at) VALUES (?, ?, ?)',
        (bob_session_id, 'carol', carol_joined)
    )

    dave_session_id = uuid.uuid4().hex
    dave_started = (now_utc - timedelta(minutes=20)).strftime('%Y-%m-%d %H:%M:%S')
    cur.execute(
        'INSERT INTO reading_sessions (session_id, host, book_title, started_at, status) VALUES (?, ?, ?, ?, ?)',
        (dave_session_id, 'dave', 'The Great Gatsby', dave_started, 'active')
    )

    eve_session_id = uuid.uuid4().hex
    eve_started = (now_utc - timedelta(minutes=2)).strftime('%Y-%m-%d %H:%M:%S')
    cur.execute(
        'INSERT INTO reading_sessions (session_id, host, book_title, started_at, status) VALUES (?, ?, ?, ?, ?)',
        (eve_session_id, 'eve', '1984', eve_started, 'active')
    )

    # ------------------------------------------------------------------ #
    # Recommendation catalog + demo session_history for alice             #
    # ------------------------------------------------------------------ #
    catalog = [
        ('Dune', 'Frank Herbert', 'sci-fi', 'https://covers.openlibrary.org/b/isbn/9780441172719-M.jpg'),
        ('1984', 'George Orwell', 'dystopian', 'https://covers.openlibrary.org/b/isbn/9780451524935-M.jpg'),
        ('The Great Gatsby', 'F. Scott Fitzgerald', 'classic', 'https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg'),
        ('Pride and Prejudice', 'Jane Austen', 'classic', 'https://covers.openlibrary.org/b/isbn/9780141439518-M.jpg'),
        ('The Hobbit', 'J.R.R. Tolkien', 'fantasy', 'https://covers.openlibrary.org/b/isbn/9780345339683-M.jpg'),
        ('Murder on the Orient Express', 'Agatha Christie', 'mystery', 'https://covers.openlibrary.org/b/isbn/9780062693662-M.jpg'),
        ('The Catcher in the Rye', 'J.D. Salinger', 'fiction', 'https://covers.openlibrary.org/b/isbn/9780316769177-M.jpg'),
        ('To Kill a Mockingbird', 'Harper Lee', 'fiction', 'https://covers.openlibrary.org/b/isbn/9780061120084-M.jpg'),
        ('Foundation', 'Isaac Asimov', 'sci-fi', 'https://covers.openlibrary.org/b/isbn/9780553293357-M.jpg'),
        ('Neuromancer', 'William Gibson', 'sci-fi', 'https://covers.openlibrary.org/b/isbn/9780441569595-M.jpg'),
        ('The Lord of the Rings', 'J.R.R. Tolkien', 'fantasy', 'https://covers.openlibrary.org/b/isbn/9780618640157-M.jpg'),
        ('Jane Eyre', 'Charlotte Brontë', 'classic', 'https://covers.openlibrary.org/b/isbn/9780141441146-M.jpg'),
        ('Crime and Punishment', 'Fyodor Dostoevsky', 'classic', 'https://covers.openlibrary.org/b/isbn/9780486415871-M.jpg'),
        ('The Handmaid\'s Tale', 'Margaret Atwood', 'dystopian', 'https://covers.openlibrary.org/b/isbn/9780385490818-M.jpg'),
        ('Educated', 'Tara Westover', 'memoir', 'https://covers.openlibrary.org/b/isbn/9780399590504-M.jpg'),
        ('Sapiens', 'Yuval Noah Harari', 'nonfiction', 'https://covers.openlibrary.org/b/isbn/9780062316110-M.jpg'),
        ('Thinking, Fast and Slow', 'Daniel Kahneman', 'nonfiction', 'https://covers.openlibrary.org/b/isbn/9780374533557-M.jpg'),
        ('The Name of the Wind', 'Patrick Rothfuss', 'fantasy', 'https://covers.openlibrary.org/b/isbn/9780756404741-M.jpg'),
        ('Circe', 'Madeline Miller', 'fantasy', 'https://covers.openlibrary.org/b/isbn/9780316556347-M.jpg'),
        ('Project Hail Mary', 'Andy Weir', 'sci-fi', 'https://covers.openlibrary.org/b/isbn/9780593135204-M.jpg'),
    ]
    for title, author, genre, cover in catalog:
        cur.execute(
            'INSERT INTO catalog_books (title, author, genre, cover_url) VALUES (?, ?, ?, ?)',
            (title, author, genre, cover),
        )

    hist_time = now_utc.strftime('%Y-%m-%d %H:%M:%S')
    # Alice has completed sessions for Dune + 1984 — recommendations exclude / deprioritize these
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
    print("  alice follows bob (~45min, carol inside), dave (~20min), eve (~2min) — all appear in the Join feed")
    print("  frank / password  — no follows, Join feed is empty")
    print("  grace / password  — follows bob, sees bob's Dune session (~45min) in the Join feed")
    print()
    print("Recommendations (Discover tab):")
    print("  alice has session_history for Dune + 1984; GET /recommendations excludes those and boosts genre.")

if __name__ == '__main__':
    main()
