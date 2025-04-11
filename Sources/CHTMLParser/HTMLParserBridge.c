// DTHTMLParserBridge.c

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <libxml/parser.h>

/**
 Handles SAX parser errors by formatting the error message and passing it to a Swift handler.
 
 @param ctx A context pointer passed to the handler.
 @param msg A format string for the error message.
 @param ... Additional arguments for the format string.
 
 @discussion
 This function is necessary when using Swift because Swift's native error handling and
 string formatting mechanisms are different from those in C. By creating a C function
 that formats the error message and then calls a Swift function (`swift_error_handler`),
 we can seamlessly integrate C-based error handling with Swift's error management system.
 This allows for better interoperability and ensures that error messages generated by
 the SAX parser are correctly handled and displayed within a Swift application.
 */
void htmlparser_error_sax_handler(void *ctx, const char *msg, ...)
{
	if (ctx == NULL) return;

	va_list args;
	va_start(args, msg);

	// Determine the length of the formatted string
	int length = vsnprintf(NULL, 0, msg, args);
	va_end(args);

	if (length < 0) return;

	// Allocate memory for the formatted string
	char *formattedMsg = (char *)malloc((length + 1) * sizeof(char));
	if (!formattedMsg) return;

	// Format the string
	va_start(args, msg);
	vsnprintf(formattedMsg, length + 1, msg, args);
	va_end(args);

	// Call the Swift handler
	extern void swift_error_handler(void *ctx, const char *msg);
	swift_error_handler(ctx, formattedMsg);

	// Free the allocated memory
	free(formattedMsg);
}


/**
 Sets the error handler in the SAX handler structure.
 
 @param sax_handler A pointer to the SAX handler structure.
 */
void htmlparser_set_error_handler(htmlSAXHandlerPtr sax_handler) 
{
	if (sax_handler != NULL) 
	{
		sax_handler->error = (errorSAXFunc)htmlparser_error_sax_handler;
	}
}
