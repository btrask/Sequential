/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGExifEntry.h"

// Other
#import "PGByteOrdering.h"

// External
#import "exif.h"

enum {
	PGExifOrientationTag = 0x0112,
};

@implementation PGExifEntry

#pragma mark Class Methods

+ (NSData *)exifDataWithImageData:(NSData *)data
{
	if([data length] < 2 || 0xFFD8 != CFSwapInt16BigToHost(*(uint16_t *)[data bytes])) return nil;
	unsigned offset = 2;
	while(offset + 18 < [data length]) {
		void const *const bytes = [data bytes] + offset;
		uint16_t const type = CFSwapInt16BigToHost(*(uint16_t *)(bytes + 0));
		if(0xFFDA == type) break;
		uint16_t const size = CFSwapInt16BigToHost(*(uint16_t *)(bytes + 2));
		if(0xFFE1 != type) {
			offset += 2 + size;
			continue;
		}
		if(size < 18) break;
		if(0x45786966 != CFSwapInt32BigToHost(*(uint32_t *)(bytes + 4))) break;
		if(0 != *(uint16_t *)(bytes + 8)) break;
		return [data subdataWithRange:NSMakeRange(offset + 4, size - 2)];
	}
	return nil;
}
+ (void)getEntries:(out NSArray **)outEntries
        orientation:(out PGOrientation *)outOrientation
        forImageData:(NSData *)data
{
	NSMutableArray *const entries = [NSMutableArray array];
	PGOrientation orientation = PGUpright;
	NSData *const exifData = [self exifDataWithImageData:data];
	struct exiftags *const tags = exifData ? exifparse((unsigned char *)[exifData bytes], [exifData length]) : NULL;
	if(!tags) {
		if(outEntries) *outEntries = [NSArray array];
		if(outOrientation) *outOrientation = PGUpright;
		return;
	}

	struct exifprop *entry = tags->props;
	for(; entry; entry = entry->next) {
		if(entry->lvl != ED_CAM && entry->lvl != ED_IMG) continue;
		if(PGExifOrientationTag == entry->tag) switch(entry->value) {
			case 2: orientation = PGFlippedHorz; break;
			case 3: orientation = PGUpsideDown; break;
			case 4: orientation = PGFlippedVert; break;
			case 5: orientation = PGRotated90CC | PGFlippedHorz; break;
			case 6: orientation = PGRotated270CC; break;
			case 7: orientation = PGRotated90CC | PGFlippedVert; break;
			case 8: orientation = PGRotated90CC; break;
		}
		[entries addObject:[[[self alloc] initWithLabel:[NSString stringWithCString:(entry->descr ? entry->descr : entry->name)] value:(entry->str ? [NSString stringWithCString:entry->str] : [NSString stringWithFormat:@"%u", entry->value])] autorelease]];
	}

	exiffree(tags);
	if(outEntries) *outEntries = [entries sortedArrayUsingSelector:@selector(compare:)];
	if(outOrientation) *outOrientation = orientation;
}

#pragma mark Instance Methods

- (id)initWithLabel:(NSString *)label
	  value:(NSString *)value
{
	if((self = [super init])) {
		_label = [label copy];
		_value = [value copy];
	}
	return self;
}
- (NSString *)label
{
	return [[_label retain] autorelease];
}
- (NSString *)value
{
	return [[_value retain] autorelease];
}
- (NSComparisonResult)compare:(PGExifEntry *)anEntry
{
	return [[self label] compare:[anEntry label] options:NSCaseInsensitiveSearch | NSNumericSearch];
}

#pragma mark NSObject

- (void)dealloc
{
	[_label release];
	[_value release];
	[super dealloc];
}

@end
