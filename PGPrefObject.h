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
// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGPrefObjectShowsInfoDidChangeNotification;
extern NSString *const PGPrefObjectShowsThumbnailsDidChangeNotification;
extern NSString *const PGPrefObjectReadingDirectionDidChangeNotification;
extern NSString *const PGPrefObjectImageScaleDidChangeNotification;
extern NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification;
extern NSString *const PGPrefObjectAnimatesImagesDidChangeNotification;
extern NSString *const PGPrefObjectSortOrderDidChangeNotification;
extern NSString *const PGPrefObjectTimerIntervalDidChangeNotification;
extern NSString *const PGPrefObjectBaseOrientationDidChangeNotification;

extern NSString *const PGPrefObjectAnimateKey;

enum {
	PGNoPattern = 0,
	PGCheckerboardPattern = 1,
};
typedef NSInteger PGPatternType;

enum {
	PGConstantFactorScale = 0, // Formerly known as PGNoScale.
	PGAutomaticScale = 1,
	PGDeprecatedVerticalFitScale = 2, // Deprecated after 1.0.3.
	PGViewFitScale = 3, // Fits the entire image inside the screen/window.
	PGDeprecatedActualSizeWithDPI = 4, // Depcrecated after 2.1.2.
};
typedef NSInteger PGImageScaleMode;

enum {
	PGUnsorted           = 0,
	PGSortOrderMask      = 0x0000FFFF,
	PGSortByName         = 1,
	PGSortByDateModified = 2,
	PGSortByDateCreated  = 3,
	PGSortBySize         = 4,
	PGSortByKind         = 5,
	PGSortShuffle        = 100,
	PGSortInnateOrder    = 200,
	PGSortOptionsMask    = 0x7FFF0000,
	PGSortDescendingMask = 1 << 16,
	PGSortRepeatMask     = 1 << 17,
};
typedef NSInteger PGSortOrder;

@interface PGPrefObject : NSObject
{
	@private
	BOOL _showsInfo;
	BOOL _showsThumbnails;
	PGReadingDirection _readingDirection;
	PGImageScaleMode _imageScaleMode;
	CGFloat _imageScaleFactor;
	BOOL _animatesImages;
	PGSortOrder _sortOrder;
	NSTimeInterval _timerInterval;
	PGOrientation _baseOrientation;
}

+ (id)globalPrefObject;
+ (NSArray *)imageScaleModes;

@property(assign) BOOL showsInfo;
@property(assign) BOOL showsThumbnails;
@property(assign) PGReadingDirection readingDirection;
@property(assign) PGImageScaleMode imageScaleMode;
@property(assign) CGFloat imageScaleFactor;
- (void)setImageScaleFactor:(CGFloat)factor animate:(BOOL)flag;
@property(assign) BOOL animatesImages;
@property(assign) PGSortOrder sortOrder;
@property(assign) NSTimeInterval timerInterval;
@property(assign) PGOrientation baseOrientation;

- (BOOL)isCurrentSortOrder:(PGSortOrder)order; // Ignores sort options.

@end
