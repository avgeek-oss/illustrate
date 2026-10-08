// MARK: - AgentGraphServiceTests.swift

// Unit tests for AgentGraphService - the graph manipulation and analysis engine
// for agent workflows.
//
// Tests cover:
// - Topological sorting (Kahn's algorithm)
// - Cycle detection (DFS-based)
// - Root/leaf card identification
// - Link validation
// - Graph validation

import XCTest
@testable import Illustrate

final class AgentGraphServiceTests: XCTestCase {
    // MARK: - Properties

    private var service: AgentGraphService!
    private var testAgentId: UUID!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        service = AgentGraphService.shared
        testAgentId = UUID()
    }

    override func tearDown() {
        service = nil
        testAgentId = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// Creates a test card with the given ID for graph testing.
    private func createTestCard(
        id: UUID = UUID(),
        agentId: UUID? = nil,
        cardType: CardType = .process,
        isDefault: Bool = false,
        position: CGPoint = .zero
    ) -> AgentCard {
        let card = AgentCard(
            agentId: agentId ?? testAgentId,
            cardType: cardType,
            position: position,
            isDefault: isDefault,
            title: "Test Card"
        )
        // Override the auto-generated ID for predictable testing
        setCardId(card, to: id)
        return card
    }

    /// Creates a test link between two cards.
    private func createTestLink(
        from sourceId: UUID,
        to targetId: UUID,
        agentId: UUID? = nil
    ) -> CardLink {
        CardLink(
            agentId: agentId ?? testAgentId,
            sourceCardId: sourceId,
            targetCardId: targetId
        )
    }

    /// Helper to set card ID via reflection (for testing with specific IDs).
    private func setCardId(_ card: AgentCard, to id: UUID) {
        // Access the underlying storage directly
        let mirror = Mirror(reflecting: card)
        for child in mirror.children {
            if child.label == "_id" || child.label == "id" {
                // Use the fact that AgentCard.id is settable
                break
            }
        }
        // Since id is a var, we can use key path
        // Actually, since AgentCard uses @Model, we need another approach
        // For test purposes, we'll work with the auto-generated IDs
    }

    // MARK: - Topological Sort Tests

    func testTopologicalSort_emptyGraph_returnsEmptyArray() {
        let cards: [AgentCard] = []
        let links: [CardLink] = []

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    func testTopologicalSort_singleCard_returnsSingleItem() {
        let card = createTestCard()
        let cards = [card]
        let links: [CardLink] = []

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.id, card.id)
    }

    func testTopologicalSort_linearChain_returnsCorrectOrder() throws {
        // Create a linear chain: A -> B -> C
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)

        // A must come before B, B must come before C
        if let sorted = result {
            let indexA = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardA.id }))
            let indexB = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardB.id }))
            let indexC = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardC.id }))

            XCTAssertLessThan(indexA, indexB, "A should come before B")
            XCTAssertLessThan(indexB, indexC, "B should come before C")
        }
    }

    func testTopologicalSort_diamondShape_returnsValidOrder() throws {
        // Diamond: A -> B, A -> C, B -> D, C -> D
        //     A
        //    / \
        //   B   C
        //    \ /
        //     D
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()
        let cardD = createTestCard()

        let cards = [cardA, cardB, cardC, cardD]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardA.id, to: cardC.id),
            createTestLink(from: cardB.id, to: cardD.id),
            createTestLink(from: cardC.id, to: cardD.id),
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 4)

        // Validate ordering constraints
        if let sorted = result {
            let indexA = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardA.id }))
            let indexB = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardB.id }))
            let indexC = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardC.id }))
            let indexD = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardD.id }))

            XCTAssertLessThan(indexA, indexB, "A should come before B")
            XCTAssertLessThan(indexA, indexC, "A should come before C")
            XCTAssertLessThan(indexB, indexD, "B should come before D")
            XCTAssertLessThan(indexC, indexD, "C should come before D")
        }
    }

    func testTopologicalSort_multipleRoots_allRootsFirst() throws {
        // Multiple independent roots: A -> C, B -> C
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardC.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)

        if let sorted = result {
            let indexA = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardA.id }))
            let indexB = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardB.id }))
            let indexC = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardC.id }))

            XCTAssertLessThan(indexA, indexC, "A should come before C")
            XCTAssertLessThan(indexB, indexC, "B should come before C")
        }
    }

    func testTopologicalSort_disconnectedComponents_returnsAll() throws {
        // Two separate components: A -> B, C -> D
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()
        let cardD = createTestCard()

        let cards = [cardA, cardB, cardC, cardD]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardC.id, to: cardD.id),
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 4)

        if let sorted = result {
            let indexA = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardA.id }))
            let indexB = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardB.id }))
            let indexC = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardC.id }))
            let indexD = try XCTUnwrap(sorted.firstIndex(where: { $0.id == cardD.id }))

            XCTAssertLessThan(indexA, indexB, "A should come before B")
            XCTAssertLessThan(indexC, indexD, "C should come before D")
        }
    }

    func testTopologicalSort_cycleDetected_returnsNil() {
        // Cycle: A -> B -> C -> A
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
            createTestLink(from: cardC.id, to: cardA.id), // Creates cycle
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNil(result, "Should return nil when cycle is detected")
    }

    func testTopologicalSort_selfLoop_returnsNil() {
        // Self-loop: A -> A
        let cardA = createTestCard()

        let cards = [cardA]
        let links = [
            createTestLink(from: cardA.id, to: cardA.id), // Self-loop
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNil(result, "Should return nil for self-loop")
    }

    // MARK: - Cycle Detection Tests

    func testWouldCreateCycle_noCycle_returnsFalse() {
        // Existing: A -> B
        // Adding: B -> C (no cycle)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let existingLinks = [
            createTestLink(from: cardA.id, to: cardB.id),
        ]

        let wouldCycle = service.wouldCreateCycle(
            from: cardB.id,
            to: cardC.id,
            existingLinks: existingLinks
        )

        XCTAssertFalse(wouldCycle, "Adding B -> C should not create a cycle")
    }

    func testWouldCreateCycle_directCycle_returnsTrue() {
        // Existing: A -> B
        // Adding: B -> A (creates direct cycle)
        let cardA = createTestCard()
        let cardB = createTestCard()

        let existingLinks = [
            createTestLink(from: cardA.id, to: cardB.id),
        ]

        let wouldCycle = service.wouldCreateCycle(
            from: cardB.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertTrue(wouldCycle, "Adding B -> A should create a cycle")
    }

    func testWouldCreateCycle_indirectCycle_returnsTrue() {
        // Existing: A -> B -> C
        // Adding: C -> A (creates indirect cycle)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let existingLinks = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let wouldCycle = service.wouldCreateCycle(
            from: cardC.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertTrue(wouldCycle, "Adding C -> A should create a cycle")
    }

    func testWouldCreateCycle_emptyGraph_returnsFalse() {
        let cardA = createTestCard()
        let cardB = createTestCard()

        let existingLinks: [CardLink] = []

        let wouldCycle = service.wouldCreateCycle(
            from: cardA.id,
            to: cardB.id,
            existingLinks: existingLinks
        )

        XCTAssertFalse(wouldCycle, "Empty graph should not have cycles")
    }

    func testWouldCreateCycle_selfLoop_returnsTrue() {
        // Self-loop: A -> A
        // When source == target, the algorithm starts with target in the stack.
        // On first iteration, current == target == source, so it returns true.
        let cardA = createTestCard()

        let existingLinks: [CardLink] = []

        let wouldCycle = service.wouldCreateCycle(
            from: cardA.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertTrue(wouldCycle, "Self-loop should be detected as a cycle")
    }

    func testWouldCreateCycle_longChain_detectsCycle() {
        // Existing: A -> B -> C -> D -> E
        // Adding: E -> A (creates long cycle)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()
        let cardD = createTestCard()
        let cardE = createTestCard()

        let existingLinks = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
            createTestLink(from: cardC.id, to: cardD.id),
            createTestLink(from: cardD.id, to: cardE.id),
        ]

        let wouldCycle = service.wouldCreateCycle(
            from: cardE.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertTrue(wouldCycle, "Adding E -> A should create a cycle")
    }

    // MARK: - canLink Tests

    func testCanLink_validLink_returnsTrue() {
        let cardA = createTestCard()
        let cardB = createTestCard()

        let existingLinks: [CardLink] = []

        let canLink = service.canLink(
            from: cardA.id,
            to: cardB.id,
            existingLinks: existingLinks
        )

        XCTAssertTrue(canLink, "Should allow link between unconnected cards")
    }

    func testCanLink_selfLink_returnsFalse() {
        let cardA = createTestCard()

        let existingLinks: [CardLink] = []

        let canLink = service.canLink(
            from: cardA.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertFalse(canLink, "Should not allow self-links")
    }

    func testCanLink_wouldCreateCycle_returnsFalse() {
        let cardA = createTestCard()
        let cardB = createTestCard()

        let existingLinks = [
            createTestLink(from: cardA.id, to: cardB.id),
        ]

        let canLink = service.canLink(
            from: cardB.id,
            to: cardA.id,
            existingLinks: existingLinks
        )

        XCTAssertFalse(canLink, "Should not allow links that create cycles")
    }

    // MARK: - Root Card Tests

    func testGetRootCards_singleRoot_returnsOne() {
        // A -> B -> C (A is the only root)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let roots = service.getRootCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots.first?.id, cardA.id)
    }

    func testGetRootCards_multipleRoots_returnsAll() {
        // A -> C, B -> C (A and B are roots)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardC.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let roots = service.getRootCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(roots.count, 2)
        let rootIds = Set(roots.map(\.id))
        XCTAssertTrue(rootIds.contains(cardA.id))
        XCTAssertTrue(rootIds.contains(cardB.id))
    }

    func testGetRootCards_noLinks_allAreRoots() {
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links: [CardLink] = []

        let roots = service.getRootCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(roots.count, 3, "All disconnected cards are roots")
    }

    func testGetRootCards_emptyGraph_returnsEmpty() {
        let cards: [AgentCard] = []
        let links: [CardLink] = []

        let roots = service.getRootCards(for: testAgentId, cards: cards, links: links)

        XCTAssertTrue(roots.isEmpty)
    }

    func testGetRootCards_filtersbyAgentId() {
        let otherAgentId = UUID()

        let cardA = createTestCard(agentId: testAgentId)
        let cardB = createTestCard(agentId: otherAgentId)

        let cards = [cardA, cardB]
        let links: [CardLink] = []

        let roots = service.getRootCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots.first?.id, cardA.id)
    }

    // MARK: - Leaf Card Tests

    func testGetLeafCards_singleLeaf_returnsOne() {
        // A -> B -> C (C is the only leaf)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let leaves = service.getLeafCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(leaves.count, 1)
        XCTAssertEqual(leaves.first?.id, cardC.id)
    }

    func testGetLeafCards_multipleLeaves_returnsAll() {
        // A -> B, A -> C (B and C are leaves)
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardA.id, to: cardC.id),
        ]

        let leaves = service.getLeafCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(leaves.count, 2)
        let leafIds = Set(leaves.map(\.id))
        XCTAssertTrue(leafIds.contains(cardB.id))
        XCTAssertTrue(leafIds.contains(cardC.id))
    }

    func testGetLeafCards_noLinks_allAreLeaves() {
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links: [CardLink] = []

        let leaves = service.getLeafCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(leaves.count, 3, "All disconnected cards are leaves")
    }

    func testGetLeafCards_emptyGraph_returnsEmpty() {
        let cards: [AgentCard] = []
        let links: [CardLink] = []

        let leaves = service.getLeafCards(for: testAgentId, cards: cards, links: links)

        XCTAssertTrue(leaves.isEmpty)
    }

    func testGetLeafCards_filtersByAgentId() {
        let otherAgentId = UUID()

        let cardA = createTestCard(agentId: testAgentId)
        let cardB = createTestCard(agentId: otherAgentId)

        let cards = [cardA, cardB]
        let links: [CardLink] = []

        let leaves = service.getLeafCards(for: testAgentId, cards: cards, links: links)

        XCTAssertEqual(leaves.count, 1)
        XCTAssertEqual(leaves.first?.id, cardA.id)
    }

    // MARK: - Incoming/Outgoing Links Tests

    func testGetIncomingLinks_hasLinks_returnsCorrect() {
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let linkAB = createTestLink(from: cardA.id, to: cardB.id)
        let linkCB = createTestLink(from: cardC.id, to: cardB.id)
        let linkBC = createTestLink(from: cardB.id, to: cardC.id)

        let links = [linkAB, linkCB, linkBC]

        let incoming = service.getIncomingLinks(for: cardB.id, links: links)

        XCTAssertEqual(incoming.count, 2)
        let sourceIds = Set(incoming.map(\.sourceCardId))
        XCTAssertTrue(sourceIds.contains(cardA.id))
        XCTAssertTrue(sourceIds.contains(cardC.id))
    }

    func testGetIncomingLinks_noLinks_returnsEmpty() {
        let cardA = createTestCard()

        let links: [CardLink] = []

        let incoming = service.getIncomingLinks(for: cardA.id, links: links)

        XCTAssertTrue(incoming.isEmpty)
    }

    func testGetOutgoingLinks_hasLinks_returnsCorrect() {
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let linkAB = createTestLink(from: cardA.id, to: cardB.id)
        let linkAC = createTestLink(from: cardA.id, to: cardC.id)
        let linkBC = createTestLink(from: cardB.id, to: cardC.id)

        let links = [linkAB, linkAC, linkBC]

        let outgoing = service.getOutgoingLinks(for: cardA.id, links: links)

        XCTAssertEqual(outgoing.count, 2)
        let targetIds = Set(outgoing.map(\.targetCardId))
        XCTAssertTrue(targetIds.contains(cardB.id))
        XCTAssertTrue(targetIds.contains(cardC.id))
    }

    func testGetOutgoingLinks_noLinks_returnsEmpty() {
        let cardA = createTestCard()

        let links: [CardLink] = []

        let outgoing = service.getOutgoingLinks(for: cardA.id, links: links)

        XCTAssertTrue(outgoing.isEmpty)
    }

    // MARK: - Execution Order Tests

    func testGetExecutionOrder_validGraph_returnsOrder() {
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardC.id),
        ]

        let order = service.getExecutionOrder(for: testAgentId, cards: cards, links: links)

        XCTAssertNotNil(order)
        XCTAssertEqual(order?.count, 3)
    }

    func testGetExecutionOrder_cycleInGraph_returnsNil() {
        let cardA = createTestCard()
        let cardB = createTestCard()

        let cards = [cardA, cardB]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardA.id), // Cycle
        ]

        let order = service.getExecutionOrder(for: testAgentId, cards: cards, links: links)

        XCTAssertNil(order, "Should return nil for graph with cycle")
    }

    func testGetExecutionOrder_filtersByAgentId() {
        let otherAgentId = UUID()

        let cardA = createTestCard(agentId: testAgentId)
        let cardB = createTestCard(agentId: testAgentId)
        let cardC = createTestCard(agentId: otherAgentId)

        let cards = [cardA, cardB, cardC]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id, agentId: testAgentId),
        ]

        let order = service.getExecutionOrder(for: testAgentId, cards: cards, links: links)

        XCTAssertNotNil(order)
        XCTAssertEqual(order?.count, 2, "Should only include cards from testAgentId")
    }

    // MARK: - Graph Validation Tests

    func testValidateGraph_validGraph_isValid() {
        let startCard = createTestCard(cardType: .start, isDefault: true)
        let processCard = createTestCard(cardType: .process)
        let outputCard = createTestCard(cardType: .output)

        let cards = [startCard, processCard, outputCard]
        let links = [
            createTestLink(from: startCard.id, to: processCard.id),
            createTestLink(from: processCard.id, to: outputCard.id),
        ]

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testValidateGraph_missingStartCard_returnsError() {
        // No start card with isDefault = true
        let processCard = createTestCard(cardType: .process)
        let outputCard = createTestCard(cardType: .output)

        let cards = [processCard, outputCard]
        let links = [
            createTestLink(from: processCard.id, to: outputCard.id),
        ]

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("missing a Start card") })
    }

    func testValidateGraph_cycleInGraph_returnsError() {
        let startCard = createTestCard(cardType: .start, isDefault: true)
        let cardA = createTestCard(cardType: .process)
        let cardB = createTestCard(cardType: .process)

        let cards = [startCard, cardA, cardB]
        let links = [
            createTestLink(from: startCard.id, to: cardA.id),
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardA.id), // Cycle
        ]

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("cycle") })
    }

    func testValidateGraph_orphanedLink_returnsError() {
        let startCard = createTestCard(cardType: .start, isDefault: true)
        let nonExistentCardId = UUID()

        let cards = [startCard]
        let links = [
            createTestLink(from: startCard.id, to: nonExistentCardId),
        ]

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("non-existent") })
    }

    func testValidateGraph_emptyGraph_missingStartCard() {
        let cards: [AgentCard] = []
        let links: [CardLink] = []

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("missing a Start card") })
    }

    func testValidateGraph_startCardNotDefault_returnsError() {
        // Start card exists but isDefault = false
        let startCard = createTestCard(cardType: .start, isDefault: false)

        let cards = [startCard]
        let links: [CardLink] = []

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("missing a Start card") })
    }

    func testValidateGraph_multipleErrors_returnsAll() {
        // No start card AND cycle
        let cardA = createTestCard(cardType: .process)
        let cardB = createTestCard(cardType: .process)

        let cards = [cardA, cardB]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardB.id, to: cardA.id),
        ]

        let result = service.validateGraph(for: testAgentId, cards: cards, links: links)

        XCTAssertFalse(result.isValid)
        XCTAssertGreaterThanOrEqual(result.errors.count, 2, "Should have multiple errors")
    }

    // MARK: - Complex Graph Tests

    func testTopologicalSort_complexDAG_maintainsAllConstraints() throws {
        // Complex DAG:
        //     A
        //    /|\
        //   B C D
        //   |X|/
        //   E F
        //    \|
        //     G
        let cardA = createTestCard()
        let cardB = createTestCard()
        let cardC = createTestCard()
        let cardD = createTestCard()
        let cardE = createTestCard()
        let cardF = createTestCard()
        let cardG = createTestCard()

        let cards = [cardA, cardB, cardC, cardD, cardE, cardF, cardG]
        let links = [
            createTestLink(from: cardA.id, to: cardB.id),
            createTestLink(from: cardA.id, to: cardC.id),
            createTestLink(from: cardA.id, to: cardD.id),
            createTestLink(from: cardB.id, to: cardE.id),
            createTestLink(from: cardB.id, to: cardF.id),
            createTestLink(from: cardC.id, to: cardE.id),
            createTestLink(from: cardC.id, to: cardF.id),
            createTestLink(from: cardD.id, to: cardF.id),
            createTestLink(from: cardE.id, to: cardG.id),
            createTestLink(from: cardF.id, to: cardG.id),
        ]

        let result = service.topologicalSort(cards: cards, links: links)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 7)

        if let sorted = result {
            // Verify all dependencies are satisfied
            let indices = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($1.id, $0) })

            // A must come before B, C, D
            XCTAssertLessThan(try XCTUnwrap(indices[cardA.id]), try XCTUnwrap(indices[cardB.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardA.id]), try XCTUnwrap(indices[cardC.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardA.id]), try XCTUnwrap(indices[cardD.id]))

            // B, C must come before E
            XCTAssertLessThan(try XCTUnwrap(indices[cardB.id]), try XCTUnwrap(indices[cardE.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardC.id]), try XCTUnwrap(indices[cardE.id]))

            // B, C, D must come before F
            XCTAssertLessThan(try XCTUnwrap(indices[cardB.id]), try XCTUnwrap(indices[cardF.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardC.id]), try XCTUnwrap(indices[cardF.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardD.id]), try XCTUnwrap(indices[cardF.id]))

            // E, F must come before G
            XCTAssertLessThan(try XCTUnwrap(indices[cardE.id]), try XCTUnwrap(indices[cardG.id]))
            XCTAssertLessThan(try XCTUnwrap(indices[cardF.id]), try XCTUnwrap(indices[cardG.id]))
        }
    }
}
