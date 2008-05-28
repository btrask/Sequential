#import <Cocoa/Cocoa.h>
#import "PGResourceAdapting.h"

// Models
@class PGDocument;
@class PGResourceAdapter;
@class PGContainerAdapter;
@class PGResourceIdentifier;

extern NSString *const PGNodeLoadingDidProgressNotification;
extern NSString *const PGNodeReadyForViewingNotification;

extern NSString *const PGImageKey;
extern NSString *const PGErrorKey;

extern NSString *const PGPasswordError;
extern NSString *const PGEncodingError;

@interface PGNode : NSObject
{
	@private
	PGContainerAdapter   *_parentAdapter;
	PGDocument           *_document;
	PGResourceIdentifier *_identifier;
	id                    _dataSource;
	NSMenuItem           *_menuItem;
	BOOL                  _isViewable;
	NSString             *_lastPassword;
	BOOL                  _expectsReturnedImage;
	PGResourceAdapter    *_resourceAdapter;
}

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGResourceIdentifier *)ident adapterClass:(Class)class dataSource:(id)source load:(BOOL)flag;

- (unsigned)depth;
- (NSMenuItem *)menuItem;
- (void)setIsViewable:(BOOL)flag;
- (void)becomeViewed;
- (void)becomeViewedWithPassword:(NSString *)pass;

- (PGResourceAdapter *)resourceAdapter;
- (PGResourceAdapter *)setResourceAdapter:(PGResourceAdapter *)adapter; // If it changes, returns -resourceAdapter, otherwise nil.
- (PGResourceAdapter *)setResourceAdapterClass:(Class)aClass;

- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.

- (void)identifierDidChange:(NSNotification *)aNotif;
- (void)fileEventDidOccur:(NSNotification *)aNotif;

@end

@interface PGNode (PGResourceAdapterProxy) <PGResourceAdapting>
@end
