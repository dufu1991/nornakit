using System.Collections.Immutable;

namespace NornaKit;

internal sealed class LayeredLayoutEngine(TextMeasurement text)
{
    private readonly EdgeLabelLayout labels = new(text);
    public DiagramScene Layout(FlowchartModel graph, DiagramLayoutOptions options)
        => graph.Groups.IsEmpty ? Flat(graph, options) : new CompoundLayoutEngine(this, text).Layout(graph, options);

    public DiagramScene Flat(FlowchartModel graph, DiagramLayoutOptions options, Dictionary<string, DiagramSize>? imposedSizes = null, double padding = 8)
    {
        imposedSizes ??= [];
        if (graph.Edges.Any(edge => edge.MinimumRankSpan is < 1 or > 10)) throw new DiagramRenderException("连线跨度必须介于 1 到 10 层之间。", "limit");
        if (graph.Nodes.IsEmpty) return new(new(), "flowchart", []);
        var horizontal = graph.Direction.Horizontal();
        var lines = graph.Nodes.Select(node => text.Lines(node.Label, options.LabelWidth)).ToArray();
        var measured = graph.Nodes.Select(node => imposedSizes.TryGetValue(node.Id, out var size) ? size : text.NodeSize(node.Label, options.LabelWidth, node.Shape)).ToArray();
        var sizes = measured.Select(size => horizontal ? new DiagramSize(size.Height, size.Width) : size).ToList();
        var lookup = graph.Nodes.Select((node, index) => (node.Id, index)).ToDictionary(pair => pair.Id, pair => pair.index);
        var n = graph.Nodes.Length;
        var outgoing = Enumerable.Range(0, n).Select(_ => new List<int>()).ToArray();
        for (var i = 0; i < graph.Edges.Length; i++) outgoing[lookup[graph.Edges[i].From]].Add(i);
        var state = new int[n]; var feedback = new HashSet<int>();
        Action<int> visit = null!;
        visit = node =>
        {
            state[node] = 1;
            foreach (var i in outgoing[node])
            { var target = lookup[graph.Edges[i].To]; if (state[target] == 1) feedback.Add(i); else if (state[target] == 0) visit(target); }
            state[node] = 2;
        };
        for (var i = 0; i < n; i++) if (state[i] == 0) visit(i);
        var degrees = new int[n]; var ranks = Enumerable.Repeat(0, n).ToList();
        for (var i = 0; i < graph.Edges.Length; i++) if (!feedback.Contains(i)) degrees[lookup[graph.Edges[i].To]]++;
        var queue = new Queue<int>(Enumerable.Range(0, n).Where(i => degrees[i] == 0));
        while (queue.TryDequeue(out var node)) foreach (var i in outgoing[node].Where(i => !feedback.Contains(i)))
        { var target = lookup[graph.Edges[i].To]; ranks[target] = Math.Max(ranks[target], ranks[node] + graph.Edges[i].MinimumRankSpan); if (--degrees[target] == 0) queue.Enqueue(target); }
        var chains = new List<List<int>>();
        for (var i = 0; i < graph.Edges.Length; i++)
        {
            var from = lookup[graph.Edges[i].From]; var to = lookup[graph.Edges[i].To]; var chain = new List<int> { from };
            if (!feedback.Contains(i)) for (var rank = ranks[from] + 1; rank < ranks[to]; rank++)
            {
                if (sizes.Count >= 5_000) throw new DiagramRenderException("图表的跨层连线过于复杂，请减少节点或连线。", "limit");
                chain.Add(sizes.Count); sizes.Add(new(36, 0)); ranks.Add(rank);
            }
            chain.Add(to); chains.Add(chain);
        }
        var layers = Enumerable.Range(0, ranks.Max() + 1).Select(rank => Enumerable.Range(0, sizes.Count).Where(i => ranks[i] == rank).ToList()).ToArray();
        var previous = sizes.Select(_ => new List<int>()).ToArray(); var next = sizes.Select(_ => new List<int>()).ToArray();
        for (var i = 0; i < chains.Count; i++) if (!feedback.Contains(i)) for (var j = 1; j < chains[i].Count; j++)
        { var a = chains[i][j - 1]; var b = chains[i][j]; next[a].Add(b); previous[b].Add(a); }
        for (var sweep = 0; sweep < 8; sweep++)
        {
            var order = sweep % 2 == 0 ? Enumerable.Range(1, layers.Length - 1) : Enumerable.Range(0, layers.Length - 1).Reverse();
            foreach (var layer in order)
            {
                var positions = layers.SelectMany(row => row.Select((vertex, position) => (vertex, position))).ToDictionary(pair => pair.vertex, pair => (double)pair.position);
                var neighbours = sweep % 2 == 0 ? previous : next;
                var score = (int vertex) => neighbours[vertex].Count == 0 ? positions[vertex] : neighbours[vertex].Average(item => positions[item]);
                layers[layer] = layers[layer].OrderBy(score).ThenBy(vertex => positions[vertex]).ToList();
            }
        }
        var gap = options.Compact ? 28 : 40;
        var layerWidths = layers.Select(row => row.Sum(vertex => sizes[vertex].Width) + Math.Max(0, row.Count - 1) * gap).ToArray();
        var totalWidth = layerWidths.Max(); var frames = new DiagramRect[sizes.Count]; double y = 0;
        for (var layer = 0; layer < layers.Length; layer++)
        {
            var row = layers[layer]; var height = row.Select(vertex => sizes[vertex].Height).DefaultIfEmpty(0).Max(); var x = (totalWidth - layerWidths[layer]) / 2;
            foreach (var vertex in row) { frames[vertex] = new(x, y + (height - sizes[vertex].Height) / 2, sizes[vertex].Width, sizes[vertex].Height); x += sizes[vertex].Width + gap; }
            var room = graph.Edges.Where(edge => ranks[lookup[edge.From]] == layer && edge.Label.Length > 0)
                .Select(edge => horizontal ? labels.Size(labels.Lines(edge.Label)).Width - 4 + 64 : labels.Lines(edge.Label).Length * 18 + 64).DefaultIfEmpty(0).Max();
            y += height + Math.Max(48, room);
        }
        var parents = Enumerable.Range(0, frames.Length).ToArray();
        Func<int, int> root = vertex => { var value = vertex; while (parents[value] != value) value = parents[value]; while (parents[vertex] != vertex) { var p = parents[vertex]; parents[vertex] = value; vertex = p; } return value; };
        for (var vertex = 0; vertex < frames.Length; vertex++) if (next[vertex].Count == 1)
        {
            var target = next[vertex][0];
            if (previous[target].Count != 1 || vertex < n && imposedSizes.ContainsKey(graph.Nodes[vertex].Id) || target < n && imposedSizes.ContainsKey(graph.Nodes[target].Id)) continue;
            var a = root(vertex); var b = root(target); parents[Math.Max(a, b)] = Math.Min(a, b);
        }
        var members = Enumerable.Range(0, frames.Length).GroupBy(root).ToDictionary(group => group.Key, group => group.ToArray());
        for (var sweep = 0; sweep < 4; sweep++) foreach (var key in sweep % 2 == 0 ? members.Keys.Order() : members.Keys.OrderDescending())
        {
            var chain = members[key]; if (chain.Length < 2) continue;
            double lower = double.NegativeInfinity, upper = double.PositiveInfinity;
            foreach (var vertex in chain)
            {
                var row = layers[ranks[vertex]]; var position = row.IndexOf(vertex); var half = frames[vertex].Width / 2;
                lower = Math.Max(lower, (position == 0 ? 0 : frames[row[position - 1]].Right + gap) + half);
                upper = Math.Min(upper, (position == row.Count - 1 ? totalWidth : frames[row[position + 1]].Left - gap) - half);
            }
            if (lower > upper + .001) continue;
            var center = Math.Max(lower, Math.Min(upper, chain.Average(vertex => frames[vertex].Center.X)));
            foreach (var vertex in chain) frames[vertex] = frames[vertex] with { X = center - frames[vertex].Width / 2 };
        }
        var roots = members.Keys.Order().ToArray(); var constraints = roots.ToDictionary(key => key, _ => new Dictionary<int, double>()); var indegrees = roots.ToDictionary(key => key, _ => 0);
        foreach (var row in layers) for (var i = 1; i < row.Count; i++)
        {
            var a = root(row[i - 1]); var b = root(row[i]); if (a == b) continue;
            if (!constraints[a].ContainsKey(b)) indegrees[b]++;
            constraints[a][b] = Math.Max(constraints[a].GetValueOrDefault(b), (frames[row[i - 1]].Width + frames[row[i]].Width) / 2 + gap);
        }
        var topological = roots.Where(key => indegrees[key] == 0).ToList();
        for (var head = 0; head < topological.Count; head++) foreach (var target in constraints[topological[head]].Keys.Order()) if (--indegrees[target] == 0) topological.Add(target);
        if (topological.Count == roots.Length)
        {
            var centers = roots.ToDictionary(key => key, key => members[key].Average(vertex => frames[vertex].Center.X));
            foreach (var key in topological) foreach (var (target, distance) in constraints[key]) centers[target] = Math.Max(centers[target], centers[key] + distance);
            foreach (var key in roots) foreach (var vertex in members[key]) frames[vertex] = frames[vertex] with { X = centers[key] - frames[vertex].Width / 2 };
            totalWidth = Math.Max(totalWidth, frames.Max(frame => frame.Right));
        }
        var totalHeight = frames.Max(frame => frame.Bottom);
        Func<int, int, double, DiagramPoint> anchor = (vertex, side, offset) =>
        {
            var frame = frames[vertex]; var shape = imposedSizes.ContainsKey(graph.Nodes[vertex].Id) ? NodeShape.Rectangle : graph.Nodes[vertex].Shape;
            if (!horizontal) return NodeGeometry.Anchor(shape, frame, side, offset);
            var point = NodeGeometry.Anchor(shape, new(frame.Y, frame.X, frame.Height, frame.Width), new[] { 3, 2, 1, 0 }[side], offset); return new(point.Y, point.X);
        };
        Func<int, int, bool, DiagramPoint> port = (vertex, index, leaving) =>
        {
            var relevant = Enumerable.Range(0, graph.Edges.Length).Where(i => !feedback.Contains(i) && lookup[leaving ? graph.Edges[i].From : graph.Edges[i].To] == vertex)
                .OrderBy(i => frames[lookup[leaving ? graph.Edges[i].To : graph.Edges[i].From]].Center.X).ThenBy(i => i).ToList();
            var step = Math.Min(16, frames[vertex].Width / 2 / Math.Max(1, relevant.Count - 1));
            return anchor(vertex, leaving ? 2 : 0, (relevant.IndexOf(index) - (relevant.Count - 1) / 2d) * step);
        };
        for (var i = 0; i < graph.Edges.Length; i++) if (!feedback.Contains(i))
        {
            var edge = graph.Edges[i]; var from = lookup[edge.From]; var to = lookup[edge.To];
            if (outgoing[from].Count <= 1 || previous[to].Count != 1 || outgoing[to].Count != 1 || ranks[to] != ranks[from] + 1 || imposedSizes.ContainsKey(edge.From) || imposedSizes.ContainsKey(edge.To)) continue;
            var dx = port(from, i, true).X - frames[to].Center.X; if (Math.Abs(dx) <= .01 || Math.Abs(dx) > Math.Max(20, gap)) continue;
            var chain = members[root(to)]; var ids = chain.ToHashSet();
            if (chain.Any(vertex => frames.Where((_, index) => !ids.Contains(index)).Any(frame => frame.Inset(-8, -8).Intersects(frames[vertex].Offset(dx, 0))))) continue;
            foreach (var vertex in chain) frames[vertex] = frames[vertex].Offset(dx, 0);
        }
        totalWidth = Math.Max(totalWidth, frames.Max(frame => frame.Right));
        var starts = layers.Select(row => row.Select(vertex => frames[vertex].Top).DefaultIfEmpty(0).Min()).ToArray();
        var ends = layers.Select(row => row.Select(vertex => frames[vertex].Bottom).DefaultIfEmpty(0).Max()).ToArray();
        var forwardRoutes = new Dictionary<int, ImmutableArray<DiagramPoint>>();
        for (var i = 0; i < graph.Edges.Length; i++) if (!feedback.Contains(i))
        {
            var points = new List<DiagramPoint>(); var chain = chains[i];
            for (var j = 1; j < chain.Count; j++)
            {
                var a = chain[j - 1]; var b = chain[j];
                var start = a < n ? port(a, i, true) : new(frames[a].Center.X, frames[a].Bottom);
                var end = b < n ? port(b, i, false) : new(frames[b].Center.X, frames[b].Top);
                var middle = (ends[ranks[a]] + starts[ranks[b]]) / 2;
                if (j == 1) points.Add(start);
                if (Math.Abs(start.X - end.X) >= .001) { points.Add(new(start.X, middle)); points.Add(new(end.X, middle)); }
                points.Add(end);
            }
            forwardRoutes.Add(i, EdgeGeometry.Simplify(points));
        }
        var routed = new List<SceneEdge>(); var feedbackRoutes = new List<ImmutableArray<DiagramPoint>>(); var lane = totalWidth; double previousExtent = 0;
        for (var i = 0; i < graph.Edges.Length; i++)
        {
            var edge = graph.Edges[i]; var from = lookup[edge.From]; var to = lookup[edge.To]; var a = frames[from]; var b = frames[to];
            var labelLines = labels.Lines(edge.Label); var size = labels.Size(labelLines); ImmutableArray<DiagramPoint> points;
            if (feedback.Contains(i))
            {
                var extent = edge.Label.Length == 0 ? 0 : horizontal ? size.Height : size.Width;
                lane += Math.Max(48, (previousExtent + extent) / 2 + 12); previousExtent = extent;
                var peers = Enumerable.Range(0, graph.Edges.Length).Where(index => feedback.Contains(index) && graph.Edges[index].To == edge.To).ToList();
                var spread = (peers.IndexOf(i) - (peers.Count - 1) / 2d) * Math.Min(16, b.Height * .6 / Math.Max(1, peers.Count - 1));
                var end = anchor(to, 1, spread); var entry = new DiagramPoint(lane, end.Y);
                var obstacles = Enumerable.Range(0, n).Where(vertex => vertex != to).Select(vertex => frames[vertex].Inset(-8, -8)).ToArray();
                if (from == to)
                {
                    var loops = Enumerable.Range(0, graph.Edges.Length).Where(index => graph.Edges[index].From == edge.From && graph.Edges[index].To == edge.From).ToList();
                    points = SelfLoop(a, loops.IndexOf(i), loops.Count, (side, offset) => anchor(from, side, offset), obstacles, forwardRoutes.Values.Concat(feedbackRoutes).ToArray());
                }
                else if (EdgeGeometry.Clear(entry, end, obstacles))
                { var start = anchor(from, 2, 0); points = [start, new(start.X, a.Bottom + 28), new(lane, a.Bottom + 28), entry, end]; }
                else { var start = anchor(from, 2, 0); end = anchor(to, 0, 0); points = [start, new(start.X, a.Bottom + 28), new(lane, a.Bottom + 28), new(lane, b.Top - 28), new(end.X, b.Top - 28), end]; }
                feedbackRoutes.Add(points);
            }
            else points = forwardRoutes[i];
            points = EdgeGeometry.Simplify(points);
            var segment = points.Zip(points.Skip(1)).MaxBy(pair => pair.First.DistanceTo(pair.Second));
            var center = new DiagramPoint((segment.First.X + segment.Second.X) / 2, (segment.First.Y + segment.Second.Y) / 2);
            routed.Add(new(edge.From, edge.To, points, edge.Label, new(center.X - size.Width / 2, center.Y - size.Height / 2, size.Width, size.Height), edge.Style, edge.Arrow, edge.StartMarker, edge.EndMarker));
        }
        Func<DiagramPoint, DiagramPoint> transform = point => graph.Direction switch
        { FlowDirection.BottomUp => new(point.X, totalHeight - point.Y), FlowDirection.LeftRight => new(point.Y, point.X), FlowDirection.RightLeft => new(totalHeight - point.Y, point.X), _ => point };
        Func<DiagramRect, DiagramRect> transformFrame = frame => { var a = transform(new(frame.Left, frame.Top)); var b = transform(new(frame.Right, frame.Bottom)); return new(Math.Min(a.X, b.X), Math.Min(a.Y, b.Y), Math.Abs(b.X - a.X), Math.Abs(b.Y - a.Y)); };
        var nodes = graph.Nodes.Select((node, i) => new SceneNode(node.Id, node.Label, node.Shape, transformFrame(frames[i]), lines[i])).ToArray();
        for (var i = 0; i < routed.Count; i++)
        { var edge = routed[i]; var center = transform(edge.LabelFrame.Center); routed[i] = edge with { Points = edge.Points.Select(transform).ToImmutableArray(), LabelFrame = edge.LabelFrame with { X = center.X - edge.LabelFrame.Width / 2, Y = center.Y - edge.LabelFrame.Height / 2 } }; }
        var labelObstacles = nodes.Select(node => node.Frame.Inset(-4, -4)).ToList(); var paths = routed.Where(edge => edge.Style != EdgeStyle.Invisible).Select(edge => edge.Points).ToArray();
        for (var i = 0; i < routed.Count; i++) if (routed[i].Label.Length > 0 && routed[i].Style != EdgeStyle.Invisible)
        { var edge = routed[i]; var frame = labels.Frame(new(edge.LabelFrame.Width, edge.LabelFrame.Height), edge.Points, labelObstacles, paths); routed[i] = edge with { LabelFrame = frame }; labelObstacles.Add(frame.Inset(-4, -4)); }
        return Normalize(new(new(), "flowchart", []) { Nodes = nodes.ToImmutableArray(), Edges = routed.ToImmutableArray() }, padding);
    }

