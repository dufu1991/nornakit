using System.Collections.Immutable;

namespace NornaKit;

internal sealed record GraphEntity(string Id)
{
    public string Title { get; set; } = Id;
    public List<string> Members { get; } = [];
    public NodeShape Shape { get; set; }
    public string? Parent { get; set; }
    public string Stereotype { get; set; } = "";
    public bool Actor { get; set; }
    public int StateMarker { get; set; }
    public bool Synchronization { get; set; }
}
internal sealed record GraphRelation(string From, string To, string Label = "", string Start = "", string End = "arrow", bool Dashed = false, string FromMultiplicity = "", string ToMultiplicity = "");
internal sealed record GraphNote(string? Target, string Text, string Side = "right");
internal sealed class RelationshipModel(DiagramKind kind)
{
    public DiagramKind Kind { get; } = kind;
    public FlowDirection Direction { get; set; } = FlowDirection.TopDown;
    public List<GraphEntity> Entities { get; } = [];
    public List<GraphRelation> Relations { get; } = [];
    public List<FlowGroup> Groups { get; } = [];
    public List<GraphNote> Notes { get; } = [];
    public HashSet<string> RegionGroups { get; } = [];
    public string Title { get; set; } = "";
    public GraphEntity Register(string id, string? title = null, string? parent = null)
    {
        var entity = Entities.FirstOrDefault(entity => entity.Id == id);
        if (entity is null) { entity = new(id) { Title = title ?? id, Parent = parent }; Entities.Add(entity); }
        else { if (title is not null) entity.Title = title; entity.Parent ??= parent; }
        return entity;
    }
    public DiagramScene Scene(TextMeasurement text, DiagramLayoutOptions options)
    {
        DiagramSyntax.Nonempty(Entities.Count + Groups.Count + Notes.Count, Kind);
        var nodes = Entities.Where(entity => Groups.All(group => group.Id != entity.Id)).Select((entity, index) =>
        {
            var label = entity.Synchronization ? "" : string.Join('\n', entity.Actor ? new[] { "", "", entity.Title }.Concat(entity.Members) : new[] { entity.Stereotype, entity.Title }.Where(value => value.Length > 0).Concat(entity.Members));
            return new FlowNode(entity.Id, label, entity.Shape, entity.Parent, index + Groups.Count);
        }).ToImmutableArray();
        var model = new FlowchartModel(Direction, nodes, Relations.Select(relation => new FlowEdge(relation.From, relation.To, relation.Label, relation.Dashed ? EdgeStyle.Dashed : EdgeStyle.Solid, false)).ToImmutableArray(), Groups.ToImmutableArray());
        var engine = new LayeredLayoutEngine(text); var placed = engine.Layout(model, options);
        if (options.MaxWidth is { } width && options.AutoDirection && options.Compact && Direction.Horizontal() && placed.Size.Width > width)
        { var candidate = engine.Layout(model with { Direction = FlowDirection.TopDown }, options); if (candidate.Size.Width < placed.Size.Width) placed = candidate; }
        if (Kind == DiagramKind.Usecase) placed = placed with { Nodes = AlignActors(placed) };
        if (Kind == DiagramKind.Usecase || Entities.Any(entity => entity.Actor))
        {
            var original = placed.Nodes.ToDictionary(node => node.Id); var actors = Entities.Where(entity => entity.Actor).Select(entity => entity.Id).ToHashSet();
            var glyphs = placed.Nodes.Select(node => actors.Contains(node.Id) ? node with { Frame = new(node.Frame.Center.X - 18, node.Frame.Y, 36, 52) } : node).ToImmutableArray();
            var captions = placed.Nodes.Where(node => actors.Contains(node.Id)).Select(node => new DiagramRect(node.Frame.X - 12, node.Frame.Y + 54, node.Frame.Width + 24, Math.Max(24, node.Frame.Height - 54))).ToArray();
            var routed = new CompoundEdgeRouter(text).Route(model, placed with { Nodes = glyphs, Edges = [] }, captions, separateConnections: true);
            placed = routed with { Nodes = routed.Nodes.Select(node => actors.Contains(node.Id) ? original[node.Id] with { Frame = original[node.Id].Frame.Offset(node.Frame.Center.X - original[node.Id].Frame.Center.X, node.Frame.Y - original[node.Id].Frame.Y) } : node).ToImmutableArray() };
        }
        var b = new SceneBuilder(Kind, text); var offset = Title.Length == 0 ? 0 : 44;
        Func<DiagramRect, bool, DiagramRect> bar = (r, horizontal) => horizontal ? new(r.Center.X - 4, r.Y, 8, Math.Max(40, r.Height)) : new(r.X, r.Center.Y - 4, Math.Max(48, r.Width), 8);
        var bars = placed.Nodes.ToDictionary(node => node.Id, node => { var edge = placed.Edges.FirstOrDefault(edge => edge.From == node.Id || edge.To == node.Id); var point = edge is null ? (DiagramPoint?)null : edge.From == node.Id ? edge.Points[0] : edge.Points[^1]; return point is { } p ? Math.Abs(p.X - node.Frame.Center.X) >= node.Frame.Width / 2 - 1 : Direction.Horizontal(); });
        var occupied = placed.Nodes.Select(node => node.Frame.Offset(0, offset).Inset(-3, -3)).Concat(placed.Groups.Select(group => group.TitleFrame.Offset(0, offset).Inset(-3, -3))).Concat(placed.Edges.Where(edge => edge.Label.Length > 0).Select(edge => edge.LabelFrame.Offset(0, offset).Inset(-3, -3))).ToList();
        foreach (var group in placed.Groups) { var region = RegionGroups.Contains(group.Id); b.Rect(group.Frame.Offset(0, offset), region ? C.None : C.SurfaceAlt, opacity: region ? 1 : .5, dash: region ? [5, 5] : []); b.Text(group.Label, group.TitleFrame.Offset(0, offset), color: C.Muted); }
        for (var index = 0; index < placed.Edges.Length; index++)
        {
            var edge = placed.Edges[index]; var relation = Relations[index]; var points = edge.Points.Select(point => point.Offset(0, offset)).ToArray();
            foreach (var (id, start) in new[] { (relation.From, true), (relation.To, false) })
            {
                var entity = Entities.FirstOrDefault(entity => entity.Id == id); var node = placed.Nodes.FirstOrDefault(node => node.Id == id);
                if (entity is null || node is null || entity.StateMarker == 0 && !entity.Synchronization || points.Length < 2) continue;
                var center = node.Frame.Center.Offset(0, offset); var i = start ? 0 : points.Length - 1; var other = points[start ? 1 : points.Length - 2]; var dx = other.X - center.X; var dy = other.Y - center.Y; double scale;
                if (entity.Synchronization) { var r = bar(node.Frame.Offset(0, offset), bars[id]); scale = Math.Min(Math.Abs(dx) > .001 ? r.Width / 2 / Math.Abs(dx) : double.PositiveInfinity, Math.Abs(dy) > .001 ? r.Height / 2 / Math.Abs(dy) : double.PositiveInfinity); }
                else scale = 9 / Math.Max(.001, double.Hypot(dx, dy));
                points[i] = center.Offset(dx * scale, dy * scale);
            }
            b.Line(points, dash: relation.Dashed ? [4, 4] : [], id: $"relation-{index}"); Marker(relation.End, points, b); Marker(relation.Start, points.Reverse().ToArray(), b);
            foreach (var (value, route, suffix) in new[] { (relation.FromMultiplicity, points, "from"), (relation.ToMultiplicity, points.Reverse().ToArray(), "to") })
                if (value.Length > 0) { var r = MultiplicityFrame(value, route, occupied, text); occupied.Add(r.Inset(-3, -3)); b.Rect(r, C.Background, C.None, 3, id: $"multiplicity-{index}-{suffix}", label: value); b.Text(value, r, 11); }
            if (edge.Label.Length > 0) { var r = edge.LabelFrame.Offset(0, offset); b.Rect(r, C.Background, C.None, 3, id: $"edge-label-relation-{index}"); b.Text(edge.Label, r, 12); }
        }
        foreach (var node in placed.Nodes)
        {
            var entity = Entities.First(entity => entity.Id == node.Id); var r = node.Frame.Offset(0, offset);
            if (entity.Synchronization) b.Rect(bar(r, bars[node.Id]), C.Foreground, C.None, 2, id: entity.Id, label: entity.Stereotype);
            else if (entity.StateMarker != 0) { var circle = new DiagramRect(r.Center.X - 9, r.Center.Y - 9, 18, 18); b.Ellipse(circle, entity.StateMarker == 1 ? C.Foreground : C.Background, C.Foreground, id: entity.Id, label: entity.Title); if (entity.StateMarker == 2) b.Ellipse(circle.Inset(4, 4), C.Foreground, C.None); }
            else if (entity.Actor)
            { var x = r.Center.X; var y = r.Y; b.Ellipse(new(x - 8, y, 16, 16), C.None, C.Foreground); b.Line([new(x, y + 16), new(x, y + 38)]); b.Line([new(x - 16, y + 24), new(x + 16, y + 24)]); b.Line([new(x - 12, y + 52), new(x, y + 38), new(x + 12, y + 52)]); b.Text(string.Join('\n', new[] { entity.Title }.Concat(entity.Members)), new(r.X - 12, y + 54, r.Width + 24, Math.Max(24, r.Height - 54)), 14); }
            else if (Kind is DiagramKind.ClassDiagram or DiagramKind.ER or DiagramKind.Requirement or DiagramKind.C4)
            {
                b.Rect(r, id: entity.Id, label: entity.Title); var heading = string.Join('\n', new[] { entity.Stereotype, entity.Title }.Where(value => value.Length > 0)); var header = entity.Stereotype.Length == 0 ? 34 : 54;
                b.Text(heading, new(r.X + 6, r.Y + 4, r.Width - 12, Math.Min(header, r.Height - 8)), 15, bold: true);
                if (entity.Members.Count == 0) continue; var separator = r.Y + header + 4; b.Line([new(r.X, separator), new(r.Right, separator)], C.Border);
                var sections = Kind == DiagramKind.ClassDiagram ? new[] { entity.Members.Where(value => !value.Contains('(')).ToArray(), entity.Members.Where(value => value.Contains('(')).ToArray() }.Where(section => section.Length > 0).ToArray() : [entity.Members.ToArray()]; var bodyY = separator + 4;
                for (var i = 0; i < sections.Length; i++) { var h = Math.Min(sections[i].Sum(value => text.Lines(value, r.Width - 20).Length) * 20, Math.Max(20, r.Bottom - bodyY - 4)); b.Text(string.Join('\n', sections[i]), new(r.X + 10, bodyY, r.Width - 20, h), 14, align: TextAlignment.Leading, mono: Kind == DiagramKind.ER); bodyY += h + 4; if (i < sections.Length - 1) { b.Line([new(r.X, bodyY), new(r.Right, bodyY)], C.Border); bodyY += 4; } }
            }
            else if (entity.Shape is NodeShape.Circle or NodeShape.Ellipse) { b.Ellipse(r, id: entity.Id, label: entity.Title); b.Text(entity.Title, r.Inset(8, 6)); }
            else if (entity.Shape == NodeShape.Diamond) { b.Path(ScenePaths.Node(node with { Frame = r }), C.Surface, C.Border, id: entity.Id); b.Text(entity.Title, r.Inset(12, 12)); }
            else b.Box(entity.Title, r, radius: Kind == DiagramKind.State ? 10 : 8, id: entity.Id);
        }
        var noteBottom = new Dictionary<string, double>();
        for (var i = 0; i < Notes.Count; i++)
        {
            var note = Notes[i]; var lines = text.Lines(note.Text, options.Compact ? 160 : 220); var w = Math.Max(120, lines.Max(value => text.Width(value)) + 24); var h = lines.Length * 22 + 24;
            var target = placed.Nodes.FirstOrDefault(node => node.Id == note.Target)?.Frame.Offset(0, offset) ?? placed.Groups.FirstOrDefault(group => group.Id == note.Target)?.Frame.Offset(0, offset);
            var y = Math.Max(8, Math.Max((target?.Center.Y ?? 8) - h / 2, noteBottom.GetValueOrDefault(note.Side, 8))); var x = note.Side == "left" ? -w - 24 : placed.Size.Width + 24; var r = new DiagramRect(x, y, w, h);
            if (target is { } t) b.Line([new(note.Side == "left" ? r.Right : r.Left, r.Center.Y), new(note.Side == "left" ? t.Left : t.Right, t.Center.Y)], C.Border, dash: [3, 4]);
            b.Rect(r, C.SurfaceAlt, id: $"note-{i}", label: note.Text); b.Text(note.Text, r.Inset(12, 12), 14, align: TextAlignment.Leading); noteBottom[note.Side] = r.Bottom + 16;
        }
        if (Title.Length > 0) b.Text(Title, new(8, 4, placed.Size.Width - 16, 32), 20, bold: true);
        return b.Build(placed.Size.Width, placed.Size.Height + offset);
    }
    private ImmutableArray<SceneNode> AlignActors(DiagramScene scene)
    {
        var nodes = scene.Nodes.ToArray(); var actors = Entities.Where(entity => entity.Actor).Select(entity => entity.Id).ToHashSet();
        Func<SceneNode, DiagramRect> footprint = node => actors.Contains(node.Id) ? new(node.Frame.X - 12, node.Frame.Y, node.Frame.Width + 24, Math.Max(78, node.Frame.Height)) : node.Frame;
        for (var i = 0; i < nodes.Length; i++) if (actors.Contains(nodes[i].Id))
        {
            var actor = nodes[i]; var adjacent = Relations.Where(relation => relation.From == actor.Id || relation.To == actor.Id).Select(relation => relation.From == actor.Id ? relation.To : relation.From).ToHashSet();
            var targets = nodes.Where(node => adjacent.Contains(node.Id) && !actors.Contains(node.Id)).ToArray(); if (targets.Length == 0 || targets.Length != adjacent.Count || !(targets.All(node => node.Frame.Left > actor.Frame.Right) || targets.All(node => node.Frame.Right < actor.Frame.Left))) continue;
            var centers = targets.Select(node => node.Frame.Center.Y).Order().ToArray(); var middle = centers.Length / 2; var center = centers.Length % 2 == 0 ? (centers[middle - 1] + centers[middle]) / 2 : centers[middle]; var aligned = actor with { Frame = actor.Frame with { Y = center - 26 } }; var bounds = footprint(aligned);
            if (nodes.Where((_, index) => index != i).Any(node => footprint(node).Inset(-8, -8).Intersects(bounds))) continue;
            var parent = Entities.First(entity => entity.Id == actor.Id).Parent; var group = scene.Groups.FirstOrDefault(group => group.Id == parent);
            if (group is not null && (!group.Frame.Inset(8, 8).Contains(bounds) || bounds.Top < group.TitleFrame.Bottom + 8)) continue; nodes[i] = aligned;
        }
        return nodes.ToImmutableArray();
    }
    private static DiagramRect MultiplicityFrame(string value, DiagramPoint[] points, List<DiagramRect> occupied, TextMeasurement text)
    {
        var width = text.Width(value, 11) + 4; const double height = 16; var candidates = new List<DiagramRect>(); double traversed = 0;
        foreach (var (a, b) in points.Zip(points.Skip(1)))
        {
            var length = a.DistanceTo(b); if (length <= .001) continue; var dx = (b.X - a.X) / length; var dy = (b.Y - a.Y) / length;
            foreach (var distance in new[] { 18, 28, 40, 54 }.Where(distance => distance >= traversed && distance <= traversed + length))
            { var baseOffset = Math.Abs(dx) > Math.Abs(dy) ? height / 2 + 5 : width / 2 + 5; foreach (var normal in new[] { baseOffset, baseOffset + 16, baseOffset + 32, baseOffset + 64 }) foreach (var sign in new[] { 1, -1 }) { var center = new DiagramPoint(a.X + dx * (distance - traversed) - dy * normal * sign, a.Y + dy * (distance - traversed) + dx * normal * sign); var r = new DiagramRect(center.X - width / 2, center.Y - height / 2, width, height); if (occupied.All(other => !other.Intersects(r))) return r; candidates.Add(r); } }
            traversed += length;
        }
        return candidates.Count > 0 ? candidates[0] : new(points.Length == 0 ? 0 : points[0].X, points.Length == 0 ? 0 : points[0].Y, width, height);
    }
    private static void Marker(string symbol, IReadOnlyList<DiagramPoint> points, SceneBuilder b)
    {
        if (symbol.Length == 0 || points.Count < 2) return; var tip = points[^1]; var previous = points[^2]; var length = Math.Max(.01, tip.DistanceTo(previous)); var dx = (tip.X - previous.X) / length; var dy = (tip.Y - previous.Y) / length;
        Func<double, double, DiagramPoint> p = (along, across) => new(tip.X - dx * along - dy * across, tip.Y - dy * along + dx * across);
        switch (symbol)
        {
            case "arrow": b.Path(ScenePaths.Arrow(points), C.Line, C.None); break;
            case "triangle": b.Path(DataCharts.Polygon([tip, p(14, 7), p(14, -7)]), C.Background, C.Line); break;
            case "diamond": case "filledDiamond": b.Path(DataCharts.Polygon([tip, p(7, 5), p(14, 0), p(7, -5)]), symbol == "diamond" ? C.Background : C.Line, C.Line); break;
            case "interface": var center = p(6, 0); b.Ellipse(new(center.X - 6, center.Y - 6, 12, 12), C.Background, C.Line); break;
            default:
                if (symbol.Contains("many", StringComparison.Ordinal)) { b.Line([p(0, -6), p(12, 0), p(0, 6)]); b.Line([p(0, 0), p(12, 0)]); } else b.Line([p(4, -6), p(4, 6)]);
                if (symbol.Contains("optional", StringComparison.Ordinal)) { var c = p(18, 0); b.Ellipse(new(c.X - 4, c.Y - 4, 8, 8), C.Background, C.Line); } else b.Line([p(14, -6), p(14, 6)]); break;
        }
    }
}
