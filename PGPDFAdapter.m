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
#import "PGPDFAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

@interface PGPDFAdapter (Private)

- (NSPDFImageRep *)_rep;

@end

@implementation PGPDFAdapter

#pragma mark Private Protocol

- (NSPDFImageRep *)_rep
{
	return [[_rep retain] autorelease];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)canExtractData
{
	return YES;
}

#pragma mark PGResourceAdapter

- (PGLoadingPolicy)descendentLoadingPolicy
{
	return MAX(PGLoadAll, [[self parentAdapter] descendentLoadingPolicy]);
}
- (void)loadWithURLResponse:(NSURLResponse *)response
{
	NSData *data;
	if([self getData:&data] != PGDataReturned) return;
	if(![NSPDFImageRep canInitWithData:data]) return;
	_rep = [[NSPDFImageRep alloc] initWithData:data];
	if(!_rep) return;

	NSDictionary *const localeDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSMutableArray *const nodes = [NSMutableArray array];
	int i = 0;
	for(; i < [_rep pageCount]; i++) {
		PGResourceIdentifier *const identifier = [[self identifier] subidentifierWithIndex:i];
		[identifier setCustomDisplayName:[[NSNumber numberWithUnsignedInt:i + 1] descriptionWithLocale:localeDict] notify:NO];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:identifier] autorelease];
		if(!node) continue;
		[node setResourceAdapterClass:[PGPDFPageAdapter class]];
		[node loadIfNecessaryWithURLResponse:nil];
		[nodes addObject:node];
	}
	[self setUnsortedChildren:nodes presortedOrder:PGUnsorted];
}

#pragma mark NSObject

- (void)dealloc
{
	[_rep release];
	[super dealloc];
}

@end

@implementation PGPDFPageAdapter

#pragma mark PGResourceAdapter

- (void)read
{
	NSPDFImageRep *const rep = [(PGPDFAdapter *)[self parentAdapter] _rep];
	[rep setCurrentPage:[[self identifier] index]];
	[rep setPixelsWide:NSWidth([rep bounds])]; // Important on Panther, where this doesn't get set automatically.
	[rep setPixelsHigh:NSHeight([rep bounds])];
	[self readReturnedImageRep:rep error:nil];
}
- (BOOL)isResolutionIndependent
{
	return YES;
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		[self setIsImage:YES];
	}
	return self;
}

@end
