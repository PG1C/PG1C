#include <stdarg.h>
#include <stdio.h>

char error_last[1024] = "";

const char *ERRORS[] = {
	"No error",                                                       // 8000
	"Cannot create socket (errno %d,%s)",                             // 8001
	"Cannot connect to %s:%d (errno %d,%s)",                          // 8002
	"Cannot start WSA (errno %d)",                                    // 8003
	"Cannot close socket (errno %d,%s)",                              // 8004
	"Cannot send to socket (errno %d,%s)",                            // 8005
	"No data to recieve from socket",                                 // 8006
	"Error on recieved data from socket (errno %d,%s)",               // 8007
	"No free space to recieve data from TCP socket (%d bytes used)",  // 8008
	"HTTP error (code %d):\n%s",                                      // 8009
	"Cannot allocate memory (%d bytes)",                              // 8010
	"Incorrect HTTP request parameters",                              // 8011
	"Cannot get IP-address for hostname \"%s\" (%serrno %d)",         // 8012
	"Incorrect HTTP response headers",                                // 8013
	"Unauthorized (HTTP code 401), check login/password",             // 8014
	"Unrecognized error"                                              //
};

int error_return(int code, ...) {
	int len = snprintf(error_last, sizeof(error_last), "PG1C-%d ", code);
    va_list args;
    va_start(args, &code);
	vsnprintf(error_last+len, sizeof(error_last)-len, ERRORS[code-8000], args);
    va_end(args);
   	return 1;
}

void error_last_get(char *error, size_t error_size) {
	strncpy(error, error_last, error_size);
}
