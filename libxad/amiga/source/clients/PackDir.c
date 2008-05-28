/* PackDir client for XAD.
 * Copyright (C) 2002 Stuart Caie <kyzer@4u.net>
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

/* My thanks go to John Kortink, the author of PackDir, for providing
 * me with the file format information:
 *
 * all values are little-endian
 *
 * archive format:
 *
 * offset  length   what
 * 0       5        "PACK",0
 * 5       4        compression mode - 0 to 4
 * 9       xxx      root directory object
 * xxx     1        0
 *
 * root directory object format:
 *
 * offset  length   what
 * 0       x        null terminated object name
 * x       4        load address
 * x+4     4        execution address
 * x+8     4        attributes
 * x+12    4        number of entries in this directory
 * x+16    xxx      the entries start here - directory/file objects
 *
 * directory object format:
 *
 * offset  length   what
 * 0       x        null terminated directory name
 * x       4        load address
 * x+4     4        execution address
 * x+8     4        attributes
 * x+12    4        number of entries in this directory
 * x+16    4        1, to indicate this is a directory
 * x+20    xxx      the entries start here
 *
 * file object format:
 *
 * offset  length   what
 * 0       x        null terminated directory name
 * x       4        load address
 * x+4     4        execution address
 * x+8     4        attributes
 * x+12    4        uncompressed size of file
 * x+16    4        0, to indicate this is a file
 * x+20    4        the compressed size of file
 * x+24    xxx      the compressed data
 *
 * if the compressed size is -1, the data is not compressed
 * if the compressed size is -2, the data is not stored
 *
 * attributes:
 * bit 0 - object has owner read access
 * bit 1 - object has owner write access
 * bit 3 - object is protected from deletion
 * bit 4 - object has public read access
 * bit 5 - object has public write access
 *
 * note that "load address" and "execution address" are misnomers, they
 * actually have this format; load: 0xFFFtttdd exec: 0xdddddddd
 * the FFF indicates this special format (as opposed to actual load/exec
 * addresses), ttt is the object filetype, and dddddddddd is the time and
 * date, a 40 bit unsigned number which is the number of centiseconds
 * since 00:00:00 1st January 1900 (UTC).
 * 
 * compression modes: 0 = GIF LZW with a maximum of 12 bits
 * compression modes: 1 = GIF LZW with a maximum of 13 bits
 * compression modes: 2 = GIF LZW with a maximum of 14 bits
 * compression modes: 3 = GIF LZW with a maximum of 15 bits
 * compression modes: 4 = GIF LZW with a maximum of 16 bits
 */

#ifdef DEBUG
void KPrintF(char *fmt, ...);
#define D(x) { KPrintF x ; }
#else
#define D(x)
#endif

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>
#include <stdio.h>

#include "SDI_compiler.h"
#include "ConvertE.c"
#include "RISCOSfiletypes.c"

#ifndef XADMASTERFILE
#define PackDir_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: PackDir 1.0 (27.11.2002)";
#endif
#define PACKDIR_VERSION		1
#define PACKDIR_REVISION	0

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

ASM(BOOL) PackDir_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (d[0]=='P' && d[1]=='A' && d[2]=='C' && d[3]=='K' &&
          d[4]==0   && d[5] < 5  && d[6]==0   && d[7]==0   && d[8]==0);
}

#define MAX_DEPTH  (64)
#define MAX_NAMELEN (512)

struct PackDir_state {
  UBYTE names[MAX_DEPTH][MAX_NAMELEN];
  ULONG numobjs[MAX_DEPTH];
  struct TagItem tags[(MAX_DEPTH+3)];
};

#define READAT(offset,buffer,length) \
  (PackDir_read_at_offset((offset),(buffer),(length),ai,xadMasterBase))

LONG PackDir_read_at_offset(ULONG offset, UBYTE *buffer, ULONG length,
  struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  if ((offset - ai->xai_InPos) != 0) {
    LONG err = xadHookAccess(XADAC_INPUTSEEK, offset-ai->xai_InPos, NULL, ai);
    if (err) return err;
  }
  return xadHookAccess(XADAC_READ, length, buffer, ai);
}



LONG PackDir_readname(ULONG *offset, UBYTE *name, struct xadArchiveInfo *ai,
                      struct xadMasterBase *xadMasterBase)
{
  UBYTE buf[64], *p;
  ULONG namelen = 0;
  LONG err;

  while (!(err = READAT(*offset, buf, 64))) {
    for (p = buf; p <= &buf[63]; ) {
      (*offset)++;
      if (!(*name++ = *p++)) return XADERR_OK;
      if (++namelen == MAX_NAMELEN) return XADERR_DATAFORMAT;
    }
  }
  return err;
}

