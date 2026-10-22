using System.Collections.Immutable;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace NornaKit;

public sealed record OfficialExampleOrigin(string Url, int Ordinal, string Section);
public sealed record OfficialExample(string Id, string Kind, string Sha256, string Source, ImmutableArray<OfficialExampleOrigin> Origins);
public sealed record OfficialExamplePage(string Url, string File, string Sha256, int ExampleCount);
public sealed record OfficialExampleSnapshot(int SchemaVersion, string RetrievedAt,
    ImmutableArray<OfficialExamplePage> Pages, ImmutableArray<OfficialExample> Examples);
public sealed record OfficialValidationResult(string Id, string Kind, string Status,
    string? Code = null, string? Message = null, int? Line = null, double? Width = null, double? Height = null);

/// <summary>Uses the same checked in source and status resources as the Swift library.</summary>
public static class OfficialExampleCatalog
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        RespectNullableAnnotations = true,
        RespectRequiredConstructorParameters = true
    };
    private static readonly Lazy<OfficialExampleSnapshot> SnapshotValue = new(() =>
    {
        var snapshot = Load<OfficialExampleSnapshot>("official-examples");
        if (snapshot.SchemaVersion != 1) throw new InvalidDataException("Unsupported official example schema version.");
        return snapshot;
    });
    private static readonly Lazy<ImmutableDictionary<string, OfficialValidationResult>> ResultValue = new(() =>
        Load<ImmutableArray<OfficialValidationResult>>("official-status").ToImmutableDictionary(result => result.Id));

    public static OfficialExampleSnapshot Snapshot => SnapshotValue.Value;
    public static ImmutableDictionary<string, OfficialValidationResult> Results => ResultValue.Value;

    private static T Load<T>(string name)
    {
        using var stream = typeof(OfficialExampleCatalog).Assembly.GetManifestResourceStream($"NornaKit.{name}.json")
            ?? throw new InvalidDataException($"Missing bundled resource: {name}.");
        return JsonSerializer.Deserialize<T>(stream, Options)
            ?? throw new InvalidDataException($"The bundled resource is null: {name}.");
    }
}
