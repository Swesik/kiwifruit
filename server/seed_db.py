#!/usr/bin/env python3
"""Seed the sqlite database with mock users and synthetic content.

Creates `kiwifruit.db` next to this script using `schema.sql` then inserts
5 demo users (password stored as literal 'password') and a few posts,
likes, comments, and follows so the app has visible shared data.
"""
import os
import sqlite3
from datetime import datetime

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
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
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

    conn.commit()
    conn.close()
    print(f"Seeded database created at: {DB_PATH}")

if __name__ == '__main__':
    main()
