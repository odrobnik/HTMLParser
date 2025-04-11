// DTHTMLParser-Bridging-Header.h

#ifndef DTHTMLParser_Bridging_Header_h
#define DTHTMLParser_Bridging_Header_h

#include <libxml/parser.h>
#include <libxml/HTMLParser.h>

// Function to format variadic arguments into a string and call a Swift handler
void htmlparser_error_sax_handler(void *ctx, const char *msg, ...);

// Function to set the error handler
void htmlparser_set_error_handler(htmlSAXHandlerPtr sax_handler);

#endif /* DTHTMLParser_Bridging_Header_h */
