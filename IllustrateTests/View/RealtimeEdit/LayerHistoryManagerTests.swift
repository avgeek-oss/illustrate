// MARK: - LayerHistoryManagerTests.swift

import XCTest
@testable import Illustrate

final class LayerHistoryManagerTests: XCTestCase {
    var historyManager: LayerHistoryManager!
    var sessionId: UUID!

    override func setUp() {
        super.setUp()
        historyManager = LayerHistoryManager()
        sessionId = UUID()
    }

    override func tearDown() {
        historyManager = nil
        sessionId = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    func createTestLayer(
        name: String = "Test Layer",
        x: CGFloat = 0,
        y: CGFloat = 0,
        width: CGFloat = 100,
        height: CGFloat = 100
    ) -> RealtimeEditLayer {
        RealtimeEditLayer(
            sessionId: sessionId,
            layerType: .drawing,
            name: name,
            position: CGPoint(x: x, y: y),
            size: CGSize(width: width, height: height),
            zIndex: 0
        )
    }

    // MARK: - Initial State Tests

    func testInitialStateCannotUndo() {
        XCTAssertFalse(historyManager.canUndo)
    }

    // MARK: - Record Modification Tests

    func testRecordModificationEnablesUndo() {
        let layers = [createTestLayer()]

        historyManager.recordModification(of: layers)

        XCTAssertTrue(historyManager.canUndo)
    }

    func testRecordModificationWithMultipleLayers() {
        let layers = [
            createTestLayer(name: "Layer 1", x: 0, y: 0),
            createTestLayer(name: "Layer 2", x: 100, y: 100),
            createTestLayer(name: "Layer 3", x: 200, y: 200),
        ]

        historyManager.recordModification(of: layers)

        XCTAssertTrue(historyManager.canUndo)
    }

    func testMultipleRecordModificationsEnablesUndo() {
        let layers1 = [createTestLayer(name: "Layer 1")]
        let layers2 = [createTestLayer(name: "Layer 2")]

        historyManager.recordModification(of: layers1)
        historyManager.recordModification(of: layers2)

        XCTAssertTrue(historyManager.canUndo)
    }

    // MARK: - Record Addition Tests

    func testRecordAdditionEnablesUndo() {
        let layerId = UUID()

        historyManager.recordAddition(of: layerId)

        XCTAssertTrue(historyManager.canUndo)
    }

    // MARK: - Record Deletion Tests

    func testRecordDeletionEnablesUndo() {
        let layers = [createTestLayer()]

        historyManager.recordDeletion(of: layers)

        XCTAssertTrue(historyManager.canUndo)
    }

    func testRecordDeletionCapturesLayerState() {
        let layer = createTestLayer(name: "Deleted Layer", x: 50, y: 75)

        historyManager.recordDeletion(of: [layer])

        let action = historyManager.undo()
        XCTAssertNotNil(action)
        XCTAssertEqual(action?.changes.count, 1)

        if case let .deleted(snapshot) = action?.changes.first {
            XCTAssertEqual(snapshot.name, "Deleted Layer")
            XCTAssertEqual(snapshot.positionX, 50)
            XCTAssertEqual(snapshot.positionY, 75)
        } else {
            XCTFail("Expected deleted change type")
        }
    }

    // MARK: - History Size Limit Tests

    func testHistorySizeLimit() {
        let maxSize = HistorySettings.maxHistorySize

        // Add more modifications than the limit
        for i in 0 ..< (maxSize + 10) {
            let layers = [createTestLayer(name: "Layer \(i)")]
            historyManager.recordModification(of: layers)
        }

        // Undo all actions (should be limited to maxSize)
        var undoCount = 0
        while historyManager.canUndo {
            _ = historyManager.undo()
            undoCount += 1
        }

        XCTAssertEqual(undoCount, maxSize)
    }

    // MARK: - Undo Tests

    func testUndoReturnsNilWhenEmpty() {
        let result = historyManager.undo()

        XCTAssertNil(result)
    }

    func testUndoReturnsAction() {
        let layer = createTestLayer(name: "Layer 1", x: 0, y: 0)
        historyManager.recordModification(of: [layer])

        let result = historyManager.undo()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.changes.count, 1)
    }

    func testUndoReturnsModifiedChange() {
        let layer = createTestLayer(name: "Original", x: 100, y: 200)
        historyManager.recordModification(of: [layer])

        let result = historyManager.undo()

        XCTAssertNotNil(result)
        if case let .modified(layerId, beforeSnapshot) = result?.changes.first {
            XCTAssertEqual(layerId, layer.id)
            XCTAssertEqual(beforeSnapshot.positionX, 100)
            XCTAssertEqual(beforeSnapshot.positionY, 200)
        } else {
            XCTFail("Expected modified change type")
        }
    }

    func testUndoAfterRecordAdditionReturnsAddedChange() {
        let layerId = UUID()
        historyManager.recordAddition(of: layerId)

        let result = historyManager.undo()

        XCTAssertNotNil(result)
        if case let .added(id) = result?.changes.first {
            XCTAssertEqual(id, layerId)
        } else {
            XCTFail("Expected added change type")
        }
    }

