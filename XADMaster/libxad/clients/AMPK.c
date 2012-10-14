#ifndef XADMASTER_AMPK_C
#define XADMASTER_AMPK_C

/*  $Id: AMPK.c,v 1.16 2005/06/23 14:54:40 stoecker Exp $
    AmiPack file archiver

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/


#include "../unix/xadClient.h"
#define XADIOGETBITSHIGH
#define XADIOGETBITSLOW
#define XADIOGETBITSLOWR
#define XADIOREADBITSLOW
#include "xadIO.c"
#include "xadIO_Compress.c"
#include "xadIO_XPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      13
#endif

XADCLIENTVERSTR("AMPK 1.16 (21.2.2004)")

#define AMPK_VERSION            1
#define AMPK_REVISION           16
#define AMPLUSUNPACK_VERSION    AMPK_VERSION
#define AMPLUSUNPACK_REVISION   AMPK_REVISION
#define LHWARP_VERSION          AMPK_VERSION
#define LHWARP_REVISION         AMPK_REVISION
#define COMPDISK_VERSION        AMPK_VERSION
#define COMPDISK_REVISION       AMPK_REVISION
#define COMPRESS_VERSION        AMPK_VERSION
#define COMPRESS_REVISION       AMPK_REVISION
#define ARC_VERSION             AMPK_VERSION
#define ARC_REVISION            AMPK_REVISION
#define ARCCBM_VERSION          AMPK_VERSION
#define ARCCBM_REVISION         AMPK_REVISION
#define ARCCBMSFX_VERSION       AMPK_VERSION
#define ARCCBMSFX_REVISION      AMPK_REVISION
#define WARP_VERSION            AMPK_VERSION
#define WARP_REVISION           AMPK_REVISION
#define SQ_VERSION              AMPK_VERSION
#define SQ_REVISION             AMPK_REVISION
#define CRUNCH_VERSION          AMPK_VERSION
#define CRUNCH_REVISION         AMPK_REVISION

#ifndef MAKE_ID
#define MAKE_ID(a, b, c, d) ((a << 24) | (b << 16) | (c << 8) | d)
#endif

#define xadIOPutFuncRLE90TYPE2 ((xadPTR) 0x80000000)
/* xx9000 --> xx90 */
/* xx90yy --> xx(yy times) */
/* io->xio_PutFuncPrivate may be initialized with 0x80000000 for Type 2 mode */
/* Type 2 mode: xx9001 --> xx90 instead of xx */
static xadUINT8 xadIOPutFuncRLE90(struct xadInOut *io, xadUINT8 data)
{
  xadUINT32 a, num;

  a = (xadUINT32)(uintptr_t) io->xio_PutFuncPrivate;

  if(a & 0x100) /* was RLE mode */
  {
    if(!data || (data == 1 && (a & 0x80000000))) { a = 0x90; num = 1; }
    else { a &= 0xFF; num = data-1; }
  }
  else if(data == 0x90) { num = 0; a |= 0x100; }
  else { num = 1; a = data; }

  io->xio_PutFuncPrivate = (xadPTR)(uintptr_t) a;

  while(num-- && !io->xio_Error)
  {
    if(!io->xio_OutSize && !(io->xio_Flags & XADIOF_NOOUTENDERR))
    {
      io->xio_Error = XADERR_DECRUNCH;
      io->xio_Flags |= XADIOF_ERROR;
    }
    else
    {
      if(io->xio_OutBufferPos >= io->xio_OutBufferSize)
        xadIOWriteBuf(io);
      io->xio_OutBuffer[io->xio_OutBufferPos++] = a;
      if(!--io->xio_OutSize)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }
  }

  return data;
}

#define xadIOPutFuncRLECBMSet(io,c,old) (io->xio_PutFuncPrivate = ((xadPTR)(uintptr_t) \
  (((old) ? 0x80000000 : 0)|((c)<<8))))
/* xxyyzz --> zz (yy times) */
/* xx00zz --> zz (255/256 times) */
/* xx is first character of stream */
/* io->xio_PutFuncPrivate may be initialized with 0x80000000 for old mode */
static xadUINT8 xadIOPutFuncRLECBM(struct xadInOut *io, xadUINT8 data)
{
  xadUINT32 a, num;

  a = (xadUINT32)(uintptr_t) io->xio_PutFuncPrivate;
  /* upper 16 bits == flags
       mid  8 bits == rle char
     lower  8 bits == count
  */

  num = 0;
  if(a & 0x40000) /* RLE + size found */
  {
    num = a&0xFF;
    if(!num) num = ((a & 0x80000000) ? 255 : 256);
    a &= ~(0x600FF); /* clear flags and size */
  }
  else if(a & 0x20000) /* RLE found */
    a |= 0x40000+data;
  else if(data == ((a>>8)&0xFF))
    a |= 0x20000;
  else
    num = 1;

  io->xio_PutFuncPrivate = (xadPTR)(uintptr_t) a;

  while(num-- && !io->xio_Error)
  {
    if(!io->xio_OutSize && !(io->xio_Flags & XADIOF_NOOUTENDERR))
    {
      io->xio_Error = XADERR_DECRUNCH;
      io->xio_Flags |= XADIOF_ERROR;
    }
    else
    {
      if(io->xio_OutBufferPos >= io->xio_OutBufferSize)
        xadIOWriteBuf(io);
      io->xio_OutBuffer[io->xio_OutBufferPos++] = data;
      if(!--io->xio_OutSize)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }
  }

  return data;
}

static void xadIOChecksum(struct xadInOut *io, xadUINT32 size)
{
  xadUINT32 s, i;

  s = (xadUINT32)(uintptr_t) io->xio_OutFuncPrivate;

  for(i = 0; i < size; i++)
    s += io->xio_OutBuffer[i];
  /* byte sum */

  io->xio_OutFuncPrivate  = (xadPTR)(uintptr_t) s;
}

/* AMPK1 ******************************************************************************************/

struct AMPK1Data {
  xadUINT8      datfield[0x1000];
  xadUINT16     Var7[314];      /* This separation mostly is a result */
  xadUINT16     Var8[314];      /* of reassembling and not a real need */
  xadUINT16     Var9[1];
  xadUINT16     Var10[314];
  xadUINT16     Var11[1];
  xadUINT16     Var12[314];
  xadUINT16     Var13[1];
  xadUINT16     Var14[1];
  xadUINT16     Var15[4095];
  xadUINT16     Var16[1];
};

