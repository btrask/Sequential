#import <Cocoa/Cocoa.h>

// Views
@class PGAlertGraphic;

enum {
	PGSingleImageGraphic,
	PGInterImageGraphic
};
typedef unsigned PGAlertGraphicType;

@interface PGAlertView : NSView
{
	@private
	NSMutableArray *_graphicStack;
	PGAlertGraphic *_currentGraphic;
	unsigned        _frameCount;
	NSTimer        *_frameTimer;
}

- (PGAlertGraphic *)currentGraphic;
- (void)pushGraphic:(PGAlertGraphic *)aGraphic;
- (void)popGraphic:(PGAlertGraphic *)aGraphic;
- (void)popGraphicIdenticalTo:(PGAlertGraphic *)aGraphic;
- (void)popGraphicsOfType:(PGAlertGraphicType)type;

- (unsigned)frameCount;
- (void)animateOneFrame:(NSTimer *)aTimer;

- (void)windowWillClose:(NSNotification *)aNotif;

@end

@interface PGAlertGraphic : NSObject

+ (id)cannotGoRightGraphic;
+ (id)cannotGoLeftGraphic;
+ (id)loopedRightGraphic;
+ (id)loopedLeftGraphic;

- (PGAlertGraphicType)graphicType;

- (void)drawInView:(PGAlertView *)anAlertView;
- (void)flipHorizontally;

- (NSTimeInterval)fadeOutDelay; // 0 means forever.

- (NSTimeInterval)animationDelay; // 0 means don't animate.
- (unsigned)frameMax;
- (void)animateOneFrame:(PGAlertView *)anAlertView;

@end

@interface PGLoadingGraphic : PGAlertGraphic
{
	@private
	float _progress;
}

+ (id)loadingGraphic;

- (float)progress;
- (void)setProgress:(float)progress;

@end
