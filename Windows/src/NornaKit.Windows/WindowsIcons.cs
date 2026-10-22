namespace NornaKit.Windows;

public static class WindowsIcons
{
    private static readonly IReadOnlyDictionary<string, string> Glyphs = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["document"] = "\uE8A5", ["upload"] = "\uE898", ["check-circle"] = "\uE73E", ["drive"] = "\uEDA2",
        ["check"] = "\uE73E", ["sparkles"] = "\uE734", ["person"] = "\uE77B", ["arrow-right"] = "\uE72A",
        ["align-center"] = "\uE8E3", ["return"] = "\uE751", ["weather"] = "\uE706", ["folder"] = "\uE8B7",
        ["cloud"] = "\uE753", ["settings"] = "\uE713", ["code"] = "\uE943", ["warning"] = "\uE7BA"
    };
    private static readonly IReadOnlyDictionary<string, string> SfAliases = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["doc.text"] = "document", ["icloud.and.arrow.up"] = "upload", ["checkmark.circle.fill"] = "check-circle",
        ["externaldrive"] = "drive", ["checkmark.seal"] = "check", ["sparkles"] = "sparkles", ["person.fill"] = "person",
        ["arrow.right"] = "arrow-right", ["text.aligncenter"] = "align-center", ["arrow.turn.down.left"] = "return",
        ["cloud.sun.fill"] = "weather"
    };

    public static string? Glyph(string name) => Glyphs.GetValueOrDefault(name);
    public static string? FromSfSymbol(string name) => SfAliases.GetValueOrDefault(name);
}
