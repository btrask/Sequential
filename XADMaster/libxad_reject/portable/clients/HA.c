#ifndef XADMASTER_HA_C
#define XADMASTER_HA_C

/*  $Id: HA.c,v 1.9 2005/06/23 14:54:41 stoecker Exp $
    HA file archiver client for XAD

    XAD library system for archive handling
    Copyright (C) 2000 and later by Dirk Stöcker <soft@dstoecker.de>

    based on ha 0.999 by Harri Hirvola
    Copyright (C) 1993-1995 Harri Hirvola <harri.hirvola@vaisala.infonet.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "xadClient.h"
#include "xadIO.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      11
#endif

XADCLIENTVERSTR("HA 1.4 (22.2.2004) GPL by Dirk Stöcker")

#define HA_VERSION              1
#define HA_REVISION             4

#define HATYPE_CPY      0
#define HATYPE_ASC      1
#define HATYPE_HSC      2
#define HATYPE_DIR      14
#define HATYPE_SPECIAL  15

#define HAMTYPE_MSDOS   1
#define HAMTYPE_UNIX    2

#define HA_ISVTX     0x0200
#define HA_ISGID     0x0400
#define HA_ISUID     0x0800

#define HA_IRUSR     0x0100
#define HA_IWUSR     0x0080
#define HA_IXUSR     0x0040

#define HA_IRGRP     0x0020
#define HA_IWGRP     0x0010
#define HA_IXGRP     0x0008

#define HA_IROTH     0x0004
#define HA_IWOTH     0x0002
#define HA_IXOTH     0x0001

#define HA_IFMT      0xf000
#define HA_IFIFO     0x1000
#define HA_IFCHR     0x2000
#define HA_IFDIR     0x4000
#define HA_IFBLK     0x6000
#define HA_IFREG     0x8000
#define HA_IFLNK     0xa000
#define HA_IFSOCK    0xc000

#define HA_ISDIR(m)  ((m&HA_IFMT)==HA_IFDIR)
#define HA_ISCHR(m)  ((m&HA_IFMT)==HA_IFCHR)
#define HA_ISBLK(m)  ((m&HA_IFMT)==HA_IFBLK)
#define HA_ISLNK(m)  ((m&HA_IFMT)==HA_IFLNK)
#define HA_ISFIFO(m) ((m&HA_IFMT)==HA_IFIFO)
#define HA_ISSOCK(m) ((m&HA_IFMT)==HA_IFSOCK)

struct HAPrivate {
  xadUINT32 CRC32;
  xadUINT8 Method;
};

#define HAPI(a) ((struct HAPrivate *) ((a)->xfi_PrivateInfo))
#define HASCANSIZE      2048

static const xadSTRPTR hatypes[] = {"CPY", "ASC", "HSC"};

/*
  archive header (intel storage):
  xadUINT8[2]   ID = 'HA'
  xadUINT16             number of entries

  file header:
  xadUINT8              (version<<4) + compression type
  xadUINT32             Compressed file size
  xadUINT32             Original file size
  xadUINT32             CRC32
  xadUINT32             timestamp (unix)
  xadUINT8[..]  pathname, filename
  xadUINT8              Length of machine specific information
  xadUINT8[..]  Machine specific information
*/

XADRECOGDATA(HA)
{
  if(data[0] == 'H' && data[1] == 'A' && (data[4]>>4) == 2 &&
  (data[4]&0xF) <= HATYPE_SPECIAL && EndGetI32(data+5) <=
  EndGetI32(data+9))
    return 1;
  return 0;
}

