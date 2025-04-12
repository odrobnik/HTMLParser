//
//  DTHTMLParser.swift
//  HTMLParser
//
//  Created by Oliver Drobnik on 12.04.25.
//

import Foundation

// Make the class conform to Sendable to allow it to be used in concurrent contexts
@objc(DTHTMLParser)
public final class DTHTMLParser: NSObject, @unchecked Sendable
{
	public weak var delegate: DTHTMLParserDelegate?
	
	// Parser properties
	private var data: Data
	private var encoding: String.Encoding
	private var htmlParser: HTMLParser?
	private var isAborting = false
	
	// Private serial queue for parsing operations
	private let parsingQueue = DispatchQueue(label: "htmlparser.parsing", qos: .userInitiated)
	
	public init(data: Data, encoding: String.Encoding = .utf8)
	{
		self.data = data
		self.encoding = encoding
		super.init()
	}
	
	public func parse()
	{
		// Create the HTML parser with the data
		let options: HTMLParserOptions = [.recover, .noNet, .compact, .noBlanks]
		htmlParser = HTMLParser(data: data, encoding: encoding, options: options)
		
		// Create a semaphore to wait for the async task to complete
		let semaphore = DispatchSemaphore(value: 0)
		
		// Use our private serial queue for parsing
		parsingQueue.async {
			// Create a task to process the async stream
			Task {
				do {
					// Get the stream of parsing events
					let stream = self.htmlParser!.parse()
					
					// Process each event and call the appropriate delegate method
					for try await event in stream {
						switch event {
							case .startDocument:
								self.delegate?.parserDidStartDocument?(self)
								
							case .endDocument:
								self.delegate?.parserDidEndDocument?(self)
								
							case .startElement(let name, let attributes):
								self.delegate?.parser?(self, didStartElement: name, attributes: attributes)
								
							case .endElement(let name):
								self.delegate?.parser?(self, didEndElement: name)
								
							case .characters(let string):
								self.delegate?.parser?(self, foundCharacters: string)
								
							case .comment(let comment):
								self.delegate?.parser?(self, foundComment: comment)
								
							case .processingInstruction(let target, let data):
								self.delegate?.parser?(self, foundProcessingInstructionWithTarget: target, data: data)
						}
					}
				} catch {
					// Convert the error to NSError and report it to the delegate
					let nsError = error as NSError
					
					self.parsingQueue.async {
						self.delegate?.parser?(self, parseErrorOccurred: nsError)
					}
				}
				
				// Signal the semaphore to indicate completion
				semaphore.signal()
			}
		}
		
		// Wait for the semaphore to be signaled
		semaphore.wait()
	}
	
	public func abort()
	{
		isAborting = true
		htmlParser?.abortParsing()
	}
}
