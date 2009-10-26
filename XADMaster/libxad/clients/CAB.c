#ifndef XADMASTER_CAB_C
#define XADMASTER_CAB_C

/*  $Id: CAB.c,v 1.9 2005/06/23 14:54:40 stoecker Exp $
    Microsoft Cabinet archiver

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>
    Copyright (C) 2000-2002 Stuart Caie <kyzer@4u.net>

    Quantum algorithm is based on the work of  Matthew T. Russotto
    Copyright (C) 2002 Matthew T. Russotto <russotto@speakeasy.net>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/* Credits:
 * The CAB format, and MSZIP/LZX formats are described in the documents
 * CABFMT.DOC, LZXFMT.DOC and MSZIPFMT.DOC in the CAB SDK, which is
 * (C) 1997 Microsoft Corporation.
 *
 * MSZIP is a modification of the inflate and deflate methods created by
 * Phil Katz. LZX was created by Johnathan Forbes and Tomi Poutanen.
 * Quantum was created by David Stafford.
 *
 * The MSZIP part of this client was written for me by Dirk Stˆcker, who
 * based it on code from InfoZip's free UnZip utility. Dirk also provided
 * extensive testing materials, feedback and moral support (oh - and he
 * created the XAD system :). I took the fast Huffman table builder from
 * David Tritscher's unlzx (no relation :) and adapted to my needs.
 */

/* CAB has pretty much everything - multivolume archives, merged file data,
 * and multiple compression formats. 'Folders' store compressed data, and
 * may span several cabinets. 'Files' live as data inside a folder when
 * uncompressed. EOR checksums are used instead of CRCs. Four compression
 * formats are known - NONE, MSZIP, QUANTUM and LZX. NONE is obviously
 * uncompressed data. MSZIP is simply PKZIP's deflate/inflate algorithims
 * with 'CK' as a signature instead of 'PK'. QUANTUM is an LZ + arithmetic
 * coding compressor from 1994, licensed by Microsoft from Cinematronics.
 * LZX is a much loved LZH based archiver in the Amiga world, the algorithim
 * taken (bought?) by Microsoft and tweaked for Intel code.
 */

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 10
#endif

XADCLIENTVERSTR("CAB 1.6 (04.04.2004)")

/* disable debugging for now */
#define D(x)

#define CAB_VERSION             1
#define CAB_REVISION            6

/* work-doing macros */

/* required: label exit_handler; struct xadArchiveInfo *ai; xadINT32 err; */

#define SKIP(offset) if ((err = xadHookAccess(XADM XADAC_INPUTSEEK, \
  (xadUINT32)(offset), NULL, ai))) goto exit_handler
#define SEEK(offset) SKIP((offset) - ai->xai_InPos)

#define READ(buffer,length) if ((err = xadHookAccess(XADM XADAC_READ, \
  (xadUINT32)(length), (xadPTR)(buffer), ai))) goto exit_handler
#define WRITE(buffer,length) if ((err = xadHookAccess(XADM XADAC_WRITE, \
  (xadUINT32)(length), (xadPTR)(buffer), ai))) goto exit_handler

#define ERROR(error) { \
  D(("CAB: error " #error " line %ld\n", __LINE__)) \
  err = XADERR_##error; goto exit_handler; \
}
#define TAINT(reason) { \
  ai->xai_Flags |= XADAIF_FILECORRUPT; \
  D(("CAB: TAINT - " reason "\n")) \
}

#define ALLOC(t,v,l) \
  if (!((v) = (t) xadAllocVec(XADM (l),0x10000))) ERROR(NOMEMORY)
#define FREE(obj) xadFreeObjectA(XADM (obj),NULL)

/* shortcuts */
#define CABSTATE struct CABstate *cabstate
#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)
#define CAB(x)   (cabstate->x)
#define ZIP(x)   (cabstate->arcstate.zip.x)
#define QTM(x)   (cabstate->arcstate.qtm.x)
#define LZX(x)   (cabstate->arcstate.lzx.x)

#define CABFILEFOL(fi) ((struct CABfolder *)(fi)->xfi_PrivateInfo)

/* requires xadUINT8 buf[] */
#define GETLONG(n) EndGetI32(&buf[n])
#define GETWORD(n) EndGetI16(&buf[n])
#define GETBYTE(n) buf[n]

/* number of bits in xadUINT32. Note: This must be at multiple of 16, and at
 * least 32 for the bitbuffer code to work (ie, it must be able to ensure
 * up to 17 bits - that's adding 16 bits when there's one bit left, or
 * adding 32 bits when there are no bits left. The code should work fine
 * for machines where xadUINT32 >= 32 bits.
 */
#define xadUINT32_BITS (sizeof(xadUINT32)<<3)

/*--------------------------------------------------------------------------*/
/* our archiver information / state */

/* MSZIP stuff */

#define ZIPWSIZE        0x8000  /* window size--must be a power of two, and at least 32K for zip's deflate method */
#define ZIPLBITS        9       /* bits in base literal/length lookup table */
#define ZIPDBITS        6       /* bits in base distance lookup table */
#define ZIPBMAX         16      /* maximum bit length of any code (16 for explode) */
#define ZIPN_MAX        288     /* maximum number of codes in any set */

struct CABZiphuft {
  xadUINT8 e;                /* number of extra bits or operation */
  xadUINT8 b;                /* number of bits in this code or subcode */
  union {
    xadUINT16 n;              /* literal, length base, or distance base */
    struct CABZiphuft *t;    /* pointer to next level of table */
  } v;
};

struct CABZIPstate {
    xadUINT32 window_posn;     /* current offset within the window        */

    xadUINT32 bb;              /* bit buffer */
    xadUINT32 bk;              /* bits in bit buffer */
    xadUINT32 ll[288+32];          /* literal/length and distance code lengths */
    xadUINT32 c[ZIPBMAX+1];    /* bit length count table */
    xadINT32  lx[ZIPBMAX+1];   /* memory for l[-1..ZIPBMAX-1] */
    struct CABZiphuft *u[ZIPBMAX];              /* table stack */
    xadUINT32 v[ZIPN_MAX];     /* values in order of bit length */
    xadUINT32 x[ZIPBMAX+1];    /* bit offsets, then code stack */

    xadUINT8 *inpos;
};


/* Quantum stuff */

struct CABQTMmodelsym {
  xadUINT16 sym, cumfreq;
};

struct CABQTMmodel {
  int shiftsleft, entries;
  struct CABQTMmodelsym *syms;
  xadUINT16 tabloc[256];
};

struct CABQTMstate {
    xadUINT8 *window;         /* the actual decoding window              */
    xadUINT32 window_size;     /* window size (1Kb through 2Mb)           */
    xadUINT32 actual_size;     /* window size when it was first allocated */
    xadUINT32 window_posn;     /* current offset within the window        */

    struct CABQTMmodel model7;
    struct CABQTMmodelsym m7sym[7+1];

    struct CABQTMmodel model4, model5, model6pos, model6len;
    struct CABQTMmodelsym m4sym[0x18 + 1];
    struct CABQTMmodelsym m5sym[0x24 + 1];
    struct CABQTMmodelsym m6psym[0x2a + 1], m6lsym[0x1b + 1];

    struct CABQTMmodel model00, model40, model80, modelC0;
    struct CABQTMmodelsym m00sym[0x40 + 1], m40sym[0x40 + 1];
    struct CABQTMmodelsym m80sym[0x40 + 1], mC0sym[0x40 + 1];
};

/* LZX stuff */

/* some constants defined by the LZX specification */
#define LZX_MIN_MATCH                (2)
#define LZX_MAX_MATCH                (257)
#define LZX_NUM_CHARS                (256)
#define LZX_BLOCKTYPE_INVALID        (0)   /* also blocktypes 4-7 invalid */
#define LZX_BLOCKTYPE_VERBATIM       (1)
#define LZX_BLOCKTYPE_ALIGNED        (2)
#define LZX_BLOCKTYPE_UNCOMPRESSED   (3)
#define LZX_PRETREE_NUM_ELEMENTS     (20)
#define LZX_ALIGNED_NUM_ELEMENTS     (8)   /* aligned offset tree #elements */
#define LZX_NUM_PRIMARY_LENGTHS      (7)   /* this one missing from spec! */
#define LZX_NUM_SECONDARY_LENGTHS    (249) /* length tree #elements */


/* LZX huffman defines: tweak tablebits as desired */
#define LZX_PRETREE_MAXSYMBOLS  (LZX_PRETREE_NUM_ELEMENTS)
#define LZX_PRETREE_TABLEBITS   (6)
#define LZX_MAINTREE_MAXSYMBOLS (LZX_NUM_CHARS + 50*8)
#define LZX_MAINTREE_TABLEBITS  (12)
#define LZX_LENGTH_MAXSYMBOLS   (LZX_NUM_SECONDARY_LENGTHS+1)
#define LZX_LENGTH_TABLEBITS    (12)
#define LZX_ALIGNED_MAXSYMBOLS  (LZX_ALIGNED_NUM_ELEMENTS)
#define LZX_ALIGNED_TABLEBITS   (7)

#define LZX_LENTABLE_SAFETY (64) /* we allow length table decoding overruns */

#define LZX_DECLARE_TABLE(tbl) \
  xadUINT16 tbl##_table[(1<<LZX_##tbl##_TABLEBITS) + (LZX_##tbl##_MAXSYMBOLS<<1)];\
  xadUINT8 tbl##_len  [LZX_##tbl##_MAXSYMBOLS + LZX_LENTABLE_SAFETY]


struct CABLZXstate {
    xadUINT8 *window;         /* the actual decoding window              */
    xadUINT32 window_size;     /* window size (32Kb through 2Mb)          */
    xadUINT32 actual_size;     /* window size when it was first allocated */
    xadUINT32 window_posn;     /* current offset within the window        */
    xadUINT32 R0, R1, R2;      /* for the LRU offset system               */
    xadUINT16 main_elements;   /* number of main tree elements            */
    xadBOOL  header_read;     /* have we started decoding at all yet?    */
    xadUINT16 block_type;      /* type of this block                      */
    xadUINT32 block_length;    /* uncompressed length of this block       */
    xadUINT32 block_remaining; /* uncompressed bytes still left to decode */
    xadUINT32 frames_read;     /* the number of CFDATA blocks processed   */
    xadINT32  intel_filesize;  /* magic header value used for transform   */
    xadINT32  intel_curpos;    /* current offset in transform space       */
    xadBOOL  intel_started;   /* have we seen any translatable data yet? */

    LZX_DECLARE_TABLE(PRETREE);
    LZX_DECLARE_TABLE(MAINTREE);
    LZX_DECLARE_TABLE(LENGTH);
    LZX_DECLARE_TABLE(ALIGNED);
};



/*--------------------------------------------------------------------------*/
/* CAB structures */

#define CFHEAD_SIGNATURE (('M') | ('S'<<8) | ('C'<<16) | ('F'<<24)) /*intel!*/

#define cfhead_Signature         (0x00)
#define cfhead_Reserved1         (0x04)
#define cfhead_CabinetSize       (0x08)
#define cfhead_Reserved2         (0x0C)
#define cfhead_FileOffset        (0x10)
#define cfhead_Reserved3         (0x14)
#define cfhead_MinorVersion      (0x18)
#define cfhead_MajorVersion      (0x19)
#define cfhead_NumFolders        (0x1A)
#define cfhead_NumFiles          (0x1C)
#define cfhead_Flags             (0x1E)
#define cfhead_SetID             (0x20)
#define cfhead_CabinetIndex      (0x22)
#define cfhead_SIZEOF            (0x24)
#define cfheadext_HeaderReserved (0x00)
#define cfheadext_FolderReserved (0x02)
#define cfheadext_DataReserved   (0x03)
#define cfheadext_SIZEOF         (0x04)
/* cfhead_ReservedArea (== HeaderReserved bytes) */
/* cfhead_PrevCabFile (null terminated string)   */
/* cfhead_PrevCabName (null terminated string)   */
/* cfhead_NextCabFile (null terminated string)   */
/* cfhead_NextCabName (null terminated string)   */

#define cffold_DataOffset        (0x00)
#define cffold_NumBlocks         (0x04)
#define cffold_CompType          (0x06)
#define cffold_SIZEOF            (0x08)
/* cffold_ReservedArea (== FolderReserved bytes) */

#define cffile_UncompressedSize  (0x00)
#define cffile_FolderOffset      (0x04)
#define cffile_FolderIndex       (0x08)
#define cffile_Date              (0x0A)
#define cffile_Time              (0x0C)
#define cffile_Attribs           (0x0E)
#define cffile_SIZEOF            (0x10)
/* cffile_FileName (null terminated string)      */

