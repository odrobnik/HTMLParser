//
//  DTHTMLParserDelegate.swift
//
//
//  Created by Oliver Drobnik on 01.06.24.
//

#if !os(Linux)

import Foundation

/**
 A delegate protocol for receiving HTML parsing events.
 
 This protocol is designed to be used from Objective-C code, providing a delegate-based API
 for receiving events during HTML parsing. All methods are optional, allowing implementers
 to only handle the events they're interested in.
 
 This protocol is not available on Linux platforms.
 */
@objc(DTHTMLParserDelegate)
public protocol DTHTMLParserDelegate: AnyObject
{
	/**
	 Called when the parser begins parsing a document.
	 
	 - Parameter parser: The parser that is parsing the document
	 */
	@objc optional func parserDidStartDocument(_ parser: DTHTMLParser)
	
	/**
	 Called when the parser finishes parsing a document.
	 
	 - Parameter parser: The parser that finished parsing the document
	 */
	@objc optional func parserDidEndDocument(_ parser: DTHTMLParser)
	
	/**
	 Called when the parser encounters the start of an element.
	 
	 - Parameters:
	   - parser: The parser that encountered the element
	   - elementName: The name of the element
	   - attributes: A dictionary of attribute names and values
	 */
	@objc optional func parser(_ parser: DTHTMLParser, didStartElement elementName: String, attributes attributeDict: [String: String])
	
	/**
	 Called when the parser encounters the end of an element.
	 
	 - Parameters:
	   - parser: The parser that encountered the element
	   - elementName: The name of the element
	 */
	@objc optional func parser(_ parser: DTHTMLParser, didEndElement elementName: String)
	
	/**
	 Called when the parser encounters character data.
	 
	 - Parameters:
	   - parser: The parser that encountered the characters
	   - string: The character data
	 */
	@objc optional func parser(_ parser: DTHTMLParser, foundCharacters string: String)
	
	/**
	 Called when the parser encounters a comment.
	 
	 - Parameters:
	   - parser: The parser that encountered the comment
	   - comment: The comment text
	 */
	@objc optional func parser(_ parser: DTHTMLParser, foundComment comment: String)
	
	/**
	 Called when the parser encounters a processing instruction.
	 
	 - Parameters:
	   - parser: The parser that encountered the processing instruction
	   - target: The target of the processing instruction
	   - data: The data of the processing instruction
	 */
	@objc optional func parser(_ parser: DTHTMLParser, foundProcessingInstructionWithTarget target: String, data: String)
	
	/**
	 Called when the parser encounters an error.
	 
	 - Parameters:
	   - parser: The parser that encountered the error
	   - parseError: The error that occurred
	 */
	@objc optional func parser(_ parser: DTHTMLParser, parseErrorOccurred parseError: NSError)
}

#endif
