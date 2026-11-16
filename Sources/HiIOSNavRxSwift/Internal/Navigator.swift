// Adapted from URLNavigator (https://github.com/devxoul/URLNavigator)
//
// The MIT License (MIT)
// Copyright (c) 2016 Suyeol Jeon (xoul.kr)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if os(iOS) || os(tvOS)
import UIKit

internal typealias NavigatorURLPattern = String
internal typealias ViewControllerFactory = @MainActor (
    _ url: URLConvertible,
    _ values: [String: any Sendable],
    _ context: Any?
) -> UIViewController?
internal typealias URLOpenHandlerFactory = @MainActor (
    _ url: URLConvertible,
    _ values: [String: any Sendable],
    _ context: Any?
) -> Bool
internal typealias URLOpenHandler = @MainActor () -> Bool

@MainActor
internal protocol UINavigationControllerType: AnyObject {
    func pushViewController(_ viewController: UIViewController, animated: Bool)
}

@MainActor
internal protocol UIViewControllerType: AnyObject {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
}

extension UINavigationController: UINavigationControllerType {}
extension UIViewController: UIViewControllerType {}

@MainActor
internal protocol NavigatorDelegate: AnyObject {
    func shouldPush(viewController: UIViewController, from: UINavigationControllerType) -> Bool
    func shouldPresent(viewController: UIViewController, from: UIViewControllerType) -> Bool
}

extension NavigatorDelegate {
    internal func shouldPush(viewController: UIViewController, from: UINavigationControllerType) -> Bool {
        true
    }

    internal func shouldPresent(viewController: UIViewController, from: UIViewControllerType) -> Bool {
        true
    }
}

@MainActor
internal protocol NavigatorProtocol: AnyObject {
    var delegate: NavigatorDelegate? { get set }

    func register(_ pattern: NavigatorURLPattern, _ factory: @escaping ViewControllerFactory)
    func handle(_ pattern: NavigatorURLPattern, _ factory: @escaping URLOpenHandlerFactory)

    func viewController(for url: URLConvertible, context: Any?) -> UIViewController?
    func handler(for url: URLConvertible, context: Any?) -> URLOpenHandler?

    @discardableResult
    func push(_ url: URLConvertible, context: Any?, from: UINavigationControllerType?, animated: Bool) -> UIViewController?

    @discardableResult
    func push(_ viewController: UIViewController, from: UINavigationControllerType?, animated: Bool) -> UIViewController?

    @discardableResult
    func present(
        _ url: URLConvertible,
        context: Any?,
        wrap: UINavigationController.Type?,
        from: UIViewControllerType?,
        animated: Bool,
        completion: (() -> Void)?
    ) -> UIViewController?

    @discardableResult
    func present(
        _ viewController: UIViewController,
        wrap: UINavigationController.Type?,
        from: UIViewControllerType?,
        animated: Bool,
        completion: (() -> Void)?
    ) -> UIViewController?

    @discardableResult
    func open(_ url: URLConvertible, context: Any?) -> Bool
}

extension NavigatorProtocol {
    internal func viewController(for url: URLConvertible, context: Any? = nil) -> UIViewController? {
        self.viewController(for: url, context: context)
    }

    internal func handler(for url: URLConvertible, context: Any? = nil) -> URLOpenHandler? {
        self.handler(for: url, context: context)
    }

    @discardableResult
    internal func push(
        _ url: URLConvertible,
        context: Any? = nil,
        from: UINavigationControllerType? = nil,
        animated: Bool = true
    ) -> UIViewController? {
        self.push(url, context: context, from: from, animated: animated)
    }

    @discardableResult
    internal func present(
        _ url: URLConvertible,
        context: Any? = nil,
        wrap: UINavigationController.Type? = nil,
        from: UIViewControllerType? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> UIViewController? {
        self.present(url, context: context, wrap: wrap, from: from, animated: animated, completion: completion)
    }

    @discardableResult
    internal func open(_ url: URLConvertible, context: Any? = nil) -> Bool {
        self.open(url, context: context)
    }
}

@MainActor
internal final class Navigator: NavigatorProtocol {
    internal let matcher = URLMatcher()
    internal weak var delegate: NavigatorDelegate?

    private var viewControllerFactories = [NavigatorURLPattern: ViewControllerFactory]()
    private var handlerFactories = [NavigatorURLPattern: URLOpenHandlerFactory]()

    internal init() {}

    internal func register(_ pattern: NavigatorURLPattern, _ factory: @escaping ViewControllerFactory) {
        self.viewControllerFactories[pattern] = factory
    }

    internal func handle(_ pattern: NavigatorURLPattern, _ factory: @escaping URLOpenHandlerFactory) {
        self.handlerFactories[pattern] = factory
    }