static xadINT32 DecrAMPK1(struct xadInOut *io)
{
  xadUINT32 i, j, k = 0xFC4, l;
  xadUINT32 u = 0, v, w = 0x20000, r, s, t;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct AMPK1Data *dat;

  if(!(dat = (struct AMPK1Data *) xadAllocVec(XADM sizeof(struct AMPK1Data), XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  v = xadIOGetBitsHigh(io,17);

  for(i = 314; i; --i)
  {
    dat->Var7[i-1] = i;
    dat->Var8[i] = i-1;
    dat->Var10[i] = 1;
    dat->Var11[i] = dat->Var12[i] + dat->Var10[i];
  }
  for(i = 0x1000; i; --i)
    dat->Var13[i] = dat->Var14[i] + (10000 / (i + 200));

  memset(dat->datfield, ' ', k);

  while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
  {
    i = w - u;
    r = ((dat->Var12[0] * (v - u + 1))-1)/i;
    j = 1;
    s = 314;
    while(j < s)
    {
      t = (s + j)>>1;
      if(dat->Var12[t] > r)
        j = ++t;
      else
        s = t;
    } /* returns j */
    w = ((dat->Var11[j] * i) / dat->Var12[0]) + u;
    u += (i * dat->Var12[j]) / dat->Var12[0];

    for(;;)
    {
      if(u >= 0x10000)
      {
        u -= 0x10000; w -= 0x10000; v -= 0x10000;
      }
      else if(u >= 0x8000 && w <= 0x18000)
      {
        u -= 0x8000; w -= 0x8000; v -= 0x8000;
      }
      else if(w > 0x10000)
        break;

      u <<= 1; w <<= 1;
      v = (v<<1) + xadIOGetBitsHigh(io, 1);
    }

    i = dat->Var8[j];
    if(dat->Var12[0] >= 0x7FFF)
    {
      s = 0;
      for(r = 314; r; --r)
      {
        dat->Var12[r] = s;
        dat->Var10[r] = (dat->Var10[r] + 1)>>1;
        s += dat->Var10[r];
      }
      dat->Var12[0] = s;
    }

    for(r = j; dat->Var10[r] == dat->Var9[r]; --r)
      ;

    if(r < j)
    {
      s = dat->Var8[r];
      t = dat->Var8[j];
      dat->Var8[r] = t;
      dat->Var8[j] = s;
      dat->Var7[s] = j;
      dat->Var7[t] = r;
    }
    ++dat->Var10[r];

    while(r--)
      ++dat->Var12[r];

    if(i < 0x100)
    {
      dat->datfield[k++] = xadIOPutChar(io, i);
      k &= 0xFFF;
    }
    else
    {
      l = w - u;
      r = ((dat->Var14[0] * (v - u + 1)-1)/l);
      j = 1;
      s = 0x1000;
      while(j < s)
      {
        t = (s + j)>>1;
        if(dat->Var14[t] > r)
          j = ++t;
        else
          s = t;
      }
      --j; /* return j */
      w = ((dat->Var14[j] * l) / dat->Var14[0]) + u;
      u += (l * dat->Var15[j]) / dat->Var14[0];

      for(;;)
      {
        if(u >= 0x10000)
        {
          u -= 0x10000; w -= 0x10000; v -= 0x10000;
        }
        else if(u >= 0x8000 && w <= 0x18000)
        {
          u -= 0x8000; w -= 0x8000; v -= 0x8000;
        }
        else if(w > 0x10000)
          break;

        u <<= 1; w <<= 1;
        v = (v<<1) + xadIOGetBitsHigh(io, 1);
      }

      l = k - j - 1;
      i -= 253;
      for(j = 0; j < i; ++j)
      {
        dat->datfield[k++] = xadIOPutChar(io, dat->datfield[(l+j)&0xFFF]);
        k &= 0xFFF;
      }
    }
  }

  xadFreeObjectA(XADM dat, 0);

  return io->xio_Error;
}

/* AMPK2 ******************************************************************************************/

static xadINT32 DecrAMPK2(struct xadInOut *io)
{
  xadINT32 i = 0, k = 0xFEE, m, n;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadSTRPTR datfield;

  if(!(datfield = (xadSTRPTR) xadAllocVec(XADM 0x1000, XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  memset(datfield, ' ', k);

  while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
  {
    i >>= 1;
    if(!(i & 0x100))
      i = xadIOGetChar(io) | 0xFF00;

    if(i & 1)
    {
      datfield[k++] = xadIOPutChar(io, xadIOGetChar(io));
      k &= 0xFFF;
    }
    else
    {
      n = xadIOGetChar(io);
      m = xadIOGetChar(io);
      n |= ((m&0xF0)<<4);
      m = (m&0xF)+2;

      while(m-- >= 0)
      {
        datfield[k++] = xadIOPutChar(io, datfield[n++ & 0xFFF]);
        k &= 0xFFF;
      }
    }
  }

  xadFreeObjectA(XADM datfield, 0);

  return io->xio_Error;
}

/* AMPK3 - LZHUF **********************************************************************************/

#ifndef XADMASTERFILE
static const xadUINT8 AMPK3_d_code[256] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,
  10,10,10,10,10,10,10,10,11,11,11,11,11,11,11,11,
  12,12,12,12,13,13,13,13,14,14,14,14,15,15,15,15,
  16,16,16,16,17,17,17,17,18,18,18,18,19,19,19,19,
  20,20,20,20,21,21,21,21,22,22,22,22,23,23,23,23,
  24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,
  32,32,33,33,34,34,35,35,36,36,37,37,38,38,39,39,
  40,40,41,41,42,42,43,43,44,44,45,45,46,46,47,47,
  48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,
};

static const xadUINT8 AMPK3_d_len[256] = {
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
};
#else /* save space, as this is double used */
static const xadUINT8 DMS_d_code[256];
static const xadUINT8 DMS_d_len[256];
#define AMPK3_d_code    DMS_d_code
#define AMPK3_d_len     DMS_d_len
#endif

/* These defines need to reflect the largest values when thinking of
the field size (lowest threshold, highest lz_f and lz_n) */
#define AMPK3_LZ_N      4096
#define AMPK3_LZ_F      60
#define AMPK3_THRESHOLD 2

#define AMPK3_N_CHAR    (256 + 1 - AMPK3_THRESHOLD + AMPK3_LZ_F)
#define AMPK3_LZ_T      (AMPK3_N_CHAR * 2 - 1)  /* size of table */
#define AMPK3_LZ_R      (AMPK3_LZ_T - 1)  /* position of root */
#define AMPK3_MAX_FREQ  0x8000            /* updates tree when the */
                           /* root frequency comes to this value. */

struct AMPK3Data {
  xadUINT8      datfield[0x1000];
  xadUINT16     freq[AMPK3_LZ_T+1];
  xadUINT16     son[AMPK3_LZ_T];
  xadUINT16     parent[AMPK3_LZ_T+AMPK3_N_CHAR];
};

static xadINT32 DecrAMPK3(struct xadInOut *io, xadUINT32 type)
{
  xadUINT32 i, j, k, l, m, n, o;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct AMPK3Data *dat;
  xadUINT32 n_char, threshold, lz_t, lz_r, bitnum;

  switch(type)
  {
  case 2:
    threshold = 2;
    bitnum = 5;
    break;
  case 1:
    threshold = 2;
    bitnum = 6;
    break;
  default:
    threshold = 3;
    bitnum = 6;
    break;
  };

  n_char = 256 + 1 - threshold + AMPK3_LZ_F;
  lz_t = n_char * 2 - 1;
  lz_r = lz_t - 1;
  k = AMPK3_LZ_N-AMPK3_LZ_F;

  if(!(dat = (struct AMPK3Data *) xadAllocVec(XADM sizeof(struct AMPK3Data), XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  for(i = 0; i < n_char; ++i)
  {
    dat->freq[i] = 1;
    dat->son[i] = lz_t+i;
    dat->parent[lz_t+i] = i;
  }
  /* i already has correct value n_char */
  for(j = 0; i <= lz_r; ++i)
  {
    dat->freq[i] = dat->freq[j] + dat->freq[j+1];
    dat->son[i] = j;
    dat->parent[j] = dat->parent[j+1] = i;
    j += 2;
  }
  dat->freq[i] = AMPK3_MAX_FREQ;

  memset(dat->datfield, ' ', k);

  while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
  {
    i = dat->son[lz_r];
    while(i < lz_t)
      i = dat->son[i+xadIOGetBitsHigh(io, 1)];

    if(dat->freq[lz_r] == 0x8000)
    {
      j = 0;
      for(n = 0; n < lz_t; ++n)
      {
        if(dat->son[n] >= lz_t)
        {
          dat->freq[j] = (dat->freq[n] + 1) >> 1;
          dat->son[j++] = dat->son[n];
        }
      }

      n = 0;
      for(j = n_char; j < lz_t; ++j)
      {
        o = dat->freq[j] = dat->freq[n] + dat->freq[n+1];
        for(l = j-1; o < dat->freq[l]; --l)
          ;
        ++l;

        for(m = j-1; m >= l; --m)
          dat->freq[m+1] = dat->freq[m];
        dat->freq[l] = o;

        for(m = j-1; m >= l; --m)
          dat->son[m+1] = dat->son[m];
        dat->son[l] = n;
        n += 2;
      }

      for(n = 0; n < lz_t; ++n)
      {
        j = dat->son[n];
        dat->parent[j] = n;
        if(j < lz_t)
          dat->parent[j+1] = n;
      }
    }

    o = dat->parent[i];
    do
    {
      j = ++dat->freq[o];
      l = o+1;
      if(j > dat->freq[l])
      {
        while(j > dat->freq[l+1])
          ++l;

        dat->freq[o] = dat->freq[l];
        dat->freq[l] = j;

        j = dat->son[o];
        dat->parent[j] = l;
        if(j < lz_t)
          dat->parent[j+1] = l;

        m = dat->son[l];

        dat->son[l] = j;
        dat->parent[m] = o;
        if(m < lz_t)
          dat->parent[m+1] = o;

        dat->son[o] = m;

        o = l;
      }
      o = dat->parent[o];
    } while(o);

    i -= lz_t;
    if(i < 0x100)
    {
      dat->datfield[k++] = xadIOPutChar(io, i);
      k &= 0xFFF;
    }
    else if((io->xio_Flags & XADIOF_NOOUTENDERR) && i == 0x100) /* crunch end indicator */
      break;
    else
    {
      l = xadIOGetBitsHigh(io,8);
      m = AMPK3_d_len[l] - (8-bitnum);
      l = k - (AMPK3_d_code[l] << bitnum | (((l << m) | xadIOGetBitsHigh(io, m)) & ((1<<bitnum)-1))) - 1;
      i -= 256-threshold;
      for(j = 0; j < i; ++j)
      {
        dat->datfield[k++] = xadIOPutChar(io, dat->datfield[(l+j)&0xFFF]);
        k &= 0xFFF;
      }
    }
  }

  xadFreeObjectA(XADM dat, 0);

  return io->xio_Error;
}

/* ARC squeeze ************************************************************************************/

#define ARCSQSPEOF   256                /* special endfile token */
#define ARCSQNUMVALS 257                /* 256 data values plus SPEOF */

static xadINT32 ARCunsqueeze(struct xadInOut *io)
{
  xadINT32 err;
  struct xadMasterBase *xadMasterBase  = io->xio_xadMasterBase;
  xadINT32 i, numnodes;
  xadINT16 *node;

  if((node = (xadINT16 *) xadAllocVec(XADM 2*2*ARCSQNUMVALS, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    numnodes = xadIOGetBitsLow(io, 16);

    if(numnodes < 0 || numnodes >= ARCSQNUMVALS)
      err = XADERR_DECRUNCH;
    else
    {  /* initialize for possible empty tree (SPEOF only) */
      node[0] = node[1] = -(ARCSQSPEOF + 1);

      numnodes *= 2; i = 0;
      while(i < numnodes)       /* get decoding tree from file */
      {
        node[i++] = xadIOGetBitsLow(io, 16);
        node[i++] = xadIOGetBitsLow(io, 16);
      }

      do
      {
        /* follow bit stream in tree to a leaf */
        i = 0;
        while(i >= 0 && !io->xio_Error)
          i = node[2*i + xadIOGetBitsLow(io, 1)];

        i = -(i + 1); /* decode fake node index to original data value */

        if(i != ARCSQSPEOF)
          xadIOPutChar(io, i);
      } while(i != ARCSQSPEOF && !io->xio_Error);
      err = io->xio_Error;
    }
    xadFreeObjectA(XADM node, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/* CBM huffman ************************************************************************************/

struct CBMHuffmanData {
  xadUINT32 hc[256]; /* Huffman codes */
  xadUINT8 hl[256]; /* Lengths of huffman codes */
  xadUINT8 hv[256]; /* Character associated with Huffman code */
};

static xadINT32 CBMunhuff(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase  = io->xio_xadMasterBase;
  struct CBMHuffmanData *cd;

  if((cd = (struct CBMHuffmanData *) xadAllocVec(XADM sizeof(struct CBMHuffmanData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    xadINT32 hcount, i;

    hcount = 255;                                 /* Will be first code */
    for(i = 0; i < 256 && !io->xio_Error; ++i)    /* Fetch Huffman codes */
    {
      cd->hv[i] = i;
      cd->hl[i] = xadIOGetBitsLow(io, 5);
      if(cd->hl[i] > 24)
      {
        io->xio_Flags |= XADIOF_ERROR;
        io->xio_Error = XADERR_DECRUNCH;          /* Code too big */
      }
      else if(cd->hl[i])
        cd->hc[i] = xadIOGetBitsLow(io, cd->hl[i]);
      else
        --hcount;
    }
    if(!io->xio_Error)
    {
      xadINT32 h,j,k,m;
      xadUINT32 t;
      xadUINT8 u;

      m = sizeof(cd->hl);
      while(m >>= 1)
      {
        k = sizeof(cd->hl) - m;
        j = 1;
        do
        {
          i = j;
          do
          {
            h = i + m;
            if(cd->hl[h - 1] > cd->hl[i - 1])
            {
              t = cd->hc[i - 1]; cd->hc[i - 1] = cd->hc[h - 1]; cd->hc[h - 1] = t;
              u = cd->hv[i - 1]; cd->hv[i - 1] = cd->hv[h - 1]; cd->hv[h - 1] = u;
              u = cd->hl[i - 1]; cd->hl[i - 1] = cd->hl[h - 1]; cd->hl[h - 1] = u;
              i -= m;
            }
            else
              break;
          } while (i >= 1);
          j += 1;
        } while(j <= k);
      }
    }

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      xadINT32 hcode, size;

      hcode = size = 0;
      for(i = hcount; i >= 0; --i)
      {
        if(size != cd->hl[i])
          hcode = xadIOReadBitsLow(io,(size = cd->hl[i]));
        if(hcode == cd->hc[i])
        {
          xadIOPutChar(io, cd->hv[i]);
          xadIODropBitsLow(io, size);
          break;
        }
      }
      if(i < 0)
      {
        io->xio_Error = XADERR_DECRUNCH;
        io->xio_Flags |= XADIOF_ERROR;
      }
    }
    xadFreeObjectA(XADM cd, 0);
  }
  else
    io->xio_Error = XADERR_NOMEMORY;

  return io->xio_Error;
}

/* CBM pack ***************************************************************************************/

struct CBM_LZ /* Lempel Zev compression string table entry */
{
  xadUINT32 prefix;   /* Prefix code */
  xadUINT8 ext;   /* Extension character */
};

#define CBMLZTABLESIZE 4096
#define CBMLZSTACKSIZE 512
struct CBMLZData {
  struct CBM_LZ Table[CBMLZTABLESIZE]; /* Lempel Zev compression string table */
  xadUINT8  Stack[CBMLZSTACKSIZE];        /* Lempel Zev stack */
};

/* This is pretty straight forward if you have Terry Welch's article
 * "A Technique for High Performance Data Compression" from IEEE Computer
 * June 1984
 *
 * This implemention reserves code 256 to indicate the end of a crunched
 * file, and code 257 was reserved for future considerations. Codes grow
 * up to 12 bits and then stay there. There is no reset of the string
 * table.
 */
static xadINT32 CBMunpack(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase  = io->xio_xadMasterBase;
  struct CBMLZData *cd;

  if((cd = (struct CBMLZData *) xadAllocVec(XADM sizeof(struct CBMLZData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    xadINT32  lzstack = 0;  /* Lempel Zev stack pointer */
    xadINT32  cdlen = 9;    /* Current code size */
    xadINT32  code;         /* Last received code */
    xadINT32  wtcl = 256;   /* Bump cdlen when code reaches this value */
    xadINT32  wttcl = 254-1;/* Copy of wtcl */
    xadINT32  oldcode;
    xadINT32  incode;
    xadUINT8 finchar;
    xadINT32  ncodes = 258; /* Current # of codes in table */

    oldcode = xadIOGetBitsLowR(io, 9);

    if(oldcode != 256) /* Code 256 is EOF for this entry (a zero length file) */
    {
      finchar = xadIOPutChar(io, oldcode);

      while(!io->xio_Error)
      {
        incode = code = xadIOGetBitsLowR(io, cdlen);
        /* Get ready for next time */
        if((cdlen < 12))
        {
          if(!(--wttcl))
          {
            wtcl = wtcl << 1;
            cdlen++;
            wttcl = wtcl;
          }
        }
        if(incode == 256)
          break; /* end code */
        /* code 257 is reserved */
        else if(incode >= ncodes) /* Undefined code, special case */
        {
          cd->Stack[lzstack++] = finchar;
          code = oldcode;
          incode = ncodes;
        }
        while(code > 255) /* Decompose string */
        {
          if(lzstack >= CBMLZSTACKSIZE)
            io->xio_Error = XADERR_DECRUNCH;
          else
            cd->Stack[lzstack++] = cd->Table[code].ext;
          code = cd->Table[code].prefix;
        }
        xadIOPutChar(io, (finchar = code));
        while(lzstack)
          xadIOPutChar(io, cd->Stack[--lzstack]);
        if(ncodes < CBMLZTABLESIZE)
        {
          cd->Table[ncodes].prefix = oldcode;
          cd->Table[ncodes].ext = finchar;
          ncodes++;
        }
        oldcode = incode;
      }
    }

    xadFreeObjectA(XADM cd, 0);
  }
  else
    io->xio_Error = XADERR_NOMEMORY;

  return io->xio_Error;
}

/**************************************************************************************************/

XADRECOGDATA(AMPK)
{
  if(data[0] == 'A' && data[1] == 'M' && data[2] == 'P' && data[3] == 'K')
    return 1;
  else
    return 0;
}

struct AMPKHead {
  xadUINT8              ID[4];
  xadUINT8              FileVersion;
  xadUINT8              pad1;
  xadUINT8              NumDirs[2];     /* First entry is missing always! */
  xadUINT8              NumFiles[2];    /* Buggy format */
  xadUINT8              UnCrunchedSize[4];
  xadUINT8              CrunchedSize[4];
  xadUINT8              pad2;
  xadUINT8              pad3;
};

#define AMPKHead_TRUESIZE 20

#define AMPKENTRYTYPE_FILE      2
#define AMPKENTRYTYPE_NEWDIR    1
#define AMPKENTRYTYPE_LEAVEDIR  0

struct AMPKEntry {
  xadUINT8              Type;
  xadUINT8              NameSize;
  xadUINT8              DirSize[4];
  /* DirSite matches 3 bytes more than complete directory size
     including start node and leave node. */
};

#define AMPKEntry_TRUESIZE 6

/* Always followed by directory or file name. */

struct AMPKFile {
  xadUINT8              Size[4];
  xadUINT8              CrunchedSize[4];        /* wrong for crunchtype 0 (store) */
  xadUINT8              CrunchType;
  xadUINT8              pad1;
  xadUINT8              Protection[4];
  xadUINT8              pad2[2];
  xadUINT8              CommentSize;
  xadUINT8              pad3;
};
/* Always followed by comment (if there is one!). */

#define AMPKFile_TRUESIZE 18

static const xadSTRPTR ampktype[4] = {(xadSTRPTR)"stored", (xadSTRPTR)"medium", (xadSTRPTR)"fast", (xadSTRPTR)"slow"};

XADGETINFO(AMPK)
{
  xadUINT8 dirname[512];        /* never 0 terminated */
  xadINT32 err, i, dirnamesize = 0;
  xadUINT32 skip = 0;
  struct AMPKHead hd;
  struct AMPKEntry et;
  struct AMPKFile fl;
  struct xadFileInfo *fi;

  if((err = xadHookAccess(XADM XADAC_READ, AMPKHead_TRUESIZE, &hd, ai)))
    return err;

  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, AMPKEntry_TRUESIZE, &et, ai)))
    {
      /* Format has problems with stored file. When a file is stored as last entry
         in a directory, some useless stuff is stored behind it. */

      xadUINT32 dirSize = EndGetM32(et.DirSize);

      if(skip && (et.Type > AMPKENTRYTYPE_FILE ||
      (et.Type == AMPKENTRYTYPE_NEWDIR && dirSize >= 0x01000000) ||
      (et.Type != AMPKENTRYTYPE_NEWDIR && dirSize)))
      {
        if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, skip-AMPKEntry_TRUESIZE, 0, ai)))
        {
          if(ai->xai_InPos < ai->xai_InSize)
          {
            if(!(err = xadHookAccess(XADM XADAC_READ, AMPKEntry_TRUESIZE, &et, ai)))
            {
              if(et.Type || EndGetM32(et.DirSize)) /* a leave-dir node must follow */
                err = XADERR_ILLEGALDATA;
            }
          }
        }
      }

      skip = 0;
      if(!err && ai->xai_InPos < ai->xai_InSize)
      {
        switch(et.Type)
        {
        default: err = XADERR_ILLEGALDATA; break;
        case AMPKENTRYTYPE_LEAVEDIR:
          if(dirnamesize)
          {
            --dirnamesize;  /* skip last slash */
            while(dirnamesize && dirname[dirnamesize-1] != '/')
              dirnamesize--;
          }
          break;
        case AMPKENTRYTYPE_NEWDIR:
          if(!(err = xadHookAccess(XADM XADAC_READ, et.NameSize, dirname+dirnamesize, ai)))
          {
            dirnamesize += et.NameSize;
            if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
            XAD_OBJNAMESIZE, dirnamesize+1, TAG_DONE)))
            {
              fi->xfi_Flags = XADFIF_DIRECTORY|XADFIF_NODATE;
              xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
              &fi->xfi_Date, TAG_DONE);
              for(i = 0; i < dirnamesize; ++i)
                fi->xfi_FileName[i] = dirname[i];
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
            }
            else
              err = XADERR_NOMEMORY;
            dirname[dirnamesize++] = '/';
          }
          break;
        case AMPKENTRYTYPE_FILE:
          if(!(err = xadHookAccess(XADM XADAC_READ, et.NameSize, dirname+dirnamesize, ai)))
          {
            if(!(err = xadHookAccess(XADM XADAC_READ, AMPKFile_TRUESIZE, &fl, ai)))
            {
              xadUINT32 size = EndGetM32(fl.Size);
              xadUINT32 crunchedSize = EndGetM32(fl.CrunchedSize);
              xadUINT32 protection = EndGetM32(fl.Protection);
              if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
              XAD_OBJNAMESIZE, dirnamesize+et.NameSize+1,  fl.CommentSize ? XAD_OBJCOMMENTSIZE :
              TAG_DONE, fl.CommentSize+1, TAG_DONE)))
              {
                if(!fl.CommentSize || !(err = xadHookAccess(XADM XADAC_READ, fl.CommentSize, fi->xfi_Comment, ai)))
                {
                  fi->xfi_DataPos = ai->xai_InPos;
                  fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) fl.CrunchType;
                  fi->xfi_EntryInfo = ampktype[fl.CrunchType];
                  for(i = 0; i < dirnamesize + et.NameSize; ++i)
                    fi->xfi_FileName[i] = dirname[i];
                  fi->xfi_CrunchSize = fl.CrunchType ? crunchedSize : size;
                  fi->xfi_Size = size;
                  fi->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
                  xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
                  &fi->xfi_Date, TAG_DONE);
                  fi->xfi_Protection = protection;
                  skip = crunchedSize - fi->xfi_CrunchSize;
                  err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                }
                else
                  xadFreeObjectA(XADM fi, 0);
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
          break;
        } /* switch */
      }
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? 0 : XADERR_ILLEGALDATA;
}

XADUNARCHIVE(AMPK)
{
  xadINT32 err;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(!fi->xfi_PrivateInfo) /* private info is crunch type */
    err = xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else
  {
    struct xadInOut *io;

    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
    {
      io->xio_InSize = fi->xfi_CrunchSize;
      io->xio_OutSize = fi->xfi_Size;
      switch((xadUINT32)(uintptr_t)fi->xfi_PrivateInfo)
      {
      case 1: io->xio_Flags |= XADIOF_NOINENDERR; err = DecrAMPK1(io); break;
      case 2: err = DecrAMPK2(io); break;
      case 3: err = DecrAMPK3(io,0); break;
      default: err = XADERR_DATAFORMAT; break;
      }

      if(!err)
        err = xadIOWriteBuf(io);

      if(!err && io->xio_InSize)
        err = XADERR_DECRUNCH;

      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  return err;
}

/************************************************************************************************/

XADRECOGDATA(AmPlusUnpack)
{
  if(data[0] == 'F' && data[1] == 'O' && data[2] == 'R' && data[3] == 'M'
  && data[8] == 'A' && data[9] == 'P' && data[10] == 'U' && data[11] == 'P')
    return 1;
  else
    return 0;
}

/* This archiver uses a slightly modified IFF format, where chunks are used
in other chunk body. F.e. FILE is used in HELP, DATA or PACK and NAME is used
in file or DISK chunks. */

/* FILE chunks start with that header. The chunk size includes NAME entry. */
struct AmPlusUnpackData {
  xadUINT32 FileSize;
  xadUINT8  Date[12];
  xadUINT32 Protection;
};

/* DCYL chunk is missing in this client (never saw such a file). */

#define AMPLUSPACKMODE_INT      0
#define AMPLUSPACKMODE_XPK      1

/* PACK or DATA chunks start with a 10 Byte information header */
/* HELP chunk has same data format, but no header (starts directly with FILE) */
struct AmPlusDataHead {
  xadUINT16             type;   /* unknown*/
  xadUINT32             crsize; /* real value (maybe 1 less than size of body) */
  xadUINT32             crc;    /* always -1 for XPKF files, CRC is longword sum of file data */
};
/* PACK data either uses own algorithm or XPK */

/* VERS chunk contains of following structure: */
struct AmPlusVers {
  xadUINT32 Version;          /* Really 4 bytes? */
  xadUINT8  CreationDate[12]; /* its a DateStamp, but really creation date? */
};

/* PREF chunk contains of 6 unknown bytes */
/* DISK chunk contains of 2 unknown longwords followed by a NAME chunk for disk
   name - this name is inserted in SPECIAL info field of xadArchiveInfo. */
/* MKDR chunk contains the name of a directory to be created on that disk */

struct AmUnpackIFF {
  xadUINT32     ID;
  xadUINT32 Size;
};

struct AmUnpackPriv {
  xadUINT32 ID;
  xadUINT32 CRC;
  xadUINT16 Mode;
};

static const xadSTRPTR apuptype[2] = {(xadSTRPTR)"internal", (xadSTRPTR)"XPK"};

/* This Client does not scan all correct IFF file possibilities, but only
IFF-APUP file structures, which really exist. */
XADGETINFO(AmPlusUnpack)
{
  xadINT32 err;
  struct AmPlusUnpackData sd;
  struct AmPlusDataHead dh;
  struct AmUnpackIFF iff;
  struct xadFileInfo *fi;
  xadUINT32 id;
  xadUINT32 crsize = 0;

  dh.type = 0;
  dh.crc = 0;
  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 12, 0, ai)))
    return err;
  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmUnpackIFF), &iff, ai)))
    {
      id = iff.ID;
      switch(iff.ID)
      {
      default: err = XADERR_ILLEGALDATA; break;
      case MAKE_ID('V','E','R','S'):
      case MAKE_ID('D','I','S','K'):
      case MAKE_ID('P','R','E','F'):
        err = xadHookAccess(XADM XADAC_INPUTSEEK, iff.Size, 0, ai);
        break;
      case MAKE_ID('M','K','D','R'):
        if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        XAD_OBJNAMESIZE, iff.Size, TAG_DONE)))
        {
          fi->xfi_Flags = XADFIF_DIRECTORY|XADFIF_NODATE;
          xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
          &fi->xfi_Date, TAG_DONE);
          if(!(err = xadHookAccess(XADM XADAC_READ, iff.Size, fi->xfi_FileName, ai)))
            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
          else
            xadFreeObjectA(XADM fi, 0);
        }
        else
          err = XADERR_NOMEMORY;
        break;
      case MAKE_ID('P','A','C','K'):
      case MAKE_ID('D','A','T','A'):
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmPlusDataHead), &dh, ai)))
          crsize = dh.crsize;
      case MAKE_ID('H','E','L','P'):
        if(!err)
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmUnpackIFF), &iff, ai)))
          {
            if(iff.ID != MAKE_ID('F','I','L','E'))
            {
              err = XADERR_ILLEGALDATA;
            }
            else if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmPlusUnpackData), &sd, ai)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmUnpackIFF), &iff, ai)))
              {
                if(iff.ID != MAKE_ID('N','A','M','E'))
                {
                  err = XADERR_ILLEGALDATA;
                }
                else if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
                XAD_OBJNAMESIZE, iff.Size, XAD_OBJPRIVINFOSIZE, sizeof(struct AmUnpackPriv),
                TAG_DONE)))
                {
                  ((struct AmUnpackPriv *)fi->xfi_PrivateInfo)->ID = id;
                  if(!(err = xadHookAccess(XADM XADAC_READ, iff.Size, fi->xfi_FileName, ai)))
                  {
                    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct AmUnpackIFF), &iff, ai)))
                    {
                      fi->xfi_DataPos = ai->xai_InPos;
                      fi->xfi_Flags = XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
                      ((struct AmUnpackPriv *)fi->xfi_PrivateInfo)->Mode = dh.type;
                      fi->xfi_EntryInfo = apuptype[dh.type];
                      ((struct AmUnpackPriv *)fi->xfi_PrivateInfo)->CRC = dh.crc;
                      if(id == MAKE_ID('H','E','L','P'))
                      {
                        crsize = iff.Size;
                        fi->xfi_Flags |= XADFIF_INFOTEXT;
                      }
                      fi->xfi_CrunchSize = crsize;
                      xadConvertDates(XADM XAD_DATEDATESTAMP, &sd.Date, XAD_GETDATEXADDATE,
                      &fi->xfi_Date, TAG_DONE);
                      fi->xfi_Protection = sd.Protection;
                      fi->xfi_Size = sd.FileSize;
                      err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, (ai->xai_InPos + (iff.Size+1)) & ~1, TAG_DONE);
                    }
                    else
                      xadFreeObjectA(XADM fi, 0);
                  }
                  else
                    xadFreeObjectA(XADM fi, 0);
                }
                else
                  err = XADERR_NOMEMORY;
              }
            }
          }
        }
        break;
      } /* switch */
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? 0 : XADERR_ILLEGALDATA;
}

