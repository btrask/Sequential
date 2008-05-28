/* Disk Imploder (DImp) disk archiver client for XAD.
 * Copyright (C) 2000-2001 Stuart Caie <kyzer@4u.net>
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

/* This XAD client reads DImp disk files, either normal data files
 * or ones with executable headers (1.00 and 2.27 headers known),
 * and writes them out as ADF files, or  allows them to be written
 * to standard Amiga formatted disks.
 * The DImp format is (C) 1988-1991 Albert-Jan Brouwer
 *
 * $VER: DImp.c 1.3 (20.08.2001)
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifndef XADMASTERFILE
#define DImp_Client      FirstClient
#define NEXTCLIENT      NULL
const UBYTE version[] = "$VER: DImp 1.3 (20.08.2001)";
#endif
#define DIMP_VERSION     1
#define DIMP_REVISION    3

#define XADBASE REG(a6, struct xadMasterBase *xadMasterBase)

/* work-doing macros */
#define SKIP(offset) if ((err = xadHookAccess(XADAC_INPUTSEEK, \
  (ULONG)(offset), NULL, ai))) goto exit_handler
#define READ(buffer,length) if ((err = xadHookAccess(XADAC_READ, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define WRITE(buffer,length) if ((err = xadHookAccess(XADAC_WRITE, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define COPY(length) if ((err = xadHookAccess(XADAC_COPY, \
  (ULONG)(length), NULL, ai))) goto exit_handler
#define ALLOC(t,v,l) if (!((v) = (t) xadAllocVec((l),0x10000))) \
  ERROR(NOMEMORY)
#define ALLOCOBJ(t,v,kind,tags) \
  if (!((v) = (t) xadAllocObjectA((kind),(tags)))) ERROR(NOMEMORY)
#define FREE(obj) xadFreeObjectA((APTR)(obj),NULL)
#define ERROR(error) do { err = XADERR_##error; goto exit_handler; } while(0)




#define DIMP_CYLSIZE  (2*11*512)

/* DImp's info-table */
#define dinf_cksum      (0)   /* ULONG checksum               */
#define dinf_compmode   (4)   /* UWORD compression_mode       */
#define dinf_bitmap     (6)   /* UBYTE disk_bitmap[10]        */
#define dinf_ctable1    (16)  /* UBYTE compression_table1[28] */
#define dinf_ctable2    (44)  /* UBYTE compression_table2[28] */
#define dinf_textplen   (72)  /* ULONG textmsg_packed_len     */
#define dinf_textulen   (76)  /* ULONG textmsg_unpacked_len   */
#define dinf_textcksum  (80)  /* ULONG textmsg_checksum       */
#define dinf_cylinfo    (84)  /* ULONG cylinder_info[80]      */
#define dinf_SIZEOF     (404) /* ...maximum length            */

static INLINE int DImp_bitmap(UBYTE *info, int track) {
  return info[dinf_bitmap + (track>>3)] & (1 << (7-(track&7)));
}

static ULONG DImp_checksum(UBYTE *data, ULONG len) {
  ULONG cksum = 0;
  while (len > 1) {
    cksum += EndGetM16(data);
    data += 2; len -= 2;
  }
  if (len) cksum += (*data << 8);
  return (cksum+7) & 0xFFFFFFFF;
}


/* de-implosion */

/* add.b d3,d3; bne gotbit; move.b -(a3),d3; addx.b d3,d3; gotbit: */
#define GETBIT do { \
 bit = bitbuf & 0x80; bitbuf <<= 1; \
 if (!bitbuf) { bit2 = bit; bitbuf = *--inp; bit = bitbuf & 0x80; \
   bitbuf <<= 1; if (bit2) bitbuf++; }; \
} while (0)

static UBYTE explode_tab1[] = { 6, 10, 10, 18 };
static UBYTE explode_tab2[] = { 1, 1, 1, 1, 2, 3, 3, 4, 4, 5, 7, 14 };

