#import "XADAppleDouble.h"
#import "XADException.h"

// AppleDouble format referenced from:
// http://www.opensource.apple.com/source/Libc/Libc-391.2.3/darwin/copyfile.c

@implementation XADAppleDouble

+(BOOL)parseAppleDoubleWithHandle:(CSHandle *)fh resourceForkOffset:(off_t *)resourceoffsetptr
resourceForkLength:(off_t *)resourcelengthptr extendedAttributes:(NSDictionary **)extattrsptr
{
	if([fh readUInt32BE]!=0x00051607) return NO;
	if([fh readUInt32BE]!=0x00020000) return NO;

	[fh skipBytes:16];

	int num=[fh readUInt16BE];

	uint32_t rsrcoffs=0,rsrclen=0;
	uint32_t finderoffs=0,finderlen=0;

	for(int i=0;i<num;i++)
	{
		uint32_t entryid=[fh readUInt32BE];
		uint32_t entryoffs=[fh readUInt32BE];
		uint32_t entrylen=[fh readUInt32BE];

		switch(entryid)
		{
			case 2: // Resource fork
				rsrcoffs=entryoffs;
				rsrclen=entrylen;
			break;
			case 9: // Finder info
				finderoffs=entryoffs;
				finderlen=entrylen;
			break;
		}
	}

	if(!rsrcoffs&&!finderoffs) return NO;

	// Load FinderInfo struct and extended attributes if available.
	NSData *finderinfo=nil;
	NSMutableDictionary *extattrs=nil;
 	if(finderoffs)
	{
		// First 32 bytes are the FinderInfo struct.
		[fh seekToFileOffset:finderoffs];
		if(finderlen>32) finderinfo=[fh readDataOfLength:32];
		else finderinfo=[fh readDataOfLength:finderlen];

		// Add FinderInfo to extended attributes only if it is not empty.
		static const uint8_t zerobytes[32]={0x00};
		if(memcmp([finderinfo bytes],zerobytes,[finderinfo length])!=0)
		{
			extattrs=[NSMutableDictionary dictionaryWithObject:finderinfo
			forKey:@"com.apple.FinderInfo"];
		}

		// The FinderInfo struct is optionally followed by the extended attributes.
		if(finderlen>70)
		{
			if(!extattrs) extattrs=[NSMutableDictionary dictionary];
			[self parseAppleDoubleExtendedAttributesWithHandle:fh intoDictionary:extattrs];
		}
	}

	if(resourceoffsetptr) *resourceoffsetptr=rsrcoffs;
	if(resourcelengthptr) *resourcelengthptr=rsrclen;
	if(extattrsptr) *extattrsptr=extattrs;

	return YES;
}

+(void)parseAppleDoubleExtendedAttributesWithHandle:(CSHandle *)fh intoDictionary:(NSMutableDictionary *)extattrs
{
	[fh skipBytes:2];
	uint32_t magic=[fh readUInt32BE];

	if(magic!=0x41545452) return;

	/*uint32_t debug=*/[fh readUInt32BE];
	/*uint32_t totalsize=*/[fh readUInt32BE];
	/*uint32_t datastart=*/[fh readUInt32BE];
	/*uint32_t datalength=*/[fh readUInt32BE];
	[fh skipBytes:12];
	/*int flags=*/[fh readUInt16BE];
	int numattrs=[fh readUInt16BE];

	struct
	{
		int offset,length,namelen;
		uint8_t namebytes[256];
	} entries[numattrs];

	for(int i=0;i<numattrs;i++)
	{
		entries[i].offset=[fh readUInt32BE];
		entries[i].length=[fh readUInt32BE];
		/*int flags=*/[fh readUInt16BE];
		entries[i].namelen=[fh readUInt8];
		[fh readBytes:entries[i].namelen toBuffer:entries[i].namebytes];

		int padbytes=(-(entries[i].namelen+11))&3;
		[fh skipBytes:padbytes]; // Align to 4 bytes.
	}

	for(int i=0;i<numattrs;i++)
	{
		off_t curroffset=[fh offsetInFile];

		// Find the entry that comes next in the file to avoid seeks.
		int minoffset=INT_MAX;
		int minindex=-1;
		for(int j=0;j<numattrs;j++)
		{
			if(entries[j].offset>=curroffset && entries[j].offset<minoffset)
			{
				minoffset=entries[j].offset;
				minindex=j;
			}
		}
		if(minindex<0) break; // File structure was messed up, so give up.

		if(minoffset!=curroffset) [fh seekToFileOffset:minoffset];
		NSData *data=[fh readDataOfLength:entries[minindex].length];

		NSString *name=[[[NSString alloc] initWithBytes:entries[minindex].namebytes
		length:entries[minindex].namelen-1 encoding:NSUTF8StringEncoding] autorelease];

		[extattrs setObject:data forKey:name];
	}
}



