using System.Collections.Immutable;

namespace NornaKit;

internal sealed class CompoundEdgeRouter(TextMeasurement text)
{
    private const double GroupEdgeClearance = 16;
    private sealed record Port(DiagramPoint Anchor, DiagramPoint Stub, double Penalty, int Side);
    private readonly EdgeLabelLayout labels = new(text);
    public DiagramScene Route(FlowchartModel graph, DiagramScene scene, IReadOnlyList<DiagramRect>? additionalObstacles = null,
        bool separateConnections = false, bool allowCrossingGroups = false, bool projectSpanningPorts = false, bool avoidGroupBorders = false)
    {
        additionalObstacles ??= [];
        var nodes = scene.Nodes.ToDictionary(node => node.Id); var groups = scene.Groups.ToDictionary(group => group.Id);
        var modelGroups = graph.Groups.ToDictionary(group => group.Id); var modelNodes = graph.Nodes.ToDictionary(node => node.Id);
        Func<string, string?> parent = id => modelGroups.TryGetValue(id, out var group) ? group.ParentId : modelNodes[id].ParentId;
        Func<string, List<string>> ancestors = id => { var result = new List<string>(); var current = parent(id); while (current is not null) { result.Add(current); current = parent(current); } return result; };
        Func<string, DiagramRect> frame = id => nodes.TryGetValue(id, out var node) ? node.Frame : groups[id].Frame;
        Func<string, FlowDirection> direction = id => { var current = parent(id); while (current is not null) { if (modelGroups[current].Direction is { } local) return local; current = parent(current); } return graph.Direction; };
        Func<FlowEdge, bool, bool> longitudinal = (edge, backward) =>
        { var a = frame(edge.From); var b = frame(edge.To); return direction(edge.From) switch { FlowDirection.TopDown => backward ? a.Top > b.Bottom : a.Bottom < b.Top, FlowDirection.BottomUp => backward ? a.Bottom < b.Top : a.Top > b.Bottom, FlowDirection.LeftRight => backward ? a.Left > b.Right : a.Right < b.Left, _ => backward ? a.Right < b.Left : a.Left > b.Right }; };
        var routingEdges = graph.Edges.Select(edge => edge.From != edge.To && edge.SourceSide is null && edge.TargetSide is null && parent(edge.From) == parent(edge.To) && longitudinal(edge, true)
            ? edge with { SourceSide = direction(edge.From).Horizontal() ? 2 : 1, TargetSide = direction(edge.From).Horizontal() ? 2 : 1 } : edge).ToArray();
        var reservedPorts = new Dictionary<int, ImmutableArray<DiagramPoint>[]>();
        if (avoidGroupBorders)
            for (var index = 0; index < graph.Edges.Length; index++)
            {
                var edge = graph.Edges[index];
                if (edge.Style == EdgeStyle.Invisible || edge.From == edge.To || parent(edge.From) != parent(edge.To) || !longitudinal(edge, false)) continue;
                reservedPorts[index] = new[] { true, false }.Select(leaving =>
                {
                    var id = leaving ? edge.From : edge.To;
                    return Ports(frame(id), nodes.GetValueOrDefault(id), direction(id), leaving, index, routingEdges, frame, 12, projectSpanningPorts).FirstOrDefault(port => port.Penalty == 0);
                }).OfType<Port>().Select(port => ImmutableArray.Create(port.Anchor, port.Stub)).ToArray();
            }
        var routed = new List<SceneEdge>(); var domains = new List<DiagramRect>();
        for (var i = 0; i < graph.Edges.Length; i++)
        {
            var edge = graph.Edges[i]; var a = frame(edge.From); var b = frame(edge.To); var sourceAncestors = ancestors(edge.From); var targetAncestors = ancestors(edge.To);
            var common = sourceAncestors.FirstOrDefault(targetAncestors.Contains); var containsTarget = targetAncestors.Contains(edge.From); var containsSource = sourceAncestors.Contains(edge.To);
            var enclosure = containsTarget ? groups[edge.From] : containsSource ? groups[edge.To] : common is null ? null : groups[common];
            var allowed = sourceAncestors.Concat(targetAncestors).Concat([edge.From, edge.To]).ToHashSet();
            var borders = avoidGroupBorders ? scene.Groups.Where(group => group.Id != edge.From && group.Id != edge.To).Select(group => group.Frame).ToArray() : [];
            var labelSize = labels.Size(labels.Lines(edge.Label)); var horizontalPort = edge.SourceSide is { } sourceSide ? sourceSide % 2 != 0 : direction(edge.From).Horizontal();
            var clearance = projectSpanningPorts && edge.Label.Length > 0;
            var ox = clearance && !horizontalPort ? Math.Max(8, labelSize.Width / 2 + 6) : 8; var oy = clearance && horizontalPort ? Math.Max(8, labelSize.Height / 2 + 6) : 8;
            var obstacles = scene.Nodes.Select(node => node.Frame.Inset(-ox, -oy))
                .Concat(scene.Groups.Where(group => !allowCrossingGroups && !allowed.Contains(group.Id)).Select(group => group.Frame.Inset(-8, -8)))
                .Concat(scene.Groups.Where(group => group.TitleLines.Any(line => line.Length > 0)).Select(group => group.TitleFrame.Inset(-4, -3))).Concat(additionalObstacles).ToArray();
            var domain = enclosure?.Frame.Inset(3, 3) ?? new DiagramRect(0, 0, scene.Size.Width, scene.Size.Height).Inset(-40, -40);
            var starts = Ports(a, nodes.GetValueOrDefault(edge.From), direction(edge.From), true, i, routingEdges, frame, separateConnections && !projectSpanningPorts ? 24 : 12, projectSpanningPorts);
            var ends = Ports(b, nodes.GetValueOrDefault(edge.To), direction(edge.To), false, i, routingEdges, frame, separateConnections && !projectSpanningPorts ? 24 : 12, projectSpanningPorts);
            if (edge.SourceSide is { } ss) starts = starts.Where(port => port.Side == ss).ToList();
            if (edge.TargetSide is { } ts) ends = ends.Where(port => port.Side == ts).ToList();
            Func<Port, Port> inward = port => port with { Stub = new(port.Anchor.X * 2 - port.Stub.X, port.Anchor.Y * 2 - port.Stub.Y) };
            if (containsTarget) starts = starts.Select(inward).ToList(); if (containsSource) ends = ends.Select(inward).ToList();
            var portObstacles = scene.Nodes.Where(node => node.Id != edge.From && node.Id != edge.To).Select(node => node.Frame.Inset(-5, -5))
                .Concat(scene.Groups.Where(group => !allowCrossingGroups && !allowed.Contains(group.Id)).Select(group => group.Frame))
                .Concat(scene.Groups.Select(group => group.TitleFrame.Inset(-3, -2))).Concat(additionalObstacles).ToArray();
            Func<Port, DiagramRect?, Port> trim = (port, endpoint) =>
            {
                var forbidden = endpoint is { } rect ? portObstacles.Append(rect.Inset(-8, -8)).ToArray() : portObstacles;
                if (domain.Contains(port.Stub) && EdgeGeometry.Clear(port.Anchor, port.Stub, forbidden)) return port;
                var dx = port.Stub.X - port.Anchor.X; var dy = port.Stub.Y - port.Anchor.Y; var length = double.Hypot(dx, dy);
                foreach (var distance in new[] { 12, 8 }.Where(value => value < length))
                { var stub = port.Anchor.Offset(dx / length * distance, dy / length * distance); if (domain.Contains(stub) && EdgeGeometry.Clear(port.Anchor, stub, forbidden)) return port with { Stub = stub }; }
                return port;
            };
            starts = starts.Select(port => trim(port, containsTarget || containsSource || edge.From == edge.To ? null : b)).Where(port => domain.Contains(port.Stub) && EdgeGeometry.Clear(port.Anchor, port.Stub, portObstacles) && ClearOfBorders(port.Anchor, port.Stub, borders)).ToList();
            ends = ends.Select(port => trim(port, containsTarget || containsSource || edge.From == edge.To ? null : a)).Where(port => domain.Contains(port.Stub) && EdgeGeometry.Clear(port.Anchor, port.Stub, portObstacles) && ClearOfBorders(port.Anchor, port.Stub, borders)).ToList();
            if (parent(edge.From) == parent(edge.To) && edge.From != edge.To)
            {
                if (longitudinal(edge, false))
                { if (edge.SourceSide is null && starts.Any(port => port.Penalty == 0)) starts = starts.Where(port => port.Penalty == 0).ToList(); if (edge.TargetSide is null && ends.Any(port => port.Penalty == 0)) ends = ends.Where(port => port.Penalty == 0).ToList(); }
                else if (edge.SourceSide is null && edge.TargetSide is null && graph.Edges.Any(other => other.From == edge.To && other.To == edge.From))
                {
                    var horizontal = direction(edge.From).Horizontal(); var side = horizontal ? 2 : 1; var opposite = labels.Size(labels.Lines(graph.Edges.First(other => other.From == edge.To && other.To == edge.From).Label));
                    var space = Math.Max(32, ((horizontal ? labelSize.Height : labelSize.Width) + (horizontal ? opposite.Height : opposite.Width)) / 2 + 12 - (horizontal ? Math.Min(a.Height, b.Height) : Math.Min(a.Width, b.Width)) / 2);
                    var lane = horizontal ? Math.Max(a.Bottom, b.Bottom) + space : Math.Max(a.Right, b.Right) + space;
                    Func<Port, Port> extend = port => port with { Stub = horizontal ? new(port.Anchor.X, lane) : new(lane, port.Anchor.Y) };
                    var rs = starts.Where(port => port.Side == side).Select(extend).Where(port => domain.Contains(port.Stub) && EdgeGeometry.Clear(port.Anchor, port.Stub, portObstacles) && ClearOfBorders(port.Anchor, port.Stub, borders)).ToList();
                    var re = ends.Where(port => port.Side == side).Select(extend).Where(port => domain.Contains(port.Stub) && EdgeGeometry.Clear(port.Anchor, port.Stub, portObstacles) && ClearOfBorders(port.Anchor, port.Stub, borders)).ToList();
                    if (rs.Count > 0 && re.Count > 0) { starts = rs; ends = re; }
                }
            }
            var fallbackStarts = starts; var fallbackEnds = ends;
            if (separateConnections)
            {
                (int A, int B)? sides = a.Right < b.Left ? (1, 3) : a.Left > b.Right ? (3, 1) : a.Bottom < b.Top ? (2, 0) : a.Top > b.Bottom ? (0, 2) : null;
                if (sides is { } facing)
                { if (edge.SourceSide is null && starts.Any(port => port.Side == facing.A)) starts = starts.Where(port => port.Side == facing.A).ToList(); if (edge.TargetSide is null && ends.Any(port => port.Side == facing.B)) ends = ends.Where(port => port.Side == facing.B).ToList(); }
            }
            ImmutableArray<DiagramPoint>? points = null;
            if (edge.From == edge.To)
            {
                var loops = Enumerable.Range(0, graph.Edges.Length).Where(index => graph.Edges[index].From == edge.From && graph.Edges[index].To == edge.From).ToList();
                var loop = LayeredLayoutEngine.SelfLoop(a, loops.IndexOf(i), loops.Count, (side, offset) => NodeGeometry.Anchor(nodes.GetValueOrDefault(edge.From)?.Shape ?? NodeShape.Rectangle, a, side, offset), portObstacles, routed.Where(value => value.Style != EdgeStyle.Invisible).Select(value => value.Points).ToArray(), domain);
                if (!loop.IsEmpty && loop.Zip(loop.Skip(1)).All(pair => ClearOfBorders(pair.First, pair.Second, borders))) points = loop;
            }
            var reservations = parent(edge.From) == parent(edge.To) ? [] : reservedPorts.Keys.Order().Where(index => index > i).SelectMany(index => reservedPorts[index]).ToArray();
            var siblings = routed.Where(other => other.Style != EdgeStyle.Invisible).Select(other => other.Points).Concat(reservations).ToArray();
            var fan = separateConnections ? FanRoute(i, graph.Edges, starts, ends, frame, obstacles, additionalObstacles, domain) : null;
            if (fan is { } candidate && (EdgeGeometry.SharesSegment(candidate, siblings) || !candidate.Zip(candidate.Skip(1)).All(pair => ClearOfBorders(pair.First, pair.Second, borders)))) fan = null;
            points ??= fan ?? (separateConnections ? null : ForwardRoute(starts, ends, obstacles, borders, domain, siblings));
            points ??= VisibilityRoute(starts, ends, obstacles, borders, a.Union(b).Inset(-80, -80).Intersection(domain), siblings);
            points ??= VisibilityRoute(starts, ends, obstacles, borders, domain, siblings);
            if (separateConnections) points ??= VisibilityRoute(fallbackStarts, fallbackEnds, obstacles, borders, domain, siblings);
            // Explicit architecture ports can require a shared junction channel.
            if (points is null && (edge.SourceSide is not null || edge.TargetSide is not null))
                points = VisibilityRoute(fallbackStarts, fallbackEnds, obstacles, borders, domain, []);
            if (points is null) throw new DiagramRenderException($"无法为 {edge.From} 到 {edge.To} 的连线找到不穿过节点的路径，请增加分组空间或简化连线。", "layout");
            domains.Add(domain); routed.Add(new(edge.From, edge.To, points.Value, edge.Label, new(0, 0, labelSize.Width, labelSize.Height), edge.Style, edge.Arrow, edge.StartMarker, edge.EndMarker));
        }
        var labelObstacles = scene.Nodes.Select(node => node.Frame.Inset(-4, -4)).Concat(scene.Groups.Where(group => group.TitleLines.Any(line => line.Length > 0)).Select(group => group.TitleFrame.Inset(-4, -4))).Concat(additionalObstacles).ToList();
        var paths = routed.Where(edge => edge.Style != EdgeStyle.Invisible).Select(edge => edge.Points).ToArray();
        for (var i = 0; i < routed.Count; i++) if (routed[i].Label.Length > 0 && routed[i].Style != EdgeStyle.Invisible)
        { var edge = routed[i]; var label = labels.Frame(new(edge.LabelFrame.Width, edge.LabelFrame.Height), edge.Points, labelObstacles, paths, domains[i]); routed[i] = edge with { LabelFrame = label }; labelObstacles.Add(label.Inset(-4, -4)); }
        return LayeredLayoutEngine.Normalize(scene with { Edges = routed.ToImmutableArray() });
    }

