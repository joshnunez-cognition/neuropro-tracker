import RealityKit
import SwiftUI

/// The interactive human body. Drag to rotate, pinch to zoom, tap to select.
struct BodyViewer: View {
    let controller: BodyInteractionController
    var onTap: (BodyTapResult) -> Void
    var onReady: () -> Void = {}

    @State private var isDragging = false
    @State private var isPinching = false

    var body: some View {
        GeometryReader { geometry in
            RealityView { content in
                await controller.attach(to: content)
                onReady()
            } update: { content in
                controller.refreshContent(content)
            }
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            controller.dragBegan()
                        }
                        controller.dragChanged(translation: value.translation, viewWidth: geometry.size.width)
                    }
                    .onEnded { value in
                        isDragging = false
                        controller.dragEnded(
                            predictedTranslation: value.predictedEndTranslation,
                            translation: value.translation,
                            viewWidth: geometry.size.width)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        if !isPinching {
                            isPinching = true
                            controller.pinchBegan()
                        }
                        controller.pinchChanged(magnification: value.magnification)
                    }
                    .onEnded { _ in isPinching = false }
            )
            .onTapGesture(coordinateSpace: .local) { location in
                onTap(controller.tap(at: location))
            }
            .accessibilityLabel("Interactive human body")
            .accessibilityHint("Swipe left or right to rotate. Double tap a highlighted area to choose it. Use Choose Area Manually for a list instead.")
        }
    }
}