    internal static DiagramScene Normalize(DiagramScene scene, double padding = 8)
    {
        var rects = scene.Nodes.Select(node => node.Frame).Concat(scene.Groups.Select(group => group.Frame))
            .Concat(scene.Edges.SelectMany(edge => edge.Points.Select(point => new DiagramRect(point.X, point.Y, 1, 1))))
            .Concat(scene.Edges.Where(edge => edge.Label.Length > 0).Select(edge => edge.LabelFrame)).ToArray();
        if (rects.Length == 0) return scene;
        var bounds = rects.Aggregate((a, b) => a.Union(b)); var dx = padding - bounds.Left; var dy = padding - bounds.Top;
        return scene with { Size = new(bounds.Width + padding * 2, bounds.Height + padding * 2),
            Nodes = scene.Nodes.Select(node => node with { Frame = node.Frame.Offset(dx, dy) }).ToImmutableArray(),
            Groups = scene.Groups.Select(group => group with { Frame = group.Frame.Offset(dx, dy), TitleFrame = group.TitleFrame.Offset(dx, dy) }).ToImmutableArray(),
            Edges = scene.Edges.Select(edge => edge with { Points = edge.Points.Select(point => point.Offset(dx, dy)).ToImmutableArray(), LabelFrame = edge.LabelFrame.Offset(dx, dy) }).ToImmutableArray() };
    }

