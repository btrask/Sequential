#import <Cocoa/Cocoa.h>

extern NSString *const PGPrefObjectShowsOnScreenDisplayDidChangeNotification;
extern NSString *const PGPrefObjectReadingDirectionDidChangeNotification;
extern NSString *const PGPrefObjectImageScaleDidChangeNotification;
extern NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification;
extern NSString *const PGPrefObjectSortOrderDidChangeNotification;
extern NSString *const PGPrefObjectAnimatesImagesDidChangeNotification;

enum {
	PGNoPattern           = 0,
	PGCheckerboardPattern = 1
};
typedef int PGPatternType;

enum {
	PGReadingDirectionLeftToRight = 0,
	PGReadingDirectionRightToLeft = 1
};
typedef int PGReadingDirection;

enum {
	PGConstantFactorScaling        = 0, // Formerly known as PGNoScaling.
	PGAutomaticScaling             = 1,
	PGDeprecatedVerticalFitScaling = 2, // Valid through 1.0.3.
	PGViewFitScaling               = 3  // Fits the entire image inside the screen/window.
};
typedef int PGImageScalingMode;

enum {
	PGDownscale   = -1,
	PGScaleFreely = 0,
	PGUpscale     = 1
};
typedef int PGImageScalingConstraint;

enum {
	PGUnsorted           = 0,
	PGSortOrderMask      = 0x0000FFFF,
	PGSortByName         = 1,
	PGSortByDateModified = 2,
	PGSortByDateCreated  = 3,
	PGSortBySize         = 4,
	PGSortShuffle        = 100,
	PGSortOptionsMask    = 0x7FFF0000,
	PGSortDescendingMask = 1 << 16,
	PGSortRepeatMask     = 1 << 17,
};
typedef int PGSortOrder;

#define PGValueOrDefault(val, default) ({ __typeof__(val) __val = (val); __val ? __val : (default); })
#define PGValueWithSelectorOrDefault(val, msg, default) ({ id __val = (val); __val ? [__val msg] : (default); })

@interface PGPrefObject : NSObject
{
	@private
	BOOL                     _loaded;
	BOOL                     _showsOnScreenDisplay;
	PGReadingDirection       _readingDirection;
	PGImageScalingMode       _imageScalingMode;
	float                    _imageScaleFactor;
	PGImageScalingConstraint _imageScalingConstraint;
	PGSortOrder              _sortOrder;
	BOOL                     _animatesImages;
}

+ (id)globalPrefObject;

- (BOOL)showsOnScreenDisplay;
- (void)setShowsOnScreenDisplay:(BOOL)flag;

- (PGReadingDirection)readingDirection;
- (void)setReadingDirection:(PGReadingDirection)aDirection;

- (PGImageScalingMode)imageScalingMode;
- (void)setImageScalingMode:(PGImageScalingMode)aMode;
- (float)imageScaleFactor;
- (void)setImageScaleFactor:(float)aFloat;
- (PGImageScalingConstraint)imageScalingConstraint;
- (void)setImageScalingConstraint:(PGImageScalingConstraint)flag;

- (PGSortOrder)sortOrder;
- (void)setSortOrder:(PGSortOrder)anOrder;

- (BOOL)animatesImages;
- (void)setAnimatesImages:(BOOL)flag;

@end
