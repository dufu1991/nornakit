using System.Text.RegularExpressions;

namespace NornaKit;

internal sealed class GitDiagram(TextMeasurement text)
{
    private sealed record Commit(string Id, int Lane, int[] Parents, string Type, string Tag, string Message);
    public DiagramScene Render(string source)
    {
        var lines = DiagramSyntax.Lines(source); var b = new SceneBuilder(DiagramKind.GitGraph, text); var header = lines[0].Text.Replace(":", "", StringComparison.Ordinal).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (header.Skip(1).Any(token => token is not ("LR" or "TB" or "BT"))) throw lines[0].Error("Git 图方向当前支持 LR、TB 和 BT。"); var vertical = header.Contains("TB") || header.Contains("BT"); var reverse = header.Contains("BT");
        var branches = new List<string> { "main" }; var current = "main"; var heads = new Dictionary<string, int>(); var commits = new List<Commit>();
        foreach (var line in lines.Skip(1))
        {
            var s = line.Text; if (s.StartsWith("title ", StringComparison.Ordinal)) continue;
            if (DiagramSyntax.Match(@"^branch\s+([^\s]+)$", s) is { } branch) { if (branches.Contains(branch[1])) throw line.Error("分支名称重复。", "semantic"); branches.Add(branch[1]); if (heads.TryGetValue(current, out var head)) heads[branch[1]] = head; current = branch[1]; continue; }
            if (DiagramSyntax.Match(@"^(?:checkout|switch)\s+([^\s]+)$", s) is { } checkout) { if (!branches.Contains(checkout[1])) throw line.Error("目标分支不存在。", "semantic"); current = checkout[1]; continue; }
            var m = DiagramSyntax.Match(@"^(commit|merge|cherry-pick)\b\s*(.*)$", s) ?? throw line.Error("暂不支持这条 Git 图语法。"); var rest = m[2]; var parents = heads.TryGetValue(current, out var parent) ? new List<int> { parent } : [];
            if (m[1] == "merge") { var parts = rest.Split((char[]?)null, 2, StringSplitOptions.RemoveEmptyEntries); if (parts.Length == 0 || parts[0] == current || !heads.TryGetValue(parts[0], out var target)) throw line.Error("无法合并空分支或当前分支。", "semantic"); parents.Add(target); rest = parts.Length > 1 ? parts[1] : ""; }
            var idField = DiagramSyntax.Match("\\bid:\\s*\"([^\"]+)\"", rest)?[1];
            if (m[1] == "cherry-pick") { var index = commits.FindIndex(commit => commit.Id == idField); if (idField is null || index < 0) throw line.Error("cherry-pick 引用的提交不存在。", "semantic"); parents.Add(index); }
            var id = m[1] == "cherry-pick" ? $"pick-{commits.Count}" : idField ?? $"c{commits.Count}"; if (commits.Any(commit => commit.Id == id)) throw line.Error("提交标识符重复。", "semantic");
            var type = DiagramSyntax.Match(@"\btype:\s*(NORMAL|REVERSE|HIGHLIGHT)\b", rest)?[1] ?? m[1]; var tag = DiagramSyntax.Match("\\btag:\\s*\"([^\"]+)\"", rest)?[1] ?? ""; var message = DiagramSyntax.Match("\\bmsg:\\s*\"([^\"]+)\"", rest)?[1] ?? "";
            foreach (var field in new[] { "id", "tag", "msg", "type" }) if (Regex.Matches(rest, @"\b" + field + ":", RegexOptions.CultureInvariant, TimeSpan.FromSeconds(2)).Count > 1) throw line.Error("同一个提交属性不能重复。", "semantic");
            var cleaned = Regex.Replace(rest, "\\b(?:id|tag|msg):\\s*\"[^\"]*\"|\\btype:\\s*(?:NORMAL|REVERSE|HIGHLIGHT)", "", RegexOptions.CultureInvariant, TimeSpan.FromSeconds(2)).Trim(); if (cleaned.Length > 0) throw line.Error($"暂不支持这条提交属性：{cleaned}");
            commits.Add(new(id, branches.IndexOf(current), parents.ToArray(), type, tag, message)); heads[current] = commits.Count - 1;
        }
        DiagramSyntax.Nonempty(commits.Count, DiagramKind.GitGraph); var timeLength = commits.Count * 100 + 140; var laneLength = branches.Count * 90 + 100; var width = vertical ? laneLength : timeLength; var top = b.Title(DiagramSyntax.Title(lines), width);
        Func<int, DiagramPoint> point = i => { var time = 110 + (reverse ? commits.Count - 1 - i : i) * 100; var lane = 80 + commits[i].Lane * 90; return vertical ? new(lane, time + top) : new(time, lane + top); };
        for (var i = 0; i < branches.Count; i++) { var lane = 80 + i * 90; if (vertical) { b.Text(branches[i], new(lane - 40, top + 32, 80, 28), 14, C.Series(i)); b.Line([new(lane, top + 76), new(lane, top + timeLength - 20)], C.Series(i), dash: [2, 4]); } else { b.Text(branches[i], new(8, lane + top - 14, 84, 28), 14, C.Series(i)); b.Line([new(96, lane + top), new(width - 20, lane + top)], C.Series(i), dash: [2, 4]); } }
        for (var i = 0; i < commits.Count; i++)
        {
            var commit = commits[i]; var p = point(i);
            foreach (var parent in commit.Parents) { var a = point(parent); var c1 = vertical ? new DiagramPoint(a.X, (a.Y + p.Y) / 2) : new((a.X + p.X) / 2, a.Y); var c2 = vertical ? new DiagramPoint(p.X, (a.Y + p.Y) / 2) : new((a.X + p.X) / 2, p.Y); b.Path([new PathCommand.Move(a), new PathCommand.Cubic(c1, c2, p)], stroke: C.Series(commit.Lane), width: 2, dash: commit.Type == "cherry-pick" ? [4, 3] : []); }
            var dot = new DiagramRect(p.X - 7, p.Y - 7, 14, 14); if (commit.Type == "HIGHLIGHT") b.Rect(dot, C.Series(commit.Lane), C.None, 2, id: commit.Id, label: commit.Id); else b.Ellipse(dot, commit.Type == "merge" ? C.Background : C.Series(commit.Lane), C.Series(commit.Lane), id: commit.Id, label: commit.Id);
            if (commit.Type == "merge") b.Ellipse(dot.Inset(4, 4), C.Series(commit.Lane), C.None); if (commit.Type == "REVERSE") b.Line([new(p.X - 3, p.Y - 3), new(p.X + 3, p.Y + 3)], C.Background);
            b.Text(commit.Message.Length == 0 ? commit.Id : commit.Message, new(p.X - 42, p.Y + 14, 84, 24), 12); if (commit.Tag.Length > 0) b.Box(commit.Tag, new(p.X - 40, p.Y - 42, 80, 24), C.SurfaceAlt, size: 12);
        }
        return b.Build(width, top + (vertical ? timeLength : laneLength));
    }
}
