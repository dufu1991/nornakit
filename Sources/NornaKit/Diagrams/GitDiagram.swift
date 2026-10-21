import Foundation

enum GitDiagram {
    static func render(_ source: String) throws -> DiagramScene {
        struct Commit { let id: String; let lane: Int; let parents: [Int]; let type: String; let tag: String; let message: String }
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.gitGraph)
        let header = lines[0].text.replacingOccurrences(of: ":", with: "").split(whereSeparator: \.isWhitespace)
        guard header.dropFirst().allSatisfy({ ["LR", "TB", "BT"].contains(String($0)) }) else { throw lines[0].error("Git 图方向当前支持 LR、TB 和 BT。") }
        let vertical = header.contains("TB") || header.contains("BT"), reverse = header.contains("BT")
        var branches = ["main"], current = "main", heads: [String: Int] = [:], commits: [Commit] = []
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if let m = DiagramSyntax.match(#"^branch\s+([^\s]+)$"#, s) {
                guard !branches.contains(m[1]) else { throw line.error("分支名称重复。", code: "semantic") }
                branches.append(m[1]); heads[m[1]] = heads[current]; current = m[1]; continue
            }
            if let m = DiagramSyntax.match(#"^(?:checkout|switch)\s+([^\s]+)$"#, s) {
                guard branches.contains(m[1]) else { throw line.error("目标分支不存在。", code: "semantic") }; current = m[1]; continue
            }
            guard let m = DiagramSyntax.match(#"^(commit|merge|cherry-pick)\b\s*(.*)$"#, s) else { throw line.error("暂不支持这条 Git 图语法。") }
            var rest = m[2], parents = heads[current].map { [$0] } ?? []
            if m[1] == "merge" {
                let parts = rest.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard let target = parts.first.map(String.init), target != current, let parent = heads[target] else { throw line.error("无法合并空分支或当前分支。", code: "semantic") }
                parents.append(parent); rest = parts.count > 1 ? String(parts[1]) : ""
            }
            let idField = DiagramSyntax.match(#"\bid:\s*"([^"]+)""#, rest)?[1]
            if m[1] == "cherry-pick" {
                guard let idField, let index = commits.firstIndex(where: { $0.id == idField }) else { throw line.error("cherry-pick 引用的提交不存在。", code: "semantic") }
                parents.append(index)
            }
            let id = m[1] == "cherry-pick" ? "pick-\(commits.count)" : idField ?? "c\(commits.count)"
            guard !commits.contains(where: { $0.id == id }) else { throw line.error("提交标识符重复。", code: "semantic") }
            let type = DiagramSyntax.match(#"\btype:\s*(NORMAL|REVERSE|HIGHLIGHT)\b"#, rest)?[1] ?? m[1]
            let tag = DiagramSyntax.match(#"\btag:\s*"([^"]+)""#, rest)?[1] ?? ""
            let message = DiagramSyntax.match(#"\bmsg:\s*"([^"]+)""#, rest)?[1] ?? ""
            for field in ["id", "tag", "msg", "type"] {
                let regex = try! NSRegularExpression(pattern: "\\b" + field + ":")
                guard regex.numberOfMatches(in: rest, range: NSRange(rest.startIndex..., in: rest)) <= 1 else { throw line.error("同一个提交属性不能重复。", code: "semantic") }
            }
            let cleaned = rest.replacingOccurrences(of: #"\b(?:id|tag|msg):\s*"[^"]*"|\btype:\s*(?:NORMAL|REVERSE|HIGHLIGHT)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            guard cleaned.isEmpty else { throw line.error("暂不支持这条提交属性：\(cleaned)") }
            commits.append(Commit(id: id, lane: branches.firstIndex(of: current)!, parents: parents, type: type, tag: tag, message: message)); heads[current] = commits.count - 1
        }
        try DiagramSyntax.nonempty(commits.count, kind: .gitGraph)
        let timeLength = CGFloat(commits.count) * 100 + 140, laneLength = CGFloat(branches.count) * 90 + 100
        let width = vertical ? laneLength : timeLength, top = b.title(DiagramSyntax.title(lines), width: width)
        let point: (Int) -> CGPoint = { index in
            let time = 110 + CGFloat(reverse ? commits.count - 1 - index : index) * 100, lane = 80 + CGFloat(commits[index].lane) * 90
            return vertical ? CGPoint(x: lane, y: time + top) : CGPoint(x: time, y: lane + top)
        }
        for (i, branch) in branches.enumerated() {
            let lane = 80 + CGFloat(i) * 90
            if vertical { b.text(branch, CGRect(x: lane - 40, y: top + 32, width: 80, height: 28), size: 14, color: .series(i)); b.line([CGPoint(x: lane, y: top + 76), CGPoint(x: lane, y: top + timeLength - 20)], color: .series(i), dash: [2, 4]) }
            else { b.text(branch, CGRect(x: 8, y: lane + top - 14, width: 84, height: 28), size: 14, color: .series(i)); b.line([CGPoint(x: 96, y: lane + top), CGPoint(x: width - 20, y: lane + top)], color: .series(i), dash: [2, 4]) }
        }
        for (i, commit) in commits.enumerated() {
            let p = point(i)
            for parent in commit.parents {
                let a = point(parent)
                let controls = vertical ? (CGPoint(x: a.x, y: (a.y + p.y) / 2), CGPoint(x: p.x, y: (a.y + p.y) / 2))
                    : (CGPoint(x: (a.x + p.x) / 2, y: a.y), CGPoint(x: (a.x + p.x) / 2, y: p.y))
                b.path([.move(a), .cubic(controls.0, controls.1, p)], stroke: .series(commit.lane), width: 2, dash: commit.type == "cherry-pick" ? [4, 3] : [])
            }
            let dot = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
            if commit.type == "HIGHLIGHT" { b.rect(dot, fill: .series(commit.lane), stroke: .none, radius: 2, id: commit.id, label: commit.id) }
            else { b.ellipse(dot, fill: commit.type == "merge" ? .background : .series(commit.lane), stroke: .series(commit.lane), id: commit.id, label: commit.id) }
            if commit.type == "merge" { b.ellipse(dot.insetBy(dx: 4, dy: 4), fill: .series(commit.lane), stroke: .none) }
            if commit.type == "REVERSE" { b.line([CGPoint(x: p.x - 3, y: p.y - 3), CGPoint(x: p.x + 3, y: p.y + 3)], color: .background) }
            b.text(commit.message.isEmpty ? commit.id : commit.message, CGRect(x: p.x - 42, y: p.y + 14, width: 84, height: 24), size: 12)
            if !commit.tag.isEmpty { b.box(commit.tag, CGRect(x: p.x - 40, y: p.y - 42, width: 80, height: 24), fill: .surfaceAlt, size: 12) }
        }
        return b.scene(width: width, height: top + (vertical ? timeLength : laneLength))
    }
}
