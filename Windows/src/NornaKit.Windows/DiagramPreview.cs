using System.Numerics;
using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using global::Windows.Foundation;
using global::Windows.System;

namespace NornaKit.Windows;

/// <summary>A native Win2D preview. View transforms and its grid never modify the scene.</summary>
[WinRT.GeneratedWinRTExposedType]
public sealed partial class DiagramPreview : UserControl, IDisposable
{
    private readonly Image image = new() { Stretch = Stretch.Fill, IsHitTestVisible = false };
    private CanvasImageSource? surface;
    private CanvasDevice? device;
    private XamlRoot? observedRoot;
    private bool invalidated, software;
    private int loadedCount;
    private double surfaceWidth, surfaceHeight, surfaceDpi;
    private DiagramScene? scene;
    private DiagramPalette palette = WindowsPalette.Resolve();
    private bool grid, panning, disposed, fitOnResize = true;
    private Point last;
    private Vector2 pan;
    private float zoom = 1;
    public event Action<Exception>? RenderingFailed;
    public event Action<DiagramScene>? SceneRendered;
    public DiagramPreview()
    {
        Content = image;
        IsTabStop = true; MinWidth = 120; MinHeight = 120;
        AutomationProperties.SetName(this, "Diagram preview");
        AutomationProperties.SetHelpText(this, "Drag to pan. Scroll to zoom. Press 0 to fit, plus or minus to zoom.");
        SizeChanged += (_, _) => { if (fitOnResize) Fit(); else Invalidate(); };
        PointerPressed += (_, e) => { Focus(FocusState.Pointer); panning = true; last = e.GetCurrentPoint(this).Position; CapturePointer(e.Pointer); e.Handled = true; };
        PointerMoved += (_, e) => { if (!panning) return; var point = e.GetCurrentPoint(this).Position; pan += new Vector2((float)(point.X - last.X), (float)(point.Y - last.Y)); last = point; fitOnResize = false; Invalidate(); e.Handled = true; };
        PointerReleased += (_, e) => { panning = false; ReleasePointerCapture(e.Pointer); };
        PointerCaptureLost += (_, _) => panning = false;
        PointerWheelChanged += (_, e) => { var p = e.GetCurrentPoint(this); Zoom(Math.Pow(1.1, p.Properties.MouseWheelDelta / 120d), p.Position); e.Handled = true; };
        KeyDown += (_, e) =>
        {
            switch (e.Key)
            {
                case VirtualKey.Number0: Fit(); break;
                case VirtualKey.Add: case (VirtualKey)187: Zoom(1.2); break;
                case VirtualKey.Subtract: case (VirtualKey)189: Zoom(1 / 1.2); break;
                case VirtualKey.Left: pan.X += 32; break; case VirtualKey.Right: pan.X -= 32; break;
                case VirtualKey.Up: pan.Y += 32; break; case VirtualKey.Down: pan.Y -= 32; break;
                default: return;
            }
            e.Handled = true; Invalidate();
        };
        Loaded += (_, _) =>
        {
            loadedCount++;
            if (observedRoot is not null) observedRoot.Changed -= RootChanged;
            observedRoot = XamlRoot; observedRoot.Changed += RootChanged; Invalidate();
        };
        Unloaded += (_, _) =>
        {
            if (--loadedCount > 0) return;
            panning = false;
            if (observedRoot is not null) observedRoot.Changed -= RootChanged;
            observedRoot = null; ReleaseSurface();
        };
    }
    public DiagramScene? Scene
    { get => scene; set { scene = value; if (fitOnResize) Fit(); Invalidate(); } }
    public DiagramPalette Palette
    { get => palette; set { palette = value; Invalidate(); } }
    public bool ShowGrid
    { get => grid; set { grid = value; Invalidate(); } }
    public double ZoomFactor => zoom;
    /// <summary>Use WARP for deterministic rendering on machines without a hardware graphics adapter.</summary>
    public bool ForceSoftwareRenderer
    { get => software; set { if (software == value) return; software = value; ReleaseSurface(); Invalidate(); } }
    public void Fit()
    {
        fitOnResize = true;
        if (scene is null || ActualWidth <= 0 || ActualHeight <= 0) return;
        zoom = (float)Math.Clamp(Math.Min((ActualWidth - 48) / scene.Size.Width, (ActualHeight - 48) / scene.Size.Height), .02, 4);
        pan = new((float)(ActualWidth - scene.Size.Width * zoom) / 2, (float)(ActualHeight - scene.Size.Height * zoom) / 2); Invalidate();
    }
    public void Zoom(double factor, Point? around = null)
    {
        var center = around ?? new(ActualWidth / 2, ActualHeight / 2); var next = (float)Math.Clamp(zoom * factor, .02, 8); var ratio = next / zoom; var point = new Vector2((float)center.X, (float)center.Y);
        pan = point - (point - pan) * ratio; zoom = next; fitOnResize = false; Invalidate();
    }
    private void RootChanged(XamlRoot sender, XamlRootChangedEventArgs args) => Invalidate();
    private void Invalidate()
    {
        if (disposed || invalidated) return;
        invalidated = DispatcherQueue.TryEnqueue(() => { invalidated = false; Draw(); });
    }
    private void DeviceLost(CanvasDevice sender, object args) => DispatcherQueue.TryEnqueue(() =>
    {
        if (disposed || !ReferenceEquals(sender, device)) return;
        ReleaseSurface(); Invalidate();
    });
    private void ReleaseSurface()
    {
        image.Source = null; surface = null;
        if (device is not null) device.DeviceLost -= DeviceLost;
        device = null;
    }
    private void Draw()
    {
        if (disposed || !IsLoaded || XamlRoot is null || ActualWidth <= 0 || ActualHeight <= 0) return;
        try
        {
            var dpi = XamlRoot.RasterizationScale * 96;
            if (surface is null || surfaceWidth != ActualWidth || surfaceHeight != ActualHeight || surfaceDpi != dpi)
            {
                ReleaseSurface(); device = CanvasDevice.GetSharedDevice(software); device.DeviceLost += DeviceLost;
                surface = new CanvasImageSource(device, (float)ActualWidth, (float)ActualHeight, (float)dpi);
                surfaceWidth = ActualWidth; surfaceHeight = ActualHeight; surfaceDpi = dpi; image.Source = surface;
            }
            using (var drawing = surface.CreateDrawingSession(Win2DScenePainter.Native(palette.Background)))
            {
                if (grid)
                {
                    var color = Win2DScenePainter.Native(palette.Border, .2); const int step = 24;
                    for (var x = (int)(pan.X % step); x < ActualWidth; x += step)
                    for (var y = (int)(pan.Y % step); y < ActualHeight; y += step) drawing.FillCircle(x, y, 1, color);
                }
                if (scene is not null)
                {
                    drawing.Transform = Matrix3x2.CreateScale(zoom) * Matrix3x2.CreateTranslation(pan);
                    Win2DScenePainter.Draw(drawing, scene, palette);
                }
            }
            if (scene is not null) SceneRendered?.Invoke(scene);
        }
        catch (Exception error) when (device is not null && device.IsDeviceLost(error.HResult))
        {
            // Win2D replaces a lost shared device; retry with freshly created surface resources.
            device.RaiseDeviceLost(); ReleaseSurface(); Invalidate();
        }
        catch (Exception error)
        {
            RenderingFailed?.Invoke(error);
            throw;
        }
    }
    public void Dispose()
    {
        if (disposed) return; disposed = true; panning = false;
        if (observedRoot is not null) observedRoot.Changed -= RootChanged;
        observedRoot = null; ReleaseSurface(); Content = null;
    }
}
