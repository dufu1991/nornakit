using Microsoft.UI;
using global::Windows.UI.ViewManagement;

namespace NornaKit.Windows;

public enum CanvasAppearance { System, Light, Dark, HighContrastLight, HighContrastDark }
public enum DiagramColorStyle { Neutral, Themed, Custom }

public static class WindowsPalette
{
    public static DiagramPalette Resolve(CanvasAppearance appearance = CanvasAppearance.System,
        DiagramColorStyle style = DiagramColorStyle.Themed, DiagramColor? customAccent = null)
    {
        var settings = new UISettings();
        var accessibility = new AccessibilitySettings();
        var systemBackground = settings.GetColorValue(UIColorType.Background);
        var forcedContrast = appearance is CanvasAppearance.HighContrastLight or CanvasAppearance.HighContrastDark;
        var highContrast = accessibility.HighContrast || forcedContrast;
        var dark = appearance is CanvasAppearance.Dark or CanvasAppearance.HighContrastDark || appearance == CanvasAppearance.System && systemBackground.R < 128;
        var background = forcedContrast ? dark ? C("000000") : C("ffffff") : accessibility.HighContrast ? From(systemBackground) : dark ? C("202020") : C("ffffff");
        var foreground = forcedContrast ? dark ? C("ffffff") : C("000000") : accessibility.HighContrast ? From(settings.GetColorValue(UIColorType.Foreground)) : dark ? C("f5f5f5") : C("1a1a1a");
        var accent = style == DiagramColorStyle.Custom ? customAccent ?? C("5148d8") : From(settings.GetColorValue(UIColorType.Accent));
        if (style == DiagramColorStyle.Neutral) accent = foreground;
        if (highContrast) accent = foreground;
        return new(background, foreground, highContrast ? foreground : dark ? C("cccccc") : C("5c5c5c"), foreground,
            highContrast ? background : dark ? C("2c2c2c") : C("f3f3f3"),
            highContrast ? background : dark ? C("383838") : C("e8e8e8"),
            highContrast ? foreground : dark ? C("9d9d9d") : C("707070"), accent,
            highContrast ? [foreground, foreground, foreground, foreground, foreground, foreground, foreground, foreground]
                : [accent, C("f58518"), C("54a24b"), C("e45756"), C("72b7b2"), C("eeca3b"), C("b279a2"), C("9d755d")]);
    }
    private static DiagramColor C(string hex) => DiagramColor.FromHex(hex);
    private static DiagramColor From(global::Windows.UI.Color color) => new(color.R, color.G, color.B, color.A);
}
