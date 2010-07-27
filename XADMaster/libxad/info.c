#ifndef XADMASTER_INFO_C
#define XADMASTER_INFO_C

/*  $Id: info.c,v 1.13 2005/06/23 14:54:37 stoecker Exp $
    information handling functions

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

#include "include/functions.h"

FUNCxadGetSystemInfo /* no args */
{
  return &xadMasterBase->xmb_System;
}
ENDFUNC

FUNCxadRecogFile /* xadSize size, const void *mem, xadTAGPTR tags */
{
#ifdef AMIGA
  struct xadClient *xc = xadGetClientInfo();
#else
  struct xadClient *xc = xadGetClientInfo(xadMasterBase);
#endif

  xadINT32 noext = 0;
  xadUINT32 onlyflags = 0, ignoreflags = 0;
  xadTAGPTR ti, ti2 = tags;

#ifdef DEBUG
  xadUINT32 crc, crc2;

  crc = xadCalcCRC32(XADM_PRIV XADCRC32_ID1, ~0, size, mem);
#endif

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_NOEXTERN:    noext = ti->ti_Data; break;
    case XAD_IGNOREFLAGS: ignoreflags = ti->ti_Data; break;
    case XAD_ONLYFLAGS:   onlyflags = ti->ti_Data; break;
    }
  }

  if(noext)
    ignoreflags |= XADCF_EXTERN;

#ifdef DEBUG
  DebugRunTime("xadRecogFileA: %s (%08lx, %ld)", noext ? "NOEXTERN" : "EXTERN", mem, size);
#endif

  while(xc)
  {
    if((xc->xc_Flags & (XADCF_FILEARCHIVER|XADCF_DISKARCHIVER)) && xc->xc_RecogData &&
    !(xc->xc_Flags & ignoreflags) && ((xc->xc_Flags & onlyflags) == onlyflags))
    {
      if((size >= xc->xc_RecogSize) || (xc->xc_Flags & XADCF_NOCHECKSIZE))
      {
#ifdef DEBUG
  crc2 = xadCalcCRC32(XADM XADCRC32_ID1, ~0, size, mem);
#endif
        if(Callback_RecogData(xc, MinVal(size, xc->xc_RecogSize), mem,
        xadMasterBase))
        {
#ifdef DEBUG
  DebugRunTime("xadRecogFileA: found %s", xc->xc_ArchiverName);
  if(crc2 != xadCalcCRC32(XADM XADCRC32_ID1, ~0, size, mem))
    DebugError("xadRecogFileA: The input buffer was modified by this client.");
#endif
          return xc;
        }
#ifdef DEBUG
  if(crc2 != xadCalcCRC32(XADM XADCRC32_ID1, ~0, size, mem))
    DebugError("xadRecogFileA: The input buffer was modified by %s.",
    xc->xc_ArchiverName);
#endif
      }
    }
    xc = xc->xc_Next;
  }
#ifdef DEBUG
  if(crc != xadCalcCRC32(XADM XADCRC32_ID1, ~0, size, mem))
    DebugError("xadRecogFileA: The input buffer was modified.");
#endif

  return 0;
}
ENDFUNC

FUNCxadGetInfo /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
  xadERROR err;

#ifdef DEBUG
  DebugTagList("xadGetInfoA", tags);
