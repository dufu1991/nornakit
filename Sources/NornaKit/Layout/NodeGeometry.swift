import Foundation

enum NodeGeometry {
    /// Side order is top, right, bottom, left. The offset runs rightward or downward.
    static func anchor(shape: NodeShape, frame r: CGRect, side: Int, offset: CGFloat) -> CGPoint {
        let vertical = side.isMultiple(of: 2)
        let half = (vertical ? r.width : r.height) / 2
        let offset = min(half * 0.9, max(-half * 0.9, offset))
        if let polygon = ScenePath.polygon(shape, frame: r) {
            let fixed = (vertical ? r.midX : r.midY) + offset
            let intersections = zip(polygon, polygon.dropFirst() + [polygon[0]]).compactMap { a, b -> CGFloat? in
                let low = vertical ? a.x : a.y, high = vertical ? b.x : b.y
                guard abs(high - low) > 0.001, fixed >= min(low, high), fixed <= max(low, high) else { return nil }
                let t = (fixed - low) / (high - low)
                return vertical ? a.y + t * (b.y - a.y) : a.x + t * (b.x - a.x)
            }
            if let edge = (side == 0 || side == 3) ? intersections.min() : intersections.max() {
                return vertical ? CGPoint(x: fixed, y: edge) : CGPoint(x: edge, y: fixed)
            }
        }
        var depth = (vertical ? r.height : r.width) / 2
        switch shape {
        case .diamond: depth *= 1 - abs(offset) / half
        case .circle, .doubleCircle, .ellipse: depth *= sqrt(max(0, 1 - pow(offset / half, 2)))
        case .cylinder where vertical:
            let ry = min(12, max(6, r.width / 14))
            depth -= ry * (1 - sqrt(max(0, 1 - pow(offset / half, 2))))
        case .stadium:
            let radius = r.height / 2
            if vertical {
                let curved = max(0, abs(offset) - (r.width / 2 - radius))
                depth = sqrt(max(0, radius * radius - curved * curved))
            } else {
                depth = r.width / 2 - radius + sqrt(max(0, radius * radius - offset * offset))
            }
        case .rectangle, .rounded, .subroutine:
            let radius = min(shape == .rounded ? 12 : DiagramStyle.cornerRadius, min(r.width, r.height) / 2)
            let corner = max(0, abs(offset) - (half - radius))
            depth -= radius - sqrt(max(0, radius * radius - corner * corner))
        default: break
        }
        switch side {
        case 0: return CGPoint(x: r.midX + offset, y: r.midY - depth)
        case 1: return CGPoint(x: r.midX + depth, y: r.midY + offset)
        case 2: return CGPoint(x: r.midX + offset, y: r.midY + depth)
        default: return CGPoint(x: r.midX - depth, y: r.midY + offset)
        }
    }
}
