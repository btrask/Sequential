#import "XADSimpleUnarchiver.h"
#import "XADPlatform.h"
#import "XADException.h"

#ifdef __APPLE__
#include <sys/xattr.h>
#endif


@implementation XADSimpleUnarchiver

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path
{
	return [self simpleUnarchiverForPath:path error:NULL];
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;
{
	XADArchiveParser *archiveparser=[XADArchiveParser archiveParserForPath:path error:errorptr];
	if(!archiveparser) return nil;
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser
{
	return [self initWithArchiveParser:archiveparser entries:nil];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser entries:(NSArray *)entryarray
{
	if((self=[super init]))
	{
		parser=[archiveparser retain];
		unarchiver=[[XADUnarchiver alloc] initWithArchiveParser:archiveparser];
		subunarchiver=nil;

		delegate=nil;
		shouldstop=NO;

		destination=nil;

		NSString *name=[archiveparser name];
		if([name matchedByPattern:
		@"\\.(part[0-9]+\\.rar|tar\\.gz|tar\\.bz2|tar\\.lzma|sit\\.hqx)$"
		options:REG_ICASE])
		{
			enclosingdir=[[[name stringByDeletingPathExtension]
			stringByDeletingPathExtension] retain];
		}
		else
		{
			enclosingdir=[[name stringByDeletingPathExtension] retain];
		}

		// TODO: Check if we accidentally create a package. Seems impossible, though.

		extractsubarchives=YES;
		removesolo=YES;

		overwrite=NO;
		rename=NO;
		skip=NO;

		copydatetoenclosing=NO;
		copydatetosolo=NO;
		resetsolodate=NO;
		propagatemetadata=YES;

		regexes=nil;
		indices=nil;

		if(entryarray) entries=[[NSMutableArray alloc] initWithArray:entryarray];
		else entries=[NSMutableArray new];

		reasonsforinterest=[NSMutableArray new];
		renames=[NSMutableDictionary new];
		resourceforks=[NSMutableSet new];

		NSString *archivename=[parser filename];
		if(archivename) metadata=[[XADPlatform readCloneableMetadataFromPath:archivename] retain];
		else metadata=nil;

		unpackdestination=nil;
		finaldestination=nil;
		soloitem=nil;

		toplevelname=nil;
		lookslikesolo=NO;

		numextracted=0;
	}

	return self;
}

-(void)dealloc
{
	[parser release];
	[unarchiver release];
	[subunarchiver release];

	[destination release];
	[enclosingdir release];

	[regexes release];
	[indices release];

	[entries release];
	[reasonsforinterest release];
	[renames release];
	[resourceforks release];
	[metadata release];

	[unpackdestination release];
	[finaldestination release];
	[soloitem release];

	[toplevelname release];

	[super dealloc];
}

-(XADArchiveParser *)archiveParser
{
	if(subunarchiver) return [subunarchiver archiveParser];
	else return parser;
}

-(XADArchiveParser *)outerArchiveParser { return parser; }
-(XADArchiveParser *)innerArchiveParser { return [subunarchiver archiveParser]; }

-(NSArray *)reasonsForInterest { return reasonsforinterest; }

-(id)delegate { return delegate; }
-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(NSString *)password { return [parser password]; }
-(void)setPassword:(NSString *)password
{
	[parser setPassword:password];
	[[subunarchiver archiveParser] setPassword:password];
}

-(NSString *)destination { return destination; }
-(void)setDestination:(NSString *)destpath
{
	if(destpath!=destination)
	{
		[destination release];
		destination=[destpath retain];
	}
}

-(NSString *)enclosingDirectoryName { return enclosingdir; }
-(void)setEnclosingDirectoryName:(NSString *)dirname
{
	if(dirname!=enclosingdir)
	{
		[enclosingdir release];
		enclosingdir=[dirname retain];
	}
}

-(BOOL)removesEnclosingDirectoryForSoloItems { return removesolo; }
-(void)setRemovesEnclosingDirectoryForSoloItems:(BOOL)removeflag { removesolo=removeflag; }

-(BOOL)alwaysOverwritesFiles { return overwrite; }
-(void)setAlwaysOverwritesFiles:(BOOL)overwriteflag { overwrite=overwriteflag; }

-(BOOL)alwaysRenamesFiles { return rename; }
-(void)setAlwaysRenamesFiles:(BOOL)renameflag { rename=renameflag; }

-(BOOL)alwaysSkipsFiles { return skip; }
-(void)setAlwaysSkipsFiles:(BOOL)skipflag { skip=skipflag; }

-(BOOL)extractsSubArchives { return extractsubarchives; }
-(void)setExtractsSubArchives:(BOOL)extractflag { extractsubarchives=extractflag; }

-(BOOL)copiesArchiveModificationTimeToEnclosingDirectory { return copydatetoenclosing; }
-(void)setCopiesArchiveModificationTimeToEnclosingDirectory:(BOOL)copyflag { copydatetoenclosing=copyflag; }

-(BOOL)copiesArchiveModificationTimeToSoloItems { return copydatetosolo; }
-(void)setCopiesArchiveModificationTimeToSoloItems:(BOOL)copyflag { copydatetosolo=copyflag; }

-(BOOL)resetsDateForSoloItems { return resetsolodate; }
-(void)setResetsDateForSoloItems:(BOOL)resetflag { resetsolodate=resetflag; }

-(BOOL)propagatesRelevantMetadata { return propagatemetadata; }
-(void)setPropagatesRelevantMetadata:(BOOL)propagateflag { propagatemetadata=propagateflag; }

-(int)macResourceForkStyle { return [unarchiver macResourceForkStyle]; }
-(void)setMacResourceForkStyle:(int)style
{
	[unarchiver setMacResourceForkStyle:style];
	[subunarchiver setMacResourceForkStyle:style];
}

-(BOOL)preservesPermissions { return [unarchiver preservesPermissions]; }
-(void)setPreserevesPermissions:(BOOL)preserveflag
{
	[unarchiver setPreserevesPermissions:preserveflag];
	[subunarchiver setPreserevesPermissions:preserveflag];
}

-(double)updateInterval { return [unarchiver updateInterval]; }
-(void)setUpdateInterval:(double)interval
{
	[unarchiver setUpdateInterval:interval];
	[subunarchiver setUpdateInterval:interval];
}

-(void)addGlobFilter:(NSString *)wildcard
{
	// TODO: SOMEHOW correctly handle case sensitivity!
	NSString *pattern=[XADRegex patternForGlob:wildcard];
	#if defined(__APPLE__) || defined(__MINGW32__)
	[self addRegexFilter:[XADRegex regexWithPattern:pattern options:REG_ICASE]];
	#else
	[self addRegexFilter:[XADRegex regexWithPattern:pattern options:0]];
	#endif
}

-(void)addRegexFilter:(XADRegex *)regex
{
	if(!regexes) regexes=[NSMutableArray new];
	[regexes addObject:regex];
}

-(void)addIndexFilter:(int)index
{
	if(!indices) indices=[NSMutableIndexSet new];
	[indices addIndex:index];
}

-(void)setIndices:(NSIndexSet *)newindices
{
	if(!indices) indices=[NSMutableIndexSet new];
	[indices removeAllIndexes];
	[indices addIndexes:newindices];
}




-(off_t)predictedTotalSize { return [self predictedTotalSizeIgnoringUnknownFiles:NO]; }

-(off_t)predictedTotalSizeIgnoringUnknownFiles:(BOOL)ignoreunknown
{
	off_t total=0;

	NSEnumerator *enumerator=[entries objectEnumerator];
	NSDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		NSNumber *num=[dict objectForKey:XADFileSizeKey];
		if(!num)
		{
			if(ignoreunknown) continue;
			else return -1;
		}

		total+=[num longLongValue];
	}

	return total;
}




-(int)numberOfItemsExtracted { return numextracted; }

-(BOOL)wasSoloItem { return lookslikesolo; }

-(NSString *)actualDestination { return finaldestination; }

-(NSString *)soloItem { return soloitem; }

-(NSString *)createdItem
{
	if(!enclosingdir) return nil;
	else if(lookslikesolo && removesolo) return soloitem;
	else return finaldestination;
}

-(NSString *)createdItemOrActualDestination
{
	if(lookslikesolo && enclosingdir && removesolo) return soloitem;
	else return finaldestination;
}




-(XADError)parse
{
	if([entries count]) [NSException raise:NSInternalInconsistencyException format:@"You can not call parseAndUnarchive twice"];

	// Run parser to find archive entries.
	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	if(error) return error;

	if(extractsubarchives)
	{
		// Check if we have a single entry, which is an archive.
		if([entries count]==1)
		{
			NSDictionary *entry=[entries objectAtIndex:0];
			NSNumber *archnum=[entry objectForKey:XADIsArchiveKey];
			BOOL isarc=archnum&&[archnum boolValue];
			if(isarc) return [self _setupSubArchiveForEntryWithDictionary:entry];
		}

		// Check if we have two entries, which are data and resource forks
		// of the same archive.
		if([entries count]==2)
		{
			NSDictionary *first=[entries objectAtIndex:0];
			NSDictionary *second=[entries objectAtIndex:1];
			XADPath *name1=[first objectForKey:XADFileNameKey];
			XADPath *name2=[second objectForKey:XADFileNameKey];
			NSNumber *archnum1=[first objectForKey:XADIsArchiveKey];
			NSNumber *archnum2=[second objectForKey:XADIsArchiveKey];
			BOOL isarc1=archnum1&&[archnum1 boolValue];
			BOOL isarc2=archnum2&&[archnum2 boolValue];

			if([name1 isEqual:name2] && (isarc1||isarc2))
			{
				NSNumber *resnum=[first objectForKey:XADIsResourceForkKey];
				NSDictionary *datafork,*resourcefork;
				if(resnum&&[resnum boolValue])
				{
					datafork=second;
					resourcefork=first;
				}
				else
				{
					datafork=first;
					resourcefork=second;
				}

				// TODO: Handle resource forks for archives that require them.
				NSNumber *archnum=[datafork objectForKey:XADIsArchiveKey];
				if(archnum&&[archnum boolValue]) return [self _setupSubArchiveForEntryWithDictionary:datafork];
			}
		}
	}

	return XADNoError;
}

-(XADError)_setupSubArchiveForEntryWithDictionary:(NSDictionary *)dict
{
	// Create unarchiver.
	XADError error;
	subunarchiver=[[unarchiver unarchiverForEntryWithDictionary:dict
	wantChecksum:YES error:&error] retain];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADSubArchiveError;
	}
	return XADNoError;
}




-(XADError)unarchive
{
	if(subunarchiver) return [self _unarchiveSubArchive];
	else return [self _unarchiveRegularArchive];
}

-(XADError)_unarchiveRegularArchive
{
	NSEnumerator *enumerator;
	NSDictionary *entry;

	// Calculate total size and check if there is a single top-level item.
	totalsize=0;
	totalprogress=0;

	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSNumber *dirnum=[entry objectForKey:XADIsDirectoryKey];
		BOOL isdir=dirnum && [dirnum boolValue];

		// If we have not given up on calculating a total size, and this
		// is not a directory, add the size of the current item.
		if(totalsize>=0 && !isdir)
		{
			NSNumber *size=[entry objectForKey:XADFileSizeKey];

			// Disable accurate progress calculation if any sizes are unknown.
			if(size) totalsize+=[size longLongValue];
			else totalsize=-1;
		}
		

		// Run test for single top-level items.
		[self _testForSoloItems:entry];
	}

	// Figure out actual destination to write to.
	NSString *destpath;
	BOOL shouldremove=removesolo && lookslikesolo;
	if(enclosingdir && !shouldremove)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		// Check for collision.
		destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
		if(!destpath) return XADNoError;
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	unpackdestination=[destpath retain];
	finaldestination=[destpath retain];

	// Run unarchiver on all entries.
	[unarchiver setDelegate:self];

	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		if([self _shouldStop]) return XADBreakError;

		if(totalsize>=0) currsize=[[entry objectForKey:XADFileSizeKey] longLongValue];

		XADError error=[unarchiver extractEntryWithDictionary:entry];
		if(error==XADBreakError) return XADBreakError;

		if(totalsize>=0) totalprogress+=currsize;
	}

	if([self _shouldStop]) return XADBreakError;

	// If we ended up extracting nothing, give up.
	if(!numextracted) return XADNoError;

	// If we unpacked a solo item, remember its path.
	soloitem=[[self _findPathForSoloItem] retain];

	return [self _finalizeExtraction];
}

