/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGTimerPanelController.h"

// Controllers
#import "PGDisplayController.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSNumberAdditions.h"

#define PGTimerMax 90.0f

@interface PGTimerPanelController (Private)

- (void)_runTimerIfNeeded;
- (void)_updateOnTimer:(NSTimer *)timer;

@end

@implementation PGTimerPanelController

#pragma mark Instance Methods

- (IBAction)changeTimerInterval:(id)sender
{
	float const interval = round(pow([sender doubleValue], 2.0));
	[[self displayController] setTimerInterval:(interval > PGTimerMax ? 0 : interval)];
	[intervalSlider setDoubleValue:(interval > PGTimerMax ? FLT_MAX : sqrt(interval))];
}

#pragma mark -

- (void)displayControllerTimerDidChange:(NSNotification *)aNotif
{
	[self _runTimerIfNeeded];
	[self _updateOnTimer:nil];
}

#pragma mark Private Protocol

- (void)_runTimerIfNeeded
{
	if([self isShown] && [self displayController] && [[self displayController] timerInterval]) {
		if(_updateTimer) return;
		_updateTimer = [[NSTimer timerWithTimeInterval:1.0 / 24.0 target:[self PG_nonretainedObjectProxy] selector:@selector(_updateOnTimer:) userInfo:nil repeats:YES] retain];
		[[NSRunLoop currentRunLoop] addTimer:_updateTimer forMode:PGCommonRunLoopsMode];
	} else {
		if(!_updateTimer) return;
		[_updateTimer invalidate];
		[_updateTimer release];
		_updateTimer = nil;
	}
}
- (void)_updateOnTimer:(NSTimer *)timer
{
	NSDate *const fireDate = [[self displayController] nextTimerFireDate];
	NSTimeInterval timeRemaining = fireDate ? [fireDate timeIntervalSinceNow] : 0;
	if(timeRemaining < 0) timeRemaining = 0;
	NSTimeInterval const interval = [self displayController] ? [[self displayController] timerInterval] : 0;

	[progressIndicator setFloatValue:(interval ? (interval - timeRemaining) / interval : 0)];

	[remainingField setStringValue:(interval ? [NSString stringWithFormat:NSLocalizedString(@"%@ seconds", @"Display string for timer intervals. %@ is replaced with the remaining seconds and tenths of seconds."), [[NSNumber numberWithDouble:timeRemaining] AE_localizedStringWithFractionDigits:1]] : NSLocalizedString(@"---", @"Display string for no timer interval."))];

	if(!timer) {
		[totalField setStringValue:(interval ? [NSString stringWithFormat:NSLocalizedString(@"%@ seconds", @"Display string for timer intervals. %@ is replaced with the remaining seconds and tenths of seconds."), [[NSNumber numberWithDouble:interval] AE_localizedStringWithFractionDigits:1]] : NSLocalizedString(@"---", @"Display string for no timer interval."))];
		[intervalSlider setDoubleValue:(interval ? sqrt(interval) : FLT_MAX)];
		[intervalSlider setEnabled:!![self displayController]];
	}
}

#pragma mark PGFloatingPanelController

- (void)setShown:(BOOL)flag
{
	[super setShown:flag];
	[self _runTimerIfNeeded];
}
- (BOOL)setDisplayController:(PGDisplayController *)controller
{
	PGDisplayController *const oldController = [self displayController];
	if(![super setDisplayController:controller]) return NO;
	[oldController AE_removeObserver:self name:PGDisplayControllerTimerDidChangeNotification];
	PGDisplayController *const newController = [self displayController];
	[newController AE_addObserver:self selector:@selector(displayControllerTimerDidChange:) name:PGDisplayControllerTimerDidChangeNotification];
	[self _runTimerIfNeeded];
	[self _updateOnTimer:nil];
	return YES;
}
- (NSString *)nibName
{
	return @"PGTimer";
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self _updateOnTimer:nil];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:@"PGTimer"];
}
- (void)dealloc
{
	[self AE_removeObserver];
	[_updateTimer invalidate];
	[_updateTimer release];
	[super dealloc];
}

@end
