#ifndef XADMASTER_BINHEX_C
#define XADMASTER_BINHEX_C



#include "xadClient.h"
#include "xadCRC_1021.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 13
#endif

XADCLIENTVERSTR("BinHex 1.1 (22.06.2006)")

#define BINHEX_VERSION           1
#define BINHEX_REVISION          0



#define BINHEX_BUFSIZE 16384

struct binhex_parser
{
	struct xadArchiveInfo *ai;
	struct xadMasterBase *xmb;
	xadSize start_xadpos;

	const xadUINT8 *mem_buf;
	xadUINT32 mem_size,mem_pos;

	int state;
	xadUINT8 prev_bits;
	xadUINT8 rle_byte,rle_num;
	xadUINT32 pos;
	xadERROR err;
};

struct binhex_archive_private
{
	struct binhex_parser parser;
	xadUINT8 buf[BINHEX_BUFSIZE];
};

#define BINHEXPAI(a) ((struct binhex_archive_private *) ((a)->xai_PrivateClient))

#define BINHEX_HEX_DIGIT(a) (((a)<=9)?((a)+'0'):((a)-10+'A'))


static void binhex_setup_hook_parser(struct binhex_parser *parser,struct xadArchiveInfo *ai,struct xadMasterBase *xmb)
{
	parser->ai=ai;
	parser->xmb=xmb;
	parser->start_xadpos=ai->xai_InPos.S;
	parser->mem_buf=NULL;
	parser->mem_size=0;
	parser->mem_pos=0;
	parser->state=0;
	parser->rle_byte=0;
	parser->rle_num=0;
	parser->pos=0;
	parser->err=XADERR_OK;
}

static void binhex_setup_mem_parser(struct binhex_parser *parser,const xadPTR buf,xadUINT32 size)
{
	parser->ai=NULL;
	parser->xmb=NULL;
	parser->start_xadpos=0;
	parser->mem_buf=buf;
	parser->mem_size=size;
	parser->mem_pos=0;
	parser->state=0;
	parser->rle_byte=0;
	parser->rle_num=0;
	parser->pos=0;
	parser->err=XADERR_OK;
}

static xadUINT8 binhex_get_bits(struct binhex_parser *parser)
{
	xadUINT8 *codes=(xadUINT8 *)"!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr";

	if(parser->err) return 0;
	for(;;)
	{
		xadUINT8 byte;
		if(parser->ai)
		{
			if(parser->err=xadHookAccess(parser->xmb,XADAC_READ,1,&byte,parser->ai)) return 0;
		}
		else if(parser->mem_buf)
		{
			if(parser->mem_pos>=parser->mem_size) { parser->err=XADERR_INPUT; return 0; }
			else byte=parser->mem_buf[parser->mem_pos++];
		}
		if(byte==':') { parser->err=XADERR_INPUT; return 0; }
		for(xadUINT8 bits=0;bits<64;bits++) if(byte==codes[bits]) return bits;
	}
}

static xadUINT8 binhex_decode_byte(struct binhex_parser *parser)
{
	xadUINT8 bits1,bits2,res;

	switch(parser->state)
	{
		case 0:
			bits1=binhex_get_bits(parser);
			bits2=binhex_get_bits(parser);
			parser->prev_bits=bits2;
			res=(bits1<<2)|(bits2>>4);
			parser->state=1;
		break;

		case 1:
			bits1=parser->prev_bits;
			bits2=binhex_get_bits(parser);
			parser->prev_bits=bits2;
			res=(bits1<<4)|(bits2>>2);
			parser->state=2;
		break;

		case 2:
			bits1=parser->prev_bits;
			bits2=binhex_get_bits(parser);
			res=(bits1<<6)|bits2;
			parser->state=0;
		break;
	}

	return res;
}

static xadERROR binhex_read_bytes(struct binhex_parser *parser,xadUINT32 bytes,xadUINT8 *buf)
{
	for(xadUINT32 i=0;i<bytes;i++)
	{
		if(parser->rle_num)
		{
			if(buf) buf[i]=parser->rle_byte;
			parser->rle_num--;
		}
		else
		{
			xadUINT8 byte=binhex_decode_byte(parser);
			if(parser->err) return parser->err;

			if(byte!=0x90)
			{
				if(buf) buf[i]=byte;
				parser->rle_byte=byte;
			}
			else
			{
				xadUINT8 count=binhex_decode_byte(parser);
				if(parser->err) return parser->err;

				if(count==0)
				{
					if(buf) buf[i]=0x90;
					parser->rle_byte=0x90;
				}
				else if(count>=2)
				{
					if(buf) buf[i]=parser->rle_byte;
					parser->rle_num=count-2;
				}
			}
		}
	}

	parser->pos+=bytes;

	return XADERR_OK;
}

static xadERROR binhex_seek(struct binhex_parser *parser,xadUINT32 newpos)
{
	if(newpos<parser->pos)
	{
		if(parser->ai)
		{
			if(parser->err=xadHookAccess(parser->xmb,XADAC_INPUTSEEK,
			parser->start_xadpos-parser->ai->xai_InPos.S,NULL,parser->ai)) return parser->err;
		}
		else if(parser->mem_buf) parser->mem_pos=0;

		parser->state=0;
		parser->rle_byte=0;
		parser->rle_num=0;
		parser->pos=0;
	}

	return binhex_read_bytes(parser,newpos-parser->pos,NULL);
}

