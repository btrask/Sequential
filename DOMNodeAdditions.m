#import "DOMNodeAdditions.h"

@implementation DOMNode (AEAdditions)

- (void)AE_getLinkedURLs:(NSMutableArray *)array
        validExtensions:(NSArray *)exts
{
	DOMNodeList *const list = [self childNodes];
	unsigned i = 0;
	unsigned const count = [list length];
	for(; i < count; i++) [[list item:i] AE_getLinkedURLs:array validExtensions:exts];
}
- (void)AE_getEmbeddedImageURLs:(NSMutableArray *)array
{
	DOMNodeList *const list = [self childNodes];
	unsigned i = 0;
	unsigned const count = [list length];
	for(; i < count; i++) [[list item:i] AE_getEmbeddedImageURLs:array];
}

@end

@implementation DOMHTMLAnchorElement (AEAdditions)

- (void)AE_getLinkedURLs:(NSMutableArray *)array
        validExtensions:(NSArray *)exts
{
	NSString *const href = [self href];
	if(!exts || [exts containsObject:[href pathExtension]]) {
		NSURL *const URL = [NSURL URLWithString:href];
		if(![array containsObject:URL]) [array addObject:URL];
	}
	[super AE_getLinkedURLs:array validExtensions:exts];
}

@end

@implementation DOMHTMLImageElement (AEAdditions)

- (void)AE_getEmbeddedImageURLs:(NSMutableArray *)array
{
	NSURL *const URL = [NSURL URLWithString:[self src]];
	if(![array containsObject:URL]) [array addObject:URL];
	[super AE_getEmbeddedImageURLs:array];
}

@end
