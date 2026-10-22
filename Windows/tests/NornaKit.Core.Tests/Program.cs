using System.Buffers.Binary;
using System.Collections.Immutable;
using System.Xml.Linq;
using System.Security.Cryptography;
using System.Text;
using NornaKit;

var count = 0;
var check = (bool condition, string message) =>
{
    if (!condition) throw new InvalidOperationException(message);
    count++;
};
var rejects = (Action action, string code) =>
{
    try { action(); }
    catch (DiagramRenderException error) when (error.Code == code) { count++; return; }
    throw new InvalidOperationException($"Expected {code}.");
};

var scene = new DiagramScene(new(320, 160), "flowchart", []);
check(new DiagramExportOptions().OutputSize(scene) == new DiagramSize(704, 384), "Bitmap pixel size must include padding and scale.");
check(new DiagramExportOptions(Format: DiagramExportFormat.Pdf).OutputSize(scene) == new DiagramSize(352, 192), "Vector dimensions must ignore scale.");
rejects(() => new DiagramExportOptions(Scale: double.NaN).OutputSize(scene), "export-options");
rejects(() => new DiagramExportOptions(Format: DiagramExportFormat.Jpeg, Background: DiagramExportBackground.Transparent).OutputSize(scene), "export-options");
rejects(() => new DiagramExportOptions(Scale: 8).OutputSize(scene with { Size = new(4000, 4000) }), "export-limit");
rejects(() => new DiagramLayoutOptions(MaxWidth: 159).Validate(), "limit");
rejects(() => new DiagramLayoutOptions(DirectionBreakpoint: double.PositiveInfinity).Validate(), "limit");
new DiagramLayoutOptions(MaxWidth: 160).Validate();
check(new DiagramRect(1, 2, 3, 4).Union(new(0, 0, 8, 8)) == new DiagramRect(0, 0, 8, 8), "Rectangle union failed.");

var palette = new DiagramPalette(new(255, 255, 255), new(0, 0, 0), new(80, 80, 80), new(20, 20, 20),
    new(240, 240, 240), new(230, 230, 230), new(80, 80, 80), new(81, 72, 216), [new(0, 0, 0), new(255, 255, 255)]);
check(palette.Resolve(new(SceneColorRole.Series, -1)) == new DiagramColor(255, 255, 255), "Negative series index failed.");
check(palette.Resolve(new(SceneColorRole.OnSeries, 0)) == new DiagramColor(255, 255, 255), "Contrast color failed.");
var text = new PreparedText(new(80, 24), [new("中文 <A> & \"B\"", new(), new("Test", "unused.ttf"), new(0, 18), 80, [], [], 0, [])]);
var content = scene with
{
    Primitives = [new(new VectorGeometry.Rectangle(new(8, 8, 304, 144)), new() { Fill = new(SceneColorRole.Surface) }, "a&b"),
        new(new VectorGeometry.Text(text, new(16, 16), new(SceneColorRole.Foreground)), new())]
};
var svg = SvgExporter.Export(content, palette);
var xml = XDocument.Parse(svg);
check(xml.Descendants().Any(element => element.Name.LocalName == "text" && element.Value == "中文 <A> & \"B\""), "SVG must preserve Unicode and escape XML.");
check(svg.Contains("data-id=\"a&amp;b\"", StringComparison.Ordinal), "SVG must escape attribute values.");
check(ScenePaths.Ellipse(new(0, 0, 20, 20)).Count(command => command is PathCommand.Cubic) == 4, "Ellipse must have four cubic segments.");
var rich = InlineText.Parse("[b]Hello [i]世界[/i][/b] :sf:doc.text: :win:check@palette(#2563eb,#f59e0b):");
check(rich[0].Style.Bold && rich[1].Style.Bold && rich[1].Style.Italic, "Nested native text styles were lost.");
check(rich.Single(run => run.IconName == "sf:doc.text").Text == ":sf:doc.text:", "The original icon token must be retained.");
check(rich.Single(run => run.IconName == "win:check").Style.Color == DiagramColor.FromHex("2563eb"), "Windows icons must use the first palette color.");
check(string.Concat(InlineText.Parse("[b]unclosed").Select(run => run.Text)) == "[b]unclosed", "Unclosed markup must remain literal.");
check(string.Concat(InlineText.Parse("[b][i]invalid[/b][/i]").Select(run => run.Text)) == "[b][i]invalid[/b][/i]", "Misnested markup must remain literal.");

