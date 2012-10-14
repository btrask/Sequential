#ifndef XADMASTER_CRUNCHDISK_C
#define XADMASTER_CRUNCHDISK_C

/*  $Id: CrunchDisk.c,v 1.6 2005/06/23 14:54:40 stoecker Exp $
    CrunchDisk disk archiver client from Klaus Deppisch

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
//#include "xadXPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("CrunchDisk 1.1 (23.2.2004)")

#define CRUNCHDISK_VERSION              1
#define CRUNCHDISK_REVISION             1

struct CrunchDisk {
  xadUINT32 ID;         /* 0x43444630 - "CDF0" */
  xadUINT32 BlockSize;
  xadUINT32 BlocksPerTrack;
  xadUINT32 Heads;
  xadUINT32 LowCyl;
  xadUINT32 HighCyl;
  xadUINT8 IsPassword;
  xadUINT8 pad0;
  xadUINT16 PasswordChecksum; /* PX20 password checksum */
  xadUINT16 Efficiency;
  xadUINT16 Packertype; /* 0 = none, 1 = pp, 2 = xpk */
};
/* CYL0 xxxx - unpacked data */
/* CYL1 xxxx - packed data */

static const xadSTRPTR crunchdisktypes[3] = {(xadSTRPTR)"stored", (xadSTRPTR)"powerpacked", (xadSTRPTR)"XPK"};

#define PPgetbits(n, res) {xadUINT32 i = n, r = 0; while(i--){  \
        if(shift_in & (1<<8)) shift_in = (1<<16) + *(--src);    \
        r = (r<<1) | (shift_in & 1); shift_in >>= 1;}res = r;}
#define PPskipbits(n) {xadUINT32 i = n; while(i--){if(shift_in & (1<<8)) shift_in = (1<<16) + *(--src); shift_in >>= 1;}}

static void PPdepack(xadUINT8 *src, xadUINT8 *depacked, xadUINT32 plen, xadUINT32 unplen, xadUINT8 *offset_sizes)
{
  xadUINT32 shift_in = (1<<8), bytes, offset;
  xadUINT8 *dest;
  xadINT32 n_bits, idx, to_add;

  src += plen - 4;
  dest = depacked + unplen;
  PPskipbits(src[3]);
  while(dest > depacked)
  {
    /* copy some bytes from the source anyway */
    PPgetbits(1, to_add);
    if(!to_add)
    {
      bytes = 1;
      do
      {
        PPgetbits(2, to_add);
        bytes += to_add;
      } while(to_add == 3);
      while(bytes--)
      {
        if(--dest < depacked)
          return;
        PPgetbits(8, *dest);
      }
    }
    /* decode what to copy from the destination file */
    PPgetbits(2, idx);
    n_bits = offset_sizes[idx];
    /* bytes to copy */
    bytes = idx+2;
    if(idx == 3) /* 3 means bytes >= 4+1 */
    {
      /* and maybe a bigger offset */
      PPgetbits(1, to_add);
      PPgetbits((to_add ? n_bits : 7), offset);
      do
      {
        PPgetbits(3, to_add);
        bytes += to_add;
      } while(to_add == 7);
    }
    else
      PPgetbits(n_bits, offset);

    ++offset;
    while(bytes--)
    {
      if(--dest < depacked)
        return;
      *dest = dest[offset];
    }
  }
}

XADRECOGDATA(CrunchDisk)
{
  if(((xadUINT32 *) data)[0] == 0x43444630)
    return 1;
  else
    return 0;
}

XADGETINFO(CrunchDisk)
{
  xadINT32 err;
  struct CrunchDisk *cd;
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObject(XADM XADOBJ_DISKINFO, XAD_OBJPRIVINFOSIZE,
  sizeof(struct CrunchDisk), TAG_DONE)))
    return XADERR_NOMEMORY;
  ai->xai_DiskInfo = xdi;
  cd = (struct CrunchDisk *) xdi->xdi_PrivateInfo;

  if((err = xadHookAccess(XADM XADAC_READ, sizeof(struct CrunchDisk), cd, ai)))
    return err;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_EntryInfo = crunchdisktypes[cd->Packertype];
  xdi->xdi_Cylinders = cd->HighCyl-cd->LowCyl+1;
  xdi->xdi_LowCyl = cd->LowCyl;
  xdi->xdi_HighCyl = cd->HighCyl;
  xdi->xdi_SectorSize = cd->BlockSize;
  xdi->xdi_TrackSectors = cd->BlocksPerTrack;
  xdi->xdi_Heads = cd->Heads;
  xdi->xdi_CylSectors = xdi->xdi_TrackSectors*xdi->xdi_Heads;
  xdi->xdi_TotalSectors = xdi->xdi_Cylinders*xdi->xdi_CylSectors;
  xdi->xdi_Flags = XADDIF_SEEKDATAPOS;
  xdi->xdi_DataPos = sizeof(struct CrunchDisk);

  return 0;
}

