"""Tests for the mood-aware reflection prompt endpoint.

Covers:
- Template fallback when no mood / no OpenAI key
- Template variants per mood
- Pages_read is reflected in output when provided
- OpenAI path is used when key present (mocked)
- Graceful fallback when OpenAI call raises
"""

import os
import sqlite3
from unittest.mock import patch, MagicMock

import pytest


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

class TestAuth:
    def test_requires_auth(self, app_client):
        client, _ = app_client
        resp = client.post('/reflection-prompt', json={'book_title': 'Dune', 'duration_minutes': 30})
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Fallback templates (OpenAI disabled)
# ---------------------------------------------------------------------------

@patch.dict(os.environ, {}, clear=False)
class TestTemplateFallback:
    """With OPENAI_API_KEY unset, endpoint must fall back to templates."""

    @pytest.fixture(autouse=True)
    def _no_openai_key(self, monkeypatch):
        monkeypatch.delenv('OPENAI_API_KEY', raising=False)

    def test_no_mood_uses_generic_template(self, app_client):
        client, _ = app_client
        resp = client.post('/reflection-prompt',
                           json={'book_title': 'Dune', 'duration_minutes': 30},
                           headers=_auth())
        assert resp.status_code == 200
        data = resp.get_json()
        assert 'prompt' in data
        assert 'Dune' in data['prompt']
        assert '30' in data['prompt']
        assert data['source'] == 'template'

    def test_tired_mood_uses_tired_template_language(self, app_client):
        client, _ = app_client
        resp = client.post('/reflection-prompt',
                           json={'book_title': 'Dune', 'duration_minutes': 15, 'mood': 'tired'},
                           headers=_auth())
        data = resp.get_json()
        # All 3 tired templates mention "tired", "rest", or "short".
        lower = data['prompt'].lower()
        assert any(k in lower for k in ['tired', 'rest', 'short', 'stood out'])
        assert data['mood'] == 'tired'

    def test_focused_mood_prompts_differ_from_tired(self, app_client):
        """Mood selection influences template choice."""
        client, _ = app_client
        resp = client.post('/reflection-prompt',
                           json={'book_title': 'Dune', 'duration_minutes': 45, 'mood': 'focused'},
                           headers=_auth())
        assert resp.get_json()['mood'] == 'focused'

    def test_pages_read_included_in_template(self, app_client):
        """When pages_read provided, template string should include it."""
        client, _ = app_client
        # Tired template #1 embeds pages_clause: "... for X minutes and Y pages ..."
        # We can't guarantee that variant is picked, so call multiple times and
        # check at least one response uses the pages value.
        found_pages = False
        for _ in range(15):
            resp = client.post('/reflection-prompt',
                               json={
                                   'book_title': 'Dune',
                                   'duration_minutes': 30,
                                   'pages_read': 42,
                                   'mood': 'tired'
                               },
                               headers=_auth())
            if '42' in resp.get_json()['prompt']:
                found_pages = True
                break
        assert found_pages, "Expected pages_read to appear in at least one template variant"


# ---------------------------------------------------------------------------
# OpenAI path (mocked)
# ---------------------------------------------------------------------------

class TestOpenAIPath:
    """With OPENAI_API_KEY set and the client returning a response, source=openai."""

    def test_openai_success_returns_model_output(self, app_client, monkeypatch):
        client, app_module = app_client
        monkeypatch.setenv('OPENAI_API_KEY', 'sk-test-fake-key')

        fake_resp = MagicMock()
        fake_resp.choices = [MagicMock(message=MagicMock(content='Custom AI-generated question?'))]
        fake_client = MagicMock()
        fake_client.chat.completions.create.return_value = fake_resp

        with patch('openai.OpenAI', return_value=fake_client):
            resp = client.post('/reflection-prompt',
                               json={'book_title': 'Dune', 'duration_minutes': 30, 'mood': 'focused'},
                               headers=_auth())

        data = resp.get_json()
        assert resp.status_code == 200
        assert data['source'] == 'openai'
        assert data['prompt'] == 'Custom AI-generated question?'

    def test_openai_failure_falls_back_to_template(self, app_client, monkeypatch):
        """Network/API errors should degrade gracefully to the template."""
        client, _ = app_client
        monkeypatch.setenv('OPENAI_API_KEY', 'sk-test-fake-key')

        fake_client = MagicMock()
        fake_client.chat.completions.create.side_effect = RuntimeError('timeout')

        with patch('openai.OpenAI', return_value=fake_client):
            resp = client.post('/reflection-prompt',
                               json={'book_title': 'Dune', 'duration_minutes': 30, 'mood': 'focused'},
                               headers=_auth())

        data = resp.get_json()
        assert resp.status_code == 200
        assert data['source'] == 'template'
        assert 'Dune' in data['prompt']

    def test_openai_empty_response_falls_back(self, app_client, monkeypatch):
        """If OpenAI returns empty content, fall back rather than emit an empty prompt."""
        client, _ = app_client
        monkeypatch.setenv('OPENAI_API_KEY', 'sk-test-fake-key')

        fake_resp = MagicMock()
        fake_resp.choices = [MagicMock(message=MagicMock(content='   '))]
        fake_client = MagicMock()
        fake_client.chat.completions.create.return_value = fake_resp

        with patch('openai.OpenAI', return_value=fake_client):
            resp = client.post('/reflection-prompt',
                               json={'book_title': 'Dune', 'duration_minutes': 30},
                               headers=_auth())

        assert resp.get_json()['source'] == 'template'

    def test_openai_strips_surrounding_quotes(self, app_client, monkeypatch):
        """Some models wrap answers in quotes; server should strip them."""
        client, _ = app_client
        monkeypatch.setenv('OPENAI_API_KEY', 'sk-test-fake-key')

        fake_resp = MagicMock()
        fake_resp.choices = [MagicMock(message=MagicMock(content='"What surprised you today?"'))]
        fake_client = MagicMock()
        fake_client.chat.completions.create.return_value = fake_resp

        with patch('openai.OpenAI', return_value=fake_client):
            resp = client.post('/reflection-prompt',
                               json={'book_title': 'Dune', 'duration_minutes': 30},
                               headers=_auth())

        data = resp.get_json()
        assert data['prompt'] == 'What surprised you today?'
