using System.Collections.Immutable;
using System.Text.Json;

namespace NornaKit;

internal enum ParticipantStyle { Participant, Actor, Boundary, Control, Entity, Database, Collections, Queue }
internal sealed record SequenceParticipant(string Id, string Label, int? Box, ParticipantStyle Style = ParticipantStyle.Participant)
{ public bool Symbolic => Style is ParticipantStyle.Actor or ParticipantStyle.Boundary or ParticipantStyle.Control or ParticipantStyle.Entity; }
internal sealed record SequenceEvent(string Kind, string A = "", string B = "", string Text = "", string Arrow = "", int Change = 0, ImmutableArray<string> Ids = default);
internal sealed record SequenceModel(ImmutableArray<SequenceParticipant> Participants, ImmutableArray<SequenceEvent> Events, ImmutableArray<string> Boxes, string Title);

internal sealed class SequenceDiagram(TextMeasurement text)
{
    private readonly EdgeLabelLayout labels = new(text);
    public static SequenceModel Parse(string source)
    {
        var lines = DiagramSyntax.Lines(source); var participants = new List<SequenceParticipant>(); var positions = new Dictionary<string, int>(); var events = new List<SequenceEvent>();
        var frames = new Stack<string>(); var boxes = new List<string>(); int? box = null; var active = new Dictionary<string, int>(); var destroyed = new HashSet<string>();
        (string Id, int Line)? create = null, destroy = null;
        Action<string, SourceLine> alive = (id, line) => { if (destroyed.Contains(id)) throw line.Error($"参与者 {id} 已销毁，不能再次使用。", "semantic"); };
        Action<string> register = id => { if (positions.ContainsKey(id)) return; positions.Add(id, participants.Count); participants.Add(new(id, id, box)); };
        const string messagePattern = @"^([\p{L}\p{N}_]+)\s*(<<-->>|<<->>|-->>|->>|-->|->|--x|-x|--\)|-\))\s*([+-]?)\s*([\p{L}\p{N}_]+)\s*:\s*(.*)$";
        for (var cursor = 1; cursor < lines.Count; cursor++)
        {
            var line = lines[cursor]; var s = line.Text;
            if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if ((create is not null || destroy is not null) && DiagramSyntax.Match(messagePattern, s) is null) throw line.Error("生命周期指令后必须紧接关联消息。", "semantic");
            if (DiagramSyntax.Match(@"^create\s+(participant|actor)\s+([\p{L}\p{N}_]+)(?:\s+as\s+(.+))?$", s) is { } cr)
            {
                if (positions.ContainsKey(cr[2])) throw line.Error("只能创建尚未声明或使用的参与者。", "semantic");
                register(cr[2]); var index = positions[cr[2]]; participants[index] = participants[index] with { Style = cr[1] == "actor" ? ParticipantStyle.Actor : ParticipantStyle.Participant, Label = cr[3].Length == 0 ? cr[2] : DiagramSyntax.Label(cr[3]) };
                create = (cr[2], line.Number); events.Add(new("create", cr[2]));
            }
            else if (DiagramSyntax.Match(@"^destroy\s+([\p{L}\p{N}_]+)$", s) is { } de)
            { if (!positions.ContainsKey(de[1])) throw line.Error("不能销毁尚未声明或使用的参与者。", "semantic"); alive(de[1], line); destroy = (de[1], line.Number); }
            else if (DiagramSyntax.Match(@"^(participant|actor)\s+([\p{L}\p{N}_]+)(?:\s*@\s*(\{.*\}))?(?:\s+as\s+(.+))?$", s) is { } pa)
            {
                alive(pa[2], line); register(pa[2]); var index = positions[pa[2]]; var style = pa[1] == "actor" ? ParticipantStyle.Actor : ParticipantStyle.Participant; string? alias = null;
                if (pa[3].Length > 0)
                {
                    // Translate malformed participant JSON into a source diagnostic at this syntax boundary.
                    JsonDocument configuration;
                    try { configuration = JsonDocument.Parse(pa[3]); }
                    catch (JsonException) { throw line.Error("参与者配置需要 JSON 对象，仅支持字符串类型的 type 和 alias。", "syntax"); }
                    using (configuration)
                    {
                        if (configuration.RootElement.ValueKind != JsonValueKind.Object || configuration.RootElement.EnumerateObject().Any(property => property.Name is not ("type" or "alias") || property.Value.ValueKind != JsonValueKind.String)) throw line.Error("参与者配置需要 JSON 对象，仅支持字符串类型的 type 和 alias。", "syntax");
                        if (configuration.RootElement.TryGetProperty("type", out var type))
                        { if (!Enum.TryParse<ParticipantStyle>(type.GetString(), true, out style) || !Enum.IsDefined(style)) throw line.Error($"暂不支持参与者类型：{type.GetString()}。"); }
                        if (configuration.RootElement.TryGetProperty("alias", out var value)) alias = value.GetString();
                    }
                }
                participants[index] = participants[index] with { Style = style, Label = pa[4].Length > 0 ? DiagramSyntax.Label(pa[4]) : alias is not null ? DiagramSyntax.Label(alias) : participants[index].Label, Box = box };
            }
            else if (DiagramSyntax.Match(messagePattern, s) is { } m)
            {
                alive(m[1], line); alive(m[4], line);
                if (create is { } pendingCreate && m[4] != pendingCreate.Id) throw line.Error("创建消息的接收方必须是新参与者。", "semantic");
                if (destroy is { } pendingDestroy && m[1] != pendingDestroy.Id && m[4] != pendingDestroy.Id) throw line.Error("销毁消息必须连接待销毁的参与者。", "semantic");
                register(m[1]); register(m[4]); var change = m[3] == "+" ? 1 : m[3] == "-" ? -1 : 0;
                if (change > 0) active[m[4]] = active.GetValueOrDefault(m[4]) + 1;
                if (change < 0) { if (active.GetValueOrDefault(m[1]) <= 0) throw line.Error("发送方没有可结束的激活区间。", "semantic"); active[m[1]]--; }
                events.Add(new("message", m[1], m[4], DiagramSyntax.Label(m[5]), m[2], change));
                if (destroy is { } pending) { events.Add(new("destroy", pending.Id)); destroyed.Add(pending.Id); active[pending.Id] = 0; }
                create = null; destroy = null;
            }
            else if (DiagramSyntax.Match(@"^(?i:note)\s+(left of|right of|over)\s+([^:]+):\s*(.*)$", s) is { } no)
            {
                var ids = no[2].Split(',').Select(id => id.Trim()).ToImmutableArray();
                if (ids.Length is < 1 or > 2 || ids.Any(id => DiagramSyntax.Match(@"^[\p{L}\p{N}_]+$", id) is null)) throw line.Error("注释需要一个或两个参与者标识符。", "syntax");
                foreach (var id in ids) { alive(id, line); register(id); } events.Add(new("note", no[1], Text: DiagramSyntax.Label(no[3]), Ids: ids));
            }
            else if (DiagramSyntax.Match(@"^(?i:note)\s+(left of|right of|over)\s+([\p{L}\p{N}_]+(?:\s*,\s*[\p{L}\p{N}_]+)?)$", s) is { } multi)
            {
                var ids = multi[2].Split(',').Select(id => id.Trim()).ToImmutableArray(); foreach (var id in ids) alive(id, line);
                var rows = new List<string>(); cursor++; while (cursor < lines.Count && !lines[cursor].Text.Equals("end note", StringComparison.OrdinalIgnoreCase)) rows.Add(lines[cursor++].Text);
                if (cursor >= lines.Count) throw line.Error("多行注释缺少 end note。", "syntax"); foreach (var id in ids) register(id);
                events.Add(new("note", multi[1], Text: DiagramSyntax.Label(string.Join('\n', rows)), Ids: ids));
            }
            else if (DiagramSyntax.Match(@"^(activate|deactivate)\s+([\p{L}\p{N}_]+)$", s) is { } act)
            {
                alive(act[2], line); register(act[2]); var count = active.GetValueOrDefault(act[2]);
                if (act[1] == "deactivate" && count <= 0) throw line.Error("参与者没有可结束的激活区间。", "semantic");
                active[act[2]] = count + (act[1] == "activate" ? 1 : -1); events.Add(new(act[1], act[2]));
            }
            else if (s is "autonumber" or "autonumber off") events.Add(new("numbering", "1", "1", Change: s == "autonumber" ? 1 : 0));
            else if (DiagramSyntax.Match(@"^autonumber\s+(\d+)(?:\s+(\d+))?$", s) is { } num)
            { if (!int.TryParse(num[1], out var start) || !int.TryParse(num[2].Length == 0 ? "1" : num[2], out var step) || step is <= 0 or >= 1_000 || start >= 1_000_000) throw line.Error("消息编号或步长超出范围。", "limit"); events.Add(new("numbering", num[1], step.ToString(System.Globalization.CultureInfo.InvariantCulture), Change: 1)); }
            else if (DiagramSyntax.Match(@"^(loop|alt|opt|par|critical|break|rect)\b\s*(.*)$", s) is { } control)
            { if (frames.Count >= 16) throw line.Error("时序图最多嵌套 16 层控制片段。", "limit"); if (control[1] == "rect") BackgroundColor(control[2], line); frames.Push(control[1]); events.Add(new("frame", control[1], Text: control[2])); }
            else if (DiagramSyntax.Match(@"^(else|and|option)\b\s*(.*)$", s) is { } branch)
            { var expected = branch[1] switch { "else" => "alt", "and" => "par", _ => "critical" }; if (!frames.TryPeek(out var outer) || outer != expected) throw line.Error("分支指令与外层控制片段不匹配。", "syntax"); events.Add(new("branch", branch[1], Text: branch[2])); }
            else if (s == "end")
            { if (frames.TryPop(out _)) events.Add(new("end")); else if (box is not null) box = null; else throw line.Error("end 没有对应的控制片段或参与者分组。", "syntax"); }
            else if (s.StartsWith("box ", StringComparison.Ordinal))
            { if (box is not null || frames.Count > 0) throw line.Error("参与者 box 不支持嵌套。"); boxes.Add(s[4..]); box = boxes.Count - 1; }
            else throw line.Error($"暂不支持这条时序图语法：{s}");
            if (participants.Count > 60 || events.Count > 500) throw line.Error("时序图最多支持 60 个参与者和 500 个事件。", "limit");
        }
        if ((create ?? destroy) is { } unfinished) throw new DiagramRenderException("生命周期指令缺少关联消息。", "semantic", unfinished.Line);
        if (frames.Count > 0 || box is not null) throw new DiagramRenderException("时序图控制片段或参与者分组缺少 end。", "syntax", lines.LastOrDefault()?.Number);
        DiagramSyntax.Nonempty(participants.Count, DiagramKind.Sequence);
        return new(participants.ToImmutableArray(), events.ToImmutableArray(), boxes.ToImmutableArray(), DiagramSyntax.Title(lines));
    }
    private static SceneColor BackgroundColor(string value, SourceLine line)
    {
        value = value.Trim();
        if (DiagramSyntax.Match(@"^#[0-9a-fA-F]{6}$", value) is not null) return SceneColor.Literal(DiagramColor.FromHex(value));
        if (DiagramSyntax.Match(@"^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$", value) is { } rgb && byte.TryParse(rgb[1], out var r) && byte.TryParse(rgb[2], out var g) && byte.TryParse(rgb[3], out var b)) return SceneColor.Literal(new(r, g, b));
        var hex = value.ToLowerInvariant() switch { "blue" => "0000ff", "red" => "ff0000", "green" => "008000", "yellow" => "ffff00", "purple" => "800080", "orange" => "ffa500", "gray" => "808080", "white" => "ffffff", _ => null };
        return hex is null ? throw line.Error("rect 颜色当前支持六位十六进制、rgb 和常用英文颜色名称。") : SceneColor.Literal(DiagramColor.FromHex(hex));
    }

