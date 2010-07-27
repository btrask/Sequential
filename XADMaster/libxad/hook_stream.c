#ifndef XADMASTER_HOOK_STREAM_C
#define XADMASTER_HOOK_STREAM_C

/*  $Id: hook_stream.c,v 1.6 2005/06/23 14:54:37 stoecker Exp $
    XAD Stream IO hooks

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
*    In/OutHookStream private structure                                 *
*                                                                       *
************************************************************************/

struct StreamPrivate
{
  struct xadArchiveInfo *ai;
  struct TagItem         ti[6];
  /* XAD_USESKIPINFO, XAD_GETCRC16, XAD_GETCRC32, XAD_CRC16ID, XAD_CRC32ID, TAG_DONE */
};

/*************************** read-from-mem hook **************************/


FUNCHOOK(InHookStream)
{
  xadERROR err = 0;
  struct xadMasterBaseP *xadMasterBase;
  struct StreamPrivate *sp;

  xadMasterBase = ai->xaip_MasterBase;
  sp = (struct StreamPrivate *) param->xhp_PrivatePtr;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_InSize)
      err = XADERR_INPUT;
    else if(param->xhp_BufferPtr)
    {
      err = xadHookTagAccessA(XADM_PRIV XADAC_READ, param->xhp_BufferSize,
      param->xhp_BufferPtr, XADM_AI(sp->ai), sp->ti);
      param->xhp_DataPos += param->xhp_BufferSize;
    }
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0)
    || (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_InSize))
    {
      return XADERR_INPUT;
    }
    err = xadHookTagAccessA(XADM_PRIV XADAC_INPUTSEEK,
    param->xhp_CommandData, 0, XADM_AI(sp->ai), sp->ti);
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugOther("InHookStream: XADHC_INIT");
#endif
    if((sp = xadAllocVec(XADM sizeof(struct StreamPrivate), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      xadTAGPTR ti, ti2;
#ifdef AMIGA
      struct UtilityBase *UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif
      xadINT32 i;

      param->xhp_PrivatePtr = sp;

      for(i = 0; i < 5; ++i)
        sp->ti[i].ti_Tag = TAG_IGNORE;
      sp->ti[5].ti_Tag = TAG_DONE;

      ti = ti2 = ai->xaip_InArcInfo;
      while((ti2 = NextTagItem(&ti)))
      {
        switch(ti2->ti_Tag)
        {
          case XAD_ARCHIVEINFO: sp->ai = (struct xadArchiveInfo *)(uintptr_t) ti2->ti_Data; break;
          case XAD_USESKIPINFO: sp->ti[0].ti_Tag = ti2->ti_Tag; sp->ti[0].ti_Data = ti2->ti_Data; break;
          case XAD_GETCRC32: sp->ti[1].ti_Tag = ti2->ti_Tag; sp->ti[1].ti_Data = ti2->ti_Data; break;
          case XAD_GETCRC16: sp->ti[2].ti_Tag = ti2->ti_Tag; sp->ti[2].ti_Data = ti2->ti_Data; break;
          case XAD_CRC32ID: sp->ti[3].ti_Tag = ti2->ti_Tag; sp->ti[3].ti_Data = ti2->ti_Data; break;
          case XAD_CRC16ID: sp->ti[4].ti_Tag = ti2->ti_Tag; sp->ti[4].ti_Data = ti2->ti_Data; break;
        }
      }

      for(i = 5; i >= 0 && sp->ti[i].ti_Tag == TAG_IGNORE; --i) /* reduce the number of TAG_IGNORE */
        sp->ti[i].ti_Tag = TAG_DONE;

      if(!sp->ai)
        err = XADERR_BADPARAMS;
    }
    else
      err = XADERR_NOMEMORY;
    param->xhp_DataPos = 0;
    break;
  case XADHC_FREE:
    if(param->xhp_PrivatePtr)
    {
      xadFreeObjectA(XADM param->xhp_PrivatePtr, 0);
      param->xhp_PrivatePtr = 0;
    }
    break;
  case XADHC_FULLSIZE:
    param->xhp_CommandData = sp->ai->xai_InSize-sp->ai->xai_InPos;
    if(sp->ti[0].ti_Data) /* use skipinfo */
    {
      param->xhp_CommandData += param->xhp_CommandData
      - getskipsize(param->xhp_CommandData, (struct xadArchiveInfoP *) sp->ai);
    }
#ifdef DEBUG
  DebugOther("InHookStream: XADHC_FULLSIZE = %ld", param->xhp_CommandData);
#endif
    break;
  case XADHC_ABORT:
    break;
  default: return XADERR_NOTSUPPORTED;
  }

  return err;
}
ENDFUNC