static void CrunchDiskResort(xadSTRPTR s, xadSTRPTR d, xadUINT32 size, xadUINT32 numblocks, xadUINT32 fullsize)
{
  xadINT32 i;
  xadSTRPTR p, e;

  while(numblocks--)
  {
    e = d+size;
    if(fullsize >= size)
    {
      for(i = 0; i < 4; ++i)
      {
        for(p = d++; p < e; p += 4)
          *p = *(s++);
      }
      fullsize -= size;
    }
    else
    {
      for(i = 0; i < size; ++i)
        *(d++) = 0;
    }
    d = e;
  }
}

XADUNARCHIVE(CrunchDisk)
{
  struct CrunchDisk *cd;
  xadSTRPTR buf, s;
  xadUINT8 offset_sizes[4];
  xadINT32 i, err = 0, m;
  struct {
    xadUINT32 a;
    xadUINT32 s;
  } dat;

  cd = (struct CrunchDisk *) ai->xai_CurDisk->xdi_PrivateInfo;
  m = ai->xai_CurDisk->xdi_CylSectors*cd->BlockSize;
  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 8, &dat, ai)))
    {
      if(dat.a != 0x43594C30 && dat.a != 0x43594C31)
        err = XADERR_ILLEGALDATA;
      else
        err = xadHookAccess(XADM XADAC_INPUTSEEK, dat.s, 0, ai);
    }
  }

  if(cd->Packertype == 1)
  {
    offset_sizes[0] = offset_sizes[1] = offset_sizes[2] = offset_sizes[3] = 9;

    switch(cd->Efficiency)
    {
    case 4: ++offset_sizes[3];
    case 3: ++offset_sizes[3]; ++offset_sizes[2];
    case 2: ++offset_sizes[3]; ++offset_sizes[2];
    case 1: ++offset_sizes[3]; ++offset_sizes[2]; ++offset_sizes[1];
    }
  }

  if((buf = (xadSTRPTR) xadAllocVec(XADM m, XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    for(; !err && i <= ai->xai_HighCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 8, &dat, ai)))
      {
        switch(dat.a)
        {
        case 0x43594C30:
          err = xadHookAccess(XADM XADAC_COPY, dat.s, 0, ai);
          break;
        case 0x43594C31:
          switch(cd->Packertype)
          {
          case 0:
            if((s = (xadSTRPTR) xadAllocVec(XADM dat.s, XADMEMF_PUBLIC)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, dat.s, s, ai)))
              {
                CrunchDiskResort(s, buf, cd->BlockSize, ai->xai_CurDisk->xdi_CylSectors, dat.s);
                err = xadHookAccess(XADM XADAC_WRITE, m, buf, ai);
              }
              xadFreeObjectA(XADM s, 0);
            }
            else
              err = XADERR_NOMEMORY;
            break;
          case 1:
            if((s = (xadSTRPTR) xadAllocVec(XADM dat.s, XADMEMF_PUBLIC)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, dat.s, s, ai)))
              {
                xadSTRPTR r;

                if((r = (xadSTRPTR) xadAllocVec(XADM m, XADMEMF_PUBLIC)))
                {
                  PPdepack((xadUINT8 *)s, (xadUINT8 *)r, dat.s, m, offset_sizes);
                  CrunchDiskResort(r, buf, cd->BlockSize, ai->xai_CurDisk->xdi_CylSectors, m);
                  err = xadHookAccess(XADM XADAC_WRITE, m, buf, ai);
                  xadFreeObjectA(XADM r, 0);
                }
                else
                  err = XADERR_NOMEMORY;
              }
              xadFreeObjectA(XADM s, 0);
            }
            else
              err = XADERR_NOMEMORY;
            break;
          /*case 2: // XPK not supported
            if(!(err = xpkDecrunch(&s, &dat.s, ai, xadMasterBase)))
            {
              CrunchDiskResort(s, buf, cd->BlockSize, ai->xai_CurDisk->xdi_CylSectors, dat.s);
              err = xadHookAccess(XADM XADAC_WRITE, m, buf, ai);
              xadFreeObjectA(XADM s, 0);
            }
            break;*/
          default: err = XADERR_ILLEGALDATA; break;
          }
          break;
        default: err = XADERR_ILLEGALDATA; break;
        }
      }
    }
    xadFreeObjectA(XADM buf, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

XADFIRSTCLIENT(CrunchDisk) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  CRUNCHDISK_VERSION,
  CRUNCHDISK_REVISION,
  4,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_CRUNCHDISK,
  "CrunchDisk",
  XADRECOGDATAP(CrunchDisk),
  XADGETINFOP(CrunchDisk),
  XADUNARCHIVEP(CrunchDisk),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(CrunchDisk)

#endif /* XADMASTER_CRUNCHDISK_C */
