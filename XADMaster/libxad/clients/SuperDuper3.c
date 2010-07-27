#ifndef XADMASTER_SUPERDUPER3_C
#define XADMASTER_SUPERDUPER3_C

/*  $Id: SuperDuper3.c,v 1.7 2005/06/23 14:54:41 stoecker Exp $
    SuperDuper3 disk image client

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
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "../unix/xadClient.h"
#include "xadIO_XPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("SuperDuper3 1.4 (23.02.2004)")

#define SUPERDUPER3_VERSION     1
#define SUPERDUPER3_REVISION    4

XADRECOGDATA(SuperDuper3)
{
  if(EndGetM32(data) == 0x464F524D &&
  (EndGetM32(data+8) == 0x53444444 || EndGetM32(data+8) == 0x53444844))
    return 1;
  else
    return 0;
}

XADGETINFO(SuperDuper3)
{
  xadINT32 err;
  xadUINT8 data[9*4];
  xadUINT32 num = 0;
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;
  ai->xai_DiskInfo = xdi;

  if((err = xadHookAccess(XADM XADAC_READ, 12, data, ai)))
    return err;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_Cylinders = 80;
  xdi->xdi_Heads = 2;
  xdi->xdi_Flags = XADDIF_GUESSLOWCYL|XADDIF_GUESSHIGHCYL|XADDIF_SEEKDATAPOS;
/*xdi->xdi_LowCyl = 0; */
  xdi->xdi_DataPos = 12;
  xdi->xdi_TrackSectors = (EndGetM32(data+8) == 0x53444844) ? 22 : 11;
  xdi->xdi_CylSectors = 2 * xdi->xdi_TrackSectors;
  xdi->xdi_TotalSectors = 80 * xdi->xdi_CylSectors;

  while(ai->xai_InPos < ai->xai_InSize)
  {
    if((err = xadHookAccess(XADM XADAC_READ, 36, data, ai)))
      return err;
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetM32(data+4)-28, 0, ai)))
      return err;
    ++num;
    if(EndGetM32(data) == 0x58504B46 && (EndGetM32(data+8*4) & (1<<25)))
    { /* check for password flag in every entry */
      ai->xai_Flags |= XADAIF_CRYPTED;
      xdi->xdi_Flags |= XADDIF_CRYPTED;
    }
  }

  if(num > 80)
    return XADERR_ILLEGALDATA;

  xdi->xdi_HighCyl = num-1;

  return 0;
}

XADUNARCHIVE(SuperDuper3)
{
  xadUINT32 i;
  xadINT32 err = 0;
  xadUINT8 data[8];

  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 8, data, ai)))
      err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetM32(data+4), 0, ai);
  }

  for(; !err && i <= ai->xai_HighCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 8, data, ai)))
    {
      if(EndGetM32(data) == 0x58504B46)
      {
        if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) -8, 0, ai)))
        {
          struct xadInOut *io;
          if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
          |XADIOF_NOOUTENDERR, ai, xadMasterBase)))
          {
            io->xio_InSize = EndGetM32(data+4)+8;
            if(!(err = xadIO_XPK(io, io->xio_ArchiveInfo->xai_Password)))
              err = xadIOWriteBuf(io);
            xadFreeObjectA(XADM io, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
      }
      else /* normal BODY chunk */
        err = xadHookAccess(XADM XADAC_COPY, (xadUINT32) EndGetM32(data+4), 0, ai);
    }
  }

  return err;
}

XADFIRSTCLIENT(SuperDuper3) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SUPERDUPER3_VERSION,
  SUPERDUPER3_REVISION,
  12,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_SUPERDUPER3,
  "SuperDuper3",
  XADRECOGDATAP(SuperDuper3),
  XADGETINFOP(SuperDuper3),
  XADUNARCHIVEP(SuperDuper3),
  0
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(SuperDuper3)

#endif /* XADMASTER_SUPERDUPER3_C */
