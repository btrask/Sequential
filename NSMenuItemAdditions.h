#import <Cocoa/Cocoa.h>

@interface NSMenuItem (AEAdditions)

- (void)AE_addAfterItem:(NSMenuItem *)anItem;
- (void)AE_removeFromMenu;

@end
