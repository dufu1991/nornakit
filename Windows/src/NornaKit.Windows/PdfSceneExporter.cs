using System.Buffers.Binary;
using System.Collections.Immutable;
using System.Globalization;
using System.Text;
using PdfSharp.Drawing;
using PdfSharp.Pdf;

namespace NornaKit.Windows;

/// <summary>Writes positioned DirectWrite glyphs as PDF text with embedded fonts and Unicode maps.</summary>
internal static class PdfSceneExporter
{
    public static byte[] Export(DiagramScene scene, DiagramPalette palette, DiagramExportOptions options,
        CancellationToken cancellationToken)
    {
        var size = options.OutputSize(scene);
        using var document = new PdfDocument();
        document.Info.Creator = "NornaKit";
        document.Info.Title = scene.Kind;
        var page = document.AddPage();
        page.Width = XUnit.FromPoint(size.Width);
        page.Height = XUnit.FromPoint(size.Height);
        var resources = new PdfDictionary(document);
        var fontResources = new PdfDictionary(document);
        var states = new PdfDictionary(document);
        resources.Elements["/Font"] = fontResources;
        resources.Elements["/ExtGState"] = states;
        page.Elements["/Resources"] = resources;
        var fonts = new Dictionary<FontFaceReference, EmbeddedFont>();
        var output = new StringBuilder($"q 1 0 0 -1 {N(options.Padding)} {N(size.Height - options.Padding)} cm\n1 J 1 j\n");
        if (options.Background == DiagramExportBackground.Theme)
        {
            output.Append(Color(palette.Background, false));
            output.Append($"{N(-options.Padding)} {N(-options.Padding)} {N(size.Width)} {N(size.Height)} re f\n");
        }
        foreach (var primitive in scene.Primitives)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var state = new PdfDictionary(document);
            state.Elements.SetReal("/ca", primitive.Style.Opacity);
            state.Elements.SetReal("/CA", primitive.Style.Opacity);
            document.Internals.AddObject(state);
            var stateName = $"/G{states.Elements.Count}";
            states.Elements[stateName] = state.Reference!;
            output.Append($"q {stateName} gs\n");
            if (primitive.Geometry is VectorGeometry.Text text)
            {
                foreach (var run in text.Layout.Runs)
                {
                    var color = run.Style.Color ?? palette.Resolve(text.Color);
                    output.Append(Color(color, false));
                    var origin = text.Origin.Offset(run.Baseline.X, run.Baseline.Y);
                    if (run.IsIcon)
                    {
                        output.Append($"q 1 0 0 1 {N(origin.X)} {N(origin.Y)} cm\n");
                        output.Append(Path(run.GlyphPath));
                        output.Append("f Q\n");
                    }
                    else
                    {
                        if (!fonts.TryGetValue(run.Font, out var font))
                        {
                            font = new(run.Font, $"/F{fonts.Count}");
                            fonts.Add(run.Font, font);
                        }
                        // ActualText preserves ligatures and multi-glyph clusters in copy/search results.
                        output.Append($"/Span << /ActualText <FEFF{Unicode(run.Text)}> >> BDC\n");
                        if (run.Font.SimulatedBold) output.Append(Color(color, true));
                        var x = origin.X;
                        var rightToLeft = (run.BidiLevel & 1) != 0;
                        for (var index = 0; index < run.Glyphs.Length; index++)
                        {
                            var glyph = run.Glyphs[index];
                            if (rightToLeft) x -= glyph.Advance;
                            var unicode = ClusterText(run, index);
                            var cid = font.Register(glyph.Index, unicode, glyph.Advance / run.Style.Size * 1000);
                            var shear = run.Font.SimulatedItalic ? .21255656 : 0;
                            output.Append($"BT {font.Name} {N(run.Style.Size)} Tf {(run.Font.SimulatedBold ? "2" : "0")} Tr {N(run.Style.Size * .02)} w 1 0 {N(shear)} -1 {N(x + glyph.AdvanceOffset)} {N(origin.Y - glyph.AscenderOffset)} Tm <{cid:X4}> Tj ET\n");
                            if (!rightToLeft) x += glyph.Advance;
                        }
                        output.Append("EMC\n");
                    }
                    if (run.Style.Underline || run.Style.Strikethrough)
                    {
                        output.Append(Color(color, true));
                        if (run.Style.Underline) output.Append($"1 w {N(origin.X)} {N(origin.Y + run.Style.Size * .12)} m {N(origin.X + run.Width)} {N(origin.Y + run.Style.Size * .12)} l S\n");
                        if (run.Style.Strikethrough) output.Append($"1 w {N(origin.X)} {N(origin.Y - run.Style.Size * .3)} m {N(origin.X + run.Width)} {N(origin.Y - run.Style.Size * .3)} l S\n");
                    }
                }
            }
            else
            {
                var style = primitive.Style;
                output.Append(Color(palette.Resolve(style.Fill), false));
                output.Append(Color(palette.Resolve(style.Stroke), true));
                output.Append($"{N(style.LineWidth)} w [{string.Join(' ', style.Dash.Select(N))}] 0 d\n");
                output.Append(Path(ScenePaths.Geometry(primitive.Geometry)));
                var fill = style.Fill.Role != SceneColorRole.None;
                var stroke = style.Stroke.Role != SceneColorRole.None && style.LineWidth > 0;
                output.Append(fill && stroke ? "B\n" : fill ? "f\n" : stroke ? "S\n" : "n\n");
            }
            output.Append("Q\n");
        }
        foreach (var font in fonts.Values)
        {
            cancellationToken.ThrowIfCancellationRequested();
            fontResources.Elements[font.Name] = font.Build(document).Reference!;
        }
        output.Append("Q\n");
        page.Contents.AppendContent().CreateStream(Encoding.ASCII.GetBytes(output.ToString()));
        using var stream = new MemoryStream();
        document.Save(stream, false);
        return stream.ToArray();
    }

    private static string ClusterText(PreparedTextRun run, int glyphIndex)
    {
        var indices = Enumerable.Range(0, run.ClusterMap.Length).Where(index => run.ClusterMap[index] == glyphIndex).ToArray();
        return indices.Length == 0 ? "" : run.Text.Substring(indices[0], indices.Length);
    }

    private sealed class EmbeddedFont(FontFaceReference source, string name)
    {
        public string Name { get; } = name;
        private readonly Dictionary<(int Glyph, string Unicode), ushort> identifiers = [];
        private readonly List<(int Glyph, string Unicode, double Width)> entries = [];

        public ushort Register(int glyph, string unicode, double width)
        {
            if (identifiers.TryGetValue((glyph, unicode), out var existing)) return existing;
            if (entries.Count >= 65_534) throw new DiagramRenderException("Too many glyph mappings in one font.", "export-limit");
            var cid = checked((ushort)(entries.Count + 1));
            identifiers.Add((glyph, unicode), cid);
            entries.Add((glyph, unicode, width));
            return cid;
        }

        public PdfDictionary Build(PdfDocument document)
        {
            var data = OpenTypeFontFile.ExtractFace(File.ReadAllBytes(source.FilePath), source.FaceIndex);
            if (BinaryPrimitives.ReadUInt32BigEndian(data) != 0x00010000)
                throw new DiagramRenderException("PDF text export requires a TrueType outline font.", "export-font");
            var head = Table(data, 0x68656164);
            var metrics = Table(data, 0x68686561);
            var os2 = Table(data, 0x4F532F32);
            var rights = BinaryPrimitives.ReadUInt16BigEndian(os2.AsSpan(8, 2));
            if ((rights & 0x0002) != 0 || (rights & 0x0200) != 0)
                throw new DiagramRenderException("The selected font does not permit embedding outline text.", "export-font");
            var units = BinaryPrimitives.ReadUInt16BigEndian(head.AsSpan(18, 2));
            var scale = (short value) => value * 1000d / units;
            var fontName = $"/NornaFont{Name[2..]}";
            var file = Stream(document, data);
            file.Elements.SetInteger("/Length1", data.Length);
            var descriptor = new PdfDictionary(document);
            descriptor.Elements.SetName("/Type", "/FontDescriptor");
            descriptor.Elements.SetName("/FontName", fontName);
            descriptor.Elements.SetInteger("/Flags", 32 | (source.Italic ? 64 : 0));
            descriptor.Elements["/FontBBox"] = Array(document, Enumerable.Range(0, 4)
                .Select(index => scale(BinaryPrimitives.ReadInt16BigEndian(head.AsSpan(36 + index * 2, 2)))));
            descriptor.Elements.SetReal("/ItalicAngle", source.Italic ? -12 : 0);
            descriptor.Elements.SetReal("/Ascent", scale(BinaryPrimitives.ReadInt16BigEndian(metrics.AsSpan(4, 2))));
            descriptor.Elements.SetReal("/Descent", scale(BinaryPrimitives.ReadInt16BigEndian(metrics.AsSpan(6, 2))));
            descriptor.Elements.SetReal("/CapHeight", scale(BinaryPrimitives.ReadInt16BigEndian(metrics.AsSpan(4, 2))));
            descriptor.Elements.SetReal("/StemV", source.Bold ? 120 : 80);
            descriptor.Elements["/FontFile2"] = file.Reference!;
            document.Internals.AddObject(descriptor);
            var mapping = new byte[(entries.Count + 1) * 2];
            for (var index = 0; index < entries.Count; index++)
                BinaryPrimitives.WriteUInt16BigEndian(mapping.AsSpan((index + 1) * 2, 2), checked((ushort)entries[index].Glyph));
            var descendant = new PdfDictionary(document);
            descendant.Elements.SetName("/Type", "/Font");
            descendant.Elements.SetName("/Subtype", "/CIDFontType2");
            descendant.Elements.SetName("/BaseFont", fontName);
            var system = new PdfDictionary(document);
            system.Elements.SetString("/Registry", "Adobe");
            system.Elements.SetString("/Ordering", "Identity");
            system.Elements.SetInteger("/Supplement", 0);
            descendant.Elements["/CIDSystemInfo"] = system;
            descendant.Elements["/FontDescriptor"] = descriptor.Reference!;
            descendant.Elements["/CIDToGIDMap"] = Stream(document, mapping).Reference!;
            var widths = new PdfArray(document);
            widths.Elements.Add(new PdfInteger(1));
            widths.Elements.Add(Array(document, entries.Select(entry => entry.Width)));
            descendant.Elements["/W"] = widths;
            document.Internals.AddObject(descendant);
            var cmap = new StringBuilder("/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n/CMapName /NornaUnicode def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n");
            var mappings = entries.Select((entry, index) => (entry.Unicode, Cid: index + 1)).Where(entry => entry.Unicode.Length != 0).ToArray();
            foreach (var chunk in mappings.Chunk(100))
            {
                cmap.Append($"{chunk.Length} beginbfchar\n");
                foreach (var entry in chunk) cmap.Append($"<{entry.Cid:X4}> <{Unicode(entry.Unicode)}>\n");
                cmap.Append("endbfchar\n");
            }
            cmap.Append("endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n");
            var font = new PdfDictionary(document);
            font.Elements.SetName("/Type", "/Font");
            font.Elements.SetName("/Subtype", "/Type0");
            font.Elements.SetName("/BaseFont", fontName);
            font.Elements.SetName("/Encoding", "/Identity-H");
            font.Elements["/ToUnicode"] = Stream(document, Encoding.ASCII.GetBytes(cmap.ToString())).Reference!;
            var descendants = new PdfArray(document);
            descendants.Elements.Add(descendant.Reference!);
            font.Elements["/DescendantFonts"] = descendants;
            document.Internals.AddObject(font);
            return font;
        }

        private static byte[] Table(byte[] data, uint tag)
        {
            var count = BinaryPrimitives.ReadUInt16BigEndian(data.AsSpan(4, 2));
            for (var index = 0; index < count; index++)
            {
                var entry = data.AsSpan(12 + index * 16, 16);
                if (BinaryPrimitives.ReadUInt32BigEndian(entry) != tag) continue;
                return data.AsSpan(checked((int)BinaryPrimitives.ReadUInt32BigEndian(entry[8..])),
                    checked((int)BinaryPrimitives.ReadUInt32BigEndian(entry[12..]))).ToArray();
            }
            throw new DiagramRenderException("A required font table is missing.", "export-font");
        }
    }

    private static PdfDictionary Stream(PdfDocument document, byte[] bytes)
    {
        var dictionary = new PdfDictionary(document);
        dictionary.CreateStream(bytes);
        document.Internals.AddObject(dictionary);
        return dictionary;
    }
    private static PdfArray Array(PdfDocument document, IEnumerable<double> values)
    {
        var array = new PdfArray(document);
        foreach (var value in values) array.Elements.Add(new PdfReal(value));
        return array;
    }
    private static string Unicode(string text) => Convert.ToHexString(Encoding.BigEndianUnicode.GetBytes(text));
    private static string Color(DiagramColor color, bool stroke) => $"{N(color.R / 255d)} {N(color.G / 255d)} {N(color.B / 255d)} {(stroke ? "RG" : "rg")}\n";
    private static string N(double value) => value.ToString("0.########", CultureInfo.InvariantCulture);
    private static string P(DiagramPoint point) => $"{N(point.X)} {N(point.Y)}";
    private static string Path(IEnumerable<PathCommand> commands)
    {
        var output = new StringBuilder();
        var current = new DiagramPoint();
        foreach (var command in commands)
        {
            switch (command)
            {
                case PathCommand.Move move: output.Append($"{P(move.Point)} m\n"); current = move.Point; break;
                case PathCommand.Line line: output.Append($"{P(line.Point)} l\n"); current = line.Point; break;
                case PathCommand.Cubic cubic: output.Append($"{P(cubic.Control1)} {P(cubic.Control2)} {P(cubic.End)} c\n"); current = cubic.End; break;
                case PathCommand.Quadratic quadratic:
                    var c1 = new DiagramPoint(current.X + (quadratic.Control.X - current.X) * 2 / 3, current.Y + (quadratic.Control.Y - current.Y) * 2 / 3);
                    var c2 = new DiagramPoint(quadratic.End.X + (quadratic.Control.X - quadratic.End.X) * 2 / 3, quadratic.End.Y + (quadratic.Control.Y - quadratic.End.Y) * 2 / 3);
                    output.Append($"{P(c1)} {P(c2)} {P(quadratic.End)} c\n"); current = quadratic.End; break;
                case PathCommand.Close: output.Append("h\n"); break;
            }
        }
        return output.ToString();
    }
}
