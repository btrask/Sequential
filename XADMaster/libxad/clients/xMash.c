#ifndef XADMASTER_XMASH_C
#define XADMASTER_XMASH_C

/*  $Id: xMash.c,v 1.5 2005/06/23 14:54:41 stoecker Exp $
    xMash disk archiver client

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
#include "xadXPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("xMash 1.5 (23.2.2004)")

#define XMASH_VERSION           1
#define XMASH_REVISION          5

/*
  structure of one xMash chunk:
    xadUINT8            xmc_Type;
    xadUINT8            xmc_Start
    xadUINT8            xmc_Num;
    xadUINT32           xmc_Size;
*/

#define XMASH_INFOTEXT  0x46
#define XMASH_BANNER    0x42
#define XMASH_ARCHIVE   0x44

struct xMashHead {
  xadUINT8 type;
  xadUINT8 start;
  xadUINT8 num;
};

XADRECOGDATA(xMash)
{
  if(data[0] == 'M' && data[1] == 'S' && data[2] == 'H' &&
  (data[3] == XMASH_BANNER || data[3] == XMASH_ARCHIVE || data[3] ==
  XMASH_INFOTEXT))
    return 1;
  else
    return 0;
}

XADGETINFO(xMash)
{
  xadINT32 err, lowcyl = 80, highcyl = -1;
  xadUINT32 dat[9], start = 3;
  struct xadDiskInfo *xdi;
  struct xadTextInfo *ti = 0;
  struct xMashHead h;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;
  ai->xai_DiskInfo = xdi;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_Cylinders = 80;
  xdi->xdi_Heads = 2;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_CylSectors = 22;
  xdi->xdi_TotalSectors = 80 * 22;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 3, 0, ai))) /* skip MSH */
    return err;

  while(ai->xai_InPos < ai->xai_InSize && !err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 3, &h, ai)) &&
    !(err = xadHookAccess(XADM XADAC_READ, 4, dat, ai)))
    {
      switch(h.type)
      {
      case XMASH_INFOTEXT: case XMASH_BANNER:
        {
          struct xadTextInfo *ti2;
          if((ti2 = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
          {
            if(h.type == XMASH_BANNER)
              ti2->xti_Flags |= XADTIF_BANNER;

            err = xpkDecrunch(&ti2->xti_Text, &ti2->xti_Size, ai, xadMasterBase);

            start = ai->xai_InPos;

            if(!ti)
              xdi->xdi_TextInfo = ti2;
            else
              ti->xti_Next = ti2;
            ti = ti2;
          }
          else
            err = XADERR_NOMEMORY;
        break;
        }
      case XMASH_ARCHIVE:
        if(!(err = xadHookAccess(XADM XADAC_READ, 36, dat, ai)) &&
        !(err = xadHookAccess(XADM XADAC_INPUTSEEK, dat[1]-28, 0, ai)))
        {
          if(dat[8] & (1<<25))
          { /* check for password flag in every entry */
            ai->xai_Flags |= XADAIF_CRYPTED;
            xdi->xdi_Flags |= XADDIF_CRYPTED;
          }
          h.num = ((h.num+h.start) >> 1)-1;
          h.start >>= 1;
          if(h.start < lowcyl)
            lowcyl = h.start;
          if(h.num > highcyl)
            highcyl = h.num;
        }
        break;
      }
    }
  }

  if(lowcyl <= highcyl)
  {
    xdi->xdi_LowCyl  = lowcyl;
    xdi->xdi_HighCyl = highcyl;
  }
  else
    err = XADERR_INPUT;

  xdi->xdi_DataPos = start;
  xdi->xdi_Flags |= XADDIF_SEEKDATAPOS;

  return err;
}

XADUNARCHIVE(xMash)
{
  struct xMashHead h;
  xadINT32 err = 0;
  xadUINT32 size, lowcyl;
  xadSTRPTR a;

  lowcyl = ai->xai_LowCyl;

  while(!err && lowcyl <= ai->xai_HighCyl)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 3, &h, ai)) &&
    !(err = xadHookAccess(XADM XADAC_READ, 4, &size, ai)))
    {
      xadINT32 endcyl, startcyl, skipbyte;

      startcyl = h.start>>1;
      endcyl = ((h.start+h.num)>>1)-1;

      if(endcyl < lowcyl)
        err = xadHookAccess(XADM XADAC_INPUTSEEK, size, 0, ai);
      else
      {
        xadUINT32 size;
        if(!(err = xpkDecrunch(&a, &size, ai, xadMasterBase)))
        {
          skipbyte = 0;

          if(startcyl < lowcyl)
            skipbyte = (lowcyl-startcyl)*22*512;
          if(endcyl > ai->xai_HighCyl)
            endcyl = ai->xai_HighCyl;
          size = (endcyl+1-lowcyl)*22*512;

          err = xadHookAccess(XADM XADAC_WRITE, size, a+skipbyte, ai);
          xadFreeObjectA(XADM a, 0);
          lowcyl = endcyl+1;
        }
      }
    }
  }

  return err;
}

XADFIRSTCLIENT(xMash) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  XMASH_VERSION,
  XMASH_REVISION,
  3,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_XMASH,
  "xMash",
  XADRECOGDATAP(xMash),
  XADGETINFOP(xMash),
  XADUNARCHIVEP(xMash),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(xMash)

#endif /* XADMASTER_XMASH_C */
