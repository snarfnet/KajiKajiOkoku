import SwiftUI
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    class PlayerView: UIView {
        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let shift: CGFloat = 150
            playerLayer.frame = CGRect(x: -shift, y: 0, width: bounds.width + shift, height: bounds.height)
            CATransaction.commit()
        }
    }
}
