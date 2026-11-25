import SwiftUI
import WebKit

struct HtmlViewer: View {
    let payload: HtmlPayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebContainer(payload: payload)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(payload.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let payload: HtmlPayload

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .always
        web.load(payload.data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: payload.base)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// 从 zip 里取出的 HTML：没有目录，用自定义 scheme 保证相对资源不报错
struct HtmlDataContainer: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.load(data, mimeType: "text/html", characterEncodingName: "utf-8", baseURL: nil)
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
