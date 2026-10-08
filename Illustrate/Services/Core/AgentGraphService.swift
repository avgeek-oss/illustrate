// MARK: - AgentGraphService.swift

// Service for managing agent workflow graphs (cards and links).
//
// AgentGraphService provides all graph operations for agent workflows:
// - Card CRUD (add, remove, move)
// - Link CRUD (add, remove)
// - Graph analysis (execution order, validation)
//
// ## Graph Model
// Agent workflows form a Directed Acyclic Graph (DAG):
// - Nodes = AgentCards (start, process, output)
// - Edges = CardLinks (directed connections)
// - No cycles allowed
//
// ## Topological Sorting
// The service provides `getExecutionOrder()` which returns cards in
// topologically sorted order. This ensures cards are executed after
// all their dependencies (incoming links) are satisfied.
//
// ## Cycle Prevention
// Before adding links, `wouldCreateCycle()` checks if the new link
// would create a cycle. Links that would create cycles are rejected.
//
// ## Graph Queries
// - `getRootCards()`: Cards with no incoming links (entry points)
// - `getLeafCards()`: Cards with no outgoing links (endpoints)
// - `getIncomingLinks()` / `getOutgoingLinks()`: Links for a card

import Foundation
import OSLog
import SwiftData

/// Singleton service for agent graph manipulation and analysis.
///
/// Provides operations for managing the DAG structure of agent workflows:
/// - CRUD operations for cards and links
/// - Cycle detection to maintain DAG property
/// - Topological sorting for execution order
/// - Graph validation
class AgentGraphService {
    /// Shared singleton instance
    static let shared = AgentGraphService()

    private init() {}

    func addCard(
        to agentId: UUID,
        at position: CGPoint,
        type: CardType,
        title: String,
        modelContext: ModelContext
    ) -> AgentCard {
        let card = AgentCard(
            agentId: agentId,
            cardType: type,
            position: position,
            isDefault: false,
            title: title
        )
        modelContext.insert(card)
        return card
    }

    func removeCard(
        _ cardId: UUID,
        from agentId: UUID,
        cards: [AgentCard],
        links: [CardLink],
        modelContext: ModelContext
    ) -> Bool {
        guard let card = cards.first(where: { $0.id == cardId && $0.agentId == agentId }) else {
            return false
        }

        if card.isDefault {
            return false
        }

        let connectedLinks = links.filter {
            $0.sourceCardId == cardId || $0.targetCardId == cardId
        }

        for link in connectedLinks {
            modelContext.delete(link)
        }

        modelContext.delete(card)

        return true
    }

    func moveCard(
        _ cardId: UUID,
        to position: CGPoint,
        cards: [AgentCard]
    ) -> Bool {
        guard let card = cards.first(where: { $0.id == cardId }) else {
            return false
        }

        card.position = position
        return true
    }

    func addLink(
        from sourceCardId: UUID,
        to targetCardId: UUID,
        agentId: UUID,
        cards: [AgentCard],
        links: [CardLink],
        modelContext: ModelContext
    ) -> CardLink? {
        guard cards.first(where: { $0.id == sourceCardId && $0.agentId == agentId }) != nil,
              cards.first(where: { $0.id == targetCardId && $0.agentId == agentId }) != nil
        else {
            return nil
        }

        if sourceCardId == targetCardId {
            return nil
        }

        let existingLink = links.first {
            $0.sourceCardId == sourceCardId && $0.targetCardId == targetCardId
        }
        if existingLink != nil {
            return nil
        }

        if wouldCreateCycle(from: sourceCardId, to: targetCardId, existingLinks: links) {
            return nil
        }

        let link = CardLink(
            agentId: agentId,
            sourceCardId: sourceCardId,
            targetCardId: targetCardId
        )
        modelContext.insert(link)

        return link
    }

    func removeLink(
        _ linkId: UUID,
        links: [CardLink],
        modelContext: ModelContext
    ) -> Bool {
        guard let link = links.first(where: { $0.id == linkId }) else {
            return false
        }

        modelContext.delete(link)
        return true
    }

    func canLink(
        from sourceCardId: UUID,
        to targetCardId: UUID,
        existingLinks: [CardLink]
    ) -> Bool {
        if sourceCardId == targetCardId {
            return false
        }

        return !wouldCreateCycle(from: sourceCardId, to: targetCardId, existingLinks: existingLinks)
    }