// The synthetic collection contains two faces sharing the same table data.
var collection = new byte[140];
var write32 = (int offset, uint value) => BinaryPrimitives.WriteUInt32BigEndian(collection.AsSpan(offset), value);
var write16 = (int offset, ushort value) => BinaryPrimitives.WriteUInt16BigEndian(collection.AsSpan(offset), value);
write32(0, 0x74746366); write32(4, 0x00010000); write32(8, 2); write32(12, 20); write32(16, 48);
foreach (var offset in new[] { 20, 48 })
{
    write32(offset, 0x00010000); write16(offset + 4, 1); write16(offset + 6, 16);
    write32(offset + 12, 0x68656164); write32(offset + 20, 80); write32(offset + 24, 54);
}
var extracted = OpenTypeFontFile.ExtractFace(collection, 1);
check(BinaryPrimitives.ReadUInt32BigEndian(extracted) == 0x00010000, "A collection must produce a standalone font.");
check(BinaryPrimitives.ReadUInt32BigEndian(extracted.AsSpan(20)) == 28, "Font table offsets must be rebased.");
uint checksum = 0;
for (var index = 0; index < extracted.Length; index += 4)
    checksum = unchecked(checksum + BinaryPrimitives.ReadUInt32BigEndian(extracted.AsSpan(index, 4)));
check(checksum == 0xB1B0AFBA, "Extracted font checksum must be valid.");
try { OpenTypeFontFile.ExtractFace(collection, 2); throw new InvalidOperationException("Invalid face index was accepted."); }
catch (InvalidDataException) { count++; }
try { OpenTypeFontFile.ExtractFace(collection.AsSpan(0, 40), 1); throw new InvalidOperationException("Truncated font was accepted."); }
catch (InvalidDataException) { count++; }

var official = OfficialExampleCatalog.Snapshot;
check(official.Pages.Length == 33 && official.Examples.Length == 600, "The shared official source catalog changed unexpectedly.");
check(official.Examples.Select(example => example.Id).Distinct().Count() == 600, "Official example identifiers must be unique.");
foreach (var example in official.Examples)
    check(Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(example.Source))) == example.Sha256,
        $"Official source bytes changed: {example.Id}.");
check(OfficialExampleCatalog.Results.Count == 600, "Every official example needs a baseline result.");
check(OfficialExampleCatalog.Results.Values.Count(result => result.Status == "rendered") == 304, "The rendered baseline count changed.");
check(OfficialExampleCatalog.Results.Values.Count(result => result.Status == "rejected") == 296, "The rejected baseline count changed.");
check(official.Examples.All(example => OfficialExampleCatalog.Results.ContainsKey(example.Id)), "Official status identifiers do not match the sources.");

check(ExampleCatalog.All.Length == 79 && ExampleCatalog.Kinds.Length == 33 && ExampleCatalog.Comparisons.Length == 29,
    "The shared bilingual sample catalog changed unexpectedly.");
var catalogFields = ExampleCatalog.All.SelectMany(example => new[]
{
    example.Id, example.Kind, example.Symbol, example.Titles.Zh, example.Titles.En, example.Sources.Zh, example.Sources.En
});
var catalogHash = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join('\0', catalogFields))));
check(catalogHash == "0b02676e05913aeef6d772ea627fe8ff634cb696ffb6d8a40f400fbeb8fe360b", "The original bilingual examples changed during migration.");
foreach (var kind in ExampleCatalog.Kinds)
    check(ExampleCatalog.Starter(kind.Id).Kind == kind.Id, $"Invalid starter: {kind.Id}.");
foreach (var comparison in ExampleCatalog.Comparisons)
{
    check(ExampleCatalog.Get(comparison.SimpleId).Kind == comparison.Kind, $"Invalid simple example: {comparison.Kind}.");
    check(ExampleCatalog.Get(comparison.ComplexId).Kind == comparison.Kind, $"Invalid complex example: {comparison.Kind}.");
}
var groupedIds = ExampleCatalog.Group("catalog").Concat(ExampleCatalog.Group("flowcharts")).Concat(ExampleCatalog.Group("advanced"))
    .Select(example => example.Id).Concat(ExampleCatalog.Comparisons.Select(comparison => comparison.ComplexId));
check(groupedIds.SequenceEqual(ExampleCatalog.All.Select(example => example.Id)), "Canonical example ordering changed.");
foreach (var example in ExampleCatalog.All)
    foreach (var language in Enum.GetValues<DiagramExampleLanguage>())
        check(DiagramKinds.Detect(example.Source(language))?.Id() == example.Kind, $"Incorrect diagram detection: {example.Id}.");
