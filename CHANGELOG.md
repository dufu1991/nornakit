# NornaKit changelog

NornaKit library versions use `vX.Y.Z` tags. Norna Studio keeps an independent app version and build number. Kit releases may include optional Studio companion assets; standalone app releases use `studio-vX.Y.Z` tags.

## 0.1.1 — 2026-10-22

- Stabilize compound layouts across edge declaration orders and plan nested connections at their shared outer boundaries.
- Reserve routing space around group borders and enforce parallel channel clearance in both planned routes and fallback pathfinding.
- Separate overlapping connections, improve feedback edge selection, and keep edge labels clear of nodes and other routes.
- Keep XY lines on their exact data samples, preserve square axes, and show the zero baseline for positive and negative bars.
- Reflow narrow mindmaps at a readable text size and consider narrower flowchart directions when the requested width is exceeded.
- Add 12 business fixtures and generated topology regressions covering fan-in, fan-out, nested groups, many-to-many connections, mixed directions, cycles, labels, and edge-order permutations.

No public API changes are required. The optional companion is Norna Studio 0.1.1, build 8.

## 0.1.0 — 2026-10-22

First independently versioned NornaKit Swift Package release, including the native rendering library and the following embedding fixes:

- Render horizontal XY bar and line charts, including grouped series and negative values.
- Support hexadecimal node colors and stroke widths in flowchart `classDef` and `class` declarations, preserving them through native drawing and SVG export.
- Support common Gantt `axisFormat` directives and correct dependency dates when weekends are excluded.
- Keep neutral appearances filled in grayscale with the themed palette's luminance and opacity layers. Preserve categorical data colors.
- Improve border and connector contrast in system appearances, and draw translucent fills independently from their outlines.
- Reflow timelines and journeys when their horizontal content exceeds the embedded width, and adjust sequence participant spacing and message wrapping to the requested width.
- Add regressions for 12 supplied Mermaid examples at natural, 320-point, and 640-point widths, with native pixel, SVG, and appearance checks.

Requires macOS 14 or later and Swift 6. The Swift Package has no external dependencies.