    internal func viewController(for url: URLConvertible, context: Any? = nil) -> UIViewController? {
        let urlPatterns = Array(self.viewControllerFactories.keys)
        guard let match = self.matcher.match(url, from: urlPatterns) else { return nil }
        guard let factory = self.viewControllerFactories[match.pattern] else { return nil }
        return factory(url, match.values, context)
    }

    internal func handler(for url: URLConvertible, context: Any? = nil) -> URLOpenHandler? {
        let urlPatterns = Array(self.handlerFactories.keys)
        guard let match = self.matcher.match(url, from: urlPatterns) else { return nil }
        guard let handler = self.handlerFactories[match.pattern] else { return nil }
        return { handler(url, match.values, context) }
    }

    @discardableResult
    internal func push(
        _ url: URLConvertible,
        context: Any? = nil,
        from: UINavigationControllerType? = nil,
        animated: Bool = true
    ) -> UIViewController? {
        guard let viewController = self.viewController(for: url, context: context) else { return nil }
        return self.push(viewController, from: from, animated: animated)
    }

    @discardableResult
    internal func push(
        _ viewController: UIViewController,
        from: UINavigationControllerType? = nil,
        animated: Bool = true
    ) -> UIViewController? {
        guard (viewController is UINavigationController) == false else { return nil }
        guard let navigationController = from ?? UIViewController.navigatorTopMost?.navigationController else { return nil }
        guard self.delegate?.shouldPush(viewController: viewController, from: navigationController) != false else { return nil }
        navigationController.pushViewController(viewController, animated: animated)
        return viewController
    }

    @discardableResult
    internal func present(
        _ url: URLConvertible,
        context: Any? = nil,
        wrap: UINavigationController.Type? = nil,
        from: UIViewControllerType? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let viewController = self.viewController(for: url, context: context) else { return nil }
        return self.present(viewController, wrap: wrap, from: from, animated: animated, completion: completion)
    }

    @discardableResult
    internal func present(
        _ viewController: UIViewController,
        wrap: UINavigationController.Type? = nil,
        from: UIViewControllerType? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let fromViewController = from ?? UIViewController.navigatorTopMost else { return nil }

        let viewControllerToPresent: UIViewController
        if let navigationControllerClass = wrap, (viewController is UINavigationController) == false {
            viewControllerToPresent = navigationControllerClass.init(rootViewController: viewController)
        } else {
            viewControllerToPresent = viewController
        }

        guard self.delegate?.shouldPresent(viewController: viewController, from: fromViewController) != false else { return nil }
        fromViewController.present(viewControllerToPresent, animated: animated, completion: completion)
        return viewController
    }

    @discardableResult
    internal func open(_ url: URLConvertible, context: Any? = nil) -> Bool {
        guard let handler = self.handler(for: url, context: context) else { return false }
        return handler()
    }
}

extension UIViewController {
    @MainActor
    private static var navigatorSharedApplication: UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        return UIApplication.perform(selector)?.takeUnretainedValue() as? UIApplication
    }

    @MainActor
    private static var navigatorKeyWindow: UIWindow? {
        guard let app = self.navigatorSharedApplication else { return nil }
        let windowScenes = app.connectedScenes.compactMap { $0 as? UIWindowScene }
        let orderedScenes = windowScenes.filter { $0.activationState == .foregroundActive }
            + windowScenes.filter { $0.activationState != .foregroundActive }
        for scene in orderedScenes {
            if let keyWindow = scene.keyWindow {
                return keyWindow
            }
            if let fallbackWindow = scene.windows.first(where: \.isKeyWindow) {
                return fallbackWindow
            }
        }
        return nil
    }

    @MainActor
    internal class var navigatorTopMost: UIViewController? {
        self.navigatorTopMost(of: self.navigatorKeyWindow?.rootViewController)
    }

    @MainActor
    internal class func navigatorTopMost(of viewController: UIViewController?) -> UIViewController? {
        if let presentedViewController = viewController?.presentedViewController {
            return self.navigatorTopMost(of: presentedViewController)
        }
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return self.navigatorTopMost(of: selectedViewController)
        }
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return self.navigatorTopMost(of: visibleViewController)
        }
        if let pageViewController = viewController as? UIPageViewController,
           pageViewController.viewControllers?.count == 1 {
            return self.navigatorTopMost(of: pageViewController.viewControllers?.first)
        }
        for subview in viewController?.view?.subviews ?? [] {
            if let childViewController = subview.next as? UIViewController {
                return self.navigatorTopMost(of: childViewController)
            }
        }
        return viewController
    }
}
#endif
