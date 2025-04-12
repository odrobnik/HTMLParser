import Foundation
@testable import HTMLParser

import Testing

@Suite("HTMLParser Tests")
struct HTMLParserTests {
	
	@Test("Simple Test")
	func testSimple() throws {
		#expect(Bool(true), "This test should always pass")
	}
	
	@Test("Basic HTML Parsing")
	func testBasicHTMLParsing() async throws {
		// Create a simple HTML document
		let htmlString = """
		<!DOCTYPE html>
		<html>
		<head>
			<title>Test Page</title>
			<!-- This is a comment -->
			<meta charset="utf-8">
		</head>
		<body>
			<h1>Hello, World!</h1>
			<p>This is a <b>test</b> paragraph.</p>
			<![CDATA[This is CDATA content]]>
			<?xml-stylesheet type="text/css" href="style.css"?>
		</body>
		</html>
		"""
		
		// Convert to Data
		let htmlData = Data(htmlString.utf8)
		
		// Create parser
		let parser = HTMLParser(data: htmlData, encoding: .utf8)
		
		// Collect events
		var events: [HTMLParsingEvent] = []
		
		// Parse and collect events
		for try await event in parser.parse() {
			events.append(event)
		}
		
		// Verify events
		#expect(events.count > 0, "Should have parsed at least one event")
		
		// Check for specific events
		#expect(events.contains { 
			if case .startDocument = $0 { return true }
			return false
		}, "Should have a startDocument event")
		
		#expect(events.contains { 
			if case .endDocument = $0 { return true }
			return false
		}, "Should have an endDocument event")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "html" { return true }
			return false
		}, "Should have a startElement event for html")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "head" { return true }
			return false
		}, "Should have a startElement event for head")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "title" { return true }
			return false
		}, "Should have a startElement event for title")
		
		#expect(events.contains { 
			if case .characters(let text) = $0, text == "Test Page" { return true }
			return false
		}, "Should have a characters event for 'Test Page'")
		
		#expect(events.contains { 
			if case .comment(let text) = $0, text == " This is a comment " { return true }
			return false
		}, "Should have a comment event")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "body" { return true }
			return false
		}, "Should have a startElement event for body")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "h1" { return true }
			return false
		}, "Should have a startElement event for h1")
		
		#expect(events.contains { 
			if case .characters(let text) = $0, text == "Hello, World!" { return true }
			return false
		}, "Should have a characters event for 'Hello, World!'")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "p" { return true }
			return false
		}, "Should have a startElement event for p")
		
		#expect(events.contains { 
			if case .startElement(let name, _) = $0, name == "b" { return true }
			return false
		}, "Should have a startElement event for b")
		
		#expect(events.contains { 
			if case .characters(let text) = $0, text == "test" { return true }
			return false
		}, "Should have a characters event for 'test'")
		
		#expect(events.contains { 
			if case .processingInstruction(let target, let data) = $0, target == "xml-stylesheet" && data.contains("type=\"text/css\"") { return true }
			return false
		}, "Should have a processingInstruction event")
	}
	
	@Test("Error Handling")
	func testErrorHandling() async throws {
		// Create an invalid HTML document (completely unclosed)
		let invalidHTML = "<html<"
		let htmlData = Data(invalidHTML.utf8)
		
		// Create parser, disabling recovery to make it throw errors
		let parser = HTMLParser(data: htmlData, encoding: .utf8, options: [.noNet])  // no .recover so that we get error
		
		// Try to parse and expect an error
		do {
			for try await _ in parser.parse() {
				// Should not reach here
			}
			#expect(Bool(false), "Expected an error to be thrown")
		} catch {
			// Verify it's our custom error type
			#expect(error is HTMLParserError, "Error should be of type HTMLParserError")
			
			// Check the error description
			if let parserError = error as? HTMLParserError {
				switch parserError {
					case .parsingError(let message):
						#expect(!message.isEmpty, "Error message should not be empty")
					default:
						#expect(Bool(false), "Expected a parsingError")
				}
			}
		}
	}
	
	@Test("Abort Parsing")
	func testAbortParsing() async throws {
		// Create a simple HTML document
		let htmlString = "<html><body><div>Test</div></body></html>"
		let htmlData = Data(htmlString.utf8)
		
		// Create parser
		let parser = HTMLParser(data: htmlData, encoding: .utf8)
		
		// Start parsing in a task
		do {
			for try await _ in parser.parse() {
				// Abort parsing after the first event
				parser.abortParsing()
				break
			}
		} catch {
			print(error)
			// Expected error
		}
		
		
		// Verify the parser was aborted
		#expect(parser.error is HTMLParserError, "Error should be of type HTMLParserError")
		
		// Check if the error is the aborted case without using Equatable
		if let parserError = parser.error as? HTMLParserError {
			switch parserError {
				case .aborted:
					// This is the expected case
					break
				default:
					#expect(Bool(false), "Error should be .aborted, but got \(parserError)")
			}
		} else {
			#expect(Bool(false), "Error should be of type HTMLParserError")
		}
	}
	
	@Test("DTHTMLParser Delegate Pattern")
	func testDTHTMLParserDelegate() throws {
		#if !os(Linux)
		// Create a simple HTML document
		let htmlString = """
		<!DOCTYPE html>
		<html>
			<head>
				<title>Test Page</title>
				<!-- This is a comment -->
			</head>
			<body>
				<h1>Hello World</h1>
				<p>This is a <b>test</b> paragraph.</p>
			</body>
		</html>
		"""
		
		// Convert to Data
		let htmlData = Data(htmlString.utf8)
		
		// Create a delegate to collect events
		class TestDelegate: NSObject, DTHTMLParserDelegate {
			var events: [(String, Any)] = []
			
			func parserDidStartDocument(_ parser: DTHTMLParser) {
				events.append(("startDocument", ""))
			}
			
			func parserDidEndDocument(_ parser: DTHTMLParser) {
				events.append(("endDocument", ""))
			}
			
			func parser(_ parser: DTHTMLParser, didStartElement elementName: String, attributes attributeDict: [String : String]) {
				events.append(("startElement", (elementName, attributeDict)))
			}
			
			func parser(_ parser: DTHTMLParser, didEndElement elementName: String) {
				events.append(("endElement", elementName))
			}
			
			func parser(_ parser: DTHTMLParser, foundCharacters string: String) {
				// Only add non-whitespace character events
				if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					events.append(("characters", string))
				}
			}
			
			func parser(_ parser: DTHTMLParser, foundComment comment: String) {
				events.append(("comment", comment))
			}
		}
		
		// Create parser and delegate
		let delegate = TestDelegate()
		let parser = DTHTMLParser(data: htmlData, encoding: .utf8)
		parser.delegate = delegate
		
		// Parse the document
		parser.parse()
		
		// Verify events
		#expect(delegate.events.count > 0, "Should have parsed at least one event")
		
		// Expected events in order
		let expectedEvents: [(String, Any)] = [
			("startDocument", ""),
			("startElement", ("html", [:])),
			("startElement", ("head", [:])),
			("startElement", ("title", [:])),
			("characters", "Test Page"),
			("endElement", "title"),
			("comment", " This is a comment "),
			("endElement", "head"),
			("startElement", ("body", [:])),
			("startElement", ("h1", [:])),
			("characters", "Hello World"),
			("endElement", "h1"),
			("startElement", ("p", [:])),
			("characters", "This is a "),
			("startElement", ("b", [:])),
			("characters", "test"),
			("endElement", "b"),
			("characters", " paragraph."),
			("endElement", "p"),
			("endElement", "body"),
			("endElement", "html"),
			("endDocument", "")
		]
		
		// Verify event count
		#expect(delegate.events.count == expectedEvents.count, "Should have the correct number of events")
		
		// Verify each event
		for (index, (expectedType, expectedValue)) in expectedEvents.enumerated() {
			let (actualType, actualValue) = delegate.events[index]
			#expect(actualType == expectedType, "Event type mismatch at index \(index)")
			
			if let expectedTuple = expectedValue as? (String, [String: String]),
			   let actualTuple = actualValue as? (String, [String: String]) {
				#expect(actualTuple.0 == expectedTuple.0, "Element name mismatch at index \(index)")
				#expect(actualTuple.1 == expectedTuple.1, "Attributes mismatch at index \(index)")
			} else {
				#expect(String(describing: actualValue) == String(describing: expectedValue), "Value mismatch at index \(index)")
			}
		}
		#endif
	}
}
