//
//  String+Helpers.swift
//  Simple Notes
//
//  Created by Paulo Mattos on 11/03/19.
//  Copyright © 2019 Paulo Mattos. All rights reserved.
//

import Foundation

extension String {
    var length: Int {
        return count
    }

    func at(_ i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    func substring(_ r: Range<Int>) -> String {
        return self[r]
    }

    subscript(r: Range<Int>) -> String {
        let range = Range(
            uncheckedBounds: (
                lower: max(0, min(length, r.lowerBound)),
                upper: min(length, max(0, r.upperBound))
            )
        )
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

/// General `String` helpers.
extension String {
    /// Returns an array of all the lines in this string.
    /// The new line terminator is *not* included in each line.
    var lines: [String] {
        return components(separatedBy: "\n")
    }
}

// MARK: -

/// General `NSString` helpers.
extension NSString {
    /// Returns this string *full* range.
    var range: NSRange {
        return NSRange(location: 0, length: length)
    }
}

extension String {
    func string(inRange nsrange: NSRange) -> String {
        guard let range = Range<String.Index>(nsrange, in: self) else {
            return ""
        }
        return String(self[range])
    }
}

// MARK: -

/// General `NSAttributedString` helpers.
extension NSAttributedString {
    /// Returns this string *full* range.
    var range: NSRange {
        return NSRange(location: 0, length: length)
    }

    /// Returns the range of characters representing the line
    /// or lines containing the specified index.
    func lineRange(for index: Int) -> NSRange {
        precondition(index <= string.length, "Index must be less than length [\(index) < \(string.length)]")
        let charRange = NSRange(location: index, length: 0)
        return (string as NSString).lineRange(for: charRange)
    }

    /// Returns the character in the specified index, if any.
    func character(at charIndex: Int) -> String? {
        let string = self.string as NSString
        guard charIndex >= 0 && charIndex < string.length else {
            return nil
        }
        return string.substring(with: NSRange(location: charIndex, length: 1))
    }

    /// Enumerates all the lines in this attributed string.
    /// This *also* includes the new line terminator as well.
    func enumerateLines(inRange: NSRange? = nil, _ body: (NSAttributedString, NSRange) -> Void) {
        let string = self.string as NSString
        var lineStart = 0, lineEnd = 0
        var maxIndex =  string.length
        
        if let threshold = inRange, threshold.max < maxIndex && threshold.location >= 0 {
            lineStart = threshold.location
            maxIndex = threshold.max + 1
        }

        while lineStart < maxIndex {
            string.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: nil,
                for: NSRange(location: lineStart, length: 0)
            )
            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            let line = attributedSubstring(from: lineRange)

            body(line, lineRange)
            lineStart = lineEnd
        }
    }

    /// Returns a new attributed string containing the results
    /// of mapping the given closure over each string's line.
    /// Each provided line *also* includes the new line terminator as well.
    func mapLines(
        transform: (NSAttributedString) -> NSAttributedString
    ) -> NSAttributedString {
        let transformedString = NSMutableAttributedString()
        enumerateLines { line, _ in
            transformedString.append(transform(line))
        }
        return transformedString
    }

    /// Returns all attribute values and ranges in the specified range.
    func attribute(
        _ attribKey: NSAttributedString.Key,
        in range: NSRange
    ) -> [(value: Any, range: NSRange)] {
        var result: [(value: Any, range: NSRange)] = []
        enumerateAttribute(attribKey, in: range) {
            value, range, _ in
            guard let value = value else { return }
            result.append((value, range))
        }
        return result
    }
}

// MARK: -

/// General `NSMutableAttributedString` helpers.
extension NSMutableAttributedString {
    /// Adds to the end of this string the characters of the specified string.
    /// This **will** extend the previous attributes to the new string as well.
    func append(_ string: String) {
        mutableString.append(string)
    }

    /// Sets the attribute for the characters in
    /// the specified range to the specified value.
    func setAttribute(_ attrib: NSAttributedString.Key, value: Any, range: NSRange) {
        setAttributes([attrib: value], range: range)
    }

    func updateAttribute(_ attrib: NSAttributedString.Key, value: Any, range: NSRange) {
        var attributes = attributes(at: 0, longestEffectiveRange: nil, in: range)
        attributes[attrib] = value
        setAttributes(attributes, range: range)
    }
}

// MARK: - Regular Expressions

func regex(_ pattern: String) -> NSRegularExpression {
    return try! NSRegularExpression(pattern: pattern)
}

extension NSRegularExpression {
    func firstMatch(in string: String) -> NSTextCheckingResult? {
        let fullRange = (string as NSString).range
        return firstMatch(in: string, range: fullRange)
    }
}

// MARK: - Misc

extension NSRange {
    func nextChar() -> NSRange {
        return NSRange(location: location + 1, length: length)
    }
}

extension String {
    func regex(pattern: String) -> [NSTextCheckingResult] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .init(rawValue: 0))
            let all = NSRange(location: 0, length: length)
            return regex.matches(in: self, range: all)
        } catch {
            return []
        }
    }
}

extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        guard let from = range.lowerBound.samePosition(in: utf16),
              let to = range.upperBound.samePosition(in: utf16) else {
            return nil
        }
        return NSRange(
            location: utf16.distance(from: utf16.startIndex, to: from),
            length: utf16.distance(from: from, to: to)
        )
    }
}

extension String {
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location + nsRange.length, limitedBy: utf16.endIndex),
            let from = from16.samePosition(in: self),
            let to = to16.samePosition(in: self)
        else { return nil }
        return from ..< to
    }
}
