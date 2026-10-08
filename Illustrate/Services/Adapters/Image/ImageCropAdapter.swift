// MARK: - ImageCropAdapter.swift

// Interactive image cropping component with aspect ratio constraints.
//
// Provides a native cropping UI that works on both macOS and iOS:
// - Drag to move the crop region
// - Drag corners to resize
// - Maintains aspect ratio when specified
// - Rule-of-thirds grid overlay
//
// ## Crop Normalization
// Crop coordinates are normalized to 0-1 range relative to the image,
// making them resolution-independent. The final crop is applied using
// the platform's native image cropping APIs.
//
// ## Aspect Ratio Handling
// When a target dimension is provided (e.g., "1024x1024"), the crop
// region maintains that aspect ratio. For flexible crops, any shape allowed.

import Foundation
import IllustrateProviders
import OSLog
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import Cocoa
#endif

/// Native crop view with drag handles and aspect ratio constraints.
struct NativeCropperView: View {
    let image: Image
    let platformImage: PlatformImage
    let aspectRatio: CGFloat?
    @Binding var cropRect: CGRect

    @State private var containerSize: CGSize = .zero
    @State private var displayedImageRect: CGRect = .zero

    @State private var cropOrigin: CGPoint = .zero
    @State private var cropSize: CGSize = .zero
    @State private var isDragging = false
    @State private var dragStartOrigin: CGPoint = .zero
    @State private var activeHandle: ResizeHandle? = nil
    @State private var initialCropRect: CGRect = .zero
    @State private var isInitialized = false

    private let handleSize: CGFloat = 12
    private let minCropSize: CGFloat = 50

    enum ResizeHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    private var imageAspectRatio: CGFloat {
        guard platformImage.size.height > 0 else { return 1 }
        return platformImage.size.width / platformImage.size.height
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height

            let displaySize = calculateDisplaySize(
                containerWidth: containerWidth,
                containerHeight: containerHeight
            )

            let imageRect = CGRect(
                x: (containerWidth - displaySize.width) / 2,
                y: (containerHeight - displaySize.height) / 2,
                width: displaySize.width,
                height: displaySize.height
            )

            ZStack {
                Color.black.opacity(0.1)

                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .position(x: containerWidth / 2, y: containerHeight / 2)

                if isInitialized, cropSize.width > 0, cropSize.height > 0 {
                    CropOverlayView(
                        displayedImageRect: displayedImageRect,
                        cropOrigin: cropOrigin,
                        cropSize: cropSize
                    )

                    CropHandlesView(
                        cropOrigin: cropOrigin,
                        cropSize: cropSize,
                        handleSize: handleSize,
                        onDrag: handleDrag,
                        onHandleDrag: handleResizeDrag
                    )
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .onAppear {
                initializeWithRect(imageRect)
            }
            .onChange(of: geometry.size) { _, _ in
                updateForNewRect(imageRect)
            }
        }
    }

    private func calculateDisplaySize(containerWidth: CGFloat, containerHeight: CGFloat) -> CGSize {
        let containerAspect = containerWidth / containerHeight

        var width: CGFloat
        var height: CGFloat

        if imageAspectRatio > containerAspect {
            width = containerWidth
            height = containerWidth / imageAspectRatio
        } else {
            height = containerHeight
            width = containerHeight * imageAspectRatio
        }

        return CGSize(width: width, height: height)
    }

    private func initializeWithRect(_ imageRect: CGRect) {
        guard !isInitialized else { return }
        displayedImageRect = imageRect
        initializeCropRect()
        isInitialized = true
    }

    private func updateForNewRect(_ imageRect: CGRect) {
        let normalizedCrop = cropRect
        displayedImageRect = imageRect
        if normalizedCrop.width > 0, normalizedCrop.height > 0 {
            cropOrigin = CGPoint(
                x: imageRect.minX + normalizedCrop.origin.x * imageRect.width,
                y: imageRect.minY + normalizedCrop.origin.y * imageRect.height
            )
            cropSize = CGSize(
                width: normalizedCrop.width * imageRect.width,
                height: normalizedCrop.height * imageRect.height
            )
        } else {
            initializeCropRect()
        }
    }