static void AmPlusUnpCalcChecksum(struct xadInOut *io, xadUINT32 size)
{
  xadUINT32 s, i;

  s = (xadUINT32)(uintptr_t) io->xio_OutFuncPrivate;

  for(i = 0; i < size; i++)
    s += io->xio_OutBuffer[i] << ((3 - (i&3)) << 3);
  /* longword sum, with remainder added at highest position */

  io->xio_OutFuncPrivate  = (xadPTR)(uintptr_t) s;
}

XADUNARCHIVE(AmPlusUnpack)
{
  xadINT32 err = 0;
  xadUINT32 i;
  struct AmUnpackPriv *up;
  struct xadFileInfo *fi;
  struct xadInOut *io;

  fi = ai->xai_CurFile;
  up = (struct AmUnpackPriv *) fi->xfi_PrivateInfo;

  if(up->ID == MAKE_ID('H','E','L','P'))
    return xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else if(up->ID == MAKE_ID('D','A','T','A'))
  {
    xadUINT32 bufsize, data, crc = 0;
    xadUINT32 * buf;

    data = fi->xfi_Size;

    if((bufsize = data+3) > 51200) /* +3 to get longword rounding */
      bufsize = 51200;
    if((buf = (xadUINT32 *) xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    {
      while(data && !err)
      {
        if(data < bufsize)
          bufsize = data;
        if(bufsize & 3)
          buf[bufsize>>2] = 0; /* clear last longword when necessary */
        if(!(err = xadHookAccess(XADM XADAC_READ, bufsize, buf, ai)))
        {
          for(i = 0; i < ((bufsize+3) >> 2); ++i)
            crc += buf[i];
          err = xadHookAccess(XADM XADAC_WRITE, bufsize, buf, ai);
        }
        data -= bufsize;
      }
      xadFreeObjectA(XADM buf, 0);
    }
    else
      err = XADERR_NOMEMORY;
    if(!err && crc != up->CRC)
      err = XADERR_CHECKSUM;

    return err;
  }

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
  |XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;

    switch(up->Mode)
    {
    case AMPLUSPACKMODE_XPK:
      err = xadIO_XPK(io, 0);
      break;
    case AMPLUSPACKMODE_INT:
      io->xio_OutFunc = AmPlusUnpCalcChecksum;
      err = DecrAMPK2(io);
      break;
    default:
      err = XADERR_DATAFORMAT;
      break;
    }
    if(!err)
      err = xadIOWriteBuf(io);

    if(!err && (up->Mode == AMPLUSPACKMODE_INT)
    && (xadUINT32)(uintptr_t) io->xio_OutFuncPrivate != up->CRC)
      err = XADERR_CHECKSUM;

    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/************************************************************************************************************************/

struct CompDisk {
  xadUINT8 ID[4];
  xadUINT32 Version;
  xadUINT32 Compression;
  xadUINT32 Flags;
};
/* Compression type 2 is either normal Lh (Zoom) or with SeqMax set to 59. */
/* Size then always (512+16)*22. */
/* CRC32 instead of CRC16 and either CRC of crunched or uncrunched data. */
/* Could not find out, what's correct, as sources showed differences. */

XADRECOGDATA(CompDisk)
{
  if(data[0] == 'C' && data[1] == 'O' && data[2] == 'M' && data[3] == 'P' &&
  !data[4] && !data[5] && !data[6] && data[7] == 5 && !data[8] && !data[9]
  && !data[10] && !data[11])
    return 1;
  else
    return 0;
}

XADGETINFO(CompDisk)
{
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_Cylinders = 80;
/*  xdi->xdi_LowCyl = 0; */
  xdi->xdi_HighCyl = 79;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_CylSectors = 22;
  xdi->xdi_Heads = 2;
  xdi->xdi_TotalSectors = 1760;
  xdi->xdi_Flags = XADDIF_SEEKDATAPOS|XADDIF_EXTRACTONBUILD;
  xdi->xdi_DataPos = sizeof(struct CompDisk);

  return xadAddDiskEntryA(XADM xdi, ai, 0);
}

static xadUINT16 MakeOlafCRC(xadUINT8 *Mem, xadINT32 Size)
{
  xadUINT16 CRC = 0, buf[256], i, j, k;

  for(i = 0; i < 256; ++i)
  {
    k = i << 8;

    for(j = 0; j < 8; ++j)
    {
      if(k & 0x8000)
        k = (k << 1) ^ 0x1021;
      else
        k <<= 1;
    }
    buf[i] = k;
  }

  while(Size--)
    CRC = buf[((CRC>>8) & 0xFF)] ^ ((CRC << 8) ^ *Mem++);

  return CRC;
}

XADUNARCHIVE(CompDisk)
{
  xadINT32 i, j, err = 0;
  xadSTRPTR buf, buf2, dat[6]; /* dat == xadUINT32 compsize, xadUINT16 crc16 */

  if((buf = (xadSTRPTR) xadAllocVec(XADM 512*22*2, XADMEMF_PUBLIC))) /* 2 buffers */
  {
    buf2 = buf + 512*22;
    /* skip entries */
    for(i = 0; !err && i < ai->xai_LowCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 6, &dat, ai)))
      {
        if(!(j = EndGetM32(dat)))
          j = 512*22;
        err = xadHookAccess(XADM XADAC_INPUTSEEK, j, 0, ai);
      }
    }

    for(; !err && i <= ai->xai_HighCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 6, &dat, ai)))
      {
        if(!(j = EndGetM32(dat)))
          err = xadHookAccess(XADM XADAC_READ, 512*22, buf, ai);
        else
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, j, buf2, ai)))
          {
            struct xadInOut *io;

            if((io = xadIOAlloc(XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
            {
              io->xio_InSize = io->xio_InBufferSize = j;
              io->xio_OutSize = io->xio_OutBufferSize = 512*22;
              io->xio_InBuffer = (xadUINT8 *)buf2;
              io->xio_OutBuffer = (xadUINT8 *)buf;

              if(!(err = xadIO_Compress(io, 12|UCOMPBLOCK_MASK)) && io->xio_OutSize)
                err = XADERR_DECRUNCH;
              xadFreeObjectA(XADM io,0);
            }
            else
              err = XADERR_NOMEMORY;
          }
        }
        if(!err)
        {
          if(MakeOlafCRC((xadUINT8 *)buf, 512*22) != EndGetM16(dat+4))
            err = XADERR_CHECKSUM;
          else
            err = xadHookAccess(XADM XADAC_WRITE, 512*22, buf, ai);
        }
      }
    }
    xadFreeObjectA(XADM buf, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/************************************************************************************************************************/

struct LhWarpHead {
  xadUINT8 version;
  xadUINT8 revision1;
  xadUINT8 revision2;
  xadUINT8 empty;
  xadUINT8 lowcyl[2];
  xadUINT8 highcyl[2];
  xadUINT8 textsize[4];
  xadUINT8 crtextsize[4];
  xadUINT8 filesize[4]; /* not for revision <= 2 files */
}; /* followed by crunched text */

#define LHWARPMETHOD_FREEZE      0
#define LHWARPMETHOD_STORED      1
#define LHWARPMETHOD_VAPORIZE    7
#define LHWARPMETHOD_SQUEEZE    10

struct LhWarpEntry {
  xadUINT8 method;
  xadUINT8 nodata;              /* set to 2 for empty blocks */
  xadUINT8 tracknum;
  xadUINT8 pad;
  xadUINT8 blocks[3];   /* [0] Bits 0..7 == blocks  1.. 7 */
                        /* [1] Bits 0..7 == blocks  8..15 */
                        /* [2] Bits 0..5 == blocks 16..22 */
  xadUINT8 oldmode;     /* not used by LhWarp */
  xadUINT8 datasize[4];
  xadUINT8 crsize[4];
  xadUINT8 crc32[4];
}; /* followed by data */

/* old mode is
  xadUINT8 pad1;
  xadUINT8 pad2;
  xadUINT8 tracknum;
  xadUINT8 pad3;
  xadUINT32 datasize;
  xadUINT32 crsize;
  xadUINT32 checksum;
*/

XADRECOGDATA(LHWARP)
{
  if(data[0] == 1 && data[1] <= 3 && data[2] <= 9 && !data[3] &&
  !data[4] && data[5] <= data[7] && !data[6] && data[7] <= 79 &&
  data[1] + data[2] > 0 && !data[8] && !data[9] &&
  EndGetM32(data+8) >= EndGetM32(data+12))
    return 1;
  else
    return 0;
}

XADGETINFO(LHWARP)
{
  xadINT32 err, cr, ucr;
  struct xadDiskInfo *xdi;
  struct LhWarpHead lhw;
  struct xadTextInfo *ti;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhWarpHead), &lhw, ai)))
  {
    if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
      err = XADERR_NOMEMORY;
    else
    {
      cr = EndGetM32(lhw.crtextsize);
      ucr = EndGetM32(lhw.textsize);
      if((xdi->xdi_PrivateInfo = (xadPTR)(uintptr_t) lhw.revision1))
        xdi->xdi_Flags |= XADDIF_SECTORLABELS;
      xdi->xdi_EntryNumber = 1;
      xdi->xdi_Cylinders = 80;
      xdi->xdi_LowCyl = EndGetM16(lhw.lowcyl);
      xdi->xdi_HighCyl = EndGetM16(lhw.highcyl);
      xdi->xdi_SectorSize = 512;
      xdi->xdi_TrackSectors = 11;
      xdi->xdi_CylSectors = 22;
      xdi->xdi_Heads = 2;
      xdi->xdi_TotalSectors = 1760;
      xdi->xdi_Flags |= XADDIF_SEEKDATAPOS;
      if(ucr && (lhw.revision1 == 3 || !xadHookAccess(XADM XADAC_INPUTSEEK, -4, 0, ai)))
      {
        if((ti = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
        {
          xadINT32 ok = 0;

          ti->xti_Size = ucr;
          if((ti->xti_Text = (xadSTRPTR) xadAllocVec(XADM ucr+1, XADMEMF_ANY|XADMEMF_CLEAR)))
          {
            struct xadInOut *io;

            if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16,
            ai, xadMasterBase)))
            {
              io->xio_InSize = cr;
              io->xio_OutSize = io->xio_OutBufferSize = ucr;
              io->xio_OutBuffer = (xadUINT8 *)ti->xti_Text;

              if(!DecrAMPK3(io,0))
                ok = 1;
              xadFreeObjectA(XADM io, 0);
            }
            if(!ok)
              xadFreeObjectA(XADM ti->xti_Text, 0);
          }
          if(!ok)
            xadFreeObjectA(XADM ti, 0);
          else
            xdi->xdi_TextInfo = ti;
        }
      }
      xdi->xdi_DataPos = sizeof(struct LhWarpHead)+cr;
      if(lhw.revision1 < 3)
        xdi->xdi_DataPos -= 4;

      err = xadAddDiskEntryA(XADM xdi, ai, 0);
    }
  }

  return err;
}

