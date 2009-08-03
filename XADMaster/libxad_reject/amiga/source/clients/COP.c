/* COP! disk archiver client for XAD
 * (C) 2000-2002 Stuart Caie <kyzer@4u.net>
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

/* COP! is an XPK-based disk archiver, written by Armin Sander
 * for Markt & Technik in 1992. It is part of the RAP!TOP!COP!
 * compilation of utilities, all written by Armin Sander.
 * - RAP! is a Stakker-like realtime disk compression system.
 * - TOP! is a disk defragmenter
 * - COP! is a disk copier and archiver.
 *
 * COP! can use not just XPK libraries for compression, but also
 * the four special "PACK" libraries that come with RAP!:
 * - lhst: This simply uses the lh.library compression, by Holger P. Krekel
 *         and Olaf Barthel.
 * - runl: A simple run length encoder
 * - scf1: A messy LZ77 algorithim by Armin. Fast compression.
 * - scn1: Identical to scf1 in format, but slower/better compression.
 *
 * "Dem Paket beiliegend ist nun auch der scf1-Packer, der um einige
 * Prozente schlechter abschneidet als scn1-Packer, aber dafür im einiges
 * schneller ist."
 *
 * Armin Sander's homepage is at http://mindwalker.org/rnd/
 *
 * COP format (all unsigned big-endian four byte values):
 * - header
 * - block
 * - block
 * - ...
 * 
 * COP header:
 * offset  field                value in normal Amiga disk
 * 0       Identification 1     "COP0"
 * 4       Identification 2     0x932AE3DB	
 * 8       compression used     "SHRI", "SQSH", etc or 0 for no compression
 * 12      lowcyl               0
 * 16      highcyl              79
 * 20      reserved             2
 * 24      sectorsize           512
 * 28      surfaces             2
 * 32      sectors per cylinder 11
 * 36      interleave           0
 * 40      cylinders            80
 * 44      SIZEOF
 * 
 * COP block type 1: no compression (XPK packer = 0x000000000)
 *   ULONG block_size
 *   UBYTE raw_data[block_size]
 * 
 * COP block type 2: XPK packed
 *   ULONG block_size
 *   ULONG packed_data_size (== block_size - 8)
 *   ULONG unpacked_data_size
 *   UBYTE xpk_packed_data[packed_data_size]
 * 
 * COP block type 3: XPK packed, but XPK failed to compress the block
 *   ULONG block_size
 *   ULONG packed_data_size            (== block_size - 8)
 *   ULONG unpacked_data_size          (== packed_data_size)
 *   UBYTE raw_data[packed_data_size]
 *
 * $VER: COP.c 1.3 (14.04.2002)
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "ConvertE.c"
#include "SDI_compiler.h"
#include "xadXPK.c"

#ifndef XADMASTERFILE
#define COP_Client		FirstClient
#define NEXTCLIENT		0
UBYTE version[] = "$VER: COP 1.3 (14.04.2002)";
#endif
#define COP_VERSION     1
#define COP_REVISION    3

#ifdef DEBUG
void KPrintF(char *fmt, ...);
#define D(x) { KPrintF x ; }
#else
#define D(x)
#endif

#define XADBASE REG(a6, struct xadMasterBase *xadMasterBase)

ASM(BOOL) COP_RecogData(REG(d0, ULONG size), REG(a0, UBYTE *d), XADBASE) {
  return (BOOL) (d[0]=='C'  && d[1]=='O'  && d[2]=='P'  && d[3]=='0' &&
                 d[4]==0x93 && d[5]==0x2A && d[6]==0xE3 && d[7]==0xDB) ? 1:0;
}

ASM(LONG) COP_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct xadDiskInfo *xdi;
  UBYTE buffer[44];
  LONG err;

  xdi = (struct xadDiskInfo *) xadAllocObjectA(XADOBJ_DISKINFO, NULL);
  if (!(ai->xai_DiskInfo = xdi)) return XADERR_NOMEMORY;
  if ((err = xadHookAccess(XADAC_READ, 44, (APTR)&buffer, ai))) return err;

  xdi->xdi_EntryNumber  = 1;
  xdi->xdi_TrackSectors = EndGetM32(&buffer[32]);
  xdi->xdi_Heads        = EndGetM32(&buffer[28]);
  xdi->xdi_LowCyl       = EndGetM32(&buffer[12]);
  xdi->xdi_HighCyl      = EndGetM32(&buffer[16]);
  xdi->xdi_SectorSize   = EndGetM32(&buffer[24]);
  xdi->xdi_Cylinders    = EndGetM32(&buffer[40]);
  xdi->xdi_CylSectors   = xdi->xdi_TrackSectors * xdi->xdi_Heads;
  xdi->xdi_TotalSectors = xdi->xdi_CylSectors * xdi->xdi_Cylinders;
  return XADERR_OK;
}


/* RAP!TOP!COP! special compression library methods */

