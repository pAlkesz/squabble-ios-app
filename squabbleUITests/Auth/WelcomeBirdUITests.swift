import XCTest

final class WelcomeBirdUITests: XCTestCase {
    /// The bird is the welcome screen's easter egg: it has to survive the splash, stay
    /// hittable, and react without taking the sign-in button with it.
    @MainActor
    func testTappingTheBirdRufflesItAndLeavesSignInUsable() {
        let app = XCUIApplication()
        app.launch()

        let bird = app.descendants(matching: .any)["welcome.bird"]
        XCTAssertTrue(bird.waitForExistence(timeout: 20), "welcome bird never appeared")
        XCTAssertTrue(bird.isHittable)

        bird.tap()
        attach(XCUIScreen.main.screenshot(), named: "bird-ruffled")

        XCTAssertTrue(bird.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Apple'")).firstMatch.exists)
    }

    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
