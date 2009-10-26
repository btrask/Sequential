#ifndef XADMASTER_DMS_CANY
#define XADMASTER_DMS_C

/*  $Id: DMS.c,v 1.11 2006/06/01 06:55:03 stoecker Exp $
    DMS and related disk/file archiver clients

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>

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

//#define CRACK_PWD

/* This format seems to have really lots of problems. Append option
does not work correctly, because the crunching algorithm start data
seems to be handled wrong. ENCRYPTION over APPEND borders does not
work correctly as well. DIZ text sometimes are encrypted, sometimes
are not. Generally all is possible and all may fail. Hopefully there
are not too much archives out there doing such a strange defective
stuff. */

/* This client is lossely based (mainly decrunch stuff) on xDMS
source made by Andre R. de la Rocha. Thanks for your work. The code
has been made reentrant to fit requirements of shared libraries and
also lots of strange files are handled correctly now. Crunch Type
reinitialisation has been fixed as well. This client does not use
DMS header information (except password flag), but always the track
data. This should reduce influence of modified DMS files.

DIZ texts seem to use easy compression (NONE or RLE) always, so they
can be decompressed without decompressiong all the data before.
APPENDED files which use a password, where the normal file does
not use one, will fail. The other way round should work.
*/

/* FMS format:
- pre 2.04 FMS files contain file name in block DMSTRTYPE_FILENAME
- 2.04 format contains additionally information:
  LONGWORD      protection bits
  3 LONGWORDs   DateStamp structure
  xadUINT8      size of following text, if bit 7 is set, the text
                is a comment
[ xadUINT8      size of filename, when there was a comment]
*/

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("DMS 1.13 (31.05.2006)")

#define DMS_VERSION             1
#define DMS_REVISION            12
#define DMSSFX_VERSION          DMS_VERSION
#define DMSSFX_REVISION         DMS_REVISION
#define SDSSFX_VERSION          DMS_VERSION
#define SDSSFX_REVISION         DMS_REVISION

/****************************************************************************/

#define DMSINFO_NOZERO          (1<<0)
#define DMSINFO_ENCRYPT         (1<<1)
#define DMSINFO_APPENDS         (1<<2)
#define DMSINFO_BANNER          (1<<3)
#define DMSINFO_HIGHDENSITY     (1<<4)
#define DMSINFO_PC              (1<<5)
#define DMSINFO_DMS_DEVICE_FIX  (1<<6)
#define DMSINFO_REGIST_VERSION  (1<<7)
#define DMSINFO_DIZ             (1<<8)
/* InfoFlags seem to be valid for first part. Appended part may have
   other flags! */

#define DMSOSV_AMIGA_AGA        (1<<15)

#define DMSCPU_68000            0
#define DMSCPU_68010            1
#define DMSCPU_68020            2
#define DMSCPU_68030            3
#define DMSCPU_68040            4
#define DMSCPU_68060            5
#define DMSCPU_6086             6
#define DMSCPU_8088             7
#define DMSCPU_80188            8
#define DMSCPU_80186            9
#define DMSCPU_80286            10
#define DMSCPU_80386SX          11
#define DMSCPU_80386            12
#define DMSCPU_80486            13
#define DMSCPU_80586            14

#define DMSFPU_NONE             0
#define DMSFPU_68881            1
#define DMSFPU_68882            2
#define DMSFPU_8087             3
#define DMSFPU_80287SX          4
#define DMSFPU_80387            5

#define DMSMACH_UNKNOWN         0
#define DMSMACH_AMIGA           1
#define DMSMACH_PC              2
#define DMSMACH_ATARI           3
#define DMSMACH_MACINTOSH       4

#define DMSTYPE_UNKNOWN         0
#define DMSTYPE_AOS1OFS         1
#define DMSTYPE_AOS1FFS         2
#define DMSTYPE_AOS3INT         3
#define DMSTYPE_AOS3INTFFS      4
#define DMSTYPE_AOS3DIR         5
#define DMSTYPE_AOS3DIRFFS      6
#define DMSTYPE_FMS             7

#define DMSCOMP_NOCOMP          0
#define DMSCOMP_SIMPLE          1
#define DMSCOMP_QUICK           2
#define DMSCOMP_MEDIUM          3
#define DMSCOMP_DEEP            4
#define DMSCOMP_HEAVY1          5
#define DMSCOMP_HEAVY2          6

#define DMSCFLAG_NOINIT         (1<<0)
#define DMSCFLAG_HEAVY_C        (1<<1)
#define DMSCFLAG_HEAVYRLE       (1<<2)
#define DMSCFLAG_HEAVY2         (1<<3)  /* own flag */

#define DMSTRTYPE_DIZ           80
#define DMSTRTYPE_BANNER        -1
#define DMSTRTYPE_FILENAME      0x03E7
#define DMSTRTYPE_FILESTART     0x03E8

#define DMSPWD_USE      1
#define DMSPWD_NOUSE    2

struct DMSHeader {
  xadUINT8 DMSID[4];          /* "DMS!" */
  xadUINT8 ID[4];             /* " PRO" or "FILE" */
  xadUINT8 InfoFlags[4];      /* DMSINFO_ defines */
  xadUINT8 Date[4];           /* UNIX format */
  xadUINT8 LowTrack[2];
  xadUINT8 HighTrack[2];
  xadUINT8 PackedSize[4];
  xadUINT8 UnpackedSize[4];
  xadUINT8 OSVersion[2];      /* DMSOSV_ defines */
  xadUINT8 OSRevision[2];
  xadUINT8 CPU[2];            /* DMSCPU_ defines */
  xadUINT8 FPU[2];            /* DMSFPU_ defines */
  xadUINT8 Machine[2];        /* DMSMACH_ defines */
  xadUINT8 DiskType2[2];      /* DMSTYPE_ defines */
  xadUINT8 CPUSpeed[2];       /* multiplied (in 0.01 MHz) */
  xadUINT8 CreationTime[4];
  xadUINT8 CreatorVersion[2];
  xadUINT8 NeededVersion[2];
  xadUINT8 DiskType[2];       /* DMSTYPE_ defines */
  xadUINT8 CompMode[2];       /* DMSCOMP_ defines */
  xadUINT8 CheckSum[2];
  /* checksums exclude DMSID and checksum word itself */
};

struct DMSTrack {
  xadUINT8 TRID[2];        /* "TR" */
  xadUINT8 TrackNumber[2]; /* signed */
  xadUINT8 pad[2];
  xadUINT8 CMODE_Packed[2];
  xadUINT8 RuntimePacked[2];
  xadUINT8 UnpackedSize[2];
  xadUINT8 CFlag;
  xadUINT8 CModeTrk;       /* DMSCOMP_ defines */
  xadUINT8 UncrunchedCRC[2];
  xadUINT8 CrunchedCRC[2];
  xadUINT8 CheckSum[2];
};

#define DMSNC 510
#define DMSNPT 30
#define DMSN1 510
#define DMSOFFSET 253

#define DMSF            60              /* lookahead buffer size */
#define DMSTHRESHOLD    2
#define DMSN_BYTE       (256 - DMSTHRESHOLD + DMSF)     /* kinds of characters (character code = 0..DMSN_BYTE-1) */
#define DMST            (DMSN_BYTE * 2 - 1)             /* size of table */
#define DMSR            (DMST - 1)      /* position of root */
#define DMSMAX_FREQ     0x8000          /* DMSupdates tree when the */

