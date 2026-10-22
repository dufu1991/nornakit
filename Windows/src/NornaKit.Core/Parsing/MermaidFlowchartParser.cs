using System.Collections.Immutable;
using System.Text;

namespace NornaKit;

public static class MermaidFlowchartParser
{
    public static FlowchartModel Parse(string source)
    {
        if (source.Length > 50_000) throw new DiagramRenderException("Source exceeds 50000 UTF16 code units.", "limit");
        var statements = Statements(source);
        if (statements.Count == 0) throw new DiagramRenderException("Start with flowchart TD or graph LR.", "syntax", 1);
        var header = statements[0];
        var parts = header.Text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 2 || parts[0] is not ("flowchart" or "graph"))
            throw new DiagramRenderException("Use a separate flowchart or graph direction declaration.", "unsupported-diagram", header.Line);
        var direction = FlowDirections.Parse(parts[1]) ?? throw new DiagramRenderException("Direction must be TD, TB, BT, LR or RL.", "syntax", header.Line);
        var nodes = new List<FlowNode>();
        var positions = new Dictionary<string, int>(StringComparer.Ordinal);
        var edges = new List<FlowEdge>();
        var groups = new List<FlowGroup>();
        var groupPositions = new Dictionary<string, int>(StringComparer.Ordinal);
        var stack = new List<(int Index, int Line)>();
        var explicitNodes = new HashSet<string>(StringComparer.Ordinal);
        var sequence = 0;
        var register = (FlowNode node, bool explicitShape) =>
        {
            var parent = stack.Count == 0 ? null : groups[stack[^1].Index].Id;
            if (explicitShape) explicitNodes.Add(node.Id);
            if (positions.TryGetValue(node.Id, out var index))
            {
                var current = nodes[index];
                if (explicitShape) current = current with { Label = node.Label, Shape = node.Shape };
                if (current.ParentId is null) current = current with { ParentId = parent };
                nodes[index] = current;
            }
            else
            {
                positions.Add(node.Id, nodes.Count);
                nodes.Add(node with { ParentId = parent, Sequence = sequence++ });
            }
        };
        foreach (var statement in statements.Skip(1))
        {
            var scanner = new Scanner(statement.Text, statement.Line);
            if (statement.Text == "end")
            {
                if (stack.Count == 0) throw scanner.Error("end has no matching subgraph.");
                stack.RemoveAt(stack.Count - 1); continue;
            }
            if (statement.Text == "subgraph" || statement.Text.StartsWith("subgraph ", StringComparison.Ordinal) || statement.Text.StartsWith("subgraph\t", StringComparison.Ordinal))
            {
                var (id, label) = GroupHeader(statement.Text[8..], statement.Line, groups.Count);
                var parent = stack.Count == 0 ? null : groups[stack[^1].Index].Id;
                if (stack.Count >= 16) throw scanner.Error("Subgraphs may be nested at most 16 levels.", "limit");
                if (groupPositions.TryGetValue(id, out var index))
                {
                    if (stack.Any(group => group.Index == index) || groups[index].ParentId != parent)
                        throw scanner.Error("A subgraph cannot contain itself or have different parents.", "semantic");
                    groups[index] = groups[index] with { Label = label };
                    stack.Add((index, statement.Line));
                }
                else
                {
                    if (groups.Count >= 64) throw scanner.Error("A diagram may contain at most 64 subgraphs.", "limit");
                    groupPositions.Add(id, groups.Count); stack.Add((groups.Count, statement.Line));
                    groups.Add(new(id, label, parent, Sequence: sequence++));
                }
                continue;
            }
            if (statement.Text.StartsWith("direction ", StringComparison.Ordinal) || statement.Text.StartsWith("direction\t", StringComparison.Ordinal))
            {
                var values = statement.Text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
                if (values.Length != 2 || FlowDirections.Parse(values[1]) is not { } local) throw scanner.Error("Invalid subgraph direction.");
                if (stack.Count == 0) direction = local;
                else { var index = stack[^1].Index; groups[index] = groups[index] with { Direction = local }; }
                continue;
            }
            if (new[] { "style", "classDef", "class", "click", "linkStyle" }.Any(token => statement.Text == token || statement.Text.StartsWith(token + " ", StringComparison.Ordinal)))
                throw scanner.Error("Style and interaction directives are not supported.", "unsupported-syntax");
            var left = scanner.NodeList(register);
            while (!scanner.AtEnd)
            {
                var connection = scanner.Connection();
                var right = scanner.NodeList(register);
                if (edges.Count + left.Count * right.Count > 500) throw scanner.Error("A flowchart may contain at most 500 edges.", "limit");
                foreach (var from in left)
                    foreach (var to in right)
                        edges.Add(new(from, to, connection.Label, connection.Style, connection.End == EdgeMarker.Arrow,
                            StartMarker: connection.Start, EndMarker: connection.End, MinimumRankSpan: connection.Span));
                left = right;
            }
        }
        if (stack.Count != 0) throw new DiagramRenderException("A subgraph is missing end.", "syntax", stack[^1].Line);
        if (groups.Any(group => explicitNodes.Contains(group.Id))) throw new DiagramRenderException("A subgraph and an explicit node cannot share an identifier.", "semantic");
        nodes.RemoveAll(node => groupPositions.ContainsKey(node.Id));
        if (nodes.Count == 0 && groups.Count == 0) throw new DiagramRenderException("Add nodes below the direction declaration.", "syntax", header.Line);
        if (nodes.Count > 200) throw new DiagramRenderException("A flowchart may contain at most 200 nodes.", "limit");
        return new(direction, nodes.ToImmutableArray(), edges.ToImmutableArray(), groups.ToImmutableArray());
    }

    private static (string Id, string Label) GroupHeader(string text, int line, int anonymousIndex)
    {
        text = text.Trim();
        var anonymous = $"@group_{anonymousIndex}";
        if (text.StartsWith('"')) return (anonymous, DiagramSyntax.Label(text));
        var bracket = text.IndexOf('[');
        if (bracket >= 0)
        {
            var id = text[..bracket].Trim();
            if (!ValidId(id) || !text.EndsWith(']')) throw new DiagramRenderException("Use subgraph ID[title].", "syntax", line);
            return (id, DiagramSyntax.Label(text[(bracket + 1)..^1]));
        }
        if (text.Length == 0) throw new DiagramRenderException("A subgraph requires a title or identifier.", "syntax", line);
        return (ValidId(text) ? text : anonymous, DiagramSyntax.Label(text));
    }
    private static bool ValidId(string value) => value.Length != 0 && value.EnumerateRunes().All(rune => Rune.IsLetterOrDigit(rune) || rune.Value == '_');
    private sealed record Statement(string Text, int Line);
    private static List<Statement> Statements(string source)
    {
        var statements = new List<Statement>();
        var buffer = new StringBuilder();
        var stack = new Stack<char>();
        var quoted = false;
        var line = 1;
        var startLine = 1;
        var hasContent = false;
        var append = () => { var text = buffer.ToString().Trim(); if (text.Length != 0) statements.Add(new(text, startLine)); buffer.Clear(); hasContent = false; };
        for (var index = 0; index < source.Length; index++)
        {
            var character = source[index];
            if (!quoted && stack.Count == 0 && character == '%' && index + 1 < source.Length && source[index + 1] == '%')
            { while (index < source.Length && source[index] != '\n') index++; index--; continue; }
            if (character == '"') quoted = !quoted;
            if (!quoted)
            {
                if (character == '>' && stack.Count == 0)
                {
                    var position = buffer.Length - 1;
                    while (position >= 0 && char.IsWhiteSpace(buffer[position])) position--;
                    if (position >= 0 && (char.IsLetterOrDigit(buffer[position]) || buffer[position] == '_')) stack.Push(']');
                }
                if (character == '[') stack.Push(']');
                if (character == '(') stack.Push(')');
                if (character == '{') stack.Push('}');
                if (character is ']' or ')' or '}')
                {
                    if (!stack.TryPop(out var expected) || expected != character) throw new DiagramRenderException("Mismatched node brackets.", "syntax", line);
                }
            }
            if (character is '\n' or ';' && stack.Count == 0 && !quoted) { append(); startLine = character == '\n' ? line + 1 : line; }
            else
            {
                if (!hasContent && !char.IsWhiteSpace(character)) startLine = line;
                if (!char.IsWhiteSpace(character)) hasContent = true;
                buffer.Append(character);
            }
            if (character == '\n') line++;
        }
        if (stack.Count != 0 || quoted) throw new DiagramRenderException("Unclosed node brackets or quote.", "syntax", startLine);
        append(); return statements;
    }

    private sealed record ConnectionSpec(string Label, EdgeStyle Style, EdgeMarker Start = EdgeMarker.None, EdgeMarker End = EdgeMarker.Arrow, int Span = 1);
    private sealed class Scanner(string text, int line)
    {
        private int index;
        public bool AtEnd => string.IsNullOrWhiteSpace(text[index..]);
        private void Space() { while (index < text.Length && char.IsWhiteSpace(text[index])) index++; }
        private bool Has(string token) => text.AsSpan(index).StartsWith(token, StringComparison.Ordinal);
        private bool Consume(string token) { if (!Has(token)) return false; index += token.Length; return true; }
        public DiagramRenderException Error(string message, string code = "syntax") => new(message, code, line, index + 1);
        public List<string> NodeList(Action<FlowNode, bool> register)
        {
            var ids = new List<string> { Node(register) }; Space();
            while (Consume("&")) { ids.Add(Node(register)); Space(); }
            return ids;
        }
        private string Node(Action<FlowNode, bool> register)
        {
            Space(); var start = index;
            while (index < text.Length && Rune.TryGetRuneAt(text, index, out var rune) && (Rune.IsLetterOrDigit(rune) || rune.Value == '_')) index += rune.Utf16SequenceLength;
            if (index == start) throw Error("A node identifier must contain letters, digits or underscores.");
            var id = text[start..index]; Space();
            if (Consume("@{"))
            {
                var attributes = ReadUntil("}");
                var values = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var item in DiagramSyntax.Split(attributes))
                {
                    var match = DiagramSyntax.Match(@"^\s*(shape|label)\s*:\s*(.+?)\s*$", item);
                    if (match is null || values.ContainsKey(match[1])) throw Error("Node attributes support unique shape and label fields only.", "unsupported-syntax");
                    values.Add(match[1], DiagramSyntax.Label(match[2]));
                }
                var name = values.GetValueOrDefault("shape", "rect");
                if (!Shapes.TryGetValue(name, out var shape)) throw Error($"Unsupported node shape: {name}.", "unsupported-syntax");
                register(new(id, values.GetValueOrDefault("label", id), shape), true); return id;
            }
            foreach (var (open, close, shape) in Delimiters)
            {
                if (!MatchesShape(open, close)) continue;
                Consume(open); var labelStart = index; var quoted = false;
                while (index < text.Length)
                {
                    if (text[index] == '"') quoted = !quoted;
                    if (!quoted && Has(close)) break;
                    index++;
                }
                if (index == text.Length) throw Error("Unclosed node label.");
                var label = DiagramSyntax.Label(text[labelStart..index]); index += close.Length;
                register(new(id, label, shape), true); return id;
            }
            register(new(id, id), false); return id;
        }
        private bool MatchesShape(string open, string close)
        {
            if (!Has(open)) return false;
            if (open is not ("[/" or "[\\")) return true;
            var quoted = false;
            for (var position = index + open.Length; position < text.Length; position++)
            {
                if (text[position] == '"') quoted = !quoted;
                if (!quoted && text[position] == ']') return position + 1 >= close.Length && text.AsSpan(position - close.Length + 1, close.Length).SequenceEqual(close);
            }
            return false;
        }
        public ConnectionSpec Connection()
        {
            Space();
            if (DiagramSyntax.Match(@"^~{3,}", text[index..]) is { } invisible)
            {
                index += invisible[0].Length;
                if (invisible[0].Length > 12) throw Error("An invisible edge may span at most 10 ranks.", "limit");
                return new("", EdgeStyle.Invisible, End: EdgeMarker.None, Span: invisible[0].Length - 2);
            }
            if (DiagramSyntax.Match(@"^([<ox]?)(-{2,}|={2,}|-\.+-)([>ox]?)", text[index..]) is { } match
                && (match[1].Length != 0 || match[3].Length != 0 || match[2].Length >= 3))
            {
                index += match[0].Length; Space();
                var label = Consume("|") ? ReadUntil("|") : "";
                var dashed = match[2].Contains('.');
                var headed = match[1].Length != 0 || match[3].Length != 0;
                var span = dashed ? match[2].Count(character => character == '.') : Math.Max(1, match[2].Length - (headed ? 1 : 2));
                if (span > 10) throw Error("An edge may span at most 10 ranks.", "limit");
                return new(label, dashed ? EdgeStyle.Dashed : match[2].Contains('=') ? EdgeStyle.Thick : EdgeStyle.Solid, Marker(match[1]), Marker(match[3]), span);
            }
            foreach (var (open, close, style) in new[] { ("--", "-->", EdgeStyle.Solid), ("-.", ".->", EdgeStyle.Dashed), ("==", "==>", EdgeStyle.Thick) })
                if (Consume(open)) return new(ReadUntil(close).Trim(), style);
            throw Error("Expected an edge such as -->, -->|label|, -.-> or ==>.");
        }
        private string ReadUntil(string delimiter)
        {
            var start = index; var quoted = false;
            while (index < text.Length)
            {
                if (text[index] == '"') quoted = !quoted;
                if (!quoted && Has(delimiter))
                {
                    var value = text[start..index]; index += delimiter.Length;
                    return value.Length >= 2 && value[0] == '"' && value[^1] == '"' ? value[1..^1] : value;
                }
                index++;
            }
            throw Error("Unclosed edge label.");
        }
        private static EdgeMarker Marker(string value) => value switch { "o" => EdgeMarker.Circle, "x" => EdgeMarker.Cross, "" => EdgeMarker.None, _ => EdgeMarker.Arrow };
        private static readonly (string Open, string Close, NodeShape Shape)[] Delimiters =
        [ ("(((", ")))", NodeShape.DoubleCircle), ("{{", "}}", NodeShape.Hexagon), ("[/", "/]", NodeShape.Parallelogram),
          ("[\\", "\\]", NodeShape.ParallelogramAlt), ("[/", "\\]", NodeShape.Trapezoid), ("[\\", "/]", NodeShape.TrapezoidAlt),
          (">", "]", NodeShape.Asymmetric), ("([", "])", NodeShape.Stadium), ("((", "))", NodeShape.Circle),
          ("[[", "]]", NodeShape.Subroutine), ("[(", ")]", NodeShape.Cylinder), ("[", "]", NodeShape.Rectangle),
          ("(", ")", NodeShape.Rounded), ("{", "}", NodeShape.Diamond) ];
        private static readonly IReadOnlyDictionary<string, NodeShape> Shapes = new Dictionary<string, NodeShape>(StringComparer.Ordinal)
        {
            ["rect"] = NodeShape.Rectangle, ["rectangle"] = NodeShape.Rectangle, ["rounded"] = NodeShape.Rounded, ["round"] = NodeShape.Rounded,
            ["stadium"] = NodeShape.Stadium, ["pill"] = NodeShape.Stadium, ["circle"] = NodeShape.Circle,
            ["dbl-circ"] = NodeShape.DoubleCircle, ["double-circle"] = NodeShape.DoubleCircle, ["diam"] = NodeShape.Diamond,
            ["diamond"] = NodeShape.Diamond, ["decision"] = NodeShape.Diamond, ["hex"] = NodeShape.Hexagon, ["hexagon"] = NodeShape.Hexagon,
            ["cyl"] = NodeShape.Cylinder, ["cylinder"] = NodeShape.Cylinder, ["database"] = NodeShape.Cylinder,
            ["fr-rect"] = NodeShape.Subroutine, ["subroutine"] = NodeShape.Subroutine, ["odd"] = NodeShape.Asymmetric,
            ["lean-r"] = NodeShape.Parallelogram, ["lean-l"] = NodeShape.ParallelogramAlt, ["trap-b"] = NodeShape.Trapezoid, ["trap-t"] = NodeShape.TrapezoidAlt
        };
    }
}
