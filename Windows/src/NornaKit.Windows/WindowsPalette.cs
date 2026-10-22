using Microsoft.UI;
using global::Windows.UI.ViewManagement;

namespace NornaKit.Windows;

public enum CanvasAppearance { System, Light, Dark }
public enum DiagramColorStyle { Neutral, Themed, Custom }

public static class WindowsPalette
{
    public static DiagramPalette Resolve(CanvasAppearance appearance = CanvasAppearance.System,
        DiagramColorStyle style = DiagramColorStyle.Themed, DiagramColor? customAccent = null)
    {
        var settings = new UISettings();
        var accessibility = new AccessibilitySettings();
        var systemBackground = settings.GetColorValue(UIColorType.Background);
        var dark = appearance == CanvasAppearance.Dark || appearance == CanvasAppearance.System && systemBackground.R < 128;
        var background = accessibility.HighContrast ? From(systemBackground) : dark ? C("202020") : C("ffffff");
        var foreground = accessibility.HighContrast ? From(settings.GetColorValue(UIColorType.Foreground)) : dark ? C("f5f5f5") : C("1a1a1a");
        var accent = style == DiagramColorStyle.Custom ? customAccent ?? C("5148d8") : From(settings.GetColorValue(UIColorType.Accent));
        if (style == DiagramColorStyle.Neutral) accent = foreground;
        return new(background, foreground, accessibility.HighContrast ? foreground : dark ? C("cccccc") : C("5c5c5c"), foreground,
            accessibility.HighContrast ? background : dark ? C("2c2c2c") : C("f3f3f3"),
            accessibility.HighContrast ? background : dark ? C("383838") : C("e8e8e8"),
            accessibility.HighContrast ? foreground : dark ? C("9d9d9d") : C("707070"), accent,
            [accent, C("f58518"), C("54a24b"), C("e45756"), C("72b7b2"), C("eeca3b"), C("b279a2"), C("9d755d")]);
    }
    private static DiagramColor C(string hex) => DiagramColor.FromHex(hex);
    private static DiagramColor From(global::Windows.UI.Color color) => new(color.R, color.G, color.B, color.A);
}
