import os
import uuid
import hashlib
import sqlite3
import logging
import json
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from flask import Flask, request, jsonify, g, abort, send_from_directory, make_response
from werkzeug.exceptions import HTTPException
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

try:
    from .ai_recommendations import generate_book_recommendations, calculate_behavioral_signals
except ImportError:
    # Support running as a script: `python app.py`
    from ai_recommendations import generate_book_recommendations, calculate_behavioral_signals
import urllib.request
import urllib.parse
import json

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, 'kiwifruit.db')
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Basic logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("kiwifruit")

GENRE_KEYWORDS = [
    ("sci-fi", ["science fiction", "sci fi", "sci-fi", "sf"]),
    ("fantasy", ["fantasy", "magic", "dragon"]),
    ("mystery", ["mystery", "detective", "crime", "thriller"]),
    ("classic", ["classic", "victorian", "19th century"]),
    ("dystopian", ["dystopia", "dystopian", "post-apocalyptic"]),
    ("memoir", ["memoir", "autobiography"]),
    ("nonfiction", ["nonfiction", "non-fiction", "history", "biography", "science"]),
    ("fiction", ["fiction", "literary"]),
    ("romance", ["romance", "love story"]),
]
DEFAULT_RECOMMENDATION_GENRES = ["fiction", "fantasy", "sci-fi", "mystery", "classic", "romance"]
DEFAULT_COVER_URL = "https://picsum.photos/seed/kiwifruit-book/240/360"


def _pick_isbn13(isbns):
    if not isinstance(isbns, list):
        return None
    for value in isbns:
        if value is None:
            continue
        candidate = ''.join(ch for ch in str(value) if ch.isdigit())
        if len(candidate) == 13:
            return candidate
    return None


def _normalize_genres(raw_values):
    """Map provider subject labels to app canonical genres."""
    if not isinstance(raw_values, list):
        return None

    found = []
    for raw in raw_values:
        text = str(raw or "").strip().lower()
        if not text:
            continue
        for canonical, keywords in GENRE_KEYWORDS:
            if any(keyword in text for keyword in keywords):
                if canonical not in found:
                    found.append(canonical)
                break
    return found or None


def _fetch_json(url, timeouts, log_prefix, query):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "kiwifruit/1.0 (+https://github.com/Swesik/kiwifruit)"}
    )
    for attempt, timeout_seconds in enumerate(timeouts, start=1):
        try:
            with urllib.request.urlopen(req, timeout=timeout_seconds) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            logger.warning(
                "%s upstream failed: provider_url=%r query=%r attempt=%d timeout=%ss error=%s",
                log_prefix,
                url,
                query,
                attempt,
                timeout_seconds,
                e,
            )
    return None


def _openlibrary_cover_url(cover_id):
    try:
        parsed = int(cover_id)
    except Exception:
        return None
    if parsed <= 0:
        return None
    return f"https://covers.openlibrary.org/b/id/{parsed}-M.jpg"


def _external_candidates_for_query(query, limit, log_prefix):
    """Fetch candidate books from Open Library with Gutendex fallback."""
    params = urllib.parse.urlencode({
        "q": query,
        "limit": limit,
        "fields": "key,title,author_name,subject,cover_i",
    })
    openlibrary_url = f"https://openlibrary.org/search.json?{params}"

    payload = _fetch_json(openlibrary_url, (4,), log_prefix, query)
    if isinstance(payload, dict):
        docs = payload.get('docs', [])
        results = []
        for doc in docs:
            if not isinstance(doc, dict):
                continue
            title = (doc.get('title') or '').strip()
            if not title:
                continue
            authors = doc.get('author_name')
            if not isinstance(authors, list) or len(authors) == 0:
                authors = None
            genres = _normalize_genres(doc.get('subject'))
            cover_url = _openlibrary_cover_url(doc.get('cover_i')) or DEFAULT_COVER_URL
            work_key = doc.get('key')
            result_id = work_key.strip() if isinstance(work_key, str) and work_key.strip() else uuid.uuid4().hex
            results.append({
                'id': result_id,
                'title': title,
                'authors': authors,
                'isbn13': _pick_isbn13(doc.get('isbn')),
                'genres': genres,
                'cover_url': cover_url,
            })
            if len(results) >= limit:
                break
        if results:
            return results

    gutendex_url = "https://gutendex.com/books?" + urllib.parse.urlencode({
        "search": query
    })
    fallback_payload = _fetch_json(gutendex_url, (90,), log_prefix, query)
    if isinstance(fallback_payload, dict):
        items = fallback_payload.get('results', [])
        fallback_results = []
        for item in items:
            if not isinstance(item, dict):
                continue
            title = (item.get('title') or '').strip()
            if not title:
                continue

            raw_authors = item.get('authors') if isinstance(item.get('authors'), list) else []
            authors = []
            for author in raw_authors:
                if not isinstance(author, dict):
                    continue
                name = (author.get('name') or '').strip()
                if name:
                    authors.append(name)
            normalized_authors = authors if authors else None

            subjects = item.get('subjects') if isinstance(item.get('subjects'), list) else None
            genres = _normalize_genres(subjects)

            formats = item.get('formats') if isinstance(item.get('formats'), dict) else {}
            cover_url = formats.get('image/jpeg') or DEFAULT_COVER_URL

            fallback_results.append({
                'id': f"gutendex:{item.get('id', uuid.uuid4().hex)}",
                'title': title,
                'authors': normalized_authors,
                'isbn13': None,
                'genres': genres,
                'cover_url': cover_url,
            })
            if len(fallback_results) >= limit:
                break
        if fallback_results:
            return fallback_results

    return []


def _hydrate_catalog_from_external(db, preferred_genres, target_new_rows):
    """Populate catalog_books from external sources when candidate pool is small."""
    if target_new_rows <= 0:
        return 0

    queries = [g for g in (preferred_genres or []) if isinstance(g, str) and g.strip()]
    if not queries:
        queries = DEFAULT_RECOMMENDATION_GENRES

    existing_keys = {
        (row['title'].strip().lower(), row['author'].strip().lower())
        for row in db.execute('SELECT title, author FROM catalog_books').fetchall()
    }

    inserted = 0
    per_query_limit = max(6, min(20, target_new_rows))
    for query in queries:
        candidates = _external_candidates_for_query(query, per_query_limit, "recommendations/hydrate")
        for candidate in candidates:
            title = (candidate.get('title') or '').strip()
            if not title:
                continue
            authors = candidate.get('authors')
            author = (authors[0] if isinstance(authors, list) and authors else "Unknown Author").strip()
            if not author:
                author = "Unknown Author"
            dedupe_key = (title.lower(), author.lower())
            if dedupe_key in existing_keys:
                continue

            genres = candidate.get('genres')
            primary_genre = genres[0] if isinstance(genres, list) and genres else str(query).strip().lower()
            if not primary_genre:
                primary_genre = "fiction"
            cover_url = candidate.get('cover_url') or DEFAULT_COVER_URL
            db.execute(
                'INSERT INTO catalog_books (title, author, genre, cover_url) VALUES (?, ?, ?, ?)',
                (title, author, primary_genre, cover_url)
            )
            existing_keys.add(dedupe_key)
            inserted += 1
            if inserted >= target_new_rows:
                return inserted
    return inserted

