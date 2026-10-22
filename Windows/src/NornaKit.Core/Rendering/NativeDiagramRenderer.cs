using System.Collections.Immutable;

namespace NornaKit;

/// <summary>Runs local parsing and geometry using the host's immutable text layout service.</summary>
public sealed class NativeDiagramRenderer(ITextLayoutProvider textLayoutProvider) : IDiagramRenderer
{
    public Task<DiagramArtifact> RenderAsync(string source, DiagramLayoutOptions? options = null, CancellationToken cancellationToken = default)
        => Task.Run(() => Render(source, options ?? new(), cancellationToken), cancellationToken);

    private DiagramArtifact Render(string source, DiagramLayoutOptions options, CancellationToken cancellationToken)
    {
        options.Validate();
        if (source.Length > 50_000) throw new DiagramRenderException("源码超过 50000 个字符。", "limit");
        if (source.Any(character => character < 32 && character is not ('\t' or '\n' or '\r'))) throw new DiagramRenderException("源码包含无法导出的控制字符。", "syntax");
        cancellationToken.ThrowIfCancellationRequested();
        var document = MermaidDocument.Prepare(source); var body = document.Body;
        var kind = DiagramKinds.Detect(body) ?? throw new DiagramRenderException("无法识别图表声明，请从示例中选择一种图形。", "unsupported-diagram", DiagramSyntax.Lines(body).FirstOrDefault()?.Number);
        var text = new TextMeasurement(textLayoutProvider, cancellationToken);
        var scene = kind switch
        {
            DiagramKind.Flowchart => Flow(body, options, text),
            DiagramKind.Sequence => new SequenceDiagram(text).Layout(SequenceDiagram.Parse(body), options),
            DiagramKind.Pie => new DataCharts(text).Pie(body, options),
            DiagramKind.XYChart => new DataCharts(text).XY(body, options),
            DiagramKind.QuadrantChart => new DataCharts(text).Quadrant(body),
            DiagramKind.Radar => new DataCharts(text).Radar(body, options),
            DiagramKind.Mindmap => new HierarchyDiagrams(text).Mindmap(body),
            DiagramKind.TreeView => new HierarchyDiagrams(text).Tree(body),
            DiagramKind.Treemap => new HierarchyDiagrams(text).Treemap(body, options),
            DiagramKind.Ishikawa => new HierarchyDiagrams(text).Ishikawa(body),
            DiagramKind.Kanban => new HierarchyDiagrams(text).Kanban(body, options),
            DiagramKind.Timeline => new TemporalDiagrams(text).Timeline(body, options),
            DiagramKind.Journey => new TemporalDiagrams(text).Journey(body, options),
            DiagramKind.Gantt => new TemporalDiagrams(text).Gantt(body, options),
            DiagramKind.GitGraph => new GitDiagram(text).Render(body),
            DiagramKind.Packet => new PacketEventDiagrams(text).Packet(body),
            DiagramKind.EventModeling => new PacketEventDiagrams(text).Events(body),
            DiagramKind.ClassDiagram => RelationshipDiagrams.Class(body).Scene(text, options),
            DiagramKind.State => RelationshipDiagrams.State(body).Scene(text, options),
            DiagramKind.ER => RelationshipDiagrams.ER(body).Scene(text, options),
            DiagramKind.Requirement => new ArchitectureDiagrams(text).Requirement(body, options),
            DiagramKind.C4 => new ArchitectureDiagrams(text).C4(body, options),
            DiagramKind.Usecase => new ArchitectureDiagrams(text).Usecase(body, options),
            DiagramKind.Architecture => new ArchitectureDiagrams(text).Architecture(body, options),
            DiagramKind.Agentflow => new BlockLaneDiagrams(text).Agent(body, options),
            DiagramKind.Block => new BlockLaneDiagrams(text).Block(body),
            DiagramKind.Swimlane => new BlockLaneDiagrams(text).Swimlane(body, options),
            DiagramKind.Sankey => new SpatialDataDiagrams(text).Sankey(body),
            DiagramKind.Venn => new SpatialDataDiagrams(text).Venn(body),
            DiagramKind.Cynefin => new SpatialDataDiagrams(text).Cynefin(body),
            DiagramKind.Wardley => new SpatialDataDiagrams(text).Wardley(body),
            DiagramKind.Railroad => new RailroadDiagram(text).Render(body),
            DiagramKind.Info => Info(body, text),
            _ => throw new ArgumentOutOfRangeException(nameof(kind))
        };
        if (DiagramSyntax.Title(DiagramSyntax.Lines(body)).Length == 0 && document.Title is { Length: > 0 } title)
        {
            var heading = new SceneBuilder(kind, text); var headingHeight = heading.Title(title, Math.Max(240, scene.Size.Width));
            scene = scene with { Size = new(Math.Max(240, scene.Size.Width), scene.Size.Height + headingHeight),
                Primitives = heading.Primitives.Concat(scene.Primitives.Select(primitive => primitive with { Geometry = SceneGeometry.Offset(primitive.Geometry, 0, headingHeight) })).ToImmutableArray(),
                Nodes = scene.Nodes.Select(node => node with { Frame = node.Frame.Offset(0, headingHeight) }).ToImmutableArray(),
                Groups = scene.Groups.Select(group => group with { Frame = group.Frame.Offset(0, headingHeight), TitleFrame = group.TitleFrame.Offset(0, headingHeight) }).ToImmutableArray(),
                Edges = scene.Edges.Select(edge => edge with { Points = edge.Points.Select(point => point.Offset(0, headingHeight)).ToImmutableArray(), LabelFrame = edge.LabelFrame.Offset(0, headingHeight) }).ToImmutableArray() };
        }
        cancellationToken.ThrowIfCancellationRequested();
        if (!double.IsFinite(scene.Size.Width) || !double.IsFinite(scene.Size.Height) || scene.Size.Width is <= 0 or > 250_000 || scene.Size.Height is <= 0 or > 250_000 || scene.Primitives.Length > 20_000)
            throw new DiagramRenderException("图表几何数据超过安全绘制范围，请减少数据项。", "limit");
        if (scene.Primitives.Any(primitive => SceneGeometry.Bounds(primitive.Geometry) is { IsFinite: false })) throw new DiagramRenderException("布局生成了无效几何数据。", "layout");
        return new(scene);
    }
    private static DiagramScene Flow(string body, DiagramLayoutOptions options, TextMeasurement text)
    {
        var graph = MermaidFlowchartParser.Parse(body); var engine = new LayeredLayoutEngine(text); var scene = engine.Layout(graph, options);
        if (options.MaxWidth is { } width && options.AutoDirection && options.Compact && graph.Direction.Horizontal() && scene.Size.Width > width)
        { var candidate = engine.Layout(graph with { Direction = FlowDirection.TopDown }, options); if (candidate.Size.Width < scene.Size.Width) scene = candidate; }
        return FlowScenePainter.Prepare(scene, text);
    }
    private static DiagramScene Info(string body, TextMeasurement text)
    {
        foreach (var line in DiagramSyntax.Lines(body).Skip(1)) if (line.Text != "showInfo") throw line.Error("info 当前只接受 showInfo。");
        var builder = new SceneBuilder(DiagramKind.Info, text);
        builder.Box("NornaKit\nC# · Win2D · DirectWrite", new(16, 16, 420, 140), C.SurfaceAlt);
        return builder.Build(452, 172);
    }
}
