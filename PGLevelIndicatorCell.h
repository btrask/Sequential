#import <Cocoa/Cocoa.h>

@interface PGLevelIndicatorCell : NSCell
{
	@private
	BOOL _hidden;
}

- (BOOL)hidden;
- (void)setHidden:(BOOL)flag;

@end
