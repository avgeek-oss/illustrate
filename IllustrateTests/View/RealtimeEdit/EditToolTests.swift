// MARK: - EditToolTests.swift

import XCTest
@testable import Illustrate

final class EditToolTests: XCTestCase {
    // MARK: - Case Enumeration Tests

    func testAllCasesCount() {
        XCTAssertEqual(EditTool.allCases.count, 4)
    }

    func testAllCasesContainsSelect() {
        XCTAssertTrue(EditTool.allCases.contains(.select))
    }

    func testAllCasesContainsBrush() {
        XCTAssertTrue(EditTool.allCases.contains(.brush))
    }

    func testAllCasesContainsShape() {
        XCTAssertTrue(EditTool.allCases.contains(.shape))
    }

    func testAllCasesContainsAttach() {
        XCTAssertTrue(EditTool.allCases.contains(.attach))
    }

    // MARK: - Icon Property Tests

    func testSelectIcon() {
        XCTAssertEqual(EditTool.select.icon, "pointer.arrow")
    }

    func testBrushIcon() {
        XCTAssertEqual(EditTool.brush.icon, "paintbrush.pointed")
    }

    func testShapeIcon() {
        XCTAssertEqual(EditTool.shape.icon, "square.on.circle")
    }

    func testAttachIcon() {
        XCTAssertEqual(EditTool.attach.icon, "photo.on.rectangle.angled")
    }

    func testAllToolsHaveNonEmptyIcons() {
        for tool in EditTool.allCases {
            XCTAssertFalse(tool.icon.isEmpty, "\(tool) should have a non-empty icon")
        }
    }

    // MARK: - Label Property Tests

    func testSelectLabel() {
        XCTAssertEqual(EditTool.select.label, "Select")
    }

    func testBrushLabel() {
        XCTAssertEqual(EditTool.brush.label, "Brush")
    }

    func testShapeLabel() {
        XCTAssertEqual(EditTool.shape.label, "Shape")
    }

    func testAttachLabel() {
        XCTAssertEqual(EditTool.attach.label, "Attach")
    }

    func testAllToolsHaveNonEmptyLabels() {
        for tool in EditTool.allCases {
            XCTAssertFalse(tool.label.isEmpty, "\(tool) should have a non-empty label")
        }
    }

    // MARK: - Description Property Tests

    func testSelectDescription() {
        let description = EditTool.select.description
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("Select"))
        XCTAssertTrue(description.contains("transform"))
    }

    func testBrushDescription() {
        let description = EditTool.brush.description
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("Draw"))
        XCTAssertTrue(description.contains("drawing layer"))
    }

    func testShapeDescription() {
        let description = EditTool.shape.description
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("shapes"))
        XCTAssertTrue(description.contains("rectangles") || description.contains("circles"))
    }

    func testAttachDescription() {
        let description = EditTool.attach.description
        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("Attach"))
        XCTAssertTrue(description.contains("image"))
    }

    func testAllToolsHaveNonEmptyDescriptions() {
        for tool in EditTool.allCases {
            XCTAssertFalse(tool.description.isEmpty, "\(tool) should have a non-empty description")
        }
    }

    func testDescriptionsAreLongerThanLabels() {
        for tool in EditTool.allCases {
            XCTAssertGreaterThan(
                tool.description.count,
                tool.label.count,
                "\(tool) description should be longer than label for proper help text"
            )
        }
    }

    // MARK: - RequiresSelection Property Tests

    func testSelectRequiresSelection() {
        XCTAssertFalse(EditTool.select.requiresSelection)
    }

    func testBrushRequiresSelection() {
        XCTAssertFalse(EditTool.brush.requiresSelection)
    }

    func testShapeRequiresSelection() {
        XCTAssertFalse(EditTool.shape.requiresSelection)
    }

    func testAttachRequiresSelection() {
        XCTAssertFalse(EditTool.attach.requiresSelection)
    }

    // MARK: - Identifiable Conformance Tests

    func testSelectId() {
        XCTAssertEqual(EditTool.select.id, "select")
    }

    func testBrushId() {
        XCTAssertEqual(EditTool.brush.id, "brush")
    }

    func testShapeId() {
        XCTAssertEqual(EditTool.shape.id, "shape")
    }

    func testAttachId() {
        XCTAssertEqual(EditTool.attach.id, "attach")
    }

    func testIdsAreUnique() {
        let ids = EditTool.allCases.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All tool IDs should be unique")
    }

    // MARK: - Raw Value Tests

    func testSelectRawValue() {
        XCTAssertEqual(EditTool.select.rawValue, "select")
    }

    func testBrushRawValue() {
        XCTAssertEqual(EditTool.brush.rawValue, "brush")
    }

    func testShapeRawValue() {
        XCTAssertEqual(EditTool.shape.rawValue, "shape")
    }

    func testAttachRawValue() {
        XCTAssertEqual(EditTool.attach.rawValue, "attach")
    }

    func testRawValueInitialization() {
        XCTAssertEqual(EditTool(rawValue: "select"), .select)
        XCTAssertEqual(EditTool(rawValue: "brush"), .brush)
        XCTAssertEqual(EditTool(rawValue: "shape"), .shape)
        XCTAssertEqual(EditTool(rawValue: "attach"), .attach)
        XCTAssertNil(EditTool(rawValue: "invalid"))
    }
}
