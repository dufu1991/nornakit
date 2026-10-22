using System.Numerics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using global::Windows.Foundation;
using global::Windows.UI;

namespace NornaKit.Windows;

public static class Win2DScenePainter
{
    public static void Draw(CanvasDrawingSession drawing, DiagramScene scene, DiagramPalette palette)
    {
        foreach (var primitive in scene.Primitives)
        {
            if (primitive.Geometry is VectorGeometry.Text text)
            {
                foreach (var run in text.Layout.Runs)
                {
                    var color = Native(run.Style.Color ?? palette.Resolve(text.Color), primitive.Style.Opacity);
                    using var glyphs = Geometry(drawing, run.GlyphPath);
                    var origin = text.Origin.Offset(run.Baseline.X, run.Baseline.Y);
                    drawing.FillGeometry(glyphs, new Vector2((float)origin.X, (float)origin.Y), color);
                    if (run.Style.Underline) drawing.DrawLine((float)origin.X, (float)(origin.Y + run.Style.Size * .12),
                        (float)(origin.X + run.Width), (float)(origin.Y + run.Style.Size * .12), color, 1);
                    if (run.Style.Strikethrough) drawing.DrawLine((float)origin.X, (float)(origin.Y - run.Style.Size * .3),
                        (float)(origin.X + run.Width), (float)(origin.Y - run.Style.Size * .3), color, 1);
                }
                continue;
            }
            using var geometry = Geometry(drawing, ScenePaths.Geometry(primitive.Geometry));
            var style = primitive.Style;
            if (style.Fill.Role != SceneColorRole.None) drawing.FillGeometry(geometry, Native(palette.Resolve(style.Fill), style.Opacity));
            if (style.Stroke.Role != SceneColorRole.None && style.LineWidth > 0)
            {
                using var stroke = new CanvasStrokeStyle
                {
                    StartCap = CanvasCapStyle.Round, EndCap = CanvasCapStyle.Round, LineJoin = CanvasLineJoin.Round
                };
                if (!style.Dash.IsEmpty) stroke.CustomDashStyle = style.Dash.Select(value => (float)(value / style.LineWidth)).ToArray();
                drawing.DrawGeometry(geometry, Native(palette.Resolve(style.Stroke), style.Opacity), (float)style.LineWidth, stroke);
            }
        }
    }

    internal static CanvasGeometry Geometry(ICanvasResourceCreator creator, IEnumerable<PathCommand> commands)
    {
        using var builder = new CanvasPathBuilder(creator);
        var active = false;
        foreach (var command in commands)
        {
            switch (command)
            {
                case PathCommand.Move move:
                    if (active) builder.EndFigure(CanvasFigureLoop.Open);
                    builder.BeginFigure((float)move.Point.X, (float)move.Point.Y);
                    active = true;
                    break;
                case PathCommand.Line line: builder.AddLine((float)line.Point.X, (float)line.Point.Y); break;
                case PathCommand.Quadratic quadratic: builder.AddQuadraticBezier(V(quadratic.Control), V(quadratic.End)); break;
                case PathCommand.Cubic cubic: builder.AddCubicBezier(V(cubic.Control1), V(cubic.Control2), V(cubic.End)); break;
                case PathCommand.Close:
                    builder.EndFigure(CanvasFigureLoop.Closed);
                    active = false;
                    break;
            }
        }
        if (active) builder.EndFigure(CanvasFigureLoop.Open);
        return CanvasGeometry.CreatePath(builder);
    }

    internal static Color Native(DiagramColor color, double opacity = 1)
        => Color.FromArgb((byte)Math.Round(color.A * opacity), color.R, color.G, color.B);
    private static Vector2 V(DiagramPoint point) => new((float)point.X, (float)point.Y);
}
