import Foundation
import SwiftUI
import Combine

// MARK: - 1. Models & Enums (Made fully self-contained)

enum ResponseViewMode: String, CaseIterable, Identifiable {
    case raw = "Raw"
    case json = "JSON"

    var id: String { self.rawValue }
}

// MARK: - JSON Tree Node

enum JSONNodeType {
    case object
    case array
    case string(String)
    case number(String)
    case boolean(String)
    case null

    var color: Color {
        switch self {
        case .object, .array: return Color.blue
        case .string: return Color.green
        case .number: return Color.orange
        case .boolean: return Color.purple
        case .null: return Color.gray
        }
    }
}

enum JSONNode {
    case container(key: String?, type: JSONNodeType, children: [JSONNode], isFolded: Bool)
    case scalar(key: String?, value: String, type: JSONNodeType)

    var key: String? {
        switch self {
        case .container(let key, _, _, _): return key
        case .scalar(let key, _, _): return key
        }
    }

    var type: JSONNodeType {
        switch self {
        case .container(_, let t, _, _): return t
        case .scalar(_, _, let t): return t
        }
    }

    var isContainer: Bool {
        if case .container = self { return true }
        return false
    }

    var isFolded: Bool {
        if case .container(_, _, _, let f) = self { return f }
        return false
    }

    var children: [JSONNode] {
        if case .container(_, _, let c, _) = self { return c }
        return []
    }

    var value: String? {
        if case .scalar(_, let v, _) = self { return v }
        return nil
    }

    mutating func setFolded(_ folded: Bool) {
        if case .container(let k, let t, let c, _) = self {
            self = .container(key: k, type: t, children: c, isFolded: folded)
        }
    }

    func expanded() -> JSONNode {
        var copy = self
        copy.setFolded(false)
        return copy
    }

    func mapChildren(_ transform: ([JSONNode]) -> [JSONNode]) -> JSONNode {
        let children = transform(self.children)
        if case .container(let k, let t, _, let f) = self {
            return .container(key: k, type: t, children: children, isFolded: f)
        }
        return self
    }

    func expandedAll() -> JSONNode {
        return mapChildren { $0.map { $0.expandedAll() } }
    }
}

extension JSONNode {
    func foldCount() -> (folded: Int, total: Int) {
        if isFolded {
            let (_, total) = countAll()
            return (1, total)
        }
        if !isContainer { return (0, 0) }
        var folded = 0
        var total = 0
        for child in children {
            let (f, t) = child.foldCount()
            folded += f
            total += t
        }
        return (folded, total)
    }

    func countAll() -> (count: Int, total: Int) {
        if !isContainer { return (1, 1) }
        var sum = 0
        for child in children {
            sum += child.countAll().total
        }
        return (sum, sum)
    }

    func foldedSummary() -> String {
        if let v = value {
            return v
        }
        let (count, _) = countAll()
        switch type {
        case .object: return "{ \(count) \("item".pluralized(count) ) }"
        case .array: return "[ \(count) \("item".pluralized(count) ) ]"
        default: return "\(type.color.description)"
        }
    }
}

extension String {
    func pluralized(_ count: Int) -> String {
        return count == 1 ? self : self + "s"
    }
}

func parseJSONNode(from json: Any, key: String? = nil) -> JSONNode {
    switch json {
    case let dict as [String: Any]:
        let children = dict.sorted { $0.key < $1.key }.map { k, v in parseJSONNode(from: v, key: k) }
        return .container(key: key, type: .object, children: children, isFolded: true)
    case let arr as [Any]:
        let children = arr.enumerated().map { i, v in parseJSONNode(from: v, key: String(i)) }
        return .container(key: key, type: .array, children: children, isFolded: true)
    case let str as String:
        return .scalar(key: key, value: str, type: .string(str))
    case let num as NSNumber:
        if num === (true as NSNumber) || num === (false as NSNumber) {
            return .scalar(key: key, value: String(num.boolValue), type: .boolean(String(num.boolValue)))
        }
        return .scalar(key: key, value: num.description, type: .number(num.description))
    case is NSNull:
        return .scalar(key: key, value: "null", type: .null)
    case let bool as Bool:
        return .scalar(key: key, value: String(bool), type: .boolean(String(bool)))
    default:
        return .scalar(key: key, value: String(describing: json), type: .string(String(describing: json)))
    }
}

