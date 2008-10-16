/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGCFMutableArray.h"

static CFIndex PGUnsignedToCFIndex(unsigned i)
{
	return NSNotFound == i ? kCFNotFound : (CFIndex)i;
}
static unsigned PGCFIndexToUnsigned(CFIndex i)
{
	return kCFNotFound == i ? NSNotFound : (unsigned)i;
}

@implementation PGCFMutableArray

#pragma mark PGExtendedMutableArray Protocol

- (id)initWithCallbacks:(CFArrayCallBacks const *)callbacks
{
	if((self = [super init])) {
		_array = CFArrayCreateMutable(kCFAllocatorDefault, 0, callbacks);
	}
	return self;
}

#pragma mark NSExtendedMutableArray Protocol

- (void)removeAllObjects
{
	CFArrayRemoveAllValues(_array);
}
- (void)addObjectsFromArray:(NSArray *)otherArray
{
	CFArrayAppendArray(_array, (CFArrayRef)otherArray, CFRangeMake(0, CFArrayGetCount((CFArrayRef)otherArray)));
}

#pragma mark NSExtendedArray Protocol

- (BOOL)containsObject:(id)anObject
{
	return kCFNotFound != CFArrayGetFirstIndexOfValue(_array, CFRangeMake(0, CFArrayGetCount(_array)), anObject);
}
- (NSString *)description
{
	return [(NSString *)CFCopyDescription(_array) autorelease];
}
- (BOOL)isEqualToArray:(NSArray *)otherArray
{
	return CFEqual(_array, (CFArrayRef)otherArray);
}
- (unsigned)indexOfObject:(id)anObject
              inRange:(NSRange)range
{
	return PGCFIndexToUnsigned(CFArrayGetFirstIndexOfValue(_array, CFRangeMake(PGUnsignedToCFIndex(range.location), PGUnsignedToCFIndex(range.length)), anObject));
}
- (unsigned)indexOfObjectIdenticalTo:(id)anObject
            inRange:(NSRange)range
{
	return [self indexOfObject:anObject inRange:range];
}

#pragma mark NSMutableArray

- (void)addObject:(id)anObject
{
	CFArrayAppendValue(_array, anObject);
}
- (void)insertObject:(id)anObject
        atIndex:(unsigned)index
{
	CFArrayInsertValueAtIndex(_array, PGUnsignedToCFIndex(index), anObject);
}
- (void)removeLastObject
{
	unsigned const count = [self count];
	if(count) CFArrayRemoveValueAtIndex(_array, PGUnsignedToCFIndex(count - 1));
}
- (void)removeObjectAtIndex:(unsigned)index
{
	CFArrayRemoveValueAtIndex(_array, PGUnsignedToCFIndex(index));
}
- (void)replaceObjectAtIndex:(unsigned)index
        withObject:(id)anObject
{
	CFArraySetValueAtIndex(_array, PGUnsignedToCFIndex(index), anObject);
}

#pragma mark NSArray

- (unsigned)count
{
	return PGCFIndexToUnsigned(CFArrayGetCount(_array));
}
- (id)objectAtIndex:(unsigned)index
{
	return (id)CFArrayGetValueAtIndex(_array, PGUnsignedToCFIndex(index));
}

#pragma mark NSObject

- (id)init
{
	return [self initWithCallbacks:NULL];
}
- (void)dealloc
{
	if(_array) CFRelease(_array);
	[super dealloc];
}

@end

@implementation NSMutableArray (PGExtendedMutableArray)

- (id)initWithCallbacks:(CFArrayCallBacks const *)callbacks
{
	[self release];
	return [[PGCFMutableArray alloc] initWithCallbacks:callbacks];
}

@end
