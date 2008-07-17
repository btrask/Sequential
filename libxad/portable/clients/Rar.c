#ifndef XADMASTER_RAR_C
#define XADMASTER_RAR_C



#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 13
#endif

XADCLIENTVERSTR("Rar 1.1 (18.06.2006)")

#define RAR_VERSION           1
#define RAR_REVISION          1



struct RarArchivePrivate
{
	xadUINT32 flags;
	xadUINT8 encryptver;
	xadPTR unpacker;
	struct xadFileInfo *last_unpacked;
};

#define RARPAI(a) ((struct RarArchivePrivate *) ((a)->xai_PrivateClient))

struct RarFilePrivate
{
	xadUINT16 flags;
	xadUINT32 crc;
	xadUINT8 version,method;
	xadBOOL compressed,solid;
	struct xadFileInfo *solid_start,*next_solid;
};

#define RARPFI(a) ((struct RarFilePrivate *) ((a)->xfi_PrivateInfo))



#define RARFLAG_SKIP_IF_UNKNOWN 0x4000
#define RARFLAG_LONG_BLOCK    0x8000

#define RARMHD_VOLUME         0x0001
#define RARMHD_COMMENT        0x0002
#define RARMHD_LOCK           0x0004
#define RARMHD_SOLID          0x0008
#define RARMHD_PACK_COMMENT   0x0010
#define RARMHD_NEWNUMBERING   0x0010
#define RARMHD_AV             0x0020
#define RARMHD_PROTECT        0x0040
#define RARMHD_PASSWORD       0x0080
#define RARMHD_FIRSTVOLUME    0x0100
#define RARMHD_ENCRYPTVER     0x0200

#define RARLHD_SPLIT_BEFORE   0x0001
#define RARLHD_SPLIT_AFTER    0x0002
#define RARLHD_PASSWORD       0x0004
#define RARLHD_COMMENT        0x0008
#define RARLHD_SOLID          0x0010

#define RARLHD_WINDOWMASK     0x00e0
#define RARLHD_WINDOW64       0x0000
#define RARLHD_WINDOW128      0x0020
#define RARLHD_WINDOW256      0x0040
#define RARLHD_WINDOW512      0x0060
#define RARLHD_WINDOW1024     0x0080
#define RARLHD_WINDOW2048     0x00a0
#define RARLHD_WINDOW4096     0x00c0
#define RARLHD_DIRECTORY      0x00e0

#define RARLHD_LARGE          0x0100
#define RARLHD_UNICODE        0x0200
#define RARLHD_SALT           0x0400
#define RARLHD_VERSION        0x0800
#define RARLHD_EXTTIME        0x1000
#define RARLHD_EXTFLAGS       0x2000

#define RARMETHOD_STORE 0x30
#define RARMETHOD_FASTEST 0x31
#define RARMETHOD_FAST 0x32
#define RARMETHOD_NORMAL 0x33
#define RARMETHOD_GOOD 0x34
#define RARMETHOD_BEST 0x35

#define RAR_NOSIGNATURE 0
#define RAR_OLDSIGNATURE 1
#define RAR_SIGNATURE 2


int RarTestSignature(const xadUINT8 *ptr)
{
	if(ptr[0]==0x52)
	if(ptr[1]==0x45&&ptr[2]==0x7e&&ptr[3]==0x5e) return RAR_OLDSIGNATURE;
    else if(ptr[1]==0x61&&ptr[2]==0x72&&ptr[3]==0x21&&ptr[4]==0x1a&&ptr[5]==0x07&&ptr[6]==0x00) return RAR_SIGNATURE;

	return RAR_NOSIGNATURE;
}

XADRECOGDATA(Rar)
{
	if(size<7) return XADFALSE; // fix to use correct min size
	for(xadSize i=0;i<=size-7;i++) if(RarTestSignature(data+i)) return XADTRUE;
	return XADFALSE;
}

