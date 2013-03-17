#import "XADStuffItXParser.h"
#import "XADStuffItXBlockHandle.h"
#import "XADPPMdHandles.h"
#import "XADStuffItXCyanideHandle.h"
#import "XADStuffItXDarkhorseHandle.h"
#import "XADStuffItXIronHandle.h"
#import "XADStuffItXBlendHandle.h"
#import "XADStuffItXEnglishHandle.h"
#import "XADStuffItXX86Handle.h"
#import "XADDeflateHandle.h"
#import "XADRC4Handle.h"
#import "CSZlibHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "StuffItXUtilities.h"

typedef struct StuffItXElement
{
	int something,type;
	int64_t attribs[10];
	int64_t alglist[6];
	int64_t alglist3_extra;
	off_t dataoffset,actualsize;
	uint32_t datacrc;
} StuffItXElement;

static void ReadElement(CSHandle *fh,StuffItXElement *element);
static void ScanElementData(CSHandle *fh,StuffItXElement *element);
static CSHandle *HandleForElement(XADStuffItXParser *self,StuffItXElement *element,BOOL wantchecksum);
static void DumpElement(StuffItXElement *element);

static void ReadElement(CSHandle *fh,StuffItXElement *element)
{
	for(int i=0;i<10;i++) element->attribs[i]=-1;
	for(int i=0;i<6;i++) element->alglist[i]=-1;
	element->alglist3_extra=-1;

	element->something=[fh readBitsLE:1];
	element->type=ReadSitxP2(fh);

	for(;;)
	{
		int type=ReadSitxP2(fh);
		if(type==0) break;
		uint64_t value=ReadSitxP2(fh);
		if(type<=10) element->attribs[type-1]=value;
		else NSLog(@"attrib type too big: %d",type);
	}

	for(;;)
	{
		int type=ReadSitxP2(fh);
		if(type==0) break;
		uint64_t value=ReadSitxP2(fh);
		if(type<=6) element->alglist[type-1]=value;
		else NSLog(@"alglist type too big: %d",type);
		if(type==4) element->alglist3_extra=ReadSitxP2(fh);
	}

	element->dataoffset=[fh offsetInFile];
	element->actualsize=0;
}



static void ScanElementData(CSHandle *fh,StuffItXElement *element)
{
	[fh seekToFileOffset:element->dataoffset];
	[fh flushReadBits];

	for(;;)
	{
		uint64_t len=ReadSitxP2(fh);
		if(!len) break;
		[fh skipBytes:len];
	}

	[fh flushReadBits];
	uint64_t len=ReadSitxP2(fh);

	if(len==0) return;
	else if(len==4)
	{
		element->datacrc=[fh readUInt32BE];
		len=ReadSitxP2(fh);
	}

	while(len)
	{
		[fh skipBytes:len];
		len=ReadSitxP2(fh);
	}
}



