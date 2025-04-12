import Foundation

import CHTMLParser

#if canImport(ClibXML2)
import CLibXML2
#else
import libxml2
#endif

/**
 A Swift wrapper around libxml2's HTML parser that provides a streaming interface for parsing HTML documents.
 */
public final class HTMLParser
{
	// Input
	
	private let data: Data
	private let encoding: String.Encoding
	private let options: HTMLParserOptions
	
	// Parser State
	
	private var parserContext: htmlParserCtxtPtr?
	private var handler: htmlSAXHandler
	private var accumulateBuffer: String?
	private var parserError: HTMLParserError?
	private var isAborting = false
	private var currentContinuation: AsyncThrowingStream<HTMLParsingEvent, Error>.Continuation?
	
	// MARK: - Init / Deinit
	
	/**
	 Creates a new HTML parser instance.
	 
	 - Parameters:
	   - data: The HTML data to parse
	   - encoding: The character encoding of the HTML data (defaults to UTF-8)
	   - options: Parser options to control parsing behavior
	 */
	public init(data: Data, encoding: String.Encoding = .utf8, options: HTMLParserOptions = [.noNet, .noBlanks, .recover])
	{
		self.data = data
		self.encoding = encoding
		self.options = options
		self.handler = htmlSAXHandler()
		
		// Set up the error handler
		htmlparser_set_error_handler(&handler)
	}

	deinit {
		
		if let context = parserContext {
			htmlFreeParserCtxt(context)
		}
	}
	
	// MARK: - Public Methods
	
	/**
	 The current line number being parsed.
	 */
	public var lineNumber: Int {
		return Int(xmlSAX2GetLineNumber(parserContext))
	}

	/**
	 The current column number being parsed.
	 */
	public var columnNumber: Int {
		return Int(xmlSAX2GetColumnNumber(parserContext))
	}

	/**
	 The system ID of the document being parsed.
	 */
	public var systemID: String? {
		guard let systemID = xmlSAX2GetSystemId(parserContext) else { return nil }
		return String(cString: systemID)
	}

	/**
	 The public ID of the document being parsed.
	 */
	public var publicID: String? {
		guard let publicID = xmlSAX2GetPublicId(parserContext) else { return nil }
		return String(cString: publicID)
	}

	/**
	 The current parsing error, if any.
	 */
	public var error: Error? {
		return parserError
	}
	
	// MARK: - AsyncThrowingStream API
	
	/**
	 Parses the HTML document and returns a stream of parsing events.
	 
	 - Returns: An async stream that yields HTML parsing events
	 */
	public func parse() -> AsyncThrowingStream<HTMLParsingEvent, Error> {
		return AsyncThrowingStream { continuation in
			// Store the continuation
			self.currentContinuation = continuation
			
			// Configure handlers for the stream
			configureHandlersForStream()
			
			// Set up the parser
			let bytes = (data as NSData).bytes.assumingMemoryBound(to: Int8.self)
			let dataSize = data.count
			
			// Use the extension to convert Swift encoding to libxml2 encoding
			let charEnc = encoding.xmlCharEncoding
			
			parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), bytes, Int32(dataSize), nil, charEnc)
			
			htmlCtxtUseOptions(parserContext, options.rawValue)
			
			let result = htmlParseDocument(parserContext)

			// Clean up
			if let context = parserContext {
				htmlFreeParserCtxt(context)
				parserContext = nil
			}
			