    internal static ImmutableArray<DiagramPoint> SelfLoop(DiagramRect frame, int position, int count, Func<int, double, DiagramPoint> anchor,
        IReadOnlyList<DiagramRect> obstacles, IReadOnlyList<ImmutableArray<DiagramPoint>> routes, DiagramRect? domain = null)
    {
        var channels = routes.SelectMany(route => route.Zip(route.Skip(1)).Select(pair => new DiagramRect(Math.Min(pair.First.X, pair.Second.X), Math.Min(pair.First.Y, pair.Second.Y), Math.Abs(pair.First.X - pair.Second.X), Math.Abs(pair.First.Y - pair.Second.Y)).Inset(-6, -6))).ToArray();
        ImmutableArray<DiagramPoint> best = []; var bestScore = double.PositiveInfinity;
        foreach (var side in new[] { 3, 1, 2, 0 })
        {
            var vertical = side % 2 == 0; var spread = Math.Min(12, (vertical ? frame.Width : frame.Height) / (2 * count + 2)) * (position + 1);
            var start = anchor(side, spread); var end = anchor(side, -spread);
            foreach (var clearance in new[] { 28, 44, 64, 88 })
            {
                var distance = clearance + position * 16; var lane = side switch { 3 => frame.Left - distance, 1 => frame.Right + distance, 0 => frame.Top - distance, _ => frame.Bottom + distance };
                ImmutableArray<DiagramPoint> points = [start, vertical ? new(start.X, lane) : new(lane, start.Y), vertical ? new(end.X, lane) : new(lane, end.Y), end];
                if (domain is { } bounds && points.Any(point => !bounds.Contains(point))) continue;
                var segments = points.Zip(points.Skip(1)).ToArray(); var blocked = segments.Count(pair => !EdgeGeometry.Clear(pair.First, pair.Second, obstacles));
                var crowded = segments.Sum(pair => channels.Count(channel => !EdgeGeometry.Clear(pair.First, pair.Second, [channel])));
                if (blocked == 0 && crowded == 0) return points;
                var score = blocked * 100_000 + crowded * 10_000 + distance; if (score < bestScore) { best = points; bestScore = score; }
            }
        }
        return best;
    }
}