XADGETINFO(HA)
{
  xadINT32 err, s, i, nsize, psize, msize;
  struct xadFileInfo *fi;
  xadSTRPTR hdr, machine;

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 4, 0, ai)))
  {
    if((hdr = xadAllocVec(XADM HASCANSIZE, XADMEMF_PUBLIC)))
    {
      while(ai->xai_InPos < ai->xai_InSize && !err)
      {
        if((s = ai->xai_InSize - ai->xai_InPos) > HASCANSIZE)
          s = HASCANSIZE;
        if(!(err = xadHookAccess(XADM XADAC_READ, s, hdr, ai)))
        {
          msize = 0;
          for(psize = 0; psize <= s-20 && hdr[17+psize]; ++psize)
            ;
          for(nsize = 0; nsize+psize <= s-20 && hdr[17+psize+1+nsize]; ++nsize)
            ;
          if(nsize+psize <= s-20)
            msize = hdr[17+psize+1+nsize+1];
          if(hdr[0] >> 4 == 2 && (hdr[0]&0xF) <= HATYPE_SPECIAL &&
          EndGetI32(hdr+1) <= EndGetI32(hdr+5) && psize + nsize + msize <= s-20)
          {
            machine = hdr+20+psize+nsize;

            if((hdr[0]&0xF) == HATYPE_SPECIAL)
            {
              if(machine[0] == HAMTYPE_UNIX)
              {
                if(machine[2]>>4 == 0xA) /* check for link */
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, nsize+1+psize+1+EndGetI32(hdr+1)+1, TAG_DONE)))
                  {
                    i = 0;
                    if(psize)
                    {
                      for(i = 0; i < psize; ++i)
                      {
                        fi->xfi_FileName[i] = ((xadUINT8)hdr[17+i]) == 0xFF ? '/' : hdr[17+i];
                      }
                      if(fi->xfi_FileName[i-1] != '/')
                        fi->xfi_FileName[i++] = '/';
                    }
                    xadCopyMem(XADM hdr+17+psize+1, fi->xfi_FileName+i, nsize+1); i += nsize+1;

                    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 20+nsize+psize+msize-s, 0, ai)))
                    {
                      fi->xfi_LinkName = fi->xfi_FileName+i;
                      err = xadHookAccess(XADM XADAC_READ, EndGetI32(hdr+1), fi->xfi_LinkName, ai);
                      for(i = 0; fi->xfi_LinkName[i]; ++i)
                      {
                        if(((xadUINT8)fi->xfi_LinkName[i]) == 0xFF)
                          fi->xfi_LinkName[i] = '/';
                      }
                    }

                    xadConvertProtection(XADM XAD_PROTUNIX, EndGetI16(machine+1), XAD_GETPROTFILEINFO, fi, TAG_DONE);

                    fi->xfi_Flags |= XADFIF_LINK|XADFIF_EXTRACTONBUILD;
                    xadConvertDates(XADM XAD_DATEUNIX, EndGetI32(hdr+13), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

                    i = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
                    if(!err && i)
                      err = i;
                  }
                  else
                    err = XADERR_NOMEMORY;
                }
                else if(machine[2]>>4 == 0x1) /* fifo */
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, nsize+1+psize+1, TAG_DONE)))
                  {
                    i = 0;
                    if(psize)
                    {
                      for(i = 0; i < psize; ++i)
                      {
                        fi->xfi_FileName[i] = ((xadUINT8)hdr[17+i]) == 0xFF ? '/' : hdr[17+i];
                      }
                      if(fi->xfi_FileName[i-1] != '/')
                        fi->xfi_FileName[i++] = '/';
                    }
                    xadCopyMem(XADM hdr+17+psize+1, fi->xfi_FileName+i, nsize+1);
                    fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
                    fi->xfi_FileType = XADFILETYPE_UNIXFIFO;
                    xadConvertProtection(XADM XAD_PROTUNIX, EndGetI16(machine+1), XAD_GETPROTFILEINFO, fi, TAG_DONE);
                    xadConvertDates(XADM XAD_DATEUNIX, EndGetI32(hdr+13), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

                    err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos-s+20+nsize+psize+msize, TAG_DONE);
                  }
                }
                else if((machine[2]>>4) == 0x2 || (machine[2]>>4) == 0x6)
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, nsize+1+psize+1, TAG_DONE)))
                  {
                    i = 0;
                    if(psize)
                    {
                      for(i = 0; i < psize; ++i)
                      {
                        fi->xfi_FileName[i] = ((xadUINT8)hdr[17+i]) == 0xFF ? '/' : hdr[17+i];
                      }
                      if(fi->xfi_FileName[i-1] != '/')
                        fi->xfi_FileName[i++] = '/';
                    }
                    xadCopyMem(XADM hdr+17+psize+1, fi->xfi_FileName+i, nsize+1);
                    fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
                    fi->xfi_FileType = (machine[2]>>4) == 0x6 ? XADFILETYPE_UNIXBLOCKDEVICE : XADFILETYPE_UNIXCHARDEVICE;
                    xadConvertProtection(XADM XAD_PROTUNIX, EndGetI16(machine+1), XAD_GETPROTFILEINFO, fi, TAG_DONE);
                    xadConvertDates(XADM XAD_DATEUNIX, EndGetI32(hdr+13), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

                    i = EndGetI32(hdr+1);
                    /* set the block-special types here ??? */

                    err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos-s+20+nsize+psize+msize+i, TAG_DONE);
                  }
                }
                else
                {
                  err = xadHookAccess(XADM XADAC_INPUTSEEK, 20+nsize+psize+msize+EndGetI32(hdr+1)-s, 0, ai);
                }
              }
              else
                err = xadHookAccess(XADM XADAC_INPUTSEEK, 20+nsize+psize+msize+EndGetI32(hdr+1)-s, 0, ai);
            }
            else if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, nsize+1+psize+1,
            XAD_OBJPRIVINFOSIZE, sizeof(struct HAPrivate), TAG_DONE)))
            {
              i = 0;
              if(psize)
              {
                for(i = 0; i < psize; ++i)
                {
                  fi->xfi_FileName[i] = ((xadUINT8)hdr[17+i]) == 0xFF ? '/' : hdr[17+i];
                }
                if(fi->xfi_FileName[i-1] != '/')
                  fi->xfi_FileName[i++] = '/';
              }
              xadCopyMem(XADM hdr+17+psize+1, fi->xfi_FileName+i, nsize+1);

              fi->xfi_CrunchSize = EndGetI32(hdr+1);
              fi->xfi_Size = EndGetI32(hdr+5);

              switch(machine[0])
              {
              case HAMTYPE_MSDOS: xadConvertProtection(XADM XAD_PROTMSDOS, machine[1],
                XAD_GETPROTAMIGA, &fi->xfi_Protection, TAG_DONE); break;
              case HAMTYPE_UNIX: xadConvertProtection(XADM XAD_PROTUNIX, EndGetI16(machine+1),
                XAD_GETPROTAMIGA, &fi->xfi_Protection, TAG_DONE);
                break;
              }

              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
              fi->xfi_DataPos = ai->xai_InPos-s+20+nsize+psize+msize;

              xadConvertDates(XADM XAD_DATEUNIX, EndGetI32(hdr+13), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

              HAPI(fi)->CRC32 = EndGetI32(hdr+9);
              HAPI(fi)->Method = hdr[0]&15;
              if(HAPI(fi)->Method == HATYPE_DIR)
                fi->xfi_Flags |= XADFIF_DIRECTORY;
              else if(HAPI(fi)->Method <= HATYPE_HSC)
                fi->xfi_EntryInfo = hatypes[HAPI(fi)->Method];
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, fi->xfi_DataPos+fi->xfi_CrunchSize, TAG_DONE);
            }
            else
              err = XADERR_NOMEMORY;
          }
          else
            err = XADERR_ILLEGALDATA;
        }
      }
      xadFreeObjectA(XADM hdr,0);
    }
    else
      err = XADERR_NOMEMORY;

    if(!err && ai->xai_InPos < ai->xai_InSize)
      err = XADERR_ILLEGALDATA;
    if(err)
    {
      ai->xai_Flags |= XADAIF_FILECORRUPT;
      ai->xai_LastError = err;
    }
  }
  return (ai->xai_FileInfo ? 0 : err);
}


/* Arithmetic Decoding *******************************************************/

struct HaArithData {
 struct xadInOut *io;
 xadUINT16 h;
 xadUINT16 l;
 xadUINT16 v;
 xadINT16  s;
 xadINT16  gpat;
 xadINT16  ppat;
};

