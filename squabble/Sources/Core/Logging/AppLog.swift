import FirebaseCrashlytics
import OSLog

/// Single entry point for diagnostics. Features log here and never import Firebase directly,
/// so the crash/analytics backend can change without touching feature code.
nonisolated enum AppLog {
    private static let logger = Logger(subsystem: "com.palkesz.squabble", category: "app")

    /// Records a handled error as a Crashlytics non-fatal and mirrors it to the console.
    static func error(_ error: Error, _ context: String? = nil) {
        if let context {
            logger.error("\(context, privacy: .public): \(error)")
            Crashlytics.crashlytics().log(context)
        } else {
            logger.error("\(error)")
        }
        Crashlytics.crashlytics().record(error: error)
    }

    /// Breadcrumb that shows up in the next crash report's log.
    static func breadcrumb(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        Crashlytics.crashlytics().log(message)
    }
}