    func getExecutionOrder(for agentId: UUID, cards: [AgentCard], links: [CardLink]) -> [AgentCard]? {
        let agentCards = cards.filter { $0.agentId == agentId }
        let agentLinks = links.filter { $0.agentId == agentId }

        return topologicalSort(cards: agentCards, links: agentLinks)
    }

    func getLeafCards(for agentId: UUID, cards: [AgentCard], links: [CardLink]) -> [AgentCard] {
        let agentCards = cards.filter { $0.agentId == agentId }
        let agentLinks = links.filter { $0.agentId == agentId }

        let cardsWithOutgoingLinks = Set(agentLinks.map(\.sourceCardId))

        return agentCards.filter { !cardsWithOutgoingLinks.contains($0.id) }
    }

    func getRootCards(for agentId: UUID, cards: [AgentCard], links: [CardLink]) -> [AgentCard] {
        let agentCards = cards.filter { $0.agentId == agentId }
        let agentLinks = links.filter { $0.agentId == agentId }

        let cardsWithIncomingLinks = Set(agentLinks.map(\.targetCardId))

        return agentCards.filter { !cardsWithIncomingLinks.contains($0.id) }
    }

    func getIncomingLinks(for cardId: UUID, links: [CardLink]) -> [CardLink] {
        links.filter { $0.targetCardId == cardId }
    }

    func getOutgoingLinks(for cardId: UUID, links: [CardLink]) -> [CardLink] {
        links.filter { $0.sourceCardId == cardId }
    }

    func wouldCreateCycle(
        from source: UUID,
        to target: UUID,
        existingLinks: [CardLink]
    ) -> Bool {
        var visited = Set<UUID>()
        var stack = [target]

        while let current = stack.popLast() {
            if current == source {
                return true
            }

            if visited.contains(current) {
                continue
            }
            visited.insert(current)

            let outgoing = existingLinks.filter { $0.sourceCardId == current }
            stack.append(contentsOf: outgoing.map(\.targetCardId))
        }

        return false
    }

    func topologicalSort(cards: [AgentCard], links: [CardLink]) -> [AgentCard]? {
        guard !cards.isEmpty else { return [] }

        var inDegree: [UUID: Int] = [:]
        var adjacencyList: [UUID: [UUID]] = [:]
        var cardMap: [UUID: AgentCard] = [:]

        for card in cards {
            inDegree[card.id] = 0
            adjacencyList[card.id] = []
            cardMap[card.id] = card
        }

        for link in links {
            adjacencyList[link.sourceCardId]?.append(link.targetCardId)
            inDegree[link.targetCardId, default: 0] += 1
        }

        var queue: [UUID] = cards
            .filter { inDegree[$0.id] == 0 }
            .map(\.id)

        var result: [AgentCard] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()

            if let card = cardMap[current] {
                result.append(card)
            }

            for neighbor in adjacencyList[current] ?? [] {
                inDegree[neighbor, default: 0] -= 1

                if inDegree[neighbor] == 0 {
                    queue.append(neighbor)
                }
            }
        }

        if result.count != cards.count {
            return nil
        }

        return result
    }

    func validateGraph(for agentId: UUID, cards: [AgentCard], links: [CardLink]) -> GraphValidationResult {
        let agentCards = cards.filter { $0.agentId == agentId }
        let agentLinks = links.filter { $0.agentId == agentId }

        var errors: [String] = []

        if topologicalSort(cards: agentCards, links: agentLinks) == nil {
            errors.append("Graph contains a cycle")
        }

        let cardIds = Set(agentCards.map(\.id))
        for link in agentLinks {
            if !cardIds.contains(link.sourceCardId) {
                errors.append("Link references non-existent source card: \(link.sourceCardId)")
            }
            if !cardIds.contains(link.targetCardId) {
                errors.append("Link references non-existent target card: \(link.targetCardId)")
            }
        }

        let hasStartCard = agentCards.contains { $0.cardType == .start && $0.isDefault }
        if !hasStartCard {
            errors.append("Agent is missing a Start card")
        }

        return GraphValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

struct GraphValidationResult {
    let isValid: Bool
    let errors: [String]
}
