#import "HMBlkSearchField.h"
#import "HMBlkSearchFieldCell.h"

@implementation HMBlkSearchField

#pragma mark NSCell

+ (Class)cellClass
{
	return [HMBlkSearchFieldCell class];
}

@end
