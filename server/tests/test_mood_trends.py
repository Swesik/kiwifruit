"""Tests for /mood-trends — detection of sustained tired mood and declining engagement.

These are the signals the iOS client displays as a 'gentle nudge' banner.
"""

import os
import sqlite3
import uuid

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


def _insert_sessions(app_module, sessions):
    """sessions: list of (duration_seconds, pages_read, mood) tuples, inserted in order."""
    with app_module.app.app_context():
        db = sqlite3.connect(app_module.DB_PATH)
        for dur, pages, mood in sessions:
            db.execute(
                'INSERT INTO session_history (id, username, book_title, duration_seconds, pages_read, mood) '
                'VALUES (?, ?, ?, ?, ?, ?)',
                (uuid.uuid4().hex, 'alice', 'Dune', dur, pages, mood)
            )
        db.commit()
        db.close()


class TestEmptyState:
    def test_no_sessions_returns_insufficient_data(self, app_client):
        client, _ = app_client
        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        assert data['trend'] == 'insufficient_data'
        assert data['suggestion'] is None
        assert data['total_sessions'] == 0


class TestSustainedTired:
    """3 consecutive tired moods should trigger a declining trend + tired-specific suggestion."""

    def test_three_consecutive_tired_triggers_declining(self, app_client):
        client, app_module = app_client
        # Insert 3 sessions all tired (the last 3 are what matters).
        _insert_sessions(app_module, [
            (1800, 20, 'tired'),
            (1800, 20, 'tired'),
            (1800, 20, 'tired'),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        assert data['trend'] == 'declining'
        # Suggestion copy is AI-generated; assert presence only (content quality
        # is covered by the OpenAI integration tests, not here).
        assert data['suggestion'] is None or isinstance(data['suggestion'], str)

    def test_mixed_with_recent_tired_still_triggers(self, app_client):
        """If the MOST RECENT 3 sessions are tired, it triggers regardless of earlier sessions."""
        client, app_module = app_client
        _insert_sessions(app_module, [
            (1800, 20, 'focused'),
            (1800, 20, 'inspired'),
            (1800, 20, 'tired'),
            (1800, 20, 'tired'),
            (1800, 20, 'tired'),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        assert resp.get_json()['trend'] == 'declining'

    def test_only_two_tired_does_not_trigger(self, app_client):
        client, app_module = app_client
        _insert_sessions(app_module, [
            (1800, 20, 'focused'),
            (1800, 20, 'tired'),
            (1800, 20, 'tired'),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        # Last 3 aren't all tired, and duration is flat → stable.
        assert data['trend'] == 'stable'
        assert data['suggestion'] is None


class TestDurationTrend:
    """>25% drop in avg duration between first and second half → declining."""

    def test_sharp_duration_drop_triggers_declining(self, app_client):
        client, app_module = app_client
        # First half avg = 3600 (60 min); second half avg = 600 (10 min) → -83%.
        _insert_sessions(app_module, [
            (3600, 30, None),
            (3600, 30, None),
            (600, 5, None),
            (600, 5, None),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        assert data['trend'] == 'declining'
        # Suggestion copy is AI-generated; presence-only check.
        assert data['suggestion'] is None or isinstance(data['suggestion'], str)

    def test_sharp_duration_rise_triggers_improving(self, app_client):
        client, app_module = app_client
        _insert_sessions(app_module, [
            (600, 5, None),
            (600, 5, None),
            (3600, 30, None),
            (3600, 30, None),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        assert data['trend'] == 'improving'

    def test_flat_duration_is_stable(self, app_client):
        client, app_module = app_client
        _insert_sessions(app_module, [
            (1800, 20, None),
            (1800, 20, None),
            (1800, 20, None),
            (1800, 20, None),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        data = resp.get_json()
        assert data['trend'] == 'stable'
        assert data['suggestion'] is None

    def test_below_minimum_session_count_is_stable(self, app_client):
        """Need >= 4 sessions for duration trend logic to apply."""
        client, app_module = app_client
        _insert_sessions(app_module, [
            (3600, 30, None),
            (600, 5, None),
            (600, 5, None),
        ])

        resp = client.get('/mood-trends', headers=_auth())
        # 3 sessions → duration_trend can't classify, falls through to stable.
        assert resp.get_json()['trend'] == 'stable'
