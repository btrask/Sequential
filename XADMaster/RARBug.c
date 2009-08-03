#include "RARBug.h"

#include <stdint.h>

#define rol(value,bits) (((value)<<(bits))|((value)>>(32-(bits))))

#define blk0(i) W[i]
#define blk(i) (W[i&15]=rol(W[(i+13)&15]^W[(i+8)&15]^W[(i+2)&15]^W[i&15],1))

#define R0(v,w,x,y,z,i) {z+=((w&(x^y))^y)+blk0(i)+0x5A827999+rol(v,5);w=rol(w,30);}
#define R1(v,w,x,y,z,i) {z+=((w&(x^y))^y)+blk(i)+0x5A827999+rol(v,5);w=rol(w,30);}
#define R2(v,w,x,y,z,i) {z+=(w^x^y)+blk(i)+0x6ED9EBA1+rol(v,5);w=rol(w,30);}
#define R3(v,w,x,y,z,i) {z+=(((w|x)&y)|(w&x))+blk(i)+0x8F1BBCDC+rol(v,5);w=rol(w,30);}
#define R4(v,w,x,y,z,i) {z+=(w^x^y)+blk(i)+0xCA62C1D6+rol(v,5);w=rol(w,30);}

void GarbleBlock(unsigned char *block,uint32_t a,uint32_t b,uint32_t c,uint32_t d,uint32_t e)
{
	uint32_t W[16];
	for(int i=0;i<16;i++) W[i]=(block[4*i+0]<<24)|(block[4*i+1]<<16)|(block[4*i+2]<<8)|block[4*i+3];

    R0(a,b,c,d,e, 0); R0(e,a,b,c,d, 1); R0(d,e,a,b,c, 2); R0(c,d,e,a,b, 3);
    R0(b,c,d,e,a, 4); R0(a,b,c,d,e, 5); R0(e,a,b,c,d, 6); R0(d,e,a,b,c, 7);
    R0(c,d,e,a,b, 8); R0(b,c,d,e,a, 9); R0(a,b,c,d,e,10); R0(e,a,b,c,d,11);
    R0(d,e,a,b,c,12); R0(c,d,e,a,b,13); R0(b,c,d,e,a,14); R0(a,b,c,d,e,15);
    R1(e,a,b,c,d,16); R1(d,e,a,b,c,17); R1(c,d,e,a,b,18); R1(b,c,d,e,a,19);
    R2(a,b,c,d,e,20); R2(e,a,b,c,d,21); R2(d,e,a,b,c,22); R2(c,d,e,a,b,23);
    R2(b,c,d,e,a,24); R2(a,b,c,d,e,25); R2(e,a,b,c,d,26); R2(d,e,a,b,c,27);
    R2(c,d,e,a,b,28); R2(b,c,d,e,a,29); R2(a,b,c,d,e,30); R2(e,a,b,c,d,31);
    R2(d,e,a,b,c,32); R2(c,d,e,a,b,33); R2(b,c,d,e,a,34); R2(a,b,c,d,e,35);
    R2(e,a,b,c,d,36); R2(d,e,a,b,c,37); R2(c,d,e,a,b,38); R2(b,c,d,e,a,39);
    R3(a,b,c,d,e,40); R3(e,a,b,c,d,41); R3(d,e,a,b,c,42); R3(c,d,e,a,b,43);
    R3(b,c,d,e,a,44); R3(a,b,c,d,e,45); R3(e,a,b,c,d,46); R3(d,e,a,b,c,47);
    R3(c,d,e,a,b,48); R3(b,c,d,e,a,49); R3(a,b,c,d,e,50); R3(e,a,b,c,d,51);
    R3(d,e,a,b,c,52); R3(c,d,e,a,b,53); R3(b,c,d,e,a,54); R3(a,b,c,d,e,55);
    R3(e,a,b,c,d,56); R3(d,e,a,b,c,57); R3(c,d,e,a,b,58); R3(b,c,d,e,a,59);
    R4(a,b,c,d,e,60); R4(e,a,b,c,d,61); R4(d,e,a,b,c,62); R4(c,d,e,a,b,63);
    R4(b,c,d,e,a,64); R4(a,b,c,d,e,65); R4(e,a,b,c,d,66); R4(d,e,a,b,c,67);
    R4(c,d,e,a,b,68); R4(b,c,d,e,a,69); R4(a,b,c,d,e,70); R4(e,a,b,c,d,71);
    R4(d,e,a,b,c,72); R4(c,d,e,a,b,73); R4(b,c,d,e,a,74); R4(a,b,c,d,e,75);
    R4(e,a,b,c,d,76); R4(d,e,a,b,c,77); R4(c,d,e,a,b,78); R4(b,c,d,e,a,79);

	for(int i=0;i<64;i++) block[i]=W[i/4]>>(i%4)*8;
}

void SHA1_Update_WithRARBug(SHA_CTX *ctx,void *bytes,unsigned long length,int bug)
{
	int firstbytes=64-ctx->num;
	if(!bug||length<=firstbytes) { SHA1_Update(ctx,bytes,length); return; }

	SHA1_Update(ctx,bytes,firstbytes);

	int numblocks=(length-firstbytes)/64;
	int lastbytes=(length-firstbytes)%64;

	for(int i=0;i<numblocks;i++)
	{
		unsigned char *block=(unsigned char *)bytes+firstbytes+i*64;
		uint32_t a=ctx->h0;
		uint32_t b=ctx->h1;
		uint32_t c=ctx->h2;
		uint32_t d=ctx->h3;
		uint32_t e=ctx->h4;
		
		SHA1_Update(ctx,(void *)block,64);
		GarbleBlock(block,a,b,c,d,e);
	}

	SHA1_Update(ctx,(void *)((unsigned char *)bytes+firstbytes+numblocks*64),lastbytes);
}
