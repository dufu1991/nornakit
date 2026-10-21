import Foundation

public enum MermaidFlowchartParser {
    public static func parse(_ source: String) throws -> FlowchartModel {
        guard source.utf16.count <= 50_000 else {
            throw DiagramRenderError(message: "源码超过 50000 个字符。", code: "limit")
        }
        let statements = try splitStatements(source)
        guard let header = statements.first else {
            throw DiagramRenderError(message: "请输入 flowchart TD 或 graph LR 开始绘制。", code: "syntax", line: 1)
        }
        let parts = header.text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 2, ["flowchart", "graph"].contains(String(parts[0])) else {
            throw DiagramRenderError(message: "第一版支持 flowchart 和 graph 流程图，请使用独立的方向声明行。", code: "unsupported-diagram", line: header.line)
        }
        let directionName = parts[1] == "TB" ? "TD" : String(parts[1])
        guard var direction = FlowDirection(rawValue: directionName) else {
            throw DiagramRenderError(message: "流程图方向支持 TD、TB、BT、LR 和 RL。", code: "syntax", line: header.line)
        }
        var nodes: [FlowNode] = []
        var positions: [String: Int] = [:]
        var edges: [FlowEdge] = []
        var groups: [FlowGroup] = []
        var groupPositions: [String: Int] = [:]
        var groupStack: [(index: Int, line: Int)] = []
        var explicitNodes = Set<String>()
        var sequence = 0
        let register: (FlowNode, Bool) -> Void = { node, explicit in
            var node = node
            let parent = groupStack.last.map { groups[$0.index].id }
            if explicit { explicitNodes.insert(node.id) }
            if let index = positions[node.id] {
                if explicit { nodes[index].label = node.label; nodes[index].shape = node.shape }
                if nodes[index].parentID == nil { nodes[index].parentID = parent }
            } else {
                node.parentID = parent
                node.sequence = sequence
                sequence += 1
                positions[node.id] = nodes.count
                nodes.append(node)
            }
        }
        for statement in statements.dropFirst() {
            var scanner = Scanner(text: statement.text, line: statement.line)
            if statement.text == "end" {
                guard !groupStack.isEmpty else { throw scanner.error("end 没有对应的 subgraph。") }
                groupStack.removeLast()
                continue
            }
            if statement.text == "subgraph" || statement.text.hasPrefix("subgraph ") || statement.text.hasPrefix("subgraph\t") {
                let header = try groupHeader(String(statement.text.dropFirst(8)), line: statement.line, anonymousIndex: groups.count)
                let parent = groupStack.last.map { groups[$0.index].id }
                guard groupStack.count < 16 else { throw scanner.error("子图最多嵌套 16 层。", code: "limit") }
                if let index = groupPositions[header.id] {
                    guard !groupStack.contains(where: { $0.index == index }), groups[index].parentID == parent else {
                        throw scanner.error("子图不能包含自身，也不能在不同父级下重复声明。", code: "semantic")
                    }
                    groups[index].label = header.label
                    groupStack.append((index, statement.line))
                } else {
                    guard groups.count < 64 else { throw scanner.error("最多支持 64 个子图。", code: "limit") }
                    groupPositions[header.id] = groups.count
                    groupStack.append((groups.count, statement.line))
                    groups.append(FlowGroup(id: header.id, label: header.label, parentID: parent, direction: nil, sequence: sequence))
                    sequence += 1
                }
                continue
            }
            if statement.text.hasPrefix("direction ") || statement.text.hasPrefix("direction\t") {
                let value = statement.text.split(whereSeparator: \.isWhitespace)
                guard value.count == 2, let local = FlowDirection(rawValue: value[1] == "TB" ? "TD" : String(value[1])) else {
                    throw scanner.error("子图方向支持 TD、TB、BT、LR 和 RL。")
                }
                if let group = groupStack.last { groups[group.index].direction = local }
                else { direction = local }
                continue
            }
            let unsupported = ["style", "classDef", "class", "click", "linkStyle"]
            if unsupported.contains(where: { statement.text == $0 || statement.text.hasPrefix($0 + " ") }) {
                throw scanner.error("暂不支持样式指令和交互指令。", code: "unsupported-syntax")
            }
            var left = try scanner.nodeList(register: register)
            while !scanner.atEnd {
                let connection = try scanner.connection()
                let right = try scanner.nodeList(register: register)
                guard edges.count + left.count * right.count <= 500 else {
                    throw scanner.error("第一版最多支持 500 条连线。", code: "limit")
                }
                for from in left {
                    for to in right {
                        edges.append(FlowEdge(from: from, to: to, label: connection.label, style: connection.style, arrow: connection.end == .arrow,
                                              startMarker: connection.start, endMarker: connection.end, minimumRankSpan: connection.span))
                    }
                }
                left = right
            }
        }
        if let unclosed = groupStack.last {
            throw DiagramRenderError(message: "子图尚未使用 end 闭合。", code: "syntax", line: unclosed.line)
        }
        if let collision = groups.first(where: { explicitNodes.contains($0.id) }) {
            throw DiagramRenderError(message: "子图与带形状的节点不能共用标识符：\(collision.id)。", code: "semantic")
        }
        // A forward edge may name a group before its declaration. Such references are not nodes.
        nodes.removeAll { groupPositions[$0.id] != nil }
        guard !nodes.isEmpty || !groups.isEmpty else {
            throw DiagramRenderError(message: "请在方向声明下添加节点，例如 A[开始] --> B[结束]。", code: "syntax", line: header.line)
        }
        guard nodes.count <= 200 else {
            throw DiagramRenderError(message: "第一版最多支持 200 个节点。", code: "limit")
        }
        return FlowchartModel(direction: direction, nodes: nodes, edges: edges, groups: groups)
    }

