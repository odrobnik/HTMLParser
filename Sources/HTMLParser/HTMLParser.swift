import Foundation

import CHTMLParser

#if canImport(ClibXML2)
import CLibXML2
#endif

// https://opensource.apple.com/source/libxml2/libxml2-21/libxml2/doc/html/libxml-HTMLparser.html

public final class HTMLParser
{
	// Input
	
	private var data: Data
	private var encoding: String.Encoding
	
	// Parser State
	
	private var parserContext: htmlParserCtxtPtr?
	private var handler: htmlSAXHandler
	private var accumulateBuffer: String?
	private var parserError: HTMLParserError?
	private var isAborting = false
	private var currentContinuation: AsyncThrowingStream<HTMLParsingEvent, Error>.Continuation?
	
	// MARK: - Init / Deinit
	
	public init(data: Data, encoding: String.Encoding)
	{
		self.data = data
		self.encoding = encoding
		self.handler = htmlSAXHandler()
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
	
	@discardableResult
	public func parse() -> Bool
	{
		let dataBytes = (data as NSData).bytes
		let dataSize = data.count

		var charEnc: xmlCharEncoding = XML_CHAR_ENCODING_NONE

		if encoding == .utf8 {
			charEnc = XML_CHAR_ENCODING_UTF8
		}

		parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), dataBytes, Int32(dataSize), nil, charEnc)

		let options: HTMLParserOptions = [.recover, .noNet, .compact, .noBlanks]
		htmlCtxtUseOptions(parserContext, options.rawValue)

		let result = htmlParseDocument(parserContext)

		return result == 0 && !isAborting
	}
	
	// MARK: - AsyncThrowingStream API
	
	public func parse() -> AsyncThrowingStream<HTMLParsingEvent, Error> {
		return AsyncThrowingStream { continuation in
			// Store the continuation
			self.currentContinuation = continuation
			
			// Configure handlers for the stream
			configureHandlersForStream()
			
			// Set up the parser
			let dataBytes = (data as NSData).bytes
			let dataSize = data.count
			
			var charEnc: xmlCharEncoding = XML_CHAR_ENCODING_NONE
			if encoding == .utf8 {
				charEnc = XML_CHAR_ENCODING_UTF8
			}
			
			parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), dataBytes, Int32(dataSize), nil, charEnc)
			
			let options: HTMLParserOptions = [.recover, .noNet, .compact, .noBlanks]
			htmlCtxtUseOptions(parserContext, options.rawValue)
			
			// Start parsing
			let result = htmlParseDocument(parserContext)
			
			// Check for errors
			if result != 0 || isAborting {
				if let error = parserError {
					continuation.finish(throwing: error)
				} else {
					continuation.finish(throwing: HTMLParserError.parsingError(message: "Parsing failed"))
				}
			} else {
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
			if let error = parserError {
				continuation.finish(throwing: error)
			} else {
				continuation.finish(throwing: HTMLParserError.aborted)
			}
			currentContinuation = nil
		}
	}
	
	// MARK: - Helpers
	
	private func configureHandlersForStream() {
		// Set all handlers first
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
			parser.resetAccumulateBufferAndReportCharacters()
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
			parser.currentContinuation?.yield(.startElement(name: elementName, attributes: attributes))
		}

		handler.endElement = { context, name in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.resetAccumulateBufferAndReportCharacters()
			let elementName = String(cString: name!)
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

		// Set the error handler function for the specific instance
		htmlparser_set_error_handler(&handler)
	}

	private var startElementNoDelegate: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<xmlChar>?, UnsafePointer<UnsafePointer<xmlChar>?>?) -> Void {
		return { context, name, atts in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.resetAccumulateBufferAndReportCharacters()
		}
	}

	private var endElementNoDelegate: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<xmlChar>?) -> Void {
		return { context, name in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.resetAccumulateBufferAndReportCharacters()
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

	// Function to handle the formatted error message
	func handleError(_ errorMessage: String)
	{
		let error = HTMLParserError.parsingError(message: errorMessage)
		self.parserError = error
		
		// If we have a continuation, finish it with an error
		if let continuation = currentContinuation {
			continuation.finish(throwing: error)
			currentContinuation = nil
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
