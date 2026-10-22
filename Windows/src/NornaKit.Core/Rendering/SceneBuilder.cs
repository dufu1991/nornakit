using System.Collections.Immutable;

namespace NornaKit;

internal static class DiagramStyle
{
    public const double FontSize = 16, LineHeight = 22, EdgeFontSize = 12, EdgeLineHeight = 18;
    public const double NodeSeparation = 40, RankSeparation = 48, GroupPadding = 20, CornerRadius = 8, ScenePadding = 8;
}
internal static class C
{
    public static readonly SceneColor None = new(SceneColorRole.None), Background = new(SceneColorRole.Background),
        Foreground = new(SceneColorRole.Foreground), Muted = new(SceneColorRole.Muted), Line = new(SceneColorRole.Line),
        Surface = new(SceneColorRole.Surface), SurfaceAlt = new(SceneColorRole.SurfaceAlt), Border = new(SceneColorRole.Border), Accent = new(SceneColorRole.Accent);
    public static SceneColor Series(int index) => new(SceneColorRole.Series, index);
    public static SceneColor OnSeries(int index) => new(SceneColorRole.OnSeries, index);
}

internal sealed class TextMeasurement(ITextLayoutProvider provider, CancellationToken cancellationToken)
{
    private readonly Dictionary<(string, double, double, bool, bool, TextAlignment, double), PreparedText> cache = [];
    public PreparedText Layout(string text, double maxWidth = 200, double size = 16, bool bold = false, bool mono = false,
        TextAlignment alignment = TextAlignment.Leading, double? lineHeight = null)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var height = lineHeight ?? size * 1.4;
        var key = (text, maxWidth, size, bold, mono, alignment, height);
        if (cache.TryGetValue(key, out var result)) return result;
        result = provider.Layout(new(InlineText.Parse(text, new(size, bold, Monospace: mono)), maxWidth, alignment, height), cancellationToken);
        cache.Add(key, result); return result;
    }
    public double Width(string text, double size = 16, bool bold = false, bool mono = false) => Layout(text, 250_000, size, bold, mono).Size.Width;
    public ImmutableArray<string> Lines(string text, double maxWidth = 200, double size = 16, bool bold = false, bool mono = false)
    {
        var layout = Layout(text, maxWidth, size, bold, mono);
        var lines = layout.Runs.GroupBy(run => Math.Round(run.Baseline.Y, 3)).OrderBy(group => group.Key)
            .Select(group => string.Concat(group.Select(run => run.Text))).ToImmutableArray();
        return lines.IsEmpty ? [""] : lines;
    }
    public DiagramSize NodeSize(ImmutableArray<string> lines, NodeShape shape)
    {
        var width = lines.Select(line => Width(line)).DefaultIfEmpty(0).Max();
        var height = lines.Length * DiagramStyle.LineHeight;
        return NodeSize(width, height, shape);
    }
    public DiagramSize NodeSize(string label, double maxWidth, NodeShape shape)
    {
        var layout = Layout(label, maxWidth, lineHeight: DiagramStyle.LineHeight);
        var count = Math.Max(1, layout.Runs.Select(run => Math.Round(run.Baseline.Y, 3)).Distinct().Count());
        return NodeSize(layout.Size.Width, count * DiagramStyle.LineHeight, shape);
    }
    private static DiagramSize NodeSize(double width, double height, NodeShape shape)
    {
        return shape switch
        {
            NodeShape.Diamond => new(width + 16 + 1.6 * (height + 8), (width + 16) / 1.6 + height + 8),
            NodeShape.Circle or NodeShape.DoubleCircle => CircleSize(width, height, shape),
            NodeShape.Hexagon or NodeShape.Asymmetric or NodeShape.Parallelogram or NodeShape.ParallelogramAlt or NodeShape.Trapezoid or NodeShape.TrapezoidAlt => new(Math.Max(80, (width + 36) / .6), height + 32),
            NodeShape.Ellipse => new(Math.Max(100, (width + 24) * 1.42), Math.Max(50, (height + 12) * 1.42)),
            NodeShape.Stadium => new(width + (height + 24) * .5 + 28, height + 24),
            NodeShape.Cylinder => new(Math.Max(56, width + 36), height + 24 + 2 * Math.Min(12, Math.Max(6, Math.Max(56, width + 36) / 14))),
            NodeShape.Subroutine => new(width + 52, height + 24),
            _ => new(Math.Max(48, width + 36), height + 24)
        };
    }
    private static DiagramSize CircleSize(double width, double height, NodeShape shape)
    { var diameter = Math.Max(44, double.Hypot(width, height) + (shape == NodeShape.DoubleCircle ? 28 : 16)); return new(diameter, diameter); }
}

