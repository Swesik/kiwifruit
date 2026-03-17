PRAGMA foreign_keys = ON;

-- Users table (username is primary key)
CREATE TABLE users (
    username TEXT PRIMARY KEY CHECK (LENGTH(username) <= 20),
    fullname TEXT NOT NULL CHECK (LENGTH(fullname) <= 40),
    email TEXT NOT NULL CHECK (LENGTH(email) <= 40),
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    password TEXT NOT NULL CHECK (LENGTH(password) <= 512),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Posts table with AUTOINCREMENT integer primary key
CREATE TABLE posts (
    postid INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 64),
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    caption TEXT,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE
);

-- Following table (follower / followee)
CREATE TABLE following (
    follower TEXT NOT NULL CHECK (LENGTH(follower) <= 20),
    followee TEXT NOT NULL CHECK (LENGTH(followee) <= 20),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower, followee),
    FOREIGN KEY (follower) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (followee) REFERENCES users (username) ON DELETE CASCADE
);

-- Comments table with AUTOINCREMENT integer primary key
CREATE TABLE comments (
    commentid INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid INTEGER NOT NULL,
    text TEXT NOT NULL CHECK (LENGTH(text) <= 1024),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE
);

-- Likes table with AUTOINCREMENT integer primary key; enforce one-like-per-user-per-post
CREATE TABLE likes (
    likeid INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    postid INTEGER NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE,
    FOREIGN KEY (postid) REFERENCES posts (postid) ON DELETE CASCADE,
    UNIQUE (owner, postid)
);

-- Sessions table for token mapping (simple session storage)
CREATE TABLE sessions (
    token TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Reading sessions table capturing focused reading activity.
-- Each row represents a single in-app reading session summary. this is filler I dont know what goes here yet - Anurag
CREATE TABLE reading_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL CHECK (LENGTH(username) <= 20),
    book_id TEXT,
    source TEXT CHECK (LENGTH(source) <= 32),
    started_at DATETIME,
    ended_at DATETIME,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Optional mood-map summary table keyed by reading session.
-- This keeps the schema ready for CV-derived mood features without
-- requiring them for every session. this is filler I dont know what goes here yet - Anurag
CREATE TABLE mood_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reading_session_id INTEGER NOT NULL,
    avg_valence REAL,
    volatility REAL,
    dominant_emotion TEXT CHECK (LENGTH(dominant_emotion) <= 32),
    frames_observed INTEGER,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reading_session_id) REFERENCES reading_sessions (id) ON DELETE CASCADE
);