static xadINT32 LHWSave(xadSTRPTR data, struct LhWarpEntry *lhw, struct xadMasterBase *xadMasterBase,
struct xadArchiveInfo *ai)
{
  xadINT32 bits, i, j, endpos, blksize;
  bits = lhw->blocks[0]|(lhw->blocks[1]<<8)|(lhw->blocks[2]<<16);
  endpos = EndGetM32(lhw->datasize);
  blksize = 512+16;

  if(lhw->oldmode)
  {
    j = EndGetM32(lhw->datasize);
    for(i = endpos = 0; i < j; ++i)
      endpos += data[i];
    if(endpos != EndGetM32(lhw->crc32))
      return XADERR_CHECKSUM;
    bits = (1<<22)-1;
  }
  else if(xadCalcCRC32(XADM XADCRC32_ID1, 0, endpos, (xadUINT8 *) data) != EndGetM32(lhw->crc32))
    return XADERR_CHECKSUM;

  if(bits < (1<<22)-1) /* if equal, no copy necessary */
  {
    for(i = 21; i >= 0; --i)
    {
      if(bits&(1<<i))
      {
        endpos -= blksize;
        if(endpos != i*blksize)
          xadCopyMem(XADM data+endpos, data+(i*blksize), blksize);
      }
      else
        memset(data+(i*blksize), 0, blksize);
    }
  }

