#import "NSMenuItemAdditions.h"

@implementation NSMenuItem (AEAdditions)

- (void)AE_addAfterItem:(NSMenuItem *)anItem
{
	NSMenu *const menu = [anItem menu];
	NSAssert(menu, @"Can't add item after an item not in a menu.");
	[menu insertItem:self atIndex:[menu indexOfItem:anItem] + 1];
}
- (void)AE_removeFromMenu
{
	[[self menu] removeItem:self];
}

@end
