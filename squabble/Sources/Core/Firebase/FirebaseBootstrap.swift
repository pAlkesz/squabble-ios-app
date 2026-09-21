import FirebaseCore
import OSLog

enum FirebaseBootstrap {
    private static let logger = Logger(subsystem: "com.palkesz.squabble", category: "firebase")
    private static var isConfigured = false

    /// Configures Firebase once at launch. `GoogleService-Info.plist` is gitignored, so a
    /// fresh clone without it must still run — `FirebaseApp.configure()` would otherwise
    /// raise on the missing file. (Not guarded via `FirebaseApp.app()`: that call logs a
    /// spurious "not yet configured" error when no app exists.)
    static func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            logger.warning("GoogleService-Info.plist missing; Firebase disabled for this build")
            return
        }
        FirebaseApp.configure()
    }
}
