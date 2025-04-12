//
//  DTHTMLParser.swift
//  HTMLParser
//
//  Created by Oliver Drobnik on 12.04.25.
//

#if !os(Linux)

import Foundation

/**
 A Swift wrapper around the HTMLParser that provides an Objective-C compatible interface.
 
 This class is designed to be used from Objective-C code, providing a delegate-based API
 for parsing HTML documents. It internally uses the modern Swift HTMLParser with its
 async stream of events, but presents a synchronous interface to Objective-C code.
 
 This class is not available on Linux platforms.
 */
@objc(DTHTMLParser)
public final class DTHTMLParser: NSObject, @unchecked Sendable
{
	/**
	 The delegate that will receive parsing events.
	 */
	public weak var delegate: DTHTMLParserDelegate?
	
	// Parser properties
	private var data: Data
	private var encoding: String.Encoding
	private var htmlParser: HTMLParser?
	private var isAborting = false
	
	// Private serial queue for parsing operations
	private let parsingQueue = DispatchQueue(label: "htmlparser.parsing", qos: .userInitiated)
	
	/**
	 Creates a new HTML parser instance.
	 
	 - Parameters:
	   - data: The HTML data to parse
	   - encoding: The character encoding of the HTML data (defaults to UTF-8)
	 */
	public init(data: Data, encoding: String.Encoding = .utf8)
	{
		self.data = data
		self.encoding = encoding
		super.init()
	}
	
	// MARK: - Public Methods
	
	/**
	 The current line number being parsed.
	 */
	public var lineNumber: Int {
		return htmlParser?.lineNumber ?? 0
	}

	/**
	 The current column number being parsed.
	 */
	public var columnNumber: Int {
		return htmlParser?.columnNumber ?? 0
	}

	/**
	 The system ID of the document being parsed.
	 */
	public var systemID: String? {
		return htmlParser?.systemID
	}

	/**
	 The public ID of the document being parsed.
	 */
	public var publicID: String? {
		return htmlParser?.publicID
	}
	
	/**
	 Parses the HTML document and reports events to the delegate.
	 
	 This method is synchronous and will block the current thread until parsing is complete.
	 It internally uses an asynchronous stream of events from the HTMLParser, but presents
	 a synchronous interface to Objective-C code.
	 */
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
	
	/**
	 Aborts the current parsing operation.
	 
	 This method can be called from any thread to stop the parsing operation.
	 The delegate will be notified of the abort through the parseErrorOccurred method.
	 */
	public func abort()
	{
		isAborting = true
		htmlParser?.abortParsing()
	}
}

#endif