#define cfdata_CheckSum          (0x00) /* cksum of header/reserved/data */
#define cfdata_CompressedSize    (0x04) /* compressed size of block */
#define cfdata_UncompressedSize  (0x06) /* uncompressed size of block */
#define cfdata_SIZEOF            (0x08)
/* cfdata_ReservedArea (== DataReserved bytes)   */

/* flags and values */

#define cffoldCOMPTYPE_MASK    (0x000f)
#define cffoldCOMPTYPE_NONE    (0x0000)
#define cffoldCOMPTYPE_MSZIP   (0x0001)
#define cffoldCOMPTYPE_QUANTUM (0x0002)
#define cffoldCOMPTYPE_LZX     (0x0003)

#define cfheadPREV_CABINET       (0x0001)
#define cfheadNEXT_CABINET       (0x0002)
#define cfheadRESERVE_PRESENT    (0x0004)

#define cffileCONTINUED_FROM_PREV      (0xFFFD)
#define cffileCONTINUED_TO_NEXT        (0xFFFE)
#define cffileCONTINUED_PREV_AND_NEXT  (0xFFFF)
#define cffileUTFNAME (0x80)

#define CAB_NAMEMAX 512   /* maximum length of a single path/filename */

/* CAB data blocks are <= 32768 bytes in uncompressed form. Uncompressed
 * blocks have zero growth. MSZIP guarantees that it won't grow above
 * uncompressed size by more than 12 bytes. LZX guarantees it won't grow
 * more than 6144 bytes.
 */
#define CAB_BLOCKMAX (32768)
#define CAB_INPUTMAX (CAB_BLOCKMAX+6144)

/* maximum number of split blocks in any one folder */
#define CAB_SPLITMAX (10)

struct CABfolder {
  struct CABfolder *next;

  xadUINT32 offsets[CAB_SPLITMAX];  /* offset of first/split data blocks  */
  xadUINT8 data_res[CAB_SPLITMAX]; /* bytes reserved in block headers    */
  xadUINT32 comp_size;      /* number of compressed bytes in this part    */
  xadUINT16 comp_type;      /* compression format and window size         */
  xadUINT16 num_splits;     /* number of split blocks                     */
  struct xadFileInfo *contfile; /* is this folder continuable?        */
};

struct CABstate {
  struct xadMasterBase *xad; /* XAD library base                      */
  struct xadArchiveInfo *ai; /* archive we're extracting from         */
  struct CABfolder *folders; /* linked list of all folders            */
  struct CABfolder *current; /* current folder we're extracting from  */
  xadUINT32 offset;              /* uncompressed offset within folder     */
  xadUINT8 *outpos;             /* (high level) start of data to use up  */
  xadUINT16 outlen;              /* (high level) amount of data to use up */
  xadUINT8 split;               /* at which split in current folder?     */

  /* to speed up the arrival of an error message for trashed files */
  struct CABfolder *lastfolder;
  xadUINT32 lastoffset;
  xadINT32 lasterror;

  /* the chosen compression type functions */
  xadINT32 (*decompress)(CABSTATE, int, int);
  void (*free)(CABSTATE);

  union {
    struct CABZIPstate zip;
    struct CABQTMstate qtm;
    struct CABLZXstate lzx;
  } arcstate;

  /* the '+2' on inbuf is an LZX hack - see the stuff about bitbuffers
   * in the LZX decruncher for more info.
   */
  xadUINT8 inbuf[CAB_INPUTMAX+2], outbuf[CAB_BLOCKMAX];
};

/*--------------------------------------------------------------------------*/
/* MSZIP decompressor */

/* This part was written by Dirk Stˆcker, based on the InfoZip deflate code */

/* Tables for deflate from PKZIP's appnote.txt. */
static const xadUINT8 CABZipborder[] = /* Order of the bit length code lengths */
{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
static const xadUINT16 CABZipcplens[] = /* Copy lengths for literal codes 257..285 */
{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51,
 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0};
static const xadUINT16 CABZipcplext[] = /* Extra bits for literal codes 257..285 */
{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4,
  4, 5, 5, 5, 5, 0, 99, 99}; /* 99==invalid */
static const xadUINT16 CABZipcpdist[] = /* Copy offsets for distance codes 0..29 */
{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385,
513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
static const xadUINT16 CABZipcpdext[] = /* Extra bits for distance codes */
{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10,
10, 11, 11, 12, 12, 13, 13};

/* And'ing with CABZipmask[n] masks the lower n bits */
static const xadUINT16 CABZipmask[17] = {
 0x0000, 0x0001, 0x0003, 0x0007, 0x000f, 0x001f, 0x003f, 0x007f, 0x00ff,
 0x01ff, 0x03ff, 0x07ff, 0x0fff, 0x1fff, 0x3fff, 0x7fff, 0xffff
};

#define CABZIPNEEDBITS(n) {while(k<(n)){xadINT32 c=*(ZIP(inpos)++);\
    b|=((xadUINT32)c)<<k;k+=8;}}
#define CABZIPDUMPBITS(n) {b>>=(n);k-=(n);}

static xadINT32 CABZiphuft_free(CABSTATE, struct CABZiphuft *t)
{
  struct xadMasterBase *xadMasterBase = CAB(xad);
  register struct CABZiphuft *p, *q;

  /* Go through linked list, freeing from the allocated (t[-1]) address. */
  p = t;
  while (p != (struct CABZiphuft *)NULL)
  {
    q = (--p)->v.t;
    xadFreeObjectA(XADM p, 0);
    p = q;
  }
  return 0;
}

static xadINT32 CABZiphuft_build(CABSTATE, xadUINT32 *b, xadUINT32 n, xadUINT32 s, xadUINT16 *d, xadUINT16 *e, struct CABZiphuft **t, xadINT32 *m)
{
  xadUINT32 a;                          /* counter for codes of length k */
  xadUINT32 el;                         /* length of EOB code (value 256) */
  xadUINT32 f;                          /* i repeats in table every f entries */
  xadINT32 g;                           /* maximum code length */
  xadINT32 h;                           /* table level */
  register xadUINT32 i;                 /* counter, current code */
  register xadUINT32 j;                 /* counter */
  register xadINT32 k;                  /* number of bits in current code */
  xadINT32 *l;                  /* stack of bits per table */
  register xadUINT32 *p;                /* pointer into ZIP(c)[], ZIP(b)[], or ZIP(v)[] */
  register struct CABZiphuft *q;   /* points to current table */
  struct CABZiphuft r;             /* table entry for structure assignment */
  register xadINT32 w;              /* bits before this table == (l * h) */
  xadUINT32 *xp;                        /* pointer into x */
  xadINT32 y;                       /* number of dummy codes added */
  xadUINT32 z;                          /* number of entries in current table */
  struct xadMasterBase *xadMasterBase = CAB(xad);

  l = ZIP(lx)+1;

  /* Generate counts for each bit length */
  el = n > 256 ? b[256] : ZIPBMAX; /* set length of EOB code, if any */

  for(i = 0; i < ZIPBMAX+1; ++i)
    ZIP(c)[i] = 0;
  p = b;  i = n;
  do
  {
    ZIP(c)[*p]++; p++;               /* assume all entries <= ZIPBMAX */
  } while (--i);
  if (ZIP(c)[0] == n)                /* null input--all zero length codes */
  {
    *t = (struct CABZiphuft *)NULL;
    *m = 0;
    return 0;
  }

  /* Find minimum and maximum length, bound *m by those */
  for (j = 1; j <= ZIPBMAX; j++)
    if (ZIP(c)[j])
      break;
  k = j;                        /* minimum code length */
  if ((xadUINT32)*m < j)
    *m = j;
  for (i = ZIPBMAX; i; i--)
    if (ZIP(c)[i])
      break;
  g = i;                        /* maximum code length */
  if ((xadUINT32)*m > i)
    *m = i;

  /* Adjust last length count to fill out codes, if needed */
  for (y = 1 << j; j < i; j++, y <<= 1)
    if ((y -= ZIP(c)[j]) < 0)
      return 2;                 /* bad input: more codes than bits */
  if ((y -= ZIP(c)[i]) < 0)
    return 2;
  ZIP(c)[i] += y;

  /* Generate starting offsets LONGo the value table for each length */
  ZIP(x)[1] = j = 0;
  p = ZIP(c) + 1;  xp = ZIP(x) + 2;
  while (--i)
  {                 /* note that i == g from above */
    *xp++ = (j += *p++);
  }

  /* Make a table of values in order of bit lengths */
  p = b;  i = 0;
  do{
    if ((j = *p++) != 0)
      ZIP(v)[ZIP(x)[j]++] = i;
  } while (++i < n);


  /* Generate the Huffman codes and for each, make the table entries */
  ZIP(x)[0] = i = 0;                 /* first Huffman code is zero */
  p = ZIP(v);                        /* grab values in bit order */
  h = -1;                       /* no tables yet--level -1 */
  w = l[-1] = 0;                /* no bits decoded yet */
  ZIP(u)[0] = (struct CABZiphuft *)NULL;   /* just to keep compilers happy */
  q = (struct CABZiphuft *)NULL;      /* ditto */
  z = 0;                        /* ditto */

  /* go through the bit lengths (k already is bits in shortest code) */
  for (; k <= g; k++)
  {
    a = ZIP(c)[k];
    while (a--)
    {
      /* here i is the Huffman code of length k bits for value *p */
      /* make tables up to required level */
      while (k > w + l[h])
      {
        w += l[h++];            /* add bits already decoded */

        /* compute minimum size table less than or equal to *m bits */
        z = (z = g - w) > (xadUINT32)*m ? (xadUINT32)*m : z;        /* upper limit */
        if ((f = 1 << (j = k - w)) > a + 1)     /* try a k-w bit table */
        {                       /* too few codes for k-w bit table */
          f -= a + 1;           /* deduct codes from patterns left */
          xp = ZIP(c) + k;
          while (++j < z)       /* try smaller tables up to z bits */
          {
            if ((f <<= 1) <= *++xp)
              break;            /* enough codes to use up j bits */
            f -= *xp;           /* else deduct codes from patterns */
          }
        }
        if ((xadUINT32)w + j > el && (xadUINT32)w < el)
          j = el - w;           /* make EOB code end at table */
        z = 1 << j;             /* table entries for j-bit table */
        l[h] = j;               /* set table size in stack */

        /* allocate and link in new table */
        if (!(q = (struct CABZiphuft *) xadAllocVec(XADM (z + 1)*sizeof(struct CABZiphuft), 1)))
        {
          if(h)
            CABZiphuft_free(cabstate, ZIP(u)[0]);
          return 3;             /* not enough memory */
        }
        *t = q + 1;             /* link to list for Ziphuft_free() */
        *(t = &(q->v.t)) = (struct CABZiphuft *)NULL;
        ZIP(u)[h] = ++q;             /* table starts after link */

        /* connect to last table, if there is one */
        if (h)
        {
          ZIP(x)[h] = i;             /* save pattern for backing up */
          r.b = (xadUINT8)l[h-1];    /* bits to dump before this table */
          r.e = (xadUINT8)(16 + j);  /* bits in this table */
          r.v.t = q;            /* pointer to this table */
          j = (i & ((1 << w) - 1)) >> (w - l[h-1]);
          ZIP(u)[h-1][j] = r;        /* connect to last table */
        }
      }

      /* set up table entry in r */
      r.b = (xadUINT8)(k - w);
      if (p >= ZIP(v) + n)
        r.e = 99;               /* out of values--invalid code */
      else if (*p < s)
      {
        r.e = (xadUINT8)(*p < 256 ? 16 : 15);    /* 256 is end-of-block code */
        r.v.n = *p++;           /* simple code is just the value */
      }
      else
      {
        r.e = (xadUINT8)e[*p - s];   /* non-simple--look up in lists */
        r.v.n = d[*p++ - s];
      }

      /* fill code-like entries with r */
      f = 1 << (k - w);
      for (j = i >> w; j < z; j += f)
        q[j] = r;

      /* backwards increment the k-bit code i */
      for (j = 1 << (k - 1); i & j; j >>= 1)
        i ^= j;
      i ^= j;

      /* backup over finished tables */
      while ((i & ((1 << w) - 1)) != ZIP(x)[h])
        w -= l[--h];            /* don't need to update q */
    }
  }

  /* return actual size of base table */
  *m = l[0];

  /* Return true (1) if we were given an incomplete table */
  return y != 0 && g != 1;
}

