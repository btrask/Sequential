#import "XADCABParser.h"
#import "XADCABBlockReader.h"
#import "XADMSZipHandle.h"
#import "XADQuantumHandle.h"
#import "XADMSLZXHandle.h"
#import "XADCRCHandle.h"
#import "XADPlatform.h"
#import "NSDateXAD.h"
#import "CSMemoryHandle.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"
#import "Scanning.h"

#include <dirent.h>



typedef struct CABHeader
{
	off_t cabsize;
	off_t fileoffs;
	int minorversion,majorversion;
	int numfolders,numfiles;
	int flags;
	int setid,cabindex;

	int headerextsize,folderextsize,datablockextsize;

	NSData *nextvolume,*prevvolume;
} CABHeader;

static CABHeader ReadCABHeader(CSHandle *fh);
static void SkipCString(CSHandle *fh);
static NSData *ReadCString(CSHandle *fh);
static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname,NSArray *dircontents);



@implementation XADCABParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=4&&bytes[0]=='M'&&bytes[1]=='S'&&bytes[2]=='C'&&bytes[3]=='F';
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	NSArray *res=nil;
	@try
	{
		CSHandle *fh=[CSMemoryHandle memoryHandleForReadingData:data];
		CABHeader firsthead=ReadCABHeader(fh);

		if(!firsthead.prevvolume && !firsthead.nextvolume) return nil;

		NSString *dirname=[name stringByDeletingLastPathComponent];
		if(!dirname) dirname=@".";

		NSArray *dircontents=[XADPlatform contentsOfDirectoryAtPath:dirname];
		if(!dircontents) return [NSArray array];

		NSMutableArray *volumes=[NSMutableArray arrayWithObject:name];

		NSData *namedata=firsthead.prevvolume;
		int lastindex=firsthead.cabindex;
		while(namedata)
		{
			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			CSHandle *fh=FindHandleForName(namedata,dirname,dircontents);
			[volumes insertObject:[fh name] atIndex:0];
			CABHeader head=ReadCABHeader(fh);
			if(head.cabindex!=lastindex-1) @throw @"Index mismatch";

			namedata=[head.prevvolume retain];
			lastindex=head.cabindex;
			[pool release];
			[namedata autorelease];
		}

		if(lastindex!=0) @throw @"Couldn't find first volume";
		res=volumes;

		namedata=firsthead.nextvolume;
		lastindex=firsthead.cabindex;
		while(namedata)
		{
			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			CSHandle *fh=FindHandleForName(namedata,dirname,dircontents);
			[volumes addObject:[fh name]];
			CABHeader head=ReadCABHeader(fh);
			if(head.cabindex!=lastindex+1) @throw @"Index mismatch";

			namedata=[head.nextvolume retain];
			lastindex=head.cabindex;
			[pool release];
			[namedata autorelease];
		}
	}
	@catch(id e) { NSLog(@"CAB volume scanning error: %@",e); }

	return res;
}



