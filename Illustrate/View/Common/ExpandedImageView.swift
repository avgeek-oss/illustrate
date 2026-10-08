// MARK: - ExpandedImageView.swift

// Full-screen zoomable image viewer.
//
// Presents an image in a modal overlay with:
// - Pinch/scroll to zoom (1x to 5x)
// - Pan to navigate when zoomed
// - Close button overlay
// - Platform-specific controls (scroll wheel on macOS)
//
// ## Gesture Handling
// - macOS: Scroll wheel for zoom, drag for pan
// - iOS: Pinch for zoom, drag for pan

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Full-screen zoomable image viewer with pan support.
struct ExpandedImageView: View {
    let imageName: String
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero

    #if os(macOS)
    @State private var scrollMonitor: Any?
    #endif

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    private func clampOffset(_ offset: CGSize, scale: CGFloat, viewSize: CGSize) -> CGSize {
        let maxOffsetX = (viewSize.width * (scale - 1)) / 2
        let maxOffsetY = (viewSize.height * (scale - 1)) / 2

        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                systemBackground.ignoresSafeArea()

                ICloudImageLoader(imageName: imageName) { image in
                    if let image {
                        imageContent(image: image, geometry: geometry)
                    } else {
                        GradientSpinner()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .id("expanded_\(imageName)")

                closeButton
            }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 800)
        #endif
    }

    @ViewBuilder
    private func imageContent(image: PlatformImage, geometry: GeometryProxy) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = 2.0
                    }
                    lastScale = scale
                    lastOffset = offset
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                viewSize = geometry.size
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
                    if scale > 1.0 {
                        let delta = CGSize(
                            width: event.scrollingDeltaX,
                            height: event.scrollingDeltaY
                        )
                        DispatchQueue.main.async {
                            let newOffset = CGSize(
                                width: offset.width + delta.width,
                                height: offset.height + delta.height
                            )
                            offset = clampOffset(newOffset, scale: scale, viewSize: viewSize)
                            lastOffset = offset
                        }
                    }
                    return event
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
            .onDisappear {
                if let monitor = scrollMonitor {
                    NSEvent.removeMonitor(monitor)
                    scrollMonitor = nil
                }
            }
        #else
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture)
            .gesture(dragGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = 2.0
                    }
                    lastScale = scale
                    lastOffset = offset
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
        #endif
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                    lastOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    let newOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = clampOffset(newOffset, scale: scale, viewSize: viewSize)
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(label.opacity(0.6), systemBackground)
                }
                .buttonStyle(.plain)
                .padding(20)
                .contentShape(Circle())
            }
            Spacer()
        }
    }
}
