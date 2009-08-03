/* bzip -- an XAD client for extracting bzip (not bzip2) files
 * This XAD client is (C) 2000-2002 Stuart Caie <kyzer@4u.net>, but the
 * original bzip decompression code used in this client was written by
 * bzip's author, Julian Seward. bzip is (C) 1996 Julian R. Seward.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

/* $VER: bzip.c 1.2 (17.08.2002) */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>
#include "SDI_compiler.h"

#ifdef DEBUG
void KPrintF(char *fmt, ...);
#define D(x) { KPrintF x ; }
#else
#define D(x)
#endif

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

#ifndef XADMASTERFILE
#define bzip_Client     FirstClient
#define NEXTCLIENT      0
const UBYTE version[] = "$VER: bzip 1.2 (17.08.2002)";
#endif
#define BZIP_VERSION    1
#define BZIP_REVISION   2


ASM(BOOL) bzip_RecogData(REG(d0, ULONG size), REG(a0, STRPTR data), XADBASE) {
  if (data[0] != 'B' || data[1] != 'Z' || data[2] != '0') return 0;
  if (data[3] <  '1' || data[3] > '9') return 0;
  return 1;
}

/* there's only one file in a bzip archive - the uncompressed data */
ASM(LONG) bzip_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct TagItem tags[]  = {
    { XAD_OBJNAMESIZE, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct xadFileInfo *fi;
  char *name;
  int namelen;

  /* do we have a filename for this archive? */
  if ((name = ai->xai_InName))
    tags[0].ti_Data = namelen = strlen(name) + 1;

  if (!(ai->xai_FileInfo = fi = (struct xadFileInfo *) xadAllocObjectA(
    XADOBJ_FILEINFO, (name) ? tags : NULL))) return XADERR_NOMEMORY;
  fi->xfi_EntryNumber = 1;
  fi->xfi_CrunchSize  = ai->xai_InSize - 4;
  fi->xfi_Size        = 0;
  fi->xfi_DataPos     = 3;
  fi->xfi_Flags = XADFIF_NODATE | XADFIF_NOUNCRUNCHSIZE | XADFIF_SEEKDATAPOS;

  /* fill in today's date */
  datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
  xadConvertDatesA(datetags);

  if (name) {
    xadCopyMem(ai->xai_InName, (name = fi->xfi_FileName), namelen);
    if (name[namelen-4] == '.'
    && (name[namelen-3] == 'b' || name[namelen-3] == 'B')
    && (name[namelen-2] == 'z' || name[namelen-2] == 'Z'))
      name[namelen-4] = 0;
  }
  else {
    fi->xfi_FileName = xadMasterBase->xmb_DefaultName;
    fi->xfi_Flags   |= XADFIF_NOFILENAME;
  }
  return XADERR_OK;
}



/* here begins the hard bit */

#define BZIP_READBUF_SIZE  512
#define BZIP_OUTBUF_SIZE   4096
#define BZIP_MAX_SYMBOLS   256

typedef 
   struct {
      ULONG  numScalings;
      ULONG  numTraffic;
      ULONG  totFreq;
      ULONG  numSymbols;
      ULONG  incValue;
      ULONG  noExceed;
      ULONG  freq[BZIP_MAX_SYMBOLS + 2];
   }
   Model;

struct BZIPstate {
  struct xadMasterBase *xad;
  struct xadArchiveInfo *ai;

  Model models[8], bogusModel;
  ULONG bigL, bigR, bigD;

  UBYTE readbuf[BZIP_READBUF_SIZE], *bufp, *bufend;
  UBYTE outbuf[BZIP_OUTBUF_SIZE], *obufp, *obufend;
  ULONG bitbuf;
  UBYTE bitsleft;

  ULONG blocklen;      /* length of block */
  UBYTE err;           /* error code */
  UBYTE lastblock;     /* flag - is this the last block? */
  ULONG crc;           /* CRC-so-far */
  LONG  last;
  LONG  origPtr;

  /* big memory areas */
  UBYTE *block, *ll;
  LONG *zptr;
};

static void bzip_fill_readbuf(struct BZIPstate *bzs) {
  struct xadMasterBase *xadMasterBase = bzs->xad;
  struct xadArchiveInfo *ai = bzs->ai;
  ULONG avail = ai->xai_InSize - ai->xai_InPos;

  if (avail > BZIP_READBUF_SIZE) avail = BZIP_READBUF_SIZE;
  bzs->bufend = (bzs->bufp = bzs->readbuf) + avail;
  bzs->err = xadHookAccess(XADAC_READ, avail, (APTR)&bzs->readbuf, ai);
}

#define ULONG_BITS (sizeof(ULONG)<<3)
#define ENSURE_BITS(n) while (bzs->bitsleft < (n)) { \
  if (bzs->bufp >= bzs->bufend) bzip_fill_readbuf(bzs); \
  bzs->bitbuf |= *bzs->bufp++ << (ULONG_BITS-8 - bzs->bitsleft); \
  bzs->bitsleft += 8; \
}
#define PEEK_BITS(n)   (bzs->bitbuf >> (ULONG_BITS - (n)))
#define REMOVE_BITS(n) ((bzs->bitbuf <<= (n)), (bzs->bitsleft -= (n)))
#define READ_BITS(v,n) {ENSURE_BITS(n); (v)=PEEK_BITS(n); REMOVE_BITS(n);}

