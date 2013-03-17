#ifndef XADMASTER_HOOK_FH_C
#define XADMASTER_HOOK_FH_C

/*  $Id: hook_fh.c,v 1.10 2005/06/23 14:54:43 stoecker Exp $
    File IO hooks for Unix

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


#include "../include/functions.h"
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#define         XADFHBUFSIZE    (16*1024)

struct xadFHData {
  xadSize xfh_BufStart;
  xadSize xfh_BufEnd; /* equals file position! */
  xadUINT8  xfh_Buffer[XADFHBUFSIZE];
};

#define XADFH   ((struct xadFHData *) param->xhp_PrivatePtr)

/*************************** read-from-fh hook ***************************/

FUNCHOOK(InHookFH)
{
  struct xadMasterBaseP *xadMasterBase;
  xadMasterBase = ai->xaip_MasterBase;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    if(param->xhp_DataPos + param->xhp_BufferSize > ai->xaip_InSize)
      return XADERR_INPUT;
    else
    {
      xadSTRPTR buf;
      xadSize size, pos, p, siz;

      buf = param->xhp_BufferPtr;
      pos = param->xhp_DataPos;
      size = param->xhp_BufferSize;

      //printf("InHookFH: IS [%10ld - %10ld], NEED [%10ld - %10ld]\n", XADFH->xfh_BufStart, XADFH->xfh_BufEnd, pos, pos+size);

      if(pos >= XADFH->xfh_BufStart && pos < XADFH->xfh_BufEnd)
      {
        if((siz = XADFH->xfh_BufEnd-pos) > size)
          siz = size;

        xadCopyMem(XADM XADFH->xfh_Buffer + (pos - XADFH->xfh_BufStart), buf, siz);
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
          if(lseek(ai->xaip_InFileHandle, p, SEEK_SET) == (off_t) -1)
          {
            return XADERR_INPUT;
          }
        }

        if(size > XADFHBUFSIZE && (p == pos))
        {
         //printf("InHookFH: DirectRead(., ., %ld) from %ld\n", size, pos);

         if(read(ai->xaip_InFileHandle, buf, size) != size)
            return XADERR_INPUT;

          buf += size;
          pos += size;
          size = 0;
          xadCopyMem(XADM buf-XADFHBUFSIZE, XADFH->xfh_Buffer, XADFHBUFSIZE);
          XADFH->xfh_BufStart = pos-XADFHBUFSIZE;
          XADFH->xfh_BufEnd = pos;
        }
        else
        {
          if((siz = ai->xaip_InSize - p) > XADFHBUFSIZE)
            siz = XADFHBUFSIZE;

          XADFH->xfh_BufStart = p;
          XADFH->xfh_BufEnd = XADFH->xfh_BufStart + siz;

          //printf("InHookFH: Read(., ., %ld) from %ld\n", siz, XADFH->xfh_BufStart);

          if(read(ai->xaip_InFileHandle, XADFH->xfh_Buffer, siz) != siz)
            return XADERR_INPUT;

          if((siz = XADFH->xfh_BufEnd-pos) > size)
            siz = size;

          xadCopyMem(XADM XADFH->xfh_Buffer + (pos - XADFH->xfh_BufStart), buf, siz);
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
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_FREE: /* free filehandle */
    if(param->xhp_PrivatePtr)
    {
      xadFreeObjectA(XADM param->xhp_PrivatePtr, 0);
      param->xhp_PrivatePtr = 0;
    }
    if(ai->xaip_InFileName && ai->xaip_InFileHandle)
      close(ai->xaip_InFileHandle);
    ai->xaip_InFileHandle = 0;
    break;
  case XADHC_FULLSIZE:
    {
      off_t s1 = lseek(ai->xaip_InFileHandle, 0, SEEK_END);
      if(s1 == -1)
        return XADERR_INPUT;

      if(lseek(ai->xaip_InFileHandle, 0, SEEK_SET) == -1)
        return XADERR_INPUT;

      param->xhp_CommandData = s1;
      //ai->xaip_InSize = s1;
    }
    break;
  case XADHC_INIT:
    if(!(param->xhp_PrivatePtr = xadAllocVec(XADM sizeof(struct xadFHData),
    XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      return XADERR_NOMEMORY;
    param->xhp_DataPos = 0;
    if(ai->xaip_InFileName)
      if(-1 == (ai->xaip_InFileHandle = open((const char *)ai->xaip_InFileName, O_RDONLY)))
        return XADERR_OPENFILE;
    break;
  case XADHC_ABORT:
    break;
  default:
   return XADERR_NOTSUPPORTED;
  }
  return 0;
}
ENDFUNC

static xadINT32 opendestfile(struct xadArchiveInfoP *ai)
{
  xadUINT32 i, j, flags;
  xadINT32 ret = 0, doloop = 1;
  xadSTRPTR n, n2 = 0, name = ai->xaip_OutFileName;
  struct xadMasterBaseP *xadMasterBase;
  struct stat statBuf;

  xadMasterBase = ai->xaip_MasterBase;
  flags = ai->xaip_ArchiveInfo.xai_Flags;

  while(!ret && doloop)
  {
    if(stat((const char *)name, &statBuf) == -1)
      break;

    n = name;

    if((S_ISREG(statBuf.st_mode) && (flags & XADAIF_OVERWRITE)))
        break;

#ifdef DEBUG
  DebugOther("InHookFH: ask overwrite/isdir: '%s'", name);
#endif

    j = callprogressFN(ai, S_ISREG(statBuf.st_mode) ? XADPIF_OVERWRITE
    : XADPIF_ISDIRECTORY, XADPMODE_ASK, &n, ai->xaip_MasterBase);

#ifdef DEBUG
  DebugOther("InHookFH: ask overwrite/isdir result: %ld", j);
#endif

   if(n2)
     xadFreeObjectA(XADM n2, 0);

   n2 = 0;

   if(!(j & XADPIF_OK))
     ret = XADERR_BREAK;
   else if(j & XADPIF_SKIP)
     ret = XADERR_SKIP;
   else if(j & XADPIF_RENAME)
   {
     if(!n)
       ret = XADERR_BADPARAMS;
     else
       name = n2 = n;
   }
   else if((j & XADPIF_OVERWRITE) && S_ISREG(statBuf.st_mode))
   {
     flags |= XADAIF_OVERWRITE;
     break;
   }
   else
     ret = S_ISREG(statBuf.st_mode) ? XADERR_FILEEXISTS : XADERR_FILEDIR;
  }

  if(!ret && ((ai->xaip_OutFileHandle =
  open((const char *)name, O_WRONLY|O_CREAT, S_IRWXU))) == -1)
  {
    xadSTRPTR buf;

    i = strlen((const char *)name)+1;
    if((buf = (xadSTRPTR) xadAllocVec(XADM i, XADMEMF_PUBLIC)))
    {
      i = 0;
      while(!ret && name[i])
      {
        for(;name[i] && name[i] != '/'; ++i)
          buf[i] = name[i];
        if(name[i] == '/')
        {
          buf[i] = 0;
          if(stat((const char *)buf, &statBuf) != -1)
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
              #ifndef __MINGW32__
              if(mkdir((const char *)buf, S_IRWXU) == -1)
                ret = XADERR_MAKEDIR;
              #else
              if(mkdir((const char *)buf) == -1)
                ret = XADERR_MAKEDIR;
              #endif
            }
          }
          buf[i] = name[i];
          ++i;
        }
      }
      xadFreeObjectA(XADM buf, 0);
    }
    else
      ret = XADERR_NOMEMORY;
    if(!ret && ((ai->xaip_OutFileHandle = open((const char *)name, O_WRONLY|O_CREAT, S_IRWXU)) == -1))
      ret = XADERR_OPENFILE;
  }

  if(n2)
    xadFreeObjectA(XADM n2, 0);

  return ret;
}

/****************************** write-to-fh hook *************************/

FUNCHOOK(OutHookFH)
{
  switch(param->xhp_Command)
  {
  case XADHC_WRITE:
    if(write(ai->xaip_OutFileHandle, param->xhp_BufferPtr,
    param->xhp_BufferSize) != param->xhp_BufferSize /*== -1*/)
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_BufferSize;
    break;
  case XADHC_SEEK:
    if(param->xhp_CommandData && /* skip useless 0 seek */
    lseek(ai->xaip_OutFileHandle, param->xhp_CommandData, SEEK_CUR) == -1)
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_ABORT:
    if(ai->xaip_OutFileName && ai->xaip_OutFileHandle)
    {
      close(ai->xaip_OutFileHandle);
      ai->xaip_OutFileHandle = 0;
      if(!(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_NOKILLPARTIAL))
        remove((const char *)ai->xaip_OutFileName);
    }
    break;
  case XADHC_FREE: /* free filehandle */
    if(ai->xaip_OutFileName && ai->xaip_OutFileHandle)
      close(ai->xaip_OutFileHandle);
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
