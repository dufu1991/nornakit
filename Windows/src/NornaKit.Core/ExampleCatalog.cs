using System.Collections.Immutable;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace NornaKit;

public enum DiagramExampleLanguage { English, SimplifiedChinese }
public sealed record LocalizedExampleText(string En, string Zh)
{
    public string For(DiagramExampleLanguage language) => language switch
    {
        DiagramExampleLanguage.English => En,
        DiagramExampleLanguage.SimplifiedChinese => Zh,
        _ => throw new ArgumentOutOfRangeException(nameof(language))
    };
}
public sealed record DiagramExample(string Id, string Kind, string Symbol, LocalizedExampleText Titles, LocalizedExampleText Sources)
{
    public string Source(DiagramExampleLanguage language) => Sources.For(language);
    public string Title(DiagramExampleLanguage language) => Titles.For(language);
}
public sealed record DiagramKindInfo(string Id, string Category, string StarterId, LocalizedExampleText Titles, LocalizedExampleText LayoutNotes);
public sealed record DiagramExampleComparison(string Kind, string SimpleId, string ComplexId, LocalizedExampleText LayoutNotes);

/// <summary>Canonical bilingual samples shared by the Swift and C# libraries.</summary>
public static class ExampleCatalog
{
    private sealed record Snapshot(int SchemaVersion, ImmutableArray<DiagramExample> Examples,
        ImmutableArray<DiagramKindInfo> Kinds, ImmutableArray<DiagramExampleComparison> Comparisons,
        ImmutableDictionary<string, ImmutableArray<string>> Groups);
    private static readonly Lazy<Snapshot> Data = new(() =>
    {
        using var stream = typeof(ExampleCatalog).Assembly.GetManifestResourceStream("NornaKit.examples.json")
            ?? throw new InvalidDataException("Missing bundled example catalog.");
        var snapshot = JsonSerializer.Deserialize<Snapshot>(stream, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
            RespectNullableAnnotations = true,
            RespectRequiredConstructorParameters = true
        }) ?? throw new InvalidDataException("The bundled example catalog is null.");
        if (snapshot.SchemaVersion != 1) throw new InvalidDataException("Unsupported bundled example schema version.");
        return snapshot;
    });
    private static readonly Lazy<ImmutableDictionary<string, DiagramExample>> Index = new(() => All.ToImmutableDictionary(example => example.Id));
    private static readonly Lazy<ImmutableDictionary<string, DiagramKindInfo>> KindIndex = new(() => Kinds.ToImmutableDictionary(kind => kind.Id));

    public static ImmutableArray<DiagramExample> All => Data.Value.Examples;
    public static ImmutableArray<DiagramKindInfo> Kinds => Data.Value.Kinds;
    public static ImmutableArray<DiagramExampleComparison> Comparisons => Data.Value.Comparisons;
    public static DiagramExample Get(string id) => Index.Value[id];
    public static DiagramExample Starter(string kind) => Get(KindIndex.Value[kind].StarterId);
    public static ImmutableArray<DiagramExample> Group(string name) => Data.Value.Groups[name].Select(Get).ToImmutableArray();
}
