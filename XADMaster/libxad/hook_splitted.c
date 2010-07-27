#ifndef XADMASTER_HOOK_SPLITTED_C
#define XADMASTER_HOOK_SPLITTED_C

/*  $Id: hook_splitted.c,v 1.8 2005/06/23 14:54:37 stoecker Exp $
    splitted input file IO hook

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
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifdef AMIGA
#include <proto/utility.h>
#include <proto/xadmaster.h>
#endif
#include "include/functions.h"
#include "include/SDI_compiler.h"

static xadERROR callsplitthook(struct xadSplitData *sd, struct xadArchiveInfoP *ai,
xadUINT32 command, xadSignSize data, xadPTR bufptr, xadUINT32 bufsize)
{
  xadERROR res;
  xadSize insize;
  xadSize *multivol;
#ifdef AMIGA
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) ai->xaip_MasterBase;
  struct UtilityBase *UtilityBase;
  UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif

  sd->xsd_HookParam.xhp_Command = command;
  sd->xsd_HookParam.xhp_CommandData = data;
  sd->xsd_HookParam.xhp_BufferPtr = bufptr;
  sd->xsd_HookParam.xhp_BufferSize = bufsize;

  insize = ai->xaip_InSize;
  multivol = ai->xaip_ArchiveInfo.xai_MultiVolume;
#ifdef AMIGA
  ai->xaip_InDevice = sd->xsd_InDevice;
#endif
  ai->xaip_InFileHandle = sd->xsd_InFileHandle;
  ai->xaip_InFileName = sd->xsd_InFileName;
  ai->xaip_InMemory = sd->xsd_InMemory;
  ai->xaip_InSize = sd->xsd_InSize;
  ai->xaip_InSplitted = sd->xsd_InSplitted;
  ai->xaip_InDiskArc = sd->xsd_InDiskArc;
  ai->xaip_InArcInfo = sd->xsd_InArcInfo;
  ai->xaip_ArchiveInfo.xai_MultiVolume = sd->xsd_MultiVolume;

#ifdef DEBUG
  {
    static const xadSTRPTR commands[] = {"XADHC_READ", "XADHC_WRITE",
    "XADHC_SEEK", "XADHC_INIT", "XADHC_FREE", "XADHC_ABORT", "XADHC_FULLSIZE"};
    DebugOther("callsplitthook(..., %s, %ld, $%08lx, %ld)", commands[command-XADHC_READ], data, bufptr, bufsize);
  }
#endif

  res = CallHookPkt(sd->xsd_Hook, ai, &sd->xsd_HookParam);

#ifdef AMIGA
  sd->xsd_InDevice = ai->xaip_InDevice;
#endif
  sd->xsd_InFileHandle = ai->xaip_InFileHandle;
  sd->xsd_InFileName = ai->xaip_InFileName;
  sd->xsd_InMemory = ai->xaip_InMemory;
  sd->xsd_InSize = ai->xaip_InSize;
  sd->xsd_InSplitted = ai->xaip_InSplitted;
  sd->xsd_InDiskArc = ai->xaip_InDiskArc;
  sd->xsd_InArcInfo = ai->xaip_InArcInfo;
  sd->xsd_MultiVolume = ai->xaip_ArchiveInfo.xai_MultiVolume;
  ai->xaip_InSize = insize;
  ai->xaip_ArchiveInfo.xai_MultiVolume = multivol;

  return res;
}

/******************** join-multiple-types hook **************************/

FUNCHOOK(InHookSplitted)
{
  struct xadSplitData *sd;
  struct xadMasterBaseP * xadMasterBase;
  xadSignSize i;

  xadMasterBase = ai->xaip_MasterBase;
  sd = (struct xadSplitData *) param->xhp_PrivatePtr;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_InSize)
      return XADERR_INPUT;
    else
    {
      xadSignSize j;
      xadERROR err;
      xadUINT8 *buf;

      i = param->xhp_BufferSize;
      buf = (xadUINT8 *) param->xhp_BufferPtr;
      while(sd->xsd_Offset+sd->xsd_InSize <= param->xhp_DataPos)
        ++sd;
      while(i) /* do as long as we need to read */
      {
        /* correct part position */
        if((j = param->xhp_DataPos-sd->xsd_Offset) != sd->xsd_HookParam.xhp_DataPos)
          if((err = callsplitthook(sd, ai, XADHC_SEEK, j-sd->xsd_HookParam.xhp_DataPos, 0, 0)))
            return err;
        /* get read size of that part */
        if((j = sd->xsd_Offset+sd->xsd_InSize-param->xhp_DataPos) > i)
          j = i;
        /* read that size */
        if((err = callsplitthook(sd, ai, XADHC_READ, 0, buf, j)))
          return err;
        buf += j;               /* next part or end of buffer */
        param->xhp_DataPos += j;        /* add already read offset */
        i -= j;                 /* subtract already read size */
        ++sd;                   /* go to next part */
      }
    }
    break;
  case XADHC_SEEK:
    /* we cannot do any seeks, only set the current position */
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) ||
    (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_InSize))
      return XADERR_INPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_FULLSIZE:
    /* only last assignment is useful! */
    while(sd->xsd_InSize)
    {
      param->xhp_CommandData = sd->xsd_Offset + sd->xsd_InSize;
      ++sd;
    }
