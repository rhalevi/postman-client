# Project Plan: SwiftUI Postman Client

## 🚀 Goal
Build a macOS SwiftUI desktop application that simulates Postman's core functionality: sending HTTP requests (GET and POST) with customizable headers and body content, and displaying the received response.

## 📐 Architecture
The solution will be modular, separating UI presentation from business logic (networking/state).

### 1. State Management (ViewModel/NetworkService)
*   **Responsibility:** Hold and mutate all application state and execute the network calls.
*   **State Variables:**
    *   `url`: `String` (The endpoint URL).
    *   `method`: `HTTPMethod` (Enum: `.get`, `.post`).
    *   `headers`: `[String: String]` (A map for custom key-value headers).
    *   `body`: `String` (The payload for POST requests).
    *   `response`: `NetworkResponse` (A struct to hold `statusCode: Int`, `body: String`, and any `error: Error?`).
*   **Key Function:** `sendRequest()`: This asynchronous function will take the current state, construct the appropriate `URLRequest`, and execute the network call.

### 2. User Interface (ContentView - SwiftUI)
*   **Layout:** A clean, standard macOS split view layout.
*   **Input Panel (Top):**
    *   **Method Selector:** A segmented control or Picker for selecting the method (`GET`, `POST`).
    *   **URL Field:** A primary `TextField` for the URL.
    *   **Headers Panel:** A dedicated section allowing the user to dynamically add, edit, or remove header key/value pairs.
    *   **Body Panel:** A large `TextEditor` for the request body (visible only for POST).
    *   **Action Button:** A primary "Send" button that triggers `sendRequest()`.
*   **Output Panel (Bottom):**
    *   **Status Display:** Shows the HTTP status code (e.g., 200 OK).
    *   **Response Body:** A scrollable view displaying the raw response body text.
    *   **Error Display:** Dedicated area to show network or API errors.

### 3. Network Implementation (Networking Logic)
*   **Library:** Use `Foundation`'s `URLSession` (native macOS API).
*   **GET Request:**
    1.  Construct a basic `URLRequest` using the provided URL.
    2.  Apply all headers from the `headers` state.
    3.  Execute using `URLSession.shared.dataTask`.
*   **POST Request:**
    1.  Construct a `URLRequest`.
    2.  Set the `Content-Type` header (recommended: `application/json`).
    3.  Convert the `body` string into `Data` and assign it to `httpBody`.
    4.  Execute using `URLSession.shared.uploadTask`.

### 🛠️ Next Steps (Implementation Phases)
1.  Define `ViewModel` and state models.
2.  Build the SwiftUI UI structure (`ContentView`).
3.  Implement the networking logic and tie the UI action to the `ViewModel` call.