XADGETINFO(Rar)
{
	xadERROR err=XADERR_OK;
	xadUINT8 buf[29];
	struct xadFileInfo *fi=NULL;
	struct xadFileInfo *last_compressed=NULL,*last_nonsolid=NULL;
	int curr_part;
	xadSTRPTR namebuf;
	xadSize lastpos;

	if(err=xadHookAccess(XADM XADAC_READ,7,buf,ai)) return err;

	int sigtype;
	while(!(sigtype=RarTestSignature(buf)))
	{
		buf[0]=buf[1]; buf[1]=buf[2]; buf[2]=buf[3];
		buf[3]=buf[4]; buf[4]=buf[5]; buf[5]=buf[6];

		if(err=xadHookAccess(XADM XADAC_READ,1,buf+6,ai)) return err;
	}

	if(sigtype==RAR_OLDSIGNATURE)
	{
		return XADERR_NOTSUPPORTED;
		//if(err=xadHookAccess(XADM XADAC_SEEK,-3,NULL,ai)) return err;
		// ...
	}

	ai->xai_Flags=XADAIF_FILEARCHIVE;
	// XADAIF_CRYPTED

	ai->xai_PrivateClient=xadAllocVec(XADM sizeof(struct RarArchivePrivate),XADMEMF_CLEAR);
	if(!ai->xai_PrivateClient) return XADERR_NOMEMORY;

	namebuf=xadAllocVec(XADM 65536,XADMEMF_CLEAR);
	if(!namebuf) return XADERR_NOMEMORY;

	while(ai->xai_InPos<ai->xai_InSize)
	{
		xadSize block_start=ai->xai_InPos;
//printf("inpos:%qu ",ai->xai_InPos);

		if(err=xadHookAccess(XADM XADAC_READ,7,buf,ai)) goto rar_getinfo_end;

		//xadUINT16 crc=EndGetI16(buf);
		xadUINT8 type=buf[2];
		xadUINT16 flags=EndGetI16(buf+3);
		xadUINT16 size1=EndGetI16(buf+5);
		xadSize size2=0;

		if(flags&RARFLAG_LONG_BLOCK)
		{
			if(err=xadHookAccess(XADM XADAC_READ,4,buf,ai)) goto rar_getinfo_end;
			size2=EndGetI32(buf);
		}

//printf("block:%x flags:%x size1:%d size2:%qu ",type,flags,size1,size2);

		switch(type)
		{
			case 0x73: // archive header
				if(flags&(/*RARMHD_LOCK|*/RARMHD_PASSWORD))
				{
fprintf(stderr,"err\n");
					err=XADERR_NOTSUPPORTED;
					goto rar_getinfo_end;
				}

				RARPAI(ai)->flags=flags;

				if(flags&RARMHD_ENCRYPTVER)
				{
					if(err=xadHookAccess(XADM XADAC_READ,9,buf,ai)) goto rar_getinfo_end;
					RARPAI(ai)->encryptver=buf[8];
				}
			break;

			case 0x74: // file header
			{
				if(err=xadHookAccess(XADM XADAC_READ,21,buf,ai)) goto rar_getinfo_end;
				xadUINT16 namesize=EndGetI16(buf+15);
				xadUINT32 unpsize_upper=0;

				if(flags&RARLHD_LARGE)
				{
					if(err=xadHookAccess(XADM XADAC_READ,8,buf+21,ai)) goto rar_getinfo_end;
					size2+=((xadSize)EndGetI32(buf+21))<<32;
					unpsize_upper=EndGetI32(buf+25);
				}

				if(err=xadHookAccess(XADM XADAC_READ,namesize,namebuf,ai)) goto rar_getinfo_end;
				namebuf[namesize]=0;

#ifndef NO_FILENAME_MANGLING
				for(int i=0;i<namesize;i++) if(namebuf[i]=='\\') namebuf[i]='/'; 
#endif

				if(fi)
				{
					// If we can't continue from the last piece, store it as a broken file and clear.
					if(!(flags&RARLHD_SPLIT_BEFORE)||strcmp(namebuf,fi->xfi_FileName))
					{
						fi->xfi_Flags|=XADFIF_PARTIALFILE;
						ai->xai_Flags|=XADAIF_FILECORRUPT;
						ai->xai_LastError=XADERR_ILLEGALDATA;
						xadAddFileEntryA(XADM fi,ai,NULL);
						fi=NULL;
					}
				}

				if(flags&RARLHD_SPLIT_BEFORE)
				{
					if(!fi) break;

					struct xadSkipInfo *si=xadAllocObjectA(XADM XADOBJ_SKIPINFO,NULL);
					if(!si)
					{
						err=XADERR_NOMEMORY;
						goto rar_getinfo_end;
					}

					si->xsi_Position=lastpos;
					si->xsi_SkipSize=block_start+size1-lastpos;
					si->xsi_Next=ai->xai_SkipInfo;
					ai->xai_SkipInfo=si;
//printf("(created skipinfo: %qu,%qu) ",si->xsi_Position,si->xsi_SkipSize);
					fi->xfi_CrunchSize+=size2;
					RARPFI(fi)->crc=EndGetI32(buf+5);
				}
				else
				{
					fi=(struct xadFileInfo *)xadAllocObject(XADM XADOBJ_FILEINFO,
						XAD_OBJNAMESIZE,namesize,
						XAD_OBJPRIVINFOSIZE,sizeof(struct RarFilePrivate),
					TAG_DONE);
					if(!fi)  { err=XADERR_NOMEMORY; goto rar_getinfo_end; }

					fi->xfi_Flags=XADFIF_EXTRACTONBUILD|XADFIF_SEEKDATAPOS;
					fi->xfi_DataPos=block_start+size1;
					fi->xfi_Size=EndGetI32(buf)+(((xadSize)unpsize_upper)<<32);
					fi->xfi_CrunchSize=size2;
					xadCopyMem(XADM namebuf,fi->xfi_FileName,namesize);

					if(flags&RARLHD_PASSWORD)
                    {  
                        fi->xfi_Flags|=XADFIF_CRYPTED;
                        ai->xai_Flags|=XADAIF_CRYPTED;
                    }
					if((flags&RARLHD_WINDOWMASK)==RARLHD_DIRECTORY) fi->xfi_Flags|=XADFIF_DIRECTORY;

					xadUINT32 dostime=EndGetI32(buf+9);
					xadConvertDates(XADM XAD_DATEMSDOS,dostime,XAD_GETDATEXADDATE,&fi->xfi_Date,TAG_DONE);

					xadUINT8 version=buf[13];
					xadUINT8 method=buf[14];
					xadBOOL compressed=(method!=RARMETHOD_STORE);
					xadBOOL solid;

					if(version<15)
					{
						version=15;
						solid=compressed&&(RARPAI(ai)->flags&RARMHD_SOLID)&&ai->xai_FileInfo;
					}
					else solid=(flags&RARLHD_SOLID)!=0;

					RARPFI(fi)->flags=flags;
					RARPFI(fi)->crc=EndGetI32(buf+5);
					RARPFI(fi)->version=version;
					RARPFI(fi)->method=method;
					RARPFI(fi)->solid=solid;
					RARPFI(fi)->compressed=compressed;

					if(compressed)
					{
						if(solid)
						{
							RARPFI(fi)->solid_start=last_nonsolid;
							if(last_compressed) RARPFI(last_compressed)->next_solid=fi;
						}
						else
						{
							RARPFI(fi)->solid_start=fi;
							last_nonsolid=fi;
						}
						last_compressed=fi;
					}

					//xadUINT8 os=buf[4];
					//xadUINT16 attrs=EndGetI32(buf+17);

					curr_part=0;
				}

//printf("file:%s fixedsize2:%qu fullsize:%qu ver:%d meth:%x crc:%x",fi->xfi_FileName,size2,fi->xfi_Size,RARPFI(fi)->version,RARPFI(fi)->method,EndGetI32(buf+5));

				// check crc?

				lastpos=block_start+size1+size2;

				if(!(flags&RARLHD_SPLIT_AFTER))
				{
					xadAddFileEntryA(XADM fi,ai,NULL);
					fi=NULL;
				}
			}
			break;

			//case 0x7b: // archive end
			//	goto rar_getinfo_end;
		}
//printf("\n");
		if(err=xadHookAccess(XADM XADAC_INPUTSEEK,block_start+size1+size2-ai->xai_InPos,NULL,ai)) goto rar_getinfo_end;
	}

	rar_getinfo_end:

	if(fi)
	{
		fi->xfi_Flags|=XADFIF_PARTIALFILE;
		ai->xai_Flags|=XADAIF_FILECORRUPT;
		ai->xai_LastError=XADERR_ILLEGALDATA;
		xadAddFileEntryA(XADM fi,ai,NULL);
	}

	xadFreeObjectA(XADM namebuf,NULL);

	if(err)
	{
		ai->xai_Flags|=XADAIF_FILECORRUPT;
		ai->xai_LastError=err;
	}

	return ai->xai_FileInfo?XADERR_OK:err;
}




