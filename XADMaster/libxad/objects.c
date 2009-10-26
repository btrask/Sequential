#ifndef XADMASTER_OBJECTS_C
#define XADMASTER_OBJECTS_C

/*  $Id: objects.c,v 1.10 2005/06/23 14:54:37 stoecker Exp $
    object allocation functions

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

#include "functions.h"

#ifndef AMIGA
#include <stdlib.h>
#include <string.h>
#define ObtainSemaphore(a)
#define ReleaseSemaphore(a)
#define AllocMem(a,b) malloc(a)
#define FreeMem(a,b) free(a)
#else
#include <proto/exec.h>
#define SysBase xadMasterBase->xmb_SysBase
#endif

FUNCxadAllocVec /* xadSize size, xadUINT32 flags */
{
  struct xadObject *obj;

  size += sizeof(struct xadObject);
  if((obj = (struct xadObject *) AllocMem(size, flags)))
  {
#ifndef AMIGA
    if(flags & XADMEMF_CLEAR)
      memset(obj, 0, size);
#endif
    obj->xo_Size = size;
    obj->xo_Type = XADOBJ_MEMBLOCK;
#ifdef DEBUGRESOURCE
    obj->xo_Next = 0;
    obj->xo_Cookie = XADOBJCOOKIE;
#ifdef AMIGA
    obj->xo_Task = FindTask(NULL);
    ObtainSemaphore(&xadMasterBase->xmb_ResourceLock);
#endif
    if((obj->xo_Last = xadMasterBase->xmb_Resource))
      obj->xo_Last->xo_Next = obj;
    xadMasterBase->xmb_Resource = obj;
    ReleaseSemaphore(&xadMasterBase->xmb_ResourceLock);
#endif
    ++obj;
  }

#ifdef DEBUG
  DebugMem("xadAllocVec: $%08lx, size %ld(+%ld)", obj,
  size-sizeof(struct xadObject), sizeof(struct xadObject));
#endif

  return obj;
}
ENDFUNC

#define ENDSTRUCT(b)    (((xadUINT8 *) obj) + sizeof(struct b))

#if defined(DEBUG) || defined(DEBUGRESOURCE)
static const xadSTRPTR debtype[] = {"unknown", "XADOBJ_ARCHIVEINFO",
  "XADOBJ_FILEINFO", "XADOBJ_DISKINFO", "XADOBJ_HOOKPARAM",
  "XADOBJ_DEVICEINFO", "XADOBJ_PROGRESSINFO", "XADOBJ_TEXTINFO",
  "XADOBJ_SPLITFILE", "XADOBJ_SKIPINFO", "XADOBJ_IMAGEINFO",
  "XADOBJ_SPECIAL"};

xadSTRPTR xadGetObjectTypeName(xadUINT32 type)
{
  if(type == XADOBJ_MEMBLOCK)
    return "XADOBJ_MEMBLOCK";
  else if(type == XADOBJ_STRING)
    return "XADOBJ_STRING";
  else if(type <= XADOBJ_SPECIAL)
    return debtype[type];
  return debtype[0];
}
#endif

