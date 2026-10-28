using System.Collections.Immutable;

namespace NornaKit;

public static class ScenePaths
{
    public static ImmutableArray<PathCommand> Node(SceneNode node)
    {
        var r = node.Frame;
        if (Polygon(node.Shape, r) is { } polygon) return PolygonPath(polygon);
        return node.Shape switch
        {
            NodeShape.Diamond => PolygonPath([new(r.Center.X, r.Top), new(r.Right, r.Center.Y), new(r.Center.X, r.Bottom), new(r.Left, r.Center.Y)]),
            NodeShape.Circle or NodeShape.DoubleCircle or NodeShape.Ellipse => Ellipse(r),
            NodeShape.Cylinder => Cylinder(r),
            NodeShape.Stadium => Rectangle(r, r.Height / 2), NodeShape.Rounded => Rectangle(r, 12),
            _ => Rectangle(r, 8)
        };
    }
    public static ImmutableArray<PathCommand> Detail(SceneNode node)
    {
        var r = node.Frame;
        var ry = Math.Min(12, Math.Max(6, r.Width / 14));
        return node.Shape switch
        {
            NodeShape.DoubleCircle => Ellipse(r.Inset(5, 5)),
            NodeShape.Cylinder => [new PathCommand.Move(new(r.Left, r.Top + ry)), new PathCommand.Cubic(new(r.Left, r.Top + ry * 7 / 3), new(r.Right, r.Top + ry * 7 / 3), new(r.Right, r.Top + ry))],
            NodeShape.Subroutine => [new PathCommand.Move(new(r.Left + 8, r.Top)), new PathCommand.Line(new(r.Left + 8, r.Bottom)), new PathCommand.Move(new(r.Right - 8, r.Top)), new PathCommand.Line(new(r.Right - 8, r.Bottom))],
            _ => []
        };
    }
    public static DiagramPoint[]? Polygon(NodeShape shape, DiagramRect frame)
    {
        (double X, double Y)[]? vertices = shape switch
        {
            NodeShape.Hexagon => [(.2, 0), (.8, 0), (1, .5), (.8, 1), (.2, 1), (0, .5)],
            NodeShape.Asymmetric => [(0, 0), (.8, 0), (1, .5), (.8, 1), (0, 1), (.2, .5)],
            NodeShape.Parallelogram => [(.2, 0), (1, 0), (.8, 1), (0, 1)],
            NodeShape.ParallelogramAlt => [(0, 0), (.8, 0), (1, 1), (.2, 1)],
            NodeShape.Trapezoid => [(.2, 0), (.8, 0), (1, 1), (0, 1)],
            NodeShape.TrapezoidAlt => [(0, 0), (1, 0), (.8, 1), (.2, 1)], _ => null
        };
        return vertices?.Select(point => new DiagramPoint(frame.X + point.X * frame.Width, frame.Y + point.Y * frame.Height)).ToArray();
    }
    private static ImmutableArray<PathCommand> PolygonPath(DiagramPoint[] points)
        => [new PathCommand.Move(points[0]), .. points.Skip(1).Select(point => (PathCommand)new PathCommand.Line(point)), new PathCommand.Close()];
    private static ImmutableArray<PathCommand> Cylinder(DiagramRect r)
    {
        var ry = Math.Min(12, Math.Max(6, r.Width / 14));
        return [new PathCommand.Move(new(r.Left, r.Top + ry)),
            new PathCommand.Cubic(new(r.Left, r.Top - ry / 3), new(r.Right, r.Top - ry / 3), new(r.Right, r.Top + ry)),
            new PathCommand.Line(new(r.Right, r.Bottom - ry)),
            new PathCommand.Cubic(new(r.Right, r.Bottom + ry / 3), new(r.Left, r.Bottom + ry / 3), new(r.Left, r.Bottom - ry)), new PathCommand.Close()];
    }
    public static ImmutableArray<PathCommand> Edge(IReadOnlyList<DiagramPoint> points)
    {
        if (points.Count == 0) return [];
        var result = ImmutableArray.CreateBuilder<PathCommand>(); result.Add(new PathCommand.Move(points[0]));
        for (var index = 1; index < points.Count - 1; index++)
        {
            var a = points[index - 1]; var b = points[index]; var c = points[index + 1];
            var ab = a.DistanceTo(b); var bc = b.DistanceTo(c); var radius = Math.Min(20, Math.Min(ab, bc) / 2);
            if (ab == 0 || bc == 0) continue;
            var start = new DiagramPoint(b.X + (a.X - b.X) * radius / ab, b.Y + (a.Y - b.Y) * radius / ab);
            var end = new DiagramPoint(b.X + (c.X - b.X) * radius / bc, b.Y + (c.Y - b.Y) * radius / bc);
            result.Add(new PathCommand.Line(start));
            result.Add(new PathCommand.Cubic(new(start.X + (b.X - start.X) * .62, start.Y + (b.Y - start.Y) * .62),
                new(end.X + (b.X - end.X) * .62, end.Y + (b.Y - end.Y) * .62), end));
        }
        if (points.Count > 1) result.Add(new PathCommand.Line(points[^1]));
        return result.ToImmutable();
    }
    public static ImmutableArray<PathCommand> Arrow(IReadOnlyList<DiagramPoint> points)
    {
        if (points.Count < 2) return [];
        var tip = points[^1]; var previous = points[^2]; var length = tip.DistanceTo(previous);
        if (length == 0) return [];
        var x = (tip.X - previous.X) / length; var y = (tip.Y - previous.Y) / length;
        return PolygonPath([tip, new(tip.X - x * 8 - y * 3.36, tip.Y - y * 8 + x * 3.36), new(tip.X - x * 8 + y * 3.36, tip.Y - y * 8 - x * 3.36)]);
    }
    public static ImmutableArray<PathCommand> Marker(EdgeMarker marker, IReadOnlyList<DiagramPoint> points)
    {
        if (marker == EdgeMarker.None || points.Count == 0) return [];
        if (marker == EdgeMarker.Arrow) return Arrow(points);
        var tip = points[^1]; var previous = points.Count > 1 ? points[^2] : tip; var length = Math.Max(.001, tip.DistanceTo(previous));
        var distance = marker == EdgeMarker.Circle ? 3.5 : 6;
        var center = new DiagramPoint(tip.X - (tip.X - previous.X) / length * distance, tip.Y - (tip.Y - previous.Y) / length * distance);
        return marker == EdgeMarker.Circle ? Ellipse(new(center.X - 3.5, center.Y - 3.5, 7, 7))
            : [new PathCommand.Move(new(center.X - 4, center.Y - 4)), new PathCommand.Line(new(center.X + 4, center.Y + 4)),
                new PathCommand.Move(new(center.X + 4, center.Y - 4)), new PathCommand.Line(new(center.X - 4, center.Y + 4))];
    }
    public static ImmutableArray<PathCommand> Rectangle(DiagramRect frame, double radius)
    {
        var r = frame;
        var k = Math.Min(radius, Math.Min(r.Width, r.Height) / 2);
        var h = k * .55228475;
        return [new PathCommand.Move(new(r.Left + k, r.Top)), new PathCommand.Line(new(r.Right - k, r.Top)),
            new PathCommand.Cubic(new(r.Right - k + h, r.Top), new(r.Right, r.Top + k - h), new(r.Right, r.Top + k)),
            new PathCommand.Line(new(r.Right, r.Bottom - k)),
            new PathCommand.Cubic(new(r.Right, r.Bottom - k + h), new(r.Right - k + h, r.Bottom), new(r.Right - k, r.Bottom)),
            new PathCommand.Line(new(r.Left + k, r.Bottom)),
            new PathCommand.Cubic(new(r.Left + k - h, r.Bottom), new(r.Left, r.Bottom - k + h), new(r.Left, r.Bottom - k)),
            new PathCommand.Line(new(r.Left, r.Top + k)),
            new PathCommand.Cubic(new(r.Left, r.Top + k - h), new(r.Left + k - h, r.Top), new(r.Left + k, r.Top)),
            new PathCommand.Close()];
    }