  if(!lhw->oldmode)
  {
    /* resort SectorLabels - we have an extra sectorlabel field at buffer end */
    for(i = 0; i < 22; ++i)
    {
      xadCopyMem(XADM data+(i*blksize)+512, data+(22*(512+16))+i*16, 16);
      xadCopyMem(XADM data+(i*blksize), data+(i*512), 512);
    }
  }

  return xadHookTagAccess(XADM XADAC_WRITE, 512*22, data, ai,
  lhw->oldmode ? TAG_DONE : XAD_SECTORLABELS, data+(22*(512+16)), TAG_DONE);
}

XADUNARCHIVE(LHWARP)
{
  xadINT32 i, j, l, err = 0, ofs = 0;
  struct LhWarpEntry lhw;
  struct xadInOut *io;
  xadSTRPTR data;

  if(!ai->xai_CurDisk->xdi_PrivateInfo)
  {
    ofs = 4;
    lhw.method = LHWARPMETHOD_FREEZE;
  }

  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhWarpEntry)-ofs, ((xadSTRPTR)&lhw)+ofs, ai)))
    {
      if(lhw.crsize)
        err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(lhw.crsize), 0, ai);
    }
  }

  if((data = xadAllocVec(XADM 22*(512+16) + 22*16, XADMEMF_PUBLIC))) /* including sector labels */
  {
    for(; !err && i <= ai->xai_HighCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhWarpEntry)-ofs, ((xadSTRPTR)&lhw)+ofs, ai)))
      {
        lhw.oldmode = ofs;
        j = EndGetM32(lhw.crsize);
        l = EndGetM32(lhw.datasize);
        if(l > 22*(512+16))
          err = XADERR_ILLEGALDATA;
        else if(l) /* ignore empty store blocks */
        {
          if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
          {
            io->xio_InSize = j;
            io->xio_OutSize = io->xio_OutBufferSize = l;
            io->xio_OutBuffer = (xadUINT8 *)data;

            switch(lhw.method)
            {
            case LHWARPMETHOD_STORED:
              while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
                xadIOPutChar(io, xadIOGetChar(io));
              err = io->xio_Error;
              break;
            case LHWARPMETHOD_VAPORIZE:
              if(!(err = xadIO_Compress(io, 14|UCOMPBLOCK_MASK)) && io->xio_OutSize)
                err = XADERR_DECRUNCH;
              break;
            case LHWARPMETHOD_FREEZE:
              err = DecrAMPK3(io,0);
              break;
            case LHWARPMETHOD_SQUEEZE:
              io->xio_PutFunc = xadIOPutFuncRLE90;
              err = ARCunsqueeze(io);
              break;
            default:
              err = XADERR_DATAFORMAT;
              break;
            }
            xadFreeObjectA(XADM io, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(!err)
          err = LHWSave(data, &lhw, xadMasterBase, ai);
      }
    }
    xadFreeObjectA(XADM data, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/************************************************************************************************************************/

/*
   00 - Archive version
        01 = original
        02 = extended header
   01 - Compression mode
        00 - Stored
        01 - Packed
        02 - Squeezed
        03 - Crunched (arc version 2 only)
        04 - Squeezed and packed (arc version 2 only)
        05 - Crunched in 1 pass (arc version 2 only)
02-03 - Checksum
04-06 - Original file size in bytes
        This value is not valid if the compression mode  (from
        above) is 5, a one pass crunch)
07-08 - Number of blocks compressed file takes (254 bytes/block)
   09 - Filetype ("P", "S",  "U",  "R",  uppercase  in  ASCII,
        lowercase in PETASCII )
   0A - Filename length
0B-0B+length - Filename (in PETASCII, no longer than  16  characters)
0B+length+1  - Relative file record length (only for arc version 2)
0B+length+2  - Date (2 bytes, in MSDOS format, only in arc vers. 2)

The header can also have some extra fields, depending on what version the
archive is. Version 1 archives do not have the RECORD length and DATE
fields, meaning they cannot contain REL files. The RECORD length is only
used when the filetype is REL.

Immediately following the filename (for version 1 archives) is the RLE
control byte, and then follows the LZ table and compressed data.
*/

static const xadSTRPTR arctypes[] = {
(xadSTRPTR)"stored", (xadSTRPTR)"stored", (xadSTRPTR)"packed", (xadSTRPTR)"squeezed", (xadSTRPTR)"crunched", (xadSTRPTR)"pack+crunch",
(xadSTRPTR)"fastpacked", (xadSTRPTR)"LZW packed", (xadSTRPTR)"squashed", (xadSTRPTR)"compressed"};

XADRECOGDATA(ArcCBM)
{
  if(data[0] == 1) /* ARC V1 header */
  {
    if(data[1] <= 2 /* Compression mode */
    && (data[9] == 'P' || data[9] == 'S' || data[9] == 'U') && /* type */
    (data[1] || ((EndGetI24(data+4)+253)/254 == EndGetI16(data+7)))) /* stored size */
      return 1;
  }
  else if(data[0] == 2) /* ARC V2 header */
  {
    if(data[1] <= 5 /* Compression mode */
    && (data[9] == 'P' || data[9] == 'S' || data[9] == 'U' || data[9] == 'R') && /* type */
    (data[1] || ((EndGetI24(data+4)+253)/254 == EndGetI16(data+7)))) /* stored size */
      return 1;
  }
  return 0;
}

/*  Header format
 *
 *  xadINT16  BASIC load address
 *  xadINT8   ????
 *  xadINT8   ????
 *  xadINT16  Line number
 *  xadINT8   Token 'SYS' = 0x9E
 *  xadINT8   '('
 *  BYTEs address in ASCII
 *  xadINT8   ')'
 */
XADRECOGDATA(ArcCBMSFX)
{
  if(size >= 254+11 && data[6] == 0x9E && data[7] == 0x28)
  {
    /* Calculate the start of the ARC data */
    xadUINT32 i;
    i = EndGetI16(data+4);
    i = (i == 15 && data[8] == '7') ? (15-6)*254-1 : (i-6)*254; /* i == 15: SDA232.128 */
    if(size >= i+11)
      return ArcCBM_RecogData(size-i,data+i,xadMasterBase);
  }
  return 0;
}

struct ArcCBMPrivate {
  xadUINT16 CRC;
  xadUINT8 Method;
  xadUINT8 Version;
};

#define ACBPI(a)        ((struct ArcCBMPrivate *) ((a)->xfi_PrivateInfo))

static xadINT32 ArcCBMScanSize(struct xadArchiveInfo *ai,
struct xadFileInfo *fi, xadUINT8 *data, struct xadMasterBase *xadMasterBase)
{
  xadINT32 i=0, err = 0;
  xadSTRPTR buf;
  xadUINT32 bufsize, fsize, pos;

  pos = ai->xai_InPos;
  fsize = ai->xai_InSize-ai->xai_InPos;
  bufsize = 254*50;
  if(!(buf = xadAllocVec(XADM bufsize+254*2, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  xadCopyMem(XADM data,buf+254,254); /* store the last 254 bytes */
  /* first 254*2 bytes store older buffer and not current data */
  while(!err && fsize >= 254)
  {
    if(fsize < bufsize)
      bufsize = fsize;
    fsize -= bufsize;
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize, buf+254*2, ai)))
    {
      for(i = 254*2; i < bufsize+254; i += 254)
      {
        if(buf[i] == 2 && buf[i+1] <= 5 && buf[i+10] <= 16
        && (buf[i+9] == 'P' || buf[i+9] == 'S' || buf[i+9] == 'U' ||
        buf[i+9] == 'R'))
        {
          fsize = 0;
          break;
        }
      }
      if(fsize)
      {
        xadCopyMem(XADM buf+bufsize,buf,254*2); /* store the last 2*254 bytes */
      }
    }
  }

  i -= 254*2;
  fi->xfi_CrunchSize += (ai->xai_InPos-pos)+254-bufsize+i;
  if(!fsize) /* find CRC and size */
  {
    xadINT32 j, k, l, m;
    xadUINT32 b, r=0;

    for(j = 254*2-1; j >= 254 && !buf[i+j]; --j)
      ; /* skip the empty chars */
    if(j >= 254)
    {
      b = (buf[i+j]<<16)+(buf[i+j-1]<<8)+(buf[i+j-2]);
      for(k = 0; k <= 10 && (b>>k) != 0x2608; ++k)
        ;
      if((b>>k) == 0x2608) /* we found the wanted information */
      {
        if(k >= 8)
        {
          k -= 8;
          ++j;
        }
        j -= 9;
        for(l = 0; l < 8; ++l)
        {
          b = buf[i+j++];
          for(m = 0; m < 8; ++m)
          {
            r = (r<<1)|(b&1);
            b >>= 1;
          }
          if(l == 4)
            ACBPI(fi)->CRC = (r>>(8-k))&0xFFFF;
          else if(l == 3+4)
          {
            fi->xfi_Size = (r>>(8-k))&0xFFFFFF;
            fi->xfi_Flags &= ~(XADFIF_NOUNCRUNCHSIZE);
          }
        }
      }
    }
  }

  xadFreeObjectA(XADM buf, 0);
  if(err)
    xadAddFileEntryA(XADM fi, ai,0);
  else
    err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos-bufsize+i,
    TAG_DONE);

  return err;
}

XADGETINFO(ArcCBM)
{
  xadUINT8 data[254]; /* One sector, minimum size of a compressed file with header */
  struct xadFileInfo *fi;
  struct xadSpecial *sp;
  xadINT32 err = XADERR_OK, blocksize, insize;

  while(!err && ai->xai_InPos < ai->xai_InSize-11)
  {
    /* Read archive header */
    if((insize = ai->xai_InSize-ai->xai_InPos) > sizeof(data))
      insize = sizeof(data);
    if(!(err = xadHookAccess(XADM XADAC_READ, insize, data, ai)))
    {
      if((data[0] == 1 || data[0] == 2) && data[1] <= 5 && data[10] <= 16) /* Valid header? */
      {
        if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        XAD_OBJPRIVINFOSIZE, sizeof(struct ArcCBMPrivate), TAG_DONE)))
        {
          fi->xfi_Flags = XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD|
                          XADFIF_XADSTRFILENAME;

          blocksize = EndGetI16(data+7)*254;
          fi->xfi_DataPos = ai->xai_InPos+11+data[10]-insize;
          if(data[0] == 2)
            fi->xfi_DataPos += 3;
          if(data[1] == 5) /* Original size invalid? */
            fi->xfi_Flags |= XADFIF_NOUNCRUNCHSIZE;
          else
            fi->xfi_Size = EndGetI24(data+4);

          if(!data[1]) /* File is stored: original size == crunched size */
            fi->xfi_CrunchSize  = fi->xfi_Size;
          else
            fi->xfi_CrunchSize = blocksize-11-data[10];

          fi->xfi_EntryInfo = arctypes[1+data[1]];

          ACBPI(fi)->Version = data[0];
          ACBPI(fi)->Method = data[1];
          ACBPI(fi)->CRC = EndGetI16(data+2);

          /* Set file date */
          xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
          &fi->xfi_Date, TAG_DONE);
          fi->xfi_Flags |= XADFIF_NODATE;
          /* The date information contained in ARC files is not very
             reliable and thus ignored. */

          fi->xfi_FileName = xadConvertName(XADM CHARSET_HOST,
          XAD_CHARACTERSET, CHARSET_C64, XAD_PATHSEPERATOR, 0,
          XAD_PSTRING, data+10, XAD_ERRORCODE, &err, TAG_DONE);

          if(fi->xfi_FileName)
          {
            /* Set Commodore specific file information */
            if((fi->xfi_Special = sp = (struct xadSpecial *)
            xadAllocObjectA(XADM XADOBJ_SPECIAL, 0)))
            {
              sp->xfis_Type=XADSPECIALTYPE_CBM8BIT;
              switch (data[9])
              {
              case 'P':
                sp->xfis_Data.xfis_CBM8bit.xfis_FileType=XADCBM8BITTYPE_PRG;
                break;
              case 'S':
                sp->xfis_Data.xfis_CBM8bit.xfis_FileType=XADCBM8BITTYPE_SEQ;
                break;
              case 'R':
                sp->xfis_Data.xfis_CBM8bit.xfis_FileType=XADCBM8BITTYPE_REL;
                sp->xfis_Data.xfis_CBM8bit.xfis_RecordLength=data[11+data[10]+1];
                break;
              case 'U':
                sp->xfis_Data.xfis_CBM8bit.xfis_FileType=XADCBM8BITTYPE_USR;
                break;
              default:
                sp->xfis_Data.xfis_CBM8bit.xfis_FileType=XADCBM8BITTYPE_UNKNOWN;
                break;
              }
              if(data[1] != 5) /* Mode 5? */
              {
                blocksize = ((blocksize+253)/254)*254 + ai->xai_InPos - insize;
                if(blocksize > ai->xai_InSize)
                  blocksize = ai->xai_InSize;
                err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, (xadSignSize)blocksize, TAG_DONE);
              }
              else
                err = ArcCBMScanSize(ai, fi, data, xadMasterBase); /* also does addentry */
            }
            else
            {
              xadFreeObjectA(XADM fi->xfi_FileName, 0);
              xadFreeObjectA(XADM fi, 0);
            }
          }
          else
            xadFreeObjectA(XADM fi, 0);
        }
        else
          err = XADERR_NOMEMORY;
      }
      else if(insize == sizeof(data) && !(data[0] == 0x1A
      || (data[0] == 0x20 && data[1] == 0x20 && data[2] == 0x20))) /* not at end */
        err = XADERR_ILLEGALDATA;
      else
        break;
    } /* read header */
  } /* loop */

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