static BOOL COP_lhst(UBYTE *src, UBYTE *dest, ULONG slen, ULONG dlen) {
  /* TODO: use LhDecode() from Zoom.c */
  return 0;
}

static BOOL COP_runl(UBYTE *src, UBYTE *dest, ULONG slen, ULONG dlen) {
  UBYTE *src_end  = &src[slen], *dest_end = &dest[dlen], x, y;
  while (dest < dest_end) {
    if ((src+2) > src_end) return 0;
    if ((x = *src++) < 128) {
      x++; if ((x > (src_end-src)) || (x > (dest_end-dest))) return 0;
      while (x--) *dest++ = *src++;
    }
    else {
      x = (256 - x) + 2; y = *src++;
      if (x > (dest_end-dest)) return 0;
      while (x--) *dest++ = y;
    }
  }
  return dest == dest_end;
}

/* SCF1 and SCN1 are the same format, the user either gets to pick 'fast'
 * compression (SCF1) or 'normal' compression (SCN1). Data is broken up
 * into blocks of 16k. Each block is encoded two bytes dictating how long
 * this block is when compressed, and then has a bitstream running forwards
 * from the start of the block and a bytestream running backwards from the
 * end of the block.
 */

#define SCF1_BLKSIZE (0x4000)

static UWORD scf1_lens[4] = { 4, 6, 8, 10 };
static UWORD scf1_offsets[4] = {
  2,
  2 + 32,
  2 + 32 + 128,
  2 + 32 + 128 + 512
};

#define SCF1_GET_BIT do {\
  if (!bitc--) { bitc = 15; bitbuf = (bitp[0]<<8) | bitp[1]; bitp += 2; } \
  bit = (bitbuf & 0x8000) ? 1 : 0; bitbuf <<= 1; \
} while (0)

#define SCF1_GET_BITS(nbits) do { \
  bitsc=nbits; bits=0; while (bitsc--) { SCF1_GET_BIT; bits += bits + bit; } \
} while (0)

static BOOL SAVEDS COP_scf1(UBYTE *src, UBYTE *dest, ULONG slen, ULONG dlen) {
  UBYTE *bitp, bit, bitc, bitsc;
  UBYTE *bytep, *dest_end, *match, *src_end = &src[slen], *org_dest;
  ULONG blklen, x, bitbuf, bits;

  while (dlen > 0) {
    blklen     = (dlen > SCF1_BLKSIZE) ? SCF1_BLKSIZE : dlen;
    dest_end   = &dest[blklen];
    slen       = ((src[0]<<8) | src[1]);
    bytep      = &src[slen];
    if (bytep > src_end) return 0;

    /* initialise bitstream */
    bitp       = &src[2];
    bitc       = 0;

    while (dest < dest_end) {
      if ((bitp > bytep) || (bytep < src)) return 0;

      SCF1_GET_BIT;
      if (! bit) {
        /* literal */
        *dest++ = *--bytep;

        SCF1_GET_BITS(2);
        if (bits == 0) {
          *dest++ = *--bytep;
          *dest++ = *--bytep;
          *dest++ = *--bytep;

          SCF1_GET_BITS(2);
          if (bits == 0) {
            do {
              *dest++ = *--bytep;
              *dest++ = *--bytep;
              *dest++ = *--bytep;

              SCF1_GET_BITS(4);
              if (bits == 0) {
                /* go back to top of do loop - 15 bytes in total */
                x = 12; while (x--) *dest++ = *--bytep;
              }
              else {
                x = 15 - bits; while (x--) *dest++ = *--bytep;
              }
            } while ((bits == 0) && (dest < dest_end));
          }
          else {
            x = 3 - bits; while (x--) *dest++ = *--bytep;
          }
        }
        else {
          x = 3 - bits; while (x--) *dest++ = *--bytep;
        }
        if (dest == dest_end) break;
      } /* if (! bit) */

      SCF1_GET_BITS(2);
      match = dest - scf1_offsets[bits];
      x = scf1_lens[bits] + 1;

      /* refine offset using scf1_lens[] number of bits */
      bits = 0;
      if (x >= 8) { bits = *--bytep; x -= 8; }
      while (x--) { SCF1_GET_BIT; bits += bits + bit; }
      match -= bits;
      
      org_dest = dest;
      *dest++ = *match++;
      *dest++ = *match++;
      do {
        SCF1_GET_BITS(2);
        x = 3-bits; while (x--) *dest++ = *match++;
      } while ((bits == 0) && (dest < dest_end));
    } /* while (dest < dest_end) */

    /* move to next compressed block */
    if (dest != dest_end) return 0;
    src  += slen;
    dlen -= blklen;
  }
  return 1;
}