-(void)parse
{
	CSHandle *fh=[self handle];

	off_t baseoffs=[fh offsetInFile];

	NSMutableArray *files=[NSMutableArray array];
	NSMutableArray *folders=[NSMutableArray array];

	for(;;)
	{
		CABHeader head=ReadCABHeader(fh);

		for(int i=0;i<head.numfolders;i++)
		{
			uint32_t dataoffs=[fh readUInt32LE];
			int numblocks=[fh readUInt16LE];
			int method=[fh readUInt16LE];
			[fh skipBytes:head.folderextsize];

			XADCABBlockReader *blocks;
			if(i==0&&[folders count]==1) // Continuing a folder from last volume
			{
				NSDictionary *folder=[folders objectAtIndex:0];
				if(method!=[[folder objectForKey:@"Method"] intValue]) [XADException raiseIllegalDataException];
				blocks=[folder objectForKey:@"BlockReader"];
			}
			else
			{
				blocks=[[[XADCABBlockReader alloc] initWithHandle:fh reservedBytes:head.datablockextsize] autorelease];
				[folders addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
					blocks,@"BlockReader",
					[NSNumber numberWithInt:method],@"Method",
				nil]];
			}

			[blocks addFolderAtOffset:baseoffs+dataoffs numberOfBlocks:numblocks];
		}

		[fh seekToFileOffset:baseoffs+head.fileoffs];

		BOOL continuingfolder=NO;

		for(int i=0;i<head.numfiles;i++)
		{
			uint32_t filesize=[fh readUInt32LE];
			uint32_t folderoffs=[fh readUInt32LE];
			int folderindex=[fh readUInt16LE];
			int date=[fh readUInt16LE];
			int time=[fh readUInt16LE];
			int attribs=[fh readUInt16LE];
			NSData *namedata=ReadCString(fh);

			if(folderindex==0xffff||folderindex==0xfffe)
			{
				folderindex=head.numfolders-1;
				continuingfolder=YES;
			}
			else if(folderindex==0xfffd)
			{
				folderindex=0;
			}
			
			if(folderindex>=head.numfolders) [XADException raiseIllegalDataException];
			NSDictionary *folder=[folders objectAtIndex:folderindex];

			XADPath *name;
			if(attribs&0x80) name=[self XADPathWithData:namedata encodingName:XADUTF8StringEncodingName separators:XADEitherPathSeparator];
			else name=[self XADPathWithData:namedata separators:XADEitherPathSeparator];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:filesize],XADFileSizeKey,
				[NSDate XADDateWithMSDOSDate:date time:time],XADLastModificationDateKey,
				[NSNumber numberWithUnsignedInt:folderoffs],XADSolidOffsetKey,
				[NSNumber numberWithUnsignedInt:filesize],XADSolidLengthKey,
				folder,XADSolidObjectKey,
			nil];

			int method=[[folder objectForKey:@"Method"] intValue];
			NSString *methodname=nil;
			switch(method&0x0f)
			{
				case 0: methodname=@"None"; break;
				case 1: methodname=@"MSZIP"; break;
				case 2: methodname=[NSString stringWithFormat:@"Quantum:%d",(method>>8)&0x1f]; break;
				case 3: methodname=[NSString stringWithFormat:@"LZX:%d",(method>>8)&0x1f]; break;
			}
			if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

			[files addObject:dict];
		}

		off_t position=[fh offsetInFile];

		while([folders count]>(continuingfolder?1:0))
		{
			NSMutableDictionary *folder=[folders objectAtIndex:0];

			XADCABBlockReader *blocks=[folder objectForKey:@"BlockReader"];
			[blocks scanLengths];

			[folders removeObjectAtIndex:0];
		}

		NSMutableDictionary *continuedfolder=nil;
		if(continuingfolder) continuedfolder=[folders lastObject];

		while([files count]>0)
		{
			NSMutableDictionary *file=[files objectAtIndex:0];

			if([file objectForKey:XADSolidObjectKey]==continuedfolder) break;

			off_t filesize=[[file objectForKey:XADFileSizeKey] longLongValue];
			XADCABBlockReader *blocks=[[file objectForKey:XADSolidObjectKey] objectForKey:@"BlockReader"];
			off_t streamcompsize=[blocks compressedLength];
			off_t streamuncompsize=[blocks uncompressedLength];

			[file setObject:[NSNumber numberWithLongLong:filesize*streamcompsize/streamuncompsize] forKey:XADCompressedSizeKey];

			[self addEntryWithDictionary:file];
			[files removeObjectAtIndex:0];
		}

		[fh seekToFileOffset:position];

		if([fh respondsToSelector:@selector(currentHandle)])
		{
			[[(id)fh currentHandle] seekToEndOfFile];
			if([fh atEndOfFile]) break;
			baseoffs=[fh offsetInFile];
		}
		else break;
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

/*	if(checksum)
	{
		static NSDictionary *knownchecksums=nil;
		if(!knownchecksums) knownchecksums=[[NSDictionary alloc] initWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:0xd538e5cf],@"sitx_d538e5cf.work",
			[NSNumber numberWithUnsignedInt:0x53c0e7bf],@"CABARC.EXE",
			[NSNumber numberWithUnsignedInt:0x09c36559],@"MAKECAB.EXE",
			[NSNumber numberWithUnsignedInt:0xd2323fe9],@"CABINET.DLL",
			[NSNumber numberWithUnsignedInt:0x2e09794a],@"Georgia.TTF",
			[NSNumber numberWithUnsignedInt:0xbc55bbfd],@"acmsetup.hlp",
			[NSNumber numberWithUnsignedInt:0x80e74ea2],@"TENSION.PER",
			[NSNumber numberWithUnsignedInt:0x1c8407bc],@"BLUEGRAS.STY",
			[NSNumber numberWithUnsignedInt:0xe27844bb],@"AMADEUS.STY",
			[NSNumber numberWithUnsignedInt:0xfcafb03e],@"ppmusic.ppa",
			[NSNumber numberWithUnsignedInt:0x228a28b1],@"mssetup.dll",
			[NSNumber numberWithUnsignedInt:0xe8762e3b],@"1394vdbg.sys",
			[NSNumber numberWithUnsignedInt:0xf797e4fa],@"xem336n5.sys",
			[NSNumber numberWithUnsignedInt:0x98aa2a8d],@"mdgndis5.sys",
//			[NSNumber numberWithUnsignedInt:],@"",
//			[NSNumber numberWithUnsignedInt:],@"",
		nil];

		NSString *name=[[(XADPath *)[dict objectForKey:XADFileNameKey] lastPathComponent] string];
		NSNumber *crc=[knownchecksums objectForKey:name];
		if(crc) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
		correctCRC:[crc unsignedIntValue] conditioned:YES];
	}*/

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	XADCABBlockReader *blocks=[obj objectForKey:@"BlockReader"];
	int method=[[obj objectForKey:@"Method"] intValue];

	switch(method&0x0f)
	{
		case 0: return [[[XADCABCopyHandle alloc] initWithBlockReader:blocks] autorelease];
		case 1: return [[[XADMSZipHandle alloc] initWithBlockReader:blocks] autorelease];
		case 2: return [[[XADQuantumHandle alloc] initWithBlockReader:blocks windowBits:(method>>8)&0x1f] autorelease];
		case 3: return [[[XADMSLZXHandle alloc] initWithBlockReader:blocks windowBits:(method>>8)&0x1f] autorelease];
		default:
			[self reportInterestingFileWithReason:@"Unsupported compression method %d",method&0x0f];
			return nil;
	}
}