-(XADError)_unarchiveSubArchive
{
	XADError error;

	// Figure out actual destination to write to.
	NSString *destpath,*originaldest=nil;
	if(enclosingdir)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		if(removesolo)
		{
			// If there is a possibility we might remove the enclosing directory
			// later, do not handle collisions until after extraction is finished.
			// For now, just pick a unique name if necessary.
			if([XADPlatform fileExistsAtPath:destpath])
			{
				originaldest=destpath;
				destpath=[XADSimpleUnarchiver _findUniquePathForOriginalPath:destpath];
			}
		}
		else
		{
			// Check for collision.
			destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
			if(!destpath) return XADNoError;
		}
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	unpackdestination=[destpath retain];

	// Disable accurate progress calculation.
	totalsize=-1;

	// Parse sub-archive and automatically unarchive its contents.
	// At this stage, files are guaranteed to be written to unpackdestination
	// and never outside it.
	[subunarchiver setDelegate:self];
	error=[subunarchiver parseAndUnarchive];

	// Check if the caller wants to give up.
	if(error==XADBreakError) return XADBreakError;
	if([self _shouldStop]) return XADBreakError;

	// If we ended up extracting nothing, give up.
	if(!numextracted) return error;

	// If we extracted a single item, remember its path.
	NSString *soloitempath=[self _findPathForSoloItem];

	// If we are removing the enclosing directory for solo items, check
	// how many items were extracted, and handle collisions and moving files.
	if(enclosingdir && removesolo)
	{
		if(lookslikesolo)
		{
			// Only one top-level item was unpacked. Move it to the parent
			// directory and remove the enclosing directory.
			NSString *itemname=[soloitempath lastPathComponent];

			// To avoid trouble, first rename the enclosing directory
			// to something unique.
			NSString *enclosingpath=destpath;
			NSString *newenclosingpath=[XADPlatform uniqueDirectoryPathWithParentDirectory:destination];
			[XADPlatform moveItemAtPath:enclosingpath toPath:newenclosingpath];

			NSString *newitempath=[newenclosingpath stringByAppendingPathComponent:itemname];

			// Figure out the new path, and check it for collisions.
			NSString *finalitempath;
			if(destination) finalitempath=[destination stringByAppendingPathComponent:itemname];
			else finalitempath=itemname;

			finalitempath=[self _checkPath:finalitempath forEntryWithDictionary:nil deferred:YES];
			if(!finalitempath)
			{
				// In case skipping was requested, delete everything and give up.
				[XADPlatform removeItemAtPath:newenclosingpath];
				numextracted=0;
				return error;
			}

			// Move the item into place and delete the enclosing directory.
			if(![self _recursivelyMoveItemAtPath:newitempath toPath:finalitempath overwrite:YES])
			error=XADFileExistsError; // TODO: Better error handling.

			[XADPlatform removeItemAtPath:newenclosingpath];

			// Remember where the item ended up.
			finaldestination=[[finalitempath stringByDeletingLastPathComponent] retain];
			soloitempath=finalitempath;

		}
		else
		{
			// Multiple top-level items were unpacked, so we keep the enclosing
			// directory, but we need to check if there was a collision while
			// creating it, and handle this.
			if(originaldest)
			{
				NSString *enclosingpath=destpath;
				NSString *newenclosingpath=[self _checkPath:originaldest forEntryWithDictionary:nil deferred:YES];
				if(!newenclosingpath)
				{
					// In case skipping was requested, delete everything and give up.
					[XADPlatform removeItemAtPath:enclosingpath];
					numextracted=0;
					return error;
				}
				else if([newenclosingpath isEqual:enclosingpath])
				{
					// If the selected new path is equal to the earlier picked
					// unique path, nothing needs to be done.
				}
				else
				{
					// Otherwise, move the directory at the unique path to the
					// new location selected. This may end up being the original
					// path that caused the collision.
					if(![self _recursivelyMoveItemAtPath:enclosingpath toPath:newenclosingpath overwrite:YES])
					error=XADFileExistsError; // TODO: Better error handling.
				}

				// Remember where the items ended up.
				finaldestination=[newenclosingpath retain];
			}
			else
			{
				// Remember where the items ended up.
				finaldestination=[destpath retain];
			}
		}
	}
	else
	{
		// Remember where the items ended up.
		finaldestination=[destpath retain];
	}

	// Save the final path to the solo item, if any.
	soloitem=[soloitempath retain];

	if(error) return error;

	return [self _finalizeExtraction];
}