def get_db():
    """Return the SQLite database connection for the current app context.

    Creates a new connection if one does not already exist, storing it on
    Flask's ``g`` object so it is reused within the same request.
    Rows are returned as :class:`sqlite3.Row` objects for dict-style access.

    :returns: Active SQLite database connection.
    :rtype: sqlite3.Connection
    """
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    """Close the database connection at the end of the app context.

    Registered with Flask's teardown mechanism so it runs automatically
    after each request or when the app context is popped.

    :param exception: Any exception that triggered the teardown, or ``None``.
    """
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
    """Initialize the database by executing ``schema.sql``.

    Reads ``schema.sql`` from the same directory as this file and runs it
    against the database inside an app context. Intended to be called once
    on first run when no database file exists yet.
    """
    with app.app_context():
        db = get_db()
        schema_path = os.path.join(BASE_DIR, 'schema.sql')
        with open(schema_path, 'r') as f:
            db.executescript(f.read())


def run_migrations():
    """Apply lightweight, idempotent schema patches to an existing database.

    Databases created before a column was added to ``schema.sql`` won't have
    that column and any query that references it will throw
    ``no such column``. Call this on every app startup (alongside ``init_db``
    if the DB is new) so stale dev/demo databases stay usable without wiping.
    """
    with app.app_context():
        db = get_db()

        def column_exists(table, column):
            rows = db.execute(f"PRAGMA table_info({table})").fetchall()
            return any(row['name'] == column for row in rows)

        # reflections.title was added after the initial schema shipped.
        if not column_exists('reflections', 'title'):
            db.execute("ALTER TABLE reflections ADD COLUMN title TEXT")
            logger.info("migration: added reflections.title")

        db.commit()



def _to_iso(ts):
    # ts is a SQLite DATETIME like 'YYYY-MM-DD HH:MM:SS' or already ISO; return ISO8601 with timezone
    if ts is None:
        return None
    try:
        dt = datetime.strptime(ts, '%Y-%m-%d %H:%M:%S')
        return dt.replace(tzinfo=timezone.utc).isoformat()
    except Exception:
        return ts