/*************************** write-to-mem hook **************************/

FUNCHOOK(OutHookStream)
{
  xadERROR err = 0;
  struct xadMasterBaseP *xadMasterBase;
  struct StreamPrivate *sp;

  xadMasterBase = ai->xaip_MasterBase;
  sp = (struct StreamPrivate *) param->xhp_PrivatePtr;

  switch(param->xhp_Command)
  {
  case XADHC_WRITE:
    err = xadHookTagAccessA(XADM_PRIV XADAC_WRITE, param->xhp_BufferSize,
    param->xhp_BufferPtr, XADM_AI(sp->ai), sp->ti);
    param->xhp_DataPos += param->xhp_BufferSize;
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) || (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_OutSize))
      return XADERR_OUTPUT;
    err = xadHookTagAccessA(XADM XADAC_OUTPUTSEEK, param->xhp_CommandData,
    0, XADM_AI(sp->ai), sp->ti);
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugOther("OutHookStream: XADHC_INIT");
#endif
    if((sp = xadAllocVec(XADM sizeof(struct StreamPrivate), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      xadTAGPTR ti, ti2;
#ifdef AMIGA
      struct UtilityBase *UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif
      xadINT32 i;

      param->xhp_PrivatePtr = sp;

      for(i = 0; i < 5; ++i)
        sp->ti[i].ti_Tag = TAG_IGNORE;
      sp->ti[5].ti_Tag = TAG_DONE;

      ti = ti2 = ai->xaip_InArcInfo;
      while((ti2 = NextTagItem(&ti)))
      {
        switch(ti2->ti_Tag)
        {
          case XAD_ARCHIVEINFO: sp->ai = (struct xadArchiveInfo *)(uintptr_t) ti2->ti_Data; break;
          case XAD_USESKIPINFO: sp->ti[0].ti_Tag = ti2->ti_Tag; sp->ti[0].ti_Data = ti2->ti_Data; break;
          case XAD_GETCRC32: sp->ti[1].ti_Tag = ti2->ti_Tag; sp->ti[1].ti_Data = ti2->ti_Data; break;
          case XAD_GETCRC16: sp->ti[2].ti_Tag = ti2->ti_Tag; sp->ti[2].ti_Data = ti2->ti_Data; break;
          case XAD_CRC32ID: sp->ti[3].ti_Tag = ti2->ti_Tag; sp->ti[3].ti_Data = ti2->ti_Data; break;
          case XAD_CRC16ID: sp->ti[4].ti_Tag = ti2->ti_Tag; sp->ti[4].ti_Data = ti2->ti_Data; break;
        }
      }

      for(i = 5; i >= 0 && sp->ti[i].ti_Tag == TAG_IGNORE; --i) /* reduce the number of TAG_IGNORE */
        sp->ti[i].ti_Tag = TAG_DONE;

      if(!sp->ai)
        err = XADERR_BADPARAMS;
    }
    else
      err = XADERR_NOMEMORY;
    param->xhp_DataPos = 0;
    break;
  case XADHC_FREE:
    if(param->xhp_PrivatePtr)
    {
      xadFreeObjectA(XADM_PRIV param->xhp_PrivatePtr, 0);
      param->xhp_PrivatePtr = 0;
    }
    break;
  case XADHC_ABORT:
    break;
  default: return XADERR_NOTSUPPORTED;
  }

  return err;
}
ENDFUNC

#endif /* XADMASTER_HOOK_STREAM_C */