#ifdef DEBUG
  DebugOther("InHookSplitted: XADHC_FULLSIZE is %ld", param->xhp_CommandData);
#endif
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugHook("InHookSplitted: XADHC_INIT");
#endif
    {
      const struct xadSplitFile *sf;

      /* allocate xai_MultiVolume and xadSplitData array in one block */
      param->xhp_DataPos = 0;

      sf = ai->xaip_InSplitted;
      for(i = 1; sf; ++i)
      {
#ifdef AMIGA
        if(sf->xsf_Type < XAD_INFILENAME || sf->xsf_Type > XAD_INDEVICE)
#else
        if(sf->xsf_Type < XAD_INFILENAME || sf->xsf_Type > XAD_INXADSTREAM)
#endif
          return XADERR_BADPARAMS;
#ifdef DEBUG
  {
    static const xadSTRPTR type[] = {"XAD_INFILEHANDLE", "XAD_INMEMORY",
    "XAD_INHOOK", "XAD_INSPLITTED", "XAD_INDISKARCHIVE", "XAD_INXADSTREAM",
    "XAD_INDEVICE"};
    if(sf->xsf_Type == XAD_INFILENAME)
      DebugOther("InHookSplitted: XAD_INFILENAME, \"%s\" ($%08lx), size %ld", sf->xsf_Data, sf->xsf_Data, sf->xsf_Size);
    else
      DebugOther("InHookSplitted: %s, $%08lx, size %ld", type[sf->xsf_Type-XAD_INFILEHANDLE], sf->xsf_Data, sf->xsf_Size);
  }
#endif
        sf = sf->xsf_Next;
      }
      sf = ai->xaip_InSplitted;

      /* i is number of entries + 1 (last zero entry) */
      if((sd = (struct xadSplitData *) xadAllocVec(XADM i*(4 +
      sizeof(struct xadSplitData)), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
        xadERROR err;
        xadSignSize ofs = 0;

        param->xhp_PrivatePtr = sd;
        ai->xaip_ArchiveInfo.xai_MultiVolume = (xadSize *) (sd+i);
        for(i = 0; sf; ++i)
        {
          switch(sf->xsf_Type)
          {
          case XAD_INFILENAME:
            sd[i].xsd_InFileName = (xadSTRPTR)(uintptr_t) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookFH;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
          case XAD_INFILEHANDLE:
            sd[i].xsd_InFileHandle = /*(BPTR)*/ sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookFH;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
          case XAD_INMEMORY:
            sd[i].xsd_InMemory = (xadPTR)(uintptr_t) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookMem;
            if(!sf->xsf_Size || !sf->xsf_Data) return XADERR_BADPARAMS;
            break;
          case XAD_INHOOK:
            sd[i].xsd_Hook = (struct Hook *)(uintptr_t) sf->xsf_Data;
            break;
          case XAD_INSPLITTED:
            sd[i].xsd_InSplitted = (struct xadSplitFile *)(uintptr_t) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookSplitted;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
          case XAD_INDISKARCHIVE:
            sd[i].xsd_InDiskArc = (xadTAGPTR)(uintptr_t) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookDiskArc;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
          case XAD_INXADSTREAM:
            sd[i].xsd_InArcInfo = (xadTAGPTR)(uintptr_t) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookStream;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
#ifdef AMIGA
          case XAD_INDEVICE:
            sd[i].xsd_InDevice = (struct xadDeviceInfo *) sf->xsf_Data;
            sd[i].xsd_Hook = &ai->xaip_MasterBase->xmb_InHookDisk;
            if(!sf->xsf_Data) return XADERR_BADPARAMS;
            break;
#endif
          }
          if((err = callsplitthook(sd+i, ai, XADHC_INIT, 0, 0, 0)))
            return err;
          if(sf->xsf_Size)
            sd[i].xsd_InSize = sf->xsf_Size;
          else if((err = callsplitthook(sd+i, ai, XADHC_FULLSIZE, 0, 0, 0)))
            return err;
          else
            sd[i].xsd_InSize = sd[i].xsd_HookParam.xhp_CommandData;
          sd[i].xsd_Offset = ai->xaip_ArchiveInfo.xai_MultiVolume[i] = ofs;
          ofs += sd[i].xsd_InSize;
          sf = sf->xsf_Next;
        }
        sd[i].xsd_Offset = ofs; /* to get all-time abort condition */
      }
    }
    break;
  case XADHC_FREE:
    if(param->xhp_PrivatePtr)
    {
      while(sd->xsd_InSize)
        callsplitthook(sd++, ai, XADHC_FREE, 0, 0, 0);
      xadFreeObjectA(XADM_PRIV param->xhp_PrivatePtr, 0);
      param->xhp_PrivatePtr = 0;
      ai->xaip_ArchiveInfo.xai_MultiVolume = 0;
    }
    break;
  case XADHC_ABORT:
    if(param->xhp_PrivatePtr)
    {
      while(sd->xsd_InSize)
        callsplitthook(sd++, ai, XADHC_ABORT, 0, 0, 0);
    }
    break;
  default: return XADERR_NOTSUPPORTED;
  }

  return 0;
}
ENDFUNC

#endif /* XADMASTER_HOOK_SPLITTED_C */
