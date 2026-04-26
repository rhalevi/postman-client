import SwiftUI
import Combine

// MARK: - Mutable Tree Node (class for persistent fold state)

class JSONTreeNode: Identifiable, Hashable {
    let id = UUID()
    let key: String?
    let type: JSONNodeType
    let value: String?
    var children: [JSONTreeNode]
    var isFolded: Bool

    init(key: String?, type: JSONNodeType, children: [JSONTreeNode], isFolded: Bool, value: String?) {
        self.key = key
        self.type = type
        self.children = children
        self.isFolded = isFolded
        self.value = value
    }

    convenience init(node: JSONNode) {
        self.init(
            key: node.key,
            type: node.type,
            children: node.children.map { JSONTreeNode(node: $0) },
            isFolded: node.isFolded,
            value: node.value
        )
    }

    var isContainer: Bool { !children.isEmpty }

    func foldedSummary() -> String {
        if let v = value { return v }
        let count = children.count
        let itemWord = count == 1 ? "item" : "items"
        switch type {
        case .object: return "{ \(count) \(itemWord) }"
        case .array: return "[ \(count) \(itemWord) ]"
        default: return ""
        }
    }

    func expandedAll() -> JSONTreeNode {
        let result = JSONTreeNode(
            key: key, type: type, children: children, isFolded: isFolded, value: value
        )
        result.isFolded = false
        result.children = children.map { $0.expandedAll() }
        return result
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: JSONTreeNode, rhs: JSONTreeNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = ContentViewViewModel()
    @State private var treeNodes: [JSONTreeNode] = []
    @State private var isJSONExpandAll = false

    private var hasResponse: Bool {
        viewModel.response.statusCode != nil
    }

    private var responseColor: Color {
        guard let code = viewModel.response.statusCode else { return .secondary }
        switch code {
        case 200...299: return .green
        case 300...399: return .orange
        case 400...599: return .red
        default: return .secondary
        }
    }

    private var responseLabel: String {
        guard let code = viewModel.response.statusCode else { return "Pending" }
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 500: return "Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "Error"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let _ = CGFloat(320)
            VStack(spacing: 0) {
                formArea(geometry: geometry)

                Divider()

                responseArea

            }
        }
        .onChange(of: viewModel.response.body) { _ in updateTree() }
        .onChange(of: viewModel.responseViewMode) { _ in updateTree() }
        .task { updateTree() }
    }

    // MARK: - Form Area