@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    """Serve an uploaded file, requiring authentication.

    **GET** ``/uploads/<filename>``

    :param filename: Path to the file inside the uploads folder.
    :type filename: str
    :returns: The requested file.
    :status 200: File returned successfully.
    :status 403: No valid session token provided.
    :status 404: File not found on disk.
    """
    # Require authentication to fetch uploaded files (P2 behavior)
    username = get_username_from_token(request)
    if not username:
        abort(403)
    # send file or 404
    fullpath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if not os.path.exists(fullpath):
        abort(404)
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/users/me', methods=['GET'])
def get_current_session():
    """Return the authenticated user for the current token.

    **GET** ``/users/me``

    Used by the iOS client to validate a stored session token on startup.
    Unlike ``GET /users/<username>``, this endpoint requires a valid token
    and will return 403 if the token is missing or not in the sessions table.

    :returns: JSON user object.
    :status 200: Token is valid; user returned.
    :status 403: Token missing or invalid.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute('SELECT username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(403)
    user = {
        'id': row['username'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['filename'] or 'default.jpg')
    }
    return jsonify(user)


@app.route('/sessions', methods=['POST'])
def create_session():
    """Create a new session (login).

    **POST** ``/sessions``

    Accepts a JSON body with ``username`` and ``password``. Verifies the
    password against the stored salted SHA-512 hash, generates a session
    token, and returns it along with the authenticated user object.
    Also sets an ``httponly`` session cookie for browser clients.

    :json string username: Account username.
    :json string password: Account password (plaintext, hashed server-side).
    :returns: JSON with ``token`` (str) and ``user`` object.
    :status 200: Login successful.
    :status 400: Missing ``username`` or ``password``.
    :status 403: Invalid credentials.
    """
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        abort(400)
    db = get_db()
    # verify username/password
    row = db.execute('SELECT username, fullname, filename, password FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(403)
    stored = row['password'] or ''
    # Allow a simple mock password marker for seeded development users.
    # If the stored password is the literal string 'password', accept when
    # the provided password is also 'password'. This enables simple mock
    # accounts seeded into the repository for demos/testing.
    if stored == 'password':
        if password != 'password':
            abort(403)
    # Support salted format: sha512$<salt>$<hash>
    elif stored.startswith('sha512$'):
        try:
            _prefix, salt, stored_hash = stored.split('$', 2)
            provided_hash = hashlib.sha512((salt + password).encode('utf-8')).hexdigest()
            if provided_hash != stored_hash:
                abort(403)
        except Exception:
            abort(403)
    else:
        # legacy unsalted hash
        provided_hash = hashlib.sha512(password.encode('utf-8')).hexdigest()
        if provided_hash != stored:
            abort(403)

    token = uuid.uuid4().hex
    db.execute('INSERT INTO sessions (token, username) VALUES (?, ?)', (token, username))
    db.commit()
    # Return user where id is the username (username is primary key)
    user = {
        'id': row['username'],
        'username': row['username'],
        'displayName': row['fullname'],
        'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (row['filename'] or 'default.jpg')
    }
    logger.info("session created: username=%s token=%s", username, token)
    resp = make_response(jsonify({'token': token, 'user': user}))
    # also set a session cookie for browser-based pages
    resp.set_cookie('session', token, httponly=True)
    return resp

@app.route('/books/search', methods=['GET'])
def search_books():
    """Search for books by title/author/ISBN (stub).

    **GET** `/books/search?q=<query>`

    Returns a list of mock results. Real search integration is handled in a
    separate workstream.
    """
    q = (request.args.get('q') or '').strip()
    if not q:
        return jsonify([])

    # Try to use Open Library to return real metadata when possible.
    def normalize_isbn(s):
        return ''.join(ch for ch in s if ch.isdigit())

    # Heuristic: if q looks like an ISBN (10 or 13 digits after stripping hyphens),
    # use the ISBN API which returns richer data for a single ISBN.
    isbn_candidate = normalize_isbn(q)
    if len(isbn_candidate) in (10, 13):
        try:
            ol_url = f'https://openlibrary.org/api/books?bibkeys=ISBN:{urllib.parse.quote(isbn_candidate)}&format=json&jscmd=data'
            with urllib.request.urlopen(ol_url, timeout=8) as resp:
                raw = resp.read()
            parsed = json.loads(raw)
            key = f'ISBN:{isbn_candidate}'
            if key in parsed:
                entry = parsed[key]
                title = entry.get('title')
                authors = [a.get('name') for a in entry.get('authors', []) if a.get('name')]
                isbns = []
                identifiers = entry.get('identifiers', {})
                for k in ('isbn_13', 'isbn_10'):
                    for v in identifiers.get(k, []):
                        isbns.append(v)
                isbn13 = None
                for v in isbns:
                    if len(v) == 13:
                        isbn13 = v
                        break
                cover_url = None
                if isinstance(entry.get('cover'), dict):
                    cover = entry.get('cover')
                    cover_url = cover.get('medium') or cover.get('large') or cover.get('small')
                results = [{
                    'id': uuid.uuid4().hex,
                    'title': title or q,
                    'authors': authors or None,
                    'isbn13': isbn13,
                    'cover_url': cover_url
                }]
                return jsonify(results)
        except Exception as e:
            logger.warning('books.search: ISBN lookup failed: %s', e)

    # Free-text search against Open Library.
    try:
        search_url = f'https://openlibrary.org/search.json?q={urllib.parse.quote(q)}&limit=20'
        with urllib.request.urlopen(search_url, timeout=8) as resp:
            raw = resp.read()
        parsed = json.loads(raw)
        docs = parsed.get('docs', [])
        out = []
        for d in docs[:20]:
            title = d.get('title') or d.get('title_suggest') or q
            authors = d.get('author_name') or None
            isbn13 = None
            isbns = d.get('isbn') or []
            for s in isbns:
                sdigits = ''.join(ch for ch in s if ch.isdigit())
                if len(sdigits) == 13:
                    isbn13 = sdigits
                    break
            cover_url = None
            if d.get('cover_i'):
                cover_url = f"https://covers.openlibrary.org/b/id/{d.get('cover_i')}-M.jpg"
            out.append({'id': d.get('key') or uuid.uuid4().hex, 'title': title, 'authors': authors, 'isbn13': isbn13, 'cover_url': cover_url})
        if out:
            return jsonify(out)
    except Exception as e:
        logger.warning('books.search: Open Library search failed: %s', e)

    return jsonify([])


@app.route('/books/description', methods=['GET'])
def get_book_description():
    """Fetch book description from cache or OpenLibrary (two-step process).

    **GET** `/books/description?title=<title>&author=<author>`

    Returns description, title, and author from cache or OpenLibrary search.
    Two-step process:
    1. Search by title + author to get Work ID
    2. Fetch Work JSON to get description
    """
    title = (request.args.get('title') or '').strip()
    author = (request.args.get('author') or '').strip()

    if not title or not author:
        return jsonify({'error': 'title and author required'}), 400

    db = get_db()
    if db is None:
        return jsonify({'description': 'No description available'}), 200

    # Check cache first
    try:
        cursor = db.execute(
            "SELECT description FROM book_description_cache WHERE title = ? AND author = ?",
            (title, author)
        )
        cached = cursor.fetchone()
        if cached:
            logger.info("Book description cache hit: %s by %s", title, author)
            return jsonify({
                'description': cached[0],
                'title': title,
                'author': author,
                'cached': True
            })
    except Exception as e:
        logger.warning("Cache lookup failed: %s", e)

    # Step 1: Search OpenLibrary for the Work key by title + author
    search_params = urllib.parse.urlencode({
        "title": title,
        "author": author,
        "fields": "key,title"
    })
    search_url = f"https://openlibrary.org/search.json?{search_params}"
    logger.info("Step 1 - Searching OpenLibrary: %s", search_url)
    
    try:
        search_data = _fetch_json(search_url, (10, 20, 30), "get_book_description_step1", f"{title} by {author}")
    except Exception as e:
        logger.error("Step 1 failed: %s", e)
        return jsonify({'description': 'No description available'}), 200

    description = 'No description available'
    
    if not isinstance(search_data, dict) or not search_data.get('docs'):
        logger.warning("No search results from OpenLibrary for: %s by %s", title, author)
        return jsonify({'description': description}), 200

    # Get the first result's Work key
    first_result = search_data['docs'][0]
    work_key = first_result.get('key')
    
    if not work_key:
        logger.warning("No work key found in search result")
        return jsonify({'description': description}), 200

    # Step 2: Fetch the Work JSON to get description
    work_url = f"https://openlibrary.org{work_key}.json"
    logger.info("Step 2 - Fetching Work JSON: %s", work_url)
    
    try:
        work_data = _fetch_json(work_url, (10, 20, 30), "get_book_description_step2", work_key)
    except Exception as e:
        logger.error("Step 2 failed: %s", e)
        return jsonify({'description': description}), 200

    if isinstance(work_data, dict):
        # Handle both string and dict description formats from OpenLibrary
        desc_value = work_data.get('description')
        if isinstance(desc_value, dict):
            description = desc_value.get('value', description)
        elif isinstance(desc_value, str):
            description = desc_value
    
    if description and description != 'No description available':
        logger.info("Found description from OpenLibrary: %s...", description[:100])
        
        # Cache the result
        try:
            db.execute(
                "INSERT OR IGNORE INTO book_description_cache (title, author, description) VALUES (?, ?, ?)",
                (title, author, description)
            )
            db.commit()
            logger.info("Cached description for: %s by %s", title, author)
        except Exception as e:
            logger.warning("Failed to cache book description: %s", e)

    return jsonify({
        'description': description,
        'title': title,
        'author': author,
        'cached': False
    })



@app.route('/recommendations', methods=['GET'])
def get_recommendations():
    """Return personalized book recommendations for the authenticated user.

    **GET** ``/recommendations``

    Query params: ``limit`` (default 8, max 20).

    Uses AI to generate personalized book recommendations based on user's 
    reading history and preferences. Fetches cover URLs from OpenLibrary.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    try:
        limit = int(request.args.get('limit', 8))
    except (TypeError, ValueError):
        limit = 8
    limit = max(1, min(limit, 20))

    db = get_db()
    
    # Fetch user's reading history (most recent first)
    history = db.execute(
        'SELECT book_title, duration_seconds, pages_read FROM session_history WHERE username = ? ORDER BY ended_at DESC',
        (username,),
    ).fetchall()

    # Preferences are stored on-device and are not available to the server.
    preferred_genres = []

    # Build user context for AI
    recent_books = [h['book_title'] for h in history][:10]
    behavioral_signals = calculate_behavioral_signals(history)
    
    user_context = {
        'reading_history': recent_books,
        'preferred_genres': preferred_genres or [],
        'behavioral_signals': behavioral_signals
    }

    # Get AI-generated recommendations
    ai_recommendations = generate_book_recommendations(user_context, limit=limit)
    
    if not ai_recommendations:
        logger.warning('AI recommendations failed for user=%s', username)
        # Fallback: return empty list (API key not set or AI call failed)
        return jsonify([])

    # Enrich each recommendation with cover URL from OpenLibrary
    payload = []
    for i, rec in enumerate(ai_recommendations):
        book_id = i + 1  # Use simple integer ID instead of UUID
        title = rec.get('title', 'Unknown')
        author = rec.get('author', 'Unknown Author')
        genre = rec.get('genre', 'fiction')
        reason = rec.get('reason', f'Based on your preferences, try this {genre} book.')
        
        # Try to fetch cover URL from OpenLibrary
        cover_url = _fetch_cover_url_for_book(title, author) or DEFAULT_COVER_URL
        
        payload.append({
            'book_id': book_id,
            'title': title,
            'author': author,
            'genre': genre,
            'cover_url': cover_url,
            'why_recommended': reason
        })
    
    logger.info(
        'recommendations: ai_recommendations_returned=%d history_rows=%d total_hours=%s avg_session=%s reader_type=%s genres=%s user=%s',
        len(payload),
        behavioral_signals.get('total_books', 0),
        behavioral_signals.get('total_hours', 0),
        behavioral_signals.get('avg_reading_session_minutes', 0),
        behavioral_signals.get('reading_frequency', 'unknown'),
        preferred_genres,
        username,
    )
    return jsonify(payload)


