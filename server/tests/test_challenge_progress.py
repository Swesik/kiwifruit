"""Tests for challenge progress data flow.

Verifies that marking a book completed and recording sessions produce
the correct data from /completed-books and /session-history, which the
iOS ChallengeViewModel uses to calculate challenge progress.
"""

import os
import sqlite3

import pytest


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def app_client(tmp_path):
    """Flask test client backed by a temporary DB with a seeded user."""
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


# ---------------------------------------------------------------------------
# Book completion affects challenge progress data
# ---------------------------------------------------------------------------

class TestBookCompletionForChallenges:
    """Completing a book should appear in GET /completed-books so the
    client can count it toward book-based challenges."""

    def test_completed_book_appears_in_list(self, app_client):
        client, _ = app_client
        client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth())

        resp = client.get('/completed-books', headers=_auth())
        data = resp.get_json()
        assert len(data) == 1
        assert data[0]['book_title'] == 'Dune'
        assert 'completed_at' in data[0]

    def test_multiple_books_count_toward_challenge(self, app_client):
        """A books/month challenge with goalCount=3 needs 3 completed books."""
        client, _ = app_client
        for title in ['Book A', 'Book B', 'Book C']:
            resp = client.post('/completed-books', json={'book_title': title}, headers=_auth())
            assert resp.status_code == 201

        resp = client.get('/completed-books', headers=_auth())
        assert len(resp.get_json()) == 3

    def test_completed_at_is_iso8601(self, app_client):
        """ChallengeViewModel parses completed_at with ISO8601DateFormatter."""
        client, _ = app_client
        client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth())

        resp = client.get('/completed-books', headers=_auth())
        completed_at = resp.get_json()[0]['completed_at']
        # Should contain 'T' separator (ISO 8601 format)
        assert 'T' in completed_at


# ---------------------------------------------------------------------------
# Session history affects challenge progress data
# ---------------------------------------------------------------------------

class TestSessionHistoryForChallenges:
    """Completed reading sessions should appear in GET /session-history
    so the client can sum duration/pages for minutes and page challenges."""

    def _create_and_complete_session(self, client, book_title='Test Book', pages_read=None):
        """Helper: create a session, then immediately complete it."""
        resp = client.post('/reading-sessions', json={'book_title': book_title}, headers=_auth())
        assert resp.status_code == 201
        session_id = resp.get_json()['id']

        body = {'status': 'completed'}
        if pages_read is not None:
            body['pages_read'] = pages_read
        resp = client.post(f'/reading-sessions/{session_id}/complete', json=body, headers=_auth())
        assert resp.status_code == 200
        return session_id

    def test_completed_session_appears_in_history(self, app_client):
        client, _ = app_client
        self._create_and_complete_session(client)

        resp = client.get('/session-history', headers=_auth())
        assert resp.status_code == 200
        data = resp.get_json()
        assert len(data) == 1
        assert data[0]['book_title'] == 'Test Book'
        assert 'duration_seconds' in data[0]
        assert 'ended_at' in data[0]

    def test_pages_read_recorded(self, app_client):
        """Page-based challenges need pages_read from session history."""
        client, _ = app_client
        self._create_and_complete_session(client, pages_read=42)

        resp = client.get('/session-history', headers=_auth())
        data = resp.get_json()
        assert data[0]['pages_read'] == 42

    def test_multiple_sessions_sum_for_minutes_challenge(self, app_client):
        """A minutes/week challenge sums duration_seconds across sessions."""
        client, _ = app_client
        for _ in range(3):
            self._create_and_complete_session(client)

        resp = client.get('/session-history', headers=_auth())
        data = resp.get_json()
        assert len(data) == 3
        # All sessions should have non-negative duration
        for entry in data:
            assert entry['duration_seconds'] >= 0

    def test_ended_at_is_iso8601(self, app_client):
        """ChallengeViewModel filters by ended_at with ISO8601DateFormatter."""
        client, _ = app_client
        self._create_and_complete_session(client)

        resp = client.get('/session-history', headers=_auth())
        ended_at = resp.get_json()[0]['ended_at']
        assert 'T' in ended_at

    def test_history_fields_match_client_model(self, app_client):
        """SessionHistoryEntry expects: id, book_title, duration_seconds, pages_read, ended_at."""
        client, _ = app_client
        self._create_and_complete_session(client, pages_read=10)

        resp = client.get('/session-history', headers=_auth())
        entry = resp.get_json()[0]
        expected_keys = {'id', 'book_title', 'duration_seconds', 'pages_read', 'ended_at'}
        assert set(entry.keys()) == expected_keys
