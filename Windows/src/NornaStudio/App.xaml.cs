using Microsoft.UI.Xaml;

namespace NornaStudio;

public sealed partial class App : Application
{
    private StudioWindow? window;
    public App()
    {
        // Application construction precedes the WinUI unhandled-exception boundary.
        try
        {
            if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 } directory)
            { Directory.CreateDirectory(directory); File.AppendAllText(Path.Combine(directory, "steps.log"), "application-constructed\n"); }
            UnhandledException += (sender, args) => WriteFailure(args.Exception);
            InitializeComponent();
        }
        catch (Exception error) { WriteFailure(error); throw; }
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
