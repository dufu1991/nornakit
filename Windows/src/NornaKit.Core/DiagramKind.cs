namespace NornaKit;

public enum DiagramKind
{
    Flowchart, Sequence, ClassDiagram, State, ER, Pie, Gantt, GitGraph, Mindmap, Timeline, Journey,
    XYChart, QuadrantChart, Requirement, C4, Sankey, Block, Packet, Kanban, Architecture, Radar,
    Treemap, Info, Agentflow, Usecase, Railroad, TreeView, Venn, Cynefin, Wardley, Swimlane, Ishikawa, EventModeling
}

public static class DiagramKinds
{
    private static readonly string[] Names = ["flowchart", "sequence", "class", "state", "er", "pie", "gantt", "gitGraph", "mindmap", "timeline", "journey",
        "xychart", "quadrantChart", "requirement", "c4", "sankey", "block", "packet", "kanban", "architecture", "radar", "treemap", "info",
        "agentflow", "usecase", "railroad", "treeView", "venn", "cynefin", "wardley", "swimlane", "ishikawa", "eventmodeling"];
    private static readonly IReadOnlyDictionary<string, DiagramKind> Headers = new Dictionary<string, DiagramKind>(StringComparer.Ordinal)
    {
        ["flowchart"] = DiagramKind.Flowchart, ["graph"] = DiagramKind.Flowchart, ["flowchart-elk"] = DiagramKind.Flowchart,
        ["sequenceDiagram"] = DiagramKind.Sequence, ["classDiagram"] = DiagramKind.ClassDiagram,
        ["stateDiagram"] = DiagramKind.State, ["stateDiagram-v2"] = DiagramKind.State, ["erDiagram"] = DiagramKind.ER,
        ["pie"] = DiagramKind.Pie, ["gantt"] = DiagramKind.Gantt, ["gitGraph"] = DiagramKind.GitGraph,
        ["mindmap"] = DiagramKind.Mindmap, ["timeline"] = DiagramKind.Timeline, ["journey"] = DiagramKind.Journey,
        ["xychart"] = DiagramKind.XYChart, ["xychart-beta"] = DiagramKind.XYChart, ["quadrantChart"] = DiagramKind.QuadrantChart,
        ["requirementDiagram"] = DiagramKind.Requirement, ["requirement"] = DiagramKind.Requirement,
        ["sankey"] = DiagramKind.Sankey, ["sankey-beta"] = DiagramKind.Sankey, ["block"] = DiagramKind.Block,
        ["block-beta"] = DiagramKind.Block, ["packet"] = DiagramKind.Packet, ["packet-beta"] = DiagramKind.Packet,
        ["kanban"] = DiagramKind.Kanban, ["architecture"] = DiagramKind.Architecture, ["architecture-beta"] = DiagramKind.Architecture,
        ["radar-beta"] = DiagramKind.Radar, ["treemap"] = DiagramKind.Treemap, ["treemap-beta"] = DiagramKind.Treemap,
        ["info"] = DiagramKind.Info, ["agentflow-beta"] = DiagramKind.Agentflow, ["usecase-beta"] = DiagramKind.Usecase,
        ["railroad-beta"] = DiagramKind.Railroad, ["railroad-ebnf-beta"] = DiagramKind.Railroad,
        ["railroad-abnf-beta"] = DiagramKind.Railroad, ["railroad-peg-beta"] = DiagramKind.Railroad,
        ["treeView-beta"] = DiagramKind.TreeView, ["venn-beta"] = DiagramKind.Venn, ["cynefin-beta"] = DiagramKind.Cynefin,
        ["wardley-beta"] = DiagramKind.Wardley, ["swimlane-beta"] = DiagramKind.Swimlane,
        ["ishikawa"] = DiagramKind.Ishikawa, ["ishikawa-beta"] = DiagramKind.Ishikawa, ["eventmodeling"] = DiagramKind.EventModeling,
        ["C4Context"] = DiagramKind.C4, ["C4Container"] = DiagramKind.C4, ["C4Component"] = DiagramKind.C4,
        ["C4Dynamic"] = DiagramKind.C4, ["C4Deployment"] = DiagramKind.C4
    };
    public static string Id(this DiagramKind kind) => Names[(int)kind];
    public static string MermaidType(this DiagramKind kind) => kind switch
    {
        DiagramKind.Flowchart => "flowchart-v2", DiagramKind.ClassDiagram => "classDiagram",
        DiagramKind.State => "stateDiagram", _ => kind.Id()
    };
    public static DiagramKind? Detect(string source)
    {
        var lines = DiagramSyntax.Lines(source);
        if (lines.Count > 0 && lines[0].Text == "---")
        {
            var end = lines.FindIndex(1, line => line.Text == "---");
            if (end >= 0) lines = lines[(end + 1)..];
        }
        if (lines.Count == 0) return null;
        var token = lines[0].Text.Split([' ', '\t', ':'], StringSplitOptions.RemoveEmptyEntries)[0];
        return Headers.TryGetValue(token, out var kind) ? kind : null;
    }
}
