#import <Cocoa/Cocoa.h>

@interface PGLevelIndicatorCell : NSLevelIndicatorCell
{
	@private
	BOOL _hidden;
}

- (BOOL)hidden;
- (void)setHidden:(BOOL)flag;

@end
