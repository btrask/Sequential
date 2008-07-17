#ifndef XADMASTER_BZIP2_C
#define XADMASTER_BZIP2_C

/*  $Id: bzip2.c,v 1.14 2005/06/23 14:54:41 stoecker Exp $
    bzip2 file archiver

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
    Copyright (C) 2000-2004 by Kyzer/CSG <kyzer@4u.net>

    Decompression code of bzip2's author
    Copyright (C) 1996-2002 by Julian Seward

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

/* Additional license comment:
 * The modified and unmodified code of libbzip2 is (C) Julian R. Seward
 * and retains its original license. However, you should not directly
 * use these modified versions. You should obtain the original bzip2
 * and libbzip2 from http://sources.redhat.com/bzip2/
 */

/* bzip2, (C) 1996-2000 Julian R. Seward, is a "block-sorting file
 * compressor". It uses the Burrows-Wheeler block-sorting text compression
 * algorithm, with some Huffman coding on the output, and, run length encoding
 * and randomisation thrown in to improve the speed efficiency of the
 * compressor. The run-length encoding "is entirely irrelevant" and the
 * randomisation "doesn't really need to be there". However, "compression is
 * generally considerably better than that achieved by more conventional
 * LZ77/LZ78-based compressors, and approaches the performance of the PPM
 * family of statistical compressors."
 *
 * bzip2 is mainly used as a replacement for gzip in compressing UNIX tar
 * archives, because it beats gzip (which uses the LZH-like deflate
 * algorithim) in compression and is therefore useful for saving valuable
 * bandwidth for Linux distributions and the like.
 *
 * The main 'problems' with bzip2 are:
 * - it uses huge amounts of memory. The default compression mode is the
 *   maximum block size, which means that decompression requires 2.1Mb of RAM
 *   (preferably 3.5Mb), even for the tiniest files.
 * - it can only compress and decompress single files - it doesn't store any
 *   file metadata whatsoever, not even a single file's name or size.
 * - it has no idea how large the output data is in advance, and it can't even
 *   tell how big each block is in the file. It can only run through the data
 *   and tell you once it's decompressed how big it was.
 *
 * Even with these problems, the advantage in compression over gzip is enough
 * to make it popular with new archive sites.
 *
 * The original bzip2 and libbzip2 are available from
 * http://sources.redhat.com/bzip2/
 */

/* bzip2 file format:
 * - first, the header: 'BZh1' to 'BZh9'
 *   - the 1-9 in the header is the size of a block / 100000
 *
 * - next, 0 or more compressed data blocks
 *   - the block starts with recogdata: $314159265359 (BCD pi :)
 *   - then comes a 4 byte CRC-so-far
 *   - then the various state tables
 *   - then the sorted randomized huffed RLE data
 *
 * - a final block containing no data is always included
 *   - it's recog is $177245385090, however after the first block
 *     the data is 87.5% likely not to be byte aligned, so you probably
 *     won't see it in a hex editor.
 *   - there's a 4 byte final CRC, but for the reason mentioned above,
 *     it's difficult to check.
 *
 * - minimum size of file is 14 bytes for a 0 byte input file (just a
 *   header and the final block, no data blocks), or 37 bytes for a 1 byte
 *   input file
 *
 * bzip2, by virtue of early recklessness and backwards compatibility on
 * the part of the author, does not contain *any* information whatsoever
 * about the data itself, it can't even know how long a block is without
 * decompressing it. But hey! It beats gzip on compression, so that's got
 * to be good, right?
 */

/* CHANGES TO LIBBZIP2
 *
 * All files are collected into a single file.
 * All superfluous header definitions are removed.
 * All compression code and definitions are removed.
 *
 * The decompresser has been modified to try and enter 'small mode'
 * automatically if it cannot allocate enough memory for 'fast mode'. The
 * library normally expects you to say which mode you want and sticks rigidly
 * to that.
 *
 * Assertion failures in decompression (that is, failures of the code that
 * can't logically occur) are turned into returning error codes, as the XAD
 * client can't support the immediate exit() that libbzip2 would like -
 * instead we have to pop back to the original entry point and return, it's
 * the only way.
 *
 * The random number table 'rNums' has been made into Int16 instead of Int32.
 * This halves the size of the table (and saves exactly 1Kb), yet because all
 * the numbers are small enough to fit into an Int16, it doesn't require
 * changing code at all. All I've added is an explicit cast when a table entry
 * is retrieved, to be on the safe side. This optimisation was suggested by
 * Dirk Stöcker.
 *
 * The CRC table is now generated at runtime, saving another 1Kb. The code for
 * this was written by Dirk Stöcker.
 */

/* VERSION HISTORY
 *
 * v1.0: original
 * v1.1: uses XAD's new 'no size' flag and default name. Released with XAD 6.
 * v1.2: now uses bzip2-1.0.0 sources.
 * v1.3: uses XAD's new 'input archive filename'. Released with XAD 7.
 * v1.4: generates CRC table at runtime, slightly better file extension code.
 * v1.5: "trailing garbage after EOF ignored" non-error implemented. 68040
 *       version and install script added.
 * v1.6: memory leak fixed in UnArc() function
 * v1.7: Dirk made unarchive routine much neater! Removed static xadbase from
 *       memory funcs, made buffersize #define instead of const int, and
 *       increased input/output buffers to 32k each.
 * v1.8: added "BZip2 SFX" client (created by "bz2exe", a clone of "gzexe").
 *       Released with XAD 12.
 *
 * $VER: bzip2.c 1.9 (04.04.2004)
 */

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 13
#endif

XADCLIENTVERSTR("bzip2 1.9 (04.04.2004)")

#define BZIP2_VERSION           1
#define BZIP2_REVISION          9

static void BZ2_MakeCRC32R(xadUINT32 *buf, xadUINT32 ID) {
  xadUINT32 k;
  int i, j;
  for(i = 0; i < 256; i++) {
    k = i << 24;
    for(j=8; j--;) k = (k & 0x80000000) ? ((k << 1) ^ ID) : (k << 1);
    buf[i] = k;
  }
}

/*--- bzip2 code ------------------------------------------------------------*/

/*--
  This file is a part of bzip2 and/or libbzip2, a program and
  library for lossless, block-sorting data compression.

  Copyright (C) 1996-2000 Julian R Seward.  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. The origin of this software must not be misrepresented; you must
     not claim that you wrote the original software.  If you use this
     software in a product, an acknowledgment in the product
     documentation would be appreciated but is not required.

  3. Altered source versions must be plainly marked as such, and must
     not be misrepresented as being the original software.

  4. The name of the author may not be used to endorse or promote
     products derived from this software without specific prior written
     permission.

  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  Julian Seward, Cambridge, UK.
  jseward@acm.org
  bzip2/libbzip2 version 1.0 of 21 March 2000

  This program is based on (at least) the work of:
     Mike Burrows
     David Wheeler
     Peter Fenwick
     Alistair Moffat
     Radford Neal
     Ian H. Witten
     Robert Sedgewick
     Jon L. Bentley

  For more information on these sources, see the manual.
--*/

#define BZ_RUN               0
#define BZ_FLUSH             1
#define BZ_FINISH            2

#define BZ_OK                0
#define BZ_RUN_OK            1
#define BZ_FLUSH_OK          2
#define BZ_FINISH_OK         3
#define BZ_STREAM_END        4
#define BZ_SEQUENCE_ERROR    (-1)
#define BZ_PARAM_ERROR       (-2)
#define BZ_MEM_ERROR         (-3)
#define BZ_DATA_ERROR        (-4)
#define BZ_DATA_ERROR_MAGIC  (-5)
#define BZ_IO_ERROR          (-6)
#define BZ_UNEXPECTED_EOF    (-7)
#define BZ_OUTBUFF_FULL      (-8)
#define BZ_CONFIG_ERROR      (-9)

typedef
   struct {
      char *next_in;
      unsigned int avail_in;
      unsigned int total_in_lo32;
      unsigned int total_in_hi32;

      char *next_out;
      unsigned int avail_out;
      unsigned int total_out_lo32;
      unsigned int total_out_hi32;

      void *state;

      void *(*bzalloc)(void *,int,int);
      void (*bzfree)(void *,void *);
      void *opaque;
   }
   bz_stream;

