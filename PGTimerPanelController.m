/* Copyright © 2007-2008, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGTimerPanelController.h"

// Controllers
#import "PGDisplayController.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSNumberAdditions.h"

#define PGTimerMax (NSTimeInterval)90

@interface PGTimerPanelController (Private)

- (void)_runTimerIfNeeded;
- (void)_updateOnTimer:(NSTimer *)timer;

@end

@implementation PGTimerPanelController

#pragma mark Instance Methods

- (IBAction)changeTimerInterval:(id)sender
{
	NSTimeInterval const interval = round([sender doubleValue]);
	NSTimeInterval const offPoint = ([intervalSlider maxValue] + PGTimerMax) / 2;
	[[self displayController] setTimerInterval:(interval > offPoint ? 0 : MIN(interval, PGTimerMax))];
	[intervalSlider setDoubleValue:(interval > offPoint ? DBL_MAX : MIN(interval, PGTimerMax))];
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
		[intervalSlider setDoubleValue:(fabs(interval) < 0.1 ? DBL_MAX : interval)];
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