FUNCxadAllocObject /* xadUINT32 type, xadTAGPTR tags */
{
  struct xadObject *obj = 0;

#ifdef DEBUG
  DebugTagListMem("xadAllocObjectA(%s [%ld], ...)", tags,
  debtype[type > XADOBJ_SPECIAL ? 0 : type], type);
#endif

  switch(type)
  {
    case XADOBJ_FILEINFO:
    {
      xadTAGPTR ti;
      xadSize nsize = 0, csize = 0, psize = 0;
      if((ti = FindTagItem(XAD_OBJNAMESIZE, tags)))
        nsize = ti->ti_Data + 1; /* +1 for programs forgetting 0 byte */
      if((ti = FindTagItem(XAD_OBJCOMMENTSIZE, tags)))
        csize = ti->ti_Data + 1;
      if((ti = FindTagItem(XAD_OBJPRIVINFOSIZE, tags)))
        psize = ti->ti_Data;

      if((obj = xadAllocVec(XADM nsize + csize + psize + sizeof(struct xadFileInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
        if(psize)
          ((struct xadFileInfo *) obj)->xfi_PrivateInfo
          = ENDSTRUCT(xadFileInfo);
        if(nsize)
          ((struct xadFileInfo *) obj)->xfi_FileName
          = (xadSTRPTR) ENDSTRUCT(xadFileInfo) + psize;
        if(csize)
          ((struct xadFileInfo *) obj)->xfi_Comment
          = (xadSTRPTR) ENDSTRUCT(xadFileInfo) + psize + nsize;
      }
    }
    break;
    case XADOBJ_DISKINFO:
    {
      xadTAGPTR ti;
      xadSize bsize = 0, psize = 0;
      if((ti = FindTagItem(XAD_OBJBLOCKENTRIES, tags)))
        bsize = ti->ti_Data;
      if((ti = FindTagItem(XAD_OBJPRIVINFOSIZE, tags)))
        psize = (ti->ti_Data+3)&(~3);   /* rounded to long */
      if((obj = xadAllocVec(XADM bsize + psize + sizeof(struct xadDiskInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
        if(psize)
          ((struct xadDiskInfo *) obj)->xdi_PrivateInfo
          = ENDSTRUCT(xadDiskInfo);
        if(bsize)
        {
          ((struct xadDiskInfo *) obj)->xdi_BlockInfo
          = (xadUINT8 *) ENDSTRUCT(xadDiskInfo) + psize;
          ((struct xadDiskInfo *) obj)->xdi_BlockInfoSize = bsize;
        }
      }
    }
    break;
    case XADOBJ_ARCHIVEINFO:
      obj = xadAllocVec(XADM sizeof(struct xadArchiveInfoP),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_HOOKPARAM:
      obj = xadAllocVec(XADM sizeof(struct xadHookParam),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_DEVICEINFO:
      obj = xadAllocVec(XADM sizeof(struct xadDeviceInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_PROGRESSINFO:
      obj = xadAllocVec(XADM sizeof(struct xadProgressInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_TEXTINFO:
      obj = xadAllocVec(XADM sizeof(struct xadTextInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_SPLITFILE:
      obj = xadAllocVec(XADM sizeof(struct xadSplitFile),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_SKIPINFO:
      obj = xadAllocVec(XADM sizeof(struct xadSkipInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_IMAGEINFO:
      obj = xadAllocVec(XADM sizeof(struct xadImageInfo),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
    case XADOBJ_SPECIAL:
      obj = xadAllocVec(XADM sizeof(struct xadSpecial),
      XADMEMF_PUBLIC|XADMEMF_CLEAR); break;
  }

  if(obj)
    (obj-1)->xo_Type = type;

  return obj;
}
ENDFUNC

FUNCxadFreeObject /* xadPTR object, xadTAGPTR tags */
{
  if(!object)
  {
#ifdef DEBUG
    DebugError("xadFreeObjectA: empty object pointer");
#endif
    return;
  }
  else
  {
    struct xadObject *obj;

    obj = ((struct xadObject *) object) - 1; /* get xadObject header */

#ifdef DEBUG
    if(obj->xo_Type == XADOBJ_MEMBLOCK)
    {
      if(!tags)
        DebugMem("xadFreeObjectA: XADOBJ_MEMBLOCK ($%08lx)", object);
      else
        DebugTagListMem("xadFreeObjectA: XADOBJ_MEMBLOCK ($%08lx)", tags,
        object);
    }
    else
      DebugTagListMem("xadFreeObjectA: %s ($%08lx)", tags,
      xadGetObjectTypeName(obj->xo_Type), object);
#endif
#ifdef DEBUGRESOURCE
    if(obj->xo_Cookie != XADOBJCOOKIE)
    {
      DebugResource(xadMasterBase,
      "xadFreeObjectA: %s ($%08lx) has defective cookie $%08lx",
      xadGetObjectTypeName(obj->xo_Type), object, obj->xo_Cookie);
    }

    if((obj->xo_Task != FindTask(NULL)))
    {
      DebugResource(xadMasterBase,
      "xadFreeObjectA: %s ($%08lx) was allocated by task $%08lx",
      xadGetObjectTypeName(obj->xo_Type), object, obj->xo_Task);
    }

    ObtainSemaphore(&xadMasterBase->xmb_ResourceLock);
    if(!obj->xo_Next) /* this is last entry, correct list */
    {
      if(obj != xadMasterBase->xmb_Resource)
      {
        DebugResource(xadMasterBase,
        "xadFreeObjectA: %s ($%08lx) last entry incorrect",
        xadGetObjectTypeName(obj->xo_Type), object);
      }
      xadMasterBase->xmb_Resource = obj->xo_Last;
    }
    else
    {
      if(obj->xo_Next->xo_Cookie != XADOBJCOOKIE)
      {
        DebugResource(xadMasterBase,
        "xadFreeObjectA: %s ($%08lx) has defective next cookie $%08lx",
        xadGetObjectTypeName(obj->xo_Type), object, obj->xo_Next->xo_Cookie);
      }
      obj->xo_Next->xo_Last = obj->xo_Last;
    }
    if(obj->xo_Last)
    {
      if(obj->xo_Last->xo_Cookie != XADOBJCOOKIE)
      {
        DebugResource(xadMasterBase,
        "xadFreeObjectA: %s ($%08lx) has defective last cookie $%08lx",
        xadGetObjectTypeName(obj->xo_Type), object, obj->xo_Last->xo_Cookie);
      }
      obj->xo_Last->xo_Next = obj->xo_Next;
    }
    ReleaseSemaphore(&xadMasterBase->xmb_ResourceLock);
#endif

    FreeMem(obj, obj->xo_Size);
  }
}
ENDFUNC

#endif  /* XADMASTER_OBJECTS_C */