#endif

  /* Validate tag arguments, fill out some ArchiveInfo fields from tags,
   * and initialise hook if required. Only "input" tags are allowed, tags
   * that would generate output are not allowed. */
  ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_ONLYIN;
  err = xadGetHookAccessA(XADM_PRIV XADM_AI(ai), tags);
  ai->xaip_ArchiveInfo.xai_Flags &= ~XADAIF_ONLYIN;

  /* if a full file path has been provided, extract the filename part */
  if(ai->xaip_InFileName)
  {
    /* FIXME: use an appropriate ConvertName function, as this code is
     * hacky, only working for Amiga and UNIX */
    xadSTRPTR pos, f;

    for(f = pos = ai->xaip_InFileName; *pos; ++pos)
    {
#ifdef AMIGA
      if(*pos == ':' || *pos == '/')
#else
      if(*pos == '/')
#endif
        f = pos+1;
    }
    if(*f)
      ai->xaip_ArchiveInfo.xai_InName = f;
  }
  if(!err)
  {
// GOA -->
    struct xadClient *xc = 0;
    xadUINT32 client_id = GetTagData(XAD_CLIENT, 0, tags);

    if(!client_id)
    {
      xadPTR buf;
      xadSignSize size;

      size = MinVal(xadMasterBase->xmb_RecogSize,
      ai->xaip_ArchiveInfo.xai_InSize);

      if((buf = xadAllocVec(XADM size, XADMEMF_ANY|XADMEMF_PUBLIC)))
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, size, buf, XADM_AI(ai))))
        {
          if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, -size, 0,
          XADM_AI(ai))))
          {
            if(!(xc = xadRecogFileA(XADM size, buf, tags)))
              err = XADERR_FILETYPE;
          }
        }
        xadFreeObjectA(XADM buf, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
    else
    {
#ifdef AMIGA
      xc = xadGetClientInfo();
#else
      xc = xadGetClientInfo(xadMasterBase);
#endif
      while(xc)
      {
        if(xc->xc_Identifier == client_id) break;
        xc = xc->xc_Next;
      }
    }
// <-- GOA

    if(xc)
    {
      ai->xaip_ArchiveInfo.xai_Client = xc;
      err = Callback_GetInfo(xc, ai, xadMasterBase);
    }
  }

  callprogress(ai, err, err ? XADPMODE_ERROR : XADPMODE_GETINFOEND,
  xadMasterBase);
  ai->xaip_ArchiveInfo.xai_InName = 0;
  /* it is no longer valid after leaving that function */

  if(err)
  {
    xadFreeInfo(XADM XADM_AI(ai));
#ifdef DEBUG
    DebugError("xadGetInfo returns \"%s\" (%ld)", xadGetErrorText(XADM err),
    err);
#endif
  }

  return err;
}
ENDFUNC

