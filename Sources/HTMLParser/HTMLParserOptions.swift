//
//  HTMLParserOptions.swift
//  HTMLParser
//
//  Created by Oliver Drobnik on 11.04.25.
//

import Foundation

public struct HTMLParserOptions: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let recover   = HTMLParserOptions(rawValue: 1 << 0)
    public static let noError   = HTMLParserOptions(rawValue: 1 << 1)
    public static let noWarning = HTMLParserOptions(rawValue: 1 << 2)
    public static let pedantic  = HTMLParserOptions(rawValue: 1 << 3)
    public static let noBlanks  = HTMLParserOptions(rawValue: 1 << 4)
    public static let noNet     = HTMLParserOptions(rawValue: 1 << 5)
    public static let compact   = HTMLParserOptions(rawValue: 1 << 6)
}
