//
//  HTMLParserOptions.h
//
//
//  Created by Oliver Drobnik on 01.06.24.
//

// HTMLParserOptions.h


#ifndef HTMLParserOptions_h
#define HTMLParserOptions_h

#if defined(__OBJC__) && __has_feature(objc_modules)
  // Objective-C + modules = can use Foundation
  #import <Foundation/Foundation.h>
  typedef NS_OPTIONS(int32_t, HTMLParserOptions) {
	  HTMLParserOptionRecover   = 1 << 0,
	  HTMLParserOptionNoError   = 1 << 1,
	  HTMLParserOptionNoWarning = 1 << 2,
	  HTMLParserOptionPedantic  = 1 << 3,
	  HTMLParserOptionNoBlanks  = 1 << 4,
	  HTMLParserOptionNoNet     = 1 << 5,
	  HTMLParserOptionCompact   = 1 << 6
  };
#else
  // Pure C / Linux-compatible version
  typedef int32_t HTMLParserOptions;
  enum {
	  HTMLParserOptionRecover   = 1 << 0,
	  HTMLParserOptionNoError   = 1 << 1,
	  HTMLParserOptionNoWarning = 1 << 2,
	  HTMLParserOptionPedantic  = 1 << 3,
	  HTMLParserOptionNoBlanks  = 1 << 4,
	  HTMLParserOptionNoNet     = 1 << 5,
	  HTMLParserOptionCompact   = 1 << 6
  };
#endif

#endif /* HTMLParserOptions_h */