/*-- General stuff. --*/

#define BZ_VERSION  "1.0.0, 16-May-2000"

#define BZALLOC(nnn) (strm->bzalloc)(strm->opaque,(int)(nnn),1)
#define BZFREE(ppp)  (strm->bzfree)(strm->opaque,(ppp))


/*-- Constants for the back end. --*/

#define BZ_MAX_ALPHA_SIZE 258
#define BZ_MAX_CODE_LEN    23

#define BZ_RUNA 0
#define BZ_RUNB 1

#define BZ_N_GROUPS 6
#define BZ_G_SIZE   50
#define BZ_N_ITERS  4

#define BZ_MAX_SELECTORS (2 + (900000 / BZ_G_SIZE))

/*-- Stuff for randomising repetitive blocks. --*/

#define BZ_RAND_DECLS                          \
   xadINT32 rNToGo;                               \
   xadINT32 rTPos                                 \

#define BZ_RAND_INIT_MASK                      \
   s->rNToGo = 0;                              \
   s->rTPos  = 0                               \

#define BZ_RAND_MASK ((s->rNToGo == 1) ? 1 : 0)

#define BZ_RAND_UPD_MASK                       \
   if (s->rNToGo == 0) {                       \
      s->rNToGo = (xadINT32) BZ2_rNums[s->rTPos]; \
      s->rTPos++;                              \
      if (s->rTPos == 512) s->rTPos = 0;       \
   }                                           \
   s->rNToGo--;



/*-- Stuff for doing CRCs. --*/

#define BZ_INITIALISE_CRC(crcVar)              \
{                                              \
   crcVar = 0xffffffffL;                       \
}

#define BZ_FINALISE_CRC(crcVar)                \
{                                              \
   crcVar = ~(crcVar);                         \
}

#define BZ_UPDATE_CRC(crcVar,cha)              \
{                                              \
   crcVar = (crcVar << 8) ^                    \
            BZ2_crc32Table[(crcVar >> 24) ^    \
                           ((xadUINT8)cha)];      \
}

/*-- states for decompression. --*/

#define BZ_X_IDLE        1
#define BZ_X_OUTPUT      2

#define BZ_X_MAGIC_1     10
#define BZ_X_MAGIC_2     11
#define BZ_X_MAGIC_3     12
#define BZ_X_MAGIC_4     13
#define BZ_X_BLKHDR_1    14
#define BZ_X_BLKHDR_2    15
#define BZ_X_BLKHDR_3    16
#define BZ_X_BLKHDR_4    17
#define BZ_X_BLKHDR_5    18
#define BZ_X_BLKHDR_6    19
#define BZ_X_BCRC_1      20
#define BZ_X_BCRC_2      21
#define BZ_X_BCRC_3      22
#define BZ_X_BCRC_4      23
#define BZ_X_RANDBIT     24
#define BZ_X_ORIGPTR_1   25
#define BZ_X_ORIGPTR_2   26
#define BZ_X_ORIGPTR_3   27
#define BZ_X_MAPPING_1   28
#define BZ_X_MAPPING_2   29
#define BZ_X_SELECTOR_1  30
#define BZ_X_SELECTOR_2  31
#define BZ_X_SELECTOR_3  32
#define BZ_X_CODING_1    33
#define BZ_X_CODING_2    34
#define BZ_X_CODING_3    35
#define BZ_X_MTF_1       36
#define BZ_X_MTF_2       37
#define BZ_X_MTF_3       38
#define BZ_X_MTF_4       39
#define BZ_X_MTF_5       40
#define BZ_X_MTF_6       41
#define BZ_X_ENDHDR_2    42
#define BZ_X_ENDHDR_3    43
#define BZ_X_ENDHDR_4    44
#define BZ_X_ENDHDR_5    45
#define BZ_X_ENDHDR_6    46
#define BZ_X_CCRC_1      47
#define BZ_X_CCRC_2      48
#define BZ_X_CCRC_3      49
#define BZ_X_CCRC_4      50

/*-- Constants for the fast MTF decoder. --*/

#define MTFA_SIZE 4096
#define MTFL_SIZE 16

/*-- Structure holding all the decompression-side stuff. --*/

typedef
   struct {
      /* pointer back to the struct bz_stream */
      bz_stream* strm;

      /* state indicator for this stream */
      xadINT32    state;

      /* for doing the final run-length decoding */
      xadUINT8    state_out_ch;
      xadINT32    state_out_len;
      xadBOOL     blockRandomised;
      BZ_RAND_DECLS;

      /* the buffer for bit stream reading */
      xadUINT32   bsBuff;
      xadINT32    bsLive;

      /* misc administratium */
      xadINT32    blockSize100k;
      xadBOOL     smallDecompress;
      xadINT32    currBlockNo;
      xadINT32    verbosity;

      /* for undoing the Burrows-Wheeler transform */
      xadINT32    origPtr;
      xadUINT32   tPos;
      xadINT32    k0;
      xadINT32    unzftab[256];
      xadINT32    nblock_used;
      xadINT32    cftab[257];
      xadINT32    cftabCopy[257];

      /* for undoing the Burrows-Wheeler transform (FAST) */
      xadUINT32   *tt;

      /* for undoing the Burrows-Wheeler transform (SMALL) */
      xadUINT16   *ll16;
      xadUINT8    *ll4;

      /* stored and calculated CRCs */
      xadUINT32   storedBlockCRC;
      xadUINT32   storedCombinedCRC;
      xadUINT32   calculatedBlockCRC;
      xadUINT32   calculatedCombinedCRC;

      /* map of bytes used in block */
      xadINT32    nInUse;
      xadBOOL     inUse[256];
      xadBOOL     inUse16[16];
      xadUINT8    seqToUnseq[256];

      /* for decoding the MTF values */
      xadUINT8    mtfa   [MTFA_SIZE];
      xadINT32    mtfbase[256 / MTFL_SIZE];
      xadUINT8    selector   [BZ_MAX_SELECTORS];
      xadUINT8    selectorMtf[BZ_MAX_SELECTORS];
      xadUINT8    len  [BZ_N_GROUPS][BZ_MAX_ALPHA_SIZE];

      xadINT32    limit  [BZ_N_GROUPS][BZ_MAX_ALPHA_SIZE];
      xadINT32    base   [BZ_N_GROUPS][BZ_MAX_ALPHA_SIZE];
      xadINT32    perm   [BZ_N_GROUPS][BZ_MAX_ALPHA_SIZE];
      xadINT32    minLens[BZ_N_GROUPS];

      /* save area for scalars in the main decompress code */
      xadINT32    save_i;
      xadINT32    save_j;
      xadINT32    save_t;
      xadINT32    save_alphaSize;
      xadINT32    save_nGroups;
      xadINT32    save_nSelectors;
      xadINT32    save_EOB;
      xadINT32    save_groupNo;
      xadINT32    save_groupPos;
      xadINT32    save_nextSym;
      xadINT32    save_nblockMAX;
      xadINT32    save_nblock;
      xadINT32    save_es;
      xadINT32    save_N;
      xadINT32    save_curr;
      xadINT32    save_zt;
      xadINT32    save_zn;
      xadINT32    save_zvec;
      xadINT32    save_zj;
      xadINT32    save_gSel;
      xadINT32    save_gMinlen;
      xadINT32*   save_gLimit;
      xadINT32*   save_gBase;
      xadINT32*   save_gPerm;

   }
   DState;



/*-- Macros for decompression. --*/

#define BZ_GET_FAST(cccc)                     \
    s->tPos = s->tt[s->tPos];                 \
    cccc = (xadUINT8)(s->tPos & 0xff);           \
    s->tPos >>= 8;

#define BZ_GET_FAST_C(cccc)                   \
    c_tPos = c_tt[c_tPos];                    \
    cccc = (xadUINT8)(c_tPos & 0xff);            \
    c_tPos >>= 8;

#define SET_LL4(i,n)                                          \
   { if (((i) & 0x1) == 0)                                    \
        s->ll4[(i) >> 1] = (s->ll4[(i) >> 1] & 0xf0) | (n); else    \
        s->ll4[(i) >> 1] = (s->ll4[(i) >> 1] & 0x0f) | ((n) << 4);  \
   }