ASM(LONG) PackDir_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG offset, depth, load, exec, attr, i;
  struct PackDir_state *state;
  struct xadFileInfo *fi;
  LONG err = XADERR_OK;
  UBYTE buf[24], *p, *q;

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct TagItem prottags[] = {
    { XAD_PROTAMIGA, 0 },
    { XAD_GETPROTFILEINFO, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem addtags[] = {
    { XAD_SETINPOS, 0 },
    { TAG_DONE, 0 }
  };

  /* allocate memory for state information */
  if (!(state = xadAllocVec(sizeof(struct PackDir_state),0)))
    return XADERR_NOMEMORY;


  /* read the file header */
  if ((err = xadHookAccess(XADAC_READ, 9, buf, ai))) return err;
  /* get compression mode */
  ai->xai_PrivateClient = (APTR) EndGetI32(&buf[5]); /* LZW MAXBITS - 12 */

  /* read the root directory object */
  offset = 9;
  err = PackDir_readname(&offset, &state->names[0][0], ai, xadMasterBase);
  if (err || (err = READAT(offset, buf, 16))) goto exit_handler;
  offset += 16;
  state->numobjs[1] = EndGetI32(&buf[8]);
  depth = 1;

  /* tweak root object name - remove RISCOS directory root (eg adfs::4.$.)
   * and convert dots to slashes (backslashes to dots is todo)
   */
  q = NULL;
  for (p = &state->names[0][0]; *p; p++) {
    if (*p == '$' && p[1] == '.') q = p+2; if (*p == '.') *p = '/';
  }
  if (q) {p = &state->names[0][0]; while ((*p++ = *q++));}

  while (!err) {
    if (state->numobjs[depth] == 0) {
      /* MAIN LOOP EXIT CONDITION: depth==1, numobjs[0]==0 */
      if (depth == 1) break;
      depth--;
    }
    else {
      /* read name and object entry */
      err = PackDir_readname(&offset,&state->names[depth][0],ai,xadMasterBase);
      if (err || (err = READAT(offset, buf, 24))) goto exit_handler;
      /* that's one less object in this directory */
      state->numobjs[depth]--;

      load = EndGetI32(&buf[0]);
      exec = EndGetI32(&buf[4]);
      attr = EndGetI32(&buf[12]);
      
      /* is the object a file or directory? */
      switch (EndGetI32(&buf[16])) {
      case 0:
        /* file object */
        fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, NULL);
        if (fi) {
          fi->xfi_Size       = EndGetI32(&buf[8]);
          fi->xfi_CrunchSize = EndGetI32(&buf[20]);
          fi->xfi_Flags      = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
          fi->xfi_DataPos    = offset + 24;

          /* -1 = data not compressed */
          if (fi->xfi_CrunchSize == 0xFFFFFFFF)
            fi->xfi_CrunchSize = fi->xfi_Size;

          /* -2 = data not stored */
          if (fi->xfi_CrunchSize == 0xFFFFFFFE)
            fi->xfi_CrunchSize = 0;

          /* is date/time and filetype information included? */
          if ((load >> 20) == 0xFFF) {
            /* convert time to UNIX, then get XAD to convert, as XAD doesn't
             * support RISCOS times. Conversion code from InfoZIP.
             */
            ULONG t1, t2, tc;
            t1 = exec; t2 = load & 0xff;
            D(("date  = %02lX%08lX\n",t2,t1))

            /* 70 years forward from 1900 to 1970 is 70 years, of which 18
             * are leap years. Therefore, (365*(70-18))+(366*18) days pass,
             * which is 25568 days. 25568*24*60*60*100 = 220907520000.
             * Convert to hex = 0x336F1D4000
             * PKZIP says 25567 days, which is 0x336e996a00
             */

            /* 00:00:00 Jan. 1 1970 = 0x336e996a00 */
            tc = 0x6E996A00U;
            if (t1 < tc) t2--;
            t1 -= tc;
            t2 -= 0x33;

            D(("-1970 = %02lX%08lX\n",t2,t1))
            /* 0x100000000 / 100 = 42949672.96 */
            t1 = (t1 / 100) + (t2 * 42949673U);
            t1 -= (t2 / 25);             /* compensate for .04 error */

            D(("/100  = 00%08lX\n",t1))
            datetags[0].ti_Tag  = XAD_DATEUNIX;
            datetags[0].ti_Data = t1;

            fi->xfi_EntryInfo = GetRISCOSfiletype((load >> 8) & 0xFFF);
          }
          else {
            /* today's date only */
            D(("no date\n"))
            datetags[0].ti_Tag  = XAD_DATECURRENTTIME;
            datetags[0].ti_Data = 1;
          }
          datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
          xadConvertDatesA(datetags);

          /* convert protection flags (via Amiga protections, as XAD
           * doesn't support RISCOS protection bits)
           */
          prottags[0].ti_Data = 0x110E;
          if (attr & 0x01) prottags[0].ti_Data &= 0x00F3; /* owner read */
          if (attr & 0x02) prottags[0].ti_Data &= 0x00FB; /* owner write */
          if (attr & 0x08) prottags[0].ti_Data |= 0x0001; /* delete protect */
          if (attr & 0x08) prottags[0].ti_Data |= 0x1100; /* delete protect */
          if (attr & 0x10) prottags[0].ti_Data |= 0x8800; /* all read */
          if (attr & 0x10) prottags[0].ti_Data |= 0x4400; /* all write */
          prottags[1].ti_Data = (ULONG) fi;
          xadConvertProtectionA(prottags);
          
          /* create the filename */
          for (i = 0; i <= depth; i++) {
            state->tags[i].ti_Tag  = XAD_CSTRING;
            state->tags[i].ti_Data = (ULONG) &state->names[i][0];
          }
          state->tags[i].ti_Tag = TAG_DONE;

          fi->xfi_FileName = xadConvertNameA(CHARSET_HOST, &state->tags[0]);
          if (!fi->xfi_FileName) {
            err = XADERR_NOMEMORY;
            goto exit_handler;
          }

          /* add the file */
          offset += 24 + fi->xfi_CrunchSize;
          err = xadAddFileEntryA(fi, ai, NULL);
        }
        else {
          err = XADERR_NOMEMORY;
        }
        break;
      case 1:
        /* directory object */
        offset += 20; /* directory header size */
        state->numobjs[++depth] = EndGetI32(&buf[8]);
        break;
      default:
        err = XADERR_DATAFORMAT;
        break;
      }
    }
  }

exit_handler:

  xadFreeObjectA((APTR) state, NULL);

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

/* PackDir uses the GIF variant of LZW compression, except that the first
 * byte of the GIF Raster Data stream (giving the number of bits needed
 * per pixel, i.e. 8 for 256-colour pictures) is missing. Instead, this
 * value is fixed to 8 bits per "pixel" (we're decoding generic 8-bit
 * data, not pixels).
 *
 * The LZW implementation is inspired equally by the sources of compress(1)
 * and Mozilla 1.1.
 */

/* size of input/output buffers. Arbitrary. */
#define LZW_INSZ  (64)
#define LZW_OUTSZ (64)

#define LZW_DATASIZE (8) /* bits per "pixel" */

#define LZW_OUTPUT_BYTE(x) do {                                  \
  if (olen == 0) { err = XADERR_OUTPUT; goto exit_handler; }     \
  *optr++ = (UBYTE) (x); olen--;                                 \
  if (optr == oend) {                                            \
    if ((err = xadHookAccess(XADAC_WRITE, LZW_OUTSZ, obuf, ai))) \
        goto exit_handler;                                       \
    optr = &obuf[0];                                             \
  }                                                              \
} while (0)