static int DImp_explode(UBYTE *buf, UBYTE *table, ULONG inlen, ULONG outlen) {
  UBYTE *inp  = buf + inlen-5;
  UBYTE *outp = buf + outlen;
  UBYTE *rep, bitbuf, bit, bit2;
  ULONG litlen, matchlen, x, y, z;

  if (inlen & 1) {
    bitbuf = inp[4];
    litlen = EndGetM32(inp);
  }
  else {
    bitbuf = inp[0];
    litlen = EndGetM32(inp+1);
  }

  while (1) {
    if (outp-litlen < buf) return 0;
    while (litlen--) *--outp = *--inp;

    /* main exit point - after the literal copy */
    if (outp <= buf) break;

    GETBIT; if (bit) {
      GETBIT; if (bit) {
        GETBIT; if (bit) {
          GETBIT; if (bit) {
            matchlen = 0;
            GETBIT; if (bit) {
              x = 3;
              matchlen = *--inp - 1;
            }
            else {
              x = 3;
              matchlen <<= 1; GETBIT; if (bit) matchlen++;
              matchlen <<= 1; GETBIT; if (bit) matchlen++;
              matchlen <<= 1; GETBIT; if (bit) matchlen++;
              matchlen += 5;
            }
          } else x=3, matchlen=4;
        } else x=2, matchlen=3;
      } else x=1, matchlen=2;
    } else x=0, matchlen=1;

    y = 0;
    z = x;
    GETBIT; if (bit) {
      GETBIT; if (bit) {
        y = explode_tab1[x];
        x += 8;
      }
      else {
        y = 2;
        x += 4;
      }
    }

    x = explode_tab2[x];
    litlen = 0;
    while (x--) { litlen<<=1; GETBIT; if (bit) litlen++; }
    litlen += y;

    rep = outp + 1;
    x = z;

    GETBIT; if (bit) {
      z <<= 1; GETBIT;
      if (bit) { rep += EndGetM16(table+z+8); x += 8; }
      else     { rep += EndGetM16(table+z);   x += 4; }
    }
    x = table[x+16];

    y = 0;
    while (x--) { y<<=1; GETBIT; if (bit) y++; }
    rep += y;

    if (outp-matchlen < buf) return 0;
    do { *--outp = *--rep; } while (matchlen--);
  }

  /* return 1 if we used up all input bytes (as we should) */
  return (inp == buf);
}




ASM(BOOL) DImp_RecogData(REG(d0, ULONG size), REG(a0, UBYTE *d), XADBASE) {
  ULONG infolen;
  if (d[0]!='D' || d[1]!='I' || d[2]!='M' || d[3]!='P') return 0;
  infolen = EndGetM32(d+4);
  return (BOOL) (infolen > 4 && infolen <= dinf_SIZEOF);
}

ASM(LONG) SAVEDS DImp_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE buffer[8], *info, *text;
  ULONG infolen, textplen, textulen;
  struct xadDiskInfo *di = NULL;
  struct xadTextInfo *ti;
  LONG err = XADERR_OK;
  int x;

  ALLOCOBJ(struct xadDiskInfo *, di, XADOBJ_DISKINFO, NULL);
  ai->xai_DiskInfo     = di;
  di->xdi_EntryNumber  = 1;
  di->xdi_SectorSize   = 512;
  di->xdi_TotalSectors = 80 * 22;
  di->xdi_Cylinders    = 80;
  di->xdi_CylSectors   = 22;
  di->xdi_Heads        = 2;
  di->xdi_TrackSectors = 11;

  /* read "DIMP" and info table length */
  READ(buffer, 8);
  infolen = EndGetM32(buffer+4);

  /* allocate and read info table */
  ALLOC(UBYTE *, info, dinf_SIZEOF);
  ai->xai_PrivateClient = (APTR) info;
  READ(info, infolen);

  /* info table checksum */
  if (EndGetM32(info+dinf_cksum) != DImp_checksum(info+4, infolen-4))
    ERROR(CHECKSUM);

  /* look for start and end cylinders */
  for (x=0; x<80; x++) if (DImp_bitmap(info, x)) break;
  di->xdi_LowCyl = x;
  if (x == 80) ERROR(EMPTY);

  for (x=79; x>=0; x--) if (DImp_bitmap(info, x)) break;
  di->xdi_HighCyl = x;


  textplen = EndGetM32(info+dinf_textplen);
  textulen = EndGetM32(info+dinf_textulen);

  di->xdi_Flags   = XADDIF_SEEKDATAPOS;
  di->xdi_DataPos = ai->xai_InPos + textplen;

  if (textulen) {
    ALLOCOBJ(struct xadTextInfo *, ti, XADOBJ_TEXTINFO, NULL);
    ALLOC(UBYTE *, text, (ti->xti_Size = textulen)+1);
    di->xdi_TextInfo = ti;
    ti->xti_Text     = text;

    READ(text, textplen);
    text[textulen] = 0;

    if (textulen != textplen && !DImp_explode(text, info+dinf_ctable1,
      textplen, textulen)) ERROR(DECRUNCH);
  }
  else {
    di->xdi_TextInfo = NULL;
  }

exit_handler:
  if (err) {
    if (!di) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}


