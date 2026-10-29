import CoreGraphics

nonisolated enum CropHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move
}

/// The rules of the crop frame, in coordinates from 0 to 1 across the photo, so the screen and the tests share one definition.
nonisolated enum CropGeometry {
    static let full = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// The frame can't get smaller than this share of the photo in either direction.
    static let minSide: CGFloat = 0.1

    static func isFull(_ rect: CGRect) -> Bool {
        abs(rect.minX) < 0.001 && abs(rect.minY) < 0.001 && abs(rect.maxX - 1) < 0.001 && abs(rect.maxY - 1) < 0.001
    }

    /// What a touch at `point` grabs, with the frame given in the same units as the point (view points). Corners win over
    /// edges, edges over the inside.
    static func hitTest(_ point: CGPoint, rect: CGRect, slop: CGFloat = 28) -> CropHandle? {
        let nearLeft = abs(point.x - rect.minX) <= slop
        let nearRight = abs(point.x - rect.maxX) <= slop
        let nearTop = abs(point.y - rect.minY) <= slop
        let nearBottom = abs(point.y - rect.maxY) <= slop
        let withinX = point.x >= rect.minX - slop && point.x <= rect.maxX + slop
        let withinY = point.y >= rect.minY - slop && point.y <= rect.maxY + slop

        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if nearTop && withinX { return .top }
        if nearBottom && withinX { return .bottom }
        if nearLeft && withinY { return .left }
        if nearRight && withinY { return .right }
        return rect.contains(point) ? .move : nil
    }

    /// The frame after dragging `handle` by `delta` (a share of the photo), kept inside the photo and above the minimum size.
    static func drag(_ handle: CropHandle, from start: CGRect, by delta: CGSize) -> CGRect {
        if handle == .move {
            let x = min(max(start.minX + delta.width, 0), 1 - start.width)
            let y = min(max(start.minY + delta.height, 0), 1 - start.height)
            return CGRect(x: x, y: y, width: start.width, height: start.height)
        }
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        switch handle {
        case .topLeft, .left, .bottomLeft: minX = min(max(start.minX + delta.width, 0), maxX - minSide)
        case .topRight, .right, .bottomRight: maxX = max(min(start.maxX + delta.width, 1), minX + minSide)
        default: break
        }
        switch handle {
        case .topLeft, .top, .topRight: minY = min(max(start.minY + delta.height, 0), maxY - minSide)
        case .bottomLeft, .bottom, .bottomRight: maxY = max(min(start.maxY + delta.height, 1), minY + minSide)
        default: break
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