static xadINT32 CABZipinflate_codes(CABSTATE, struct CABZiphuft *tl, struct CABZiphuft *td, xadINT32 bl, xadINT32 bd)
{
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct CABZiphuft *t; /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;  /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */

  /* make local copies of globals */
  b = ZIP(bb);                       /* initialize bit buffer */
  k = ZIP(bk);
  w = ZIP(window_posn);                       /* initialize window position */

  /* inflate the coded data */
  ml = CABZipmask[bl];                  /* precompute masks for speed */
  md = CABZipmask[bd];

  for(;;)
  {
    CABZIPNEEDBITS((xadUINT32)bl)
    if((e = (t = tl + ((xadUINT32)b & ml))->e) > 16)
      do
      {
        if (e == 99)
          return 1;
        CABZIPDUMPBITS(t->b)
        e -= 16;
        CABZIPNEEDBITS(e)
      } while ((e = (t = t->v.t + ((xadUINT32)b & CABZipmask[e]))->e) > 16);
    CABZIPDUMPBITS(t->b)
    if (e == 16)                /* then it's a literal */
      CAB(outbuf)[w++] = (xadUINT8)t->v.n;
    else                        /* it's an EOB or a length */
    {
      /* exit if end of block */
      if(e == 15)
        break;

      /* get length of block to copy */
      CABZIPNEEDBITS(e)
      n = t->v.n + ((xadUINT32)b & CABZipmask[e]);
      CABZIPDUMPBITS(e);

      /* decode distance of block to copy */
      CABZIPNEEDBITS((xadUINT32)bd)
      if ((e = (t = td + ((xadUINT32)b & md))->e) > 16)
        do {
          if (e == 99)
            return 1;
          CABZIPDUMPBITS(t->b)
          e -= 16;
          CABZIPNEEDBITS(e)
        } while ((e = (t = t->v.t + ((xadUINT32)b & CABZipmask[e]))->e) > 16);
      CABZIPDUMPBITS(t->b)
      CABZIPNEEDBITS(e)
      d = w - t->v.n - ((xadUINT32)b & CABZipmask[e]);
      CABZIPDUMPBITS(e)
      do
      {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        do
        {
          CAB(outbuf)[w++] = CAB(outbuf)[d++];
        } while (--e);
      } while (n);
    }
  }

  /* restore the globals from the locals */
  ZIP(window_posn) = w;                       /* restore global window pointer */
  ZIP(bb) = b;                       /* restore global bit buffer */
  ZIP(bk) = k;

  /* done */
  return 0;
}

static xadINT32 CABZipinflate_stored(CABSTATE) /* "decompress" an inflated type 0 (stored) block. */
{
  xadUINT32 n;           /* number of bytes in block */
  xadUINT32 w;           /* current window position */
  register xadUINT32 b;  /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */

  /* make local copies of globals */
  b = ZIP(bb);                       /* initialize bit buffer */
  k = ZIP(bk);
  w = ZIP(window_posn);                       /* initialize window position */

  /* go to byte boundary */
  n = k & 7;
  CABZIPDUMPBITS(n);

  /* get the length and its complement */
  CABZIPNEEDBITS(16)
  n = ((xadUINT32)b & 0xffff);
  CABZIPDUMPBITS(16)
  CABZIPNEEDBITS(16)
  if (n != (xadUINT32)((~b) & 0xffff))
    return 1;                   /* error in compressed data */
  CABZIPDUMPBITS(16)

  /* read and output the compressed data */
  while(n--)
  {
    CABZIPNEEDBITS(8)
    CAB(outbuf)[w++] = (xadUINT8)b;
    CABZIPDUMPBITS(8)
  }

  /* restore the globals from the locals */
  ZIP(window_posn) = w;                       /* restore global window pointer */
  ZIP(bb) = b;                       /* restore global bit buffer */
  ZIP(bk) = k;
  return 0;
}

static xadINT32 CABZipinflate_fixed(CABSTATE)
{
  struct CABZiphuft *fixed_tl;
  struct CABZiphuft *fixed_td;
  xadINT32 fixed_bl, fixed_bd;
  xadINT32 i;                /* temporary variable */
  xadUINT32 *l;

  l = ZIP(ll);

  /* literal table */
  for(i = 0; i < 144; i++)
    l[i] = 8;
  for(; i < 256; i++)
    l[i] = 9;
  for(; i < 280; i++)
    l[i] = 7;
  for(; i < 288; i++)          /* make a complete, but wrong code set */
    l[i] = 8;
  fixed_bl = 7;
  if((i = CABZiphuft_build(cabstate, l, 288, 257, (xadUINT16 *) CABZipcplens, (xadUINT16 *) CABZipcplext, &fixed_tl, &fixed_bl)))
    return i;

  /* distance table */
  for(i = 0; i < 30; i++)      /* make an incomplete code set */
    l[i] = 5;
  fixed_bd = 5;
  if((i = CABZiphuft_build(cabstate, l, 30, 0, (xadUINT16 *) CABZipcpdist, (xadUINT16 *) CABZipcpdext, &fixed_td, &fixed_bd)) > 1)
  {
    CABZiphuft_free(cabstate, fixed_tl);
    return i;
  }

  /* decompress until an end-of-block code */
  i = CABZipinflate_codes(cabstate, fixed_tl, fixed_td, fixed_bl, fixed_bd);

  CABZiphuft_free(cabstate, fixed_td);
  CABZiphuft_free(cabstate, fixed_tl);
  return i;
}

