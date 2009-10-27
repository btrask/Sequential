/* Copyright © 2007-2009, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGPrefObject.h"
#import <tgmath.h>

// Other Sources
#import "PGFoundationAdditions.h"

NSString *const PGPrefObjectShowsInfoDidChangeNotification = @"PGPrefObjectShowsInfoDidChange";
NSString *const PGPrefObjectShowsThumbnailsDidChangeNotification = @"PGPrefObjectShowsThumbnailsDidChange";
NSString *const PGPrefObjectReadingDirectionDidChangeNotification = @"PGPrefObjectReadingDirectionDidChange";
NSString *const PGPrefObjectImageScaleDidChangeNotification = @"PGPrefObjectImageScaleDidChange";
NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification = @"PGPrefObjectUpscalesToFitScreenDidChange";
NSString *const PGPrefObjectAnimatesImagesDidChangeNotification = @"PGPrefObjectAnimatesImagesDidChange";
NSString *const PGPrefObjectSortOrderDidChangeNotification = @"PGPrefObjectSortOrderDidChange";
NSString *const PGPrefObjectTimerIntervalDidChangeNotification = @"PGPrefObjectTimerIntervalDidChange";

NSString *const PGPrefObjectAnimateKey = @"PGPrefObjectAnimate";

static NSString *const PGShowsInfoKey = @"PGShowsInfo";
static NSString *const PGShowsThumbnailsKey = @"PGShowsThumbnails";
static NSString *const PGReadingDirectionRightToLeftKey = @"PGReadingDirectionRightToLeft";
static NSString *const PGImageScaleModeKey = @"PGImageScaleMode";
static NSString *const PGImageScaleFactorKey = @"PGImageScaleFactor";
static NSString *const PGAnimatesImagesKey = @"PGAnimatesImages";
static NSString *const PGSortOrderKey = @"PGSortOrder2";
static NSString *const PGTimerIntervalKey = @"PGTimerInterval";

static NSString *const PGSortOrderDeprecatedKey = @"PGSortOrder"; // Deprecated after 1.3.2.

NSArray *PGScaleModes(void)
{
	return [NSArray arrayWithObjects:[NSNumber numberWithInteger:PGConstantFactorScale], [NSNumber numberWithInteger:PGAutomaticScale], [NSNumber numberWithInteger:PGViewFitScale], [NSNumber numberWithInteger:PGActualSizeWithDPI], nil];
}

@implementation PGPrefObject

#pragma mark +PGPrefObject

+ (id)globalPrefObject
{
	static PGPrefObject *obj = nil;
	if(!obj) obj = [[self alloc] init];
	return obj;
}

#pragma mark +NSObject

+ (void)initialize
{
	if([PGPrefObject class] != self) return;
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], PGShowsInfoKey,
		[NSNumber numberWithBool:YES], PGShowsThumbnailsKey,
		[NSNumber numberWithBool:NO], PGReadingDirectionRightToLeftKey,
		[NSNumber numberWithInteger:PGConstantFactorScale], PGImageScaleModeKey,
		[NSNumber numberWithDouble:1.0f], PGImageScaleFactorKey,
		[NSNumber numberWithBool:YES], PGAnimatesImagesKey,
		[NSNumber numberWithInteger:PGSortByName | PGSortRepeatMask], PGSortOrderKey,
		[NSNumber numberWithDouble:30.0f], PGTimerIntervalKey,
		nil]];
}

#pragma mark -PGPrefObject

- (BOOL)showsInfo
{
	return _showsInfo;
}
- (void)setShowsInfo:(BOOL)flag
{
	if(!flag == !_showsInfo) return;
	_showsInfo = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGShowsInfoKey];
	[self PG_postNotificationName:PGPrefObjectShowsInfoDidChangeNotification];
}
- (BOOL)showsThumbnails
{
	return _showsThumbnails;
}
- (void)setShowsThumbnails:(BOOL)flag
{
	if(!flag == !_showsThumbnails) return;
	_showsThumbnails = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGShowsThumbnailsKey];
	[self PG_postNotificationName:PGPrefObjectShowsThumbnailsDidChangeNotification];
}

#pragma mark -

- (PGReadingDirection)readingDirection
{
	return _readingDirection;
}
- (void)setReadingDirection:(PGReadingDirection)aDirection
{
	if(aDirection == _readingDirection) return;
	_readingDirection = aDirection;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:aDirection == PGReadingDirectionRightToLeft] forKey:PGReadingDirectionRightToLeftKey];
	[self PG_postNotificationName:PGPrefObjectReadingDirectionDidChangeNotification];
}

#pragma mark -

- (PGImageScaleMode)imageScaleMode
{
	return _imageScaleMode;
}
- (void)setImageScaleMode:(PGImageScaleMode)aMode
{
	_imageScaleMode = aMode;
	_imageScaleFactor = 1;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:aMode] forKey:PGImageScaleModeKey];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:1] forKey:PGImageScaleFactorKey];
	[self PG_postNotificationName:PGPrefObjectImageScaleDidChangeNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], PGPrefObjectAnimateKey, nil]];
}

- (CGFloat)imageScaleFactor
{
	return _imageScaleFactor;
}
- (void)setImageScaleFactor:(CGFloat)factor
{
	[self setImageScaleFactor:factor animate:YES];
}
- (void)setImageScaleFactor:(CGFloat)factor animate:(BOOL)flag
{
	NSParameterAssert(factor > 0.0f);
	CGFloat const newFactor = fabs(1.0f - factor) < 0.01f ? 1.0f : factor; // If it's close to 1, fudge it.
	_imageScaleFactor = newFactor;
	_imageScaleMode = PGConstantFactorScale;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:newFactor] forKey:PGImageScaleFactorKey];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:PGConstantFactorScale] forKey:PGImageScaleModeKey];
	[self PG_postNotificationName:PGPrefObjectImageScaleDidChangeNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:flag], PGPrefObjectAnimateKey, nil]];
}

#pragma mark -

- (BOOL)animatesImages
{
	return _animatesImages;
}
- (void)setAnimatesImages:(BOOL)flag
{
	if(!flag == !_animatesImages) return;
	_animatesImages = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGAnimatesImagesKey];
	[self PG_postNotificationName:PGPrefObjectAnimatesImagesDidChangeNotification];
}

#pragma mark -

- (PGSortOrder)sortOrder
{
	return _sortOrder;
}
- (void)setSortOrder:(PGSortOrder)anOrder
{
	if(anOrder == _sortOrder) return;
	_sortOrder = anOrder;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:anOrder] forKey:PGSortOrderKey];
	[self PG_postNotificationName:PGPrefObjectSortOrderDidChangeNotification];
}

#pragma mark -

- (NSTimeInterval)timerInterval
{
	return _timerInterval;
}
- (void)setTimerInterval:(NSTimeInterval)interval
{
	if(interval == _timerInterval) return;
	_timerInterval = interval;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:interval] forKey:PGTimerIntervalKey];
	[self PG_postNotificationName:PGPrefObjectTimerIntervalDidChangeNotification];
}

#pragma mark -

- (BOOL)isCurrentSortOrder:(PGSortOrder)order
{
	return (PGSortOrderMask & order) == (PGSortOrderMask & self.sortOrder);
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		NSUserDefaults *const d = [NSUserDefaults standardUserDefaults];
		_showsInfo = [[d objectForKey:PGShowsInfoKey] boolValue];
		_showsThumbnails = [[d objectForKey:PGShowsThumbnailsKey] boolValue];
		_readingDirection = [[d objectForKey:PGReadingDirectionRightToLeftKey] boolValue] ? PGReadingDirectionRightToLeft : PGReadingDirectionLeftToRight;
		_imageScaleMode = [[d objectForKey:PGImageScaleModeKey] integerValue];
		if(_imageScaleMode < 0 || _imageScaleMode > 4) _imageScaleMode = PGConstantFactorScale;
		if(PGDeprecatedVerticalFitScale == _imageScaleMode) _imageScaleMode = PGAutomaticScale;
		_imageScaleFactor = (CGFloat)[[d objectForKey:PGImageScaleFactorKey] doubleValue];
		_animatesImages = [[d objectForKey:PGAnimatesImagesKey] boolValue];
		_sortOrder = [[d objectForKey:PGSortOrderKey] integerValue];
		_timerInterval = [[d objectForKey:PGTimerIntervalKey] doubleValue];
	}
	return self;
}

@end
