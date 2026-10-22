using System.Runtime.CompilerServices;

namespace NornaStudio;

internal static class StartupDiagnostics
{
    private static readonly object Writer = new();
    [ModuleInitializer]
    internal static void Initialize()
    {
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is not { Length: > 0 } directory) return;
        Directory.CreateDirectory(directory);
        File.AppendAllText(Path.Combine(directory, "steps.log"), "managed-module-loaded\n");
        AppDomain.CurrentDomain.FirstChanceException += (_, args) =>
        {
            if (args.Exception.HResult != unchecked((int)0x8000ffff)) return;
            lock (Writer) File.AppendAllText(Path.Combine(directory, "managed-first-chance.txt"), args.Exception + "\n");
        };
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            lock (Writer) File.AppendAllText(Path.Combine(directory, "managed-unhandled.txt"), args.ExceptionObject + "\n");
        };
    }
}
