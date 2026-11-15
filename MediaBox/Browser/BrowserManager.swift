import Foundation
import WebKit
import Combine

struct DetectedFile: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let destination: DownloadDestination
}

final class BrowserNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var manager: BrowserManager?
    var allowOnce = Set<URL>()   // accédé uniquement depuis le thread principal

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload, let url = navigationAction.request.url {
            decisionHandler(.cancel)
            DispatchQueue.main.async { self.manager?.detected(url: url, suggested: nil) }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let mime = (navigationResponse.response.mimeType ?? "").lowercased()
        let url = navigationResponse.response.url
        let ext = url?.pathExtension.lowercased() ?? ""
        let isMedia = mime.hasPrefix("audio/") || mime.hasPrefix("video/")
            || (mime == "application/octet-stream" && (SourceResolver.audioExt.contains(ext) || SourceResolver.videoExt.contains(ext)))
        if navigationResponse.isForMainFrame, isMedia || !navigationResponse.canShowMIMEType, let u = url {
            if allowOnce.remove(u) == nil {
                decisionHandler(.cancel)
                let sug = navigationResponse.response.suggestedFilename
                DispatchQueue.main.async { self.manager?.detected(url: u, suggested: sug) }
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { self.manager?.didFinish() }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}

@MainActor
final class BrowserManager: ObservableObject {
    @Published private(set) var webView: WKWebView?
    @Published var addressText = ""
    @Published private(set) var title = ""
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentService: MediaService?
    @Published var pendingDownload: DetectedFile?

    let history: BrowserHistory
    private let navDelegate = BrowserNavigationDelegate()
    private var observers: [NSKeyValueObservation] = []
    private var lastURL: URL?
    private var discardTask: Task<Void, Never>?
    private let eco = EcoCore.shared

    init(history: BrowserHistory) {
        self.history = history
        navDelegate.manager = self
    }

    private func makeWebView() -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = true
        cfg.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = navDelegate
        wv.uiDelegate = navDelegate
        wv.allowsBackForwardNavigationGestures = true
        observers = [
            wv.observe(\.estimatedProgress, options: [.new]) { [weak self] w, _ in
                let p = w.estimatedProgress
                Task { @MainActor in self?.progress = p }
            },
            wv.observe(\.canGoBack, options: [.new]) { [weak self] w, _ in
                let v = w.canGoBack
                Task { @MainActor in self?.canGoBack = v }
            },
            wv.observe(\.canGoForward, options: [.new]) { [weak self] w, _ in
                let v = w.canGoForward
                Task { @MainActor in self?.canGoForward = v }
            },
            wv.observe(\.isLoading, options: [.new]) { [weak self] w, _ in
                let v = w.isLoading
                Task { @MainActor in self?.isLoading = v }
            }
        ]
        return wv
    }

    // MARK: Cycle de vie
    func pageShown() {
        discardTask?.cancel()
        eco.setBrowserActive(true)
        if webView == nil {
            let wv = makeWebView()
            webView = wv
            let target = lastURL ?? URL(string: "https://duckduckgo.com")!
            wv.load(URLRequest(url: target))
        }
    }

    /// Quand l'onglet est quitté : libération différée du WKWebView (sauf si un média web est en lecture).
    func pageHidden() {
        eco.setBrowserActive(false)
        discardTask?.cancel()
        let delay: UInt64 = eco.profile == .normal ? 120 : 10
        discardTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.discardIfIdle()
        }
    }

    private func discardIfIdle() {
        guard let wv = webView else { return }
        wv.requestMediaPlaybackState { [weak self] state in
            Task { @MainActor in
                if state == .playing { self?.pageHidden() } else { self?.discard() }
            }
        }
    }

    func discard() {
        guard let wv = webView else { return }
        lastURL = wv.url ?? lastURL
        observers.removeAll()
        wv.stopLoading()
        wv.navigationDelegate = nil
        wv.uiDelegate = nil
        webView = nil
        canGoBack = false; canGoForward = false; isLoading = false; progress = 0
        MemoryManager.shared.sample()
    }

    // MARK: Navigation
    func go(_ input: String) {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var target: URL?
        if let u = URL(string: t), let s = u.scheme?.lowercased(), s == "http" || s == "https" { target = u }
        else if t.contains(".") && !t.contains(" "), let u = URL(string: "https://" + t) { target = u }
        else if let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { target = URL(string: "https://duckduckgo.com/?q=" + q) }
        guard let url = target else { return }
        open(url)
    }

    func open(_ url: URL) {
        lastURL = url
        if let wv = webView { wv.load(URLRequest(url: url)) } else { pageShown() }
    }
    func back() { webView?.goBack() }
    func forward() { webView?.goForward() }
    func reload() { isLoading ? webView?.stopLoading() : webView?.reload() }

    func didFinish() {
        guard let wv = webView else { return }
        title = wv.title ?? ""
        if let u = wv.url {
            addressText = u.absoluteString
            currentService = ServiceRouter.service(for: u)
            history.add(url: u.absoluteString, title: title)
        }
        MemoryManager.shared.checkBudget(reason: "page web")
    }

    // MARK: Détection de fichiers
    func detected(url: URL, suggested: String?) {
        if ServiceRouter.service(for: url) != nil { return }
        let kind = SourceResolver.classify(url)
        var name = SourceResolver.suggestedFileName(for: url)
        if (name as NSString).pathExtension.isEmpty, let s = suggested { name = FileManagerService.sanitize(s) }
        pendingDownload = DetectedFile(url: url, filename: name, destination: SourceResolver.destination(for: kind))
    }

    func ignoreDetected() {
        if let p = pendingDownload { navDelegate.allowOnce.insert(p.url); webView?.load(URLRequest(url: p.url)) }
        pendingDownload = nil
    }

    /// Copie les cookies de la session de l'utilisateur pour l'hôte concerné (fichiers derrière une connexion légitime).
    func copyCookies(for url: URL) async {
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore, let host = url.host else { return }
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in store.getAllCookies { cont.resume(returning: $0) } }
        for c in cookies where host.hasSuffix(c.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) {
            HTTPCookieStorage.shared.setCookie(c)
        }
    }
}
