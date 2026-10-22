namespace NornaKit;

internal sealed record HierarchyItem(int Id, string Label, int? Parent, int Depth, double? Weight);
internal sealed class HierarchyDiagrams(TextMeasurement text)
{
    private static List<HierarchyItem> Parse(string source, DiagramKind kind)
    {
        var items = new List<HierarchyItem>(); var stack = new Stack<(int Id, int Indent)>();
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if (s.StartsWith("::", StringComparison.Ordinal) || s.Contains("@{", StringComparison.Ordinal) || s.Contains(":::", StringComparison.Ordinal) || s.Contains(" icon(", StringComparison.Ordinal) || s.Contains(" ## ", StringComparison.Ordinal)) throw line.Error("树形图暂不支持图标、样式或元数据指令。");
            if (kind == DiagramKind.TreeView && (s.Contains('├') || s.Contains('└') || s.StartsWith('│'))) throw line.Error("目录树当前支持空格缩进格式。");
            while (stack.TryPeek(out var last) && line.Indent <= last.Indent) stack.Pop();
            if (stack.Count >= 16) throw line.Error("树形结构最多嵌套 16 层。", "limit");
            string title; double? weight = null;
            if (kind == DiagramKind.Treemap)
            { var m = DiagramSyntax.Match("^\"([^\"]+)\"(?:\\s*:\\s*([-+\\d.eE]+))?$", s) ?? throw line.Error("矩形树图条目需要双引号标签和可选的正数权重。", "syntax"); title = m[1]; if (m[2].Length > 0) weight = DiagramSyntax.Number(m[2], line, true); }
            else title = DiagramSyntax.Match(@"^\w+(?:\(\((.*?)\)\)|\[(.*?)\]|\((.*?)\)|\{(.*?)\})$", s) is { } shaped ? DiagramSyntax.Label(shaped.Skip(1).FirstOrDefault(value => value.Length > 0) ?? s) : DiagramSyntax.Label(s);
            var item = new HierarchyItem(items.Count, title, stack.TryPeek(out var parent) ? parent.Id : null, stack.Count, weight); items.Add(item); stack.Push((item.Id, line.Indent));
        }
        DiagramSyntax.Nonempty(items.Count, kind); return items;
    }
    public DiagramScene Tree(string source)
    {
        var items = Parse(source, DiagramKind.TreeView); var b = new SceneBuilder(DiagramKind.TreeView, text); var width = Math.Max(420, items.Max(item => item.Depth * 28 + text.Width(item.Label) + 78));
        foreach (var item in items)
        {
            var x = 30 + item.Depth * 28; var y = 22 + item.Id * 30;
            if (item.Parent is { } parent) b.Line([new(x - 18, 22 + parent * 30 + 24), new(x - 18, y + 12), new(x - 5, y + 12)], C.Border);
            if (item.Label.EndsWith('/')) { b.Rect(new(x, y + 5, 15, 12), C.SurfaceAlt, radius: 2, id: $"tree-{item.Id}", label: item.Label); b.Line([new(x + 1, y + 5), new(x + 1, y + 2), new(x + 7, y + 2), new(x + 10, y + 5)], C.Border); }
            else b.Rect(new(x + 2, y + 2, 11, 16), C.Background, radius: 1, id: $"tree-{item.Id}", label: item.Label);
            b.Text(item.Label, new(x + 24, y, width - x - 36, 24), 14, align: TextAlignment.Leading, mono: true);
        }
        return b.Build(width, items.Count * 30 + 44);
    }
    public DiagramScene Mindmap(string source)
    {
        var items = Parse(source, DiagramKind.Mindmap); if (items.Count(item => item.Parent is null) != 1) throw new DiagramRenderException("思维导图必须只有一个根节点。", "semantic");
        var children = items.Where(item => item.Parent is not null).GroupBy(item => item.Parent!.Value).ToDictionary(group => group.Key, group => group.ToArray()); var heights = new Dictionary<int, double>();
        Func<int, double> height = null!;
        height = id => { if (heights.TryGetValue(id, out var cached)) return cached; var kids = children.GetValueOrDefault(id, []); var own = Math.Max(56, text.Lines(items[id].Label, 154).Length * 22 + 16); return heights[id] = Math.Max(own, kids.Sum(item => height(item.Id)) + Math.Max(0, kids.Length - 1) * 24); };
        var branches = children.GetValueOrDefault(0, []); var left = branches.Take((branches.Length + 1) / 2).ToArray(); var right = branches.Skip(left.Length).ToArray(); var rootX = items.Max(item => item.Depth) * 220 + 110;
        var leftH = left.Sum(item => height(item.Id) + 24); var rightH = right.Sum(item => height(item.Id) + 24); var total = Math.Max(130, Math.Max(leftH, rightH) + 60); var b = new SceneBuilder(DiagramKind.Mindmap, text); var root = new DiagramRect(rootX - 85, total / 2 - 28, 170, 56);
        Action<HierarchyItem, double, double, int, int, DiagramRect> draw = null!;
        draw = (item, x, cy, side, branch, parent) =>
        {
            var h = Math.Max(46, text.Lines(item.Label, 154).Length * 22 + 16); var r = new DiagramRect(x - 92, cy - h / 2, 184, h); var a = new DiagramPoint(side > 0 ? parent.Right : parent.Left, parent.Center.Y); var z = new DiagramPoint(side > 0 ? r.Left : r.Right, r.Center.Y);
            b.Path([new PathCommand.Move(a), new PathCommand.Cubic(new((a.X + z.X) / 2, a.Y), new((a.X + z.X) / 2, z.Y), z)], stroke: C.Series(branch), width: 1.5); b.Rect(r, C.Series(branch), C.Series(branch), opacity: .16, id: $"mindmap-{item.Id}", label: item.Label); b.Text(item.Label, r.Inset(10, 6), 14);
            var top = cy - height(item.Id) / 2; foreach (var child in children.GetValueOrDefault(item.Id, [])) { var ch = height(child.Id); draw(child, x + side * 220, top + ch / 2, side, branch, r); top += ch + 24; }
        };
        foreach (var (side, nodes, extent) in new[] { (-1, left, leftH), (1, right, rightH) }) { var y = (total - extent) / 2 + 12; foreach (var item in nodes) { var h = height(item.Id); draw(item, rootX + side * 240, y + h / 2, side, item.Id - 1, root); y += h + 24; } }
        b.Box(items[0].Label, root, C.SurfaceAlt, 28, "mindmap-root"); return b.Build(Math.Max(420, rootX * 2), total);
    }
    public DiagramScene Treemap(string source, DiagramLayoutOptions options)
    {
        var items = Parse(source, DiagramKind.Treemap); var b = new SceneBuilder(DiagramKind.Treemap, text); var children = items.Where(item => item.Parent is not null).GroupBy(item => item.Parent!.Value).ToDictionary(group => group.Key, group => group.ToArray());
        Func<HierarchyItem, double> weight = null!; weight = item => children.TryGetValue(item.Id, out var kids) ? kids.Sum(weight) : item.Weight ?? throw new DiagramRenderException($"叶节点 {item.Label} 缺少正数权重。", "semantic");
        var weights = items.ToDictionary(item => item.Id, weight); var width = options.Width(820); var top = b.Title(DiagramSyntax.Title(DiagramSyntax.Lines(source)), width);
        Action<HierarchyItem[], DiagramRect, int, int> tile = null!;
        tile = (siblings, rect, depth, series) =>
        {
            var total = siblings.Sum(item => weights[item.Id]); var horizontal = rect.Width >= rect.Height; var cursor = horizontal ? rect.Left : rect.Top;
            for (var index = 0; index < siblings.Length; index++)
            {
                var item = siblings[index]; var length = (horizontal ? rect.Width : rect.Height) * weights[item.Id] / total; var cell = horizontal ? new DiagramRect(cursor, rect.Top, length, rect.Height) : new(rect.Left, cursor, rect.Width, length); cursor += length;
                var r = cell.Inset(2, 2); var color = depth == 0 ? index : series; if (r.Width <= 1 || r.Height <= 1) continue;
                b.Rect(r, C.Series(color), C.Background, 2, children.ContainsKey(item.Id) ? .18 : .45, id: $"treemap-{item.Id}", label: $"{item.Label}: {DataCharts.Format(weights[item.Id])}");
                if (children.TryGetValue(item.Id, out var kids) && r.Height > 40 && r.Width > 24) { b.Text(item.Label, new(r.Left + 6, r.Top + 3, r.Width - 12, 24), 14, align: TextAlignment.Leading, bold: true); tile(kids, new(r.Left + 4, r.Top + 30, r.Width - 8, r.Height - 34), depth + 1, color); }
                else if (r.Width > 60 && r.Height > 36) b.Text($"{item.Label}\n{DataCharts.Format(weights[item.Id])}", r.Inset(6, 6), 13);
            }
        };
        tile(items.Where(item => item.Parent is null).ToArray(), new(12, top, width - 24, 440), 0, 0); return b.Build(width, top + 452);
    }
    public DiagramScene Ishikawa(string source)
    {
        var items = Parse(source, DiagramKind.Ishikawa); if (items.Count(item => item.Parent is null) != 1 || items.Any(item => item.Depth > 2)) throw new DiagramRenderException("鱼骨图当前支持一个结果、主因和次因三级结构。", "unsupported-syntax");
        var causes = items.Where(item => item.Parent == 0).ToArray(); var b = new SceneBuilder(DiagramKind.Ishikawa, text); var width = Math.Max(720, (causes.Length + 1) / 2 * 230 + 280); const double mid = 250;
        b.Line([new(30, mid), new(width - 210, mid)], width: 2, arrow: true); b.Box(items[0].Label, new(width - 205, mid - 35, 185, 70), C.SurfaceAlt, 12, "fish-effect");
        for (var index = 0; index < causes.Length; index++)
        {
            var item = causes[index]; var sign = index % 2 == 0 ? -1 : 1; var x = 100 + index / 2 * 230; var end = new DiagramPoint(x + 130, mid); var start = new DiagramPoint(x + 20, mid + sign * 150);
            b.Line([start, end], C.Series(index), 1.5); b.Text(item.Label, new(x - 30, start.Y + (sign < 0 ? -36 : 10), 170, 28), bold: true);
            var children = items.Where(child => child.Parent == item.Id).ToArray();
            for (var i = 0; i < children.Length; i++) { var t = (i + 1d) / (children.Length + 1); var p = new DiagramPoint(start.X + (end.X - start.X) * t, start.Y + (end.Y - start.Y) * t); b.Line([new(p.X - 76, p.Y), p], C.Border); b.Text(children[i].Label, new(p.X - 138, p.Y - 28, 132, 24), 12, align: TextAlignment.Leading); }
        }
        return b.Build(width, 500);
    }
    public DiagramScene Kanban(string source, DiagramLayoutOptions options)
    {
        var items = Parse(source, DiagramKind.Kanban); var roots = items.Where(item => item.Parent is null).ToArray(); var b = new SceneBuilder(DiagramKind.Kanban, text);
        if (items.Any(item => item.Depth > 1)) throw new DiagramRenderException("看板当前支持列与卡片两级结构。", "unsupported-syntax");
        var width = options.Width(Math.Max(320, roots.Length * 240 + 24), 264); var top = b.Title(DiagramSyntax.Title(DiagramSyntax.Lines(source)), width); var columns = Math.Min(roots.Length, Math.Max(1, (int)((width - 24) / 240))); var columnWidth = (width - 24) / columns;
        var rowTop = top; double rowHeight = 0, height = 200;
        for (var i = 0; i < roots.Length; i++)
        {
            var root = roots[i]; if (i > 0 && i % columns == 0) { rowTop += rowHeight + 24; rowHeight = 0; }
            var cards = items.Where(item => item.Parent == root.Id).ToArray(); var x = 16 + i % columns * columnWidth; var w = columnWidth - 16; var h = Math.Max(180, 64 + cards.Length * 92); rowHeight = Math.Max(rowHeight, h);
            b.Rect(new(x, rowTop, w, h), C.SurfaceAlt, C.None, opacity: .5); b.Rect(new(x, rowTop, w, 4), C.Series(i), C.None, 2); b.Text($"{root.Label}  {cards.Length}", new(x + 12, rowTop + 12, w - 24, 28), align: TextAlignment.Leading, bold: true);
            for (var j = 0; j < cards.Length; j++) b.Box(cards[j].Label, new(x + 12, rowTop + 58 + j * 92, w - 24, 76), C.Background, id: $"card-{cards[j].Id}", size: 14);
            height = Math.Max(height, rowTop + h + 16);
        }
        return b.Build(width, height);
    }
}
