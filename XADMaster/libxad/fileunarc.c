#ifndef XADMASTER_FILEUNARC_C
#define XADMASTER_FILEUNARC_C

/*  $Id: fileunarc.c,v 1.7 2005/06/23 14:54:37 stoecker Exp $
    unarchiving of file archives

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

FUNCxadFileUnArc /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
  xadSTRPTR password;
  xadERROR err;
  xadUINT32 flags;
  struct Hook *ph;

#ifdef DEBUG
  DebugTagList("xadFileUnArcA", tags);
#endif

  if(!ai->xaip_ArchiveInfo.xai_Client ||
  !(ai->xaip_ArchiveInfo.xai_Client->xc_Flags
  & (XADCF_FILEARCHIVER|XADCF_FILESYSTEM)))
    return XADERR_BADPARAMS;

  password = ai->xaip_ArchiveInfo.xai_Password; /* store global settings */
  flags = ai->xaip_ArchiveInfo.xai_Flags;
  ph = ai->xaip_ProgressHook;

  ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_ONLYOUT;
  if(ai->xaip_ArchiveInfo.xai_Client->xc_Flags & XADCF_FILEARCHIVER)
    ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_FILEARCHIVE;
  else if(ai->xaip_ArchiveInfo.xai_Client->xc_Flags & XADCF_FILESYSTEM)
    ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_DISKIMAGE;
  if(!(err = xadGetHookAccessA(XADM_PRIV XADM_AI(ai), tags)))
  {
    xadTAGPTR ti, ti2 = tags;
    xadUINT32 entry = 0, numentry = 0;

    while((ti = NextTagItem(&ti2)))
    {
      switch(ti->ti_Tag)
      {
      case XAD_ENTRYNUMBER: entry = ti->ti_Data; ++numentry; break;
      }
    }

    if(numentry != 1)
      err = XADERR_BADPARAMS;
    else
    {
      struct xadFileInfo *fi;

      fi = ai->xaip_ArchiveInfo.xai_FileInfo;
      while(fi && fi->xfi_EntryNumber != entry)
        fi = fi->xfi_Next;

      if(!fi || fi->xfi_EntryNumber != entry || (fi->xfi_Flags
      & (XADFIF_DIRECTORY|XADFIF_LINK)))
        err = XADERR_BADPARAMS;
      else
      {
        ai->xaip_ArchiveInfo.xai_CurFile = fi;
        ai->xaip_ArchiveInfo.xai_CurDisk = 0;
        ai->xaip_ArchiveInfo.xai_OutPos  = 0;
        ai->xaip_ArchiveInfo.xai_OutSize = 0;

        if(ai->xaip_ArchiveInfo.xai_CurFile->xfi_Size ||
        (ai->xaip_ArchiveInfo.xai_CurFile->xfi_Flags
        & XADFIF_NOUNCRUNCHSIZE)) /* skip empty files */
        {
          xadSize i;

          if(ai->xaip_ArchiveInfo.xai_CurFile->xfi_Flags & XADFIF_SEEKDATAPOS)
          {
            if((i = (ai->xaip_ArchiveInfo.xai_CurFile->xfi_DataPos
            - ai->xaip_ArchiveInfo.xai_InPos)))
            {
              err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0,
              XADM_AI(ai));
            }
          }

          if(!err)
          {
            err = Callback_UnArchive(ai->xaip_ArchiveInfo.xai_Client,
            ai, xadMasterBase);
#ifdef DEBUG
            if(err)
            {
              DebugError("xc_UnArchive of %s returns \"%s\" (%ld) for %s",
              ai->xaip_ArchiveInfo.xai_Client->xc_ArchiverName,
              xadGetErrorText(XADM err), err,
              ai->xaip_ArchiveInfo.xai_CurFile->xfi_FileName);
            }
#endif
          }
        }
      }
    }

    xadFreeHookAccess(XADM_PRIV XADM_AI(ai), err ? XAD_WASERROR : TAG_DONE,
    err, TAG_DONE);
  }

  ai->xaip_ArchiveInfo.xai_Password = password; /* restore global settings */
  ai->xaip_ArchiveInfo.xai_Flags = flags;
  ai->xaip_ProgressHook = ph;

#ifdef DEBUG
  if(err)
  {
    DebugError("xadFileUnArc returns \"%s\" (%ld)", xadGetErrorText(XADM err),
    err);
  }
#endif

  return err;
}
ENDFUNC

#endif  /* XADMASTER_FILEUNARC_C */
