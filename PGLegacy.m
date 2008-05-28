#import "PGLegacy.h"

// Models
#import "PGResourceIdentifier.h"

@implementation PGDynamicURL

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	PGResourceIdentifier *result = nil;
	NSURL *URL = [aCoder decodeObjectForKey:@"URL"];
	if(URL) result = [[PGResourceIdentifier resourceIdentifierWithURL:URL] retain];
	else {
		unsigned length;
		uint8_t const *const data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
		result = [[PGResourceIdentifier resourceIdentifierWithAliasData:data length:length] retain];
	}
	[result setIcon:[aCoder decodeObjectForKey:@"Icon"]];
	[result setDisplayName:[aCoder decodeObjectForKey:@"DisplayName"]];
	return result;
}

@end

@implementation PGAlias

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	unsigned length;
	uint8_t const *const data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
	return [[PGResourceIdentifier resourceIdentifierWithAliasData:data length:length] retain];
}

@end
