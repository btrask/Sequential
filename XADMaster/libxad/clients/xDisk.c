#ifndef XADMASTER_XDISK_C
#define XADMASTER_XDISK_C

/*  $Id: xDisk.c,v 1.10 2005/06/23 14:54:41 stoecker Exp $
    xDisk disk archiver client

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

XADCLIENTVERSTR("xDisk 1.6 (23.2.2004)")

#define XDISK_VERSION           1
#define XDISK_REVISION          6
#define GDC_VERSION             XDISK_VERSION
#define GDC_REVISION            XDISK_REVISION

struct xDisk {
  xadUINT8 xd_Header[4];       /* equals 'XDS0' */
  xadUINT8 xd_Date[12];        /* date of creation (an Amiga DateStamp) */
  xadUINT8 xd_PackTime[4];     /* in seconds */
  xadUINT8 xd_AttnFlags[2];    /* ExecBase->AttnFlags */
  xadUINT8 xd_SoftVer[2];      /* ExecBase->SoftVer */
  xadUINT8 xd_CylinderSize[4]; /* Size of one cylinder */
  xadUINT8 xd_NumCylinders[4]; /* Number of cylinders */
  xadUINT8 xd_InfoTextSize[4]; /* no text == 0 */
  xadUINT8 xd_LowCyl[4];       /* lowest crunched cylinder */
  xadUINT8 xd_HighCyl[4];      /* highest crunched Cylinder */
};

/* After tha xDisk structure the packed data follows. First the
   XPK-Crunched info-text (when available) and the each cylinder as a
   XPKF-block.
   NOTE: It seems that sometimes xDisk adds xd_InfoTextSize, also when no
   text was added!
*/

XADRECOGDATA(xDisk)
{
  if(data[0] == 'X' && data[1] == 'D' && data[2] == 'S' && data[3] == '0')
    return 1;
  else
    return 0;
}

XADGETINFO(xDisk)
{
  xadINT32 err;
  xadUINT8 dat[9*4];
  xadUINT32 num = 0, i;
  struct xDisk xd;
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;
  ai->xai_DiskInfo = xdi;

  if((err = xadHookAccess(XADM XADAC_READ, sizeof(struct xDisk), &xd, ai)))
    return err;
  xdi->xdi_EntryNumber = 1;
  xdi->xdi_Cylinders = EndGetM32(xd.xd_NumCylinders);
  xdi->xdi_LowCyl = EndGetM32(xd.xd_LowCyl);
  xdi->xdi_HighCyl = EndGetM32(xd.xd_HighCyl);
  xdi->xdi_SectorSize = 512; /* most devices should use 512 as blocksize */
  xdi->xdi_CylSectors = EndGetM32(xd.xd_CylinderSize)>>9;
  xdi->xdi_TotalSectors = xdi->xdi_Cylinders*xdi->xdi_CylSectors;
  xdi->xdi_Flags = XADDIF_GUESSHEADS|XADDIF_GUESSTRACKSECTORS
  |XADDIF_SEEKDATAPOS;
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

  while(ai->xai_InPos < ai->xai_InSize)
  {
    if((err = xadHookAccess(XADM XADAC_READ, 36, dat, ai)))
      return err;
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat+4)-28, 0, ai)))
      return err;
    ++num;
    /* check for password flag in every entry */
    if(EndGetM32(dat+8*4) & (1<<25))
    {
      ai->xai_Flags |= XADAIF_CRYPTED;
      xdi->xdi_Flags |= XADDIF_CRYPTED;
    }
  }
  xdi->xdi_DataPos = sizeof(struct xDisk);
  i = xdi->xdi_HighCyl+1-xdi->xdi_LowCyl;

  if(num == i+1) /* decrunch infotext and store pointer */
  {
    struct xadTextInfo *ti;

    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, sizeof(struct xDisk) -
    ai->xai_InPos, 0, ai)))
      return err;
    if((ti = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
    {
      xadINT32 err;

      if((err = xpkDecrunch(&ti->xti_Text, &ti->xti_Size, ai,
      xadMasterBase)))
        xadFreeObjectA(XADM ti, 0);
      else
        xdi->xdi_TextInfo = ti;
      return err;
    }
    else
      return XADERR_NOMEMORY;
    xdi->xdi_DataPos = ai->xai_InPos;
  }
  else if(num != i)
    return XADERR_ILLEGALDATA;

  return 0;
}

