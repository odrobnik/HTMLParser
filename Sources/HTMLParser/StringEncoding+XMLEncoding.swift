import Foundation

#if canImport(ClibXML2)
import CLibXML2
#endif

#if canImport(libxml2)
import libxml2
#endif

/// Extension to convert Swift String.Encoding to libxml2's xmlCharEncoding
extension String.Encoding {
	/// Convert Swift String.Encoding to libxml2's xmlCharEncoding
	var xmlCharEncoding: xmlCharEncoding {
		switch self {
			case .utf8:
				return XML_CHAR_ENCODING_UTF8
			case .utf16LittleEndian:
				return XML_CHAR_ENCODING_UTF16LE
			case .utf16BigEndian:
				return XML_CHAR_ENCODING_UTF16BE
			case .utf32LittleEndian:
				return XML_CHAR_ENCODING_UCS4LE
			case .utf32BigEndian:
				return XML_CHAR_ENCODING_UCS4BE
			case .ascii:
				return XML_CHAR_ENCODING_ASCII
			case .isoLatin1:
				return XML_CHAR_ENCODING_8859_1
			case .japaneseEUC:
				return XML_CHAR_ENCODING_EUC_JP
			case .shiftJIS:
				return XML_CHAR_ENCODING_SHIFT_JIS
			case .iso2022JP:
				return XML_CHAR_ENCODING_2022_JP
			default:
				// For unsupported encodings, default to UTF-8
				return XML_CHAR_ENCODING_UTF8
		}
	}
}
