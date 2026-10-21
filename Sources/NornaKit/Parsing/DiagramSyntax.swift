import Foundation

struct SourceLine {
    let text: String
    let raw: String
    let number: Int
    var indent: Int { raw.prefix(while: \.isWhitespace).reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } }
    func error(_ message: String, code: String = "unsupported-syntax") -> DiagramRenderError {
        DiagramRenderError(message: message, code: code, line: number)
    }
}

enum DiagramSyntax {
    static func lines(_ source: String) -> [SourceLine] {
        source.components(separatedBy: .newlines).enumerated().compactMap { index, raw in
            var text = raw.trimmingCharacters(in: .whitespaces)
            var quote = false
            let chars = Array(text)
            if chars.count > 1 {
                for i in 0..<(chars.count - 1) {
                    if chars[i] == "\"" { quote.toggle() }
                    if !quote, chars[i] == "%", chars[i + 1] == "%" { text = String(chars[..<i]).trimmingCharacters(in: .whitespaces); break }
                }
            }
            return text.isEmpty ? nil : SourceLine(text: text, raw: raw, number: index + 1)
        }
    }

    static func match(_ pattern: String, _ value: String) -> [String]? {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let result = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        return (0..<result.numberOfRanges).map { i in Range(result.range(at: i), in: value).map { String(value[$0]) } ?? "" }
    }

    static func label(_ value: String) -> String {
        var value = value.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.first == "\"", value.last == "\"" { value = String(value.dropFirst().dropLast()) }
        return value.replacingOccurrences(of: "<br/>", with: "\n").replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "\\n", with: "\n")
    }

    static func number(_ text: String, line: SourceLine, positive: Bool = false) throws -> Double {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value.isFinite,
              abs(value) <= 1e12, !positive || value > 0 else {
            throw line.error("需要有限的\(positive ? "正" : "")数值。", code: "semantic")
        }
        return value
    }

    static func split(_ value: String, separator: Character = ",") -> [String] {
        var values: [String] = [], buffer = "", quoted = false, depth = 0
        for c in value {
            if c == "\"" { quoted.toggle() }
            if !quoted {
                if "([{<".contains(c) { depth += 1 }
                if ")]}>".contains(c) { depth -= 1 }
            }
            if c == separator, !quoted, depth == 0 { values.append(buffer.trimmingCharacters(in: .whitespaces)); buffer = "" }
            else { buffer.append(c) }
        }
        values.append(buffer.trimmingCharacters(in: .whitespaces))
        return values
    }

    static func title(_ lines: [SourceLine]) -> String {
        lines.first(where: { $0.text.hasPrefix("title ") }).map { label(String($0.text.dropFirst(6))) } ?? ""
    }

    static func nonempty(_ count: Int, kind: DiagramKind) throws {
        guard count > 0 else { throw DiagramRenderError(message: "\(kind.title)没有可绘制的数据。", code: "semantic") }
        guard count <= 500 else { throw DiagramRenderError(message: "单张图最多包含 500 个数据项。", code: "limit") }
    }
}
