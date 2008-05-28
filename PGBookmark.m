#import "PGBookmark.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGSubscription.h"

@implementation PGBookmark

#pragma mark Instance Methods

- (id)initWithNode:(PGNode *)aNode
{
	if((self = [super init])) {
		_documentIdentifier = [[[aNode document] identifier] retain];
		_fileIdentifier = [[aNode identifier] retain];
	}
	return self;
}

#pragma mark -

- (PGResourceIdentifier *)documentIdentifier
{
	return [[_documentIdentifier retain] autorelease];
}
- (PGResourceIdentifier *)fileIdentifier
{
	return [[_fileIdentifier retain] autorelease];
}

#pragma mark -

- (NSString *)displayName
{
	NSString *const name = [_fileIdentifier displayName];
	return name ? name : [[_backupDisplayName retain] autorelease];
}
- (BOOL)isValid
{
	return [_documentIdentifier URLByFollowingAliases:YES] && [_fileIdentifier URLByFollowingAliases:YES];
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	if((self = [super init])) {
		_documentIdentifier = [[aCoder decodeObjectForKey:@"DocumentIdentifier"] retain];
		_fileIdentifier = [[aCoder decodeObjectForKey:@"FileIdentifier"] retain];
		_backupDisplayName = [[aCoder decodeObjectForKey:@"BackupDisplayName"] retain];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_documentIdentifier forKey:@"DocumentIdentifier"];
	[aCoder encodeObject:_fileIdentifier forKey:@"FileIdentifier"];
	[aCoder encodeObject:_backupDisplayName forKey:@"BackupDisplayName"];
}

#pragma mark NSObject

- (void)dealloc
{
	[_documentIdentifier release];
	[_fileIdentifier release];
	[_backupDisplayName release];
	[super dealloc];
}

@end
