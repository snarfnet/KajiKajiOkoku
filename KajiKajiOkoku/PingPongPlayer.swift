import AVFoundation

// ピンポンループ: rabbit.mp4 を 4x 正再生 → rabbit_rev.mp4 を 1x 逆再生 → 繰り返し
class PingPongPlayer: ObservableObject {
    let player: AVQueuePlayer
    private var endObserver: Any?
    private var itemObserver: NSKeyValueObservation?

    init() {
        player = AVQueuePlayer()
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        enqueue(forward: true)
        enqueue(forward: false)
        setupObservers()
    }

    private func isForward(_ item: AVPlayerItem) -> Bool {
        guard let url = (item.asset as? AVURLAsset)?.url else { return true }
        return url.lastPathComponent == "rabbit.mp4"
    }

    private func enqueue(forward: Bool) {
        let name = forward ? "rabbit" : "rabbit_rev"
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        player.insert(AVPlayerItem(url: url), after: nil)
    }

    private func setupObservers() {
        // アイテムが切り替わったら速度を調整（正再生: 4x、逆再生: 1x）
        itemObserver = player.observe(\.currentItem, options: [.new]) { [weak self] p, _ in
            guard let self, let _ = p.currentItem else { return }
            DispatchQueue.main.async {
                guard p.status == .readyToPlay else { return }
                p.rate = 4.0
            }
        }

        // 再生終了時に次のアイテムを追加してキューを維持
        // 例: rabbit(fwd)が終わる → 次はrabbit_rev → その次はrabbit(fwd) → 同種を追加
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let ended = notification.object as? AVPlayerItem else { return }
            self.enqueue(forward: self.isForward(ended))
        }
    }

    func play() {
        if player.status == .readyToPlay {
            player.rate = 4.0
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.player.rate = 4.0
            }
        }
    }

    deinit {
        itemObserver?.invalidate()
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
    }
}