    private func initializeCropRect() {
        let maxWidth = displayedImageRect.width
        let maxHeight = displayedImageRect.height

        var width: CGFloat
        var height: CGFloat

        if let aspectRatio {
            if maxWidth / aspectRatio <= maxHeight {
                width = maxWidth
                height = maxWidth / aspectRatio
            } else {
                height = maxHeight
                width = maxHeight * aspectRatio
            }
        } else {
            width = maxWidth
            height = maxHeight
        }

        cropSize = CGSize(width: width, height: height)
        cropOrigin = CGPoint(
            x: displayedImageRect.midX - width / 2,
            y: displayedImageRect.midY - height / 2
        )

        updateCropRect()
    }

    private func handleDrag(_ translation: CGSize, isDragEnded: Bool) {
        if !isDragging {
            isDragging = true
            dragStartOrigin = cropOrigin
        }

        var newX = dragStartOrigin.x + translation.width
        var newY = dragStartOrigin.y + translation.height

        newX = max(displayedImageRect.minX, min(newX, displayedImageRect.maxX - cropSize.width))
        newY = max(displayedImageRect.minY, min(newY, displayedImageRect.maxY - cropSize.height))

        cropOrigin = CGPoint(x: newX, y: newY)

        if isDragEnded {
            isDragging = false
            updateCropRect()
        }
    }

    private func handleResizeDrag(_ handle: ResizeHandle, translation: CGSize, isDragEnded: Bool) {
        if activeHandle == nil {
            activeHandle = handle
            initialCropRect = CGRect(origin: cropOrigin, size: cropSize)
        }

        var newRect = initialCropRect

        if let aspectRatio {
            switch handle {
            case .topLeft:
                newRect.origin.x += translation.width
                newRect.origin.y += translation.height
                newRect.size.width -= translation.width
                newRect.size.height = newRect.size.width / aspectRatio
            case .topRight:
                newRect.size.width += translation.width
                newRect.size.height = newRect.size.width / aspectRatio
                newRect.origin.y = initialCropRect.maxY - newRect.size.height
            case .bottomLeft:
                newRect.origin.x += translation.width
                newRect.size.width -= translation.width
                newRect.size.height = newRect.size.width / aspectRatio
            case .bottomRight:
                newRect.size.width += translation.width
                newRect.size.height = newRect.size.width / aspectRatio
            case .top, .bottom:
                newRect.size.height += (handle == .bottom ? translation.height : -translation.height)
                newRect.size.width = newRect.size.height * aspectRatio
                if handle == .top {
                    newRect.origin.y += translation.height
                }
                newRect.origin.x = initialCropRect.midX - newRect.size.width / 2
            case .left, .right:
                newRect.size.width += (handle == .right ? translation.width : -translation.width)
                newRect.size.height = newRect.size.width / aspectRatio
                if handle == .left {
                    newRect.origin.x += translation.width
                }
                newRect.origin.y = initialCropRect.midY - newRect.size.height / 2
            }
        } else {
            switch handle {
            case .topLeft:
                newRect.origin.x += translation.width
                newRect.origin.y += translation.height
                newRect.size.width -= translation.width
                newRect.size.height -= translation.height
            case .topRight:
                newRect.origin.y += translation.height
                newRect.size.width += translation.width
                newRect.size.height -= translation.height
            case .bottomLeft:
                newRect.origin.x += translation.width
                newRect.size.width -= translation.width
                newRect.size.height += translation.height
            case .bottomRight:
                newRect.size.width += translation.width
                newRect.size.height += translation.height
            case .top:
                newRect.origin.y += translation.height
                newRect.size.height -= translation.height
            case .bottom:
                newRect.size.height += translation.height
            case .left:
                newRect.origin.x += translation.width
                newRect.size.width -= translation.width
            case .right:
                newRect.size.width += translation.width
            }
        }

        if newRect.width >= minCropSize, newRect.height >= minCropSize {
            if newRect.minX >= displayedImageRect.minX,
               newRect.minY >= displayedImageRect.minY,
               newRect.maxX <= displayedImageRect.maxX,
               newRect.maxY <= displayedImageRect.maxY
            {
                cropOrigin = newRect.origin
                cropSize = newRect.size
            }
        }

        if isDragEnded {
            activeHandle = nil
            updateCropRect()
        }
    }

