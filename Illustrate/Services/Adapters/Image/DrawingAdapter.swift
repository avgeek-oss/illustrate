// MARK: - DrawingAdapter.swift

// Mask drawing component for inpainting operations.
//
// Provides a simple brush-based drawing interface for creating masks
// used in inpainting and erase operations. Users paint over areas they
// want to modify.
//
// ## Mask Format
// - Black background: Areas to preserve
// - White painted areas: Areas to modify
// - Exported as PNG for API submission

import OSLog
import SwiftUI

/// Drawing surface for creating inpainting masks.
struct MaskDrawingView: View {
    @Binding var path: Path
    var size: CGSize

    var body: some View {
        Canvas { context, _ in
            context.fill(path, with: .color(.black.opacity(0.64)))
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let newPoint = value.location
                    path.addEllipse(in: CGRect(x: newPoint.x - 18, y: newPoint.y - 18, width: 36, height: 36))
                }
        )
        .frame(width: size.width, height: size.height)
    }
}

#if os(macOS)
func exportPathToImage(path: Path, size: CGSize) -> NSImage? {
    let image = NSImage(size: size)

    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext

    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1.0, y: -1.0)

    NSColor.black.setFill()
    context.fill(CGRect(origin: .zero, size: size))

    NSColor.white.setFill()
    let bezierPath = NSBezierPath(cgPath: path.cgPath)
    bezierPath.fill()

    image.unlockFocus()

    return image
}
#else
func exportPathToImage(path: Path, size: CGSize) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
        let cgContext = context.cgContext

        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)

        UIColor.black.setFill()
        cgContext.fill(CGRect(origin: .zero, size: size))

        UIColor.white.setFill()

        let cgPath = path.cgPath
        cgContext.addPath(cgPath)
        cgContext.drawPath(using: .fill)
    }
}
#endif
