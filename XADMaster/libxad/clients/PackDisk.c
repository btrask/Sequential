#ifndef XADMASTER_PACKDISK_C
#define XADMASTER_PACKDISK_C

/*  $Id: PackDisk.c,v 1.9 2005/06/23 14:54:41 stoecker Exp $
    PackDisk disk archiver client

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
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("PackDisk 1.2 (23.2.2004)")

#define PACKDISK_VERSION                1
#define PACKDISK_REVISION               2

struct PackDiskInfo {
  xadUINT8 EntrySize[2];
  xadUINT8 EntryPos[4];
  xadUINT8 pad1[4];
  xadUINT8 uncrunched;
  xadUINT8 pad2;
};

struct PackDisk {
  xadUINT8 ID[8];
  xadUINT8 Version[2];
  xadUINT8 pad1[2];
  xadUINT8 Name[30];
};

XADRECOGDATA(PackDisk)
{
  if(data[0] == 'D' && data[1] == 'I' && data[2] == 'S' && data[3] == 'K' &&
  data[4] == 'P' && data[5] == 'A' && data[6] == 'C' && data[7] == 'K' &&
  !data[8] && data[9] == 1)
    return 1;
  else
    return 0;
}

XADGETINFO(PackDisk)
{
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;

  xdi->xdi_Cylinders = 80;
/*  xdi->xdi_LowCyl = 0; */
  xdi->xdi_HighCyl = 79;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_CylSectors = 22;
  xdi->xdi_Heads = 2;
  xdi->xdi_TotalSectors = 1760;
  xdi->xdi_Flags = XADDIF_SEEKDATAPOS | XADDIF_EXTRACTONBUILD;
  xdi->xdi_DataPos = 42;

  return xadAddDiskEntryA(XADM xdi, ai, 0);
}

XADUNARCHIVE(PackDisk)
{
  struct PackDiskInfo pdi[80];
  struct xadInOut *io;
  xadINT32 i, j, err;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct PackDiskInfo)*80,
  pdi, ai)))
  {
    for(i = ai->xai_LowCyl; !err && i <= ai->xai_HighCyl; ++i)
    {
      if((j = EndGetM32(pdi[i].EntryPos) - ai->xai_InPos))
        err = xadHookAccess(XADM XADAC_INPUTSEEK, j, 0, ai);

      if((EndGetM32(pdi[i].EntryPos) < 42+sizeof(struct PackDiskInfo)*80)
      || !EndGetM16(pdi[i].EntrySize))
        err = XADERR_ILLEGALDATA;
      if(!err)
      {
        if(pdi[i].uncrunched == 1)
        {
          err = xadHookAccess(XADM XADAC_COPY, EndGetM16(pdi[i].EntrySize),
          0, ai);
        }
        else if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
        |XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
        {
          io->xio_InSize = EndGetM16(pdi[i].EntrySize);
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
  }

  return err;
}

XADFIRSTCLIENT(PackDisk) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  PACKDISK_VERSION,
  PACKDISK_REVISION,
  10,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_PACKDISK,
  "PackDisk",
  XADRECOGDATAP(PackDisk),
  XADGETINFOP(PackDisk),
  XADUNARCHIVEP(PackDisk),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(PackDisk)

#endif /* XADMASTER_PACKDISK_C */
