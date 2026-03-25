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


def weighted_genre_scores(catalog_genre_by_norm_title, history_rows, preferred_genres):
    """Calculate engagement-weighted scores for each genre in user's history.
    
    Weights genres by:
    1. Frequency: how many books of that genre user has read
    2. Duration: total seconds spent reading that genre
    3. Pages: total pages read in that genre
    4. User preference: +50 points for genres marked as preferred
    
    Returns a dict mapping genre -> composite score.

    :param catalog_genre_by_norm_title: map normalized title -> genre string
    :param history_rows: iterable of rows with ``book_title``, ``duration_seconds``, ``pages_read`` keys
    :param preferred_genres: list of genre strings marked as preferred by user (optional)
    :returns: dict mapping genre string -> weighted score (float)
    """
    genre_stats = {}
    
    for row in history_rows:
        nt = _normalize_title(row['book_title'])
        genre = catalog_genre_by_norm_title.get(nt)
        if not genre:
            continue
        
        if genre not in genre_stats:
            genre_stats[genre] = {
                'count': 0,
                'duration': 0,
                'pages': 0
            }
        
        genre_stats[genre]['count'] += 1
        duration = row['duration_seconds'] or 0
        pages = row['pages_read'] or 0
        genre_stats[genre]['duration'] += duration
        genre_stats[genre]['pages'] += pages
    
    # Compute composite score: (count + duration/3600 + pages/50 + preference_bonus)
    # - duration/3600 converts seconds to "hours equivalent"
    # - pages/50 normalizes page counts (typical book ~300 pages, ~50 is 1/6 of book)
    # - preference_bonus: +50 points if genre is in user's preferred genres
    scores = {}
    for genre, stats in genre_stats.items():
        count_score = stats['count'] * 10  # 10 points per book
        duration_score = (stats['duration'] / 3600) * 5  # ~5 points per hour
        pages_score = (stats['pages'] / 50) * 3  # ~3 points per 50 pages
        preference_bonus = 50 if genre in preferred_genres else 0
        scores[genre] = count_score + duration_score + pages_score + preference_bonus
    
    # Add preferred genres that user hasn't read yet (preference bonus only)
    for genre in preferred_genres:
        if genre not in scores:
            scores[genre] = 50
    
    return scores


def rank_recommendations(catalog_rows, history_rows, limit, preferred_genres):
    """Return up to ``limit`` catalog rows excluding already-read titles.

    Scores rows based on genre matching against user's reading history,
    weighted by engagement metrics (duration, pages, frequency) and user preferences.

    :param catalog_rows: rows with keys book_id, title, author, genre, cover_url
    :param history_rows: rows with book_title, duration_seconds, pages_read
    :param limit: max results (>= 1)
    :param preferred_genres: list of genre strings marked as preferred by user (optional)
    :returns: list of catalog rows (same objects as input)
    """
    logger.info(f"rank_recommendations called with preferred_genres={preferred_genres}")
    
    read_titles = {_normalize_title(r['book_title']) for r in history_rows}
    catalog_genre_by_norm = {
        _normalize_title(r['title']): r['genre'] for r in catalog_rows
    }
    
    # Get engagement-weighted genre scores (including user preferences)
    genre_scores = weighted_genre_scores(catalog_genre_by_norm, history_rows, preferred_genres)
    logger.info(f"genre_scores after weighting: {genre_scores}")

    scored = []
    for row in catalog_rows:
        if _normalize_title(row['title']) in read_titles:
            continue
        
        # Base score from genre match
        score = genre_scores.get(row['genre'], 0)
        scored.append((score, row))
        logger.debug(f"  {row['title']} ({row['genre']}): score={score}")

    # Sort by score (descending), then by book_id for stability
    scored.sort(key=lambda x: (-x[0], x[1]['book_id']))
    result = [pair[1] for pair in scored[:limit]]
    logger.info(f"returning {len(result)} recommendations")
    return result
