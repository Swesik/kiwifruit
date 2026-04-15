"""Tests for the /session-summary endpoint used by the Share sheet."""

import os
import sqlite3

import pytest


@pytest.fixture()
def app_client(tmp_path):
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

        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('alice', 'Alice', 'alice@example.com', 'default.jpg', 'pw')
        )
        db.execute("INSERT INTO sessions (token, username) VALUES (?, ?)", ('alice-token', 'alice'))
        db.commit()
        db.close()

    client = app_module.app.test_client()
    yield client, app_module

    app_module.DB_PATH = original_db_path
    app_module.UPLOAD_FOLDER = original_upload_folder
    app_module.app.config['UPLOAD_FOLDER'] = original_upload_folder


def _auth(token='alice-token'):
    return {'Authorization': f'Bearer {token}'}


def _seed_sessions(app_module, count, mood=None):
    """Insert N session_history rows for alice."""
    import uuid
    with app_module.app.app_context():
        db = sqlite3.connect(app_module.DB_PATH)
        for _ in range(count):
            db.execute(
                'INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read, mood) '
                'VALUES (?, ?, ?, ?, ?, ?)',
                (uuid.uuid4().hex, 'alice', 'Dune', 1800, 20, mood)
            )
        db.commit()
        db.close()


class TestAuth:
    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.post('/session-summary', json={'book_title': 'Dune'})
        assert resp.status_code == 403


class TestSummaryContent:
    def test_minimal_payload(self, app_client):
        client, _ = app_client
        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30},
                           headers=_auth())
        assert resp.status_code == 200
        data = resp.get_json()
        assert 'Dune' in data['summary']
        assert '30' in data['summary']
        assert data['total_sessions'] == 0

    def test_includes_pages_when_provided(self, app_client):
        client, _ = app_client
        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30, 'pages_read': 42},
                           headers=_auth())
        assert '42' in resp.get_json()['summary']

    def test_includes_mood_label(self, app_client):
        client, _ = app_client
        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30, 'mood': 'inspired'},
                           headers=_auth())
        assert 'inspired' in resp.get_json()['summary'].lower()

    def test_unknown_mood_is_ignored(self, app_client):
        """Client should never send an unknown mood, but the server shouldn't
        crash or leak it into the summary either."""
        client, _ = app_client
        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30, 'mood': 'grumpy'},
                           headers=_auth())
        summary = resp.get_json()['summary']
        assert 'grumpy' not in summary.lower()


class TestStreakCount:
    def test_session_count_reflected_when_more_than_one(self, app_client):
        client, app_module = app_client
        _seed_sessions(app_module, 5)

        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30},
                           headers=_auth())
        data = resp.get_json()
        assert data['total_sessions'] == 5
        assert 'Session #5' in data['summary']

    def test_single_session_omits_counter_line(self, app_client):
        """The "Session #X" line is only added when total_sessions > 1."""
        client, app_module = app_client
        _seed_sessions(app_module, 1)

        resp = client.post('/session-summary',
                           json={'book_title': 'Dune', 'duration_minutes': 30},
                           headers=_auth())
        data = resp.get_json()
        assert data['total_sessions'] == 1
        assert 'Session #' not in data['summary']
