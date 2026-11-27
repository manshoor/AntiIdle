import CoreGraphics

/// Keeps a point on a display. Pure: callers pass display bounds in
/// global display coordinates (CGDisplayBounds: origin top-left of the
/// main display, y down; other displays may have negative origins).
enum DisplayClamp {
    static func clamp(_ point: CGPoint, to displays: [CGRect], margin: CGFloat) -> CGPoint {
        // Prefer the display under the point; else the closest one.
        let containing = displays.first { $0.contains(point) }
        guard let display = containing ?? nearest(to: point, in: displays) else {
            return point
        }

        return CGPoint(
            x: max(display.minX + margin, min(point.x, display.maxX - margin)),
            y: max(display.minY + margin, min(point.y, display.maxY - margin))
        )
    }

    // Display with the smallest straight-line distance from point to its edge.
    private static func nearest(to point: CGPoint, in displays: [CGRect]) -> CGRect? {
        return displays.min { distanceSquared(point, $0) < distanceSquared(point, $1) }
    }

    private static func distanceSquared(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
