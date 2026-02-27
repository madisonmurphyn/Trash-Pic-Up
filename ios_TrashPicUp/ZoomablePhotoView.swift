import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Native scroll-view zoom for Photos-app-like pinch/pan. iOS: UIScrollView. macOS: gesture-based.
struct ZoomablePhotoView: View {
    let image: PlatformImage

    var body: some View {
        #if os(iOS)
        ZoomablePhotoUIView(image: image)
        #else
        ZoomablePhotoSwiftUIView(image: image)
        #endif
    }
}

#if os(iOS)
private struct ZoomablePhotoUIView: UIViewRepresentable {
    let image: PlatformImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.zoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image as? UIImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        (context.coordinator.imageView as? UIImageView)?.image = image as? UIImage
        scrollView.zoomScale = 1.0
        scrollView.contentOffset = .zero
        context.coordinator.layoutScrollView(scrollView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            scrollView.zoomScale = 1.0
            context.coordinator.layoutScrollView(scrollView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(scrollView)
        }

        func layoutScrollView(_ scrollView: UIScrollView) {
            guard let imageView = imageView as? UIImageView, let img = imageView.image else { return }
            let scrollBounds = scrollView.bounds
            guard scrollBounds.width > 0, scrollBounds.height > 0 else { return }
            let imageSize = img.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let widthRatio = scrollBounds.width / imageSize.width
            let heightRatio = scrollBounds.height / imageSize.height
            let scale = min(widthRatio, heightRatio, 1.0)
            let fittedWidth = imageSize.width * scale
            let fittedHeight = imageSize.height * scale

            imageView.frame = CGRect(x: 0, y: 0, width: fittedWidth, height: fittedHeight)
            scrollView.contentSize = imageView.frame.size
            scrollView.zoomScale = 1.0
            centerContent(scrollView)
        }

        private func centerContent(_ scrollView: UIScrollView) {
            let scrollBounds = scrollView.bounds
            let contentSize = scrollView.contentSize
            let insetX = max(0, (scrollBounds.width - contentSize.width * scrollView.zoomScale) / 2)
            let insetY = max(0, (scrollBounds.height - contentSize.height * scrollView.zoomScale) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view?.superview as? UIScrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let location = gesture.location(in: gesture.view)
                let zoomScale: CGFloat = 2.5
                let w = (scrollView.bounds.width) / zoomScale
                let h = (scrollView.bounds.height) / zoomScale
                let x = location.x - (w / 2)
                let y = location.y - (h / 2)
                scrollView.zoom(to: CGRect(x: x, y: y, width: w, height: h), animated: true)
            }
        }
    }
}
#elseif os(macOS)
private struct ZoomablePhotoSwiftUIView: View {
    let image: PlatformImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(nsImage: image as! NSImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { scale = min(4, max(1.0, lastScale * $0)) }
                    .onEnded { _ in lastScale = scale }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width, height: lastOffset.height + $0.translation.height) }
                    .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
                if scale > 1.0 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }
}
#endif
