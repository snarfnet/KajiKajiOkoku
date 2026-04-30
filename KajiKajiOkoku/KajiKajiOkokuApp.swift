import SwiftUI
import GoogleMobileAds

@main
struct KajiKajiOkokuApp: App {
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