internal sealed class SceneBuilder(DiagramKind kind, TextMeasurement measurement)
{
    public List<ScenePrimitive> Primitives { get; } = [];
    public void Rect(DiagramRect frame, SceneColor? fill = null, SceneColor? stroke = null, double radius = 8,
        double opacity = 1, double[]? dash = null, string? id = null, string label = "")
        => Primitives.Add(new(new VectorGeometry.Rectangle(frame, radius), new() { Fill = fill ?? C.Surface, Stroke = stroke ?? C.Border, Opacity = opacity, Dash = dash?.ToImmutableArray() ?? [] }, id, label));
    public void Ellipse(DiagramRect frame, SceneColor? fill = null, SceneColor? stroke = null, double opacity = 1, string? id = null, string label = "")
        => Primitives.Add(new(new VectorGeometry.Ellipse(frame), new() { Fill = fill ?? C.Surface, Stroke = stroke ?? C.Border, Opacity = opacity }, id, label));
    public void Path(IEnumerable<PathCommand> commands, SceneColor? fill = null, SceneColor? stroke = null,
        double width = 1, double[]? dash = null, double opacity = 1, string? id = null)
        => Primitives.Add(new(new VectorGeometry.Path(commands.ToImmutableArray()), new() { Fill = fill ?? C.None, Stroke = stroke ?? C.Line,
            LineWidth = width, Dash = dash?.ToImmutableArray() ?? [], Opacity = opacity }, id));
    public void Line(IEnumerable<DiagramPoint> values, SceneColor? color = null, double width = 1, double[]? dash = null,
        bool arrow = false, bool open = false, string? id = null)
    {
        var points = values.ToArray();
        Path(ScenePaths.Edge(points), stroke: color ?? C.Line, width: width, dash: dash, id: id);
        if (!arrow || points.Length < 2) return;
        if (open)
        {
            var triangle = ScenePaths.Arrow(points);
            if (triangle.Length >= 3 && triangle[1] is PathCommand.Line a && triangle[2] is PathCommand.Line b)
                Path([new PathCommand.Move(a.Point), new PathCommand.Line(points[^1]), new PathCommand.Line(b.Point)], stroke: color ?? C.Line);
        }
        else Path(ScenePaths.Arrow(points), fill: color ?? C.Line, stroke: C.None);
    }
    public void Text(string text, DiagramRect frame, double size = 16, SceneColor? color = null,
        TextAlignment align = TextAlignment.Center, bool bold = false, bool mono = false, bool shrink = true, double? lineHeight = null)
    {
        var label = DiagramSyntax.Label(text);
        var width = Math.Max(8, frame.Width);
        var lines = measurement.Lines(label, width, size, bold, mono);
        var font = shrink ? Math.Min(size, Math.Max(8, frame.Height / Math.Max(1, lines.Length) / 1.4)) : size;
        var layout = measurement.Layout(label, width, font, bold, mono, align, lineHeight);
        Primitives.Add(new(new VectorGeometry.Text(layout, new(frame.X, frame.Y + (frame.Height - layout.Size.Height) / 2), color ?? C.Foreground), new()));
    }
    public void Box(string text, DiagramRect frame, SceneColor? fill = null, double radius = 8, string? id = null, double size = 16)
    { Rect(frame, fill, radius: radius, id: id, label: text); Text(text, frame.Inset(8, 6), size); }
    public double Title(string text, double width)
    { if (text.Length == 0) return 16; Text(text, new(16, 12, width - 32, 32), 20, bold: true); return 60; }
    public DiagramScene Build(double width, double height)
    {
        var bounds = SceneGeometry.Bounds(Primitives);
        var dx = bounds is null ? 0 : Math.Max(0, 8 - bounds.Value.Left);
        var dy = bounds is null ? 0 : Math.Max(0, 8 - bounds.Value.Top);
        return new(new(Math.Max(32, Math.Max(width, bounds?.Right + 8 ?? 0) + dx), Math.Max(32, Math.Max(height, bounds?.Bottom + 8 ?? 0) + dy)),
            kind.Id(), Primitives.Select(primitive => primitive with { Geometry = SceneGeometry.Offset(primitive.Geometry, dx, dy) }).ToImmutableArray());
    }
}