    private func updateCropRect() {
        let normalizedX = (cropOrigin.x - displayedImageRect.minX) / displayedImageRect.width
        let normalizedY = (cropOrigin.y - displayedImageRect.minY) / displayedImageRect.height
        let normalizedWidth = cropSize.width / displayedImageRect.width
        let normalizedHeight = cropSize.height / displayedImageRect.height

        cropRect = CGRect(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY)),
            width: max(0, min(1, normalizedWidth)),
            height: max(0, min(1, normalizedHeight))
        )
    }
}

struct CropOverlayView: View {
    let displayedImageRect: CGRect
    let cropOrigin: CGPoint
    let cropSize: CGSize

    var body: some View {
        Canvas { context, size in
            var overlayPath = Path()
            overlayPath.addRect(CGRect(origin: .zero, size: size))

            let cropRect = CGRect(origin: cropOrigin, size: cropSize)
            overlayPath.addRect(cropRect)

            context.fill(overlayPath, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }
}

struct CropHandlesView: View {
    let cropOrigin: CGPoint
    let cropSize: CGSize
    let handleSize: CGFloat
    let onDrag: (CGSize, Bool) -> Void
    let onHandleDrag: (NativeCropperView.ResizeHandle, CGSize, Bool) -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: cropSize.width, height: cropSize.height)
                .contentShape(Rectangle())
                .position(x: cropOrigin.x + cropSize.width / 2, y: cropOrigin.y + cropSize.height / 2)
                #if os(macOS)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.openHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                #endif
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            #if os(macOS)
                            NSCursor.closedHand.set()
                            #endif
                            onDrag(value.translation, false)
                        }
                        .onEnded { value in
                            #if os(macOS)
                            NSCursor.openHand.set()
                            #endif
                            onDrag(value.translation, true)
                        }
                )

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropSize.width, height: cropSize.height)
                .position(x: cropOrigin.x + cropSize.width / 2, y: cropOrigin.y + cropSize.height / 2)
                .allowsHitTesting(false)

            GridLinesView(cropOrigin: cropOrigin, cropSize: cropSize)

            ForEach(cornerHandles, id: \.0) { handle, position in
                HandleView(handleSize: handleSize, handleType: handle)
                    .position(position)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                onHandleDrag(handle, value.translation, false)
                            }
                            .onEnded { value in
                                onHandleDrag(handle, value.translation, true)
                            }
                    )
            }
        }
    }

    private var cornerHandles: [(NativeCropperView.ResizeHandle, CGPoint)] {
        [
            (.topLeft, CGPoint(x: cropOrigin.x, y: cropOrigin.y)),
            (.topRight, CGPoint(x: cropOrigin.x + cropSize.width, y: cropOrigin.y)),
            (.bottomLeft, CGPoint(x: cropOrigin.x, y: cropOrigin.y + cropSize.height)),
            (.bottomRight, CGPoint(x: cropOrigin.x + cropSize.width, y: cropOrigin.y + cropSize.height)),
        ]
    }
}

struct HandleView: View {
    let handleSize: CGFloat
    let handleType: NativeCropperView.ResizeHandle

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: handleSize + 16, height: handleSize + 16)
            Circle()
                .fill(Color.white)
                .frame(width: handleSize, height: handleSize)
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(width: handleSize, height: handleSize)
        }
        .contentShape(Circle())
        #if os(macOS)
        .onHover { isHovering in
            if isHovering {
                resizeCursor(for: handleType).push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
    }

    #if os(macOS)
    private func resizeCursor(for handle: NativeCropperView.ResizeHandle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthWestSouthEastCursor"))?
                .takeUnretainedValue() as? NSCursor
            {
                return cursor
            }
            return NSCursor.crosshair
        case .topRight, .bottomLeft:
            if let cursor = NSCursor.perform(NSSelectorFromString("_windowResizeNorthEastSouthWestCursor"))?
                .takeUnretainedValue() as? NSCursor
            {
                return cursor
            }
            return NSCursor.crosshair
        case .top, .bottom:
            return NSCursor.resizeUpDown
        case .left, .right:
            return NSCursor.resizeLeftRight
        }
    }
    #endif
}

