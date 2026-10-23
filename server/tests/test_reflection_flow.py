"""Integration tests covering the full post-session reflection flow.

Flow under test:
  1. User completes a reading session.
  2. Client requests a reflection prompt.
  3. Client POSTs the reflection with the returned prompt.
  4. The saved reflection is returned as private data.
"""

import os
import sqlite3
from unittest.mock import patch

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

        # Alice, Bob, and Carol have independent private accounts.
        for u in [('alice', 'Alice'), ('bob', 'Bob'), ('carol', 'Carol')]:
            db.execute(
                "INSERT INTO users (username, fullname, email, filename, password) "
                "VALUES (?, ?, ?, ?, ?)",
                (u[0], u[1], f'{u[0]}@example.com', 'default.jpg', 'pw')
            )
            db.execute("INSERT INTO sessions (token, username) VALUES (?, ?)",
                       (f'{u[0]}-token', u[0]))
        db.commit()
        db.close()

    client = app_module.app.test_client()
    yield client, app_module

    app_module.DB_PATH = original_db_path
    app_module.UPLOAD_FOLDER = original_upload_folder
    app_module.app.config['UPLOAD_FOLDER'] = original_upload_folder


def _auth(user='alice'):
    return {'Authorization': f'Bearer {user}-token'}


class TestReflectionFlow:
    """End-to-end: prompt -> create private reflection."""

    @pytest.fixture(autouse=True)
    def _no_openai(self, monkeypatch):
        # Force template path for determinism.
        monkeypatch.delenv('OPENAI_API_KEY', raising=False)

    def test_prompt_then_save_private_reflection(self, app_client):
        client, _ = app_client

        # 1. Fetch prompt.
        prompt_resp = client.post('/reflection-prompt',
                                  json={'book_title': 'Dune', 'duration_minutes': 30},
                                  headers=_auth())
        assert prompt_resp.status_code == 200
        prompt_text = prompt_resp.get_json()['prompt']
        assert prompt_text  # non-empty

        # 2. Save reflection with that prompt.
        save_resp = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': prompt_text,
            'response': 'The idea of prescient sight fascinated me.',
            'duration_minutes': 30,
        }, headers=_auth())
        assert save_resp.status_code == 201
        reflection_id = save_resp.get_json()['id']
        assert reflection_id

        # 3. The creation response contains the saved private reflection.
        r = save_resp.get_json()
        assert r['id'] == reflection_id
        assert r['book_title'] == 'Dune'
        assert r['prompt'] == prompt_text
        assert r['response'].startswith('The idea')
        assert r['visibility'] == 'private'
        # createdAt must be ISO8601 for the iOS client's date parser.
        assert 'T' in r['created_at']

    def test_auto_generated_title_when_not_provided(self, app_client):
        """If title is omitted, server should generate a non-empty one."""
        client, _ = app_client
        resp = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'What stood out?',
            'response': 'The spice must flow. It transforms everything.',
        }, headers=_auth())
        assert resp.status_code == 201
        assert resp.get_json()['title']  # non-empty

    def test_missing_required_fields_rejected(self, app_client):
        client, _ = app_client
        # No prompt.
        resp = client.post('/reflections',
                           json={'book_title': 'Dune', 'response': 'x'},
                           headers=_auth())
        assert resp.status_code == 400

class TestReflectionUpdate:
    """Private reflection edits remain restricted to their owner."""

    def test_cannot_update_another_users_reflection(self, app_client):
        client, _ = app_client
        created = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'Q?',
            'response': 'A.',
        }, headers=_auth('alice')).get_json()

        resp = client.put(f"/reflections/{created['id']}",
                          json={'response': 'Changed reflection'},
                          headers=_auth('bob'))
        assert resp.status_code in (403, 404)
