#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

#if os(iOS)
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    var cgImageForAnalysis: CGImage? {
        return cgImage
    }
}
#elseif os(macOS)
extension NSImage {
    func resized(to size: CGSize) -> NSImage? {
        let nsSize = NSSize(width: size.width, height: size.height)
        let newImage = NSImage(size: nsSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: nsSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    var cgImageForAnalysis: CGImage? {
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif
