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

*Last Updated: February 2026*