XADUNARCHIVE(xDisk)
{
  xadINT32 i, err = 0;
  struct xadInOut *io;
  xadUINT8 dat[8];

  /* skip entries */
  for(i = ai->xai_CurDisk->xdi_LowCyl; !err && i < ai->xai_LowCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 8, dat, ai)))
      err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(dat+4), 0, ai);
  }

  for(; !err && i <= ai->xai_HighCyl; ++i)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 8, &dat, ai)) &&
    !(err = xadHookAccess(XADM XADAC_INPUTSEEK, -8, 0, ai)))
    {
      if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
      |XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
      {
        io->xio_InSize = EndGetM32(dat+4)+8;
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

/**************************************************************************************************/

/* GDC format
  xadINT32 ID = "GDC@"
  xadINT8 Minor Version ?
  xadINT8 Major Version ?
  xadINT16 CylindersPerCylinder ?
  xadINT16 LowCylinder
  xadINT16 HighCylinder
  xadINT32 CylinderSize
  xadINT32 HeaderSize
  STR  ExecDeviceUsed - null terminated
  ...  (HighCylinder-LowCylinder)+1 XPK files
*/

XADRECOGDATA(GDC)
{
  if(EndGetM32(data) == 0x47444340 && EndGetM32(data+16) > 28)
    return 1;
  else
    return 0;
}

XADGETINFO(GDC)
{
  xadUINT8 head[36];
  xadINT32 err;
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;
  ai->xai_DiskInfo = xdi;

  if((err = xadHookAccess(XADM XADAC_READ, 28, head, ai)))
    return err;
  xdi->xdi_EntryNumber = 1;
  xdi->xdi_LowCyl = EndGetM16(head+8);
  xdi->xdi_HighCyl = EndGetM16(head+10);
  xdi->xdi_Cylinders = xdi->xdi_HighCyl+1;
  xdi->xdi_SectorSize = 512; /* most devices should use 512 as blocksize */
  xdi->xdi_CylSectors = EndGetM32(head+12)>>9;
  xdi->xdi_TotalSectors = xdi->xdi_Cylinders*xdi->xdi_CylSectors;
  xdi->xdi_Flags = XADDIF_GUESSHEADS|XADDIF_GUESSTRACKSECTORS|XADDIF_GUESSSECTORSIZE|
  XADDIF_GUESSTOTALSECTORS|XADDIF_GUESSCYLINDERS|XADDIF_GUESSCYLSECTORS|XADDIF_SEEKDATAPOS;
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
  xdi->xdi_DataPos = EndGetM32(head+16);

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, xdi->xdi_DataPos-ai->xai_InPos, 0, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_READ, 36, head, ai)))
    return err;
  if(EndGetM32(head+32) & (1<<25)) /* check for password flag in first entry */
  {
    ai->xai_Flags |= XADAIF_CRYPTED;
    xdi->xdi_Flags |= XADDIF_CRYPTED;
  }

  return 0;
}


/**************************************************************************************************/

XADCLIENT(GDC) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  GDC_VERSION,
  GDC_REVISION,
  28,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_GDC,
  "GDC",
  XADRECOGDATAP(GDC),
  XADGETINFOP(GDC),
  XADUNARCHIVEP(xDisk),
  NULL
};

XADFIRSTCLIENT(xDisk) {
  (struct xadClient *) &GDC_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  XDISK_VERSION,
  XDISK_REVISION,
  4,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_XDISK,
  "xDisk",
  XADRECOGDATAP(xDisk),
  XADGETINFOP(xDisk),
  XADUNARCHIVEP(xDisk),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(xDisk)

#endif /* XADMASTER_XDISK_C */