+(void)writeAppleDoubleHeaderToHandle:(CSHandle *)fh resourceForkSize:(int)ressize
extendedAttributes:(NSDictionary *)extattrs
{
	// AppleDouble header template.
	uint8_t header[0x32]=
	{
		/*  0 */ 0x00,0x05,0x16,0x07, 0x00,0x02,0x00,0x00,
		/*  8 */ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		/* 24 */ 0x00,0x02,
		/* 26 */ 0x00,0x00,0x00,0x09, 0x00,0x00,0x00,0x32, 0x00,0x00,0x00,0x00,
		/* 38 */ 0x00,0x00,0x00,0x02, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
		/* 50 */
	};

	// Calculate FinderInfo and extended attributes size field.
	int numattributes=0,attributeentrysize=0,attributedatasize=0;

	// Sort keys and iterate over them.
	NSArray *keys=[[extattrs allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *enumerator=[keys objectEnumerator];
	NSString *key;
	while((key=[enumerator nextObject]))
	{
		// Ignore FinderInfo.
		if([key isEqual:@"com.apple.FinderInfo"]) continue;

 		NSData *data=[extattrs objectForKey:key];
		int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
		if(namelen>128) continue; // Skip entries with too long names.

		numattributes++;
		attributeentrysize+=(11+namelen+3)&~3; // Aligned to 4 bytes.
		attributedatasize+=[data length];
	}

	// Set FinderInfo size field and resource fork offset field.
	if(numattributes)
	{
		CSSetUInt32BE(&header[34],32+38+attributeentrysize+attributedatasize);
		CSSetUInt32BE(&header[42],50+32+38+attributeentrysize+attributedatasize);
	}
	else
	{
		CSSetUInt32BE(&header[34],32);
		CSSetUInt32BE(&header[42],50+32);
	}

	// Set resource fork size field.
	CSSetUInt32BE(&header[46],ressize);

	// Write AppleDouble header.
	[fh writeBytes:sizeof(header) fromBuffer:header];

	// Write FinderInfo structure.
	NSData *finderinfo=[extattrs objectForKey:@"com.apple.FinderInfo"];
	if(finderinfo)
	{
		if([finderinfo length]<32) [XADException raiseUnknownException];
		[fh writeBytes:32 fromBuffer:[finderinfo bytes]];
	}
	else
	{
		uint8_t emptyfinderinfo[32]={ 0x00 };
		[fh writeBytes:32 fromBuffer:emptyfinderinfo];
	}

	// Write extended attributes if needed.
	if(numattributes)
	{
		// Attributes section header template.
		uint8_t attributesheader[38]=
		{
			/*  0 */ 0x00,0x00,
			/*  2 */  'A', 'T', 'T', 'R', 0x00,0x00,0x00,0x00,
			/* 10 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 18 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 26 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 34 */ 0x00,0x00, 0x00,0x00,
			/* 38 */
		};

		int datastart=50+32+38+attributeentrysize;

		// Set header fields.
		CSSetUInt32BE(&attributesheader[10],datastart+attributedatasize); // total_size
		CSSetUInt32BE(&attributesheader[14],datastart); // data_start
		CSSetUInt32BE(&attributesheader[18],attributedatasize); // data_length
		CSSetUInt16BE(&attributesheader[36],numattributes); // num_attrs

		// Write attributes section header.
		[fh writeBytes:sizeof(attributesheader) fromBuffer:attributesheader];

		// Write attribute entries.
		int currdataoffset=datastart;
		NSEnumerator *enumerator=[keys objectEnumerator];
		NSString *key;
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			// Attribute entry header template.
			uint8_t entryheader[11]=
			{
				/*  0 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
				/*  8 */ 0x00,0x00, namelen,
				/* 11 */ 
			};

			// Set entry header fields.
			CSSetUInt32BE(&entryheader[0],currdataoffset); // offset
			CSSetUInt32BE(&entryheader[4],[data length]); // length

			// Write entry header.
			[fh writeBytes:sizeof(entryheader) fromBuffer:entryheader];

			// Write name.
			char namebytes[namelen];
			[key getCString:namebytes maxLength:namelen encoding:NSUTF8StringEncoding];
			[fh writeBytes:namelen fromBuffer:namebytes];

			// Calculate and write padding.
			int padbytes=(-(namelen+11))&3;
			uint8_t zerobytes[4]={ 0x00 };
			[fh writeBytes:padbytes fromBuffer:zerobytes];

			// Update data pointer.
			currdataoffset+=[data length];
		}

		// Write attribute data.
		enumerator=[keys objectEnumerator];
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			[fh writeData:data];
		}
	}
}

@end

