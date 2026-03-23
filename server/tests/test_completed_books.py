"""Integration tests for POST /completed-books and GET /completed-books."""

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


# ---------------------------------------------------------------------------
# POST /completed-books
# ---------------------------------------------------------------------------

class TestMarkBookCompleted:

    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.post('/completed-books', json={'book_title': 'Dune'})
        assert resp.status_code == 403

    def test_returns_400_when_no_title(self, app_client):
        client, _ = app_client
        resp = client.post('/completed-books', json={}, headers=_auth('alice-token'))
        assert resp.status_code == 400

    def test_returns_400_when_title_blank(self, app_client):
        client, _ = app_client
        resp = client.post('/completed-books', json={'book_title': '   '}, headers=_auth('alice-token'))
        assert resp.status_code == 400

    def test_creates_record_and_returns_201(self, app_client):
        client, _ = app_client
        resp = client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth('alice-token'))
        assert resp.status_code == 201
        data = resp.get_json()
        assert data['book_title'] == 'Dune'
        assert 'id' in data

    def test_same_book_can_be_marked_multiple_times(self, app_client):
        client, _ = app_client
        client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth('alice-token'))
        resp = client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth('alice-token'))
        assert resp.status_code == 201


# ---------------------------------------------------------------------------
# GET /completed-books
# ---------------------------------------------------------------------------

class TestGetCompletedBooks:

    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.get('/completed-books')
        assert resp.status_code == 403

    def test_empty_when_none_marked(self, app_client):
        client, _ = app_client
        resp = client.get('/completed-books', headers=_auth('alice-token'))
        assert resp.status_code == 200
        assert resp.get_json() == []

    def test_returns_completed_books(self, app_client):
        client, _ = app_client
        client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth('alice-token'))

        resp = client.get('/completed-books', headers=_auth('alice-token'))
        assert resp.status_code == 200
        data = resp.get_json()
        assert len(data) == 1
        assert data[0]['book_title'] == 'Dune'
        assert 'id' in data[0]
        assert 'completed_at' in data[0]

    def test_does_not_return_other_users_books(self, app_client):
        client, _ = app_client
        client.post('/completed-books', json={'book_title': '1984'}, headers=_auth('bob-token'))

        resp = client.get('/completed-books', headers=_auth('alice-token'))
        assert resp.get_json() == []

    def test_returns_multiple_books(self, app_client):
        client, _ = app_client
        for title in ['Dune', 'Foundation', 'Neuromancer']:
            client.post('/completed-books', json={'book_title': title}, headers=_auth('alice-token'))

        resp = client.get('/completed-books', headers=_auth('alice-token'))
        data = resp.get_json()
        assert len(data) == 3
        titles = {entry['book_title'] for entry in data}
        assert titles == {'Dune', 'Foundation', 'Neuromancer'}

    def test_response_fields_are_correct(self, app_client):
        client, _ = app_client
        client.post('/completed-books', json={'book_title': 'Dune'}, headers=_auth('alice-token'))

        resp = client.get('/completed-books', headers=_auth('alice-token'))
        entry = resp.get_json()[0]
        assert set(entry.keys()) == {'id', 'book_title', 'completed_at'}