static ULONG bzip_crc32Table[256];

#define TWO_TO_THE(n)        (1 << (n))
#define MAX_BITS_OUTSTANDING 500000000

#define smallB 26
#define smallF 18

#define BASIS           0
#define MODEL_2_3       1
#define MODEL_4_7       2
#define MODEL_8_15      3
#define MODEL_16_31     4
#define MODEL_32_63     5
#define MODEL_64_127    6
#define MODEL_128_255   7

static void bzip_arithCodeStartDecoding (struct BZIPstate *bzs) {
  bzs->bigL = 0;
  bzs->bigR = TWO_TO_THE(smallB-1);
  bzs->bigD = 0;
  READ_BITS(bzs->bigD, smallB);
}

static LONG bzip_arithDecodeSymbol(struct BZIPstate *bzs, Model *m) {
  ULONG smallL, smallH, smallT, smallR;
  ULONG smallR_x_smallL, target, symbol;
  ULONG bits, mybits;

  smallT = m->totFreq;

  /*--- Get target value. ---*/
  if (smallT == 0) {
    D(("smallT == 0\n"))
    bzs->err = XADERR_ILLEGALDATA;
    return -1;
  }
  smallR = bzs->bigR / smallT;

  if (smallR == 0) {
    D(("smallR == 0\n"))
    bzs->err = XADERR_ILLEGALDATA;
    return -1;
  }
  target = bzs->bigD / smallR;

  if ((smallT-1) < target) target = smallT-1;

  symbol = 0;
  smallH = 0;
  while (smallH <= target) {
    symbol++;
    smallH += m->freq[symbol];
  }
  smallL = smallH - m->freq[symbol];

  smallR_x_smallL = smallR * smallL;
  bzs->bigD -= smallR_x_smallL;
   
  if (smallH < smallT)
    bzs->bigR = smallR * (smallH - smallL);
  else
    bzs->bigR -= smallR_x_smallL;

  bits=0;
  while ( bzs->bigR <= TWO_TO_THE ( smallB-2 ) ) {
    bzs->bigR <<= 1; bits++;
  }
  bzs->bigD <<= bits;
  READ_BITS(mybits, bits);
  bzs->bigD |= mybits;
  return (LONG)symbol;
}

static void bzip_initModel(
  Model *m,
  LONG initNumSymbols,
  LONG initIncValue,
  LONG initNoExceed
) {

  LONG i;
  if (initIncValue == 0) {
    m->totFreq = initNumSymbols;
    for (i = 1; i <= initNumSymbols; i++) 
      m->freq[i] = 1;
  } else {
    m->totFreq = initNumSymbols * initIncValue;
    for (i = 1; i <= initNumSymbols; i++) 
      m->freq[i] = initIncValue;
  };

  m->numSymbols                = initNumSymbols;
  m->incValue                  = initIncValue;
  m->noExceed                  = initNoExceed;
  m->freq[0]                   = 0;
  m->freq[initNumSymbols + 1]  = 0;
  m->numScalings               = 0;
}


static void bzip_updateModel(Model *m, LONG symbol) {
  ULONG i;
  m->totFreq      += m->incValue;
  m->freq[symbol] += m->incValue;
  if (m->totFreq > m->noExceed) {
    m->totFreq = 0;
    m->numScalings++;
    for (i = 1; i <= m->numSymbols; i++) {
      m->freq[i] = (m->freq[i] + 1) >> 1;
      m->totFreq += m->freq[i];
    }
  }
}

static INLINE LONG bzip_getSymbol(struct BZIPstate *bzs, Model *m) {
  LONG symbol;
  if (bzs->err) return -1;
  symbol = bzip_arithDecodeSymbol(bzs, m);
  if (bzs->err) return -1;
  bzip_updateModel(m, symbol);
  return symbol;
}

