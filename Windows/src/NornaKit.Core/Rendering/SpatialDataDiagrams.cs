namespace NornaKit;

internal sealed class SpatialDataDiagrams(TextMeasurement text)
{
    private sealed record Link(int From, int To, double Value);
    public DiagramScene Sankey(string source)
    {
        var names = new List<string>(); var links = new List<Link>();
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        { var values = DiagramSyntax.Split(line.Text).Select(value => DiagramSyntax.Label(value).Replace("\"\"", "\"", StringComparison.Ordinal)).ToArray(); if (values.Length != 3 || values[0].Length == 0 || values[1].Length == 0 || values[0] == values[1]) throw line.Error("桑基图需要来源、目标和正数权重三列 CSV。", "syntax"); foreach (var name in values.Take(2)) if (!names.Contains(name)) names.Add(name); links.Add(new(names.IndexOf(values[0]), names.IndexOf(values[1]), DiagramSyntax.Number(values[2], line, true))); }
        DiagramSyntax.Nonempty(links.Count, DiagramKind.Sankey); if (names.Count > 100) throw new DiagramRenderException("桑基图最多支持 100 个节点。", "limit");
        var degrees = Enumerable.Range(0, names.Count).Select(i => links.Count(link => link.To == i)).ToArray(); var ranks = new int[names.Count]; var queue = Enumerable.Range(0, names.Count).Where(i => degrees[i] == 0).ToList();
        for (var cursor = 0; cursor < queue.Count; cursor++) foreach (var link in links.Where(link => link.From == queue[cursor])) { ranks[link.To] = Math.Max(ranks[link.To], ranks[link.From] + 1); if (--degrees[link.To] == 0) queue.Add(link.To); }
        if (queue.Count != names.Count) throw new DiagramRenderException("桑基图当前不支持循环流量。", "unsupported-syntax");
        var valuesByNode = Enumerable.Range(0, names.Count).Select(i => Math.Max(links.Where(link => link.From == i).Sum(link => link.Value), links.Where(link => link.To == i).Sum(link => link.Value))).ToArray(); var layers = Enumerable.Range(0, ranks.Max() + 1).Select(rank => Enumerable.Range(0, names.Count).Where(i => ranks[i] == rank).ToArray()).ToArray();
        var height = Math.Max(380, layers.Max(layer => layer.Length) * 56); var width = Math.Max(760, layers.Length * 220); var b = new SceneBuilder(DiagramKind.Sankey, text); var scale = layers.Min(layer => (height - 80 - (layer.Length - 1) * 20) / layer.Sum(i => valuesByNode[i])); var rects = new DiagramRect[names.Count];
        for (var rank = 0; rank < layers.Length; rank++) { var layer = layers[rank]; var h = layer.Sum(i => valuesByNode[i] * scale) + (layer.Length - 1) * 20; var y = (height - h) / 2; foreach (var i in layer) { rects[i] = new(80 + rank / (double)Math.Max(1, layers.Length - 1) * (width - 160), y, 16, valuesByNode[i] * scale); y += rects[i].Height + 20; } }
        var outgoing = new double[names.Count]; var incoming = new double[names.Count];
        foreach (var link in links)
        { var a = rects[link.From]; var z = rects[link.To]; var thickness = link.Value * scale; var ay = a.Y + outgoing[link.From]; var zy = z.Y + incoming[link.To]; var middle = (a.Right + z.X) / 2; b.Path([new PathCommand.Move(new(a.Right, ay)), new PathCommand.Cubic(new(middle, ay), new(middle, zy), new(z.X, zy)), new PathCommand.Line(new(z.X, zy + thickness)), new PathCommand.Cubic(new(middle, zy + thickness), new(middle, ay + thickness), new(a.Right, ay + thickness)), new PathCommand.Close()], C.Series(link.From), C.None, opacity: .3); outgoing[link.From] += thickness; incoming[link.To] += thickness; }
        for (var i = 0; i < names.Count; i++) { var r = rects[i]; b.Rect(r, C.Series(i), C.None, 1, id: $"sankey-{i}", label: $"{names[i]}: {DataCharts.Format(valuesByNode[i])}"); var right = ranks[i] < layers.Length - 1; b.Text(names[i], new(right ? r.Right + 6 : r.X - 156, r.Center.Y - 12, 150, 24), 13, align: right ? TextAlignment.Leading : TextAlignment.Trailing); }
        return b.Build(width + 20, height);
    }
    private sealed record SetValue(string Id, string Label, double Value, bool ShowValue);
    public DiagramScene Venn(string source)
    {
        var sets = new List<SetValue>(); var intersections = new List<(string[] Ids, double Value, string Label)>(); string[] current = []; var texts = new List<(string Id, string[] Ids, string Label)>(); var lines = DiagramSyntax.Lines(source);
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if (DiagramSyntax.Match(@"^set\s+(\w+)(?:\[([^\]]+)\])?(?:\s*:\s*([-+\d.eE]+))?$", s) is { } set)
            { if (sets.Any(item => item.Id == set[1])) throw line.Error("集合标识符重复。", "semantic"); sets.Add(new(set[1], set[2].Length == 0 ? set[1] : DiagramSyntax.Label(set[2]), set[3].Length == 0 ? 10 : DiagramSyntax.Number(set[3], line, true), set[3].Length > 0)); current = [set[1]]; }
            else if (DiagramSyntax.Match(@"^union\s+([\w, ]+?)(?:\[([^\]]+)\])?(?:\s*:\s*([-+\d.eE]+))?$", s) is { } union)
            { var ids = DiagramSyntax.Split(union[1]).ToArray(); var value = union[3].Length == 0 ? 10 / Math.Pow(ids.Length, 2) : DiagramSyntax.Number(union[3], line); if (ids.Length < 2 || ids.Distinct().Count() != ids.Length || value < 0) throw line.Error("交集需要至少两个不同集合及非负数值。", "semantic"); intersections.Add((ids, value, union[2].Length == 0 ? union[3].Length == 0 ? "" : DataCharts.Format(value) : DiagramSyntax.Label(union[2]))); current = ids; }
            else if (DiagramSyntax.Match(@"^text\s+(\w+)(?:\[([^\]]+)\])?$", s) is { } annotation)
            { if (current.Length == 0 || texts.Any(value => value.Id == annotation[1])) throw line.Error("区域文字需要前置集合或交集，并使用独立标识符。", "semantic"); texts.Add((annotation[1], current, annotation[2].Length == 0 ? annotation[1] : DiagramSyntax.Label(annotation[2]))); }
            else throw line.Error("韦恩图当前支持 set、union 和区域 text 声明。");
        }
        if (sets.Count is < 1 or > 3) throw new DiagramRenderException("韦恩图当前支持 1 到 3 个集合。", "unsupported-syntax");
        foreach (var item in intersections) { var values = item.Ids.Select(id => sets.FirstOrDefault(set => set.Id == id)?.Value).ToArray(); if (values.Any(value => value is null) || item.Value > values.Min()) throw new DiagramRenderException("交集引用未知集合或大于集合本身。", "semantic"); }
        var scale = 150 / Math.Sqrt(sets.Max(set => set.Value) / Math.PI); var radii = sets.Select(set => Math.Sqrt(set.Value / Math.PI) * scale).ToArray();
        Func<int, int, double> desired = (a, z) =>
        {
            var fallback = intersections.Any(item => item.Ids.Length == 3) ? Math.Min(sets[a].Value, sets[z].Value) * .3 : 0; var match = intersections.FindIndex(item => item.Ids.ToHashSet().SetEquals([sets[a].Id, sets[z].Id])); var value = match >= 0 ? intersections[match].Value : fallback; var target = value * scale * scale; var r = radii[a]; var s = radii[z]; var low = Math.Abs(r - s); var high = r + s;
            for (var i = 0; i < 70; i++) { var d = (low + high) / 2; var aa = Math.Acos(Math.Clamp((d * d + r * r - s * s) / (2 * d * r), -1, 1)); var bb = Math.Acos(Math.Clamp((d * d + s * s - r * r) / (2 * d * s), -1, 1)); var area = r * r * aa + s * s * bb - .5 * Math.Sqrt(Math.Max(0, (-d + r + s) * (d + r - s) * (d - r + s) * (d + r + s))); if (area > target) low = d; else high = d; }
            return (low + high) / 2;
        };
        var centers = new List<DiagramPoint> { new() }; if (sets.Count > 1) centers.Add(new(desired(0, 1), 0));
        if (sets.Count > 2) { var a = Math.Max(.001, centers[1].X); var z = desired(0, 2); var c = desired(1, 2); var x = (z * z + a * a - c * c) / (2 * a); if (Math.Abs(x) > z + .1) throw new DiagramRenderException("这些交集权重无法表示为三个圆形集合。", "semantic"); centers.Add(new(x, Math.Sqrt(Math.Max(0, z * z - x * x)))); }
        var bounds = centers.Select((p, i) => new DiagramRect(p.X - radii[i], p.Y - radii[i], radii[i] * 2, radii[i] * 2)).Aggregate((a, b) => a.Union(b)); var width = Math.Max(460, bounds.Width + 80); var b = new SceneBuilder(DiagramKind.Venn, text); var top = b.Title(DiagramSyntax.Title(lines), width);
        centers = centers.Select(p => p.Offset(-bounds.X + (width - bounds.Width) / 2, -bounds.Y + top + 28)).ToList(); var centroid = new DiagramPoint(centers.Average(p => p.X), centers.Average(p => p.Y));
        for (var i = 0; i < sets.Count; i++)
        {
            var r = new DiagramRect(centers[i].X - radii[i], centers[i].Y - radii[i], radii[i] * 2, radii[i] * 2); b.Ellipse(r, C.Series(i), C.Series(i), .3, sets[i].Id, sets[i].Label); var frame = new DiagramRect(r.X, r.Y + 12, r.Width, 48);
            if (sets.Count == 3) { var dx = centers[i].X - centroid.X; var dy = centers[i].Y - centroid.Y; var length = double.Hypot(dx, dy); if (length > .001) { var p = centers[i].Offset(dx / length * radii[i] * .55, dy / length * radii[i] * .55); var w = Math.Min(160, Math.Max(1, r.Width - 16)); frame = new(p.X - w / 2, p.Y - 24, w, 48); } }
            b.Text(sets[i].Label + (sets[i].ShowValue ? "\n" + DataCharts.Format(sets[i].Value) : ""), frame, 14, bold: true);
        }
        Func<string[], DiagramPoint> position = ids => { var values = ids.Select(id => centers[sets.FindIndex(set => set.Id == id)]).ToArray(); return new(values.Average(p => p.X), values.Average(p => p.Y)); };
        foreach (var item in intersections) { var p = position(item.Ids); b.Text(item.Label, new(p.X - 80, p.Y - 12, 160, 24), 14); }
        var rows = new Dictionary<string, int>(); foreach (var item in texts) { var key = string.Join(',', item.Ids.Order()); var row = rows.GetValueOrDefault(key); rows[key] = row + 1; var p = position(item.Ids); b.Text(item.Label, new(p.X - 70, p.Y + 22 + row * 26, 140, 24), 13); b.Primitives[^1] = b.Primitives[^1] with { Id = item.Id, Label = item.Label }; }
        return b.Build(width, top + bounds.Height + 64);
    }
    public DiagramScene Cynefin(string source)
    {
        string[] keys = ["complex", "complicated", "clear", "chaotic", "confusion"], descriptions = ["Probe → Sense → Respond", "Sense → Analyze → Respond", "Sense → Categorize → Respond", "Act → Sense → Respond", "Disorder"];
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Cynefin, text); var items = new Dictionary<string, List<string>>(); string? current = null; var transitions = new List<(string From, string To, string Label)>();
        foreach (var line in lines.Skip(1))
        { var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue; if (keys.Contains(s)) { current = s; items.TryAdd(s, []); continue; } if (DiagramSyntax.Match(@"^(complex|complicated|clear|chaotic|confusion)\s*-->\s*(complex|complicated|clear|chaotic|confusion)(?:\s*:\s*(.*))?$", s) is { } m) { if (m[1] != m[2]) transitions.Add((m[1], m[2], DiagramSyntax.Label(m[3]))); continue; } if (current is null || !s.StartsWith('"') || !s.EndsWith('"')) throw line.Error("Cynefin 条目需要所属领域和双引号标签。", "syntax"); items[current].Add(DiagramSyntax.Label(s)); }
        var centerHeight = Math.Max(72, items.GetValueOrDefault("confusion", []).Count * 44 + 68); var centerGap = Math.Max(20, centerHeight - 32); var cellHeight = Math.Max(230, items.Values.Select(values => values.Count).DefaultIfEmpty(0).Max() * 52 + 80); const double width = 900; var top = b.Title(DiagramSyntax.Title(lines), width);
        DiagramRect[] frames = [new(20, top, 420, cellHeight), new(460, top, 420, cellHeight), new(460, top + cellHeight + centerGap, 420, cellHeight), new(20, top + cellHeight + centerGap, 420, cellHeight), new(310, top + cellHeight - 16, 280, centerHeight)];
        for (var i = 0; i < keys.Length; i++) { var r = frames[i]; b.Rect(r, C.Series(i), C.Border, 12, i == 4 ? .6 : .08); b.Text(char.ToUpperInvariant(keys[i][0]) + keys[i][1..], new(r.X + 8, r.Y + 10, r.Width - 16, 24), 17, bold: true); b.Text(descriptions[i], new(r.X + 8, r.Y + 36, r.Width - 16, 22), 12, C.Muted); var values = items.GetValueOrDefault(keys[i], []); for (var j = 0; j < values.Count; j++) b.Box(values[j], new(r.X + 20, r.Y + 70 + j * (i == 4 ? 44 : 52), r.Width - 40, 40), C.Background, id: $"{keys[i]}-{j}", size: 14); }
        foreach (var (from, to, label) in transitions) { var a = frames[Array.IndexOf(keys, from)]; var z = frames[Array.IndexOf(keys, to)]; b.Line([a.Center, z.Center], C.Accent, 1.5, arrow: true); if (label.Length > 0) b.Box(label, new((a.Center.X + z.Center.X) / 2 - 100, (a.Center.Y + z.Center.Y) / 2 - 14, 200, 28), C.Background, size: 12); }
        return b.Build(width, top + cellHeight * 2 + centerGap + 20);
    }
    private sealed record Component(string Label, double X, double Y, bool Anchor);
    public DiagramScene Wardley(string source)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Wardley, text); var components = new List<Component>(); var links = new List<(string From, string To)>(); var evolutions = new List<(string Name, double Target)>();
        Func<string, SourceLine, double> fraction = (value, line) => { var number = DiagramSyntax.Number(value, line); if (number is < 0 or > 100) throw line.Error("地图坐标需要 0 到 1 的小数或 0 到 100 的百分数。", "semantic"); return number <= 1 ? number : number / 100; };
        foreach (var line in lines.Skip(1))
        { var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue; if (DiagramSyntax.Match(@"^(anchor|component)\s+(.+?)\s*\[([^,]+),([^\]]+)\]$", s) is { } c) { if (components.Any(item => item.Label == c[2])) throw line.Error("组件名称重复。", "semantic"); components.Add(new(c[2], fraction(c[4], line), fraction(c[3], line), c[1] == "anchor")); } else if (DiagramSyntax.Match(@"^(.+?)\s*->\s*(.+)$", s) is { } link) links.Add((link[1], link[2])); else if (DiagramSyntax.Match(@"^evolve\s+(.+?)\s+([\d.]+)$", s) is { } evolution) evolutions.Add((evolution[1], fraction(evolution[2], line))); else throw line.Error("暂不支持这条 Wardley 图语法。"); }
        DiagramSyntax.Nonempty(components.Count, DiagramKind.Wardley); const double width = 860; var top = b.Title(DiagramSyntax.Title(lines), width); var plot = new DiagramRect(72, top + 16, 740, 440); b.Line([new(plot.Left, plot.Top), new(plot.Left, plot.Bottom), new(plot.Right, plot.Bottom)], C.Border);
        string[] labels = ["Genesis", "Custom-built", "Product", "Commodity"]; for (var i = 0; i < 4; i++) { var x = plot.Left + i * plot.Width / 4; b.Line([new(x, plot.Top), new(x, plot.Bottom)], C.Border, dash: [3, 4]); b.Text(labels[i], new(x, plot.Bottom + 8, plot.Width / 4, 28), 13, C.Muted); }
        Func<Component, DiagramPoint> point = c => new(plot.X + c.X * plot.Width, plot.Bottom - c.Y * plot.Height);
        foreach (var (from, to) in links) { var a = components.FirstOrDefault(c => c.Label == from); var z = components.FirstOrDefault(c => c.Label == to); if (a is null || z is null) throw new DiagramRenderException("地图关系引用了未知组件。", "semantic"); b.Line([point(a), point(z)], C.Line); }
        foreach (var (name, target) in evolutions) { var c = components.FirstOrDefault(c => c.Label == name) ?? throw new DiagramRenderException("演化路径引用了未知组件。", "semantic"); var a = point(c); b.Line([a, new(plot.X + target * plot.Width, a.Y)], C.Accent, dash: [4, 4], arrow: true); }
        for (var i = 0; i < components.Count; i++) { var c = components[i]; var p = point(c); var r = new DiagramRect(p.X - 5, p.Y - 5, 10, 10); if (c.Anchor) b.Rect(r, C.Foreground, C.None, 0, id: $"component-{i}", label: c.Label); else b.Ellipse(r, C.Background, C.Foreground, id: $"component-{i}", label: c.Label); b.Text(c.Label, new(Math.Clamp(p.X - 80, plot.Left, plot.Right - 160), p.Y + 8, 160, 24), 13); }
        b.Text("Visible", new(4, plot.Top - 20, 68, 24), 12, C.Muted); b.Text("Invisible", new(4, plot.Bottom - 10, 68, 24), 12, C.Muted); return b.Build(width, plot.Bottom + 60);
    }
}
