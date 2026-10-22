using System.Text;
using System.Text.RegularExpressions;

namespace NornaKit;

internal sealed class RailroadDiagram(TextMeasurement text)
{
    private sealed record Expression(string Kind, string Label = "", bool Terminal = false, Expression[]? Children = null)
    { public Expression[] Values => Children ?? []; }
    private sealed record Token(string Value, bool Quoted, int Line);
    private readonly record struct Layout(double Width, double Height, double Baseline);
    public DiagramScene Render(string source)
    {
        var lines = Regex.Split(source, "\r\n|\r|\n"); var first = Array.FindIndex(lines, line => line.Trim().Length > 0 && !line.TrimStart().StartsWith("%%", StringComparison.Ordinal)); var header = lines[first].Trim();
        var body = string.Join('\n', lines.Skip(first + 1).Select(line => (header.Contains("abnf", StringComparison.Ordinal) || header.Contains("peg", StringComparison.Ordinal)) && line.Trim().Length > 0 && !line.TrimStart().StartsWith("%%", StringComparison.Ordinal) && !line.TrimEnd().EndsWith(';') ? line + ";" : line));
        var parser = new Parser(Tokenize(body, first + 2)); var rules = new List<(string Name, Expression Value)>();
        while (!parser.Done)
        { var name = parser.Take(); if (name.Quoted || name.Value.Length == 0 || !char.IsLetter(name.Value[0]) || !(parser.Consume("=") || parser.Consume("<-"))) throw parser.Error("铁路图规则需要名称和 = 或 <-。"); var value = parser.Choice([";"]); if (!parser.Consume(";")) throw parser.Error("规则缺少分号。"); if (rules.Any(rule => rule.Name == name.Value)) throw parser.Error("规则名称重复。"); rules.Add((name.Value, value)); }
        DiagramSyntax.Nonempty(rules.Count, DiagramKind.Railroad); var layouts = rules.Select(rule => Measure(rule.Value)).ToArray(); var width = Math.Max(360, layouts.Max(size => size.Width) + 72); var b = new SceneBuilder(DiagramKind.Railroad, text); double y = 12;
        for (var i = 0; i < rules.Count; i++)
        { var rule = rules[i]; var size = layouts[i]; b.Text(rule.Name, new(16, y, width - 32, 26), 15, align: TextAlignment.Leading, bold: true); y += 36; var baseline = y + size.Baseline; b.Line([new(12, baseline - 8), new(12, baseline + 8)]); b.Line([new(18, baseline - 8), new(18, baseline + 8)]); b.Line([new(18, baseline), new(36, baseline)]); Draw(rule.Value, 36, y, b); b.Line([new(36 + size.Width, baseline), new(54 + size.Width, baseline)]); b.Line([new(54 + size.Width, baseline - 8), new(54 + size.Width, baseline + 8)]); b.Line([new(60 + size.Width, baseline - 8), new(60 + size.Width, baseline + 8)]); y += size.Height + 28; }
        return b.Build(width, y);
    }
    private static List<Token> Tokenize(string source, int line)
    {
        var result = new List<Token>(); var i = 0;
        while (i < source.Length)
        {
            var c = source[i]; if (char.IsWhiteSpace(c)) { if (c == '\n') line++; i++; continue; }
            if (c == '%' && i + 1 < source.Length && source[i + 1] == '%') { while (i < source.Length && source[i] != '\n') i++; continue; }
            if (c is '\'' or '"')
            { var quote = c; var startLine = line; i++; var value = new StringBuilder(); var closed = false; while (i < source.Length) { if (source[i] == quote) { closed = true; i++; break; } if (source[i] == '\\' && i + 1 < source.Length) { i++; value.Append(source[i] == 'n' ? '\n' : source[i]); } else value.Append(source[i]); i++; } if (!closed) throw new DiagramRenderException("铁路图字符串尚未闭合。", "syntax", startLine); result.Add(new(value.ToString(), true, startLine)); continue; }
            if (char.IsLetter(c) || c == '_') { var start = i; while (i < source.Length && (char.IsLetterOrDigit(source[i]) || "_.-".Contains(source[i]))) i++; result.Add(new(source[start..i], false, line)); continue; }
            if (c == '<' && i + 1 < source.Length && source[i + 1] == '-') { result.Add(new("<-", false, line)); i += 2; continue; }
            if (!"=;|/[]{}()?*+,".Contains(c)) throw new DiagramRenderException($"铁路图暂不支持这个词法符号：{c}。", "unsupported-syntax", line); result.Add(new(c.ToString(), false, line)); i++;
        }
        return result;
    }
    private sealed class Parser(List<Token> tokens)
    {
        private int index, depth;
        public bool Done => index == tokens.Count;
        public DiagramRenderException Error(string message) => new(message, "syntax", index < tokens.Count ? tokens[index].Line : tokens.LastOrDefault()?.Line);
        public Token Take() => Done ? throw Error("语法表达式意外结束。") : tokens[index++];
        public bool Consume(string value) { if (Done || tokens[index].Quoted || tokens[index].Value != value) return false; index++; return true; }
        public Expression Choice(HashSet<string> stops)
        {
            depth++; if (depth > 32) throw Error("语法表达式最多嵌套 32 层。"); var boundaries = stops.Concat(["|", "/"]).ToHashSet(); var values = new List<Expression> { Sequence(boundaries) }; while (Consume("|") || Consume("/")) values.Add(Sequence(boundaries)); depth--; return values.Count == 1 ? values[0] : new("choice", Children: values.ToArray());
        }
        private Expression Sequence(HashSet<string> stops)
        {
            var values = new List<Expression>(); while (!Done && (tokens[index].Quoted || !stops.Contains(tokens[index].Value))) { if (!stops.Contains(",") && Consume(",")) continue; values.Add(Atom()); }
            if (values.Count == 0) throw Error("缺少语法表达式。"); return values.Count == 1 ? values[0] : new("sequence", Children: values.ToArray());
        }
        private Expression Atom()
        {
            var token = Take(); Expression value;
            if (token.Quoted) value = new("atom", token.Value, true);
            else if (token.Value is "[" or "{" or "(")
            { var closing = token.Value switch { "[" => "]", "{" => "}", _ => ")" }; var expression = Choice([closing]); if (!Consume(closing)) throw Error("语法表达式括号不匹配。"); value = token.Value == "[" ? new("optional", Children: [expression]) : token.Value == "{" ? new("optional", Children: [new("repetition", Children: [expression])]) : expression; }
            else if (token.Value.Length > 0 && (char.IsLetter(token.Value[0]) || token.Value[0] == '_'))
            {
                if (!Consume("(")) value = new("atom", token.Value);
                else
                {
                    var name = token.Value.ToLowerInvariant();
                    if (name is "terminal" or "nonterminal") { var label = Take(); if (!label.Quoted || !Consume(")")) throw Error("terminal 和 nonterminal 需要一个字符串参数。"); value = new("atom", label.Value, name == "terminal"); }
                    else
                    { var values = new List<Expression> { Choice([",", ")"]) }; while (Consume(",")) values.Add(Choice([",", ")"])); if (!Consume(")")) throw Error("铁路图函数缺少结束括号。"); value = name switch { "sequence" => new("sequence", Children: values.ToArray()), "choice" => new("choice", Children: values.ToArray()), "optional" when values.Count == 1 => new("optional", Children: [values[0]]), "zeroormore" when values.Count == 1 => new("optional", Children: [new("repetition", Children: [values[0]])]), "oneormore" when values.Count == 1 => new("repetition", Children: [values[0]]), _ => throw Error($"暂不支持铁路图函数 {token.Value}。") }; }
                }
            }
            else throw Error("此处需要终结符、规则名称或分组表达式。");
            if (Consume("?")) value = new("optional", Children: [value]); else if (Consume("*")) value = new("optional", Children: [new("repetition", Children: [value])]); else if (Consume("+")) value = new("repetition", Children: [value]); return value;
        }
    }
    private Layout Measure(Expression e)
    {
        if (e.Kind == "empty") return new(32, 30, 15); if (e.Kind == "atom") return new(Math.Max(52, text.Width(e.Label, 14) + 28), 30, 15);
        if (e.Kind == "optional") return Measure(new("choice", Children: [new("empty"), e.Values[0]]));
        var sizes = e.Values.Select(Measure).ToArray();
        return e.Kind switch { "sequence" => new(sizes.Sum(size => size.Width) + (sizes.Length - 1) * 20, sizes.Max(size => size.Baseline) + sizes.Max(size => size.Height - size.Baseline), sizes.Max(size => size.Baseline)), "choice" => new(sizes.Max(size => size.Width) + 48, sizes.Sum(size => size.Height) + (sizes.Length - 1) * 18, sizes[0].Baseline), _ => new(sizes[0].Width + 48, sizes[0].Height + 34, sizes[0].Baseline) };
    }
    private void Draw(Expression e, double x, double y, SceneBuilder b)
    {
        var size = Measure(e);
        switch (e.Kind)
        {
            case "empty": b.Line([new(x, y + 15), new(x + size.Width, y + 15)]); break;
            case "atom": var r = new DiagramRect(x, y, size.Width, 30); b.Rect(r, e.Terminal ? C.Surface : C.Background, radius: e.Terminal ? 15 : 4); b.Text(e.Label, r.Inset(8, 2), 14, mono: true); break;
            case "sequence":
                var cursor = x; for (var i = 0; i < e.Values.Length; i++) { var child = e.Values[i]; var childSize = Measure(child); Draw(child, cursor, y + size.Baseline - childSize.Baseline, b); cursor += childSize.Width; if (i < e.Values.Length - 1) { b.Line([new(cursor, y + size.Baseline), new(cursor + 20, y + size.Baseline)]); cursor += 20; } } break;
            case "choice":
                var top = y; var start = new DiagramPoint(x, y + size.Baseline); var end = new DiagramPoint(x + size.Width, y + size.Baseline);
                foreach (var child in e.Values) { var childSize = Measure(child); var childX = x + (size.Width - childSize.Width) / 2; var baseline = top + childSize.Baseline; b.Line([start, new(x + 12, start.Y), new(x + 12, baseline), new(childX, baseline)]); Draw(child, childX, top, b); b.Line([new(childX + childSize.Width, baseline), new(end.X - 12, baseline), new(end.X - 12, end.Y), end]); top += childSize.Height + 18; } break;
            case "optional": Draw(new("choice", Children: [new("empty"), e.Values[0]]), x, y, b); break;
            case "repetition":
                var s = Measure(e.Values[0]); var lineY = y + size.Baseline; var bottom = y + s.Height + 22; b.Line([new(x, lineY), new(x + 24, lineY)]); Draw(e.Values[0], x + 24, y, b); b.Line([new(x + 24 + s.Width, lineY), new(x + size.Width, lineY)]); b.Line([new(x + size.Width - 8, lineY), new(x + size.Width - 8, bottom), new(x + 8, bottom), new(x + 8, lineY)], arrow: true); break;
        }
    }
}
