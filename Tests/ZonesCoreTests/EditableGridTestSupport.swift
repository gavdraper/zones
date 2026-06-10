import CoreGraphics
@testable import ZonesCore

// Shared geometry helpers for the editable-grid suites. The scalar
// `isApproximately(_:tolerance:)` lives in LayoutTemplateTests.swift (same test
// target) and is reused here.

extension CGRect {
    /// Tolerant equality across all four components.
    func isApproximately(_ other: CGRect, tolerance: CGFloat = 1e-9) -> Bool {
        origin.x.isApproximately(other.origin.x, tolerance: tolerance)
            && origin.y.isApproximately(other.origin.y, tolerance: tolerance)
            && width.isApproximately(other.width, tolerance: tolerance)
            && height.isApproximately(other.height, tolerance: tolerance)
    }
}

/// The combined area of every zone's normalized frame.
func totalArea(of zones: [Zone]) -> Double {
    zones.reduce(0.0) { $0 + Double($1.normalizedFrame.width * $1.normalizedFrame.height) }
}

/// The largest overlapping area between any two distinct zones — `0` when the
/// zones tile without overlap.
func maxPairwiseOverlap(of zones: [Zone]) -> Double {
    var maxOverlap = 0.0
    for i in zones.indices {
        for j in zones.indices where j > i {
            let intersection = zones[i].normalizedFrame.intersection(zones[j].normalizedFrame)
            guard !intersection.isNull else { continue }
            maxOverlap = max(maxOverlap, Double(intersection.width * intersection.height))
        }
    }
    return maxOverlap
}
