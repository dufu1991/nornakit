import Foundation

indirect enum RailExpression {
    case atom(String, Bool), sequence([RailExpression]), choice([RailExpression]), optional(RailExpression), repetition(RailExpression), empty
}

enum RailroadDiagram {
    private struct Token { let value: String; let quoted: Bool; let line: Int }
    private struct Layout { let width: CGFloat; let height: CGFloat; let baseline: CGFloat }

    static func render(_ source: String) throws -> DiagramScene {
        let lines = source.components(separatedBy: .newlines)
        let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") })!
        let header = lines[first].trimmingCharacters(in: .whitespaces)
        let body = lines.dropFirst(first + 1).enumerated().map { _, line in
            let clean = line.trimmingCharacters(in: .whitespaces)
            return (header.contains("abnf") || header.contains("peg")) && !clean.isEmpty && !clean.hasPrefix("%%") && !clean.hasSuffix(";") ? line + ";" : line
        }.joined(separator: "\n")
        var parser = Parser(tokens: try tokenize(body, lineOffset: first + 2))
        var rules: [(String, RailExpression)] = []
        while !parser.done {
            let name = try parser.take()
            guard !name.quoted, name.value.first?.isLetter == true, parser.consume("=") || parser.consume("<-") else { throw parser.error("铁路图规则需要名称和 = 或 <-。") }
            let expression = try parser.choice(stops: [";"])
            guard parser.consume(";") else { throw parser.error("规则缺少分号。") }
            guard !rules.contains(where: { $0.0 == name.value }) else { throw parser.error("规则名称重复。") }
            rules.append((name.value, expression))
        }
        try DiagramSyntax.nonempty(rules.count, kind: .railroad)
        let layouts = rules.map { layout($0.1) }, width = max(360, (layouts.map(\.width).max() ?? 0) + 72), b = SceneBuilder(.railroad)
        var y: CGFloat = 12
        for (i, rule) in rules.enumerated() {
            let size = layouts[i]
            b.text(rule.0, CGRect(x: 16, y: y, width: width - 32, height: 26), size: 15, align: .leading, bold: true)
            y += 36
            let baseline = y + size.baseline
            b.line([CGPoint(x: 12, y: baseline - 8), CGPoint(x: 12, y: baseline + 8)])
            b.line([CGPoint(x: 18, y: baseline - 8), CGPoint(x: 18, y: baseline + 8)])
            b.line([CGPoint(x: 18, y: baseline), CGPoint(x: 36, y: baseline)])
            draw(rule.1, x: 36, y: y, builder: b)
            b.line([CGPoint(x: 36 + size.width, y: baseline), CGPoint(x: 54 + size.width, y: baseline)])
            b.line([CGPoint(x: 54 + size.width, y: baseline - 8), CGPoint(x: 54 + size.width, y: baseline + 8)])
            b.line([CGPoint(x: 60 + size.width, y: baseline - 8), CGPoint(x: 60 + size.width, y: baseline + 8)])
            y += size.height + 28
        }
        return b.scene(width: width, height: y)
    }

