"""AI-powered recommendation explanations using OpenAI.

Generates personalized 50-100 word explanations for book recommendations
based on user reading history, behavioral signals (time, frequency, completion),
and preferences.
"""

import os
import json
import logging
from openai import OpenAI

logger = logging.getLogger("kiwifruit")

# Initialize OpenAI client only if key exists, with error handling
try:
    api_key = os.getenv("OPENAI_API_KEY")
    if api_key:
        client = OpenAI(api_key=api_key, timeout=15.0)
        logger.info("OpenAI client initialized successfully")
    else:
        client = None
        logger.warning("OPENAI_API_KEY not found in environment")
except Exception as e:
    client = None
    logger.error(f"Failed to initialize OpenAI client: {e}")


def calculate_behavioral_signals(history):
    """Extract behavioral signals from reading history.
    
    :param history: list of dicts or sqlite3.Row objects with book_title, duration_seconds, pages_read
    :returns: dict with statistics about reading behavior
    """
    if not history:
        return {
            'total_books': 0,
            'total_hours': 0,
            'avg_reading_session_minutes': 0,
            'total_pages': 0,
            'reading_frequency': 'new',
            'avg_session_duration': 0
        }
    
    # Convert sqlite3.Row objects to dicts for easier access
    history_dicts = []
    for h in history:
        if hasattr(h, 'keys'):  # sqlite3.Row or dict-like object
            history_dicts.append(dict(h))
        else:
            history_dicts.append(h)
    
    total_time = sum(h.get('duration_seconds') or 0 for h in history_dicts)
    total_pages = sum(h.get('pages_read') or 0 for h in history_dicts)
    
    # Calculate average reading session (minutes)
    reading_sessions = len(history_dicts)
    avg_session_minutes = (total_time / 60 / reading_sessions) if reading_sessions > 0 else 0
    
    # Determine frequency pattern
    if reading_sessions >= 20:
        frequency = 'daily reader'
    elif reading_sessions >= 10:
        frequency = 'frequent reader'
    elif reading_sessions >= 5:
        frequency = 'regular reader'
    else:
        frequency = 'casual reader'
    
    return {
        'total_books': reading_sessions,
        'total_hours': round(total_time / 3600, 1),
        'avg_reading_session_minutes': round(avg_session_minutes, 1),
        'total_pages': total_pages,
        'reading_frequency': frequency,
        'avg_session_duration': round(total_time / reading_sessions, 0) if reading_sessions > 0 else 0
    }


