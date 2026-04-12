"""Integration tests for speed reading progress and chapter text endpoints."""

import io
import os
import time
import sqlite3
import tempfile
import uuid

import pytest
from ebooklib import epub as epub_lib


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_epub(title="Test Book", author="Test Author", chapters=None):
    """Build a minimal valid .epub file in memory and return its bytes."""
    if chapters is None:
        chapters = [
            ("Chapter 1", "<h1>Chapter 1</h1><p>First chapter text.</p>"),
            ("Chapter 2", "<h2>Chapter 2</h2><p>Second chapter text.</p>"),
        ]

    book = epub_lib.EpubBook()
    book.set_identifier(uuid.uuid4().hex)
    book.set_title(title)
    book.set_language('en')
    book.add_author(author)

    spine = ['nav']
    items = []
    for i, (ch_title, html_body) in enumerate(chapters, 1):
        ch = epub_lib.EpubHtml(title=ch_title, file_name=f'ch{i}.xhtml', lang='en')
        ch.content = f'<html><body>{html_body}</body></html>'
        book.add_item(ch)
        items.append(ch)
        spine.append(ch)

    book.toc = items
    book.add_item(epub_lib.EpubNcx())
    book.add_item(epub_lib.EpubNav())
    book.spine = spine

    tmp = tempfile.NamedTemporaryFile(suffix='.epub', delete=False)
    tmp.close()
    epub_lib.write_epub(tmp.name, book)
    with open(tmp.name, 'rb') as f:
        data = f.read()
    os.unlink(tmp.name)
    return data


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def app_client(tmp_path):
    """Create a Flask test client backed by a temporary database and uploads dir."""
    import server.app as app_module

    original_db_path = app_module.DB_PATH
    original_upload_folder = app_module.UPLOAD_FOLDER
    original_epub_folder = app_module.EPUB_FOLDER

    db_path = str(tmp_path / 'test.db')
    upload_dir = str(tmp_path / 'uploads')
    epub_dir = os.path.join(upload_dir, 'epubs')
    os.makedirs(upload_dir, exist_ok=True)
    os.makedirs(epub_dir, exist_ok=True)

    app_module.DB_PATH = db_path
    app_module.UPLOAD_FOLDER = upload_dir
    app_module.EPUB_FOLDER = epub_dir
    app_module.app.config['UPLOAD_FOLDER'] = upload_dir
    app_module.app.config['EPUB_FOLDER'] = epub_dir
    app_module.app.config['TESTING'] = True

    with app_module.app.app_context():
        db = sqlite3.connect(db_path)
        db.row_factory = sqlite3.Row
        schema_path = os.path.join(os.path.dirname(app_module.__file__), 'schema.sql')
        with open(schema_path, 'r') as f:
            db.executescript(f.read())

        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('testuser', 'Test User', 'test@example.com', 'default.jpg', 'password')
        )
        db.execute(
            "INSERT INTO sessions (token, username) VALUES (?, ?)",
            ('test-token', 'testuser')
        )
        # Second user for ownership tests
        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('otheruser', 'Other User', 'other@example.com', 'default.jpg', 'password')
        )
        db.execute(
            "INSERT INTO sessions (token, username) VALUES (?, ?)",
            ('other-token', 'otheruser')
        )
        db.commit()
        db.close()

    client = app_module.app.test_client()
    yield client, app_module

    app_module.DB_PATH = original_db_path
    app_module.UPLOAD_FOLDER = original_upload_folder
    app_module.EPUB_FOLDER = original_epub_folder
    app_module.app.config['UPLOAD_FOLDER'] = original_upload_folder
    app_module.app.config['EPUB_FOLDER'] = original_epub_folder


def _auth_header(token='test-token'):
    return {'Authorization': f'Bearer {token}'}


def _upload_and_wait(client, epub_bytes=None, filename='book.epub', timeout=5):
    """Upload an epub and wait for parsing to complete. Returns epub_id."""
    if epub_bytes is None:
        epub_bytes = _make_epub(
            chapters=[
                ("Ch 1", "<h1>Chapter One</h1><p>The quick brown fox jumps over the lazy dog.</p>"),
                ("Ch 2", "<h1>Chapter Two</h1><p>Speed reading is fun and exciting.</p>"),
            ]
        )
    resp = client.post(
        '/api/epub',
        data={'file': (io.BytesIO(epub_bytes), filename)},
        content_type='multipart/form-data',
        headers=_auth_header()
    )
    assert resp.status_code == 201
    epub_id = resp.get_json()['id']

    start = time.time()
    while time.time() - start < timeout:
        r = client.get(f'/api/epub/{epub_id}', headers=_auth_header())
        if r.get_json()['status'] != 'LOADING':
            break
        time.sleep(0.1)

    return epub_id


# ---------------------------------------------------------------------------
# Tests — Chapter Text
# ---------------------------------------------------------------------------

