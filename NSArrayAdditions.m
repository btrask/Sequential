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
#import "NSArrayAdditions.h"

// Categories
#import "NSObjectAdditions.h"

@implementation NSArray (AEAdditions)

- (NSArray *)AE_arrayWithUniqueObjects
{
	NSMutableArray *const array = [[self mutableCopy] autorelease];
	unsigned i = 0, count;
	for(; i < (count = [array count]); i++) [array removeObject:[array objectAtIndex:i] inRange:NSMakeRange(i + 1, count - i - 1)];
	return array;
}
- (void)AE_addObjectObserver:(id)observer
        selector:(SEL)aSelector
        name:(NSString *)aName
{
	id obj;
	NSEnumerator *const objEnum = [self objectEnumerator];
	while((obj = [objEnum nextObject])) [obj AE_addObserver:observer selector:aSelector name:aName];
}
- (void)AE_removeObjectObserver:(id)observer
        name:(NSString *)aName
{
	id obj;
	NSEnumerator *const objEnum = [self objectEnumerator];
	while((obj = [objEnum nextObject])) [obj AE_removeObserver:observer name:aName];
}

@end