def generate_book_recommendations(user_context, limit=8):
    """Use AI to suggest books based on user reading history, behavioral patterns, and preferences.

    :param user_context: dict with keys:
        - reading_history: list of book titles/authors recently read
        - preferred_genres: list of user's preferred genres
        - behavioral_signals: dict with reading analytics
    :param limit: number of recommendations to generate (default 8)
    :returns: list of dicts with title, author, genre, reason or None if API fails
    """
    if not client:
        logger.warning("OpenAI client not initialized - skipping AI recommendations")
        return None
    
    if not os.getenv("OPENAI_API_KEY"):
        logger.warning("OPENAI_API_KEY not set - skipping AI recommendations")
        return None

    try:
        recent_books = user_context.get("reading_history", [])
        pref_genres = user_context.get("preferred_genres", [])
        signals = user_context.get("behavioral_signals", {})
        
        # Format reading history for the prompt - emphasize most recent books
        if recent_books:
            most_recent = recent_books[0] if recent_books else "unknown"
            history_text = f"Most recently read: {most_recent}. Also read: " + ", ".join(recent_books[:5])
        else:
            history_text = "No reading history yet."
            most_recent = "N/A"
        
        logger.info(f"AI recommendations: most_recent_book={most_recent} total_books={len(recent_books)}")
        
        genres_text = ", ".join(pref_genres) if pref_genres else "general fiction, mystery, fantasy"
        
        # Build behavioral context - emphasize recent reading patterns
        behavior_text = f"""\nReading Behavior (Most Recent Sessions Are Most Important):
- Total books completed: {signals.get('total_books', 0)}
- Total hours reading: {signals.get('total_hours', 0)}
- Average reading session: {signals.get('avg_reading_session_minutes', 0)} minutes
- Total pages read: {signals.get('total_pages', 0)}
- Reader type: {signals.get('reading_frequency', 'new reader')}

IMPORTANT: The most recently read book ({most_recent if recent_books else 'N/A'}) is a strong signal of current reading interests. Prioritize recommendations that align with it."""
        
        prompt = f"""You are an expert book recommendation engine. Based on a reader's profile and behavioral patterns, suggest exactly {limit} books they would enjoy reading next.

**EMPHASIS: Recent reading is highly predictive of current interests. Weight recent books heavily in your recommendations.**

Reader's Profile:
- {history_text}
- Preferred genres: {genres_text}{behavior_text}

Return ONLY a JSON array with exactly {limit} book objects. Each object must have:
- title (string) - must be a real published book
- author (string) - real author name
- genre (string, one of: fiction, fantasy, sci-fi, mystery, classic, dystopian, memoir, nonfiction, romance)
- reason (string, 50-100 words explaining why this is a great fit for them based on their reading behavior and history)

The reason MUST:
1. Reference their RECENT reading or the most recent book they read
2. Explain how this book continues or complements their current reading pattern
3. Be warm, personalized, and specific

Format: [
  {{"title": "...", "author": "...", "genre": "...", "reason": "..."}},
  ...
]

IMPORTANT: Return ONLY the JSON array, no other text or markdown."""

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a book recommendation AI that returns only valid JSON arrays with real published books. Always return exactly the number of recommendations requested. Base recommendations on behavioral patterns and reading history."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1500,
            temperature=0.7,
            timeout=15  # 15 second timeout
        )
        
        response_text = response.choices[0].message.content.strip()
        
        # Parse JSON response
        try:
            recommendations = json.loads(response_text)
            if not isinstance(recommendations, list):
                logger.error(f"AI response was not a list: {response_text[:200]}")
                return None
            
            if len(recommendations) != limit:
                logger.warning(f"AI returned {len(recommendations)} recommendations, expected {limit}")
            
            # Validate each recommendation has required fields
            validated = []
            for rec in recommendations:
                if isinstance(rec, dict) and all(k in rec for k in ['title', 'author', 'genre', 'reason']):
                    validated.append(rec)
            
            return validated if validated else None
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI recommendation JSON: {str(e)}\nResponse: {response_text[:500]}")
            return None

    except Exception as e:
        logger.error(f"Failed to generate AI recommendations: {str(e)}")
        # Return None on timeout or any error - let iOS show fallback
        return None


def generate_recommendation_explanation(book, user_context):
    """Generate a 50-100 word explanation for why this book is recommended.

    :param book: dict with keys - title, author, genre
    :param user_context: dict with keys - reading_history (list of titles), 
                         preferred_genres (list), behavioral_signals (dict)
    :returns: str with 50-100 word explanation, or None if API fails
    """
    if not os.getenv("OPENAI_API_KEY"):
        logger.warning("OPENAI_API_KEY not set - skipping AI explanations")
        return None

    try:
        # Build context from user's history
        recent_books = user_context.get("reading_history", [])[:5]
        pref_genres = ", ".join(user_context.get("preferred_genres", ["general fiction"]))
        signals = user_context.get("behavioral_signals", {})
        
        prompt = f"""Based on a reader's history and preferences, explain why they should read this book.

Reader's Profile:
- Recently read: {", ".join(recent_books) if recent_books else "diverse genres"}
- Preferred genres: {pref_genres}
- Reading behavior: {signals.get('reading_frequency', 'avid reader')} ({signals.get('total_books', '?')} books, {signals.get('avg_reading_session_minutes', 0)} min avg session)

Book to Recommend:
- Title: {book['title']}
- Author: {book['author']}
- Genre: {book['genre']}

Write a personalized, compelling 50-100 word recommendation explanation that references their reading behavior.
Start directly with why they'd enjoy it—no "You might enjoy" preamble."""

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a friendly book recommendation expert who gives warm, specific explanations for why someone should read a book based on their reading patterns and history."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=150,
            temperature=0.7
        )
        
        explanation = response.choices[0].message.content.strip()
        
        # Verify it's roughly 50-100 words (word count check)
        word_count = len(explanation.split())
        if word_count < 20:
            logger.warning(f"AI explanation too short ({word_count} words) for {book['title']}")
        
        return explanation

    except Exception as e:
        logger.error(f"Failed to generate AI explanation: {str(e)}")
        return None


def generate_explanations_batch(books, user_context):
    """Generate explanations for multiple books efficiently.

    :param books: list of dicts with title, author, genre
    :param user_context: dict with reading_history, preferred_genres, behavioral_signals
    :returns: dict mapping book_title -> explanation (or None if failed)
    """
    explanations = {}
    
    for book in books:
        explanation = generate_recommendation_explanation(book, user_context)
        explanations[book['title']] = explanation
    
    return explanations
