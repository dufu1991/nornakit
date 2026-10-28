using System.Collections.Immutable;

namespace NornaKit;

internal static class NodeGeometry
{
    public static DiagramPoint Anchor(NodeShape shape, DiagramRect frame, int side, double offset = 0)
    {
        var vertical = side % 2 == 0;
        var half = (vertical ? frame.Width : frame.Height) / 2;
        offset = Math.Clamp(offset, -half * .9, half * .9);
        if (ScenePaths.Polygon(shape, frame) is { } polygon)
        {
            var fixedPoint = (vertical ? frame.Center.X : frame.Center.Y) + offset;
            var intersections = new List<double>();
            for (var index = 0; index < polygon.Length; index++)
            {
                var a = polygon[index]; var b = polygon[(index + 1) % polygon.Length];
                var low = vertical ? a.X : a.Y; var high = vertical ? b.X : b.Y;
                if (Math.Abs(high - low) <= .001 || fixedPoint < Math.Min(low, high) || fixedPoint > Math.Max(low, high)) continue;
                var t = (fixedPoint - low) / (high - low);
                intersections.Add(vertical ? a.Y + t * (b.Y - a.Y) : a.X + t * (b.X - a.X));
            }
            if (intersections.Count > 0)
            {
                var edge = side is 0 or 3 ? intersections.Min() : intersections.Max();
                return vertical ? new(fixedPoint, edge) : new(edge, fixedPoint);
            }
        }
        var depth = (vertical ? frame.Height : frame.Width) / 2;
        if (half > 0)
        {
            switch (shape)
            {
                case NodeShape.Diamond: depth *= 1 - Math.Abs(offset) / half; break;
                case NodeShape.Circle: case NodeShape.DoubleCircle: case NodeShape.Ellipse:
                    depth *= Math.Sqrt(Math.Max(0, 1 - Math.Pow(offset / half, 2))); break;
                case NodeShape.Cylinder when vertical:
                    depth -= Math.Min(12, Math.Max(6, frame.Width / 14)) * (1 - Math.Sqrt(Math.Max(0, 1 - Math.Pow(offset / half, 2)))); break;
                case NodeShape.Stadium:
                    var radius = frame.Height / 2;
                    var curved = Math.Max(0, Math.Abs(offset) - (frame.Width / 2 - radius));
                    depth = vertical ? Math.Sqrt(Math.Max(0, radius * radius - curved * curved))
                        : frame.Width / 2 - radius + Math.Sqrt(Math.Max(0, radius * radius - offset * offset)); break;
                case NodeShape.Rectangle: case NodeShape.Rounded: case NodeShape.Subroutine:
                    var cornerRadius = Math.Min(shape == NodeShape.Rounded ? 12 : 8, Math.Min(frame.Width, frame.Height) / 2);
                    var corner = Math.Max(0, Math.Abs(offset) - (half - cornerRadius));
                    depth -= cornerRadius - Math.Sqrt(Math.Max(0, cornerRadius * cornerRadius - corner * corner)); break;
            }
        }
        return side switch
        {
            0 => new(frame.Center.X + offset, frame.Center.Y - depth), 1 => new(frame.Center.X + depth, frame.Center.Y + offset),
            2 => new(frame.Center.X + offset, frame.Center.Y + depth), _ => new(frame.Center.X - depth, frame.Center.Y + offset)
        };
    }
}

internal static class EdgeGeometry
{
    public static double SharedLength(DiagramPoint a, DiagramPoint b, DiagramPoint c, DiagramPoint d)
    {
        if (Math.Abs(a.X - b.X) < .001 && Math.Abs(c.X - d.X) < .001 && Math.Abs(a.X - c.X) < .001)
            return Math.Max(0, Math.Min(Math.Max(a.Y, b.Y), Math.Max(c.Y, d.Y)) - Math.Max(Math.Min(a.Y, b.Y), Math.Min(c.Y, d.Y)));
        if (Math.Abs(a.Y - b.Y) < .001 && Math.Abs(c.Y - d.Y) < .001 && Math.Abs(a.Y - c.Y) < .001)
            return Math.Max(0, Math.Min(Math.Max(a.X, b.X), Math.Max(c.X, d.X)) - Math.Max(Math.Min(a.X, b.X), Math.Min(c.X, d.X)));
        return 0;
    }

    public static bool SharesSegment(IEnumerable<DiagramPoint> points, IEnumerable<ImmutableArray<DiagramPoint>> routes)
        => points.Zip(points.Skip(1)).Any(pair => routes.Any(route => route.Zip(route.Skip(1))
            .Any(other => SharedLength(pair.First, pair.Second, other.First, other.Second) > .01)));

