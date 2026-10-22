using System.Numerics;
using System.Text;
using Microsoft.Graphics.Canvas;
using global::Windows.Storage.Streams;

namespace NornaKit.Windows;

public sealed class DiagramExporter(CanvasDevice device)
{
    public async Task<byte[]> ExportAsync(DiagramScene scene, DiagramPalette palette,
        DiagramExportOptions? options = null, CancellationToken cancellationToken = default)
    {
        options ??= new();
        var pixels = options.OutputSize(scene);
        cancellationToken.ThrowIfCancellationRequested();
        if (options.Format == DiagramExportFormat.Svg)
            return Encoding.UTF8.GetBytes(SvgExporter.Export(scene, palette, options));
        if (options.Format == DiagramExportFormat.Pdf)
            return await Task.Run(() => PdfSceneExporter.Export(scene, palette, options, cancellationToken), cancellationToken);
        using var target = new CanvasRenderTarget(device, (float)pixels.Width, (float)pixels.Height, 96);
        using (var drawing = target.CreateDrawingSession())
        {
            drawing.Clear(options.Background == DiagramExportBackground.Transparent
                ? global::Windows.UI.Color.FromArgb(0, 0, 0, 0) : Win2DScenePainter.Native(palette.Background));
            drawing.Transform = Matrix3x2.CreateScale((float)options.Scale)
                * Matrix3x2.CreateTranslation(new Vector2((float)(options.Padding * options.Scale)));
            Win2DScenePainter.Draw(drawing, scene, palette);
        }
        cancellationToken.ThrowIfCancellationRequested();
        using var stream = new InMemoryRandomAccessStream();
        var format = options.Format switch
        {
            DiagramExportFormat.Png => CanvasBitmapFileFormat.Png,
            DiagramExportFormat.Jpeg => CanvasBitmapFileFormat.Jpeg,
            DiagramExportFormat.Tiff => CanvasBitmapFileFormat.Tiff,
            _ => throw new ArgumentOutOfRangeException(nameof(options))
        };
        await target.SaveAsync(stream, format, (float)options.Quality).AsTask(cancellationToken);
        if (stream.Size > int.MaxValue) throw new DiagramRenderException("The encoded image exceeds the export byte limit.", "export-limit");
        using var reader = new DataReader(stream.GetInputStreamAt(0));
        await reader.LoadAsync((uint)stream.Size).AsTask(cancellationToken);
        var bytes = new byte[(int)stream.Size];
        reader.ReadBytes(bytes);
        return bytes;
    }
}
