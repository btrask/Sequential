#ifndef XADMASTER_HOOK_C
#define XADMASTER_HOOK_C

/*  $Id: hook.c,v 1.8 2005/06/23 14:54:37 stoecker Exp $
    allows hook access from programs

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

#define MakeXADFlag(fl) if(ti->ti_Data) flags |= fl; else flags &= ~fl

FUNCxadGetHookAccess /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
  xadINT32 in = 0, out = 0, outfl = 0;
  xadERROR ret = 0;
  xadUINT32 flags;
  xadTAGPTR ti, ti2 = tags;
  struct Hook *proghook = 0;

  xadSignSize insize = -1;
  xadFileHandle infh = 0;
  xadSTRPTR inname = 0;
  xadPTR inbuf = 0;
  struct xadSplitFile *insplitt = 0;
  struct Hook *inhook = 0;
  xadTAGPTR inda = 0, inai = 0;

  xadSignSize outsize = -1;
  xadFileHandle outfh = 0;
  xadSTRPTR outname = 0;
  xadPTR outbuf = 0;
  struct Hook *outhook = 0;
  xadTAGPTR outai = 0;
#ifdef AMIGA
  struct xadDeviceInfo *outdev = 0;
  struct xadDeviceInfo *indev = 0;
#endif

#ifdef DEBUG
  DebugTagList("xadGetHookAccess", tags);
#endif

  flags = ai->xaip_ArchiveInfo.xai_Flags;
  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_INSIZE: insize = (xadSignSize) ti->ti_Data; break;
    case XAD_INFILENAME: ++in; inname = (xadSTRPTR)(uintptr_t) ti->ti_Data; break;
    case XAD_INFILEHANDLE: ++in; infh = (xadFileHandle) ti->ti_Data; break;
    case XAD_INMEMORY: ++in; inbuf = (xadPTR)(uintptr_t) ti->ti_Data; break;
    case XAD_INHOOK: ++in; inhook = (struct Hook *)(uintptr_t) ti->ti_Data; break;
    case XAD_INSPLITTED: ++in; insplitt = (struct xadSplitFile *)(uintptr_t) ti->ti_Data;
      break;
    case XAD_INDISKARCHIVE: ++in; inda = (xadTAGPTR)(uintptr_t) ti->ti_Data;
      break;
    case XAD_INXADSTREAM: ++in; inai = (xadTAGPTR)(uintptr_t) ti->ti_Data; break;

#ifdef AMIGA
    case XAD_INDEVICE: ++in; indev = (struct xadDeviceInfo *) ti->ti_Data;
      break;
    case XAD_OUTDEVICE: ++out; outdev = (struct xadDeviceInfo *) ti->ti_Data;
      break;
    case XAD_VERIFY: ++outfl; MakeXADFlag(XADAIF_VERIFY); break;
    case XAD_FORMAT: ++outfl; MakeXADFlag(XADAIF_FORMAT); break;
    case XAD_IGNOREGEOMETRY: ++outfl; MakeXADFlag(XADAIF_IGNOREGEOMETRY);
      break;
    case XAD_USESECTORLABELS: ++outfl; MakeXADFlag(XADAIF_USESECTORLABELS);
      break;
#endif

    case XAD_OUTFILEHANDLE: ++out; outfh = (xadFileHandle) ti->ti_Data; break;
    case XAD_OUTFILENAME: ++out; outname = (xadSTRPTR)(uintptr_t) ti->ti_Data; break;
    case XAD_OUTHOOK: ++out; outhook = (struct Hook *)(uintptr_t) ti->ti_Data; break;
    case XAD_OUTMEMORY: ++out; outbuf = (xadPTR)(uintptr_t) ti->ti_Data; break;
    case XAD_OUTSIZE: outsize = ti->ti_Data; break;
    case XAD_OUTXADSTREAM: ++out; outai = (xadTAGPTR)(uintptr_t) ti->ti_Data;
      break;

    case XAD_PROGRESSHOOK: proghook = (struct Hook *)(uintptr_t) ti->ti_Data; break;
    case XAD_PASSWORD: ai->xaip_ArchiveInfo.xai_Password
    = (xadSTRPTR)(uintptr_t) ti->ti_Data; break;

    case XAD_OVERWRITE: ++outfl; MakeXADFlag(XADAIF_OVERWRITE); break;
    case XAD_MAKEDIRECTORY: ++outfl; MakeXADFlag(XADAIF_MAKEDIRECTORY); break;
    case XAD_NOKILLPARTIAL: ++outfl; MakeXADFlag(XADAIF_NOKILLPARTIAL); break;
    }
  }

  if(in > 1 || out > 1 || !(in+out) ||
  ((ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYOUT) && in) ||
  ((ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYIN) && (out+outfl)) ||
  (inbuf && insize == -1) || (in && !inbuf && !inhook && !infh
  && !inname && !insplitt && !inda
#ifdef AMIGA
  && !indev
#endif
  && !inai) || (outbuf && outsize == -1) || (out && !outbuf && !outhook
  && !outfh && !outname
#ifdef AMIGA
  && !outdev
#endif
  && !outai))
    ret = XADERR_BADPARAMS;

#ifdef DEBUG
  if(ret)
    DebugError("xadGetHookAccess error(%s,%s,%s,%s,%s,%s,%s,%s,%s)",
    in > 1 ? "T" : "F",
    out > 1 ? "T" : "F",
    !(in+out) ? "T" : "F",
    ((ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYOUT) && in) ? "T" : "F",
    ((ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYIN) && (out+outfl))
    ? "T" : "F", (inbuf && insize == -1) ? "T" : "F",
    (in && !inbuf && !inhook && !infh && !inname && !insplitt && !inda
#ifdef AMIGA
    && !indev
#endif
    && !inai) ? "T" : "F", (outbuf && outsize == -1) ? "T" : "F",
    (out && !outbuf && !outhook && !outfh && !outname
#ifdef AMIGA
    && !outdev
#endif
    && !outai) ? "T" : "F");
#endif

  ai->xaip_ProgressHook = proghook;

  if(!ret && in)
  {
    if(inbuf)
      inhook = &xadMasterBase->xmb_InHookMem;
    else if(infh || inname)
      inhook = &xadMasterBase->xmb_InHookFH;
    else if(insplitt)
      inhook = &xadMasterBase->xmb_InHookSplitted;
    else if(inda)
      inhook = &xadMasterBase->xmb_InHookDiskArc;
#ifdef AMIGA
    else if(indev)
      inhook = &xadMasterBase->xmb_InHookDisk;
#endif
    else if(inai)
      inhook = &xadMasterBase->xmb_InHookStream;

    ai->xaip_ArchiveInfo.xai_InSize =
    ai->xaip_InSize                     = insize;
    ai->xaip_InSplitted                 = insplitt;
    ai->xaip_InMemory                   = inbuf;
    ai->xaip_InFileHandle               = infh;
    ai->xaip_InFileName                 = inname;
    ai->xaip_InHook                     = inhook;
    ai->xaip_InDiskArc                  = inda;
#ifdef AMIGA
    ai->xaip_InDevice                   = indev;
#endif
    ai->xaip_InArcInfo                  = inai;
    ai->xaip_MasterBase                 = xadMasterBase;

    ai->xaip_InHookParam.xhp_Command    = XADHC_INIT;
    if(!(ret = CallHookPkt(ai->xaip_InHook, ai, &ai->xaip_InHookParam))
    && insize == -1)
    {
      ai->xaip_InHookParam.xhp_Command = XADHC_FULLSIZE;
      if(!(ret = CallHookPkt(ai->xaip_InHook, ai, &ai->xaip_InHookParam)))
      {
        ai->xaip_ArchiveInfo.xai_InSize = ai->xaip_InSize =
        ai->xaip_InHookParam.xhp_CommandData;
      }
    }
  }

  if(!ret && out)
  {
    if(outbuf)
      outhook = &xadMasterBase->xmb_OutHookMem;
    else if(outfh || outname)
      outhook = &xadMasterBase->xmb_OutHookFH;
#ifdef AMIGA
    else if(outdev)
      outhook = &xadMasterBase->xmb_OutHookDisk;
#endif
    else if(outai)
      outhook = &xadMasterBase->xmb_OutHookStream;

    ai->xaip_ArchiveInfo.xai_Flags      = flags;
    ai->xaip_OutSize                    = outsize;
    ai->xaip_OutMemory                  = outbuf;
    ai->xaip_OutFileHandle              = outfh;
    ai->xaip_OutFileName                = outname;
    ai->xaip_OutHook                    = outhook;
#ifdef AMIGA
    ai->xaip_OutDevice                  = outdev;
#endif
    ai->xaip_OutArcInfo                 = outai;
    ai->xaip_MasterBase                 = xadMasterBase;

    ai->xaip_OutHookParam.xhp_Command   = XADHC_INIT;
    ret = CallHookPkt(ai->xaip_OutHook, ai, &ai->xaip_OutHookParam);
  }

  if(ret)
  {
    xadFreeHookAccess(XADM_PRIV XADM_AI(ai), XAD_WASERROR, ret, TAG_DONE);
#ifdef DEBUG
    DebugError("xadGetHookAccess returns \"%s\" (%ld)",
    xadGetErrorText(XADM ret), ret);
#endif
  }

  return ret;
}
ENDFUNC

FUNCxadFreeHookAccess /* struct xadArchiveInfoP *ai, xadTAGPTR tags */
{
#ifdef DEBUG
  DebugTagList("xadFreeHookAccess", tags);
#endif

  if(!(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYOUT))
  {
    if(ai->xaip_InHook)
    {
      ai->xaip_InHookParam.xhp_Command = XADHC_FREE;
      CallHookPkt(ai->xaip_InHook, ai, &ai->xaip_InHookParam);
      memset(&ai->xaip_InHookParam, 0, sizeof(struct xadHookParam));
    }
  }

  if(!(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_ONLYIN))
  {
    xadERROR err;
    err = GetTagData(XAD_WASERROR, 0, tags);

    if(ai->xaip_OutHook)
    {
      if(err)
      {
        ai->xaip_OutHookParam.xhp_Command = XADHC_ABORT;
        CallHookPkt(ai->xaip_OutHook, ai, &ai->xaip_OutHookParam);
      }
      ai->xaip_OutHookParam.xhp_Command = XADHC_FREE;
      CallHookPkt(ai->xaip_OutHook, ai, &ai->xaip_OutHookParam);
      memset(&ai->xaip_OutHookParam, 0, sizeof(struct xadHookParam));

      callprogress(ai, err, err ? XADPMODE_ERROR : XADPMODE_END,
      xadMasterBase);
    }
  }

  /* clear the structure to allow reuse */
  if(!(ai->xaip_ArchiveInfo.xai_Flags & (XADAIF_ONLYOUT|XADAIF_ONLYOUT)))
    memset(ai, 0, sizeof(struct xadArchiveInfoP));
}
ENDFUNC

#endif /* XADMASTER_HOOK_C */