#define GET_LL4(i)                             \
   ((((xadUINT32)(s->ll4[(i) >> 1])) >> (((i) << 2) & 0x4)) & 0xF)

#define SET_LL(i,n)                          \
   { s->ll16[i] = (xadUINT16)(n & 0x0000ffff);  \
     SET_LL4(i, n >> 16);                    \
   }

#define GET_LL(i) \
   (((xadUINT32)s->ll16[i]) | (GET_LL4(i) << 16))

#define BZ_GET_SMALL(cccc)                            \
      cccc = BZ2_indexIntoF ( (xadINT32)s->tPos, s->cftab );    \
      s->tPos = GET_LL(s->tPos);

static xadUINT32 BZ2_crc32Table[256];

static const xadINT16 BZ2_rNums[512] = {
  619, 720, 127, 481, 931, 816, 813, 233, 566, 247, 985, 724, 205, 454, 863,
  491, 741, 242, 949, 214, 733, 859, 335, 708, 621, 574,  73, 654, 730, 472,
  419, 436, 278, 496, 867, 210, 399, 680, 480,  51, 878, 465, 811, 169, 869,
  675, 611, 697, 867, 561, 862, 687, 507, 283, 482, 129, 807, 591, 733, 623,
  150, 238,  59, 379, 684, 877, 625, 169, 643, 105, 170, 607, 520, 932, 727,
  476, 693, 425, 174, 647,  73, 122, 335, 530, 442, 853, 695, 249, 445, 515,
  909, 545, 703, 919, 874, 474, 882, 500, 594, 612, 641, 801, 220, 162, 819,
  984, 589, 513, 495, 799, 161, 604, 958, 533, 221, 400, 386, 867, 600, 782,
  382, 596, 414, 171, 516, 375, 682, 485, 911, 276,  98, 553, 163, 354, 666,
  933, 424, 341, 533, 870, 227, 730, 475, 186, 263, 647, 537, 686, 600, 224,
  469,  68, 770, 919, 190, 373, 294, 822, 808, 206, 184, 943, 795, 384, 383,
  461, 404, 758, 839, 887, 715,  67, 618, 276, 204, 918, 873, 777, 604, 560,
  951, 160, 578, 722,  79, 804,  96, 409, 713, 940, 652, 934, 970, 447, 318,
  353, 859, 672, 112, 785, 645, 863, 803, 350, 139,  93, 354,  99, 820, 908,
  609, 772, 154, 274, 580, 184,  79, 626, 630, 742, 653, 282, 762, 623, 680,
   81, 927, 626, 789, 125, 411, 521, 938, 300, 821,  78, 343, 175, 128, 250,
  170, 774, 972, 275, 999, 639, 495,  78, 352, 126, 857, 956, 358, 619, 580,
  124, 737, 594, 701, 612, 669, 112, 134, 694, 363, 992, 809, 743, 168, 974,
  944, 375, 748,  52, 600, 747, 642, 182, 862,  81, 344, 805, 988, 739, 511,
  655, 814, 334, 249, 515, 897, 955, 664, 981, 649, 113, 974, 459, 893, 228,
  433, 837, 553, 268, 926, 240, 102, 654, 459,  51, 686, 754, 806, 760, 493,
  403, 415, 394, 687, 700, 946, 670, 656, 610, 738, 392, 760, 799, 887, 653,
  978, 321, 576, 617, 626, 502, 894, 679, 243, 440, 680, 879, 194, 572, 640,
  724, 926,  56, 204, 700, 707, 151, 457, 449, 797, 195, 791, 558, 945, 679,
  297,  59,  87, 824, 713, 663, 412, 693, 342, 606, 134, 108, 571, 364, 631,
  212, 174, 643, 304, 329, 343,  97, 430, 751, 497, 314, 983, 374, 822, 928,
  140, 206,  73, 263, 980, 736, 876, 478, 430, 305, 170, 514, 364, 692, 829,
   82, 855, 953, 676, 246, 369, 970, 294, 750, 807, 827, 150, 790, 288, 923,
  804, 378, 215, 828, 592, 281, 565, 555, 710,  82, 896, 831, 547, 261, 524,
  462, 293, 465, 502,  56, 661, 821, 976, 991, 658, 869, 905, 758, 745, 193,
  768, 550, 608, 933, 378, 286, 215, 979, 792, 961,  61, 688, 793, 644, 986,
  403, 106, 366, 905, 644, 372, 567, 466, 434, 645, 210, 389, 550, 919, 135,
  780, 773, 635, 389, 707, 100, 626, 958, 165, 504, 920, 176, 193, 713, 857,
  265, 203,  50, 668, 108, 645, 990, 626, 197, 510, 357, 358, 850, 858, 364,
  936, 638
};

static void BZ2_hbCreateDecodeTables ( xadINT32 *limit, xadINT32 *base, xadINT32 *perm,
xadUINT8 *length, xadINT32 minLen, xadINT32 maxLen, xadINT32 alphaSize ) {
   xadINT32 pp, i, j, vec;

   pp = 0;
   for (i = minLen; i <= maxLen; i++)
      for (j = 0; j < alphaSize; j++)
         if (length[j] == i) { perm[pp] = j; pp++; };

   for (i = 0; i < BZ_MAX_CODE_LEN; i++) base[i] = 0;
   for (i = 0; i < alphaSize; i++) base[length[i]+1]++;
   for (i = 1; i < BZ_MAX_CODE_LEN; i++) base[i] += base[i-1];
   for (i = 0; i < BZ_MAX_CODE_LEN; i++) limit[i] = 0;
   vec = 0;

   for (i = minLen; i <= maxLen; i++) {
      vec += (base[i+1] - base[i]);
      limit[i] = vec-1;
      vec <<= 1;
   }
   for (i = minLen + 1; i <= maxLen; i++)
      base[i] = ((limit[i-1] + 1) << 1) - base[i];
}

/*---------------------------------------------------*/
static void makeMaps_d ( DState* s )
{
   xadINT32 i;
   s->nInUse = 0;
   for (i = 0; i < 256; i++)
      if (s->inUse[i]) {
         s->seqToUnseq[s->nInUse] = i;
         s->nInUse++;
      }
}


/*---------------------------------------------------*/
#define RETURN(rrr)                               \
   { retVal = rrr; goto save_state_and_return; };

#define GET_BITS(lll,vvv,nnn)                     \
   case lll: s->state = lll;                      \
   while (XADTRUE) {                                 \
      if (s->bsLive >= nnn) {                     \
         xadUINT32 v;                                \
         v = (s->bsBuff >>                        \
             (s->bsLive-nnn)) & ((1 << nnn)-1);   \
         s->bsLive -= nnn;                        \
         vvv = v;                                 \
         break;                                   \
      }                                           \
      if (s->strm->avail_in == 0) RETURN(BZ_OK);  \
      s->bsBuff                                   \
         = (s->bsBuff << 8) |                     \
           ((xadUINT32)                              \
              (*((xadUINT8*)(s->strm->next_in))));   \
      s->bsLive += 8;                             \
      s->strm->next_in++;                         \
      s->strm->avail_in--;                        \
      s->strm->total_in_lo32++;                   \
      if (s->strm->total_in_lo32 == 0)            \
         s->strm->total_in_hi32++;                \
   }

#define GET_UCHAR(lll,uuu)                        \
   GET_BITS(lll,uuu,8)

#define GET_BIT(lll,uuu)                          \
   GET_BITS(lll,uuu,1)

/*---------------------------------------------------*/
#define GET_MTF_VAL(label1,label2,lval)           \
{                                                 \
   if (groupPos == 0) {                           \
      groupNo++;                                  \
      if (groupNo >= nSelectors)                  \
         RETURN(BZ_DATA_ERROR);                   \
      groupPos = BZ_G_SIZE;                       \
      gSel = s->selector[groupNo];                \
      gMinlen = s->minLens[gSel];                 \
      gLimit = &(s->limit[gSel][0]);              \
      gPerm = &(s->perm[gSel][0]);                \
      gBase = &(s->base[gSel][0]);                \
   }                                              \
   groupPos--;                                    \
   zn = gMinlen;                                  \
   GET_BITS(label1, zvec, zn);                    \
   while (1) {                                    \
      if (zn > 20 /* the longest code */)         \
         RETURN(BZ_DATA_ERROR);                   \
      if (zvec <= gLimit[zn]) break;              \
      zn++;                                       \
      GET_BIT(label2, zj);                        \
      zvec = (zvec << 1) | zj;                    \
   };                                             \
   if (zvec - gBase[zn] < 0                       \
       || zvec - gBase[zn] >= BZ_MAX_ALPHA_SIZE)  \
      RETURN(BZ_DATA_ERROR);                      \
   lval = gPerm[zvec - gBase[zn]];                \
}


