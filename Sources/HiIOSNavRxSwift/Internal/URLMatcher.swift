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

import Foundation

internal struct URLMatcher: Sendable {
    internal typealias NavigatorURLPattern = String
    internal typealias URLValueConverter = @Sendable (_ pathComponents: [String], _ index: Int) -> (any Sendable)?

    internal static let defaultURLValueConverters: [String: URLValueConverter] = [
        "string": { pathComponents, index in
            pathComponents[index]
        },
        "int": { pathComponents, index in
            Int(pathComponents[index])
        },
        "float": { pathComponents, index in
            Float(pathComponents[index])
        },
        "uuid": { pathComponents, index in
            UUID(uuidString: pathComponents[index])
        },
        "path": { pathComponents, index in
            pathComponents[index..<pathComponents.count].joined(separator: "/")
        }
    ]

    internal var valueConverters: [String: URLValueConverter]

    internal init(valueConverters: [String: URLValueConverter] = URLMatcher.defaultURLValueConverters) {
        self.valueConverters = valueConverters
    }

    internal func match(_ url: URLConvertible, from candidates: [NavigatorURLPattern]) -> URLMatchResult? {
        let url = self.normalizeURL(url)
        let urlScheme = self.scheme(of: url)
        let stringPathComponents = self.stringPathComponents(from: url)

        var results = [URLMatchResult]()
        for candidate in candidates {
            guard urlScheme == self.scheme(of: candidate) else { continue }
            if let result = self.match(stringPathComponents, with: candidate) {
                results.append(result)
            }
        }

        return results.max {
            self.numberOfPlainPathComponent(in: $0.pattern) < self.numberOfPlainPathComponent(in: $1.pattern)
        }
    }

    internal func match(_ stringPathComponents: [String], with candidate: NavigatorURLPattern) -> URLMatchResult? {
        let normalizedCandidate = self.normalizeURL(candidate).urlStringValue
        let candidatePathComponents = self.pathComponents(from: normalizedCandidate)
        guard self.ensurePathComponentsCount(stringPathComponents, candidatePathComponents) else {
            return nil
        }

        var urlValues: [String: any Sendable] = [:]

        let pairCount = min(stringPathComponents.count, candidatePathComponents.count)
        for index in 0..<pairCount {
            let result = self.matchStringPathComponent(
                at: index,
                from: stringPathComponents,
                with: candidatePathComponents
            )

            switch result {
            case let .matches(placeholderValue):
                if let (key, value) = placeholderValue {
                    urlValues[key] = value
                }

            case .notMatches:
                return nil
            }
        }

        return URLMatchResult(pattern: candidate, values: urlValues)
    }

    internal func normalizeURL(_ dirtyURL: URLConvertible) -> URLConvertible {
        guard dirtyURL.urlValue != nil else { return dirtyURL }
        var urlString = dirtyURL.urlStringValue
        urlString = urlString.components(separatedBy: "?")[0].components(separatedBy: "#")[0]
        urlString = self.replaceRegex(":/{3,}", "://", urlString)
        urlString = self.replaceRegex("(?<!:)/{2,}", "/", urlString)
        urlString = self.replaceRegex("(?<!:|:/)/+$", "", urlString)
        return urlString
    }

    internal func replaceRegex(_ pattern: String, _ repl: String, _ string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return string }
        // Use UTF-16 String bounds instead of character count to handle non-BMP scalars safely.
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: repl)
    }

    internal func ensurePathComponentsCount(
        _ stringPathComponents: [String],
        _ candidatePathComponents: [URLPathComponent]
    ) -> Bool {
        let hasSameNumberOfComponents = (stringPathComponents.count == candidatePathComponents.count)
        let containsPathPlaceholderComponent = candidatePathComponents.contains {
            if case let .placeholder(type, _) = $0, type == "path" {
                return true
            } else {
                return false
            }
        }
        return hasSameNumberOfComponents || (containsPathPlaceholderComponent && stringPathComponents.count > candidatePathComponents.count)
    }

    internal func stringPathComponents(from url: URLConvertible) -> [String] {
        url.urlStringValue.components(separatedBy: "/").lazy.enumerated()
            .filter { _, component in !component.isEmpty }
            .filter { index, component in !self.isScheme(index, component) }
            .map { _, component in component }
    }

    private func scheme(of url: URLConvertible) -> String? {
        if let scheme = url.urlValue?.scheme {
            return scheme.lowercased()
        }
        // Patterns such as "http://<path:url>" fail URL(string:) because Foundation interprets
        // ":" inside the typed placeholder as an invalid port; inspect RFC 3986 scheme prefix directly.
        let raw = url.urlStringValue
        guard let colonIndex = raw.firstIndex(of: ":"), colonIndex > raw.startIndex else {
            return nil
        }
        if let firstSlash = raw.firstIndex(of: "/"), colonIndex > firstSlash {
            return nil
        }
        let candidate = raw[..<colonIndex]
        guard let first = candidate.first, first.isASCII, first.isLetter else {
            return nil
        }
        let isValidScheme = candidate.allSatisfy { ch in
            ch.isASCII && (ch.isLetter || ch.isNumber || ch == "+" || ch == "-" || ch == ".")
        }
        return isValidScheme ? candidate.lowercased() : nil
    }

    private func isScheme(_ index: Int, _ component: String) -> Bool {
        index == 0 && component.hasSuffix(":")
    }

    internal func pathComponents(from url: NavigatorURLPattern) -> [URLPathComponent] {
        self.stringPathComponents(from: url).map(URLPathComponent.init)
    }

    internal func matchStringPathComponent(
        at index: Int,
        from stringPathComponents: [String],
        with candidatePathComponents: [URLPathComponent]
    ) -> URLPathComponentMatchResult {
        let stringPathComponent = stringPathComponents[index]
        let urlPathComponent = candidatePathComponents[index]

        switch urlPathComponent {
        case let .plain(value):
            guard stringPathComponent == value else { return .notMatches }
            return .matches(nil)

        case let .placeholder(type, key):
            guard let type = type, let converter = self.valueConverters[type] else {
                return .matches((key, stringPathComponent))
            }
            if let value = converter(stringPathComponents, index) {
                return .matches((key, value))
            } else {
                return .notMatches
            }
        }
    }

    private func numberOfPlainPathComponent(in pattern: NavigatorURLPattern) -> Int {
        self.pathComponents(from: pattern).lazy.filter {
            guard case .plain = $0 else { return false }
            return true
        }.count
    }
}