foreach (var example in ExampleCatalog.All.Where(example => example.Kind == "flowchart"))
    foreach (var language in Enum.GetValues<DiagramExampleLanguage>())
    {
        var model = MermaidFlowchartParser.Parse(example.Source(language));
        check(model.Nodes.Length + model.Groups.Length > 0, $"Empty flowchart: {example.Id}.");
    }
var product = MermaidFlowchartParser.Parse("flowchart LR\nA & B --> C & D");
check(product.Edges.Length == 4 && product.Nodes.Length == 4, "Cartesian edge expansion failed.");
var nested = MermaidFlowchartParser.Parse("flowchart TD\nStart --> API\nsubgraph API[Service]\n direction LR\n A[Input] --> B[Output]\nend");
check(nested.Groups.Length == 1 && nested.Nodes.Length == 3 && nested.Nodes.Single(node => node.Id == "A").ParentId == "API", "Forward group references or parent membership failed.");
check(nested.Groups[0].Direction == FlowDirection.LeftRight, "Subgraph direction was lost.");
var markers = MermaidFlowchartParser.Parse("flowchart LR\nA@{ shape: stadium, label: \"Input\" } <--> B{{Decision}}\nB --o C>Output]\nC --x A");
check(markers.Nodes[0].Shape == NodeShape.Stadium && markers.Nodes[1].Shape == NodeShape.Hexagon && markers.Nodes[2].Shape == NodeShape.Asymmetric, "Expanded node shapes were lost.");
check(markers.Edges[0].StartMarker == EdgeMarker.Arrow && markers.Edges[1].EndMarker == EdgeMarker.Circle && markers.Edges[2].EndMarker == EdgeMarker.Cross, "Edge markers were lost.");
rejects(() => MermaidFlowchartParser.Parse("flowchart TD\nsubgraph G[Group]\nA --> B"), "syntax");
rejects(() => MermaidFlowchartParser.Parse("flowchart TD\nA --> B\nstyle A fill:red"), "unsupported-syntax");

var renderer = new NativeDiagramRenderer(new FixedTextLayoutProvider());
foreach (var example in ExampleCatalog.All.Where(example => example.Kind == "flowchart"))
foreach (var language in Enum.GetValues<DiagramExampleLanguage>())
foreach (var width in new double?[] { null, 360, 720 })
{
    var result = await renderer.RenderAsync(example.Source(language), new(MaxWidth: width));
    check(result.Scene.Nodes.Length > 0 && result.Scene.Primitives.Length > 0, $"Flow layout lost nodes: {example.Id}.");
    check(result.Scene.Nodes.All(node => node.Frame.IsFinite && node.Frame.Width > 0 && node.Frame.Height > 0), "Node frames must be finite and positive.");
    check(result.Scene.Edges.All(edge => edge.Points.Length >= 2 && edge.Points.All(point => double.IsFinite(point.X) && double.IsFinite(point.Y))), "Edge routes must be finite and connected.");
    var model = MermaidFlowchartParser.Parse(example.Source(language));
    check(result.Scene.Groups.All(group => model.Nodes.Where(node => node.ParentId == group.Id).All(node => group.Frame.Contains(result.Scene.Nodes.Single(placed => placed.Id == node.Id).Frame))), "A subgraph must enclose its direct children.");
}
var straight = await renderer.RenderAsync("flowchart TD\nA --> B --> C");
check(straight.Scene.Nodes.Select(node => node.Frame.Center.X).Distinct().Count() == 1, "Serial flow chains must align.");
var feedbackArtifact = await renderer.RenderAsync("flowchart TD\nA --> B\nB --> A\nA --> A");
check(feedbackArtifact.Scene.Edges.Length == 3 && feedbackArtifact.Scene.Edges.All(edge => edge.Points.Length >= 2), "Feedback edges and self loops must be routed.");
var implemented = Enum.GetValues<DiagramKind>().Select(kind => kind.Id()).ToArray();
foreach (var example in ExampleCatalog.All.Where(example => implemented.Contains(example.Kind) && example.Kind != "flowchart"))
foreach (var language in Enum.GetValues<DiagramExampleLanguage>())
foreach (var width in new double?[] { null, 360, 720 })
{
    var result = await renderer.RenderAsync(example.Source(language), new(MaxWidth: width));
    check(result.Type == example.Kind && result.Scene.Primitives.Length > 0, $"The {example.Id} sample must render as {example.Kind}.");
    check(result.Width is > 0 and <= 250_000 && result.Height is > 0 and <= 250_000, "Diagram bounds must be exportable.");
}
var regressionFailures = new List<string>();
foreach (var example in OfficialExampleCatalog.Snapshot.Examples.Where(example => implemented.Contains(example.Kind)))
{
    var expected = OfficialExampleCatalog.Results[example.Id];
    try
    {
        var result = await renderer.RenderAsync(example.Source);
        if (expected.Status != "rendered") regressionFailures.Add($"{example.Id}: expected {expected.Code}@{expected.Line}, rendered {result.Type}.");
        else check(result.Type == expected.Kind, $"Official example {example.Id} changed kind.");
    }
    catch (DiagramRenderException error)
    {
        if (expected.Status == "rendered" || error.Code != expected.Code || error.Line != expected.Line) regressionFailures.Add($"{example.Id}: expected {expected.Status}/{expected.Code}@{expected.Line}, got {error.Code}@{error.Line}: {error.Message}");
        else count++;
    }
}
check(regressionFailures.Count == 0, string.Join('\n', regressionFailures));
rejects(() => renderer.RenderAsync("flowchart TD\nA\u0001").GetAwaiter().GetResult(), "syntax");
using (var cancellation = new CancellationTokenSource())
{
    cancellation.Cancel();
    try { await renderer.RenderAsync("flowchart TD\nA --> B", cancellationToken: cancellation.Token); }
    catch (OperationCanceledException) { count++; }
}

