using System.Collections.Immutable;

namespace NornaKit;

public enum NodeShape { Rectangle, Rounded, Stadium, Circle, Ellipse, Diamond, Cylinder, Subroutine, DoubleCircle, Hexagon, Asymmetric, Parallelogram, ParallelogramAlt, Trapezoid, TrapezoidAlt }
public enum FlowDirection { TopDown, BottomUp, LeftRight, RightLeft }
public enum EdgeStyle { Solid, Dashed, Thick, Invisible }
public enum EdgeMarker { None, Arrow, Circle, Cross }
public sealed record FlowNode(string Id, string Label, NodeShape Shape = NodeShape.Rectangle, string? ParentId = null, int Sequence = 0);
public sealed record FlowGroup(string Id, string Label, string? ParentId = null, FlowDirection? Direction = null, int Sequence = 0);
public sealed record FlowEdge(string From, string To, string Label = "", EdgeStyle Style = EdgeStyle.Solid,
    bool Arrow = true, int? SourceSide = null, int? TargetSide = null, EdgeMarker StartMarker = EdgeMarker.None,
    EdgeMarker? EndMarker = null, int MinimumRankSpan = 1);
public sealed record FlowchartModel(FlowDirection Direction, ImmutableArray<FlowNode> Nodes, ImmutableArray<FlowEdge> Edges, ImmutableArray<FlowGroup> Groups);
public sealed record SceneNode(string Id, string Label, NodeShape Shape, DiagramRect Frame, ImmutableArray<string> Lines);
public sealed record SceneEdge(string From, string To, ImmutableArray<DiagramPoint> Points, string Label, DiagramRect LabelFrame,
    EdgeStyle Style, bool Arrow, EdgeMarker StartMarker = EdgeMarker.None, EdgeMarker? EndMarker = null);
public sealed record SceneGroup(string Id, string Label, string? ParentId, DiagramRect Frame, DiagramRect TitleFrame, ImmutableArray<string> TitleLines, int Depth);

internal static class FlowDirections
{
    public static bool Horizontal(this FlowDirection direction) => direction is FlowDirection.LeftRight or FlowDirection.RightLeft;
    public static FlowDirection? Parse(string source) => source switch
    {
        "TD" or "TB" => FlowDirection.TopDown, "BT" => FlowDirection.BottomUp,
        "LR" => FlowDirection.LeftRight, "RL" => FlowDirection.RightLeft, _ => null
    };
}