internal static class SceneGeometry
{
    public static VectorGeometry Offset(VectorGeometry geometry, double x, double y) => geometry switch
    {
        VectorGeometry.Rectangle rectangle => rectangle with { Frame = rectangle.Frame.Offset(x, y) },
        VectorGeometry.Ellipse ellipse => ellipse with { Frame = ellipse.Frame.Offset(x, y) },
        VectorGeometry.Text text => text with { Origin = text.Origin.Offset(x, y) },
        VectorGeometry.Path path => path with { Commands = path.Commands.Select(command => Offset(command, x, y)).ToImmutableArray() },
        _ => throw new ArgumentOutOfRangeException(nameof(geometry))
    };
    public static PathCommand Offset(PathCommand command, double x, double y) => command switch
    {
        PathCommand.Move move => new PathCommand.Move(move.Point.Offset(x, y)), PathCommand.Line line => new PathCommand.Line(line.Point.Offset(x, y)),
        PathCommand.Quadratic quadratic => new PathCommand.Quadratic(quadratic.Control.Offset(x, y), quadratic.End.Offset(x, y)),
        PathCommand.Cubic cubic => new PathCommand.Cubic(cubic.Control1.Offset(x, y), cubic.Control2.Offset(x, y), cubic.End.Offset(x, y)),
        PathCommand.Close => command, _ => throw new ArgumentOutOfRangeException(nameof(command))
    };
    public static DiagramRect? Bounds(IEnumerable<ScenePrimitive> primitives)
    {
        DiagramRect? bounds = null;
        foreach (var primitive in primitives)
        {
            var rect = Bounds(primitive.Geometry);
            if (rect is not null) bounds = bounds?.Union(rect.Value) ?? rect;
        }
        return bounds;
    }
    public static DiagramRect? Bounds(VectorGeometry geometry) => geometry switch
    {
        VectorGeometry.Rectangle rectangle => rectangle.Frame,
        VectorGeometry.Ellipse ellipse => ellipse.Frame,
        VectorGeometry.Text text => TextBounds(text),
        VectorGeometry.Path path => PointBounds(path.Commands.SelectMany(command => command switch
        {
            PathCommand.Move move => new[] { move.Point }, PathCommand.Line line => [line.Point],
            PathCommand.Quadratic quadratic => [quadratic.Control, quadratic.End],
            PathCommand.Cubic cubic => [cubic.Control1, cubic.Control2, cubic.End], _ => []
        })),
        _ => throw new ArgumentOutOfRangeException(nameof(geometry))
    };
    private static DiagramRect TextBounds(VectorGeometry.Text text)
    {
        var left = Math.Min(0, text.Layout.Runs.Select(run => (run.BidiLevel & 1) == 0 ? run.Baseline.X : run.Baseline.X - run.Width).DefaultIfEmpty(0).Min());
        var right = Math.Max(text.Layout.Size.Width, text.Layout.Runs.Select(run => (run.BidiLevel & 1) == 0 ? run.Baseline.X + run.Width : run.Baseline.X).DefaultIfEmpty(0).Max());
        return new(text.Origin.X + left, text.Origin.Y, right - left, text.Layout.Size.Height);
    }
    public static DiagramRect? PointBounds(IEnumerable<DiagramPoint> values)
    {
        var points = values.ToArray();
        if (points.Length == 0) return null;
        var x = points.Min(point => point.X); var y = points.Min(point => point.Y);
        return new(x, y, points.Max(point => point.X) - x, points.Max(point => point.Y) - y);
    }
}
