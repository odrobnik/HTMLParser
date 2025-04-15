import Foundation

import CHTMLParser

#if canImport(ClibXML2)
import CLibXML2
#endif

/**
 A Swift wrapper around libxml2's HTML parser that provides a streaming interface for parsing HTML documents.
 */
public final class HTMLParser: @unchecked Sendable
{
	// Input
	
	private let data: Data?
	private let url: URL?
	private let encoding: String.Encoding
	private let options: HTMLParserOptions
	private let session: URLSession
	
	// Parser State
	
	internal var parserContext: htmlParserCtxtPtr?
	private var handler: htmlSAXHandler
	private var accumulateBuffer: String?
	private var parserError: HTMLParserError?
	private var isAborting = false
	private var currentContinuation: AsyncThrowingStream<HTMLParsingEvent, Error>.Continuation?
	
	// MARK: - Init / Deinit
	
	/**
	 Creates a new HTML parser instance with data.
	 
	 - Parameters:
	   - data: The HTML data to parse
	   - encoding: The character encoding of the HTML data (defaults to UTF-8)
	   - options: Parser options to control parsing behavior
	 */
	public init(data: Data, encoding: String.Encoding = .utf8, options: HTMLParserOptions = [.noNet, .noBlanks, .recover])
	{
		self.data = data
		self.url = nil
		self.encoding = encoding
		self.options = options
		self.session = .shared
		self.handler = htmlSAXHandler()
		
		// Set up the error handler
		htmlparser_set_error_handler(&handler)
	}
	
	/**
	 Creates a new HTML parser instance with a URL.
	 
	 - Parameters:
	   - url: The URL to load HTML data from
	   - encoding: The character encoding of the HTML data (defaults to UTF-8)
	   - options: Parser options to control parsing behavior
	   - session: The URL session to use for loading data (defaults to .shared)
	 */
	public init(url: URL, encoding: String.Encoding = .utf8, options: HTMLParserOptions = [.noNet, .noBlanks, .recover], session: URLSession = .shared)
	{
		self.data = nil
		self.url = url
		self.encoding = encoding
		self.options = options
		self.session = session
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
			let charEnc = encoding.xmlCharEncoding
			
			// Create a push parser context
			parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, charEnc)
			
			htmlCtxtUseOptions(parserContext, options.rawValue)
			
			// Create a task to handle the async work
			Task { @Sendable in
				do {
					// If we have data, parse it directly
					if let data = self.data {
						let bytes = (data as NSData).bytes.assumingMemoryBound(to: Int8.self)
						let dataSize = data.count
						
						// Feed the data to the parser
						htmlParseChunk(parserContext, bytes, Int32(dataSize), 0)
						
						// Check for errors
						if let error = self.parserError {
							throw error
						}
					}
					
					// If we have a URL, handle it based on the scheme
					else if let url = self.url {
						if url.isFileURL {
							// For file URLs, read the file in chunks
							let fileHandle = try FileHandle(forReadingFrom: url)
							defer { try? fileHandle.close() }
							
							// Read the file in chunks
							while true {
								let chunk = fileHandle.readData(ofLength: 8192) // 8KB chunks
								guard !chunk.isEmpty else { break }
								
								// Convert chunk to bytes
								let bytes = (chunk as NSData).bytes.assumingMemoryBound(to: Int8.self)
								let dataSize = chunk.count
								
								// Feed the chunk to the parser
								htmlParseChunk(parserContext, bytes, Int32(dataSize), 0)
								
								// Check for errors
								if let error = self.parserError {
									throw error
								}
							}
						} else {
							// For network URLs, use ChunkLoader
							let loader = ChunkLoader(url: url, session: session)
							
							// Load chunks and feed them to the parser
							for try await chunk in loader.loadChunks() {
								// Convert chunk to bytes
								let bytes = (chunk as NSData).bytes.assumingMemoryBound(to: Int8.self)
								let dataSize = chunk.count
								
								// Feed the chunk to the parser
								htmlParseChunk(parserContext, bytes, Int32(dataSize), 0)
								
								// Check for errors
								if let error = self.parserError {
									throw error
								}
							}
						}
					}
					
					// Finish parsing
					htmlParseChunk(parserContext, nil, 0, 1)
					
					// Check for errors
					if let error = self.parserError {
						throw error
					}
					
					// Finish the stream
					continuation.finish()
				} catch {
					// Handle errors
					continuation.finish(throwing: error)
				}
				
				// Clean up
				if let context = parserContext {
					htmlFreeParserCtxt(context)
					parserContext = nil
				}
			}
			
			// Set up cancellation
			continuation.onTermination = { @Sendable _ in
				self.abortParsing()
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
		
		// Create a buffer with the correct length
		let buffer = UnsafeBufferPointer(start: characters, count: Int(length))
		
		// Convert to Data and then to String
		let data = Data(buffer: buffer)
		if let str = String(data: data, encoding: .utf8) {
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