    @ViewBuilder
    private func formArea(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            methodPicker
            urlBar
            sendButton
            headersSection
            addHeaderButton
            if viewModel.method == .post {
                bodyEditor
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var methodPicker: some View {
        Picker("Method", selection: $viewModel.method) {
            ForEach(HTTPMethod.allCases) { method in
                Text(method.rawValue).tag(method)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
    }

    private var urlBar: some View {
        HStack(spacing: 8) {
            TextField("https://api.example.com/endpoint", text: $viewModel.url)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private var sendButton: some View {
        Button(action: {
            Task { await viewModel.sendRequest() }
        }) {
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Send")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
            }
            .foregroundColor(.white)
        }
        .disabled(viewModel.isLoading)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background {
            if viewModel.isLoading {
                Color.gray.opacity(0.5)
            } else {
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .cornerRadius(8)
    }

    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Headers")
            HeadersListView(headers: $viewModel.headers)
        }
    }

    private var addHeaderButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                viewModel.headers.append(Header(key: "", value: ""))
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("Add Header")
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Body (JSON)")
            TextEditor(text: $viewModel.body)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(2)
                .frame(height: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
        }
    }

    // MARK: - Response Area

    private var responseArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            responseHeaderBar

            errorBanner

            responseToolbar

            responseContentPanel
        }
        .padding(12)
    }

    private var responseHeaderBar: some View {
        HStack {
            Text("Response")
                .font(.headline)
            Spacer()
            if hasResponse {
                StatusBadge(code: viewModel.response.statusCode, label: responseLabel, color: responseColor)
            }
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 4)
    }

    private var errorBanner: some View {
        let error = viewModel.response.error
        let message: String?
        if let urlError = error as? URLError {
            message = urlError.localizedDescription
        } else if error != nil {
            message = error?.localizedDescription
        } else {
            message = nil
        }
        return Group {
            if let msg = message {
                ErrorBanner(message: msg)
            }
        }
    }

    private var responseToolbar: some View {
        HStack(spacing: 12) {
            Text("Body")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            ResponseModePicker(mode: $viewModel.responseViewMode)
            if viewModel.responseViewMode == .json, !treeNodes.isEmpty {
                ExpandCollapseButton(treeNodes: $treeNodes, expandAll: $isJSONExpandAll)
            }
        }
    }

    private var responseContentPanel: some View {
        ScrollView {
            if viewModel.responseViewMode == .json, !treeNodes.isEmpty {
                JSONTreeView(nodes: $treeNodes, indent: 0)
            } else {
                RawBodyView(text: viewModel.response.body)
            }
        }
        .frame(minHeight: 100)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }

    private func updateTree() {
        guard viewModel.responseViewMode == .json,
              let tree = viewModel.parsedTree else {
            treeNodes = []
            return
        }
        treeNodes = isJSONExpandAll ? tree.children.map { JSONTreeNode(node: $0).expandedAll() } : tree.children.map { JSONTreeNode(node: $0) }
    }
}

// MARK: - Components

struct SendButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Send")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
            }
            .foregroundColor(.white)
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
        .background {
            if isLoading {
                Color.gray.opacity(0.5)
            } else {
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .cornerRadius(8)
    }
}

struct HeaderRow: View {
    @Binding var header: Header
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Key", text: $header.key)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 140)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)

            TextField("Value", text: $header.value)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
    }
}

struct HeadersListView: View {
    @Binding var headers: [Header]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(headers.enumerated()), id: \.0) { index, header in
                HeaderRow(
                    header: Binding(
                        get: { headers[index] },
                        set: { headers[index] = $0 }
                    ),
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            var updated = headers
                            updated.remove(at: index)
                            headers = updated
                        }
                    }
                )
            }
        }
        .padding(8)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct StatusBadge: View {
    let code: Int?
    let label: String
    let color: Color

    var body: some View {
        Text("\(code ?? 0) \(label)")
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.yellow)
            Spacer()
        }
        .padding(8)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(6)
    }
}

struct ResponseModePicker: View {
    @Binding var mode: ResponseViewMode

    var body: some View {
        Picker("View", selection: $mode) {
            ForEach(ResponseViewMode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 90)
    }
}

struct ExpandCollapseButton: View {
    @Binding var treeNodes: [JSONTreeNode]
    @Binding var expandAll: Bool

    var body: some View {
        Button {
            expandAll.toggle()
            treeNodes = expandAll ? treeNodes.map { $0.expandedAll() } : treeNodes.map { $0.allFolded() }
        } label: {
            Text(expandAll ? "Collapse" : "Expand")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct RawBodyView: View {
    let text: String

    var body: some View {
        TextEditor(text: .constant(text))
            .font(.system(.body, design: .monospaced))
            .lineSpacing(2)
            .padding(8)
    }
}

// MARK: - JSON Tree View

struct JSONTreeView: View {
    @Binding var nodes: [JSONTreeNode]
    let indent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                let nodeRef = Binding<JSONTreeNode>(
                    get: { nodes[index] },
                    set: { nodes[index] = $0 }
                )
                JSONRowView(node: nodeRef, indent: indent)
                if index < nodes.count - 1 {
                    Divider().padding(.leading, 20)
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .lineSpacing(2)
    }
}

struct JSONRowView: View {
    @Binding var node: JSONTreeNode
    let indent: Int
    @State private var isHovered: Bool = false

    private var indentWidth: CGFloat {
        CGFloat(indent) * 20
    }

    private var openBrace: String {
        switch node.type {
        case .object: return "{ "
        case .array: return "[ "
        default: return ""
        }
    }

    private var closeBrace: String {
        switch node.type {
        case .object: return "}"
        case .array: return "]"
        default: return ""
        }
    }

    var body: some View {
        Group {
            if node.isContainer {
                foldableRow
            } else {
                scalarRow
            }
        }
        .overlay(alignment: .leading) {
            hoverIndicator
        }
    }

    private var hoverIndicator: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.1))
            .frame(width: isHovered ? 2 : 0)
            .padding(.leading, indentWidth)
            .opacity(isHovered ? 1 : 0)
    }

