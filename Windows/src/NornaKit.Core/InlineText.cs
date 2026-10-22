using System.Collections.Immutable;
using System.Text.RegularExpressions;

namespace NornaKit;

public static partial class InlineText
{
    [GeneratedRegex(@"\[(/?)(b|i|code|u|s|color)(?:=(#[A-Fa-f0-9]{6}))?\]", RegexOptions.CultureInvariant)]
    private static partial Regex Tags();
    [GeneratedRegex(@":(sf|win):([A-Za-z0-9][A-Za-z0-9._-]*)(?:@(monochrome|hierarchical|multicolor|palette\(#[A-Fa-f0-9]{6}(?:,#[A-Fa-f0-9]{6}){0,2}\)))?:", RegexOptions.CultureInvariant)]
    private static partial Regex Icons();

    /// <summary>Parses balanced native formatting tags. Unknown or unbalanced markup remains literal text.</summary>
    public static ImmutableArray<InlineRun> Parse(string source, TextStyle? style = null)
    {
        style ??= new();
        var tags = Tags().Matches(source).Where(tag => tag.Groups[2].Value == "color"
            ? tag.Groups[1].Length != 0 || tag.Groups[3].Success : !tag.Groups[3].Success).ToArray();
        var stack = new Stack<int>();
        var valid = new HashSet<int>();
        for (var index = 0; index < tags.Length; index++)
        {
            if (tags[index].Groups[1].Length == 0) stack.Push(index);
            else if (stack.TryPeek(out var opening) && tags[opening].Groups[2].Value == tags[index].Groups[2].Value)
            {
                valid.Add(opening); valid.Add(index); stack.Pop();
            }
            else stack.Clear();
        }
        var result = ImmutableArray.CreateBuilder<InlineRun>();
        var styles = new Stack<TextStyle>();
        styles.Push(style);
        var cursor = 0;
        for (var index = 0; index < tags.Length; index++)
        {
            if (!valid.Contains(index)) continue;
            var tag = tags[index];
            Add(source[cursor..tag.Index], styles.Peek(), result);
            if (tag.Groups[1].Length != 0) styles.Pop();
            else
            {
                var current = styles.Peek();
                styles.Push(tag.Groups[2].Value switch
                {
                    "b" => current with { Bold = true },
                    "i" => current with { Italic = true },
                    "code" => current with { Monospace = true },
                    "u" => current with { Underline = true },
                    "s" => current with { Strikethrough = true },
                    "color" => current with { Color = DiagramColor.FromHex(tag.Groups[3].Value) },
                    _ => throw new InvalidOperationException("Unexpected supported tag.")
                });
            }
            cursor = tag.Index + tag.Length;
        }
        Add(source[cursor..], styles.Peek(), result);
        return result.ToImmutable();
    }

    private static void Add(string text, TextStyle style, ImmutableArray<InlineRun>.Builder result)
    {
        var cursor = 0;
        foreach (Match match in Icons().Matches(text))
        {
            if (match.Index > cursor) result.Add(new(text[cursor..match.Index], style));
            var mode = match.Groups[3].Value;
            var iconStyle = mode.StartsWith("palette(", StringComparison.Ordinal)
                ? style with { Color = DiagramColor.FromHex(mode.Substring(8, 7)) } : style;
            result.Add(new(match.Value, iconStyle, $"{match.Groups[1].Value}:{match.Groups[2].Value}"));
            cursor = match.Index + match.Length;
        }
        if (cursor < text.Length) result.Add(new(text[cursor..], style));
    }
}
