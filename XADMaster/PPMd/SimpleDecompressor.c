#include <stdio.h>
#include <stdint.h>

#include "VariantG.h"
#include "VariantH.h"
#include "VariantI.h"
#include "SubAllocatorVariantG.h"
#include "SubAllocatorVariantH.h"
#include "SubAllocatorVariantI.h"
#include "SubAllocatorBrimstone.h"

static inline uint16_t EndianSwap16(uint16_t val) { return (val>>8)|(val<<8); }
static inline uint32_t EndianSwap32(uint32_t val) { return (val>>24)|((val>>8)&0x0000ff00)|((val<<8)&0x00ff0000)|(val<<24); }

static int STDIORead(void *context);

int main(int argc,const char **argv)
{
	FILE *fh;

	if(argc>=2)
	{
		fh=fopen(argv[1],"rb");
		if(!fh)
		{
			fprintf(stderr,"Couldn't open file \"%s\".\n",argv[1]);
			return 1;
		}
	}
	else fh=stdin;

	struct
	{
		uint32_t magic;
		uint32_t attribs;
		uint16_t info;
		uint16_t namelen;
		uint16_t time,date;
	} header;

	fread(&header,sizeof(header),1,fh);

	if(header.magic!=0x84acaf8f&&header.magic!=0x8fafac84)
	{
		fprintf(stderr,"\"%s\" does not look like a PPMd file.\n",argv[1]);
		return 1;
	}

	if(header.magic==0x8fafac84)
	{
		header.attribs=EndianSwap32(header.attribs);
		header.info=EndianSwap16(header.info);
		header.namelen=EndianSwap16(header.namelen);
		header.time=EndianSwap16(header.time);
		header.date=EndianSwap16(header.date);
	}

	int maxorder=(header.info&0x0f)+1;
	int suballocsize=((header.info>>4)&0xff)+1;
	int variant=(header.info>>12)+'A';

	int modelrestoration=-1;
	if(variant>='I')
	{
		modelrestoration=header.namelen>>14;
		header.namelen&=0x3fff;
	}

	fprintf(stderr,"PPMd variant %c file.\n",variant);
	fprintf(stderr,"Max order = %d\n",maxorder);
	fprintf(stderr,"Suballocator size = %d\n",suballocsize);
	if(modelrestoration>=0) fprintf(stderr,"Model restoration = %d\n",modelrestoration);
	fprintf(stderr,"File attributes = %x\n",header.attribs);
	fprintf(stderr,"Time and date = %04x %04x\n",header.time,header.date);

	uint8_t namebuf[header.namelen];
	fread(namebuf,header.namelen,1,fh);

	fprintf(stderr,"Filename = ");
	fwrite(namebuf,header.namelen,1,stderr);
	fprintf(stderr,"\n");

	if(variant!='G'&&variant!='I'&&variant!='H')
	{
		fprintf(stderr,"Variant %c is not supported.\n",variant);
		return 1;
	}

	switch(variant)
	{
		case 'G':
		{
			PPMdSubAllocatorVariantG *alloc=CreateSubAllocatorVariantG(suballocsize<<20);
			PPMdModelVariantG model;
			StartPPMdModelVariantG(&model,STDIORead,fh,&alloc->core,maxorder,false);
			for(;;)
			{
				int byte=NextPPMdVariantGByte(&model);
				if(byte<0) break;
				fputc(byte,stdout);
			}
		}
		break;

		case 'H':
		{
			PPMdSubAllocatorVariantH *alloc=CreateSubAllocatorVariantH(suballocsize<<20);
			PPMdModelVariantH model;
			StartPPMdModelVariantH(&model,STDIORead,fh,alloc,maxorder,false);
			for(;;)
			{
				int byte=NextPPMdVariantHByte(&model);
				if(byte<0) break;
				fputc(byte,stdout);
			}
		}
		break;

		case 'I':
		{
			PPMdSubAllocatorVariantI *alloc=CreateSubAllocatorVariantI(suballocsize<<20);
			PPMdModelVariantI model;
			StartPPMdModelVariantI(&model,STDIORead,fh,alloc,maxorder,modelrestoration);
			for(;;)
			{
				int byte=NextPPMdVariantIByte(&model);
				if(byte<0) break;
				fputc(byte,stdout);
			}
		}
		break;
	}
}

static int STDIORead(void *context)
{
	FILE *fh=context;
	return fgetc(fh)&0xff;
}