struct DMSData {
  xadUINT32             bitbuf;
  xadSTRPTR             indata;
  xadUINT8              bitcount;
  xadUINT8              DidInit;
  xadUINT16             RTV_Medium;
  xadUINT8              Text[32768];
  /* the above are accessed by Medium decruncher and supplied as a short
    data structure from SDS SFX */

  xadUINT16             UsePwd;
  xadUINT16             PassCRC;
  xadUINT16             RTV_Pass; /* RunTimeVariable */
  xadUINT16             RTV_Quick;
  xadUINT16             RTV_Deep;
  xadUINT16             RTV_Heavy;
  xadUINT16             c_table[4096];
  xadUINT16             pt_table[256];
  xadUINT16             lastlen;
  xadUINT16             np;
  xadUINT16             left[2*DMSNC - 1];
  xadUINT16             right[2*DMSNC -1 + 9];
  xadUINT16             freq[DMST + 1];         /* d->frequency table */
  xadUINT16             prnt[DMST + DMSN_BYTE]; /* pointers to parent nodes, except for the */
                /* elements [DMST..DMST + DMSN_BYTE - 1] which are used to get */
                /* the positions of leaves corresponding to the codes. */
  xadUINT16             son[DMST];      /* pointers to child nodes (son[], son[] + 1) */

  xadUINT8              DidInitDEEP;
  xadUINT8              c_len[DMSNC];
  xadUINT8              pt_len[DMSNPT];
};

/****************************************************************************/

static const xadUINT32 DMS_mask_bits[25]={
  0x000000,0x000001,0x000003,0x000007,0x00000f,0x00001f,
  0x00003f,0x00007f,0x0000ff,0x0001ff,0x0003ff,0x0007ff,
  0x000fff,0x001fff,0x003fff,0x007fff,0x00ffff,0x01ffff,
  0x03ffff,0x07ffff,0x0fffff,0x1fffff,0x3fffff,0x7fffff,
  0xffffff
};

static const xadUINT8 DMS_d_code[256] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
    0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
    0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09,
    0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A,
    0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B,
    0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D,
    0x0E, 0x0E, 0x0E, 0x0E, 0x0F, 0x0F, 0x0F, 0x0F,
    0x10, 0x10, 0x10, 0x10, 0x11, 0x11, 0x11, 0x11,
    0x12, 0x12, 0x12, 0x12, 0x13, 0x13, 0x13, 0x13,
    0x14, 0x14, 0x14, 0x14, 0x15, 0x15, 0x15, 0x15,
    0x16, 0x16, 0x16, 0x16, 0x17, 0x17, 0x17, 0x17,
    0x18, 0x18, 0x19, 0x19, 0x1A, 0x1A, 0x1B, 0x1B,
    0x1C, 0x1C, 0x1D, 0x1D, 0x1E, 0x1E, 0x1F, 0x1F,
    0x20, 0x20, 0x21, 0x21, 0x22, 0x22, 0x23, 0x23,
    0x24, 0x24, 0x25, 0x25, 0x26, 0x26, 0x27, 0x27,
    0x28, 0x28, 0x29, 0x29, 0x2A, 0x2A, 0x2B, 0x2B,
    0x2C, 0x2C, 0x2D, 0x2D, 0x2E, 0x2E, 0x2F, 0x2F,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
    0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
};

static const xadUINT8 DMS_d_len[256] = {
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05, 0x05,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
};

/****************************************************************************/

