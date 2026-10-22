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
internal sealed partial class StudioApp : Application
{
    private StudioWindow? window;
    public StudioApp() => Resources.MergedDictionaries.Add(new XamlControlsResources());
    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        window = new(); window.Activate(); _ = StartAsync();
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
