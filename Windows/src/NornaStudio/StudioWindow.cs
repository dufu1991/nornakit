using System.Text;
using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.Windows.Storage.Pickers;
using NornaKit;
using NornaKit.Windows;
using global::Windows.ApplicationModel.DataTransfer;
using global::Windows.System;
using global::Windows.UI;
using global::Windows.UI.ViewManagement;

namespace NornaStudio;

internal sealed partial class StudioWindow : Window
{
    private readonly StudioSession session = new(WindowsDiagramRenderer.Create());
    private readonly StudioSettingsStore store = new();
    private readonly UISettings systemSettings = new();
    private readonly Microsoft.UI.System.ThemeSettings themeSettings;
    private StudioSettings settings = new();
    private Grid root = null!;
    private TextBox editor = null!;
    private readonly DiagramPreview preview = new();
    private TextBlock status = null!;
    private Button diagnostic = null!;
    private InfoBar errors = null!;
    private AppBarButton export = null!, copy = null!;
    private ComboBox categories = null!, kinds = null!;
    private ListView examples = null!;
    private string search = "";
    private bool rebuilding, closing;
    private DiagramExampleLanguage Language => settings.Language == "zh" ? DiagramExampleLanguage.SimplifiedChinese : DiagramExampleLanguage.English;
    private string L(string en, string zh) => settings.Language == "zh" ? zh : en;
    private DiagramPalette Palette => WindowsPalette.Resolve(settings.Appearance, settings.ColorStyle, DiagramColor.FromHex(settings.Accent));
    public StudioWindow(StudioSettings initialSettings)
    {
        settings = initialSettings;
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 }) preview.ForceSoftwareRenderer = true;
        preview.Element.Loaded += (_, _) => SmokeStep("preview-loaded");
        preview.RenderingFailed += error =>
        {
            if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is not { Length: > 0 } directory) return;
            Directory.CreateDirectory(directory); File.WriteAllText(Path.Combine(directory, "drawing-failure.txt"), error.ToString());
        };
        preview.Element.SizeChanged += (sender, e) => { if (!closing && !rebuilding && !session.Busy && session.Artifact is not null && Math.Abs(e.NewSize.Width - e.PreviousSize.Width) > 32) _ = RunAsync(RenderAsync); };
        Title = "Norna Studio"; AppWindow.SetIcon(Path.Combine(AppContext.BaseDirectory, "NornaStudio.ico")); AppWindow.Resize(new(1440, 920)); SystemBackdrop = new MicaBackdrop(); Build();
        session.Changed += Refresh;
        systemSettings.ColorValuesChanged += ColorsChanged;
        themeSettings = Microsoft.UI.System.ThemeSettings.CreateForWindowId(AppWindow.Id);
        themeSettings.Changed += ThemeChanged;
        AppWindow.Closing += (sender, args) =>
        {
            if (closing) return; args.Cancel = true;
            _ = RunAsync(async () => { await SaveWorkspaceAsync(); closing = true; session.Dispose(); preview.Dispose(); systemSettings.ColorValuesChanged -= ColorsChanged; themeSettings.Changed -= ThemeChanged; Close(); });
        };
    }
    public async Task InitializeAsync() => await RunAsync(async () => { SmokeStep("initial-render"); await RenderAsync(); SmokeStep("initialized"); });
    private static void SmokeStep(string step)
    {
        if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is not { Length: > 0 } directory) return;
        Directory.CreateDirectory(directory); File.AppendAllText(Path.Combine(directory, "steps.log"), $"{DateTime.UtcNow:O} {step}\n");
    }
    internal async Task VerifyStartupAsync(string directory)
    {
        SmokeStep("verify-startup");
        Directory.CreateDirectory(directory);
        if (!session.CanExport || session.Artifact is null) throw new InvalidOperationException("The initial native workbench preview was not rendered.");
        await WaitForPreviewFrameAsync();
        SmokeStep("default-device"); preview.ForceSoftwareRenderer = false; await WaitForPreviewFrameAsync();
        SmokeStep("software-device"); preview.ForceSoftwareRenderer = true; await WaitForPreviewFrameAsync();
        foreach (var language in new[] { "en", "zh" })
        {
            SmokeStep($"language-{language}"); settings = settings with { Language = language }; Build(); await RenderAsync();
            await WaitForPreviewFrameAsync();
            if (examples.Items.Count == 0 || !export.IsEnabled) throw new InvalidOperationException("The native workbench lost its examples or export command.");
            var scene = session.Snapshot(Palette); await File.WriteAllTextAsync(Path.Combine(directory, $"studio-{language}.svg"), SvgExporter.Export(scene.Scene, scene.Palette));
        }
        await File.WriteAllTextAsync(Path.Combine(directory, "studio.json"), JsonSerializer.Serialize(new { status = "passed", architecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(), families = ExampleCatalog.Kinds.Length, examples = ExampleCatalog.All.Length, title = Title }));
    }
    private async Task WaitForPreviewFrameAsync()
    {
        var scene = session.Artifact!.Scene;
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        Action<DiagramScene> rendered = value => { if (ReferenceEquals(value, scene)) completion.TrySetResult(); };
        preview.SceneRendered += rendered;
        try { preview.Scene = scene; await completion.Task.WaitAsync(TimeSpan.FromSeconds(15)); SmokeStep("preview-frame-rendered"); }
        finally { preview.SceneRendered -= rendered; }
    }
    private void ColorsChanged(UISettings sender, object args) => DispatcherQueue.TryEnqueue(RefreshAppearance);
    private void ThemeChanged(Microsoft.UI.System.ThemeSettings sender, object args) => DispatcherQueue.TryEnqueue(RefreshAppearance);
    private void RefreshAppearance()
    {
        var palette = Palette; preview.Palette = palette;
        root.Background = new SolidColorBrush(Color.FromArgb(palette.Background.A, palette.Background.R, palette.Background.G, palette.Background.B));
    }
    private void Build()
    {
        rebuilding = true;
        if (preview.Element.Parent is Panel previousPanel) previousPanel.Children.Remove(preview.Element);
        root = new() { RequestedTheme = settings.Appearance switch { CanvasAppearance.Light or CanvasAppearance.HighContrastLight => ElementTheme.Light, CanvasAppearance.Dark or CanvasAppearance.HighContrastDark => ElementTheme.Dark, _ => ElementTheme.Default } };
        root.RowDefinitions.Add(new() { Height = GridLength.Auto }); root.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) }); root.RowDefinitions.Add(new() { Height = GridLength.Auto });
        root.RowDefinitions.Add(new() { Height = GridLength.Auto });
        var toolbar = new CommandBar { DefaultLabelPosition = CommandBarDefaultLabelPosition.Right, IsOpen = false };
        toolbar.Content = new TextBlock { Text = "Norna Studio", FontSize = 20, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, Margin = new(20, 12, 24, 12) };
        toolbar.PrimaryCommands.Add(Command(L("Open", "打开"), Symbol.OpenFile, OpenAsync, VirtualKey.O));
        toolbar.PrimaryCommands.Add(Command(L("Save", "保存"), Symbol.Save, () => SaveAsync(false), VirtualKey.S));
        toolbar.PrimaryCommands.Add(Command(L("Save as", "另存为"), Symbol.SaveLocal, () => SaveAsync(true), VirtualKey.S, true));
        toolbar.PrimaryCommands.Add(new AppBarSeparator());
        copy = Command(L("Copy SVG", "复制 SVG"), Symbol.Copy, CopyAsync, VirtualKey.C, true); toolbar.PrimaryCommands.Add(copy);
        export = Command(L("Export", "导出"), Symbol.Download, ExportAsync, VirtualKey.E); toolbar.PrimaryCommands.Add(export);
        toolbar.SecondaryCommands.Add(Command(L("Settings", "设置"), Symbol.Setting, SettingsAsync));
        root.Children.Add(toolbar);
        var workspace = new Grid { ColumnSpacing = 1 };
        workspace.ColumnDefinitions.Add(new() { Width = new(240) }); workspace.ColumnDefinitions.Add(new() { Width = new(2, GridUnitType.Star), MinWidth = 240, MaxWidth = 640 }); workspace.ColumnDefinitions.Add(new() { Width = new(3, GridUnitType.Star), MinWidth = 180 });
        Grid.SetRow(workspace, 1); root.Children.Add(workspace);
        var library = new Grid { Padding = new(16), RowSpacing = 10 };
        for (var i = 0; i < 4; i++) library.RowDefinitions.Add(new() { Height = i == 3 ? new(1, GridUnitType.Star) : GridLength.Auto });
        categories = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, Header = L("Category", "分类") };
        categories.Items.Add(new ComboBoxItem { Content = L("All diagrams", "全部图形"), Tag = "all" });
        foreach (var category in ExampleCatalog.Kinds.Select(kind => kind.Category).Distinct()) categories.Items.Add(new ComboBoxItem { Content = CategoryName(category), Tag = category }); categories.SelectedIndex = 0;
        categories.SelectionChanged += (_, _) => { if (!rebuilding) DispatcherQueue.TryEnqueue(PopulateKinds); }; library.Children.Add(categories);
        kinds = new ComboBox { HorizontalAlignment = HorizontalAlignment.Stretch, Header = L("Diagram", "图形") }; kinds.SelectionChanged += (_, _) => { if (!rebuilding) DispatcherQueue.TryEnqueue(PopulateExamples); }; Grid.SetRow(kinds, 1); library.Children.Add(kinds);
        var filter = new AutoSuggestBox { PlaceholderText = L("Search examples", "搜索示例") }; filter.TextChanged += (_, args) => { if (args.Reason != AutoSuggestionBoxTextChangeReason.UserInput) return; search = filter.Text; DispatcherQueue.TryEnqueue(PopulateExamples); }; Grid.SetRow(filter, 2); library.Children.Add(filter);
        examples = new ListView { SelectionMode = ListViewSelectionMode.Single, IsItemClickEnabled = true };
        examples.ItemClick += (_, e) => { if (e.ClickedItem is ListViewItem { Tag: DiagramExample example }) { preview.Fit(); settings = settings with { SourcePath = null }; editor.Text = example.Source(Language); UpdateTitle(); } };
        Grid.SetRow(examples, 3); library.Children.Add(examples); workspace.Children.Add(library);
        var sourcePanel = new Grid { Padding = new(12, 16, 12, 12), RowSpacing = 12 };
        sourcePanel.RowDefinitions.Add(new() { Height = GridLength.Auto }); sourcePanel.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) });
        sourcePanel.Children.Add(new TextBlock { Text = L("Source", "源码"), FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        editor = new TextBox { Text = settings.Source, AcceptsReturn = true, TextWrapping = TextWrapping.NoWrap, FontFamily = new("Cascadia Mono, Consolas"), FontSize = 14, HorizontalAlignment = HorizontalAlignment.Stretch, VerticalAlignment = VerticalAlignment.Stretch, Padding = new(12), MaxLength = 50_001 };
        ScrollViewer.SetHorizontalScrollBarVisibility(editor, ScrollBarVisibility.Auto); ScrollViewer.SetVerticalScrollBarVisibility(editor, ScrollBarVisibility.Auto); AutomationProperties.SetName(editor, L("Diagram source", "图形源码"));
        editor.TextChanged += (_, _) => { if (!rebuilding) _ = RunAsync(RenderAsync); }; Grid.SetRow(editor, 1); sourcePanel.Children.Add(editor); Grid.SetColumn(sourcePanel, 1); workspace.Children.Add(sourcePanel);
        var previewPanel = new Grid { RowSpacing = 8, Padding = new(12, 12, 16, 12) }; previewPanel.RowDefinitions.Add(new() { Height = GridLength.Auto }); previewPanel.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) });
        preview.Palette = Palette; preview.ShowGrid = settings.Grid; Grid.SetRow(preview.Element, 1); previewPanel.Children.Add(preview.Element);
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        controls.Children.Add(ActionButton(L("Fit", "适应窗口"), () => preview.Fit())); controls.Children.Add(ActionButton("−", () => preview.Zoom(1 / 1.2))); controls.Children.Add(ActionButton("+", () => preview.Zoom(1.2)));
        var grid = new ToggleSwitch { Header = L("Grid", "网格"), IsOn = settings.Grid, OnContent = "", OffContent = "", VerticalAlignment = VerticalAlignment.Center }; grid.Toggled += (_, _) => { preview.ShowGrid = grid.IsOn; settings = settings with { Grid = grid.IsOn }; _ = RunAsync(SaveWorkspaceAsync); }; controls.Children.Add(grid); previewPanel.Children.Add(controls); Grid.SetColumn(previewPanel, 2); workspace.Children.Add(previewPanel);
        var footer = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, Padding = new(16, 8, 16, 8) }; status = new() { VerticalAlignment = VerticalAlignment.Center }; footer.Children.Add(status);
        diagnostic = new() { Visibility = Visibility.Collapsed }; diagnostic.Click += (_, _) => LocateDiagnostic(); footer.Children.Add(diagnostic); Grid.SetRow(footer, 2); root.Children.Add(footer);
        errors = new InfoBar { Severity = InfoBarSeverity.Error, IsClosable = true, Margin = new(16, 0, 16, 12) }; Grid.SetRow(errors, 3); root.Children.Add(errors);
        AutomationProperties.SetName(preview.Element, L("Diagram preview", "图形预览"));
        AutomationProperties.SetHelpText(preview.Element, L("Drag to pan. Scroll to zoom. Press 0 to fit, plus or minus to zoom.", "拖动以平移，滚轮以缩放。按 0 适应窗口，按加减键缩放。"));
        RefreshAppearance(); Content = root; PopulateKinds(); rebuilding = false; Refresh(); UpdateTitle();
    }
    private string CategoryName(string category) => category switch { "process" => L("Process", "流程"), "relationships" => L("Relationships", "关系"), "charts" => L("Charts", "数据图表"), "planning" => L("Planning", "规划"), "development" => L("Development", "开发"), "hierarchy" => L("Hierarchy", "层级"), "architecture" => L("Architecture", "架构"), _ => category };
    private void PopulateKinds()
    {
        var selected = (kinds.SelectedItem as ComboBoxItem)?.Tag as string ?? DiagramKinds.Detect(settings.Source)?.Id() ?? "flowchart"; var category = (categories.SelectedItem as ComboBoxItem)?.Tag as string;
        kinds.Items.Clear(); kinds.Items.Add(new ComboBoxItem { Content = L("All types", "全部类型"), Tag = "all" });
        foreach (var kind in ExampleCatalog.Kinds.Where(kind => category == "all" || kind.Category == category)) kinds.Items.Add(new ComboBoxItem { Content = kind.Titles.For(Language), Tag = kind.Id });
        kinds.SelectedItem = kinds.Items.Cast<ComboBoxItem>().FirstOrDefault(item => (string)item.Tag == selected) ?? kinds.Items[0]; PopulateExamples();
    }
    private void PopulateExamples()
    {
        var kind = (kinds.SelectedItem as ComboBoxItem)?.Tag as string; var category = (categories.SelectedItem as ComboBoxItem)?.Tag as string; var ids = ExampleCatalog.Kinds.Where(info => category == "all" || info.Category == category).Select(info => info.Id).ToHashSet(); examples.Items.Clear();
        foreach (var example in ExampleCatalog.All.Where(example => ids.Contains(example.Kind) && (kind == "all" || kind == example.Kind) && (search.Length == 0 || example.Title(Language).Contains(search, StringComparison.CurrentCultureIgnoreCase) || example.Id.Contains(search, StringComparison.OrdinalIgnoreCase)))) examples.Items.Add(new ListViewItem { Content = new TextBlock { Text = example.Title(Language), TextWrapping = TextWrapping.Wrap }, Tag = example });
    }
    private AppBarButton Command(string label, Symbol icon, Func<Task> action, VirtualKey? key = null, bool shift = false)
    {
        var button = new AppBarButton { Label = label, Icon = new SymbolIcon(icon) }; button.Click += (_, _) => _ = RunAsync(action);
        if (key is { } value) { var accelerator = new KeyboardAccelerator { Key = value, Modifiers = VirtualKeyModifiers.Control | (shift ? VirtualKeyModifiers.Shift : VirtualKeyModifiers.None) }; accelerator.Invoked += (sender, e) => { e.Handled = true; if (button.IsEnabled) _ = RunAsync(action); }; button.KeyboardAccelerators.Add(accelerator); } return button;
    }
    private static Button ActionButton(string label, Action action) { var button = new Button { Content = label, MinWidth = 36 }; button.Click += (_, _) => action(); return button; }
    private async Task RenderAsync()
    {
        settings = settings with { Source = editor.Text }; var source = settings.Source;
        SmokeStep("request-render");
        var render = session.UpdateAsync(source, new(MaxWidth: Math.Max(320, preview.ActualWidth > 0 ? preview.ActualWidth : 720)));
        await SaveWorkspaceAsync(); SmokeStep("workspace-saved"); await render; SmokeStep("render-complete");
    }
    private void Refresh()
    {
        preview.Scene = session.Artifact?.Scene; export.IsEnabled = copy.IsEnabled = session.CanExport;
        status.Text = session.Busy ? L("Rendering…", "正在渲染……") : session.Diagnostic is not null ? L("Source needs attention", "请检查源码") : session.Artifact is { } artifact ? $"{artifact.Type}   {artifact.Width:0} × {artifact.Height:0}" : L("Ready", "就绪");
        diagnostic.Visibility = session.Diagnostic is null ? Visibility.Collapsed : Visibility.Visible;
        if (session.Diagnostic is { } error) diagnostic.Content = $"{error.Code} · {error.Line}:{error.Column} · {error.Message}";
    }
    private void LocateDiagnostic()
    {
        if (session.Diagnostic?.Line is not { } line) return;
        var selection = SourceSelection.Locate(editor.Text, line, session.Diagnostic.Column);
        editor.Focus(FocusState.Programmatic); editor.Select(selection.Start, selection.Length);
    }
    private Task SaveWorkspaceAsync() => store.SaveAsync(settings with { Source = editor.Text });
    private void UpdateTitle() => Title = (settings.SourcePath is null ? L("Untitled", "未命名") : Path.GetFileName(settings.SourcePath)) + " — Norna Studio";
    private async Task OpenAsync()
    {
        var picker = new FileOpenPicker(AppWindow.Id); foreach (var extension in new[] { ".mmd", ".mermaid", ".txt" }) picker.FileTypeFilter.Add(extension); var result = await picker.PickSingleFileAsync(); if (result is null) return;
        var info = new FileInfo(result.Path); if (info.Length > 200_000) throw new DiagramRenderException(L("The source file is too large.", "源码文件过大。"), "limit");
        var source = await File.ReadAllTextAsync(result.Path, new UTF8Encoding(false, true)); if (source.Length > 50_000) throw new DiagramRenderException(L("Source exceeds 50000 characters.", "源码超过 50000 个字符。"), "limit"); settings = settings with { SourcePath = result.Path }; editor.Text = source; UpdateTitle(); await SaveWorkspaceAsync();
    }
    private async Task SaveAsync(bool saveAs)
    {
        var path = settings.SourcePath;
        if (saveAs || path is null) { var picker = new FileSavePicker(AppWindow.Id) { SuggestedFileName = path is null ? "diagram" : Path.GetFileNameWithoutExtension(path) }; picker.FileTypeChoices.Add("Mermaid", [".mmd"]); var result = await picker.PickSaveFileAsync(); if (result is null) return; path = result.Path; }
        await File.WriteAllTextAsync(path, editor.Text, new UTF8Encoding(false)); settings = settings with { SourcePath = path }; UpdateTitle(); await SaveWorkspaceAsync();
    }
    private Task CopyAsync()
    {
        var snapshot = session.Snapshot(Palette); var data = new DataPackage(); data.SetText(SvgExporter.Export(snapshot.Scene, snapshot.Palette)); Clipboard.SetContent(data); Clipboard.Flush(); return Task.CompletedTask;
    }
    private async Task ExportAsync()
    {
        var snapshot = session.Snapshot(Palette); var format = new ComboBox { Header = L("Format", "格式"), ItemsSource = Enum.GetValues<DiagramExportFormat>().Select(value => new ComboBoxItem { Content = value.ToString().ToUpperInvariant(), Tag = value }), SelectedIndex = 0, HorizontalAlignment = HorizontalAlignment.Stretch };
        var scale = new NumberBox { Header = L("Bitmap scale", "位图倍率"), Value = 2, Minimum = .25, Maximum = 8, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        var padding = new NumberBox { Header = L("Padding", "留白"), Value = 16, Minimum = 0, Maximum = 512, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline };
        var transparent = new CheckBox { Content = L("Transparent background", "透明背景") }; var quality = new Slider { Header = L("JPEG quality", "JPEG 质量"), Minimum = .1, Maximum = 1, Value = .92, StepFrequency = .01 };
        var panel = new StackPanel { Spacing = 16, MinWidth = 320 }; foreach (var control in new FrameworkElement[] { format, scale, padding, transparent, quality }) panel.Children.Add(control);
        var selectedFormat = () => (DiagramExportFormat)((ComboBoxItem)format.SelectedItem).Tag;
        var updateOptions = () => { var selected = selectedFormat(); scale.IsEnabled = selected is not (DiagramExportFormat.Svg or DiagramExportFormat.Pdf); transparent.IsEnabled = selected != DiagramExportFormat.Jpeg; if (!transparent.IsEnabled) transparent.IsChecked = false; quality.IsEnabled = selected == DiagramExportFormat.Jpeg; };
        format.SelectionChanged += (_, _) => updateOptions(); updateOptions();
        var dialog = new ContentDialog { XamlRoot = root.XamlRoot, Title = L("Export diagram", "导出图形"), Content = panel, PrimaryButtonText = L("Save", "保存"), CloseButtonText = L("Cancel", "取消"), DefaultButton = ContentDialogButton.Primary };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        var options = new DiagramExportOptions(selectedFormat(), transparent.IsChecked == true ? DiagramExportBackground.Transparent : DiagramExportBackground.Theme, scale.Value, quality.Value, padding.Value); options.OutputSize(snapshot.Scene);
        var picker = new FileSavePicker(AppWindow.Id) { SuggestedFileName = "diagram" }; picker.FileTypeChoices.Add(options.Format.ToString(), ["." + options.Format.ToString().ToLowerInvariant()]); var file = await picker.PickSaveFileAsync(); if (file is null) return;
        var bytes = await new DiagramExporter(Microsoft.Graphics.Canvas.CanvasDevice.GetSharedDevice()).ExportAsync(snapshot.Scene, snapshot.Palette, options); await File.WriteAllBytesAsync(file.Path, bytes);
    }
    private string AppearanceName(CanvasAppearance value) => value switch
    {
        CanvasAppearance.System => L("Use system setting", "跟随系统"), CanvasAppearance.Light => L("Light", "浅色"), CanvasAppearance.Dark => L("Dark", "深色"),
        CanvasAppearance.HighContrastLight => L("High contrast light", "高对比度浅色"), CanvasAppearance.HighContrastDark => L("High contrast dark", "高对比度深色"),
        _ => throw new ArgumentOutOfRangeException(nameof(value))
    };
    private string ColorStyleName(DiagramColorStyle value) => value switch
    {
        DiagramColorStyle.Neutral => L("Neutral", "中性"), DiagramColorStyle.Themed => L("System accent", "系统强调色"), DiagramColorStyle.Custom => L("Custom accent", "自定义强调色"),
        _ => throw new ArgumentOutOfRangeException(nameof(value))
    };
    private async Task SettingsAsync()
    {
        var language = new ComboBox { Header = L("Language", "语言"), ItemsSource = new[] { "English", "简体中文" }, SelectedIndex = settings.Language == "zh" ? 1 : 0, HorizontalAlignment = HorizontalAlignment.Stretch };
        var appearance = new ComboBox { Header = L("Appearance", "外观"), ItemsSource = Enum.GetValues<CanvasAppearance>().Select(value => new ComboBoxItem { Content = AppearanceName(value), Tag = value }), SelectedIndex = Array.IndexOf(Enum.GetValues<CanvasAppearance>(), settings.Appearance), HorizontalAlignment = HorizontalAlignment.Stretch };
        var colors = new ComboBox { Header = L("Colors", "配色"), ItemsSource = Enum.GetValues<DiagramColorStyle>().Select(value => new ComboBoxItem { Content = ColorStyleName(value), Tag = value }), SelectedIndex = Array.IndexOf(Enum.GetValues<DiagramColorStyle>(), settings.ColorStyle), HorizontalAlignment = HorizontalAlignment.Stretch };
        var value = Palette.Accent;
        var accent = new ColorPicker { Color = Color.FromArgb(255, value.R, value.G, value.B), IsAlphaEnabled = false, IsColorSliderVisible = true, IsHexInputVisible = true };
        var panel = new StackPanel { Spacing = 16 }; foreach (var control in new FrameworkElement[] { language, appearance, colors, new TextBlock { Text = L("Accent", "强调色") }, accent }) panel.Children.Add(control);
        var dialog = new ContentDialog { XamlRoot = root.XamlRoot, Title = L("Settings", "设置"), Content = new ScrollViewer { Content = panel, MaxHeight = 600 }, PrimaryButtonText = L("Apply", "应用"), CloseButtonText = L("Cancel", "取消") };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        settings = settings with { Source = editor.Text, Language = language.SelectedIndex == 1 ? "zh" : "en", Appearance = (CanvasAppearance)((ComboBoxItem)appearance.SelectedItem).Tag, ColorStyle = (DiagramColorStyle)((ComboBoxItem)colors.SelectedItem).Tag, Accent = new DiagramColor(accent.Color.R, accent.Color.G, accent.Color.B).Hex };
        await SaveWorkspaceAsync(); Build(); await RenderAsync();
    }
    private async Task RunAsync(Func<Task> action)
    {
        // Expected UI, file and render failures are shown here; the Kit never discards them.
        try { await action(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or DiagramRenderException or DecoderFallbackException or System.Runtime.InteropServices.COMException)
        {
            errors.Title = L("Unable to complete the action", "无法完成操作"); errors.Message = error.Message; errors.IsOpen = true;
            if (Environment.GetEnvironmentVariable("NORNA_STUDIO_SMOKE") is { Length: > 0 } directory)
            { Directory.CreateDirectory(directory); await File.WriteAllTextAsync(Path.Combine(directory, "action-failure.txt"), error.ToString()); }
        }
    }
}