def _fetch_cover_url_for_book(title, author):
    """Fetch cover URL from OpenLibrary for a given title and author.
    
    :param title: Book title
    :param author: Book author
    :returns: Cover URL string or None if not found
    """
    try:
        params = urllib.parse.urlencode({
            'title': title,
            'author': author,
            'limit': 1,
            'fields': 'cover_i'
        })
        url = f"https://openlibrary.org/search.json?{params}"
        
        data = _fetch_json(url, (3, 5), "fetch_cover_url", f"{title} by {author}")
        
        if isinstance(data, dict) and data.get('docs'):
            cover_id = data['docs'][0].get('cover_i')
            if cover_id:
                return _openlibrary_cover_url(cover_id)
    except Exception as e:
        logger.debug(f"Failed to fetch cover for {title}: {e}")
    
    return None


@app.route('/users', methods=['POST'])
def create_user():
    """Create a new user account.

    **POST** ``/users``

    Stores a salted SHA-512 password hash. Returns 409 if the username is
    already taken.

    :json string username: Desired username (required).
    :json string password: Account password in plaintext (required, hashed server-side).
    :json string fullname: Display name (optional, defaults to username).
    :json string email: Email address (optional, defaults to ``<username>@example.com``).
    :returns: JSON user object with ``id``, ``username``, ``displayName``,
              and ``avatarURL``.
    :status 201: User created successfully.
    :status 400: Missing ``username`` or ``password``.
    :status 409: Username already exists.
    """
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')
    fullname = data.get('fullname') or username
    email = data.get('email') or f"{username}@example.com"
    if not username or not password:
        abort(400)
    db = get_db()
    # check uniqueness
    if db.execute('SELECT 1 FROM users WHERE username = ?', (username,)).fetchone():
        return jsonify({'error': 'username_conflict'}), 409
    # generate per-user salt and store as sha512$<salt>$<hash>
    salt = uuid.uuid4().hex
    pw_hash_raw = hashlib.sha512((salt + password).encode('utf-8')).hexdigest()
    pw_hash = f"sha512${salt}${pw_hash_raw}"
    filename = 'default.jpg'
    db.execute('INSERT INTO users (username, fullname, email, filename, password) VALUES (?, ?, ?, ?, ?)', (username, fullname, email, filename, pw_hash))
    db.commit()
    user = {'id': username, 'username': username, 'displayName': fullname, 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + filename}
    logger.info('user created: username=%s', username)
    return jsonify(user), 201


