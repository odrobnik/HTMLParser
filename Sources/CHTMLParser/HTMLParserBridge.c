// DTHTMLParserBridge.c

#include "DTHTMLParser-Bridging-Header.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

void htmlparser_error_sax_handler(void *ctx, const char *msg, ...) {
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

void htmlparser_set_error_handler(htmlSAXHandlerPtr sax_handler) {
	if (sax_handler != NULL) {
		sax_handler->error = (errorSAXFunc)htmlparser_error_sax_handler;
	}
}
