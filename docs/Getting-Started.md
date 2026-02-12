# Getting Started

This guide will help you set up and run the KiwiFruit project on your local machine.

## Prerequisites

### For iOS Development
- **macOS** (Monterey 12.0 or later recommended)
- **Xcode** 15.0 or later (Swift 6.2 support required)
- **iOS Simulator** or physical iOS device (iOS 17.0+)
- **Apple Developer Account** (for device deployment)
- **Swift 6.2** - Modern concurrency and observation features

### For Backend Development
- **Python** 3.8 or later
- **pip** (Python package manager)
- **virtualenv** or **venv** (recommended for isolated environments)

## Technology Stack

### iOS (Swift 6.2)
- **Swift 6.2** with `@Observable` macro and structured concurrency
- **SwiftUI** for UI (iOS 17.0+)
- **Xcode 15.0+**

### Backend
- **Flask** - Python web framework
- **SQLite** - Database
- See `/server/requirements.txt` for dependencies

## Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Swesik/kiwifruit.git
cd kiwifruit
```

### 2. Backend Setup

#### Step 1: Navigate to server directory
```bash
cd server
```

#### Step 2: Create a virtual environment
```bash
python3 -m venv .venv
```

#### Step 3: Activate the virtual environment
```bash
# On macOS/Linux:
source .venv/bin/activate

# On Windows:
.venv\Scripts\activate
```

#### Step 4: Install dependencies
```bash
pip install -r requirements.txt
```

#### Step 5: Initialize and run the server
```bash
python app.py
```

The Flask server will start on `http://localhost:5000` by default.

**Note:** If you have an existing `kiwifruit.db` from a previous schema version, remove it first:
```bash
rm kiwifruit.db
python app.py
```

The server will automatically:
- Create the SQLite database (`kiwifruit.db`)
- Initialize tables from `schema.sql`
- Create an `uploads/` directory for image storage
- Start listening on port 5000

#### Verify Backend is Running
```bash
curl http://localhost:5000/posts
```

You should see an empty array `[]` or sample posts.

### 3. iOS App Setup

#### Step 1: Open the Xcode project
```bash
cd ../kiwifruit
open kiwifruit.xcodeproj
```

#### Step 2: Configure the API endpoint

The app is configured to connect to the Flask backend by default. The base URL is set in `/kiwifruit/Services/APIClient.swift`:

```swift
static var shared: APIClientProtocol = RESTAPIClient(baseURL: URL(string: "http://127.0.0.1:5001")!)
```

If your Flask server runs on a different port or URL, update this line.

**For iOS Simulator:**
- Use `http://localhost:5000` or `http://127.0.0.1:5000`

**For Physical Device:**
- Find your Mac's local IP address: `ifconfig | grep "inet "`
- Update to `http://YOUR_MAC_IP:5000`
- Ensure your device is on the same Wi-Fi network

#### Step 3: Build and run
1. In Xcode, select a simulator or connected device as the run destination
2. Click the **Run** button (▶️) or press `Cmd+R`
3. The app will build and launch on your selected destination

#### Step 4: Test the app
- Create an account or log in
- Browse the feed
- Create a post with a photo from your library
- Like and comment on posts

### 4. Mock Mode (Optional)

The app can run without a backend using the `MockAPIClient` for testing and development.

To enable mock mode, change the following line in `APIClient.swift`:

```swift
static var shared: APIClientProtocol = MockAPIClient()
```

This is useful for:
- UI development without backend dependency
- Testing UI flows in isolation
- SwiftUI previews and debugging

## Project Structure

```
kiwifruit/
├── kiwifruit/                 # iOS App
│   ├── kiwifruit.xcodeproj    # Xcode project file
│   └── kiwifruit/             # Source code
│       ├── Views/             # SwiftUI views
│       ├── Models/            # Data models
│       ├── Services/          # API client and networking
│       └── Stores/            # State management stores
│
├── server/                    # Flask Backend
│   ├── app.py                 # Main Flask application
│   ├── schema.sql             # Database schema
│   ├── requirements.txt       # Python dependencies
│   └── uploads/               # Image storage (created on run)
│
└── README.md                  # Project documentation
```

## Next Steps

- Review the [Model and Engine](./Model-and-Engine.md) documentation to understand the architecture
- Check the [APIs and Controller](./APIs-and-Controller.md) for API endpoint details
- Explore the codebase and make your first feature!

## Additional Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [iOS App Programming Guide](https://developer.apple.com/library/archive/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Introduction/Introduction.html)
