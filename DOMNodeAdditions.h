#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface DOMNode (AEAdditions)

- (void)AE_getLinkedURLs:(NSMutableArray *)array validExtensions:(NSArray *)exts;
- (void)AE_getEmbeddedImageURLs:(NSMutableArray *)array;

@end
