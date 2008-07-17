/* This XAD client is (C) 2000-2001 Stuart Caie <kyzer@4u.net>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* ZAP is a lesser-known Amiga disk archiver. This client is only tested
 * with ZAP v1.41. It uses byte-based run-length encoding and LZ77
 * compression, which is redundant because the LZ compressor handles
 * repeated byte runs really well. The archiver only supports normal
 * Amiga DOS disks (80*2*11*512 = 901120 bytes), and it compresses them
 * in 10 blocks of 8 cylinders. It also supports using the AmigaDOS
 * disk bitmap, but just by clearing those sectors before compression,
 * not some special format. Finally, it supports attaching a textfile/
 * banner to the archive, shown on extraction. ZAP is (C) 1990 GREMLIN of
 * MAYHEM.
 *
 * $VER: ZAP.c 1.2 (20.08.2001)";

 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "ConvertE.c"
#include "SDI_compiler.h"

#ifndef XADMASTERFILE
#define ZAP_Client		FirstClient
#define NEXTCLIENT		0
UBYTE version[] = "$VER: ZAP 1.2 (20.08.2001)";
#endif
#define ZAP_VERSION     1
#define ZAP_REVISION    2


#define XADBASE REG(a6, struct xadMasterBase *xadMasterBase)

/* work-doing macros */
#define SKIP(offset) if ((err = xadHookAccess(XADAC_INPUTSEEK, \
  (ULONG)(offset), NULL, ai))) goto exit_handler
#define SEEK(offset) SKIP((offset) - ai->xai_InPos)
#define READ(buffer,length) if ((err = xadHookAccess(XADAC_READ, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define WRITE(buffer,length) if ((err = xadHookAccess(XADAC_WRITE, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler

#define ERROR(error) do { err = XADERR_##error; goto exit_handler; } while(0)
#define ALLOC(t,v,l) \
  if (!((v) = (t) xadAllocVec((l),0x10000))) ERROR(NOMEMORY)
#define ALLOCOBJ(t,v,kind,tags) \
  if (!((v) = (t) xadAllocObjectA((kind),(tags)))) ERROR(NOMEMORY)
#define FREE(obj) xadFreeObjectA((APTR)(obj),NULL)

#define READLONG(var) do { READ(&buffer,4); (var)=EndGetM32(buffer);} while(0)


/* main ZAP LZ77 decruncher */
struct ZAPdecr {
  /* bitbuffer, checksum, input pointer, input beginning, bits left, error */
  ULONG bb, sum; UBYTE *i, *in, bl, err;
};

static INLINE ULONG ZAP_getlong(struct ZAPdecr *zd) {
  UBYTE *in; if ((in=(zd->i -= 4)) < zd->in) {zd->err=XADERR_INPUT; return 0;}
  return EndGetM32(in);
}
static INLINE ULONG ZAP_getbits(struct ZAPdecr *zd, int n) {
  int x=0; ULONG bb = zd->bb;
  while (n--) {
    if (!zd->bl--) { zd->sum ^= (bb = ZAP_getlong(zd)); zd->bl = 31; }
    x = (x<<1) | (bb&1); bb >>= 1;
  }
  zd->bb = bb;
  return x;
}

#define BITS(n) (ZAP_getbits(&zd, (n)))
#define BIT     (ZAP_getbits(&zd, 1))
#define PUT(x)  if(--o < out) return XADERR_OUTPUT; else *o=(UBYTE)(x)

static LONG ZAP_decrunch(UBYTE *in, UBYTE *out, ULONG inlen) {
  struct ZAPdecr zd;
  UBYTE *match, *o;
  int x, y;

  /* initialise state */
  zd.bb  = 0;
  zd.bl  = 0;
  zd.err = XADERR_OK;
  zd.in  = in;
  zd.i   = in + inlen;
  o      = out + ZAP_getlong(&zd);
  zd.sum = ZAP_getlong(&zd);

  /* throw away bits up to first set bit */
  while (!BIT) if (zd.err) break;

  while (o > out) {
    if ((x=BITS(2)) == 3) x = BIT ? (BIT ? -1 : (BITS(8)+19)) : (BITS(4)+3);
    if (x >= 0) do { PUT(BITS(8)); } while (x-- > 0);
    if (o <= out) break;

    if ((x = BITS(2)) == 3) {
      x = BIT ? (BIT ? -1 : (BITS(8)+20)) : (BITS(4)+4);
      if (x >= 0) y = BIT ? (BITS(13)+258) : (BITS(8)+2);
    }
    else {
      if (x) { x++; y = BIT ? (BITS(13)+258) : (BITS(8)+2); }
      else   { x=1; y = BITS(8)+2; }
    }
    match = o + y; if (x >= 0) do { PUT(*--match); } while (x-- > 0);
  }

  /* checksum should be 0 on exit */
  if (!zd.err && zd.sum) zd.err = XADERR_CHECKSUM;
  return (LONG) zd.err;
}