static void bzip_initBogusModel(struct BZIPstate *bzs) {
  bzip_initModel(&bzs->bogusModel, 256, 0, 256);
}

static INLINE UBYTE bzip_getUBYTE(struct BZIPstate *bzs) {
  return (UBYTE) (bzip_getSymbol(bzs, &bzs->bogusModel) - 1);
}


static INLINE LONG bzip_getLONG(struct BZIPstate *bzs) {
  ULONG x =
     (bzip_getUBYTE(bzs) << 24)
   | (bzip_getUBYTE(bzs) << 16)
   | (bzip_getUBYTE(bzs) <<  8)
   | (bzip_getUBYTE(bzs)      );
  return (LONG) x;
}

static INLINE ULONG bzip_getULONG(struct BZIPstate *bzs) {
  return
     (bzip_getUBYTE(bzs) << 24)
   | (bzip_getUBYTE(bzs) << 16)
   | (bzip_getUBYTE(bzs) <<  8)
   | (bzip_getUBYTE(bzs)      );
}


static void bzip_initModels(struct BZIPstate *bzs) {
  bzip_initModel(&bzs->models[BASIS],         11,  12,  1000);
  bzip_initModel(&bzs->models[MODEL_2_3],     2,   4,   1000);
  bzip_initModel(&bzs->models[MODEL_4_7],     4,   3,   1000);
  bzip_initModel(&bzs->models[MODEL_8_15],    8,   3,   1000);
  bzip_initModel(&bzs->models[MODEL_16_31],   16,  3,   1000);
  bzip_initModel(&bzs->models[MODEL_32_63],   32,  3,   1000);
  bzip_initModel(&bzs->models[MODEL_64_127],  64,  2,   1000);
  bzip_initModel(&bzs->models[MODEL_128_255], 128, 1,   1000);
}


#define VAL_RUNA     1
#define VAL_RUNB     2
#define VAL_ONE      3
#define VAL_2_3      4
#define VAL_4_7      5
#define VAL_8_15     6
#define VAL_16_31    7
#define VAL_32_63    8
#define VAL_64_127   9
#define VAL_128_255  10
#define VAL_EOB      11

#define RUNA    257
#define RUNB    258
#define EOB     259
#define INVALID 260

static INLINE LONG bzip_getMTFVal(struct BZIPstate *bzs) {
  switch (bzip_getSymbol(bzs, &bzs->models[BASIS])) {
  case VAL_EOB:    return EOB;
  case VAL_RUNA:   return RUNA;
  case VAL_RUNB:   return RUNB;
  case VAL_ONE:    return 1;
  case VAL_2_3:    return bzip_getSymbol(bzs, &bzs->models[MODEL_2_3])+2-1;
  case VAL_4_7:    return bzip_getSymbol(bzs, &bzs->models[MODEL_4_7])+4-1;
  case VAL_8_15:   return bzip_getSymbol(bzs, &bzs->models[MODEL_8_15])+8-1;
  case VAL_16_31:  return bzip_getSymbol(bzs, &bzs->models[MODEL_16_31])+16-1;
  case VAL_32_63:  return bzip_getSymbol(bzs, &bzs->models[MODEL_32_63])+32-1;
  case VAL_64_127: return bzip_getSymbol(bzs, &bzs->models[MODEL_64_127])+64-1;
  }
  return (LONG) bzip_getSymbol(bzs, &bzs->models[MODEL_128_255]) + 128 - 1;
}