enum HTTPMethod: String, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"

    var id: String { self.rawValue }
}

struct Header: Identifiable {
    var id: String { UUID().uuidString }
    var key: String
    var value: String
}

struct NetworkResponse {
    var statusCode: Int? = nil
    var body: String = "No response yet."
    var error: Error? = nil
}

// MARK: - 2. Extensions for Utility

extension Data {
    /// Converts Data to its hexadecimal string representation for debugging.
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - 3. ViewModel (State and Networking)

class ContentViewViewModel: ObservableObject {

    // MARK: Published State
    @Published var url: String = "https://jsonplaceholder.typicode.com/todos/1" // Changed to a reliable test URL
    @Published var method: HTTPMethod = .get
    @Published var headers: [Header] = [
        Header(key: "Content-Type", value: "application/json")
    ]
    @Published var body: String = "" // Empty body by default for GET
    @Published var response: NetworkResponse = NetworkResponse()
    @Published var isLoading: Bool = false
    @Published var responseViewMode: ResponseViewMode = .raw

    private let session = URLSession.shared

    /// Returns the response body formatted based on the current view mode.
    var displayBody: String {
        guard responseViewMode == .json, !response.body.isEmpty, response.body != "(empty response)" else {
            return response.body
        }
        guard let data = response.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let prettyText = String(data: prettyData, encoding: .utf8) else {
            return "Not valid JSON"
        }
        return prettyText
    }

    /// Parses the response body into a JSON tree for the collapsible view.
    var parsedTree: JSONNode? {
        guard responseViewMode == .json,
              !response.body.isEmpty,
              response.body != "(empty response)",
              let data = response.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        let tree = parseJSONNode(from: json)
        return tree.expandedAll()
    }

    // MARK: Public Actions

    /// Constructs and sends the HTTP request based on current published state.
    func sendRequest() async {
        // For MVP, we'll only support GET/POST
        guard method == .get || method == .post else {
            self.response = NetworkResponse(error: NSError(domain: "AppError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported method for MVP: \(method.rawValue). Please use GET or POST."]))
            return
        }

        guard !url.isEmpty else {
            self.response = NetworkResponse(error: NSError(domain: "AppError", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL cannot be empty."]))
            return
        }

        isLoading = true
        self.response = NetworkResponse() // Clear previous response

        do {
            // 1. Build URLRequest
            guard let urlRequest = try buildURLRequest(from: url, method: method, headers: headers, body: body) else {
                self.response = NetworkResponse(error: NSError(domain: "AppError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to build request."]))
                return
            }

            // 2. Execute Network Task
            let (data, response) = try await awaitPerformNetworkCall(request: urlRequest)

            // 3. Process and Publish Results
            var responseBodyString: String
            if data.isEmpty {
                responseBodyString = "(empty response)"
            } else if let textBody = String(data: data, encoding: .utf8) {
                responseBodyString = textBody
            } else {
                responseBodyString = "ERROR: Could not decode response body as UTF-8 text. Raw data received: \(data.hexEncodedString())"
            }

            self.response = NetworkResponse(
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                body: responseBodyString,
                error: nil
            )

        } catch let error {
            // Handle any errors thrown during the process
            self.response = NetworkResponse(error: error)
        }

        isLoading = false
    }

    // MARK: Helper Functions

    /// Constructs the URLRequest object from the state variables.
    private func buildURLRequest(from urlString: String, method: HTTPMethod, headers: [Header], body: String) throws -> URLRequest? {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        // Handle body for POST/PUT
        if method == .post {
            request.httpBody = body.data(using: .utf8)
        } else {
            request.httpBody = nil
        }

        return request
    }

    /// Asynchronously performs the URLSession data task.
    private func awaitPerformNetworkCall(request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type."]))
                    return
                }

                // Success case
                continuation.resume(returning: (data ?? Data(), httpResponse))
            }
            task.resume()
        }
    }
}