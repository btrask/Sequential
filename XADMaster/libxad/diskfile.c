#ifndef XADMASTER_DISKFILE_C
#define XADMASTER_DISKFILE_C

/*  $Id: diskfile.c,v 1.7 2005/06/23 14:54:37 stoecker Exp $
    file extraction from disk images

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

#include "include/functions.h"

FUNCxadGetDiskInfo /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
  xadERROR err;
  xadINT32 noext = 0;
  struct xadImageInfo *ii;
  xadTAGPTR ti, ti2 = tags;
  xadUINT32 onlyflags = 0, ignoreflags = 0;

#ifdef DEBUG
  DebugTagList("xadGetDiskInfoA", tags);
#endif

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_STARTCLIENT: ai->xaip_ArchiveInfo.xai_Client
    = (struct xadClient *)(uintptr_t) ti->ti_Data; break;
    case XAD_NOEXTERN: noext = ti->ti_Data; break;
    case XAD_NOEMPTYERROR:
      if(ti->ti_Data)
        ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_NOEMPTYERROR;
      else
        ai->xaip_ArchiveInfo.xai_Flags &= ~XADAIF_NOEMPTYERROR;
      break;
    case XAD_IGNOREFLAGS: ignoreflags = ti->ti_Data; break;
    case XAD_ONLYFLAGS:   onlyflags = ti->ti_Data; break;
    }
  }

  if(noext)
    ignoreflags |= XADCF_EXTERN;

  ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_ONLYIN;
  err = xadGetHookAccessA(XADM_PRIV XADM_AI(ai), tags);
  ai->xaip_ArchiveInfo.xai_Flags &= ~XADAIF_ONLYIN;

  if(!err)
  {
    if((ii = (struct xadImageInfo *) xadAllocObjectA(XADM XADOBJ_IMAGEINFO,
    0)))
    {
      struct xadClient *xc;
      ai->xaip_InHookParam.xhp_Command = XADHC_IMAGEINFO;
      ai->xaip_InHookParam.xhp_CommandData = (xadSignSize)(uintptr_t)ii;
      if(CallHookPkt(ai->xaip_InHook, ai, &ai->xaip_InHookParam))
      {
#ifdef DEBUG
  DebugOther("xadGetDiskInfoA: got no image info, using defaults");
#endif
        ii->xii_SectorSize = 512;
//        ii->xii_FirstSector = 0;
        ii->xii_NumSectors = ii->xii_TotalSectors = ai->xaip_InSize/512;
      }
      ai->xaip_ArchiveInfo.xai_ImageInfo = ii;

      xc = xadMasterBase->xmb_FirstClient;
      err = XADERR_FILESYSTEM;
      if(ai->xaip_ArchiveInfo.xai_Client)
      { /* do not use it directly to disable wrong pointer errors */
        while(xc && xc != ai->xaip_ArchiveInfo.xai_Client)
          xc = xc->xc_Next;
#ifdef DEBUG
  if(xc)
    DebugRunTime("xadGetDiskInfoA: Starting with client %s",
    xc->xc_ArchiverName);
#endif
        if(!xc)
        {
#ifdef DEBUG
  DebugError("xadGetDiskInfoA: Wrong start client pointer");
#endif
          err = XADERR_BADPARAMS;
        }
        ai->xaip_ArchiveInfo.xai_Client = 0; /* reset that field */
      }
      while(xc && err == XADERR_FILESYSTEM)
      {
        if((xc->xc_Flags & XADCF_FILESYSTEM) &&
        !(xc->xc_Flags & ignoreflags) && ((xc->xc_Flags & onlyflags)
        == onlyflags))
        {
#ifdef DEBUG
  DebugOther("xadGetDiskInfoA: Testing client %s", xc->xc_ArchiverName);
#endif
          err = 0;
          if(ai->xaip_ArchiveInfo.xai_InPos)
            err = xadHookAccess(XADM XADAC_INPUTSEEK,
            -ai->xaip_ArchiveInfo.xai_InPos, 0, XADM_AI(ai));
          if(!err)
          {
            ai->xaip_ArchiveInfo.xai_Client = xc;
            err = Callback_GetInfo(xc, ai, xadMasterBase);
          }
#ifdef DEBUG
  if(err == XADERR_FILESYSTEM)
  {
    if(ai->xaip_ArchiveInfo.xai_PrivateClient)
      DebugError("%s set PrivateClient field", xc->xc_ArchiverName);
    if(ai->xaip_ArchiveInfo.xai_FileInfo)
      DebugError("%s set FileInfo field", xc->xc_ArchiverName);
    if(ai->xaip_ArchiveInfo.xai_DiskInfo)
      DebugError("%s set DiskInfo field", xc->xc_ArchiverName);
  }
#endif
        }
        xc = xc->xc_Next;
      }
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && !ai->xaip_ArchiveInfo.xai_FileInfo &&
  !(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_NOEMPTYERROR))
    err = XADERR_EMPTY;

  callprogress(ai, err, err ? XADPMODE_ERROR : XADPMODE_GETINFOEND,
  xadMasterBase);
  if(err)
    xadFreeInfo(XADM_PRIV XADM_AI(ai));

#ifdef DEBUG
  if(err)
  {
    DebugError("xadGetDiskInfo returns \"%s\" (%ld)",
    xadGetErrorText(XADM err), err);
  }
#endif

  return err;
}
ENDFUNC

#endif  /* XADMASTER_DISKFILE_C */