static xadINT32 CABZipinflate_dynamic(CABSTATE) /* decompress an inflated type 2 (dynamic Huffman codes) block. */
{
  xadINT32 i;           /* temporary variables */
  xadUINT32 j;
  xadUINT32 *ll;
  xadUINT32 l;                  /* last length */
  xadUINT32 m;                  /* mask for bit lengths table */
  xadUINT32 n;                  /* number of lengths to get */
  struct CABZiphuft *tl;      /* literal/length code table */
  struct CABZiphuft *td;      /* distance code table */
  xadINT32 bl;              /* lookup bits for tl */
  xadINT32 bd;              /* lookup bits for td */
  xadUINT32 nb;                 /* number of bit length codes */
  xadUINT32 nl;                 /* number of literal/length codes */
  xadUINT32 nd;                 /* number of distance codes */
  register xadUINT32 b;     /* bit buffer */
  register xadUINT32 k; /* number of bits in bit buffer */

  /* make local bit buffer */
  b = ZIP(bb);
  k = ZIP(bk);
  ll = ZIP(ll);

  /* read in table lengths */
  CABZIPNEEDBITS(5)
  nl = 257 + ((xadUINT32)b & 0x1f);      /* number of literal/length codes */
  CABZIPDUMPBITS(5)
  CABZIPNEEDBITS(5)
  nd = 1 + ((xadUINT32)b & 0x1f);        /* number of distance codes */
  CABZIPDUMPBITS(5)
  CABZIPNEEDBITS(4)
  nb = 4 + ((xadUINT32)b & 0xf);         /* number of bit length codes */
  CABZIPDUMPBITS(4)
  if(nl > 288 || nd > 32)
    return 1;                   /* bad lengths */

  /* read in bit-length-code lengths */
  for(j = 0; j < nb; j++)
  {
    CABZIPNEEDBITS(3)
    ll[CABZipborder[j]] = (xadUINT32)b & 7;
    CABZIPDUMPBITS(3)
  }
  for(; j < 19; j++)
    ll[CABZipborder[j]] = 0;

  /* build decoding table for trees--single level, 7 bit lookup */
  bl = 7;
  if((i = CABZiphuft_build(cabstate, ll, 19, 19, NULL, NULL, &tl, &bl)) != 0)
  {
    if(i == 1)
      CABZiphuft_free(cabstate, tl);
    return i;                   /* incomplete code set */
  }

  /* read in literal and distance code lengths */
  n = nl + nd;
  m = CABZipmask[bl];
  i = l = 0;
  while((xadUINT32)i < n)
  {
    CABZIPNEEDBITS((xadUINT32)bl)
    j = (td = tl + ((xadUINT32)b & m))->b;
    CABZIPDUMPBITS(j)
    j = td->v.n;
    if (j < 16)                 /* length of code in bits (0..15) */
      ll[i++] = l = j;          /* save last length in l */
    else if (j == 16)           /* repeat last length 3 to 6 times */
    {
      CABZIPNEEDBITS(2)
      j = 3 + ((xadUINT32)b & 3);
      CABZIPDUMPBITS(2)
      if((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = l;
    }
    else if (j == 17)           /* 3 to 10 zero length codes */
    {
      CABZIPNEEDBITS(3)
      j = 3 + ((xadUINT32)b & 7);
      CABZIPDUMPBITS(3)
      if ((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = 0;
      l = 0;
    }
    else                        /* j == 18: 11 to 138 zero length codes */
    {
      CABZIPNEEDBITS(7)
      j = 11 + ((xadUINT32)b & 0x7f);
      CABZIPDUMPBITS(7)
      if ((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = 0;
      l = 0;
    }
  }

  /* free decoding table for trees */
  CABZiphuft_free(cabstate, tl);

  /* restore the global bit buffer */
  ZIP(bb) = b;
  ZIP(bk) = k;

  /* build the decoding tables for literal/length and distance codes */
  bl = ZIPLBITS;
  if((i = CABZiphuft_build(cabstate, ll, nl, 257, (xadUINT16 *) CABZipcplens, (xadUINT16 *) CABZipcplext, &tl, &bl)) != 0)
  {
    if(i == 1)
      CABZiphuft_free(cabstate, tl);
    return i;                   /* incomplete code set */
  }
  bd = ZIPDBITS;
  CABZiphuft_build(cabstate, ll + nl, nd, 0, (xadUINT16 *) CABZipcpdist, (xadUINT16 *) CABZipcpdext, &td, &bd);

  /* decompress until an end-of-block code */
  if(CABZipinflate_codes(cabstate, tl, td, bl, bd))
    return 1;

  /* free the decoding tables, return */
  CABZiphuft_free(cabstate, tl);
  CABZiphuft_free(cabstate, td);
  return 0;
}

static xadINT32 CABZipinflate_block(CABSTATE, xadINT32 *e) /* e == last block flag */
{ /* decompress an inflated block */
  xadUINT32 t;                  /* block type */
  register xadUINT32 b;     /* bit buffer */
  register xadUINT32 k;     /* number of bits in bit buffer */

  /* make local bit buffer */
  b = ZIP(bb);
  k = ZIP(bk);

  /* read in last block bit */
  CABZIPNEEDBITS(1)
  *e = (xadINT32)b & 1;
  CABZIPDUMPBITS(1)

  /* read in block type */
  CABZIPNEEDBITS(2)
  t = (xadUINT32)b & 3;
  CABZIPDUMPBITS(2)

  /* restore the global bit buffer */
  ZIP(bb) = b;
  ZIP(bk) = k;

  D(("ZIP: blocktype=%ld, last block=%ld\n", t, *e))

  /* inflate that block type */
  if(t == 2)
    return CABZipinflate_dynamic(cabstate);
  if(t == 0)
    return CABZipinflate_stored(cabstate);
  if(t == 1)
    return CABZipinflate_fixed(cabstate);
  /* bad block type */
  return 2;
}

static xadINT32 CAB_ZIPdecompress(CABSTATE, int inlen, int outlen)
{
  xadINT32 e;               /* last block flag */

  D(("ZIP: outlen %ld\n", outlen))
  ZIP(inpos) = CAB(inbuf);
  ZIP(bb) = ZIP(bk) = ZIP(window_posn) = 0;
  if(outlen > ZIPWSIZE)
    return XADERR_DATAFORMAT;

  /* CK = Chris Kirmse, official Microsoft purloiner */
  if(ZIP(inpos)[0] != 0x43 || ZIP(inpos)[1] != 0x4B)
    return XADERR_ILLEGALDATA;
  ZIP(inpos) += 2;

  do
  {
    if(CABZipinflate_block(cabstate, &e))
      return XADERR_ILLEGALDATA;
  } while(!e);

  /* return success */
  return XADERR_OK;
}

/*--------------------------------------------------------------------------*/
/* Quantum decompressor */

/* This decruncher was researched and implemented by Matthew Russotto. */
/* It has since been tidied up by Stuart Caie */

static xadUINT8 q_length_base[27], q_length_extra[27], q_extra_bits[42];
static xadUINT32 q_position_base[42];

/* Initialise a model which decodes symbols from [s] to [s]+[n]-1 */
static void CAB_QTMinitmodel(struct CABQTMmodel *m,
                             struct CABQTMmodelsym *sym,
                             int n, int s)
{
  int i;
  m->shiftsleft = 4;
  m->entries    = n;
  m->syms       = sym;
  memset(m->tabloc, 0xFF, sizeof(m->tabloc)); /* clear out look-up table */
  for (i = 0; i < n; i++) {
    m->tabloc[i+s]     = i;   /* set up a look-up entry for symbol */
    m->syms[i].sym     = i+s; /* actual symbol */
    m->syms[i].cumfreq = n-i; /* current frequency of that symbol */
  }
  m->syms[n].cumfreq = 0;
}

static xadINT32 CAB_QTMinit(CABSTATE, int window) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  int wndsize = 1 << window, msz = window * 2, i;
  xadUINT32 j;

  /* QTM supports window sizes of 2^10 (1Kb) through 2^21 (2Mb) */
  /* if a previously allocated window is big enough, keep it    */
  if (window < 10 || window > 21) return XADERR_DATAFORMAT;
  if (QTM(actual_size) < (xadUINT32) wndsize) {
    if (QTM(window)) FREE(QTM(window));
    QTM(window) = NULL;
  }
  if (!QTM(window)) {
    /* not using ALLOC() macro because we don't need to clear the window */
    if (!(QTM(window) = xadAllocVec(XADM (xadUINT32) wndsize, 0))) return XADERR_NOMEMORY;
    QTM(actual_size) = wndsize;
  }
  QTM(window_size) = wndsize;
  QTM(window_posn) = 0;

  /* initialise static slot/extrabits tables */
  for (i = 0, j = 0; i < 27; i++) {
    q_length_extra[i] = (i == 26) ? 0 : (i < 2 ? 0 : i - 2) >> 2;
    q_length_base[i] = j; j += 1 << ((i == 26) ? 5 : q_length_extra[i]);
  }
  for (i = 0, j = 0; i < 42; i++) {
    q_extra_bits[i] = (i < 2 ? 0 : i-2) >> 1;
    q_position_base[i] = j; j += 1 << q_extra_bits[i];
  }

  /* initialise arithmetic coding models */

  CAB_QTMinitmodel(&QTM(model7), &QTM(m7sym)[0], 7, 0);

  CAB_QTMinitmodel(&QTM(model00), &QTM(m00sym)[0], 0x40, 0x00);
  CAB_QTMinitmodel(&QTM(model40), &QTM(m40sym)[0], 0x40, 0x40);
  CAB_QTMinitmodel(&QTM(model80), &QTM(m80sym)[0], 0x40, 0x80);
  CAB_QTMinitmodel(&QTM(modelC0), &QTM(mC0sym)[0], 0x40, 0xC0);

  /* model 4 depends on table size, ranges from 20 to 24  */
  CAB_QTMinitmodel(&QTM(model4), &QTM(m4sym)[0], (msz < 24) ? msz : 24, 0);
  /* model 5 depends on table size, ranges from 20 to 36  */
  CAB_QTMinitmodel(&QTM(model5), &QTM(m5sym)[0], (msz < 36) ? msz : 36, 0);
  /* model 6pos depends on table size, ranges from 20 to 42 */
  CAB_QTMinitmodel(&QTM(model6pos), &QTM(m6psym)[0], msz, 0);
  CAB_QTMinitmodel(&QTM(model6len), &QTM(m6lsym)[0], 27, 0);

  return XADERR_OK;
}


static void CAB_QTMupdatemodel(struct CABQTMmodel *model, int sym) {
  struct CABQTMmodelsym temp;
  int i, j;

  for (i = 0; i < sym; i++) model->syms[i].cumfreq += 8;

  if (model->syms[0].cumfreq > 3800) {
    if (--model->shiftsleft) {
      for (i = model->entries - 1; i >= 0; i--) {
        /* -1, not -2; the 0 entry saves this */
        model->syms[i].cumfreq >>= 1;
        if (model->syms[i].cumfreq <= model->syms[i+1].cumfreq) {
          model->syms[i].cumfreq = model->syms[i+1].cumfreq + 1;
        }
      }
    }
    else {
      model->shiftsleft = 50;
      for (i = 0; i < model->entries ; i++) {
        /* no -1, want to include the 0 entry */
        /* this converts cumfreqs into frequencies, then shifts right */
        model->syms[i].cumfreq -= model->syms[i+1].cumfreq;
        model->syms[i].cumfreq++; /* avoid losing things entirely */
        model->syms[i].cumfreq >>= 1;
      }

      /* now sort by frequencies, decreasing order -- this must be an
       * inplace selection sort, or a sort with the same (in)stability
       * characteristics
       */
      for (i = 0; i < model->entries - 1; i++) {
        for (j = i + 1; j < model->entries; j++) {
          if (model->syms[i].cumfreq < model->syms[j].cumfreq) {
            temp = model->syms[i];
            model->syms[i] = model->syms[j];
            model->syms[j] = temp;
          }
        }
      }

      /* then convert frequencies back to cumfreq */
      for (i = model->entries - 1; i >= 0; i--) {
        model->syms[i].cumfreq += model->syms[i+1].cumfreq;
      }
      /* then update the other part of the table */
      for (i = 0; i < model->entries; i++) {
        model->tabloc[model->syms[i].sym] = i;
      }
    }
  }
}

/* Bitstream reading macros (Quantum / normal byte order)
 *
 * Q_INIT_BITSTREAM    should be used first to set up the system
 * Q_READ_BITS(var,n)  takes N bits from the buffer and puts them in var.
 *                     unlike LZX, this can loop several times to get the
 *                     requisite number of bits.
 * Q_FILL_BUFFER       adds more data to the bit buffer, if there is room
 *                     for another 16 bits.
 * Q_PEEK_BITS(n)      extracts (without removing) N bits from the bit
 *                     buffer
 * Q_REMOVE_BITS(n)    removes N bits from the bit buffer
 *
 * These bit access routines work by using the area beyond the MSB and the
 * LSB as a free source of zeroes. This avoids having to mask any bits.
 * So we have to know the bit width of the bitbuffer variable. This is
 * defined as xadUINT32_BITS.
 *
 * xadUINT32_BITS should be at least 16 bits. Unlike LZX's Huffman decoding,
 * Quantum's arithmetic decoding only needs 1 bit at a time, it doesn't
 * need an assured number. Retrieving larger bitstrings can be done with
 * multiple reads and fills of the bitbuffer. The code should work fine
 * for machines where xadUINT32 >= 32 bits.
 *
 * Also note that Quantum reads bytes in normal order; LZX is in
 * little-endian order.
 */

#define Q_INIT_BITSTREAM do { bitsleft = 0; bitbuf = 0; } while (0)

#define Q_FILL_BUFFER do {                                                \
  if (bitsleft <= (xadUINT32_BITS - 16)) {                                \
    bitbuf |= ((inpos[0]<<8)|inpos[1]) << (xadUINT32_BITS-16 - bitsleft); \
    bitsleft += 16; inpos += 2;                                           \
  }                                                                       \
} while (0)

#define Q_PEEK_BITS(n)   (bitbuf >> (xadUINT32_BITS - (n)))
#define Q_REMOVE_BITS(n) ((bitbuf <<= (n)), (bitsleft -= (n)))

#define Q_READ_BITS(v,n) do {                                           \
  (v) = 0;                                                              \
  for (bitsneed = (n); bitsneed; bitsneed -= bitrun) {                  \
    Q_FILL_BUFFER;                                                      \
    bitrun = (bitsneed > bitsleft) ? bitsleft : bitsneed;               \
    (v) = ((v) << bitrun) | Q_PEEK_BITS(bitrun);                        \
    Q_REMOVE_BITS(bitrun);                                              \
  }                                                                     \
} while (0)

#define Q_MENTRIES(model) (QTM(model).entries)
#define Q_MSYM(model,symidx) (QTM(model).syms[(symidx)].sym)
#define Q_MSYMFREQ(model,symidx) (QTM(model).syms[(symidx)].cumfreq)

/* GET_SYMBOL(model, var) fetches the next symbol from the stated model
 * and puts it in var. it may need to read the bitstream to do this.
 */
#define GET_SYMBOL(m, var) do {                                         \
  range =  ((H - L) & 0xFFFF) + 1;                                      \
  symf = ((((C - L + 1) * Q_MSYMFREQ(m,0)) - 1) / range) & 0xFFFF;      \
                                                                        \
  for (i=1; i < Q_MENTRIES(m); i++) {                                   \
    if (Q_MSYMFREQ(m,i) <= symf) break;                                 \
  }                                                                     \
  (var) = Q_MSYM(m,i-1);                                                \
                                                                        \
  range = (H - L) + 1;                                                  \
  H = L + ((Q_MSYMFREQ(m,i-1) * range) / Q_MSYMFREQ(m,0)) - 1;          \
  L = L + ((Q_MSYMFREQ(m,i)   * range) / Q_MSYMFREQ(m,0));              \
  while (1) {                                                           \
    if ((L & 0x8000) != (H & 0x8000)) {                                 \
      if ((L & 0x4000) && !(H & 0x4000)) {                              \
        /* underflow case */                                            \
        C ^= 0x4000; L &= 0x3FFF; H |= 0x4000;                          \
      }                                                                 \
      else break;                                                       \
    }                                                                   \
    L <<= 1; H = (H << 1) | 1;                                          \
    Q_FILL_BUFFER;                                                      \
    C  = (C << 1) | Q_PEEK_BITS(1);                                     \
    Q_REMOVE_BITS(1);                                                   \
  }                                                                     \
                                                                        \
  CAB_QTMupdatemodel(&(QTM(m)), i);                                     \
} while (0)


static xadINT32 CAB_QTMdecompress(CABSTATE, int inlen, int outlen) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  xadUINT8 *inpos  = CAB(inbuf);
  xadUINT8 *window = QTM(window);
  xadUINT8 *runsrc, *rundest;

  xadUINT32 window_posn = QTM(window_posn);
  xadUINT32 window_size = QTM(window_size);

  /* used by bitstream macros */
  register int bitsleft, bitrun, bitsneed;
  register xadUINT32 bitbuf;

  /* used by GET_SYMBOL */
  xadUINT32 range;
  xadUINT16 symf;
  int i;

  int extra, togo = outlen, match_length=0, copy_length;
  xadUINT8 selector, sym;
  xadUINT32 match_offset=0;

  xadUINT16 H = 0xFFFF, L = 0, C;

  /* read initial value of C */
  Q_INIT_BITSTREAM;
  Q_READ_BITS(C, 16);

  /* apply 2^x-1 mask */
  window_posn &= window_size - 1;
  /* runs can't straddle the window wraparound */
  if ((window_posn + togo) > window_size) {
    D(("QTM: straddled run\n"))
    return XADERR_DATAFORMAT;
  }

  while (togo > 0) {
    GET_SYMBOL(model7, selector);
    switch (selector) {
    case 0:
      GET_SYMBOL(model00, sym); window[window_posn++] = sym; togo--;
      break;
    case 1:
      GET_SYMBOL(model40, sym); window[window_posn++] = sym; togo--;
      break;
    case 2:
      GET_SYMBOL(model80, sym); window[window_posn++] = sym; togo--;
      break;
    case 3:
      GET_SYMBOL(modelC0, sym); window[window_posn++] = sym; togo--;
      break;

    case 4:
      /* selector 4 = fixed length of 3 */
      GET_SYMBOL(model4, sym);
      Q_READ_BITS(extra, q_extra_bits[sym]);
      match_offset = q_position_base[sym] + extra + 1;
      match_length = 3;
      break;

    case 5:
      /* selector 5 = fixed length of 4 */
      GET_SYMBOL(model5, sym);
      Q_READ_BITS(extra, q_extra_bits[sym]);
      match_offset = q_position_base[sym] + extra + 1;
      match_length = 4;
      break;

    case 6:
      /* selector 6 = variable length */
      GET_SYMBOL(model6len, sym);
      Q_READ_BITS(extra, q_length_extra[sym]);
      match_length = q_length_base[sym] + extra + 5;
      GET_SYMBOL(model6pos, sym);
      Q_READ_BITS(extra, q_extra_bits[sym]);
      match_offset = q_position_base[sym] + extra + 1;
      break;

    default:
      D(("QTM: Selector is bogus\n"))
      return XADERR_ILLEGALDATA;
    }

    /* if this is a match */
    if (selector >= 4) {
      rundest = window + window_posn;
      togo -= match_length;

      /* copy any wrapped around source data */
      if (window_posn >= match_offset) {
        /* no wrap */
        runsrc = rundest - match_offset;
      } else {
        runsrc = rundest + (window_size - match_offset);
        copy_length = match_offset - window_posn;
        if (copy_length < match_length) {
          match_length -= copy_length;
          window_posn += copy_length;
          while (copy_length-- > 0) *rundest++ = *runsrc++;
          runsrc = window;
        }
      }
      window_posn += match_length;

      /* copy match data - no worries about destination wraps */
      while (match_length-- > 0) *rundest++ = *runsrc++;
    }
  } /* while (togo > 0) */

  if (togo != 0) {
    D(("QTM: Frame overflow, this_run = %ld\n", togo))
    return XADERR_ILLEGALDATA;
  }

  xadCopyMem(XADM window + ((!window_posn) ? window_size : window_posn) -
    outlen, CAB(outbuf), (xadUINT32) outlen);

  QTM(window_posn) = window_posn;
  return XADERR_OK;
}

static void CAB_QTMfree(CABSTATE) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  if (QTM(window)) FREE(QTM(window));
  QTM(window) = NULL;
}

/*--------------------------------------------------------------------------*/
/* LZX decompressor */

