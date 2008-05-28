#import <Cocoa/Cocoa.h>
#import "PGResourceAdapting.h"

// Models
@class PGNode;

@interface PGResourceAdapter : NSObject <PGResourceAdapting>
{
	@private
	PGNode   *_node;
	unsigned  _determiningTypeCount;
	BOOL      _isImage;
	BOOL      _needsPassword;
	BOOL      _needsEncoding;
	BOOL      _hasReadContents;
}

- (PGNode *)node;
- (void)setNode:(PGNode *)aNode;

- (BOOL)isDeterminingType;
- (BOOL)isImage;
- (BOOL)needsPassword;
- (BOOL)needsEncoding;
- (void)setIsDeterminingType:(BOOL)flag;
- (void)setIsImage:(BOOL)flag;
- (void)setNeedsPassword:(BOOL)flag;
- (void)setNeedsEncoding:(BOOL)flag;
- (void)noteIsViewableDidChange;

- (void)loadFromData:(NSData *)data URLResponse:(NSURLResponse *)response;
- (Class)classForData:(NSData *)data URLResponse:(NSURLResponse *)response;
- (void)replacedWithAdapter:(PGResourceAdapter *)newAdapter;
- (BOOL)shouldReadAllDescendants;
- (BOOL)shouldRead;
- (void)readFromData:(NSData *)data URLResponse:(NSURLResponse *)response; // Abstract method. Perform an initial read. PGContainerAdapters should create any child nodes here if possible. This gets called for every node created when the document is first opened, so defer anything slow to -readContents. -lastPassword won't be set yet.

- (BOOL)shouldReadContents;
- (void)setHasReadContents;
- (void)readContents; // Abstract method. Sent by -becomeViewed and -becomeViewedWithPassword:. -lastPassword may be set--you can send -readFromData:URLResponse: if you need to defer loading until a password is set. If -[node expectsReturnedImage], should send -setHasReadContents and then -returnImage:error must be sent sometime thereafter.

- (NSString *)sortName;
- (NSDate *)dateModified:(BOOL)allowNil; // If 'allowNil', nil will be returned when there is no meaningful value.
- (NSDate *)dateCreated:(BOOL)allowNil;
- (NSNumber *)size:(BOOL)allowNil;

- (void)fileResourceDidChange:(unsigned)flags;

@end

@interface NSObject (PGResourceAdapterDataSource)

- (NSDate *)dateModifiedForResourceAdapter:(PGResourceAdapter *)sender;
- (NSDate *)dateCreatedForResourceAdapter:(PGResourceAdapter *)sender;
- (NSNumber *)dataLengthForResourceAdapter:(PGResourceAdapter *)sender;
- (NSData *)dataForResourceAdapter:(PGResourceAdapter *)sender; // If a password is required, sends -lastPassword, then sends -setNeedsPassword: with whether the password worked.

@end