static inline xadUINT16 binhex_update_crc(xadUINT16 crc,xadUINT8 val)
{
	return (crc<<8)^xadCRC_1021_crctable[(crc>>8)^val];
}



XADRECOGDATA(BinHex)
{
	if(size>=45&&!memcmp("(This file must be converted with BinHex 4.0)",data,45)) return XADTRUE;

	// Scan for start-of-data ':' marker
	xadUINT8 prev='\n';
	int i;
	for(i=0;i<size;i++)
	{
		if(data[i]==':'&&(prev=='\n'||prev=='\r')) break;
		prev=data[i];
	}
	if(i==size) return XADFALSE;

	// Start memory buffer parser
	struct binhex_parser parser;
	binhex_setup_mem_parser(&parser,(const xadPTR)data+i+1,size-i-1);

	xadUINT16 crc=0;

	// Read and check name length
	xadUINT8 len;
	if(binhex_read_bytes(&parser,1,&len)) return XADFALSE;

	if(len<1||len>63) return XADFALSE;
	crc=binhex_update_crc(crc,len);

	// Scan name to make sure there are no null bytes
	for(int i=0;i<len;i++)
	{
		xadUINT8 chr;
		if(binhex_read_bytes(&parser,1,&chr)) return XADFALSE;
		if(chr==0) return XADFALSE;
		crc=binhex_update_crc(crc,chr);
	}

	// Read rest of header
	for(int i=0;i<19;i++)
	{
		xadUINT8 byte;
		if(binhex_read_bytes(&parser,1,&byte)) return XADFALSE;
		crc=binhex_update_crc(crc,byte);
	}

	// Check CRC
	xadUINT8 realcrc[2];
	if(binhex_read_bytes(&parser,2,realcrc)) return XADFALSE;
	if(EndGetM16(realcrc)!=crc) return XADFALSE;

	return XADTRUE;
}

XADGETINFO(BinHex)
{
	struct xadFileInfo *rsrc_fi=NULL;
	xadERROR err=XADERR_OK;

	ai->xai_PrivateClient=xadAllocVec(XADM sizeof(struct binhex_archive_private),XADMEMF_CLEAR);
	if(!ai->xai_PrivateClient) return XADERR_NOMEMORY;

	ai->xai_Flags=XADAIF_FILEARCHIVE;

	// Scan for start-of-data ':' marker
	char prev='\n',curr;
	for(;;)
	{
		if(err=xadHookAccess(XADM XADAC_READ,1,&curr,ai)) return err;
		if(curr==':'&&(prev=='\n'||prev=='\r')) break;
		prev=curr;
	}

	binhex_setup_hook_parser(&BINHEXPAI(ai)->parser,ai,xadMasterBase);

	xadUINT8 namelen;
	xadUINT8 namebuf[64];
	if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,1,&namelen)) return err;
	if(namelen>63) return XADERR_DATAFORMAT;
	if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,namelen,namebuf)) return err;
	namebuf[namelen]=0;

	xadUINT8 headbuf[21];
	if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,21,headbuf)) return err;

	//xadUINT8 version=headbuf[0];
	xadUINT16 flags=EndGetM16(headbuf+9);
	xadUINT32 datalen=EndGetM32(headbuf+11);
	xadUINT32 rsrclen=EndGetM32(headbuf+15);
	//xadUINT16 crc=EndGetM16(headbuf+19);

