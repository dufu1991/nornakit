import Foundation

enum TemporalDiagrams {
    static func timeline(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.timeline)
        var events: [(String, [String], String)] = [], section = ""
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { continue }
            if line.text.hasPrefix("section ") { section = String(line.text.dropFirst(8)); continue }
            let parts = line.text.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { throw line.error("时间线事件需要时间标签和冒号分隔的事件。", code: "syntax") }
            if parts[0].isEmpty {
                guard !events.isEmpty else { throw line.error("续写事件前需要一个时间标签。", code: "semantic") }
                events[events.count - 1].1 += parts.dropFirst()
            } else { events.append((parts[0], Array(parts.dropFirst()), section)) }
        }
        try DiagramSyntax.nonempty(events.count, kind: .timeline)
        let naturalWidth = max(520, CGFloat(events.count) * 200 + 40)
        if let maxWidth = options.maxWidth, options.autoDirection, naturalWidth > maxWidth {
            let width = options.width(naturalWidth), top = b.title(DiagramSyntax.title(lines), width: width)
            var y = top + 12
            let track = SceneBuilder(.timeline)
            for (i, event) in events.enumerated() {
                let start = y
                b.text(event.2, CGRect(x: 72, y: y, width: width - 96, height: 24), size: 12, color: .muted, align: .leading)
                y += 28
                b.box(event.0, CGRect(x: 72, y: y, width: width - 96, height: 42), fill: .surfaceAlt, size: 15)
                b.ellipse(CGRect(x: 31, y: y + 16, width: 10, height: 10), fill: .series(i), stroke: .background)
                y += 56
                for (j, label) in event.1.enumerated() {
                    let text = TextMeasurement.lines(DiagramSyntax.label(label), maxWidth: width - 120).joined(separator: "\n")
                    let h = CGFloat(text.components(separatedBy: "\n").count) * 20 + 20
                    b.rect(CGRect(x: 72, y: y, width: width - 96, height: h), fill: .series(i), stroke: .none, opacity: 0.15, id: "event-\(i)-\(j)", label: text)
                    b.text(text, CGRect(x: 80, y: y + 6, width: width - 112, height: h - 12), size: 14)
                    y += h + 10
                }
                track.line([CGPoint(x: 36, y: start), CGPoint(x: 36, y: y + 12)], color: .border, width: 2)
                y += 24
            }
            b.primitives = track.primitives + b.primitives
            return b.scene(width: width, height: y + 12)
        }
        let width = naturalWidth, top = b.title(DiagramSyntax.title(lines), width: width)
        b.line([CGPoint(x: 20, y: top + 90), CGPoint(x: width - 20, y: top + 90)], width: 2, arrow: true)
        var height = top + 160
        for (i, event) in events.enumerated() {
            let x = 24 + CGFloat(i) * 200, color = SceneColor.series(i)
            b.text(event.2, CGRect(x: x, y: top + 4, width: 180, height: 24), size: 12, color: .muted)
            b.box(event.0, CGRect(x: x, y: top + 36, width: 180, height: 42), fill: .surfaceAlt, size: 15)
            b.ellipse(CGRect(x: x + 85, y: top + 85, width: 10, height: 10), fill: color, stroke: .background)
            var y = top + 112
            for (j, label) in event.1.enumerated() {
                let text = TextMeasurement.lines(DiagramSyntax.label(label), maxWidth: 152).joined(separator: "\n"), h = CGFloat(text.components(separatedBy: "\n").count) * 20 + 20
                b.rect(CGRect(x: x, y: y, width: 180, height: h), fill: color, stroke: .none, opacity: 0.15, id: "event-\(i)-\(j)", label: text)
                b.text(text, CGRect(x: x + 8, y: y + 6, width: 164, height: h - 12), size: 14)
                y += h + 10
            }
            height = max(height, y + 12)
        }
        return b.scene(width: width, height: height)
    }

    static func journey(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.journey)
        var items: [(String, Int, [String], String)] = [], section = "", actors: [String] = []
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { continue }
            if line.text.hasPrefix("section ") { section = String(line.text.dropFirst(8)); continue }
            guard let m = DiagramSyntax.match(#"^(.+?):\s*([1-5])(?:\s*:\s*(.*))?$"#, line.text) else { throw line.error("旅程步骤需要标签、1 到 5 的评分和可选的参与者。", code: "syntax") }
            let names = m[3].isEmpty ? [] : DiagramSyntax.split(m[3]).map(DiagramSyntax.label)
            for name in names where !actors.contains(name) { actors.append(name) }
            items.append((m[1], Int(m[2])!, names, section))
        }
        try DiagramSyntax.nonempty(items.count, kind: .journey)
        let naturalWidth = max(600, CGFloat(items.count) * 180 + 32)
        if let maxWidth = options.maxWidth, options.autoDirection, naturalWidth > maxWidth {
            let width = options.width(naturalWidth, minimum: 360), top = b.title(DiagramSyntax.title(lines), width: width)
            var y = top + 12, points: [CGPoint] = []
            for (i, item) in items.enumerated() {
                let label = TextMeasurement.lines(item.0, maxWidth: width - 168).joined(separator: "\n")
                let h = max(64, CGFloat(label.components(separatedBy: "\n").count) * 20 + 24)
                b.text(item.3, CGRect(x: 132, y: y, width: width - 152, height: 24), size: 12, color: .muted, align: .leading)
                y += 28
                b.box(label, CGRect(x: 132, y: y, width: width - 152, height: h), size: 14)
                let point = CGPoint(x: 20 + CGFloat(item.1) * 16, y: y + h / 2)
                points.append(point)
                b.ellipse(CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28), fill: .surface, stroke: .border, id: "journey-\(i)", label: "\(item.0): \(item.1)")
                b.text(String(item.1), CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24), size: 13)
                y += h + 8
                for actor in item.2 {
                    b.ellipse(CGRect(x: 136, y: y + 6, width: 10, height: 10), fill: .series(actors.firstIndex(of: actor)!), stroke: .none)
                    b.text(actor, CGRect(x: 152, y: y, width: width - 172, height: 24), size: 12, align: .leading)
                    y += 26
                }
                y += 20
            }
            let track = SceneBuilder(.journey); track.line(points, color: .accent)
            b.primitives = track.primitives + b.primitives
            return b.scene(width: width, height: y + 12)
        }
        let width = naturalWidth, top = b.title(DiagramSyntax.title(lines), width: width)
        b.line([CGPoint(x: 16, y: top + 300), CGPoint(x: width - 16, y: top + 300)], color: .border)
        var points: [CGPoint] = []
        for (i, item) in items.enumerated() {
            let x = 20 + CGFloat(i) * 180
            b.text(item.3, CGRect(x: x, y: top + 2, width: 160, height: 24), size: 12, color: .muted)
            b.box(TextMeasurement.lines(item.0, maxWidth: 136).joined(separator: "\n"), CGRect(x: x, y: top + 34, width: 160, height: 74), size: 14)
            let point = CGPoint(x: x + 80, y: top + 300 - CGFloat(item.1 - 1) * 40)
            points.append(point)
            b.ellipse(CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28), fill: .surface, stroke: .border, id: "journey-\(i)", label: "\(item.0): \(item.1)")
            b.text(String(item.1), CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24), size: 13)
            for (j, actor) in item.2.enumerated() {
                let color = SceneColor.series(actors.firstIndex(of: actor)!)
                b.ellipse(CGRect(x: x + 10 + CGFloat(j) * 18, y: top + 116, width: 10, height: 10), fill: color, stroke: .none)
            }
        }
        let link = SceneBuilder(.journey); link.line(points, color: .accent, width: 1.5)
        let labelsPerRow = max(1, Int(width / 150))
        for (i, actor) in actors.enumerated() {
            let x = 20 + CGFloat(i % labelsPerRow) * 150, y = top + 338 + CGFloat(i / labelsPerRow) * 26
            b.ellipse(CGRect(x: x, y: y + 7, width: 10, height: 10), fill: .series(i), stroke: .none)
            b.text(actor, CGRect(x: x + 18, y: y, width: 126, height: 24), size: 13, align: .leading)
        }
        b.primitives = link.primitives + b.primitives
        return b.scene(width: width, height: top + 380 + CGFloat(actors.count / labelsPerRow) * 26)
    }

    static func gantt(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        struct TaskBar { let id: String; let label: String; let start: Date; let end: Date; let status: [String]; let section: String }
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.gantt)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        var tasks: [TaskBar] = [], section = "", last: Date?, weekends = false, axisPattern = "MM-dd"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if s.hasPrefix("section ") { section = String(s.dropFirst(8)); continue }
            if s.hasPrefix("dateFormat ") {
                let value = String(s.dropFirst(11)), formats = ["YYYY-MM-DD": "yyyy-MM-dd", "YYYY-MM-DD HH:mm": "yyyy-MM-dd HH:mm", "YYYY/MM/DD": "yyyy/MM/dd"]
                guard let pattern = formats[value] else { throw line.error("甘特图暂不支持这个日期格式。") }; formatter.dateFormat = pattern; continue
            }
            if s == "excludes weekends" { weekends = true; continue }
            if s.hasPrefix("axisFormat ") { axisPattern = try ganttAxisPattern(String(s.dropFirst(11)), line: line); continue }
            guard let colon = s.firstIndex(of: ":") else { throw line.error("甘特任务需要冒号和时间定义。", code: "syntax") }
            let label = String(s[..<colon]), raw = DiagramSyntax.split(String(s[s.index(after: colon)...]))
            let statuses = raw.filter { ["active", "done", "crit", "milestone"].contains($0) }
            var fields = raw.filter { !statuses.contains($0) }, id = "task-\(tasks.count)"
            if let first = fields.first, formatter.date(from: first) == nil, !first.hasPrefix("after "), DiagramSyntax.match(#"^\d+[dwhm]$"#, first) == nil { id = fields.removeFirst() }
            guard !tasks.contains(where: { $0.id == id }) else { throw line.error("任务标识符重复。", code: "semantic") }
            var start = last ?? calendar.startOfDay(for: Date())
            if let first = fields.first, first.hasPrefix("after ") {
                let ids = first.dropFirst(6).split(separator: " ").map(String.init)
                let dependencies = try ids.map { id -> TaskBar in guard let task = tasks.first(where: { $0.id == id }) else { throw line.error("after 引用了尚未定义的任务。", code: "semantic") }; return task }
                guard let latest = dependencies.map(\.end).max() else { throw line.error("after 至少需要一个任务标识符。", code: "syntax") }
                start = latest; fields.removeFirst()
            } else if let first = fields.first, let date = formatter.date(from: first) { start = date; fields.removeFirst() }
            if weekends, !statuses.contains("milestone") {
                while calendar.isDateInWeekend(start) { start = start.addingTimeInterval(86400) }
            }
            guard fields.count == 1 else { throw line.error("任务需要开始日期或 after 依赖，以及结束日期或时长。", code: "syntax") }
            let end: Date
            if let date = formatter.date(from: fields[0]) { end = date }
            else if let duration = DiagramSyntax.match(#"^(\d+)([dwhm])$"#, fields[0]), let amount = Int(duration[1]), amount <= 36_600 {
                if duration[2] == "d" || duration[2] == "w" {
                    var cursor = start, remaining = amount * (duration[2] == "w" ? 7 : 1)
                    while remaining > 0 {
                        if !weekends || !calendar.isDateInWeekend(cursor) { remaining -= 1 }
                        cursor = cursor.addingTimeInterval(86400)
                    }
                    end = cursor
                } else { end = start.addingTimeInterval(Double(amount) * (duration[2] == "h" ? 3600 : 60)) }
            } else { throw line.error("无法解析任务日期或时长。", code: "syntax") }
            guard end >= start, statuses.contains("milestone") || end > start else { throw line.error("任务结束时间必须晚于开始时间。", code: "semantic") }
            tasks.append(TaskBar(id: id, label: label, start: start, end: end, status: statuses, section: section)); last = end
        }
        try DiagramSyntax.nonempty(tasks.count, kind: .gantt)
        let minimum = tasks.map(\.start).min()!, maximum = tasks.map(\.end).max()!, span = max(86400, maximum.timeIntervalSince(minimum))
        let width = options.width(1000, minimum: 360), top = b.title(DiagramSyntax.title(lines), width: width), plotX: CGFloat = width < 640 ? 140 : 240, plotW = width - plotX - 40
        let x: (Date) -> CGFloat = { plotX + CGFloat($0.timeIntervalSince(minimum) / span) * plotW }
        var y = top + 50, currentSection = ""
        var sectionCount = 0, previousSection = ""
        for task in tasks where task.section != previousSection { sectionCount += 1; previousSection = task.section }
        let gridBottom = top + 50 + CGFloat(tasks.count) * 50 + CGFloat(sectionCount) * 28
        let dateLabel = DateFormatter(); dateLabel.locale = Locale(identifier: "en_US_POSIX"); dateLabel.timeZone = formatter.timeZone; dateLabel.dateFormat = axisPattern
        let ticks = width < 640 ? 3 : 6
        for tick in 0...ticks {
            let px = plotX + CGFloat(tick) / CGFloat(ticks) * plotW
            b.line([CGPoint(x: px, y: top + 34), CGPoint(x: px, y: gridBottom)], color: .border, dash: [2, 4])
            b.text(dateLabel.string(from: minimum.addingTimeInterval(span * Double(tick) / Double(ticks))), CGRect(x: px - 32, y: top + 4, width: 64, height: 24), size: 12, color: .muted)
        }
        for (i, task) in tasks.enumerated() {
            if task.section != currentSection { currentSection = task.section; b.text(currentSection, CGRect(x: 12, y: y, width: plotX - 20, height: 24), size: 14, align: .leading, bold: true); y += 28 }
            b.text(task.label, CGRect(x: 12, y: y, width: plotX - 24, height: 34), size: 13, align: .leading)
            let color: SceneColor = task.status.contains("crit") ? .series(3) : task.status.contains("done") ? .muted : .series(i % 3)
            let px = x(task.start), w = max(2, x(task.end) - px)
            if task.status.contains("milestone") { b.path([.move(CGPoint(x: px, y: y + 4)), .line(CGPoint(x: px + 10, y: y + 15)), .line(CGPoint(x: px, y: y + 26)), .line(CGPoint(x: px - 10, y: y + 15)), .close], fill: color, stroke: .none, id: task.id) }
            else { b.rect(CGRect(x: px, y: y + 3, width: w, height: 28), fill: color, stroke: .none, id: task.id, label: task.label) }
            y += 50
        }
        return b.scene(width: width, height: y + 24)
    }

    private static func ganttAxisPattern(_ source: String, line: SourceLine) throws -> String {
        let formats: [Character: String] = ["Y": "yyyy", "y": "yy", "m": "MM", "d": "dd", "H": "HH", "I": "hh",
            "M": "mm", "S": "ss", "L": "SSS", "j": "DDD", "a": "EEE", "A": "EEEE", "b": "MMM", "B": "MMMM",
            "p": "a", "Z": "xx", "x": "MM/dd/yyyy", "X": "HH:mm:ss"]
        let characters = Array(source)
        var result = "", literal = "", index = 0
        let quoted: (String) -> String = { "'" + $0.replacingOccurrences(of: "'", with: "''") + "'" }
        while index < characters.count {
            if characters[index] != "%" { literal.append(characters[index]); index += 1; continue }
            index += 1
            guard index < characters.count else { throw line.error("axisFormat 缺少百分号后的格式符。", code: "syntax") }
            if characters[index] == "%" { literal.append("%"); index += 1; continue }
            guard let format = formats[characters[index]] else { throw line.error("axisFormat 暂不支持格式符 %\(characters[index])。") }
            if !literal.isEmpty { result += quoted(literal); literal = "" }
            result += format
            index += 1
        }
        if !literal.isEmpty { result += quoted(literal) }
        return result
    }
}
