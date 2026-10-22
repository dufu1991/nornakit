using System.Globalization;

namespace NornaKit;

public readonly record struct DiagramPoint(double X, double Y)
{
    public DiagramPoint Offset(double x, double y) => new(X + x, Y + y);
    public double DistanceTo(DiagramPoint other) => double.Hypot(X - other.X, Y - other.Y);
}

public readonly record struct DiagramSize(double Width, double Height);

public readonly record struct DiagramRect(double X, double Y, double Width, double Height)
{
    public double Left => X;
    public double Top => Y;
    public double Right => X + Width;
    public double Bottom => Y + Height;
    public DiagramPoint Center => new(X + Width / 2, Y + Height / 2);
    public bool IsFinite => double.IsFinite(X) && double.IsFinite(Y)
        && double.IsFinite(Width) && double.IsFinite(Height);
    public DiagramRect Offset(double x, double y) => this with { X = X + x, Y = Y + y };
    public DiagramRect Inset(double x, double y) => new(X + x, Y + y, Width - 2 * x, Height - 2 * y);
    public bool Contains(DiagramPoint point) => point.X >= Left && point.X <= Right
        && point.Y >= Top && point.Y <= Bottom;
    public bool Intersects(DiagramRect other) => Left < other.Right && Right > other.Left
        && Top < other.Bottom && Bottom > other.Top;
    public DiagramRect Union(DiagramRect other) => new(Math.Min(Left, other.Left), Math.Min(Top, other.Top),
        Math.Max(Right, other.Right) - Math.Min(Left, other.Left),
        Math.Max(Bottom, other.Bottom) - Math.Min(Top, other.Top));
}

public abstract record PathCommand
{
    public sealed record Move(DiagramPoint Point) : PathCommand;
    public sealed record Line(DiagramPoint Point) : PathCommand;
    public sealed record Quadratic(DiagramPoint Control, DiagramPoint End) : PathCommand;
    public sealed record Cubic(DiagramPoint Control1, DiagramPoint Control2, DiagramPoint End) : PathCommand;
    public sealed record Close : PathCommand;
}

internal static class DiagramNumber
{
    public static string Format(double value) => value.ToString("0.########", CultureInfo.InvariantCulture);
}