/*	printf("file:%s version:%d flags:%x datalen:%d rsrclen:%d %c%c%c%c %c%c%c%c\n",
	namebuf,version,flags,datalen,rsrclen,headbuf[1],headbuf[2],headbuf[3],headbuf[4],
	headbuf[5],headbuf[6],headbuf[7],headbuf[8]);*/

	if(rsrclen)
	{
		struct xadFileInfo *fi=(struct xadFileInfo *)xadAllocObject(XADM XADOBJ_FILEINFO,
			XAD_OBJCOMMENTSIZE,15,
		TAG_DONE);
		if(!fi)  return XADERR_NOMEMORY;

		xadSTRPTR name=xadConvertName(XADM CHARSET_HOST,
			XAD_CHARACTERSET, CHARSET_MACOS,
			XAD_STRINGSIZE,namelen,
			XAD_CSTRING,namebuf,
			XAD_ADDPATHSEPERATOR,XADFALSE,
			XAD_CSTRING,".rsrc",
		TAG_DONE);
		if(!name)
		{
			xadFreeObjectA(XADM fi,NULL);
			return XADERR_NOMEMORY;
		}

		fi->xfi_DataPos=24+namelen+datalen;
		fi->xfi_FileName=name;
		fi->xfi_Flags=XADFIF_EXTRACTONBUILD|XADFIF_MACRESOURCE|XADFIF_NODATE|XADFIF_XADSTRFILENAME;
		fi->xfi_Size=fi->xfi_CrunchSize=rsrclen;

		xadCopyMem(XADM headbuf+1,fi->xfi_Comment,4);
		xadCopyMem(XADM headbuf+5,fi->xfi_Comment+5,4);
		fi->xfi_Comment[4]='/';
		fi->xfi_Comment[9]=' ';
		fi->xfi_Comment[10]=BINHEX_HEX_DIGIT(flags>>12);
		fi->xfi_Comment[11]=BINHEX_HEX_DIGIT((flags>>8)&0x0f);
		fi->xfi_Comment[12]=BINHEX_HEX_DIGIT((flags>>4)&0x0f);
		fi->xfi_Comment[13]=BINHEX_HEX_DIGIT(flags&0x0f);
		fi->xfi_Comment[14]=0;

		if(err=xadAddFileEntryA(XADM fi,ai,NULL))
		{
			xadFreeObjectA(XADM fi,NULL);
			xadFreeObjectA(XADM name,NULL);
			return err;
		}
		rsrc_fi=fi;
	}

	if(datalen||!rsrclen)
	{
		struct xadFileInfo *fi=(struct xadFileInfo *)xadAllocObject(XADM XADOBJ_FILEINFO,
			XAD_OBJCOMMENTSIZE,15,
		TAG_DONE);
		if(!fi)  return XADERR_NOMEMORY;

		xadSTRPTR name=xadConvertName(XADM CHARSET_HOST,
			XAD_CHARACTERSET,CHARSET_MACOS,
			XAD_STRINGSIZE,namelen,
			XAD_CSTRING,namebuf,
		TAG_DONE);
		if(!name)
		{
			xadFreeObjectA(XADM fi,NULL);
			return XADERR_NOMEMORY;
		}

		fi->xfi_DataPos=22+namelen;
		fi->xfi_FileName=name;
		fi->xfi_Flags=XADFIF_EXTRACTONBUILD|XADFIF_MACDATA|XADFIF_NODATE|XADFIF_XADSTRFILENAME;
		fi->xfi_Size=fi->xfi_CrunchSize=datalen;

		xadCopyMem(XADM headbuf+1,fi->xfi_Comment,4);
		xadCopyMem(XADM headbuf+5,fi->xfi_Comment+5,4);
		fi->xfi_Comment[4]='/';
		fi->xfi_Comment[9]=' ';
		fi->xfi_Comment[10]=BINHEX_HEX_DIGIT(flags>>12);
		fi->xfi_Comment[11]=BINHEX_HEX_DIGIT((flags>>8)&0x0f);
		fi->xfi_Comment[12]=BINHEX_HEX_DIGIT((flags>>4)&0x0f);
		fi->xfi_Comment[13]=BINHEX_HEX_DIGIT(flags&0x0f);
		fi->xfi_Comment[14]=0;

		if(rsrc_fi)
		{
			rsrc_fi->xfi_MacFork=fi;
			fi->xfi_MacFork=rsrc_fi;
		}

		if(err=xadAddFileEntryA(XADM fi,ai,NULL))
		{
			xadFreeObjectA(XADM fi,NULL);
			xadFreeObjectA(XADM name,NULL);
			return err;
		}
	}

	return XADERR_OK;
}



XADUNARCHIVE(BinHex)
{
	struct xadFileInfo *fi=ai->xai_CurFile;
	xadERROR err=XADERR_OK;
	xadUINT16 crc=0;
	xadUINT8 *buf=BINHEXPAI(ai)->buf,realcrc[2];
	xadUINT32 bytesleft;

	if(err=binhex_seek(&BINHEXPAI(ai)->parser,(xadUINT32)fi->xfi_DataPos)) return err;

	bytesleft=(xadUINT32)fi->xfi_Size;
	while(bytesleft)
	{
		xadUINT32 readbytes=BINHEX_BUFSIZE;
		if(readbytes>bytesleft) readbytes=bytesleft;

		if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,readbytes,buf)) return err;
		if(err=xadHookTagAccess(XADM XADAC_WRITE,readbytes,buf,ai,
//			XAD_CRC16ID,0x1021,
//			XAD_GETCRC16,&crc,
		TAG_DONE)) return err;

		for(int i=0;i<readbytes;i++) crc=binhex_update_crc(crc,buf[i]);

		bytesleft-=readbytes;
	}

	if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,2,realcrc)) return err;
	if(crc!=EndGetM16(realcrc)) return XADERR_CHECKSUM;

	return XADERR_OK;
}

XADFREE(BinHex)
{
	xadFreeObjectA(XADM ai->xai_PrivateClient,NULL);
}


XADFIRSTCLIENT(BinHex)
{
	XADNEXTCLIENT,
	XADCLIENT_VERSION,
	XADMASTERVERSION,
	BINHEX_VERSION,
	BINHEX_REVISION,
	4096,
	XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS|XADCF_NOCHECKSIZE,
	XADCID_BINHEX,
	"BinHex",
	/* client functions */
	XADRECOGDATAP(BinHex),
	XADGETINFOP(BinHex),
	XADUNARCHIVEP(BinHex),
	XADFREEP(BinHex),
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(BinHex)

#endif /* XADMASTER_BINHEX_C */
