#if DEBUG
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation

/// Runs the app against the Firebase emulators on the developer's Mac (docs/specs/testing.md).
/// Debug builds only. The options are made up and the project doesn't exist online, so
/// nothing can reach the live one, and its sign-in and cache stay separate from live's.
enum LocalEmulator {
    private static let defaultsKey = "useLocalEmulator"
    private static let hostKey = "emulatorHost"

    /// The Mac's address. A simulator shares the Mac's network; a phone has to be told.
    static var host: String? {
        #if targetEnvironment(simulator)
        UserDefaults.standard.string(forKey: hostKey) ?? "127.0.0.1"
        #else
        UserDefaults.standard.string(forKey: hostKey)
        #endif
    }

    /// Takes effect on the next launch. Nil if this isn't a bare host name or IPv4 address.
    static func validHost(_ input: String) -> String? {
        let host = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.wholeMatch(of: /[A-Za-z0-9.-]+/) == nil ? nil : host
    }

    static func setHost(_ host: String) {
        UserDefaults.standard.set(host, forKey: hostKey)
    }

    /// Also settable from outside: `simctl launch <device> com.palkesz.squabble -useLocalEmulator YES`.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey) && host != nil
    }

    /// Firebase can only be configured once per launch, so switching quits the app.
    static func setEnabled(_ isEnabled: Bool) -> Never {
        UserDefaults.standard.set(isEnabled, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        exit(0)
    }

    static func configure() {
        guard let host else { return }
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
