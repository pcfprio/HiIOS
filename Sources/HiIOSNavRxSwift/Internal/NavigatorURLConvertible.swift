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

/// A type which can be converted to a URL string.
internal protocol URLConvertible: Sendable {
    var urlValue: URL? { get }
    var urlStringValue: String { get }
    var queryParameters: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
}

extension URLConvertible {
    internal var queryParameters: [String: String] {
        var parameters = [String: String]()
        self.urlValue?.query?.components(separatedBy: "&").forEach { component in
            guard let separatorIndex = component.firstIndex(of: "=") else { return }
            let keyRange = component.startIndex..<separatorIndex
            let valueRange = component.index(after: separatorIndex)..<component.endIndex
            let key = String(component[keyRange])
            let value = component[valueRange].removingPercentEncoding ?? String(component[valueRange])
            parameters[key] = value
        }
        return parameters
    }

    internal var queryItems: [URLQueryItem]? {
        URLComponents(string: self.urlStringValue)?.queryItems
    }
}

extension String: URLConvertible {
    internal var urlValue: URL? {
        if let url = URL(string: self) {
            return url
        }
        var set = CharacterSet()
        set.formUnion(.urlHostAllowed)
        set.formUnion(.urlPathAllowed)
        set.formUnion(.urlQueryAllowed)
        set.formUnion(.urlFragmentAllowed)
        return self.addingPercentEncoding(withAllowedCharacters: set).flatMap { URL(string: $0) }
    }

    internal var urlStringValue: String {
        self
    }
}

extension URL: URLConvertible {
    internal var urlValue: URL? {
        self
    }

    internal var urlStringValue: String {
        self.absoluteString
    }
}
