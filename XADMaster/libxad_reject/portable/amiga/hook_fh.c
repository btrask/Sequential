#ifndef XADMASTER_HOOK_FH_C
#define XADMASTER_HOOK_FH_C

/*  $Id: hook_fh.c,v 1.7 2006/05/16 06:05:05 stoecker Exp $
    File IO hooks

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

#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/utility.h>
#include <proto/xadmaster.h>
#include "privdefs.h"
#include "functions.h"
#include "SDI_compiler.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

#define         XADFHBUFSIZE    (16*1024)

struct xadFHData {
  xadSize  xfh_BufStart;
  xadSize  xfh_BufEnd; /* equals file position! */
  xadUINT8 xfh_Buffer[XADFHBUFSIZE];
};

#define XADFH   ((struct xadFHData *) param->xhp_PrivatePtr)

/*************************** read-from-fh hook ***************************/
FUNCHOOK(InHookFH) /* struct Hook *hook, struct xadArchiveInfoP *ai,
struct xadHookParam *param */
{
  struct xadMasterBaseP *xadMasterBase;
  struct DosLibrary *DOSBase;

  xadMasterBase = ai->xaip_MasterBase;
  DOSBase = xadMasterBase->xmb_DOSBase;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_InSize)
      return XADERR_INPUT;
    else
    {
      xadUINT8 *buf;
      xadSignSize size, pos, p, siz;

      buf = param->xhp_BufferPtr;
      pos = param->xhp_DataPos;
      size = param->xhp_BufferSize;

#ifdef DEBUG
  DebugOther("InHookFH: IS [%10ld - %10ld], NEED [%10ld - %10ld]",
  XADFH->xfh_BufStart, XADFH->xfh_BufEnd, pos, pos+size);
#endif

      if(pos >= XADFH->xfh_BufStart && pos < XADFH->xfh_BufEnd)
      {
        if((siz = XADFH->xfh_BufEnd-pos) > size)
          siz = size;
#ifdef DEBUG
  DebugOther("InHookFH: Copy %ld bytes", siz);
#endif
        xadCopyMem(XADFH->xfh_Buffer + (pos - XADFH->xfh_BufStart), buf, siz);
        buf += siz;
        pos += siz;
        size -= siz;
      }
      while(size)
      {
        p = pos;
        if(size < XADFHBUFSIZE/2)
          p -= pos % (XADFHBUFSIZE/2); /* round down to half buffer */
        if(XADFH->xfh_BufEnd != p)
        {
#ifdef DEBUG
  DebugOther("InHookFH: Seek(., %ld, OFFSET_CURRENT) from %ld",
  p-XADFH->xfh_BufEnd, XADFH->xfh_BufEnd);
#endif
          if(Seek(ai->xaip_InFileHandle, p-XADFH->xfh_BufEnd, OFFSET_CURRENT) < 0)
            return XADERR_INPUT;
        }

        if(size > XADFHBUFSIZE && (p == pos))
        {
#ifdef DEBUG
  DebugOther("InHookFH: DirectRead(., ., %ld) from %ld", size, pos);
#endif
          if(Read(ai->xaip_InFileHandle, buf, size) != size)
            return XADERR_INPUT;
          buf += size;
          pos += size;
          size = 0;
          xadCopyMem(buf-XADFHBUFSIZE, XADFH->xfh_Buffer, XADFHBUFSIZE);
          XADFH->xfh_BufStart = pos-XADFHBUFSIZE;
          XADFH->xfh_BufEnd = pos;
        }
        else
        {
          if((siz = ai->xaip_InSize - p) > XADFHBUFSIZE)
            siz = XADFHBUFSIZE;

          XADFH->xfh_BufStart = p;
          XADFH->xfh_BufEnd = XADFH->xfh_BufStart + siz;
#ifdef DEBUG
  DebugOther("InHookFH: Read(., ., %ld) from %ld", siz, XADFH->xfh_BufStart);
#endif
          if(Read(ai->xaip_InFileHandle, XADFH->xfh_Buffer, siz) != siz)
            return XADERR_INPUT;

          if((siz = XADFH->xfh_BufEnd-pos) > size)
            siz = size;
#ifdef DEBUG
  DebugOther("InHookFH: Copy %ld bytes", siz);
#endif
          xadCopyMem(XADFH->xfh_Buffer + (pos - XADFH->xfh_BufStart), buf, siz);
          buf += siz;
          pos += siz;
          size -= siz;
        }
      }
      param->xhp_DataPos += param->xhp_BufferSize;
    }
    break;
  case XADHC_SEEK:
    if(param->xhp_DataPos + param->xhp_CommandData > ai->xaip_InSize)
      return XADERR_INPUT;
