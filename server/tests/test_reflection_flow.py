"""Integration tests covering the full post-session reflection flow.

Flow under test:
  1. User completes a reading session.
  2. Client requests a mood-aware reflection prompt.
  3. Client POSTs the reflection with the returned prompt.
  4. Reflection appears in GET /reflections with correct fields.
  5. Visibility rules are enforced for other users.
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

        # Alice and Bob; Bob follows Alice.
        for u in [('alice', 'Alice'), ('bob', 'Bob'), ('carol', 'Carol')]:
            db.execute(
                "INSERT INTO users (username, fullname, email, filename, password) "
                "VALUES (?, ?, ?, ?, ?)",
                (u[0], u[1], f'{u[0]}@example.com', 'default.jpg', 'pw')
            )
            db.execute("INSERT INTO sessions (token, username) VALUES (?, ?)",
                       (f'{u[0]}-token', u[0]))
        db.execute("INSERT INTO following (follower, followee) VALUES (?, ?)", ('bob', 'alice'))
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
    """End-to-end: prompt -> create reflection -> fetch reflections."""

    @pytest.fixture(autouse=True)
    def _no_openai(self, monkeypatch):
        # Force template path for determinism.
        monkeypatch.delenv('OPENAI_API_KEY', raising=False)

    def test_prompt_then_save_then_fetch(self, app_client):
        client, _ = app_client

        # 1. Fetch prompt.
        prompt_resp = client.post('/reflection-prompt',
                                  json={'book_title': 'Dune', 'duration_minutes': 30, 'mood': 'focused'},
                                  headers=_auth())
        assert prompt_resp.status_code == 200
        prompt_text = prompt_resp.get_json()['prompt']
        assert prompt_text  # non-empty

        # 2. Save reflection with that prompt.
        save_resp = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': prompt_text,
            'response': 'The idea of prescient sight fascinated me.',
            'mood': 'focused',
            'duration_minutes': 30,
            'visibility': 'private'
        }, headers=_auth())
        assert save_resp.status_code == 201
        reflection_id = save_resp.get_json()['id']
        assert reflection_id

        # 3. Fetch reflections and verify.
        list_resp = client.get('/reflections', headers=_auth())
        assert list_resp.status_code == 200
        items = list_resp.get_json()
        assert len(items) == 1
        r = items[0]
        assert r['id'] == reflection_id
        assert r['book_title'] == 'Dune'
        assert r['prompt'] == prompt_text
        assert r['response'].startswith('The idea')
        assert r['mood'] == 'focused'
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
            'visibility': 'private'
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

    def test_invalid_visibility_rejected(self, app_client):
        client, _ = app_client
        resp = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'What stood out?',
            'response': 'Something.',
            'visibility': 'everyone',  # invalid
        }, headers=_auth())
        assert resp.status_code == 400


class TestVisibilityRules:
    """GET /reflections should enforce per-visibility access control."""

    @pytest.fixture(autouse=True)
    def _no_openai(self, monkeypatch):
        monkeypatch.delenv('OPENAI_API_KEY', raising=False)

    def _create(self, client, user, visibility):
        return client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'Q?',
            'response': f'{user} / {visibility}',
            'visibility': visibility,
        }, headers=_auth(user)).get_json()

    def test_own_reflections_visible_at_all_levels(self, app_client):
        client, _ = app_client
        for v in ['private', 'friends_only', 'public']:
            self._create(client, 'alice', v)
        items = client.get('/reflections', headers=_auth('alice')).get_json()
        assert len(items) == 3

    def test_friend_sees_friends_only_and_public_but_not_private(self, app_client):
        client, _ = app_client
        for v in ['private', 'friends_only', 'public']:
            self._create(client, 'alice', v)
        # Bob follows Alice, so should see friends_only + public; NOT private.
        items = client.get('/reflections', headers=_auth('bob')).get_json()
        alice_items = [r for r in items if r['username'] == 'alice']
        visibilities = {r['visibility'] for r in alice_items}
        assert visibilities == {'friends_only', 'public'}

    def test_non_friend_sees_nothing(self, app_client):
        """Carol does not follow Alice, so she sees none of Alice's reflections."""
        client, _ = app_client
        for v in ['private', 'friends_only', 'public']:
            self._create(client, 'alice', v)
        items = client.get('/reflections', headers=_auth('carol')).get_json()
        assert [r for r in items if r['username'] == 'alice'] == []


class TestReflectionUpdate:
    """Update endpoint is used by Share page 'Past reflection' mode to change visibility."""

    def test_update_visibility(self, app_client):
        client, _ = app_client
        created = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'Q?',
            'response': 'A.',
            'visibility': 'private'
        }, headers=_auth()).get_json()

        upd = client.put(f"/reflections/{created['id']}",
                         json={'visibility': 'public'},
                         headers=_auth())
        assert upd.status_code in (200, 204)

        items = client.get('/reflections', headers=_auth()).get_json()
        assert items[0]['visibility'] == 'public'

    def test_cannot_update_another_users_reflection(self, app_client):
        client, _ = app_client
        created = client.post('/reflections', json={
            'book_title': 'Dune',
            'prompt': 'Q?',
            'response': 'A.',
            'visibility': 'private'
        }, headers=_auth('alice')).get_json()

        resp = client.put(f"/reflections/{created['id']}",
                          json={'visibility': 'public'},
                          headers=_auth('bob'))
        assert resp.status_code in (403, 404)
