// MARK: - CompareImagesView.swift

// Side-by-side image comparison view (macOS only).
//
// Shows two images side by side for comparison, useful for:
// - Comparing source vs generated image
// - Viewing before/after for edits
// - Comparing inpainting mask with result
//
// ## Features
// - Synchronized zoom and pan
// - Labels for each panel
// - Optional mask overlay toggle
// - Full-screen presentation

import SwiftUI

#if os(macOS)
import AppKit

/// Side-by-side image comparison with synchronized zoom/pan.
struct CompareImagesView: View {
    let leftImageName: String
    let rightImageName: String
    let leftLabel: String
    let rightLabel: String
    let maskImageName: String?
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scrollMonitor: Any?
    @State private var viewSize: CGSize = .zero

    @State private var maskImage: PlatformImage? = nil
    @State private var showMask = false

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 5.0

    private func baseDisplaySize(for panelSize: CGSize) -> CGSize {
        CGSize(width: panelSize.width, height: panelSize.height)
    }

    private func clampOffset(_ offset: CGSize, scale: CGFloat, panelSize: CGSize) -> CGSize {
        let baseSize = baseDisplaySize(for: panelSize)
        let scaledWidth = baseSize.width * scale
        let scaledHeight = baseSize.height * scale

        let maxOffsetX = max(0, (scaledWidth - panelSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - panelSize.height) / 2)

        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = (geometry.size.width - 2) / 2
            let panelSize = CGSize(width: panelWidth, height: geometry.size.height)

            ZStack {
                systemBackground.ignoresSafeArea()

                HStack(spacing: 0) {
                    leftImagePanel(panelSize: panelSize)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)

                    imagePanel(
                        imageName: rightImageName,
                        label: rightLabel,
                        panelSize: panelSize,
                        showMaskOverlay: false
                    )
                }
                .gesture(dragGesture(panelSize: panelSize))
                .gesture(magnificationGesture(panelSize: panelSize))

                VStack {
                    HStack {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = max(minScale, scale - 0.25)
                                    lastScale = scale
                                    offset = clampOffset(offset, scale: scale, panelSize: panelSize)
                                    lastOffset = offset
                                }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Text("\(Int(scale * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 50)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = min(maxScale, scale + 0.25)
                                    lastScale = scale
                                }
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    scale = 1.0
                                    lastScale = scale
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            } label: {
                                Text("Reset")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )

                        if maskImage != nil {
                            Toggle(isOn: $showMask) {
                                Text("Show Mask")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                        }

                        Spacer()

                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(label.opacity(0.6), systemBackground)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                    }
                    .padding(20)

                    Spacer()
                }
            }
            .onAppear {
                viewSize = geometry.size
                setupScrollMonitor(panelSize: panelSize)
                loadMaskImage()
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
                let newPanelSize = CGSize(width: (newSize.width - 2) / 2, height: newSize.height)
                offset = clampOffset(offset, scale: scale, panelSize: newPanelSize)
                lastOffset = offset
            }
            .onDisappear {
                if let monitor = scrollMonitor {
                    NSEvent.removeMonitor(monitor)
                    scrollMonitor = nil
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 800)
        #endif
    }

    private func loadMaskImage() {
        guard let maskImageName else { return }
        DispatchQueue.global(qos: .background).async {
            let loaded = loadImageFromiCloud(maskImageName)
            DispatchQueue.main.async {
                maskImage = loaded
            }
        }
    }

    private func leftImagePanel(panelSize: CGSize) -> some View {
        imagePanel(imageName: leftImageName, label: leftLabel, panelSize: panelSize, showMaskOverlay: true)
    }

    private func imagePanel(imageName: String, label: String, panelSize: CGSize, showMaskOverlay: Bool) -> some View {
        ZStack {
            ICloudImageLoader(imageName: imageName) { image in
                if let image {
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: panelSize.width, height: panelSize.height)

                        if showMaskOverlay, showMask, let maskImage {
                            Image(nsImage: maskImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: panelSize.width, height: panelSize.height)
                                .opacity(0.4)
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                } else {
                    GradientSpinner()
                }
            }
            .frame(width: panelSize.width, height: panelSize.height)
            .id("compare_\(imageName)")

            VStack {
                Spacer()
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.bottom, 20)
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .clipped()
    }

    private func magnificationGesture(panelSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                offset = clampOffset(offset, scale: scale, panelSize: panelSize)
                lastOffset = offset
            }
    }

    private func dragGesture(panelSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampOffset(newOffset, scale: scale, panelSize: panelSize)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func setupScrollMonitor(panelSize: CGSize) {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            let delta = CGSize(
                width: event.scrollingDeltaX,
                height: event.scrollingDeltaY
            )
            DispatchQueue.main.async {
                let newOffset = CGSize(
                    width: offset.width + delta.width,
                    height: offset.height + delta.height
                )
                let currentPanelSize = CGSize(width: (viewSize.width - 2) / 2, height: viewSize.height)
                offset = clampOffset(newOffset, scale: scale, panelSize: currentPanelSize)
                lastOffset = offset
            }
            return event
        }
    }
}

#endif
