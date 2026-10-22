using System.Collections.Immutable;

namespace NornaKit;

internal sealed class PacketEventDiagrams(TextMeasurement text)
{
    public DiagramScene Packet(string source)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.Packet, text); var blocks = new List<(int Start, int End, string Label)>(); var last = -1;
        foreach (var line in lines.Skip(1))
        {
            if (line.Text.StartsWith("title ", StringComparison.Ordinal)) continue;
            var m = DiagramSyntax.Match("^(\\+?\\d+)(?:-(\\d+))?\\s*:\\s*\"([^\"]+)\"$", line.Text) ?? throw line.Error("数据包字段应写作起止比特范围和双引号标签。", "syntax"); int start, end;
            if (m[1].StartsWith('+')) { if (!int.TryParse(m[1][1..], out var length) || length is <= 0 or > 65_536) throw line.Error("字段长度无效。", "semantic"); start = last + 1; end = start + length - 1; }
            else { if (!int.TryParse(m[1], out start) || !int.TryParse(m[2].Length == 0 ? m[1] : m[2], out end) || start < 0 || end < start || end > 65_535) throw line.Error("字段范围无效。", "semantic"); }
            if (start <= last || end > 65_535) throw line.Error("数据包字段不能重叠或倒序。", "semantic"); blocks.Add((start, end, m[3])); last = end;
        }
        DiagramSyntax.Nonempty(blocks.Count, DiagramKind.Packet); const double width = 800, bit = 24; var top = b.Title(DiagramSyntax.Title(lines), width); var rows = last / 32 + 1; if (rows > 256) throw new DiagramRenderException("数据包最多显示 256 行。", "limit");
        for (var row = 0; row < rows; row++) for (var i = 0; i < 32; i++) b.Text((row * 32 + i).ToString(System.Globalization.CultureInfo.InvariantCulture), new(16 + i * bit, top + row * 74, bit, 20), 9, C.Muted);
        foreach (var (start, end, label) in blocks) for (var cursor = start; cursor <= end;)
        { var row = cursor / 32; var tail = Math.Min(end, row * 32 + 31); var w = (tail - cursor + 1) * bit - 2; var r = new DiagramRect(16 + cursor % 32 * bit, top + row * 74 + 22, w, 42); b.Rect(r, id: $"packet-{start}-{cursor}", label: label); var size = Math.Min(14, Math.Max(8, w / Math.Max(1, text.Width(label)) * 14)); if (w > 18) b.Text(label, r.Inset(3, 4), size); cursor = tail + 1; }
        return b.Build(width, top + rows * 74 + 12);
    }
    private sealed record EventFrame(string Id, string Label, string Kind, bool Reset, string[] Refs);
    public DiagramScene Events(string source)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.EventModeling, text); var frames = new List<EventFrame>();
        foreach (var line in lines.Skip(1))
        {
            if (line.Text.StartsWith("title ", StringComparison.Ordinal)) continue;
            var m = DiagramSyntax.Match(@"^(tf|rf)\s+(\w+)\s+(ui|cmd|evt|rmo|pcr)\s+(.+?)(?:\s+->>\s+(.+))?$", line.Text) ?? throw line.Error("事件建模当前支持 tf、rf 帧和显式来源引用。");
            if (frames.Any(frame => frame.Id == m[2]) || m[4].Contains('{') || m[4].Contains("[[", StringComparison.Ordinal)) throw line.Error("帧标识符重复，或使用了尚未支持的数据块。", "unsupported-syntax");
            frames.Add(new(m[2], m[4], m[3], m[1] == "rf", m[5].Length == 0 ? [] : m[5].Split("->>").Select(value => value.Trim()).ToArray()));
        }
        DiagramSyntax.Nonempty(frames.Count, DiagramKind.EventModeling); Func<string, int> lane = kind => kind is "ui" or "pcr" ? 0 : kind == "evt" ? 2 : 1;
        var width = Math.Max(600, frames.Count * 190 + 170); var top = b.Title(DiagramSyntax.Title(lines), width); string[] names = ["UI / Automation", "Command / Read Model", "Events"];
        for (var i = 0; i < names.Length; i++) { var y = top + i * 140; b.Rect(new(12, y, width - 24, 128), C.SurfaceAlt, C.Border, opacity: .35); b.Text(names[i], new(22, y + 4, 240, 24), 13, C.Muted, TextAlignment.Leading); }
        var rects = frames.Select((frame, i) => new DiagramRect(150 + i * 190, top + lane(frame.Kind) * 140 + 38, 168, 72)).ToArray(); var ids = frames.Select((frame, i) => (frame.Id, i)).ToDictionary(pair => pair.Id, pair => pair.i); var connections = new List<FlowEdge>();
        for (var i = 0; i < frames.Count; i++)
        {
            var frame = frames[i]; var sources = new List<int>();
            if (frame.Refs.Length > 0) sources.AddRange(frame.Refs.Select(id => ids.TryGetValue(id, out var index) ? index : throw new DiagramRenderException($"帧引用 {id} 不存在。", "semantic")));
            else if (!frame.Reset) { var previous = frames.Take(i).ToList().FindLastIndex(other => lane(other.Kind) != lane(frame.Kind)); if (previous >= 0) sources.Add(previous); }
            foreach (var from in sources) { if (from == i) throw new DiagramRenderException("帧不能引用自身。", "semantic"); connections.Add(new(frames[from].Id, frame.Id)); }
        }
        var nodes = frames.Select((frame, i) => new SceneNode(frame.Id, frame.Label, NodeShape.Rectangle, rects[i], [frame.Label])).ToImmutableArray();
        var graph = new FlowchartModel(FlowDirection.LeftRight, frames.Select(frame => new FlowNode(frame.Id, frame.Label)).ToImmutableArray(), connections.ToImmutableArray(), []);
        var routed = new CompoundEdgeRouter(text).Route(graph, new(new(width, top + 438), "eventmodeling", []) { Nodes = nodes }, separateConnections: true);
        var dx = rects[0].X - routed.Nodes[0].Frame.X; var dy = rects[0].Y - routed.Nodes[0].Frame.Y;
        for (var i = 0; i < routed.Edges.Length; i++) b.Line(routed.Edges[i].Points.Select(point => point.Offset(dx, dy)), arrow: routed.Edges[i].Arrow, id: $"event-edge-{i}");
        for (var i = 0; i < frames.Count; i++)
        { var frame = frames[i]; var color = frame.Kind switch { "ui" => -1, "cmd" => 0, "evt" => 1, "rmo" => 2, _ => 6 }; b.Rect(rects[i], color < 0 ? C.Surface : C.Series(color), opacity: color < 0 ? 1 : .22, id: frame.Id, label: frame.Label); b.Text(frame.Label, rects[i].Inset(8, 8), 14); b.Text(frame.Id, new(rects[i].X, rects[i].Bottom + 2, rects[i].Width, 18), 10, C.Muted); }
        return b.Build(width, top + 438);
    }
}
