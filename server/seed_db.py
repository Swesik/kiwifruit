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


def main():
   if os.path.exists(DB_PATH):
       print(f"Removing existing DB at {DB_PATH}")
       os.remove(DB_PATH)


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
   follows = [('alice', 'bob'), ('alice', 'carol'), ('bob', 'alice'), ('carol', 'dave'), ('eve', 'alice')]
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
   # Seed an active host session for bob (45 min elapsed) and a participant carol
   # Note: elapsed_seconds included for testing real-time displays; the client
   # will still only count completed sessions for challenge auto-complete unless
   # requested via the new status parameter.
   cur.execute(
       'INSERT INTO reading_sessions (session_id, host, book_title, started_at, status, elapsed_seconds) VALUES (?, ?, ?, ?, ?, ?)',
       (bob_session_id, 'bob', 'Dune', bob_started, 'active', 45 * 60)
   )
   cur.execute(
       'INSERT INTO session_participants (session_id, username, joined_at) VALUES (?, ?, ?)',
       (bob_session_id, 'carol', carol_joined)
   )

   # Also seed one completed session for alice to allow testing of automatic
   # challenge completion logic (clients requesting completed sessions will
   # receive this entry and can compute progress from elapsed_seconds).
   alice_session_id = uuid.uuid4().hex
   alice_started = (now_utc - timedelta(hours=2)).strftime('%Y-%m-%d %H:%M:%S')
   cur.execute(
       'INSERT INTO reading_sessions (session_id, host, book_title, started_at, status, elapsed_seconds) VALUES (?, ?, ?, ?, ?, ?)',
       (alice_session_id, 'alice', 'Sample Complete', alice_started, 'completed', 60 * 60)
   )


   conn.commit()
   conn.close()
   print(f"Seeded database created at: {DB_PATH}")
   print()
   print("Focus session test accounts:")
   print("  Login as: alice / password")
   print("  alice follows bob — bob's session (Dune, ~45min, carol already inside) appears in the Join feed")


if __name__ == '__main__':
   main()



