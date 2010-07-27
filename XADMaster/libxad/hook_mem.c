#ifndef XADMASTER_HOOK_MEM_C
#define XADMASTER_HOOK_MEM_C

/*  $Id: hook_mem.c,v 1.5 2005/06/23 14:54:37 stoecker Exp $
    Memory IO hooks

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
#endif
#include "include/functions.h"
#include "include/SDI_compiler.h"

/*************************** read-from-mem hook **************************/

FUNCHOOK(InHookMem)
{
  struct xadMasterBaseP *xadMasterBase;

  xadMasterBase = ai->xaip_MasterBase;
  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_InSize)
      return XADERR_INPUT;
    if(param->xhp_BufferPtr)
      xadCopyMem(XADM ai->xaip_InMemory + param->xhp_DataPos, param->xhp_BufferPtr,
      param->xhp_BufferSize);
    param->xhp_DataPos += param->xhp_BufferSize;
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) ||
    (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_InSize))
      return XADERR_INPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugHook("InHookMem: XADHC_INIT");
#endif
    param->xhp_DataPos = 0;
  case XADHC_FREE:
  case XADHC_ABORT:
    break;
  default: return XADERR_NOTSUPPORTED;
  }

  return 0;
}
ENDFUNC

/*************************** write-to-mem hook **************************/

FUNCHOOK(OutHookMem)
{
  struct xadMasterBaseP *xadMasterBase;

  xadMasterBase = ai->xaip_MasterBase;
  switch(param->xhp_Command)
  {
  case XADHC_WRITE:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_OutSize)
      return XADERR_OUTPUT;
    xadCopyMem(XADM param->xhp_BufferPtr, ai->xaip_OutMemory + param->xhp_DataPos,
    param->xhp_BufferSize);
    param->xhp_DataPos += param->xhp_BufferSize;
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) ||
    (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_OutSize))
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugHook("OutHookMem: XADHC_INIT");
#endif
    param->xhp_DataPos = 0;
  case XADHC_FREE:
  case XADHC_ABORT:
    break;
  default: return XADERR_NOTSUPPORTED;
  }

  return 0;
}
ENDFUNC

#endif /* XADMASTER_HOOK_MEM_C */