@app.route('/users/<username>', methods=['PUT'])
def update_user(username):
    """Update a user's profile information.

    **PUT** ``/users/<username>``

    Only the authenticated account owner may update their own profile.
    Fields not present in the request body are left unchanged.

    :param username: The username of the account to update.
    :type username: str
    :json string fullname: New display name (optional).
    :json string email: New email address (optional).
    :returns: JSON user object reflecting the updated profile.
    :status 200: Profile updated and returned.
    :status 403: Not authenticated or not the account owner.
    :status 404: User not found.
    """
    current = get_username_from_token(request)
    if not current:
        abort(403)
    db = get_db()
    row = db.execute('SELECT username FROM users WHERE username = ?', (username,)).fetchone()
    if not row:
        abort(404)
    if row['username'] != current:
        abort(403)
    data = request.get_json() or {}
    fullname = data.get('fullname')
    email = data.get('email')
    updates = []
    params = []
    if fullname is not None:
        updates.append('fullname = ?')
        params.append(fullname)
    if email is not None:
        updates.append('email = ?')
        params.append(email)
    if updates:
        params.append(username)
        sql = 'UPDATE users SET ' + ', '.join(updates) + ' WHERE username = ?'
        db.execute(sql, params)
        db.commit()
    newrow = db.execute('SELECT username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    user = {'id': newrow['username'], 'username': newrow['username'], 'displayName': newrow['fullname'], 'avatarURL': request.host_url.rstrip('/') + '/uploads/' + (newrow['filename'] or 'default.jpg')}
    return jsonify(user)

@app.route('/books/scan', methods=['POST'])
def capture_book_scan():
    """Receive a camera-derived book scan payload for later processing.

    **POST** ``/books/scan``

    Accepts JSON containing either:
    - ``barcode``: detected EAN-13 string
    - ``ocrText``: OCR-extracted candidate title/author text

    At least one payload field must be present.

    :json string barcode: Detected EAN-13 barcode value (optional).
    :json string ocrText: OCR candidate text payload (optional).
    :returns: JSON echoing the accepted payload.
    :status 200: Payload accepted.
    :status 400: Missing both barcode and OCR text.
    """
    data = request.get_json() or {}
    barcode = data.get('barcode')
    ocr_text = data.get('ocrText')

    if not barcode and not ocr_text:
        return jsonify({
            'message': 'Missing scan payload',
            'status_code': 400
        }), 400

    logger.info('book scan captured: barcode=%s ocr_present=%s', barcode, bool(ocr_text))

    return jsonify({
        'status': 'ok',
        'barcode': barcode,
        'ocrText': ocr_text
    })

def _session_dict(session_row, host_row, req):
    """Build the solo ReadingSession JSON object expected by the iOS client."""
    return {
        'id': session_row['session_id'],
        'host': {
            'id': host_row['username'],
            'username': host_row['username'],
            'displayName': host_row['fullname'],
            'avatarURL': req.host_url.rstrip('/') + '/uploads/' + (host_row['filename'] or 'default.jpg')
        },
        'book_title': session_row['book_title'],
        'started_at': _to_iso(session_row['started_at']),
        'status': session_row['status'],
    }


@app.route('/reading-sessions', methods=['POST'])
def create_reading_session():
    """Start a new reading session.

    **POST** ``/reading-sessions``

    :json string book_title: Title of the book being read (required).
    :returns: JSON ``ReadingSession`` object.
    :status 201: Session created.
    :status 400: Missing ``book_title``.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    data = request.get_json() or {}
    book_title = (data.get('book_title') or '').strip()
    if not book_title:
        abort(400)
    db = get_db()
    # Close any existing active sessions for this user before creating a new one.
    # This prevents stale 'active' rows from accumulating (e.g. after a crash or force-quit).
    db.execute(
        "UPDATE reading_sessions SET status = 'completed' WHERE host = ? AND status = 'active'",
        (username,)
    )
    session_id = uuid.uuid4().hex
    db.execute(
        'INSERT INTO reading_sessions (session_id, host, book_title) VALUES (?, ?, ?)',
        (session_id, username, book_title)
    )
    db.commit()
    row = db.execute('SELECT * FROM reading_sessions WHERE session_id = ?', (session_id,)).fetchone()
    host_row = db.execute('SELECT username, fullname, filename FROM users WHERE username = ?', (username,)).fetchone()
    logger.info('reading_session created: session_id=%s host=%s book=%s', session_id, username, book_title)
    return jsonify(_session_dict(row, host_row, request)), 201


@app.route('/reading-sessions/<session_id>/complete', methods=['POST'])
def complete_reading_session(session_id):
    """End a reading session (host only). Elapsed time is calculated server-side.

    **POST** ``/reading-sessions/<session_id>/complete``

    :json string status: Must be ``"completed"``.
    :json int pages_read: Pages read this session (optional).
        :returns: JSON ``{"status": "ok"}``.
    :status 200: Session completed.
    :status 403: Not authenticated or not the session host.
    :status 404: Session not found.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute('SELECT host, status FROM reading_sessions WHERE session_id = ?', (session_id,)).fetchone()
    if not row:
        abort(404)
    if row['host'] != username:
        abort(403)
    data = request.get_json() or {}
    try:
        if data.get('status') == 'completed':
            if row['status'] == 'paused':
                # Elapsed already accumulated on the last pause — just mark completed.
                db.execute(
                    "UPDATE reading_sessions SET status = 'completed' WHERE session_id = ?",
                    (session_id,)
                )
            else:
                # Active: add time since the last resume (or start) to any stored elapsed.
                db.execute(
                    '''UPDATE reading_sessions
                       SET status = 'completed',
                           elapsed_seconds = COALESCE(elapsed_seconds, 0) +
                               CAST((julianday('now') - julianday(COALESCE(resumed_at, started_at))) * 86400 AS INTEGER)
                       WHERE session_id = ?''',
                    (session_id,)
                )
            # Write session summary to history for the host.
            session_row = db.execute(
                'SELECT book_title, elapsed_seconds FROM reading_sessions WHERE session_id = ?',
                (session_id,)
            ).fetchone()
            if session_row:
                db.execute(
                    'INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read, ended_at) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
                    (uuid.uuid4().hex, username, session_row['book_title'], session_row['elapsed_seconds'] or 0, data.get('pages_read'))
                )
                logger.info('session completed: user=%s book=%s duration=%d pages=%s', username, session_row['book_title'], session_row['elapsed_seconds'] or 0, data.get('pages_read'))
        db.commit()
    except Exception:
        db.rollback()
        raise
    return jsonify({'status': 'ok'})


@app.route('/reading-sessions/<session_id>/pause', methods=['POST'])
def pause_reading_session(session_id):
    """Pause an active reading session (host only).

    Accumulates elapsed time server-side using ``julianday`` and sets
    the session status to ``'paused'``.

    **POST** ``/reading-sessions/<session_id>/pause``

    :returns: JSON ``{"status": "ok"}``.
    :status 200: Session paused.
    :status 403: Not authenticated or not the session host.
    :status 404: Session not found or not currently active.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute(
        "SELECT host FROM reading_sessions WHERE session_id = ? AND status = 'active'",
        (session_id,)
    ).fetchone()
    if not row:
        abort(404)
    if row['host'] != username:
        abort(403)
    db.execute(
        '''UPDATE reading_sessions
           SET status = 'paused',
               elapsed_seconds = COALESCE(elapsed_seconds, 0) +
                   CAST((julianday('now') - julianday(COALESCE(resumed_at, started_at))) * 86400 AS INTEGER)
           WHERE session_id = ?''',
        (session_id,)
    )
    db.commit()
    logger.info('reading_session paused: session_id=%s host=%s', session_id, username)
    return jsonify({'status': 'ok'})


@app.route('/reading-sessions/<session_id>/resume', methods=['POST'])
def resume_reading_session(session_id):
    """Resume a paused reading session (host only).

    Sets ``resumed_at`` to the current time so the next pause or completion
    can accurately measure the newly active interval.

    **POST** ``/reading-sessions/<session_id>/resume``

    :returns: JSON ``{"status": "ok"}``.
    :status 200: Session resumed.
    :status 403: Not authenticated or not the session host.
    :status 404: Session not found or not currently paused.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute(
        "SELECT host FROM reading_sessions WHERE session_id = ? AND status = 'paused'",
        (session_id,)
    ).fetchone()
    if not row:
        abort(404)
    if row['host'] != username:
        abort(403)
    db.execute(
        "UPDATE reading_sessions SET status = 'active', resumed_at = CURRENT_TIMESTAMP WHERE session_id = ?",
        (session_id,)
    )
    db.commit()
    logger.info('reading_session resumed: session_id=%s host=%s', session_id, username)
    return jsonify({'status': 'ok'})


@app.route('/session-history', methods=['GET'])
def get_session_history():
    """Return completed reading sessions for the authenticated user.

    **GET** ``/session-history``

    Used by the iOS client to calculate challenge progress (minutes read,
    books completed, pages read) over rolling time windows.

    :returns: JSON list of session history objects ordered by most recent first.
    :status 200: List returned (may be empty).
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    rows = db.execute(
        'SELECT id, book_title, duration_seconds, pages_read, ended_at '
        'FROM session_history WHERE username = ? ORDER BY ended_at DESC',
        (username,)
    ).fetchall()
    return jsonify([{
        'id': r['id'],
        'book_title': r['book_title'],
        'duration_seconds': r['duration_seconds'],
        'pages_read': r['pages_read'],
        'ended_at': _to_iso(r['ended_at'])
    } for r in rows])


@app.route('/completed-books', methods=['POST'])
def add_completed_book():
    """Mark a book as fully completed by the authenticated user.

    **POST** ``/completed-books``

    :json string book_title: Title of the completed book (required).
    :returns: JSON object with the new record id and book_title.
    :status 201: Book recorded.
    :status 400: Missing or empty book_title.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    data = request.get_json(silent=True) or {}
    book_title = (data.get('book_title') or '').strip()
    if not book_title:
        abort(400)
    row_id = uuid.uuid4().hex
    db = get_db()
    db.execute(
        'INSERT INTO completed_books (id, username, book_title) VALUES (?, ?, ?)',
        (row_id, username, book_title)
    )
    db.commit()
    return jsonify({'id': row_id, 'book_title': book_title}), 201


@app.route('/completed-books', methods=['GET'])
def get_completed_books():
    """Return books the authenticated user has marked as completed.

    **GET** ``/completed-books``

    :returns: JSON list ordered by most recent completion first.
    :status 200: List returned (may be empty).
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    rows = db.execute(
        'SELECT id, book_title, completed_at FROM completed_books '
        'WHERE username = ? ORDER BY completed_at DESC',
        (username,)
    ).fetchall()
    return jsonify([{
        'id': r['id'],
        'book_title': r['book_title'],
        'completed_at': _to_iso(r['completed_at'])
    } for r in rows])


@app.route('/adaptive-challenges', methods=['GET'])
def adaptive_challenges():
    """Return a single adaptive challenge based on reading engagement signals. Returns ``available=false`` only when the user has no
    session history at all (nothing to base a recommendation on).

    **GET** ``/adaptive-challenges``

    :returns: JSON with ``available`` bool and optional ``challenge`` object.
    :status 200: Response returned.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    db = get_db()

    rows = db.execute(
        'SELECT duration_seconds, pages_read, ended_at '
        'FROM session_history WHERE username = ? '
        'ORDER BY ended_at ASC',
        (username,)
    ).fetchall()

    # No data at all — nothing to personalize on.
    if not rows:
        return jsonify({'available': False})

    # Use last 14 days for trend analysis; fall back to everything available.
    cutoff = db.execute("SELECT datetime('now', '-14 days')").fetchone()[0]
    recent = [r for r in rows if r['ended_at'] and r['ended_at'] >= cutoff]
    if not recent:
        recent = rows

    total = len(recent)
    durations = [r['duration_seconds'] or 0 for r in recent]
    avg_duration = sum(durations) / total
    pages_list = [r['pages_read'] or 0 for r in recent]
    avg_pages = sum(pages_list) / total if any(pages_list) else 0

    half = total // 2
    if half >= 2:
        first_avg = sum(durations[:half]) / half
        second_avg = sum(durations[half:]) / (total - half)
        dur_trend = (second_avg - first_avg) / first_avg if first_avg > 0 else 0
    else:
        dur_trend = 0

    # Pick the most relevant challenge type and scale based on trend.
    if dur_trend < -0.25:
        branch = 'declining'
        goal_minutes = max(5, round(avg_duration / 60 * 0.75))
        challenge = {
            'title': f'Stay consistent: {goal_minutes} min/day',
            'goalUnit': 'minutes/week',
            'goalCount': goal_minutes * 7,
            'rewardXP': 25,
        }
    elif dur_trend > 0.25:
        branch = 'improving'
        goal_minutes = max(10, round(avg_duration / 60 * 1.3))
        challenge = {
            'title': f'Push further: {goal_minutes} min/day',
            'goalUnit': 'minutes/week',
            'goalCount': goal_minutes * 7,
            'rewardXP': 40,
        }
    else:
        branch = 'stable'
        goal_pages = max(10, round(avg_pages * 7))
        challenge = {
            'title': f'Read {goal_pages} pages this week',
            'goalUnit': 'pages/week',
            'goalCount': goal_pages,
            'rewardXP': 30,
        }

    narrative = _openai_adaptive_narrative(
        branch=branch,
        title=challenge['title'],
        goal_unit=challenge['goalUnit'],
        goal_count=challenge['goalCount'],
        avg_minutes=round(avg_duration / 60, 1),
        avg_pages=round(avg_pages, 1),
        dur_trend_pct=round(dur_trend * 100, 1),
        session_count=total,
    )
    if not narrative:
        return jsonify({'available': False})

    challenge['description'] = narrative['description']
    challenge['reason'] = narrative['reason']
    challenge['adaptive'] = True
    return jsonify({'available': True, 'challenge': challenge})


def _openai_adaptive_narrative(
    branch, title, goal_unit, goal_count,
    avg_minutes, avg_pages, dur_trend_pct,
    session_count,
):
    """Use OpenAI to generate a personalized description + reason for an
    adaptive challenge based on the user's actual stats.

    Returns {'description': str, 'reason': str} on success, None on any failure.
    """
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        return None
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)

        branch_hint = {
            'declining': "User's session duration has dropped noticeably recently — we're scaling back expectations.",
            'improving': "User's session duration is growing — we're nudging them a bit further.",
            'stable': "User has a steady reading rhythm — we're matching their current pace, not pushing harder.",
        }[branch]

        user_msg = (
            f"Generate two short, personalized strings for a reading challenge card.\n\n"
            f"Challenge title: {title}\n"
            f"Goal: {goal_count} {goal_unit}\n"
            f"\n"
            f"User stats over the last {session_count} sessions (≤14 days):\n"
            f"- Average session length: {avg_minutes} minutes\n"
            f"- Average pages per session: {avg_pages}\n"
            f"- Session duration trend vs earlier half: {dur_trend_pct:+.1f}%\n"
            f"\n"
            f"Context for this recommendation: {branch_hint}\n"
            f"\n"
            f"Return a JSON object with exactly two fields:\n"
            f'  "description": a 1-sentence description of the challenge that cites at least one concrete number from the stats above (max 160 chars).\n'
            f'  "reason": a 1-sentence explanation of WHY this specific goal was chosen, grounded in the user\'s actual numbers or pattern (max 160 chars).\n'
            f"\n"
            f"Be specific, warm, and avoid generic phrases. Do not include markdown or prose outside the JSON."
        )

        resp = client.chat.completions.create(
            model=os.environ.get('OPENAI_ADAPTIVE_MODEL', 'gpt-4o-mini'),
            messages=[
                {"role": "system", "content": "You write concise, personalized reading-challenge copy grounded in the user's real stats."},
                {"role": "user", "content": user_msg},
            ],
            max_tokens=200,
            temperature=0.7,
            timeout=8,
            response_format={"type": "json_object"},
        )
        raw = (resp.choices[0].message.content or '').strip()
        data = json.loads(raw)
        description = (data.get('description') or '').strip()
        reason = (data.get('reason') or '').strip()
        if not description or not reason:
            return None
        return {'description': description, 'reason': reason}
    except Exception as e:
        logger.warning(f"OpenAI adaptive narrative failed: {e}")
        return None


