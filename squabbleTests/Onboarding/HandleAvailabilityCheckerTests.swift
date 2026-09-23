import Foundation
import Testing
@testable import squabble

struct HandleAvailabilityCheckerTests {
    private let profiles = FakeProfileRepository()

    private func checker(logging log: LogSpy = LogSpy()) -> HandleAvailabilityChecker {
        HandleAvailabilityChecker(profiles: profiles, logFailure: { log.record($0) })
    }

    @Test func emptyInputIsIdleWithoutAsking() async {
        #expect(await checker().check("", for: "uid-1", isOnline: true) == .idle)
        #expect(profiles.availabilityLookups == 0)
    }

    @Test func invalidInputIsReportedWithoutAsking() async {
        #expect(await checker().check("ab", for: "uid-1", isOnline: true) == .invalid(.tooShort))
        #expect(profiles.availabilityLookups == 0)
    }

    @Test func offlineDeviceDoesNotAsk() async {
        #expect(await checker().check("pal", for: "uid-1", isOnline: false) == .offline)
        #expect(profiles.availabilityLookups == 0)
    }

    @Test func freeHandleIsAvailable() async {
        #expect(await checker().check("pal", for: "uid-1", isOnline: true) == .available)
    }

    @Test func handleHeldBySomeoneElseIsTaken() async throws {
        profiles.claim(try Handle(validating: "pal"), by: "uid-2")
        #expect(await checker().check("@Pal", for: "uid-1", isOnline: true) == .taken)
    }

    @Test func ownHandleCountsAsAvailable() async throws {
        profiles.claim(try Handle(validating: "pal"), by: "uid-1")
        #expect(await checker().check("pal", for: "uid-1", isOnline: true) == .available)
    }

    @Test func serverUnreachableIsOfflineAndNotLogged() async {
        profiles.availabilityError = ProfileError.offline
        let log = LogSpy()
        #expect(await checker(logging: log).check("pal", for: "uid-1", isOnline: true) == .offline)
        #expect(log.count == 0)
    }

    @Test func otherFailuresAreLoggedAndRetryable() async {
        profiles.availabilityError = FirestoreMappingError.malformed("handles/pal")
        let log = LogSpy()
        #expect(await checker(logging: log).check("pal", for: "uid-1", isOnline: true) == .failed)
        #expect(log.count == 1)
    }

    @Test(arguments: [
        HandleAvailability.idle, .checking, .taken, .offline, .failed, .invalid(.tooShort),
    ])
    func onlyAConfirmedHandleAllowsContinuing(state: HandleAvailability) {
        #expect(!state.allowsContinuing)
        #expect(HandleAvailability.available.allowsContinuing)
    }
}

nonisolated final class LogSpy: @unchecked Sendable {
    private(set) var count = 0

    func record(_ error: Error) {
        count += 1
    }
}
