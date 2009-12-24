/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGCFMutableArray.h"

@interface PGCFMutableArray : NSMutableArray
{
	@private
	CFMutableArrayRef _array;
}
@end

@implementation NSMutableArray(PGExtendedMutableArray)

- (id)initWithCallbacks:(CFArrayCallBacks const *)callbacks
{
	[self release];
	return [[PGCFMutableArray alloc] initWithCallbacks:callbacks];
}

@end

static CFIndex PGNSUIntegerToCFIndex(NSUInteger i)
{
	return NSNotFound == i ? kCFNotFound : (CFIndex)i;
}
static NSUInteger PGCFIndexToNSUInteger(CFIndex i)
{
	return kCFNotFound == i ? NSNotFound : (NSUInteger)i;
}

@implementation PGCFMutableArray

#pragma mark -NSMutableArray

- (void)addObject:(id)anObject
{
	CFArrayAppendValue(_array, anObject);
}
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index
{
	CFArrayInsertValueAtIndex(_array, PGNSUIntegerToCFIndex(index), anObject);
}
- (void)removeLastObject
{
	NSUInteger const count = [self count];
	if(count) CFArrayRemoveValueAtIndex(_array, PGNSUIntegerToCFIndex(count - 1));
}
- (void)removeObjectAtIndex:(NSUInteger)index
{
	CFArrayRemoveValueAtIndex(_array, PGNSUIntegerToCFIndex(index));
}
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject
{
	CFArraySetValueAtIndex(_array, PGNSUIntegerToCFIndex(index), anObject);
}

#pragma mark -NSMutableArray(NSExtendedMutableArray)

- (void)removeAllObjects
{
	CFArrayRemoveAllValues(_array);
}
- (void)addObjectsFromArray:(NSArray *)otherArray
{
	CFArrayAppendArray(_array, (CFArrayRef)otherArray, CFRangeMake(0, CFArrayGetCount((CFArrayRef)otherArray)));
}
- (void)removeObject:(id)anObject inRange:(NSRange)range
{
	CFIndex const start = PGNSUIntegerToCFIndex(range.location);
	CFIndex i = PGNSUIntegerToCFIndex(NSMaxRange(range));
	while(kCFNotFound != (i = CFArrayGetLastIndexOfValue(_array, CFRangeMake(start, i - start), anObject))) CFArrayRemoveValueAtIndex(_array, i);
}
- (void)removeObject:(id)anObject
{
	return [self removeObject:anObject inRange:NSMakeRange(0, [self count])];
}
- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	return [self removeObject:anObject inRange:range];
}
- (void)removeObjectIdenticalTo:(id)anObject
{
	return [self removeObjectIdenticalTo:anObject inRange:NSMakeRange(0, [self count])];
}

#pragma mark -NSMutableArray(PGExtendedMutableArray)

- (id)initWithCallbacks:(CFArrayCallBacks const *)callbacks
{
	if((self = [super init])) {
		_array = CFArrayCreateMutable(kCFAllocatorDefault, 0, callbacks);
	}
	return self;
}

#pragma mark -NSArray

- (NSUInteger)count
{
	return PGCFIndexToNSUInteger(CFArrayGetCount(_array));
}
- (id)objectAtIndex:(NSUInteger)index
{
	return (id)CFArrayGetValueAtIndex(_array, PGNSUIntegerToCFIndex(index));
}

#pragma mark -NSArray(NSExtendedArray)

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
- (NSUInteger)indexOfObject:(id)anObject inRange:(NSRange)range
{
	return PGCFIndexToNSUInteger(CFArrayGetFirstIndexOfValue(_array, CFRangeMake(PGNSUIntegerToCFIndex(range.location), PGNSUIntegerToCFIndex(range.length)), anObject));
}
- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range
{
	return [self indexOfObject:anObject inRange:range];
}

#pragma mark -NSObject

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
