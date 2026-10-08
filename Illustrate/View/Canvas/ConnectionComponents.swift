// MARK: - ConnectionComponents.swift

// Components for drawing and managing card connections on the canvas.
//
// This file provides:
// - ConnectionDragState: Tracks in-progress link creation
// - ConnectionStateManager: Shared state for connection interactions
// - Connection dots and lines for visual representation
//
// ## Connection Flow
// 1. User drags from card's output connector
// 2. ConnectionStateManager tracks drag state
// 3. Preview line drawn to cursor
// 4. On drop over valid target, link is created
//
// ## Connection Lines
// Drawn as bezier curves between card connectors.
// Selected links are highlighted for deletion.

import SwiftUI

// MARK: - Connection Drag State

/// State for an in-progress connection drag operation.
struct ConnectionDragState: Equatable {
    let sourceCardId: UUID
    let sourcePosition: CGPoint
    let isFromOutput: Bool
    var currentMousePosition: CGPoint

    static func == (lhs: ConnectionDragState, rhs: ConnectionDragState) -> Bool {
        lhs.sourceCardId == rhs.sourceCardId && lhs.isFromOutput == rhs.isFromOutput
    }
}

// MARK: - Connection State Manager

@MainActor
class ConnectionStateManager: ObservableObject {
    static let shared = ConnectionStateManager()

    @Published var dragState: ConnectionDragState?
    @Published var selectedLinkId: UUID?
    @Published var hoveredCardId: UUID?

    private init() {}

    func startDragging(from cardId: UUID, position: CGPoint, isOutput: Bool) {
        dragState = ConnectionDragState(
            sourceCardId: cardId,
            sourcePosition: position,
            isFromOutput: isOutput,
            currentMousePosition: position
        )
        selectedLinkId = nil
    }

    func updateDragPosition(_ position: CGPoint) {
        dragState?.currentMousePosition = position
    }

    func endDragging() {
        dragState = nil
    }

    func selectLink(_ linkId: UUID) {
        selectedLinkId = linkId
    }

    func clearLinkSelection() {
        selectedLinkId = nil
    }

    func setHoveredCard(_ cardId: UUID?) {
        hoveredCardId = cardId
    }
}

// MARK: - Connection Dot Type

enum ConnectionDotType {
    case input
    case output
}

// MARK: - Bezier Curve Shape

struct BezierCurveShape: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: startPoint)

        let deltaX = endPoint.x - startPoint.x
        let controlOffset = max(abs(deltaX) * 0.5, 50)

        let controlPoint1 = CGPoint(x: startPoint.x + controlOffset, y: startPoint.y)
        let controlPoint2 = CGPoint(x: endPoint.x - controlOffset, y: endPoint.y)

        path.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        return path
    }
}

// MARK: - Vertical Bezier Curve Shape (for Flow Canvas - top to bottom)

struct VerticalBezierCurveShape: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: startPoint)

        let deltaY = endPoint.y - startPoint.y
        let controlOffset = max(abs(deltaY) * 0.5, 50)

        let controlPoint1 = CGPoint(x: startPoint.x, y: startPoint.y + controlOffset)
        let controlPoint2 = CGPoint(x: endPoint.x, y: endPoint.y - controlOffset)

        path.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        return path
    }
}

// MARK: - Connection Line View

struct ConnectionLineView: View {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let isSelected: Bool
    let isAnimating: Bool
    let isLocked: Bool
    var isVertical = false
    var isConnectedToSelectedCard = false
    let onTap: () -> Void

    private let dashPattern: [CGFloat] = [8, 6]

    var body: some View {
        ZStack {
            if isAnimating {
                TimelineView(.animation) { timeline in
                    let dashPhase = -CGFloat(
                        timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 1.0)
                    ) * 14
                    dashedLine(dashPhase: dashPhase)
                }
            } else {
                dashedLine(dashPhase: 0)
            }

            if isSelected {
                selectionHighlight
            }

            tapTarget
        }
    }

    @ViewBuilder
    private var selectionHighlight: some View {
        if isVertical {
            VerticalBezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(
                    Color.red.opacity(0.3),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
        } else {
            BezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(
                    Color.red.opacity(0.3),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
        }
    }

    @ViewBuilder
    private var tapTarget: some View {
        if isVertical {
            VerticalBezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(Color.clear, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .contentShape(
                    VerticalBezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                        .stroke(style: StrokeStyle(lineWidth: 20))
                )
                .onTapGesture {
                    guard !isLocked else { return }
                    onTap()
                }
        } else {
            BezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(Color.clear, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .contentShape(
                    BezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                        .stroke(style: StrokeStyle(lineWidth: 20))
                )
                .onTapGesture {
                    guard !isLocked else { return }
                    onTap()
                }
        }
    }

    @ViewBuilder
    private func dashedLine(dashPhase: CGFloat) -> some View {
        let lineColor: Color = if isSelected {
            Color.red
        } else if isConnectedToSelectedCard {
            secondaryLabel.opacity(0.85)
        } else {
            secondaryLabel.opacity(0.5)
        }

        let lineWidth: CGFloat = if isSelected {
            3
        } else if isConnectedToSelectedCard {
            2.5
        } else {
            2
        }

        if isVertical {
            VerticalBezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(
                    lineColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dashPattern,
                        dashPhase: dashPhase
                    )
                )
        } else {
            BezierCurveShape(startPoint: startPoint, endPoint: endPoint)
                .stroke(
                    lineColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dashPattern,
                        dashPhase: dashPhase
                    )
                )
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let connectionDropped = Notification.Name("connectionDropped")
}

// MarqueeSelectionState is defined in CanvasConstants.swift