ASM(LONG) COP_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct xadDiskInfo *di = ai->xai_CurDisk;
  UBYTE buffer[12], *inbuf = NULL, *outbuf = NULL;
  ULONG cylsize, start, length, offset=0, foffset=44;
  ULONG crlen, blklen, outlen, xpk_mode;
  LONG err;

  cylsize = di->xdi_CylSectors * di->xdi_SectorSize;
  start  = (ai->xai_LowCyl - di->xdi_LowCyl) * cylsize;
  length = (ai->xai_HighCyl + 1 - ai->xai_LowCyl) * cylsize;

  if ((err = xadHookAccess(XADAC_INPUTSEEK, 8 - ai->xai_InPos, NULL, ai)) ||
      (err = xadHookAccess(XADAC_READ, 4, buffer, ai))) return err;
  xpk_mode = EndGetM32(&buffer[0]);
  
  while (length) {
    /* go to next header and read in unpacked block length */
    if ((err = xadHookAccess(XADAC_INPUTSEEK, foffset - ai->xai_InPos,
                             NULL, ai)) ||
        (err = xadHookAccess(XADAC_READ, 4, buffer, ai))) break;
    blklen = EndGetM32(buffer);
    foffset = ai->xai_InPos + blklen;

    if (xpk_mode != 0) {
      if ((err = xadHookAccess(XADAC_READ, 8, buffer, ai))) break;
      crlen  = EndGetM32(&buffer[0]);
      blklen = EndGetM32(&buffer[4]);
    }

    /* should we be writing data from this block? */
    if (start < (offset + blklen)) {
      /* calculate amount required to be output */
      length -= (outlen = (blklen > length) ? length : blklen);

      /* read (and decrunch) the block */
      if (xpk_mode && (crlen != blklen)) {
        switch (xpk_mode) {
        case 0x6C687374: /* lhst */
        case 0x72756E6C: /* runl */
        case 0x73636631: /* scf1 */
        case 0x73636E31: /* scn1 */
          /* allocate memory for input and output buffer */
          inbuf  = (UBYTE *) xadAllocVec(crlen,      0);
          outbuf = (UBYTE *) xadAllocVec(blklen+16,  0); /* scf1 safety */
          if (!inbuf || !outbuf) { err = XADERR_NOMEMORY; break; }

          /* read crunched data into input buffer */
          if ((err = xadHookAccess(XADAC_READ, crlen, inbuf, ai))) break;

          /* pick appropriate decrunch function and perform decrunch */
          switch (xpk_mode) {
          case 0x6C687374: /* lhst */
            err = COP_lhst(inbuf, outbuf, crlen, blklen);
            break;
          case 0x72756E6C: /* runl */
            err = COP_runl(inbuf, outbuf, crlen, blklen);
            break;
          case 0x73636631: /* scf1 */
          case 0x73636E31: /* scn1 */
            err = COP_scf1(inbuf, outbuf, crlen, blklen);
            break;
          }
          err = err ? XADERR_OK : XADERR_DECRUNCH;
          break;

        default: /* XPK compression */
          err = xpkDecrunch(&outbuf, &crlen, ai, xadMasterBase);
        }

        /* write decrunched data to disk */
        if (!err) err = xadHookAccess(XADAC_WRITE, outlen,
                                      &outbuf[start - offset], ai);
          

        if (inbuf) { xadFreeObjectA((APTR) inbuf,  NULL); inbuf  = NULL; }
        xadFreeObjectA((APTR) outbuf, NULL); outbuf = NULL;
      }
      else {
        err = xadHookAccess(XADAC_COPY, outlen, NULL, ai);
      }
     if (err) break;
    }
    offset += blklen;
  }

  if (inbuf)  xadFreeObjectA((APTR) inbuf,  NULL);
  if (outbuf) xadFreeObjectA((APTR) outbuf, NULL);
  return err;
}

const struct xadClient COP_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 4, COP_VERSION, COP_REVISION,
  44, XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  0, "COP!",
  (BOOL (*)()) COP_RecogData,
  (LONG (*)()) COP_GetInfo,
  (LONG (*)()) COP_UnArchive,
  (void (*)()) NULL
};