static void HA_ac_init_decode(struct HaArithData *dat)
{
  dat->h = 0xffff;
/*  dat->l = 0; */
/*  dat->gpat = 0; */
  dat->v = xadIOGetChar(dat->io)<<8;
  dat->v |= 0xff&xadIOGetChar(dat->io);
}

xadUINT16 HA_ac_threshold_val(struct HaArithData *dat, xadUINT16 tot)
{
  xadUINT32 r;

  r = (xadUINT32)(dat->h - dat->l)+1;
  return (xadUINT16)((((xadUINT32)(dat->v-dat->l)+1)*tot-1)/r);
}

#define HA_getbit(b)    { dat->gpat <<= 1;                              \
                          if(!(dat->gpat&0xff)) {                       \
                            dat->gpat=xadIOGetChar(dat->io);            \
                                if(dat->gpat&0x100) dat->gpat=0x100;    \
                                else {                                  \
                                        dat->gpat <<= 1;                \
                                        dat->gpat |= 1;                 \
                                }                                       \
                          }                                             \
                          b |= (dat->gpat&0x100)>>8;                    \
                        }

static void HA_ac_in(struct HaArithData *dat, xadUINT16 low, xadUINT16 high, xadUINT16 tot)
{
  xadUINT32 r;

  r = (xadUINT32)(dat->h - dat->l)+1;
  dat->h = (xadUINT16)(r*high/tot-1)+dat->l;
  dat->l += (xadUINT16)(r*low/tot);
  while(!((dat->h^dat->l)&0x8000))
  {
    dat->l <<= 1;
    dat->h <<= 1;
    dat->h |= 1;
    dat->v <<= 1;
    HA_getbit(dat->v);
  }
  while((dat->l&0x4000)&&!(dat->h&0x4000))
  {
    dat->l <<= 1;
    dat->l &= 0x7fff;
    dat->h <<= 1;
    dat->h |= 0x8001;
    dat->v <<= 1;
    dat->v ^= 0x8000;
    HA_getbit(dat->v);
  }
}

/* ASC ***********************************************************************/

#define HA_POSCODES     31200
#define HA_CTCODES      256
#define HA_PTCODES      16
#define HA_SLCODES      16
#define HA_LLCODES      48
#define HA_TTORD        4
#define HA_LTSTEP       8
#define HA_CTSTEP       1
#define HA_TTSTEP       40
#define HA_PTSTEP       24
#define HA_MAXPT        (250*HA_PTSTEP)
#define HA_MAXLT        (750*HA_LTSTEP)
#define HA_MAXTT        (150*HA_TTSTEP)
#define HA_MAXCT        (1000*HA_CTSTEP)
#define HA_TTOMASK      (HA_TTORD-1);
#define HA_LPLEN        4
#define HA_CPLEN        8
#define HA_LLLEN        16
#define HA_LLBITS       4
#define HA_CCUTOFF      (3*HA_CTSTEP)
#define HA_LCUTOFF      (3*HA_LTSTEP)
#define HA_LTCODES      (HA_SLCODES+HA_LLCODES)
#define HA_LENCODES     (HA_SLCODES+HA_LLCODES*HA_LLLEN)

struct HaAscData {
  struct HaArithData arith;
  xadUINT16 cblen;
  xadUINT16 bbf;
  xadUINT16 ccnt;
  xadUINT16 pmax;
  xadUINT16 npt;
  xadUINT16 ces;
  xadUINT16 les;
  xadUINT16 ttcon;
  xadUINT16 ltab[2*HA_LTCODES];
  xadUINT16 eltab[2*HA_LTCODES];
  xadUINT16 ptab[2*HA_PTCODES];
  xadUINT16 ctab[2*HA_CTCODES];
  xadUINT16 ectab[2*HA_CTCODES];
  xadUINT16 ttab[HA_TTORD][2];
  xadUINT8 b[HA_POSCODES];
};

static void HA_tabinit(xadUINT16 *t, xadUINT16 tl, xadUINT16 ival)
{
  xadUINT16 i,j;

  for(i = tl; i < 2*tl; ++i)
    t[i] = ival;
  for(i = tl-1, j = (tl<<1)-2; i; --i, j-=2)
  {
    t[i] = t[j] + t[j+1];
  }
}

static void HA_tscale(xadUINT16 *t, xadUINT16 tl)
{
  xadUINT16 i,j;

  for(i = (tl<<1)-1; i>=tl; --i)
  {
    if(t[i]>1)
      t[i]>>=1;
  }
  for(i = tl-1, j = (tl<<1)-2; i; --i, j-=2)
  {
    t[i] = t[j] + t[j+1];
  }
}

static void HA_ttscale(struct HaAscData *dat, xadUINT16 con)
{
  dat->ttab[con][0]>>=1;
  if(dat->ttab[con][0]==0)
    dat->ttab[con][0]=1;
  dat->ttab[con][1]>>=1;
  if(dat->ttab[con][1]==0)
    dat->ttab[con][1]=1;
}

static void HA_tupd(xadUINT16 *t, xadUINT16 tl, xadUINT16 maxt, xadUINT16 step, xadUINT16 p)
{
  xadINT16 i;

  for(i = p+tl; i; i>>=1)
    t[i] += step;
  if(t[1] >= maxt)
    HA_tscale(t,tl);
}

static void HA_tzero(xadUINT16 *t, xadUINT16 tl, xadUINT16 p)
{
  xadINT16 i, step;

  for(i = p+tl, step = t[i]; i; i>>=1)
    t[i] -= step;
}

