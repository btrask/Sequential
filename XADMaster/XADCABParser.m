#import "XADCABParser.h"
#import "XADCABBlockReader.h"
#import "XADMSZipHandle.h"
#import "XADQuantumHandle.h"
#import "XADMSLZXHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"

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
static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname);



@implementation XADCABParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=4&&bytes[0]=='M'&&bytes[1]=='S'&&bytes[2]=='C'&&bytes[3]=='F';
}

+(NSArray *)volumesForFilename:(NSString *)filename
{
	NSArray *res=nil;
	@try
	{
		NSString *dirname=[filename stringByDeletingLastPathComponent];
		NSMutableArray *volumes=[NSMutableArray arrayWithObject:filename];

		CSHandle *fh=[CSFileHandle fileHandleForReadingAtPath:filename];
		CABHeader firsthead=ReadCABHeader(fh);

		NSData *namedata=firsthead.prevvolume;
		int lastindex=firsthead.cabindex;
		while(namedata)
		{
			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			CSHandle *fh=FindHandleForName(namedata,dirname);
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

			CSHandle *fh=FindHandleForName(namedata,dirname);
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
			if(attribs&0x80) name=[self XADPathWithData:namedata encoding:NSUTF8StringEncoding separators:XADWindowsPathSeparator];
			else name=[self XADPathWithData:namedata separators:XADWindowsPathSeparator];

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
		default: return nil;
	}
}

-(NSString *)formatName { return @"CAB"; }

@end




@implementation XADCABSFXParser

+(int)requiredHeaderSize { return 65536; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<20000||bytes[0]!='M'||bytes[1]!='Z') return NO;

	// From libxad:
	for(int i=8;i<=length+8;i++)
	{
		// word aligned code signature: 817C2404 "MSCF" (found at random, sorry)
		if((i&1)==0)
		if(bytes[i+0]==0x81 && bytes[i+1]==0x7c && bytes[i+2]==0x24 && bytes[i+3]==0x04 &&
		bytes[i+4]=='M' && bytes[i+5]=='S' && bytes[i+6]=='C' && bytes[i+7]=='F') return YES;

		// another revision: 7D817DDC "MSCF" (which might not be aligned)
		if(bytes[i+0]==0x7d && bytes[i+1]==0x81 && bytes[i+2]==0x7d && bytes[i+3]==0xdc &&
		bytes[i+4]=='M' && bytes[i+5]=='S' && bytes[i+6]=='C' && bytes[i+7]=='F') return YES;
	}

	return NO;
}

+(NSArray *)volumesForFilename:(NSString *)name { return nil; }

-(void)parse
{
	CSHandle *fh=[self handle];
	off_t remainingsize=[fh fileSize];

	uint8_t buf[20];
	[fh readBytes:sizeof(buf) toBuffer:buf];

	for(;;)
	{
		if(buf[0]=='M'&&buf[1]=='S'&&buf[2]=='C'&&buf[3]=='F')
		{
			uint32_t len=CSUInt32LE(&buf[8]);
			uint32_t offs=CSUInt32LE(&buf[16]);
			if(len<=remainingsize&&offs<len) break;
		}

		memmove(buf,buf+1,sizeof(buf)-1);
		if([fh readAtMost:1 toBuffer:&buf[sizeof(buf)-1]]==0) return;

		remainingsize--;
	}

	[fh skipBytes:-sizeof(buf)];
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
	while(b=[fh readUInt8]) [data appendBytes:&b length:1];
	return data;
}

static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname)
{
	NSString *filepart=[[[NSString alloc] initWithData:namedata encoding:NSWindowsCP1252StringEncoding] autorelease];
	NSString *volumename=[dirname stringByAppendingPathComponent:filepart];

	@try
	{
		CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:volumename];
		if(handle) return handle;
	}
	@catch(id e) { }

	if(!dirname||[dirname length]==0) dirname=@".";
	DIR *dir=opendir([dirname fileSystemRepresentation]);
	if(!dir) return nil;

	struct dirent *ent;
	while(ent=readdir(dir))
	{
		int len=strlen(ent->d_name);
		if(len==[namedata length]&&strncasecmp([namedata bytes],ent->d_name,len)==0)
		{
			NSString *filename=[dirname stringByAppendingPathComponent:[NSString stringWithUTF8String:ent->d_name]];
			@try
			{
				CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:filename];
				if(handle)
				{
					closedir(dir);
					return handle;
				}
			}
			@catch(id e) { }
		}
	}

	closedir(dir);

	return nil;
}
