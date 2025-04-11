import Foundation

/// Represents events that can occur during HTML parsing.
public enum HTMLParsingEvent: Equatable {
    /// Called when the parser begins parsing the document.
    case startDocument
    
    /// Called when the parser finishes parsing the document.
    case endDocument
    
    /// Called when the parser encounters the start of an element.
    /// - Parameters:
    ///   - name: The name of the element.
    ///   - attributes: A dictionary of attribute names and values.
    case startElement(name: String, attributes: [String: String])
    
    /// Called when the parser encounters the end of an element.
    /// - Parameter name: The name of the element.
    case endElement(name: String)
    
    /// Called when the parser encounters character data.
    /// - Parameter string: The character data.
    case characters(String)
    
    /// Called when the parser encounters a comment.
    /// - Parameter comment: The comment text.
    case comment(String)
    
    /// Called when the parser encounters a CDATA section.
    /// - Parameter CDATABlock: The CDATA content as Data.
    case cdata(Data)
    
    /// Called when the parser encounters a processing instruction.
    /// - Parameters:
    ///   - target: The target of the processing instruction.
    ///   - data: The data of the processing instruction.
    case processingInstruction(target: String, data: String)
    
    /// Compares two HTMLParsingEvent values for equality.
    public static func == (lhs: HTMLParsingEvent, rhs: HTMLParsingEvent) -> Bool {
        switch (lhs, rhs) {
        case (.startDocument, .startDocument):
            return true
        case (.endDocument, .endDocument):
            return true
        case (.startElement(let name1, let attrs1), .startElement(let name2, let attrs2)):
            return name1 == name2 && attrs1 == attrs2
        case (.endElement(let name1), .endElement(let name2)):
            return name1 == name2
        case (.characters(let str1), .characters(let str2)):
            return str1 == str2
        case (.comment(let comment1), .comment(let comment2)):
            return comment1 == comment2
        case (.cdata(let data1), .cdata(let data2)):
            return data1 == data2
        case (.processingInstruction(let target1, let data1), .processingInstruction(let target2, let data2)):
            return target1 == target2 && data1 == data2
        default:
            return false
        }
    }
} 