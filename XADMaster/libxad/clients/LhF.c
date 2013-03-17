#ifndef XADMASTER_LHF_C
#define XADMASTER_LHF_C

/*  $Id: LhF.c,v 1.7 2005/06/23 14:54:41 stoecker Exp $
    LhF file archiver client

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>

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

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("LhF 1.1 (22.2.2004)")

#define LHF_VERSION             1
#define LHF_REVISION            1

struct LhFData {
  xadUINT8 Comment;
  xadUINT8 Protection;
  xadUINT16 NameSize;
  xadUINT32 CrunchSize;
  xadUINT32 Size;
  xadUINT32 Date;
};

XADGETINFO(LhF)
{
  xadINT32 err, num = 1, i;
  xadUINT32 data[2];
  struct LhFData ld;
  struct xadFileInfo *fi = 0, *fi2;

  if((err = xadHookAccess(XADM XADAC_READ, 8, data, ai)))
    return err;
  while(!err && ai->xai_InPos < ai->xai_InSize && ai->xai_InPos < data[1])
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhFData), &ld, ai)))
    {
      if((fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
      XAD_OBJNAMESIZE, ld.NameSize+1, TAG_DONE)))
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, ld.NameSize, fi2->xfi_FileName, ai)))
        {
          struct xadDate xd;
          if(ld.Comment)
          {
            xadSTRPTR a;

            for(a = fi2->xfi_FileName; *a; ++a)
              ;
            fi2->xfi_Comment = ++a;
          }
          fi2->xfi_DataPos = ai->xai_InPos;
          fi2->xfi_EntryNumber = num++;
          if(ld.Size == 0xFFFFFFFF)
            fi2->xfi_Flags |= XADFIF_DIRECTORY;
          else if(!ld.Size)
          {
            fi2->xfi_Size = fi2->xfi_CrunchSize = ld.CrunchSize;
            fi2->xfi_PrivateInfo = (xadPTR) 1;
          }
          else
          {
            fi2->xfi_Size = ld.Size;
            fi2->xfi_CrunchSize = ld.CrunchSize;
          }
          fi2->xfi_Protection = ld.Protection;
          fi2->xfi_Flags |= XADFIF_SEEKDATAPOS;
          i = ld.Date;
          xd.xd_Second = i&63; i >>= 6;
          xd.xd_Minute = i&63; i >>= 6;
          xd.xd_Hour = i&31; i >>= 5;
          xd.xd_Day = (1 + i)&31; i >>= 5;
          xd.xd_Month = i&15; i >>= 4;
          xd.xd_Year = 1976 + i;
          xd.xd_Micros = 0;
          xadConvertDates(XADM XAD_DATEXADDATE, &xd, XAD_GETDATEXADDATE,
          &fi2->xfi_Date, TAG_DONE);
          err = xadHookAccess(XADM XADAC_INPUTSEEK, ld.CrunchSize, 0, ai);
        }

        if(!err)
        {
          if(fi)
            fi->xfi_Next = fi2;
          else
            ai->xai_FileInfo = fi2;
          fi = fi2;
        }
        else
          xadFreeObjectA(XADM fi2, 0);
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

  return fi ? 0 : XADERR_ILLEGALDATA;
}

XADRECOGDATA(LhF)
{
  if(((xadUINT32 *)data)[0] == 0x4C684600)
    return 1;
  else
    return 0;
}

/****************************************************************************/

#define LHFWINDOWSIZE   0x8000

struct LhFDecrunch {
  xadINT16              backstack[20];
  xadINT16              stackdata[256];
  xadINT32              leftwinsize;
  xadSTRPTR             windowpos;
  xadSTRPTR             sourcebuf;
  xadUINT32             sourcelen;
  xadINT16              data0[16];
  xadINT8               data1[20];
  xadINT8               data2[2560];
  xadINT16              data3[4098];

