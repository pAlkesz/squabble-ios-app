#if DEBUG && targetEnvironment(simulator)
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation

/// Runs the app against the Firebase emulators on this Mac (docs/specs/testing.md). Debug
/// simulator builds only. The options are made up and the project doesn't exist online, so
/// nothing can reach the live one, and its sign-in and cache stay separate from live's.
enum LocalEmulator {
    private static let defaultsKey = "useLocalEmulator"
    private static let host = "127.0.0.1"

    /// Also settable from outside: `simctl launch <device> com.palkesz.squabble -useLocalEmulator YES`.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Firebase can only be configured once per launch, so switching quits the app.
    static func setEnabled(_ isEnabled: Bool) -> Never {
        UserDefaults.standard.set(isEnabled, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        exit(0)
    }

    static func configure() {
        let options = FirebaseOptions(googleAppID: "1:123456789012:ios:abcdef0123456789abcdef", gcmSenderID: "123456789012")
        options.projectID = "demo-squabble"
        options.storageBucket = "demo-squabble.firebasestorage.app"
        // The right shape for an API key, but not one.
        options.apiKey = "A" + String(repeating: "x", count: 38)
        FirebaseApp.configure(options: options)
        Analytics.setAnalyticsCollectionEnabled(false)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        Auth.auth().useEmulator(withHost: host, port: 9099)
        // Not `useEmulator`: it leaves TLS on, which the emulator doesn't speak.
        let settings = Firestore.firestore().settings
        settings.host = "\(host):8080"
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings
        Functions.functions().useEmulator(withHost: host, port: 5001)
        Storage.storage().useEmulator(withHost: host, port: 9199)
    }
}
#endif
