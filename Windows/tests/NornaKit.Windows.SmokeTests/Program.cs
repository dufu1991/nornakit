using System.Text.Json;
using System.Xml.Linq;
using System.Numerics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Text;
using NornaKit;
using NornaKit.Windows;

WinRT.ComWrappersSupport.InitializeComWrappers();
AppDomain.CurrentDomain.UnhandledException += (_, arguments) =>
{
    if (arguments.ExceptionObject is Exception exception)
        Console.Error.WriteLine("Native failure details: " + JsonSerializer.Serialize(exception.Data.Keys.Cast<object>()
            .ToDictionary(key => key.ToString()!, key => exception.Data[key])));
};
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
var factoryArtifact = await WindowsDiagramRenderer.Create().RenderAsync("flowchart LR\nA[Source] --> B[Native]");
if (factoryArtifact.Type != "flowchart") throw new InvalidOperationException("The public Windows renderer factory failed.");
var renderer = new NativeDiagramRenderer(text);
var regression = new List<string>();
var rendered = 0; var rejected = 0;
foreach (var example in OfficialExampleCatalog.Snapshot.Examples)
{
    var expected = OfficialExampleCatalog.Results[example.Id];
    try
    {
        var artifact = await renderer.RenderAsync(example.Source);
        if (expected.Status != "rendered" || artifact.Type != expected.Kind) regression.Add($"{example.Id}: unexpected render {artifact.Type}.");
        else rendered++;
    }
    catch (DiagramRenderException error)
    {
        if (expected.Status == "rendered" || error.Code != expected.Code || error.Line != expected.Line) regression.Add($"{example.Id}: expected {expected.Status}/{expected.Code}@{expected.Line}, got {error.Code}@{error.Line}: {error.Message}");
        else rejected++;
    }
}
await File.WriteAllTextAsync(Path.Combine(directory, "regression.json"), JsonSerializer.Serialize(new { rendered, rejected, failures = regression }, new JsonSerializerOptions { WriteIndented = true }));
if (regression.Count > 0 || rendered != 304 || rejected != 296) throw new InvalidOperationException(string.Join('\n', regression.Prepend($"Native baseline: {rendered} rendered, {rejected} rejected.")));
foreach (var example in ExampleCatalog.All)
foreach (var language in Enum.GetValues<DiagramExampleLanguage>())
{
    var artifact = await renderer.RenderAsync(example.Source(language), new(MaxWidth: 720));
    if (artifact.Type != example.Kind) throw new InvalidOperationException($"Changed native sample kind: {example.Id}.");
    using var target = new CanvasRenderTarget(device, (float)Math.Min(1600, artifact.Width), (float)Math.Min(1200, artifact.Height), 96);
    using var drawing = target.CreateDrawingSession();
    var palette = WindowsPalette.Resolve(CanvasAppearance.Light);
    drawing.Clear(global::Windows.UI.Color.FromArgb(255, palette.Background.R, palette.Background.G, palette.Background.B));
    var scale = Math.Min(target.Size.Width / artifact.Width, target.Size.Height / artifact.Height);
    drawing.Transform = Matrix3x2.CreateScale((float)scale);
    Win2DScenePainter.Draw(drawing, artifact.Scene, palette);
}
foreach (var kind in Enum.GetValues<DiagramKind>())
{
    var example = ExampleCatalog.Starter(kind.Id());
    var artifact = await renderer.RenderAsync(example.Source(DiagramExampleLanguage.SimplifiedChinese), new(MaxWidth: 720));
    var sampleDirectory = Path.Combine(directory, "diagrams"); Directory.CreateDirectory(sampleDirectory);
    foreach (var format in new[] { DiagramExportFormat.Png, DiagramExportFormat.Svg, DiagramExportFormat.Pdf })
        await File.WriteAllBytesAsync(Path.Combine(sampleDirectory, $"{kind.Id()}.{format.ToString().ToLowerInvariant()}"), await exporter.ExportAsync(artifact.Scene, WindowsPalette.Resolve(CanvasAppearance.Light), new(Format: format, Scale: 1)));
}
foreach (var appearance in new[] { CanvasAppearance.Light, CanvasAppearance.Dark, CanvasAppearance.HighContrastLight, CanvasAppearance.HighContrastDark })
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
var callbackFailure = new InvalidOperationException("Injected font callback failure.");
var failingText = new WindowsTextLayoutProvider(device) { ResolveFont = _ => throw callbackFailure };
try
{
    failingText.Layout(new([new("Callback failure", new())], 300));
    throw new InvalidOperationException("A native callback failure was swallowed.");
}
catch (InvalidOperationException exception) when (ReferenceEquals(exception, callbackFailure)) { }
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