  xadINT32              numbits;
  xadUINT32             bitbuf;
  xadUINT16             err;
  struct xadArchiveInfo *ai;
  struct xadMasterBase *xadMasterBase;
  xadUINT8              inbuffer[LHFWINDOWSIZE];
  xadINT8               outbuffer[256*2+LHFWINDOWSIZE+6];
};

static xadUINT16 LHFgetc(struct LhFDecrunch *lhd)
{
  xadUINT16 a;
  if(lhd->sourcelen < 2 || lhd->err)
    return 0;
  if(lhd->sourcebuf == (xadSTRPTR) lhd->inbuffer + LHFWINDOWSIZE)
  {
    xadUINT32 i;
    struct xadMasterBase *xadMasterBase = lhd->xadMasterBase;

    if((i = lhd->sourcelen) > LHFWINDOWSIZE)
      i = LHFWINDOWSIZE;

    if((lhd->err = xadHookAccess(XADM XADAC_READ, i, lhd->inbuffer, lhd->ai)))
      return 0;
    lhd->sourcebuf = (xadSTRPTR) lhd->inbuffer;
  }

  lhd->sourcelen -= 2;
  a = *(lhd->sourcebuf++) << 8;
  a += *(lhd->sourcebuf++);

  return a;
}

/* Neue Bytes von rechts herein, Daten links abgreifen */
static xadUINT16 LHFgetbits(struct LhFDecrunch *lhd, xadUINT32 bits)
{
  xadUINT16 r;

  r = lhd->bitbuf >> (32-bits);
  lhd->numbits += bits;
  if(lhd->numbits < 0)
    lhd->bitbuf <<= bits;
  else
  {
    bits -= lhd->numbits;
    lhd->bitbuf <<= bits;
    lhd->bitbuf |= LHFgetc(lhd);
    lhd->bitbuf <<= lhd->numbits;
    lhd->numbits -= 16;
  }
  return r;
}

static xadINT32 LHFflush(struct LhFDecrunch *lhd)
{
  xadINT32 i, j, err;
  struct xadMasterBase *xadMasterBase = lhd->xadMasterBase;

  lhd->leftwinsize = LHFWINDOWSIZE-1;
  j = LHFWINDOWSIZE;

  if((i = ((uintptr_t)lhd->windowpos - (uintptr_t)(lhd->outbuffer+256)) - j) < 0)
    j += i;
  lhd->windowpos -= j;

  if((err = xadHookAccess(XADM XADAC_WRITE, (xadUINT32) j, lhd->outbuffer+256, lhd->ai)) && !lhd->err)
    lhd->err = err;

  if(i >= 0) /* copy the overworked buffer back */
  {
    lhd->leftwinsize -= i;
    i += 256 - 1;
    do
    {
      lhd->outbuffer[i] = lhd->outbuffer[LHFWINDOWSIZE+i];
    } while(i--);
  }
  return lhd->err;
}

static xadINT32 LHFsub1(struct LhFDecrunch *lhd, xadINT16 *p, xadINT8 *q, xadINT16 rounds, xadINT16 maxbits)
{
  xadINT16 data[32], *r = data+16, *s = data, *t = lhd->data0, *u;
  xadINT16 i = 0, j = 0, k = 0, l = maxbits-1, m, n, o;

  m = (1<<l);
  n = (m<<1);
  do
  {
    *(s++) = m;
    m >>= 1;
    *(r++) = k;
    o = *(t++);
    o = (o<<l)|(o>>(16-l));
    k += o;
    if(k < 0)
      return XADERR_ILLEGALDATA;
  } while(l--);
  if(k > n)
    return XADERR_ILLEGALDATA;
  else if(k != n)
  {
    u = p + n;
    n -= k;
    l += (n&1) + (n>>1);
    do
    {
      *(--u) = m;
      *(--u) = 0;
    } while(l--);
    o = 16 - maxbits;
    k = (k<<o)|(k>>(16-o));
    l += o;
    m |= (1<<l);
    do
    {
      *(s++) = m;
      m >>= 1;
      *(r++) = k;
      o = *(t++);
      o = (o<<l)|(o>>(16-l));
      k += o;
    } while(k < 0 && l--);
    if(k)
      return XADERR_ILLEGALDATA;
  }
  t = p;
  do
  {
    if((k = *(q++)) > 0)
    {
      s = data+15+k;
      o = *s;
      m = *(s-16);
      *s += m;
      k -= maxbits;
      if(k <= 0 && m--)
      {
        s = p+o;
        do
        {
          *(s++) = i;
        } while(m--);
      }
      else
      {
        s = p + (((xadUINT16) o) >> (16-maxbits));
        o <<= maxbits;
        do
        {
          if(!(m = *s))
          {
            do
            {
              j -= 4;
              *s = j;
              *(--t) = m;
              *(--t) = 0;
              s = t;
              if(o & 0x8000)
                ++s;
              o <<= 1;
            } while(--k > 0);
            *(s) = i;
          }
          else
          {
            s = p + (m/2);
            if(o & 0x8000)
              ++s;
            o <<= 1;
            --k;
          }
        } while(k > 0);
        *s = i;
      }
    }
    ++i;
  } while(rounds--);
  return 0;
}