static xadINT32 DMSUnpRLE(xadSTRPTR *res, xadUINT32 size, struct xadMasterBase *xadMasterBase)
{
  xadSTRPTR out, outstore, outend, in = *res;
  xadUINT16 n;
  xadUINT8 a,b;
  xadINT32 err = 0;

  if(!(out = outstore = (xadSTRPTR) xadAllocVec(XADM size+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  outend = out+size;

  while(out < outend && !err)
  {
    if((a = *(in++)) != 0x90)
      *(out++) = a;
    else if(!(b = *(in++)))
      *(out++) = a;
    else
    {
      a = *(in++);
      if(b == 0xFF)
      {
        n = *(in++);
        n = ((n<<8) + *(in++));
      }
      else
        n = b;
      if(out+n > outend)
        err = XADERR_ILLEGALDATA;
      else
      {
        if(!n)
          break;
        memset(out,a,n);
        out += n;
      }
    }
  }

  xadFreeObjectA(XADM *res, 0);
  *res = outstore;
  return err;
}

/****************************************************************************/

#define DMSGETBITS(n) ((xadUINT16)(d->bitbuf >> (d->bitcount-(n))))
#define DMSDROPBITS(n) {d->bitbuf &= DMS_mask_bits[d->bitcount-=(n)]; \
        while (d->bitcount<16) {d->bitbuf = (d->bitbuf << 8) | \
        *d->indata++;  d->bitcount += 8;}}

static void DMSinitbitbuf(xadSTRPTR in, struct DMSData *d)
{
  d->bitbuf = 0;
  d->bitcount = 0;
  d->indata = in;
  DMSDROPBITS(0);
}

static xadINT32 DMSUnpQUICK(xadSTRPTR *res, xadUINT32 size, struct DMSData *d, struct xadMasterBase *xadMasterBase)
{
  xadSTRPTR out, outstore, outend, in = *res;
  xadUINT16 i,j;
  xadINT32 err = 0;

  if(!(out = outstore = (xadSTRPTR) xadAllocVec(XADM size+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  d->DidInit = 0;       /* clear Init flag */

  DMSinitbitbuf(in, d);
  outend = out + size;
  while (out < outend)
  {
    if(DMSGETBITS(1))
    {
      DMSDROPBITS(1);
      *out++ = d->Text[d->RTV_Quick++ & 0xFF] = (xadUINT8) DMSGETBITS(8);
      DMSDROPBITS(8);
    }
    else
    {
      DMSDROPBITS(1);
      j = DMSGETBITS(2)+2;
      DMSDROPBITS(2);
      i = d->RTV_Quick - DMSGETBITS(8) - 1;
      DMSDROPBITS(8);
      if(j + out > outend)
        err = XADERR_ILLEGALDATA;
      else
        while(j--)
          *out++ = d->Text[d->RTV_Quick++ & 0xFF] = d->Text[i++ & 0xFF];
    }
  }
  d->RTV_Quick = (d->RTV_Quick+5) & 0xFF;

  xadFreeObjectA(XADM *res, 0);
  *res = outstore;
  return err;
}

/****************************************************************************/

static xadINT32 DMSUnpMEDIUM(xadSTRPTR *res, xadUINT32 size, struct DMSData *d, struct xadMasterBase *xadMasterBase)
{
  xadSTRPTR out, outstore, outend, in = *res;
  xadUINT16 i,j, c;
  xadINT32 err = 0;
  xadUINT8 u;

  if(!(out = outstore = (xadSTRPTR) xadAllocVec(XADM size+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  d->DidInit = 0;       /* clear Init flag */

  DMSinitbitbuf(in, d);
  outend = out + size;

  while(out < outend)
  {
    if(DMSGETBITS(1))
    {
      DMSDROPBITS(1);
      *out++ = d->Text[d->RTV_Medium++ & 0x3FFF] = (xadUINT8)DMSGETBITS(8);
      DMSDROPBITS(8);
    }
    else
    {
      DMSDROPBITS(1);
      c = DMSGETBITS(8);
      DMSDROPBITS(8);
      j = (xadUINT16) (DMS_d_code[c]+3);
      u = DMS_d_len[c];
      c = (xadUINT16) (((c << u) | DMSGETBITS(u)) & 0xff);
      DMSDROPBITS(u);
      u = DMS_d_len[c];
      c = (xadUINT16) ((DMS_d_code[c] << 8) | (((c << u) | DMSGETBITS(u)) & 0xff));
      DMSDROPBITS(u);
      i = (xadUINT16) (d->RTV_Medium - c - 1);

      if(j + out > outend)
        err = XADERR_ILLEGALDATA;
      else
        while(j--)
          *out++ = d->Text[d->RTV_Medium++ & 0x3FFF] = d->Text[i++ & 0x3FFF];
    }
  }
  d->RTV_Medium = (xadUINT16)((d->RTV_Medium+66) & 0x3FFF);

  xadFreeObjectA(XADM *res,0);
  *res = outstore;
  return err;
}

/****************************************************************************/

/* reconstruction of tree */
static void DMSreconst(struct DMSData *d)
{
  xadUINT16 i, j, k, f, l;

  /* collect leaf nodes in the first half of the table */
  /* and replace the d->freq by (d->freq + 1) / 2. */
  j = 0;
  for (i = 0; i < DMST; i++)
  {
    if(d->son[i] >= DMST)
    {
      d->freq[j] = (xadUINT16) ((d->freq[i] + 1) / 2);
      d->son[j] = d->son[i];
      j++;
    }
  }
  /* begin constructing tree by connecting d->sons */
  for(i = 0, j = DMSN_BYTE; j < DMST; i += 2, j++)
  {
    k = (xadUINT16) (i + 1);
    f = d->freq[j] = (xadUINT16) (d->freq[i] + d->freq[k]);
    for(k = (xadUINT16)(j - 1); f < d->freq[k]; k--)
      ;
    k++;
    for(l = j; l > k; --l)
    {
      d->freq[l] = d->freq[l-1];
      d->son[l] = d->son[l-1];
    }
    d->freq[k] = f;
    d->son[k] = i;
  }
  /* connect d->prnt */
  for(i = 0; i < DMST; i++)
  {
    if((k = d->son[i]) >= DMST)
      d->prnt[k] = i;
    else
      d->prnt[k] = d->prnt[k + 1] = i;
  }
}

/* increment d->frequency of given code by one, and update tree */
static void DMSupdate(xadUINT16 c, struct DMSData *d)
{
  xadUINT16 i, j, k, l;

  if(d->freq[DMSR] == DMSMAX_FREQ)
    DMSreconst(d);
  c = d->prnt[c + DMST];
  do
  {
    k = ++d->freq[c];

    /* if the order is disturbed, exchange nodes */
    if(k > d->freq[l = (xadUINT16)(c + 1)])
    {
      while(k > d->freq[++l])
        ;
      l--;
      d->freq[c] = d->freq[l];
      d->freq[l] = k;

      i = d->son[c];
      d->prnt[i] = l;
      if(i < DMST)
        d->prnt[i + 1] = l;

      j = d->son[l];
      d->son[l] = i;

      d->prnt[j] = c;
      if(j < DMST)
        d->prnt[j + 1] = c;
      d->son[c] = j;

      c = l;
    }
  } while((c = d->prnt[c]) != 0); /* repeat up to root */
}

static xadUINT16 DMSDecodeChar(struct DMSData *d)
{
  xadUINT16 c;

  c = d->son[DMSR];

  /* travel from root to leaf, */
  /* choosing the smaller child node (d->son[]) if the read bit is 0, */
  /* the bigger (d->son[]+1) if 1 */
  while(c < DMST)
  {
    c = d->son[c + DMSGETBITS(1)];
    DMSDROPBITS(1);
  }
  c -= DMST;
  DMSupdate(c, d);
  return c;
}

static xadUINT16 DMSDecodePosition(struct DMSData *d)
{
  xadUINT16 i, j, c;

  i = DMSGETBITS(8);
  DMSDROPBITS(8);
  c = (xadUINT16) (DMS_d_code[i] << 8);
  j = DMS_d_len[i];
  i = (xadUINT16) (((i << j) | DMSGETBITS(j)) & 0xff);
  DMSDROPBITS(j);

  return (xadUINT16) (c | i);
}

static xadINT32 DMSUnpDEEP(xadSTRPTR *res, xadUINT32 size, struct DMSData *d, struct xadMasterBase *xadMasterBase)
{
  xadSTRPTR out, outstore, outend, in = *res;
  xadUINT16 i,j, c;
  xadINT32 err = 0;

  if(!(out = outstore = (xadSTRPTR) xadAllocVec(XADM size+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  d->DidInitDEEP = d->DidInit = 0;      /* clear Init flag */

  DMSinitbitbuf(in, d);
  outend = out + size;

  while(out < outend)
  {
    c = DMSDecodeChar(d);
    if(c < 256)
      *out++ = d->Text[d->RTV_Deep++ & 0x3FFF] = (xadUINT8)c;
    else
    {
      j = (xadUINT16) (c - 255 + DMSTHRESHOLD);
      i = (xadUINT16) (d->RTV_Deep - DMSDecodePosition(d) - 1);
      if(j + out > outend)
        err = XADERR_ILLEGALDATA;
      else
        while (j--)
          *out++ = d->Text[d->RTV_Deep++ & 0x3FFF] = d->Text[i++ & 0x3FFF];
    }
  }

  d->RTV_Deep = (xadUINT16)((d->RTV_Deep+60) & 0x3FFF);

  xadFreeObjectA(XADM *res, 0);
  *res = outstore;
  return err;
}

/****************************************************************************/

struct DMSTableData {
  xadINT16              c;
  xadUINT16             n;
  xadUINT16             tblsiz;
  xadUINT16             len;
  xadUINT16             depth;
  xadUINT16             maxdepth;
  xadUINT16             avail;
  xadUINT16             codeword;
  xadUINT16             bit;
  xadUINT16     *       tbl;
  xadUINT16     TabErr;
  xadSTRPTR     blen;

  xadUINT16     *       left;  /* copy of data in DMSData */
  xadUINT16     *       right; /* copy of data in DMSData */
};

static xadUINT16 DMSmktbl(struct DMSTableData *t)
{
  xadUINT16 i=0;

  if(t->TabErr)
    return 0;

  if(t->len == t->depth)
  {
    while(++t->c < t->n)
      if(t->blen[t->c] == t->len)
      {
        i = t->codeword;
        t->codeword += t->bit;
        if(t->codeword > t->tblsiz)
        {
          t->TabErr=1;
          return 0;
        }
        while(i < t->codeword)
          t->tbl[i++] = (xadUINT16) t->c;
        return (xadUINT16) t->c;
      }
      t->c = -1;
      t->len++;
      t->bit >>= 1;
  }
  t->depth++;
  if(t->depth < t->maxdepth)
  {
    (void) DMSmktbl(t);
    (void) DMSmktbl(t);
  }
  else if(t->depth > 32)
  {
    t->TabErr = 2;
    return 0;
  }
  else
  {
    if((i = t->avail++) >= 2 * t->n - 1)
    {
      t->TabErr = 3;
      return 0;
    }
    t->left[i] = DMSmktbl(t);
    t->right[i] = DMSmktbl(t);
    if(t->codeword >= t->tblsiz)
    {
      t->TabErr = 4;
      return 0;
    }
    if(t->depth == t->maxdepth)
      t->tbl[t->codeword++] = i;
  }
  t->depth--;
  return i;
}

static xadUINT16 DMSmake_table(xadUINT16 nchar, xadUINT8 bitlen[], xadUINT16 tablebits, xadUINT16 table[],
struct DMSData *d)
{
  struct DMSTableData t;

  t.left = d->left;
  t.right = d->right;

  t.n = t.avail = nchar;
  t.blen = (xadSTRPTR) bitlen;
  t.tbl = table;
  t.tblsiz = (xadUINT16) (1 << tablebits);
  t.bit = (xadUINT16) (t.tblsiz / 2);
  t.maxdepth = (xadUINT16)(tablebits + 1);
  t.depth = t.len = 1;
  t.c = -1;
  t.codeword = 0;
  t.TabErr = 0;
  (void) DMSmktbl(&t);  /* left subtree */
  (void) DMSmktbl(&t);  /* right subtree */
  if(t.TabErr)
    return t.TabErr;
  if(t.codeword != t.tblsiz)
    return 5;
  return 0;
}

static xadUINT16 DMSdecode_c(struct DMSData *d)
{
  xadUINT16 i, j, m;

  j = d->c_table[DMSGETBITS(12)];
  if(j < DMSN1)
  {
    DMSDROPBITS(d->c_len[j]);
  }
  else
  {
    DMSDROPBITS(12);
    i = DMSGETBITS(16);
    m = 0x8000;
    do
    {
      if(i & m)
        j = d->right[j];
      else
        j = d->left[j];
      m >>= 1;
    } while (j >= DMSN1);
    DMSDROPBITS(d->c_len[j] - 12);
  }
  return j;
}

static xadUINT16 DMSdecode_p(struct DMSData *d)
{
  xadUINT16 i, j, m;

  j = d->pt_table[DMSGETBITS(8)];
  if(j < d->np)
  {
    DMSDROPBITS(d->pt_len[j]);
  }
  else
  {
    DMSDROPBITS(8);
    i = DMSGETBITS(16);
    m = 0x8000;
    do
    {
      if(i & m)
        j = d->right[j];
      else
        j = d->left[j];
      m >>= 1;
    } while (j >= d->np);
    DMSDROPBITS(d->pt_len[j] - 8);
  }

  if(j != d->np-1)
  {
    if(j > 0)
    {
      j = (xadUINT16)(DMSGETBITS(i=(xadUINT16)(j-1)) | (1 << (j-1)));
      DMSDROPBITS(i);
    }
    d->lastlen=j;
  }

  return d->lastlen;
}

static xadUINT16 DMSread_tree_c(struct DMSData *d)
{
  xadUINT16 i,n;

  n = DMSGETBITS(9);
  DMSDROPBITS(9);
  if(n > 0)
  {
    for(i=0; i<n; i++)
    {
      d->c_len[i] = (xadUINT8)DMSGETBITS(5);
      DMSDROPBITS(5);
    }
    for(i=n; i<510; i++)
      d->c_len[i] = 0;
    if(DMSmake_table(510,d->c_len,12,d->c_table, d))
      return 1;
  }
  else
  {
    n = DMSGETBITS(9);
    DMSDROPBITS(9);
    for(i=0; i<510; i++)
      d->c_len[i] = 0;
    for(i=0; i<4096; i++)
      d->c_table[i] = n;
  }
  return 0;
}

static xadUINT16 DMSread_tree_p(struct DMSData *d)
{
  xadUINT16 i,n;

  n = DMSGETBITS(5);
  DMSDROPBITS(5);
  if(n > 0)
  {
    for(i=0; i<n; i++)
    {
      d->pt_len[i] = (xadUINT8) DMSGETBITS(4);
      DMSDROPBITS(4);
    }
    for(i=n; i<d->np; i++)
    d->pt_len[i] = 0;
    if(DMSmake_table(d->np,d->pt_len,8,d->pt_table, d))
      return 1;
  }
  else
  {
    n = DMSGETBITS(5);
    DMSDROPBITS(5);
    for(i=0; i<d->np; i++)
      d->pt_len[i] = 0;
    for (i=0; i<256; i++)
      d->pt_table[i] = n;
  }
  return 0;
}

static xadINT32 DMSUnpHEAVY(xadSTRPTR *res, xadUINT32 size, xadUINT8 flags, struct DMSData *d, struct xadMasterBase *xadMasterBase)
{
  xadSTRPTR out, outstore, outend, in = *res;
  xadUINT16 i,j, c, bitmask;
  xadINT32 err = 0;

  if(!(out = outstore = (xadSTRPTR) xadAllocVec(XADM size+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  d->DidInit = 0;       /* clear Init flag */

  /*  Heavy 1 uses a 4Kb dictionary,  Heavy 2 uses 8Kb  */

  if(flags & DMSCFLAG_HEAVY2)
  {
    d->np = 15;
    bitmask = 0x1fff;
  }
  else
  {
    d->np = 14;
    bitmask = 0x0fff;
  }

  DMSinitbitbuf(in, d);
  outend = out + size;

  if(flags & DMSCFLAG_HEAVY_C)
  {
    if(DMSread_tree_c(d))
    {
      xadFreeObjectA(XADM outstore, 0);
      return 1;
    }
    if(DMSread_tree_p(d))
    {
      xadFreeObjectA(XADM outstore, 0);
      return 2;
    }
  }

  while(out < outend)
  {
    c = DMSdecode_c(d);
    if(c < 256)
      *out++ = d->Text[d->RTV_Heavy++ & bitmask] = (xadUINT8)c;
    else
    {
      j = (xadUINT16) (c - DMSOFFSET);
      i = (xadUINT16) (d->RTV_Heavy - DMSdecode_p(d) - 1);
      if(j + out > outend)
      {
        err = XADERR_ILLEGALDATA; break;
      }
      else
      {
        while(j--)
          *out++ = d->Text[d->RTV_Heavy++ & bitmask] = d->Text[i++ & bitmask];
      }
    }
  }

  xadFreeObjectA(XADM *res,0);
  *res = outstore;
  return err;

}

/****************************************************************************/
/*  track 80 is FILEID.DIZ, track 0xffff (-1) is Banner  */
/*  and track 0 with 1024 bytes only is a fake boot block with more advertising */

static xadINT32 testDMSTrack(struct DMSTrack *t, struct xadMasterBase *xadMasterBase)
{
  if(EndGetM16(t->TRID) != 0x5452)
    return XADERR_ILLEGALDATA;
  if(xadCalcCRC16(XADM XADCRC16_ID1, 0, sizeof(struct DMSTrack)-2,
  (xadUINT8 *)t) != EndGetM16(t->CheckSum))
    return XADERR_CHECKSUM;

  return 0;
}

static xadUINT16 CheckSumDMS(xadSTRPTR mem, xadUINT32 size)
{
  xadUINT16 u = 0;

  while(size--)
    u += *mem++;

  return u;
}

static void DecryptDMS(xadSTRPTR p, xadUINT32 size, struct DMSData *d)
{
  xadUINT16 t;

  while(size--)
  {
    t = (xadUINT16) *p;
    *p++ ^= (xadUINT8) d->RTV_Pass;
    d->RTV_Pass = (xadUINT16)((d->RTV_Pass >> 1) + t);
  }
}

static void DMSInitData(struct DMSData *d)
{
  d->RTV_Quick = 251;
  d->RTV_Medium = 0x3FBE;
  d->RTV_Deep = 0x3fc4;

  if(!d->DidInitDEEP)
  {
    xadUINT16 i, j;
    for(i = 0; i < DMSN_BYTE; i++)
    {
      d->freq[i] = 1;
      d->son[i] = (xadUINT16)(i + DMST);
      d->prnt[i + DMST] = i;
    }
    i = 0;
    j = DMSN_BYTE;
    while(j <= DMSR)
    {
      d->freq[j] = (xadUINT16) (d->freq[i] + d->freq[i + 1]);
      d->son[j] = i;
      d->prnt[i] = d->prnt[i + 1] = j;
      i += 2;
      j++;
    }
    d->freq[DMST] = 0xffff;
    d->prnt[DMSR] = 0;
  }

  d->DidInit = d->DidInitDEEP = 1;

  memset(d->Text,0,0x3fc8);
}

/* always make buffer 1 byte larger, which is filled with 0! */
static xadINT32 DecrunchDMS(struct DMSTrack *t, struct xadArchiveInfo *ai,
struct xadMasterBase *xadMasterBase, xadSTRPTR *res, struct DMSData *d)
{
  xadPTR inbuf;
  xadINT32 err;
  xadUINT16 cmode = EndGetM16(t->CMODE_Packed);
  xadUINT16 upsize = EndGetM16(t->UnpackedSize);
  xadUINT16 rtsize = EndGetM16(t->RuntimePacked);

  *res = 0;

  if(!(inbuf = xadAllocVec(XADM cmode+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  if((err = xadHookAccess(XADM XADAC_READ, cmode, inbuf, ai)))
  {
    xadFreeObjectA(XADM inbuf,0);
    return err;
  }

  *res = inbuf;

  if(d->UsePwd == DMSPWD_USE && d->PassCRC)
    DecryptDMS(inbuf, cmode, d);

  switch(t->CModeTrk)
  {
  case DMSCOMP_NOCOMP: break;
  case DMSCOMP_SIMPLE: err = DMSUnpRLE(res, upsize, xadMasterBase); break;
  case DMSCOMP_QUICK:
    if(!(err = DMSUnpQUICK(res, rtsize, d, xadMasterBase)))
      err = DMSUnpRLE(res, upsize, xadMasterBase);
    break;
  case DMSCOMP_MEDIUM:
    if(!(err = DMSUnpMEDIUM(res, rtsize, d, xadMasterBase)))
      err = DMSUnpRLE(res, upsize, xadMasterBase);
    break;
  case DMSCOMP_DEEP:
    if(!(err = DMSUnpDEEP(res, rtsize, d, xadMasterBase)))
      err = DMSUnpRLE(res, upsize, xadMasterBase);
    break;
  case DMSCOMP_HEAVY1: case DMSCOMP_HEAVY2:
    if(t->CModeTrk == DMSCOMP_HEAVY1)
      err = DMSUnpHEAVY(res, rtsize, t->CFlag & ~DMSCFLAG_HEAVY2, d, xadMasterBase);
    else
      err = DMSUnpHEAVY(res, rtsize, t->CFlag | DMSCFLAG_HEAVY2, d, xadMasterBase);
    if(t->CFlag & DMSCFLAG_HEAVYRLE && !err)
      err = DMSUnpRLE(res, upsize, xadMasterBase);
    break;
  default: err = XADERR_DECRUNCH; break;
  }

  if(!err && CheckSumDMS(*res, upsize) != EndGetM16(t->UncrunchedCRC))
  {
    /* try again without password */
    if(d->UsePwd == DMSPWD_USE && d->PassCRC && !(err = xadHookAccess(XADM XADAC_INPUTSEEK,
    -cmode, 0, ai)))
    {
      xadFreeObjectA(XADM *res, 0);
      d->UsePwd = DMSPWD_NOUSE;
      return DecrunchDMS(t, ai, xadMasterBase, res, d);
    }
    if(!err)
      err = d->UsePwd ? XADERR_PASSWORD : XADERR_CHECKSUM;
  }

  if(!(t->CFlag & DMSCFLAG_NOINIT) && !(d->DidInit))
    DMSInitData(d);

  if(err)
  {
    if(*res)
    {
      xadFreeObjectA(XADM *res, 0);
      *res= 0;
    }
  }

  return err;
}

static struct DMSData *GetDMSData(struct xadMasterBase *xadMasterBase, xadSTRPTR pwd)
{
  struct DMSData *d;
  if((d = (struct DMSData *) xadAllocVec(XADM sizeof(struct DMSData), XADMEMF_CLEAR)))
  {
    DMSInitData(d);
    if(pwd)
    {
#ifdef CRACK_PWD
      if(pwd[0] == '0' && pwd[1] == 'x')
        d->RTV_Pass = d->PassCRC = 0;
      else
#endif
      d->RTV_Pass = d->PassCRC = xadCalcCRC16(XADM XADCRC16_ID1, 0, strlen(pwd), (xadUINT8 *)pwd);
    }
  }
  return d;
}

/****************************************************************************/

XADRECOGDATA(DMS)
{
  if(EndGetM32(((struct DMSHeader *)data)->DMSID) == 0x444D5321 && xadCalcCRC16(XADM XADCRC16_ID1, 0,
  sizeof(struct DMSHeader)-6, (xadUINT8 *) ((xadSTRPTR)data)+4) == EndGetM16(((struct DMSHeader *)data)->CheckSum))
    return 1;
  else
    return 0;
}

/****************************************************************************/

/* Only the crypted information is used form DMS header. All the other
   information is taken from data directly, to allow these lots of
   modified headers. */

static struct xadDiskInfo *DMSOneArc(struct xadMasterBase *xadMasterBase,
struct xadArchiveInfo *ai, xadINT32 *more, xadINT32 crypted, xadINT32 *ret)
{
  struct xadDiskInfo *di;
  struct xadTextInfo *ti = 0, *ti2;
  struct DMSData *d;
  struct DMSTrack t;
  xadINT32 err = 0, stop = 0, tracksize = 0;
  xadINT32 lowcyl = -1, highcyl = -1;
  xadSTRPTR zerotxt = 0;
  xadUINT32 zerosize = 0;

  *more = 0;

  if((di = (struct xadDiskInfo *) xadAllocObject(XADM XADOBJ_DISKINFO, TAG_DONE)))
  {
    di->xdi_Flags |= XADDIF_SEEKDATAPOS;
    if((d = GetDMSData(xadMasterBase, ai->xai_Password)))
    {
      if(crypted)
        d->UsePwd = DMSPWD_USE;

      di->xdi_DataPos = ai->xai_InPos;

      while(!stop && !err && ai->xai_InPos < ai->xai_InSize)
      {
        if(xadHookAccess(XADM XADAC_READ, sizeof(struct DMSTrack), &t, ai))
          stop = 1;
        else
        {
          if(testDMSTrack(&t, xadMasterBase))
            stop = 2;   /* stop > 1 means seek back one Track */
          else
          {
            xadINT16 tr = EndGetM16(t.TrackNumber);
            xadUINT16 upsize = EndGetM16(t.UnpackedSize);
            if(zerotxt)
            {
              while(zerosize && !zerotxt[zerosize-1])
                --zerosize;
              if(tr != 1 && zerosize && zerosize <= 2048) /* was a information text */
              {
                highcyl = lowcyl = -1; /* reset these two */
                if((ti2 = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
                {
                  if(ti)
                    ti->xti_Next = ti2;
                  else
                    di->xdi_TextInfo = ti2;
                  ti = ti2;
                  if(!(ti2->xti_Text = (xadSTRPTR) xadAllocVec(XADM zerosize+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
                    err = XADERR_NOMEMORY;
                  else
                  {
                    ti2->xti_Size = zerosize;
                    xadCopyMem(XADM zerotxt, ti->xti_Text, zerosize);
                  }
                }
                else
                  err = XADERR_NOMEMORY;
              }
              xadFreeObjectA(XADM zerotxt,0);
              zerotxt = 0;
            }
            /* Normally only -1 is allowed as banner, but I found at least
               one file using -2. */
            if(tr < 0 || tr == DMSTRTYPE_DIZ || (!tr && upsize == 1024))
            {
              if((ti2 = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
              {
                if(tr == DMSTRTYPE_DIZ)
                  ti2->xti_Flags |= XADTIF_FILEDIZ;
                if(!DecrunchDMS(&t, ai, xadMasterBase, &ti2->xti_Text, d))
                  ti2->xti_Size = upsize;
                else if(crypted && !d->PassCRC)
                  ti2->xti_Flags |= XADTIF_CRYPTED;
                if(ti)
                  ti->xti_Next = ti2;
                else
                  di->xdi_TextInfo = ti2;
                ti = ti2;

                if(highcyl == -1)
                  di->xdi_DataPos = ai->xai_InPos;
              }
              else
                err = XADERR_NOMEMORY;
            }
            else
            {
              xadUINT16 cmode = EndGetM16(t.CMODE_Packed);
              if(highcyl == -1)
              {
                highcyl = lowcyl = tr;
                tracksize = upsize;
                /* store first track to extract */
/* FIXME - make real pointer! */
                di->xdi_PrivateInfo = (xadPTR)(uintptr_t) (ai->xai_InPos-sizeof(struct DMSTrack));
                if(!tr)
                {
                  zerosize = upsize;
                  if((DecrunchDMS(&t, ai, xadMasterBase, &zerotxt, d)))
                    zerotxt = 0;        /* ignore it */
                  continue;
                }
              }
              else if(tr != highcyl+1 || tracksize != upsize)
              {
                stop = 3; break;
              }
              else
                ++highcyl;

              if(d->UsePwd)
              {
                xadSTRPTR a;
                if(!(a = xadAllocVec(XADM cmode, XADMEMF_ANY)))
                  err = XADERR_NOMEMORY;
                else
                {
                  if(!(err = xadHookAccess(XADM XADAC_READ, cmode, a, ai)))
                    DecryptDMS(a, cmode, d);   /* to get a valid pwd pointer */
                  xadFreeObjectA(XADM a, 0);
                }
              }
              else
                err = xadHookAccess(XADM XADAC_INPUTSEEK, cmode, 0, ai);
            }
          } /* testDMSTrack */
        } /* xadHookAccess */
      } /* while */

      if(zerotxt) /* in case there is only one zero track and nothing else */
      {
        xadFreeObjectA(XADM zerotxt,0);
        zerotxt = 0;
      }

      if(stop > 1)
        err = xadHookAccess(XADM XADAC_INPUTSEEK, -sizeof(struct DMSTrack), &t, ai);

      if(!tracksize || lowcyl == -1 || highcyl == -1 || tracksize % (2*512))
        err = XADERR_ILLEGALDATA;
      else
      {
        if(crypted & DMSINFO_ENCRYPT)
          di->xdi_Flags |= XADDIF_CRYPTED;

        tracksize /= (2*512);

        di->xdi_LowCyl = lowcyl;
        di->xdi_HighCyl = highcyl;
        di->xdi_SectorSize = 512;
        di->xdi_Heads = 2;
        di->xdi_Cylinders = 80;
        switch(tracksize)
        {
        case 18: case 9:
          di->xdi_EntryInfo = "MSDOS disk"; /* no break! */
        case 22: case 11:
          di->xdi_TrackSectors = tracksize;
          break;
        default: err = XADERR_ILLEGALDATA; break;
        }
        di->xdi_CylSectors = 2 * di->xdi_TrackSectors;
        di->xdi_TotalSectors = 80 * di->xdi_CylSectors;
      }

      xadFreeObjectA(XADM d, 0);
    } /* GetDMSData */
    else
      err = XADERR_NOMEMORY;

    if(err)
    {
      for(ti = di->xdi_TextInfo; ti; ti = ti2)
      {
        ti2 = ti->xti_Next;
        if(ti->xti_Text)
          xadFreeObjectA(XADM ti->xti_Text, 0);
        xadFreeObjectA(XADM ti, 0);
      }
      xadFreeObjectA(XADM di, 0);
      di = 0;
    }
  } /* xadAllocObjectA */
  else
    err = XADERR_NOMEMORY;

  *ret = err;
  if(stop == 3 && !err)
    *more = 1;

  return di;
}

XADGETINFO(DMS)
{
  xadINT32 err = 0;
  struct DMSHeader h;
  struct DMSTrack t;
  struct xadFileInfo *fi;
  struct xadDiskInfo *di;
  xadUINT32 i, j;

  /* appended stuff is treated as own archive, as there may be gaps and double
     parts due to the chaotic file format of DMS. */

  while(!err && ai->xai_InPos < ai->xai_InSize &&
  !xadHookAccess(XADM XADAC_READ, sizeof(struct DMSHeader), &h, ai))
  {
    if(!testDMSTrack((struct DMSTrack *) &h, xadMasterBase))
      err = xadHookAccess(XADM XADAC_INPUTSEEK, sizeof(struct DMSTrack)+
      sizeof(struct DMSHeader)+EndGetM16(((struct DMSTrack *)&h)->CMODE_Packed), 0, ai);
    else
    {
      if(!DMS_RecogData(sizeof(struct DMSHeader), (xadPTR) &h, xadMasterBase))
        return 0;

      if(EndGetM32(h.InfoFlags) & DMSINFO_ENCRYPT)
        ai->xai_Flags |= XADAIF_CRYPTED;
      if(EndGetM16(h.DiskType2) == DMSTYPE_FMS || EndGetM16(h.DiskType) == DMSTYPE_FMS)
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct DMSTrack), &t, ai)) &&
        !(err = testDMSTrack(&t, xadMasterBase)) && EndGetM16(t.TrackNumber) == DMSTRTYPE_FILENAME)
        {
          if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
          XAD_OBJNAMESIZE, EndGetM16(t.UnpackedSize)+1, TAG_DONE)))
            return XADERR_NOMEMORY;
          if(!(err = xadHookAccess(XADM XADAC_READ, EndGetM16(t.UnpackedSize), fi->xfi_FileName, ai)))
          {
            i = ai->xai_InPos;
            j = 0;
            while(j < EndGetM32(h.UnpackedSize) && !err)
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct DMSTrack), &t, ai)) &&
              !(err = testDMSTrack(&t, xadMasterBase)))
              {
                if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM16(t.CMODE_Packed), 0, ai)))
                  j += EndGetM16(t.UnpackedSize);
              }
            }
            if(!err)
            {
              if(EndGetM32(h.InfoFlags) & DMSINFO_ENCRYPT)
                fi->xfi_Flags = XADFIF_CRYPTED;
              if(!fi->xfi_FileName[0]) /* This is a 2.04 FMS files */
              {
                struct FMSInfo {
                  xadUINT8 prot[4];
                  xadUINT8 date[12];
                  } inf;

                xadCopyMem(XADM fi->xfi_FileName, (xadPTR) &inf,
                sizeof(struct FMSInfo));
                fi->xfi_FileName += sizeof(struct FMSInfo);

                fi->xfi_Protection = EndGetM32(inf.prot);
                err = xadConvertDates(XADM XAD_DATEDATESTAMP, &inf.date,
                XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
                if(fi->xfi_FileName[0] & 0x80)
                {
                  fi->xfi_Comment = fi->xfi_FileName+1;
                  fi->xfi_FileName += (fi->xfi_FileName[0]&0x7F)+1;
                }
                *(fi->xfi_FileName++) = 0; /* clear size (make C pointer) */
              }
              else
                err = xadConvertDates(XADM XAD_DATEUNIX, EndGetM32(h.Date)-7*60*60,
                XAD_GETDATEXADDATE, &fi->xfi_Date, XAD_MAKELOCALDATE, 1, TAG_DONE);
              fi->xfi_DataPos = i;
              fi->xfi_Flags |= XADFIF_SEEKDATAPOS;
              fi->xfi_Size = EndGetM32(h.UnpackedSize);
              fi->xfi_CrunchSize = EndGetM32(h.PackedSize);
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
              fi = 0;
            }
          }
          if(fi)
            xadFreeObjectA(XADM fi, 0);
        }
      }
      else /* is a disk archive */
      {
        xadINT32 more = 1;

        while(more)
        {
          if((di = DMSOneArc(xadMasterBase, ai, &more, EndGetM32(h.InfoFlags) & DMSINFO_ENCRYPT, &err)))
            err = xadAddDiskEntry(XADM di, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
        }
      } /* DISK ARCHIVE */
    } /* found correct track */
    if(err)
    {
      ai->xai_Flags |= XADAIF_FILECORRUPT;
      ai->xai_LastError = err;
    }
  } /* while */

  return 0;
}

/****************************************************************************/

XADUNARCHIVE(DMS)
{
  struct DMSTrack t;
  xadINT32 i;
  xadINT32 err = 0;
  xadSTRPTR pwd = ai->xai_Password;
  struct DMSData *d;

#ifdef CRACK_PWD
  xadINT32 j=1, k;

  if((ai->xai_CurFile && !(ai->xai_CurFile->xfi_Flags & XADFIF_CRYPTED)) ||
  !(ai->xai_CurDisk->xdi_Flags & XADDIF_CRYPTED))
    pwd = 0;

  if(pwd && pwd[0] == '0' && pwd[1] == 'x')
  {
    xadUINT8 a;
    for(j = i = 0; i < 4; ++i)
    {
      a = pwd[2+i];
      if(a >= 'A' && a <= 'F') a = a-('A'-10);
      else if(a >= 'a' && a <= 'f') a = a-('a'-10);
      else if(a >= '0' && a <= '9') a = a-'0';
      j = (j<<4)+a;
    }
    pwd = 0;
  }

  k = ai->xai_InPos;
  do
  {
    err = 0;
    if(k != ai->xai_InPos)
      xadHookAccess(XADM XADAC_INPUTSEEK, k-ai->xai_InPos, 0, ai);
    if(ai->xai_OutPos)
      xadHookAccess(XADM XADAC_OUTPUTSEEK, -ai->xai_OutPos, 0, ai);
#else

  if((ai->xai_CurFile && !(ai->xai_CurFile->xfi_Flags & XADFIF_CRYPTED)) ||
  !(ai->xai_CurDisk->xdi_Flags & XADDIF_CRYPTED))
    pwd = 0;
  else if(!pwd)
    return XADERR_PASSWORD;
#endif

  if(!(d = GetDMSData(xadMasterBase, pwd)))
    return XADERR_NOMEMORY;

#ifdef CRACK_PWD
  if(!pwd)
  {
    d->RTV_Pass = d->PassCRC = j;
    if(!(j & 0xFF))
    {
      DebugClient(ai, "CRACKPWD %04lx", j);
    }
  }
  else
    j = d->PassCRC;
#endif

  if(ai->xai_CurFile)
  {
    struct xadFileInfo *fi;

    fi = ai->xai_CurFile;

    if(fi->xfi_Flags & XADFIF_CRYPTED)
      d->UsePwd = DMSPWD_USE;

    for(i = DMSTRTYPE_FILESTART; !err && ai->xai_OutSize < fi->xfi_Size; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct DMSTrack), &t, ai)) &&
      !(err = testDMSTrack(&t, xadMasterBase)))
      {
        xadSTRPTR res;

        if(i != EndGetM16(t.TrackNumber))
          err = XADERR_ILLEGALDATA;
        else if(!(err = DecrunchDMS(&t, ai, xadMasterBase, &res, d)))
        {
          err = xadHookAccess(XADM XADAC_WRITE, EndGetM16(t.UnpackedSize), res, ai);
          xadFreeObjectA(XADM res, 0);
        }
        else if((err == XADERR_PASSWORD) && i != DMSTRTYPE_FILESTART)
          err = XADERR_CHECKSUM; /* prevent wrong password errors */
      }
    }
  }
  else
  {
    struct xadDiskInfo *di;

    di = ai->xai_CurDisk;
    if(di->xdi_Flags & XADDIF_CRYPTED)
      d->UsePwd = DMSPWD_USE;

    for(i = ai->xai_LowCyl; !err && i <= ai->xai_HighCyl;)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct DMSTrack), &t, ai)) &&
      !(err = testDMSTrack(&t, xadMasterBase)))
      {
        xadSTRPTR res;

        if(!(err = DecrunchDMS(&t, ai, xadMasterBase, &res, d)))
        { /* xdi_PrivateInfo contains start pos of useful data */
          if(ai->xai_InPos > (xadUINT32)(uintptr_t) di->xdi_PrivateInfo) /* skip unusable parts */
          {
            if(i == EndGetM16(t.TrackNumber))
            {
              err = xadHookAccess(XADM XADAC_WRITE, EndGetM16(t.UnpackedSize), res, ai); ++i;
            }
            else if(EndGetM16(t.TrackNumber) > i)
              err = XADERR_ILLEGALDATA;
          }
          xadFreeObjectA(XADM res,0);
        }
        else if((err == XADERR_PASSWORD) && i != ai->xai_LowCyl)
          err = XADERR_CHECKSUM; /* prevent wrong password errors */
      }
    }
  }

  xadFreeObjectA(XADM d, 0);

#ifdef CRACK_PWD
  } while(++j < 65536 && err && !pwd);

  if(!err)
    DebugClient(ai,"Final Pass CRC is %04lx\n", --j);
#endif

  return err;
}

/****************************************************************************/

XADRECOGDATA(DMSSFX)
{
  if(EndGetM32(data) == 0x3F3 /*HUNK_HEADER*/)
  { /* DMS 2.03 file */
    if(EndGetM32(data+5*4) == 0x1605 && EndGetM32(data+6*4) == 0x1C24
    && EndGetM32(data+16*4) == 0x303C05CD && EndGetM32(data+17*4) == 0x421B51C8
    && EndGetM32(data+18*4) == 0xFFFC47F9)
      return 1;
    /* DMS 2.04 file - defective */
    if(EndGetM32(data+10*4) == 0x24E2 && EndGetM32(data+9*4) == 0x60000006
    && EndGetM32(data+11*4) == 0x48E77EFE && EndGetM32(data+12*4) == 0x24482400
    && EndGetM32(data+16*4) == 0x3B61425B)
      return 1;
    /* DMS 2.03, 2.04 disk */
    if(EndGetM32(data+11*4) == 0xABCD && EndGetM32(data+19*4) == 0x48E7FFF6
    && EndGetM32(data+20*4) == 0x61000030 && EndGetM32(data+21*4) == 0x4CDF6FFF)
      return 1;
  }
  return 0;
}

/****************************************************************************/

XADGETINFO(DMSSFX)
{
  xadINT32 err, offs = 0;
  xadUINT8 data[6*4];

  if(!(err = xadHookAccess(XADM XADAC_READ, 6*4, data, ai)))
  {
    switch(EndGetM32(data+5*4))
    {
    case 0x1605: offs = 0x58C4; break; /* DMS 2.03 file */
    case 0x2462: offs = 0x45D0; break; /* DMS 2.03 disk */
    case 0x2466: offs = 0x45E0; break; /* DMS 2.04 disk */
    case 0x3269: offs = 0x537C; break; /* DMS 2.04 file */
    default:
      err = XADERR_ILLEGALDATA;
    }
    if(!err && !(err = xadHookAccess(XADM XADAC_INPUTSEEK, offs-6*4, 0, ai)))
      err = DMS_GetInfo(ai, xadMasterBase);
  }

  return err;
}

/****************************************************************************/

XADRECOGDATA(SDSSFX)
{
  if(EndGetM32(data) == 0x3F3 /*HUNK_HEADER*/)
  {
    if(EndGetM32(data+15*4) == 0xFDD823C0 && EndGetM32(data+17*4) == 0x2C404EAE
    && EndGetM32(data+19*4) == 0x405A && EndGetM32(data+20*4) == 0x207C0000
    && EndGetM32(data+21*4) == 0x020C7600)
      return 1;
  }
  return 0;
}

struct SDSSFXData {
  xadUINT8 Name[20];
  xadUINT8 CrSize[4];
  xadUINT8 Size[4];
  xadUINT8 CheckSum[2];
};

XADGETINFO(SDSSFX)
{
  xadINT32 err, i, j;
  struct SDSSFXData sd;
  struct xadFileInfo *fi;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x41C, 0, ai)))
    return err;
  while(!err)
  {
    j = ai->xai_InPos;
    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct SDSSFXData), &sd, ai)))
    {
      if(!(i = strlen((char *)sd.Name)))
        break; /* last entry */
      else if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
      XAD_OBJNAMESIZE, i, TAG_DONE)))
      {
        fi->xfi_DataPos = j; /* file position */
        fi->xfi_Size = EndGetM32(sd.Size);
        fi->xfi_CrunchSize = EndGetM32(sd.CrSize);
        fi->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
        for(j = 0; j < i; ++j)
          fi->xfi_FileName[j] = sd.Name[j];
        xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
        &fi->xfi_Date, TAG_DONE);

        err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
      }
      else
        err = XADERR_NOMEMORY;
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? 0 : XADERR_ILLEGALDATA;
}

