using System.Globalization;

namespace NornaKit;

internal sealed class TemporalDiagrams(TextMeasurement text)
{
    private sealed record TimelineEvent(string Label, List<string> Events, string Section);
    public DiagramScene Timeline(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Timeline, text); var events = new List<TimelineEvent>(); var section = "";
        foreach (var line in lines.Skip(1))
        {
            if (line.Text.StartsWith("title ", StringComparison.Ordinal)) continue; if (line.Text.StartsWith("section ", StringComparison.Ordinal)) { section = line.Text[8..]; continue; }
            var parts = line.Text.Split(':').Select(value => value.Trim()).ToArray(); if (parts.Length < 2) throw line.Error("时间线事件需要时间标签和冒号分隔的事件。", "syntax");
            if (parts[0].Length == 0) { if (events.Count == 0) throw line.Error("续写事件前需要一个时间标签。", "semantic"); events[^1].Events.AddRange(parts.Skip(1)); }
            else events.Add(new(parts[0], parts.Skip(1).ToList(), section));
        }
        DiagramSyntax.Nonempty(events.Count, DiagramKind.Timeline); var natural = Math.Max(520, events.Count * 200 + 40); var vertical = options.Compact && options.AutoDirection && natural > options.MaxWidth;
        var width = vertical ? options.Width(natural) : natural; var top = b.Title(DiagramSyntax.Title(lines), width); var track = new SceneBuilder(DiagramKind.Timeline, text); var y = top + 12; var height = top + 160;
        if (!vertical) b.Line([new(20, top + 90), new(width - 20, top + 90)], width: 2, arrow: true);
        for (var i = 0; i < events.Count; i++)
        {
            var e = events[i]; var start = y; var x = vertical ? 72 : 24 + i * 200; var w = vertical ? width - 96 : 180;
            b.Text(e.Section, new(x, vertical ? y : top + 4, w, 24), 12, C.Muted, vertical ? TextAlignment.Leading : TextAlignment.Center);
            if (vertical) y += 28;
            b.Box(e.Label, new(x, vertical ? y : top + 36, w, 42), C.SurfaceAlt, size: 15);
            b.Ellipse(new(vertical ? 31 : x + 85, vertical ? y + 16 : top + 85, 10, 10), C.Series(i), C.Background);
            y = vertical ? y + 56 : top + 112;
            for (var j = 0; j < e.Events.Count; j++)
            { var label = DiagramSyntax.Label(e.Events[j]); var h = text.Lines(label, vertical ? width - 120 : 152).Length * 20 + 20; b.Rect(new(x, y, w, h), C.Series(i), C.None, opacity: .15, id: $"event-{i}-{j}", label: label); b.Text(label, new(x + 8, y + 6, w - 16, h - 12), 14); y += h + 10; }
            if (vertical) { track.Line([new(36, start), new(36, y + 12)], C.Border, 2); y += 24; } else height = Math.Max(height, y + 12);
        }
        b.Primitives.InsertRange(0, track.Primitives); return b.Build(width, vertical ? y + 12 : height);
    }
    private sealed record JourneyItem(string Label, int Score, string[] Actors, string Section);
    public DiagramScene Journey(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Journey, text); var items = new List<JourneyItem>(); var section = ""; var actors = new List<string>();
        foreach (var line in lines.Skip(1))
        {
            if (line.Text.StartsWith("title ", StringComparison.Ordinal)) continue; if (line.Text.StartsWith("section ", StringComparison.Ordinal)) { section = line.Text[8..]; continue; }
            var m = DiagramSyntax.Match(@"^(.+?):\s*([1-5])(?:\s*:\s*(.*))?$", line.Text) ?? throw line.Error("旅程步骤需要标签、1 到 5 的评分和可选的参与者。", "syntax");
            var names = m[3].Length == 0 ? [] : DiagramSyntax.Split(m[3]).Select(DiagramSyntax.Label).ToArray(); foreach (var name in names) if (!actors.Contains(name)) actors.Add(name);
            items.Add(new(m[1], int.Parse(m[2], CultureInfo.InvariantCulture), names, section));
        }
        DiagramSyntax.Nonempty(items.Count, DiagramKind.Journey); var natural = Math.Max(600, items.Count * 180 + 32); var vertical = options.Compact && options.AutoDirection && natural > options.MaxWidth;
        var width = vertical ? options.Width(natural, 360) : natural; var top = b.Title(DiagramSyntax.Title(lines), width); var points = new List<DiagramPoint>(); var y = top + 12;
        if (!vertical) b.Line([new(16, top + 300), new(width - 16, top + 300)], C.Border);
        for (var i = 0; i < items.Count; i++)
        {
            var item = items[i]; var x = vertical ? 132 : 20 + i * 180; var w = vertical ? width - 152 : 160; var h = vertical ? Math.Max(64, text.Lines(item.Label, width - 168).Length * 20 + 24) : 74;
            b.Text(item.Section, new(x, vertical ? y : top + 2, w, 24), 12, C.Muted, vertical ? TextAlignment.Leading : TextAlignment.Center); if (vertical) y += 28;
            b.Box(item.Label, new(x, vertical ? y : top + 34, w, h), size: 14);
            var point = vertical ? new DiagramPoint(20 + item.Score * 16, y + h / 2) : new(x + 80, top + 300 - (item.Score - 1) * 40); points.Add(point);
            b.Ellipse(new(point.X - 14, point.Y - 14, 28, 28), C.Surface, C.Border, id: $"journey-{i}", label: $"{item.Label}: {item.Score}"); b.Text(item.Score.ToString(CultureInfo.InvariantCulture), new(point.X - 12, point.Y - 12, 24, 24), 13);
            if (vertical) y += h + 8;
            for (var j = 0; j < item.Actors.Length; j++) { var actor = item.Actors[j]; b.Ellipse(new(vertical ? 136 : x + 10 + j * 18, vertical ? y + 6 : top + 116, 10, 10), C.Series(actors.IndexOf(actor)), C.None); if (vertical) { b.Text(actor, new(152, y, width - 172, 24), 12, align: TextAlignment.Leading); y += 26; } }
            if (vertical) y += 20;
        }
        var track = new SceneBuilder(DiagramKind.Journey, text); track.Line(points, C.Accent, vertical ? 1 : 1.5); b.Primitives.InsertRange(0, track.Primitives);
        if (vertical) return b.Build(width, y + 12);
        var perRow = Math.Max(1, (int)(width / 150)); for (var i = 0; i < actors.Count; i++) { var x = 20 + i % perRow * 150; var ly = top + 338 + i / perRow * 26; b.Ellipse(new(x, ly + 7, 10, 10), C.Series(i), C.None); b.Text(actors[i], new(x + 18, ly, 126, 24), 13, align: TextAlignment.Leading); }
        return b.Build(width, top + 380 + actors.Count / perRow * 26);
    }
    private sealed record TaskBar(string Id, string Label, DateTime Start, DateTime End, string[] Status, string Section);
    public DiagramScene Gantt(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Gantt, text); var tasks = new List<TaskBar>(); var section = ""; DateTime? last = null; var weekends = false; var pattern = "yyyy-MM-dd";
        Func<string, DateTime?> date = value => DateTime.TryParseExact(value, pattern, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed) ? parsed : null;
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue; if (s.StartsWith("section ", StringComparison.Ordinal)) { section = s[8..]; continue; }
            if (s.StartsWith("dateFormat ", StringComparison.Ordinal)) { pattern = s[11..] switch { "YYYY-MM-DD" => "yyyy-MM-dd", "YYYY-MM-DD HH:mm" => "yyyy-MM-dd HH:mm", "YYYY/MM/DD" => "yyyy/MM/dd", _ => throw line.Error("甘特图暂不支持这个日期格式。") }; continue; }
            if (s == "excludes weekends") { weekends = true; continue; } if (s.StartsWith("axisFormat ", StringComparison.Ordinal)) throw line.Error("甘特图暂不支持自定义 axisFormat。");
            var colon = s.IndexOf(':'); if (colon < 0) throw line.Error("甘特任务需要冒号和时间定义。", "syntax"); var label = s[..colon]; var raw = DiagramSyntax.Split(s[(colon + 1)..]); var statuses = raw.Where(value => value is "active" or "done" or "crit" or "milestone").ToArray(); var fields = raw.Where(value => !statuses.Contains(value)).ToList(); var id = $"task-{tasks.Count}";
            if (fields.Count > 0 && date(fields[0]) is null && !fields[0].StartsWith("after ", StringComparison.Ordinal) && DiagramSyntax.Match(@"^\d+[dwhm]$", fields[0]) is null) { id = fields[0]; fields.RemoveAt(0); }
            if (tasks.Any(task => task.Id == id)) throw line.Error("任务标识符重复。", "semantic"); var start = last ?? DateTime.UtcNow.Date;
            if (fields.Count > 0 && fields[0].StartsWith("after ", StringComparison.Ordinal))
            { var ids = fields[0][6..].Split(' ', StringSplitOptions.RemoveEmptyEntries); if (ids.Length == 0) throw line.Error("after 至少需要一个任务标识符。", "syntax"); start = ids.Select(dependency => tasks.FirstOrDefault(task => task.Id == dependency)?.End ?? throw line.Error("after 引用了尚未定义的任务。", "semantic")).Max(); fields.RemoveAt(0); }
            else if (fields.Count > 0 && date(fields[0]) is { } specified) { start = specified; fields.RemoveAt(0); }
            if (fields.Count != 1) throw line.Error("任务需要开始日期或 after 依赖，以及结束日期或时长。", "syntax");
            DateTime end;
            if (date(fields[0]) is { } explicitEnd) end = explicitEnd;
            else if (DiagramSyntax.Match(@"^(\d+)([dwhm])$", fields[0]) is { } duration && int.TryParse(duration[1], out var amount) && amount <= 36_600)
            {
                if (duration[2] is "d" or "w") { end = start; var remaining = amount * (duration[2] == "w" ? 7 : 1); while (remaining > 0) { end = end.AddDays(1); if (!weekends || end.DayOfWeek is not (DayOfWeek.Saturday or DayOfWeek.Sunday)) remaining--; } }
                else end = start.AddMinutes(amount * (duration[2] == "h" ? 60 : 1));
            }
            else throw line.Error("无法解析任务日期或时长。", "syntax");
            if (end < start || !statuses.Contains("milestone") && end <= start) throw line.Error("任务结束时间必须晚于开始时间。", "semantic"); tasks.Add(new(id, label, start, end, statuses, section)); last = end;
        }
        DiagramSyntax.Nonempty(tasks.Count, DiagramKind.Gantt); var minimum = tasks.Min(task => task.Start); var maximum = tasks.Max(task => task.End); var span = Math.Max(86400, (maximum - minimum).TotalSeconds);
        var width = options.Width(1000, 360); var top = b.Title(DiagramSyntax.Title(lines), width); var plotX = width < 640 ? 140 : 240; var plotWidth = width - plotX - 40;
        Func<DateTime, double> x = value => plotX + (value - minimum).TotalSeconds / span * plotWidth;
        var sectionCount = 0; var previous = ""; foreach (var task in tasks) if (task.Section != previous) { sectionCount++; previous = task.Section; }
        var gridBottom = top + 50 + tasks.Count * 50 + sectionCount * 28; var ticks = width < 640 ? 3 : 6;
        for (var tick = 0; tick <= ticks; tick++) { var px = plotX + tick / (double)ticks * plotWidth; b.Line([new(px, top + 34), new(px, gridBottom)], C.Border, dash: [2, 4]); b.Text(minimum.AddSeconds(span * tick / ticks).ToString("MM-dd", CultureInfo.InvariantCulture), new(px - 32, top + 4, 64, 24), 12, C.Muted); }
        var y = top + 50; var current = "";
        for (var i = 0; i < tasks.Count; i++)
        {
            var task = tasks[i]; if (task.Section != current) { current = task.Section; b.Text(current, new(12, y, plotX - 20, 24), 14, align: TextAlignment.Leading, bold: true); y += 28; }
            b.Text(task.Label, new(12, y, plotX - 24, 34), 13, align: TextAlignment.Leading); var color = task.Status.Contains("crit") ? C.Series(3) : task.Status.Contains("done") ? C.Muted : C.Series(i % 3); var px = x(task.Start); var w = Math.Max(2, x(task.End) - px);
            if (task.Status.Contains("milestone")) b.Path(DataCharts.Polygon([new(px, y + 4), new(px + 10, y + 15), new(px, y + 26), new(px - 10, y + 15)]), color, C.None, id: task.Id); else b.Rect(new(px, y + 3, w, 28), color, C.None, id: task.Id, label: task.Label); y += 50;
        }
        return b.Build(width, y + 24);
    }
}
