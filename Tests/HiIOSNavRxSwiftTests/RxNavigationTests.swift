import Foundation
import HiIOSNavCore
@testable import HiIOSNavRxSwift
import Testing
import UIKit

private enum TestRoute: Hashable, Sendable { case details }

@MainActor
@Test
func rxEmitterPublishesTypedAction() {
    let emitter = RxNavigationEmitter<TestRoute>()
    var received: [NavigationAction<TestRoute>] = []
    let disposable = emitter.actions.subscribe(onNext: { received.append($0) })

    emitter.send(.push(.details))

    #expect(received == [.push(.details)])
    disposable.dispose()
}

@MainActor
@Test
func rxURLNavigatorRejectsDisallowedURLBeforeNavigation() throws {
    let navigator = RxURLNavigator()
    let url = try #require(URL(string: "https://example.com/private"))

    #expect(throws: URLNavigationError.disallowedURL) {
        try navigator.open(url, allowedBy: [], queryIsAllowed: { _ in true })
    }
}

@MainActor
@Test
func rxURLNavigatorRequiresCallerQueryValidation() throws {
    let navigator = RxURLNavigator()
    let url = try #require(URL(string: "https://example.com/callback?code=secret"))
    let pattern = HiIOSNavCore.URLPattern(
        scheme: "https", host: "example.com", path: "/callback", port: nil, fragment: nil
    )

    #expect(throws: URLNavigationError.disallowedURL) {
        try navigator.open(url, allowedBy: [pattern], queryIsAllowed: { $0.query == nil })
    }
}

@MainActor
@Test
func rxURLNavigatorPushesMatchingViewController() throws {
    let navigator = RxURLNavigator()
    let expected = UIViewController()
    let navController = UINavigationController()
    let url = try #require(URL(string: "https://example.com/users/42"))
    let allowed = HiIOSNavCore.URLPattern(
        scheme: "https", host: "example.com", path: "/users/42", port: nil, fragment: nil
    )

    navigator.register("https://example.com/users/<int:id>") { matchedURL in
        matchedURL == url ? expected : nil
    }

    let pushed = try navigator.push(url, from: navController, allowedBy: [allowed], queryIsAllowed: { _ in true })
    #expect(pushed === expected)
    #expect(navController.viewControllers.contains { $0 === expected })
}

@Test
func urlMatcherMatchesWebPatternsWithTypedHostPlaceholders() {
    let matcher = URLMatcher()

    let angleMatch = matcher.match("http://example.com/repos/HiIOS", from: ["http://<path:url>"])
    #expect(angleMatch?.pattern == "http://<path:url>")
    #expect(angleMatch?.values["url"] as? String == "example.com/repos/HiIOS")

    let bracketMatch = matcher.match("https://example.com/repos/HiIOS", from: ["https://[path:url]"])
    #expect(bracketMatch?.pattern == "https://[path:url]")
    #expect(bracketMatch?.values["url"] as? String == "example.com/repos/HiIOS")

    let caseInsensitiveScheme = matcher.match("HTTPS://example.com/42", from: ["https://example.com/<int:id>"])
    #expect(caseInsensitiveScheme?.values["id"] as? Int == 42)
}

@Test
func urlMatcherNormalizesUnicodeURLsWithoutNSRangeTruncation() {
    let matcher = URLMatcher()
    let normalized = matcher.normalizeURL("https://example.com/🚀/path//end/?q=1#frag").urlStringValue
    #expect(normalized == "https://example.com/🚀/path/end")
}
