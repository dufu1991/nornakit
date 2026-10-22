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

Console.WriteLine($"Passed {count} Core assertions.");
