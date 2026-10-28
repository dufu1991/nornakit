namespace NornaKit;

public enum DiagramExportFormat { Png, Jpeg, Tiff, Svg, Pdf }
public enum DiagramExportBackground { Theme, Transparent }

public sealed record DiagramExportOptions(DiagramExportFormat Format = DiagramExportFormat.Png,
    DiagramExportBackground Background = DiagramExportBackground.Theme,
    double Scale = 2, double Quality = .92, double Padding = 16)
{
    public bool IsVector => Format is DiagramExportFormat.Svg or DiagramExportFormat.Pdf;
    public DiagramSize OutputSize(DiagramScene scene)
    {
        if (!double.IsFinite(scene.Size.Width) || !double.IsFinite(scene.Size.Height)
            || scene.Size.Width <= 0 || scene.Size.Height <= 0
            || !double.IsFinite(Scale) || Scale is < .25 or > 8
            || !double.IsFinite(Quality) || Quality is < 0 or > 1
            || !double.IsFinite(Padding) || Padding is < 0 or > 512
            || !Enum.IsDefined(Format) || !Enum.IsDefined(Background))
            throw new DiagramRenderException("Invalid export size, scale, quality or padding.", "export-options");
        if (Format == DiagramExportFormat.Jpeg && Background == DiagramExportBackground.Transparent)
            throw new DiagramRenderException("JPEG does not support a transparent background.", "export-options");
        var size = new DiagramSize(scene.Size.Width + Padding * 2, scene.Size.Height + Padding * 2);
        if (IsVector) return size;
        var pixels = new DiagramSize(Math.Ceiling(size.Width * Scale), Math.Ceiling(size.Height * Scale));
        if (pixels.Width > 16_384 || pixels.Height > 16_384 || pixels.Width * pixels.Height > 32_000_000)
            throw new DiagramRenderException("Export exceeds the 16384 pixel edge or 32 million pixel limit.", "export-limit");
        return pixels;
    }
}
