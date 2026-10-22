using Microsoft.UI.Xaml;

namespace NornaStudio;

public sealed partial class StudioApp : Application
{
    private StudioWindow? window;
    public StudioApp()
    {
        UnhandledException += (sender, args) => WriteFailure(args.Exception);
        // Application construction precedes the WinUI unhandled-exception boundary.
        try { InitializeComponent(); }
        catch (Exception error) { WriteFailure(error); throw; }
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 } output)
        {
            Directory.CreateDirectory(output);
            File.WriteAllText(Path.Combine(output, "application-resources.txt"), $"Merged dictionaries: {Resources.MergedDictionaries.Count}\n" + string.Join('\n', typeof(StudioApp).Assembly.GetManifestResourceNames()));
        }
    }
    private static void WriteFailure(Exception error)
    {
        var directory = Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE");
        if (string.IsNullOrEmpty(directory)) return;
        Directory.CreateDirectory(directory); File.WriteAllText(Path.Combine(directory, "failure.txt"), error.ToString());
    }
    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        var settings = await new StudioSettingsStore().LoadAsync();
        window = new(settings); window.Activate(); await StartAsync();
    }
    private async Task StartAsync()
    {
        await window!.InitializeAsync();
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 } directory)
        {
            await window.VerifyStartupAsync(directory);
            Exit();
        }
    }
}
