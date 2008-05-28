#import "PGArchiveAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSStringAdditions.h"

@interface XADArchive (PGAdditions)

- (NSString *)HFSTypeCodeForEntry:(int)index standardFormat:(BOOL)flag;
- (NSString *)typeForEntry:(int)index preferHFSTypeCode:(BOOL)flag;

@end

@implementation PGArchiveAdapter

#pragma mark Instance Methods

- (XADArchive *)archive
{
	return [[_archive retain] autorelease];
}
- (void)setIsSubarchive:(BOOL)flag
{
	_isSubarchive = flag;
}
- (NSArray *)nodesUnderPath:(NSString *)path
             parentAdapter:(PGContainerAdapter *)parent
{
	NSParameterAssert(path);
	NSParameterAssert(parent);
	NSParameterAssert(_archive);
	NSParameterAssert(_remainingIndexes);
	NSMutableArray *const children = [NSMutableArray array];
	int i = [_remainingIndexes firstIndex];
	for(; NSNotFound != i; i = [_remainingIndexes indexGreaterThanIndex:i]) {
		NSString *const entryPath = [_archive nameOfEntry:i];
		if([self needsEncoding]) return nil;
		if(!entryPath || (![entryPath hasPrefix:path] && ![path isEqualToString:@""])) continue;
		[_remainingIndexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] AE_firstPathComponent]];
		if([path isEqualToString:entryPath]) continue;
		BOOL const isEntrylessFolder = ![subpath isEqualToString:entryPath];
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGResourceIdentifier *const identifier = [[self identifier] subidentifierWithIndex:i];
		[identifier setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:(isFile ? [_archive typeForEntry:i preferHFSTypeCode:YES] : @"'fldr'")]];
		[identifier setDisplayName:[subpath AE_displayName]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier adapterClass:(isFile ? [PGArchiveResourceAdapter class] : [PGContainerAdapter class]) dataSource:self load:YES] autorelease];
		if(!isFile) {
			if(isEntrylessFolder) [_remainingIndexes addIndex:i]; // We ended up taking care of a folder in its path instead.
			PGContainerAdapter *const adapter = (id)[node resourceAdapter];
			[adapter setUnsortedChildren:[self nodesUnderPath:subpath parentAdapter:adapter] presortedOrder:PGUnsorted];
		}
		[children addObject:node];
	}
	return children;
}

#pragma mark XADArchiveDelegate Protocol

- (NSStringEncoding)archive:(XADArchive *)archive
                    encodingForName:(const char *)bytes
                    guess:(NSStringEncoding)guess
                    confidence:(float)confidence
{
	if(confidence >= 0.8) return guess;
	_guessedEncoding = guess;
	[self setNeedsEncoding:YES];
	return guess;
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)isViewable
{
	return !_hasCreatedChildren || [super isViewable];
}
- (char const *)unencodedSampleString
{
	return [_archive numberOfEntries] ? [_archive _undecodedNameOfEntry:0] : NULL;
}
- (NSStringEncoding)defaultEncoding
{
	return _guessedEncoding;
}
- (void)setEncoding:(NSStringEncoding)encoding
{
	[_archive setNameEncoding:encoding];
	[self setNeedsEncoding:NO];
	[self readFromData:nil URLResponse:nil];
}

#pragma mark PGResourceAdapterDataSource Protocol

- (NSDate *)dateCreatedForResourceAdapter:(PGResourceAdapter *)sender
{
	struct xadFileInfo const *const info = [_archive xadFileInfoForEntry:[[sender identifier] index]];
	xadUINT32 timestamp;
	if(info->xfi_Flags & XADFIF_NODATE || xadConvertDates([_archive xadMasterBase], XAD_DATEXADDATE, &info->xfi_Date, XAD_DATEUNIX, &timestamp, TAG_DONE) != XADERR_OK) return [NSDate distantPast];
	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}
- (NSNumber *)dataLengthForResourceAdapter:(PGResourceAdapter *)sender
{
	return [NSNumber numberWithUnsignedLongLong:[_archive xadFileInfoForEntry:[[sender identifier] index]]->xfi_Size];
}
- (NSData *)dataForResourceAdapter:(PGResourceAdapter *)sender
{
	[_archive clearLastError];
	if([sender lastPassword]) [_archive setPassword:[sender lastPassword]];
	NSData *const data = [_archive contentsOfEntry:[[[sender node] identifier] index]];
	[sender setNeedsPassword:([_archive lastError] == XADERR_PASSWORD)];
	return data;
}