struct GridLinesView: View {
    let cropOrigin: CGPoint
    let cropSize: CGSize

    var body: some View {
        Canvas { context, _ in
            let lineColor = Color.white.opacity(0.5)

            for i in 1 ... 2 {
                let x = cropOrigin.x + cropSize.width * CGFloat(i) / 3
                var path = Path()
                path.move(to: CGPoint(x: x, y: cropOrigin.y))
                path.addLine(to: CGPoint(x: x, y: cropOrigin.y + cropSize.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }

            for i in 1 ... 2 {
                let y = cropOrigin.y + cropSize.height * CGFloat(i) / 3
                var path = Path()
                path.move(to: CGPoint(x: cropOrigin.x, y: y))
                path.addLine(to: CGPoint(x: cropOrigin.x + cropSize.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

#if os(macOS)
private func cropImageFromRect(_ image: NSImage, normalizedRect: CGRect) -> NSImage? {
    guard let tiffData = image.tiffRepresentation,
          let sourceImageRep = NSBitmapImageRep(data: tiffData),
          let cgImage = sourceImageRep.cgImage
    else {
        return nil
    }

    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)

    let cropRect = CGRect(
        x: normalizedRect.origin.x * imageWidth,
        y: normalizedRect.origin.y * imageHeight,
        width: normalizedRect.width * imageWidth,
        height: normalizedRect.height * imageHeight
    )

    guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
        return nil
    }

    return NSImage(
        cgImage: croppedCGImage,
        size: NSSize(width: cropRect.width, height: cropRect.height)
    )
}
#else
private func cropImageFromRect(_ image: UIImage, normalizedRect: CGRect) -> UIImage? {
    guard let cgImage = image.cgImage else {
        return nil
    }

    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)

    let cropRect = CGRect(
        x: normalizedRect.origin.x * imageWidth,
        y: normalizedRect.origin.y * imageHeight,
        width: normalizedRect.width * imageWidth,
        height: normalizedRect.height * imageHeight
    )

    guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
        return nil
    }

    return UIImage(
        cgImage: croppedCGImage,
        scale: image.scale,
        orientation: image.imageOrientation
    )
}
#endif

func cropImage(
    _ image: PlatformImage,
    normalizedRect: CGRect
) -> PlatformImage? {
    cropImageFromRect(image, normalizedRect: normalizedRect)
}

struct ImageCropAdapter: View {
    var image: PlatformImage
    var cropDimensions: String
    var flexibleDimensions = false
    var sessionId = UUID()

    @State private var cropRect: CGRect = .zero
    @State private var internalId = UUID()

    var onCropConfirm: (PlatformImage) -> Void
    var onCropCancel: () -> Void

    private var aspectRatio: CGFloat? {
        guard !flexibleDimensions else { return nil }
        let ratio = getAspectRatio(dimension: cropDimensions)
        // Handle empty or invalid dimensions by treating as flexible crop
        guard ratio.width > 0, ratio.height > 0 else { return nil }
        return CGFloat(ratio.width) / CGFloat(ratio.height)
    }

    var body: some View {
        VStack(spacing: 16) {
            NativeCropperView(
                image: image.toImage(),
                platformImage: image,
                aspectRatio: aspectRatio,
                cropRect: $cropRect
            )
            .id(internalId)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Spacer()
                Button("Cancel") {
                    onCropCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Crop") {
                    if cropRect.width > 0, cropRect.height > 0,
                       let croppedImage = cropImage(image, normalizedRect: cropRect)
                    {
                        onCropConfirm(croppedImage)
                    } else {
                        onCropCancel()
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 550)
        .padding(.all, 24)
        #else
        .padding(.all, 12)
        .presentationDetents([.large])
        #endif
        .onChange(of: sessionId) { _, _ in
            internalId = UUID()
            cropRect = .zero
        }
        .onAppear {
            internalId = UUID()
            cropRect = .zero
        }
    }
}