			// If we haven't finished due to error or abort, finish normally
			if currentContinuation != nil {
				
				if result == 0 || options.contains(.recover) || isAborting
				{
					continuation.finish()
				}
				else if let error = self.parserError
				{
					continuation.finish(throwing: error)
				}
				else
				{
					continuation.finish(throwing: HTMLParserError.unknown)
				}
				
				// Reset the continuation
				self.currentContinuation = nil
			}
		}
	}

	/**
	 Aborts the current parsing operation.
	 */
	public func abortParsing()
	{
		if parserContext != nil {
			xmlStopParser(parserContext)
			parserContext = nil
		}

		isAborting = true
		parserError = .aborted

		handler.startDocument = nil
		handler.endDocument = nil
		handler.startElement = nil
		handler.endElement = nil
		handler.characters = nil
		handler.comment = nil
		handler.error = nil
		handler.processingInstruction = nil

		// If we have a continuation, finish it with an error
		if let continuation = currentContinuation {
			continuation.finish(throwing: HTMLParserError.aborted)
			currentContinuation = nil
		}
	}
	
	// MARK: - Helpers
	
	/**
	 Configures the SAX handler callbacks for the parser.
	 */
	private func configureHandlersForStream() {
		handler.startDocument = { context in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			
			parser.currentContinuation?.yield(.startDocument)
		}

		handler.endDocument = { context in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			
			parser.currentContinuation?.yield(.endDocument)
		}

		handler.startElement = { context, name, atts in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let elementName = String(cString: name!)
			
			var attributes = [String: String]()
			var i = 0
			while let att = atts?[i] {
				let key = String(cString: att)
				i += 1
				if let valueAtt = atts?[i] {
					let value = String(cString: valueAtt)
					attributes[key] = value
				}
				i += 1
			}
			
			parser.resetAccumulateBufferAndReportCharacters()
			parser.currentContinuation?.yield(.startElement(name: elementName, attributes: attributes))
		}

		handler.endElement = { context, name in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let elementName = String(cString: name!)
			
			parser.resetAccumulateBufferAndReportCharacters()
			parser.currentContinuation?.yield(.endElement(name: elementName))
		}

		handler.characters = { context, chars, len in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.accumulateCharacters(chars, length: len)
		}

		handler.comment = { context, chars in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let comment = String(cString: chars!)
			
			parser.currentContinuation?.yield(.comment(comment))
		}

		handler.processingInstruction = { context, target, data in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let targetString = String(cString: target!)
			let dataString = String(cString: data!)

			parser.currentContinuation?.yield(.processingInstruction(target: targetString, data: dataString))
		}
	}

	/**
	 Resets the character accumulation buffer and reports any accumulated characters.
	 */
	private func resetAccumulateBufferAndReportCharacters() {
		if let buffer = accumulateBuffer, !buffer.isEmpty {
			currentContinuation?.yield(.characters(buffer))
			accumulateBuffer = nil
		}
	}

	/**
	 Accumulates characters from the parser.
	 
	 - Parameter characters: The characters to accumulate
	 */
	private func accumulateCharacters(_ characters: UnsafePointer<xmlChar>?, length: Int32) {
		guard let characters = characters else { return }
		let str = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: characters), length: Int(length), encoding: .utf8, freeWhenDone: false)
		if let str = str {
			if accumulateBuffer == nil {
				accumulateBuffer = str
			} else {
				accumulateBuffer?.append(str)
			}
		}
	}
	
	/**
	 Handles parser errors.
	 
	 - Parameter errorMessage: The error message from the parser
	 */
	func handleError(_ errorMessage: String)
	{
		let error = HTMLParserError.parsingError(message: errorMessage)
		self.parserError = error // Always record the error
		
		// If we have a continuation and we're not in recovery mode, *always* finish with error
		if let continuation = currentContinuation, !options.contains(.recover) {
			continuation.finish(throwing: error)
			currentContinuation = nil // Mark as finished
		}
	}
}

// Extern declaration to be called from C code
@_cdecl("swift_error_handler")
func swift_error_handler(_ ctx: UnsafeMutableRawPointer?, _ msg: UnsafePointer<CChar>?) {
	guard let context = ctx,
			let message = msg else
	{
		return
	}

	let parser = Unmanaged<HTMLParser>.fromOpaque(context).takeUnretainedValue()
	let errorMessage = String(cString: message)

	parser.handleError(errorMessage)
}