    public static ImmutableArray<PathCommand> Ellipse(DiagramRect r)
    {
        var rx = r.Width / 2;
        var ry = r.Height / 2;
        const double k = .55228475;
        return [new PathCommand.Move(new(r.Center.X, r.Top)),
            new PathCommand.Cubic(new(r.Center.X + rx * k, r.Top), new(r.Right, r.Center.Y - ry * k), new(r.Right, r.Center.Y)),
            new PathCommand.Cubic(new(r.Right, r.Center.Y + ry * k), new(r.Center.X + rx * k, r.Bottom), new(r.Center.X, r.Bottom)),
            new PathCommand.Cubic(new(r.Center.X - rx * k, r.Bottom), new(r.Left, r.Center.Y + ry * k), new(r.Left, r.Center.Y)),
            new PathCommand.Cubic(new(r.Left, r.Center.Y - ry * k), new(r.Center.X - rx * k, r.Top), new(r.Center.X, r.Top)),
            new PathCommand.Close()];
    }

    public static ImmutableArray<PathCommand> Geometry(VectorGeometry geometry) => geometry switch
    {
        VectorGeometry.Rectangle rectangle => Rectangle(rectangle.Frame, rectangle.Radius),
        VectorGeometry.Ellipse ellipse => Ellipse(ellipse.Frame),
        VectorGeometry.Path path => path.Commands,
        _ => throw new ArgumentException("Text does not have a single scene path.", nameof(geometry))
    };
}
