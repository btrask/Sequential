#ifndef XADMASTER_DISKUNARC_C
#define XADMASTER_DISKUNARC_C

/*  $Id: diskunarc.c,v 1.7 2005/06/23 14:54:37 stoecker Exp $
    disk unarchiving stuff

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

#include "include/functions.h"

FUNCxadDiskUnArc /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
  xadSTRPTR password;
  xadERROR err;
  xadUINT32 flags;
  struct Hook *ph;

#ifdef DEBUG
  DebugTagList("xadDiskUnArcA", tags);
#endif

  if(!ai->xaip_ArchiveInfo.xai_Client ||
  !(ai->xaip_ArchiveInfo.xai_Client->xc_Flags & XADCF_DISKARCHIVER))
    return XADERR_BADPARAMS;

  password = ai->xaip_ArchiveInfo.xai_Password; /* store global settings */
  flags = ai->xaip_ArchiveInfo.xai_Flags;
  ph = ai->xaip_ProgressHook;

  ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_DISKARCHIVE|XADAIF_ONLYOUT;
  if(!(err = xadGetHookAccessA(XADM_PRIV XADM_AI(ai), tags)))
  {
    xadTAGPTR ti, ti2 = tags;
    xadUINT32 lowcyl = 0, highcyl = 0, entry = 0, numlow = 0, numhigh = 0,
    numentry = 0;

    while((ti = NextTagItem(&ti2)))
    {
      switch(ti->ti_Tag)
      {
      case XAD_ENTRYNUMBER: entry = ti->ti_Data; ++numentry; break;
      case XAD_HIGHCYLINDER: highcyl = ti->ti_Data; ++numhigh; break;
      case XAD_LOWCYLINDER: lowcyl = ti->ti_Data; ++numlow; break;
      }
    }

    if(numentry != 1 || numlow > 1 || numhigh > 1)
      err = XADERR_BADPARAMS;
    else
    {
      struct xadDiskInfo *di;

      di = ai->xaip_ArchiveInfo.xai_DiskInfo;
      while(di && di->xdi_EntryNumber != entry)
        di = di->xdi_Next;

      if(!di || di->xdi_EntryNumber != entry)
        err = XADERR_BADPARAMS;
      else
      {
        if(!numlow)
          lowcyl = di->xdi_LowCyl;
        if(!numhigh)
          highcyl = di->xdi_HighCyl;
        if(lowcyl < di->xdi_LowCyl || highcyl > di->xdi_HighCyl)
          err = XADERR_BADPARAMS;
        else if((di->xdi_Flags & XADDIF_NOCYLINDERS) && (numlow || numhigh))
          err = XADERR_BADPARAMS;
        else
        {
          xadSize i;

          ai->xaip_ArchiveInfo.xai_CurFile = 0;
          ai->xaip_ArchiveInfo.xai_CurDisk = di;
          ai->xaip_ArchiveInfo.xai_LowCyl  = lowcyl;
          ai->xaip_ArchiveInfo.xai_HighCyl = highcyl;
          ai->xaip_ArchiveInfo.xai_OutPos = 0;
          ai->xaip_ArchiveInfo.xai_OutSize = 0;

          if(ai->xaip_ArchiveInfo.xai_CurDisk->xdi_Flags & XADDIF_SEEKDATAPOS)
          {
            if((i = (ai->xaip_ArchiveInfo.xai_CurDisk->xdi_DataPos
            - ai->xaip_ArchiveInfo.xai_InPos)))
            {
              err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0,
              XADM_AI(ai));
            }
          }
          if(!err)
          {
            err = Callback_UnArchive(ai->xaip_ArchiveInfo.xai_Client, ai,
            xadMasterBase);
#ifdef DEBUG
            if(err)
              DebugError("xc_UnArchive of %s returns \"%s\" (%ld)",
              ai->xaip_ArchiveInfo.xai_Client->
              xc_ArchiverName, xadGetErrorText(XADM err), err);
#endif
          }
        }
      }
    }

    xadFreeHookAccess(XADM_PRIV XADM_AI(ai), err ? XAD_WASERROR : TAG_DONE, err, TAG_DONE);
  }

  ai->xaip_ArchiveInfo.xai_Password = password; /* restore global settings */
  ai->xaip_ArchiveInfo.xai_Flags = flags;
  ai->xaip_ProgressHook = ph;

#ifdef DEBUG
  if(err)
  {
    DebugError("xadDiskUnArc returns \"%s\" (%ld)",
    xadGetErrorText(XADM err), err);
  }
#endif

  return err;
}
ENDFUNC

#endif  /* XADMASTER_DISKUNARC_C */