    private static func groupHeader(_ text: String, line: Int, anonymousIndex: Int) throws -> (id: String, label: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        let anonymousID = "@group_\(anonymousIndex)"
        let unquote: (String) -> String = { value in
            let value = value.trimmingCharacters(in: .whitespaces)
            let result = value.first?.asciiValue == 34 && value.last?.asciiValue == 34 && value.count >= 2
                ? String(value.dropFirst().dropLast()) : value
            return result.replacingOccurrences(of: "<br/>", with: "\n").replacingOccurrences(of: "<br />", with: "\n")
                .replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "\\n", with: "\n")
        }
        if text.first?.asciiValue == 34 { return (anonymousID, unquote(text)) }
        if let bracket = text.firstIndex(of: "[") {
            let id = String(text[..<bracket]).trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }), text.last == "]" else {
                throw DiagramRenderError(message: "子图声明应写作 subgraph ID[标题]。", code: "syntax", line: line)
            }
            let label = unquote(String(text[text.index(after: bracket)..<text.index(before: text.endIndex)]))
            return (id, label)
        }
        guard !text.isEmpty else { throw DiagramRenderError(message: "子图需要标题或标识符。", code: "syntax", line: line) }
        return (text.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" } ? text : anonymousID, unquote(text))
    }

    private struct Statement {
        let text: String
        let line: Int
    }

    private static func splitStatements(_ source: String) throws -> [Statement] {
        let characters = Array(source)
        var statements: [Statement] = []
        var buffer = ""
        var stack: [Character] = []
        var quoted = false
        var line = 1
        var startLine = 1
        var i = 0
        let append = { (buffer: String, line: Int) in
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { statements.append(Statement(text: text, line: line)) }
        }
        while i < characters.count {
            let c = characters[i]
            if !quoted, stack.isEmpty, c == "%", i + 1 < characters.count, characters[i + 1] == "%" {
                while i < characters.count, characters[i] != "\n" { i += 1 }
                continue
            }
            if c == "\"" { quoted.toggle() }
            if !quoted {
                if c == ">", stack.isEmpty, let previous = buffer.trimmingCharacters(in: .whitespaces).last,
                   previous.isLetter || previous.isNumber || previous == "_" { stack.append("]") }
                if c == "[" { stack.append("]") }
                if c == "(" { stack.append(")") }
                if c == "{" { stack.append("}") }
                if ["]", ")", "}"].contains(c) {
                    guard stack.last == c else {
                        throw DiagramRenderError(message: "节点括号不匹配。", code: "syntax", line: line)
                    }
                    stack.removeLast()
                }
            }
            if (c == "\n" || c == ";"), stack.isEmpty, !quoted {
                append(buffer, startLine)
                buffer = ""
                startLine = c == "\n" ? line + 1 : line
            } else {
                if buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !c.isWhitespace { startLine = line }
                buffer.append(c)
            }
            if c == "\n" { line += 1 }
            i += 1
        }
        guard stack.isEmpty, !quoted else {
            throw DiagramRenderError(message: "节点的括号或双引号尚未闭合。", code: "syntax", line: startLine)
        }
        append(buffer, startLine)
        return statements
    }

    private struct Connection {
        let label: String
        let style: EdgeStyle
        var start: EdgeMarker = .none
        var end: EdgeMarker = .arrow
        var span: Int = 1
    }

    private struct Scanner {
        let characters: [Character]
        let line: Int
        var index = 0
        init(text: String, line: Int) { characters = Array(text); self.line = line }
        var atEnd: Bool { characters.dropFirst(index).allSatisfy(\.isWhitespace) }
        mutating func space() { while index < characters.count, characters[index].isWhitespace { index += 1 } }
        func has(_ token: String) -> Bool { characters.dropFirst(index).starts(with: token) }
        mutating func consume(_ token: String) -> Bool {
            guard has(token) else { return false }
            index += token.count
            return true
        }
        func error(_ message: String, code: String = "syntax") -> DiagramRenderError {
            DiagramRenderError(message: message, code: code, line: line, column: index + 1)
        }

        mutating func nodeList(register: (FlowNode, Bool) -> Void) throws -> [String] {
            var ids = [try node(register: register)]
            space()
            while consume("&") {
                ids.append(try node(register: register))
                space()
            }
            return ids
        }

        mutating func node(register: (FlowNode, Bool) -> Void) throws -> String {
            space()
            let start = index
            while index < characters.count {
                let c = characters[index]
                if c.isLetter || c.isNumber || c == "_" { index += 1 } else { break }
            }
            guard index > start else { throw error("此处需要节点标识符。第一版支持字母、数字、中文和下划线。") }
            let id = String(characters[start..<index])
            space()
            if consume("@{") {
                let attributes = try readUntil("}")
                var values: [String: String] = [:]
                for item in DiagramSyntax.split(attributes) {
                    guard let m = DiagramSyntax.match(#"^\s*(shape|label)\s*:\s*(.+?)\s*$"#, item), values[m[1]] == nil else {
                        throw error("节点属性仅支持不重复的 shape 和 label。", code: "unsupported-syntax")
                    }
                    values[m[1]] = DiagramSyntax.label(m[2])
                }
                let name = values["shape"] ?? "rect"
                guard let shape = Self.shapes[name] else { throw error("暂不支持节点形状：\(name)。", code: "unsupported-syntax") }
                register(FlowNode(id: id, label: values["label"] ?? id, shape: shape), true)
                return id
            }
            let shapes: [(String, String, NodeShape)] = [
                ("(((", ")))", .doubleCircle), ("{{", "}}", .hexagon),
                ("[/", "/]", .parallelogram), ("[\\", "\\]", .parallelogramAlt),
                ("[/", "\\]", .trapezoid), ("[\\", "/]", .trapezoidAlt), (">", "]", .asymmetric),
                ("([", "])", .stadium), ("((", "))", .circle), ("[[", "]]", .subroutine),
                ("[(", ")]", .cylinder), ("[", "]", .rectangle), ("(", ")", .rounded), ("{", "}", .diamond)
            ]
            for (open, close, shape) in shapes where matchesShape(open: open, close: close) {
                _ = consume(open)
                let labelStart = index
                var quoted = false
                while index < characters.count {
                    if characters[index] == "\"" { quoted.toggle() }
                    if !quoted, has(close) { break }
                    index += 1
                }
                guard index < characters.count else { throw error("节点标签尚未闭合。") }
                var label = String(characters[labelStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                index += close.count
                if label.first?.asciiValue == 34, label.last?.asciiValue == 34, label.count >= 2 { label = String(label.dropFirst().dropLast()) }
                label = label.replacingOccurrences(of: "<br/>", with: "\n")
                    .replacingOccurrences(of: "<br />", with: "\n")
                    .replacingOccurrences(of: "<br>", with: "\n")
                    .replacingOccurrences(of: "\\n", with: "\n")
                register(FlowNode(id: id, label: label, shape: shape), true)
                return id
            }
            register(FlowNode(id: id, label: id, shape: .rectangle), false)
            return id
        }

        private func matchesShape(open: String, close: String) -> Bool {
            guard has(open) else { return false }
            guard open == "[/" || open == "[\\" else { return true }
            var quoted = false
            for position in (index + open.count)..<characters.count {
                if characters[position] == "\"" { quoted.toggle() }
                if !quoted, characters[position] == "]" {
                    return String(characters[(position - close.count + 1)...position]) == close
                }
            }
            return false
        }

        mutating func connection() throws -> Connection {
            space()
            let rest = String(characters.dropFirst(index))
            if let m = DiagramSyntax.match(#"^~{3,}"#, rest) {
                index += m[0].count
                guard m[0].count <= 12 else { throw error("不可见连线最多跨越 10 层。", code: "limit") }
                return Connection(label: "", style: .invisible, end: .none, span: m[0].count - 2)
            }
            if let m = DiagramSyntax.match(#"^([<ox]?)(-{2,}|={2,}|-\.+-)([>ox]?)"#, rest),
               !m[1].isEmpty || !m[3].isEmpty || m[2].count >= 3 {
                index += m[0].count
                space()
                let label = consume("|") ? try readUntil("|") : ""
                let marker: (String) -> EdgeMarker = { $0 == "o" ? .circle : $0 == "x" ? .cross : $0.isEmpty ? .none : .arrow }
                let dashed = m[2].contains("."), headed = !m[1].isEmpty || !m[3].isEmpty
                let span = dashed ? m[2].filter { $0 == "." }.count : max(1, m[2].count - (headed ? 1 : 2))
                guard span <= 10 else { throw error("连线最多跨越 10 层。", code: "limit") }
                return Connection(label: label, style: dashed ? .dashed : m[2].contains("=") ? .thick : .solid,
                                  start: marker(m[1]), end: marker(m[3]), span: span)
            }
            let labeled: [(String, String, EdgeStyle)] = [("--", "-->", .solid), ("-.", ".->", .dashed), ("==", "==>", .thick)]
            for (open, close, style) in labeled where consume(open) {
                let label = try readUntil(close).trimmingCharacters(in: .whitespaces)
                return Connection(label: label, style: style)
            }
            throw error("此处需要连线，例如 -->、-->|标签|、-.-> 或 ==>。")
        }

        private static let shapes: [String: NodeShape] = [
            "rect": .rectangle, "rectangle": .rectangle, "rounded": .rounded, "round": .rounded,
            "stadium": .stadium, "pill": .stadium, "circle": .circle, "dbl-circ": .doubleCircle, "double-circle": .doubleCircle,
            "diam": .diamond, "diamond": .diamond, "decision": .diamond, "hex": .hexagon, "hexagon": .hexagon,
            "cyl": .cylinder, "cylinder": .cylinder, "database": .cylinder, "fr-rect": .subroutine, "subroutine": .subroutine,
            "odd": .asymmetric, "lean-r": .parallelogram, "lean-l": .parallelogramAlt,
            "trap-b": .trapezoid, "trap-t": .trapezoidAlt
        ]

        mutating func readUntil(_ delimiter: String) throws -> String {
            let start = index
            var quoted = false
            while index < characters.count {
                if characters[index] == "\"" { quoted.toggle() }
                if !quoted, has(delimiter) {
                    var value = String(characters[start..<index])
                    index += delimiter.count
                    if value.first?.asciiValue == 34, value.last?.asciiValue == 34, value.count >= 2 { value = String(value.dropFirst().dropLast()) }
                    return value
                }
                index += 1
            }
            throw error("连线标签尚未闭合。")
        }
    }
}
