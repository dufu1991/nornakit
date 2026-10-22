import Foundation

enum DataCharts {
    static func pie(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source)
        var title = "", values: [(String, Double)] = []
        if let range = lines[0].text.range(of: "title ") { title = String(lines[0].text[range.upperBound...]) }
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { title = String(line.text.dropFirst(6)); continue }
            guard let m = DiagramSyntax.match(#"^"([^"]+)"\s*:\s*([\d.eE+-]+)$"#, line.text) else { throw line.error("饼图数据应写作双引号标签、冒号与数值。", code: "syntax") }
            let value = try DiagramSyntax.number(m[2], line: line)
            guard value >= 0 else { throw line.error("饼图数值不能为负。", code: "semantic") }
            values.append((m[1], value))
        }
        try DiagramSyntax.nonempty(values.count, kind: .pie)
        let total = values.reduce(0) { $0 + $1.1 }
        guard total > 0 else { throw DiagramRenderError(message: "饼图总值必须大于零。", code: "semantic") }
        let b = SceneBuilder(.pie), width = options.width(max(620, (values.map { TextMeasurement.width($0.0) }.max() ?? 0) + 460))
        let stacked = width < 560, radius: CGFloat = stacked ? min(160, (width - 48) / 2) : 160
        let top = b.title(title, width: width), center = CGPoint(x: stacked ? width / 2 : 205, y: top + radius + 24)
        var angle = -CGFloat.pi / 2
        for (i, item) in values.enumerated() where item.1 > 0 {
            let end = angle + CGFloat(item.1 / total) * 2 * .pi
            var commands: [PathCommand] = [.move(center), .line(CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))]
            commands += arc(center: center, radius: radius, from: angle, to: end)
            commands.append(.close)
            b.path(commands, fill: .series(i), stroke: .background, width: 1, id: "slice-\(i)")
            if item.1 / total >= 0.045 {
                let mid = (angle + end) / 2
                b.text(String(format: "%.1f%%", item.1 / total * 100), CGRect(x: center.x + cos(mid) * radius * 0.65 - 32, y: center.y + sin(mid) * radius * 0.65 - 12, width: 64, height: 24), size: 14, color: .onSeries(i))
            }
            angle = end
        }
        var legendY = stacked ? top + radius * 2 + 60 : top + 36
        for (i, item) in values.enumerated() {
            let y = legendY, x: CGFloat = stacked ? 24 : 402
            let label = "\(item.0)  \(format(item.1))"
            let textWidth = width - x - 42
            let h = max(24, CGFloat(TextMeasurement.lines(label, maxWidth: textWidth).count) * 20)
            legendY += h + 6
            b.rect(CGRect(x: x, y: y + 5, width: 14, height: 14), fill: .series(i), stroke: .none)
            b.text(label, CGRect(x: x + 26, y: y, width: textWidth, height: h), size: 14, align: .leading)
        }
        return b.scene(width: width, height: max(top + radius * 2 + 48, legendY + 24))
    }

    static func xy(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source)
        let horizontal = lines[0].text.split(whereSeparator: \.isWhitespace).dropFirst().contains("horizontal")
        var title = "", categories: [String] = [], xLabel = "", yLabel = "", explicitRange: (Double, Double)?
        var series: [(String, String, [Double])] = []
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { title = DiagramSyntax.label(String(s.dropFirst(6))) }
            else if let m = DiagramSyntax.match(#"^x-axis\s*(.*?)\s*\[(.*)\]$"#, s) { xLabel = DiagramSyntax.label(m[1]); categories = DiagramSyntax.split(m[2]).map(DiagramSyntax.label) }
            else if let m = DiagramSyntax.match(#"^y-axis\s*(.*?)\s+([-+\d.eE]+)\s*-->\s*([-+\d.eE]+)$"#, s) {
                yLabel = DiagramSyntax.label(m[1]); explicitRange = (try DiagramSyntax.number(m[2], line: line), try DiagramSyntax.number(m[3], line: line))
            } else if s.hasPrefix("y-axis ") { yLabel = DiagramSyntax.label(String(s.dropFirst(7))) }
            else if let m = DiagramSyntax.match(#"^(bar|line)\s*(.*?)\s*\[(.*)\]$"#, s) {
                let numbers = try DiagramSyntax.split(m[3]).map { try DiagramSyntax.number($0, line: line) }
                series.append((m[1], DiagramSyntax.label(m[2]), numbers))
            } else { throw line.error("暂不支持这条 XY 图语法：\(s)") }
        }
        try DiagramSyntax.nonempty(series.count, kind: .xychart)
        let count = series[0].2.count
        guard count > 0, count <= 100, series.allSatisfy({ $0.2.count == count }), categories.isEmpty || categories.count == count else { throw DiagramRenderError(message: "坐标轴标签和每条数据系列的数量必须一致，最多 100 项。", code: "semantic") }
        if categories.isEmpty { categories = (1...count).map(String.init) }
        let all = series.flatMap(\.2)
        let low = explicitRange?.0 ?? min(0, all.min()!), high = explicitRange?.1 ?? max(1, all.max()! * 1.1)
        guard high > low else { throw DiagramRenderError(message: "纵轴上限必须大于下限。", code: "semantic") }
        guard all.allSatisfy({ $0 >= low && $0 <= high }) else { throw DiagramRenderError(message: "数据超出显式纵轴范围。", code: "semantic") }
        if horizontal {
            return horizontalXY(title: title, categories: categories, categoryTitle: xLabel, valueTitle: yLabel,
                series: series, low: low, high: high, options: options)
        }
        let width = options.width(max(680, CGFloat(count) * 64 + 120), minimum: max(320, CGFloat(count) * 28 + 118)), b = SceneBuilder(.xychart), top = b.title(title, width: width)
        let plot = CGRect(x: 82, y: top + 16, width: width - 118, height: 320)
        let y: (Double) -> CGFloat = { plot.maxY - CGFloat(($0 - low) / (high - low)) * plot.height }
        for tick in 0...5 {
            let value = low + (high - low) * Double(tick) / 5, py = y(value)
            b.line([CGPoint(x: plot.minX, y: py), CGPoint(x: plot.maxX, y: py)], color: .border, dash: [2, 4])
            b.text(format(value), CGRect(x: 4, y: py - 12, width: 68, height: 24), size: 12, color: .muted, align: .trailing)
        }
        let slot = plot.width / CGFloat(count), baseline = y(min(high, max(low, 0)))
        let bars = series.indices.filter { series[$0].0 == "bar" }
        for (i, item) in series.enumerated() {
            if item.0 == "bar" {
                let barWidth = slot * 0.7 / CGFloat(max(1, bars.count)), barIndex = bars.firstIndex(of: i)!
                for (j, value) in item.2.enumerated() {
                    let py = y(value), x = plot.minX + CGFloat(j) * slot + slot * 0.15 + CGFloat(barIndex) * barWidth
                    b.rect(CGRect(x: x, y: min(py, baseline), width: max(0.5, barWidth - 2), height: max(0.5, abs(py - baseline))), fill: .series(i), stroke: .none, radius: 2, id: "bar-\(i)-\(j)", label: "\(categories[j]): \(format(value))")
                }
            } else {
                let points = item.2.enumerated().map { CGPoint(x: plot.minX + (CGFloat($0.offset) + 0.5) * slot, y: y($0.element)) }
                b.line(points, color: .series(i), width: 2.5)
                for (j, p) in points.enumerated() { b.ellipse(CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6), fill: .series(i), stroke: .background, id: "point-\(i)-\(j)", label: "\(categories[j]): \(format(item.2[j]))") }
            }
        }
        b.line([CGPoint(x: plot.minX, y: plot.minY), CGPoint(x: plot.minX, y: plot.maxY), CGPoint(x: plot.maxX, y: plot.maxY)], color: .line, width: 1.5)
        let axisHeight = max(24, CGFloat(categories.map { TextMeasurement.lines($0, maxWidth: max(12, slot - 4)).count }.max() ?? 1) * 18)
        for (i, label) in categories.enumerated() { b.text(label, CGRect(x: plot.minX + CGFloat(i) * slot + 2, y: plot.maxY + 8, width: slot - 4, height: axisHeight), size: 12, color: .muted) }
        b.text(xLabel, CGRect(x: plot.minX, y: plot.maxY + axisHeight + 16, width: plot.width, height: 24), size: 14)
        b.text(yLabel, CGRect(x: 4, y: top - 10, width: width - 8, height: 24), size: 12, color: .muted, align: .leading)
        let perRow = max(1, Int((width - 80) / 150))
        for (i, item) in series.enumerated() {
            let x = 80 + CGFloat(i % perRow) * 150, row = CGFloat(i / perRow) * 30
            b.rect(CGRect(x: x, y: plot.maxY + axisHeight + 60 + row, width: 14, height: 12), fill: .series(i), stroke: .none)
            b.text(item.1.isEmpty ? "\(item.0) \(i + 1)" : item.1, CGRect(x: x + 22, y: plot.maxY + axisHeight + 54 + row, width: 124, height: 24), size: 12, align: .leading)
        }
        return b.scene(width: width, height: plot.maxY + axisHeight + 90 + CGFloat((series.count - 1) / perRow) * 30)
    }

    private static func horizontalXY(title: String, categories: [String], categoryTitle: String, valueTitle: String,
                                     series: [(String, String, [Double])], low: Double, high: Double,
                                     options: DiagramLayoutOptions) -> DiagramScene {
        let width = options.width(680), b = SceneBuilder(.xychart), top = b.title(title, width: width)
        let labelWidth = min(width * 0.35, max(82, (categories.map { TextMeasurement.width($0, size: 12) }.max() ?? 0) + 20))
        let labelLines = categories.map { TextMeasurement.lines($0, maxWidth: labelWidth - 20, size: 12) }
        let slot = max(48, CGFloat(labelLines.map(\.count).max() ?? 1) * 18 + 16)
        let plot = CGRect(x: labelWidth, y: top + 20, width: width - labelWidth - 40, height: slot * CGFloat(categories.count))
        let x: (Double) -> CGFloat = { plot.minX + CGFloat(($0 - low) / (high - low)) * plot.width }
        let baseline = x(min(high, max(low, 0))), ticks = width < 480 ? 3 : 5
        for tick in 0...ticks {
            let value = low + (high - low) * Double(tick) / Double(ticks), px = x(value)
            b.line([CGPoint(x: px, y: plot.minY), CGPoint(x: px, y: plot.maxY)], color: .border, dash: [2, 4])
            b.text(format(value), CGRect(x: px - 30, y: plot.maxY + 8, width: 60, height: 24), size: 12, color: .muted)
        }
        let bars = series.indices.filter { series[$0].0 == "bar" }
        for (i, item) in series.enumerated() {
            if item.0 == "bar" {
                let barHeight = slot * 0.7 / CGFloat(bars.count), barIndex = bars.firstIndex(of: i)!
                for (j, value) in item.2.enumerated() {
                    let px = x(value), y = plot.minY + CGFloat(j) * slot + slot * 0.15 + CGFloat(barIndex) * barHeight
                    b.rect(CGRect(x: min(px, baseline), y: y, width: max(0.5, abs(px - baseline)), height: max(0.5, barHeight - 2)),
                        fill: .series(i), stroke: .none, radius: 2, id: "bar-\(i)-\(j)", label: "\(categories[j]): \(format(value))")
                }
            } else {
                let points = item.2.enumerated().map { CGPoint(x: x($0.element), y: plot.minY + (CGFloat($0.offset) + 0.5) * slot) }
                b.line(points, color: .series(i), width: 2.5)
                for (j, p) in points.enumerated() {
                    b.ellipse(CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6), fill: .series(i), stroke: .background,
                        id: "point-\(i)-\(j)", label: "\(categories[j]): \(format(item.2[j]))")
                }
            }
        }
        b.line([CGPoint(x: plot.minX, y: plot.minY), CGPoint(x: plot.minX, y: plot.maxY), CGPoint(x: plot.maxX, y: plot.maxY)], color: .line, width: 1.5)
        for (i, lines) in labelLines.enumerated() {
            b.text(lines.joined(separator: "\n"), CGRect(x: 8, y: plot.minY + CGFloat(i) * slot, width: labelWidth - 20, height: slot), size: 12, color: .muted, align: .trailing)
        }
        b.text(categoryTitle, CGRect(x: 8, y: top - 6, width: labelWidth - 20, height: 24), size: 12, color: .muted, align: .trailing)
        b.text(valueTitle, CGRect(x: plot.minX, y: plot.maxY + 40, width: plot.width, height: 24), size: 14)
        let perRow = max(1, Int((width - 48) / 150))
        for (i, item) in series.enumerated() {
            let px = 24 + CGFloat(i % perRow) * 150, py = plot.maxY + 80 + CGFloat(i / perRow) * 30
            b.rect(CGRect(x: px, y: py + 6, width: 14, height: 12), fill: .series(i), stroke: .none)
            b.text(item.1.isEmpty ? "\(item.0) \(i + 1)" : item.1, CGRect(x: px + 22, y: py, width: 124, height: 24), size: 12, align: .leading)
        }
        return b.scene(width: width, height: plot.maxY + 116 + CGFloat((series.count - 1) / perRow) * 30)
    }

    static func quadrant(_ source: String) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.quadrantChart)
        let title = DiagramSyntax.title(lines), top = b.title(title, width: 640), plot = CGRect(x: 80, y: top + 30, width: 480, height: 400)
        var labels = ["", "", "", ""], xLabels = ["", ""], yLabels = ["", ""], points: [(String, Double, Double)] = []
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if let m = DiagramSyntax.match(#"^quadrant-([1-4])\s+(.+)$"#, s) { labels[Int(m[1])! - 1] = m[2] }
            else if let m = DiagramSyntax.match(#"^([xy])-axis\s+(.+?)\s*-->\s*(.+)$"#, s) { if m[1] == "x" { xLabels = [m[2], m[3]] } else { yLabels = [m[2], m[3]] } }
            else if let m = DiagramSyntax.match(#"^(.+?):\s*\[([^,]+),([^\]]+)\]$"#, s) {
                let x = try DiagramSyntax.number(m[2], line: line), y = try DiagramSyntax.number(m[3], line: line)
                guard (0...1).contains(x), (0...1).contains(y) else { throw line.error("象限坐标必须在 0 与 1 之间。", code: "semantic") }
                points.append((DiagramSyntax.label(m[1]), x, y))
            } else { throw line.error("暂不支持这条象限图语法：\(s)") }
        }
        for i in 0..<4 {
            let x = plot.minX + (i == 0 || i == 3 ? plot.width / 2 : 0), y = plot.minY + (i > 1 ? plot.height / 2 : 0)
            let r = CGRect(x: x, y: y, width: plot.width / 2, height: plot.height / 2)
            b.rect(r, fill: .series(i), stroke: .none, radius: 0, opacity: 0.13)
            b.text(labels[i], CGRect(x: r.minX + 6, y: r.minY + 8, width: r.width - 12, height: 24), size: 14, color: .muted)
        }
        b.rect(plot, fill: .none, stroke: .border, radius: 0)
        b.line([CGPoint(x: plot.midX, y: plot.minY), CGPoint(x: plot.midX, y: plot.maxY)], color: .border)
        b.line([CGPoint(x: plot.minX, y: plot.midY), CGPoint(x: plot.maxX, y: plot.midY)], color: .border)
        for (i, p) in points.enumerated() {
            let x = plot.minX + CGFloat(p.1) * plot.width, y = plot.maxY - CGFloat(p.2) * plot.height
            b.ellipse(CGRect(x: x - 5, y: y - 5, width: 10, height: 10), fill: .accent, stroke: .background, id: "quadrant-\(i)", label: p.0)
            b.text(p.0, CGRect(x: min(max(x - 90, plot.minX), plot.maxX - 180), y: min(y + 8, plot.maxY - 26), width: 180, height: 24), size: 12)
        }
        b.text(xLabels[0], CGRect(x: plot.minX, y: plot.maxY + 10, width: plot.width / 2, height: 24), size: 12, align: .leading)
        b.text(xLabels[1], CGRect(x: plot.midX, y: plot.maxY + 10, width: plot.width / 2, height: 24), size: 12, align: .trailing)
        b.text(yLabels[1], CGRect(x: 4, y: top + 2, width: 632, height: 22), size: 12, color: .muted, align: .leading)
        b.text(yLabels[0], CGRect(x: 4, y: plot.maxY + 42, width: 632, height: 22), size: 12, color: .muted, align: .leading)
        return b.scene(width: 640, height: plot.maxY + 80)
    }

    static func radar(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.radar)
        var axes: [String] = [], curves: [(String, [Double])] = [], maximum: Double?, minimum: Double = 0
        var circular = false
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if s.hasPrefix("axis ") { axes += DiagramSyntax.split(String(s.dropFirst(5))).map { value in DiagramSyntax.match(#"^\w+\["([^"]+)"\]$"#, value)?[1] ?? DiagramSyntax.label(value) } }
            else if let m = DiagramSyntax.match(#"^curve\s+(\w+)(?:\["([^"]+)"\])?\s*\{([^}]+)\}$"#, s) { curves.append((m[2].isEmpty ? m[1] : m[2], try DiagramSyntax.split(m[3]).map { try DiagramSyntax.number($0, line: line) })) }
            else if s == "graticule polygon" { circular = false }
            else if s == "graticule circle" { circular = true }
            else if s.hasPrefix("min ") { minimum = try DiagramSyntax.number(String(s.dropFirst(4)), line: line) }
            else if s.hasPrefix("max ") { maximum = try DiagramSyntax.number(String(s.dropFirst(4)), line: line, positive: true) }
            else { throw line.error("暂不支持这条雷达图语法：\(s)") }
        }
        guard axes.count >= 3, axes.count <= 30, !curves.isEmpty, curves.allSatisfy({ $0.1.count == axes.count && $0.1.allSatisfy { $0 >= 0 } }) else { throw DiagramRenderError(message: "雷达图至少需要 3 个轴，每条曲线需要相同数量的非负数据。", code: "semantic") }
        let high = maximum ?? max(1, curves.flatMap(\.1).max()!)
        guard high > minimum, curves.flatMap(\.1).allSatisfy({ $0 >= minimum && $0 <= high }) else { throw DiagramRenderError(message: "雷达图数据超过 max。", code: "semantic") }
        let width = options.width(620, minimum: 360), radius = min(165, (width - 200) / 2)
        let top = b.title(DiagramSyntax.title(lines), width: width), center = CGPoint(x: width / 2, y: top + radius + 55)
        let point: (Int, CGFloat) -> CGPoint = { i, r in let angle = CGFloat(i) / CGFloat(axes.count) * 2 * .pi - .pi / 2; return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r) }
        for tick in 1...5 {
            let points = axes.indices.map { point($0, radius * CGFloat(tick) / 5) }
            if circular { let r = radius * CGFloat(tick) / 5; b.ellipse(CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2), fill: .none, stroke: .border) }
            else { b.path([.move(points[0])] + points.dropFirst().map(PathCommand.line) + [.close], stroke: .border, dash: [2, 3]) }
        }
        for i in axes.indices {
            b.line([center, point(i, radius)], color: .border)
            let p = point(i, radius + 32)
            b.text(axes[i], CGRect(x: p.x - 64, y: p.y - 16, width: 128, height: 32), size: 13)
        }
        let perRow = max(1, Int((width - 80) / 150)), legendY = top + radius * 2 + 120
        for (i, curve) in curves.enumerated() {
            let points = curve.1.enumerated().map { point($0.offset, radius * CGFloat(($0.element - minimum) / (high - minimum))) }
            let outline = [.move(points[0])] + points.dropFirst().map(PathCommand.line) + [PathCommand.close]
            b.path(outline, fill: .series(i), stroke: .none, opacity: 0.15, id: "radar-\(i)")
            b.path(outline, stroke: .series(i), width: 2)
            let legendX = 40 + CGFloat(i % perRow) * 150, rowY = legendY + CGFloat(i / perRow) * 28
            b.rect(CGRect(x: legendX, y: rowY + 6, width: 12, height: 12), fill: .series(i), stroke: .none, radius: 3)
            b.text(curve.0, CGRect(x: legendX + 20, y: rowY, width: 120, height: 24), size: 13, align: .leading)
        }
        return b.scene(width: width, height: legendY + CGFloat((curves.count - 1) / perRow) * 28 + 40)
    }

    static func arc(center: CGPoint, radius: CGFloat, from: CGFloat, to: CGFloat) -> [PathCommand] {
        let count = max(1, Int(ceil(abs(to - from) / (.pi / 2)))), step = (to - from) / CGFloat(count)
        return (0..<count).map { i in
            let a = from + CGFloat(i) * step, z = a + step, k = 4 / 3 * tan(step / 4)
            let p = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            let q = CGPoint(x: center.x + radius * cos(z), y: center.y + radius * sin(z))
            return .cubic(CGPoint(x: p.x - radius * sin(a) * k, y: p.y + radius * cos(a) * k),
                          CGPoint(x: q.x + radius * sin(z) * k, y: q.y - radius * cos(z) * k), q)
        }
    }

    static func format(_ value: Double) -> String { value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.2g", value) }
}
