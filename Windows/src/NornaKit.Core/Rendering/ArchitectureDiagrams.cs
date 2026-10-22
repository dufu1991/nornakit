using System.Collections.Immutable;

namespace NornaKit;

internal sealed class ArchitectureDiagrams(TextMeasurement text)
{
    public DiagramScene Requirement(string source, DiagramLayoutOptions options)
    {
        var graph = new RelationshipModel(DiagramKind.Requirement); string? current = null;
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text;
            if (current is { } id) { if (s == "}") { current = null; continue; } var attribute = DiagramSyntax.Match(@"^(id|text|risk|verifymethod|type|docRef)\s*:\s*(.+)$", s) ?? throw line.Error("暂不支持这条需求属性。"); graph.Entities.First(entity => entity.Id == id).Members.Add($"{attribute[1]}: {DiagramSyntax.Label(attribute[2])}"); }
            else if (DiagramSyntax.Match(@"^(requirement|functionalRequirement|performanceRequirement|interfaceRequirement|physicalRequirement|designConstraint|element)\s+(\w+)\s*\{$", s) is { } entity) { graph.Register(entity[2]).Stereotype = $"«{entity[1]}»"; current = entity[2]; }
            else if (DiagramSyntax.Match(@"^(\w+)\s*-\s*(contains|copies|derives|satisfies|verifies|refines|traces)\s*->\s*(\w+)$", s) is { } relation) graph.Relations.Add(new(relation[1], relation[3], $"«{relation[2]}»", Dashed: relation[2] != "contains"));
            else if (DiagramSyntax.Match(@"^direction\s+(LR|RL|TB|TD|BT)$", s) is { } direction) graph.Direction = FlowDirections.Parse(direction[1])!.Value;
            else throw line.Error("暂不支持这条需求图语法。");
        }
        if (current is not null) throw new DiagramRenderException("需求定义缺少结束花括号。", "syntax"); Validate(graph); return graph.Scene(text, options);
    }
    public DiagramScene C4(string source, DiagramLayoutOptions options)
    {
        var graph = new RelationshipModel(DiagramKind.C4) { Direction = FlowDirection.LeftRight }; var stack = new Stack<string>();
        string[] boundaries = ["Boundary", "Enterprise_Boundary", "System_Boundary", "Container_Boundary", "Deployment_Node", "Node"];
        string[] elements = ["Person", "Person_Ext", "System", "System_Ext", "SystemDb", "SystemDb_Ext", "SystemQueue", "SystemQueue_Ext", "Container", "Container_Ext", "ContainerDb", "ContainerDb_Ext", "ContainerQueue", "Component", "Component_Ext", "ComponentDb"];
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) { graph.Title = s[6..]; continue; } if (s == "}") { if (!stack.TryPop(out _)) throw line.Error("多余的边界结束符。", "syntax"); continue; }
            var m = DiagramSyntax.Match(@"^(\w+)\((.*)\)\s*(\{)?$", s) ?? throw line.Error("C4 图需要宏形式的元素或关系声明。", "syntax"); var name = m[1]; var args = DiagramSyntax.Split(m[2]).Select(DiagramSyntax.Label).ToArray(); if (args.Length < 2) throw line.Error("C4 声明至少需要标识符和标签或目标。", "syntax");
            if (name is "Rel" or "BiRel" or "Rel_Back") { if (args.Length < 3) throw line.Error("关系缺少标签。", "syntax"); graph.Relations.Add(new(name == "Rel_Back" ? args[1] : args[0], name == "Rel_Back" ? args[0] : args[1], args[2] + (args.Length > 3 ? $"\n[{args[3]}]" : ""), name == "BiRel" ? "arrow" : "")); }
            else if (boundaries.Contains(name)) { if (m[3].Length == 0 || graph.Groups.Any(group => group.Id == args[0]) || stack.Count >= 16) throw line.Error("边界重复、缺少花括号或嵌套过深。", "syntax"); graph.Groups.Add(new(args[0], args[1], stack.FirstOrDefault(), Sequence: graph.Groups.Count)); stack.Push(args[0]); }
            else if (elements.Contains(name)) { if (graph.Entities.Any(entity => entity.Id == args[0])) throw line.Error("元素标识符重复。", "semantic"); var entity = graph.Register(args[0], args[1], stack.FirstOrDefault()); entity.Actor = name.StartsWith("Person", StringComparison.Ordinal); entity.Stereotype = $"[{name}]"; entity.Members.AddRange(args.Skip(2).Where(value => value.Length > 0)); }
            else throw line.Error($"暂不支持 C4 宏 {name}。");
        }
        if (stack.Count > 0) throw new DiagramRenderException("C4 边界缺少结束花括号。", "syntax"); Validate(graph); return graph.Scene(text, options);
    }
    public DiagramScene Usecase(string source, DiagramLayoutOptions options)
    {
        var graph = new RelationshipModel(DiagramKind.Usecase) { Direction = FlowDirection.LeftRight }; var stack = new Stack<string>(); var rectangles = new HashSet<string>();
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (s == "end") { if (!stack.TryPop(out _)) throw line.Error("end 没有对应的系统边界。", "syntax"); continue; }
            if (DiagramSyntax.Match(@"^direction\s+(LR|RL|TD|TB|BT)$", s) is { } direction) { graph.Direction = FlowDirections.Parse(direction[1])!.Value; continue; }
            if (DiagramSyntax.Match(@"^systemBoundary\s+(\w+)(?:\[([^\]]+)\])?$", s) is { } boundary) { if (graph.Groups.Any(group => group.Id == boundary[1]) || stack.Count >= 16) throw line.Error("边界重复或嵌套过深。", "semantic"); graph.Groups.Add(new(boundary[1], boundary[2].Length == 0 ? boundary[1] : DiagramSyntax.Label(boundary[2]), stack.FirstOrDefault(), Sequence: graph.Groups.Count)); stack.Push(boundary[1]); continue; }
            if (DiagramSyntax.Match(@"^actor\s+(\w+)(?:\[([^\]]+)\])?$", s) is { } actor) { graph.Register(actor[1], actor[2].Length == 0 ? null : DiagramSyntax.Label(actor[2]), stack.FirstOrDefault()).Actor = true; continue; }
            if (DiagramSyntax.Match(@"^(\w+)\s*(-->|--|\.\.>|<\|--)\s*(\w+)(?:\s*:\s*(.*))?$", s) is { } relation) { graph.Register(relation[1], parent: stack.FirstOrDefault()); graph.Register(relation[3], parent: stack.FirstOrDefault()); graph.Relations.Add(new(relation[1], relation[3], relation[4], relation[2] == "<|--" ? "triangle" : "", relation[2] is "-->" or "..>" ? "arrow" : "", relation[2] == "..>")); continue; }
            if (DiagramSyntax.Match(@"^(\w+)(?:\((.+)\)|\[(.+)\])?$", s) is { } entity) { if (entity[3].Length > 0) rectangles.Add(entity[1]); graph.Register(entity[1], entity[2].Length == 0 ? entity[3].Length == 0 ? null : DiagramSyntax.Label(entity[3]) : DiagramSyntax.Label(entity[2]), stack.FirstOrDefault()); continue; }
            throw line.Error("暂不支持这条用例图语法。");
        }
        if (stack.Count > 0) throw new DiagramRenderException("系统边界缺少 end。", "syntax"); foreach (var entity in graph.Entities.Where(entity => !entity.Actor && !rectangles.Contains(entity.Id))) entity.Shape = NodeShape.Ellipse; return graph.Scene(text, options);
    }
    private static void Validate(RelationshipModel graph)
    {
        var ids = graph.Entities.Select(entity => entity.Id).Concat(graph.Groups.Select(group => group.Id)).ToHashSet(); if (graph.Relations.Any(relation => !ids.Contains(relation.From) || !ids.Contains(relation.To))) throw new DiagramRenderException("关系引用了未定义的元素。", "semantic");
    }
    private sealed record Service(string Id, string Title, string Icon, string? Parent, bool Junction);
    public DiagramScene Architecture(string source, DiagramLayoutOptions options)
    {
        var services = new List<Service>(); var groups = new List<FlowGroup>(); var edges = new List<FlowEdge>(); var sides = new Dictionary<string, int> { ["T"] = 0, ["R"] = 1, ["B"] = 2, ["L"] = 3 };
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text;
            if (DiagramSyntax.Match(@"^(group|service|junction)\s+(\w+)(?:\(([^)]+)\))?(?:\[([^\]]*)\])?(?:\s+in\s+(\w+))?$", s) is { } item)
            {
                if (item[1] == "group") groups.Add(new(item[2], item[4].Length == 0 ? item[2] : item[4], item[5].Length == 0 ? null : item[5], Sequence: groups.Count));
                else { if (!new[] { "", "server", "database", "disk", "cloud", "internet" }.Contains(item[3])) throw line.Error("暂不支持这个架构图图标。"); services.Add(new(item[2], item[4].Length == 0 ? item[2] : item[4], item[3], item[5].Length == 0 ? null : item[5], item[1] == "junction")); }
            }
            else if (DiagramSyntax.Match(@"^(\w+):([TRBL])\s*(<)?--(>)?\s*([TRBL]):(\w+)$", s) is { } edge) { if (edge[3].Length > 0) throw line.Error("架构图暂不支持起点箭头。"); edges.Add(new(edge[1], edge[6], Arrow: edge[4].Length > 0, SourceSide: sides[edge[2]], TargetSide: sides[edge[5]])); }
            else throw line.Error("暂不支持这条架构图语法。");
        }
        DiagramSyntax.Nonempty(services.Count, DiagramKind.Architecture); var ids = services.Select(service => service.Id).ToArray(); var groupIds = groups.Select(group => group.Id).ToArray();
        if (ids.Concat(groupIds).Distinct().Count() != ids.Length + groupIds.Length || services.Any(service => service.Parent is not null && !groupIds.Contains(service.Parent)) || edges.Any(edge => !ids.Contains(edge.From) || !ids.Contains(edge.To))) throw new DiagramRenderException("架构图存在重复标识符或未定义的引用。", "semantic");
        foreach (var group in groups) { var seen = new HashSet<string> { group.Id }; var parent = group.ParentId; while (parent is not null) { var next = groups.FirstOrDefault(group => group.Id == parent); if (!seen.Add(parent) || next is null) throw new DiagramRenderException("架构分组存在循环或未知父组。", "semantic"); parent = next.ParentId; } }
        var graph = new FlowchartModel(FlowDirection.LeftRight, services.Select((service, index) => new FlowNode(service.Id, $"\n\n{service.Title}\n", ParentId: service.Parent, Sequence: index + groups.Count)).ToImmutableArray(), edges.ToImmutableArray(), groups.ToImmutableArray());
        var placed = new LayeredLayoutEngine(text).Layout(graph with { Edges = graph.Edges.Select(edge => edge with { SourceSide = null, TargetSide = null }).ToImmutableArray() }, options with { AutoDirection = false });
        var aligned = AlignedServiceNodes(placed, graph); var routed = new CompoundEdgeRouter(text).Route(graph, placed with { Nodes = aligned, Edges = [] }, separateConnections: true); var b = new SceneBuilder(DiagramKind.Architecture, text);
        foreach (var group in routed.Groups) { b.Rect(group.Frame, C.SurfaceAlt, opacity: .4); b.Text(group.Label, group.TitleFrame, color: C.Muted); }
        for (var i = 0; i < routed.Edges.Length; i++) b.Line(routed.Edges[i].Points, arrow: routed.Edges[i].Arrow, id: $"architecture-edge-{i}");
        foreach (var node in routed.Nodes)
        {
            var service = services.First(service => service.Id == node.Id); var r = node.Frame; if (service.Junction) { b.Ellipse(r.Inset(17, 17), C.Foreground, C.None, id: node.Id); continue; }
            b.Rect(r, C.Surface, id: node.Id, label: service.Title); var icon = r.Inset(10, 10);
            if (service.Icon is "database" or "disk") { var shape = new SceneNode(node.Id, "", NodeShape.Cylinder, icon, []); b.Path(ScenePaths.Node(shape), C.None, C.Foreground); b.Path(ScenePaths.Detail(shape), stroke: C.Foreground); }
            else if (service.Icon is "cloud" or "internet") { b.Ellipse(icon.Inset(0, 6), C.None, C.Foreground); b.Line([new(icon.Center.X, icon.Top + 6), new(icon.Center.X, icon.Bottom - 6)], C.Foreground); b.Line([new(icon.Left, icon.Center.Y), new(icon.Right, icon.Center.Y)], C.Foreground); }
            else for (var i = 0; i < 3; i++) b.Rect(new(icon.X, icon.Y + i * 9, icon.Width, 7), C.None, C.Foreground, 1);
            var bottom = edges.Any(edge => edge.From == node.Id && edge.SourceSide == 2 || edge.To == node.Id && edge.TargetSide == 2); b.Text(service.Title, new(r.Center.X - 90, bottom ? r.Top - 30 : r.Bottom + 6, 180, 24), 14);
        }
        return b.Build(routed.Size.Width, routed.Size.Height + 32);
    }
    private static ImmutableArray<SceneNode> AlignedServiceNodes(DiagramScene scene, FlowchartModel graph)
    {
        var reserved = scene.Nodes.ToDictionary(node => node.Id, node => node.Frame); var model = graph.Nodes.ToDictionary(node => node.Id); var groups = graph.Groups.ToDictionary(group => group.Id); var lookup = scene.Nodes.Select((node, i) => (node.Id, i)).ToDictionary(pair => pair.Id, pair => pair.i);
        Func<string, int> depth = id => { var parent = model[id].ParentId; var result = 0; while (parent is not null) { result++; parent = groups[parent].ParentId; } return result; };
        Func<string, int> degree = id => graph.Edges.Count(edge => edge.From == id || edge.To == id);
        var nodes = scene.Nodes.Select(node => node with { Frame = new(node.Frame.Center.X - 24, node.Frame.Center.Y - 24, 48, 48) }).ToArray();
        foreach (var horizontal in new[] { true, false })
        {
            var adjacent = nodes.Select(_ => new List<int>()).ToArray(); foreach (var edge in graph.Edges)
            { var opposite = horizontal ? new[] { (1, 3), (3, 1) } : [(0, 2), (2, 0)]; if (!opposite.Any(pair => edge.SourceSide == pair.Item1 && edge.TargetSide == pair.Item2) || edge.From == edge.To) continue; var from = lookup[edge.From]; var to = lookup[edge.To]; adjacent[from].Add(to); adjacent[to].Add(from); }
            Func<int, double> center = i => horizontal ? nodes[i].Frame.Center.Y : nodes[i].Frame.Center.X; var visited = new HashSet<int>();
            for (var seed = 0; seed < nodes.Length; seed++) if (visited.Add(seed))
            {
                var members = new List<int> { seed }; var low = center(seed); var high = low;
                for (var cursor = 0; cursor < members.Count; cursor++) foreach (var next in adjacent[members[cursor]].Where(next => !visited.Contains(next))) { var value = center(next); if (Math.Max(high, value) - Math.Min(low, value) > 12) continue; low = Math.Min(low, value); high = Math.Max(high, value); members.Add(next); visited.Add(next); }
                if (members.Count <= 1) continue; var reference = members.OrderByDescending(i => depth(nodes[i].Id)).ThenByDescending(i => degree(nodes[i].Id)).ThenBy(i => i).First(); var baseline = center(reference);
                var frames = members.Select(i => nodes[i].Frame.Offset(horizontal ? 0 : baseline - center(i), horizontal ? baseline - center(i) : 0)).ToArray(); if (members.Select((i, j) => reserved[nodes[i].Id].Contains(frames[j])).Any(valid => !valid)) continue;
                for (var i = 0; i < members.Count; i++) nodes[members[i]] = nodes[members[i]] with { Frame = frames[i] };
            }
        }
        return nodes.ToImmutableArray();
    }
}
