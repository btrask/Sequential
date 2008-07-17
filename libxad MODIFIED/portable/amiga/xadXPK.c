#ifndef XADMASTER_XADXPK_C
#define XADMASTER_XADXPK_C

/*  $Id: xadXPK.c,v 1.5 2005/06/23 14:54:40 stoecker Exp $
    xpk decrunch handling

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

#include <proto/xpkmaster.h>
#include <proto/xadmaster.h>
#include <proto/exec.h>

extern struct ExecBase *SysBase;

static xadERROR GetXpkError(xadINT32 err)
{
  xadERROR ret;

  switch(err)
  {
    case XPKERR_OK:             ret = XADERR_OK; break;
    case XPKERR_IOERRIN:        ret = XADERR_INPUT; break;
    case XPKERR_IOERROUT:       ret = XADERR_OUTPUT; break;
    case XPKERR_CORRUPTPKD:
    case XPKERR_TRUNCATED:      ret = XADERR_ILLEGALDATA; break;
    case XPKERR_NOMEM:          ret = XADERR_NOMEMORY; break;
    case XPKERR_WRONGCPU:
    case XPKERR_MISSINGLIB:
    case XPKERR_VERSION:
    case XPKERR_OLDMASTLIB:
    case XPKERR_OLDSUBLIB:
    case XPKERR_NOHARDWARE:
    case XPKERR_BADHARDWARE:    ret = XADERR_RESOURCE; break;
    case XPKERR_NEEDPASSWD:
    case XPKERR_WRONGPW:        ret = XADERR_PASSWORD; break;
    default:                    ret = XADERR_DECRUNCH; break;
  };
  return ret;
}

/* reads XPKF file from current input stream and stores a pointer to
decrunched file in *str and the size in *size */
static xadERROR xpkDecrunch(xadUINT8 **str, xadUINT32 *size,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  struct Library *XpkBase;
  xadUINT32 buf[2];
  xadERROR err;
  xadUINT32 *mem;

  if((XpkBase = OpenLibrary("xpkmaster.library", 4)))
  {
    #ifdef __amigaos4__
    struct XpkIFace *IXpk;
    
    if (!(IXpk = (struct XpkIFace *) GetInterface(XpkBase, "main", 1, NULL)))
    {
      CloseLibrary(XpkBase);
      return XADERR_NOMEMORY;
    }
    #endif
  
    if(!(err = xadHookAccess(XADAC_READ, 8, buf, ai)))
    {
      if((mem = xadAllocVec(buf[1]+8, XADMEMF_PUBLIC)))
      {
        if(!(err = xadHookAccess(XADAC_READ, buf[1], mem+2, ai)))
        {
          struct XpkFib xfib;

          mem[0] = buf[0];
          mem[1] = buf[1];

          if(!XpkExamineTags(&xfib, XPK_InBuf, mem,
          XPK_InLen, buf[1]+8, TAG_DONE))
          {
            xadUINT8 *mem2;

            if((mem2 = (xadUINT8 *) xadAllocVec(xfib.xf_ULen+XPK_MARGIN,
            XADMEMF_PUBLIC|XADMEMF_CLEAR)))
            {
              *str = mem2;
              *size = xfib.xf_ULen;

              if((err = GetXpkError(XpkUnpackTags(XPK_InBuf, mem,
              XPK_InLen, buf[1]+8, XPK_OutBuf, mem2, XPK_OutBufLen,
              *size + XPK_MARGIN, ai->xai_Password ? XPK_Password :
              TAG_IGNORE, ai->xai_Password, XPK_UseXfdMaster, 0,
              XPK_PassRequest, FALSE, TAG_DONE))))
              {
                xadFreeObjectA(mem2, 0); *str = 0; *size = 0;
              }
            }
          }
          else
            err = XADERR_ILLEGALDATA;
        }
        xadFreeObjectA(mem, 0);
      } /* xadAllocVec */
      else
        err = XADERR_NOMEMORY;
    } /* Hook Read */
    #ifdef __amigaos4__
    DropInterface((struct Interface *)IXpk);
    #endif
    CloseLibrary(XpkBase);
  } /* OpenLibrary */
  else
    err = XADERR_RESOURCE;

  return err;
}

#endif /* XADMASTER_XADXPK_C */