/* Microsoft's LZX document and their implementation of the
 * com.ms.util.cab Java package do not concur.
 *
 * Correlation between window size and number of position slots: In the
 * LZX document, 1MB window = 40 slots, 2MB window = 42 slots. In the
 * implementation, 1MB = 42 slots, 2MB = 50 slots. (The actual calculation
 * is 'find the first slot whose position base is equal to or more than the
 * required window size'). This would explain why other tables in the
 * document refer to 50 slots rather than 42.
 *
 * The constant NUM_PRIMARY_LENGTHS used in the decompression pseudocode
 * is not defined in the specification, although it could be derived from
 * the section on encoding match lengths.
 *
 * The LZX document does not state the uncompressed block has an
 * uncompressed length. Where does this length field come from, so we can
 * know how large the block is? The implementation suggests that it's in
 * the 24 bits proceeding the 3 blocktype bits, before the alignment
 * padding.
 *
 * The LZX document states that aligned offset blocks have their aligned
 * offset huffman tree AFTER the main and length tree. The implementation
 * suggests that the aligned offset tree is BEFORE the main and length trees.
 *
 * The LZX document decoding algorithim states that, in an aligned offset
 * block, if an extra_bits value is 1, 2 or 3, then that number of bits
 * should be read and the result added to the match offset. This is correct
 * for 1 and 2, but not 3 bits, where only an aligned symbol should be read.
 *
 * Regarding the E8 preprocessing, the LZX document states 'No
 * translation may be performed on the last 6 bytes of the input
 * block'. This is correct. However, the pseudocode provided checks
 * for the *E8 leader* up to the last 6 bytes. If the leader appears
 * between -10 and -7 bytes from the end, this would cause the next
 * four bytes to be modified, at least one of which would be in the
 * last 6 bytes, which is not allowed according to the spec.
 *
 * The specification states that the huffman trees must always contain
 * at least one element. However, many CAB files contain badly compressed
 * sections where the length tree is completely empty (because there
 * are no matches), and this is expected to succeed.
 */

/* LZX uses what it calls 'position slots' to represent match offsets.
 * What this means is that a small 'position slot' number and a small
 * offset from that slot are encoded instead of one large offset for
 * every match.
 * - position_base is an index to the position slot bases
 * - extra_bits states how many bits of offset-from-base data is needed.
 */
static xadUINT32 position_base[51];
static xadUINT8 extra_bits[51];


static xadINT32 CAB_LZXinit(CABSTATE, int window) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  int wndsize = 1 << window;
  int i, j, posn_slots;

  D(("LZX: init wndsize=%ld\n", window))

  /* LZX supports window sizes of 2^15 (32Kb) through 2^21 (2Mb) */
  /* if a previously allocated window is big enough, keep it     */
  if (window < 15 || window > 21) return XADERR_DATAFORMAT;
  if (LZX(actual_size) < (xadUINT32) wndsize) {
    if (LZX(window)) FREE(LZX(window));
    LZX(window) = NULL;
  }
  if (!LZX(window)) {
    /* not using ALLOC() macro because we don't need to clear the window */
    if (!(LZX(window) = xadAllocVec(XADM (xadUINT32) wndsize, 0))) return XADERR_NOMEMORY;
    LZX(actual_size) = wndsize;
  }
  LZX(window_size) = wndsize;

  /* initialise static tables */
  for (i=0, j=0; i <= 50; i += 2) {
    extra_bits[i] = extra_bits[i+1] = j; /* 0,0,0,0,1,1,2,2,3,3... */
    if ((i != 0) && (j < 17)) j++; /* 0,0,1,2,3,4...15,16,17,17,17,17... */
  }
  for (i=0, j=0; i <= 50; i++) {
    position_base[i] = j; /* 0,1,2,3,4,6,8,12,16,24,32,... */
    j += 1 << extra_bits[i]; /* 1,1,1,1,2,2,4,4,8,8,16,16,32,32,... */
  }

  /* calculate required position slots */
       if (window == 20) posn_slots = 42;
  else if (window == 21) posn_slots = 50;
  else posn_slots = window << 1;

  /*posn_slots=i=0; while (i < wndsize) i += 1 << extra_bits[posn_slots++]; */


  LZX(R0)  =  LZX(R1)  = LZX(R2) = 1;
  LZX(main_elements)   = LZX_NUM_CHARS + (posn_slots << 3);
  LZX(header_read)     = 0;
  LZX(frames_read)     = 0;
  LZX(block_remaining) = 0;
  LZX(block_type)      = LZX_BLOCKTYPE_INVALID;
  LZX(intel_curpos)    = 0;
  LZX(intel_started)   = 0;
  LZX(window_posn)     = 0;

  /* initialise tables to 0 (because deltas will be applied to them) */
  for (i = 0; i < LZX_MAINTREE_MAXSYMBOLS; i++) LZX(MAINTREE_len)[i] = 0;
  for (i = 0; i < LZX_LENGTH_MAXSYMBOLS; i++)   LZX(LENGTH_len)[i]   = 0;

  return XADERR_OK;
}

static void CAB_LZXfree(CABSTATE) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  if (LZX(window)) FREE(LZX(window));
  LZX(window) = NULL;
}



/* Bitstream reading macros:
 *
 * INIT_BITSTREAM    should be used first to set up the system
 * READ_BITS(var,n)  takes N bits from the buffer and puts them in var
 *
 * ENSURE_BITS(n)    ensures there are at least N bits in the bit buffer
 * PEEK_BITS(n)      extracts (without removing) N bits from the bit buffer
 * REMOVE_BITS(n)    removes N bits from the bit buffer
 *
 * These bit access routines work by using the area beyond the MSB and the
 * LSB as a free source of zeroes. This avoids having to mask any bits.
 * So we have to know the bit width of the bitbuffer variable. This is
 * sizeof(xadUINT32) * 8, also defined as xadUINT32_BITS
 *
 * In the case of the final 16 bits of the file, the READ_HUFFSYM
 * macro can make the bit buffer code go 'over the edge' and read the
 * next two bytes from the input buffer, because it uses
 * ENSURE_BITS(17) even if it doesn't need all 17 bits. The input
 * buffer is increased by two bytes to take account of this.
 */

#define INIT_BITSTREAM do { bitsleft = 0; bitbuf = 0; } while (0)

#define ENSURE_BITS(n)                                                  \
  while (bitsleft < (n)) {                                              \
    bitbuf |= ((inpos[1]<<8)|inpos[0]) << (xadUINT32_BITS-16 - bitsleft);       \
    bitsleft += 16; inpos+=2;                                           \
  }

#define PEEK_BITS(n)   (bitbuf >> (xadUINT32_BITS - (n)))
#define REMOVE_BITS(n) ((bitbuf <<= (n)), (bitsleft -= (n)))

#define READ_BITS(v,n) do {                                             \
  ENSURE_BITS(n);                                                       \
  (v) = PEEK_BITS(n);                                                   \
  REMOVE_BITS(n);                                                       \
  /*D(("LZX: getbits(%ld)=%ld\n",n,(v)))*/                                      \
} while (0)


/* Huffman macros */

#define TABLEBITS(tbl)   (LZX_##tbl##_TABLEBITS)
#define MAXSYMBOLS(tbl)  (LZX_##tbl##_MAXSYMBOLS)
#define SYMTABLE(tbl)    (LZX(tbl##_table))
#define LENTABLE(tbl)    (LZX(tbl##_len))

/* BUILD_TABLE(tablename) builds a huffman lookup table from code lengths.
 * In reality, it just calls make_decode_table() with the appropriate
 * values - they're all fixed by some #defines anyway, so there's no point
 * writing each call out in full by hand.
 */
#define BUILD_TABLE(tbl)                                                \
  if (make_decode_table(                                                \
    MAXSYMBOLS(tbl), TABLEBITS(tbl), LENTABLE(tbl), SYMTABLE(tbl)       \
  )) { D(("LZX: table failure\n")) return XADERR_ILLEGALDATA; }


/* READ_HUFFSYM(tablename, var) decodes one huffman symbol from the
 * bitstream using the stated table and puts it in var.
 */
#define READ_HUFFSYM(tbl,var) do {                                      \
  ENSURE_BITS(16);                                                      \
  hufftbl = SYMTABLE(tbl);                                              \
  if ((i = hufftbl[PEEK_BITS(TABLEBITS(tbl))]) >= MAXSYMBOLS(tbl)) {    \
    j = 1 << (xadUINT32_BITS - TABLEBITS(tbl));                         \
    do {                                                                \
      j >>= 1; i <<= 1; i |= (bitbuf & j) ? 1 : 0;                      \
      if (!j) return XADERR_ILLEGALDATA;                                \
    } while ((i = hufftbl[i]) >= MAXSYMBOLS(tbl));                      \
  }                                                                     \
  j = LENTABLE(tbl)[(var) = i];                                         \
  REMOVE_BITS(j);                                                       \
} while (0)


/* READ_LENGTHS(tablename, first, last) reads in code lengths for symbols
 * first to last in the given table. The code lengths are stored in their
 * own special LZX way. Note that we pass in an lzx_bits structure to
 * get the bitstream state between the function and the caller - this has
 * to be initialised before using READ_LENGTHS, and retrieved again before
 * the bit macros are next used.
 */
#define READ_LENGTHS(tbl,first,last) \
  if (lzx_read_lens(cabstate, LENTABLE(tbl), (first), (last), &lb)) \
    return XADERR_ILLEGALDATA;

struct lzx_bits {
  xadUINT32 bb;
  int bl;
  xadUINT8 *ip;
};


/* make_decode_table(nsyms, nbits, length[], table[])
 *
 * This function was coded by David Tritscher. It builds a fast huffman
 * decoding table out of just a canonical huffman code lengths table.
 *
 * nsyms  = total number of symbols in this huffman tree.
 * nbits  = any symbols with a code length of nbits or less can be decoded
 *          in one lookup of the table.
 * length = A table to get code lengths from [0 to syms-1]
 * table  = The table to fill up with decoded symbols and pointers.
 *
 * Returns 0 for OK or 1 for error
 */
static int make_decode_table(int nsyms,int nbits,xadUINT8 *length,xadUINT16 *table) {
  register xadUINT16 sym;
  register xadUINT32 leaf;
  register xadUINT8 bit_num = 1;
  xadUINT32 fill;
  xadUINT32 pos         = 0; /* the current position in the decode table */
  xadUINT32 table_mask  = 1 << nbits;
  xadUINT32 bit_mask    = table_mask >> 1; /* don't do 0 length codes */
  xadUINT32 next_symbol = bit_mask; /* base of allocation for long codes */

  /* fill entries for codes short enough for a direct mapping */
  while (bit_num <= nbits) {
    for (sym = 0; sym < nsyms; sym++) {
      if (length[sym] == bit_num) {
        leaf = pos;

        if((pos += bit_mask) > table_mask) return 1; /* table overrun */

        /* fill all possible lookups of this symbol with the symbol itself */
        fill = bit_mask;
        while (fill-- > 0) table[leaf++] = sym;
      }
    }
    bit_mask >>= 1;
    bit_num++;
  }

  /* if there are any codes longer than nbits */
  if (pos != table_mask) {
    /* clear the remainder of the table */
    for (sym = pos; sym < table_mask; sym++) table[sym] = 0;

    /* give ourselves room for codes to grow by up to 16 more bits */
    pos <<= 16;
    table_mask <<= 16;
    bit_mask = 1 << 15;

    while (bit_num <= 16) {
      for (sym = 0; sym < nsyms; sym++) {
        if (length[sym] == bit_num) {
          leaf = pos >> 16;
          for (fill = 0; fill < (xadUINT32) bit_num - nbits; fill++) {
            /* if this path hasn't been taken yet, 'allocate' two entries */
            if (table[leaf] == 0) {
              table[(next_symbol << 1)] = 0;
              table[(next_symbol << 1) + 1] = 0;
              table[leaf] = next_symbol++;
            }
            /* follow the path and select either left or right for next bit */
            leaf = table[leaf] << 1;
            if ((pos >> (15-fill)) & 1) leaf++;
          }
          table[leaf] = sym;

          if ((pos += bit_mask) > table_mask) return 1; /* table overflow */
        }
      }
      bit_mask >>= 1;
      bit_num++;
    }
  }

  /* full table? */
  if (pos == table_mask) return 0;

  /* either erroneous table, or all elements are 0 - let's find out. */
  for (sym = 0; sym < nsyms; sym++) if (length[sym]) return 1;
  return 0;
}


