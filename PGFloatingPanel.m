#import "PGFloatingPanel.h"

// Models
#import "PGNode.h"

// Controllers
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGFloatingPanel (Private)

- (void)_updateNode:(PGDisplayController *)controller;

@end

@implementation PGFloatingPanel

- (PGNode *)node
{
	return [[_node retain] autorelease];
}
- (void)nodeChanged {}

#pragma mark -

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif
{
	[self _updateNode:nil];
}
- (void)windowDidBecomeMain:(NSNotification *)aNotif
{
	PGDisplayController *const c = aNotif ? [[aNotif object] windowController] : [[NSApp mainWindow] windowController];
	[c AE_addObserver:self selector:@selector(displayControllerActiveNodeDidChange:) name:PGDisplayControllerActiveNodeDidChangeNotification];
	[self _updateNode:c];
}
- (void)windowDidResignMain:(NSNotification *)aNotif
{
	[[[aNotif object] windowController] AE_removeObserver:self name:PGDisplayControllerActiveNodeDidChangeNotification];
	[self _updateNode:nil];
}

#pragma mark Private Protocol

- (void)_updateNode:(PGDisplayController *)controller
{
	PGDisplayController *const c = controller ? controller : [[NSApp mainWindow] windowController];
	[_node release];
	_node = [c respondsToSelector:@selector(activeNode)] ? [[c activeNode] retain] : nil;
	[self nodeChanged];
}

#pragma mark NSWindowController

- (id)initWithWindowNibName:(NSString *)name
{
	if((self = [super initWithWindowNibName:name])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeMain:) name:NSWindowDidBecomeMainNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignMain:) name:NSWindowDidResignMainNotification object:nil];
	}
	return self;
}
- (BOOL)shouldCascadeWindows
{
	return NO;
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_node release];
	[super dealloc];
}

@end
