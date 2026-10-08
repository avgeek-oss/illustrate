// MARK: - BrushStroke.swift

// Data model for freehand brush strokes.
//
// Stores stroke geometry and appearance for serialization
// to RealtimeEditLayer.drawingData.
//
// ## Structure
// Each stroke contains:
// - points: Array of CGPoints forming the stroke path
// - colorHex: Hex color string (e.g., "FF0000")
// - size: Stroke width in points
//
// ## Serialization
// DrawingData wraps an array of strokes for JSON encoding.

import Foundation
import SwiftUI

// MARK: - Brush Stroke

/// A single freehand brush stroke with points and styling.
struct BrushStroke: Codable, Identifiable {
    var id = UUID()
    var points: [CGPoint]
    var colorHex: String
    var size: CGFloat

    init(id: UUID = UUID(), points: [CGPoint], colorHex: String, size: CGFloat) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.size = size
    }
}

// MARK: - Stroke Simplification

extension BrushStroke {
    /// Simplifies the stroke using Douglas-Peucker algorithm.
    ///
    /// This reduces memory usage by removing points that don't significantly
    /// affect the visual appearance of the stroke.
    ///
    /// - Parameter epsilon: Maximum perpendicular distance for a point to be kept.
    ///   Lower values preserve more detail, higher values remove more points.
    ///   Default of 1.0 provides good balance between quality and compression.
    mutating func simplify(epsilon: CGFloat = 1.0) {
        guard points.count > 2 else { return }
        points = douglasPeucker(points: points, epsilon: epsilon)
    }

    /// Douglas-Peucker line simplification algorithm.
    ///
    /// Recursively simplifies a polyline by removing points that are within
    /// epsilon distance of the line segment between start and end points.
    private func douglasPeucker(points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        // Find the point with maximum distance from the line
        var maxDistance: CGFloat = 0
        var maxIndex = 0

        let start = points[0]
        let end = points[points.count - 1]

        for i in 1 ..< points.count - 1 {
            let distance = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance exceeds epsilon, recursively simplify
        if maxDistance > epsilon {
            let left = douglasPeucker(points: Array(points[0 ... maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(points: Array(points[maxIndex...]), epsilon: epsilon)

            // Combine results, removing duplicate middle point
            return Array(left.dropLast()) + right
        } else {
            // All points are within epsilon, keep only endpoints
            return [start, end]
        }
    }

    /// Calculates perpendicular distance from a point to a line segment.
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        // Handle degenerate case where start and end are the same point
        let lineLengthSquared = dx * dx + dy * dy
        if lineLengthSquared == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        // Calculate perpendicular distance using cross product formula
        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let denominator = sqrt(lineLengthSquared)

        return numerator / denominator
    }
}

// MARK: - Drawing Data

/// Container for all strokes in a drawing layer.
struct DrawingData: Codable {
    var strokes: [BrushStroke]

    init(strokes: [BrushStroke] = []) {
        self.strokes = strokes
    }

    /// Encodes drawing data to JSON for storage.
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decodes drawing data from JSON.
    static func decode(from data: Data?) -> DrawingData {
        guard let data,
              let decoded = try? JSONDecoder().decode(DrawingData.self, from: data)
        else {
            return DrawingData()
        }
        return decoded
    }
}
