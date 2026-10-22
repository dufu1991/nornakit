using System.Text.Json;
using System.Xml.Linq;
using System.Numerics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Text;
using NornaKit;
using NornaKit.Windows;

WinRT.ComWrappersSupport.InitializeComWrappers();
var directory = Path.GetFullPath(args.Length == 0 ? "artifacts/native-smoke" : args[0]);
Directory.CreateDirectory(directory);
using var device = new CanvasDevice(forceSoftwareRenderer: true);
using (var probeFormat = new CanvasTextFormat { FontFamily = "Segoe UI", FontSize = 20 })
using (var probeLayout = new CanvasTextLayout(device, "Probe 你好", probeFormat, 400, 100))
{
    var probe = new ProbeTextRenderer();
    var bounds = probeLayout.LayoutBounds;
    probeLayout.DrawToTextRenderer(probe, 0, 0);
    var coordinateCalls = probe.GlyphCalls;
    probeLayout.DrawToTextRenderer(probe, Vector2.Zero);
    var diagnostics = JsonSerializer.Serialize(new { bounds, coordinateCalls, probe.GlyphCalls, probe.PixelReads, probe.DpiReads, probe.TransformReads, probe.Text });
    Console.WriteLine("Native renderer probe: " + diagnostics);
    await File.WriteAllTextAsync(Path.Combine(directory, "probe.json"), diagnostics);
}
var text = new WindowsTextLayoutProvider(device);
var layout = text.Layout(new(InlineText.Parse("NornaKit Windows 你好，世界。\n"
    + "[b]Bold 粗体[/b] [i]Italic 斜体[/i] [code]render(source)[/code]\n"
    + "[u][s][color=#2563eb]Rich text 原生富文本[/color][/s][/u] :win:check: :sf:doc.text:", new(Size: 20)),
    560, LineHeight: 32));
await File.WriteAllTextAsync(Path.Combine(directory, "layout.json"), JsonSerializer.Serialize(new
{
    layout.Size,
    runs = layout.Runs.Select(run => new { run.Text, run.Font, run.Baseline, run.Width, run.Style, run.Glyphs, run.ClusterMap, run.IsIcon })
}, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine("Native text runs: " + JsonSerializer.Serialize(layout.Runs.Select(run => run.Text)));
if (!layout.Runs.Any(run => run.Text.Contains('你'))) throw new InvalidOperationException("DirectWrite dropped Chinese text.");
if (!layout.Runs.Any(run => run.IsIcon && !run.GlyphPath.IsEmpty)) throw new InvalidOperationException("The native icon has no paths.");
if (layout.Runs.Any(run => !File.Exists(run.Font.FilePath))) throw new InvalidOperationException("The actual system font file could not be resolved.");
if (layout.Runs.Where(run => !run.IsIcon).Any(run => run.Glyphs.Any(glyph => glyph.Index == 0)))
    throw new InvalidOperationException("Text contains a missing glyph.");
var scene = new DiagramScene(new(608, Math.Max(200, layout.Size.Height + 48)), "native-smoke", [
    new(new VectorGeometry.Rectangle(new(8, 8, 592, Math.Max(184, layout.Size.Height + 32)), 12),
        new() { Fill = new(SceneColorRole.Surface), Stroke = new(SceneColorRole.Border) }),
    new(new VectorGeometry.Text(layout, new(24, 24), new(SceneColorRole.Foreground)), new())
]);
var exporter = new DiagramExporter(device);
foreach (var appearance in new[] { CanvasAppearance.Light, CanvasAppearance.Dark })
{
    var palette = WindowsPalette.Resolve(appearance);
    foreach (var format in Enum.GetValues<DiagramExportFormat>())
    {
        var bytes = await exporter.ExportAsync(scene, palette, new(Format: format));
        if (bytes.Length < 100) throw new InvalidOperationException($"Empty {format} export.");
        var file = Path.Combine(directory, $"native-{appearance.ToString().ToLowerInvariant()}.{format.ToString().ToLowerInvariant()}");
        await File.WriteAllBytesAsync(file, bytes);
        if (format == DiagramExportFormat.Svg) XDocument.Parse(System.Text.Encoding.UTF8.GetString(bytes));
    }
    var transparent = await exporter.ExportAsync(scene, palette, new(Background: DiagramExportBackground.Transparent));
    await File.WriteAllBytesAsync(Path.Combine(directory, $"native-{appearance.ToString().ToLowerInvariant()}-transparent.png"), transparent);
}
using var cancelled = new CancellationTokenSource();
cancelled.Cancel();
try
{
    await exporter.ExportAsync(scene, WindowsPalette.Resolve(), cancellationToken: cancelled.Token);
    throw new InvalidOperationException("Cancelled export was accepted.");
}
catch (OperationCanceledException) { }
await File.WriteAllTextAsync(Path.Combine(directory, "result.json"), JsonSerializer.Serialize(new
{
    schemaVersion = 1,
    architecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(),
    operatingSystem = Environment.OSVersion.ToString(),
    width = scene.Size.Width,
    height = scene.Size.Height,
    fonts = layout.Runs.Select(run => run.Font).Distinct(),
    text = string.Concat(layout.Runs.Where(run => !run.IsIcon).Select(run => run.Text)),
    status = "passed"
}, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Native smoke tests passed: {directory}");

[WinRT.GeneratedWinRTExposedType]
public sealed partial class ProbeTextRenderer : ICanvasTextRenderer
{
    public int GlyphCalls { get; private set; }
    public int PixelReads { get; private set; }
    public int DpiReads { get; private set; }
    public int TransformReads { get; private set; }
    public List<string> Text { get; } = [];
    public bool PixelSnappingDisabled { get { PixelReads++; return true; } }
    public Matrix3x2 Transform { get { TransformReads++; return Matrix3x2.Identity; } }
    public float Dpi { get { DpiReads++; return 96; } }
    public void DrawGlyphRun(Vector2 point, CanvasFontFace fontFace, float fontSize, CanvasGlyph[] glyphs,
        bool isSideways, uint bidiLevel, object brush, CanvasTextMeasuringMode measuringMode, string localeName,
        string textString, int[] clusterMapIndices, uint characterIndex, CanvasGlyphOrientation glyphOrientation)
    { GlyphCalls++; Text.Add(textString); }
    public void DrawStrikethrough(Vector2 point, float width, float thickness, float offset, CanvasTextDirection direction,
        object brush, CanvasTextMeasuringMode mode, string locale, CanvasGlyphOrientation orientation) { }
    public void DrawUnderline(Vector2 point, float width, float thickness, float offset, float height, CanvasTextDirection direction,
        object brush, CanvasTextMeasuringMode mode, string locale, CanvasGlyphOrientation orientation) { }
    public void DrawInlineObject(Vector2 point, ICanvasTextInlineObject inlineObject, bool sideways, bool rtl,
        object brush, CanvasGlyphOrientation orientation) { }
}
