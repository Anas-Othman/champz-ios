import Core
import CoreText
import Foundation
import UIKit

/// Registers the bundled fonts with Core Text at launch. Fonts in a Swift package
/// cannot be listed in the app's Info.plist, so the app calls `registerAll()` once.
public enum FontRegistrar {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var registered: Set<String> = []

    public static func registerAll() {
        let urls = (Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])
            + (Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
        for url in urls {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                Log.app.debug("Registered font \(url.lastPathComponent, privacy: .public)")
            } else if let error = error?.takeRetainedValue(),
                      CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue
            {
                let detail = "\(url.lastPathComponent): \(String(describing: error))"
                Log.app.error("Font registration failed — \(detail, privacy: .public)")
            }
        }
    }

    /// Whether a PostScript name resolves to a real font. Cached; falls back to system fonts when false.
    static func isAvailable(_ postScriptName: String) -> Bool {
        if lock.withLock({ registered.contains(postScriptName) }) {
            return true
        }
        let available = UIFont(name: postScriptName, size: 12) != nil
        if available {
            lock.withLock { _ = registered.insert(postScriptName) }
        }
        return available
    }
}
