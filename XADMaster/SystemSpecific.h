#import <sys/param.h>

#ifndef BSD
// Kludge for reallocf() on Linux
#define reallocf realloc
#endif

#ifndef __cplusplus

// Find the name of an external resource. OS X uses bundles, others might not.
#ifdef __APPLE__

#import "XADArchiveParser.h"

static inline NSString *PathForExternalResource(NSString *resname)
{
	return [[NSBundle bundleForClass:[XADArchiveParser class]] pathForResource:resname ofType:nil];
}

#endif

#endif