/*---------------------------------------------------*/
static /*INLINE*/ xadINT32 BZ2_indexIntoF ( xadINT32 indx, xadINT32 *cftab )
{
   xadINT32 nb, na, mid;
   nb = 0;
   na = 256;
   do {
      mid = (nb + na) >> 1;
      if (indx >= cftab[mid]) nb = mid; else na = mid;
   }
   while (na - nb != 1);
   return nb;
}


/*---------------------------------------------------*/
static xadINT32 BZ2_decompress ( DState* s )
{
   xadUINT8      uc=0;
   xadINT32      retVal;
   xadINT32      minLen, maxLen;
   bz_stream* strm = s->strm;

   /* stuff that needs to be saved/restored */
   xadINT32  i;
   xadINT32  j;
   xadINT32  t;
   xadINT32  alphaSize;
   xadINT32  nGroups;
   xadINT32  nSelectors;
   xadINT32  EOB;
   xadINT32  groupNo;
   xadINT32  groupPos;
   xadINT32  nextSym;
   xadINT32  nblockMAX;
   xadINT32  nblock;
   xadINT32  es;
   xadINT32  N;
   xadINT32  curr;
   xadINT32  zt;
   xadINT32  zn;
   xadINT32  zvec;
   xadINT32  zj;
   xadINT32  gSel;
   xadINT32  gMinlen;
   xadINT32* gLimit;
   xadINT32* gBase;
   xadINT32* gPerm;

   if (s->state == BZ_X_MAGIC_1) {
      /*initialise the save area*/
      s->save_i           = 0;
      s->save_j           = 0;
      s->save_t           = 0;
      s->save_alphaSize   = 0;
      s->save_nGroups     = 0;
      s->save_nSelectors  = 0;
      s->save_EOB         = 0;
      s->save_groupNo     = 0;
      s->save_groupPos    = 0;
      s->save_nextSym     = 0;
      s->save_nblockMAX   = 0;
      s->save_nblock      = 0;
      s->save_es          = 0;
      s->save_N           = 0;
      s->save_curr        = 0;
      s->save_zt          = 0;
      s->save_zn          = 0;
      s->save_zvec        = 0;
      s->save_zj          = 0;
      s->save_gSel        = 0;
      s->save_gMinlen     = 0;
      s->save_gLimit      = NULL;
      s->save_gBase       = NULL;
      s->save_gPerm       = NULL;
   }

   /*restore from the save area*/
   i           = s->save_i;
   j           = s->save_j;
   t           = s->save_t;
   alphaSize   = s->save_alphaSize;
   nGroups     = s->save_nGroups;
   nSelectors  = s->save_nSelectors;
   EOB         = s->save_EOB;
   groupNo     = s->save_groupNo;
   groupPos    = s->save_groupPos;
   nextSym     = s->save_nextSym;
   nblockMAX   = s->save_nblockMAX;
   nblock      = s->save_nblock;
   es          = s->save_es;
   N           = s->save_N;
   curr        = s->save_curr;
   zt          = s->save_zt;
   zn          = s->save_zn;
   zvec        = s->save_zvec;
   zj          = s->save_zj;
   gSel        = s->save_gSel;
   gMinlen     = s->save_gMinlen;
   gLimit      = s->save_gLimit;
   gBase       = s->save_gBase;
   gPerm       = s->save_gPerm;

   switch (s->state) {

      GET_UCHAR(BZ_X_MAGIC_1, uc);
      if (uc != 'B') RETURN(BZ_DATA_ERROR_MAGIC);

      GET_UCHAR(BZ_X_MAGIC_2, uc);
      if (uc != 'Z') RETURN(BZ_DATA_ERROR_MAGIC);

      GET_UCHAR(BZ_X_MAGIC_3, uc)
      if (uc != 'h') RETURN(BZ_DATA_ERROR_MAGIC);

      GET_BITS(BZ_X_MAGIC_4, s->blockSize100k, 8)
      if (s->blockSize100k < '1' ||
          s->blockSize100k > '9') RETURN(BZ_DATA_ERROR_MAGIC);
      s->blockSize100k -= '0';

      /* drops down to small mode if need be */
      if (!s->smallDecompress) {
         s->tt  = BZALLOC( s->blockSize100k * 100000 * sizeof(xadINT32) );
         if (s->tt == NULL) s->smallDecompress = XADTRUE;
      }
      if (s->smallDecompress) {

         s->ll16 = BZALLOC( s->blockSize100k * 100000 * sizeof(xadUINT16) );
         s->ll4  = BZALLOC(
                      ((1 + s->blockSize100k * 100000) >> 1) * sizeof(xadUINT8)
                   );
         if (s->ll16 == NULL || s->ll4 == NULL) RETURN(BZ_MEM_ERROR);
      }

      GET_UCHAR(BZ_X_BLKHDR_1, uc);

      if (uc == 0x17) goto endhdr_2;
      if (uc != 0x31) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_BLKHDR_2, uc);
      if (uc != 0x41) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_BLKHDR_3, uc);
      if (uc != 0x59) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_BLKHDR_4, uc);
      if (uc != 0x26) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_BLKHDR_5, uc);
      if (uc != 0x53) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_BLKHDR_6, uc);
      if (uc != 0x59) RETURN(BZ_DATA_ERROR);

      s->currBlockNo++;

      s->storedBlockCRC = 0;
      GET_UCHAR(BZ_X_BCRC_1, uc);
      s->storedBlockCRC = (s->storedBlockCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_BCRC_2, uc);
      s->storedBlockCRC = (s->storedBlockCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_BCRC_3, uc);
      s->storedBlockCRC = (s->storedBlockCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_BCRC_4, uc);
      s->storedBlockCRC = (s->storedBlockCRC << 8) | ((xadUINT32)uc);

      GET_BITS(BZ_X_RANDBIT, s->blockRandomised, 1);

      s->origPtr = 0;
      GET_UCHAR(BZ_X_ORIGPTR_1, uc);
      s->origPtr = (s->origPtr << 8) | ((xadINT32)uc);
      GET_UCHAR(BZ_X_ORIGPTR_2, uc);
      s->origPtr = (s->origPtr << 8) | ((xadINT32)uc);
      GET_UCHAR(BZ_X_ORIGPTR_3, uc);
      s->origPtr = (s->origPtr << 8) | ((xadINT32)uc);

      if (s->origPtr < 0)
         RETURN(BZ_DATA_ERROR);
      if (s->origPtr > 10 + 100000*s->blockSize100k)
         RETURN(BZ_DATA_ERROR);

      /*--- Receive the mapping table ---*/
      for (i = 0; i < 16; i++) {
         GET_BIT(BZ_X_MAPPING_1, uc);
         if (uc == 1)
            s->inUse16[i] = XADTRUE; else
            s->inUse16[i] = XADFALSE;
      }

      for (i = 0; i < 256; i++) s->inUse[i] = XADFALSE;

      for (i = 0; i < 16; i++)
         if (s->inUse16[i])
            for (j = 0; j < 16; j++) {
               GET_BIT(BZ_X_MAPPING_2, uc);
               if (uc == 1) s->inUse[i * 16 + j] = XADTRUE;
            }
      makeMaps_d ( s );
      if (s->nInUse == 0) RETURN(BZ_DATA_ERROR);
      alphaSize = s->nInUse+2;

      /*--- Now the selectors ---*/
      GET_BITS(BZ_X_SELECTOR_1, nGroups, 3);
      if (nGroups < 2 || nGroups > 6) RETURN(BZ_DATA_ERROR);
      GET_BITS(BZ_X_SELECTOR_2, nSelectors, 15);
      if (nSelectors < 1) RETURN(BZ_DATA_ERROR);
      for (i = 0; i < nSelectors; i++) {
         j = 0;
         while (XADTRUE) {
            GET_BIT(BZ_X_SELECTOR_3, uc);
            if (uc == 0) break;
            j++;
            if (j >= nGroups) RETURN(BZ_DATA_ERROR);
         }
         s->selectorMtf[i] = j;
      }

      /*--- Undo the MTF values for the selectors. ---*/
      {
         xadUINT8 pos[BZ_N_GROUPS], tmp, v;
         for (v = 0; v < nGroups; v++) pos[v] = v;

         for (i = 0; i < nSelectors; i++) {
            v = s->selectorMtf[i];
            tmp = pos[v];
            while (v > 0) { pos[v] = pos[v-1]; v--; }
            pos[0] = tmp;
            s->selector[i] = tmp;
         }
      }

      /*--- Now the coding tables ---*/
      for (t = 0; t < nGroups; t++) {
         GET_BITS(BZ_X_CODING_1, curr, 5);
         for (i = 0; i < alphaSize; i++) {
            while (XADTRUE) {
               if (curr < 1 || curr > 20) RETURN(BZ_DATA_ERROR);
               GET_BIT(BZ_X_CODING_2, uc);
               if (uc == 0) break;
               GET_BIT(BZ_X_CODING_3, uc);
               if (uc == 0) curr++; else curr--;
            }
            s->len[t][i] = curr;
         }
      }

      /*--- Create the Huffman decoding tables ---*/
      for (t = 0; t < nGroups; t++) {
         minLen = 32;
         maxLen = 0;
         for (i = 0; i < alphaSize; i++) {
            if (s->len[t][i] > maxLen) maxLen = s->len[t][i];
            if (s->len[t][i] < minLen) minLen = s->len[t][i];
         }
         BZ2_hbCreateDecodeTables (
            &(s->limit[t][0]),
            &(s->base[t][0]),
            &(s->perm[t][0]),
            &(s->len[t][0]),
            minLen, maxLen, alphaSize
         );
         s->minLens[t] = minLen;
      }

      /*--- Now the MTF values ---*/

      EOB      = s->nInUse+1;
      nblockMAX = 100000 * s->blockSize100k;
      groupNo  = -1;
      groupPos = 0;

      for (i = 0; i <= 255; i++) s->unzftab[i] = 0;

      /*-- MTF init --*/
      {
         xadINT32 ii, jj, kk;
         kk = MTFA_SIZE-1;
         for (ii = 256 / MTFL_SIZE - 1; ii >= 0; ii--) {
            for (jj = MTFL_SIZE-1; jj >= 0; jj--) {
               s->mtfa[kk] = (xadUINT8)(ii * MTFL_SIZE + jj);
               kk--;
            }
            s->mtfbase[ii] = kk + 1;
         }
      }
      /*-- end MTF init --*/

      nblock = 0;
      GET_MTF_VAL(BZ_X_MTF_1, BZ_X_MTF_2, nextSym);

      while (XADTRUE) {

         if (nextSym == EOB) break;

         if (nextSym == BZ_RUNA || nextSym == BZ_RUNB) {

            es = -1;
            N = 1;
            do {
               if (nextSym == BZ_RUNA) es = es + (0+1) * N; else
               if (nextSym == BZ_RUNB) es = es + (1+1) * N;
               N = N * 2;
               GET_MTF_VAL(BZ_X_MTF_3, BZ_X_MTF_4, nextSym);
            }
               while (nextSym == BZ_RUNA || nextSym == BZ_RUNB);

            es++;
            uc = s->seqToUnseq[ s->mtfa[s->mtfbase[0]] ];
            s->unzftab[uc] += es;

            if (s->smallDecompress)
               while (es > 0) {
                  if (nblock >= nblockMAX) RETURN(BZ_DATA_ERROR);
                  s->ll16[nblock] = (xadUINT16)uc;
                  nblock++;
                  es--;
               }
            else
               while (es > 0) {
                  if (nblock >= nblockMAX) RETURN(BZ_DATA_ERROR);
                  s->tt[nblock] = (xadUINT32)uc;
                  nblock++;
                  es--;
               };

            continue;

         } else {

            if (nblock >= nblockMAX) RETURN(BZ_DATA_ERROR);

            /*-- uc = MTF ( nextSym-1 ) --*/
            {
               xadINT32 ii, jj, kk, pp, lno, off;
               xadUINT32 nn;
               nn = (xadUINT32)(nextSym - 1);

               if (nn < MTFL_SIZE) {
                  /* avoid general-case expense */
                  pp = s->mtfbase[0];
                  uc = s->mtfa[pp+nn];
                  while (nn > 3) {
                     xadINT32 z = pp+nn;
                     s->mtfa[(z)  ] = s->mtfa[(z)-1];
                     s->mtfa[(z)-1] = s->mtfa[(z)-2];
                     s->mtfa[(z)-2] = s->mtfa[(z)-3];
                     s->mtfa[(z)-3] = s->mtfa[(z)-4];
                     nn -= 4;
                  }
                  while (nn > 0) {
                     s->mtfa[(pp+nn)] = s->mtfa[(pp+nn)-1]; nn--;
                  };
                  s->mtfa[pp] = uc;
               } else {
                  /* general case */
                  lno = nn / MTFL_SIZE;
                  off = nn % MTFL_SIZE;
                  pp = s->mtfbase[lno] + off;
                  uc = s->mtfa[pp];
                  while (pp > s->mtfbase[lno]) {
                     s->mtfa[pp] = s->mtfa[pp-1]; pp--;
                  };
                  s->mtfbase[lno]++;
                  while (lno > 0) {
                     s->mtfbase[lno]--;
                     s->mtfa[s->mtfbase[lno]]
                        = s->mtfa[s->mtfbase[lno-1] + MTFL_SIZE - 1];
                     lno--;
                  }
                  s->mtfbase[0]--;
                  s->mtfa[s->mtfbase[0]] = uc;
                  if (s->mtfbase[0] == 0) {
                     kk = MTFA_SIZE-1;
                     for (ii = 256 / MTFL_SIZE-1; ii >= 0; ii--) {
                        for (jj = MTFL_SIZE-1; jj >= 0; jj--) {
                           s->mtfa[kk] = s->mtfa[s->mtfbase[ii] + jj];
                           kk--;
                        }
                        s->mtfbase[ii] = kk + 1;
                     }
                  }
               }
            }
            /*-- end uc = MTF ( nextSym-1 ) --*/

            s->unzftab[s->seqToUnseq[uc]]++;
            if (s->smallDecompress)
               s->ll16[nblock] = (xadUINT16)(s->seqToUnseq[uc]); else
               s->tt[nblock]   = (xadUINT32)(s->seqToUnseq[uc]);
            nblock++;

            GET_MTF_VAL(BZ_X_MTF_5, BZ_X_MTF_6, nextSym);
            continue;
         }
      }

      /* Now we know what nblock is, we can do a better sanity
         check on s->origPtr.
      */
      if (s->origPtr < 0 || s->origPtr >= nblock)
         RETURN(BZ_DATA_ERROR);

      s->state_out_len = 0;
      s->state_out_ch  = 0;
      BZ_INITIALISE_CRC ( s->calculatedBlockCRC );
      s->state = BZ_X_OUTPUT;

      /*-- Set up cftab to facilitate generation of T^(-1) --*/
      s->cftab[0] = 0;
      for (i = 1; i <= 256; i++) s->cftab[i] = s->unzftab[i-1];
      for (i = 1; i <= 256; i++) s->cftab[i] += s->cftab[i-1];

      if (s->smallDecompress) {

         /*-- Make a copy of cftab, used in generation of T --*/
         for (i = 0; i <= 256; i++) s->cftabCopy[i] = s->cftab[i];

         /*-- compute the T vector --*/
         for (i = 0; i < nblock; i++) {
            uc = (xadUINT8)(s->ll16[i]);
            SET_LL(i, s->cftabCopy[uc]);
            s->cftabCopy[uc]++;
         }

         /*-- Compute T^(-1) by pointer reversal on T --*/
         i = s->origPtr;
         j = GET_LL(i);
         do {
            xadINT32 tmp = GET_LL(j);
            SET_LL(j, i);
            i = j;
            j = tmp;
         }
            while (i != s->origPtr);

         s->tPos = s->origPtr;
         s->nblock_used = 0;
         if (s->blockRandomised) {
            BZ_RAND_INIT_MASK;
            BZ_GET_SMALL(s->k0); s->nblock_used++;
            BZ_RAND_UPD_MASK; s->k0 ^= BZ_RAND_MASK;
         } else {
            BZ_GET_SMALL(s->k0); s->nblock_used++;
         }

      } else {

         /*-- compute the T^(-1) vector --*/
         for (i = 0; i < nblock; i++) {
            uc = (xadUINT8)(s->tt[i] & 0xff);
            s->tt[s->cftab[uc]] |= (i << 8);
            s->cftab[uc]++;
         }

         s->tPos = s->tt[s->origPtr] >> 8;
         s->nblock_used = 0;
         if (s->blockRandomised) {
            BZ_RAND_INIT_MASK;
            BZ_GET_FAST(s->k0); s->nblock_used++;
            BZ_RAND_UPD_MASK; s->k0 ^= BZ_RAND_MASK;
         } else {
            BZ_GET_FAST(s->k0); s->nblock_used++;
         }

      }

      RETURN(BZ_OK);



    endhdr_2:

      GET_UCHAR(BZ_X_ENDHDR_2, uc);
      if (uc != 0x72) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_ENDHDR_3, uc);
      if (uc != 0x45) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_ENDHDR_4, uc);
      if (uc != 0x38) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_ENDHDR_5, uc);
      if (uc != 0x50) RETURN(BZ_DATA_ERROR);
      GET_UCHAR(BZ_X_ENDHDR_6, uc);
      if (uc != 0x90) RETURN(BZ_DATA_ERROR);

      s->storedCombinedCRC = 0;
      GET_UCHAR(BZ_X_CCRC_1, uc);
      s->storedCombinedCRC = (s->storedCombinedCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_CCRC_2, uc);
      s->storedCombinedCRC = (s->storedCombinedCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_CCRC_3, uc);
      s->storedCombinedCRC = (s->storedCombinedCRC << 8) | ((xadUINT32)uc);
      GET_UCHAR(BZ_X_CCRC_4, uc);
      s->storedCombinedCRC = (s->storedCombinedCRC << 8) | ((xadUINT32)uc);

      s->state = BZ_X_IDLE;
      RETURN(BZ_STREAM_END);

      default:  return BZ_SEQUENCE_ERROR;
   }

   return BZ_SEQUENCE_ERROR;

   save_state_and_return:

   s->save_i           = i;
   s->save_j           = j;
   s->save_t           = t;
   s->save_alphaSize   = alphaSize;
   s->save_nGroups     = nGroups;
   s->save_nSelectors  = nSelectors;
   s->save_EOB         = EOB;
   s->save_groupNo     = groupNo;
   s->save_groupPos    = groupPos;
   s->save_nextSym     = nextSym;
   s->save_nblockMAX   = nblockMAX;
   s->save_nblock      = nblock;
   s->save_es          = es;
   s->save_N           = N;
   s->save_curr        = curr;
   s->save_zt          = zt;
   s->save_zn          = zn;
   s->save_zvec        = zvec;
   s->save_zj          = zj;
   s->save_gSel        = gSel;
   s->save_gMinlen     = gMinlen;
   s->save_gLimit      = gLimit;
   s->save_gBase       = gBase;
   s->save_gPerm       = gPerm;

   return retVal;
}

