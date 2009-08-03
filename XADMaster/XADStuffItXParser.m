#import "XADStuffItXParser.h"
#import "XADStuffItXBlockHandle.h"
#import "XADPPMdHandles.h"
#import "XADStuffItXCyanideHandle.h"
#import "XADStuffItXDarkhorseHandle.h"
#import "XADStuffItXIronHandle.h"
#import "XADStuffItXBlendHandle.h"
#import "XADStuffItXEnglishHandle.h"
#import "XADDeflateHandle.h"
#import "XADRC4Handle.h"
#import "CSZlibHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "StuffItXUtilities.h"

typedef struct StuffItXElement
{
	int something,type;
	int64_t attribs[9];
	int64_t alglist[4];
	off_t dataoffset;
	uint32_t datacrc;
} StuffItXElement;

static void ReadElement(CSHandle *fh,StuffItXElement *element);
static void ScanElementData(CSHandle *fh,StuffItXElement *element);
static CSHandle *HandleForElement(CSHandle *fh,StuffItXElement *element,BOOL wantchecksum);
static void DumpElement(StuffItXElement *element);

static void ReadElement(CSHandle *fh,StuffItXElement *element)
{
	for(int i=0;i<9;i++) element->attribs[i]=-1;
	for(int i=0;i<4;i++) element->alglist[i]=-1;

	element->something=[fh readBitsLE:1];
	element->type=ReadSitxP2(fh);

	for(;;)
	{
		int type=ReadSitxP2(fh);
		if(type==0) break;
		uint64_t value=ReadSitxP2(fh);
		if(type<=9) element->attribs[type-1]=value;
		else NSLog(@"attrib type too big: %d",type);
	}

	for(;;)
	{
		int type=ReadSitxP2(fh);
		if(type==0) break;
		uint64_t value=ReadSitxP2(fh);
		if(type<=4) element->alglist[type-1]=value;
		else NSLog(@"alglist type too big: %d",type);
		if(type==4) NSLog(@"4 extra: %qu",ReadSitxP2(fh));
	}

	element->dataoffset=[fh offsetInFile];
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



static CSHandle *HandleForElement(CSHandle *fh,StuffItXElement *element,BOOL wantchecksum)
{
	[fh seekToFileOffset:element->dataoffset];
	[fh flushReadBits];

	CSHandle *handle=[[[XADStuffItXBlockHandle alloc] initWithHandle:fh] autorelease];

	off_t length;
	if(element->alglist[2]==0) length=CSHandleMaxLength;
	else length=element->attribs[4];

	switch(element->alglist[0])
	{
		case -1: break; // no compression

		case 0: // Brimstone/PPMd
		{
			int allocsize=1<<[handle readUInt8];
			int order=[handle readUInt8];
			handle=[[[XADStuffItXBrimstoneHandle alloc] initWithHandle:handle
			length:length maxOrder:order subAllocSize:allocsize] autorelease];
		}
		break;

		case 1: // Cyanide
			handle=[[[XADStuffItXCyanideHandle alloc] initWithHandle:handle length:length] autorelease];
		break;

		case 2: // Darkhorse
		{
			int windowsize=1<<[handle readUInt8];
			if(windowsize<0x100000) windowsize=0x100000;
			handle=[[[XADStuffItXDarkhorseHandle alloc] initWithHandle:handle
			length:length windowSize:windowsize] autorelease];
		}
		break;

		case 3: // Modified Deflate
		{
			int windowsize=[handle readUInt8];
			if(windowsize!=15) return nil; // alternate sizes are not supported, as no files have been found that use them
			handle=[[[XADDeflateHandle alloc] initWithHandle:handle
			length:length variant:XADStuffItXDeflateVariant] autorelease];
		}
		break;

		case 4: // Blend
			handle=[[[XADStuffItXBlendHandle alloc] initWithHandle:handle length:length] autorelease];
		break;

		case 5: // No compression, obscured by RC4
		{
			[handle skipBytes:2];
			NSData *key=[handle readDataOfLength:1];
			handle=[[[XADRC4Handle alloc] initWithHandle:handle key:key] autorelease];
		}
		break;

		case 6: // Iron
			handle=[[[XADStuffItXIronHandle alloc] initWithHandle:handle length:length] autorelease];
		break;

		default:
			return nil;
	}

	if(element->alglist[2]==0)
	handle=[[[XADStuffItXEnglishHandle alloc] initWithHandle:handle length:element->attribs[4]] autorelease];

	if(wantchecksum&&element->alglist[1]==0)
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle
	length:element->attribs[4] correctCRC:element->datacrc conditioned:YES];

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

	for(int i=0;i<9;i++) if(element->attribs[i]>=0) NSLog(@"       attrib %d: %qu",i,element->attribs[i]);
	for(int i=0;i<4;i++) if(element->alglist[i]>=0) NSLog(@"       alglist %d: %qu",i,element->alglist[i]);
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

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	[fh skipBytes:10];

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
				ScanElementData(fh,&element);
				off_t pos=[fh offsetInFile];

				// Send out all the entries without data streams first
				if(forkedset)
				{
					NSEnumerator *enumerator=[entries objectEnumerator];
					NSMutableDictionary *entry;
					while(entry=[enumerator nextObject])
					{
						if(![forkedset containsObject:[entry objectForKey:@"StuffItXID"]])
						{
							[entry setObject:[NSNumber numberWithLongLong:0] forKey:XADFileSizeKey];
							[entry setObject:[NSNumber numberWithLongLong:0] forKey:XADCompressedSizeKey];
							[self addEntryWithDictionary:entry];
						}
					}
					forkedset=nil;
				}

				off_t compsize=pos-element.dataoffset;
				off_t uncompsize=element.attribs[4];

				NSMutableArray *forks=[streamforks objectForKey:[NSNumber numberWithLongLong:element.attribs[0]]];
				NSValue *elementval=[NSValue valueWithBytes:&element objCType:@encode(StuffItXElement)];

				NSEnumerator *enumerator=[forks objectEnumerator];
				NSMutableDictionary *fork;
				while(fork=[enumerator nextObject])
				{
					if(![self shouldKeepParsing]) return;

					NSMutableDictionary *entry=[entrydict objectForKey:[fork objectForKey:@"Entry"]];
					NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithDictionary:entry];

					[dict setObject:elementval forKey:XADSolidObjectKey];
					[dict setObject:[fork objectForKey:@"Offset"] forKey:XADSolidOffsetKey];

					NSNumber *length=[fork objectForKey:@"Length"];
					[dict setObject:length forKey:XADFileSizeKey];
					[dict setObject:length forKey:XADSolidLengthKey];
					[dict setObject:[NSNumber numberWithLongLong:[length longLongValue]*compsize/uncompsize] forKey:XADCompressedSizeKey];

					if([[fork objectForKey:@"Type"] intValue]==1)
					[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

					NSString *compname=nil;
					switch(element.alglist[0])
					{
						case 0: compname=@"Brimstone/PPMd"; break;
						case 1: compname=@"Cyanide"; break;
						case 2: compname=@"Darkhorse"; break;
						case 3: compname=@"Deflate"; break;
						//case 4: compname=@"Darkhorse?"; break;
						case 5: compname=@"None"; break;
						case 6: compname=@"Iron"; break;
						//case 7: compname=@""; break;
						default: compname=[NSString stringWithFormat:@"Method %d",(int)element.alglist[0]]; break;
					}
					[dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

					[self addEntryWithDictionary:dict];
				}

				[fh seekToFileOffset:pos];
			}
			break;

			case 2: // file
			{
				NSNumber *num=[NSNumber numberWithLongLong:element.attribs[0]];
				NSDictionary *file=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					num,@"StuffItXID",
					[NSNumber numberWithLongLong:element.attribs[1]],@"StuffItXParent",
				nil];
				[entries addObject:file];
				[entrydict setObject:file forKey:num];
			}
			break;

			case 3: // fork
			{
				uint64_t type=ReadSitxP2(fh);

				NSNumber *entrynum=[NSNumber numberWithLongLong:element.attribs[1]];
				NSNumber *streamnum=[NSNumber numberWithLongLong:element.attribs[2]];

				[forkedset addObject:entrynum];

				off_t offs;
				NSMutableArray *forks=[streamforks objectForKey:streamnum];
				if(forks)
				{
					NSMutableDictionary *last=[forks lastObject];
					offs=[[last objectForKey:@"Offset"] longLongValue]+[[last objectForKey:@"Length"] longLongValue];
				}
				else
				{
					forks=[NSMutableArray array];
					offs=0;
					[streamforks setObject:forks forKey:streamnum];
				}

				[forks addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
					entrynum,@"Entry",
					[NSNumber numberWithInt:type],@"Type",
					[NSNumber numberWithLongLong:offs],@"Offset",
					[NSNumber numberWithLongLong:element.attribs[4]],@"Length",
				nil]];
			}
			break;

			case 4: // directory
			{
				NSNumber *num=[NSNumber numberWithLongLong:element.attribs[0]];
				NSDictionary *dir=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					num,@"StuffItXID",
					[NSNumber numberWithLongLong:element.attribs[1]],@"StuffItXParent",
					[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				nil];
				[entries addObject:dir];
				[entrydict setObject:dir forKey:num];
			}
			break;

			case 5: // catalog
			{
				ScanElementData(fh,&element);
				off_t pos=[fh offsetInFile];

				CSHandle *ch=HandleForElement(fh,&element,NO);
				if(!ch) [XADException raiseNotSupportedException];
				[self parseCatalogWithHandle:ch entryArray:entries entryDictionary:entrydict];

				[fh seekToFileOffset:pos];
			}
			break;

			case 6: // clue
				[fh skipBytes:element.attribs[4]];
			break;

			case 7: // root
			{
				uint64_t something=ReadSitxP2(fh);
				NSLog(@"root: %qu",something);
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
	while(entry=[enumerator nextObject])
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
					pathByAppendingPathComponent:[self XADStringWithData:filename]];
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
					[entry setObject:ReadSitxData(fh,32) forKey:XADFinderInfoKey];
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
					NSLog(@"unknown tag");
					[XADException raiseNotSupportedException];
				break;
			}
		}
		[fh flushReadBits];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self subHandleFromSolidStreamForEntryWithDictionary:dict];
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	StuffItXElement element;
	[obj getValue:&element];

	return HandleForElement([self handle],&element,checksum);
}

-(NSString *)formatName { return @"StuffIt X"; }

@end