FUNCxadFreeInfo /* struct xadArchiveInfoP *ai */
{
  const struct xadClient *xc;

#ifdef DEBUG
  DebugRunTime("xadFreeInfo");
#endif

  if((xc = ai->xaip_ArchiveInfo.xai_Client))
  {
    if(xc->xc_Free)
      Callback_Free(xc, ai, xadMasterBase);

    if(ai->xaip_ArchiveInfo.xai_SkipInfo
    && (xc->xc_Flags & XADCF_FREESKIPINFO))
    {
      struct xadSkipInfo *si, *si2;

      for(si = ai->xaip_ArchiveInfo.xai_SkipInfo; si; si = si2)
      {
        si2 = si->xsi_Next;
        xadFreeObjectA(XADM si, 0);
      }
#ifdef DEBUG
      /* not needed in non DEBUG state, because of memset */
      ai->xaip_ArchiveInfo.xai_SkipInfo = 0;
#endif
    }

    if(ai->xaip_ArchiveInfo.xai_FileInfo && (xc->xc_Flags &
    (XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO|XADCF_FREEXADSTRINGS)))
    {
      struct xadFileInfo *fi, *fi2;
      struct xadSpecial *s, *s2;

      for(fi = ai->xaip_ArchiveInfo.xai_FileInfo; fi; fi = fi2)
      {
        if(xc->xc_Flags & XADCF_FREESPECIALINFO)
        {
          for(s = fi->xfi_Special; s; s = s2)
          {
            s2 = s->xfis_Next;
              xadFreeObjectA(XADM s, 0);
          }
#ifdef DEBUG
          /* not needed in non DEBUG state, because of memset */
          fi->xfi_Special = 0;
#endif
        }
        if(xc->xc_Flags & XADCF_FREEXADSTRINGS)
        {
          if(fi->xfi_Flags & XADFIF_XADSTRFILENAME)
          {
            xadFreeObjectA(XADM fi->xfi_FileName, 0);
#ifdef DEBUG
            fi->xfi_FileName = 0;
#endif
          }
          if(fi->xfi_Flags & XADFIF_XADSTRLINKNAME)
          {
            xadFreeObjectA(XADM fi->xfi_LinkName, 0);
#ifdef DEBUG
            fi->xfi_FileName = 0;
#endif
          }
          if(fi->xfi_Flags & XADFIF_XADSTRCOMMENT)
          {
            xadFreeObjectA(XADM fi->xfi_Comment, 0);
#ifdef DEBUG
            fi->xfi_FileName = 0;
#endif
          }
        }

#ifdef DEBUG
  if(fi->xfi_Special)
    DebugMemError("xadFreeInfo: still some Special entries in list for "
    "entry %ld", fi->xfi_EntryNumber);
  if(fi->xfi_FileName && (fi->xfi_Flags & XADFIF_XADSTRFILENAME))
    DebugMemError("xadFreeInfo: FileName string not released for "
    "entry %ld", fi->xfi_EntryNumber);
  if(fi->xfi_LinkName && (fi->xfi_Flags & XADFIF_XADSTRLINKNAME))
    DebugMemError("xadFreeInfo: LinkName string not released for "
    "entry %ld", fi->xfi_EntryNumber);
  if(fi->xfi_Comment && (fi->xfi_Flags & XADFIF_XADSTRCOMMENT))
    DebugMemError("xadFreeInfo: Comment string not released for "
    "entry %ld", fi->xfi_EntryNumber);
#endif
        fi2 = fi->xfi_Next;
        if(xc->xc_Flags & XADCF_FREEFILEINFO)
          xadFreeObjectA(XADM fi, 0);
      }
#ifdef DEBUG
      /* not needed in non DEBUG state, because of memset */
      if(xc->xc_Flags & XADCF_FREEFILEINFO)
        ai->xaip_ArchiveInfo.xai_FileInfo = 0;
#endif
    }

    if(ai->xaip_ArchiveInfo.xai_DiskInfo && (xc->xc_Flags
    & (XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT)))
    {
      struct xadDiskInfo *di, *di2;
      struct xadTextInfo *ti, *ti2;

      for(di = ai->xaip_ArchiveInfo.xai_DiskInfo; di; di = di2)
      {
        di2 = di->xdi_Next;

        for(ti = di->xdi_TextInfo; ti; ti = ti2)
        {
          ti2 = ti->xti_Next;
          if(ti->xti_Text && (xc->xc_Flags & XADCF_FREETEXTINFOTEXT))
          {
            xadFreeObjectA(XADM ti->xti_Text, 0);
            ti->xti_Text = 0;
          }
#ifdef DEBUG
  if(ti->xti_Text)
    DebugMemError("xadFreeInfo: still some Texts for entry %ld", di->xdi_EntryNumber);
#endif
          if(xc->xc_Flags & XADCF_FREETEXTINFO)
            xadFreeObjectA(XADM ti, 0);
        }
        if(xc->xc_Flags & XADCF_FREETEXTINFO)
          di->xdi_TextInfo = 0;

#ifdef DEBUG
  if(di->xdi_TextInfo)
    DebugMemError("xadFreeInfo: still some xadTextInfo for entry %ld", di->xdi_EntryNumber);
#endif
        if(xc->xc_Flags & XADCF_FREEDISKINFO)
          xadFreeObjectA(XADM di, 0);
      }
#ifdef DEBUG
      /* not needed in non DEBUG state, because of memset */
      if(xc->xc_Flags & XADCF_FREEDISKINFO)
        ai->xaip_ArchiveInfo.xai_DiskInfo = 0;
#endif
    }
  }

  if(ai->xaip_ArchiveInfo.xai_ImageInfo)
    xadFreeObjectA(XADM ai->xaip_ArchiveInfo.xai_ImageInfo, 0);

#ifdef DEBUG
  if(ai->xaip_ArchiveInfo.xai_DiskInfo)
    DebugMemError("xadFreeInfo: xai_DiskInfo entry not cleared");
  if(ai->xaip_ArchiveInfo.xai_FileInfo)
    DebugMemError("xadFreeInfo: xai_FileInfo entry not cleared");
  if(ai->xaip_ArchiveInfo.xai_SkipInfo)
    DebugMemError("xadFreeInfo: xai_SkipInfo entry not cleared");
  if(ai->xaip_ArchiveInfo.xai_PrivateClient)
    DebugMemError("xadFreeInfo: xai_PrivateClient entry not cleared");
#endif

  ai->xaip_ArchiveInfo.xai_Flags |= XADAIF_ONLYIN; /* cleared afterwards by memset */
  xadFreeHookAccessA(XADM_PRIV XADM_AI(ai), 0);

  /* clear the structure to allow reuse */
  memset(ai, 0, sizeof(struct xadArchiveInfoP));
}
ENDFUNC

#endif  /* XADMASTER_INFO_C */
