// MARK: - LumaVideoOutputControlsSection.swift

import SwiftUI

struct LumaVideoOutputControlsSection: View {
    @Binding var hdr: Bool
    @Binding var exrExport: Bool
    @Binding var loop: Bool

    let supportsHDR: Bool
    let supportsLoop: Bool
    let validationMessage: String?

    var body: some View {
        if supportsHDR || supportsLoop {
            Section(header: Text("Output")) {
                if supportsHDR {
                    Toggle("HDR MP4", isOn: $hdr)
                    Toggle("EXR Export", isOn: $exrExport)
                }

                if supportsLoop {
                    Toggle("Seamless Loop", isOn: $loop)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