    private static func tokenize(_ source: String, lineOffset: Int) throws -> [Token] {
        let chars = Array(source)
        var result: [Token] = [], i = 0, line = lineOffset
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { if c == "\n" { line += 1 }; i += 1; continue }
            if c == "%", i + 1 < chars.count, chars[i + 1] == "%" { while i < chars.count && chars[i] != "\n" { i += 1 }; continue }
            if c == "\"" || c == "'" {
                let quote = c, startLine = line; i += 1
                var text = "", closed = false
                while i < chars.count {
                    if chars[i] == quote { closed = true; i += 1; break }
                    if chars[i] == "\\", i + 1 < chars.count { i += 1; text.append(chars[i] == "n" ? "\n" : chars[i]) }
                    else { text.append(chars[i]) }
                    i += 1
                }
                guard closed else { throw DiagramRenderError(message: "铁路图字符串尚未闭合。", code: "syntax", line: startLine) }
                result.append(Token(value: text, quoted: true, line: startLine)); continue
            }
            if c.isLetter || c == "_" {
                let start = i
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || "_.-".contains(chars[i]) { i += 1 }
                result.append(Token(value: String(chars[start..<i]), quoted: false, line: line)); continue
            }
            if c == "<", i + 1 < chars.count, chars[i + 1] == "-" { result.append(Token(value: "<-", quoted: false, line: line)); i += 2; continue }
            guard "=;|/[]{}()?*+,".contains(c) else { throw DiagramRenderError(message: "铁路图暂不支持这个词法符号：\(c)。", code: "unsupported-syntax", line: line) }
            result.append(Token(value: String(c), quoted: false, line: line)); i += 1
        }
        return result
    }

    private struct Parser {
        let tokens: [Token]
        var index = 0
        var depth = 0
        var done: Bool { index == tokens.count }
        func error(_ message: String) -> DiagramRenderError { DiagramRenderError(message: message, code: "syntax", line: index < tokens.count ? tokens[index].line : tokens.last?.line) }
        mutating func take() throws -> Token { guard !done else { throw error("语法表达式意外结束。") }; defer { index += 1 }; return tokens[index] }
        mutating func consume(_ value: String) -> Bool {
            guard !done, !tokens[index].quoted, tokens[index].value == value else { return false }; index += 1; return true
        }
        mutating func choice(stops: Set<String>) throws -> RailExpression {
            depth += 1; defer { depth -= 1 }
            guard depth <= 32 else { throw error("语法表达式最多嵌套 32 层。") }
            var values = [try sequence(stops: stops.union(["|", "/"]))]
            while consume("|") || consume("/") { values.append(try sequence(stops: stops.union(["|", "/"]))) }
            return values.count == 1 ? values[0] : .choice(values)
        }
        mutating func sequence(stops: Set<String>) throws -> RailExpression {
            var values: [RailExpression] = []
            while !done && (tokens[index].quoted || !stops.contains(tokens[index].value)) {
                if !stops.contains(","), consume(",") { continue }
                values.append(try atom())
            }
            guard !values.isEmpty else { throw error("缺少语法表达式。") }
            return values.count == 1 ? values[0] : .sequence(values)
        }
        mutating func atom() throws -> RailExpression {
            let token = try take()
            var value: RailExpression
            if token.quoted { value = .atom(token.value, true) }
            else if token.value == "[" || token.value == "{" || token.value == "(" {
                let closing = ["[": "]", "{": "}", "(": ")"][token.value]!
                let expression = try choice(stops: [closing])
                guard consume(closing) else { throw error("语法表达式括号不匹配。") }
                value = token.value == "[" ? .optional(expression) : token.value == "{" ? .optional(.repetition(expression)) : expression
            } else if token.value.first?.isLetter == true || token.value.first == "_" {
                if consume("(") {
                    let name = token.value.lowercased()
                    if name == "terminal" || name == "nonterminal" {
                        let text = try take(); guard text.quoted, consume(")") else { throw error("terminal 和 nonterminal 需要一个字符串参数。") }
                        value = .atom(text.value, name == "terminal")
                    } else {
                        var expressions = [try choice(stops: [",", ")"])]
                        while consume(",") { expressions.append(try choice(stops: [",", ")"])) }
                        guard consume(")") else { throw error("铁路图函数缺少结束括号。") }
                        switch name {
                        case "sequence": value = .sequence(expressions)
                        case "choice": value = .choice(expressions)
                        case "optional" where expressions.count == 1: value = .optional(expressions[0])
                        case "zeroormore" where expressions.count == 1: value = .optional(.repetition(expressions[0]))
                        case "oneormore" where expressions.count == 1: value = .repetition(expressions[0])
                        default: throw error("暂不支持铁路图函数 \(token.value)。")
                        }
                    }
                } else { value = .atom(token.value, false) }
            } else { throw error("此处需要终结符、规则名称或分组表达式。") }
            if consume("?") { value = .optional(value) }
            else if consume("*") { value = .optional(.repetition(value)) }
            else if consume("+") { value = .repetition(value) }
            return value
        }
    }

    private static func layout(_ expression: RailExpression) -> Layout {
        switch expression {
        case .empty: return Layout(width: 32, height: 30, baseline: 15)
        case .atom(let label, _): return Layout(width: max(52, TextMeasurement.width(label, size: 14) + 28), height: 30, baseline: 15)
        case .sequence(let children):
            let sizes = children.map(layout), baseline = sizes.map(\.baseline).max()!
            return Layout(width: sizes.reduce(0) { $0 + $1.width } + CGFloat(children.count - 1) * 20,
                          height: baseline + sizes.map { $0.height - $0.baseline }.max()!, baseline: baseline)
        case .choice(let children):
            let sizes = children.map(layout)
            return Layout(width: sizes.map(\.width).max()! + 48, height: sizes.reduce(0) { $0 + $1.height } + CGFloat(children.count - 1) * 18, baseline: sizes[0].baseline)
        case .optional(let child): return layout(.choice([.empty, child]))
        case .repetition(let child): let size = layout(child); return Layout(width: size.width + 48, height: size.height + 34, baseline: size.baseline)
        }
    }

    private static func draw(_ expression: RailExpression, x: CGFloat, y: CGFloat, builder b: SceneBuilder) {
        let size = layout(expression)
        switch expression {
        case .empty: b.line([CGPoint(x: x, y: y + 15), CGPoint(x: x + size.width, y: y + 15)])
        case .atom(let label, let terminal):
            let r = CGRect(x: x, y: y, width: size.width, height: 30)
            b.rect(r, fill: terminal ? .surface : .background, radius: terminal ? 15 : 4)
            b.text(label, r.insetBy(dx: 8, dy: 2), size: 14, mono: true)
        case .sequence(let children):
            var cursor = x
            for (index, child) in children.enumerated() {
                let childSize = layout(child)
                draw(child, x: cursor, y: y + size.baseline - childSize.baseline, builder: b)
                cursor += childSize.width
                if index < children.count - 1 { b.line([CGPoint(x: cursor, y: y + size.baseline), CGPoint(x: cursor + 20, y: y + size.baseline)]); cursor += 20 }
            }
        case .choice(let children):
            var top = y
            let start = CGPoint(x: x, y: y + size.baseline), end = CGPoint(x: x + size.width, y: y + size.baseline)
            for child in children {
                let childSize = layout(child), childX = x + (size.width - childSize.width) / 2, baseline = top + childSize.baseline
                b.line([start, CGPoint(x: x + 12, y: start.y), CGPoint(x: x + 12, y: baseline), CGPoint(x: childX, y: baseline)])
                draw(child, x: childX, y: top, builder: b)
                b.line([CGPoint(x: childX + childSize.width, y: baseline), CGPoint(x: end.x - 12, y: baseline), CGPoint(x: end.x - 12, y: end.y), end])
                top += childSize.height + 18
            }
        case .optional(let child): draw(.choice([.empty, child]), x: x, y: y, builder: b)
        case .repetition(let child):
            let childSize = layout(child), baseline = y + size.baseline, bottom = y + childSize.height + 22
            b.line([CGPoint(x: x, y: baseline), CGPoint(x: x + 24, y: baseline)])
            draw(child, x: x + 24, y: y, builder: b)
            b.line([CGPoint(x: x + 24 + childSize.width, y: baseline), CGPoint(x: x + size.width, y: baseline)])
            b.line([CGPoint(x: x + size.width - 8, y: baseline), CGPoint(x: x + size.width - 8, y: bottom), CGPoint(x: x + 8, y: bottom), CGPoint(x: x + 8, y: baseline)], arrow: true)
        }
    }
}
