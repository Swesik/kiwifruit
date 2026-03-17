# APIs and Controller

This document describes how the iOS frontend communicates with the backend engine through REST APIs.

## Base URL

**Development**: `http://localhost:5000`

**Production**: TBD

## Authentication

All protected endpoints require a Bearer token in the `Authorization` header:

```
Authorization: Bearer <token>
```

---

## API Endpoints

### 1. Authentication

#### Create Session (Login)
```
POST /sessions
```

**Request Body:**
```json
{
  "username": "alice",
  "password": "password123"
}
```

**Response:**
```json
{
  "token": "abc123-token",
  "userId": "user-uuid",
  "user": {
    "id": "user-uuid",
    "username": "alice",
    "displayName": "Alice Smith",
    "avatarURL": "http://localhost:5000/uploads/avatar.jpg"
  }
}
```

#### Create Account (Sign Up)
```
POST /users
```

**Request Body:**
```json
{
  "username": "alice",
  "password": "password123",
  "fullname": "Alice Smith"
}
```

**Response:**
```json
{
  "id": "user-uuid",
  "username": "alice",
  "displayName": "Alice Smith",
  "avatarURL": null
}
```

---

### 2. Posts

#### Get Posts (Paginated Feed)
```
GET /posts?page={page}&pageSize={pageSize}
```

**Query Parameters:**
- `page`: Page number (starting from 1)
- `pageSize`: Number of posts per page (default: 20)

**Response:**
```json
[
  {
    "id": "post-uuid",
    "author": {
      "id": "user-uuid",
      "username": "alice",
      "displayName": "Alice Smith",
      "avatarURL": "http://localhost:5000/uploads/avatar.jpg"
    },
    "imageURL": "http://localhost:5000/uploads/post123.jpg",
    "caption": "Just finished reading 1984!",
    "likes": 42,
    "createdAt": "2026-02-11T12:34:56Z",
    "commentCount": 5
  }
]
```

#### Create Post
```
POST /posts
```

**Content-Type**: `multipart/form-data`

**Form Fields:**
- `file`: Image file (JPG/PNG)
- `caption`: Optional text caption
- `authorId`: User ID (optional, can be inferred from token)

**Response:** Same as single Post object above

**Requires Authentication**: Yes

---

### 3. Likes

#### Like a Post
```
POST /posts/{postId}/like
```

**Response:**
```json
{
  "likes": 43
}
```

**Requires Authentication**: Yes

#### Unlike a Post
```
DELETE /posts/{postId}/like
```

**Response:**
```json
{
  "likes": 42
}
```

**Requires Authentication**: Yes

---

### 4. Comments

#### Get Comments for a Post
```
GET /posts/{postId}/comments
```

**Response:**
```json
[
  {
    "id": "comment-uuid",
    "postId": "post-uuid",
    "author": {
      "id": "user-uuid",
      "username": "bob",
      "displayName": "Bob Jones",
      "avatarURL": null
    },
    "text": "Great book!",
    "createdAt": "2026-02-11T13:00:00Z"
  }
]
```

#### Create Comment
```
POST /comments
```

**Content-Type**: `application/x-www-form-urlencoded`

**Form Fields:**
- `operation`: "create"
- `postid`: Post ID
- `text`: Comment text

**Requires Authentication**: Yes

#### Delete Comment
```
POST /comments
```

**Content-Type**: `application/x-www-form-urlencoded`

**Form Fields:**
- `operation`: "delete"
- `commentid`: Comment ID

**Requires Authentication**: Yes

---

## iOS Client Implementation

### APIClient Protocol

The iOS app uses a protocol-based architecture for API communication:

```swift
protocol APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post]
    func createPost(authorId: String, imageData: Data?, caption: String?) async throws -> Post
    func createSession(username: String, password: String) async throws -> (token: String, user: User)
    func likePost(_ postId: String) async throws -> Int
    func unlikePost(_ postId: String) async throws -> Int
    func fetchComments(postId: String) async throws -> [Comment]
    func createComment(postId: String, text: String) async throws -> Void
    func deleteComment(commentId: String) async throws -> Void
}
```

### Two Implementations

