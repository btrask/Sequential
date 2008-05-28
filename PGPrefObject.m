#import "PGPrefObject.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGPrefObjectShowsOnScreenDisplayDidChangeNotification = @"PGPrefObjectShowsOnScreenDisplayDidChange";
NSString *const PGPrefObjectReadingDirectionDidChangeNotification     = @"PGPrefObjectReadingDirectionDidChange";
NSString *const PGPrefObjectImageScaleDidChangeNotification           = @"PGPrefObjectImageScaleDidChange";
NSString *const PGPrefObjectUpscalesToFitScreenDidChangeNotification  = @"PGPrefObjectUpscalesToFitScreenDidChange";
NSString *const PGPrefObjectSortOrderDidChangeNotification            = @"PGPrefObjectSortOrderDidChange";
NSString *const PGPrefObjectAnimatesImagesDidChangeNotification       = @"PGPrefObjectAnimatesImagesDidChange";

static NSString *const PGShowsOnScreenDisplayKey        = @"PGShowsOnScreenDisplay";
static NSString *const PGReadingDirectionRightToLeftKey = @"PGReadingDirectionRightToLeft";
static NSString *const PGImageScalingModeKey            = @"PGImageScalingMode";
static NSString *const PGImageScaleFactorKey            = @"PGImageScaleFactor";
static NSString *const PGImageScalingConstraintKey      = @"PGImageScalingConstraint";
static NSString *const PGSortOrderKey                   = @"PGSortOrder2";
static NSString *const PGSortOrderDeprecatedKey         = @"PGSortOrder";
static NSString *const PGAnimatesImagesKey              = @"PGAnimatesImages";

@implementation PGPrefObject

#pragma mark Class Methods

+ (id)globalPrefObject
{
	static PGPrefObject *obj = nil;
	if(!obj) obj = [[self alloc] init];
	return obj;
}

#pragma mark Instance Methods

- (BOOL)showsOnScreenDisplay
{
	return _showsOnScreenDisplay;
}
- (void)setShowsOnScreenDisplay:(BOOL)flag
{
	if(_loaded && !flag == !_showsOnScreenDisplay) return;
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
	if(_loaded && aDirection == _readingDirection) return;
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
	NSParameterAssert(aMode >= 0 && aMode <= 3);
	NSParameterAssert(aMode != PGDeprecatedVerticalFitScaling);
	if(_loaded && aMode == _imageScalingMode) return;
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
	if(_loaded && newFactor == _imageScaleFactor) return;
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
	if(_loaded && constraint == _imageScalingConstraint) return;
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
	if(_loaded && anOrder == _sortOrder) return;
	_sortOrder = anOrder;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:anOrder] forKey:PGSortOrderKey];
	[self AE_postNotificationName:PGPrefObjectSortOrderDidChangeNotification];
}

#pragma mark -

- (BOOL)animatesImages
{
	return _animatesImages;
}
- (void)setAnimatesImages:(BOOL)flag
{
	if(_loaded && !flag == !_animatesImages) return;
	_animatesImages = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGAnimatesImagesKey];
	[self AE_postNotificationName:PGPrefObjectAnimatesImagesDidChangeNotification];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		NSUserDefaults *const d = [NSUserDefaults standardUserDefaults];
		[self setShowsOnScreenDisplay:PGValueWithSelectorOrDefault([d objectForKey:PGShowsOnScreenDisplayKey], boolValue, NO)];
		[self setReadingDirection:(PGValueWithSelectorOrDefault([d objectForKey:PGReadingDirectionRightToLeftKey], boolValue, NO) ? PGReadingDirectionRightToLeft : PGReadingDirectionLeftToRight)];
		PGImageScalingMode scalingMode = PGValueWithSelectorOrDefault([d objectForKey:PGImageScalingModeKey], intValue, PGConstantFactorScaling);
		if(scalingMode > 3) scalingMode = PGConstantFactorScaling;
		if(scalingMode == PGDeprecatedVerticalFitScaling) scalingMode = PGAutomaticScaling;
		[self setImageScalingMode:scalingMode];
		[self setImageScaleFactor:PGValueWithSelectorOrDefault([d objectForKey:PGImageScaleFactorKey], floatValue, 1.0f)];
		[self setImageScalingConstraint:PGValueWithSelectorOrDefault([d objectForKey:PGImageScalingConstraintKey], intValue, PGDownscale)];
		[self setSortOrder:PGValueWithSelectorOrDefault([d objectForKey:PGSortOrderKey], intValue, PGSortByName)];
		[self setAnimatesImages:PGValueWithSelectorOrDefault([d objectForKey:PGAnimatesImagesKey], boolValue, YES)];
		_loaded = YES;
	}
	return self;
}

@end
