// DTHTMLParserBridge.c

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "DTHTMLParser-Bridging-Header.h"

// Forward declaration of the Swift error handling function
extern void swift_error_handler(void *ctx, const char *msg);

// C function to forward the formatted message to the Swift handler
static void forward_to_swift_error_handler(void *ctx, const char *formatted_msg) {
	// Check if the message indicates an ignored warning/error type if necessary
	// Example: ignore specific warnings if needed
	// if (strstr(formatted_msg, "some specific warning text") != NULL) {
	//     return; 
	// }
	swift_error_handler(ctx, formatted_msg);
}

// Generic error handler function conforming to the 'error' callback signature
// void (*error) (void *ctx, const char *msg, ...);
static void generic_error_handler(void *ctx, const char *msg, ...) {
	va_list args;
	va_start(args, msg);

	// Determine the required buffer size
	// vsnprintf returns the number of characters that *would* have been written
	va_list args_copy;
	va_copy(args_copy, args);
	int len = vsnprintf(NULL, 0, msg, args_copy);
	va_end(args_copy);

	if (len < 0) {
		// Encoding error
		va_end(args);
		// Optionally call swift handler with a generic error message
		forward_to_swift_error_handler(ctx, "Error formatting libxml2 message");
		return;
	}

	// Allocate buffer (+1 for null terminator)
	char *formatted_msg = (char *)malloc(len + 1);
	if (!formatted_msg) {
		va_end(args);
		// Optionally call swift handler with memory allocation error
		forward_to_swift_error_handler(ctx, "Memory allocation failed for error message");
		return;
	}

	// Format the message into the buffer
	vsnprintf(formatted_msg, len + 1, msg, args);
	va_end(args);

	// Forward the formatted message to Swift
	forward_to_swift_error_handler(ctx, formatted_msg);

	// Free the allocated buffer
	free(formatted_msg);
}

// Function callable from Swift to set the generic error handler
void htmlparser_set_error_handler(htmlSAXHandler *handler) {
	if (handler != NULL) {
		// Set the generic error handler function pointer
		handler->error = generic_error_handler;
		// Ensure structured error handler is NULL if not used, 
		// or set it appropriately if needed.
		handler->serror = NULL; 
	}
}
