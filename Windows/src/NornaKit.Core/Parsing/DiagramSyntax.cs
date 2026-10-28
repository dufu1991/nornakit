using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace NornaKit;

internal sealed record SourceLine(string Text, string Raw, int Number)
{
    public int Indent => Raw.TakeWhile(char.IsWhiteSpace).Sum(character => character == '\t' ? 4 : 1);
    public DiagramRenderException Error(string message, string code = "unsupported-syntax") => new(message, code, Number);
}

internal static class DiagramSyntax
{
    public static List<SourceLine> Lines(string source)
    {
        var result = new List<SourceLine>();
        var rows = Regex.Split(source, "\r\n|\r|\n");
        for (var index = 0; index < rows.Length; index++)
        {
            var raw = rows[index];
            var text = raw.Trim();
            var quoted = false;
            for (var position = 0; position < text.Length - 1; position++)
            {
                if (text[position] == '"') quoted = !quoted;
                if (!quoted && text[position] == '%' && text[position + 1] == '%') { text = text[..position].Trim(); break; }
            }
            if (text.Length != 0) result.Add(new(text, raw, index + 1));
        }
        return result;
    }
    public static string[]? Match(string pattern, string value)
    {
        var match = Regex.Match(value, pattern, RegexOptions.CultureInvariant, TimeSpan.FromSeconds(2));
        return match.Success ? match.Groups.Values.Select(group => group.Value).ToArray() : null;
    }
    public static string Label(string value)
    {
        value = value.Trim();
        if (value.Length >= 2 && value[0] == '"' && value[^1] == '"') value = value[1..^1];
        return value.Replace("<br/>", "\n", StringComparison.Ordinal).Replace("<br />", "\n", StringComparison.Ordinal)
            .Replace("<br>", "\n", StringComparison.Ordinal).Replace("\\n", "\n", StringComparison.Ordinal);
    }
    public static double Number(string text, SourceLine line, bool positive = false)
    {
        if (!double.TryParse(text.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var value)
            || !double.IsFinite(value) || Math.Abs(value) > 1e12 || positive && value <= 0)
            throw line.Error(positive ? "A finite positive number is required." : "A finite number is required.", "semantic");
        return value;
    }
    public static List<string> Split(string value, char separator = ',')
    {
        var values = new List<string>();
        var buffer = new StringBuilder();
        var quoted = false;
        var depth = 0;
        foreach (var character in value)
        {
            if (character == '"') quoted = !quoted;
            if (!quoted)
            {
                if ("([{<".Contains(character)) depth++;
                if (")]}>".Contains(character)) depth--;
            }
            if (character == separator && !quoted && depth == 0) { values.Add(buffer.ToString().Trim()); buffer.Clear(); }
            else buffer.Append(character);
        }
        values.Add(buffer.ToString().Trim());
        return values;
    }
    public static string Title(IEnumerable<SourceLine> lines) => lines.FirstOrDefault(line => line.Text.StartsWith("title ", StringComparison.Ordinal)) is { } title ? Label(title.Text[6..]) : "";
    public static void Nonempty(int count, DiagramKind kind)
    {
        if (count == 0) throw new DiagramRenderException($"{kind.Id()} has no drawable data.", "semantic");
        if (count > 500) throw new DiagramRenderException("A diagram can contain at most 500 data items.", "limit");
    }
}

internal sealed record MermaidDocument(string Body, string? Title)
{
    public static MermaidDocument Prepare(string source)
    {
        var lines = Regex.Split(source, "\r\n|\r|\n");
        string? title = null;
        var first = Array.FindIndex(lines, line => !string.IsNullOrWhiteSpace(line));
        if (first >= 0 && lines[first].Trim() == "---")
        {
            var end = Array.FindIndex(lines, first + 1, line => line.Trim() == "---");
            if (end < 0) throw new DiagramRenderException("Front matter has no closing delimiter.", "syntax", first + 1);
            var section = "";
            var inConfig = false;
            for (var index = first + 1; index < end; index++)
            {
                var raw = lines[index];
                var value = raw.Trim();
                if (value.Length == 0 || value.StartsWith('#')) continue;
                var line = new SourceLine(value, raw, index + 1);
                var field = DiagramSyntax.Match(@"^([\w]+)\s*:\s*(.*)$", value) ?? throw line.Error("Unsupported front matter syntax.");
                var key = field[1];
                var argument = DiagramSyntax.Label(field[2]).Trim('\'');
                if (line.Indent == 0)
                {
                    if (key == "title") { title = argument; inConfig = false; }
                    else if (key == "config" && argument.Length == 0) { inConfig = true; section = ""; }
                    else throw line.Error($"Unsupported front matter field: {key}.", "unsupported-configuration");
                }
                else if (inConfig)
                {
                    if (line.Indent == 2)
                    {
                        if (key is "theme" or "look" && argument.Length != 0) continue;
                        if (key == "layout" && argument == "dagre") continue;
                        if (key is "class" or "sequence" or "flowchart" && argument.Length == 0) { section = key; continue; }
                    }
                    else if (line.Indent == 4 && (section == "class" && key == "hierarchicalNamespaces" && argument == "false"
                        || section == "sequence" && key == "wrap" && argument == "true"
                        || section == "flowchart" && key == "htmlLabels" && argument == "false")) continue;
                    throw line.Error($"Unsupported configuration: {(section.Length == 0 ? key : section + "." + key)}.", "unsupported-configuration");
                }
                else throw line.Error("Invalid front matter indentation.", "syntax");
            }
            for (var index = first; index <= end; index++) lines[index] = "";
        }
        for (var index = 0; index < lines.Length; index++)
            if (lines[index].TrimStart().StartsWith("%%{", StringComparison.Ordinal))
                throw new DiagramRenderException("Init configuration directives are not supported.", "unsupported-configuration", index + 1);
        return new(string.Join('\n', lines), title);
    }
}
