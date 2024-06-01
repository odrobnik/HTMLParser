import Foundation
import libxml2
import CHTMLParser

public class HTMLParser: NSObject
{
	@objc public weak var delegate: HTMLParserDelegate? {
		didSet {
			configureHandlers()
		}
	}

	private var data: Data
	private var encoding: String.Encoding
	private var parserContext: htmlParserCtxtPtr?
	private var handler: htmlSAXHandler
	private var accumulateBuffer: String?
	private var parserError: Error?
	private var isAborting = false

	public init?(data: Data, encoding: String.Encoding) {
		self.data = data
		self.encoding = encoding
		self.handler = htmlSAXHandler()
		super.init()
		initializeHandler()
	}

	deinit {
		if let context = parserContext {
			htmlFreeParserCtxt(context)
		}
	}

	private func initializeHandler() {
		configureHandlers()

		parserContext = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, XML_CHAR_ENCODING_NONE)
	}

	private func configureHandlers() {
		// Set all handlers first
		handler.startDocument = { context in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.delegate?.parserDidStartDocument?(parser)
		}

		handler.endDocument = { context in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.delegate?.parserDidEndDocument?(parser)
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
			parser.delegate?.parser?(parser, didStartElement: elementName, attributes: attributes)
		}

		handler.endElement = { context, name in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.resetAccumulateBufferAndReportCharacters()
			let elementName = String(cString: name!)
			parser.delegate?.parser?(parser, didEndElement: elementName)
		}

		handler.characters = { context, chars, len in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			parser.accumulateCharacters(chars, length: len)
		}

		handler.comment = { context, chars in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let comment = String(cString: chars!)
			parser.delegate?.parser?(parser, foundComment: comment)
		}

		handler.cdataBlock = { context, value, len in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let data = Data(bytes: value!, count: Int(len))
			parser.delegate?.parser?(parser, foundCDATA: data)
		}

		handler.processingInstruction = { context, target, data in
			let parser = Unmanaged<HTMLParser>.fromOpaque(context!).takeUnretainedValue()
			let targetString = String(cString: target!)
			let dataString = String(cString: data!)
			parser.delegate?.parser?(parser, foundProcessingInstructionWithTarget: targetString, data: dataString)
		}

		// Set the error handler function for the specific instance
		htmlparser_set_error_handler(&handler)

		// Null out handlers if the delegate does not respond to the methods
		if let delegate = delegate as? NSObjectProtocol
		{
			handler.startDocument = delegate.responds(to: #selector(HTMLParserDelegate.parserDidStartDocument(_:))) ? handler.startDocument : nil
			handler.endDocument = delegate.responds(to: #selector(HTMLParserDelegate.parserDidEndDocument(_:))) ? handler.endDocument : nil
			handler.characters = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:foundCharacters:))) ? handler.characters : nil
			handler.startElement = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:didStartElement:attributes:))) ? handler.startElement : nil
			handler.endElement = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:didEndElement:))) ? handler.endElement : (handler.characters != nil ? endElementNoDelegate : nil)
			handler.comment = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:foundComment:))) ? handler.comment : nil
			handler.error = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:parseErrorOccurred:))) ? handler.error : nil
			handler.cdataBlock = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:foundCDATA:))) ? handler.cdataBlock : nil
			handler.processingInstruction = delegate.responds(to: #selector(HTMLParserDelegate.parser(_:foundProcessingInstructionWithTarget:data:))) ? handler.processingInstruction : nil
		}
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
			delegate?.parser?(self, foundCharacters: buffer)
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

	// Function to handle the formatted error message
	@objc func handleError(_ message: UnsafePointer<CChar>) {
		let errorMessage = String(cString: message)
		let error = NSError(domain: "HTMLParser", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
		self.parserError = error
		delegate?.parser?(self, parseErrorOccurred: error)
	}
}

// Extern declaration to be called from C code
@_cdecl("swift_error_handler")
func swift_error_handler(_ ctx: UnsafeMutableRawPointer?, _ msg: UnsafePointer<CChar>?) {
	guard let context = ctx, let message = msg else { return }
	let parser = Unmanaged<HTMLParser>.fromOpaque(context).takeUnretainedValue()
	parser.handleError(message)
}
