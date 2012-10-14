#ifndef XADMASTER_MDC_C
#define XADMASTER_MDC_C

/*  $Id: MDC.c,v 1.8 2005/06/23 14:54:41 stoecker Exp $
    MDC disk archiver client

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
#include "xadIO.c"
#include "xadIO_XPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("MDC 1.1 (23.2.2004)")

#define MDC_VERSION             1
#define MDC_REVISION            1

struct MDC {
  xadUINT8 ID[4]; /* 0x4D4443xx */
  xadUINT8 LowCyl[2];
  xadUINT8 HighCyl[2];
  xadUINT8 CylSize[4];
  xadUINT8 Unknown[4]; /* 0x00015858 */
};

XADRECOGDATA(MDC)
{
  if(data[0] == 'M' && data[1] == 'D' && data[2] == 'C')
    return 1;
  else
    return 0;
}

XADGETINFO(MDC)
{
  xadINT32 err, low = -1, high = -1, cylsize = -1;
  struct xadDiskInfo *xdi;
  struct {
    xadUINT8 id[3];
    xadUINT8 num;
    xadUINT8 xpkid[4];
    xadUINT8 crsize[4];
    xadUINT8 type[4];
    xadUINT8 size[4];
  } dat;

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, sizeof(struct MDC), 0, ai)))
  {
    while(ai->xai_InPos < ai->xai_InSize && !err)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 20, &dat, ai)))
      {
        if(dat.id[0] != 'M' || dat.id[1] != 'D' || dat.id[2] != 'C')
          err = XADERR_ILLEGALDATA;
        else
        {
          if(cylsize == -1)
            cylsize = EndGetM32(dat.size);
          if(low == -1)
            low = high = dat.num;
          else
            ++high;

          if(high != dat.num || cylsize != EndGetM32(dat.size))
            err = XADERR_ILLEGALDATA;
          else
            err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat.crsize)-8,
	    0, ai);
        }
      }
    }

    if(!err)
    {
      if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO,
      0)))
        err = XADERR_NOMEMORY;
      else
      {
        ai->xai_DiskInfo = xdi;

        xdi->xdi_EntryNumber = 1;
        xdi->xdi_Cylinders = high+1;
        xdi->xdi_LowCyl = low;
        xdi->xdi_HighCyl = high;
        /* most devices should use 512 as blocksize */
        xdi->xdi_SectorSize = 512;
        xdi->xdi_CylSectors = cylsize>>9;
        xdi->xdi_TotalSectors = xdi->xdi_Cylinders*xdi->xdi_CylSectors;
        xdi->xdi_Flags = XADDIF_GUESSHEADS|XADDIF_GUESSTRACKSECTORS
        |XADDIF_GUESSCYLINDERS|XADDIF_SEEKDATAPOS;
        if(xdi->xdi_CylSectors & 1)
        {
          xdi->xdi_Heads = 1;
          xdi->xdi_TrackSectors = xdi->xdi_CylSectors;
        }
        else
        {
          xdi->xdi_Heads = 2;
          xdi->xdi_TrackSectors = xdi->xdi_CylSectors>>1;
        }
        xdi->xdi_DataPos = sizeof(struct MDC);
      }
    }
  }

  return err;
}

XADUNARCHIVE(MDC)
{
  xadINT32 i, err = 0;
  struct xadInOut *io;
  struct {
    xadUINT8 id[3];
    xadUINT8 num;
    xadUINT8 xpkid[4];
    xadUINT8 size[4];
  } dat;

  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 12, &dat, ai)))
    {
      if(dat.id[0] != 'M' || dat.id[1] != 'D' || dat.id[2] != 'C' || dat.num != i)
        err = XADERR_ILLEGALDATA;
      else
        err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat.size), 0, ai);
    }
  }

  for(; !err && i <= ai->xai_HighCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 12, &dat, ai)) &&
    !(err = xadHookAccess(XADM XADAC_INPUTSEEK, -8, 0, ai)))
    {
      if(dat.id[0] != 'M' || dat.id[1] != 'D' || dat.id[2] != 'C' || dat.num != i)
        err = XADERR_ILLEGALDATA;
      else if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
      |XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
      {
        io->xio_InSize = EndGetM32(dat.size)+8;
        io->xio_OutSize = ai->xai_CurDisk->xdi_SectorSize
        *ai->xai_CurDisk->xdi_CylSectors;

        if(!(err = xadIO_XPK(io, ai->xai_Password)))
          err = xadIOWriteBuf(io);

        xadFreeObjectA(XADM io, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
  }

  return err;
}

XADFIRSTCLIENT(MDC) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  MDC_VERSION,
  MDC_REVISION,
  4,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_MDC,
  "Marc's DiskCruncher",
  XADRECOGDATAP(MDC),
  XADGETINFOP(MDC),
  XADUNARCHIVEP(MDC),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(MDC)

#endif /* XADMASTER_MDC_C */