-(NSString *)formatName { return @"CAB"; }

@end




@implementation XADCABSFXParser

static int MatchCABSignature(const uint8_t *bytes,int available,off_t offset,void *state)
{
	if(available<32) return NO;

	if(bytes[0]!='M'||bytes[1]!='S'||bytes[2]!='C'||bytes[3]!='F') return NO; // Signature

	uint32_t len=CSUInt32LE(&bytes[8]);
	uint32_t offs=CSUInt32LE(&bytes[16]);

	if(offs>=len) return NO; // Internal consistency

	if(state) // Check if cabinet fits in file
	{
		off_t size=*(off_t *)state;
		if(len>size-offset) return NO;
	}

	if(bytes[24]!=1&&bytes[24]!=2&&bytes[24]!=3) return NO; // Major version
	if(bytes[25]!=1) return NO; // Minor version

	int flags=CSUInt16LE(&bytes[30]);
	if(flags&0xfff8) return NO;

	return YES;
}

+(int)requiredHeaderSize { return 65536; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<20000||bytes[0]!='M'||bytes[1]!='Z') return NO;

	for(int i=8;i<length;i++)
	{
		if(MatchCABSignature(&bytes[i],length-i,i,NULL))
		{
			[props setObject:[NSNumber numberWithInt:i] forKey:@"CABSFXOffset"];
			return YES;
		}
	}

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return nil; }

-(void)parse
{
	off_t offs=[[[self properties] objectForKey:@"CABSFXOffset"] longLongValue];
	[[self handle] seekToFileOffset:offs];

	[super parse];
}

-(NSString *)formatName { return @"Self-extracting CAB"; }

@end



static CABHeader ReadCABHeader(CSHandle *fh)
{
	CABHeader head;

	uint32_t signature=[fh readUInt32BE];
	if(signature!='MSCF') [XADException raiseIllegalDataException];

	[fh skipBytes:4];
	head.cabsize=[fh readUInt32LE];
	[fh skipBytes:4];
	head.fileoffs=[fh readUInt32LE];
	[fh skipBytes:4];
	head.minorversion=[fh readUInt8];
	head.majorversion=[fh readUInt8];
	head.numfolders=[fh readUInt16LE];
	head.numfiles=[fh readUInt16LE];
	head.flags=[fh readUInt16LE];
	head.setid=[fh readUInt16LE];
	head.cabindex=[fh readUInt16LE];

	if(head.flags&4) // extended data present
	{
		head.headerextsize=[fh readUInt16LE];
		head.folderextsize=[fh readUInt8];
		head.datablockextsize=[fh readUInt8];
		[fh skipBytes:head.headerextsize];
	}
	else head.headerextsize=head.folderextsize=head.datablockextsize=0;

	if(head.flags&1)
	{
		head.prevvolume=ReadCString(fh);
		SkipCString(fh);
	}
	else head.prevvolume=nil;

	if(head.flags&2)
	{
		head.nextvolume=ReadCString(fh);
		SkipCString(fh);
	}
	else head.nextvolume=nil;

	return head;
}

static void SkipCString(CSHandle *fh)
{
	while([fh readUInt8]);
}

static NSData *ReadCString(CSHandle *fh)
{
	NSMutableData *data=[NSMutableData data];
	uint8_t b;
	while((b=[fh readUInt8])) [data appendBytes:&b length:1];
	return data;
}

static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname,NSArray *dircontents)
{
	NSString *filepart=[[[NSString alloc] initWithData:namedata encoding:NSWindowsCP1252StringEncoding] autorelease];
	NSString *volumename=[dirname stringByAppendingPathComponent:filepart];

	@try
	{
		CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:volumename];
		if(handle) return handle;
	}
	@catch(id e) { }

	NSEnumerator *enumerator=[dircontents objectEnumerator];
	NSString *direntry;
	while((direntry=[enumerator nextObject]))
	{
		if([filepart caseInsensitiveCompare:direntry]==NSOrderedSame)
		{
			NSString *filename=[dirname stringByAppendingPathComponent:direntry];
			@try
			{
				CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:filename];
				if(handle) return handle;
			}
			@catch(id e) { }
		}
	}

	return nil;
}