xadPTR rar_make_unpacker(struct xadArchiveInfo *ai,struct xadMasterBase *xadMasterBase);
xadERROR rar_run_unpacker(xadPTR *unpacker,xadSize packedsize,xadSize fullsize,xadUINT8 version,xadBOOL solid,xadBOOL dryrun,xadUINT32 *crc);
void rar_destroy_unpacker(xadPTR *unpacker);

XADUNARCHIVE(Rar)
{
	struct xadFileInfo *fi=ai->xai_CurFile;
	xadERROR err=XADERR_OK;
	xadUINT32 crc=0xffffffff;

	if(fi->xfi_Flags&XADFIF_CRYPTED) return XADERR_NOTSUPPORTED;

	if(RARPFI(fi)->compressed)
	{
		if(!RARPAI(ai)->unpacker)
		{
			RARPAI(ai)->unpacker=rar_make_unpacker(ai,xadMasterBase);
			if(!RARPAI(ai)->unpacker) return XADERR_NOMEMORY;
		}

		struct xadFileInfo *last_unpacked=RARPAI(ai)->last_unpacked;

		if(RARPFI(fi)->solid)
		if(!last_unpacked||RARPFI(last_unpacked)->next_solid!=fi)
		{
			struct xadFileInfo *dry_fi=NULL;
			// Try to see if we can just keep going forward.
			if(last_unpacked&&RARPFI(last_unpacked)->solid_start==RARPFI(fi)->solid_start)
			{
				struct xadFileInfo *test_fi=last_unpacked;
				while(test_fi&&test_fi!=fi) test_fi=RARPFI(test_fi)->next_solid;
				if(test_fi) dry_fi=RARPFI(last_unpacked)->next_solid;
			}

			// If we can't, jump to the beginning.
			if(!dry_fi) dry_fi=RARPFI(fi)->solid_start;

			// Run unpacker until we reach the file we want.
			while(dry_fi&&dry_fi!=fi)
			{
				if(err=xadHookAccess(XADM XADAC_INPUTSEEK,dry_fi->xfi_DataPos-ai->xai_InPos,NULL,ai)) return err;
				if(err=rar_run_unpacker(RARPAI(ai)->unpacker,dry_fi->xfi_CrunchSize,dry_fi->xfi_Size,
				RARPFI(dry_fi)->version,RARPFI(dry_fi)->solid,XADTRUE,NULL)) return err;
				dry_fi=RARPFI(dry_fi)->next_solid;
			}
			if(!dry_fi) return XADERR_DECRUNCH;

			// Seek back to the current file data position.
			if(err=xadHookAccess(XADM XADAC_INPUTSEEK,fi->xfi_DataPos-ai->xai_InPos,NULL,ai)) return err;
		}

		err=rar_run_unpacker(RARPAI(ai)->unpacker,fi->xfi_CrunchSize,fi->xfi_Size,
		RARPFI(fi)->version,RARPFI(fi)->solid,XADFALSE,&crc);

		RARPAI(ai)->last_unpacked=fi;
	}
	else
	{
		err=xadHookTagAccess(XADM XADAC_COPY,fi->xfi_Size,0,ai,
			XAD_GETCRC32,&crc,
			XAD_USESKIPINFO,1,
		TAG_DONE);
	}

	if(!err&&~crc!=RARPFI(fi)->crc) {printf("%s: crc error (%x!=%x)\n",fi->xfi_FileName,~crc,RARPFI(fi)->crc);err=XADERR_CHECKSUM;}

	return err;
//            if ((err = xadHookAccess(XADM XADAC_READ, (xadUINT32) size, buf_in, ai))) break;
}

XADFREE(Rar)
{
	if(ai->xai_PrivateClient)
	{
		if(RARPAI(ai)->unpacker) rar_destroy_unpacker(RARPAI(ai)->unpacker);
		xadFreeObjectA(XADM ai->xai_PrivateClient,NULL);
	}
}

XADFIRSTCLIENT(Rar)
{
	XADNEXTCLIENT,
	XADCLIENT_VERSION,
	XADMASTERVERSION,
	RAR_VERSION,
	RAR_REVISION,
	0x40000,
	XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESKIPINFO|XADCF_NOCHECKSIZE,
	XADCID_RAR,
	"Rar",
	/* client functions */
	XADRECOGDATAP(Rar),
	XADGETINFOP(Rar),
	XADUNARCHIVEP(Rar),
	XADFREEP(Rar)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Rar)

#endif /* XADMASTER_RAR_C */
