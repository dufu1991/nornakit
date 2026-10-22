using System.Text.Json;
using NornaKit.Windows;

namespace NornaStudio;

internal sealed record StudioSettings
{
    public string Source { get; init; } = NornaKit.ExampleCatalog.Starter("flowchart").Source(NornaKit.DiagramExampleLanguage.English);
    public string Language { get; init; } = "en";
    public CanvasAppearance Appearance { get; init; } = CanvasAppearance.System;
    public DiagramColorStyle ColorStyle { get; init; } = DiagramColorStyle.Themed;
    public string Accent { get; init; } = "5148d8";
    public bool Grid { get; init; }
    public string? SourcePath { get; init; }
}
internal sealed class StudioSettingsStore
{
    private readonly string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NornaKit", "NornaStudio");
    private readonly SemaphoreSlim writer = new(1, 1);
    public async Task<StudioSettings> LoadAsync()
    {
        var file = Path.Combine(directory, "settings.json"); if (!File.Exists(file)) return new();
        await using var stream = File.OpenRead(file);
        return await JsonSerializer.DeserializeAsync<StudioSettings>(stream) ?? throw new InvalidDataException("The saved workspace is empty.");
    }
    public async Task SaveAsync(StudioSettings settings)
    {
        await writer.WaitAsync();
        try
        {
            Directory.CreateDirectory(directory); var file = Path.Combine(directory, "settings.json"); var temporary = file + ".tmp";
            await File.WriteAllTextAsync(temporary, JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true })); File.Move(temporary, file, true);
        }
        finally { writer.Release(); }
    }
}