-(XADError)_finalizeExtraction
{
	XADError error=[unarchiver finishExtractions];
	if(error) return error;

	// Update date of the enclosing directory (or single item), if requested.
	if(enclosingdir)
	{
		NSString *archivename=[[unarchiver archiveParser] filename];
		if(archivename)
		{
			if(lookslikesolo && removesolo)
			{
				// We are dealing with a solo item removed from the enclosing directory.
				if(copydatetosolo) [XADPlatform copyDateFromPath:archivename toPath:soloitem];
				else if(resetsolodate) [XADPlatform resetDateAtPath:soloitem];
			}
			else
			{
				// We are dealing with an enclosing directory.
				if(copydatetoenclosing) [XADPlatform copyDateFromPath:archivename toPath:finaldestination];
			}
		}
	}

	return XADNoError;
}

-(void)_testForSoloItems:(NSDictionary *)entry
{
	// If we haven't already discovered there are multiple top-level items, check
	// if this one has the same first first path component as the earlier ones.
	if(lookslikesolo || !toplevelname)
	{
		NSString *firstcomp=[[entry objectForKey:XADFileNameKey] firstCanonicalPathComponent];
		if(!toplevelname)
		{
			toplevelname=[firstcomp retain];
			lookslikesolo=YES;
		}
		else
		{
			if(![toplevelname isEqual:firstcomp]) lookslikesolo=NO;
		}
	}
}