static xadINT32 LHFsub2(struct LhFDecrunch *lhd, xadINT16 bits, xadINT16 maxbits)
{
  xadINT16 i, j, k, l;
  xadINT8 *d = lhd->data1;

  memset(lhd->data0, 0, 32);
  if(!(i = LHFgetbits(lhd, (xadUINT32) bits)))
  {
    if((i = LHFgetbits(lhd, (xadUINT32)bits)) >= maxbits)
      return XADERR_ILLEGALDATA;
    lhd->data1[i] = 0;
    for(bits = 0; bits < 256; ++bits)
      lhd->stackdata[i] = i;
    return 0;
  }
  else if(i >= maxbits)
    return XADERR_ILLEGALDATA;

  l = i;
  do
  {
    if((k = LHFgetbits(lhd, 3)) == 7)
    {
      j = k;
      do
      {
        k = LHFgetbits(lhd, 1);
        j += k;
      } while(k);
      k = j;
    }
    *d = k;
    if(*(d++) > 0)
      ++lhd->data0[k-1];
  } while(i--);

  return LHFsub1(lhd, lhd->stackdata, lhd->data1, l, 8);
}

static xadINT32 DecrunchLhF(struct LhFDecrunch *lhd)
{
  xadINT32 i, j, k, l, m, n;
  xadINT8 *p;

  lhd->numbits = -16;                   /* init getbits */
  lhd->bitbuf = LHFgetc(lhd) << 16;
  lhd->bitbuf += LHFgetc(lhd);          /* end init */

//  lhd->windowpos = lhd->outbuffer + 254;
//  *(lhd->windowpos++) = 0;
//  *(lhd->windowpos++) = 0;
  lhd->windowpos = (xadSTRPTR) lhd->outbuffer + 256;
  lhd->leftwinsize = LHFWINDOWSIZE-1;
  do
  {
    if(!(i = LHFgetbits(lhd, 16)))
      return XADERR_ILLEGALDATA;
    if((j = LHFgetbits(lhd, 9)))
    {
      if(LHFsub2(lhd, 5, 20))
        return XADERR_ILLEGALDATA;
      memset(lhd->data0, 0, 32);

      p = lhd->data2;
      do
      {
        k = lhd->bitbuf >> 24;
        if((k = lhd->stackdata[k]) < 0)
        {
          l = lhd->bitbuf >> 16;
          do
          {
            if(l & 0x80)
              k += 2;
            l <<= 1;
          } while((k = lhd->stackdata[k>>1]) < 0);
        }

        LHFgetbits(lhd, (xadUINT32) lhd->data1[k]);
        k -= 3;
        if(k < 0)
        {
          l = 0;
          k += 2;
          if(!k)
            k = LHFgetbits(lhd, 2) + 3;
          else if(k > 0)
            k = LHFgetbits(lhd, 7) + 7;
          else
          {
            k = LHFgetbits(lhd, 3) + 3;
            l = *(p-1);
            lhd->data0[l-1] += k--;
          }
          do
          {
            *(p++) = l;
          } while(k--);
        }
        else
        {
          *p = k;
          if(*(p++) > 0)
            ++lhd->data0[k-1];
        }
      } while(j--);
      while(!*(--p))
        ;
      n = p-lhd->data2;
      if((k = LHFsub1(lhd, lhd->data3, lhd->data2, n, 12)))
        return k;
    }
    else
    {
      xadUINT16 temp;
      n = LHFgetbits(lhd, 9);
      lhd->data2[n] = 0;
      for(temp = 0; temp < 0x1000; ++temp)
        lhd->data3[temp] = n;
    }
    if(n >= 256 && (k = LHFsub2(lhd, 4, 16)))
      return k;

    --i;
    do
    {
      do
      {
        if((k = lhd->data3[lhd->bitbuf>>20]) < 0)
        {
          l = lhd->bitbuf >> 16;
          if(l & (1<<3))
            k += 2;
          if((k = lhd->data3[k>>1]) < 0)
          {
            if(l & (1<<2))
              k += 2;
            if((k = lhd->data3[k>>1]) < 0)
            {
              if(l & (1<<1))
                k += 2;
              if((k = lhd->data3[k>>1]) < 0)
              {
                if(l & (1<<0))
                  k += 2;
                k = lhd->data3[k>>1];
              }
            }
          }
        }
        LHFgetbits(lhd, (xadUINT32) lhd->data2[k]);
        k -= 256;
        if(k >= 0)
        {
          if((l = lhd->stackdata[lhd->bitbuf >> 24]) < 0)
          {
            m = lhd->bitbuf >> 16;
            do
            {
              m <<= 1;
              if(m & 0x100)
                l = lhd->stackdata[(l/2)+1];
              else
              {
                do
                {
                  m <<= 1;
                  l = lhd->stackdata[l/2];
                } while(l < 0 && !(m & 0x100));
              }
            } while(l < 0);
          }
          m = lhd->data1[l];
          LHFgetbits(lhd, (xadUINT32) m);
          m = l;
          if(--m > 0)
            l = LHFgetbits(lhd, (xadUINT32) m) + (1<<m);
          p = (xadINT8 *) lhd->windowpos-l-1;
          l = 256 - k;
          if(p < lhd->outbuffer)
            p += LHFWINDOWSIZE;
          while(l++ < 257+2)
            *(lhd->windowpos++) = *(p++);
          k += 3;
          lhd->leftwinsize -= k;
        }
        else
        {
          *(lhd->windowpos++) = k;
          --lhd->leftwinsize;
        }
      } while(i-- && lhd->leftwinsize >= 0);
      if(lhd->leftwinsize < 0 && LHFflush(lhd))
        return lhd->err;
    } while(i >= 0);
  } while(LHFgetbits(lhd, 1));
  return LHFflush(lhd);
}

/****************************************************************************/

XADUNARCHIVE(LhF)
{
  xadINT32 err;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(fi->xfi_PrivateInfo)
    err = xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else
  {
    struct LhFDecrunch *d;

    if((d = (struct LhFDecrunch *) xadAllocVec(XADM sizeof(struct LhFDecrunch), XADMEMF_CLEAR)))
    {
      d->ai = ai;
      d->xadMasterBase = xadMasterBase;
      d->sourcelen = fi->xfi_CrunchSize;
      d->sourcebuf = (xadSTRPTR) d->inbuffer+LHFWINDOWSIZE;
      err = DecrunchLhF(d);
      xadFreeObjectA(XADM d, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  return err;
}

/****************************************************************************/

XADFIRSTCLIENT(LhF) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHF_VERSION,
  LHF_REVISION,
  8,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_LHF,
  "LhF",
  XADRECOGDATAP(LhF),
  XADGETINFOP(LhF),
  XADUNARCHIVEP(LhF),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(LhF)

#endif /* XADMASTER_LHF_C */
