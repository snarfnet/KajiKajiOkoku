import SwiftUI
import PhotosUI

private let topAdUnitID    = "ca-app-pub-9404799280370656/3533135642"
private let bottomAdUnitID = "ca-app-pub-9404799280370656/3002652602"
private let mouthYRatio: CGFloat = 0.45

struct KajiItem: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let fontSize: CGFloat
    let chars: [String]
    var opacity: Double = 0
}

struct ContentView: View {
    @StateObject private var pingPong = PingPongPlayer()
    @State private var lastFood: UIImage?
    @State private var foodImage: UIImage?
    @State private var foodOffset: CGSize = .zero
    @State private var foodScale: CGFloat = 1.0
    @State private var foodOpacity: Double = 1.0
    @State private var foodRotation: Double = 0
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var isLooping = false
    @State private var feedTask: Task<Void, Never>?   // 1回 or ループどちらも管理
    @State private var videoSize: CGSize = .zero
    @State private var kajiItems: [KajiItem] = []

    var body: some View {
        VStack(spacing: 0) {
            AdBannerView(adUnitID: topAdUnitID).frame(height: 50)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    VideoPlayerView(player: pingPong.player)
                        .frame(width: geo.size.width, height: geo.size.height)

                    if let img = foodImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .scaleEffect(foodScale)
                            .rotationEffect(.degrees(foodRotation))
                            .opacity(foodOpacity)
                            .position(x: foodOffset.width, y: foodOffset.height)
                    }

                    // カジカジ縦文字オーバーレイ
                    ForEach(kajiItems) { item in
                        VStack(spacing: 0) {
                            ForEach(Array(item.chars.enumerated()), id: \.offset) { _, ch in
                                Text(ch)
                                    .font(.custom("HiraMinProN-W3", size: item.fontSize))
                                    .foregroundColor(.black)
                            }
                        }
                        .opacity(item.opacity)
                        .position(x: item.x, y: item.y)
                        .allowsHitTesting(false)
                    }

                    if isProcessing {
                        ProgressView("背景を消去中...")
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("🥕 餌をあげる")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                        }
                        .onChange(of: selectedPhoto) { _, item in pickPhoto(item) }

                        Button { toggleLoop() } label: {
                            Text(isLooping ? "⏹ ストップ" : "🔁 ループ")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isLooping ? .white : .black)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(isLooping ? Color.red : Color.white)
                                .clipShape(Capsule())
                                .shadow(radius: 4)
                        }
                        .disabled(lastFood == nil && !isLooping)
                        .opacity((lastFood == nil && !isLooping) ? 0.4 : 1.0)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 20)
                }
                .onAppear { videoSize = geo.size }
            }

            AdBannerView(adUnitID: bottomAdUnitID).frame(height: 50)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { pingPong.play() }
        .onDisappear { cancelFeed() }
    }

    // MARK: - 写真ロード

    private func pickPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessing = true
        cancelFeed()
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img  = UIImage(data: data) {
                let result = await BackgroundRemover.removeBackground(from: img)
                let food = result ?? img
                lastFood = food
                startFeed(food, loop: false)
            }
            isProcessing = false
        }
    }

    // MARK: - ループ切り替え

    private func toggleLoop() {
        if isLooping {
            cancelFeed()
        } else {
            guard let food = lastFood else { return }
            isLooping = true
            startFeed(food, loop: true)
        }
    }

    private func cancelFeed() {
        feedTask?.cancel()
        feedTask = nil
        isLooping = false
        kajiItems = []
    }

    // MARK: - アニメーション起動

    private func startFeed(_ img: UIImage, loop: Bool) {
        feedTask?.cancel()
        feedTask = Task { @MainActor in
            repeat {
                await animate(img, fast: loop)
                if loop { try? await Task.sleep(nanoseconds: 50_000_000) }
            } while loop && !Task.isCancelled
            isLooping = false
        }
    }

    // MARK: - 吸い込みアニメーション（1サイクル）

    @MainActor
    private func animate(_ img: UIImage, fast: Bool = false) async {
        let w = videoSize.width
        let h = videoSize.height
        let cx = w / 2
        let startCY = h * 0.78
        let mouthCY = h * mouthYRatio

        let showNs: UInt64  = fast ? 200_000_000 : 800_000_000   // 表示時間
        let animSec: Double = fast ? 0.4          : 1.5           // 吸い込み時間
        let animNs: UInt64  = fast ? 400_000_000  : 1_500_000_000

        // 初期表示
        foodImage    = img
        foodOffset   = CGSize(width: cx, height: startCY)
        foodScale    = 1.0
        foodOpacity  = 1.0
        foodRotation = 0

        do { try await Task.sleep(nanoseconds: showNs) } catch { return }

        // 吸い込み開始: 振動（中）＋カジカジ文字出現
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showKajiTexts(in: CGSize(width: w, height: h))

        // 吸い込みアニメーション
        withAnimation(.easeIn(duration: animSec)) {
            foodOffset   = CGSize(width: cx, height: mouthCY)
            foodScale    = 0.05
            foodOpacity  = 0.0
            foodRotation = fast ? 720 : 180
        }
        do { try await Task.sleep(nanoseconds: animNs) } catch {
            resetFood(); return
        }

        // 食べ終わり: 振動（強）
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        hideKajiTexts(duration: 0.4)
        resetFood()
    }

    // MARK: - カジカジ文字エフェクト

    @MainActor
    private func showKajiTexts(in size: CGSize) {
        let syllables = ["カ", "ジ"]
        let colCount = Int.random(in: 3...6)
        kajiItems = (0..<colCount).map { _ in
            let charCount = Int.random(in: 3...8)
            let chars = (0..<charCount).map { syllables[$0 % 2] }
            let fontSize = CGFloat.random(in: 18...58)
            let margin: CGFloat = 30
            let x = CGFloat.random(in: margin...(size.width - margin))
            let colHeight = CGFloat(charCount) * (fontSize + 2)
            let y = CGFloat.random(in: 60...(max(80, size.height * 0.72 - colHeight / 2)))
            return KajiItem(x: x, y: y + colHeight / 2, fontSize: fontSize, chars: chars, opacity: 0)
        }
        withAnimation(.easeIn(duration: 0.15)) {
            for i in kajiItems.indices {
                kajiItems[i].opacity = Double.random(in: 0.75...1.0)
            }
        }
    }

    @MainActor
    private func hideKajiTexts(duration: Double) {
        withAnimation(.easeOut(duration: duration)) {
            for i in kajiItems.indices { kajiItems[i].opacity = 0 }
        }
    }

    private func resetFood() {
        foodImage    = nil
        foodScale    = 1.0
        foodOpacity  = 1.0
        foodRotation = 0
        foodOffset   = .zero
        kajiItems    = []
    }
}
