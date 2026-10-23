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
    mood TEXT CHECK (mood IN ('focused', 'inspired', 'tired')),
    ended_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Seed catalog for recommendations.
CREATE TABLE catalog_books (
    book_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL CHECK (LENGTH(title) <= 512),
    author TEXT NOT NULL CHECK (LENGTH(author) <= 512),
    genre TEXT NOT NULL DEFAULT '' CHECK (LENGTH(genre) <= 128),
    cover_url TEXT NOT NULL CHECK (LENGTH(cover_url) <= 1024)
);
-- Books the user has marked as fully completed
CREATE TABLE completed_books (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    book_title TEXT NOT NULL CHECK (LENGTH(book_title) <= 256),
    completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Private post-session reflections
CREATE TABLE reflections (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    book_title TEXT NOT NULL CHECK (LENGTH(book_title) <= 256),
    title TEXT CHECK (title IS NULL OR LENGTH(title) <= 120),
    prompt TEXT NOT NULL,
    response TEXT NOT NULL CHECK (LENGTH(response) <= 2000),
    mood TEXT CHECK (mood IN ('focused', 'inspired', 'tired')),
    duration_minutes INTEGER,
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility = 'private'),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users (username) ON DELETE CASCADE
);

-- Book description cache (to avoid rate-limiting external APIs)
CREATE TABLE book_description_cache (
    cache_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL CHECK (LENGTH(title) <= 256),
    author TEXT NOT NULL CHECK (LENGTH(author) <= 256),
    description TEXT NOT NULL,
    fetched_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(title, author)
);
