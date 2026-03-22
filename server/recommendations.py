"""Rule-based ranking for skeleton GET /recommendations.

Pure functions: no Flask imports. Used by app.py after loading rows from SQLite.
"""


def _normalize_title(title):
    """Lowercase, collapse whitespace for fuzzy title equality."""
    if not title:
        return ''
    return ' '.join(str(title).strip().lower().split())


def dominant_genre_from_history(catalog_genre_by_norm_title, history_rows):
    """Pick the most common genre among history rows that resolve to the catalog.

    Ties break alphabetically by genre name for stability.

    :param catalog_genre_by_norm_title: map normalized title -> genre string
    :param history_rows: iterable of rows with ``book_title`` key
    :returns: genre string or None
    """
    counts = {}
    for row in history_rows:
        nt = _normalize_title(row['book_title'])
        genre = catalog_genre_by_norm_title.get(nt)
        if genre:
            counts[genre] = counts.get(genre, 0) + 1
    if not counts:
        return None
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]


def rank_recommendations(catalog_rows, history_rows, limit):
    """Return up to ``limit`` catalog rows excluding already-read titles.

    Boosts rows whose genre matches the dominant genre inferred from history.

    :param catalog_rows: rows with keys book_id, title, author, genre, cover_url
    :param history_rows: rows with book_title
    :param limit: max results (>= 1)
    :returns: list of catalog rows (same objects as input)
    """
    read_titles = {_normalize_title(r['book_title']) for r in history_rows}
    catalog_genre_by_norm = {
        _normalize_title(r['title']): r['genre'] for r in catalog_rows
    }
    dominant = dominant_genre_from_history(catalog_genre_by_norm, history_rows)

    scored = []
    for row in catalog_rows:
        if _normalize_title(row['title']) in read_titles:
            continue
        score = 0
        if dominant and row['genre'] == dominant:
            score += 100
        scored.append((score, row))

    scored.sort(key=lambda x: (-x[0], x[1]['book_id']))
    return [pair[1] for pair in scored[:limit]]
