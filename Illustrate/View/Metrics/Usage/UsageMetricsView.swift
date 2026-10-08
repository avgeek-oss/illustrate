// MARK: - UsageMetricsView.swift

// Analytics view showing usage statistics and costs.
//
// Displays aggregated metrics per provider:
// - Daily generation counts
// - Storage size utilized
// - Estimated costs incurred
// - Total images vs videos
//
// ## Charts
// Uses Swift Charts to visualize:
// - Generation count over time
// - Cost accumulation
// - Storage growth
//
// ## Platform
// iOS only - macOS doesn't have this view.

import AvgeekDesignSystem
import Charts
import OSLog
import SwiftData
import SwiftUI

/// Single unit of usage metrics for a time period.
struct UsageMetricsUnit: Identifiable {
    var id: UUID = .init()
    var date: Date
    var sizeUtilized: Double
    var costIncurred: Double
    var totalGenerations: Int
}

struct UsageMetrics {
    var dailyMetrics: [UsageMetricsUnit]
    var generationMetrics: [UsageMetricsUnit]
    var totalMetrics: UsageMetricsUnit?
    var totalImages = 0
    var totalVideos = 0
}

struct UsageMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var projectManager: ProjectManager
    @ObservedObject private var providerKeysCache = ProviderKeysCache.shared

    private var providerKeys: [ProviderKey] {
        providerKeysCache.providerKeys
    }

    @State private var selectedProviderId = ""
    @State private var cachedMetrics: UsageMetrics = .init(dailyMetrics: [], generationMetrics: [], totalMetrics: nil)

    private var selectedProviderKey: ProviderKey? {
        providerKeys.first { $0.providerId.uuidString == selectedProviderId }
    }

    private var selectedProvider: Provider? {
        guard let uuid = UUID(uuidString: selectedProviderId) else { return nil }
        return getProvider(providerId: uuid)
    }

    func computeMetrics() -> UsageMetrics {
        guard !selectedProviderId.isEmpty,
              let provider = providersById[UUID(uuidString: selectedProviderId) ?? UUID()]
        else {
            return UsageMetrics(dailyMetrics: [], generationMetrics: [], totalMetrics: nil)
        }

        let models: [ProviderModel] = ProviderService.shared.allModels
            .filter { $0.providerId == provider.providerId }
        let modelIds: [String] = models.map(\.modelId.uuidString)
        let videoModelIds: Set<String> = Set(models.filter {
            $0.modelSetType == .VIDEO_GENERATE || $0.modelSetType == .VIDEO_EXTEND
        }.map(\.modelId.uuidString))
        let dateLimit = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let currentProjectId = projectManager.currentProjectId
        let fetchDescriptor = FetchDescriptor<Generation>(
            predicate: #Predicate { modelIds.contains($0.modelId) && $0.projectId == currentProjectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let generations = try modelContext.fetch(fetchDescriptor)

            var dailyMetricsMap: [Date: UsageMetricsUnit] = [:]
            var generationMetrics: [UsageMetricsUnit] = []
            var totalSize = 0.0
            var totalCost = 0.0
            var totalCount = 0
            var totalImages = 0
            var totalVideos = 0

            for generation in generations {
                let sizeMB = Double(String(format: "%.2f", Double(generation.size) / 1_000_000.0)) ?? 0.0
                let cost = generation.creditUsed
                let isVideo = videoModelIds.contains(generation.modelId)

                totalCount += 1
                totalSize += sizeMB
                totalCost += cost
                if isVideo { totalVideos += 1 } else { totalImages += 1 }

                if generation.createdAt >= dateLimit {
                    let unit = UsageMetricsUnit(
                        date: generation.createdAt,
                        sizeUtilized: sizeMB,
                        costIncurred: cost,
                        totalGenerations: 1
                    )
                    generationMetrics.append(unit)

                    let dayStart = Calendar.current.startOfDay(for: generation.createdAt)
                    if var existing = dailyMetricsMap[dayStart] {
                        existing.sizeUtilized += sizeMB
                        existing.costIncurred += cost
                        existing.totalGenerations += 1
                        dailyMetricsMap[dayStart] = existing
                    } else {
                        dailyMetricsMap[dayStart] = UsageMetricsUnit(
                            date: dayStart,
                            sizeUtilized: sizeMB,
                            costIncurred: cost,
                            totalGenerations: 1
                        )
                    }
                }
            }

            let dailyMetrics = dailyMetricsMap.values.sorted(by: { $0.date > $1.date })

            return UsageMetrics(
                dailyMetrics: dailyMetrics,
                generationMetrics: generationMetrics,
                totalMetrics: .init(
                    date: Date(),
                    sizeUtilized: totalSize,
                    costIncurred: totalCost,
                    totalGenerations: totalCount
                ),
                totalImages: totalImages,
                totalVideos: totalVideos
            )
        } catch {
            AppLogger.data.error("Error fetching data: \(error.localizedDescription, privacy: .public)")
        }

        return UsageMetrics(dailyMetrics: [], generationMetrics: [], totalMetrics: nil)
    }

    let columns: [GridItem] = {
        #if os(macOS)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        #else
        return Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
        )
        #endif
    }()

    var body: some View {
        Form {
            Section("Select Provider") {
                if providerKeys.isEmpty {
                    Text("No providers available to select.")
                        .foregroundStyle(secondaryLabel)
                        .padding()
                } else {
                    Picker("Provider", selection: $selectedProviderId) {
                        ForEach(providerKeys, id: \.providerId) { providerKey in
                            let provider = getProvider(providerId: providerKey.providerId)

                            Text(provider?.providerName ?? "").tag(providerKey.providerId.uuidString)
                        }
                    }
                }

                if !selectedProviderId.isEmpty {
                    HStack {
                        Text("Total Generations")
                        Spacer()
                        Text(cachedMetrics.totalMetrics?.totalGenerations.formatted() ?? "")
                    }
                    HStack {
                        Text("Images Generated")
                        Spacer()
                        Text(cachedMetrics.totalImages.formatted())
                    }
                    HStack {
                        Text("Videos Generated")
                        Spacer()
                        Text(cachedMetrics.totalVideos.formatted())
                    }
                    HStack {
                        Text("Est. Incurred Cost")
                        Spacer()
                        if let doubleValue = cachedMetrics.totalMetrics?.costIncurred {
                            if selectedProvider?.creditCurrency == .USD {
                                Text(formatEstimatedCost(doubleValue))
                            } else if selectedProvider?.creditCurrency == .CREDITS {
                                Text("\(doubleValue, specifier: "%.0f") credits")
                            }
                        }
                    }
                    HStack {
                        Text("Storage Consumed")
                        Spacer()
                        if let doubleValue = cachedMetrics.totalMetrics?.sizeUtilized {
                            Text("\(doubleValue, specifier: "%.0f") MB")
                        }
                    }
                }
            }

            if !selectedProviderId.isEmpty {
                Section("Metrics for last 30 days") {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Total Generations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if cachedMetrics.dailyMetrics.isEmpty {
                            AvgeekEmptyStateView(
                                icon: "chart.bar",
                                title: "No generation data",
                                message: "Start generating images to see your usage metrics here"
                            )
                            .padding(.vertical, 16)
                        } else {
                            Chart(cachedMetrics.dailyMetrics) { metric in
                                BarMark(
                                    x: .value("Date", metric.date, unit: .day),
                                    y: .value("Count", metric.totalGenerations)
                                )
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(date, format: .dateTime.month().day())
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .padding(.bottom, 8)
                            .frame(height: 200)
                        }
                    }
                    .padding(.all, 12)
                    .frame(alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 24) {
                        Text("Est. Incurred Cost")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if cachedMetrics.dailyMetrics.isEmpty {
                            AvgeekEmptyStateView(
                                icon: "dollarsign",
                                title: "No cost data",
                                message: "Start generating images to see your cost metrics here"
                            )
                            .padding(.vertical, 16)
                        } else {
                            Chart(cachedMetrics.dailyMetrics) { metric in
                                BarMark(
                                    x: .value("Date", metric.date, unit: .day),
                                    y: .value("Cost", metric.costIncurred)
                                )
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(date, format: .dateTime.month().day())
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            if selectedProvider?.creditCurrency == .USD {
                                                Text(formatEstimatedCost(doubleValue))
                                            } else if selectedProvider?.creditCurrency == .CREDITS {
                                                Text("\(doubleValue, specifier: "%.0f") credits")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                            .frame(height: 200)
                        }
                    }
                    .padding(.all, 12)
                    .frame(alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 24) {
                        Text("Storage Consumed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if cachedMetrics.dailyMetrics.isEmpty {
                            AvgeekEmptyStateView(
                                icon: "internaldrive",
                                title: "No storage data",
                                message: "Start generating images to see your storage usage here"
                            )
                            .padding(.vertical, 16)
                        } else {
                            Chart(cachedMetrics.dailyMetrics) { metric in
                                BarMark(
                                    x: .value("Date", metric.date, unit: .day),
                                    y: .value("Storage", metric.sizeUtilized)
                                )
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(date, format: .dateTime.month().day())
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            Text("\(doubleValue, specifier: "%.0f") MB")
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                            .frame(height: 200)
                        }
                    }
                    .padding(.all, 12)
                    .frame(alignment: .topLeading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadData()
        }
        .onChange(of: selectedProviderId) { _, _ in
            cachedMetrics = computeMetrics()
        }
        .onChange(of: projectManager.currentProjectId) { _, _ in
            selectedProviderId = ""
            loadData()
        }
        .navigationTitle("Usage Metrics")
    }

    func loadData() {
        if !providerKeys.isEmpty {
            selectedProviderId = providerKeys.first?.providerId.uuidString ?? ""
        } else {
            selectedProviderId = ""
        }
        cachedMetrics = computeMetrics()
    }
}
