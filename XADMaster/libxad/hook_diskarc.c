#ifndef XADMASTER_HOOK_DISKARC_C
#define XADMASTER_HOOK_DISKARC_C

/*  $Id: hook_diskarc.c,v 1.8 2005/06/23 14:54:37 stoecker Exp $
    diskarc input file IO hook

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

#ifdef AMIGA
#include <proto/xadmaster.h>
#include <proto/utility.h>
#endif
#include "include/functions.h"
#include "include/SDI_compiler.h"

/************************************************************************
*                                                                       *
*    InHookDiskArc private structure                                    *
*                                                                       *
************************************************************************/

struct DiskArcPrivate
{
  struct xadArchiveInfo *ai;
  struct xadDiskInfo    *di;
  xadSize                insize;
  xadUINT8              *buffer;
};

/********************** read-from-diskarc hook **************************/

FUNCHOOK(InHookDiskArc)
{
  struct xadMasterBaseP * xadMasterBase;
  struct DiskArcPrivate *dap;
  xadERROR err = 0;

  xadMasterBase = ai->xaip_MasterBase;
  dap = (struct DiskArcPrivate *) param->xhp_PrivatePtr;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > dap->insize)
      err = XADERR_INPUT;
    else if(!dap->buffer)
    {
      if(!(dap->buffer = (xadUINT8 *) xadAllocVec(XADM dap->insize,
      XADMEMF_PUBLIC)))
      {
        err = XADERR_NOMEMORY;
      }
      else
      {
        err = xadDiskUnArc(XADM_PRIV XADM_AI(dap->ai), XAD_OUTSIZE,
        dap->insize, XAD_OUTMEMORY, dap->buffer, XAD_ENTRYNUMBER,
        dap->di->xdi_EntryNumber, TAG_DONE);
      }
    }
    if(!err)
    {
#ifdef DEBUG
  DebugOther("InHookDiskArc: read %ld bytes from %ld",
  param->xhp_BufferSize, param->xhp_DataPos);
#endif
      xadCopyMem(XADM dap->buffer + param->xhp_DataPos, param->xhp_BufferPtr, param->xhp_BufferSize);
      param->xhp_DataPos += param->xhp_BufferSize;
    }
    break;
  case XADHC_SEEK:
    if(param->xhp_DataPos + param->xhp_CommandData > dap->insize)
      return XADERR_INPUT;
#ifdef DEBUG
  DebugOther("InHookDiskArc: XADHC_SEEK, %ld from %ld", param->xhp_CommandData, param->xhp_DataPos);
#endif
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_FULLSIZE:
    param->xhp_CommandData = dap->insize;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugOther("InHookDiskArc: XADHC_INIT");
#endif
    if((dap = xadAllocVec(XADM sizeof(struct DiskArcPrivate), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      param->xhp_PrivatePtr = dap;
      if((dap->ai = (struct xadArchiveInfo *) xadAllocObject(XADM XADOBJ_ARCHIVEINFO, 0)))
      {
        if(!(err = xadGetInfoA(XADM XADM_AI(dap->ai), ai->xaip_InDiskArc)))
        {
          xadTAGPTR ti;
          xadUINT32 i = 0;
          struct xadDiskInfo *di;
#ifdef AMIGA
          struct UtilityBase *UtilityBase;
          UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif
          if((ti = FindTagItem(XAD_ENTRYNUMBER, ai->xaip_InDiskArc)))
            i = ti->ti_Data;

          if(!(di = dap->ai->xai_DiskInfo))
            err = XADERR_ILLEGALDATA;
          else
          {
            while(di && di->xdi_EntryNumber < i)
              di = di->xdi_Next;
            if(!di)
              err = XADERR_BADPARAMS;
            else
            {
              dap->di = di;
              dap->insize = di->xdi_TotalSectors;
              if(!(di->xdi_Flags & (XADDIF_NOCYLINDERS|XADDIF_NOCYLSECTORS)))
                dap->insize = (di->xdi_HighCyl-di->xdi_LowCyl+1)*di->xdi_CylSectors;
              dap->insize *= di->xdi_SectorSize;
            }
          }
        }
      }
      else
        err = XADERR_NOMEMORY;
    }
    else
      err = XADERR_NOMEMORY;
    break;
  case XADHC_FREE:
    if(dap)
    {
      if(dap->buffer)
        xadFreeObjectA(XADM dap->buffer, 0);
      if(dap->ai)
      {
        xadFreeInfo(XADM_PRIV XADM_AI(dap->ai));
        xadFreeObjectA(XADM_PRIV XADM_AI(dap->ai), 0);
      }
      xadFreeObjectA(XADM_PRIV dap, 0);
      param->xhp_PrivatePtr = 0;
    }
  case XADHC_ABORT: /* use break of XADHC_FREE */
    break;
  case XADHC_IMAGEINFO:
    {
      struct xadImageInfo *ii;

      ii = (struct xadImageInfo *)(uintptr_t) param->xhp_CommandData;
      ii->xii_SectorSize = dap->di->xdi_SectorSize;
      ii->xii_TotalSectors = dap->di->xdi_TotalSectors;
      if(dap->di->xdi_Flags & (XADDIF_NOCYLINDERS|XADDIF_NOCYLSECTORS))
      {
        ii->xii_NumSectors = dap->di->xdi_TotalSectors;
        ii->xii_FirstSector = 0;
      }
      else
      {
        ii->xii_NumSectors = (dap->di->xdi_HighCyl-dap->di->xdi_LowCyl+1)*dap->di->xdi_CylSectors;
        ii->xii_FirstSector = dap->di->xdi_LowCyl*dap->di->xdi_CylSectors;
      }
    }
    break;
  default: err = XADERR_NOTSUPPORTED;
  }

#ifdef DEBUG
  if(err)
    DebugError("InHookDiskArc returns \"%s\" (%ld)", xadGetErrorText(XADM err), err);
#endif

  return err;
}
ENDFUNC

#endif /* XADMASTER_HOOK_DISKARC_C */
