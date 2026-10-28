using System.Collections.Immutable;

namespace NornaKit;

public readonly record struct DiagramColor(byte R, byte G, byte B, byte A = 255)
{
    public string Hex => $"#{R:x2}{G:x2}{B:x2}";
    public static DiagramColor FromHex(string value)
    {
        var digits = value.StartsWith('#') ? value.AsSpan(1) : value.AsSpan();
        if (digits.Length != 6 || !uint.TryParse(digits, System.Globalization.NumberStyles.HexNumber,
            System.Globalization.CultureInfo.InvariantCulture, out var rgb))
            throw new ArgumentException("A color must contain exactly six hexadecimal digits.", nameof(value));
        return new((byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb);
    }
}

public enum SceneColorRole { None, Background, Foreground, Muted, Line, Surface, SurfaceAlt, Border, Accent, Series, OnSeries, Literal }
public readonly record struct SceneColor(SceneColorRole Role, int Index = 0, DiagramColor Value = default)
{
    public static SceneColor Literal(DiagramColor value) => new(SceneColorRole.Literal, Value: value);
}

public sealed record DiagramPalette(
    DiagramColor Background, DiagramColor Foreground, DiagramColor Muted, DiagramColor Line,
    DiagramColor Surface, DiagramColor SurfaceAlt, DiagramColor Border, DiagramColor Accent,
    ImmutableArray<DiagramColor> Series)
{
    public DiagramColor Resolve(SceneColor color) => color.Role switch
    {
        SceneColorRole.None => new(0, 0, 0, 0),
        SceneColorRole.Background => Background,
        SceneColorRole.Foreground => Foreground,
        SceneColorRole.Muted => Muted,
        SceneColorRole.Line => Line,
        SceneColorRole.Surface => Surface,
        SceneColorRole.SurfaceAlt => SurfaceAlt,
        SceneColorRole.Border => Border,
        SceneColorRole.Accent => Accent,
        SceneColorRole.Literal => color.Value,
        SceneColorRole.Series => Series[((color.Index % Series.Length) + Series.Length) % Series.Length],
        SceneColorRole.OnSeries => Contrast(Resolve(new(SceneColorRole.Series, color.Index))),
        _ => throw new ArgumentOutOfRangeException(nameof(color))
    };

    private static DiagramColor Contrast(DiagramColor color)
    {
        var linear = (byte value) => value / 255d <= .04045 ? value / 255d / 12.92 : Math.Pow((value / 255d + .055) / 1.055, 2.4);
        var luminance = .2126 * linear(color.R) + .7152 * linear(color.G) + .0722 * linear(color.B);
        return (luminance + .05) / .05 >= 1.05 / (luminance + .05) ? new(0, 0, 0) : new(255, 255, 255);
    }
}

public sealed record VectorStyle
{
    public SceneColor Fill { get; init; } = new(SceneColorRole.None);
    public SceneColor Stroke { get; init; } = new(SceneColorRole.Border);
    public double LineWidth { get; init; } = 1;
    public ImmutableArray<double> Dash { get; init; } = [];
    public double Opacity { get; init; } = 1;
}

public abstract record VectorGeometry
{
    public sealed record Rectangle(DiagramRect Frame, double Radius = 8) : VectorGeometry;
    public sealed record Ellipse(DiagramRect Frame) : VectorGeometry;
    public sealed record Path(ImmutableArray<PathCommand> Commands) : VectorGeometry;
    public sealed record Text(PreparedText Layout, DiagramPoint Origin, SceneColor Color) : VectorGeometry;
}

public sealed record ScenePrimitive(VectorGeometry Geometry, VectorStyle Style, string? Id = null, string Label = "");
public sealed record DiagramScene(DiagramSize Size, string Kind, ImmutableArray<ScenePrimitive> Primitives)
{
    public ImmutableArray<SceneNode> Nodes { get; init; } = [];
    public ImmutableArray<SceneEdge> Edges { get; init; } = [];
    public ImmutableArray<SceneGroup> Groups { get; init; } = [];
}
public sealed record DiagramArtifact(DiagramScene Scene)
{
    public double Width => Scene.Size.Width;
    public double Height => Scene.Size.Height;
    public string Type => Scene.Kind;
}
