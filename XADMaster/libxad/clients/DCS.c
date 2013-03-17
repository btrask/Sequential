#ifndef XADMASTER_DCS_C
#define XADMASTER_DCS_C

/*  $Id: DCS.c,v 1.9 2005/06/23 14:54:40 stoecker Exp $
    DCS disk archiver client

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
#include "xadIO_XPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      11
#endif

XADCLIENTVERSTR("DCS 1.1 (22.2.2004)")

#define DCS_VERSION             1
#define DCS_REVISION            1

XADRECOGDATA(DCS)
{
  if(data[0] == 'D' && data[1] == 'C' && data[2] == 'S' && !data[3]
  && !data[4] && data[6] == 'T' && data[7] == 'R')
    return 1;
  return 0;
  /* data[5] == number of crypt passes */
}

XADGETINFO(DCS)
{
  xadINT32 err, low = -1, high = -1, cr;
  struct xadDiskInfo *xdi;
  xadUINT8 dat[6];

  if(!(err = xadHookAccess(XADM XADAC_READ, 6, dat, ai)))
  {
    cr = dat[5];
    while(ai->xai_InPos+6 < ai->xai_InSize && !err)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 6, dat, ai)))
      {
        if(dat[0] != 'T' || dat[1] != 'R' || dat[2] != 0)
          err = XADERR_ILLEGALDATA;
        else
        {
          if(low == -1)
            low = high = dat[3];
          else
            ++high;

          if(high != dat[3])
            err = XADERR_ILLEGALDATA;
          else
            err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM16(dat+4), 0, ai);
        }
      }
    }
    if(!err)
    {
      if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
        err = XADERR_NOMEMORY;
      else
      {
        xdi->xdi_Cylinders = 80;
        xdi->xdi_LowCyl = low;
        xdi->xdi_HighCyl = high;
        xdi->xdi_SectorSize = 512;
        xdi->xdi_CylSectors = 22;
        xdi->xdi_TotalSectors = 1760;
        xdi->xdi_Heads = 2;
        xdi->xdi_TrackSectors = 11;
        xdi->xdi_PrivateInfo = (xadPTR) cr;
        xdi->xdi_Flags = XADDIF_SEEKDATAPOS | XADDIF_EXTRACTONBUILD | (cr ? XADDIF_CRYPTED : 0);
        xdi->xdi_DataPos = 6;
        err = xadAddDiskEntryA(XADM xdi, ai, 0);
      }
    }
  }

  return err;
}

XADUNARCHIVE(DCS)
{
  xadUINT8 dat[6];
  xadSTRPTR mem1, mem2;
  xadINT32 i, j, cr, err = 0;

  cr = (xadINT32) ai->xai_CurDisk->xdi_PrivateInfo + 1;
  if((mem1 = (xadSTRPTR) xadAllocVec(XADM 22*512*2+2000*2, XADMEMF_PUBLIC)))
  {
    mem2 = mem1+512*22+2000;

    /* skip entries */
    for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 6, dat, ai)))
      {
        if(dat[0] != 'T' || dat[1] != 'R' || dat[2] != 0 || dat[3] != i)
          err = XADERR_ILLEGALDATA;
        else
          err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM16(dat+4), 0, ai);
      }
    }

    for(; !err && i <= ai->xai_HighCyl; ++i)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 6, dat, ai)))
      {
        if(dat[0] != 'T' || dat[1] != 'R' || dat[2] != 0 || dat[3] != i)
          err = XADERR_ILLEGALDATA;
        else
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, EndGetM16(dat+4), mem2, ai)))
          {
            xadSTRPTR pwd;
            xadSTRING password[101];
            xadUINT32 p;
            for(j = 0; j < cr && !err; ++j)
            {
              struct xadInOut *io;
              p = 0;
              if((pwd = ai->xai_Password))
              {
                switch(cr-j)
                {
                case 5: while(*pwd != '|' && *pwd) ++pwd; if(*pwd) ++pwd;
                case 4: while(*pwd != '|' && *pwd) ++pwd; if(*pwd) ++pwd;
                case 3: while(*pwd != '|' && *pwd) ++pwd; if(*pwd) ++pwd;
                case 2:
                  while(*pwd && *pwd != '|' && p < 100)
                    password[p++] = *(pwd++);
                  break;
                }
              }
              password[p] = 0;
              if((io = xadIOAlloc(XADIOF_NOCRC16|XADIOF_NOCRC32, ai, xadMasterBase)))
              {
                io->xio_InBufferSize = io->xio_InSize = EndGetM16(dat+4);
                io->xio_OutBufferSize = io->xio_OutSize = 512*22+2000;
                io->xio_InBuffer = mem2;
                io->xio_OutBuffer = mem1;
                if(!(err = xadIO_XPK(io, p ? password : (xadSTRPTR) 0)))
                  xadCopyMem(XADM mem1, mem2, 512*22+2000);
                else if(j+1 < cr) /* correct the error code */
                  err = XADERR_PASSWORD;
                xadFreeObjectA(XADM io, 0);
              }
              else
                err = XADERR_NOMEMORY;
            }
            if(!err)
              err = xadHookAccess(XADM XADAC_WRITE, 512*22, mem1, ai);
          }
        }
      }
    }
    xadFreeObjectA(XADM mem1, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

XADFIRSTCLIENT(DCS) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DCS_VERSION,
  DCS_REVISION,
  8,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_DCS,
  "DCS",
  XADRECOGDATAP(DCS),
  XADGETINFOP(DCS),
  XADUNARCHIVEP(DCS),
  0
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(DCS)

#endif /* XADMASTER_DCS_C */
