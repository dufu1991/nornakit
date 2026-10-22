using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace NornaStudio;

[WinRT.GeneratedWinRTExposedType]
public sealed partial class StudioApp : Application
{
    private StudioWindow? window;
    public StudioApp()
    {
        UnhandledException += (sender, args) => WriteFailure(args.Exception);
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 } directory)
        {
            Directory.CreateDirectory(directory);
            DebugSettings.IsXamlResourceReferenceTracingEnabled = true;
            DebugSettings.XamlResourceReferenceFailed += (_, args) => File.AppendAllText(Path.Combine(directory, "xaml-resources.log"), args.Message + "\n");
        }
        InitializeComponent();
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