    // MARK: Foldable row (objects and arrays)

    private var foldableRow: some View {
        VStack(spacing: 0) {
            // Parent row
            HStack(alignment: .center, spacing: 4) {
                // Left indent guides
                if indent > 0 {
                    VStack(spacing: 2) {
                        ForEach(1..<indent, id: \.self) { _ in
                            Rectangle()
                                .fill(isHovered ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                                .frame(width: 1)
                                .frame(height: .infinity, alignment: .top)
                        }
                    }
                    .frame(width: indentWidth - 20)
                }

                // Chevron
                Image(systemName: node.isFolded ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(node.type.color)
                    .frame(width: 16, height: 16)

                // Key
                if let key = node.key {
                    Text("\"\(key)\"").foregroundColor(.blue)
                    Text(":").foregroundColor(.secondary.opacity(0.5))
                }

                // Braces (when expanded) or summary (when folded)
                if node.isFolded {
                    Text(node.foldedSummary())
                        .foregroundColor(.secondary.opacity(0.6))
                } else {
                    Text(openBrace).foregroundColor(.secondary.opacity(0.6))
                }

                Spacer()

                // Badge
                Text("\(node.children.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 4)
            .padding(.leading, indent > 0 ? 4 : 0)
            .background(isHovered ? Color.blue.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.12)) {
                    node.isFolded.toggle()
                }
            }

            // Children (shown when expanded)
            if !node.isFolded {
                JSONTreeView(nodes: Binding(
                    get: { node.children },
                    set: { node.children = $0 }
                ), indent: indent + 1)

                let closeChar = closeBrace
                HStack(spacing: 0) {
                    Spacer()
                    Text(closeChar).foregroundColor(.secondary.opacity(0.35))
                }
            }
        }
    }

    // MARK: Scalar row (primitives)

    private var scalarRow: some View {
        HStack(alignment: .top, spacing: 4) {
            // Left indent guides
            if indent > 0 {
                VStack(spacing: 2) {
                    ForEach(1..<indent, id: \.self) { _ in
                        Rectangle()
                            .fill(isHovered ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                            .frame(width: 1)
                            .frame(height: .infinity, alignment: .top)
                    }
                }
                .frame(width: indentWidth - 20)
            }

            // Key
            if let key = node.key {
                Text("\"\(key)\"").foregroundColor(.blue)
                Text(":").foregroundColor(.secondary.opacity(0.5))
            }

            // Value
            switch node.type {
            case .string(let s):
                Text("\"\(s)\"").foregroundColor(.green.opacity(0.9))
            case .number(let n):
                Text(n).foregroundColor(.orange.opacity(0.9))
            case .boolean(let b):
                Text(b).foregroundColor(.purple.opacity(0.9))
            case .null:
                Text("null").foregroundColor(.gray.opacity(0.8))
            case .object, .array:
                EmptyView()
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.leading, indent > 0 ? 20 : 0)
        .background(isHovered ? Color.blue.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }
}

extension JSONTreeNode {
    func allFolded() -> JSONTreeNode {
        let result = JSONTreeNode(
            key: key, type: type, children: children, isFolded: isFolded, value: value
        )
        result.isFolded = true
        result.children = children.map { $0.allFolded() }
        return result
    }
}
