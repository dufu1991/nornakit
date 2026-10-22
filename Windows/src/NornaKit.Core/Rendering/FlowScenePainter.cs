using System.Collections.Immutable;

namespace NornaKit;

internal static class FlowScenePainter
{
    public static DiagramScene Prepare(DiagramScene scene, TextMeasurement text, DiagramKind kind = DiagramKind.Flowchart)
    {
        var builder = new SceneBuilder(kind, text);
        foreach (var group in scene.Groups.OrderBy(group => group.Depth))
        {
            builder.Rect(group.Frame, C.SurfaceAlt, C.Border, opacity: .4, id: group.Id, label: group.Label);
            if (group.Label.Length > 0) builder.Text(group.Label, group.TitleFrame, color: C.Muted, shrink: false, lineHeight: 22);
        }
        foreach (var edge in scene.Edges.Where(edge => edge.Style != EdgeStyle.Invisible))
        {
            builder.Path(ScenePaths.Edge(edge.Points), stroke: C.Line, width: edge.Style == EdgeStyle.Thick ? 3 : 1.5,
                dash: edge.Style == EdgeStyle.Dashed ? [5, 4] : null);
            builder.Path(ScenePaths.Marker(edge.EndMarker ?? (edge.Arrow ? EdgeMarker.Arrow : EdgeMarker.None), edge.Points), fill: C.Line, stroke: C.Line);
            builder.Path(ScenePaths.Marker(edge.StartMarker, edge.Points.Reverse().ToImmutableArray()), fill: C.Line, stroke: C.Line);
        }
        foreach (var node in scene.Nodes)
        {
            builder.Path(ScenePaths.Node(node), C.Surface, C.Border, id: node.Id);
            builder.Path(ScenePaths.Detail(node), stroke: C.Border);
            builder.Text(node.Label, node.Frame.Inset(node.Shape == NodeShape.Subroutine ? 20 : 12, 8), shrink: false, lineHeight: 22);
        }
        foreach (var edge in scene.Edges.Where(edge => edge.Label.Length > 0 && edge.Style != EdgeStyle.Invisible))
        {
            builder.Rect(edge.LabelFrame, C.Background, C.None, 3, id: $"edge-label-{edge.From}-{edge.To}", label: edge.Label);
            builder.Text(edge.Label, edge.LabelFrame, 12, shrink: false, lineHeight: 18);
        }
        return scene with { Kind = kind.Id(), Primitives = scene.Primitives.AddRange(builder.Primitives) };
    }
}
