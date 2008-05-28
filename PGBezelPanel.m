#import "PGBezelPanel.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

NSString *const PGBezelPanelFrameShouldChangeNotification = @"PGBezelPanelFrameShouldChange";

NSString *const PGBezelPanelShouldAnimateKey = @"PGBezelPanelShouldAnimate";

@implementation PGBezelPanel

#pragma mark NSObject

+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
	if(@selector(cancelOperation:) == aSelector) return NO;
	if(@selector(performClose:) == aSelector) return NO;
	return [super instancesRespondToSelector:aSelector];
}

#pragma mark Instance Methods

- (id)initWithContentView:(NSView *)aView
{
	if((self = [super initWithContentRect:(NSRect){NSZeroPoint, [aView frame].size} styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES])) {
		[self setOpaque:NO];
		[self setBackgroundColor:[NSColor clearColor]];
		[self useOptimizedDrawing:YES];
		[self setHidesOnDeactivate:NO];
		[self setBecomesKeyOnlyIfNeeded:YES];
		[self setContentView:aView];
	}
	return self;
}
- (void)displayOverWindow:(NSWindow *)aWindow
{
	[self cancelFadeOut];
	if(aWindow != _parentWindow) [_parentWindow removeChildWindow:self];
	[self setIgnoresMouseEvents:!_acceptsEvents];

	[self setFrame:[[self contentView] bezelPanel:self frameForContentRect:[aWindow AE_contentRect] scale:[self AE_userSpaceScaleFactor]] display:NO];
	[aWindow addChildWindow:self ordered:NSWindowAbove];
}

#pragma mark -

- (BOOL)acceptsEvents
{
	return _acceptsEvents;
}
- (void)setAcceptsEvents:(BOOL)flag
{
	_acceptsEvents = flag;
}

#pragma mark -

- (void)changeFrameAnimate:(BOOL)flag
{
	if(!flag) PGDisableScreenUpdates();
	[self setFrame:[[self contentView] bezelPanel:self frameForContentRect:[_parentWindow AE_contentRect] scale:[self AE_userSpaceScaleFactor]] display:YES animate:flag];
	[self display];
	if(!flag) PGEnableScreenUpdates();
}

#pragma mark -

- (void)frameShouldChange:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self changeFrameAnimate:[[[aNotif userInfo] objectForKey:PGBezelPanelShouldAnimateKey] boolValue]];
}
- (void)windowDidResize:(NSNotification *)aNotif
{
	[self changeFrameAnimate:NO];
}

#pragma mark NSStandardKeyBindingMethods Protocol

- (void)cancelOperation:(id)sender
{
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark NSWindow

- (IBAction)performClose:(id)sender
{
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (BOOL)canBecomeKeyWindow
{
	return [self isFadingOut] ? NO : _acceptsEvents;
}
- (void)setContentView:(NSView *)aView
{
	[[self contentView] AE_removeObserver:self name:PGBezelPanelFrameShouldChangeNotification];
	[super setContentView:aView];
	[[self contentView] AE_addObserver:self selector:@selector(frameShouldChange:) name:PGBezelPanelFrameShouldChangeNotification];
}
- (void)setParentWindow:(NSWindow *)aWindow
{
	[_parentWindow AE_removeObserver:self name:NSWindowDidResizeNotification];
	[super setParentWindow:aWindow];
	_parentWindow = aWindow;
	[_parentWindow AE_addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification];
}
- (void)close
{
	[_parentWindow removeChildWindow:self];
	[super close];
}

#pragma mark -

// Insert the parent window before the initial first responder in the key view loop.
- (void)selectKeyViewFollowingView:(NSView *)aView
{
	if(![aView nextValidKeyView] || [aView nextValidKeyView] == [self initialFirstResponder]) {
		if([self makeFirstResponder:nil]) [_parentWindow makeKeyWindow];
	} else [super selectKeyViewFollowingView:aView];
}
- (void)selectKeyViewPrecedingView:(NSView *)aView
{
	if(!aView || aView == [self initialFirstResponder]) {
		if([self makeFirstResponder:nil]) [_parentWindow makeKeyWindow];
	} else [super selectKeyViewPrecedingView:aView];
}

#pragma mark NSObject

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if(@selector(cancelOperation:) == aSelector) return NO;
	if(@selector(performClose:) == aSelector) return NO;
	return [super respondsToSelector:aSelector];
}
- (void)dealloc
{
	[self AE_removeObserver];
	[super dealloc];
}

@end

@implementation NSView (PGBezelPanelContentView)

#pragma mark Class Methods

+ (id)PG_bezelPanel
{
	return [[[PGBezelPanel alloc] initWithContentView:[[[self alloc] initWithFrame:NSZeroRect] autorelease]] autorelease];
}

#pragma mark Instance Methods

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	return aRect;
}

@end