struct DMSDataShort {
  xadUINT32     bitbuf;
  xadSTRPTR     indata;
  xadUINT8      bitcount;
  xadUINT8      DidInit;
  xadUINT16     RTV_Medium;
  xadUINT8      Text[32768];
};

XADUNARCHIVE(SDSSFX)
{
  xadINT32 err;
  struct xadFileInfo *fi;
  struct SDSSFXData sd;

  fi = ai->xai_CurFile;
  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct SDSSFXData), &sd, ai)))
  {
    struct DMSData *d;

    if((d = (struct DMSData *) xadAllocVec(XADM sizeof(struct DMSDataShort), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      xadSTRPTR buf;

      if((buf = (xadSTRPTR) xadAllocVec(XADM fi->xfi_CrunchSize, XADMEMF_PUBLIC)))
      {
        d->RTV_Medium = 0x3FBE;

        if(!(err = xadHookAccess(XADM XADAC_READ, fi->xfi_CrunchSize, buf, ai)))
        {
          if(!(err = DMSUnpMEDIUM(&buf, fi->xfi_Size, d, xadMasterBase)))
          {
            if(CheckSumDMS(buf, fi->xfi_Size) == EndGetM16(sd.CheckSum))
              err = xadHookAccess(XADM XADAC_WRITE, fi->xfi_Size, buf, ai);
            else
              err = XADERR_CHECKSUM;
          }
        }
        xadFreeObjectA(XADM buf, 0);
      }
      else
        err = XADERR_NOMEMORY;
      xadFreeObjectA(XADM d, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  return err;
}

/****************************************************************************/

XADCLIENT(SDSSFX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SDSSFX_VERSION,
  SDSSFX_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_SDSSFX,
  "SDS Software SFX",
  XADRECOGDATAP(SDSSFX),
  XADGETINFOP(SDSSFX),
  XADUNARCHIVEP(SDSSFX),
  NULL
};

XADCLIENT(DMSSFX) {
  (struct xadClient *) &SDSSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DMSSFX_VERSION,
  DMSSFX_REVISION,
  100,
  XADCF_DISKARCHIVER|XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEDISKINFO|
    XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_DMSSFX,
  "DMS SFX",
  XADRECOGDATAP(DMSSFX),
  XADGETINFOP(DMSSFX),
  XADUNARCHIVEP(DMS),
  NULL
};

XADFIRSTCLIENT(DMS) {
  (struct xadClient *) &DMSSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DMS_VERSION,
  DMS_REVISION,
  sizeof(struct DMSHeader),
  XADCF_DISKARCHIVER|XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEDISKINFO|
    XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_DMS,
  "DMS",
  XADRECOGDATAP(DMS),
  XADGETINFOP(DMS),
  XADUNARCHIVEP(DMS),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(DMS)

#endif /* XADMASTER_DMS_C */
