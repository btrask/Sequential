#ifndef XADMASTER_XADIO_XPK_C
#define XADMASTER_XADIO_XPK_C

/*  $Id: xadIO_XPK.c,v 1.10 2005/06/23 14:54:41 stoecker Exp $
    XPK files meta archiver

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

#include "xadIO.h"

#ifndef AMIGA
static xadINT32 xadIO_XPK(struct xadInOut *io, xadSTRPTR password)
{
  return XADERR_NOTSUPPORTED;
}
#else

#include <proto/xpkmaster.h>
#include <proto/xadmaster.h>
#include <proto/exec.h>
extern struct ExecBase *SysBase;

static xadINT32 xadIO_XPK(struct xadInOut *io, xadSTRPTR password)
{
  xadINT32 err;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct Library *XpkBase;
  struct XpkFib xfib;
  xadUINT8 head[8] = {0}, *mem, *mem2;
  xadUINT32 i,s;

#ifdef DEBUG
  DebugClient(io->xio_ArchiveInfo, "XPK - Password '%s'", password);
#endif
  for(i = 0; i < 8 && !io->xio_Error; ++i)
  {
    head[i] = xadIOGetChar(io);
  }
  if(EndGetM32(head) == 0x58504B46 && !io->xio_Error)
  {
    i = EndGetM32(head+4)+8;
    if((XpkBase = OpenLibrary("xpkmaster.library", 4)))
    {
      #ifdef __amigaos4__
      struct XpkIFace *IXpk;
      if (!(IXpk = (struct XpkIFace *)GetInterface(XpkBase, "main", 1L, NULL)))
      {
        CloseLibrary(XpkBase);
        return XADERR_RESOURCE;
      }
      #endif
    
      if((mem = (xadSTRPTR) xadAllocVec(XADM i, XADMEMF_PUBLIC)))
      {
        for(s = 0; s < 8; ++s)
          mem[s] = head[s];
        for(;s < i && !io->xio_Error; ++s)
          mem[s] = xadIOGetChar(io);
#ifdef DEBUG
  DebugClient(io->xio_ArchiveInfo, "XPK - Position %ld, Size %ld, Error %ld",
  s, i, io->xio_Error);
#endif
        if(!(io->xio_Error) && (XpkExamineTags(&xfib, XPK_InBuf, mem,
        XPK_InLen, i, TAG_DONE)) == 0)
        {
          if((mem2 = (xadSTRPTR) xadAllocVec(XADM xfib.xf_ULen+XPK_MARGIN,
          XADMEMF_PUBLIC|XADMEMF_CLEAR)))
          {
            if((err = XpkUnpackTags(XPK_InBuf, mem, XPK_InLen, i,
            XPK_OutBuf, mem2, XPK_OutBufLen, xfib.xf_ULen + XPK_MARGIN,
            password ? XPK_Password : TAG_IGNORE, password,
            XPK_UseXfdMaster, 0, XPK_PassRequest, FALSE, TAG_DONE)))
            {
#ifdef DEBUG
  DebugClient(io->xio_ArchiveInfo, "XPK - Error %d", err);
#endif
              switch(err)
              {
                case XPKERR_IOERRIN:     err = XADERR_INPUT; break;
                case XPKERR_IOERROUT:    err = XADERR_OUTPUT; break;
                case XPKERR_CORRUPTPKD:
                case XPKERR_TRUNCATED:   err = XADERR_ILLEGALDATA; break;
                case XPKERR_NOMEM:       err = XADERR_NOMEMORY; break;
                case XPKERR_WRONGCPU:
                case XPKERR_MISSINGLIB:
                case XPKERR_VERSION:
                case XPKERR_OLDMASTLIB:
                case XPKERR_OLDSUBLIB:
                case XPKERR_NOHARDWARE:
                case XPKERR_BADHARDWARE: err = XADERR_DATAFORMAT; break;
                case XPKERR_NEEDPASSWD:
                case XPKERR_WRONGPW:     err = XADERR_PASSWORD; break;
                default:                 err = XADERR_DECRUNCH; break;
              }
            }
            else
            {
              for(s=0; s < xfib.xf_ULen && !io->xio_Error; ++s)
                xadIOPutChar(io, mem2[s]);
            }
            xadFreeObjectA(XADM mem2, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
        else
          err = XADERR_ILLEGALDATA;
        xadFreeObjectA(XADM mem, 0);
      } /* xadAllocVec */
      else
        err = XADERR_NOMEMORY;
      #ifdef __amigaos4__
      DropInterface((struct Interface *)IXpk);
      #endif
      CloseLibrary(XpkBase);
    } /* OpenLibrary */
    else
      err = XADERR_RESOURCE;
  }
  else
  {
#ifdef DEBUG
    DebugClient(io->xio_ArchiveInfo, "XPK - Header error %08lx != 0x48504B46",
    EndGetM32(head));
#endif

    err = XADERR_DATAFORMAT;
  }

  if(io->xio_Error)
    err = io->xio_Error;

  return err;
}
#endif /* AMIGA */

#endif /* XADMASTER_XADIO_COMPRESS_C */
