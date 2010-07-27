#include <sys/param.h>

#ifndef BSD
// Kludge for reallocf() on Linux
#define reallocf realloc
#endif