def _wmo_condition_label(code):
    """Human-readable condition string for a WMO weather code."""
    if code == 0:       return "clear sky"
    if code in (1, 2):  return "mainly clear"
    if code == 3:       return "overcast"
    if 45 <= code <= 48: return "fog"
    if 51 <= code <= 55: return "drizzle"
    if 56 <= code <= 57: return "freezing drizzle"
    if 61 <= code <= 65: return "rain"
    if 66 <= code <= 67: return "freezing rain"
    if 71 <= code <= 77: return "snow"
    if 80 <= code <= 82: return "rain showers"
    if 85 <= code <= 86: return "snow showers"
    if code == 95:      return "thunderstorm"
    if 96 <= code <= 99: return "thunderstorm with hail"
    return "mixed weather"


def _openai_weather_challenge(condition, temp_c):
    """Ask OpenAI for a weather-inspired reading challenge.

    Returns a challenge dict on success, None on any failure. Failure is
    intentional — per product direction we prefer to show nothing over a
    generic fallback.
    """
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        return None
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)

        user_msg = (
            f"Generate a short reading challenge inspired by today's weather.\n\n"
            f"Current condition: {condition}\n"
            f"Temperature: {temp_c:.0f}°C\n\n"
            f"Return a JSON object with exactly these fields:\n"
            f'  "title": evocative, under 40 characters\n'
            f'  "description": 1 sentence (<= 140 chars) that ties the challenge to the weather\n'
            f'  "reason": 1 sentence (<= 140 chars) explaining why this weather suits this challenge\n'
            f'  "goalUnit": one of "minutes/week", "pages/month", "books/month"\n'
            f'  "goalCount": positive integer goal amount matched to the unit\n'
            f'  "rewardXP": integer between 20 and 50 (harsher weather → higher XP)\n\n'
            f"Be vivid and specific — let the weather shape the wording. No markdown."
        )

        resp = client.chat.completions.create(
            model=os.environ.get('OPENAI_WEATHER_MODEL', 'gpt-4o-mini'),
            messages=[
                {"role": "system", "content": "You write short, atmospheric reading-challenge copy inspired by the current weather."},
                {"role": "user", "content": user_msg},
            ],
            max_tokens=220,
            temperature=0.9,
            timeout=8,
            response_format={"type": "json_object"},
        )
        data = json.loads((resp.choices[0].message.content or '').strip())
        title = (data.get('title') or '').strip()
        description = (data.get('description') or '').strip()
        reason = (data.get('reason') or '').strip()
        goal_unit = (data.get('goalUnit') or '').strip()
        goal_count = int(data.get('goalCount') or 0)
        reward_xp = int(data.get('rewardXP') or 0)

        if not title or not description or not reason:
            return None
        if goal_unit not in ('minutes/week', 'pages/month', 'books/month'):
            return None
        if goal_count <= 0 or reward_xp <= 0:
            return None

        return {
            'title': title,
            'description': description,
            'reason': reason,
            'goalUnit': goal_unit,
            'goalCount': goal_count,
            'rewardXP': min(max(reward_xp, 20), 50),
        }
    except Exception as e:
        logger.warning(f"OpenAI weather challenge failed: {e}")
        return None


