using System.Security;
using System.Text;

namespace NornaKit;

public static class SvgExporter
{
    public static string Export(DiagramScene scene, DiagramPalette palette, DiagramExportOptions? options = null)
    {
        options ??= new(Format: DiagramExportFormat.Svg, Padding: 0);
        var size = (options with { Format = DiagramExportFormat.Svg }).OutputSize(scene);
        var output = new StringBuilder();
        output.Append($"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{N(size.Width)}\" height=\"{N(size.Height)}\" viewBox=\"{N(-options.Padding)} {N(-options.Padding)} {N(size.Width)} {N(size.Height)}\" role=\"img\"><title>{Escape(scene.Kind)}</title>");
        if (options.Background == DiagramExportBackground.Theme)
            output.Append($"<rect x=\"{N(-options.Padding)}\" y=\"{N(-options.Padding)}\" width=\"{N(size.Width)}\" height=\"{N(size.Height)}\" fill=\"{palette.Background.Hex}\"/>");
        foreach (var primitive in scene.Primitives)
        {
            output.Append($"<g opacity=\"{N(primitive.Style.Opacity)}\"");
            if (primitive.Id is not null) output.Append($" data-id=\"{Escape(primitive.Id)}\"");
            output.Append('>');
            if (primitive.Label.Length != 0) output.Append($"<title>{Escape(primitive.Label)}</title>");
            if (primitive.Geometry is VectorGeometry.Text text)
            {
                foreach (var run in text.Layout.Runs)
                {
                    var color = run.Style.Color ?? palette.Resolve(text.Color);
                    var x = text.Origin.X + run.Baseline.X;
                    var y = text.Origin.Y + run.Baseline.Y;
                    if (run.IsIcon)
                        output.Append($"<path transform=\"translate({N(x)} {N(y)})\" fill=\"{color.Hex}\" d=\"{Path(run.GlyphPath)}\"/>");
                    else
                    {
                        var decoration = string.Join(' ', new[] { run.Style.Underline ? "underline" : "", run.Style.Strikethrough ? "line-through" : "" }.Where(value => value.Length != 0));
                        var direction = (run.BidiLevel & 1) != 0 ? " direction=\"rtl\" unicode-bidi=\"isolate\"" : "";
                        output.Append($"<text x=\"{N(x)}\" y=\"{N(y)}\" xml:space=\"preserve\"{direction} font-family=\"{Escape(run.Font.Family)}\" font-size=\"{N(run.Style.Size)}\" font-weight=\"{(run.Style.Bold ? 700 : 400)}\" font-style=\"{(run.Style.Italic ? "italic" : "normal")}\" text-decoration=\"{decoration}\" fill=\"{color.Hex}\">{Escape(run.Text)}</text>");
                    }
                }
            }
            else
            {
                var fill = palette.Resolve(primitive.Style.Fill);
                var stroke = palette.Resolve(primitive.Style.Stroke);
                var dash = primitive.Style.Dash.IsEmpty ? "" : $" stroke-dasharray=\"{string.Join(' ', primitive.Style.Dash.Select(N))}\"";
                output.Append($"<path d=\"{Path(ScenePaths.Geometry(primitive.Geometry))}\" fill=\"{(fill.A == 0 ? "none" : fill.Hex)}\" stroke=\"{(stroke.A == 0 ? "none" : stroke.Hex)}\" stroke-width=\"{N(primitive.Style.LineWidth)}\" stroke-linecap=\"round\" stroke-linejoin=\"round\"{dash}/>");
            }
            output.Append("</g>");
        }
        output.Append("</svg>");
        if (Encoding.UTF8.GetByteCount(output.ToString()) > 4_000_000) throw new DiagramRenderException("SVG 输出超过 4 MB。", "limit");
        return output.ToString();
    }

    public static string Path(IEnumerable<PathCommand> commands) => string.Join(' ', commands.Select(command => command switch
    {
        PathCommand.Move move => $"M {P(move.Point)}",
        PathCommand.Line line => $"L {P(line.Point)}",
        PathCommand.Quadratic quadratic => $"Q {P(quadratic.Control)} {P(quadratic.End)}",
        PathCommand.Cubic cubic => $"C {P(cubic.Control1)} {P(cubic.Control2)} {P(cubic.End)}",
        PathCommand.Close => "Z",
        _ => throw new ArgumentOutOfRangeException(nameof(commands))
    }));
    private static string Escape(string text) => SecurityElement.Escape(text)!;
    private static string P(DiagramPoint point) => $"{N(point.X)} {N(point.Y)}";
    private static string N(double value) => DiagramNumber.Format(value);
}
