This folder contains a minimal Flask example server for local development.

Setup
- Create a virtualenv and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

- **OpenAI (optional, for `/recommendations`):** create **`server/.env`** (gitignored) with `OPENAI_API_KEY=sk-...` when running from this directory (`python3 app.py`). If you start the app from the repo root with `python3 -m server.app`, put `.env` in the **repo root** instead. See the main [README.md](../README.md) for details.

- Seed the database and start the server:

```bash
python3 seed_db.py
python3 app.py
```

- Open the app and **log in** (do not create a new account) with:
  - Username: `alice`
  - Password: `password`

  The seed creates this account for you. Alice follows Bob, so Bob's active

Notes
- Database schema is in `schema.sql`.
- Uploaded images are saved to `uploads/` and served at `/uploads/<filename>`.

Important: if you need to reset the database (e.g. after a schema change), re-run the seed script and restart the server:

```bash
python3 seed_db.py
python3 app.py
```