static void bzip_getAndMoveToFrontDecode(struct BZIPstate *bzs) {
  UBYTE  yy[256];
  LONG  i, j, tmpOrigPtr, nextSym, limit;

  limit = bzs->blocklen;

  tmpOrigPtr = bzip_getLONG(bzs);
  if (bzs->err) return;

  if (tmpOrigPtr < 0) 
    bzs->origPtr = ( -tmpOrigPtr ) - 1;
  else
    bzs->origPtr =    tmpOrigPtr   - 1;

  bzip_initModels(bzs);

  for (i = 0; i <= 255; i++) {
    yy[i] = (UBYTE) i;
  }
   
  bzs->last = -1;

  nextSym = bzip_getMTFVal(bzs);

  LOOPSTART:

  if (bzs->err) return;

  if (nextSym == EOB) { bzs->lastblock = (tmpOrigPtr < 0); return; }

  /*--- acquire run-length bits, most significant first ---*/
  if (nextSym == RUNA || nextSym == RUNB) {
    LONG n = 0, bits = 31;
    do {
      if (!--bits) {
        D(("too many bits\n"))
        bzs->err = XADERR_ILLEGALDATA; return;
      }
      
      n <<= 1;
      if (nextSym == RUNA) n |= 1;
      n++;
      nextSym = bzip_getMTFVal(bzs);
      if (bzs->err) return;
    } while (nextSym == RUNA || nextSym == RUNB);

    while (n > 0) {
      bzs->last++;
      if (bzs->last >= limit) {
        D(("RLE limits\n"))
        bzs->err = XADERR_OUTPUT; return;
      }
      bzs->ll[bzs->last] = yy[0];
      n--;
    }
    goto LOOPSTART;
  }

  if (nextSym >= 1 && nextSym <= 255) {
    bzs->last++;
    if (bzs->last >= limit) {
      D(("limits\n"))
      bzs->err = XADERR_OUTPUT; return;
    }
    bzs->ll[bzs->last] = yy[nextSym];

    /*--
       This loop is hammered during decompression,
       hence the unrolling.

       for (j = nextSym; j > 0; j--) yy[j] = yy[j-1];
    --*/

    j = nextSym;
    for (; j > 3; j -= 4) {
      yy[j]   = yy[j-1]; 
      yy[j-1] = yy[j-2];
      yy[j-2] = yy[j-3];
      yy[j-3] = yy[j-4];
    }
    for (; j > 0; j--) yy[j] = yy[j-1];

    yy[0] = bzs->ll[bzs->last];
    nextSym = bzip_getMTFVal(bzs);
    goto LOOPSTART;
  }

  bzs->err = XADERR_ILLEGALDATA;
  return;
}

static void bzip_undoReversibleTransformation(struct BZIPstate *bzs) {
  UBYTE *block = bzs->block, *ll = bzs->ll;
  LONG  cc[256], *zptr = bzs->zptr;
  LONG  i, j, ch, sum;

  for (i = 0; i <= 255; i++) cc[i] = 0;
   
  for (i = 0; i <= bzs->last; i++) {
    UBYTE ll_i = ll[i];
    zptr[i] = cc[ll_i];
    cc[ll_i] ++;
  }

  sum = 0;
  for (ch = 0; ch <= 255; ch++) {
    sum = sum + cc[ch];
    cc[ch] = sum - cc[ch];
  }

  i = bzs->origPtr;
  for (j = bzs->last; j >= 0; j--) {
    UBYTE ll_i = ll[i];
    block[j] = ll_i;
    i = zptr[i] + cc[ll_i];
  }
}

#define SPOT_BASIS_STEP 8000

static void bzip_spotBlock (struct BZIPstate *bzs) {
  LONG pos, delta, newdelta;
  UBYTE *block = bzs->block;

  pos   = SPOT_BASIS_STEP;
  delta = 1;

  while (pos < bzs->last) {
    LONG n = (LONG) block[pos] - 1;
         if (n == 256) n = 0;
    else if (n == -1)  n = 255;

    if (n < 0 || n > 255) {
       bzs->err = XADERR_ILLEGALDATA;
       return;
    }

    block[pos] = (UBYTE)n;
    switch (delta) {
    case 3:  newdelta = 1; break;
    case 1:  newdelta = 4; break;
    case 4:  newdelta = 5; break;
    case 5:  newdelta = 9; break;
    case 9:  newdelta = 2; break;
    case 2:  newdelta = 6; break;
    case 6:  newdelta = 7; break;
    case 8:  newdelta = 8; break;
    case 7:  newdelta = 3; break;
    default: newdelta = 1; break;
    }
    delta = newdelta;
    pos = pos + SPOT_BASIS_STEP + 17 * (newdelta - 5);
  }
} 


#define OUTPUT_BYTE(byte) do { \
  if (bzs->obufp >= bzs->obufend) { \
    if ((bzs->err = xadHookAccess(XADAC_WRITE, BZIP_OUTBUF_SIZE, \
    (APTR) bzs->outbuf, ai))) return; \
    bzs->obufp = bzs->outbuf; \
  } \
  *bzs->obufp++ = (byte); \
  crc = (crc<<8) ^ bzip_crc32Table[(crc>>24) ^ ((byte) & 0xFF)]; \
} while(0)


