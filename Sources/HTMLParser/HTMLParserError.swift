import Foundation

/// Errors that can occur during HTML parsing
public enum HTMLParserError: Error, LocalizedError {
    /// The parser encountered an error during parsing
    case parsingError(message: String)
    
    /// The parser was aborted
    case aborted
    
    /// The parser encountered an unknown error
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .parsingError(let message):
            return message
        case .aborted:
            return "Parsing was aborted"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 