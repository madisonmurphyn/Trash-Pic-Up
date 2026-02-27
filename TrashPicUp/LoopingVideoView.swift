import SwiftUI
import AVKit
import AVFoundation

/// Looping video player using AVPlayerLooper. Muted, fills available space.
struct LoopingVideoView: View {
    let resourceName: String
    let fileExtension: String
    var fillScreen: Bool = false

    init(resourceName: String = "loading screen 2.0", fileExtension: String = "mov", fillScreen: Bool = false) {
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.fillScreen = fillScreen
    }

    var body: some View {
        #if os(iOS)
        LoopingVideoUIView(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
        #else
        LoopingVideoNSView(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
        #endif
    }
}

#if os(iOS)
private struct LoopingVideoUIView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String
    var fillScreen: Bool

    func makeUIView(context: Context) -> UIView {
        let view = LoopingVideoPlayerView(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class LoopingVideoPlayerView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    init(resourceName: String, fileExtension: String, fillScreen: Bool = false) {
        super.init(frame: .zero)
        setupPlayer(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupPlayer(resourceName: String, fileExtension: String, fillScreen: Bool = false) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else { return }
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        player.play()

        let looper = AVPlayerLooper(player: player, templateItem: playerItem)

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = fillScreen ? .resizeAspectFill : .resizeAspect
        layer.contentsScale = UIScreen.main.scale

        queuePlayer = player
        playerLooper = looper
        playerLayer = layer
        layer.frame = bounds
        self.layer.addSublayer(layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
#else
private struct LoopingVideoNSView: NSViewRepresentable {
    let resourceName: String
    let fileExtension: String
    var fillScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = LoopingVideoPlayerNSView(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class LoopingVideoPlayerNSView: NSView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    init(resourceName: String, fileExtension: String, fillScreen: Bool = false) {
        super.init(frame: .zero)
        wantsLayer = true
        setupPlayer(resourceName: resourceName, fileExtension: fileExtension, fillScreen: fillScreen)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupPlayer(resourceName: String, fileExtension: String, fillScreen: Bool = false) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else { return }
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        player.play()

        let looper = AVPlayerLooper(player: player, templateItem: playerItem)

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = fillScreen ? .resizeAspectFill : .resizeAspect
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2

        queuePlayer = player
        playerLooper = looper
        playerLayer = layer
        layer.frame = bounds
        self.layer?.addSublayer(layer)
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}
#endif