    private List<Port> Ports(DiagramRect r, SceneNode? node, FlowDirection direction, bool leaving, int edgeIndex,
        IReadOnlyList<FlowEdge> edges, Func<string, DiagramRect> frame, double minimumStub, bool project)
    {
        var preferred = direction switch { FlowDirection.TopDown => leaving ? 2 : 0, FlowDirection.BottomUp => leaving ? 0 : 2, FlowDirection.LeftRight => leaving ? 1 : 3, _ => leaving ? 3 : 1 };
        var edge = edges[edgeIndex]; var id = leaving ? edge.From : edge.To; var result = new List<Port>();
        for (var side = 0; side < 4; side++)
        {
            if ((leaving ? edge.SourceSide : edge.TargetSide) is { } explicitSide && side != explicitSide) continue;
            var vertical = side % 2 == 0;
            var peers = new List<(int Index, bool Leaving)>();
            for (var i = 0; i < edges.Count; i++)
            {
                var candidate = edges[i]; if (candidate.From == candidate.To && i != edgeIndex) continue;
                if (candidate.From == id && (candidate.SourceSide == side || leaving && candidate.SourceSide is null)) peers.Add((i, true));
                if (candidate.To == id && (candidate.TargetSide == side || !leaving && candidate.TargetSide is null)) peers.Add((i, false));
            }
            Func<(int Index, bool Leaving), double> coordinate = peer => { var other = frame(peer.Leaving ? edges[peer.Index].To : edges[peer.Index].From); return vertical ? other.Center.X : other.Center.Y; };
            peers = peers.OrderBy(coordinate).ThenBy(peer => peer.Index).ThenByDescending(peer => peer.Leaving).ToList();
            var position = peers.IndexOf((edgeIndex, leaving)); var count = peers.Count; var half = (vertical ? r.Width : r.Height) / 2;
            var separation = vertical ? 16 : Math.Max(16, peers.Select(peer => edges[peer.Index].Label.Length == 0 ? 16 : labels.Size(labels.Lines(edges[peer.Index].Label)).Height + 10).DefaultIfEmpty(16).Max());
            var spread = (position - (count - 1) / 2d) * Math.Min(separation, half / Math.Max(1, count - 1)); var projected = false;
            if (project && count > 1)
            { var coordinates = peers.Select(coordinate).ToArray(); var center = vertical ? r.Center.X : r.Center.Y; if (coordinates.All(value => Math.Abs(value - center) <= half - 12) && coordinates.Zip(coordinates.Skip(1)).All(pair => pair.Second - pair.First >= 12)) { spread = coordinates[position] - center; projected = true; } }
            var anchor = NodeGeometry.Anchor(node?.Shape ?? NodeShape.Rectangle, r, side, spread); var other = frame(leaving ? edge.To : edge.From);
            var before = vertical ? other.Center.X < r.Center.X : other.Center.Y < r.Center.Y; var lane = Math.Min(3, before ? position : count - position - 1); var distance = minimumStub + (projected ? 0 : lane * 12);
            var stub = side switch { 0 => new DiagramPoint(anchor.X, r.Top - distance), 1 => new(r.Right + distance, anchor.Y), 2 => new(anchor.X, r.Bottom + distance), _ => new(r.Left - distance, anchor.Y) };
            result.Add(new(anchor, stub, side == preferred ? 0 : 28, side));
        }
        return result;
    }
    private static ImmutableArray<DiagramPoint>? ForwardRoute(List<Port> starts, List<Port> ends, DiagramRect[] obstacles, DiagramRect[] borders, DiagramRect domain, ImmutableArray<DiagramPoint>[] routes)
    {
        foreach (var start in starts.Where(port => port.Penalty == 0)) foreach (var end in ends.Where(port => port.Penalty == 0 && port.Side == (start.Side + 2) % 4))
        {
            var vertical = start.Side % 2 == 0; var positive = start.Side is 1 or 2; var first = vertical ? start.Stub.Y : start.Stub.X; var last = vertical ? end.Stub.Y : end.Stub.X;
            if (positive ? first > last : first < last) continue;
            foreach (var offset in new double[] { 0, -12, 12, -24, 24, -36, 36 })
            {
                var middle = (first + last) / 2 + offset;
                if (middle < Math.Min(first, last) || middle > Math.Max(first, last)) continue;
                var a = vertical ? new DiagramPoint(start.Anchor.X, middle) : new(middle, start.Anchor.Y);
                var b = vertical ? new DiagramPoint(end.Anchor.X, middle) : new(middle, end.Anchor.Y);
                DiagramPoint[] corridor = [start.Stub, a, b, end.Stub];
                var points = EdgeGeometry.Simplify([start.Anchor, a, b, end.Anchor]);
                if (corridor.All(domain.Contains) && corridor.Zip(corridor.Skip(1)).All(pair => EdgeGeometry.Clear(pair.First, pair.Second, obstacles))
                    && points.Zip(points.Skip(1)).All(pair => ClearOfBorders(pair.First, pair.Second, borders)) && !EdgeGeometry.SharesSegment(points, routes)) return points;
            }
        }
        return null;
    }
    private static ImmutableArray<DiagramPoint>? FanRoute(int index, ImmutableArray<FlowEdge> edges, List<Port> starts, List<Port> ends,
        Func<string, DiagramRect> frame, DiagramRect[] obstacles, IReadOnlyList<DiagramRect> captions, DiagramRect domain)
    {
        var edge = edges[index]; var source = frame(edge.From);
        foreach (var start in starts)
        {
            var side = start.Side; var vertical = side % 2 == 0; var positive = side is 1 or 2;
            var peers = Enumerable.Range(0, edges.Length).Where(i =>
            { var candidate = edges[i]; var target = frame(candidate.To); return candidate.From == edge.From && (candidate.SourceSide is null || candidate.SourceSide == side) && (side switch { 0 => target.Bottom < source.Top, 1 => target.Left > source.Right, 2 => target.Top > source.Bottom, _ => target.Right < source.Left }); })
                .OrderBy(i => vertical ? frame(edges[i].To).Center.X : frame(edges[i].To).Center.Y).ThenBy(i => i).ToList();
            var position = peers.IndexOf(index); if (peers.Count <= 1 || position < 0) continue;
            var target = frame(edge.To); var before = vertical ? target.Center.X < source.Center.X : target.Center.Y < source.Center.Y; var rank = before ? position : peers.Count - position - 1;
            var envelope = captions.Where(rect => rect.Intersects(source.Inset(-12, -12))).Aggregate(source, (a, b) => a.Union(b));
            var boundary = vertical ? positive ? envelope.Bottom : envelope.Top : positive ? envelope.Right : envelope.Left; var lane = boundary + (positive ? 1 : -1) * (12 + rank * 12);
            foreach (var end in ends.Where(port => port.Side == (side + 2) % 4))
            {
                var first = vertical ? start.Stub.Y : start.Stub.X; var last = vertical ? end.Stub.Y : end.Stub.X;
                if (positive ? lane < first || lane > last : lane > first || lane < last) continue;
                var a = vertical ? new DiagramPoint(start.Anchor.X, lane) : new(lane, start.Anchor.Y); var b = vertical ? new DiagramPoint(end.Anchor.X, lane) : new(lane, end.Anchor.Y);
                DiagramPoint[] corridor = [start.Stub, a, b, end.Stub];
                if (corridor.All(domain.Contains) && corridor.Zip(corridor.Skip(1)).All(pair => EdgeGeometry.Clear(pair.First, pair.Second, obstacles))) return EdgeGeometry.Simplify([start.Anchor, a, b, end.Anchor]);
            }
        }
        return null;
    }
    private static bool ClearOfBorders(DiagramPoint a, DiagramPoint b, DiagramRect[] borders)
    {
        foreach (var rect in borders)
        {
            if (Math.Abs(a.X - b.X) < .01 && Math.Min(Math.Max(a.Y, b.Y), rect.Bottom) - Math.Max(Math.Min(a.Y, b.Y), rect.Top) > .01
                && Math.Min(Math.Abs(a.X - rect.Left), Math.Abs(a.X - rect.Right)) < GroupEdgeClearance - .01) return false;
            if (Math.Abs(a.Y - b.Y) < .01 && Math.Min(Math.Max(a.X, b.X), rect.Right) - Math.Max(Math.Min(a.X, b.X), rect.Left) > .01
                && Math.Min(Math.Abs(a.Y - rect.Top), Math.Abs(a.Y - rect.Bottom)) < GroupEdgeClearance - .01) return false;
        }
        return true;
    }
    private static ImmutableArray<DiagramPoint>? VisibilityRoute(List<Port> starts, List<Port> ends, DiagramRect[] obstacles, DiagramRect[] borders, DiagramRect bounds, ImmutableArray<DiagramPoint>[] siblings)
    {
        starts = starts.Where(port => bounds.Contains(port.Stub)).ToList(); ends = ends.Where(port => bounds.Contains(port.Stub)).ToList(); if (starts.Count == 0 || ends.Count == 0) return null;
        obstacles = obstacles.Where(rect => rect.Intersects(bounds)).ToArray();
        var channels = siblings.SelectMany(route => route.Zip(route.Skip(1)).Select(pair => new DiagramRect(Math.Min(pair.First.X, pair.Second.X), Math.Min(pair.First.Y, pair.Second.Y), Math.Abs(pair.First.X - pair.Second.X), Math.Abs(pair.First.Y - pair.Second.Y)).Inset(-8, -8))).Where(rect => rect.Intersects(bounds)).ToArray();
        Func<DiagramPoint, DiagramPoint, double> congestion = (a, b) => channels.Count(rect => !EdgeGeometry.Clear(a, b, [rect])) * 160;
        var borderXs = borders.SelectMany(rect => new[] { rect.Left - GroupEdgeClearance, rect.Left + GroupEdgeClearance, rect.Right - GroupEdgeClearance, rect.Right + GroupEdgeClearance }).Where(value => value >= bounds.Left && value <= bounds.Right);
        var borderYs = borders.SelectMany(rect => new[] { rect.Top - GroupEdgeClearance, rect.Top + GroupEdgeClearance, rect.Bottom - GroupEdgeClearance, rect.Bottom + GroupEdgeClearance }).Where(value => value >= bounds.Top && value <= bounds.Bottom);
        var xs = new[] { bounds.Left, bounds.Right }.Concat(borderXs).Concat(starts.Select(port => port.Stub.X)).Concat(ends.Select(port => port.Stub.X)).Concat(obstacles.Concat(channels).SelectMany(rect => new[] { rect.Left, rect.Right }).Where(value => value >= bounds.Left && value <= bounds.Right)).Distinct().Order().ToArray();
        var ys = new[] { bounds.Top, bounds.Bottom }.Concat(borderYs).Concat(starts.Select(port => port.Stub.Y)).Concat(ends.Select(port => port.Stub.Y)).Concat(obstacles.Concat(channels).SelectMany(rect => new[] { rect.Top, rect.Bottom }).Where(value => value >= bounds.Top && value <= bounds.Bottom)).Distinct().Order().ToArray();
        var width = xs.Length; var cells = width * ys.Length; if (cells > 200_000) return null;
        Func<DiagramPoint, int> cell = p => Array.BinarySearch(ys, p.Y) * width + Array.BinarySearch(xs, p.X);
        Func<int, DiagramPoint> point = i => new(xs[i % width], ys[i / width]);
        Func<DiagramPoint, double> heuristic = p => ends.Min(port => Math.Abs(port.Stub.X - p.X) + Math.Abs(port.Stub.Y - p.Y));
        var costs = Enumerable.Repeat(double.PositiveInfinity, cells * 3).ToArray(); var previous = Enumerable.Repeat(-1, cells * 3).ToArray(); var origin = new int[cells * 3]; var heap = new RouteHeap();
        for (var i = 0; i < starts.Count; i++)
        { var port = starts[i]; if (EdgeGeometry.SharesSegment([port.Anchor, port.Stub], siblings)) continue; var axis = Math.Abs(port.Anchor.X - port.Stub.X) > .01 ? 1 : 2; var state = cell(port.Stub) * 3 + axis; var cost = port.Penalty + Math.Abs(port.Anchor.X - port.Stub.X) + Math.Abs(port.Anchor.Y - port.Stub.Y) + congestion(port.Anchor, port.Stub); if (cost >= costs[state]) continue; costs[state] = cost; origin[state] = i; heap.Enqueue((state, cost), cost + heuristic(port.Stub)); }
        var goal = -1; var endPort = 0; var best = double.PositiveInfinity; var endCells = ends.Select(port => cell(port.Stub)).ToArray();
        while (heap.TryDequeue(out var visit, out var estimate))
        {
            if (visit.Cost != costs[visit.State]) continue; if (estimate >= best) break;
            var index = visit.State / 3; var axis = visit.State % 3; var p = point(index);
            for (var target = 0; target < ends.Count; target++) if (endCells[target] == index)
            { var end = ends[target]; if (EdgeGeometry.SharesSegment([end.Stub, end.Anchor], siblings)) continue; var endAxis = Math.Abs(end.Anchor.X - end.Stub.X) > .01 ? 1 : 2; var score = visit.Cost + end.Penalty + Math.Abs(end.Anchor.X - end.Stub.X) + Math.Abs(end.Anchor.Y - end.Stub.Y) + (axis != endAxis ? 18 : 0) + congestion(end.Stub, end.Anchor); if (score < best) { best = score; goal = visit.State; endPort = target; } }
            var x = index % width; var y = index / width;
            foreach (var (nx, ny, nextAxis) in new[] { (x - 1, y, 1), (x + 1, y, 1), (x, y - 1, 2), (x, y + 1, 2) })
            {
                if (nx < 0 || nx >= width || ny < 0 || ny >= ys.Length) continue; var nextCell = ny * width + nx; var q = point(nextCell); if (!EdgeGeometry.Clear(p, q, obstacles) || !ClearOfBorders(p, q, borders) || EdgeGeometry.SharesSegment([p, q], siblings)) continue;
                var next = nextCell * 3 + nextAxis; var cost = visit.Cost + Math.Abs(q.X - p.X) + Math.Abs(q.Y - p.Y) + (axis != 0 && axis != nextAxis ? 18 : 0) + congestion(p, q); if (cost >= costs[next]) continue;
                costs[next] = cost; previous[next] = visit.State; origin[next] = origin[visit.State]; heap.Enqueue((next, cost), cost + heuristic(q));
            }
        }
        if (goal < 0) return null;
        var route = new List<DiagramPoint> { ends[endPort].Anchor }; var cursor = goal;
        while (cursor >= 0) { route.Add(point(cursor / 3)); cursor = previous[cursor]; }
        route.Add(starts[origin[goal]].Anchor); route.Reverse(); return EdgeGeometry.Simplify(route);
    }
    // Match Swift's binary heap tie order so equal cost visibility routes stay deterministic.
    private sealed class RouteHeap
    {
        private readonly List<(int State, double Cost, double Estimate)> values = [];
        public void Enqueue((int State, double Cost) value, double estimate)
        {
            values.Add((value.State, value.Cost, estimate)); var index = values.Count - 1;
            while (index > 0)
            {
                var parent = (index - 1) / 2; if (values[index].Estimate >= values[parent].Estimate) break;
                (values[index], values[parent]) = (values[parent], values[index]); index = parent;
            }
        }
        public bool TryDequeue(out (int State, double Cost) value, out double estimate)
        {
            if (values.Count == 0) { value = default; estimate = 0; return false; }
            var first = values[0]; value = (first.State, first.Cost); estimate = first.Estimate;
            var last = values[^1]; values.RemoveAt(values.Count - 1); if (values.Count == 0) return true;
            values[0] = last; var index = 0;
            while (index * 2 + 1 < values.Count)
            {
                var child = index * 2 + 1;
                if (child + 1 < values.Count && values[child + 1].Estimate < values[child].Estimate) child++;
                if (values[child].Estimate >= values[index].Estimate) break;
                (values[index], values[child]) = (values[child], values[index]); index = child;
            }
            return true;
        }
    }

}