var delayedRenderer = new ControlledRenderer();
using (var studio = new NornaStudio.StudioSession(delayedRenderer, (_, _) => Task.CompletedTask))
{
    var first = studio.UpdateAsync("first", new());
    check(!studio.CanExport && studio.Busy, "Editing must immediately disable export.");
    var latest = studio.UpdateAsync("latest", new());
    delayedRenderer.Complete("latest", new(scene with { Kind = "latest" })); await latest;
    check(studio.CanExport && studio.Artifact?.Type == "latest", "The latest preview must become exportable.");
    var frozen = studio.Snapshot(palette);
    delayedRenderer.Complete("first", new(scene with { Kind = "stale" })); await first;
    check(studio.Artifact?.Type == "latest", "A renderer that ignores cancellation must not overwrite the latest preview.");
    var failed = studio.UpdateAsync("invalid", new());
    check(!studio.CanExport && frozen.Source == "latest" && frozen.Scene.Kind == "latest", "An open export snapshot must survive subsequent edits.");
    delayedRenderer.Fail("invalid", new("Bad token", "syntax", 4, 2)); await failed;
    check(studio.Diagnostic is { Code: "syntax", Line: 4, Column: 2 } && !studio.CanExport, "Source diagnostics must disable stale export.");
}

Console.WriteLine($"Passed {count} Core assertions.");

sealed class ControlledRenderer : IDiagramRenderer
{
    private readonly Dictionary<string, TaskCompletionSource<DiagramArtifact>> requests = [];
    public Task<DiagramArtifact> RenderAsync(string source, DiagramLayoutOptions? options = null, CancellationToken cancellationToken = default)
    { var request = new TaskCompletionSource<DiagramArtifact>(); requests.Add(source, request); return request.Task; }
    public void Complete(string source, DiagramArtifact artifact) => requests[source].SetResult(artifact);
    public void Fail(string source, DiagramRenderException error) => requests[source].SetException(error);
}

sealed class FixedTextLayoutProvider : ITextLayoutProvider
{
    public PreparedText Layout(TextLayoutRequest request, CancellationToken cancellationToken = default)
    {
        var runs = new List<PreparedTextRun>(); double x = 0, y = request.LineHeight * .8, width = 0;
        foreach (var run in request.Runs)
        foreach (var rune in run.Text.EnumerateRunes())
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (rune.Value == '\n') { width = Math.Max(width, x); x = 0; y += request.LineHeight; continue; }
            var advance = run.Style.Size * (rune.Value >= 0x2e80 ? 1 : .5);
            if (x > 0 && x + advance > request.MaxWidth) { width = Math.Max(width, x); x = 0; y += request.LineHeight; }
            runs.Add(new(rune.ToString(), run.Style, new("Fixture Sans", "fixture.ttf"), new(x, y), advance, [], [], 0, []));
            x += advance;
        }
        width = Math.Max(width, x);
        if (request.Alignment != TextAlignment.Leading)
        {
            var lineWidths = runs.GroupBy(run => run.Baseline.Y).ToDictionary(group => group.Key, group => group.Max(run => run.Baseline.X + run.Width));
            runs = runs.Select(run => run with { Baseline = run.Baseline.Offset((request.MaxWidth - lineWidths[run.Baseline.Y]) / (request.Alignment == TextAlignment.Center ? 2 : 1), 0) }).ToList();
        }
        return new(new(width, y + request.LineHeight * .2), runs.ToImmutableArray());
    }
}
