using System.Collections.Immutable;

namespace NornaKit;

internal sealed class CompoundLayoutEngine(LayeredLayoutEngine layered, TextMeasurement text)
{
    public DiagramScene Layout(FlowchartModel graph, DiagramLayoutOptions options)
    {
        var groups = graph.Groups.ToDictionary(group => group.Id); var nodes = graph.Nodes.ToDictionary(node => node.Id);
        Func<string, string?> parent = id => groups.TryGetValue(id, out var group) ? group.ParentId : nodes[id].ParentId;
        Func<string, string?, string?> childIn = (id, container) =>
        { if (id == container) return null; while (parent(id) != container) { var next = parent(id); if (next is null) return null; id = next; } return id; };
        Func<string?, FlowDirection, int, DiagramScene> build = null!;
        build = (container, inherited, depth) =>
        {
            var group = container is null ? null : groups[container]; var direction = group?.Direction ?? inherited;
            var children = graph.Groups.Where(child => child.ParentId == container).ToArray();
            var subtrees = children.ToDictionary(child => child.Id, child => build(child.Id, direction, depth + 1));
            var items = graph.Nodes.Where(node => node.ParentId == container).Concat(children.Select(child => new FlowNode(child.Id, child.Label, Sequence: child.Sequence))).OrderBy(node => node.Sequence).ToImmutableArray();
            var pairs = new HashSet<(string, string)>(); var edges = new List<FlowEdge>();
            foreach (var edge in graph.Edges)
            { var from = childIn(edge.From, container); var to = childIn(edge.To, container); if (from is null || to is null || from == to || !pairs.Add((from, to))) continue; edges.Add(edge with { From = from, To = to }); }
            edges.AddRange(graph.Edges.Where(edge => edge.From == edge.To && items.Any(item => item.Id == edge.From)));
            var flat = layered.Flat(new(direction, items, edges.ToImmutableArray(), []), options, subtrees.ToDictionary(pair => pair.Key, pair => pair.Value.Size), 0);
            var titleLines = group is null || group.Label.Length == 0 ? [] : text.Lines(group.Label, Math.Min(400, Math.Max(80, (options.MaxWidth ?? 480) - 80)));
            var titleWidth = titleLines.Select(line => text.Width(line)).DefaultIfEmpty(0).Max();
            var header = group is null ? 8 : titleLines.IsEmpty ? 20 : titleLines.Length * 22 + 16;
            var labels = new EdgeLabelLayout(text);
            var returnRoom = edges.Where(edge => edge.Label.Length > 0 && edges.Any(other => other.From == edge.To && other.To == edge.From)).Select(edge => labels.Size(labels.Lines(edge.Label)).Width / 2 + 44).DefaultIfEmpty(0).Max();
            var side = group is null ? 8 : Math.Max(20, returnRoom);
            var width = Math.Max(flat.Size.Width + 2 * side, group is null ? 0 : Math.Max(80, titleWidth + 2 * side));
            var height = Math.Max(flat.Size.Height, items.IsEmpty ? 32 : 0) + header + side; var dx = (width - flat.Size.Width) / 2;
            var placedNodes = new List<SceneNode>(); var placedGroups = new List<SceneGroup>();
            if (group is not null) placedGroups.Add(new(group.Id, group.Label, group.ParentId, new(0, 0, width, height), new((width - titleWidth) / 2, 8, titleWidth, titleLines.Length * 22), titleLines, depth - 1));
            foreach (var item in flat.Nodes)
            {
                if (subtrees.TryGetValue(item.Id, out var subtree))
                {
                    var x = item.Frame.X + dx; var y = item.Frame.Y + header;
                    placedNodes.AddRange(subtree.Nodes.Select(node => node with { Frame = node.Frame.Offset(x, y) }));
                    placedGroups.AddRange(subtree.Groups.Select(value => value with { Frame = value.Frame.Offset(x, y), TitleFrame = value.TitleFrame.Offset(x, y) }));
                }
                else placedNodes.Add(item with { Frame = item.Frame.Offset(dx, header) });
            }
            return new(new(width, height), "flowchart", []) { Nodes = placedNodes.ToImmutableArray(), Groups = placedGroups.ToImmutableArray() };
        };
        return new CompoundEdgeRouter(text).Route(graph, build(null, graph.Direction, 0));
    }
}
