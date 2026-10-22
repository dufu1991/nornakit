using System.Globalization;

namespace NornaKit;

internal sealed class DataCharts(TextMeasurement text)
{
    public static string Format(double value) => value.ToString(value == Math.Round(value) ? "0" : "G2", CultureInfo.InvariantCulture);
    public static IEnumerable<PathCommand> Arc(DiagramPoint center, double radius, double from, double to)
    {
        var count = Math.Max(1, (int)Math.Ceiling(Math.Abs(to - from) / (Math.PI / 2))); var step = (to - from) / count;
        for (var i = 0; i < count; i++)
        {
            var a = from + i * step; var z = a + step; var k = 4d / 3 * Math.Tan(step / 4);
            var p = new DiagramPoint(center.X + radius * Math.Cos(a), center.Y + radius * Math.Sin(a)); var q = new DiagramPoint(center.X + radius * Math.Cos(z), center.Y + radius * Math.Sin(z));
            yield return new PathCommand.Cubic(new(p.X - radius * Math.Sin(a) * k, p.Y + radius * Math.Cos(a) * k), new(q.X + radius * Math.Sin(z) * k, q.Y - radius * Math.Cos(z) * k), q);
        }
    }
    public DiagramScene Pie(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); var titleIndex = lines[0].Text.IndexOf("title ", StringComparison.Ordinal); var title = titleIndex < 0 ? "" : lines[0].Text[(titleIndex + 6)..]; var values = new List<(string Label, double Value)>();
        foreach (var line in lines.Skip(1))
        {
            if (line.Text.StartsWith("title ", StringComparison.Ordinal)) { title = line.Text[6..]; continue; }
            var m = DiagramSyntax.Match("^\"([^\"]+)\"\\s*:\\s*([\\d.eE+-]+)$", line.Text) ?? throw line.Error("饼图数据应写作双引号标签、冒号与数值。", "syntax");
            var value = DiagramSyntax.Number(m[2], line); if (value < 0) throw line.Error("饼图数值不能为负。", "semantic"); values.Add((m[1], value));
        }
        DiagramSyntax.Nonempty(values.Count, DiagramKind.Pie); var total = values.Sum(item => item.Value); if (total <= 0) throw new DiagramRenderException("饼图总值必须大于零。", "semantic");
        var b = new SceneBuilder(DiagramKind.Pie, text); var width = options.Width(Math.Max(620, values.Max(item => text.Width(item.Label)) + 460)); var stacked = width < 560;
        var radius = stacked ? Math.Min(160, (width - 48) / 2) : 160; var top = b.Title(title, width); var center = new DiagramPoint(stacked ? width / 2 : 205, top + radius + 24); var angle = -Math.PI / 2;
        for (var i = 0; i < values.Count; i++)
        {
            var item = values[i]; if (item.Value <= 0) continue; var end = angle + item.Value / total * 2 * Math.PI;
            var commands = new List<PathCommand> { new PathCommand.Move(center), new PathCommand.Line(new(center.X + Math.Cos(angle) * radius, center.Y + Math.Sin(angle) * radius)) }; commands.AddRange(Arc(center, radius, angle, end)); commands.Add(new PathCommand.Close());
            b.Path(commands, C.Series(i), C.Background, id: $"slice-{i}");
            if (item.Value / total >= .045) { var mid = (angle + end) / 2; b.Text((item.Value / total * 100).ToString("F1", CultureInfo.InvariantCulture) + "%", new(center.X + Math.Cos(mid) * radius * .65 - 32, center.Y + Math.Sin(mid) * radius * .65 - 12, 64, 24), 14, C.OnSeries(i)); }
            angle = end;
        }
        var legendY = stacked ? top + radius * 2 + 60 : top + 36;
        for (var i = 0; i < values.Count; i++)
        { var x = stacked ? 24 : 402; var label = $"{values[i].Label}  {Format(values[i].Value)}"; var w = width - x - 42; var h = Math.Max(24, text.Lines(label, w).Length * 20); b.Rect(new(x, legendY + 5, 14, 14), C.Series(i), C.None); b.Text(label, new(x + 26, legendY, w, h), 14, align: TextAlignment.Leading); legendY += h + 6; }
        return b.Build(width, Math.Max(top + radius * 2 + 48, legendY + 24));
    }
    public DiagramScene XY(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); if (lines[0].Text.Contains("horizontal", StringComparison.Ordinal)) throw lines[0].Error("XY 图暂不支持 horizontal 方向。");
        var title = ""; var categories = new List<string>(); var xLabel = ""; var yLabel = ""; (double Low, double High)? range = null; var series = new List<(string Type, string Label, double[] Values)>();
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text;
            if (s.StartsWith("title ", StringComparison.Ordinal)) title = DiagramSyntax.Label(s[6..]);
            else if (DiagramSyntax.Match(@"^x-axis\s*(.*?)\s*\[(.*)\]$", s) is { } x) { xLabel = DiagramSyntax.Label(x[1]); categories = DiagramSyntax.Split(x[2]).Select(DiagramSyntax.Label).ToList(); }
            else if (DiagramSyntax.Match(@"^y-axis\s*(.*?)\s+([-+\d.eE]+)\s*-->\s*([-+\d.eE]+)$", s) is { } y) { yLabel = DiagramSyntax.Label(y[1]); range = (DiagramSyntax.Number(y[2], line), DiagramSyntax.Number(y[3], line)); }
            else if (s.StartsWith("y-axis ", StringComparison.Ordinal)) yLabel = DiagramSyntax.Label(s[7..]);
            else if (DiagramSyntax.Match(@"^(bar|line)\s*(.*?)\s*\[(.*)\]$", s) is { } data) series.Add((data[1], DiagramSyntax.Label(data[2]), DiagramSyntax.Split(data[3]).Select(value => DiagramSyntax.Number(value, line)).ToArray()));
            else throw line.Error($"暂不支持这条 XY 图语法：{s}");
        }
        DiagramSyntax.Nonempty(series.Count, DiagramKind.XYChart); var count = series[0].Values.Length;
        if (count is <= 0 or > 100 || series.Any(item => item.Values.Length != count) || categories.Count != 0 && categories.Count != count) throw new DiagramRenderException("坐标轴标签和每条数据系列的数量必须一致，最多 100 项。", "semantic");
        if (categories.Count == 0) categories = Enumerable.Range(1, count).Select(value => value.ToString(CultureInfo.InvariantCulture)).ToList();
        var all = series.SelectMany(item => item.Values).ToArray(); var low = range?.Low ?? Math.Min(0, all.Min()); var high = range?.High ?? Math.Max(1, all.Max() * 1.1);
        if (high <= low) throw new DiagramRenderException("纵轴上限必须大于下限。", "semantic"); if (all.Any(value => value < low || value > high)) throw new DiagramRenderException("数据超出显式纵轴范围。", "semantic");
        var width = options.Width(Math.Max(680, count * 64 + 120), Math.Max(320, count * 28 + 118)); var b = new SceneBuilder(DiagramKind.XYChart, text); var top = b.Title(title, width); var plot = new DiagramRect(82, top + 16, width - 118, 320);
        Func<double, double> py = value => plot.Bottom - (value - low) / (high - low) * plot.Height;
        for (var tick = 0; tick <= 5; tick++) { var value = low + (high - low) * tick / 5; var y = py(value); b.Line([new(plot.Left, y), new(plot.Right, y)], C.Border, dash: [2, 4]); b.Text(Format(value), new(4, y - 12, 68, 24), 12, C.Muted, TextAlignment.Trailing); }
        var slot = plot.Width / count; var baseline = py(Math.Clamp(0, low, high)); var bars = Enumerable.Range(0, series.Count).Where(i => series[i].Type == "bar").ToList();
        for (var i = 0; i < series.Count; i++)
        {
            var item = series[i];
            if (item.Type == "bar") for (var j = 0; j < count; j++)
            { var barWidth = slot * .7 / Math.Max(1, bars.Count); var y = py(item.Values[j]); var x = plot.Left + j * slot + slot * .15 + bars.IndexOf(i) * barWidth; b.Rect(new(x, Math.Min(y, baseline), Math.Max(.5, barWidth - 2), Math.Max(.5, Math.Abs(y - baseline))), C.Series(i), C.None, 2, id: $"bar-{i}-{j}", label: $"{categories[j]}: {Format(item.Values[j])}"); }
            else
            { var points = item.Values.Select((value, j) => new DiagramPoint(plot.Left + (j + .5) * slot, py(value))).ToArray(); b.Line(points, C.Series(i), 2); for (var j = 0; j < count; j++) b.Ellipse(new(points[j].X - 3, points[j].Y - 3, 6, 6), C.Series(i), C.Background, id: $"point-{i}-{j}", label: $"{categories[j]}: {Format(item.Values[j])}"); }
        }
        b.Line([new(plot.Left, plot.Top), new(plot.Left, plot.Bottom), new(plot.Right, plot.Bottom)], C.Border);
        var axisHeight = Math.Max(24, categories.Max(label => text.Lines(label, Math.Max(12, slot - 4)).Length) * 18);
        for (var i = 0; i < count; i++) b.Text(categories[i], new(plot.Left + i * slot + 2, plot.Bottom + 8, slot - 4, axisHeight), 12, C.Muted);
        b.Text(xLabel, new(plot.Left, plot.Bottom + axisHeight + 16, plot.Width, 24), 14); b.Text(yLabel, new(4, top - 10, width - 8, 24), 12, C.Muted, TextAlignment.Leading);
        var perRow = Math.Max(1, (int)((width - 80) / 150));
        for (var i = 0; i < series.Count; i++) { var x = 80 + i % perRow * 150; var row = i / perRow * 30; b.Rect(new(x, plot.Bottom + axisHeight + 60 + row, 14, 12), C.Series(i), C.None); b.Text(series[i].Label.Length == 0 ? $"{series[i].Type} {i + 1}" : series[i].Label, new(x + 22, plot.Bottom + axisHeight + 54 + row, 124, 24), 12, align: TextAlignment.Leading); }
        return b.Build(width, plot.Bottom + axisHeight + 90 + (series.Count - 1) / perRow * 30);
    }
    public DiagramScene Quadrant(string source)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.QuadrantChart, text); var top = b.Title(DiagramSyntax.Title(lines), 640); var plot = new DiagramRect(80, top + 30, 480, 400);
        string[] labels = ["", "", "", ""], xLabels = ["", ""], yLabels = ["", ""]; var points = new List<(string Label, double X, double Y)>();
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if (DiagramSyntax.Match(@"^quadrant-([1-4])\s+(.+)$", s) is { } q) labels[int.Parse(q[1], CultureInfo.InvariantCulture) - 1] = q[2];
            else if (DiagramSyntax.Match(@"^([xy])-axis\s+(.+?)\s*-->\s*(.+)$", s) is { } axis) { if (axis[1] == "x") xLabels = [axis[2], axis[3]]; else yLabels = [axis[2], axis[3]]; }
            else if (DiagramSyntax.Match(@"^(.+?):\s*\[([^,]+),([^\]]+)\]$", s) is { } point)
            { var x = DiagramSyntax.Number(point[2], line); var y = DiagramSyntax.Number(point[3], line); if (x is < 0 or > 1 || y is < 0 or > 1) throw line.Error("象限坐标必须在 0 与 1 之间。", "semantic"); points.Add((DiagramSyntax.Label(point[1]), x, y)); }
            else throw line.Error($"暂不支持这条象限图语法：{s}");
        }
        for (var i = 0; i < 4; i++) { var r = new DiagramRect(plot.Left + (i is 0 or 3 ? plot.Width / 2 : 0), plot.Top + (i > 1 ? plot.Height / 2 : 0), plot.Width / 2, plot.Height / 2); b.Rect(r, C.Series(i), C.Border, 0, .13); b.Text(labels[i], new(r.X + 6, r.Y + 8, r.Width - 12, 24), 14, C.Muted); }
        for (var i = 0; i < points.Count; i++) { var p = points[i]; var x = plot.X + p.X * plot.Width; var y = plot.Bottom - p.Y * plot.Height; b.Ellipse(new(x - 5, y - 5, 10, 10), C.Accent, C.Background, id: $"quadrant-{i}", label: p.Label); b.Text(p.Label, new(Math.Clamp(x - 90, plot.Left, plot.Right - 180), Math.Min(y + 8, plot.Bottom - 26), 180, 24), 12); }
        b.Text(xLabels[0], new(plot.Left, plot.Bottom + 10, plot.Width / 2, 24), 12, align: TextAlignment.Leading); b.Text(xLabels[1], new(plot.Center.X, plot.Bottom + 10, plot.Width / 2, 24), 12, align: TextAlignment.Trailing);
        b.Text(yLabels[1], new(4, top + 2, 632, 22), 12, C.Muted, TextAlignment.Leading); b.Text(yLabels[0], new(4, plot.Bottom + 42, 632, 22), 12, C.Muted, TextAlignment.Leading); return b.Build(640, plot.Bottom + 80);
    }
    public DiagramScene Radar(string source, DiagramLayoutOptions options)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Radar, text); var axes = new List<string>(); var curves = new List<(string Label, double[] Values)>(); double? maximum = null; double minimum = 0; var circular = false;
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if (s.StartsWith("axis ", StringComparison.Ordinal)) axes.AddRange(DiagramSyntax.Split(s[5..]).Select(value => DiagramSyntax.Match("^\\w+\\[\"([^\"]+)\"\\]$", value)?[1] ?? DiagramSyntax.Label(value)));
            else if (DiagramSyntax.Match("^curve\\s+(\\w+)(?:\\[\"([^\"]+)\"\\])?\\s*\\{([^}]+)\\}$", s) is { } curve) curves.Add((curve[2].Length == 0 ? curve[1] : curve[2], DiagramSyntax.Split(curve[3]).Select(value => DiagramSyntax.Number(value, line)).ToArray()));
            else if (s == "graticule polygon") circular = false; else if (s == "graticule circle") circular = true;
            else if (s.StartsWith("min ", StringComparison.Ordinal)) minimum = DiagramSyntax.Number(s[4..], line);
            else if (s.StartsWith("max ", StringComparison.Ordinal)) maximum = DiagramSyntax.Number(s[4..], line, true);
            else throw line.Error($"暂不支持这条雷达图语法：{s}");
        }
        if (axes.Count is < 3 or > 30 || curves.Count == 0 || curves.Any(curve => curve.Values.Length != axes.Count || curve.Values.Any(value => value < 0))) throw new DiagramRenderException("雷达图至少需要 3 个轴，每条曲线需要相同数量的非负数据。", "semantic");
        var high = maximum ?? Math.Max(1, curves.SelectMany(curve => curve.Values).Max()); if (high <= minimum || curves.SelectMany(curve => curve.Values).Any(value => value < minimum || value > high)) throw new DiagramRenderException("雷达图数据超过 max。", "semantic");
        var width = options.Width(620, 360); var radius = Math.Min(165, (width - 200) / 2); var top = b.Title(DiagramSyntax.Title(lines), width); var center = new DiagramPoint(width / 2, top + radius + 55);
        Func<int, double, DiagramPoint> point = (i, r) => { var angle = i / (double)axes.Count * 2 * Math.PI - Math.PI / 2; return new(center.X + Math.Cos(angle) * r, center.Y + Math.Sin(angle) * r); };
        for (var tick = 1; tick <= 5; tick++) { var r = radius * tick / 5; if (circular) b.Ellipse(new(center.X - r, center.Y - r, r * 2, r * 2), C.None, C.Border); else b.Path(Polygon(Enumerable.Range(0, axes.Count).Select(i => point(i, r))), stroke: C.Border, dash: [2, 3]); }
        for (var i = 0; i < axes.Count; i++) { b.Line([center, point(i, radius)], C.Border); var p = point(i, radius + 32); b.Text(axes[i], new(p.X - 64, p.Y - 16, 128, 32), 13); }
        var perRow = Math.Max(1, (int)((width - 80) / 150)); var legendY = top + radius * 2 + 120;
        for (var i = 0; i < curves.Count; i++) { var curve = curves[i]; b.Path(Polygon(curve.Values.Select((value, j) => point(j, radius * (value - minimum) / (high - minimum)))), C.Series(i), C.Series(i), 2, opacity: .3, id: $"radar-{i}"); var x = 40 + i % perRow * 150; var y = legendY + i / perRow * 28; b.Rect(new(x, y + 6, 12, 12), C.Series(i), C.None, 3); b.Text(curve.Label, new(x + 20, y, 120, 24), 13, align: TextAlignment.Leading); }
        return b.Build(width, legendY + (curves.Count - 1) / perRow * 28 + 40);
    }
    internal static IEnumerable<PathCommand> Polygon(IEnumerable<DiagramPoint> values)
    { var points = values.ToArray(); if (points.Length == 0) yield break; yield return new PathCommand.Move(points[0]); foreach (var point in points.Skip(1)) yield return new PathCommand.Line(point); yield return new PathCommand.Close(); }
}
