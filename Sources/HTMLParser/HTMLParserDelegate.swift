//
//  HTMLParserDelegate.swift
//
//
//  Created by Oliver Drobnik on 01.06.24.
//

import Foundation

public protocol HTMLParserDelegate: AnyObject
{
	func parserDidStartDocument(_ parser: HTMLParser)
	func parserDidEndDocument(_ parser: HTMLParser)
	func parser(_ parser: HTMLParser, didStartElement elementName: String, attributes attributeDict: [String: String])
	func parser(_ parser: HTMLParser, didEndElement elementName: String)
	func parser(_ parser: HTMLParser, foundCharacters string: String)
	func parser(_ parser: HTMLParser, foundComment comment: String)
	func parser(_ parser: HTMLParser, foundCDATA CDATABlock: Data)
	func parser(_ parser: HTMLParser, foundProcessingInstructionWithTarget target: String, data: String)
	func parser(_ parser: HTMLParser, parseErrorOccurred parseError: NSError)
}
