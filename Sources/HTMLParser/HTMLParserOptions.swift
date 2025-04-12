//
//  HTMLParserOptions.swift
//  HTMLParser
//
//  Created by Oliver Drobnik on 11.04.25.
//

import Foundation

import CHTMLParser

#if canImport(ClibXML2)
import CLibXML2
#endif

/// Wrapper for libxml2 htmlParserOption enum
/// See: http://xmlsoft.org/html/libxml-HTMLparser.html#htmlParserOption
public struct HTMLParserOptions: OptionSet, Sendable {
	public let rawValue: Int32
	public init(rawValue: Int32) { self.rawValue = rawValue }

	/// Relaxed parsing (HTML_PARSE_RECOVER)
	public static let recover          = HTMLParserOptions(rawValue: Int32(HTML_PARSE_RECOVER.rawValue))
	
	/// Do not default a doctype if not found (HTML_PARSE_NODEFDTD)
	public static let noDefaultDTD     = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NODEFDTD.rawValue))
	
	/// Suppress error reports (HTML_PARSE_NOERROR)
	public static let noError          = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NOERROR.rawValue))
	
	/// Suppress warning reports (HTML_PARSE_NOWARNING)
	public static let noWarning        = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NOWARNING.rawValue))
	
	/// Pedantic error reporting (HTML_PARSE_PEDANTIC)
	public static let pedantic         = HTMLParserOptions(rawValue: Int32(HTML_PARSE_PEDANTIC.rawValue))
	
	/// Remove blank nodes (HTML_PARSE_NOBLANKS)
	public static let noBlanks         = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NOBLANKS.rawValue))
	
	/// Forbid network access (HTML_PARSE_NONET)
	public static let noNet            = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NONET.rawValue))
	
	/// Do not add implied html/body... elements (HTML_PARSE_NOIMPLIED)
	public static let noImpliedElements = HTMLParserOptions(rawValue: Int32(HTML_PARSE_NOIMPLIED.rawValue))
	
	/// Compact small text nodes (HTML_PARSE_COMPACT)
	public static let compact          = HTMLParserOptions(rawValue: Int32(HTML_PARSE_COMPACT.rawValue))
	
	/// Ignore internal document encoding hint (HTML_PARSE_IGNORE_ENC)
	public static let ignoreEncoding   = HTMLParserOptions(rawValue: Int32(HTML_PARSE_IGNORE_ENC.rawValue))
}