XADGETINFO(ArcCBMSFX)
{
  xadINT8 data[9];
  xadINT32 i;

  /* Read the first 9 bytes of the file to calculate the start of the
     decompressor code */
  if((i = xadHookAccess(XADM XADAC_READ, 9, data, ai)))
    return i;

  i = EndGetI16(data+4);
  i = (i == 15 && data[8] == '7') ? (15-6)*254-1 : (i-6)*254; /* i == 15: SDA232.128 */

  if((i = xadHookAccess(XADM XADAC_INPUTSEEK, i-9, 0, ai)))
    return i;

  return ArcCBM_GetInfo(ai, xadMasterBase);
}

static void xadIOArcCRC(struct xadInOut *io, xadUINT32 size)
{
  xadUINT16 s;
  xadUINT8 s2;
  xadUINT32 i;

  s = (xadUINT16) (xadUINT32)(uintptr_t) io->xio_OutFuncPrivate;
  s2 = (xadUINT8) (((xadUINT32)(uintptr_t) io->xio_OutFuncPrivate) >> 16);

  for(i = 0; i < size; i++)
    s += io->xio_OutBuffer[i] ^ (++s2);

  io->xio_OutFuncPrivate  = (xadPTR)(uintptr_t) ((xadUINT32)s + (((xadUINT32)s2)<<16));
}

