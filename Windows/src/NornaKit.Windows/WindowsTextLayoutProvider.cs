using System.Collections.Immutable;
using System.Numerics;
using System.Runtime.ExceptionServices;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.Text;
using global::Windows.UI.Text;

namespace NornaKit.Windows;

public sealed partial class WindowsTextLayoutProvider(CanvasDevice device) : ITextLayoutProvider
{
    internal Func<CanvasFontFace, FontFaceReference> ResolveFont { get; init; } = NativeFontFiles.Resolve;
    public PreparedText Layout(TextLayoutRequest request, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!double.IsFinite(request.MaxWidth) || request.MaxWidth <= 0
            || !double.IsFinite(request.LineHeight) || request.LineHeight <= 0)
            throw new ArgumentOutOfRangeException(nameof(request));
        var text = string.Concat(request.Runs.Select(run => run.IconName is null ? run.Text : WindowsIcons.Glyph(run.IconName) ?? run.Text));
        if (text.Length == 0) return new(new(0, request.LineHeight), []);
        using var format = new CanvasTextFormat
        {
            FontFamily = "Segoe UI", FontSize = 16,
            WordWrapping = CanvasWordWrapping.Wrap,
            HorizontalAlignment = request.Alignment switch
            {
                TextAlignment.Center => CanvasHorizontalAlignment.Center,
                TextAlignment.Trailing => CanvasHorizontalAlignment.Right,
                _ => CanvasHorizontalAlignment.Left
            }
        };
        using var layout = new CanvasTextLayout(device, text, format, (float)request.MaxWidth, 250_000);
        layout.LineSpacing = (float)request.LineHeight;
        layout.LineSpacingBaseline = (float)(request.LineHeight * .8);
        var ranges = new List<(int Start, int Length, InlineRun Run)>();
        var start = 0;
        foreach (var run in request.Runs)
        {
            var glyph = run.IconName is null ? null : WindowsIcons.Glyph(run.IconName);
            var length = glyph is null ? run.Text.Length : glyph.Length;
            if (length == 0) continue;
            ranges.Add((start, length, run));
            layout.SetFontFamily(start, length, glyph is not null ? "Segoe Fluent Icons" : run.Style.Monospace ? "Consolas" : "Segoe UI");
            layout.SetFontSize(start, length, (float)run.Style.Size);
            layout.SetFontWeight(start, length, new FontWeight { Weight = (ushort)(run.Style.Bold ? 700 : 400) });
            layout.SetFontStyle(start, length, run.Style.Italic ? FontStyle.Italic : FontStyle.Normal);
            // A distinct brush forces DirectWrite to keep formatting boundaries in its glyph callbacks.
            layout.SetColor(start, length, global::Windows.UI.Color.FromArgb(255, (byte)(ranges.Count >> 16), (byte)(ranges.Count >> 8), (byte)ranges.Count));
            start += length;
        }
        var receiver = new TextReceiver(device, ranges, text, ResolveFont, cancellationToken);
        var bounds = layout.LayoutBoundsIncludingTrailingWhitespace;
        layout.DrawToTextRenderer(receiver, 0, 0);
        receiver.Failure?.Throw();
        if (receiver.Runs.Count == 0 && !string.IsNullOrWhiteSpace(text))
            throw new DiagramRenderException("DirectWrite produced no glyph runs for nonempty text.", "layout");
        return new(new(Math.Max(0, bounds.Width), Math.Max(request.LineHeight, bounds.Height)), receiver.Runs.ToImmutableArray());
    }

    [WinRT.GeneratedWinRTExposedType]
    private sealed partial class TextReceiver(CanvasDevice device, List<(int Start, int Length, InlineRun Run)> ranges,
        string content, Func<CanvasFontFace, FontFaceReference> resolveFont, CancellationToken cancellationToken) : ICanvasTextRenderer
    {
        public List<PreparedTextRun> Runs { get; } = [];
        public ExceptionDispatchInfo? Failure { get; private set; }
        public bool PixelSnappingDisabled => true;
        public Matrix3x2 Transform => Matrix3x2.Identity;
        public float Dpi => 96;

        public void DrawGlyphRun(Vector2 point, CanvasFontFace fontFace, float fontSize, CanvasGlyph[] glyphs,
            bool isSideways, uint bidiLevel, object brush, CanvasTextMeasuringMode measuringMode, string localeName,
            string textString, int[] clusterMapIndices, uint characterIndex, CanvasGlyphOrientation glyphOrientation)
        {
            if (Failure is not null) return;
            // Preserve callback failures explicitly; native rendering can otherwise return an empty result.
            try
            {
                cancellationToken.ThrowIfCancellationRequested();
                var source = ranges.First(range => characterIndex >= range.Start && characterIndex < range.Start + range.Length).Run;
                var font = resolveFont(fontFace);
                var receiver = new GeometryReceiver();
                if (glyphs.Length > 0)
                {
                    using var geometry = CanvasGeometry.CreateGlyphRun(device, Vector2.Zero, fontFace, fontSize,
                        glyphs, isSideways, bidiLevel, measuringMode, glyphOrientation);
                    using var simplified = geometry.Simplify(CanvasGeometrySimplification.CubicsAndLines);
                    simplified.SendPathTo(receiver);
                }
                // Win2D can return the remainder of the source; the cluster map defines the actual run length.
                var runText = content.Substring(checked((int)characterIndex), clusterMapIndices.Length);
                Runs.Add(new(runText, source.Style with { Size = fontSize }, font, new(point.X, point.Y),
                    glyphs.Sum(glyph => glyph.Advance),
                    glyphs.Select(glyph => new PreparedGlyph(glyph.Index, glyph.Advance, glyph.AdvanceOffset, glyph.AscenderOffset)).ToImmutableArray(),
                    clusterMapIndices.ToImmutableArray(), bidiLevel, receiver.Commands.ToImmutableArray(),
                    source.IconName is not null && WindowsIcons.Glyph(source.IconName) is not null));
            }
            catch (Exception exception)
            {
                exception.Data["CharacterIndex"] = characterIndex;
                exception.Data["GlyphCount"] = glyphs.Length;
                exception.Data["FontSize"] = fontSize;
                exception.Data["GlyphOrientation"] = glyphOrientation.ToString();
                exception.Data["Glyphs"] = string.Join(';', glyphs.Select(glyph => $"{glyph.Index}:{glyph.Advance}"));
                Failure = ExceptionDispatchInfo.Capture(exception);
            }
        }

        public void DrawStrikethrough(Vector2 point, float width, float thickness, float offset,
            CanvasTextDirection direction, object brush, CanvasTextMeasuringMode measuringMode,
            string localeName, CanvasGlyphOrientation orientation) { }
        public void DrawUnderline(Vector2 point, float width, float thickness, float offset, float runHeight,
            CanvasTextDirection direction, object brush, CanvasTextMeasuringMode measuringMode,
            string localeName, CanvasGlyphOrientation orientation) { }
        public void DrawInlineObject(Vector2 point, ICanvasTextInlineObject inlineObject, bool sideways,
            bool rightToLeft, object brush, CanvasGlyphOrientation orientation)
            => throw new DiagramRenderException("Unexpected native inline object.", "layout");
    }
}