#pragma mark PGResourceAdapter

- (BOOL)shouldReadAllDescendants
{
	return YES;
}
- (void)readFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	if(!_archive) {
		XADError error;
		if(_isSubarchive) {
			_archive = [[XADArchive alloc] initWithArchive:[(PGArchiveAdapter *)[self dataSource] archive] entry:[[self identifier] index] error:&error];
			[_archive setDelegate:self];
		} else {
			NSData *realData = data;
			if(!realData) {
				realData = [[self dataSource] dataForResourceAdapter:self];
				if(!realData && [self needsPassword]) return;
			}
			if(realData) {
				_archive = [[XADArchive alloc] initWithData:realData error:&error];
				[_archive setDelegate:self];
			} else {
				PGResourceIdentifier *const identifier = [self identifier];
				NSParameterAssert([identifier isFileIdentifier]);
				_archive = [[XADArchive alloc] initWithFile:[[identifier URLByFollowingAliases:YES] path] delegate:self error:&error];
			}
		}
		if(!_archive || error != XADERR_OK || [_archive isCorrupted]) return;
	}
	_remainingIndexes = [[[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])] autorelease];
	NSString *const root = [_archive commonTopDirectory];
	NSArray *const children = [self nodesUnderPath:(root ? root : @"") parentAdapter:self];
	[self setUnsortedChildren:children presortedOrder:PGUnsorted];
	_remainingIndexes = nil;
	if(!children) return;
	_hasCreatedChildren = YES;
	[self noteIsViewableDidChange];
	if([self shouldReadContents]) [self readContents];
}

#pragma mark NSObject

- (void)dealloc
{
	[_archive release];
	[super dealloc];
}

@end

@implementation PGArchiveResourceAdapter

#pragma mark PGResourceAdapter

- (BOOL)canBookmark
{
	return [super canBookmark] && [[self identifier] index] != NSNotFound;
}
- (void)loadFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	unsigned index = [[self identifier] index];
	XADArchive *const archive = [(PGArchiveAdapter *)[self dataSource] archive];
	NSParameterAssert(NSNotFound != index);
	NSParameterAssert(![archive entryIsDirectory:index]);
	id adapter = nil;
	if([archive entryIsArchive:index]) {
		adapter = [[[PGArchiveAdapter alloc] init] autorelease];
		[adapter setIsSubarchive:YES];
	} else return [super loadFromData:data URLResponse:response];
	adapter = [[self node] setResourceAdapter:adapter];
	[adapter readFromData:data URLResponse:response];
	[self replacedWithAdapter:adapter];
}
- (Class)classForData:(NSData *)data
         URLResponse:(NSURLResponse *)response
{
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	XADArchive *const archive = [(PGArchiveAdapter *)[self dataSource] archive];
	unsigned const index = [[self identifier] index];
	NSParameterAssert(NSNotFound != index);
	Class class = Nil;
	if(!class) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeOSTypesKey matches:[archive HFSTypeCodeForEntry:index standardFormat:NO]];
	if(!class) class = [d resourceAdapterClassForExtension:[archive typeForEntry:index preferHFSTypeCode:NO]];
	if(!class) class = [super classForData:data URLResponse:response];
	return class;
}

@end

@implementation XADArchive (PGAdditions)

- (NSString *)HFSTypeCodeForEntry:(int)index
              standardFormat:(BOOL)flag
{
	OSType value;
	if([self entryIsDirectory:index]) value = 'fldr';
	else {
		NSNumber *const typeCode = [[self attributesOfEntry:index] objectForKey:NSFileHFSTypeCode];
		if(!typeCode) return nil;
		value = [typeCode unsignedLongValue];
	}
	return flag ? NSFileTypeForHFSTypeCode(value) : PGPseudoFileTypeForHFSTypeCode(value);
}
- (NSString *)typeForEntry:(int)index
              preferHFSTypeCode:(BOOL)flag
{
	NSString *const HFSType = flag ? [self HFSTypeCodeForEntry:index standardFormat:YES] : nil;
	return HFSType ? HFSType : [[self nameOfEntry:index] pathExtension];
}

@end
