#import <Cocoa/Cocoa.h>

@interface PGMainThreadProxy : NSProxy
{
	@private
	id _target;
}

- (id)initWithTarget:(id)anObject;

@end
