//
//  DTHTMLParserDelegate.swift
//
//
//  Created by Oliver Drobnik on 01.06.24.
//

import Foundation

@objc(DTHTMLParserDelegate)
public protocol DTHTMLParserDelegate: AnyObject
{
	@objc optional func parserDidStartDocument(_ parser: DTHTMLParser)
	@objc optional func parserDidEndDocument(_ parser: DTHTMLParser)
	@objc optional func parser(_ parser: DTHTMLParser, didStartElement elementName: String, attributes attributeDict: [String: String])
	@objc optional func parser(_ parser: DTHTMLParser, didEndElement elementName: String)
	@objc optional func parser(_ parser: DTHTMLParser, foundCharacters string: String)
	@objc optional func parser(_ parser: DTHTMLParser, foundComment comment: String)
	@objc optional func parser(_ parser: DTHTMLParser, foundCDATA CDATABlock: Data)
	@objc optional func parser(_ parser: DTHTMLParser, foundProcessingInstructionWithTarget target: String, data: String)
	@objc optional func parser(_ parser: DTHTMLParser, parseErrorOccurred parseError: NSError)
}
