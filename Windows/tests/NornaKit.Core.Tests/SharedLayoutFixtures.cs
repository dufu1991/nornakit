using System.Text.Json;
using NornaKit;

internal static class SharedLayoutFixtures
{
    public static async Task CheckAsync(IDiagramRenderer renderer, Action<bool, string> check)
    {
        using var stream = typeof(SharedLayoutFixtures).Assembly.GetManifestResourceStream("NornaKit.Tests.layout-fixtures.json")!;
        using var document = await JsonDocument.ParseAsync(stream);
        foreach (var fixture in document.RootElement.EnumerateArray())
        {
            var id = fixture.GetProperty("id").GetString();
            var width = fixture.TryGetProperty("maxWidth", out var value) && value.ValueKind != JsonValueKind.Null ? value.GetDouble() : (double?)null;
            var diagram = await renderer.RenderAsync(fixture.GetProperty("source").GetString()!, new(MaxWidth: width));
            var scene = diagram.Scene;
            Action<JsonElement, IEnumerable<double>, string> geometry = (expected, actual, field) =>
            {
                var numbers = expected.EnumerateArray().Select(number => number.GetDouble()).ToArray(); var values = actual.ToArray();
                check(numbers.Length == values.Length && numbers.Zip(values).All(pair => Math.Abs(pair.First - pair.Second) < .0001),
                    $"Shared Swift/C# layout changed: {id}/{field}: expected [{string.Join(',', numbers)}], actual [{string.Join(',', values)}].");
            };
            geometry(fixture.GetProperty("size"), [diagram.Width, diagram.Height], "size");
            var nodes = fixture.GetProperty("nodes").EnumerateArray().ToArray();
            check(nodes.Length == scene.Nodes.Length, $"Shared layout node count changed: {id}.");
            foreach (var (expected, node) in nodes.Zip(scene.Nodes))
            {
                check(expected.GetProperty("id").GetString() == node.Id && expected.GetProperty("label").GetString() == node.Label
                    && expected.GetProperty("shape").GetString() == Camel(node.Shape), $"Shared layout node semantics changed: {id}/{node.Id}.");
                geometry(expected.GetProperty("frame"), Rect(node.Frame), $"node/{node.Id}");
            }
            var edges = fixture.GetProperty("edges").EnumerateArray().ToArray();
            check(edges.Length == scene.Edges.Length, $"Shared layout edge count changed: {id}.");
            foreach (var (expected, edge) in edges.Zip(scene.Edges))
            {
                check(expected.GetProperty("from").GetString() == edge.From && expected.GetProperty("to").GetString() == edge.To
                    && expected.GetProperty("label").GetString() == edge.Label && expected.GetProperty("style").GetString() == Camel(edge.Style)
                    && expected.GetProperty("arrow").GetBoolean() == edge.Arrow && expected.GetProperty("startMarker").GetString() == Camel(edge.StartMarker)
                    && expected.GetProperty("endMarker").GetString() == Camel(edge.EndMarker ?? (edge.Arrow ? EdgeMarker.Arrow : EdgeMarker.None)), $"Shared layout edge semantics changed: {id}.");
                geometry(expected.GetProperty("labelFrame"), Rect(edge.LabelFrame), $"edge/{edge.From}-{edge.To}/label");
                var points = expected.GetProperty("points").EnumerateArray().ToArray();
                check(points.Length == edge.Points.Length, $"Shared layout route length changed: {id}/{edge.From}-{edge.To}.");
                foreach (var (point, actual) in points.Zip(edge.Points)) geometry(point, [actual.X, actual.Y], $"edge/{edge.From}-{edge.To}/point");
            }
            var groups = fixture.GetProperty("groups").EnumerateArray().ToArray();
            check(groups.Length == scene.Groups.Length, $"Shared layout group count changed: {id}.");
            foreach (var (expected, group) in groups.Zip(scene.Groups))
            {
                var parent = expected.TryGetProperty("parentId", out var parentId) ? parentId.GetString() : null;
                check(expected.GetProperty("id").GetString() == group.Id && expected.GetProperty("label").GetString() == group.Label
                    && parent == group.ParentId && expected.GetProperty("depth").GetInt32() == group.Depth, $"Shared layout group semantics changed: {id}/{group.Id}.");
                geometry(expected.GetProperty("frame"), Rect(group.Frame), $"group/{group.Id}");
                geometry(expected.GetProperty("titleFrame"), Rect(group.TitleFrame), $"group/{group.Id}/title");
            }
        }
    }
    private static double[] Rect(DiagramRect value) => [value.X, value.Y, value.Width, value.Height];
    private static string Camel<T>(T value) where T : Enum { var name = value.ToString(); return char.ToLowerInvariant(name[0]) + name[1..]; }
}
