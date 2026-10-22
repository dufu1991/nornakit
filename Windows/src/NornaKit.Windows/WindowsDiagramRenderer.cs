namespace NornaKit.Windows;

/// <summary>Creates a renderer configured with Windows DirectWrite text and Segoe Fluent Icons.</summary>
public static class WindowsDiagramRenderer
{
    public static IDiagramRenderer Create() => new NativeDiagramRenderer(new WindowsTextLayoutProvider(Microsoft.Graphics.Canvas.CanvasDevice.GetSharedDevice()));
}
