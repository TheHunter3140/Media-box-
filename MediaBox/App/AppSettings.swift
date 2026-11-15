import Foundation
import UIKit
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "s.haptics") } }
    @Published var transparency: Bool { didSet { d.set(transparency, forKey: "s.transparency") } }
    /// system = suit iOS, light = clair, dark = sombre.
    @Published var appearanceMode: String { didSet { d.set(appearanceMode, forKey: "s.appearanceMode") } }
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode { case "light": return .light; case "dark": return .dark; default: return nil }
    }
    @Published var animations: Bool { didSet { d.set(animations, forKey: "s.animations") } }
    @Published var maxDownloads: Int { didSet { d.set(maxDownloads, forKey: "s.maxDownloads") } }
    @Published var fadeSeconds: Double { didSet { d.set(fadeSeconds, forKey: "s.fade") } }
    @Published var restoreSession: Bool { didSet { d.set(restoreSession, forKey: "s.restore") } }
    @Published var autoResume: Bool { didSet { d.set(autoResume, forKey: "s.autoResume") } }
    @Published var wifiOnlyDownloads: Bool { didSet { d.set(wifiOnlyDownloads, forKey: "s.wifiOnly") } }

    init() {
        let d = UserDefaults.standard
        haptics = d.object(forKey: "s.haptics") as? Bool ?? true
        transparency = d.object(forKey: "s.transparency") as? Bool ?? true
        appearanceMode = d.string(forKey: "s.appearanceMode") ?? "system"
        animations = d.object(forKey: "s.animations") as? Bool ?? true
        maxDownloads = d.object(forKey: "s.maxDownloads") as? Int ?? 2
        fadeSeconds = d.object(forKey: "s.fade") as? Double ?? 0
        restoreSession = d.object(forKey: "s.restore") as? Bool ?? true
        autoResume = d.object(forKey: "s.autoResume") as? Bool ?? true
        wifiOnlyDownloads = d.object(forKey: "s.wifiOnly") as? Bool ?? false
    }

    func tap() {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
