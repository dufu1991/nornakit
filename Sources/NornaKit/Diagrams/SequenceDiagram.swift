import Foundation

enum SequenceParticipantStyle: String, Sendable {
    case participant, actor, boundary, control, entity, database, collections, queue
    var symbolic: Bool { [.actor, .boundary, .control, .entity].contains(self) }
}

struct SequenceParticipant: Equatable, Sendable {
    let id: String
    var label: String
    var actor: Bool
    var box: Int?
    var style: SequenceParticipantStyle = .participant
}

enum SequenceEvent: Equatable, Sendable {
    case message(String, String, String, String, Int)
    case note([String], String, String)
    case activate(String), deactivate(String)
    case frame(String, String), branch(String, String), end
    case numbering(Int, Int, Bool)
    case create(String), destroy(String)
}

struct SequenceModel: Equatable, Sendable {
    let participants: [SequenceParticipant]
    let events: [SequenceEvent]
    let boxes: [String]
    let title: String
}

enum SequenceDiagram {
    static func parse(_ source: String) throws -> SequenceModel {
        let lines = DiagramSyntax.lines(source)
        var participants: [SequenceParticipant] = [], positions: [String: Int] = [:], events: [SequenceEvent] = []
        var frames: [String] = [], boxes: [String] = [], currentBox: Int?
        var active: [String: Int] = [:]
        var destroyed = Set<String>()
        var pendingCreate: (id: String, line: Int)?, pendingDestroy: (id: String, line: Int)?
        let requireAlive: ([String], SourceLine) throws -> Void = { ids, line in
            if let id = ids.first(where: { destroyed.contains($0) }) { throw line.error("参与者 \(id) 已销毁，不能再次使用。", code: "semantic") }
        }
        let register: (String) -> Void = { id in
            if positions[id] == nil {
                positions[id] = participants.count
                participants.append(SequenceParticipant(id: id, label: id, actor: false, box: currentBox))
            }
        }
        var cursor = 1
        while cursor < lines.count {
            let line = lines[cursor]; cursor += 1
            let s = line.text
            if s.hasPrefix("title ") { continue }
            let messagePattern = #"^([\p{L}\p{N}_]+)\s*(<<-->>|<<->>|-->>|->>|-->|->|--x|-x|--\)|-\))\s*([+-]?)\s*([\p{L}\p{N}_]+)\s*:\s*(.*)$"#
            if pendingCreate != nil || pendingDestroy != nil {
                guard DiagramSyntax.match(messagePattern, s) != nil else { throw line.error("生命周期指令后必须紧接关联消息。", code: "semantic") }
            }
            if let m = DiagramSyntax.match(#"^create\s+(participant|actor)\s+([\p{L}\p{N}_]+)(?:\s+as\s+(.+))?$"#, s) {
                guard positions[m[2]] == nil else { throw line.error("只能创建尚未声明或使用的参与者。", code: "semantic") }
                register(m[2]); let index = positions[m[2]]!
                participants[index].actor = m[1] == "actor"
                participants[index].style = m[1] == "actor" ? .actor : .participant
                if !m[3].isEmpty { participants[index].label = DiagramSyntax.label(m[3]) }
                pendingCreate = (m[2], line.number); events.append(.create(m[2]))
            } else if let m = DiagramSyntax.match(#"^destroy\s+([\p{L}\p{N}_]+)$"#, s) {
                guard positions[m[1]] != nil else { throw line.error("不能销毁尚未声明或使用的参与者。", code: "semantic") }
                try requireAlive([m[1]], line)
                pendingDestroy = (m[1], line.number)
            } else if let m = DiagramSyntax.match(#"^(participant|actor)\s+([\p{L}\p{N}_]+)(?:\s*@\s*(\{.*\}))?(?:\s+as\s+(.+))?$"#, s) {
                try requireAlive([m[2]], line)
                register(m[2]); let index = positions[m[2]]!
                var style: SequenceParticipantStyle = m[1] == "actor" ? .actor : .participant
                var alias: String?
                if !m[3].isEmpty {
                    guard let values = try? JSONDecoder().decode([String: String].self, from: Data(m[3].utf8)),
                          Set(values.keys).isSubset(of: ["type", "alias"]) else { throw line.error("参与者配置需要 JSON 对象，仅支持字符串类型的 type 和 alias。", code: "syntax") }
                    if let type = values["type"] {
                        guard let specified = SequenceParticipantStyle(rawValue: type) else { throw line.error("暂不支持参与者类型：\(type)。") }
                        style = specified
                    }
                    alias = values["alias"]
                }
                participants[index].style = style; participants[index].actor = style == .actor
                if !m[4].isEmpty { participants[index].label = DiagramSyntax.label(m[4]) }
                else if let alias { participants[index].label = DiagramSyntax.label(alias) }
                participants[index].box = currentBox
            } else if let m = DiagramSyntax.match(messagePattern, s) {
                try requireAlive([m[1], m[4]], line)
                if let pendingCreate {
                    guard m[4] == pendingCreate.id else { throw line.error("创建消息的接收方必须是新参与者。", code: "semantic") }
                }
                if let pendingDestroy {
                    guard m[1] == pendingDestroy.id || m[4] == pendingDestroy.id else { throw line.error("销毁消息必须连接待销毁的参与者。", code: "semantic") }
                }
                register(m[1]); register(m[4])
                let change = m[3] == "+" ? 1 : m[3] == "-" ? -1 : 0
                if change > 0 { active[m[4], default: 0] += 1 }
                if change < 0 {
                    guard active[m[1], default: 0] > 0 else { throw line.error("发送方没有可结束的激活区间。", code: "semantic") }
                    active[m[1], default: 0] -= 1
                }
                events.append(.message(m[1], m[4], DiagramSyntax.label(m[5]), m[2], change))
                if let pendingDestroy { events.append(.destroy(pendingDestroy.id)); destroyed.insert(pendingDestroy.id); active[pendingDestroy.id] = 0 }
                pendingCreate = nil; pendingDestroy = nil
            } else if let m = DiagramSyntax.match(#"^(?i:note)\s+(left of|right of|over)\s+([^:]+):\s*(.*)$"#, s) {
                let ids = m[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard (1...2).contains(ids.count), ids.allSatisfy({ DiagramSyntax.match(#"^[\p{L}\p{N}_]+$"#, $0) != nil }) else { throw line.error("注释需要一个或两个参与者标识符。", code: "syntax") }
                try requireAlive(ids, line)
                ids.forEach(register); events.append(.note(ids, m[1], DiagramSyntax.label(m[3])))
            } else if let m = DiagramSyntax.match(#"^(?i:note)\s+(left of|right of|over)\s+([\p{L}\p{N}_]+(?:\s*,\s*[\p{L}\p{N}_]+)?)$"#, s) {
                let ids = m[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                try requireAlive(ids, line)
                var text: [String] = []
                while cursor < lines.count, lines[cursor].text.lowercased() != "end note" { text.append(lines[cursor].text); cursor += 1 }
                guard cursor < lines.count else { throw line.error("多行注释缺少 end note。", code: "syntax") }
                cursor += 1; ids.forEach(register); events.append(.note(ids, m[1], DiagramSyntax.label(text.joined(separator: "\n"))))
            } else if let m = DiagramSyntax.match(#"^(activate|deactivate)\s+([\p{L}\p{N}_]+)$"#, s) {
                try requireAlive([m[2]], line)
                register(m[2])
                if m[1] == "activate" { active[m[2], default: 0] += 1; events.append(.activate(m[2])) }
                else {
                    guard active[m[2], default: 0] > 0 else { throw line.error("参与者没有可结束的激活区间。", code: "semantic") }
                    active[m[2], default: 0] -= 1; events.append(.deactivate(m[2]))
                }
            } else if s == "autonumber" { events.append(.numbering(1, 1, true))
            } else if s == "autonumber off" { events.append(.numbering(1, 1, false))
            } else if let m = DiagramSyntax.match(#"^autonumber\s+(\d+)(?:\s+(\d+))?$"#, s) {
                guard let start = Int(m[1]), let step = Int(m[2].isEmpty ? "1" : m[2]), step > 0, start < 1_000_000, step < 1_000 else { throw line.error("消息编号或步长超出范围。", code: "limit") }
                events.append(.numbering(start, step, true))
            } else if let m = DiagramSyntax.match(#"^(loop|alt|opt|par|critical|break|rect)\b\s*(.*)$"#, s) {
                guard frames.count < 16 else { throw line.error("时序图最多嵌套 16 层控制片段。", code: "limit") }
                if m[1] == "rect" { _ = try backgroundColor(m[2], line: line) }
                frames.append(m[1]); events.append(.frame(m[1], m[2]))
            } else if let m = DiagramSyntax.match(#"^(else|and|option)\b\s*(.*)$"#, s) {
                let expected = ["else": "alt", "and": "par", "option": "critical"][m[1]]!
                guard frames.last == expected else { throw line.error("分支指令与外层控制片段不匹配。", code: "syntax") }
                events.append(.branch(m[1], m[2]))
            } else if s == "end" {
                if !frames.isEmpty { frames.removeLast(); events.append(.end) }
                else if currentBox != nil { currentBox = nil }
                else { throw line.error("end 没有对应的控制片段或参与者分组。", code: "syntax") }
            } else if s.hasPrefix("box ") {
                guard currentBox == nil, frames.isEmpty else { throw line.error("参与者 box 不支持嵌套。") }
                boxes.append(String(s.dropFirst(4))); currentBox = boxes.count - 1
            } else { throw line.error("暂不支持这条时序图语法：\(s)") }
            guard participants.count <= 60, events.count <= 500 else { throw line.error("时序图最多支持 60 个参与者和 500 个事件。", code: "limit") }
        }
        if let pending = pendingCreate ?? pendingDestroy { throw DiagramRenderError(message: "生命周期指令缺少关联消息。", code: "semantic", line: pending.line) }
        guard frames.isEmpty, currentBox == nil else { throw DiagramRenderError(message: "时序图控制片段或参与者分组缺少 end。", code: "syntax", line: lines.last?.number) }
        try DiagramSyntax.nonempty(participants.count, kind: .sequence)
        return SequenceModel(participants: participants, events: events, boxes: boxes, title: DiagramSyntax.title(lines))
    }

    private static func backgroundColor(_ value: String, line: SourceLine) throws -> SceneColor {
        let value = value.trimmingCharacters(in: .whitespaces)
        if DiagramSyntax.match(#"^#[0-9a-fA-F]{6}$"#, value) != nil { return .literal(value) }
        if let m = DiagramSyntax.match(#"^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$"#, value),
           let r = Int(m[1]), let g = Int(m[2]), let b = Int(m[3]), r <= 255, g <= 255, b <= 255 {
            return .literal(String(format: "#%02x%02x%02x", r, g, b))
        }
        let colors = ["blue": "#0000ff", "red": "#ff0000", "green": "#008000", "yellow": "#ffff00", "purple": "#800080", "orange": "#ffa500", "gray": "#808080", "white": "#ffffff"]
        if let hex = colors[value.lowercased()] { return .literal(hex) }
        throw line.error("rect 颜色当前支持六位十六进制、rgb 和常用英文颜色名称。")
    }

    static func render(_ source: String) throws -> DiagramScene {
        return try layout(parse(source), options: .init())
    }

    static func layout(_ model: SequenceModel, options: DiagramLayoutOptions) throws -> DiagramScene {
        let participants = model.participants
        let indexes = Dictionary(uniqueKeysWithValues: participants.enumerated().map { ($1.id, $0) })
        let slot = options.maxWidth.map { max(64, ($0 - 32 - CGFloat(max(0, participants.count - 1)) * 28) / CGFloat(participants.count)) } ?? 240
        let widths = participants.map { max(options.compact ? 64 : 100, min(options.compact ? min(160, slot) : 240, TextMeasurement.width($0.label) + 36)) }
        var gaps = Array(repeating: CGFloat(options.compact ? 28 : 72), count: max(0, participants.count - 1))
        var leftMargin: CGFloat = options.compact ? 16 : 120, rightMargin: CGFloat = options.compact ? 16 : 120
        for event in model.events {
            if case .message(let from, let to, let text, _, _) = event {
                let a = indexes[from]!, b = indexes[to]!
                let span = abs(b - a)
                if span > 0 {
                    let room = min(options.compact ? 100 : 280, TextMeasurement.width(text) + 40) / CGFloat(span)
                    for i in min(a, b)..<max(a, b) { gaps[i] = max(gaps[i], room - (widths[i] + widths[i + 1]) / 2) }
                } else { rightMargin = max(rightMargin, 160) }
            }
            if case .note(_, let placement, _) = event {
                if placement == "left of" { leftMargin = 220 }
                if placement == "right of" { rightMargin = 220 }
            }
        }
        var xs: [CGFloat] = [leftMargin + widths[0] / 2]
        for i in 1..<participants.count { xs.append(xs[i - 1] + widths[i - 1] / 2 + gaps[i - 1] + widths[i] / 2) }
        let width = xs.last! + widths.last! / 2 + rightMargin
        let content = SceneBuilder(.sequence), backgrounds = SceneBuilder(.sequence), lifelines = SceneBuilder(.sequence), activations = SceneBuilder(.sequence)
        let titleHeight = content.title(model.title, width: width)
        let actorY = titleHeight + 16
        let actorHeight = max(50, zip(participants, widths).map { CGFloat(TextMeasurement.lines($0.0.label, maxWidth: $0.1 - 16).count) * 22 + 12 }.max() ?? 50)
        var y = actorY + max(100, actorHeight + 40)
        var number = 1, step = 1, numbering = false
        var activationStarts: [String: [CGFloat]] = [:]
        var destroyed: [String: CGFloat] = [:]
        var created: [String: CGFloat] = [:]
        var creating: String?
        var messageIndex = 0
        var lastMessageY = y
        struct Frame { let kind: String; let label: String; let y: CGFloat; let depth: Int }
        var frames: [Frame] = []
        let closeActivation: (String, CGFloat) -> Void = { id, end in
            if let start = activationStarts[id]?.popLast() {
                let depth = activationStarts[id]!.count
                activations.rect(CGRect(x: xs[indexes[id]!] - 5 + CGFloat(depth) * 4, y: start, width: 10, height: max(14, end - start)), fill: .surfaceAlt)
            }
        }
        for event in model.events {
            switch event {
            case .create(let id): creating = id; y += (participants[indexes[id]!].style.symbolic ? 86 : actorHeight) / 2 + 18
            case .numbering(let start, let increment, let visible): number = start; step = increment; numbering = visible
            case .activate(let id): activationStarts[id, default: []].append(y); y += 12
            case .deactivate(let id): closeActivation(id, y); y += 12
            case .destroy(let id):
                let x = xs[indexes[id]!], end = lastMessageY; destroyed[id] = end
                while activationStarts[id]?.isEmpty == false { closeActivation(id, end) }
                content.path([.move(CGPoint(x: x - 6, y: end - 6)), .line(CGPoint(x: x + 6, y: end + 6)),
                    .move(CGPoint(x: x + 6, y: end - 6)), .line(CGPoint(x: x - 6, y: end + 6))], id: "destroy-\(id)")
            case .message(let from, let to, let message, let arrow, let change):
                let a = indexes[from]!, b = indexes[to]!
                let sign: CGFloat = xs[b] >= xs[a] ? 1 : -1
                let start = xs[a] + ((activationStarts[from]?.isEmpty == false) ? sign * 5 : 0)
                let end = xs[b] - (creating == to ? sign * widths[b] / 2 : (activationStarts[to]?.isEmpty == false || change > 0) ? sign * 5 : 0)
                let loopRoom = min(300, a + 1 < xs.count ? xs[a + 1] - start - 20 : width - start - 16)
                let messageWidth = a == b ? max(24, loopRoom - 48) : max(24, abs(end - start) - 36)
                let label = TextMeasurement.lines((numbering ? "\(number). " : "") + message,
                    maxWidth: min(260, messageWidth), size: DiagramStyle.edgeFontSize).joined(separator: "\n")
                let labelSize = EdgeLabelLayout.size(label.components(separatedBy: "\n"))
                y += labelSize.height / 2 + 16
                lastMessageY = y
                if creating == to { created[to] = y - (participants[indexes[to]!].style.symbolic ? 86 : actorHeight) / 2 }
                if change > 0 { activationStarts[to, default: []].append(y) }
                let points: [CGPoint]
                let labelFrame: CGRect
                let loopHeight = max(32, labelSize.height + 20)
                if a == b {
                    let loopWidth = min(loopRoom, max(80, labelSize.width + 48))
                    points = [CGPoint(x: start, y: y), CGPoint(x: start + loopWidth, y: y),
                              CGPoint(x: start + loopWidth, y: y + loopHeight), CGPoint(x: xs[b] + (activationStarts[to]?.isEmpty == false ? 5 : 0), y: y + loopHeight)]
                    labelFrame = CGRect(x: start + (loopWidth - labelSize.width) / 2, y: y - labelSize.height / 2,
                                        width: labelSize.width, height: labelSize.height)
                } else {
                    points = [CGPoint(x: start, y: y), CGPoint(x: end, y: y)]
                    labelFrame = CGRect(x: (start + end - labelSize.width) / 2, y: y - labelSize.height / 2,
                                        width: labelSize.width, height: labelSize.height)
                }
                let hasHead = arrow.contains(">>") || arrow.contains(")") || arrow.contains("x")
                content.line(points, dash: arrow.contains("--") ? [4, 4] : [], arrow: hasHead && !arrow.contains("x"),
                             open: arrow.contains(")"), id: "message-\(messageIndex)")
                if arrow.hasPrefix("<<") { content.path(ScenePath.arrow(Array(points.reversed())).commands, fill: .line, stroke: .none) }
                if arrow.contains("x"), let tip = points.last {
                    content.line([CGPoint(x: tip.x - 5, y: tip.y - 5), CGPoint(x: tip.x + 5, y: tip.y + 5)])
                    content.line([CGPoint(x: tip.x + 5, y: tip.y - 5), CGPoint(x: tip.x - 5, y: tip.y + 5)])
                }
                content.rect(labelFrame, fill: .background, stroke: .none, radius: 3, id: "edge-label-message-\(messageIndex)", label: label)
                content.text(label, labelFrame, size: DiagramStyle.edgeFontSize)
                messageIndex += 1
                number += step
                if change < 0 { closeActivation(from, y) }
                y += a == b ? loopHeight + labelSize.height / 2 + 26 : max(labelSize.height / 2 + 26, creating == to ? actorHeight / 2 + 18 : 0)
                creating = nil
            case .note(let ids, let placement, let text):
                let a = xs[indexes[ids[0]]!], b = xs[indexes[ids.last!]!]
                let lines = TextMeasurement.lines(text, maxWidth: 180), noteWidth = max(100, (lines.map { TextMeasurement.width($0) }.max() ?? 0) + 24)
                let height = CGFloat(lines.count) * 22 + 24
                let x = placement == "left of" ? a - noteWidth - 16 : placement == "right of" ? a + 16 : (a + b) / 2 - noteWidth / 2
                content.box(lines.joined(separator: "\n"), CGRect(x: x, y: y, width: noteWidth, height: height), fill: .surfaceAlt, size: 14)
                y += height + 20
            case .frame(let kind, let label): frames.append(Frame(kind: kind, label: label, y: y, depth: frames.count)); y += 46
            case .branch(let kind, let label):
                let depth = frames.last!.depth
                content.line([CGPoint(x: 24 + CGFloat(depth) * 10, y: y), CGPoint(x: width - 24 - CGFloat(depth) * 10, y: y)], color: .border, dash: [4, 4])
                content.text("\(kind)  \(label)", CGRect(x: 44 + CGFloat(depth) * 10, y: y + 6, width: width - 88, height: 24), size: 14, align: .leading)
                y += 40
            case .end:
                let frame = frames.removeLast(), inset = 24 + CGFloat(frame.depth) * 10
                backgrounds.rect(CGRect(x: inset, y: frame.y, width: width - inset * 2, height: y - frame.y + 8), fill: frame.kind == "rect" ? try backgroundColor(frame.label, line: SourceLine(text: frame.label, raw: frame.label, number: 1)) : .surfaceAlt, opacity: frame.kind == "rect" ? 0.12 : 0.22)
                content.box(frame.kind, CGRect(x: inset, y: frame.y, width: max(54, TextMeasurement.width(frame.kind, size: 14) + 18), height: 26), fill: .surfaceAlt, size: 14)
                if frame.kind != "rect" { content.text(frame.label, CGRect(x: inset + 82, y: frame.y + 2, width: width - inset * 2 - 96, height: 26), size: 14, align: .leading) }
                y += 24
            }
        }
        let endY = y + 12
        for participant in participants {
            while activationStarts[participant.id]?.isEmpty == false { closeActivation(participant.id, endY) }
        }
        for (index, participant) in participants.enumerated() {
            let x = xs[index]
            let start = (created[participant.id] ?? actorY) + (participant.style.symbolic ? 86 : actorHeight)
            lifelines.path([.move(CGPoint(x: x, y: start)), .line(CGPoint(x: x, y: destroyed[participant.id] ?? endY))], stroke: .border, dash: [4, 4], id: "lifeline-\(participant.id)")
            let tops = [created[participant.id] ?? actorY] + (destroyed[participant.id] == nil ? [endY + 12] : [])
            for top in tops {
                drawParticipant(participant, frame: CGRect(x: x - widths[index] / 2, y: top, width: widths[index], height: actorHeight), builder: content)
            }
        }
        let height = endY + 110
        for (box, label) in model.boxes.enumerated() {
            let members = participants.indices.filter { participants[$0].box == box }
            guard let first = members.first, let last = members.last else { continue }
            let x = xs[first] - widths[first] / 2 - 16, right = xs[last] + widths[last] / 2 + 16
            backgrounds.rect(CGRect(x: x, y: actorY - 12, width: right - x, height: height - actorY), fill: .surfaceAlt, opacity: 0.25)
            content.text(label, CGRect(x: x, y: actorY - 36, width: right - x, height: 24), size: 14, color: .muted)
        }
        // Outer control fragments are painted before their nested fragments.
        content.primitives = backgrounds.primitives.reversed() + lifelines.primitives + activations.primitives + content.primitives
        return content.scene(width: width, height: height)
    }

    private static func drawParticipant(_ participant: SequenceParticipant, frame r: CGRect, builder b: SceneBuilder) {
        let x = r.midX, y = r.minY, id = "participant-\(participant.id)"
        switch participant.style {
        case .actor:
            b.ellipse(CGRect(x: x - 8, y: y, width: 16, height: 16), fill: .none, stroke: .line, id: id, label: participant.label)
            b.line([CGPoint(x: x, y: y + 16), CGPoint(x: x, y: y + 34)])
            b.line([CGPoint(x: x - 16, y: y + 23), CGPoint(x: x + 16, y: y + 23)])
            b.line([CGPoint(x: x - 12, y: y + 48), CGPoint(x: x, y: y + 34), CGPoint(x: x + 12, y: y + 48)])
        case .boundary, .control, .entity:
            b.ellipse(CGRect(x: x - 18, y: y + 8, width: 36, height: 36), fill: .surface, stroke: .line, id: id, label: participant.label)
            if participant.style == .boundary {
                b.line([CGPoint(x: x - 32, y: y + 6), CGPoint(x: x - 32, y: y + 46)])
                b.line([CGPoint(x: x - 32, y: y + 26), CGPoint(x: x - 18, y: y + 26)])
            } else if participant.style == .control {
                b.line([CGPoint(x: x - 2, y: y + 2), CGPoint(x: x + 8, y: y + 8), CGPoint(x: x - 2, y: y + 14)])
            } else { b.line([CGPoint(x: x - 22, y: y + 48), CGPoint(x: x + 22, y: y + 48)]) }
        case .database:
            let node = SceneNode(id: id, label: participant.label, shape: .cylinder, frame: r, lines: [])
            b.path(ScenePath.node(node).commands, fill: .surface, stroke: .border, id: id)
            b.path(ScenePath.detail(node).commands, stroke: .border)
        case .collections:
            for offset: CGFloat in [8, 4, 0] { b.rect(CGRect(x: r.minX + offset, y: r.minY + offset, width: r.width - 8, height: r.height - 8), id: offset == 0 ? id : nil, label: participant.label) }
        case .queue:
            b.rect(r.insetBy(dx: 8, dy: 0), radius: 0, id: id, label: participant.label)
            b.ellipse(CGRect(x: r.minX, y: r.minY, width: 16, height: r.height), fill: .surface, stroke: .border)
            b.ellipse(CGRect(x: r.maxX - 16, y: r.minY, width: 16, height: r.height), fill: .surface, stroke: .border)
        case .participant: b.rect(r, id: id, label: participant.label)
        }
        let textFrame = participant.style.symbolic ? CGRect(x: r.minX, y: y + 50, width: r.width, height: 30)
            : r.insetBy(dx: participant.style == .queue ? 18 : 8, dy: 8)
        b.text(participant.label, textFrame, size: participant.style.symbolic ? 14 : 16)
    }
}