ASM(LONG) SAVEDS DImp_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE *buf = NULL, *info = (UBYTE *) ai->xai_PrivateClient, *p;
  struct xadDiskInfo *di = ai->xai_CurDisk;
  ULONG cyl, x;
  LONG err;

  ALLOC(UBYTE *, buf, DIMP_CYLSIZE);
  for (cyl = di->xdi_LowCyl; cyl <= ai->xai_HighCyl; cyl++) {
    if (cyl >= ai->xai_LowCyl) {
      /* extracting */

      /* clear the buffer */
      p=buf; x=DIMP_CYLSIZE; while (x--) *p++ = 0;

      if (DImp_bitmap(info, cyl)) {
        x = EndGetM32(info+dinf_cylinfo+(cyl<<2));
        if (x != 0xFFFFFFFF && x != 0) {
          UWORD length = x >> 16;

          if (length > DIMP_CYLSIZE) ERROR(INPUT);
          READ(buf, length);

          if ((DImp_checksum(buf, length) & 0xFFFF) != (x & 0xFFFF))
            ERROR(CHECKSUM);

          if (length != DIMP_CYLSIZE && !DImp_explode(buf,
            info+dinf_ctable2, length, DIMP_CYLSIZE)) ERROR(DECRUNCH);
        }
      }
      WRITE(buf, DIMP_CYLSIZE);
    }
    else {
      /* skipping */
      if (DImp_bitmap(info, cyl)) {
        x = EndGetM32(info+dinf_cylinfo+(cyl<<2));
        if (x != 0xFFFFFFFF && x != 0) SKIP(x >> 16);
      }
    }
  }

exit_handler:
  if (buf) FREE(buf);
  return err;
}

ASM(void) DImp_Free(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  if (ai->xai_PrivateClient) {
    FREE(ai->xai_PrivateClient);
    ai->xai_PrivateClient = NULL;
  }
}




#define HUNK_HEADER	1011
#define HUNK_CODE	1001

ASM(BOOL) DImpSFX_RecogData(REG(d0, ULONG size), REG(a0, UBYTE *d), XADBASE) {
  ULONG i;
  if (size < 32
  ||  EndGetM32(d)    != HUNK_HEADER
  ||  EndGetM32(d+24) != HUNK_CODE) return 0;

  /* specific cases: DImp 1.00 = 3856; DImp 2.27 = 5796 */
  if ((size >= 3860 && EndGetM32(d+3856) == 0x44494D50)
  ||  (size >= 5800 && EndGetM32(d+5796) == 0x44494D50)) return 1;

  /* generic case - look just past the code hunk */
  for (i = (EndGetM32(d+28)<<2) + 36; i < size; i+=4) {
    if (EndGetM32(d+i) == 0x44494D50) return 1;
  }

  return 0;
}

ASM(LONG) DImpSFX_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG readlen, offset = 0, i;
  UBYTE *buf;
  LONG err;

  readlen = ai->xai_InSize;
  if (readlen > 6144) readlen = 6144;

  ALLOC(UBYTE *, buf, readlen);
  READ(buf, readlen);

  for (i = (EndGetM32(buf+28)<<2) + 36; i < readlen; i+=4) {
    if (EndGetM32(buf+i) == 0x44494D50) { offset = i; break; }
  }

  err = XADERR_DATAFORMAT;

exit_handler:
  if (buf) FREE(buf);

  /* if we found a match, actually look at the archive */
  if (offset != 0) {
    SKIP(offset - ai->xai_InPos);
    err = DImp_GetInfo(ai, xadMasterBase);
  }
  return err;
}


const struct xadClient DImpSFX_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 4, DIMP_VERSION, DIMP_REVISION,
  6144, XADCF_DISKARCHIVER | XADCF_FREEDISKINFO |
        XADCF_FREETEXTINFO | XADCF_FREETEXTINFOTEXT | XADCF_NOCHECKSIZE,
  0, "DImp SFX",
  (BOOL (*)()) DImpSFX_RecogData,
  (LONG (*)()) DImpSFX_GetInfo,
  (LONG (*)()) DImp_UnArchive,
  (void (*)()) DImp_Free
};

const struct xadClient DImp_Client = {
  (struct xadClient *) &DImpSFX_Client, XADCLIENT_VERSION, 4,
  DIMP_VERSION, DIMP_REVISION,
  10, XADCF_DISKARCHIVER | XADCF_FREEDISKINFO |
      XADCF_FREETEXTINFO | XADCF_FREETEXTINFOTEXT,
  0, "DImp",
  (BOOL (*)()) DImp_RecogData,
  (LONG (*)()) DImp_GetInfo,
  (LONG (*)()) DImp_UnArchive,
  (void (*)()) DImp_Free
};