static xadINT32 HA_asc(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadUINT16 l,p,tv,i,lt;
  struct HaAscData *dat;

  if((dat = (struct HaAscData *) xadAllocVec(XADM sizeof(struct HaAscData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    dat->arith.io = io;
    dat->cblen = HA_POSCODES;
    dat->ces=HA_CTSTEP;
    dat->les=HA_LTSTEP;
/*    dat->ccnt=0; */
/*    dat->ttcon=0; */
    dat->npt = dat->pmax = 1;
    for(i = 0; i < HA_TTORD; ++i)
      dat->ttab[i][0] = dat->ttab[i][1] = HA_TTSTEP;
    HA_tabinit(dat->ltab, HA_LTCODES,0);
    HA_tabinit(dat->eltab,HA_LTCODES,1);
    HA_tabinit(dat->ctab, HA_CTCODES,0);
    HA_tabinit(dat->ectab,HA_CTCODES,1);
    HA_tabinit(dat->ptab, HA_PTCODES,0);
    HA_tupd(dat->ptab,HA_PTCODES,HA_MAXPT,HA_PTSTEP,0);

    HA_ac_init_decode(&dat->arith);
    for(;;)
    {
      tv = HA_ac_threshold_val(&dat->arith, dat->ttab[dat->ttcon][0]+dat->ttab[dat->ttcon][1]+1);
      i = dat->ttab[dat->ttcon][0]+dat->ttab[dat->ttcon][1];
      if(dat->ttab[dat->ttcon][0] > tv)
      {
        HA_ac_in(&dat->arith, 0, dat->ttab[dat->ttcon][0], i+1);
        dat->ttab[dat->ttcon][0] += HA_TTSTEP;

        if(i >= HA_MAXTT)
          HA_ttscale(dat, dat->ttcon);

        dat->ttcon = (dat->ttcon<<1) & HA_TTOMASK;
        tv = HA_ac_threshold_val(&dat->arith, dat->ctab[1] + dat->ces);

        if(tv >= dat->ctab[1])
        {
          HA_ac_in(&dat->arith, dat->ctab[1], dat->ctab[1]+dat->ces, dat->ctab[1]+dat->ces);
          tv = HA_ac_threshold_val(&dat->arith, dat->ectab[1]);
          for(l=2,lt=0;;)
          {
            if(lt+dat->ectab[l]<=tv)
            {
              lt += dat->ectab[l];
              ++l;
            }
            if(l >= HA_CTCODES)
            {
              l -= HA_CTCODES;
              break;
            }
            l <<= 1;
          }
          HA_ac_in(&dat->arith, lt,lt+dat->ectab[HA_CTCODES+l], dat->ectab[1]);
          HA_tzero(dat->ectab, HA_CTCODES, l);
          if(dat->ectab[1] != 0)
            dat->ces += HA_CTSTEP;
          else
            dat->ces = 0;
          for(i = l < HA_CPLEN ? 0 : l-HA_CPLEN; i < (l+HA_CPLEN >= HA_CTCODES-1 ? HA_CTCODES-1:l+HA_CPLEN); ++i)
          {
            if(dat->ectab[HA_CTCODES+i])
              HA_tupd(dat->ectab, HA_CTCODES, HA_MAXCT, 1, i);
          }
        }
        else
        {
          for(l=2,lt=0;;)
          {
            if(lt+dat->ctab[l] <= tv)
            {
              lt += dat->ctab[l];
              l++;
            }
            if(l >= HA_CTCODES)
            {
              l -= HA_CTCODES;
              break;
            }
            l <<= 1;
          }
          HA_ac_in(&dat->arith, lt, lt+dat->ctab[HA_CTCODES+l],dat->ctab[1]+dat->ces);
        }

        HA_tupd(dat->ctab, HA_CTCODES, HA_MAXCT, HA_CTSTEP, l);
        if(dat->ctab[HA_CTCODES+l] == HA_CCUTOFF)
          dat->ces -= HA_CTSTEP < dat->ces ? HA_CTSTEP : dat->ces-1;

        dat->b[dat->bbf] = xadIOPutChar(io, l);
        if(++dat->bbf == dat->cblen)
          dat->bbf=0;

        if(dat->ccnt < HA_POSCODES)
          ++dat->ccnt;
      }
      else if (i > tv)
      {
        HA_ac_in(&dat->arith, dat->ttab[dat->ttcon][0],i,i+1);
        dat->ttab[dat->ttcon][1] += HA_TTSTEP;
        if(i >= HA_MAXTT)
          HA_ttscale(dat, dat->ttcon);
        dat->ttcon = ((dat->ttcon<<1)|1)&HA_TTOMASK;
        while(dat->ccnt > dat->pmax)
        {
          HA_tupd(dat->ptab, HA_PTCODES, HA_MAXPT, HA_PTSTEP, dat->npt++);
          dat->pmax <<= 1;
        }
        tv = HA_ac_threshold_val(&dat->arith, dat->ptab[1]);
        for(p=2,lt=0;;)
        {
          if(lt + dat->ptab[p] <= tv)
          {
            lt += dat->ptab[p];
            p++;
          }
          if(p >= HA_PTCODES)
          {
            p -= HA_PTCODES;
            break;
          }
          p <<= 1;
        }
        HA_ac_in(&dat->arith, lt, lt+dat->ptab[HA_PTCODES+p], dat->ptab[1]);
        HA_tupd(dat->ptab, HA_PTCODES, HA_MAXPT, HA_PTSTEP, p);
        if(p > 1)
        {
          for(i=1; p; i <<= 1)
            --p;
          i >>= 1;
          if(i==(dat->pmax>>1))
            l = dat->ccnt-(dat->pmax>>1);
          else
            l=i;
          p = HA_ac_threshold_val(&dat->arith, l);
          HA_ac_in(&dat->arith, p, p+1, l);
          p += i;
        }
        tv = HA_ac_threshold_val(&dat->arith, dat->ltab[1]+dat->les);
        if(tv >= dat->ltab[1])
        {
          HA_ac_in(&dat->arith, dat->ltab[1], dat->ltab[1]+dat->les, dat->ltab[1]+dat->les);
          tv = HA_ac_threshold_val(&dat->arith, dat->eltab[1]);
          for(l=2,lt=0;;)
          {
            if(lt+dat->eltab[l] <= tv)
            {
              lt += dat->eltab[l];
              ++l;
            }
            if(l >= HA_LTCODES)
            {
              l -= HA_LTCODES;
              break;
            }
            l <<= 1;
          }
          HA_ac_in(&dat->arith, lt, lt+dat->eltab[HA_LTCODES+l], dat->eltab[1]);
          HA_tzero(dat->eltab, HA_LTCODES, l);
          if(dat->eltab[1] != 0)
            dat->les += HA_LTSTEP;
          else
            dat->les = 0;
          for(i = l < HA_LPLEN ? 0 : l-HA_LPLEN; i<(l+HA_LPLEN >= HA_LTCODES-1 ? HA_LTCODES-1:l+HA_LPLEN);++i)
          {
            if(dat->eltab[HA_LTCODES+i])
              HA_tupd(dat->eltab,HA_LTCODES,HA_MAXLT,1,i);
          }
        }
        else
        {
          for(l=2,lt=0;;)
          {
            if(lt+dat->ltab[l] <= tv)
            {
              lt += dat->ltab[l];
              ++l;
            }
            if(l >= HA_LTCODES)
            {
              l -= HA_LTCODES;
              break;
            }
            l <<= 1;
          }
          HA_ac_in(&dat->arith, lt, lt+dat->ltab[HA_LTCODES+l], dat->ltab[1]+dat->les);
        }
        HA_tupd(dat->ltab, HA_LTCODES, HA_MAXLT, HA_LTSTEP, l);
        if(dat->ltab[HA_LTCODES+l] == HA_LCUTOFF)
          dat->les -= HA_LTSTEP < dat->les ? HA_LTSTEP : dat->les-1;
        if(l == HA_SLCODES-1)
          l = HA_LENCODES-1;
        else if(l >= HA_SLCODES)
        {
          i = HA_ac_threshold_val(&dat->arith, HA_LLLEN);
          HA_ac_in(&dat->arith, i, i+1, HA_LLLEN);
          l = ((l-HA_SLCODES) << HA_LLBITS)+i+HA_SLCODES-1;
        }
        l += 3;
        if(dat->ccnt < HA_POSCODES)
        {
          dat->ccnt += l;
          if(dat->ccnt > HA_POSCODES)
            dat->ccnt = HA_POSCODES;
        }
        if(dat->bbf > p)
          p = dat->bbf-1-p;
        else
          p=dat->cblen-1-p+dat->bbf;
        while (l--)
        {
          dat->b[dat->bbf] = xadIOPutChar(io, dat->b[p]);
          if(++dat->bbf == dat->cblen)
            dat->bbf=0;
          if(++p == dat->cblen)
            p=0;
        }
      }
      else
      {
        HA_ac_in(&dat->arith, i, i+1, i+1);
        break;
      }
    }

    xadFreeObjectA(XADM dat, 0);
  }
  return io->xio_Error;
}

/* HSC ***********************************************************************/

#define HA_IECLIM       32      /* initial escape counter upper limit */
#define HA_NECLIM       5       /* no escape expected counter limit */
#define HA_NECTLIM      4
#define HA_NECMAX       10      /* no escape expected counter maximum */
#define HA_MAXCLEN      4       /* assumed to be 4 in several places */
#define HA_NUMCON       10000   /* number of contexts to remember */
#define HA_NUMCFB       32760   /* number of frequencies to remember */
#define HA_ESCTH        3       /* threshold for escape calculation */
#define HA_MAXTVAL      8000    /* maximum frequency value */
#define HA_RFMINI       4       /* initial refresh counter value */
#define HA_HTLEN        16384   /* length of hash table */
#define HA_NIL          0xffff  /* NIL pointer in lists */
#define HA_ESC          256     /* escape symbol */

struct HaHscData {
  struct HaArithData arith;
  xadUINT16 usp;                        /* stack pointer */
  xadINT16  cslen;                      /* length of context to search */
  xadINT16  cmsp;                       /* pointer to cmstack */
  xadINT16  dropcnt;            /* counter for context len drop */
  xadUINT16 nrel;                       /* context for frequency block release */
  xadUINT16 elf;                        /* first of expire list */
  xadUINT16     ell;                    /* last of expire list */
  xadUINT16 fcfbl;                      /* pointer to free frequency blocks */
  xadUINT16 elp[HA_NUMCON];             /* expire list previous pointer array */
  xadUINT16 eln[HA_NUMCON];             /* expire list next pointer array */
  xadUINT16 hrt[HA_HTLEN];              /* semi random data for hashing */
  xadUINT16 hs[HA_MAXCLEN+1];   /* hash stack for context search */
  xadUINT16 hp[HA_NUMCON];              /* hash list pointer array */
  xadUINT16 as[HA_MAXCLEN+1];   /* indexes to frequency array */
  xadUINT16 cps[HA_MAXCLEN+1];  /* context pointers */
  xadUINT16 nb[HA_NUMCFB];              /* next pointer for frequency array */
  xadUINT16 fa[HA_NUMCFB];              /* frequency array */
  xadUINT16 ft[HA_NUMCON];              /* total frequency of context */
  xadUINT16 ht[HA_HTLEN];               /* hash table */
  xadUINT8 nec;                 /* counter for no escape expected */
  xadUINT8 maxclen;             /* current maximum length for context */
  xadUINT8 curcon[4];           /* current context */
  xadUINT8 cmask[256];          /* masked characters */
  xadUINT8 cmstack[256];                /* stack of cmask[] entries to clear */
  xadUINT8 cl[HA_NUMCON];               /* context length array */
  xadUINT8 con[HA_NUMCON][4];   /* context array */
  xadUINT8 fe[HA_NUMCON];               /* frequencys under ESCTH in context */
  xadUINT8 fc[HA_NUMCFB];               /* character for frequency array */
  xadUINT8 cc[HA_NUMCON];               /* character counts */
  xadUINT8 rfm[HA_NUMCON];              /* refresh counter array */
  xadUINT8 iec[HA_MAXCLEN+1];   /* initial escape counters */
};

static xadUINT16 HA_find_next(struct HaHscData *dat)
{
  xadINT16 i,k;
  xadUINT16 cp;

  for(i = dat->cslen-1; i >= 0; --i)
  {
    k = dat->hs[i];
    for(cp = dat->ht[k]; cp != HA_NIL; cp = dat->hp[cp])
    {
      if(dat->cl[cp] == i)
      {
        switch(i)
        {
        case 4: if(dat->curcon[3] != dat->con[cp][3]) break;
        case 3: if(dat->curcon[2] != dat->con[cp][2]) break;
        case 2: if(dat->curcon[1] != dat->con[cp][1]) break;
        case 1: if(dat->curcon[0] != dat->con[cp][0]) break;
        case 0: dat->cslen = i; return cp;
        }
      }
    }
  }

  return HA_NIL;
}

static xadUINT16 HA_find_longest(struct HaHscData *dat)
{
  dat->hs[1] = dat->hrt[dat->curcon[0]];
  dat->hs[2] = dat->hrt[(dat->curcon[1]+dat->hs[1])&(HA_HTLEN-1)];
  dat->hs[3] = dat->hrt[(dat->curcon[2]+dat->hs[2])&(HA_HTLEN-1)];
  dat->hs[4] = dat->hrt[(dat->curcon[3]+dat->hs[3])&(HA_HTLEN-1)];
  dat->usp = 0;
  while(dat->cmsp)
    dat->cmask[dat->cmstack[--dat->cmsp]] = 0;
  dat->cslen = HA_MAXCLEN+1;

  return HA_find_next(dat);
}

static xadUINT16 HA_adj_escape_prob(struct HaHscData *dat, xadUINT16 esc, xadUINT16 cp)
{
  if(dat->ft[cp] == 1)
    return (xadUINT16) (dat->iec[dat->cl[cp]] >= (HA_IECLIM >> 1) ? 2 : 1);
  if(dat->cc[cp] == 255)
    return 1;
  if(dat->cc[cp] && ((dat->cc[cp]+1) << 1) >= dat->ft[cp])
  {
    esc = (xadINT16)((xadINT32)esc*((dat->cc[cp]+1) << 1) / dat->ft[cp]);
    if(dat->cc[cp] + 1 == dat->ft[cp])
      esc += (dat->cc[cp]+1)>>1;
  }
  return (xadUINT16) (esc?esc:1);
}

static xadINT16 HA_decode_first(struct HaHscData *dat, xadUINT16 cp)
{
  xadUINT16 c, tv, i;
  xadINT16 sum,tot,esc,cf = 0;
  xadUINT8 sv;

  esc = HA_adj_escape_prob(dat, dat->fe[cp], cp);
  tot = dat->ft[cp];
  if(dat->nec >= HA_NECLIM)
  {
    if(tot <= HA_NECTLIM && dat->nec == HA_NECMAX)
      sv=2;
    else
      sv=1;
    tot <<= sv;
    tv = HA_ac_threshold_val(&dat->arith, tot+esc) >> sv;
    for(c = cp, sum = 0; c != HA_NIL; c = dat->nb[c])
    {
      if(sum+dat->fa[c] <= tv)
        sum += dat->fa[c];
      else
      {
        cf = dat->fa[c] << sv;
        break;
      }
    }
    sum <<= sv;
  }
  else
  {
    tv = HA_ac_threshold_val(&dat->arith, tot+esc);
    for(c = cp, sum = 0; c != HA_NIL; c = dat->nb[c])
    {
      if(sum+dat->fa[c] <= tv)
        sum += dat->fa[c];
      else
      {
        cf = dat->fa[c];
        break;
      }
    }
  }
  dat->usp = 1;
  if(c != HA_NIL)
  {
    HA_ac_in(&dat->arith, sum, sum+cf, tot+esc);
    if(dat->ft[cp] == 1 && dat->iec[dat->cl[cp]])
      --dat->iec[dat->cl[cp]];
    dat->as[0] = c;
    dat->cps[0] = cp;
    c = dat->fc[c];
    if(dat->nec < HA_NECMAX)
      ++dat->nec;
  }
  else
  {
    HA_ac_in(&dat->arith, tot,tot+esc,tot+esc);
    if(dat->ft[cp] == 1 && dat->iec[dat->cl[cp]] < HA_IECLIM)
      ++dat->iec[dat->cl[cp]];
    for(i = cp; i != HA_NIL; sum=i,i=dat->nb[i])
    {
      dat->cmstack[dat->cmsp++] = dat->fc[i];
      dat->cmask[dat->fc[i]]=1;
    }
    dat->cps[0]=0x8000|cp;
    dat->as[0]=sum;
    c = HA_ESC;
    dat->nec = 0;
  }
  return (xadINT16) c;
}

static xadINT16 HA_decode_rest(struct HaHscData *dat, xadUINT16 cp)
{
  xadUINT16 c, tv, i;
  xadINT16 sum,tot,esc,cf = 0;

  esc=tot=0;
  for(i = cp; i != HA_NIL; i=dat->nb[i])
  {
    if(!dat->cmask[dat->fc[i]])
    {
      tot += dat->fa[i];
      if(dat->fa[i] < HA_ESCTH)
        ++esc;
    }
  }
  esc = HA_adj_escape_prob(dat, esc, cp);
  tv = HA_ac_threshold_val(&dat->arith, tot+esc);
  for(c = cp, sum = 0; c != HA_NIL; c = dat->nb[c])
  {
    if(!dat->cmask[dat->fc[c]])
    {
      if(sum+dat->fa[c] <= tv)
        sum += dat->fa[c];
      else
      {
        cf = dat->fa[c];
        break;
      }
    }
  }
  if(c != HA_NIL)
  {
    HA_ac_in(&dat->arith, sum,sum+cf,tot+esc);
    if(dat->ft[cp]==1 && dat->iec[dat->cl[cp]])
      --dat->iec[dat->cl[cp]];
    dat->as[dat->usp] = c;
    dat->cps[dat->usp++] = cp;
    c = dat->fc[c];
    ++dat->nec;
  }
  else
  {
    HA_ac_in(&dat->arith, tot,tot+esc,tot+esc);
    if(dat->ft[cp] == 1 && dat->iec[dat->cl[cp]] < HA_IECLIM)
      ++dat->iec[dat->cl[cp]];
    for(i = cp; i != HA_NIL; sum=i,i=dat->nb[i])
    {
      if(!dat->cmask[dat->fc[i]])
      {
        dat->cmstack[dat->cmsp++] = dat->fc[i];
        dat->cmask[dat->fc[i]] = 1;
      }
    }
    dat->cps[dat->usp] = 0x8000|cp;
    dat->as[dat->usp++]=sum;            /* sum holds last i !! */
    c = HA_ESC;
  }

  return (xadINT16) c;
}

static xadINT16 HA_decode_new(struct HaHscData *dat)
{
  xadINT16 c;
  xadUINT16 tv,sum,tot;

  tot = 257 - dat->cmsp;
  tv = HA_ac_threshold_val(&dat->arith, tot);
  for(c = sum = 0; c < 256; ++c)
  {
    if(dat->cmask[c])
      continue;
    if(sum+1 <= tv)
      ++sum;
    else
      break;
  }
  HA_ac_in(&dat->arith, sum, sum+1, tot);
  return c;
}

static void HA_el_movefront(struct HaHscData *dat, xadUINT16 cp)
{
  if(cp == dat->elf)
    return;
  if(cp == dat->ell)
    dat->ell = dat->elp[cp];
  else
  {
    dat->elp[dat->eln[cp]] = dat->elp[cp];
    dat->eln[dat->elp[cp]] = dat->eln[cp];
  }
  dat->elp[dat->elf] = cp;
  dat->eln[cp] = dat->elf;
  dat->elf = cp;
}

static void HA_release_cfblocks(struct HaHscData *dat)
{
  xadUINT16 i,j,d;

  do
  {
    do
    {
      if(++dat->nrel == HA_NUMCON)
        dat->nrel = 0;
    } while(dat->nb[dat->nrel] == HA_NIL);
    for(i=0; i <= dat->usp; ++i)
      if((dat->cps[i]&0x7fff) == dat->nrel)
        break;
  } while(i <= dat->usp);

  for(i = dat->nb[dat->nrel], d = dat->fa[dat->nrel]; i != HA_NIL; i = dat->nb[i])
    if(dat->fa[i] < d)
      d = dat->fa[i];
  ++d;
  if(dat->fa[dat->nrel] < d)
  {
    for(i = dat->nb[dat->nrel]; dat->fa[i] < d && dat->nb[i] != HA_NIL; i = dat->nb[i])
      ;
    dat->fa[dat->nrel] = dat->fa[i];
    dat->fc[dat->nrel] = dat->fc[i];
    j = dat->nb[i];
    dat->nb[i] = dat->fcfbl;
    dat->fcfbl = dat->nb[dat->nrel];
    if((dat->nb[dat->nrel] = j) == HA_NIL)
    {
      dat->cc[dat->nrel] = 0;
      dat->fe[dat->nrel] = (dat->ft[dat->nrel] = dat->fa[dat->nrel]) < HA_ESCTH ? 1 : 0;
      return;
    }
  }
  dat->fe[dat->nrel] = (dat->ft[dat->nrel] = dat->fa[dat->nrel] /= d) < HA_ESCTH ? 1 : 0;
  dat->cc[dat->nrel] = 0;
  for(j = dat->nrel, i = dat->nb[j]; i != HA_NIL;)
  {
    if(dat->fa[i] < d)
    {
      dat->nb[j] = dat->nb[i];
      dat->nb[i] = dat->fcfbl;
      dat->fcfbl = i;
      i = dat->nb[j];
    }
    else
    {
       ++dat->cc[dat->nrel];
       dat->ft[dat->nrel] += dat->fa[i] /= d;
       if(dat->fa[i] < HA_ESCTH)
         dat->fe[dat->nrel]++;
       j=i;
       i = dat->nb[i];
    }
  }
}

static void HA_add_model(struct HaHscData *dat, xadINT16 c)
{
  xadUINT16 i;
  xadINT16 cp;

  while(dat->usp != 0)
  {
    i = dat->as[--dat->usp];
    cp = dat->cps[dat->usp];
    if(cp&0x8000)
    {
      cp &= 0x7fff;
      if(dat->fcfbl == HA_NIL)
        HA_release_cfblocks(dat);
      dat->nb[i] = dat->fcfbl;
      i = dat->nb[i];
      dat->fcfbl = dat->nb[dat->fcfbl];
      dat->nb[i] = HA_NIL;
      dat->fa[i] = 1;
      dat->fc[i] = c;
      ++dat->cc[cp];
      ++dat->fe[cp];
    }
    else if(++dat->fa[i] == HA_ESCTH)
      --dat->fe[cp];
    if((dat->fa[i]<<1) < ++dat->ft[cp] / (dat->cc[cp]+1))
      --dat->rfm[cp];
    else if(dat->rfm[cp] < HA_RFMINI)
      ++dat->rfm[cp];
    if(!dat->rfm[cp] || dat->ft[cp] >= HA_MAXTVAL)
    {
      ++dat->rfm[cp];
      dat->fe[cp] = dat->ft[cp]=0;
      for(i = cp; i != HA_NIL; i = dat->nb[i])
      {
        if(dat->fa[i] > 1)
        {
          dat->ft[cp] += dat->fa[i] >>= 1;
          if(dat->fa[i] < HA_ESCTH)
            ++dat->fe[cp];
        }
        else
        {
          ++dat->ft[cp];
          ++dat->fe[cp];
        }
      }
    }
  }
}

#define HA_HASH(s,l,h)  { h = 0; if (l) h=dat->hrt[s[0]];             \
                          if (l>1) h=dat->hrt[(s[1]+h)&(HA_HTLEN-1)]; \
                          if (l>2) h=dat->hrt[(s[2]+h)&(HA_HTLEN-1)]; \
                          if (l>3) h=dat->hrt[(s[3]+h)&(HA_HTLEN-1)];}

static xadUINT16 HA_make_context(struct HaHscData *dat, xadUINT8 conlen, xadINT16 c)
{
  xadINT16 i;
  xadUINT16 nc,fp;

  nc = dat->ell;
  dat->ell = dat->elp[nc];
  dat->elp[dat->elf] = nc;
  dat->eln[nc] = dat->elf;
  dat->elf = nc;
  if(dat->cl[nc] != 0xff)
  {
    if(dat->cl[nc] == HA_MAXCLEN && --dat->dropcnt==0)
      dat->maxclen = HA_MAXCLEN-1;
    HA_HASH(dat->con[nc], dat->cl[nc], i);
    if(dat->ht[i] == nc)
      dat->ht[i] = dat->hp[nc];
    else
    {
      for(i = dat->ht[i]; dat->hp[i] != nc; i = dat->hp[i])
        ;
      dat->hp[i] = dat->hp[nc];
    }
    if(dat->nb[nc] != HA_NIL)
    {
      for(fp = dat->nb[nc]; dat->nb[fp] != HA_NIL; fp = dat->nb[fp])
        ;
      dat->nb[fp] = dat->fcfbl;
      dat->fcfbl = dat->nb[nc];
    }
  }
  dat->nb[nc] = HA_NIL;
  dat->fe[nc] = dat->ft[nc] = dat->fa[nc] = 1;
  dat->fc[nc] = c;
  dat->rfm[nc] = HA_RFMINI;
  dat->cc[nc] = 0;
  dat->cl[nc] = conlen;
  dat->con[nc][0] = dat->curcon[0];
  dat->con[nc][1] = dat->curcon[1];
  dat->con[nc][2] = dat->curcon[2];
  dat->con[nc][3] = dat->curcon[3];
  HA_HASH(dat->curcon, conlen, i);
  dat->hp[nc] = dat->ht[i];
  dat->ht[i] = nc;
  return nc;
}

static xadINT32 HA_hsc(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct HaHscData *dat;
  xadINT16 c = 0, i;
  xadUINT16 cp;
  xadINT32 z,h,l,t;
  xadUINT8 ncmax,ncmin;

  if((dat = (struct HaHscData *) xadAllocVec(XADM sizeof(struct HaHscData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    dat->arith.io = io;

    dat->maxclen = HA_MAXCLEN;
    dat->iec[0] = (HA_IECLIM>>1);
    for(i=1; i <= HA_MAXCLEN; ++i)
      dat->iec[i] = (HA_IECLIM>>1)-1;
    dat->dropcnt = HA_NUMCON/4;
/*    nec=0; */
/*    nrel=0; */
/*    dat->hs[0] = 0; */
    for(i=0; i < HA_HTLEN; ++i)
      dat->ht[i] = HA_NIL;
    for(i=0; i < HA_NUMCON; ++i)
    {
      dat->eln[i] = i+1;
      dat->elp[i] = i-1;
      dat->cl[i] = 0xff;
      dat->nb[i] = HA_NIL;
    }
/*    dat->elf=0; */
    dat->ell = HA_NUMCON-1;
    for(i = HA_NUMCON; i < HA_NUMCFB-1; ++i)
      dat->nb[i] = i+1;
    dat->nb[i] = HA_NIL;
    dat->fcfbl = HA_NUMCON;
/*    dat->curcon[3] = dat->curcon[2] = dat->curcon[1] = dat->curcon[0] = 0; */
/*    dat->cmsp = 0; */
/*    for(i=0; i < 256; ++i) */
/*      dat->cmask[i] = 0; */
    for(z=10, i=0; i < HA_HTLEN; ++i)
    {
      h = z/(2147483647L/16807L);
      l = z%(2147483647L/16807L);
      if((t = 16807L*l-(2147483647L%16807L)*h)>0)
        z=t;
      else
        z=t+2147483647L;
      dat->hrt[i] = z&(HA_HTLEN-1);
    }

    HA_ac_init_decode(&dat->arith);
    while(c != HA_ESC && !(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      cp = HA_find_longest(dat);
      ncmin = cp == HA_NIL ? 0 : dat->cl[cp]+1;
      ncmax = dat->maxclen+1;
      for(;;)
      {
        if(cp == HA_NIL)
        {
          c = HA_decode_new(dat);
          break;
        }
        if((c = dat->cmsp ? HA_decode_rest(dat, cp) : HA_decode_first(dat, cp)) != HA_ESC)
        {
          HA_el_movefront(dat, cp);
          break;
        }
        cp = HA_find_next(dat);
      }
      if(c != HA_ESC)
      {
        HA_add_model(dat, c);
        while(ncmax > ncmin)
          HA_make_context(dat, --ncmax, c);
        dat->curcon[3] = dat->curcon[2];
        dat->curcon[2] = dat->curcon[1];
        dat->curcon[1] = dat->curcon[0];
        dat->curcon[0] = c;
        xadIOPutChar(io, c);
      }
    }

    xadFreeObjectA(XADM dat, 0);
  }
  return io->xio_Error;
}

/*****************************************************************************/

XADUNARCHIVE(HA)
{
  struct xadFileInfo *fi;
  struct xadInOut *io;
  xadINT32 err;

  fi = ai->xai_CurFile;

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC16|XADIOF_NOINENDERR, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;
    io->xio_CRC32 = ~0;

    switch(HAPI(fi)->Method)
    {
    case HATYPE_CPY:
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        xadIOPutChar(io, xadIOGetChar(io));
      err = io->xio_Error;
      break;
    case HATYPE_ASC: err = HA_asc(io); break;
    case HATYPE_HSC: err = HA_hsc(io); break;
    default: err = XADERR_DATAFORMAT;
    }

    if(!err)
      err = xadIOWriteBuf(io);
    if(!err && ~io->xio_CRC32 != HAPI(fi)->CRC32)
      err = XADERR_CHECKSUM;
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

XADFIRSTCLIENT(HA) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  HA_VERSION,
  HA_REVISION,
  22,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_HA,
  "HA",
  XADRECOGDATAP(HA),
  XADGETINFOP(HA),
  XADUNARCHIVEP(HA),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(HA)

#endif /* XADMASTER_HA_C */