/* RLE decoder for compressed blocks */
static void ZAP_rledecode(UBYTE *in, UBYTE *out) {
  UBYTE *i = in+9, *o = out, *end=out + EndGetM32(in+4);
  int code=in[8], x, y;

  while (o < end) {
    if ((x = *i++) == code) {
      if ((x = *i++)) { y=*i++; x+=3; while (x--) *o++=y; } else *o++ = code;
    }
    else *o++ = x;
  }
}


ASM(BOOL) ZAP_RecogData(REG(d0, ULONG size), REG(a0, UBYTE *data), XADBASE) {
  return (BOOL) (strncmp("ZAP V1.41", data+4, 9) == 0);
}


ASM(LONG) ZAP_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE buffer[4], *textin = NULL;
  struct xadDiskInfo *xdi = NULL;
  struct xadTextInfo *ti;
  LONG err = XADERR_OK;
  ULONG tfsize;

  ALLOCOBJ(struct xadDiskInfo *, xdi, XADOBJ_DISKINFO, NULL);
  ai->xai_DiskInfo = xdi;
  xdi->xdi_EntryNumber  = 1;
  xdi->xdi_SectorSize   = 512;
  xdi->xdi_TotalSectors = 80 * 22;
  xdi->xdi_Cylinders    = 80;
  xdi->xdi_CylSectors   = 22;
  xdi->xdi_Heads        = 2;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_LowCyl       = 0;
  xdi->xdi_HighCyl      = 79;

  /* read and skip header ID text */
  READLONG(tfsize); SKIP(tfsize);

  /* read attached textfile (if it exists) */
  READLONG(tfsize);
  xdi->xdi_DataPos = ai->xai_InPos + tfsize;

  if (tfsize) {
    ALLOCOBJ(struct xadTextInfo *, ti, XADOBJ_TEXTINFO, NULL);
    xdi->xdi_TextInfo = ti;

    ALLOC(UBYTE *, textin, tfsize);
    READ(textin, tfsize);
    ti->xti_Size = EndGetM32(textin+tfsize-4);
    ALLOC(STRPTR, ti->xti_Text, ti->xti_Size+1);
    if ((err = ZAP_decrunch(textin, ti->xti_Text, tfsize))) goto exit_handler;
    ti->xti_Text[ti->xti_Size] = '\0';
  }
  else {
    xdi->xdi_TextInfo = NULL;
  }
    
exit_handler:
  if (textin) FREE(textin);

  if (err) {
    if (!xdi) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}



#define ZAP_CYLSIZE   (22*512)    /* size of one cylinder */
#define ZAP_BLOCKSIZE (22*512*8)  /* size of one block    */

struct ZAPstate {
  UBYTE data[ZAP_BLOCKSIZE+260], temp[ZAP_BLOCKSIZE], block;
};

ASM(LONG) ZAP_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct ZAPstate *zs;
  UBYTE buffer[4], cyl, block;
  LONG err = XADERR_OK;
  ULONG crlen;

  if (!(zs = (struct ZAPstate *) ai->xai_PrivateClient)) {
    ALLOC(struct ZAPstate *, zs, sizeof(struct ZAPstate));
    ai->xai_PrivateClient = (APTR) zs;
    zs->block = 99; /* sentinel value */
  }
  
  for (cyl = ai->xai_LowCyl; cyl <= ai->xai_HighCyl; cyl++) {
    /* if the current block isn't the one needed... */
    if ((block = cyl >> 3) != zs->block) {

      /* if it's not just the next block we need */
      if (zs->block != (block-1)) {
        /* go back to start of disk and skip forward to appropriate block */
        int skip = block;
        SEEK(ai->xai_CurDisk->xdi_DataPos);
        while (skip--) { READLONG(crlen); SKIP(crlen); }
      }

      /* read (possibly crunched) block into block buffer */
      READLONG(crlen);
      if (crlen > ZAP_BLOCKSIZE) ERROR(INPUT);
      READ(zs->data, crlen);

      /* if the block is crunched */
      if (crlen != ZAP_BLOCKSIZE) {
        /* decrunch it to temp buffer */
        if (EndGetM32(zs->data+crlen-4) > ZAP_BLOCKSIZE) ERROR(OUTPUT);
        if ((err = ZAP_decrunch(zs->data, zs->temp, crlen))) goto exit_handler;

        /* un-RLE back to block buffer */
        ZAP_rledecode(zs->temp, zs->data);
      }
      zs->block = block;
    }

    WRITE(zs->data + ((cyl & 7) * ZAP_CYLSIZE), ZAP_CYLSIZE);
  }

exit_handler:
  return err;
}

ASM(void) ZAP_Free(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  if (ai->xai_PrivateClient) {
    FREE(ai->xai_PrivateClient);
    ai->xai_PrivateClient = NULL;
  }
}

const struct xadClient ZAP_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 4, ZAP_VERSION, ZAP_REVISION,
  40, XADCF_DISKARCHIVER | XADCF_FREEDISKINFO |
      XADCF_FREETEXTINFO | XADCF_FREETEXTINFOTEXT,
  0, "ZAP",
  (BOOL (*)()) ZAP_RecogData,
  (LONG (*)()) ZAP_GetInfo,
  (LONG (*)()) ZAP_UnArchive,
  (void (*)()) ZAP_Free
};
