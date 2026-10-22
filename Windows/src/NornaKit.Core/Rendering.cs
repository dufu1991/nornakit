using System.Collections.Immutable;

namespace NornaKit;

public sealed class DiagramRenderException(string message, string code, int? line = null, int? column = null)
    : Exception(message)
{
    public string Code { get; } = code;
    public int? Line { get; } = line;
    public int? Column { get; } = column;
}

public sealed record DiagramLayoutOptions(double? MaxWidth = null, bool AutoDirection = true, double DirectionBreakpoint = 640)
{
    public void Validate()
    {
        if (MaxWidth is { } width && (!double.IsFinite(width) || width is < 160 or > 250_000)
            || !double.IsFinite(DirectionBreakpoint) || DirectionBreakpoint is < 160 or > 250_000)
            throw new DiagramRenderException("Layout width and direction breakpoint must be finite values from 160 to 250000.", "limit");
    }
}

public interface IDiagramRenderer
{
    Task<DiagramArtifact> RenderAsync(string source, DiagramLayoutOptions? options = null,
        CancellationToken cancellationToken = default);
}

public sealed record TextStyle(double Size = 16, bool Bold = false, bool Italic = false, bool Monospace = false,
    bool Underline = false, bool Strikethrough = false, DiagramColor? Color = null);
public sealed record InlineRun(string Text, TextStyle Style, string? IconName = null);
public enum TextAlignment { Leading, Center, Trailing }

public sealed record TextLayoutRequest(ImmutableArray<InlineRun> Runs, double MaxWidth,
    TextAlignment Alignment = TextAlignment.Leading, double LineHeight = 24);

/// <summary>Identifies the exact font face selected by the native text layout engine.</summary>
public sealed record FontFaceReference(string Family, string FilePath, int FaceIndex = 0, bool Bold = false, bool Italic = false);

public readonly record struct PreparedGlyph(int Index, double Advance, double AdvanceOffset, double AscenderOffset);

public sealed record PreparedTextRun(string Text, TextStyle Style, FontFaceReference Font,
    DiagramPoint Baseline, double Width, ImmutableArray<PreparedGlyph> Glyphs,
    ImmutableArray<int> ClusterMap, uint BidiLevel, ImmutableArray<PathCommand> GlyphPath, bool IsIcon = false);

/// <summary>Immutable positioned runs shared by preview, bitmap, SVG and PDF export.</summary>
public sealed record PreparedText(DiagramSize Size, ImmutableArray<PreparedTextRun> Runs);

public interface ITextLayoutProvider
{
    PreparedText Layout(TextLayoutRequest request, CancellationToken cancellationToken = default);
}
