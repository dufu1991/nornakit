using NornaKit;

namespace NornaStudio;

internal sealed record ExportSnapshot(DiagramScene Scene, DiagramPalette Palette, string Source);

internal static class SourceSelection
{
    public static (int Start, int Length) Locate(string source, int line, int? column)
    {
        var offset = 0; var current = 1;
        while (offset < source.Length && current < line)
        {
            var character = source[offset++];
            if (character == '\r') { if (offset < source.Length && source[offset] == '\n') offset++; current++; }
            else if (character == '\n') current++;
        }
        var end = offset; while (end < source.Length && source[end] is not ('\r' or '\n')) end++;
        var start = offset + Math.Clamp((column ?? 1) - 1, 0, end - offset);
        return (start, end - start);
    }
}

internal sealed class StudioSession(IDiagramRenderer renderer, Func<TimeSpan, CancellationToken, Task>? delay = null) : IDisposable
{
    private readonly Func<TimeSpan, CancellationToken, Task> pause = delay ?? Task.Delay;
    private CancellationTokenSource? pending;
    private long revision, renderedRevision = -1;
    public string Source { get; private set; } = "";
    public DiagramArtifact? Artifact { get; private set; }
    public DiagramRenderException? Diagnostic { get; private set; }
    public bool Busy { get; private set; }
    public bool CanExport => Artifact is not null && renderedRevision == revision && !Busy && Diagnostic is null;
    public event Action? Changed;
    public async Task UpdateAsync(string source, DiagramLayoutOptions options)
    {
        Source = source; var request = ++revision; pending?.Cancel();
        using var cancellation = new CancellationTokenSource(); pending = cancellation; Busy = true; Diagnostic = null; Changed?.Invoke();
        try
        {
            await pause(TimeSpan.FromMilliseconds(250), cancellation.Token);
            var artifact = await renderer.RenderAsync(source, options, cancellation.Token);
            if (request != revision || cancellation.IsCancellationRequested) return;
            Artifact = artifact; renderedRevision = request;
        }
        catch (OperationCanceledException) when (cancellation.IsCancellationRequested) { }
        catch (DiagramRenderException diagnostic) { if (request == revision) Diagnostic = diagnostic; }
        finally { if (request == revision) { Busy = false; pending = null; Changed?.Invoke(); } }
    }
    public ExportSnapshot Snapshot(DiagramPalette palette)
        => CanExport ? new(Artifact!.Scene, palette, Source) : throw new InvalidOperationException("The source and rendered scene do not match.");
    public void Dispose() { revision++; pending?.Cancel(); pending = null; }
}