#ifdef DEBUG
  DebugOther("InHookFH: XADHC_SEEK, %ld from %ld", param->xhp_CommandData, param->xhp_DataPos);
#endif
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_FREE: /* free filehandle */
    if(param->xhp_PrivatePtr)
    {
      xadFreeObjectA(param->xhp_PrivatePtr, 0);
      param->xhp_PrivatePtr = 0;
    }
    if(ai->xaip_InFileName && ai->xaip_InFileHandle)
      Close(ai->xaip_InFileHandle);
    ai->xaip_InFileHandle = 0;
    break;
  case XADHC_FULLSIZE:
    {
      xadSignSize s1, s2;
      if((s1 = Seek(ai->xaip_InFileHandle, 0, OFFSET_END)) < 0 ||
      (s2 = Seek(ai->xaip_InFileHandle, s1, OFFSET_BEGINNING)) < 0)
        return XADERR_INPUT;
      param->xhp_CommandData = s2-s1;
    }
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugHook("InHookFH: XADHC_INIT");
#endif
    if(!(param->xhp_PrivatePtr = xadAllocVec(sizeof(struct xadFHData),
    XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      return XADERR_NOMEMORY;
    param->xhp_DataPos = 0;
    if(ai->xaip_InFileName)
    {
      if(!(ai->xaip_InFileHandle = Open(ai->xaip_InFileName, MODE_OLDFILE)))
        return XADERR_OPENFILE;
    }
    break;
  case XADHC_ABORT:
    break;
  default: return XADERR_NOTSUPPORTED;
  }
  return 0;
}
ENDFUNC

static xadERROR opendestfile(struct xadArchiveInfoP *ai)
{
  xadFileHandle a;
  xadUINT32 i, j, flags;
  xadERROR ret = 0;
  xadINT32 doloop = 1;
  xadSTRPTR n, n2 = 0, name = ai->xaip_OutFileName;
  struct xadMasterBaseP *xadMasterBase;
  struct DosLibrary *DOSBase;

  xadMasterBase = ai->xaip_MasterBase;
  DOSBase = xadMasterBase->xmb_DOSBase;
  flags = ai->xaip_ArchiveInfo.xai_Flags;

  while(!ret && doloop)
  {
    if(!(a = Lock(name, SHARED_LOCK)))
      doloop = 0;
    else
    {
      struct FileInfoBlock *fib;
      if((fib = (struct FileInfoBlock *) AllocDosObject(DOS_FIB, 0)))
      {
        if(Examine(a, fib))
        {
          UnLock(a); a = 0;
          n = name;
          if((fib->fib_DirEntryType < 0 && (flags & XADAIF_OVERWRITE)))
            doloop = 0;
          else
          {
#ifdef DEBUG
  DebugOther("InHookFH: ask overwrite/isdir: '%s'", name);
#endif
            j = callprogressFN(ai, fib->fib_DirEntryType < 0 ? XADPIF_OVERWRITE : XADPIF_ISDIRECTORY,
            XADPMODE_ASK, &n, ai->xaip_MasterBase);
#ifdef DEBUG
  DebugOther("InHookFH: ask overwrite/isdir result: %ld", j);
#endif
            if(!(j & XADPIF_OK))
              ret = XADERR_BREAK;
            else if(j & XADPIF_SKIP)
              ret = XADERR_SKIP;
            else if(j & XADPIF_RENAME)
            {
              if(!n)
                ret = XADERR_BADPARAMS;
              else
              {
                if(n2)
                  xadFreeObjectA(n2, 0);
                name = n2 = n;
              }
            }
            else if((j & XADPIF_OVERWRITE) && fib->fib_DirEntryType < 0)
            {
              flags |= XADAIF_OVERWRITE; doloop = 0;
            }
            else
              ret = fib->fib_DirEntryType < 0 ? XADERR_FILEEXISTS : XADERR_FILEDIR;
          }
        }
        else
          ret = XADERR_INPUT;
        FreeDosObject(DOS_FIB, fib);
      }
      else
        ret = XADERR_NOMEMORY;
    }
    if(a)
      UnLock(a);
  }

  if(!ret && !((ai->xaip_OutFileHandle = Open(name, MODE_NEWFILE))))
  {
    xadSTRPTR buf;

    i = strlen(name)+1;
    if((buf = (xadSTRPTR) xadAllocVec(i, XADMEMF_PUBLIC)))
    {
      i = 0;
      while(!ret && name[i])
      {
        for(;name[i] && name[i] != '/'; ++i)
          buf[i] = name[i];
        if(name[i] == '/')
        {
          buf[i] = 0;
          if((a = Lock(buf, SHARED_LOCK)))
            UnLock(a);
          else
          {
            if(!(flags & XADAIF_MAKEDIRECTORY))
            {
              if(!((j = callprogress(ai, XADPIF_MAKEDIRECTORY, XADPMODE_ASK,
              ai->xaip_MasterBase)) & XADPIF_OK))
                ret = XADERR_BREAK;
              else if(j & XADPIF_SKIP)
                ret =  XADERR_SKIP;
              else if(!(j & XADPIF_MAKEDIRECTORY))
                ret = XADERR_MAKEDIR;
              else
                flags |= XADAIF_MAKEDIRECTORY;
            }

            if(!ret)
            {
              if((a = CreateDir(buf)))
                UnLock(a);
              else
                ret = XADERR_MAKEDIR;
            }
          }
          buf[i] = name[i];
          ++i;
        }
      }
      xadFreeObjectA(buf, 0);
    }
    else
      ret = XADERR_NOMEMORY;
    if(!ret && !((ai->xaip_OutFileHandle = Open(name, MODE_NEWFILE))))
      ret = XADERR_OPENFILE;
  }

  if(n2)
    xadFreeObjectA(n2, 0);

  return ret;
}

/****************************** write-to-fh hook *************************/

FUNCHOOK(OutHookFH) /* struct Hook *hook, struct xadArchiveInfoP *ai,
struct xadHookParam *param */
{
  struct DosLibrary *DOSBase;
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) ai->xaip_MasterBase;

  DOSBase = xadMasterBase->xmb_DOSBase;
  switch(param->xhp_Command)
  {
  case XADHC_WRITE:
    if(Write(ai->xaip_OutFileHandle, param->xhp_BufferPtr,
    param->xhp_BufferSize) != param->xhp_BufferSize)
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_BufferSize;
    break;
  case XADHC_SEEK:
    if(param->xhp_CommandData && /* skip useless 0 seek */
    Seek(ai->xaip_OutFileHandle, param->xhp_CommandData, OFFSET_CURRENT) < 0)
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_ABORT:
    if(ai->xaip_OutFileName && ai->xaip_OutFileHandle)
    {
      Close(ai->xaip_OutFileHandle);
      ai->xaip_OutFileHandle = 0;
      if(!(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_NOKILLPARTIAL))
        DeleteFile(ai->xaip_OutFileName);
    }
    break;
  case XADHC_FREE: /* free filehandle */
    if(ai->xaip_OutFileName && ai->xaip_OutFileHandle)
      Close(ai->xaip_OutFileHandle);
    ai->xaip_OutFileHandle = 0;
    break;
  case XADHC_INIT:
#ifdef DEBUG
  DebugHook("OutHookFH: XADHC_INIT");
#endif
    param->xhp_DataPos = 0;
    if(ai->xaip_OutFileName)
      return opendestfile(ai);
    break;
  default: return XADERR_NOTSUPPORTED;
  }
  return 0;
}
ENDFUNC

#endif /* XADMASTER_HOOK_FH_C */
