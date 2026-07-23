import SwiftUI
import WebKit

/// Embedded Acuity scheduler — fallback that always reflects the live Acuity
/// catalog (packages, gift certificates, anything not modeled natively yet).
struct AcuityWebView: UIViewRepresentable {
    var url: URL = AppConfig.acuitySchedulingURL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