1. **MockAPIClient**: Returns fake data for testing and UI development
2. **RESTAPIClient**: Makes real HTTP requests to Flask backend

### Switching Between Mock and Real API

In `APIClient.swift`:

```swift
// Use Mock (no backend needed)
static var shared: APIClientProtocol = MockAPIClient()

// Use Real Backend
static var shared: APIClientProtocol = RESTAPIClient(
    baseURL: URL(string: "http://localhost:5000")!
)
```

---

## Data Flow Example

### Creating a Post

```
User selects photo and taps "Post"
    ↓
CreatePostView
    ↓ postsStore.createPost(imageData, caption)
PostsStore
    ↓ apiClient.createPost(authorId, imageData, caption)
RESTAPIClient
    ↓ HTTP POST /posts (multipart/form-data)
Flask Backend
    ↓ Save image, insert into database
    ↓ Return Post JSON
RESTAPIClient
    ↓ Decode JSON → Post struct
PostsStore
    ↓ Add post to feed array
    ↓ Publish update
FeedView
    ↓ Auto re-render
User sees new post at top of feed
```

---

## Error Handling

### HTTP Status Codes

- `200 OK`: Successful request
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

### iOS Error Handling

The iOS app handles errors at multiple levels:

1. **Network Level**: `URLSession` throws `URLError`
2. **API Level**: Custom error types for specific API failures
3. **UI Level**: Display user-friendly error messages

---

## Future API Enhancements

Planned additions:

1. **User Profiles**: `GET /users/{username}`
2. **Follow System**: `POST /users/{username}/follow`, `GET /users/{username}/followers`
3. **Search**: `GET /posts/search?q={query}`
4. **Notifications**: `GET /notifications`
5. **Challenges**: `GET /challenges`, `POST /challenges/{id}/join`

---

### 5. Reading Sessions and Mood Summaries

#### Create Reading Session Summary
```
POST /reading-sessions
```

**Authentication**: required

**Request Body:**
```json
{
  "bookId": "optional-book-id-or-null",
  "durationSeconds": 900,
  "completed": true,
  "startedAt": "2026-03-17T10:00:00Z",
  "endedAt": "2026-03-17T10:15:00Z",
  "source": "focus_view"
}
```

All fields except `durationSeconds` and `completed` are optional. If `startedAt` or `endedAt` are omitted, the server may infer them from `durationSeconds` and current time.

**Response:**
```json
{
  "id": 42,
  "username": "alice",
  "bookId": "optional-book-id-or-null",
  "durationSeconds": 900,
  "completed": true,
  "startedAt": "2026-03-17T10:00:00Z",
  "endedAt": "2026-03-17T10:15:00Z",
  "source": "focus_view",
  "createdAt": "2026-03-17T10:15:01Z"
}
```

#### Create Mood Summary (optional)
```
POST /mood-summaries
```

**Authentication**: required

**Request Body:**
```json
{
  "readingSessionId": 42,
  "avgValence": 0.35,
  "volatility": 0.12,
  "dominantEmotion": "focused",
  "framesObserved": 1200
}
```

All fields except `readingSessionId` are optional. The server stores whatever subset is provided.

**Response:**
```json
{
  "id": 10,
  "readingSessionId": 42,
  "avgValence": 0.35,
  "volatility": 0.12,
  "dominantEmotion": "focused",
  "framesObserved": 1200,
  "createdAt": "2026-03-17T10:15:05Z"
}
```

---

### 6. Recommendations

#### Get Recommendations
```
GET /recommendations
```

**Authentication**: required

Returns a ranked list of recommended books or posts for the current user. The initial rule-based implementation uses social signals (friends and likes); future versions may incorporate reading sessions and mood data.

**Response:**
```json
[
  {
    "bookId": "post:17",
    "title": "Just finished reading 1984!",
    "reasonTags": ["friends_reading", "popular_recent"],
    "score": 0.92
  },
  {
    "bookId": "post:12",
    "title": "Cozy mystery night",
    "reasonTags": ["friends_reading"],
    "score": 0.75
  }
]
```

`bookId` is a string identifier for the recommended item. In the first version it may be a synthetic id like `"post:<postid>"`; later it can be a real `bookId` from your library model.

---

*Last Updated: March 2026*