static CSHandle *HandleForElement(XADStuffItXParser *self,StuffItXElement *element,BOOL wantchecksum)
{
	CSHandle *fh=[self handle];

	int64_t compressionalgorithm=element->alglist[0];
	int64_t checksumalgorithm=element->alglist[1];
	int64_t preprocessalgorithm=element->alglist[2];
	int64_t cryptoalgorithm=element->alglist[3];

	if(cryptoalgorithm>=0) [XADException raiseNotSupportedException];

	[fh seekToFileOffset:element->dataoffset];
	[fh flushReadBits];

	CSHandle *handle=[[[XADStuffItXBlockHandle alloc] initWithHandle:fh] autorelease];

	off_t uncompressedlength;
	if(element->alglist[2]==0) uncompressedlength=CSHandleMaxLength;
	else uncompressedlength=element->actualsize;

	switch(compressionalgorithm)
	{
		case -1: break; // no compression

		case 0: // Brimstone/PPMd
		{
			int allocsize=1<<[handle readUInt8];
			int order=[handle readUInt8];
			handle=[[[XADStuffItXBrimstoneHandle alloc] initWithHandle:handle
			length:uncompressedlength maxOrder:order subAllocSize:allocsize] autorelease];
		}
		break;

		case 1: // Cyanide
			handle=[[[XADStuffItXCyanideHandle alloc] initWithHandle:handle
			length:uncompressedlength] autorelease];
		break;

		case 2: // Darkhorse
		{
			int windowsize=1<<[handle readUInt8];
			if(windowsize<0x100000) windowsize=0x100000;
			handle=[[[XADStuffItXDarkhorseHandle alloc] initWithHandle:handle
			length:uncompressedlength windowSize:windowsize] autorelease];
		}
		break;

		case 3: // Modified Deflate
		{
			int windowsize=[handle readUInt8];
			if(windowsize!=15) return nil; // alternate sizes are not supported, as no files have been found that use them
			handle=[[[XADDeflateHandle alloc] initWithHandle:handle
			length:uncompressedlength variant:XADStuffItXDeflateVariant] autorelease];
		}
		break;

		case 4: // Blend
			handle=[[[XADStuffItXBlendHandle alloc] initWithHandle:handle
			length:uncompressedlength] autorelease];
		break;

		case 5: // No compression, obscured by RC4
		{
			[handle skipBytes:2];
			NSData *key=[handle readDataOfLength:1];
			handle=[[[XADRC4Handle alloc] initWithHandle:handle key:key] autorelease];
		}
		break;

		case 6: // Iron
			handle=[[[XADStuffItXIronHandle alloc] initWithHandle:handle
			length:uncompressedlength] autorelease];
		break;

		default:
			[self reportInterestingFileWithReason:@"Unsupported compression method %qd",compressionalgorithm];
			return nil;
	}

	switch(preprocessalgorithm)
	{
		case -1: break; // no filtering

		case 0: // English
			handle=[[[XADStuffItXEnglishHandle alloc] initWithHandle:handle length:element->actualsize] autorelease];
		break;

//		case 1: // biff
//		break;

		case 2: // x86
			handle=[[[XADStuffItXX86Handle alloc] initWithHandle:handle length:element->actualsize] autorelease];
		break;

/*		case 3: // peff
		break;

		case 4: // m68k
		break;

		case 5: // sparc
		break;

		case 6: // tiff
		break;

		case 7: // wav
		break;

		case 8: // wrt
		break;
*/

		default:
			[self reportInterestingFileWithReason:@"Unsupported preprocessing method %qd",preprocessalgorithm];
			return nil;
	}

	if(wantchecksum&&checksumalgorithm==0)
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle
	length:element->actualsize correctCRC:element->datacrc conditioned:YES];

	return handle;
}



static void DumpElement(StuffItXElement *element)
{
	NSString *name;
	switch(element->type)
	{
		case 0: name=@"end"; break;
		case 1: name=@"data"; break;
		case 2: name=@"file"; break;
		case 3: name=@"fork"; break;
		case 4: name=@"directory"; break;
		case 5: name=@"catalog"; break;
		case 6: name=@"clue"; break;
		case 7: name=@"root"; break;
		case 8: name=@"boundary"; break;
		case 9: name=@"?"; break;
		case 10: name=@"receipt"; break;
		case 11: name=@"index"; break;
		case 12: name=@"locator"; break;
		case 13: name=@"id"; break;
		case 14: name=@"link"; break;
		case 15: name=@"segment_index"; break;
	}

	NSLog(@"(%d) %d: %@",element->something,element->type,name);

	for(int i=0;i<10;i++) if(element->attribs[i]>=0) NSLog(@"       attrib %d: %qu",i,element->attribs[i]);
	for(int i=0;i<6;i++) if(element->alglist[i]>=0) NSLog(@"       alglist %d: %qu",i,element->alglist[i]);
	if(element->alglist3_extra>=0) NSLog(@"       alglist 3 extra: %qu",element->alglist3_extra);
}



