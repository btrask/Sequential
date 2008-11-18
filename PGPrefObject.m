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
#import "PGPrefObject.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGPrefObjectShowsInfoDidChangeNotification           = @"PGPrefObjectShowsInfoDidChange";
NSString *const PGPrefObjectShowsThumbnailsDidChangeNotification     = @"PGPrefObjectShowsThumbnailsDidChange";
NSString *const PGPrefObjectReadingDirectionDidChangeNotification    = @"PGPrefObjectReadingDirectionDidChange";
NSString *const PGPrefObjectImageScaleDidChangeNotification          = @"PGPrefObjectImageScaleDidChange";
NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification = @"PGPrefObjectUpscalesToFitScreenDidChange";
NSString *const PGPrefObjectAnimatesImagesDidChangeNotification      = @"PGPrefObjectAnimatesImagesDidChange";
NSString *const PGPrefObjectSortOrderDidChangeNotification           = @"PGPrefObjectSortOrderDidChange";

static NSString *const PGShowsInfoKey                   = @"PGShowsInfo";
static NSString *const PGShowsThumbnailsKey             = @"PGShowsThumbnails";
static NSString *const PGReadingDirectionRightToLeftKey = @"PGReadingDirectionRightToLeft";
static NSString *const PGImageScaleModeKey              = @"PGImageScaleMode";
static NSString *const PGImageScaleFactorKey            = @"PGImageScaleFactor";
static NSString *const PGImageScaleConstraintKey        = @"PGImageScaleConstraint";
static NSString *const PGAnimatesImagesKey              = @"PGAnimatesImages";
static NSString *const PGSortOrderKey                   = @"PGSortOrder2";
static NSString *const PGSortOrderDeprecatedKey         = @"PGSortOrder"; // Deprecated after 1.3.2.

NSArray *PGScaleModes() {
	return [NSArray arrayWithObjects:[NSNumber numberWithInt:PGConstantFactorScale], [NSNumber numberWithInt:PGAutomaticScale], [NSNumber numberWithInt:PGViewFitScale], [NSNumber numberWithInt:PGActualSizeWithDPI], nil];
}

@implementation PGPrefObject

#pragma mark Class Methods

+ (id)globalPrefObject
{
	static PGPrefObject *obj = nil;
	if(!obj) obj = [[self alloc] init];
	return obj;
}

#pragma mark NSObject

+ (void)initialize
{
	if([PGPrefObject class] != self) return;
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], PGShowsInfoKey,
		[NSNumber numberWithBool:NO], PGShowsThumbnailsKey,
		[NSNumber numberWithBool:NO], PGReadingDirectionRightToLeftKey,
		[NSNumber numberWithInt:PGConstantFactorScale], PGImageScaleModeKey,
		[NSNumber numberWithFloat:1.0f], PGImageScaleFactorKey,
		[NSNumber numberWithInt:PGScaleFreely], PGImageScaleConstraintKey,
		[NSNumber numberWithBool:YES], PGAnimatesImagesKey,
		[NSNumber numberWithInt:PGSortByName | PGSortRepeatMask], PGSortOrderKey,
		nil]];
}

#pragma mark Instance Methods

- (BOOL)showsInfo
{
	return _showsInfo;
}
- (void)setShowsInfo:(BOOL)flag
{
	if(!flag == !_showsInfo) return;
	_showsInfo = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGShowsInfoKey];
	[self AE_postNotificationName:PGPrefObjectShowsInfoDidChangeNotification];
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
	[self AE_postNotificationName:PGPrefObjectShowsThumbnailsDidChangeNotification];
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
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(aDirection == PGReadingDirectionRightToLeft)] forKey:PGReadingDirectionRightToLeftKey];
	[self AE_postNotificationName:PGPrefObjectReadingDirectionDidChangeNotification];
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
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:aMode] forKey:PGImageScaleModeKey];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:1] forKey:PGImageScaleFactorKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
}

- (float)imageScaleFactor
{
	return _imageScaleFactor;
}
- (void)setImageScaleFactor:(float)aFloat
{
	NSParameterAssert(aFloat > 0.0f);
	float const newFactor = fabsf(1.0f - aFloat) < 0.01f ? 1.0f : aFloat; // If it's close to 1, fudge it.
	_imageScaleFactor = newFactor;
	_imageScaleMode = PGConstantFactorScale;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:newFactor] forKey:PGImageScaleFactorKey];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:PGConstantFactorScale] forKey:PGImageScaleModeKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
}

- (PGImageScaleConstraint)imageScaleConstraint
{
	return _imageScaleConstraint;
}
- (void)setImageScaleConstraint:(PGImageScaleConstraint)constraint
{
	if(constraint == _imageScaleConstraint) return;
	_imageScaleConstraint = constraint;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:constraint] forKey:PGImageScaleConstraintKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
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
	[self AE_postNotificationName:PGPrefObjectAnimatesImagesDidChangeNotification];
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
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:anOrder] forKey:PGSortOrderKey];
	[self AE_postNotificationName:PGPrefObjectSortOrderDidChangeNotification];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		NSUserDefaults *const d = [NSUserDefaults standardUserDefaults];
		_showsInfo = [[d objectForKey:PGShowsInfoKey] boolValue];
		_showsThumbnails = [[d objectForKey:PGShowsThumbnailsKey] boolValue];
		_readingDirection = [[d objectForKey:PGReadingDirectionRightToLeftKey] boolValue] ? PGReadingDirectionRightToLeft : PGReadingDirectionLeftToRight;
		_imageScaleMode = [[d objectForKey:PGImageScaleModeKey] intValue];
		if(_imageScaleMode < 0 || _imageScaleMode > 4) _imageScaleMode = PGConstantFactorScale;
		if(PGDeprecatedVerticalFitScale == _imageScaleMode) _imageScaleMode = PGAutomaticScale;
		_imageScaleFactor = [[d objectForKey:PGImageScaleFactorKey] floatValue];
		_imageScaleConstraint = [[d objectForKey:PGImageScaleConstraintKey] intValue];
		if(_imageScaleConstraint < PGDownscale || _imageScaleConstraint > PGUpscale) _imageScaleConstraint = PGDownscale;
		_animatesImages = [[d objectForKey:PGAnimatesImagesKey] boolValue];
		_sortOrder = [[d objectForKey:PGSortOrderKey] intValue];
	}
	return self;
}

@end
