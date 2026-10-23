Overview
========

KiwiFruit is a personal reading and focus app. This document covers the
backend REST API served by the Flask application in ``server/app.py``.

Base URL
--------

During local development the server runs on::

    http://localhost:5000

Authentication
--------------

Most write endpoints require a valid session token obtained from
``POST /sessions``. The token can be supplied in two ways:

* **Authorization header** (preferred for API clients)::

      Authorization: Bearer <token>

* **Session cookie** (set automatically by the server on login, for
  browser-based clients)::

      Cookie: session=<token>

Quick-start
-----------

1. **Create an account**::

       POST /users
       Content-Type: application/json

       { "username": "alice", "password": "s3cr3t", "fullname": "Alice Example" }

2. **Log in to get a token**::

       POST /sessions
       Content-Type: application/json

       { "username": "alice", "password": "s3cr3t" }

   Response includes ``token``; pass it as ``Authorization: Bearer <token>``
   on subsequent authenticated requests.

3. **Start a focus session**::

       POST /reading-sessions
       Authorization: Bearer <token>
       Content-Type: application/json

       { "book_title": "Dune" }