@implementation XADStuffItXParser

+(int)requiredHeaderSize { return 10; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;

	return bytes[0]=='S'&&bytes[1]=='t'&&bytes[2]=='u'&&bytes[3]=='f'&&bytes[4]=='f'
	&&bytes[5]=='I'&&bytes[6]=='t'&&(bytes[7]=='!'||bytes[7]=='?');
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		repeatedentrydata=nil;
		repeatedentries=nil;
	}
	return self;
}

-(void)dealloc
{
	[repeatedentrydata release];
	[repeatedentries release];
	[super dealloc];
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	[fh skipBytes:7];

	uint8_t encodingmarker=[fh readUInt8];
	if(encodingmarker=='?')
	{
		// The file has been encoded using a base-N encoder.
		// TODO: Support these encodings.
		[XADException raiseNotSupportedException];
	}

	NSMutableArray *entries=[NSMutableArray array];
	NSMutableDictionary *entrydict=[NSMutableDictionary dictionary];
	NSMutableDictionary *streamforks=[NSMutableDictionary dictionary];
	NSMutableSet *forkedset=[NSMutableSet set];

	while([self shouldKeepParsing])
	{
		StuffItXElement element;
		ReadElement(fh,&element);
		//DumpElement(&element);

		switch(element.type)
		{
			case 0: // end
				return;
			break;

			case 1: // data
			{
				int64_t objid=element.attribs[0];
				int64_t uncompsize=element.attribs[4];
				int64_t compressionalgorithm=element.alglist[0];
				int64_t preprocessalgorithm=element.alglist[2];

				ScanElementData(fh,&element);
				off_t pos=[fh offsetInFile];

				// Find actual size of stream
				NSMutableArray *forks=[streamforks objectForKey:[NSNumber numberWithLongLong:objid]];
				NSEnumerator *enumerator=[forks objectEnumerator];
				NSMutableDictionary *fork;
				while((fork=[enumerator nextObject]))
				{
					if((id)fork==[NSNull null]) [XADException raiseIllegalDataException];
					NSNumber *lengthnum=[fork objectForKey:@"Length"];
					element.actualsize+=[lengthnum longLongValue];
				}

				// Send out all the entries without data streams first
				if(forkedset)
				{
					NSEnumerator *enumerator=[entries objectEnumerator];
					NSMutableDictionary *entry;
					while((entry=[enumerator nextObject]))
					{
						if(![forkedset containsObject:[entry objectForKey:@"StuffItXID"]])
						{
							[entry setObject:[NSNumber numberWithLongLong:0] forKey:XADFileSizeKey];
							[entry setObject:[NSNumber numberWithLongLong:0] forKey:XADCompressedSizeKey];
							[entry setObject:[NSNumber numberWithBool:YES] forKey:@"StuffItXEmpty"];
							[self addEntryWithDictionary:entry];
						}
					}
					forkedset=nil;
				}

				off_t compsize=pos-element.dataoffset;

				NSString *compname;
				switch(compressionalgorithm)
				{
					case 0: compname=@"Brimstone/PPMd"; break;
					case 1: compname=@"Cyanide"; break;
					case 2: compname=@"Darkhorse"; break;
					case 3: compname=@"Deflate"; break;
					//case 4: compname=@"Darkhorse?"; break;
					case 5: compname=@"None"; break;
					case 6: compname=@"Iron"; break;
					//case 7: compname=@""; break;
					default: compname=[NSString stringWithFormat:@"Method %qd",compressionalgorithm]; break;
				}

				NSString *preprocessname;
				switch(preprocessalgorithm)
				{
					case -1: preprocessname=nil; break;
					case 0: preprocessname=@"English"; break;
					case 1: preprocessname=@"Biff"; break;
					case 2: preprocessname=@"x86"; break;
					case 3: preprocessname=@"PEFF"; break;
					case 4: preprocessname=@"M68k"; break;
					case 5: preprocessname=@"Sparc"; break;
					case 6: preprocessname=@"TIFF"; break;
					case 7: preprocessname=@"WAV"; break;
					case 8: preprocessname=@"WRT"; break;
					default: compname=[NSString stringWithFormat:@"Preprocess %qd",preprocessalgorithm]; break;
				}

				XADString *compnamestr;
				if(!preprocessname) compnamestr=[self XADStringWithString:compname];
				else compnamestr=[self XADStringWithString:[NSString stringWithFormat:@"%@+%@",compname,preprocessname]];

				NSValue *elementval=[NSValue valueWithBytes:&element objCType:@encode(StuffItXElement)];

				enumerator=[forks objectEnumerator];
				off_t offs=0;
				while((fork=[enumerator nextObject]))
				{
					if(![self shouldKeepParsing]) return;

					if((id)fork==[NSNull null]) [XADException raiseIllegalDataException];

					NSArray *entries=[fork objectForKey:@"Entries"];
					NSNumber *lengthnum=[fork objectForKey:@"Length"];
					NSNumber *offsnum=[NSNumber numberWithLongLong:offs];

					off_t currcompsize=[lengthnum longLongValue]*compsize/uncompsize;
					NSNumber *currcompsizenum=[NSNumber numberWithLongLong:currcompsize];

					// Type 0 is a data fork, type 1 is a resource fork. There are
					// furhter types, but these are not understood so ignore them.
					// Type 3 seems to be a thumbnail?
					int type=[[fork objectForKey:@"Type"] intValue];
					if(type==0||type==1)
					{
						BOOL isresfork=(type==1);

						NSEnumerator *entryenumerator=[entries objectEnumerator];
						NSNumber *entrynum;
						while((entrynum=[entryenumerator nextObject]))
						{
							NSDictionary *entry=[entrydict objectForKey:entrynum];
							NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithDictionary:entry];

							[dict setObject:elementval forKey:XADSolidObjectKey];
							[dict setObject:offsnum forKey:XADSolidOffsetKey];
							[dict setObject:lengthnum forKey:XADFileSizeKey];
							[dict setObject:lengthnum forKey:XADSolidLengthKey];
							[dict setObject:currcompsizenum forKey:XADCompressedSizeKey];
							[dict setObject:compnamestr forKey:XADCompressionNameKey];

							if(isresfork)
							[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

							if([entries count]>1)
							[dict setObject:entries forKey:@"StuffItXRepeatedEntries"];

							[self addEntryWithDictionary:dict];
						}
					}
					offs+=[lengthnum longLongValue];
				}

				[fh seekToFileOffset:pos];
			}
			break;

			case 2: // file
			{
				int64_t objid=element.attribs[0];
				int64_t parent=element.attribs[1];

				NSNumber *num=[NSNumber numberWithLongLong:objid];

				NSDictionary *file=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					num,@"StuffItXID",
					[NSNumber numberWithLongLong:parent],@"StuffItXParent",
				nil];

				[entries addObject:file];
				[entrydict setObject:file forKey:num];
			}
			break;

			case 3: // fork
			{
				int64_t entry=element.attribs[1];
				int64_t stream=element.attribs[2];
				int64_t index=element.attribs[3];
				int64_t length=element.attribs[4];

				uint64_t type=ReadSitxP2(fh);

				NSNumber *entrynum=[NSNumber numberWithLongLong:entry];
				NSNumber *streamnum=[NSNumber numberWithLongLong:stream];

				[forkedset addObject:entrynum];

				NSMutableArray *forks=[streamforks objectForKey:streamnum];
				if(!forks)
				{
					forks=[NSMutableArray array];
					[streamforks setObject:forks forKey:streamnum];
				}

				NSDictionary *dict=[NSDictionary dictionaryWithObjectsAndKeys:
					[NSMutableArray arrayWithObject:entrynum],@"Entries",
					[NSNumber numberWithInt:type],@"Type",
					[NSNumber numberWithLongLong:length],@"Length",
				nil];

				// Insert the fork at the right part of the data stream.
				// Forks can be specified out of order.
				int count=[forks count];
				if(index==count)
				{
					[forks addObject:dict];
				}
				else if(index>count)
				{
					for(int i=count;i<index;i++) [forks addObject:[NSNull null]];
					[forks addObject:dict];
				}
				else /*if(index<count)*/
				{
					// Multiple files can also reference the same fork.
					NSDictionary *curr=[forks objectAtIndex:index];
					if((id)curr==[NSNull null])
					{
						[forks replaceObjectAtIndex:index withObject:dict];
					}
					else
					{
						if([[curr objectForKey:@"Length"] longLongValue]!=length)
						[XADException raiseIllegalDataException];

						NSMutableArray *entries=[curr objectForKey:@"Entries"];
						[entries addObject:entrynum];
					}
				}
			}
			break;

			case 4: // directory
			{
				int64_t objid=element.attribs[0];
				int64_t parent=element.attribs[1];

				NSNumber *num=[NSNumber numberWithLongLong:objid];

				NSDictionary *dir=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					num,@"StuffItXID",
					[NSNumber numberWithLongLong:parent],@"StuffItXParent",
					[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				nil];

				[entries addObject:dir];
				[entrydict setObject:dir forKey:num];
			}
			break;

			case 5: // catalog
			{
				ScanElementData(fh,&element);
				element.actualsize=element.attribs[4];
				off_t pos=[fh offsetInFile];

				CSHandle *ch=HandleForElement(self,&element,NO);
				if(!ch) [XADException raiseNotSupportedException];
				[self parseCatalogWithHandle:ch entryArray:entries entryDictionary:entrydict];

				[fh seekToFileOffset:pos];
			}
			break;

			case 6: // clue
			{
				int64_t size=element.attribs[4];
				[fh skipBytes:size];
			}
			break;

			case 7: // root
			{
				/*uint64_t something=*/ReadSitxP2(fh);
				//NSLog(@"root: %qu",something);
			}
			break;

			case 8: // boundary
			break;

			case 9: // ?
			break;

			// case 10: // receipt
			// break;

			//case 11: // index
			//break;

			// case 12: // locator
			// break;

			// case 13: // id
			// break;

			// case 14: // link
			// break;

			// case 15: // segment_index
			// break;

			default:
				if(element.type>10) ScanElementData(fh,&element);
				else [XADException raiseNotSupportedException];
			break;
		}

		[fh flushReadBits];
	}
}