-(NSString *)_findPathForSoloItem
{
	if(lookslikesolo)
	{
		NSArray *keys=[renames allKeys];
		if([keys count]==1)
		{
			id value=[[renames objectForKey:[keys objectAtIndex:0]] objectForKey:@"."];
			if(value!=[NSNull null]) return value;
		}
	}
	return nil;
}




-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	[entries addObject:dict];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return [self _shouldStop];
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason;
{
	[reasonsforinterest addObject:reason];
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(BOOL)unarchiver:(XADUnarchiver *)currunarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict suggestedPath:(NSString **)pathptr
{
	// If this is a sub-archive, we need to run the test for solo top-level items.
	if(currunarchiver==subunarchiver) [self _testForSoloItems:dict];

	// Decode name.
	XADPath *xadpath=[dict objectForKey:XADFileNameKey];
	NSString *encodingname=nil;
	if(delegate && ![xadpath encodingIsKnown])
	{
		encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:xadpath];
		if(!encodingname) return NO;
	}

	NSString *safefilename;
	if(encodingname) safefilename=[xadpath sanitizedPathStringWithEncodingName:encodingname];
	else safefilename=[xadpath sanitizedPathString];

	// Make sure to update path for resource forks.
	safefilename=[currunarchiver adjustPathString:safefilename forEntryWithDictionary:dict];

	// Apply filters.
	if(delegate)
	{
		// If any regex filters have been added, require that one matches.
		if(regexes)
		{
			BOOL found=NO;

			NSEnumerator *enumerator=[regexes objectEnumerator];
			XADRegex *regex;
			while(!found && (regex=[enumerator nextObject]))
			{
				if([regex matchesString:safefilename]) found=YES;
			}

			if(!found) return NO;
		}

		// If any index filters have been added, require that one matches.
		if(indices)
		{
			NSNumber *indexnum=[dict objectForKey:XADIndexKey];
			int index=[indexnum intValue];
			if(![indices containsIndex:index]) return NO;
		}
	}

	// Walk through the path, and check if any parts that have not already been
	// encountered collide, and cache results in the path hierarchy.
	NSMutableDictionary *parent=renames;
	NSString *path=unpackdestination;
	NSArray *components=[safefilename pathComponents];
	int numcomponents=[components count];
	for(int i=0;i<numcomponents;i++)
	{
		NSString *component=[components objectAtIndex:i];
		NSMutableDictionary *pathdict=[parent objectForKey:component];
		if(!pathdict)
		{
			// This path has not been encountered yet. First, build a
			// path based on the current component and the parent's path.
			path=[path stringByAppendingPathComponent:component];

			// Check it for collisions.
			path=[self _checkPath:path forEntryWithDictionary:dict deferred:NO];

			if(path)
			{
				// Store path and dictionary in path hierarchy.
				pathdict=[NSMutableDictionary dictionaryWithObject:path forKey:@"."];
				[parent setObject:pathdict forKey:component];
			}
			else
			{
				// If skipping was requested, store a marker in the path hierarchy
				// for future requests, and skip.
				pathdict=[NSMutableDictionary dictionaryWithObject:[NSNull null] forKey:@"."];
				[parent setObject:pathdict forKey:component];
				return NO;
			}
		}
		else
		{
			path=[pathdict objectForKey:@"."];

			// Check if this path was marked as skipped earlier.
			if((id)path==[NSNull null]) return NO;
		}

		parent=pathdict;
	}

	*pathptr=path;

	// If we have a delegate, ask it if we should extract.
	if(delegate) return [delegate simpleUnarchiver:self shouldExtractEntryWithDictionary:dict to:path];

	// Otherwise, just extract.
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarch willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	// If we are writing OS X or HFV resource forks, keep a list of which resource
	// forks have been extracted, for the collision tests in checkPath.
	int style=[unarch macResourceForkStyle];
	if(style==XADMacOSXForkStyle || style==XADHFVExplorerAppleDoubleForkStyle)
	{
		NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
		if(resnum && [resnum boolValue]) [resourceforks addObject:path];
	}

	[delegate simpleUnarchiver:self willExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	numextracted++;

	if(propagatemetadata && metadata) [XADPlatform writeCloneableMetadata:metadata toPath:path];

	[delegate simpleUnarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	if(!delegate) return nil;

	NSString *encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:link];
	if(!encodingname) return nil;

	return [link stringWithEncodingName:encodingname];
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return [self _shouldStop];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileratio estimatedTotalFraction:(double)totalratio
{
	if(!delegate) return;

	if(totalsize>=0)
	{
		// If the total size is known, report exact progress.
		off_t fileprogress=fileratio*currsize;
		[delegate simpleUnarchiver:self extractionProgressForEntryWithDictionary:dict
		fileProgress:fileprogress of:currsize
		totalProgress:totalprogress+fileprogress of:totalsize];
	}
	else
	{
		// If the total size is not known, report estimated progress.
		[delegate simpleUnarchiver:self estimatedExtractionProgressForEntryWithDictionary:dict
		fileProgress:fileratio totalProgress:totalratio];
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason
{
	[reasonsforinterest addObject:reason];
}

-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForSimpleUnarchiver:self];
}




-(NSString *)_checkPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict deferred:(BOOL)deferred
{
	// If set to always overwrite, just return the path without further checking.
	if(overwrite) return path;

	// Check for collision.
	if([XADPlatform fileExistsAtPath:path])
	{
		// When writing OS X data forks, some collisions will happen. Try
		// to handle these.
		#ifdef __APPLE__
		if(dict && [self macResourceForkStyle]==XADMacOSXForkStyle)
		{
			NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
			if(resnum && [resnum boolValue])
			{
				// If this entry is a resource fork, check if the resource fork
				// size is 0. If so, do not consider this a collision.
				const char *cpath=[path fileSystemRepresentation];
				size_t ressize=getxattr(cpath,XATTR_RESOURCEFORK_NAME,NULL,0,0,XATTR_NOFOLLOW);

				if(ressize==0) return path;
			}
			else
			{
				// If this entry is a data fork, check if we have earlier extracted this
				// file as a resource fork. If so, do not consider this a collision.
				if([resourceforks containsObject:path]) return path;
			}
		}
		#endif

		// HFV Explorer style forks always create dummy data forks, which can cause collisions.
		// Just kludge this by ignoring collisions for data forks if a resource was written earlier.
		if(dict && [self macResourceForkStyle]==XADHFVExplorerAppleDoubleForkStyle)
		{
			NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
			if(!resnum || ![resnum boolValue])
			{
				NSString *forkpath=[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
				[@"%" stringByAppendingString:[path lastPathComponent]]];

				if([resourceforks containsObject:forkpath]) return path;
			}
		}

		// If set to always skip, just return nil.
		if(skip) return nil;

		NSString *unique=[XADSimpleUnarchiver _findUniquePathForOriginalPath:path];

		if(rename)
		{
			// If set to always rename, just return the alternate path.
			return unique;
		}
		else if(delegate)
		{
			// If we have a delegate, ask it.
			if(deferred) return [delegate simpleUnarchiver:self
			deferredReplacementPathForOriginalPath:path
			suggestedPath:unique];
			else return [delegate simpleUnarchiver:self
			replacementPathForEntryWithDictionary:dict
			originalPath:path suggestedPath:unique];
		}
		else
		{
			// By default, skip file.
			return nil;
		}
	}
	else return path;
}

-(BOOL)_recursivelyMoveItemAtPath:(NSString *)src toPath:(NSString *)dest overwrite:(BOOL)overwritethislevel
{
	// Check path unless we are sure we are overwriting, and skip if requested.
	if(!overwritethislevel) dest=[self _checkPath:dest forEntryWithDictionary:nil deferred:YES];
	if(!dest) return YES;

	BOOL isdestdir;
	if([XADPlatform fileExistsAtPath:dest isDirectory:&isdestdir])
	{
		BOOL issrcdir;
		if(![XADPlatform fileExistsAtPath:src isDirectory:&issrcdir]) return NO;

		if(issrcdir&&isdestdir)
		{
			// If both source and destinaton are directories, iterate over the
			// contents and recurse.
			NSArray *files=[XADPlatform contentsOfDirectoryAtPath:src];
			NSEnumerator *enumerator=[files objectEnumerator];
			NSString *file;
			while((file=[enumerator nextObject]))
			{
				NSString *newsrc=[src stringByAppendingPathComponent:file];
				NSString *newdest=[dest stringByAppendingPathComponent:file];
				BOOL res=[self _recursivelyMoveItemAtPath:newsrc toPath:newdest overwrite:NO];
				if(!res) return NO; // TODO: Should this try to move the remaining items?
			}
			return YES;
		}
		else if(!issrcdir&&!isdestdir)
		{
			// If both are files, remove any existing file, then move.
			[XADPlatform removeItemAtPath:dest];
			return [XADPlatform moveItemAtPath:src toPath:dest];
		}
		else
		{
			// Can't overwrite a file with a directory or vice versa.
			return NO;
		}
	}
	else
	{
		return [XADPlatform moveItemAtPath:src toPath:dest];
	}
}

+(NSString *)_findUniquePathForOriginalPath:(NSString *)path
{
	return [self _findUniquePathForOriginalPath:path reservedPaths:nil];
}

+(NSString *)_findUniquePathForOriginalPath:(NSString *)path reservedPaths:(NSSet *)reserved
{
	NSString *base=[path stringByDeletingPathExtension];
	NSString *extension=[path pathExtension];
	if([extension length]) extension=[@"." stringByAppendingString:extension];

	NSString *dest=path;
	int n=1;

	while([XADPlatform fileExistsAtPath:dest] || (reserved&&[reserved containsObject:dest]))
	dest=[NSString stringWithFormat:@"%@-%d%@",base,n++,extension];

	return dest;
}

@end



@implementation NSObject (XADSimpleUnarchiverDelegate)

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver {}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(id <XADString>)string; { return [string encodingName]; }

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return YES; }
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error {}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique { return nil; }
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique { return nil; }

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver { return NO; }

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress {}

@end
