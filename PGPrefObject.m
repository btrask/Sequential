/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGPrefObject.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGPrefObjectShowsOnScreenDisplayDidChangeNotification = @"PGPrefObjectShowsOnScreenDisplayDidChange";
NSString *const PGPrefObjectReadingDirectionDidChangeNotification     = @"PGPrefObjectReadingDirectionDidChange";
NSString *const PGPrefObjectImageScaleDidChangeNotification           = @"PGPrefObjectImageScaleDidChange";
NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification  = @"PGPrefObjectUpscalesToFitScreenDidChange";
NSString *const PGPrefObjectSortOrderDidChangeNotification            = @"PGPrefObjectSortOrderDidChange";

static NSString *const PGShowsOnScreenDisplayKey        = @"PGShowsOnScreenDisplay";
static NSString *const PGReadingDirectionRightToLeftKey = @"PGReadingDirectionRightToLeft";
static NSString *const PGImageScalingModeKey            = @"PGImageScalingMode";
static NSString *const PGImageScaleFactorKey            = @"PGImageScaleFactor";
static NSString *const PGImageScalingConstraintKey      = @"PGImageScalingConstraint";
static NSString *const PGSortOrderKey                   = @"PGSortOrder2";
static NSString *const PGSortOrderDeprecatedKey         = @"PGSortOrder"; // Deprecated after 1.3.2.

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
		[NSNumber numberWithBool:YES], PGShowsOnScreenDisplayKey,
		[NSNumber numberWithBool:NO], PGReadingDirectionRightToLeftKey,
		[NSNumber numberWithInt:PGConstantFactorScaling], PGImageScalingModeKey,
		[NSNumber numberWithFloat:1.0f], PGImageScaleFactorKey,
		[NSNumber numberWithInt:PGDownscale], PGImageScalingConstraintKey,
		[NSNumber numberWithInt:PGSortByName | PGSortRepeatMask], PGSortOrderKey,
		nil]];
}

#pragma mark Instance Methods

- (BOOL)showsOnScreenDisplay
{
	return _showsOnScreenDisplay;
}
- (void)setShowsOnScreenDisplay:(BOOL)flag
{
	if(!flag == !_showsOnScreenDisplay) return;
	_showsOnScreenDisplay = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGShowsOnScreenDisplayKey];
	[self AE_postNotificationName:PGPrefObjectShowsOnScreenDisplayDidChangeNotification];
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

- (PGImageScalingMode)imageScalingMode
{
	return _imageScalingMode;
}
- (void)setImageScalingMode:(PGImageScalingMode)aMode
{
	if(aMode == _imageScalingMode) return;
	_imageScalingMode = aMode;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:aMode] forKey:PGImageScalingModeKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
}

- (float)imageScaleFactor
{
	return _imageScaleFactor;
}
- (void)setImageScaleFactor:(float)aFloat
{
	float const newFactor = fabs(aFloat);
	if(newFactor == _imageScaleFactor) return;
	_imageScaleFactor = newFactor;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:newFactor] forKey:PGImageScaleFactorKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
}

- (PGImageScalingConstraint)imageScalingConstraint
{
	return _imageScalingConstraint;
}
- (void)setImageScalingConstraint:(PGImageScalingConstraint)constraint
{
	if(constraint == _imageScalingConstraint) return;
	_imageScalingConstraint = constraint;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:constraint] forKey:PGImageScalingConstraintKey];
	[self AE_postNotificationName:PGPrefObjectImageScaleDidChangeNotification];
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
		_showsOnScreenDisplay = [[d objectForKey:PGShowsOnScreenDisplayKey] boolValue];
		_readingDirection = [[d objectForKey:PGReadingDirectionRightToLeftKey] boolValue] ? PGReadingDirectionRightToLeft : PGReadingDirectionLeftToRight;
		_imageScalingMode = [[d objectForKey:PGImageScalingModeKey] intValue];
		if(_imageScalingMode < 0 || _imageScalingMode > 3) _imageScalingMode = PGConstantFactorScaling;
		if(PGDeprecatedVerticalFitScaling == _imageScalingMode) _imageScalingMode = PGAutomaticScaling;
		_imageScaleFactor = [[d objectForKey:PGImageScaleFactorKey] floatValue];
		_imageScalingConstraint = [[d objectForKey:PGImageScalingConstraintKey] intValue];
		if(_imageScalingConstraint < PGDownscale || _imageScalingConstraint > PGUpscale) _imageScalingConstraint = PGDownscale;
		_sortOrder = [[d objectForKey:PGSortOrderKey] intValue];
	}
	return self;
}

@end
