namespace NornaKit;

internal static class RelationshipDiagrams
{
    public static RelationshipModel Class(string source)
    {
        var graph = new RelationshipModel(DiagramKind.ClassDiagram); const string identifier = @"(`[^`]+`|[\p{L}\p{N}_~.,]+)"; Func<string, string> clean = value => value.StartsWith('`') ? value[1..^1] : value;
        string? current = null; var namespaces = new Stack<string>();
        Action<string, string> member = (id, value) => { var entity = graph.Entities.First(entity => entity.Id == id); if (DiagramSyntax.Match(@"^<<([^<>]+)>>$", value) is { } annotation) entity.Stereotype = $"«{annotation[1]}»"; else entity.Members.Add(DiagramSyntax.Label(value)); };
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (current is { } id) { if (s == "}") current = null; else member(id, s); continue; }
            if (s.StartsWith("title ", StringComparison.Ordinal)) { graph.Title = DiagramSyntax.Label(s[6..]); continue; }
            if (DiagramSyntax.Match(@"^direction\s+(LR|RL|TD|TB|BT)$", s) is { } direction) { graph.Direction = FlowDirections.Parse(direction[1])!.Value; continue; }
            if (s == "}") { if (!namespaces.TryPop(out _)) throw line.Error("多余的命名空间结束符。", "syntax"); continue; }
            if (DiagramSyntax.Match("^namespace\\s+([\\w.]+)(?:\\[\"([^\"\\n]+)\"\\])?\\s*\\{$", s) is { } ns)
            { if (graph.Groups.Any(group => group.Id == ns[1]) || namespaces.Count >= 16) throw line.Error("命名空间重复或嵌套超过 16 层。", "semantic"); graph.Groups.Add(new(ns[1], ns[2].Length == 0 ? ns[1] : ns[2], namespaces.FirstOrDefault(), Sequence: graph.Groups.Count)); namespaces.Push(ns[1]); continue; }
            if (DiagramSyntax.Match("^note\\s+(?:for\\s+" + identifier + "\\s+)?\"([\\s\\S]*)\"$", s) is { } note)
            { var target = note[1].Length == 0 ? null : clean(note[1]); if (target is not null) graph.Register(target, parent: namespaces.FirstOrDefault()); graph.Notes.Add(new(target, DiagramSyntax.Label(note[2]))); continue; }
            if (DiagramSyntax.Match(@"^<<([^<>]+)>>\s+" + identifier + "$", s) is { } stereotype)
            { var target = clean(stereotype[2]); graph.Register(target, parent: namespaces.FirstOrDefault()); member(target, $"<<{stereotype[1]}>>"); continue; }
            if (DiagramSyntax.Match("^class\\s+" + identifier + "(?:\\[\"([^\"]+)\"\\])?\\s*(?:<<([^<>]+)>>)?\\s*(\\{)?\\s*(.*?)\\s*(\\})?$", s) is { } declaration)
            {
                if (declaration[4].Length == 0 && (declaration[5].Length > 0 || declaration[6].Length > 0)) throw line.Error("类声明包含未识别的内容。", "syntax");
                var target = clean(declaration[1]); graph.Register(target, declaration[2].Length == 0 ? null : declaration[2], namespaces.FirstOrDefault()); if (declaration[3].Length > 0) member(target, $"<<{declaration[3]}>>");
                if (declaration[4].Length > 0) { if (declaration[6].Length == 0) current = target; foreach (var value in declaration[5].Split(';').Select(value => value.Trim()).Where(value => value.Length > 0)) member(target, value); }
            }
            else if (DiagramSyntax.Match("^" + identifier + "\\s*(?:\"([^\"]*)\")?\\s*(<\\||\\*|o|<|\\(\\))?(--|\\.\\.)(\\|>|\\*|o|>|\\(\\))?\\s*(?:\"([^\"]*)\"\\s*)?" + identifier + "(?:\\s*:\\s*(.*))?$", s) is { } relation)
            {
                var from = clean(relation[1]); var to = clean(relation[7]); graph.Register(from, parent: namespaces.FirstOrDefault()); graph.Register(to, parent: namespaces.FirstOrDefault());
                Func<string, string> marker = value => value switch { "<|" or "|>" => "triangle", "*" => "filledDiamond", "o" => "diamond", "<" or ">" => "arrow", "()" => "interface", _ => "" };
                graph.Relations.Add(new(from, to, DiagramSyntax.Label(relation[8]), marker(relation[3]), marker(relation[5]), relation[4] == "..", relation[2], relation[6]));
            }
            else if (DiagramSyntax.Match("^" + identifier + @"\s*:\s*(.+)$", s) is { } attribute) { var target = clean(attribute[1]); graph.Register(target, parent: namespaces.FirstOrDefault()); member(target, attribute[2]); }
            else throw line.Error($"暂不支持这条类图语法：{s}");
        }
        if (current is not null || namespaces.Count > 0) throw new DiagramRenderException("类或命名空间缺少结束花括号。", "syntax"); return graph;
    }
    private sealed record Scope(string Id, int? Region = null);
    public static RelationshipModel State(string source)
    {
        var graph = new RelationshipModel(DiagramKind.State); var stack = new List<Scope>(); var lines = DiagramSyntax.Lines(source); Func<string, int, string> regionId = (id, region) => $"@region_{id}_{region}";
        for (var cursor = 1; cursor < lines.Count; cursor++)
        {
            var line = lines[cursor]; var s = line.Text; var scope = stack.LastOrDefault(); var parent = scope is null ? null : scope.Region is { } region ? regionId(scope.Id, region) : scope.Id;
            if (s.StartsWith("title ", StringComparison.Ordinal)) { graph.Title = DiagramSyntax.Label(s[6..]); continue; }
            if (DiagramSyntax.Match(@"^direction\s+(TD|TB|BT|LR|RL)$", s) is { } direction)
            { var value = FlowDirections.Parse(direction[1])!.Value; if (parent is null) graph.Direction = value; else { var index = graph.Groups.FindIndex(group => group.Id == parent); graph.Groups[index] = graph.Groups[index] with { Direction = value }; } continue; }
            if (s == "}") { if (stack.Count == 0) throw line.Error("多余的状态结束符。", "syntax"); stack.RemoveAt(stack.Count - 1); continue; }
            if (s == "--")
            {
                if (scope is null) throw line.Error("并发分隔符必须位于复合状态中。", "syntax"); var groupIndex = graph.Groups.FindIndex(group => group.Id == scope.Id);
                if (scope.Region is null)
                {
                    var id = regionId(scope.Id, 0); var original = graph.Direction; string? ancestor = scope.Id;
                    while (ancestor is not null) { var group = graph.Groups.First(group => group.Id == ancestor); if (group.Direction is { } local) { original = local; break; } ancestor = group.ParentId; }
                    graph.Groups[groupIndex] = graph.Groups[groupIndex] with { Direction = original.Horizontal() ? FlowDirection.TopDown : FlowDirection.LeftRight };
                    foreach (var entity in graph.Entities.Where(entity => entity.Parent == scope.Id)) entity.Parent = id;
                    for (var i = 0; i < graph.Groups.Count; i++) if (graph.Groups[i].ParentId == scope.Id) graph.Groups[i] = graph.Groups[i] with { ParentId = id };
                    graph.Groups.Add(new(id, "", scope.Id, original, graph.Groups.Count)); graph.RegionGroups.Add(id);
                }
                var number = (scope.Region ?? 0) + 1; var newId = regionId(scope.Id, number); var inherited = graph.Groups.First(group => group.Id == regionId(scope.Id, 0)).Direction;
                graph.Groups.Add(new(newId, "", scope.Id, inherited, graph.Groups.Count)); graph.RegionGroups.Add(newId); stack[^1] = scope with { Region = number }; if (number >= 16) throw line.Error("一个复合状态最多支持 16 个并发区域。", "limit"); continue;
            }
            if (DiagramSyntax.Match("^state\\s+(?:\"([^\"\\n]+)\"\\s+as\\s+)?(\\w+)\\s*\\{$", s) is { } composite)
            { if (graph.Groups.Any(group => group.Id == composite[2]) || stack.Count >= 16) throw line.Error("复合状态重复或嵌套超过 16 层。", "semantic"); graph.Groups.Add(new(composite[2], composite[1].Length == 0 ? composite[2] : composite[1], parent, Sequence: graph.Groups.Count)); stack.Add(new(composite[2])); continue; }
            if (DiagramSyntax.Match(@"^(?i:note)\s+(left|right)\s+of\s+(\w+)(?:\s*:\s*(.*))?$", s) is { } note)
            {
                var value = note[3]; if (!s.Contains(':')) { var body = new List<string>(); cursor++; while (cursor < lines.Count && !lines[cursor].Text.Equals("end note", StringComparison.OrdinalIgnoreCase)) body.Add(lines[cursor++].Text); if (cursor >= lines.Count) throw line.Error("状态注释缺少 end note。", "syntax"); value = string.Join('\n', body); }
                if (graph.Groups.All(group => group.Id != note[2])) graph.Register(note[2], parent: parent); graph.Notes.Add(new(note[2], DiagramSyntax.Label(value), note[1])); continue;
            }
            if (DiagramSyntax.Match("^state\\s+\"([^\"]+)\"\\s+as\\s+(\\w+)$", s) is { } alias) { graph.Register(alias[2], alias[1], parent); continue; }
            if (DiagramSyntax.Match(@"^state\s+(\w+)(?:\s+<<(choice|fork|join)>>)?$", s) is { } state)
            { var entity = graph.Register(state[1], parent: parent); if (state[2] == "choice") entity.Shape = NodeShape.Diamond; else if (state[2].Length > 0) { entity.Synchronization = true; entity.Stereotype = state[2]; } continue; }
            if (DiagramSyntax.Match(@"^(\[\*\]|\w+)\s*-->\s*(\[\*\]|\w+)(?:\s*:\s*(.*))?$", s) is { } transition)
            {
                var scopeId = scope is null ? "root" : $"{scope.Id}_{scope.Region ?? 0}"; var a = transition[1] == "[*]" ? $"@initial_{scopeId}" : transition[1]; var b = transition[2] == "[*]" ? $"@final_{scopeId}" : transition[2];
                foreach (var (id, marker) in new[] { (a, transition[1] == "[*]" ? 1 : 0), (b, transition[2] == "[*]" ? 2 : 0) }) if (graph.Groups.All(group => group.Id != id)) { var entity = graph.Register(id, parent: parent); if (marker > 0) { entity.Shape = NodeShape.Circle; entity.Title = ""; entity.StateMarker = marker; } }
                graph.Relations.Add(new(a, b, DiagramSyntax.Label(transition[3]))); continue;
            }
            if (DiagramSyntax.Match(@"^(\w+)\s*:\s*(.+)$", s) is { } description) { var entity = graph.Register(description[1], parent: parent); var value = DiagramSyntax.Label(description[2]); entity.Title = entity.Title == description[1] ? value : entity.Title + "\n" + value; continue; }
            if (DiagramSyntax.Match(@"^\w+$", s) is not null) { graph.Register(s, parent: parent); continue; }
            throw line.Error($"暂不支持这条状态图语法：{s}");
        }
        if (stack.Count > 0) throw new DiagramRenderException("复合状态缺少结束花括号。", "syntax"); return graph;
    }
    public static RelationshipModel ER(string source)
    {
        var graph = new RelationshipModel(DiagramKind.ER); string? current = null;
        Func<string, string> cardinality = value => (value.Contains('o') ? "optional" : "required") + (value.Contains('{') || value.Contains('}') ? "many" : "one");
        foreach (var line in DiagramSyntax.Lines(source).Skip(1))
        {
            var s = line.Text; if (current is { } id) { if (s == "}") current = null; else { if (DiagramSyntax.Match(@"^\S+\s+\S+", s) is null) throw line.Error("实体属性需要类型与名称。", "syntax"); graph.Entities.First(entity => entity.Id == id).Members.Add(s); } }
            else if (DiagramSyntax.Match(@"^(\w+)\s*([|o}{]{2})(--|\.\.)([|o}{]{2})\s*(\w+)\s*:\s*(.+)$", s) is { } relation)
            { if (!new[] { "||", "o|", "}|", "}o" }.Contains(relation[2]) || !new[] { "||", "|o", "|{", "o{" }.Contains(relation[4])) throw line.Error("实体关系基数标记无效。", "syntax"); graph.Register(relation[1]); graph.Register(relation[5]); graph.Relations.Add(new(relation[1], relation[5], DiagramSyntax.Label(relation[6]), cardinality(relation[2]), cardinality(relation[4]), relation[3] == "..")); }
            else if (DiagramSyntax.Match(@"^(\w+)(?:\[([^\]]+)\])?\s*\{$", s) is { } entity) { graph.Register(entity[1], entity[2].Length == 0 ? null : DiagramSyntax.Label(entity[2])); current = entity[1]; }
            else if (DiagramSyntax.Match(@"^direction\s+(LR|RL|TB|TD|BT)$", s) is { } direction) graph.Direction = FlowDirections.Parse(direction[1])!.Value;
            else throw line.Error($"暂不支持这条实体关系图语法：{s}");
        }
        if (current is not null) throw new DiagramRenderException("实体属性块缺少结束花括号。", "syntax"); return graph;
    }
}
