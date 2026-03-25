"""Integration tests for GET /session-history."""

import os
import sqlite3
import uuid

import pytest


# ---------------------------------------------------------------------------
# Fixtures (same pattern as test_epub.py)
# ---------------------------------------------------------------------------

@pytest.fixture()
def app_client(tmp_path):
    """Flask test client backed by a temporary DB with two seeded users."""
    import server.app as app_module

    original_db_path = app_module.DB_PATH
    original_upload_folder = app_module.UPLOAD_FOLDER

    db_path = str(tmp_path / 'test.db')
    upload_dir = str(tmp_path / 'uploads')
    os.makedirs(upload_dir, exist_ok=True)

    app_module.DB_PATH = db_path
    app_module.UPLOAD_FOLDER = upload_dir
    app_module.app.config['UPLOAD_FOLDER'] = upload_dir
    app_module.app.config['TESTING'] = True

    with app_module.app.app_context():
        db = sqlite3.connect(db_path)
        db.row_factory = sqlite3.Row
        schema_path = os.path.join(os.path.dirname(app_module.__file__), 'schema.sql')
        with open(schema_path, 'r') as f:
            db.executescript(f.read())

        # Two users so we can verify isolation
        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('alice', 'Alice', 'alice@example.com', 'default.jpg', 'pw')
        )
        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('bob', 'Bob', 'bob@example.com', 'default.jpg', 'pw')
        )
        db.execute("INSERT INTO sessions (token, username) VALUES (?, ?)", ('alice-token', 'alice'))
        db.execute("INSERT INTO sessions (token, username) VALUES (?, ?)", ('bob-token', 'bob'))
        db.commit()
        db.close()

    client = app_module.app.test_client()
    yield client, app_module

    app_module.DB_PATH = original_db_path
    app_module.UPLOAD_FOLDER = original_upload_folder
    app_module.app.config['UPLOAD_FOLDER'] = original_upload_folder


def _auth(token):
    return {'Authorization': f'Bearer {token}'}


def _insert_history(db_path, username, book_title, duration_seconds, pages_read=None):
    """Directly insert a session_history row and return its id."""
    row_id = uuid.uuid4().hex
    db = sqlite3.connect(db_path)
    db.execute(
        "INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read) "
        "VALUES (?, ?, ?, ?, ?)",
        (row_id, username, book_title, duration_seconds, pages_read)
    )
    db.commit()
    db.close()
    return row_id


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestSessionHistory:
    """Tests for GET /session-history."""

    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.get('/session-history')
        assert resp.status_code == 403

    def test_empty_when_no_history(self, app_client):
        client, _ = app_client
        resp = client.get('/session-history', headers=_auth('alice-token'))
        assert resp.status_code == 200
        assert resp.get_json() == []

    def test_returns_own_sessions(self, app_client):
        client, app_module = app_client
        _insert_history(app_module.DB_PATH, 'alice', 'Dune', 3600, pages_read=50)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        assert resp.status_code == 200
        data = resp.get_json()
        assert len(data) == 1
        assert data[0]['book_title'] == 'Dune'
        assert data[0]['duration_seconds'] == 3600
        assert data[0]['pages_read'] == 50
        assert 'ended_at' in data[0]
        assert 'id' in data[0]

    def test_does_not_return_other_users_sessions(self, app_client):
        client, app_module = app_client
        _insert_history(app_module.DB_PATH, 'bob', '1984', 1800)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        assert resp.status_code == 200
        assert resp.get_json() == []

    def test_returns_only_own_sessions_when_both_have_history(self, app_client):
        client, app_module = app_client
        _insert_history(app_module.DB_PATH, 'alice', 'Dune', 3600)
        _insert_history(app_module.DB_PATH, 'bob', '1984', 1800)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        data = resp.get_json()
        assert len(data) == 1
        assert data[0]['book_title'] == 'Dune'

    def test_returns_multiple_sessions(self, app_client):
        client, app_module = app_client
        _insert_history(app_module.DB_PATH, 'alice', 'Dune', 3600, pages_read=50)
        _insert_history(app_module.DB_PATH, 'alice', 'Foundation', 1800, pages_read=30)
        _insert_history(app_module.DB_PATH, 'alice', 'Neuromancer', 900)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        data = resp.get_json()
        assert len(data) == 3
        titles = {entry['book_title'] for entry in data}
        assert titles == {'Dune', 'Foundation', 'Neuromancer'}

    def test_pages_read_can_be_null(self, app_client):
        client, app_module = app_client
        _insert_history(app_module.DB_PATH, 'alice', 'Dune', 3600, pages_read=None)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        data = resp.get_json()
        assert data[0]['pages_read'] is None

    def test_response_fields_are_correct(self, app_client):
        client, app_module = app_client
        row_id = _insert_history(app_module.DB_PATH, 'alice', 'Dune', 3600, pages_read=50)

        resp = client.get('/session-history', headers=_auth('alice-token'))
        entry = resp.get_json()[0]
        assert set(entry.keys()) == {'id', 'book_title', 'duration_seconds', 'pages_read', 'ended_at'}
        assert entry['id'] == row_id