    public DiagramScene Layout(SequenceModel model, DiagramLayoutOptions options)
    {
        var participants = model.Participants; var indexes = participants.Select((p, i) => (p.Id, i)).ToDictionary(pair => pair.Id, pair => pair.i);
        var slot = options.MaxWidth is { } maximum ? Math.Max(64, (maximum - 32 - Math.Max(0, participants.Length - 1) * 28) / participants.Length) : 240;
        var widths = participants.Select(p => Math.Max(options.Compact ? 64 : 100, Math.Min(options.Compact ? Math.Min(160, slot) : 240, text.Width(p.Label) + 36))).ToArray();
        var gaps = Enumerable.Repeat(options.Compact ? 28d : 72, Math.Max(0, participants.Length - 1)).ToArray(); double left = options.Compact ? 16 : 120, right = left;
        foreach (var e in model.Events)
        {
            if (e.Kind == "message") { var a = indexes[e.A]; var b = indexes[e.B]; var span = Math.Abs(b - a); if (span > 0) { var room = Math.Min(options.Compact ? 100 : 280, text.Width(e.Text) + 40) / span; for (var i = Math.Min(a, b); i < Math.Max(a, b); i++) gaps[i] = Math.Max(gaps[i], room - (widths[i] + widths[i + 1]) / 2); } else right = Math.Max(right, 160); }
            if (e.Kind == "note") { if (e.A == "left of") left = 220; if (e.A == "right of") right = 220; }
        }
        var xs = new double[participants.Length]; xs[0] = left + widths[0] / 2;
        for (var i = 1; i < xs.Length; i++) xs[i] = xs[i - 1] + widths[i - 1] / 2 + gaps[i - 1] + widths[i] / 2;
        var width = xs[^1] + widths[^1] / 2 + right;
        var content = new SceneBuilder(DiagramKind.Sequence, text); var backgrounds = new SceneBuilder(DiagramKind.Sequence, text); var lifelines = new SceneBuilder(DiagramKind.Sequence, text); var activations = new SceneBuilder(DiagramKind.Sequence, text);
        var actorY = content.Title(model.Title, width) + 16; var actorHeight = Math.Max(50, participants.Select((p, i) => text.Lines(p.Label, widths[i] - 16).Length * 22 + 12).Max());
        var y = actorY + Math.Max(100, actorHeight + 40); var number = 1; var step = 1; var numbering = false;
        var active = new Dictionary<string, Stack<double>>(); var destroyed = new Dictionary<string, double>(); var created = new Dictionary<string, double>(); string? creating = null;
        var messageIndex = 0; var lastMessageY = y; var frames = new Stack<(string Kind, string Label, double Y, int Depth)>();
        Func<string, bool> isActive = id => active.TryGetValue(id, out var values) && values.Count > 0;
        Action<string, double> activate = (id, value) => { if (!active.TryGetValue(id, out var values)) active.Add(id, values = new()); values.Push(value); };
        Action<string, double> close = (id, end) => { if (active.TryGetValue(id, out var values) && values.TryPop(out var start)) activations.Rect(new(xs[indexes[id]] - 5 + values.Count * 4, start, 10, Math.Max(14, end - start)), C.SurfaceAlt); };
        foreach (var e in model.Events)
        {
            switch (e.Kind)
            {
                case "create": creating = e.A; y += (participants[indexes[e.A]].Symbolic ? 86 : actorHeight) / 2 + 18; break;
                case "numbering": number = int.Parse(e.A, System.Globalization.CultureInfo.InvariantCulture); step = int.Parse(e.B, System.Globalization.CultureInfo.InvariantCulture); numbering = e.Change == 1; break;
                case "activate": activate(e.A, y); y += 12; break;
                case "deactivate": close(e.A, y); y += 12; break;
                case "destroy":
                    var x = xs[indexes[e.A]]; var endY = lastMessageY; destroyed[e.A] = endY; while (isActive(e.A)) close(e.A, endY);
                    content.Path([new PathCommand.Move(new(x - 6, endY - 6)), new PathCommand.Line(new(x + 6, endY + 6)), new PathCommand.Move(new(x + 6, endY - 6)), new PathCommand.Line(new(x - 6, endY + 6))], id: $"destroy-{e.A}"); break;
                case "message":
                {
                    var a = indexes[e.A]; var b = indexes[e.B]; var sign = xs[b] >= xs[a] ? 1 : -1;
                    var start = xs[a] + (isActive(e.A) ? sign * 5 : 0); var end = xs[b] - (creating == e.B ? sign * widths[b] / 2 : isActive(e.B) || e.Change > 0 ? sign * 5 : 0);
                    var loopRoom = Math.Min(300, a + 1 < xs.Length ? xs[a + 1] - start - 20 : width - start - 16);
                    var messageWidth = a == b ? Math.Max(24, loopRoom - 48) : Math.Max(24, Math.Abs(end - start) - 36);
                    var label = (numbering ? $"{number}. " : "") + e.Text; var labelSize = labels.Size(text.Lines(label, Math.Min(260, messageWidth), 12));
                    y += labelSize.Height / 2 + 16; lastMessageY = y;
                    if (creating == e.B) created[e.B] = y - (participants[b].Symbolic ? 86 : actorHeight) / 2;
                    if (e.Change > 0) activate(e.B, y);
                    ImmutableArray<DiagramPoint> points; DiagramRect labelFrame; var loopHeight = Math.Max(32, labelSize.Height + 20);
                    if (a == b) { var loopWidth = Math.Min(loopRoom, Math.Max(80, labelSize.Width + 48)); points = [new(start, y), new(start + loopWidth, y), new(start + loopWidth, y + loopHeight), new(xs[b] + (isActive(e.B) ? 5 : 0), y + loopHeight)]; labelFrame = new(start + (loopWidth - labelSize.Width) / 2, y - labelSize.Height / 2, labelSize.Width, labelSize.Height); }
                    else { points = [new(start, y), new(end, y)]; labelFrame = new((start + end - labelSize.Width) / 2, y - labelSize.Height / 2, labelSize.Width, labelSize.Height); }
                    var head = e.Arrow.Contains(">>", StringComparison.Ordinal) || e.Arrow.Contains(')') || e.Arrow.Contains('x');
                    content.Line(points, dash: e.Arrow.Contains("--", StringComparison.Ordinal) ? [4, 4] : [], arrow: head && !e.Arrow.Contains('x'), open: e.Arrow.Contains(')'), id: $"message-{messageIndex}");
                    if (e.Arrow.StartsWith("<<", StringComparison.Ordinal)) content.Path(ScenePaths.Arrow(points.Reverse().ToArray()), C.Line, C.None);
                    if (e.Arrow.Contains('x')) content.Path(ScenePaths.Marker(EdgeMarker.Cross, points), stroke: C.Line);
                    content.Rect(labelFrame, C.Background, C.None, 3, id: $"edge-label-message-{messageIndex}", label: label); content.Text(label, labelFrame, 12, shrink: false, lineHeight: 18);
                    messageIndex++; number += step; if (e.Change < 0) close(e.A, y);
                    y += a == b ? loopHeight + labelSize.Height / 2 + 26 : Math.Max(labelSize.Height / 2 + 26, creating == e.B ? actorHeight / 2 + 18 : 0); creating = null; break;
                }
                case "note":
                {
                    var a = xs[indexes[e.Ids[0]]]; var b = xs[indexes[e.Ids[^1]]]; var rows = text.Lines(e.Text, 180); var noteWidth = Math.Max(100, rows.Max(row => text.Width(row)) + 24); var height = rows.Length * 22 + 24;
                    var noteX = e.A == "left of" ? a - noteWidth - 16 : e.A == "right of" ? a + 16 : (a + b) / 2 - noteWidth / 2;
                    content.Box(e.Text, new(noteX, y, noteWidth, height), C.SurfaceAlt, size: 14); y += height + 20; break;
                }
                case "frame": frames.Push((e.A, e.Text, y, frames.Count)); y += 46; break;
                case "branch":
                    var depth = frames.Peek().Depth; content.Line([new(24 + depth * 10, y), new(width - 24 - depth * 10, y)], C.Border, dash: [4, 4]);
                    content.Text($"{e.A}  {e.Text}", new(44 + depth * 10, y + 6, width - 88, 24), 14, align: TextAlignment.Leading); y += 40; break;
                case "end":
                    var f = frames.Pop(); var inset = 24 + f.Depth * 10;
                    backgrounds.Rect(new(inset, f.Y, width - inset * 2, y - f.Y + 8), f.Kind == "rect" ? BackgroundColor(f.Label, new(f.Label, f.Label, 1)) : C.SurfaceAlt, opacity: f.Kind == "rect" ? .12 : .22);
                    content.Box(f.Kind, new(inset, f.Y, Math.Max(54, text.Width(f.Kind, 14) + 18), 26), C.SurfaceAlt, size: 14);
                    if (f.Kind != "rect") content.Text(f.Label, new(inset + 82, f.Y + 2, width - inset * 2 - 96, 26), 14, align: TextAlignment.Leading); y += 24; break;
            }
        }
        var bottom = y + 12;
        foreach (var participant in participants) while (isActive(participant.Id)) close(participant.Id, bottom);
        for (var i = 0; i < participants.Length; i++)
        {
            var participant = participants[i]; var x = xs[i]; var top = created.GetValueOrDefault(participant.Id, actorY); var start = top + (participant.Symbolic ? 86 : actorHeight);
            lifelines.Line([new(x, start), new(x, destroyed.GetValueOrDefault(participant.Id, bottom))], C.Border, dash: [4, 4], id: $"lifeline-{participant.Id}");
            DrawParticipant(participant, new(x - widths[i] / 2, top, widths[i], actorHeight), content);
            if (!destroyed.ContainsKey(participant.Id)) DrawParticipant(participant, new(x - widths[i] / 2, bottom + 12, widths[i], actorHeight), content);
        }
        var totalHeight = bottom + 110;
        for (var i = 0; i < model.Boxes.Length; i++)
        {
            var members = Enumerable.Range(0, participants.Length).Where(index => participants[index].Box == i).ToArray(); if (members.Length == 0) continue;
            var x = xs[members[0]] - widths[members[0]] / 2 - 16; var last = xs[members[^1]] + widths[members[^1]] / 2 + 16;
            backgrounds.Rect(new(x, actorY - 12, last - x, totalHeight - actorY), C.SurfaceAlt, opacity: .25); content.Text(model.Boxes[i], new(x, actorY - 36, last - x, 24), 14, C.Muted);
        }
        var all = backgrounds.Primitives.AsEnumerable().Reverse().Concat(lifelines.Primitives).Concat(activations.Primitives).Concat(content.Primitives).ToArray(); content.Primitives.Clear(); content.Primitives.AddRange(all);
        return content.Build(width, totalHeight);
    }
    private static void DrawParticipant(SequenceParticipant participant, DiagramRect r, SceneBuilder b)
    {
        var x = r.Center.X; var y = r.Y; var id = $"participant-{participant.Id}";
        switch (participant.Style)
        {
            case ParticipantStyle.Actor:
                b.Ellipse(new(x - 8, y, 16, 16), C.None, C.Line, id: id, label: participant.Label);
                b.Line([new(x, y + 16), new(x, y + 34)]); b.Line([new(x - 16, y + 23), new(x + 16, y + 23)]); b.Line([new(x - 12, y + 48), new(x, y + 34), new(x + 12, y + 48)]); break;
            case ParticipantStyle.Boundary: case ParticipantStyle.Control: case ParticipantStyle.Entity:
                b.Ellipse(new(x - 18, y + 8, 36, 36), C.Surface, C.Line, id: id, label: participant.Label);
                if (participant.Style == ParticipantStyle.Boundary) { b.Line([new(x - 32, y + 6), new(x - 32, y + 46)]); b.Line([new(x - 32, y + 26), new(x - 18, y + 26)]); }
                else if (participant.Style == ParticipantStyle.Control) b.Line([new(x - 2, y + 2), new(x + 8, y + 8), new(x - 2, y + 14)]);
                else b.Line([new(x - 22, y + 48), new(x + 22, y + 48)]); break;
            case ParticipantStyle.Database:
                var node = new SceneNode(id, participant.Label, NodeShape.Cylinder, r, []); b.Path(ScenePaths.Node(node), C.Surface, C.Border, id: id); b.Path(ScenePaths.Detail(node), stroke: C.Border); break;
            case ParticipantStyle.Collections:
                foreach (var offset in new[] { 8, 4, 0 }) b.Rect(new(r.X + offset, r.Y + offset, r.Width - 8, r.Height - 8), id: offset == 0 ? id : null, label: participant.Label); break;
            case ParticipantStyle.Queue:
                b.Rect(r.Inset(8, 0), radius: 0, id: id, label: participant.Label); b.Ellipse(new(r.X, r.Y, 16, r.Height), C.Surface, C.Border); b.Ellipse(new(r.Right - 16, r.Y, 16, r.Height), C.Surface, C.Border); break;
            default: b.Rect(r, id: id, label: participant.Label); break;
        }
        b.Text(participant.Label, participant.Symbolic ? new(r.X, y + 50, r.Width, 30) : r.Inset(participant.Style == ParticipantStyle.Queue ? 18 : 8, 8), participant.Symbolic ? 14 : 16);
    }
}
