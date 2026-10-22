using System.Collections.Immutable;

namespace NornaKit;

public static class ScenePaths
{
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
