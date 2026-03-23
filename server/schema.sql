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

-- Reading sessions created by a user (focus tab)
CREATE TABLE reading_sessions (
    session_id TEXT PRIMARY KEY,
    host TEXT NOT NULL,
    book_title TEXT NOT NULL CHECK (LENGTH(book_title) <= 256),
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
    elapsed_seconds INTEGER,
    resumed_at DATETIME,
    FOREIGN KEY (host) REFERENCES users (username) ON DELETE CASCADE
);

-- Permanent record of every completed reading session per user
CREATE TABLE session_history (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    book_title TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL,
    pages_read INTEGER,
    ended_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Friends who joined a reading session (many-to-many)
CREATE TABLE session_participants (
    session_id TEXT NOT NULL,
    username TEXT NOT NULL,
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (session_id, username),
    FOREIGN KEY (session_id) REFERENCES reading_sessions (session_id) ON DELETE CASCADE,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Seed catalog for recommendations (not user uploads; see epubs)
CREATE TABLE catalog_books (
    book_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL CHECK (LENGTH(title) <= 512),
    author TEXT NOT NULL CHECK (LENGTH(author) <= 512),
    genre TEXT NOT NULL DEFAULT '' CHECK (LENGTH(genre) <= 128),
    cover_url TEXT NOT NULL CHECK (LENGTH(cover_url) <= 1024)
-- Books the user has marked as fully completed
CREATE TABLE completed_books (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    book_title TEXT NOT NULL CHECK (LENGTH(book_title) <= 256),
    completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Epub uploads table (tracks uploaded epub files and parsing state)
CREATE TABLE epubs (
    epubid INTEGER PRIMARY KEY AUTOINCREMENT,
    owner TEXT NOT NULL CHECK (LENGTH(owner) <= 20),
    title TEXT NOT NULL DEFAULT '' CHECK (LENGTH(title) <= 512),
    author TEXT NOT NULL DEFAULT '' CHECK (LENGTH(author) <= 512),
    original_filename TEXT NOT NULL CHECK (LENGTH(original_filename) <= 256),
    stored_filename TEXT NOT NULL CHECK (LENGTH(stored_filename) <= 128),
    status TEXT NOT NULL DEFAULT 'LOADING' CHECK (status IN ('LOADING', 'PARSED', 'FAILED')),
    error_message TEXT,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner) REFERENCES users (username) ON DELETE CASCADE
);

-- Epub chapters table (one row per chapter, text stored as .txt file on disk)
CREATE TABLE epub_chapters (
    chapterid INTEGER PRIMARY KEY AUTOINCREMENT,
    epubid INTEGER NOT NULL,
    chapter_number INTEGER NOT NULL,
    title TEXT NOT NULL DEFAULT '' CHECK (LENGTH(title) <= 512),
    filename TEXT NOT NULL CHECK (LENGTH(filename) <= 128),
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (epubid) REFERENCES epubs (epubid) ON DELETE CASCADE
);