    func testMultipleUndos() {
        let layers1 = [createTestLayer(name: "Layer 1")]
        let layers2 = [createTestLayer(name: "Layer 2")]
        let layers3 = [createTestLayer(name: "Layer 3")]

        historyManager.recordModification(of: layers1)
        historyManager.recordModification(of: layers2)
        historyManager.recordModification(of: layers3)

        XCTAssertTrue(historyManager.canUndo)

        _ = historyManager.undo()
        XCTAssertTrue(historyManager.canUndo)

        _ = historyManager.undo()
        XCTAssertTrue(historyManager.canUndo)

        _ = historyManager.undo()
        XCTAssertFalse(historyManager.canUndo)
    }

    // MARK: - Clear Tests

    func testClearResetsUndoStack() {
        let layers = [createTestLayer()]
        historyManager.recordModification(of: layers)

        XCTAssertTrue(historyManager.canUndo)

        historyManager.clear()

        XCTAssertFalse(historyManager.canUndo)
    }

    func testClearAfterMultipleOperations() {
        let layers1 = [createTestLayer(name: "Layer 1")]
        let layers2 = [createTestLayer(name: "Layer 2")]
        let layers3 = [createTestLayer(name: "Layer 3")]

        historyManager.recordModification(of: layers1)
        historyManager.recordModification(of: layers2)
        historyManager.recordModification(of: layers3)

        _ = historyManager.undo()

        historyManager.clear()

        XCTAssertFalse(historyManager.canUndo)
    }

    // MARK: - Layer Snapshot Tests

    func testLayerSnapshotCapturesPosition() {
        let layer = createTestLayer(x: 123, y: 456)
        let snapshot = LayerSnapshot(from: layer)

        XCTAssertEqual(snapshot.positionX, 123)
        XCTAssertEqual(snapshot.positionY, 456)
    }

    func testLayerSnapshotCapturesSize() {
        let layer = createTestLayer(width: 300, height: 400)
        let snapshot = LayerSnapshot(from: layer)

        XCTAssertEqual(snapshot.width, 300)
        XCTAssertEqual(snapshot.height, 400)
    }

    func testLayerSnapshotCapturesVisibility() {
        let layer = createTestLayer()
        layer.isVisible = false
        let snapshot = LayerSnapshot(from: layer)

        XCTAssertFalse(snapshot.isVisible)
    }

    func testLayerSnapshotCapturesLockState() {
        let layer = createTestLayer()
        layer.isLocked = true
        let snapshot = LayerSnapshot(from: layer)

        XCTAssertTrue(snapshot.isLocked)
    }

    func testLayerSnapshotRestoreUpdatesLayer() {
        let layer = createTestLayer(x: 100, y: 200, width: 300, height: 400)
        let snapshot = LayerSnapshot(from: layer)

        // Modify layer
        layer.positionX = 999
        layer.positionY = 999
        layer.width = 999
        layer.height = 999

        // Restore from snapshot
        snapshot.restore(to: layer)

        XCTAssertEqual(layer.positionX, 100)
        XCTAssertEqual(layer.positionY, 200)
        XCTAssertEqual(layer.width, 300)
        XCTAssertEqual(layer.height, 400)
    }

    // MARK: - Drawing Data Capture Tests

    func testLayerSnapshotCapturesDrawingData() {
        let layer = createTestLayer()
        let drawingData = DrawingData(strokes: [
            BrushStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)], colorHex: "FF0000", size: 10),
        ])
        layer.drawingData = drawingData.encode()

        let snapshot = LayerSnapshot(from: layer)

        // Modify layer's drawing data
        layer.drawingData = nil

        // Snapshot should have captured original
        let capturedData = snapshot.drawingData
        XCTAssertNotNil(capturedData)

        let decodedData = DrawingData.decode(from: capturedData)
        XCTAssertEqual(decodedData.strokes.count, 1)
    }

    // MARK: - Layer Change Enum Tests

    func testLayerChangeAddedContainsLayerId() {
        let layerId = UUID()
        let change = LayerChange.added(layerId: layerId)

        if case let .added(id) = change {
            XCTAssertEqual(id, layerId)
        } else {
            XCTFail("Expected added case")
        }
    }

    func testLayerChangeDeletedContainsSnapshot() {
        let layer = createTestLayer(name: "Test", x: 50, y: 100)
        let snapshot = LayerSnapshot(from: layer, captureDrawingDataNow: true)
        let change = LayerChange.deleted(snapshot: snapshot)

        if case let .deleted(snap) = change {
            XCTAssertEqual(snap.name, "Test")
            XCTAssertEqual(snap.positionX, 50)
            XCTAssertEqual(snap.positionY, 100)
        } else {
            XCTFail("Expected deleted case")
        }
    }

    func testLayerChangeModifiedContainsLayerIdAndSnapshot() {
        let layer = createTestLayer(name: "Modified", x: 25, y: 75)
        let snapshot = LayerSnapshot(from: layer)
        let change = LayerChange.modified(layerId: layer.id, beforeSnapshot: snapshot)

        if case let .modified(id, snap) = change {
            XCTAssertEqual(id, layer.id)
            XCTAssertEqual(snap.name, "Modified")
            XCTAssertEqual(snap.positionX, 25)
            XCTAssertEqual(snap.positionY, 75)
        } else {
            XCTFail("Expected modified case")
        }
    }
}
