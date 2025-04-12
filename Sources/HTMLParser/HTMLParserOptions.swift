//
//  HTMLParserOptions.swift
//  HTMLParser
//
//  Created by Oliver Drobnik on 11.04.25.
//

import Foundation

#if canImport(libxml2)
import libxml2
#else
import CLibXML2
#endif

/// Wrapper for libxml2 htmlParserOption enum
/// See: http://xmlsoft.org/html/libxml-HTMLparser.html#htmlParserOption
public struct HTMLParserOptions: OptionSet, Sendable {
	public let rawValue: Int32
	public init(rawValue: Int32) { self.rawValue = rawValue }

	/// Relaxed parsing (HTML_PARSE_RECOVER)
	public static let recover          = HTMLParserOptions(rawValue: 1 << 0)
	/// Do not default a doctype if not found (HTML_PARSE_NODEFDTD)
	public static let noDefaultDTD     = HTMLParserOptions(rawValue: 1 << 2)
	/// Suppress error reports (HTML_PARSE_NOERROR)
	public static let noError          = HTMLParserOptions(rawValue: 1 << 5)
	/// Suppress warning reports (HTML_PARSE_NOWARNING)
	public static let noWarning        = HTMLParserOptions(rawValue: 1 << 6)
	/// Pedantic error reporting (HTML_PARSE_PEDANTIC)
	public static let pedantic         = HTMLParserOptions(rawValue: 1 << 7)
	/// Remove blank nodes (HTML_PARSE_NOBLANKS)
	public static let noBlanks         = HTMLParserOptions(rawValue: 1 << 8)
	/// Forbid network access (HTML_PARSE_NONET)
	public static let noNet            = HTMLParserOptions(rawValue: 1 << 11)
	/// Do not add implied html/body... elements (HTML_PARSE_NOIMPLIED)
	public static let noImpliedElements = HTMLParserOptions(rawValue: 1 << 13)
	/// Compact small text nodes (HTML_PARSE_COMPACT)
	public static let compact          = HTMLParserOptions(rawValue: 1 << 16)
	/// Ignore internal document encoding hint (HTML_PARSE_IGNORE_ENC)
	public static let ignoreEncoding   = HTMLParserOptions(rawValue: 1 << 21)
}