XADUNARCHIVE(ArcCBM)
{
  xadINT32 err = 0;
  struct xadFileInfo *fi;
  struct xadInOut *io;

  fi = ai->xai_CurFile;

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;
    io->xio_OutFunc = (ACBPI(fi)->Version == 1) ?
    xadIOChecksum : xadIOArcCRC;

    if(ACBPI(fi)->Method && ACBPI(fi)->Method != 2)
    {
      io->xio_PutFunc = xadIOPutFuncRLECBM;
      xadIOPutFuncRLECBMSet(io, ACBPI(fi)->Method == 1 ?
        xadIOGetChar(io) : 0xFE, ACBPI(fi)->Version == 1);
    }

    switch(ACBPI(fi)->Method)
    {
    case 0:
    case 1:
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        xadIOPutChar(io, xadIOGetChar(io));
      break;
    case 4:
    case 2:
      err = CBMunhuff(io);
      break;
    case 5:
    case 3:
      err = CBMunpack(io);
      break;
    default: err = XADERR_DATAFORMAT; break;
    }

    if(!err)
      err = xadIOWriteBuf(io);

    if(!err && ((xadUINT16)((uintptr_t)io->xio_OutFuncPrivate)) != ACBPI(fi)->CRC)
    {
      err = XADERR_CHECKSUM;
    }
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

/*
Warp archives max 160 entries, where every entry is a track side.
Head 0 is indicated by TOP, head 1 by BOT.

576172702076312E3100    Warp v1.1\0
0031                    Track number (example: 49)
424F5400                BOT\0 or TOP\0
0001                    Fileversion (Always 1)
0003                    Algorithmus 1 = Crunch, 2 = Squeeze, 3 = Pack
089A                    CRC16
000015F8                Crunched Size


576172702076312E3100
0000
544F5000
0002

3350                    * These 8 byte are inserted for type 2 block (MFM, IBM)
1880
5100
0000

0001
0CCB
00000BAB
*/

XADRECOGDATA(Warp)
{
  if(data[0] == 'W' && data[1] == 'a' && data[2] == 'r' && data[3] == 'p'
  && data[4] == ' ' && data[5] == 'v' && data[6] == '1' && data[7] == '.'
  && data[8] == '1' && !data[9] && !data[10] && !data[15] && data[13] == 'O'
  && !data[16] && data[17] == 1 && !data[18] && data[19] <= 3)
    return 1;
  else
    return 0;
}

XADGETINFO(Warp)
{
  xadUINT8 dat[26];
  xadINT32 err = 0;
  xadUINT32 low = 0, cur = 0, c, num = 1;
  struct xadDiskInfo *xdi = 0, *xdi2;

  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 26, dat, ai)))
    {
      if(Warp_RecogData(26, dat, xadMasterBase))
      {
        if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat+22), 0, ai)))
        {
          c = (dat[11] << 1) + (dat[12] == 'T' ? 0 : 1);
          if(!low || cur+1 != c)
          {
            if(!(xdi2 = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
              err = XADERR_NOMEMORY;
            else
            {
              if(xdi)
              {
                xdi->xdi_Next = xdi2; xdi->xdi_HighCyl = cur>>1;
              }
              else
                ai->xai_DiskInfo = xdi2;
              xdi = xdi2;

              xdi->xdi_EntryNumber = num++;
              xdi->xdi_SectorSize = 512;
              xdi->xdi_Cylinders = 80;
              xdi->xdi_Heads = 2;
              xdi->xdi_Flags = XADDIF_SEEKDATAPOS|XADDIF_SECTORLABELS;
              xdi->xdi_DataPos = ai->xai_InPos-26-EndGetM32(dat+22);
              xdi->xdi_TrackSectors = 11;
              xdi->xdi_CylSectors = 22;
              xdi->xdi_TotalSectors = 1760;
              if(dat[12] == 'T' && dat[11] <= 80)
              {
                cur = c; ++low;
                xdi->xdi_LowCyl = dat[11];
              }
              else
                err = XADERR_ILLEGALDATA;
            }
          }
          else
            cur = c;
        }
      }
      else
        err = XADERR_ILLEGALDATA;
    }
  }

  if(xdi)
    xdi->xdi_HighCyl = cur>>1;

  if((ai->xai_LastError = err))
    ai->xai_Flags |= XADAIF_FILECORRUPT;

  return low ? 0 : err;
}