@app.route('/weather-challenge', methods=['POST'])
def weather_challenge():
    """Generate an AI-written reading challenge inspired by the user's local
    weather. Returns ``available=false`` on any failure (no template fallback).

    **POST** ``/weather-challenge``

    :json float latitude: User's latitude.
    :json float longitude: User's longitude.
    :returns: JSON ``{ available: bool, challenge?: {...} }`` matching the
              adaptive-challenge shape for easy client reuse.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    data = request.get_json(silent=True) or {}
    lat = data.get('latitude')
    lon = data.get('longitude')
    if lat is None or lon is None:
        return jsonify({'available': False})

    # Fetch current conditions from open-meteo.
    try:
        url = (
            "https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            "&current=weather_code,temperature_2m&forecast_days=1"
        )
        with urllib.request.urlopen(url, timeout=5) as resp:
            payload = json.loads(resp.read().decode('utf-8'))
        current = payload.get('current') or {}
        weather_code = int(current.get('weather_code', 0))
        temp_c = float(current.get('temperature_2m', 20.0))
    except Exception as e:
        logger.warning(f"open-meteo fetch failed: {e}")
        return jsonify({'available': False})

    condition = _wmo_condition_label(weather_code)
    challenge = _openai_weather_challenge(condition, temp_c)
    if not challenge:
        return jsonify({'available': False})

    challenge['weather'] = True
    challenge['conditionLabel'] = f"{condition}, {int(round(temp_c))}°C"
    return jsonify({'available': True, 'challenge': challenge})


def _fallback_reflection_prompt(book_title, duration, pages):
    """Template-based fallback when OpenAI is unavailable."""
    pages_clause = f" and {pages} pages" if pages else ""
    return f"You just spent {duration} minutes{pages_clause} with {book_title}. What stood out?"


def _openai_reflection_prompt(book_title, duration, pages):
    """Call OpenAI to generate a personalized reflection prompt.

    Returns the prompt string on success, or None on any failure.
    """
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        return None
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        pages_clause = f", read {pages} pages" if pages else ""
        user_msg = (
            f"A reader just finished a reading session: book \"{book_title}\", "
            f"{duration} minutes{pages_clause}. "
            "Generate ONE short, warm, open-ended reflection question (under 25 words) "
            "that takes session length and pages read into account. "
            "Return only the question, no preamble."
        )
        resp = client.chat.completions.create(
            model=os.environ.get('OPENAI_PROMPT_MODEL', 'gpt-4o-mini'),
            messages=[
                {"role": "system", "content": "You craft thoughtful, personalized reading reflection prompts."},
                {"role": "user", "content": user_msg},
            ],
            max_tokens=80,
            temperature=0.8,
            timeout=8,
        )
        text = (resp.choices[0].message.content or '').strip().strip('"')
        return text if text else None
    except Exception as e:
        logger.warning(f"OpenAI reflection prompt failed, falling back to template: {e}")
        return None


@app.route('/reflection-prompt', methods=['POST'])
def generate_reflection_prompt():
    """Generate a personalized reflection prompt for the user's recent session.

    **POST** ``/reflection-prompt``

    :json string book_title: Title of the book just read.
    :json int duration_minutes: Session length in minutes.
    :json int pages_read: Pages read this session (optional).
    :returns: JSON with ``prompt`` string and ``source`` ("openai" or "template").
    :status 200: Prompt generated.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    data = request.get_json(silent=True) or {}
    book_title = data.get('book_title', 'your book')
    duration = data.get('duration_minutes', 0)
    pages = data.get('pages_read')

    prompt = _openai_reflection_prompt(book_title, duration, pages)
    source = 'openai'
    if not prompt:
        prompt = _fallback_reflection_prompt(book_title, duration, pages)
        source = 'template'

    return jsonify({'prompt': prompt, 'source': source})


