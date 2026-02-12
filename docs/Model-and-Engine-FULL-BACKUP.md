# Model and Engine

This document describes the KiwiFruit application architecture, data models, state management engine, and how components interact. It includes our storymap, engine architecture diagrams, and implementation details.

## Table of Contents
1. [Storymap](#storymap)
2. [Engine Architecture](#engine-architecture)
3. [Data Models](#data-models)
4. [State Management Engine](#state-management-engine)
5. [Data Flow](#data-flow)
6. [Control Flow](#control-flow)
7. [Implementation Details](#implementation-details)

---

## Storymap

<table>
<tr>
<td width="50%">

![Storymap Stage 1](storymap_stage1.png)

</td>
<td width="50%">

![Storymap Stage 2](storymap_stage2.png)

</td>
</tr>
<tr>
<td width="50%">

![Storymap Stage 3](storymap_stage3.png)

</td>
<td width="50%">

![Storymap Stage 4](storymap_stage4.png)

</td>
</tr>
</table>

---

### User Journey Map

KiwiFruit is designed around the reader's journey of reflection and community engagement:

```
┌─────────────────────────────────────────────────────────────────┐
│                        KIWIFRUIT USER JOURNEY                    │
└─────────────────────────────────────────────────────────────────┘

1. DISCOVER
   User opens app → Sees social feed → Browses reading reflections

2. AUTHENTICATE
   New user → Sign up with username/password
   Returning user → Auto-login with stored token

3. EXPLORE
   Scroll infinite feed → View posts from community
   Tap post → See details and comments
   Tap profile → View user's reading history

4. REFLECT
   Finish reading session → Tap "Create Post"
   Select photo from library → Add caption reflection
   Post → Share with community

5. ENGAGE
   Like posts → Show appreciation
   Comment on posts → Start conversations
   Follow readers → Build community

6. RETURN
   Check feed daily → Maintain streak
   See engagement on own posts → Feel community connection
```

### Core User Stories

1. **As a reader**, I want to share my thoughts about a book with a photo, so that I can remember and reflect on my reading experience.

2. **As a community member**, I want to see what others are reading, so that I can discover new books and perspectives.

3. **As an engaged user**, I want to like and comment on posts, so that I can engage with the reading community.

4. **As a profile owner**, I want to see all my reading reflections in one place, so that I can track my reading journey.

5. **As a casual browser**, I want to scroll through an infinite feed, so that I can continuously discover new content.

---

## Engine Architecture

![Engine Architecture](engine.jpg)

KiwiFruit uses a hybrid architecture with distinct frontend and backend engines:

### High-Level Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                          iOS DEVICE                                 │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      PRESENTATION LAYER                       │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐             │  │
│  │  │  FeedView  │  │ProfileView │  │CreatePost  │  ...        │  │
│  │  │  (SwiftUI) │  │  (SwiftUI) │  │  (SwiftUI) │             │  │
│  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘             │  │
│  └────────┼───────────────┼────────────────┼────────────────────┘  │
│           │               │                │                        │
│  ┌────────┴───────────────┴────────────────┴────────────────────┐  │
│  │                     STATE MANAGEMENT ENGINE                   │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ SessionStore │  │  PostsStore  │  │  LikesStore  │       │  │
│  │  │(@StateObject)│  │(@StateObject)│  │(@StateObject)│       │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │  │
│  │         │                  │                  │               │  │
│  │  ┌──────┴──────────────────┴──────────────────┴───────────┐  │  │
│  │  │             CommentsStore (@StateObject)               │  │  │
│  │  └──────────────────────────┬─────────────────────────────┘  │  │
│  └─────────────────────────────┼────────────────────────────────┘  │
│                                 │                                   │
│  ┌─────────────────────────────┴────────────────────────────────┐  │
│  │                      NETWORKING LAYER                         │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │          APIClient (Protocol-based)                    │  │  │
│  │  │  ┌──────────────────┐      ┌──────────────────┐       │  │  │
│  │  │  │  MockAPIClient   │      │  RESTAPIClient   │       │  │  │
│  │  │  │  (Local testing) │      │  (Production)    │       │  │  │
│  │  │  └──────────────────┘      └────────┬─────────┘       │  │  │
│  │  └──────────────────────────────────────┼────────────────┘  │  │
│  └─────────────────────────────────────────┼───────────────────┘  │
└────────────────────────────────────────────┼──────────────────────┘
                                              │
                                         HTTP/HTTPS
                                              │
┌─────────────────────────────────────────────┼──────────────────────┐
│                          SERVER (Flask)     │                       │
│  ┌─────────────────────────────────────────┴───────────────────┐  │
│  │                     CONTROLLER LAYER                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │  │
│  │  │ /sessions   │  │   /posts    │  │  /comments  │   ...   │  │
│  │  │ (Auth)      │  │ (CRUD)      │  │  (CRUD)     │         │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │  │
│  └─────────┼─────────────────┼─────────────────┼────────────────┘  │
│            │                 │                 │                    │
│  ┌─────────┴─────────────────┴─────────────────┴────────────────┐  │
│  │                      BUSINESS LOGIC LAYER                     │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │  │
│  │  │ Authentication  │  │  Post Management│  │File Handling │ │  │
│  │  │ - Token gen     │  │  - Create/Read  │  │- Upload      │ │  │
│  │  │ - Validation    │  │  - Update/Delete│  │- Storage     │ │  │
│  │  └─────────────────┘  └─────────────────┘  └──────────────┘ │  │
│  └───────────────────────────────┬───────────────────────────────┘  │
│                                  │                                  │
│  ┌───────────────────────────────┴───────────────────────────────┐  │
│  │                      DATA PERSISTENCE LAYER                    │  │
│  │  ┌────────────────────────────────────────────────────────┐   │  │
│  │  │              SQLite Database (kiwifruit.db)            │   │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │  │
│  │  │  │  users   │  │  posts   │  │ comments │  ...       │   │  │
│  │  │  │  table   │  │  table   │  │  table   │            │   │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘            │   │  │
│  │  └────────────────────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                      FILE STORAGE                               │  │
│  │                    uploads/ directory                           │  │
│  │              (uploaded images served at /uploads/)              │  │
│  └────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

### Architecture Layers Explained

#### 1. Presentation Layer (iOS SwiftUI Views)
**Purpose**: Render UI and capture user interactions

**Components**:
- `FeedView`: Infinite-scroll social feed
- `ProfileView`: User profile with post history
- `CreatePostView`: Photo selection and post creation
- `LoginView` / `SignUpView`: Authentication screens
- `PostRow`: Reusable post component
- `CommentsView`: View and manage comments
- `PostDetailView`: Detailed view of a single post

**How it works**:
- Built entirely with SwiftUI declarative syntax
- Views observe Stores via `@ObservedObject` or `@StateObject`
- When Store publishes changes (`@Published`), views automatically re-render
- User interactions trigger Store methods (e.g., `postsStore.loadMore()`)

**Technology**: 100% SwiftUI (native iOS framework)

---

#### 2. State Management Engine (ViewModels with @Observable)
**Purpose**: Single source of truth for application state using Swift 6.2 Observation

This is the **core engine** of the iOS app. All data flows through these ViewModels using modern `@Observable` macro.

**Architecture**: MVVM with Swift 6.2 Observation Framework

**Components**:

##### SessionViewModel
```swift
@Observable @MainActor
final class SessionViewModel {
    var currentUser: User?
    var authToken: String?
    var isAuthenticated: Bool = false
    
    // Async operations
    func login(username: String, password: String) async throws { }
    func logout() async { }
}
```

- **Responsibility**: Manage user authentication and session state
- **State**: Current user, auth token, login status
- **Operations**: Login, logout, sign up, token persistence
- **Persistence**: Stores token in `Keychain` (not UserDefaults)
- **Concurrency**: `@MainActor` for UI updates, `async`/`await` for operations

##### PostsViewModel
```swift
@Observable @MainActor
final class PostsViewModel {
    var posts: [Post] = []
    var isLoading: Bool = false
    var currentPage: Int = 1
    
    func loadInitial() async throws { }
    func loadMore() async throws { }
}
```

- **Responsibility**: Manage feed data and pagination
- **State**: Array of posts, loading state, page number
- **Operations**: 
  - `loadInitial()` - Load first page (async)
  - `loadMore()` - Pagination for infinite scroll (async)
  - `addPost()` - Prepend new post
  - `updateLikes()` - Update like count for a post
- **Deduplication**: Removes duplicate posts when loading new pages
- **Concurrency**: All operations use `async`/`await`

##### LikesViewModel
```swift
@Observable @MainActor
final class LikesViewModel {
    var likedPostIds: Set<String> = []
    
    func like(_ postId: String) async throws { }
    func unlike(_ postId: String) async throws { }
}
```

- **Responsibility**: Track which posts user has liked
- **State**: Set of liked post IDs
- **Operations**:
  - `like()` - Optimistic UI update + async API call
  - `unlike()` - Optimistic UI update + async API call
  - `isLiked()` - Check if user liked a post
- **Persistence**: Local only (could be extended to Keychain)

##### CommentsViewModel
```swift
@Observable @MainActor
final class CommentsViewModel {
    var commentsByPost: [String: [Comment]] = [:]
    
    func fetchComments(for postId: String) async throws { }
    func addComment(to postId: String, text: String) async throws { }
}
```

- **Responsibility**: Manage comments for posts
- **State**: Dictionary mapping post ID → array of comments
- **Operations**:
  - `fetchComments()` - Load comments asynchronously
  - `addComment()` - Create new comment (async)
  - `deleteComment()` - Remove comment (async)
- **Future**: Sync with backend using repository pattern

**How they work together (Swift 6.2 style)**:
```swift
// User likes a post
PostRow: {
    Button("Like") {
        Task {
            await likesViewModel.like(postId)
        }
    }
}
    ↓
LikesViewModel.like(postId):
    - Optimistically update: likedPostIds.insert(postId)
    - UI updates automatically (view re-renders)
    ↓
    - await apiClient.likePost(postId) // async network call
    ↓
    - Get new like count from server
    ↓
    - await postsViewModel.updateLikes(postId, newCount)
    ↓
PostsViewModel.updateLikes:
    - Update post.likes in posts array
    - UI updates automatically
    ↓
All views observing the post refresh (automatic with @Observable)
```

**Technology**: Swift 6.2 Observation Framework
- `@Observable` macro (NOT `ObservableObject`)
- Direct property observation
- `@MainActor` for UI isolation
- `async`/`await` for all operations
- NO `@Published`, `@StateObject`, or Combine

---

#### 3. Networking Layer (API Client)
**Purpose**: Abstract API communication behind a protocol

**Architecture Pattern**: Protocol-Oriented Programming

```swift
protocol APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post]
    func createPost(...) async throws -> Post
    func likePost(_ postId: String) async throws -> Int
    // ... more methods
}
```

**Implementations**:

##### MockAPIClient
- **Purpose**: Testing and development without backend
- **Behavior**: Returns fake data from `MockData`
- **Use Case**: SwiftUI previews, UI development, demos

##### RESTAPIClient
- **Purpose**: Production API client
- **Behavior**: 
  - Makes HTTP requests to Flask backend
  - Encodes/decodes JSON using `Codable`
  - Handles Bearer token authentication
  - Supports multipart/form-data for image uploads
  - Logs requests for debugging
- **Use Case**: Real app usage with backend

**Why Protocol-Based?**:
- Easy to swap implementations (mock ↔ real)
- Testable (can mock API responses)
- Clean separation of concerns

**Technology**: 
- Native `URLSession` for networking
- Swift's `async`/`await` for asynchronous operations
- `Codable` for JSON serialization

---

#### 4. Backend Controller Layer (Flask Routes)
**Purpose**: Handle HTTP requests and route to business logic

**Components** (Flask endpoints):
- `POST /sessions` - User authentication
- `POST /users` - User registration
- `GET /posts` - Fetch paginated posts
- `POST /posts` - Create new post with image upload
- `POST /posts/:id/like` - Like a post
- `DELETE /posts/:id/like` - Unlike a post
- `POST /comments` - Create/delete comments
- `GET /posts/:id/comments` - Fetch comments for a post

**How it works**:
1. Receive HTTP request
2. Extract and validate parameters
3. Verify authentication (check Bearer token)
4. Call business logic functions
5. Return JSON response with appropriate status code

**Technology**: Flask web framework (Python)

---

#### 5. Business Logic Layer
**Purpose**: Implement core functionality and rules

**Components**:

##### Authentication Module
- Generate auth tokens (UUID-based in prototype)
- Validate tokens on protected endpoints
- Hash passwords (future: bcrypt/argon2)
- Associate requests with user ID

##### Post Management Module
- Create posts with metadata
- Query posts with pagination
- Update post properties (likes, comments)
- Delete posts (with authorization check)
- Handle image association

##### File Handling Module
- Validate uploaded files (type, size)
- Generate unique filenames (prevent collisions)
- Save to `uploads/` directory
- Serve images via `/uploads/<filename>`

**Technology**: Python functions and Flask utilities

---

#### 6. Data Persistence Layer (SQLite)
**Purpose**: Store and retrieve data reliably

**Database Schema** (see `schema.sql`):

```sql
users
  - id (TEXT PRIMARY KEY)
  - username (TEXT UNIQUE)
  - password_hash (TEXT)
  - fullname (TEXT)
  - avatar_url (TEXT)
  - created_at (TIMESTAMP)

posts
  - id (TEXT PRIMARY KEY)
  - author_id (TEXT, foreign key → users)
  - image_url (TEXT)
  - caption (TEXT)
  - like_count (INTEGER, default 0)
  - created_at (TIMESTAMP)

likes
  - post_id (TEXT, foreign key → posts)
  - user_id (TEXT, foreign key → users)
  - created_at (TIMESTAMP)
  - PRIMARY KEY (post_id, user_id)

comments
  - id (TEXT PRIMARY KEY)
  - post_id (TEXT, foreign key → posts)
  - author_id (TEXT, foreign key → users)
  - text (TEXT)
  - created_at (TIMESTAMP)
```

**Operations**:
- `SELECT` with `LIMIT`/`OFFSET` for pagination
- `INSERT` for creating records
- `UPDATE` for modifying records (e.g., like_count)
- `DELETE` for removing records
- `JOIN` for fetching related data (e.g., post with author info)

**Technology**: SQLite3 (embedded database, no separate server needed)

---

## Data Models

### Core Models (Swift Structs)

All models conform to `Codable` (JSON serialization) and `Identifiable` (SwiftUI list support).

#### User Model
```swift
struct User: Identifiable, Codable, Hashable {
    let id: String              // Unique identifier (UUID)
    let username: String        // Login username
    let displayName: String?    // Display name (optional)
    let avatarURL: URL?         // Profile picture URL (optional)
}
```

#### Post Model
```swift
struct Post: Identifiable, Codable, Hashable {
    let id: String              // Unique identifier (UUID)
    let author: User            // Nested user object
    let imageURL: URL           // URL to post image
    let caption: String?        // Optional reflection text
    var likes: Int              // Like count (mutable for updates)
    let createdAt: Date?        // Timestamp (optional)
    var commentCount: Int?      // Number of comments (optional)
    var likedByMe: Bool?        // Whether current user liked (optional)
}
```

#### Comment Model
```swift
struct Comment: Identifiable, Codable, Hashable {
    let id: String              // Unique identifier (UUID)
    let postId: String?         // Associated post ID (optional)
    let author: User            // Comment author
    let text: String            // Comment text content
    let createdAt: Date         // Timestamp
}
```

### Model Relationships

```
User ──┬─→ Posts (one-to-many: author_id)
       └─→ Comments (one-to-many: author_id)
       └─→ Likes (many-to-many via likes table)

Post ──┬─→ Comments (one-to-many: post_id)
       └─→ Likes (many-to-many via likes table)
```

---

## Data Flow

### Example: Creating a New Post

```
┌─────────────┐
│    USER     │
│ Taps "Post" │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  CreatePostView                         │
│  - User selected photo                  │
│  - User wrote caption                   │
│  - Convert PhotosPickerItem → Data     │
└──────┬──────────────────────────────────┘
       │ postsStore.createPost(imageData, caption)
       ▼
┌─────────────────────────────────────────┐
│  PostsStore                             │
│  - Show loading indicator               │
└──────┬──────────────────────────────────┘
       │ apiClient.createPost(authorId, imageData, caption)
       ▼
┌─────────────────────────────────────────┐
│  RESTAPIClient                          │
│  - Build multipart/form-data            │
│  - Add Authorization header (token)     │
│  - Send HTTP POST to /posts             │
└──────┬──────────────────────────────────┘
       │ HTTP POST with image data
       ▼
┌─────────────────────────────────────────┐
│  Flask Backend (/posts endpoint)        │
│  - Validate authentication              │
│  - Validate file type                   │
│  - Generate unique filename             │
│  - Save image to uploads/               │
│  - Insert post record into database     │
│  - Generate image URL                   │
│  - Return Post JSON                     │
└──────┬──────────────────────────────────┘
       │ JSON response with Post object
       ▼
┌─────────────────────────────────────────┐
│  RESTAPIClient                          │
│  - Decode JSON → Post struct            │
│  - Return Post to caller                │
└──────┬──────────────────────────────────┘
       │ Return Post
       ▼
┌─────────────────────────────────────────┐
│  PostsStore                             │
│  - Insert new post at top of array      │
│  - Publish update (@Published)          │
│  - Hide loading indicator               │
└──────┬──────────────────────────────────┘
       │ State change published
       ▼
┌─────────────────────────────────────────┐
│  FeedView (observing PostsStore)        │
│  - Automatically re-renders             │
│  - New post appears at top of feed      │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────┐
│    USER     │
│  Sees post  │
│  in feed!   │
└─────────────┘
```

### Example: Infinite Scroll Feed Loading

```
┌─────────────┐
│    USER     │
│ Scrolls to  │
│  bottom     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  FeedView                               │
│  - onAppear { if nearBottom && !loading │
│    { loadMore() } }                     │
└──────┬──────────────────────────────────┘
       │ postsStore.loadMore()
       ▼
┌─────────────────────────────────────────┐
│  PostsStore                             │
│  - if isLoadingMore { return }          │
│  - isLoadingMore = true                 │
│  - currentPage += 1                     │
└──────┬──────────────────────────────────┘
       │ apiClient.fetchPosts(page: currentPage, pageSize: 20)
       ▼
┌─────────────────────────────────────────┐
│  RESTAPIClient                          │
│  - Build URL with ?page=2&pageSize=20   │
│  - Send HTTP GET to /posts              │
└──────┬──────────────────────────────────┘
       │ HTTP GET /posts?page=2&pageSize=20
       ▼
┌─────────────────────────────────────────┐
│  Flask Backend (/posts endpoint)        │
│  - Parse page and pageSize              │
│  - Calculate OFFSET: (page-1) * pageSize│
│  - Query: SELECT * FROM posts           │
│    ORDER BY created_at DESC             │
│    LIMIT 20 OFFSET 20                   │
│  - Join with users table for author     │
│  - Return array of Post JSON            │
└──────┬──────────────────────────────────┘
       │ JSON array of 20 posts
       ▼
┌─────────────────────────────────────────┐
│  RESTAPIClient                          │
│  - Decode JSON → [Post]                 │
│  - Return array                         │
└──────┬──────────────────────────────────┘
       │ Return [Post]
       ▼
┌─────────────────────────────────────────┐
│  PostsStore                             │
│  - Append new posts to existing array   │
│  - Remove duplicates (by post.id)       │
│  - Publish update (@Published)          │
│  - isLoadingMore = false                │
└──────┬──────────────────────────────────┘
       │ State change published
       ▼
┌─────────────────────────────────────────┐
│  FeedView (observing PostsStore)        │
│  - Automatically re-renders             │
│  - New posts appear seamlessly          │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────┐
│    USER     │
│ Continues   │
│ scrolling   │
└─────────────┘
```

---

## Control Flow

### Authentication Flow

```
App Launch
    │
    ├─→ SessionStore checks UserDefaults for token
    │
    ├─→ If token exists:
    │   │
    │   ├─→ Set apiClient.authToken
    │   ├─→ Set isAuthenticated = true
    │   ├─→ Load user data
    │   └─→ Show MainTabView (Feed, Profile, etc.)
    │
    └─→ If no token:
        │
        └─→ Show LoginView
            │
            ├─→ User enters username/password
            ├─→ Taps "Log In"
            │
            ├─→ SessionStore.login(username, password)
            │   │
            │   ├─→ apiClient.createSession(username, password)
            │   ├─→ Backend validates credentials
            │   ├─→ Backend returns { token, user }
            │   │
            │   ├─→ SessionStore saves token to UserDefaults
            │   ├─→ SessionStore sets currentUser
            │   ├─→ SessionStore sets isAuthenticated = true
            │   └─→ apiClient.setAuthToken(token)
            │
            └─→ SwiftUI detects isAuthenticated change
                │
                └─→ Navigates to MainTabView
```

### Like/Unlike Flow (Optimistic UI)

```
User taps heart icon on post
    │
    ├─→ PostRow calls likesStore.like(postId)
    │
    ├─→ LikesStore.like(postId)
    │   │
    │   ├─→ Check if already liked
    │   │
    │   ├─→ If not liked:
    │   │   │
    │   │   ├─→ Add postId to likedPosts Set (optimistic)
    │   │   ├─→ Publish update → UI shows filled heart immediately
    │   │   │
    │   │   ├─→ Task { try await apiClient.likePost(postId) }
    │   │   │   │
    │   │   │   ├─→ Backend increments like_count in database
    │   │   │   ├─→ Backend inserts record in likes table
    │   │   │   └─→ Backend returns new like count
    │   │   │
    │   │   ├─→ Receive new like count
    │   │   └─→ postsStore.updateLikes(postId, newCount)
    │   │       │
    │   │       └─→ Update post.likes in posts array
    │   │           │
    │   │           └─→ UI updates with accurate count
    │   │
    │   └─→ If already liked:
    │       │
    │       ├─→ Remove postId from likedPosts Set
    │       ├─→ Publish update → UI shows empty heart immediately
    │       │
    │       └─→ Task { try await apiClient.unlikePost(postId) }
    │           │
    │           └─→ (same flow as like)
    │
    └─→ If API call fails:
        │
        ├─→ Revert optimistic update
        ├─→ Show error message
        └─→ UI returns to previous state
```

---

## Implementation Details

### How Each Component is Implemented

#### SwiftUI Views (Swift 6.2)
- **Technology**: SwiftUI declarative framework
- **State Management**: 
  - Direct observation of `@Observable` ViewModels
  - `@State` for local view state
  - `@Bindable` for two-way bindings
  - **NO** `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- **Lifecycle**: SwiftUI automatically manages view lifecycle
- **Rendering**: Efficient updates through Observation framework
- **Async Actions**: Use `Task { }` for all async operations in views

#### ViewModels (Swift 6.2)
- **Pattern**: MVVM with `@Observable` macro
- **Implementation**: Classes annotated with `@Observable` and `@MainActor`
- **Publishing**: Automatic observation at type level (no `@Published` needed)
- **Concurrency**: Swift Structured Concurrency with `async`/`await`
- **Actor Isolation**: `@MainActor` for UI-bound ViewModels

#### API Client (Swift 6.2)
- **Networking**: `URLSession` with async/await APIs
- **Concurrency**: Swift Structured Concurrency (`async`/`await`, `Task`)
- **Serialization**: `Codable` protocol (JSON ↔ Swift structs)
- **Error Handling**: Typed `throws` with domain-specific errors
- **Thread Safety**: All operations naturally thread-safe with async/await
- **NO DispatchQueue**: Uses structured concurrency exclusively

#### Flask Backend
- **Framework**: Flask (lightweight WSGI framework)
- **Routing**: Decorator-based (`@app.route('/posts', methods=['POST'])`)
- **Database**: `sqlite3` Python library (embedded database)
- **File Uploads**: `werkzeug.utils.secure_filename` for security

#### Database
- **Engine**: SQLite3 (serverless, file-based)
- **Schema Management**: SQL scripts (`schema.sql`)
- **Connections**: Pooled via Flask's `g` object (request-scoped)
- **Queries**: Raw SQL with parameterized queries (prevents SQL injection)

---

## Platform and SDK Usage

### iOS Platform SDKs (Swift 6.2)

KiwiFruit uses modern iOS frameworks with Swift 6.2 features:

1. **SwiftUI Framework**
   - Declarative UI building blocks
   - Native integration with `@Observable`
   - Efficient rendering with Observation framework
   - `NavigationStack` for navigation (NO `NavigationView`)

2. **Swift Observation Framework** (Swift 6.2)
   - `@Observable` macro for state management
   - Type-level observation (not property-level)
   - Replaces Combine for UI state observation
   - `@Bindable` for two-way bindings

3. **Swift Concurrency** (Swift 6.2)
   - Structured concurrency with `async`/`await`
   - `Task` for async operations in synchronous contexts
   - `@MainActor` for UI thread isolation
   - Actor isolation for thread safety
   - **Replaces**: All `DispatchQueue` and `RunLoop` usage

4. **PhotosUI Framework**
   - `PhotosPicker` for accessing photo library
   - Handles permissions and user privacy
   - Async photo loading with `async`/`await`

5. **Foundation Framework**
   - Async networking (`URLSession` with `async`/`await`)
   - JSON parsing (`JSONDecoder`/`JSONEncoder`)
   - Data types (`Date`, `URL`, `Data`)
   - Secure storage (`Keychain`, NOT `UserDefaults` for sensitive data)

6. **Security Framework**
   - Keychain for sensitive data (auth tokens, credentials)
   - Replaces `UserDefaults` for security-critical data

### Backend "Engine"

The Flask backend serves as the data engine:

1. **Flask Framework**
   - Request/response handling
   - Routing and middleware
   - Session management

2. **SQLite**
   - Data persistence
   - Query optimization
   - Transaction management

3. **Python Standard Library**
   - File I/O for image storage
   - UUID generation for unique IDs
   - JSON serialization

---

## Future Enhancements

Planned improvements to the engine architecture:

1. **Caching Layer**
   - Cache posts in local database (Core Data)
   - Offline support
   - Faster feed loading

2. **Real-time Updates**
   - WebSocket connection for live updates
   - Push notifications for new likes/comments

3. **Background Sync**
   - Queue failed requests for retry
   - Background upload of posts

4. **Advanced State Management**
   - Consider Redux-like architecture for complex state
   - Time-travel debugging

5. **Backend Scalability**
   - Migrate from SQLite to PostgreSQL
   - Add Redis for caching
   - Implement CDN for images

---

*Last Updated: February 2026*
*Team: Team Kiwifruit*