static int lzx_read_lens(CABSTATE,xadUINT8 *lens,int f,int l,struct lzx_bits *b) {
  xadUINT32 i,j, x,y;
  int z;

  register xadUINT32 bitbuf = b->bb;
  register int bitsleft = b->bl;
  xadUINT8 *inpos = b->ip;
  xadUINT16 *hufftbl;

  for (x = 0; x < 20; x++) {
    READ_BITS(y, 4);
    LENTABLE(PRETREE)[x] = y;
  }
  BUILD_TABLE(PRETREE);

  for (x = f; x < (xadUINT32) l; ) {
    READ_HUFFSYM(PRETREE, z);

    if (z == 17) {
      READ_BITS(y, 4); y += 4;
      while (y--) lens[x++] = 0;
    }
    else if (z == 18) {
      READ_BITS(y, 5); y += 20;
      while (y--) lens[x++] = 0;
    }
    else if (z == 19) {
      READ_BITS(y, 1); y += 4;
      READ_HUFFSYM(PRETREE, z);
      z = lens[x] - z; if (z < 0) z += 17;
      while (y--) lens[x++] = z;
    }
    else {
      z = lens[x] - z; if (z < 0) z += 17;
      lens[x++] = z;
    }
  }

  b->bb = bitbuf;
  b->bl = bitsleft;
  b->ip = inpos;

  /*for (x = f; x < l; x++) D(("LZX: length[%ld]=%ld\n", x, lens[x]))*/

  return 0;
}


static xadINT32 CAB_LZXdecompress(CABSTATE, int inlen, int outlen) {
  struct xadMasterBase *xadMasterBase = CAB(xad);
  xadUINT8 *inpos  = CAB(inbuf);
  xadUINT8 *endinp = inpos + inlen;
  xadUINT8 *window = LZX(window);
  xadUINT8 *runsrc, *rundest;
  xadUINT16 *hufftbl; /* used in READ_HUFFSYM macro as chosen decoding table */

  xadUINT32 window_posn = LZX(window_posn);
  xadUINT32 window_size = LZX(window_size);
  xadUINT32 R0 = LZX(R0);
  xadUINT32 R1 = LZX(R1);
  xadUINT32 R2 = LZX(R2);

  register xadUINT32 bitbuf;
  register int bitsleft;
  xadUINT32 match_offset, i,j,k; /* ijk used in READ_HUFFSYM macro */
  struct lzx_bits lb; /* used in READ_LENGTHS macro */

  int togo = outlen, this_run, main_element, aligned_bits;
  int match_length, copy_length, length_footer, extra, verbatim_bits;

  INIT_BITSTREAM;

  /* read header if necessary */
  if (!LZX(header_read)) {
    i = j = 0;
    READ_BITS(k, 1); if (k) { READ_BITS(i,16); READ_BITS(j,16); }
    LZX(intel_filesize) = (i << 16) | j; /* or 0 if not encoded */
    LZX(header_read) = 1;
  }

  /* main decoding loop */
  while (togo > 0) {
    D(("LZX: top of loop, %ld togo\n", togo))

    /* last block finished, new block expected */
    if (LZX(block_remaining) == 0) {
      if (LZX(block_type) == LZX_BLOCKTYPE_UNCOMPRESSED) {
        if (LZX(block_length) & 1) inpos++; /* realign bitstream to word */
        INIT_BITSTREAM;
        D(("LZX: aligning after previous uncompressed block\n"))
      }

      READ_BITS(LZX(block_type), 3);
      READ_BITS(i, 16);
      READ_BITS(j, 8);
      LZX(block_remaining) = LZX(block_length) = (i << 8) | j;

      D(("LZX: new %ld block len=%ld\n", LZX(block_type), LZX(block_length)))

      switch (LZX(block_type)) {
      case LZX_BLOCKTYPE_ALIGNED:
        for (i = 0; i < 8; i++) { READ_BITS(j, 3); LENTABLE(ALIGNED)[i] = j; }
        BUILD_TABLE(ALIGNED);
        /* rest of aligned header is same as verbatim */

      case LZX_BLOCKTYPE_VERBATIM:
        /* set up a pass-in structure with bitstream state for READ_LENGTHS */
        lb.bb = bitbuf; lb.bl = bitsleft; lb.ip = inpos;

        READ_LENGTHS(MAINTREE, 0, 256);
        READ_LENGTHS(MAINTREE, 256, LZX(main_elements));
        BUILD_TABLE(MAINTREE);
        if (LENTABLE(MAINTREE)[0xE8] != 0) LZX(intel_started) = 1;

        READ_LENGTHS(LENGTH, 0, LZX_NUM_SECONDARY_LENGTHS);
        BUILD_TABLE(LENGTH);

        /* retrieve the bitstream state from the readlens structure */
        bitbuf = lb.bb; bitsleft = lb.bl; inpos = lb.ip;

        break;

      case LZX_BLOCKTYPE_UNCOMPRESSED:
        LZX(intel_started) = 1; /* because we can't assume otherwise */
        ENSURE_BITS(16); /* get up to 16 pad bits into the buffer */
        if (bitsleft > 16) inpos -= 2; /* and align the bitstream! */
        R0 = inpos[0]|(inpos[1]<<8)|(inpos[2]<<16)|(inpos[3]<<24); inpos+=4;
        R1 = inpos[0]|(inpos[1]<<8)|(inpos[2]<<16)|(inpos[3]<<24); inpos+=4;
        R2 = inpos[0]|(inpos[1]<<8)|(inpos[2]<<16)|(inpos[3]<<24); inpos+=4;
        D(("LZX: uncomp header; Rx=%ld/%ld/%ld\n",LZX(R0),LZX(R1),LZX(R2)))
        break;

      default:
        return XADERR_ILLEGALDATA;
      }
      D(("LZX: block header read OK\n"))
    }

    /* buffer exhaustion check */
    if (inpos > endinp) {
      /* it's possible to have a file where the next run is less than
       * 16 bits in size. In this case, the READ_HUFFSYM() macro used
       * in building the tables will exhaust the buffer, so we should
       * allow for this, but not allow those accidentally read bits to
       * be used (so we check that there are at least 16 bits
       * remaining - in this boundary case they aren't really part of
       * the compressed data)
       */
      if (inpos > (endinp+2) || bitsleft < 16) return XADERR_ILLEGALDATA;
    }

    while ((this_run = LZX(block_remaining)) > 0 && togo > 0) {
      D(("LZX: block remaining = %ld, togo = %ld\n", this_run, togo))
      if (this_run > togo) this_run = togo;
      togo -= this_run;
      LZX(block_remaining) -= this_run;

      /* apply 2^x-1 mask */
      window_posn &= window_size - 1;
      /* runs can't straddle the window wraparound */
      if ((window_posn + this_run) > window_size)
        return XADERR_DATAFORMAT;

      switch (LZX(block_type)) {

      case LZX_BLOCKTYPE_VERBATIM:
        while (this_run > 0) {
          READ_HUFFSYM(MAINTREE, main_element);
          /*D(("LZX: %ld\n",main_element))*/
          if (main_element < LZX_NUM_CHARS) {
            /* literal: 0 to LZX_NUM_CHARS-1 */
            window[window_posn++] = main_element;
            this_run--;
          }
          else {
            /* match: LZX_NUM_CHARS + ((slot<<3) | length_header (3 bits)) */
            main_element -= LZX_NUM_CHARS;

            match_length = main_element & LZX_NUM_PRIMARY_LENGTHS;
            if (match_length == LZX_NUM_PRIMARY_LENGTHS) {
              READ_HUFFSYM(LENGTH, length_footer);
              match_length += length_footer;
            }
            match_length += LZX_MIN_MATCH;

            match_offset = main_element >> 3;

            if (match_offset > 2) {
              /* not repeated offset */
              if (match_offset != 3) {
                extra = extra_bits[match_offset];
                READ_BITS(verbatim_bits, extra);
                match_offset = position_base[match_offset] - 2 + verbatim_bits;
              }
              else {
                match_offset = 1;
              }

              /* update repeated offset LRU queue */
              R2 = R1; R1 = R0; R0 = match_offset;
            }
            else if (match_offset == 0) {
              match_offset = R0;
            }
            else if (match_offset == 1) {
              match_offset = R1;
              R1 = R0; R0 = match_offset;
            }
            else /* match_offset == 2 */ {
              match_offset = R2;
              R2 = R0; R0 = match_offset;
            }

            /*D(("LZX: %ld,%ld\n",match_length,match_offset))*/
            rundest = window + window_posn;
            this_run -= match_length;

            /* copy any wrapped around source data */
            if (window_posn >= match_offset) {
              /* no wrap */
              runsrc = rundest - match_offset;
            } else {
              runsrc = rundest + (window_size - match_offset);
              copy_length = match_offset - window_posn;
              if (copy_length < match_length) {
                match_length -= copy_length;
                window_posn += copy_length;
                while (copy_length-- > 0) *rundest++ = *runsrc++;
                runsrc = window;
              }
            }
            window_posn += match_length;

            /* copy match data - no worries about destination wraps */
            while (match_length-- > 0) *rundest++ = *runsrc++;
          }
        }
        break;

      case LZX_BLOCKTYPE_ALIGNED:
        while (this_run > 0) {
          READ_HUFFSYM(MAINTREE, main_element);
          /*D(("LZX: %ld\n",main_element))*/

          if (main_element < LZX_NUM_CHARS) {
            /* literal: 0 to LZX_NUM_CHARS-1 */
            window[window_posn++] = main_element;
            this_run--;
          }
          else {
            /* match: LZX_NUM_CHARS + ((slot<<3) | length_header (3 bits)) */
            main_element -= LZX_NUM_CHARS;

            match_length = main_element & LZX_NUM_PRIMARY_LENGTHS;
            if (match_length == LZX_NUM_PRIMARY_LENGTHS) {
              READ_HUFFSYM(LENGTH, length_footer);
              match_length += length_footer;
            }
            match_length += LZX_MIN_MATCH;

            match_offset = main_element >> 3;

            if (match_offset > 2) {
              /* not repeated offset */
              extra = extra_bits[match_offset];
              match_offset = position_base[match_offset] - 2;
              if (extra > 3) {
                /* verbatim and aligned bits */
                extra -= 3;
                READ_BITS(verbatim_bits, extra);
                match_offset += (verbatim_bits << 3);
                READ_HUFFSYM(ALIGNED, aligned_bits);
                match_offset += aligned_bits;
              }
              else if (extra == 3) {
                /* aligned bits only */
                READ_HUFFSYM(ALIGNED, aligned_bits);
                match_offset += aligned_bits;
              }
              else if (extra > 0) { /* extra==1, extra==2 */
                /* verbatim bits only */
                READ_BITS(verbatim_bits, extra);
                match_offset += verbatim_bits;
              }
              else /* extra == 0 */ {
                /* ??? */
                match_offset = 1;
              }

              /* update repeated offset LRU queue */
              R2 = R1; R1 = R0; R0 = match_offset;
            }
            else if (match_offset == 0) {
              match_offset = R0;
            }
            else if (match_offset == 1) {
              match_offset = R1;
              R1 = R0; R0 = match_offset;
            }
            else /* match_offset == 2 */ {
              match_offset = R2;
              R2 = R0; R0 = match_offset;
            }

            /*D(("LZX: %ld,%ld\n",match_length,match_offset))*/
            rundest = window + window_posn;
            this_run -= match_length;

            /* copy any wrapped around source data */
            if (window_posn >= match_offset) {
              /* no wrap */
              runsrc = rundest - match_offset;
            } else {
              runsrc = rundest + (window_size - match_offset);
              copy_length = match_offset - window_posn;
              if (copy_length < match_length) {
                match_length -= copy_length;
                window_posn += copy_length;
                while (copy_length-- > 0) *rundest++ = *runsrc++;
                runsrc = window;
              }
            }
            window_posn += match_length;

            /* copy match data - no worries about destination wraps */
            while (match_length-- > 0) *rundest++ = *runsrc++;
          }
        }
        break;

      case LZX_BLOCKTYPE_UNCOMPRESSED:
        if ((inpos + this_run) > endinp) return XADERR_ILLEGALDATA;
        xadCopyMem(XADM inpos, window + window_posn, (xadUINT32) this_run);
        inpos += this_run; window_posn += this_run;
        break;

      default:
        return XADERR_ILLEGALDATA; /* might as well */
      }

    }
  }

  if (togo != 0) return XADERR_ILLEGALDATA;
  xadCopyMem(XADM window + ((window_posn == 0) ? window_size : window_posn) -
    outlen, CAB(outbuf), (xadUINT32) outlen);

  LZX(window_posn) = window_posn;
  LZX(R0) = R0;
  LZX(R1) = R1;
  LZX(R2) = R2;

  /* intel decoding */
  if ((LZX(frames_read)++ < 32768) && LZX(intel_filesize) != 0) {
    if (outlen <= 6 || !LZX(intel_started)) {
      LZX(intel_curpos) += outlen;
    }
    else {
      xadUINT8 *data    = CAB(outbuf);
      xadUINT8 *dataend = data + outlen - 10;
      xadINT32 curpos    = LZX(intel_curpos);
      xadINT32 filesize  = LZX(intel_filesize);
      xadINT32 abs_off, rel_off;

      LZX(intel_curpos) = curpos + outlen;

      while (data < dataend) {
        if (*data++ != 0xE8) { curpos++; continue; }
        abs_off = data[0] | (data[1]<<8) | (data[2]<<16) | (data[3]<<24);
        if ((abs_off >= -curpos) && (abs_off < filesize)) {
          rel_off = (abs_off >= 0) ? abs_off - curpos : abs_off + filesize;
          data[0] = (xadUINT8) rel_off;
          data[1] = (xadUINT8) (rel_off >> 8);
          data[2] = (xadUINT8) (rel_off >> 16);
          data[3] = (xadUINT8) (rel_off >> 24);
          /*D(("LZX: E8 abs=%08lx rel=%08lx\n",abs_off,rel_off))*/
        }
        data += 4;
        curpos += 5;
      }
    }
  }
  return XADERR_OK;
}


