import SwiftUI

struct QueueEducationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenQueueEducation") private var hasSeenQueueEducation = false

    var body: some View {
        NavigationStack {
            #if os(macOS)
            macOSContent
            #else
            iOSContent
            #endif
        }
        #if os(macOS)
        .frame(width: 380)
        #else
        .frame(maxWidth: 400)
        #endif
    }

    #if os(macOS)
    private var macOSContent: some View {
        VStack(spacing: 20) {
            Text(
                "Your generation request has been queued and will start processing shortly. You can keep adding requests, they'll process one after another. Completed generations appear in your the gallery."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .navigationTitle("Added to Queue")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Got it") {
                    hasSeenQueueEducation = true
                    dismiss()
                }
            }
        }
    }
    #endif

    #if os(iOS)
    private var iOSContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Your generation request has been queued and will start processing shortly.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                StepRow(
                    icon: "plus.circle.fill",
                    title: "Queue More",
                    description: "You can keep adding more generation requests — they'll process one after another."
                )
                StepRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Processing",
                    description: "Each request is processed in order. You'll see progress in the queue sidebar."
                )
                StepRow(
                    icon: "photo.on.rectangle.angled",
                    title: "Results",
                    description: "Completed generations appear automatically in your Image Gallery."
                )
            }
            .padding(.horizontal, 4)
        }
        .padding(24)
        .navigationTitle("Added to Queue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Got it") {
                    hasSeenQueueEducation = true
                    dismiss()
                }
            }
        }
    }
    #endif
}

private struct StepRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension QueueEducationSheet {
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenQueueEducation")
    }
}