[WinRT.GeneratedWinRTExposedType]
internal sealed partial class GeometryReceiver : ICanvasPathReceiver
{
    public List<PathCommand> Commands { get; } = [];
    private static DiagramPoint Point(Vector2 point) => new(point.X, point.Y);
    public void BeginFigure(Vector2 startPoint, CanvasFigureFill figureFill) => Commands.Add(new PathCommand.Move(Point(startPoint)));
    public void AddLine(Vector2 endPoint) => Commands.Add(new PathCommand.Line(Point(endPoint)));
    public void AddQuadraticBezier(Vector2 controlPoint, Vector2 endPoint) => Commands.Add(new PathCommand.Quadratic(Point(controlPoint), Point(endPoint)));
    public void AddCubicBezier(Vector2 controlPoint1, Vector2 controlPoint2, Vector2 endPoint)
        => Commands.Add(new PathCommand.Cubic(Point(controlPoint1), Point(controlPoint2), Point(endPoint)));
    public void EndFigure(CanvasFigureLoop figureLoop)
    {
        if (figureLoop == CanvasFigureLoop.Closed) Commands.Add(new PathCommand.Close());
    }
    public void SetFilledRegionDetermination(CanvasFilledRegionDetermination filledRegionDetermination) { }
    public void SetSegmentOptions(CanvasFigureSegmentOptions figureSegmentOptions) { }
    public void AddArc(Vector2 endPoint, float radiusX, float radiusY, float rotationAngle,
        CanvasSweepDirection sweepDirection, CanvasArcSize arcSize)
        => throw new InvalidOperationException("Geometry must be simplified before reading its paths.");
    public void Close() { }
}
