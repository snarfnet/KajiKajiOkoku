import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.rootViewController == nil,
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.keyWindow?.rootViewController {
            uiView.rootViewController = root
            uiView.load(GADRequest())
        }
    }
}
