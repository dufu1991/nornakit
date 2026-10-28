using System.Collections.Immutable;
using NornaKit;

namespace NornaStudio;

internal static class StudioExampleCatalog
{
    public static ImmutableArray<DiagramExample> All { get; } = ExampleCatalog.All
        .Where(example => example.Id is not ("sf-symbols" or "sf-symbols-wrapping" or "sf-symbols-color" or "sequence-sf-symbols"))
        .Select(example => example.Id == "rich-text" ? example with
        {
            Sources = new(
                example.Sources.En.Replace(":sf:checkmark.circle.fill:", ":win:check-circle:", StringComparison.Ordinal),
                example.Sources.Zh.Replace(":sf:checkmark.circle.fill:", ":win:check-circle:", StringComparison.Ordinal))
        } : example)
        .ToImmutableArray();
}