-(void)parseCatalogWithHandle:(CSHandle *)fh entryArray:(NSArray *)entries entryDictionary:(NSDictionary *)dict
{
	NSEnumerator *enumerator=[entries objectEnumerator];
	NSMutableDictionary *entry;
	while((entry=[enumerator nextObject]))
	{
		for(;;)
		{
			int key=ReadSitxP2(fh);
			if(!key) break;

			switch(key)
			{
				case 1: // filename
				{
					NSData *filename=ReadSitxString(fh);

					XADPath *path;
					NSDictionary *parent=[dict objectForKey:[entry objectForKey:@"StuffItXParent"]];

					if(parent) path=[[parent objectForKey:XADFileNameKey]
					pathByAppendingXADStringComponent:[self XADStringWithData:filename]];
					else path=[self XADPathWithData:filename separators:XADNoPathSeparator];

					[entry setObject:path forKey:XADFileNameKey];
				}
				break;

				case 2: // modification time
					[entry setObject:[NSDate XADDateWithTimeIntervalSince1601:(double)ReadSitxUInt64(fh)/10000000]
					forKey:XADLastModificationDateKey];
				break;

				case 3:
					NSLog(@"3: %x",ReadSitxUInt32(fh));
				break;

				case 4: // finder info?
				case 5: // ?
				{
					NSData *data=ReadSitxData(fh,32);

					if(memcmp([data bytes],"slnkrhap",8)==0)
					{
						[entry setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];
					}
					else
					{
						[entry setObject:data forKey:XADFinderInfoKey];
					}
				}
				break;

				case 6:
				{
					int hasowner=[fh readBitsLE:8];
					[entry setObject:[NSNumber numberWithUnsignedInt:ReadSitxUInt32(fh)] forKey:XADPosixPermissionsKey];
					if(hasowner)
					{
						[entry setObject:[NSNumber numberWithUnsignedInt:ReadSitxUInt32(fh)] forKey:XADPosixUserKey];
						[entry setObject:[NSNumber numberWithUnsignedInt:ReadSitxUInt32(fh)] forKey:XADPosixGroupKey];
					}
				}
				break;

				case 7:
				{
					int val=ReadSitxP2(fh);
					NSLog(@"7: %d",val);
				}
				break;

				case 8: // creation time
					[entry setObject:[NSDate XADDateWithTimeIntervalSince1601:(double)ReadSitxUInt64(fh)/10000000]
					forKey:XADCreationDateKey];
				break;

				case 9:
				{
					NSData *data=ReadSitxString(fh);
					if(data&&[data length])
					[entry setObject:[self XADStringWithData:data] forKey:XADCommentKey];
				}
				break;

				case 10:
				{
					int num=ReadSitxP2(fh);
					for(int i=0;i<num;i++)
					NSLog(@"10: %@",[self XADStringWithData:ReadSitxString(fh)]);
				}
				break;

				case 11:
					NSLog(@"11: %@",[self XADStringWithData:ReadSitxString(fh)]);
				break;

				case 12:
					NSLog(@"12: %@",[self XADStringWithData:ReadSitxString(fh)]);
				break;

				default:
					NSLog(@"unknown tag %d",key);
					[XADException raiseNotSupportedException];
				break;
			}
		}
		[fh flushReadBits];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	if([dict objectForKey:@"StuffItXEmpty"]) return [self zeroLengthHandleWithChecksum:checksum];

	// Because multiple files can reference the same part of a stream,
	// we try to cache those files to avoid restarts (if they are smaller
	// than 16 megabytes).
	// TODO: Should the data be released at some point?
	NSArray *repeat=[dict objectForKey:@"StuffItXRepeatedEntries"];
	NSNumber *filesize=[dict objectForKey:XADFileSizeKey];
	if(repeat && [filesize longLongValue]<0x1000000)
	{
		if(repeat!=repeatedentries)
		{
			[repeatedentrydata release];
			[repeatedentries release];

			repeatedentries=[repeat retain];

			CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

			repeatedentrydata=[[handle remainingFileContents] retain];
			repeatedentryhaschecksum=[handle hasChecksum];
			repeatedentryiscorrect=[handle isChecksumCorrect];
		}

		return [[[XADStuffItXRepeatedEntryHandle alloc] initWithData:repeatedentrydata
		hasChecksum:repeatedentryhaschecksum isChecksumCorrect:repeatedentryiscorrect] autorelease];
	}
	else
	{
		return [self subHandleFromSolidStreamForEntryWithDictionary:dict];
	}
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	StuffItXElement element;
	[obj getValue:&element];

	return HandleForElement(self,&element,checksum);
}

-(NSString *)formatName { return @"StuffIt X"; }

@end




@implementation XADStuffItXRepeatedEntryHandle

-(id)initWithData:(NSData *)data hasChecksum:(BOOL)hascheck isChecksumCorrect:(BOOL)iscorrect
{
	if((self=[super initWithData:data]))
	{
		haschecksum=hascheck;
		ischecksumcorrect=iscorrect;
	}
	return self;
}

-(BOOL)hasChecksum { return haschecksum; }
-(BOOL)isChecksumCorrect { return ischecksumcorrect; }

@end