    public static List<(DiagramPoint A, DiagramPoint B)> Segments(IEnumerable<PathCommand> commands)
    {
        var result = new List<(DiagramPoint, DiagramPoint)>();
        var cursor = new DiagramPoint();
        foreach (var command in commands)
        {
            if (command is PathCommand.Move move) { cursor = move.Point; continue; }
            if (command is PathCommand.Line line) { result.Add((cursor, line.Point)); cursor = line.Point; continue; }
            if (command is PathCommand.Close) continue;
            var start = cursor;
            for (var step = 1; step <= 24; step++)
            {
                var t = step / 24d; var u = 1 - t;
                var end = command switch
                {
                    PathCommand.Quadratic q => new DiagramPoint(u * u * start.X + 2 * u * t * q.Control.X + t * t * q.End.X,
                        u * u * start.Y + 2 * u * t * q.Control.Y + t * t * q.End.Y),
                    PathCommand.Cubic c => new DiagramPoint(u * u * u * start.X + 3 * u * u * t * c.Control1.X + 3 * u * t * t * c.Control2.X + t * t * t * c.End.X,
                        u * u * u * start.Y + 3 * u * u * t * c.Control1.Y + 3 * u * t * t * c.Control2.Y + t * t * t * c.End.Y),
                    _ => throw new ArgumentOutOfRangeException(nameof(commands))
                };
                result.Add((cursor, end)); cursor = end;
            }
        }
        return result;
    }
    public static bool Clear(DiagramPoint a, DiagramPoint b, IEnumerable<DiagramRect> obstacles)
    {
        foreach (var rect in obstacles.Where(rect => rect.Width > 0 && rect.Height > 0))
        {
            var r = rect.Inset(.01, .01); double lower = 0, upper = 1; var misses = false;
            foreach (var (origin, delta, minimum, maximum) in new[] { (a.X, b.X - a.X, r.Left, r.Right), (a.Y, b.Y - a.Y, r.Top, r.Bottom) })
            {
                if (Math.Abs(delta) < .00001)
                { if (origin <= minimum || origin >= maximum) { misses = true; break; } }
                else
                {
                    var first = (minimum - origin) / delta; var last = (maximum - origin) / delta;
                    lower = Math.Max(lower, Math.Min(first, last)); upper = Math.Min(upper, Math.Max(first, last));
                }
            }
            if (!misses && upper - lower > .00001) return false;
        }
        return true;
    }
    public static ImmutableArray<DiagramPoint> Simplify(IEnumerable<DiagramPoint> points)
    {
        var result = new List<DiagramPoint>();
        foreach (var point in points)
        {
            if (result.Count > 0 && result[^1] == point) continue;
            while (result.Count >= 2)
            {
                var a = result[^2]; var b = result[^1];
                if (!(Math.Abs(a.X - b.X) < .001 && Math.Abs(b.X - point.X) < .001)
                    && !(Math.Abs(a.Y - b.Y) < .001 && Math.Abs(b.Y - point.Y) < .001)) break;
                result.RemoveAt(result.Count - 1);
            }
            if (result.Count == 0 || result[^1] != point) result.Add(point);
        }
        return result.ToImmutableArray();
    }
}

internal sealed class EdgeLabelLayout(TextMeasurement text)
{
    public ImmutableArray<string> Lines(string value) => text.Lines(value, 180, DiagramStyle.EdgeFontSize);
    public DiagramSize Size(ImmutableArray<string> lines) => new(lines.Select(line => text.Width(line, DiagramStyle.EdgeFontSize)).DefaultIfEmpty(0).Max() + 4,
        lines.Length * DiagramStyle.EdgeLineHeight);
    public DiagramRect Frame(DiagramSize size, IReadOnlyList<DiagramPoint> points, IReadOnlyList<DiagramRect> obstacles,
        IReadOnlyList<ImmutableArray<DiagramPoint>> routes, DiagramRect? domain = null)
    {
        var otherRoutes = routes.Where(route => !route.SequenceEqual(points)).Select(route => EdgeGeometry.Segments(ScenePaths.Edge(route))).ToArray();
        (DiagramRect Frame, double Score)? best = null;
        var segments = new List<(DiagramPoint A, DiagramPoint B)>();
        var cursor = points.Count == 0 ? new DiagramPoint() : points[0];
        foreach (var command in ScenePaths.Edge(points))
        {
            switch (command)
            {
                case PathCommand.Line line: segments.Add((cursor, line.Point)); cursor = line.Point; break;
                case PathCommand.Move move: cursor = move.Point; break;
                case PathCommand.Quadratic quadratic: cursor = quadratic.End; break;
                case PathCommand.Cubic cubic: cursor = cubic.End; break;
            }
        }
        foreach (var (a, b) in segments)
        {
            var length = a.DistanceTo(b); if (length <= .01) continue;
            var extent = Math.Abs(b.X - a.X) > Math.Abs(b.Y - a.Y) ? size.Width : size.Height;
            foreach (var t in new[] { .5, .35, .65, .2, .8, .3, .7, .25, .75, .15, .85, .1, .9 })
            {
                var center = new DiagramPoint(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t);
                var r = new DiagramRect(center.X - size.Width / 2, center.Y - size.Height / 2, size.Width, size.Height);
                var collisions = obstacles.Count(obstacle => obstacle.Intersects(r));
                var overlap = obstacles.Sum(obstacle => { var area = obstacle.Intersection(r); return area.Width * area.Height; }) / Math.Max(1, r.Width * r.Height);
                var crossings = otherRoutes.Count(route => route.Any(segment => !EdgeGeometry.Clear(segment.A, segment.B, [r.Inset(-6, -6)])));
                var outside = domain is { } bounds && !bounds.Contains(r) ? 1 : 0;
                var clearance = Math.Min(length * t, length * (1 - t)) - extent / 2;
                var score = collisions * 100_000 + crossings * 20_000 + outside * 10_000 + overlap * 10_000
                    + Math.Max(0, 16 - clearance) * 100 + Math.Abs(t - .5) * 40 - Math.Min(length, 300) * .02;
                if (best is null || score < best.Value.Score) best = (r, score);
            }
        }
        return best?.Frame ?? new(points.Count == 0 ? 0 : points[0].X, points.Count == 0 ? 0 : points[0].Y, size.Width, size.Height);
    }
}