/*--------------------------------------------------------------------------*/
/* CAB RecogData/GetInfo code */

static const xadSTRPTR CAB_typenames[] = {
  "stored", "MSZIP", "Quantum", "LZX"
};

XADRECOGDATA(CAB) {
  return (xadBOOL) ((data[0]=='M' && data[1]=='S' && data[2]=='C' && data[3]=='F') ? 1 : 0);
}

XADGETINFO(CAB) {
  xadUINT8 buf[cfhead_SIZEOF];   /* buffer for reading in structures  */
  xadUINT8 namebuf[CAB_NAMEMAX]; /* buffer for file paths             */
  xadUINT8 *namep;               /* for loops on namebuf              */

  xadUINT32 base_offset;  /* the file offset of the start of this cabinet        */
  xadUINT32 files_offset; /* the file offset of the first CFFILE in this cabinet */
  xadUINT32 end_offset;   /* the file offset of the end of this cabinet          */

  xadUINT16 num_folders;  /* the number of CFFOLDERs in this cabinet */
  xadUINT16 num_files;    /* the number of CFFILEs in this cabinet   */

  xadUINT16 header_res;   /* the empty space reserved in the CFHEADER */
  xadUINT8 folder_res;    /* the empty space reserved in each CFFOLDER */
  xadUINT8 data_res;      /* the empty space reserved in CFDATA */

  int i, x, curfile=1, curvol=-1, mergeok;

  struct CABfolder *firstfol;       /* first folder in this cabinet */
  struct CABfolder *lastfol = NULL; /* last folder in this cabinet */
  struct CABfolder *predfol;        /* last folder in previous cabinet */

  struct CABfolder *linkfol = NULL, *fol; /* folder addition loop */
  struct xadFileInfo *fi;

  xadINT32 err = XADERR_OK;

  struct TagItem nametags[] = {
    { XAD_CHARACTERSET, 0 },
    { XAD_STRINGSIZE, 0 },
    { XAD_CSTRING, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem prottags[] = {
    { XAD_PROTMSDOS, 0 },
    { XAD_GETPROTAMIGA, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATEMSDOS, 0 },
    { XAD_GETDATEXADDATE, 0 },
    { TAG_DONE, 0 }
  };

  /* attach state information to archive */
  ALLOC(xadPTR, ai->xai_PrivateClient, sizeof(struct CABstate));

  while (1) {
    /* the below if statement is the natural exit point of this loop */
    if (ai->xai_MultiVolume) {
      xadUINT32 pos = ai->xai_InPos, next = ai->xai_MultiVolume[++curvol];
      D(("CAB: top wanted=%ld actual=%ld\n",next,pos))
      /* files end when the 'next file' offset is 0 - except, of course
       * for the very first iteration of this loop, because the first
       * file's offset is also 0
       */
      if (!next && curvol) goto exit_handler; /* end of files */
      if (pos < next) SKIP(next - pos);       /* skip to next file */
      if (pos > next) ERROR(ILLEGALDATA);     /* overrun error */
    }
    else {
      /* singlefile exit point - we shouldn't do more than one loop. */
      if (++curvol) goto exit_handler;
    }

    base_offset = ai->xai_InPos;

    /* ------------- PROCESS CFHEADER -------------- */

    READ(&buf, cfhead_SIZEOF);
    files_offset = GETLONG(cfhead_FileOffset)  + base_offset;
    end_offset   = GETLONG(cfhead_CabinetSize) + base_offset;

    if ((buf[0]!='M' || buf[1]!='S' || buf[2]!='C' || buf[3]!='F')
    || ((num_folders = GETWORD(cfhead_NumFolders)) == 0)
    || ((num_files   = GETWORD(cfhead_NumFiles))   == 0))
      ERROR(ILLEGALDATA);

    if (GETBYTE(cfhead_MajorVersion) > 1
    ||  GETBYTE(cfhead_MinorVersion) > 3) ERROR(DATAFORMAT);

    /* read 'reserve' part of header if present and skip reserved header */
    if ((x = GETWORD(cfhead_Flags)) & cfheadRESERVE_PRESENT) {
      READ(&buf, cfheadext_SIZEOF);
      header_res = GETWORD(cfheadext_HeaderReserved);
      folder_res = GETBYTE(cfheadext_FolderReserved);
      data_res   = GETBYTE(cfheadext_DataReserved);

      SKIP(header_res);
      if (header_res > 60000) TAINT("header reserved > 60000");
    }
    else {
      folder_res = data_res = 0;
    }

    /* skip next and previous cabinet filenames/disknames if present */
    i = ((x & cfheadPREV_CABINET) ? 2:0) + ((x & cfheadNEXT_CABINET) ? 2:0);
    while (i--) {
      int len = 0;
      do { READ(&buf, 1); len++; } while (*buf);
      if (len > 256) TAINT("nameskip > 256");
    }


    /* ------------- PROCESS CFFOLDERs ------------- */

    firstfol = NULL;
    predfol = lastfol;

    for (i = 0; i < num_folders; i++) {
      READ(&buf, cffold_SIZEOF);

      D(("CAB: folder offset=%ld comptype=0x%lx\n",
        GETLONG(cffold_DataOffset)+base_offset, GETWORD(cffold_CompType)
      ))

      SKIP(folder_res);

      ALLOC(struct CABfolder *, fol, sizeof(struct CABfolder));
      fol->offsets[0]  = GETLONG(cffold_DataOffset) + base_offset;
      fol->comp_type   = GETWORD(cffold_CompType);
      fol->data_res[0] = data_res;
      fol->num_splits  = 0;

      if (!firstfol) firstfol = fol;
      lastfol = fol;

      /* link folder into folders list */
      if (linkfol) linkfol->next=fol;
      else ((struct CABstate *) ai->xai_PrivateClient)->folders = fol;
      linkfol = fol;
    }

    /* firstfol = first folder in this cabinet */
    /* lastfol  = last folder in this cabinet */
    /* predfol  = last folder in previous cabinet (or NULL if first cabinet) */

    /* assume that this cabinet's split files are OK to merge */
    mergeok = 1;

    /* ------------- PROCESS CFFILEs ------------- */
    if (ai->xai_InPos != files_offset) TAINT("not at file offset");

    for (i = 0; i < num_files; i++) {
      READ(&buf, cffile_SIZEOF);

      /* read filename */
      namep = namebuf;
      do {
        if ((namep - namebuf) > CAB_NAMEMAX) ERROR(NOMEMORY);
        READ(namep, 1);
      } while (*namep++);

      D(("CAB: file size=%ld offset=%ld index=0x%lx name=´%sª\n",
        GETLONG(cffile_UncompressedSize), GETLONG(cffile_FolderOffset),
        GETWORD(cffile_FolderIndex), namebuf
      ))

      /* file information entry */
      fi = (struct xadFileInfo *) xadAllocObjectA(XADM XADOBJ_FILEINFO, NULL);
      if (!fi) ERROR(NOMEMORY);

      fi->xfi_EntryNumber = curfile++;
      fi->xfi_Size        = GETLONG(cffile_UncompressedSize);
      fi->xfi_DataPos     = GETLONG(cffile_FolderOffset);

      /* convert filename */
      nametags[0].ti_Data = (GETWORD(cffile_Attribs) & cffileUTFNAME)
                          ? CHARSET_UNICODE_UTF8 : CHARSET_WINDOWS;
      nametags[1].ti_Data = (xadSize) (namep - namebuf);
      nametags[2].ti_Data = (xadSize)(uintptr_t) namebuf;
      fi->xfi_FileName = xadConvertNameA(XADM CHARSET_HOST, nametags);
      if (!fi->xfi_FileName) ERROR(NOMEMORY);

      prottags[0].ti_Data = GETWORD(cffile_Attribs);
      prottags[1].ti_Data = (xadSize)(uintptr_t) &fi->xfi_Protection;
      xadConvertProtectionA(XADM prottags);

      datetags[0].ti_Data = (GETWORD(cffile_Date)<<16)|GETWORD(cffile_Time);
      datetags[1].ti_Data = (xadSize)(uintptr_t) &fi->xfi_Date;
      xadConvertDatesA(XADM datetags);

      /* which folder is this file in? */
      x = GETWORD(cffile_FolderIndex);
      if (x < num_folders) {
        for (fol = firstfol; x--; fol=fol->next);
        fi->xfi_PrivateInfo = (xadPTR) fol;
      }
      else {
        if (ai->xai_MultiVolume) {
          /* FOLDER MERGING */

          if (x == cffileCONTINUED_TO_NEXT
          || x == cffileCONTINUED_PREV_AND_NEXT) {
            D(("CAB: file merge next\n"))
            /* this file is in the next cabinet, so we don't set its folder
             * as it will be repeated with the 'prev' folder in the next
             * cabinet. also, if this file is continued prev and next, it
             * can only be a single file extending a single folder beyond
             * the cabinet size limits, the next file _has_ to start in a
             * new folder. we can test that.
             */
            if (x == cffileCONTINUED_PREV_AND_NEXT) {
              if (num_folders != 1 || num_files != 1) TAINT("prev/next");
            }

            if (!lastfol->contfile) lastfol->contfile = fi;
          }

          if (x == cffileCONTINUED_FROM_PREV
          || x == cffileCONTINUED_PREV_AND_NEXT) {
            D(("CAB: file merge prev\n"))

            /* if these files are to be continued in yet _another_ cabinet,
             * don't merge them in just yet
             */
            if (x == cffileCONTINUED_PREV_AND_NEXT) mergeok = 0;

            /* only merge once per cabinet */
            if (predfol) {
              struct xadFileInfo *cfi;

            /* in this case, the file states that folder 0 of this cabinet
               * is actually part of the last folder in the previous cabinet.
               * if this is true, the first 'continued' file of the last
               * folder will match the first file of this folder. Also,
               * both folders will have the same compression type.
               */
              if ((cfi = predfol->contfile)
              && (cfi->xfi_DataPos == fi->xfi_DataPos)
              && (cfi->xfi_Size == fi->xfi_Size)
              && (strcmp(cfi->xfi_FileName, fi->xfi_FileName) == 0)
              && (predfol->comp_type == firstfol->comp_type)) {

                /* free the fileinfo kept for testing if last occurance */
                if (x == cffileCONTINUED_FROM_PREV) {
                  FREE(predfol->contfile);
                  predfol->contfile = NULL;
                }

                /* increase the number of splits */
                if ((x = ++(predfol->num_splits)) > CAB_SPLITMAX)
                  ERROR(DATAFORMAT);

                /* copy information across from the merged folder */
                predfol->offsets[x]  = firstfol->offsets[0];
                predfol->data_res[x] = firstfol->data_res[0];
                predfol->next        = firstfol->next;
                predfol->contfile    = firstfol->contfile;

                if (firstfol == lastfol) lastfol = linkfol = predfol;

                FREE(firstfol);
                firstfol = predfol;
                predfol = NULL; /* don't merge again within this cabinet */

              }
              else {
                /* if the merged folders are incompatible, certainly
                 * don't list the files in them
                 */
                mergeok = 0;
              }
            }

            /* only add split files at their final appearance
             * and only if merging was actually possible
             */
            if (mergeok) fi->xfi_PrivateInfo = (xadPTR) firstfol;
          }
        }
        else {
          /* not multivolume - can't do a folder merge, therefore it either
           * IS a merge but there's no next/prev cabinet (missing data),
           * or it's an out of range folder index (corrupt data)
           */
          TAINT("folder index");
        }
      }

      /* if there's no folder, skip this file */
      if (!fi->xfi_PrivateInfo) {
        /* but only free it if never used again */
        if (fi != lastfol->contfile) FREE(fi);
        continue;
      }
      else {
        /* use compression mode of this file's folder as entryinfo name */
        xadUINT16 ct = CABFILEFOL(fi)->comp_type & cffoldCOMPTYPE_MASK;
        if (ct <= cffoldCOMPTYPE_LZX) fi->xfi_EntryInfo = CAB_typenames[ct];
      }

      /* link file into file list */
      if ((err = xadAddFileEntryA(XADM fi, ai, NULL))) goto exit_handler;
    }


    /* Skip looking at the CFDATA blocks. Why? Well, it requires us to read
     * and skip the entire file, and the only information we get from doing
     * that is how large each folder is. Why not just use the offsets
     * between folders to define that? It's slightly less accurate - some
     * would say more accurate because it counts the block header overhead
     * - and there will be a calculation error if the folders are not
     * defined in order of data block appearance [I haven't seen any such
     * files], but overall it's much faster
     */
    for (fol = firstfol; fol; fol=fol->next) {
      fol->comp_size =
        ((fol->next) ? fol->next->offsets[0] : end_offset) - fol->offsets[0];
    }
  }

exit_handler:
  /* free any continuation comparison files in use */
  fol = ((struct CABstate *) ai->xai_PrivateClient)->folders;
  for (; fol; fol=fol->next) {
    if (fol->contfile) {
      TAINT("incomplete folder merge");
      FREE(fol->contfile);
    }
  }

  /* fill in group crunched sizes */
  for (fi = ai->xai_FileInfo; fi; fi = fi->xfi_Next) {
    fi->xfi_Flags = XADFIF_GROUPED;
    if (!fi->xfi_Next || (CABFILEFOL(fi) != CABFILEFOL(fi->xfi_Next))) {
      fi->xfi_Flags |= XADFIF_ENDOFGROUP;
      fi->xfi_GroupCrSize = CABFILEFOL(fi)->comp_size;
    }
  }

  /* if tainted, add the tainted lasterror */
  if (ai->xai_Flags & XADAIF_FILECORRUPT)
    ai->xai_LastError = XADERR_ILLEGALDATA;

  /* if a real error, then if we have files, taint and set, otherwise quit */
  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
    D(("CAB: info error=%ld\n", err))
  }
  return XADERR_OK;
}



/*--------------------------------------------------------------------------*/
/* UnArchive / Free section */

static xadINT32 CAB_NONEdecompress(CABSTATE, int inlen, int outlen) {
  struct xadMasterBase *xadMasterBase = CAB(xad);

  if (inlen != outlen) return XADERR_ILLEGALDATA;
  xadCopyMem(XADM CAB(inbuf), CAB(outbuf), (xadUINT32) inlen);
  return XADERR_OK;
}

static xadUINT32 CAB_checksum(xadUINT8 *data, xadUINT16 bytes, xadUINT32 csum) {
  int len;
  xadUINT32 ul = 0;

  for (len = bytes >> 2; len--; data += 4) {
    csum ^= ((data[0]) | (data[1]<<8) | (data[2]<<16) | (data[3]<<24));
  }

  switch (bytes & 3) {
  case 3: ul |= *data++ << 16;
  case 2: ul |= *data++ <<  8;
  case 1: ul |= *data;
  }
  csum ^= ul;

  return csum;
}

static xadINT32 CAB_decompress(CABSTATE, xadUINT32 bytes, int save) {
  struct xadArchiveInfo *ai = CAB(ai);
  struct xadMasterBase *xadMasterBase = CAB(xad);

  xadUINT8 buf[cfdata_SIZEOF], *data;
  xadUINT16 inlen, len, outlen, cando;
  xadUINT32 cksum;
  xadINT32 err = XADERR_OK;

  /* here's an optimisation to prevent the re-decoding of a folder with an
   * error at some position in it. If a file or skip goes beyond the point
   * where we last got an error, then we won't bother going through it all
   * again, we'll just repeat the error.
   */
  if (CAB(current) == CAB(lastfolder)
  && (CAB(offset) + bytes) > CAB(lastoffset))
    return CAB(lasterror);


  while (bytes > 0) {
    /* cando = the max number of bytes we can do */
    cando = CAB(outlen);
    if (cando > bytes) cando = bytes;
    D(("CAB: decomp bytes=%ld cando=%ld\n", bytes, cando))
    if (cando && save) WRITE(CAB(outpos), cando); /* if cando != 0 */
    CAB(outpos) += cando;
    CAB(outlen) -= cando;
    bytes -= cando; if (!bytes) break;

    /* we only get here if we emptied the output buffer */

    /* read data header + data */
    inlen = outlen = 0;
    while (outlen == 0) {
      /* read the block header, skip the reserved part */
      READ(buf, cfdata_SIZEOF);
      SKIP(CAB(current)->data_res[CAB(split)]);

      /* we shouldn't get blocks over CAB_INPUTMAX in size */
      data = CAB(inbuf) + inlen;
      if ((inlen += (len = GETWORD(cfdata_CompressedSize))) > CAB_INPUTMAX)
        ERROR(INPUT);

      READ(data, len);

      /* perform checksum test on the block (if one is stored) */
      if ((cksum = GETLONG(cfdata_CheckSum)) != 0) {
        if (cksum != CAB_checksum(buf+4, 4, CAB_checksum(data, len, 0)))
          ERROR(CHECKSUM);
      }

      /* outlen=0 means this block was part of a split block */
      if ((outlen = GETWORD(cfdata_UncompressedSize)) == 0) {
        CAB(split)++; SEEK(CAB(current)->offsets[CAB(split)]);
      }
    }

    /* decompress block */
    if ((err = CAB(decompress)(cabstate, inlen, outlen))) goto exit_handler;
    CAB(outlen) = outlen;
    CAB(outpos) = CAB(outbuf);
  }

exit_handler:
  if (err) {
    if (err == XADERR_INPUT
    ||  err == XADERR_ILLEGALDATA
    ||  err == XADERR_DECRUNCH
    ||  err == XADERR_CHECKSUM
    ||  err == XADERR_DATAFORMAT) {
      CAB(lasterror)  = err;
      CAB(lastfolder) = CAB(current);
      CAB(lastoffset) = CAB(offset);
    }

    /* reset folder */
    CAB(current) = NULL;
  }
  return err;
}

XADUNARCHIVE(CAB) {
  struct CABstate *cabstate = (struct CABstate *) ai->xai_PrivateClient;
  struct xadFileInfo *file = ai->xai_CurFile;
  struct CABfolder *fol = CABFILEFOL(file);
  xadINT32 err = XADERR_OK;

  CAB(ai)  = ai;
  CAB(xad) = xadMasterBase;

  /* is a change of folder needed? do we need to reset the current folder? */
  if (fol != CAB(current) || file->xfi_DataPos < CAB(offset)) {
    xadUINT16 comptype = fol->comp_type;

    /* if the archiver has changed, call the old archiver's free() function */
    if (CAB(free) && CAB(current) && ((comptype & cffoldCOMPTYPE_MASK)
    != (CAB(current)->comp_type & cffoldCOMPTYPE_MASK))) CAB(free)(cabstate);

    switch (comptype & cffoldCOMPTYPE_MASK) {
    case cffoldCOMPTYPE_NONE:
      CAB(decompress) = CAB_NONEdecompress;
      CAB(free) = NULL;
      break;
    case cffoldCOMPTYPE_MSZIP:
      CAB(decompress) = CAB_ZIPdecompress;
      CAB(free) = NULL;
      break;

    case cffoldCOMPTYPE_QUANTUM:
      CAB(decompress) = CAB_QTMdecompress;
      CAB(free) = CAB_QTMfree;
      err = CAB_QTMinit(cabstate, (comptype>>8) & 0x1f);
      break;

    case cffoldCOMPTYPE_LZX:
      CAB(decompress) = CAB_LZXdecompress;
      CAB(free) = CAB_LZXfree;
      err = CAB_LZXinit(cabstate, (comptype >> 8 & 0x1f));
      break;

    default:
      err = XADERR_NOTSUPPORTED;
    }
    if (err) goto exit_handler;

    /* initialisation OK, set current folder and reset offset */
    SEEK(fol->offsets[0]);
    CAB(current) = fol;
    CAB(offset) = 0;
    CAB(outlen) = 0; /* discard existing block */
    CAB(split)  = 0;
  }

  if (file->xfi_DataPos > CAB(offset)) {
    D(("CAB: unarc skipping %ld bytes\n",file->xfi_DataPos-CAB(offset)))
    /* decode bytes and send them to /dev/null */
    if ((err = CAB_decompress(cabstate, file->xfi_DataPos-CAB(offset), 0)))
      return err;
    else
      CAB(offset) = file->xfi_DataPos;
  }

  /* decode bytes and save them */
  D(("CAB: unarc decoding %ld bytes\n",file->xfi_Size))
  if (!(err = CAB_decompress(cabstate, file->xfi_Size, 1)))
    CAB(offset) += file->xfi_Size;

exit_handler:
  return err;
}


XADFREE(CAB) {
  struct CABstate *cabstate = (struct CABstate *) ai->xai_PrivateClient;
  struct CABfolder *f, *nf;

  if (!cabstate) return;
  if (CAB(free)) CAB(free)(cabstate); /* call archiver's free() function */
  for (f = CAB(folders); f; f = nf) { nf = f->next; FREE(f); }
  FREE(cabstate);
  ai->xai_PrivateClient = NULL;
}


/*--------------------------------------------------------------------------*/
/* executable loader */

XADRECOGDATA(CABEXE) {
  if (size < 20000 || data[0] != 'M' || data[1] != 'Z') return 0;

  /* word aligned code signature: 817C2404 "MSCF" (found at random, sorry) */
  for (data+=8, size-=8; size >= 12; data+=2, size-=2) {
    if (data[0]==0x81 && data[1]==0x7C && data[2]==0x24 && data[3]==0x04
    &&  data[4]=='M'  && data[5]=='S'  && data[6]=='C'  && data[7]=='F')
      return 1;

    /* another revision: 7D817DDC "MSCF" (which might not be aligned) */
    if (data[0]==0x81 && data[1]==0x7D && data[2]==0xDC
    &&  data[3]=='M'  && data[4]=='S'  && data[5]=='C'  && data[6]=='F')
      return 1;

    if (data[0]==0x7D && data[1]==0x81 && data[2]==0x7D && data[3]==0xDC
    &&  data[4]=='M'  && data[5]=='S'  && data[6]=='C'  && data[7]=='F')
      return 1;
  }
  return 0;
}


#define CABEXE_START (55  * 1024) /* search from 55k (StartBTClick.exe) */
#define CABEXE_END   (150 * 1024) /* search to 150k (says dirk)         */

XADGETINFO(CABEXE) {
  /* offset=0 as sentinel is OK; file has to start "MZ" to get here */
  xadUINT32 filelen, readlen, offset = 0, i;
  xadUINT8 *buf, *p;
  xadINT32 err;

  filelen = ai->xai_InSize;
  if ((readlen = filelen - CABEXE_START) > (CABEXE_END - CABEXE_START)) {
    readlen = CABEXE_END - CABEXE_START;
  }

  ALLOC(xadUINT8 *, buf, readlen);
  SKIP(CABEXE_START);
  READ(buf, readlen);

  readlen -= cfhead_SIZEOF;
  for (i=0, p=buf; i < readlen; i++, p++) {

    /* if we find a header */
    if (p[0]=='M' && p[1]=='S' && p[2]=='C' && p[3]=='F') {
      /* read the 'length of cab file and 'offset within cab file' */
      xadUINT32 len  = (p[8])  | (p[9]<<8)  | (p[10]<<16) | (p[11]<<24);
      xadUINT32 foff = (p[16]) | (p[17]<<8) | (p[18]<<16) | (p[19]<<24);
      /* if these lengths are consistent, we have a match! */
      if (len < filelen && foff < len) {
        offset = CABEXE_START + i;
        D(("CAB: exe offset=%ld\n",offset))
        goto exit_handler;
      }
    }
  }
  err = XADERR_DATAFORMAT;

exit_handler:
  if (buf) FREE(buf);

  /* if we found a match, actually look at the archive */
  if (offset != 0) {
    SEEK(offset);
    err = CAB_GetInfo(ai, xadMasterBase);
  }
  return err;
}


/*--------------------------------------------------------------------------*/

XADCLIENT(CABEXE) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  CAB_VERSION,
  CAB_REVISION,
  65536, /* first 64kb should have signature */
  XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS |
  XADCF_NOCHECKSIZE,
  XADCID_CABMSEXE,
  "CAB MS-EXE",
  /* client functions */
  XADRECOGDATAP(CABEXE),
  XADGETINFOP(CABEXE),
  XADUNARCHIVEP(CAB),
  XADFREEP(CAB)
};

XADFIRSTCLIENT(CAB) {
  (struct xadClient *) &CABEXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  CAB_VERSION,
  CAB_REVISION,
  14,
  XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  XADCID_CAB,
  "CAB",
  /* client functions */
  XADRECOGDATAP(CAB),
  XADGETINFOP(CAB),
  XADUNARCHIVEP(CAB),
  XADFREEP(CAB)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(CAB)

#endif /* XADMASTER_CAB_C */

