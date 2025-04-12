import Foundation

import CHTMLParser

#if canImport(ClibXML2)
import CLibXML2
#else
import libxml2
#endif

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
	
	public var lineNumber: Int {
		return Int(xmlSAX2GetLineNumber(parserContext))
	}

	public var columnNumber: Int {
		return Int(xmlSAX2GetColumnNumber(parserContext))
	}

	public var systemID: String? {
		guard let systemID = xmlSAX2GetSystemId(parserContext) else { return nil }
		return String(cString: systemID)
	}

	public var publicID: String? {
		guard let publicID = xmlSAX2GetPublicId(parserContext) else { return nil }
		return String(cString: publicID)
	}

	public var error: Error? {
		return parserError
	}
	
	// MARK: - AsyncThrowingStream API
	
	public func parse() -> AsyncThrowingStream<HTMLParsingEvent, Error> {
		return AsyncThrowingStream { continuation in
			// Store the continuation
			self.currentContinuation = continuation
			
			// Configure handlers for the stream
			configureHandlersForStream()
			
			// Set up the parser
			let dataSize = data.count
			
			// Use the extension to convert Swift encoding to libxml2 encoding
			let charEnc = encoding.xmlCharEncoding
			
			parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, charEnc)
			
			htmlCtxtUseOptions(parserContext, options.rawValue)
			
			// Push the data in chunks to allow for error handling
			let chunkSize = 4096
			var offset = 0
			
			while offset < dataSize {
				let remainingSize = dataSize - offset
				let currentChunkSize = min(chunkSize, remainingSize)
				
				let chunk = data.subdata(in: offset..<(offset + currentChunkSize))
				_ = htmlParseChunk(parserContext, (chunk as NSData).bytes.assumingMemoryBound(to: Int8.self), Int32(currentChunkSize), 0)
				
				// Only check for abort here. Errors are handled by handleError when !shouldRecover
				if isAborting {
					// handleError or abortParsing should have already finished the continuation
					return
				}
				
				offset += currentChunkSize
			}
			
			// Complete the parsing
			_ = htmlParseChunk(parserContext, nil, 0, 1)
			
			// Only check for abort here. Errors are handled by handleError when !shouldRecover
			if isAborting {
				// handleError or abortParsing should have already finished the continuation
				return
			}
			
			// If we haven't finished due to error or abort, finish normally
			if currentContinuation != nil {
				continuation.finish()
			}
			
			// Clean up
			if let context = parserContext {
				htmlFreeParserCtxt(context)
				parserContext = nil
			}
			
			// Reset the continuation
			self.currentContinuation = nil
		}
	}

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
			
			guard let chars,
				  let characters = String(bytesNoCopy: UnsafeMutableRawPointer(mutating: chars), length: Int(len), encoding: .utf8, freeWhenDone: false)
			else { return }
			
			parser.accumulateCharacters(characters)
		}

		handler.comment = { context, chars in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let comment = String(cString: chars!)
			
			parser.currentContinuation?.yield(.comment(comment))
		}

		handler.cdataBlock = { context, value, len in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let data = Data(bytes: value!, count: Int(len))
			
			parser.currentContinuation?.yield(.cdata(data))
		}

		handler.processingInstruction = { context, target, data in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let targetString = String(cString: target!)
			let dataString = String(cString: data!)

			parser.currentContinuation?.yield(.processingInstruction(target: targetString, data: dataString))
		}
	}

	private func resetAccumulateBufferAndReportCharacters() {
		if let buffer = accumulateBuffer, !buffer.isEmpty {
			currentContinuation?.yield(.characters(buffer))
			accumulateBuffer = nil
		}
	}

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
	
	private func accumulateCharacters(_ string: String) {
		if accumulateBuffer == nil {
			accumulateBuffer = string
		} else {
			accumulateBuffer?.append(string)
		}
	}

	// Function to handle the formatted error message
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
