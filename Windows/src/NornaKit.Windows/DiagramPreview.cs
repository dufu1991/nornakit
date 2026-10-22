using System.Numerics;
using Microsoft.Graphics.Canvas.UI.Xaml;
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
    private readonly CanvasControl canvas = new();
    private DiagramScene? scene;
    private DiagramPalette palette = WindowsPalette.Resolve();
    private bool grid, panning, fitOnResize = true;
    private Point last;
    private Vector2 pan;
    private float zoom = 1;
    public DiagramPreview()
    {
        Content = canvas; IsTabStop = true; MinWidth = 120; MinHeight = 120;
        AutomationProperties.SetName(this, "Diagram preview");
        AutomationProperties.SetHelpText(this, "Drag to pan. Scroll to zoom. Press 0 to fit, plus or minus to zoom.");
        canvas.Draw += (_, args) =>
        {
            var drawing = args.DrawingSession; drawing.Clear(Win2DScenePainter.Native(palette.Background));
            if (grid)
            {
                var color = Win2DScenePainter.Native(palette.Border, .2); const int step = 24;
                for (var x = (int)(pan.X % step); x < canvas.ActualWidth; x += step) for (var y = (int)(pan.Y % step); y < canvas.ActualHeight; y += step) drawing.FillCircle(x, y, 1, color);
            }
            if (scene is null) return;
            drawing.Transform = Matrix3x2.CreateScale(zoom) * Matrix3x2.CreateTranslation(pan);
            Win2DScenePainter.Draw(drawing, scene, palette);
        };
        SizeChanged += (_, _) => { if (fitOnResize) Fit(); else canvas.Invalidate(); };
        PointerPressed += (_, e) => { Focus(FocusState.Pointer); panning = true; last = e.GetCurrentPoint(this).Position; CapturePointer(e.Pointer); e.Handled = true; };
        PointerMoved += (_, e) => { if (!panning) return; var point = e.GetCurrentPoint(this).Position; pan += new Vector2((float)(point.X - last.X), (float)(point.Y - last.Y)); last = point; fitOnResize = false; canvas.Invalidate(); e.Handled = true; };
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
            e.Handled = true; canvas.Invalidate();
        };
        Unloaded += (_, _) => { panning = false; };
    }
    public DiagramScene? Scene
    { get => scene; set { scene = value; if (fitOnResize) Fit(); canvas.Invalidate(); } }
    public DiagramPalette Palette
    { get => palette; set { palette = value; canvas.Invalidate(); } }
    public bool ShowGrid
    { get => grid; set { grid = value; canvas.Invalidate(); } }
    public double ZoomFactor => zoom;
    public void Fit()
    {
        fitOnResize = true;
        if (scene is null || ActualWidth <= 0 || ActualHeight <= 0) return;
        zoom = (float)Math.Clamp(Math.Min((ActualWidth - 48) / scene.Size.Width, (ActualHeight - 48) / scene.Size.Height), .02, 4);
        pan = new((float)(ActualWidth - scene.Size.Width * zoom) / 2, (float)(ActualHeight - scene.Size.Height * zoom) / 2); canvas.Invalidate();
    }
    public void Zoom(double factor, Point? around = null)
    {
        var center = around ?? new(ActualWidth / 2, ActualHeight / 2); var next = (float)Math.Clamp(zoom * factor, .02, 8); var ratio = next / zoom; var point = new Vector2((float)center.X, (float)center.Y);
        pan = point - (point - pan) * ratio; zoom = next; fitOnResize = false; canvas.Invalidate();
    }
    public void Dispose() { panning = false; canvas.RemoveFromVisualTree(); Content = null; }
}
