using System.Collections.Immutable;
using System.Text.RegularExpressions;

namespace NornaKit;

internal sealed class BlockLaneDiagrams(TextMeasurement text)
{
    public DiagramScene Agent(string source, DiagramLayoutOptions options)
    {
        var lines = Regex.Split(source, "\r\n|\r|\n"); var first = Array.FindIndex(lines, line => line.Trim().Length > 0 && !line.TrimStart().StartsWith("%%", StringComparison.Ordinal)); if (first < 0) throw new DiagramRenderException("缺少图表声明。", "syntax");
        var parts = lines[first].Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries); lines[first] = "flowchart " + (parts.Length > 1 ? parts[1] : "TD"); var model = MermaidFlowchartParser.Parse(string.Join('\n', lines)); var scene = Adaptive(model, options); return FlowScenePainter.Prepare(scene, text, DiagramKind.Agentflow);
    }
    private DiagramScene Adaptive(FlowchartModel model, DiagramLayoutOptions options)
    {
        var engine = new LayeredLayoutEngine(text); var scene = engine.Layout(model, options);
        if (options.MaxWidth is { } width && options.AutoDirection && options.Compact && model.Direction.Horizontal() && scene.Size.Width > width) { var candidate = engine.Layout(model with { Direction = FlowDirection.TopDown }, options); if (candidate.Size.Width < scene.Size.Width) return candidate; }
        return scene;
    }
    public DiagramScene Block(string source)
    {
        var blocks = new List<(FlowNode? Node, int Span)>(); var edges = new List<FlowEdge>(); int? columns = null;
        const string tokenPattern = @"(?:\w+(?:\[\[.*?\]\]|\[\(.*?\)\]|\(\[.*?\]\)|\(\(.*?\)\)|\[.*?\]|\(.*?\)|\{.*?\})?)(?::\d+)?";
        var regex = new Regex(tokenPattern, RegexOptions.CultureInvariant, TimeSpan.FromSeconds(2));
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (DiagramSyntax.Match(@"^columns\s+(\d+)$", s) is { } col && int.TryParse(col[1], out var value) && value is >= 1 and <= 50) { columns = value; continue; }
            if (s.StartsWith("columns", StringComparison.Ordinal)) throw line.Error("列数需要是 1 到 50 的整数。", "semantic");
            if (s.Contains("-->", StringComparison.Ordinal) || s.Contains("---", StringComparison.Ordinal) || s.Contains("-.->", StringComparison.Ordinal)) { var graph = MermaidFlowchartParser.Parse("flowchart LR\n" + s); edges.AddRange(graph.Edges); foreach (var node in graph.Nodes) if (blocks.All(block => block.Node?.Id != node.Id)) blocks.Add((node, 1)); continue; }
            var matches = regex.Matches(s); if (matches.Count == 0 || regex.Replace(s, "").Trim().Length > 0) throw line.Error("块图暂不支持嵌套块或这条布局指令。");
            foreach (Match match in matches)
            {
                var token = match.Value; var span = 1; if (DiagramSyntax.Match(@"^(.*):(\d+)$", token) is { } sp && int.TryParse(sp[2], out var length) && length is > 0 and <= 50) { token = sp[1]; span = length; }
                if (token == "space") { blocks.Add((null, span)); continue; } var node = MermaidFlowchartParser.Parse("flowchart LR\n" + token).Nodes[0]; if (blocks.Any(block => block.Node?.Id == node.Id)) throw line.Error("块标识符重复。", "semantic"); blocks.Add((node, span));
            }
        }
        DiagramSyntax.Nonempty(blocks.Count, DiagramKind.Block); var count = columns ?? blocks.Sum(block => block.Span); var row = 0; var column = 0; var placed = new List<SceneNode>();
        foreach (var block in blocks)
        { if (block.Span > count) throw new DiagramRenderException("块跨度超过列数。", "semantic"); if (column + block.Span > count) { row++; column = 0; } if (block.Node is { } node) { var r = new DiagramRect(16 + column * 172, 16 + row * 104, block.Span * 148 + (block.Span - 1) * 24, 80); placed.Add(new(node.Id, node.Label, node.Shape, r, text.Lines(node.Label, r.Width - 24))); } column += block.Span; }
        var frames = placed.ToDictionary(node => node.Id, node => node.Frame); var connections = edges.Select(edge =>
        { if (!frames.TryGetValue(edge.From, out var a) || !frames.TryGetValue(edge.To, out var z)) throw new DiagramRenderException("块图连线引用未知节点。", "semantic"); if (edge.From == edge.To) return edge; var sides = a.Bottom <= z.Top ? (2, 0) : z.Bottom <= a.Top ? (0, 2) : a.Right <= z.Left ? (1, 3) : (3, 1); return edge with { SourceSide = sides.Item1, TargetSide = sides.Item2 }; }).ToImmutableArray();
        var model = new FlowchartModel(FlowDirection.TopDown, blocks.Where(block => block.Node is not null).Select(block => block.Node!).ToImmutableArray(), connections, []);
        var routed = new CompoundEdgeRouter(text).Route(model, new(new(count * 172 + 8, (row + 1) * 104 + 8), "block", []) { Nodes = placed.ToImmutableArray() }, separateConnections: true, projectSpanningPorts: true);
        return Paint(routed, DiagramKind.Block);
    }
    public DiagramScene Swimlane(string source, DiagramLayoutOptions options)
    {
        var lines = Regex.Split(source, "\r\n|\r|\n"); var first = Array.FindIndex(lines, line => line.TrimStart().StartsWith("swimlane-beta", StringComparison.Ordinal)); if (first < 0) throw new DiagramRenderException("缺少泳道声明。", "syntax");
        lines[first] = lines[first].Replace("swimlane-beta", "flowchart", StringComparison.Ordinal); if (lines[first].Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length == 1) lines[first] += " LR";
        var model = MermaidFlowchartParser.Parse(string.Join('\n', lines)); if (model.Groups.IsEmpty || model.Groups.Any(group => group.ParentId is not null) || model.Direction is not (FlowDirection.LeftRight or FlowDirection.TopDown)) throw new DiagramRenderException("泳道图当前支持顶级分组和 LR、TD 方向。", "unsupported-syntax");
        var nodeIds = model.Nodes.Select(node => node.Id).ToHashSet(); if (model.Edges.Any(edge => !nodeIds.Contains(edge.From) || !nodeIds.Contains(edge.To))) throw new DiagramRenderException("泳道连线当前需要连接具体节点。", "unsupported-syntax");
        if (model.Direction == FlowDirection.LeftRight && options.Compact && options.AutoDirection)
        { var horizontalScene = Swimlane(source, options with { AutoDirection = false }); if (horizontalScene.Size.Width <= options.MaxWidth) return horizontalScene; lines[first] = "swimlane-beta TD"; var vertical = Swimlane(string.Join('\n', lines), options with { AutoDirection = false }); return vertical.Size.Width < horizontalScene.Size.Width ? vertical : horizontalScene; }
        var flat = new LayeredLayoutEngine(text).Flat(model with { Groups = [] }, options); var horizontal = model.Direction == FlowDirection.LeftRight; var lanes = model.Groups.ToList(); if (model.Nodes.Any(node => node.ParentId is null)) lanes.Add(new("@unassigned", "未分组", Sequence: lanes.Count));
        var extent = horizontal ? flat.Size.Width + 174 : flat.Size.Height + 80; var placedNodes = new List<SceneNode>(); var placedGroups = new List<SceneGroup>(); double bandOffset = 16;
        foreach (var lane in lanes)
        {
            var ids = model.Nodes.Where(node => (node.ParentId ?? "@unassigned") == lane.Id).Select(node => node.Id).ToHashSet(); var columns = flat.Nodes.Where(node => ids.Contains(node.Id)).GroupBy(node => horizontal ? node.Frame.Center.X : node.Frame.Center.Y).ToDictionary(group => group.Key, group => group.ToArray()); var spacing = options.Compact ? 28 : 40;
            Func<SceneNode[], double> stackSize = column => column.Sum(node => horizontal ? node.Frame.Height : node.Frame.Width) + Math.Max(0, column.Length - 1) * spacing;
            var band = Math.Max(200, columns.Values.Select(stackSize).DefaultIfEmpty(0).Max() + 80); var rect = horizontal ? new DiagramRect(16, bandOffset, extent, band) : new(bandOffset, 16, band, extent); var title = horizontal ? new DiagramRect(24, bandOffset + 8, 126, band - 16) : new(bandOffset + 8, 24, band - 16, 36);
            placedGroups.Add(new(lane.Id, lane.Label, null, rect, title, text.Lines(lane.Label, 110), 0));
            foreach (var key in columns.Keys.Order()) { var columnNodes = columns[key].OrderBy(node => horizontal ? node.Frame.Center.Y : node.Frame.Center.X).ToArray(); var cross = bandOffset + (band - stackSize(columnNodes)) / 2; foreach (var node in columnNodes) { var r = horizontal ? node.Frame with { X = node.Frame.X + 166, Y = cross } : node.Frame with { X = cross, Y = node.Frame.Y + 70 }; cross += (horizontal ? r.Height : r.Width) + spacing; placedNodes.Add(node with { Frame = r }); } }
            bandOffset += band + 12;
        }
        var width = horizontal ? extent + 32 : bandOffset + 16; var height = horizontal ? bandOffset + 16 : extent + 32; var members = model.Nodes.Select(node => node with { ParentId = node.ParentId ?? "@unassigned" }).ToImmutableArray(); var parents = members.ToDictionary(node => node.Id, node => node.ParentId); var frames = placedNodes.ToDictionary(node => node.Id, node => node.Frame);
        var edges = model.Edges.Select(edge =>
        { if (edge.From == edge.To) return edge; var a = frames[edge.From]; var b = frames[edge.To]; int side, target;
            if (parents[edge.From] == parents[edge.To]) { var forward = horizontal ? b.Center.X > a.Center.X : b.Center.Y > a.Center.Y; side = forward ? horizontal ? 1 : 2 : horizontal ? 2 : 1; target = forward ? horizontal ? 3 : 0 : side; }
            else { var positive = horizontal ? b.Center.Y > a.Center.Y : b.Center.X > a.Center.X; side = horizontal ? positive ? 2 : 0 : positive ? 1 : 3; target = (side + 2) % 4; }
            return edge with { SourceSide = side, TargetSide = target };
        }).ToImmutableArray();
        var routed = new CompoundEdgeRouter(text).Route(model with { Nodes = members, Edges = edges, Groups = lanes.ToImmutableArray() }, new(new(width, height), "swimlane", []) { Nodes = placedNodes.ToImmutableArray(), Groups = placedGroups.ToImmutableArray() }, allowCrossingGroups: true);
        return Paint(routed, DiagramKind.Swimlane);
    }
    private DiagramScene Paint(DiagramScene routed, DiagramKind kind)
    {
        var b = new SceneBuilder(kind, text);
        for (var i = 0; i < routed.Groups.Length; i++) { var lane = routed.Groups[i]; b.Rect(lane.Frame, C.SurfaceAlt, opacity: .4); b.Rect(lane.TitleFrame, C.Series(i), C.None, opacity: .12); b.Text(lane.Label, lane.TitleFrame.Inset(6, 6), 14, bold: true); }
        for (var i = 0; i < routed.Edges.Length; i++) { var edge = routed.Edges[i]; b.Line(edge.Points, dash: edge.Style == EdgeStyle.Dashed ? [4, 4] : [], arrow: edge.Arrow, id: $"{kind.Id()}-edge-{i}"); if (edge.Label.Length > 0) { b.Rect(edge.LabelFrame, C.Background, C.None, 3, id: $"edge-label-{kind.Id()}-edge-{i}"); b.Text(edge.Label, edge.LabelFrame, 12); } }
        foreach (var node in routed.Nodes) { b.Path(ScenePaths.Node(node), C.Surface, C.Border, id: node.Id); b.Text(node.Label, node.Frame.Inset(kind == DiagramKind.Block ? 12 : 8, kind == DiagramKind.Block ? 10 : 6), kind == DiagramKind.Block ? 14 : 16); }
        return b.Build(routed.Size.Width, routed.Size.Height);
    }
}
