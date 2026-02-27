import SwiftUI
import QuartzCore
import UIKit

/// iMessage-style confetti using CAEmitterLayer. Full-screen falling confetti.
struct ConfettiView: View {
    var duration: TimeInterval = 2.5
    var onComplete: (() -> Void)?

    var body: some View {
        ConfettiEmitterRepresentable(duration: duration, onComplete: onComplete)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct ConfettiEmitterRepresentable: UIViewRepresentable {
    let duration: TimeInterval
    let onComplete: (() -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = ConfettiEmitterView()
        view.duration = duration
        view.onComplete = onComplete
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class ConfettiEmitterView: UIView {
    var duration: TimeInterval = 2.5
    var onComplete: (() -> Void)?

    private let emitterLayer = CAEmitterLayer()
    private let colors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (149/255, 58/255, 255/255),
        (255/255, 195/255, 41/255),
        (255/255, 101/255, 26/255),
        (123/255, 92/255, 255/255),
        (76/255, 126/255, 255/255),
        (71/255, 192/255, 255/255),
        (255/255, 47/255, 39/255),
        (255/255, 91/255, 134/255),
        (233/255, 122/255, 208/255),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard emitterLayer.superlayer == nil else {
            emitterLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 2)
            return
        }
        setupEmitter()
    }

    private func setupEmitter() {
        emitterLayer.masksToBounds = false
        emitterLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 2)
        emitterLayer.emitterPosition = CGPoint(x: bounds.midX, y: -30)
        emitterLayer.emitterSize = CGSize(width: bounds.width + 100, height: 1)
        emitterLayer.emitterShape = .line
        emitterLayer.emitterCells = createCells()
        layer.addSublayer(emitterLayer)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.emitterLayer.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.emitterLayer.removeFromSuperlayer()
            self?.onComplete?()
        }
    }

    private func createCells() -> [CAEmitterCell] {
        var cells: [CAEmitterCell] = []
        for color in colors {
            let rectCell = makeCell(color: color, shape: .rectangle)
            let circleCell = makeCell(color: color, shape: .circle)
            cells.append(rectCell)
            cells.append(circleCell)
        }
        return cells
    }

    private enum Shape { case rectangle, circle }

    private func makeCell(color: (r: CGFloat, g: CGFloat, b: CGFloat), shape: Shape) -> CAEmitterCell {
        let cell = CAEmitterCell()
        let uiColor = UIColor(red: color.r, green: color.g, blue: color.b, alpha: 1)
        cell.contents = createConfettiImage(color: uiColor, shape: shape)?.cgImage
        cell.birthRate = 12
        cell.lifetime = 12
        cell.velocity = 250
        cell.velocityRange = 100
        cell.emissionRange = 0
        cell.emissionLongitude = .pi
        cell.spin = 2
        cell.spinRange = 6
        cell.scale = 0.8
        cell.scaleRange = 0.4
        cell.yAcceleration = 400
        cell.alphaSpeed = -0.08
        return cell
    }

    private func createConfettiImage(color: UIColor, shape: Shape) -> UIImage? {
        let rect: CGRect = shape == .rectangle ? CGRect(x: 0, y: 0, width: 14, height: 10) : CGRect(x: 0, y: 0, width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(color.cgColor)
            switch shape {
            case .rectangle: ctx.cgContext.fill(rect)
            case .circle: ctx.cgContext.addEllipse(in: CGRect(origin: .zero, size: rect.size)); ctx.cgContext.drawPath(using: .fill)
            }
        }
    }
}
