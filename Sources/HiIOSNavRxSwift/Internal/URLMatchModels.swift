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

/// Represents a URL match result.
internal struct URLMatchResult: Sendable {
    internal let pattern: String
    internal let values: [String: any Sendable]
}

internal enum URLPathComponent: Equatable, Sendable {
    case plain(String)
    case placeholder(type: String?, key: String)
}

extension URLPathComponent {
    internal init(_ value: String) {
        // Support both upstream "<type:key>" / "<key>" and bracketed "[type:key]" / "[key]" placeholders.
        let isAnglePlaceholder = value.hasPrefix("<") && value.hasSuffix(">")
        let isBracketPlaceholder = value.hasPrefix("[") && value.hasSuffix("]")
        if isAnglePlaceholder || isBracketPlaceholder {
            let start = value.index(after: value.startIndex)
            let end = value.index(before: value.endIndex)
            let placeholder = value[start..<end]
            let typeAndKey = placeholder.components(separatedBy: ":")
            if typeAndKey.count == 1 {
                self = .placeholder(type: nil, key: typeAndKey[0])
            } else if typeAndKey.count == 2 {
                self = .placeholder(type: typeAndKey[0], key: typeAndKey[1])
            } else {
                self = .plain(value)
            }
        } else {
            self = .plain(value)
        }
    }
}

internal enum URLPathComponentMatchResult {
    case matches((key: String, value: any Sendable)?)
    case notMatches
}