class TestChapterText:
    """Tests for GET /api/epub/<epub_id>/chapter/<chapter_num>/text."""

    def test_get_chapter_text(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(f'/api/epub/{epub_id}/chapter/1/text', headers=_auth_header())
        assert resp.status_code == 200
        data = resp.get_json()
        assert 'text' in data
        assert 'quick brown fox' in data['text']

    def test_get_chapter_text_second_chapter(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(f'/api/epub/{epub_id}/chapter/2/text', headers=_auth_header())
        assert resp.status_code == 200
        assert 'Speed reading' in resp.get_json()['text']

    def test_chapter_not_found(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(f'/api/epub/{epub_id}/chapter/99/text', headers=_auth_header())
        assert resp.status_code == 404

    def test_epub_not_found(self, app_client):
        client, _ = app_client

        resp = client.get('/api/epub/99999/chapter/1/text', headers=_auth_header())
        assert resp.status_code == 404

    def test_no_auth(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(f'/api/epub/{epub_id}/chapter/1/text')
        assert resp.status_code == 403

    def test_wrong_owner(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(
            f'/api/epub/{epub_id}/chapter/1/text',
            headers=_auth_header('other-token')
        )
        assert resp.status_code == 403

    def test_loading_epub_returns_409(self, app_client):
        client, app_module = app_client
        db = sqlite3.connect(app_module.DB_PATH)
        db.execute(
            "INSERT INTO epubs (owner, title, author, original_filename, stored_filename, status) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            ('testuser', 'Loading Book', '', 'loading.epub', 'fake.epub', 'LOADING')
        )
        db.commit()
        epubid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        db.close()

        resp = client.get(f'/api/epub/{epubid}/chapter/1/text', headers=_auth_header())
        assert resp.status_code == 409


# ---------------------------------------------------------------------------
# Tests — Speed Reading Progress
# ---------------------------------------------------------------------------

class TestGetProgress:
    """Tests for GET /api/speed-reading/progress/<epub_id>."""

    def test_default_progress(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(f'/api/speed-reading/progress/{epub_id}', headers=_auth_header())
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['chapterNumber'] == 1
        assert data['wordIndex'] == 0

    def test_no_auth(self, app_client):
        client, _ = app_client

        resp = client.get('/api/speed-reading/progress/1')
        assert resp.status_code == 403

    def test_epub_not_found(self, app_client):
        client, _ = app_client

        resp = client.get('/api/speed-reading/progress/99999', headers=_auth_header())
        assert resp.status_code == 404

    def test_wrong_owner(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.get(
            f'/api/speed-reading/progress/{epub_id}',
            headers=_auth_header('other-token')
        )
        assert resp.status_code == 403


class TestUpdateProgress:
    """Tests for PUT /api/speed-reading/progress/<epub_id>."""

    def test_set_and_get_progress(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 2, 'wordIndex': 42},
            headers=_auth_header()
        )
        assert resp.status_code == 200
        assert resp.get_json()['chapterNumber'] == 2
        assert resp.get_json()['wordIndex'] == 42

        # Verify via GET
        resp = client.get(f'/api/speed-reading/progress/{epub_id}', headers=_auth_header())
        assert resp.get_json()['chapterNumber'] == 2
        assert resp.get_json()['wordIndex'] == 42

    def test_upsert_progress(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 1, 'wordIndex': 10},
            headers=_auth_header()
        )
        resp = client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 1, 'wordIndex': 50},
            headers=_auth_header()
        )
        assert resp.status_code == 200

        resp = client.get(f'/api/speed-reading/progress/{epub_id}', headers=_auth_header())
        assert resp.get_json()['wordIndex'] == 50

    def test_missing_fields(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 1},
            headers=_auth_header()
        )
        assert resp.status_code == 400
        assert resp.get_json()['error'] == 'missing_fields'

    def test_invalid_field_types(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 'one', 'wordIndex': 0},
            headers=_auth_header()
        )
        assert resp.status_code == 400
        assert resp.get_json()['error'] == 'invalid_fields'

    def test_no_auth(self, app_client):
        client, _ = app_client

        resp = client.put(
            '/api/speed-reading/progress/1',
            json={'chapterNumber': 1, 'wordIndex': 0}
        )
        assert resp.status_code == 403

    def test_epub_not_found(self, app_client):
        client, _ = app_client

        resp = client.put(
            '/api/speed-reading/progress/99999',
            json={'chapterNumber': 1, 'wordIndex': 0},
            headers=_auth_header()
        )
        assert resp.status_code == 404

    def test_wrong_owner(self, app_client):
        client, _ = app_client
        epub_id = _upload_and_wait(client)

        resp = client.put(
            f'/api/speed-reading/progress/{epub_id}',
            json={'chapterNumber': 1, 'wordIndex': 0},
            headers=_auth_header('other-token')
        )
        assert resp.status_code == 403