ASM(LONG) PackDir_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG code, oldcode, clearcode, firstchar, incode, *prefix, maxcodes;
  UBYTE ibuf[LZW_INSZ], obuf[LZW_OUTSZ], *iptr, *optr, *iend, *oend;
  UBYTE bitsleft, *suffix, *stack, codesize, *stackp;
  ULONG ilen, olen, bitbuf, iread, codemask, next_avail;
  LONG err = XADERR_OK;
  int i;

  ilen = ai->xai_CurFile->xfi_CrunchSize;
  olen = ai->xai_CurFile->xfi_Size;

  /* special case: file not stored. write nulls */
  if (ilen == 0) {
    for (i = 0; i < 64; i++) obuf[i] = 0;
    while (olen > 0) {
      i = (olen > 64) ? 64 : olen;
      if ((err = xadHookAccess(XADAC_WRITE, i, &obuf[0], ai))) return err;
      olen -= i;
    }
    return XADERR_OK;
  }

  /* special case: file not compressed. */
  if (ilen == olen) {
    return xadHookAccess(XADAC_COPY, olen, NULL, ai);
  }

  /* initialise input, output and bit buffers */
  iptr = iend = &ibuf[0];
  optr = &obuf[0];
  oend = optr + LZW_OUTSZ;
  bitsleft = 0;
  bitbuf  = 0;

  /* allocate LZW tables */
  maxcodes = 1 << (((ULONG) ai->xai_PrivateClient) + 12); /* LZW MAXBITS */
  prefix = xadAllocVec(sizeof(ULONG) * (maxcodes+1), 0);
  suffix = xadAllocVec(sizeof(UBYTE) * (maxcodes+1), 0);
  stack  = xadAllocVec(sizeof(UBYTE) * (maxcodes+1), 0);
  if (!prefix || !suffix || !stack) {
    err = XADERR_NOMEMORY;
    goto exit_handler;
  }

  /* initialise variables */
  codesize = LZW_DATASIZE + 1;
  codemask = (1 << codesize) - 1;
  clearcode = 1 << LZW_DATASIZE;
  next_avail = clearcode + 2;
  oldcode = 0xFFFF;

  /* initialise tables */
  for (i = 0; i < clearcode; i++) {
    prefix[i] = 0;
    suffix[i] = (UBYTE) i;
  }
  stackp = &stack[0];

  while (olen > 0) {
    /* add another byte to the bit buffer */
    if (iptr == iend) {
      iread = (ilen > LZW_INSZ) ?  LZW_INSZ : ilen;
      if (iread == 0) { err=XADERR_INPUT; goto exit_handler; }
      if ((err = xadHookAccess(XADAC_READ, iread, ibuf, ai)))
        goto exit_handler;
      iptr = &ibuf[0]; iend = iptr + iread; ilen -= iread;
    }
    bitbuf |= (*iptr++ << bitsleft);
    bitsleft += 8;

    while (bitsleft > codesize) {
      /* read next code */
      /* LZW bit order: Imagine you are reading 5-bit data, aaaaA bbbbB
       * ccccC ddddD eeeeE (LSB is capitalised). They are stored in the byte
       * stream like so: bbBaaaaA DccccCbb eeeEdddd .......e
       */
      code = bitbuf & codemask;
      bitsleft -= codesize;
      bitbuf >>= codesize;

      /* is it the clear table code? */
      if (code == clearcode) {
        codesize = LZW_DATASIZE + 1;
        codemask = (1 << codesize) - 1;
        clearcode = 1 << LZW_DATASIZE;
        next_avail = clearcode + 2;
        oldcode = 0xFFFF;
        continue;
      }
  
      /* is it the end-of-stream code? */
      if (code == (clearcode + 1)) {
        olen = 0;
        break;
      }
  
      /* if this is the first code output? */
      if (oldcode == 0xFFFF) {
        LZW_OUTPUT_BYTE(suffix[code]);
        firstchar = oldcode = code;
        continue;
      }
  
      /* check that code is within the current table limits */
/* this mozilla code leads to premature failures, and isn't replicated
 * in other LZW sources
      if (code > next_avail) {
        err = XADERR_ILLEGALDATA;
        goto exit_handler;
      }
*/  
      incode = code;
      if (code >= next_avail) {
        *stackp++ = firstchar;
        code = oldcode;
      }
  
      /* go through table entries back to the root */
      while (code > clearcode) {
        WORD code2;
        code2 = code;
        if (code == prefix[code]) {
          D(("search: circular table entry detected\n"))
          err = XADERR_ILLEGALDATA;
          goto exit_handler;
        }
  
        *stackp++ = suffix[code];
        code = prefix[code];
  
        if (code2 == prefix[code]) {
          D(("search: circular table entry detected (2)\n"))
          err = XADERR_ILLEGALDATA;
          goto exit_handler;
        }
      }

      *stackp++ = firstchar = suffix[code];

      if (next_avail < maxcodes) {
        prefix[next_avail] = oldcode;
        suffix[next_avail] = firstchar;
        next_avail++;
  
        /* if all codes of this bitlength are used up, increase the codesize */
        if (((next_avail & codemask) == 0) && (next_avail < maxcodes)) {
          codesize++;
          codemask += next_avail;
        }
      }
      oldcode = incode;
  
      /* copy the decoded data to output */
      do { LZW_OUTPUT_BYTE(*--stackp); } while (stackp > stack);
    }
  }

  /* final write */
  if (optr != obuf) {
    err = xadHookAccess(XADAC_WRITE, optr-obuf, obuf, ai);
  }

exit_handler:
  if (prefix) xadFreeObjectA((APTR) prefix, NULL);
  if (suffix) xadFreeObjectA((APTR) suffix, NULL);
  if (stack)  xadFreeObjectA((APTR) stack, NULL);

  return err;
}

const struct xadClient PackDir_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 10, PACKDIR_VERSION, PACKDIR_REVISION,
  9, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "PackDir",

  /* client functions */
  (BOOL (*)()) PackDir_RecogData,
  (LONG (*)()) PackDir_GetInfo,
  (LONG (*)()) PackDir_UnArchive,
  NULL
};