/*---------------------------------------------------*/
static int BZ2_bzDecompressInit(bz_stream* strm, int verbosity, int small) {
   DState* s;

   if (strm == NULL) return BZ_PARAM_ERROR;
   if (small != 0 && small != 1) return BZ_PARAM_ERROR;
   if (verbosity < 0 || verbosity > 4) return BZ_PARAM_ERROR;

   s = BZALLOC( sizeof(DState) );
   if (s == NULL) return BZ_MEM_ERROR;
   s->strm                  = strm;
   strm->state              = s;
   s->state                 = BZ_X_MAGIC_1;
   s->bsLive                = 0;
   s->bsBuff                = 0;
   s->calculatedCombinedCRC = 0;
   strm->total_in_lo32      = 0;
   strm->total_in_hi32      = 0;
   strm->total_out_lo32     = 0;
   strm->total_out_hi32     = 0;
   s->smallDecompress       = (xadBOOL)small;
   s->ll4                   = NULL;
   s->ll16                  = NULL;
   s->tt                    = NULL;
   s->currBlockNo           = 0;
   s->verbosity             = verbosity;

   BZ2_MakeCRC32R(BZ2_crc32Table, 0x04C11DB7);

   return BZ_OK;
}


/*---------------------------------------------------*/
static void unRLE_obuf_to_output_FAST ( DState* s )
{
   xadUINT8 k1;

   if (s->blockRandomised) {

      while (XADTRUE) {
         /* try to finish existing run */
         while (XADTRUE) {
            if (s->strm->avail_out == 0) return;
            if (s->state_out_len == 0) break;
            *( (xadUINT8*)(s->strm->next_out) ) = s->state_out_ch;
            BZ_UPDATE_CRC ( s->calculatedBlockCRC, s->state_out_ch );
            s->state_out_len--;
            s->strm->next_out++;
            s->strm->avail_out--;
            s->strm->total_out_lo32++;
            if (s->strm->total_out_lo32 == 0) s->strm->total_out_hi32++;
         }

         /* can a new run be started? */
         if (s->nblock_used == s->save_nblock+1) return;


         s->state_out_len = 1;
         s->state_out_ch = s->k0;
         BZ_GET_FAST(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 2;
         BZ_GET_FAST(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 3;
         BZ_GET_FAST(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         BZ_GET_FAST(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         s->state_out_len = ((xadINT32)k1) + 4;
         BZ_GET_FAST(s->k0); BZ_RAND_UPD_MASK;
         s->k0 ^= BZ_RAND_MASK; s->nblock_used++;
      }

   } else {

      /* restore */
      xadUINT32        c_calculatedBlockCRC = s->calculatedBlockCRC;
      xadUINT8         c_state_out_ch       = s->state_out_ch;
      xadINT32         c_state_out_len      = s->state_out_len;
      xadINT32         c_nblock_used        = s->nblock_used;
      xadINT32         c_k0                 = s->k0;
      xadUINT32*       c_tt                 = s->tt;
      xadUINT32        c_tPos               = s->tPos;
      char*         cs_next_out          = s->strm->next_out;
      unsigned int  cs_avail_out         = s->strm->avail_out;
      /* end restore */

      xadUINT32       avail_out_INIT = cs_avail_out;
      xadINT32        s_save_nblockPP = s->save_nblock+1;
      unsigned int total_out_lo32_old;

      while (XADTRUE) {

         /* try to finish existing run */
         if (c_state_out_len > 0) {
            while (XADTRUE) {
               if (cs_avail_out == 0) goto return_notr;
               if (c_state_out_len == 1) break;
               *( (xadUINT8*)(cs_next_out) ) = c_state_out_ch;
               BZ_UPDATE_CRC ( c_calculatedBlockCRC, c_state_out_ch );
               c_state_out_len--;
               cs_next_out++;
               cs_avail_out--;
            }
            s_state_out_len_eq_one:
            {
               if (cs_avail_out == 0) {
                  c_state_out_len = 1; goto return_notr;
               };
               *( (xadUINT8*)(cs_next_out) ) = c_state_out_ch;
               BZ_UPDATE_CRC ( c_calculatedBlockCRC, c_state_out_ch );
               cs_next_out++;
               cs_avail_out--;
            }
         }
         /* can a new run be started? */
         if (c_nblock_used == s_save_nblockPP) {
            c_state_out_len = 0; goto return_notr;
         };
         c_state_out_ch = c_k0;
         BZ_GET_FAST_C(k1); c_nblock_used++;
         if (k1 != c_k0) {
            c_k0 = k1; goto s_state_out_len_eq_one;
         };
         if (c_nblock_used == s_save_nblockPP)
            goto s_state_out_len_eq_one;

         c_state_out_len = 2;
         BZ_GET_FAST_C(k1); c_nblock_used++;
         if (c_nblock_used == s_save_nblockPP) continue;
         if (k1 != c_k0) { c_k0 = k1; continue; };

         c_state_out_len = 3;
         BZ_GET_FAST_C(k1); c_nblock_used++;
         if (c_nblock_used == s_save_nblockPP) continue;
         if (k1 != c_k0) { c_k0 = k1; continue; };

         BZ_GET_FAST_C(k1); c_nblock_used++;
         c_state_out_len = ((xadINT32)k1) + 4;
         BZ_GET_FAST_C(c_k0); c_nblock_used++;
      }

      return_notr:
      total_out_lo32_old = s->strm->total_out_lo32;
      s->strm->total_out_lo32 += (avail_out_INIT - cs_avail_out);
      if (s->strm->total_out_lo32 < total_out_lo32_old)
         s->strm->total_out_hi32++;

      /* save */
      s->calculatedBlockCRC = c_calculatedBlockCRC;
      s->state_out_ch       = c_state_out_ch;
      s->state_out_len      = c_state_out_len;
      s->nblock_used        = c_nblock_used;
      s->k0                 = c_k0;
      s->tt                 = c_tt;
      s->tPos               = c_tPos;
      s->strm->next_out     = cs_next_out;
      s->strm->avail_out    = cs_avail_out;
      /* end save */
   }
}



/*---------------------------------------------------*/
static void unRLE_obuf_to_output_SMALL ( DState* s )
{
   xadUINT8 k1;

   if (s->blockRandomised) {

      while (XADTRUE) {
         /* try to finish existing run */
         while (XADTRUE) {
            if (s->strm->avail_out == 0) return;
            if (s->state_out_len == 0) break;
            *( (xadUINT8*)(s->strm->next_out) ) = s->state_out_ch;
            BZ_UPDATE_CRC ( s->calculatedBlockCRC, s->state_out_ch );
            s->state_out_len--;
            s->strm->next_out++;
            s->strm->avail_out--;
            s->strm->total_out_lo32++;
            if (s->strm->total_out_lo32 == 0) s->strm->total_out_hi32++;
         }

         /* can a new run be started? */
         if (s->nblock_used == s->save_nblock+1) return;


         s->state_out_len = 1;
         s->state_out_ch = s->k0;
         BZ_GET_SMALL(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 2;
         BZ_GET_SMALL(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 3;
         BZ_GET_SMALL(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         BZ_GET_SMALL(k1); BZ_RAND_UPD_MASK;
         k1 ^= BZ_RAND_MASK; s->nblock_used++;
         s->state_out_len = ((xadINT32)k1) + 4;
         BZ_GET_SMALL(s->k0); BZ_RAND_UPD_MASK;
         s->k0 ^= BZ_RAND_MASK; s->nblock_used++;
      }

   } else {

      while (XADTRUE) {
         /* try to finish existing run */
         while (XADTRUE) {
            if (s->strm->avail_out == 0) return;
            if (s->state_out_len == 0) break;
            *( (xadUINT8*)(s->strm->next_out) ) = s->state_out_ch;
            BZ_UPDATE_CRC ( s->calculatedBlockCRC, s->state_out_ch );
            s->state_out_len--;
            s->strm->next_out++;
            s->strm->avail_out--;
            s->strm->total_out_lo32++;
            if (s->strm->total_out_lo32 == 0) s->strm->total_out_hi32++;
         }

         /* can a new run be started? */
         if (s->nblock_used == s->save_nblock+1) return;

         s->state_out_len = 1;
         s->state_out_ch = s->k0;
         BZ_GET_SMALL(k1); s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 2;
         BZ_GET_SMALL(k1); s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         s->state_out_len = 3;
         BZ_GET_SMALL(k1); s->nblock_used++;
         if (s->nblock_used == s->save_nblock+1) continue;
         if (k1 != s->k0) { s->k0 = k1; continue; };

         BZ_GET_SMALL(k1); s->nblock_used++;
         s->state_out_len = ((xadINT32)k1) + 4;
         BZ_GET_SMALL(s->k0); s->nblock_used++;
      }

   }
}


/*---------------------------------------------------*/
static int BZ2_bzDecompress ( bz_stream *strm )
{
   DState* s;
   if (strm == NULL) return BZ_PARAM_ERROR;
   s = strm->state;
   if (s == NULL) return BZ_PARAM_ERROR;
   if (s->strm != strm) return BZ_PARAM_ERROR;

   while (XADTRUE) {
      if (s->state == BZ_X_IDLE) return BZ_SEQUENCE_ERROR;
      if (s->state == BZ_X_OUTPUT) {
         if (s->smallDecompress)
            unRLE_obuf_to_output_SMALL ( s ); else
            unRLE_obuf_to_output_FAST  ( s );
         if (s->nblock_used == s->save_nblock+1 && s->state_out_len == 0) {
            BZ_FINALISE_CRC ( s->calculatedBlockCRC );
            if (s->calculatedBlockCRC != s->storedBlockCRC)
               return BZ_DATA_ERROR;
            s->calculatedCombinedCRC
               = (s->calculatedCombinedCRC << 1) |
                    (s->calculatedCombinedCRC >> 31);
            s->calculatedCombinedCRC ^= s->calculatedBlockCRC;
            s->state = BZ_X_BLKHDR_1;
         } else {
            return BZ_OK;
         }
      }
      if (s->state >= BZ_X_MAGIC_1) {
         xadINT32 r = BZ2_decompress ( s );
         if (r == BZ_STREAM_END) {
            if (s->calculatedCombinedCRC != s->storedCombinedCRC)
               return BZ_DATA_ERROR;
            return r;
         }
         if (s->state != BZ_X_OUTPUT) return r;
      }
   }

   return BZ_SEQUENCE_ERROR;  /*NOTREACHED*/
}


/*---------------------------------------------------*/
static int BZ2_bzDecompressEnd  ( bz_stream *strm )
{
   DState* s;
   if (strm == NULL) return BZ_PARAM_ERROR;
   s = strm->state;
   if (s == NULL) return BZ_PARAM_ERROR;
   if (s->strm != strm) return BZ_PARAM_ERROR;

   if (s->tt   != NULL) BZFREE(s->tt);
   if (s->ll16 != NULL) BZFREE(s->ll16);
   if (s->ll4  != NULL) BZFREE(s->ll4);

   BZFREE(strm->state);
   strm->state = NULL;

   return BZ_OK;
}

/*-------------------------------------------------------------*/
/*--- end                                                   ---*/
/*-------------------------------------------------------------*/


/*--- XAD slave ---*/

/* memory support functions */

struct mh {
  struct mh *next;
  struct xadMasterBase *xad;
};

static struct mh *initmem(struct xadMasterBase *xadMasterBase) {
  struct mh *base = (struct mh *) xadAllocVec(XADM sizeof(struct mh), 0);
  if (base) {
    base->next = NULL;
    base->xad  = xadMasterBase;
  }
  return base;
}

static void *bzalloc(void *base, int a, int b) {
  struct xadMasterBase *xadMasterBase = ((struct mh *)base)->xad;
  struct mh *mem = (struct mh *) xadAllocVec(XADM (a*b) + sizeof(struct mh), 0);
  if (!mem) return NULL;
  mem->next = ((struct mh *)base)->next; /* link into list */
  ((struct mh *)base)->next = mem;
  return (void *) &mem[1];
}

static void bzfree(void *base, void *mem) {
  struct xadMasterBase *xadMasterBase = ((struct mh *)base)->xad;
  struct mh *m, *x, *o;

  if (!mem || !base) return;
  m = (struct mh *) mem;  m--; /* get correct address */
  for (o = ((struct mh *)base); (x = o->next); o = x) {
    if (x == m) {
      o->next = x->next;
      xadFreeObjectA(XADM (xadPTR)x, NULL);
      return;
    }
  }
}

#define BZ2_BUFSIZE (32*1024)

XADUNARCHIVE(bzip2) {
  struct mh *base;
  char *buf_in, *buf_out, once_before = 0;
  xadERROR err = XADERR_NOMEMORY;
  xadINT32 bzerr;
  bz_stream bzs;
  int size;

  /* initialise memory system */
  if ((base = initmem(xadMasterBase))) {
    bzs.opaque  = base;
    bzs.bzalloc = bzalloc;
    bzs.bzfree  = bzfree;

    /* allocate some buffers */
    buf_in  = bzalloc((void *)base, BZ2_BUFSIZE, 1);
    buf_out = bzalloc((void *)base, BZ2_BUFSIZE, 1);
    if (buf_in && buf_out) {
      /* force immediate read-in of data on first run only */
      bzs.avail_in = 0;

      /* always keep going - exit is only when demand passes EOF */
      do {
        /* initialise the decompression state */
        if ((bzerr = BZ2_bzDecompressInit(&bzs, 0, 0)) != BZ_OK) break;

        /* reset output buffer */
        bzs.avail_out = BZ2_BUFSIZE;
        bzs.next_out  = buf_out;

        while (bzerr == BZ_OK) {
          /* fill input buffer when empty */
          if (bzs.avail_in == 0) {
            size = ai->xai_InSize - ai->xai_InPos;
            if (size > BZ2_BUFSIZE) size = BZ2_BUFSIZE;

            if (size == 0) { /* normal exit point = EOF */
              err = XADERR_OK;
              break; /* bzerr == BZ_OK */
            }

            if ((err = xadHookAccess(XADM XADAC_READ, (xadUINT32) size, buf_in, ai))) break;
            bzs.next_in  = buf_in;
            bzs.avail_in = size;
          }

          /* do some more decompression */
          bzerr = BZ2_bzDecompress(&bzs);

          /* purge any output */
          if ((size = BZ2_BUFSIZE - bzs.avail_out) > 0) {
            if ((err = xadHookAccess(XADM XADAC_WRITE, (xadUINT32) size, buf_out, ai)))
              break;
            bzs.next_out  = buf_out;
            bzs.avail_out = BZ2_BUFSIZE;
          }
        }
        /* we have exited from the decrunch loop. Why? */
        switch (bzerr) {
        case BZ_STREAM_END:
          /* We've completed a stream. If random gibberish appears
           * after it, silently ignore that. */
          BZ2_bzDecompressEnd(&bzs);
          once_before = 1;
          break;
        case BZ_DATA_ERROR_MAGIC:
          err = once_before ? XADERR_OK : XADERR_ILLEGALDATA; break;
        case BZ_DATA_ERROR:
          err = XADERR_ILLEGALDATA; break;
        case BZ_MEM_ERROR:
          err = XADERR_NOMEMORY; break;
        case BZ_OK:
          break; /* set above! */
        default:
          err = XADERR_DECRUNCH; break;
        }
      } while (bzerr == BZ_STREAM_END);
      /* we reached the end of a stream. That's OK - just go round again
       * and decompress another stream
       */
    }
  }

  while (base) {
    struct mh *next = base->next;
    xadFreeObjectA(XADM (xadPTR)base, NULL);
    base = next;
  }

  return err;
}

XADRECOGDATA(bzip2) {
  return (xadBOOL) (
    /* check file header -- BZh1 to BZh9 */
    (data[0] == 'B') && (data[1] == 'Z') && (data[2] == 'h') &&
    ((data[3] >=  '1') && (data[3] <= '9')) &&

    (
     /* check first block header -- is it 0x314159265359 ? */
     ((data[4] == 0x31) && (data[5] == 0x41) && (data[6] == 0x59) &&
      (data[7] == 0x26) && (data[8] == 0x53) && (data[9] == 0x59)) ||

     /* or is it 0x177245385090 (empty file has been archived) ? */
     ((data[4] == 0x17) && (data[5] == 0x72) && (data[6] == 0x45) &&
      (data[7] == 0x38) && (data[8] == 0x50) && (data[9] == 0x90))
    ));
}

XADGETINFO(bzip2) {
  /* there's only one file in a bzip archive - the uncompressed data */
  struct xadFileInfo *fi;

  /* allocate a fileinfo structure */
  if (!(fi = (struct xadFileInfo *) xadAllocObjectA(XADM XADOBJ_FILEINFO, NULL)))
    return XADERR_NOMEMORY;

  fi->xfi_Flags = XADFIF_NODATE | XADFIF_NOUNCRUNCHSIZE | XADFIF_SEEKDATAPOS |
    XADFIF_NOFILENAME | XADFIF_XADSTRFILENAME | XADFIF_EXTRACTONBUILD;
  fi->xfi_CrunchSize  = ai->xai_InSize - 14;
  fi->xfi_Size        = 0;
  fi->xfi_DataPos     = 0;

  fi->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai,
                       XAD_EXTENSION, ".bz", XAD_EXTENSION, ".bz2",
                       XAD_EXTENSION, ".tbz;.tar", XAD_EXTENSION, ".tbz2;.tar",
                       TAG_DONE);

  /* fill in today's date */
  xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE, &fi->xfi_Date,
    TAG_DONE);

  return xadAddFileEntryA(XADM fi, ai, NULL);
}

#define BZIP2SFX_SEARCHSIZE (5000)

XADRECOGDATA(bzip2SFX) {
  if(data[0] == '#' && data[1] == '!') {
    int i;
    if (size < 17) return 0;
    if (size > BZIP2SFX_SEARCHSIZE) size = BZIP2SFX_SEARCHSIZE;
    size -= 10;
    for (i = 2; i < (int) size; i++) {
      const xadUINT8 *p = &data[i];
      if ((p[0] == 'B') && (p[1] == 'Z') && (p[2] == 'h') &&
          ((p[3] >=  '1') && (p[3] <= '9')) &&
          (((p[4] == 0x31) && (p[5] == 0x41) && (p[6] == 0x59) &&
            (p[7] == 0x26) && (p[8] == 0x53) && (p[9] == 0x59)) ||
           ((p[4] == 0x17) && (p[5] == 0x72) && (p[6] == 0x45) &&
            (p[7] == 0x38) && (p[8] == 0x50) && (p[9] == 0x90))
          )
         )
      {
        return 1;
      }
    }
  }
  return 0;
}

XADGETINFO(bzip2SFX) {
  xadUINT32 size = ai->xai_InSize;
  int i = 0, found = 0;
  xadUINT8 *buf;
  xadERROR err;

  if (size > BZIP2SFX_SEARCHSIZE) size = BZIP2SFX_SEARCHSIZE;

  if ((buf = (xadUINT8 *) xadAllocVec(XADM size, 0))) {
    if (!(err = xadHookAccess(XADM XADAC_READ, size, (xadPTR) buf, ai))) {
      size -= 10;
      /* search for bzip2 header */
      for (i = 2; i < (int) size; i++) {
        const xadUINT8 *p = &buf[i];
        if ((p[0] == 'B') && (p[1] == 'Z') && (p[2] == 'h') &&
            ((p[3] >=  '1') && (p[3] <= '9')) &&
            (((p[4] == 0x31) && (p[5] == 0x41) && (p[6] == 0x59) &&
              (p[7] == 0x26) && (p[8] == 0x53) && (p[9] == 0x59)) ||
             ((p[4] == 0x17) && (p[5] == 0x72) && (p[6] == 0x45) &&
              (p[7] == 0x38) && (p[8] == 0x50) && (p[9] == 0x90))
            )
           )
        {
          found = 1;
          break;
        }
      }
    }
    xadFreeObjectA(XADM (xadPTR) buf, 0);

    if (found) {
      if (!(err = bzip2_GetInfo(ai, xadMasterBase))) {
        ai->xai_FileInfo->xfi_DataPos = i;
        ai->xai_FileInfo->xfi_CrunchSize -= i;
      }
    }
  }
  else {
    err = XADERR_NOMEMORY;
  }
  return err;
}


XADCLIENT(bzip2SFX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  BZIP2_VERSION,
  BZIP2_REVISION,
  BZIP2SFX_SEARCHSIZE,
  XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_NOCHECKSIZE,
  XADCID_BZIP2SFX,
  "BZip2 SFX",
  /* client functions */
  XADRECOGDATAP(bzip2SFX),
  XADGETINFOP(bzip2SFX),
  XADUNARCHIVEP(bzip2),
  NULL
};

XADFIRSTCLIENT(bzip2) {
  XADNEXTCLIENTNAME(bzip2SFX),
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  BZIP2_VERSION,
  BZIP2_REVISION,
  14,
  XADCF_FILEARCHIVER | XADCF_FREEFILEINFO,
  XADCID_BZIP2,
  "BZip2",
  /* client functions */
  XADRECOGDATAP(bzip2),
  XADGETINFOP(bzip2),
  XADUNARCHIVEP(bzip2),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(bzip2)

#endif /* XADMASTER_BZIP2_C */