XADUNARCHIVE(Warp)
{
  xadUINT32 i, j;
  xadINT32 err = 0;
  xadUINT8 dat[34];
  struct xadInOut *io;
  xadSTRPTR inbuf, outbuf;

  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    for(j = 0; !err && j < 2; ++j)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 34, dat, ai)))
        err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat+22), 0, ai);
    }
  }

  if((inbuf = (xadSTRPTR) xadAllocVec(XADM (512+16)*11*2, XADMEMF_PUBLIC)))
  {
    outbuf = inbuf+((512+16)*11);

    for(; !err && i <= ai->xai_HighCyl; ++i)
    {
      for(j = 0; !err && j < 2; ++j)
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, 26, dat, ai)))
        {
          if((io = xadIOAlloc(XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
          {
            if(dat[19])
              io->xio_PutFunc = xadIOPutFuncRLE90;
            io->xio_InBuffer = (xadUINT8 *)inbuf;
            io->xio_OutBuffer = (xadUINT8 *)outbuf;
            io->xio_OutSize = io->xio_OutBufferSize = (512+16)*11;
            io->xio_InSize = io->xio_InBufferSize = io->xio_InBufferPos = EndGetM32(dat+22);

            switch(dat[19])
            {
            case 1:
              if(!xadIOGetChar(io) == 12)
                err = XADERR_DECRUNCH;
              else
                err = xadIO_Compress(io, 12|UCOMPBLOCK_MASK);
              break;
            case 2:
              err = ARCunsqueeze(io);
              break;
            case 0: case 3:
              while(!(io->xio_Flags & (XADIOF_LASTINBYTE|XADIOF_ERROR)))
                xadIOPutChar(io, xadIOGetChar(io));
              err = io->xio_Error;
              break;
            default:
              err = XADERR_DATAFORMAT;
            }
            if(!err && xadCalcCRC16(XADM XADCRC16_ID1, 0, (512+16)*11, (xadUINT8 *) outbuf) != EndGetM16(dat+20))
                err = XADERR_CHECKSUM;
            if(!err)
            {
              err = xadHookTagAccess(XADM XADAC_WRITE, 512*11, outbuf,
              ai, XAD_SECTORLABELS, outbuf+512*11, TAG_DONE);
            }
            xadFreeObjectA(XADM io, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
      }
    }
    xadFreeObjectA(XADM inbuf, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

/*
All words are in Intel format

1 xadINT8   ID $76
1 xadINT8   ID $FE / $FD
1 STRING Filename + comment (optional):     FILENAME.EXT[ COMMENT]\0
1 xadINT8   Cruncher version, high nibble major version, low nibble minor version
1 xadINT8   Crunched format version, high nibble major version, low nibble minor version
1 xadINT8   Checksum flag (0 = checksum can be checked)
1 xadINT8   Spare info byte (unused)

n BYTEs  LZW compressed data

EOF:
1 xadINT16   Checksum (sum of all bytes in decrunched file)
n BYTEs  Padding bytes (optional) (to make the file size a multiple of 128)

Minimum file size: 7 bytes + 9 bits + 2 bytes => 11 bytes
*/

XADRECOGDATA(Crunch)
{
  int i;

  if(size >= 11 && data[0]==0x76 && data[1]==0xFD)
  {
    for(i = 2; data[i] && i < size; ++i)
      ;

    /* Check buffer size */
    if(++i <= size-6)
    {
      /* Check format version byte */
      if(data[i] >= 0x10 && data[i] <= 0x2F)
        return 1;
    }
  }
  return 0;
}

XADGETINFO(Crunch)
{
  xadUINT8 data[256];
  struct xadFileInfo *fi;
  xadINT32 err;
  int i, j;

  if((i = ai->xai_InSize) > 256)
    i = 256;

  if(!(err = xadHookAccess(XADM XADAC_READ, i, data, ai)))
  {
    if((fi=(struct xadFileInfo *) xadAllocObjectA(XADM XADOBJ_FILEINFO, NULL)))
    {
      fi->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_NOUNCRUNCHSIZE|
            XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME|XADFIF_XADSTRCOMMENT;

      /* Calculate filename length and comment length */
      i=2;
      while(data[i] && data[i] != '[')
        ++i;
      for(j = i; data[j-1] == ' '; --j)
        ;
      if((fi->xfi_FileName=xadConvertName(XADM CHARSET_HOST, XAD_CHARACTERSET,
      CHARSET_ASCII, XAD_STRINGSIZE, j-2, XAD_CSTRING, data+2,
      XAD_ERRORCODE, &err, TAG_DONE)))
      {
        if(data[i])  /* Comment available */
        {
          ++i;
          if(data[i] == ' ') ++i; /* Skip leading space */
          j=i;
          while(data[i] && data[i] != ']')
            ++i;
          fi->xfi_Comment = xadConvertName(XADM CHARSET_HOST, XAD_CHARACTERSET,
          CHARSET_ASCII, XAD_STRINGSIZE, i-j, XAD_CSTRING, data+j, TAG_DONE);
        }

        /* Make sure to skip until the end of the string */
        while(data[i])
          ++i;
        ++i;
        fi->xfi_DataPos = i;
        fi->xfi_CrunchSize = ai->xai_InSize-2-fi->xfi_DataPos;
        fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) data[1];

        if((data[i+1] & 0xF0) == 0x10)
        {
          fi->xfi_EntryInfo = data[1] == 0xFE ? (xadSTRPTR)"LZW 1" : (xadSTRPTR)"LZHUF 1";
        }
        else
        {
          fi->xfi_EntryInfo = data[1] == 0xFE ? (xadSTRPTR)"LZW 2" : (xadSTRPTR)"LZHUF 2";
        }

        /* fill in today's date */
        xadConvertDates(XADM XAD_DATECURRENTTIME, XADTRUE, XAD_GETDATEXADDATE,
        &fi->xfi_Date, TAG_DONE);
        return xadAddFileEntryA(XADM fi, ai, 0);
      }
      xadFreeObjectA(XADM fi, 0);
    }
    else err = XADERR_NOMEMORY;
  }
  return err;
}

XADUNARCHIVE(Crunch)
{
  xadUINT8 data[4];
  xadUINT16 chksum;
  xadINT32 err;

  /* Read 4 info bytes */
  if(!(err=xadHookAccess(XADM XADAC_READ, 4, data, ai)))
  {
    struct xadInOut *io;

    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|
    XADIOF_NOOUTENDERR|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
    {
      io->xio_InSize = ai->xai_CurFile->xfi_CrunchSize;
      io->xio_OutFunc = xadIOChecksum;
/*    io->xio_OutSize = 0; */
        err = DecrAMPK3(io, ((data[1] & 0xF0) == 0x10) ? 1 : 2);

      if(!err)
        err = xadIOWriteBuf(io);

      if(!err && !data[2])
      {
        chksum =  xadIOGetChar(io);
        chksum += xadIOGetChar(io)<<8;
        if((((xadUINT32)(uintptr_t)io->xio_OutFuncPrivate)&0xFFFF) != chksum)
          err = XADERR_CHECKSUM;
      }
      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  return err;
}

/**************************************************************************************************/

XADCLIENT(Crunch) {
  (struct xadClient *)XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  CRUNCH_VERSION,
  CRUNCH_REVISION,
  256,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_NOCHECKSIZE|XADCF_FREEXADSTRINGS,
  XADCID_CRUNCH,
  "Crunch-LZHUF",
  XADRECOGDATAP(Crunch),
  XADGETINFOP(Crunch),
  XADUNARCHIVEP(Crunch),
  NULL
};

XADCLIENT(Warp) {
  (struct xadClient *)&Crunch_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  WARP_VERSION,
  WARP_REVISION,
  26,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_WARP,
  "Warp",
  XADRECOGDATAP(Warp),
  XADGETINFOP(Warp),
  XADUNARCHIVEP(Warp),
  NULL
};

XADCLIENT(ArcCBMSFX) {
  (struct xadClient *)&Warp_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ARCCBMSFX_VERSION,
  ARCCBMSFX_REVISION,
  4064+11,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO
    |XADCF_FREEXADSTRINGS|XADCF_NOCHECKSIZE,
  XADCID_ARCCBMSFX,
  "Arc CBM SFX",
  XADRECOGDATAP(ArcCBMSFX),
  XADGETINFOP(ArcCBMSFX),
  XADUNARCHIVEP(ArcCBM),
  NULL
};

XADCLIENT(ArcCBM) {
  (struct xadClient *)&ArcCBMSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ARCCBM_VERSION,
  ARCCBM_REVISION,
  11,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO
    |XADCF_FREEXADSTRINGS,
  XADCID_ARCCBM,
  "Arc CBM",
  XADRECOGDATAP(ArcCBM),
  XADGETINFOP(ArcCBM),
  XADUNARCHIVEP(ArcCBM),
  NULL
};

XADCLIENT(CompDisk) {
  (struct xadClient *)&ArcCBM_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  COMPDISK_VERSION,
  COMPDISK_REVISION,
  12,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_COMPDISK,
  "CompDisk",
  XADRECOGDATAP(CompDisk),
  XADGETINFOP(CompDisk),
  XADUNARCHIVEP(CompDisk),
  NULL
};

XADCLIENT(LHWarp) {
  (struct xadClient *)&CompDisk_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHWARP_VERSION,
  LHWARP_REVISION,
  20,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO
    |XADCF_FREETEXTINFOTEXT,
  XADCID_LHWARP,
  "LhWarp",
  XADRECOGDATAP(LHWARP),
  XADGETINFOP(LHWARP),
  XADUNARCHIVEP(LHWARP),
  NULL
};

XADCLIENT(AmPlusUnpack) {
  (struct xadClient *)&LHWarp_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  AMPLUSUNPACK_VERSION,
  AMPLUSUNPACK_REVISION,
  12,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_AMIGAPLUSUNPACK,
  "Amiga Plus Unpack",
  XADRECOGDATAP(AmPlusUnpack),
  XADGETINFOP(AmPlusUnpack),
  XADUNARCHIVEP(AmPlusUnpack),
  NULL
};

XADFIRSTCLIENT(AMPK) {
  (struct xadClient *)&AmPlusUnpack_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  AMPK_VERSION,
  AMPK_REVISION,
  12,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_AMIPACK,
  "AmiPack",
  XADRECOGDATAP(AMPK),
  XADGETINFOP(AMPK),
  XADUNARCHIVEP(AMPK),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(AMPK)

#endif /* XADMASTER_AMPK_C */