@app.route('/session-summary', methods=['POST'])
def generate_session_summary():
    """Generate a shareable session summary for the user's reading session.

    **POST** ``/session-summary``

    :json string book_title: Title of the book.
    :json int duration_minutes: Session length in minutes.
    :json int pages_read: Pages read (optional).
    :returns: JSON with ``summary`` string.
    :status 200: Summary generated.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)

    data = request.get_json(silent=True) or {}
    book_title = data.get('book_title', 'a book')
    duration = data.get('duration_minutes', 0)
    pages = data.get('pages_read')

    # Build summary text.
    parts = [f"Just read {book_title} for {duration} minutes"]
    if pages:
        parts.append(f"{pages} pages")

    # Fetch streak info.
    db = get_db()
    total_sessions = db.execute(
        'SELECT COUNT(*) as cnt FROM session_history WHERE username = ?',
        (username,)
    ).fetchone()['cnt']

    if total_sessions > 1:
        parts.append(f"Session #{total_sessions} and counting")

    summary = '\n'.join(parts)
    return jsonify({'summary': summary, 'total_sessions': total_sessions})


@app.route('/reflections', methods=['POST'])
def create_reflection():
    """Save a reflection after a reading session.

    **POST** ``/reflections``

    :json string book_title: Title of the book.
    :json string title: Optional reflection title; if omitted the server generates one.
    :json string prompt: The reflection prompt shown to the user.
    :json string response: The user's written reflection.
    :json int duration_minutes: Session duration in minutes (optional).
    :returns: JSON with the created reflection.
    :status 201: Reflection created.
    :status 400: Missing required fields.
    :status 403: Not authenticated.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    def _generate_reflection_title(book_title: str, response: str) -> str:
        # Lightweight fallback "AI" title: use the first meaningful sentence/line,
        # otherwise a short book-based title.
        text = (response or '').strip()
        if text:
            first_line = text.splitlines()[0].strip()
            if first_line:
                # Take first sentence-ish chunk.
                for sep in ['. ', '。', '!', '?', '\n']:
                    if sep in first_line:
                        first_line = first_line.split(sep)[0].strip()
                        break
                if len(first_line) > 120:
                    first_line = first_line[:117].rstrip() + '...'
                return first_line
        base = (book_title or 'Reflection').strip()[:80]
        return f"Thoughts on {base}" if base else 'Reflection'

    data = request.get_json(silent=True) or {}
    book_title = data.get('book_title')
    title = data.get('title')
    prompt = data.get('prompt')
    response_text = data.get('response')
    if not book_title or not prompt or not response_text:
        abort(400, description='book_title, prompt, and response are required')
    if isinstance(title, str):
        title = title.strip()
        if title == '':
            title = None
    else:
        title = None
    if not title:
        title = _generate_reflection_title(book_title, response_text)
    duration = data.get('duration_minutes')
    visibility = 'private'

    ref_id = uuid.uuid4().hex
    db = get_db()
    db.execute(
        'INSERT INTO reflections (id, username, book_title, title, prompt, response, duration_minutes, visibility) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        (ref_id, username, book_title, title, prompt, response_text, duration, visibility)
    )
    db.commit()
    return jsonify({
        'id': ref_id,
        'username': username,
        'book_title': book_title,
        'title': title,
        'prompt': prompt,
        'response': response_text,
        'duration_minutes': duration,
        'visibility': visibility
    }), 201


@app.route('/reflections/<reflection_id>', methods=['PUT'])
def update_reflection(reflection_id):
    """Update a private reflection's title or response.

    **PUT** ``/reflections/<reflection_id>``

    :json string response: Updated response text (optional).
    :returns: JSON ``{"status": "ok"}``.
    :status 200: Updated.
    :status 403: Not authenticated or not the owner.
    :status 404: Reflection not found.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute('SELECT username FROM reflections WHERE id = ?', (reflection_id,)).fetchone()
    if not row:
        abort(404)
    if row['username'] != username:
        abort(403)
    data = request.get_json(silent=True) or {}
    if 'title' in data:
        title = data['title']
        if title is None:
            db.execute('UPDATE reflections SET title = NULL WHERE id = ?', (reflection_id,))
        else:
            title = str(title).strip()
            if title == '':
                db.execute('UPDATE reflections SET title = NULL WHERE id = ?', (reflection_id,))
            else:
                db.execute('UPDATE reflections SET title = ? WHERE id = ?', (title, reflection_id))
    if 'response' in data:
        db.execute('UPDATE reflections SET response = ? WHERE id = ?', (data['response'], reflection_id))
    db.commit()
    return jsonify({'status': 'ok'})


@app.route('/reflections/<reflection_id>', methods=['DELETE'])
def delete_reflection(reflection_id):
    """Delete a reflection.

    **DELETE** ``/reflections/<reflection_id>``

    :returns: JSON ``{"status": "ok"}``.
    :status 200: Deleted.
    :status 403: Not authenticated or not the owner.
    :status 404: Reflection not found.
    """
    username = get_username_from_token(request)
    if not username:
        abort(403)
    db = get_db()
    row = db.execute('SELECT username FROM reflections WHERE id = ?', (reflection_id,)).fetchone()
    if not row:
        abort(404)
    if row['username'] != username:
        abort(403)
    db.execute('DELETE FROM reflections WHERE id = ?', (reflection_id,))
    db.commit()
    return jsonify({'status': 'ok'})


@app.errorhandler(HTTPException)
def handle_http_exception(e: HTTPException):
    """Return a JSON error body for all HTTP exceptions.

    Converts Werkzeug :class:`~werkzeug.exceptions.HTTPException` errors
    (e.g. 400, 403, 404) into a consistent JSON response instead of HTML.

    :param e: The HTTP exception raised.
    :returns: JSON ``{"message": ..., "status_code": ...}`` with the matching status code.
    """
    response = {'message': e.description, 'status_code': e.code}
    return jsonify(response), e.code


@app.errorhandler(Exception)
def handle_exception(e):
    """Return a JSON 500 response for any unhandled exception.

    Logs the full traceback and returns a generic error message to the client
    so internal details are not exposed.

    :param e: The unhandled exception.
    :returns: JSON ``{"error": "internal_server_error", "message": ...}`` with status 500.
    """
    logger.exception('Unhandled exception: %s', e)
    return jsonify({'error': 'internal_server_error', 'message': str(e)}), 500

def get_username_from_token(req):
    """Resolve the authenticated username from a request's session token.

    Checks the ``Authorization: Bearer <token>`` header first, then falls back
    to the ``session`` cookie. Looks the token up in the ``sessions`` table.

    :param req: The current Flask request object.
    :type req: flask.Request
    :returns: The username associated with the token, or ``None`` if the token
              is missing or invalid.
    :rtype: str or None
    """
    auth = req.headers.get('Authorization')
    token = None
    if auth and auth.startswith('Bearer '):
        token = auth.split(' ', 1)[1]
    else:
        token = req.cookies.get('session')
    if not token:
        return None
    db = get_db()
    row = db.execute('SELECT username FROM sessions WHERE token = ?', (token,)).fetchone()
    return row['username'] if row else None


# Backwards-compatible aliases for clients calling /api/* paths
try:
    app.add_url_rule('/api/books/search', endpoint='search_books_api', view_func=search_books, methods=['GET'])
except Exception:
    # if handlers are not defined yet during import-time, ignore
    pass

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        init_db()
    # Apply any lightweight schema patches against existing DBs so old demo
    # databases stay usable without being wiped.
    run_migrations()
    # Allow overriding the port with the environment (useful for running on non-default ports)
    port = int(os.environ.get('PORT', '5001'))
    app.run(debug=True, host='0.0.0.0', port=port)
