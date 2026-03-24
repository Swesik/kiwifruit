"""Integration tests for GET /preferences and PUT /preferences."""

import os
import sqlite3

import pytest


# ---------------------------------------------------------------------------
# Fixtures
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


def _put(client, token, body):
    return client.put('/preferences', json=body, headers=_auth(token))


# ---------------------------------------------------------------------------
# GET /preferences
# ---------------------------------------------------------------------------

class TestGetPreferences:

    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.get('/preferences')
        assert resp.status_code == 403

    def test_returns_defaults_when_not_set(self, app_client):
        client, _ = app_client
        resp = client.get('/preferences', headers=_auth('alice-token'))
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['daily_goal_minutes'] == 30
        assert data['preferred_genres'] == []

    def test_returns_saved_preferences(self, app_client):
        client, _ = app_client
        _put(client, 'alice-token', {
            'daily_goal_minutes': 60,
            'preferred_genres': ['Fantasy', 'Sci-Fi']
        })
        resp = client.get('/preferences', headers=_auth('alice-token'))
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['daily_goal_minutes'] == 60
        assert set(data['preferred_genres']) == {'Fantasy', 'Sci-Fi'}

    def test_does_not_return_other_users_preferences(self, app_client):
        client, _ = app_client
        _put(client, 'bob-token', {
            'daily_goal_minutes': 25,
            'preferred_genres': ['Horror']
        })
        resp = client.get('/preferences', headers=_auth('alice-token'))
        data = resp.get_json()
        # alice should still see defaults, not bob's values
        assert data['preferred_genres'] == []


# ---------------------------------------------------------------------------
# PUT /preferences
# ---------------------------------------------------------------------------

class TestSavePreferences:

    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.put('/preferences', json={
            'daily_goal_minutes': 30,
            'preferred_genres': []
        })
        assert resp.status_code == 403

    def test_saves_preferences(self, app_client):
        client, _ = app_client
        resp = _put(client, 'alice-token', {
            'daily_goal_minutes': 45,
            'preferred_genres': ['Mystery', 'Thriller']
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['daily_goal_minutes'] == 45
        assert set(data['preferred_genres']) == {'Mystery', 'Thriller'}

    def test_update_overwrites_previous(self, app_client):
        client, _ = app_client
        _put(client, 'alice-token', {
            'daily_goal_minutes': 30,
            'preferred_genres': ['Fantasy']
        })
        _put(client, 'alice-token', {
            'daily_goal_minutes': 90,
            'preferred_genres': ['Non-Fiction']
        })
        resp = client.get('/preferences', headers=_auth('alice-token'))
        data = resp.get_json()
        assert data['daily_goal_minutes'] == 90
        assert data['preferred_genres'] == ['Non-Fiction']

    def test_only_one_row_per_user_after_multiple_saves(self, app_client):
        client, app_module = app_client
        _put(client, 'alice-token', {'daily_goal_minutes': 30, 'preferred_genres': []})
        _put(client, 'alice-token', {'daily_goal_minutes': 45, 'preferred_genres': []})
        db = sqlite3.connect(app_module.DB_PATH)
        count = db.execute("SELECT COUNT(*) FROM user_preferences WHERE username = 'alice'").fetchone()[0]
        db.close()
        assert count == 1

    def test_empty_genres_list_is_valid(self, app_client):
        client, _ = app_client
        resp = _put(client, 'alice-token', {
            'daily_goal_minutes': 30,
            'preferred_genres': []
        })
        assert resp.status_code == 200
        assert resp.get_json()['preferred_genres'] == []

    def test_missing_daily_goal_returns_400(self, app_client):
        client, _ = app_client
        resp = _put(client, 'alice-token', {
            'preferred_genres': []
        })
        assert resp.status_code == 400

    def test_invalid_genres_type_returns_400(self, app_client):
        client, _ = app_client
        resp = _put(client, 'alice-token', {
            'daily_goal_minutes': 30,
            'preferred_genres': 'Fantasy'
        })
        assert resp.status_code == 400

    def test_users_preferences_are_isolated(self, app_client):
        client, _ = app_client
        _put(client, 'alice-token', {
            'daily_goal_minutes': 40,
            'preferred_genres': ['Fantasy']
        })
        _put(client, 'bob-token', {
            'daily_goal_minutes': 80,
            'preferred_genres': ['Horror']
        })
        alice = client.get('/preferences', headers=_auth('alice-token')).get_json()
        bob = client.get('/preferences', headers=_auth('bob-token')).get_json()
        assert alice['preferred_genres'] == ['Fantasy']
        assert bob['preferred_genres'] == ['Horror']
