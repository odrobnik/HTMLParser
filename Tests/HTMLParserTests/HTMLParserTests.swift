import XCTest
@testable import HTMLParser

class TestHTMLParserDelegate: HTMLParserDelegate {
	func parser(_ parser: HTMLParser, parseErrorOccurred parseError: NSError) {
		
	}
	
    var events: [(String, Any)] = []
    
    func parserDidStartDocument(_ parser: HTMLParser) {
        events.append(("startDocument", ""))
    }
    
    func parserDidEndDocument(_ parser: HTMLParser) {
        events.append(("endDocument", ""))
    }
    
    func parser(_ parser: HTMLParser, didStartElement elementName: String, attributes: [String : String]) {
        events.append(("startElement", (elementName, attributes)))
    }
    
    func parser(_ parser: HTMLParser, didEndElement elementName: String) {
        events.append(("endElement", elementName))
    }
    
    func parser(_ parser: HTMLParser, foundCharacters string: String) {
        // Only add non-whitespace character events
        if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            events.append(("characters", string))
        }
    }
    
    func parser(_ parser: HTMLParser, foundComment comment: String) {
        events.append(("comment", comment))
    }
    
    func parser(_ parser: HTMLParser, foundCDATA CDATABlock: Data) {
        events.append(("cdata", CDATABlock))
    }
    
    func parser(_ parser: HTMLParser, foundProcessingInstructionWithTarget target: String, data: String) {
        events.append(("processingInstruction", (target, data)))
    }
    
    func parser(_ parser: HTMLParser, parseErrorOccurred parseError: Error) {
        events.append(("error", parseError))
    }
}

final class HTMLParserTests: XCTestCase {
    func testSimpleHTMLParsing() throws {
        // Create a simple HTML document
        let html = """
        <!DOCTYPE html>
        <html>
            <head>
                <title>Test Page</title>
            </head>
            <body>
                <h1>Hello World</h1>
                <p>This is a test paragraph.</p>
                <!-- This is a comment -->
            </body>
        </html>
        """
        
        let data = html.data(using: .utf8)!
        let delegate = TestHTMLParserDelegate()
        let parser = HTMLParser(data: data, encoding: .utf8)
        parser.delegate = delegate
        
        // Parse the document
        let success = parser.parse()
        XCTAssertTrue(success, "Parsing should succeed")
        
        // Print actual events for debugging
        print("Actual events:")
        for (index, (type, value)) in delegate.events.enumerated() {
            print("\(index): \(type) - \(value)")
        }
        
        // Verify the events
        let expectedEvents: [(String, Any)] = [
            ("startDocument", ""),
            ("startElement", ("html", [:])),
            ("startElement", ("head", [:])),
            ("startElement", ("title", [:])),
            ("characters", "Test Page"),
            ("endElement", "title"),
            ("endElement", "head"),
            ("startElement", ("body", [:])),
            ("startElement", ("h1", [:])),
            ("characters", "Hello World"),
            ("endElement", "h1"),
            ("startElement", ("p", [:])),
            ("characters", "This is a test paragraph."),
            ("endElement", "p"),
            ("comment", " This is a comment "),
            ("endElement", "body"),
            ("endElement", "html"),
            ("endDocument", "")
        ]
        
        XCTAssertEqual(delegate.events.count, expectedEvents.count, "Should receive the correct number of events")
        
        for (index, (expectedType, expectedValue)) in expectedEvents.enumerated() {
            let (actualType, actualValue) = delegate.events[index]
            XCTAssertEqual(actualType, expectedType, "Event type mismatch at index \(index)")
            
            if let expectedTuple = expectedValue as? (String, [String: String]),
               let actualTuple = actualValue as? (String, [String: String]) {
                XCTAssertEqual(actualTuple.0, expectedTuple.0, "Element name mismatch at index \(index)")
                XCTAssertEqual(actualTuple.1, expectedTuple.1, "Attributes mismatch at index \(index)")
            } else if let expectedTuple = expectedValue as? (String, String),
                      let actualTuple = actualValue as? (String, String) {
                XCTAssertEqual(actualTuple.0, expectedTuple.0, "Processing instruction target mismatch at index \(index)")
                XCTAssertEqual(actualTuple.1, expectedTuple.1, "Processing instruction data mismatch at index \(index)")
            } else {
                XCTAssertEqual(String(describing: actualValue), String(describing: expectedValue), "Value mismatch at index \(index)")
            }
        }
    }
}