static void bzip_unRLEandDump(struct BZIPstate *bzs) {
  struct xadMasterBase *xadMasterBase = bzs->xad;
  struct xadArchiveInfo *ai = bzs->ai;
  UBYTE *block = bzs->block;
  ULONG crc = bzs->crc;

  LONG  i = 0, j, numbytes = bzs->last, count = 0, chPrev, ch = 256;
  UBYTE c;

  if (bzs->lastblock) numbytes--;

  while (i <= numbytes) {
    chPrev = ch;
    ch = block[i];
    i++;

    c = (UBYTE) ch;
    OUTPUT_BYTE(c);
    if (ch != chPrev) {
      count = 1;
    } else {
      count++;
      if (count >= 4) {
        c = (UBYTE) ch;
        j = block[i];
        while (j--) OUTPUT_BYTE(c);
        i++;
        count = 0;
      }
    }
  }

  bzs->crc = crc;
  if (bzs->lastblock && block[bzs->last] != 42)
    bzs->err = XADERR_ILLEGALDATA;
}


static void bzip_MakeCRC32R(ULONG *buf, ULONG ID) {
  ULONG k;
  int i, j;
  for(i = 0; i < 256; i++) {
    k = i << 24;
    for(j=8; j--;) k = (k & 0x80000000) ? ((k << 1) ^ ID) : (k << 1);
    buf[i] = k;
  }
}

#define ERROR(error) do {bzs->err=XADERR_##error; goto exit_handler;} while(0)
#define ALLOC(t,v,l) if (!((v) = (t) xadAllocVec((l),0))) ERROR(NOMEMORY)
#define FREE(x) xadFreeObjectA((x), NULL)

ASM(LONG) SAVEDS bzip_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct BZIPstate *bzs;
  UBYTE sizechar;
  LONG err;

  bzs = xadAllocVec(sizeof(struct BZIPstate), 0);
  if (!bzs) { err = XADERR_NOMEMORY; goto exit_handler; }

  bzs->ai        = ai;
  bzs->xad       = xadMasterBase;
  bzs->crc       = ~0;
  bzs->bitbuf    = 0;
  bzs->bitsleft  = 0;
  bzs->lastblock = 0;
  bzs->err       = XADERR_OK;
  bzs->block     = NULL;
  bzs->ll        = NULL;
  bzs->zptr      = NULL;
  bzs->obufp     = bzs->outbuf;
  bzs->obufend   = bzs->outbuf + BZIP_OUTBUF_SIZE;
  bzs->bufp      = bzs->bufend = NULL;

  if ((bzs->err = xadHookAccess(XADAC_READ, 1, (APTR)&sizechar, ai)))
    goto exit_handler;
  if (sizechar < '1' || sizechar > '9') ERROR(DATAFORMAT);

  bzs->blocklen = 100000 * (sizechar - '0');
  ALLOC(UBYTE *, bzs->block, bzs->blocklen * sizeof(UBYTE));
  ALLOC(UBYTE *, bzs->ll,    bzs->blocklen * sizeof(UBYTE));
  ALLOC(LONG *,  bzs->zptr,  bzs->blocklen * sizeof(LONG));

  bzip_MakeCRC32R(&bzip_crc32Table[0], 0x04C11DB7);
  bzip_initBogusModel(bzs);
  bzip_arithCodeStartDecoding(bzs);
  do {
    if (bzs->err) goto exit_handler; bzip_getAndMoveToFrontDecode(bzs);
    if (bzs->err) goto exit_handler; bzip_undoReversibleTransformation(bzs);
    if (bzs->err) goto exit_handler; bzip_spotBlock(bzs);
    if (bzs->err) goto exit_handler; bzip_unRLEandDump(bzs);
  } while (!bzs->lastblock);

  /* write any remaining bytes */
  if (bzs->obufp > bzs->outbuf) {
    if ((bzs->err = xadHookAccess(XADAC_WRITE, bzs->obufp - bzs->outbuf,
      (APTR) bzs->outbuf, ai))) goto exit_handler;
  }

  if ((!bzs->err) && (bzip_getULONG(bzs) != (~(bzs->crc)))) ERROR(CHECKSUM);

exit_handler:
  if (bzs) {
    err = bzs->err;
    if (bzs->block) FREE(bzs->block);
    if (bzs->ll)    FREE(bzs->ll);
    if (bzs->zptr)  FREE(bzs->zptr);
    FREE(bzs);
  }
  return err;
}


const struct xadClient bzip_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 7, BZIP_VERSION, BZIP_REVISION,
  4, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO, 0, "BZip",
  (BOOL (*)()) bzip_RecogData,
  (LONG (*)()) bzip_GetInfo,
  (LONG (*)()) bzip_UnArchive,
  NULL
};
