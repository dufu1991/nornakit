using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace NornaStudio;

internal static class Program
{
    [STAThread]
    public static void Main()
    {
        WinRT.ComWrappersSupport.InitializeComWrappers();
        Application.Start(arguments => { SynchronizationContext.SetSynchronizationContext(new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread())); _ = new StudioApp(); });
    }
}

[WinRT.GeneratedWinRTExposedType]
public sealed partial class StudioApp : Application
{
    private StudioWindow? window;
    public StudioApp()
    {
        UnhandledException += (sender, args) => WriteFailure(args.Exception);
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
        window = new(); window.Activate(); await StartAsync();
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
