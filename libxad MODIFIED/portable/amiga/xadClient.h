#ifndef XADMASTER_XADCLIENT_H
#define XADMASTER_XADCLIENT_H

/*  $Id: xadClient.h,v 1.9 2005/06/23 14:54:40 stoecker Exp $
    Amiga part of client interface to get portable clients

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

#include <exec/execbase.h>
#include <proto/xadmaster.h>
#include "SDI_compiler.h"
#include "ConvertE.c"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"
#ifdef NO_INLINE_STDARG
#include "stubs.h"
#endif

#ifdef XADMASTERFILE
#else
/* The defines _M680x0 are done automatically by SAS-C. Do them in makefile
for other compilers. */
#ifdef _M68060
  #define CPUCHECK      if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68060)) return 0;
  #define CPUCHECKGI    if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68060)) return XADERR_FILESYSTEM;
  #define CPUTEXT       " 060"
#elif defined (_M68040)
  #define CPUCHECK      if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68040)) return 0;
  #define CPUCHECKGI    if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68040)) return XADERR_FILESYSTEM;
  #define CPUTEXT       " 040"
#elif defined (_M68030)
  #define CPUCHECK      if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68030)) return 0;
  #define CPUCHECKGI    if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68030)) return XADERR_FILESYSTEM;
  #define CPUTEXT       " 030"
#elif defined (_M68020)
  #define CPUCHECK      if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68020)) return 0;
  #define CPUCHECKGI    if(!(xadMasterBase->xmb_SysBase->AttnFlags & AFF_68020)) return XADERR_FILESYSTEM;
  #define CPUTEXT       " 020"
#else
  #define CPUTEXT
#endif
#endif

/* The macro CPUCHECK is used in xcRecogData() as first command. A inline
function is used to encapsulate the real function.
For filesystem clients CPUCKECKGI is used in xc_GetInfo().

These macros are security macros only. It is still not very clever to install
wrong CPU version, but if this macro is used, the computer does not crash,
but this client is skipped always.

The string CPUTEXT is used in version string after date.
*/

#if !defined(XADMASTERFILE) && defined(CPUCHECK)
#define XADRECOGDATA(name) INLINE xadBOOL _name##_RecogData( xadSize size, \
          const xadUINT8 *data, struct xadMasterBase *xadMasterBase); \
          static ASM(xadBOOL) name##_RecogData( \
          REG(d0, xadSize size), \
          REG(a0, const xadUINT8 *data), \
          REG(a6, struct xadMasterBase *xadMasterBase)) \
          { CPUCHECK return _name##_RecogData(size,data,xadMasterBase); } \
          INLINE xadBOOL _name##_RecogData( xadSize size, \
          xadUINT8 *data, struct xadMasterBase *xadMasterBase)
#else
#define XADRECOGDATA(name) static ASM(xadBOOL) name##_RecogData( \
          REG(d0, xadSize size), \
          REG(a0, const xadUINT8 *data), \
          REG(a6, struct xadMasterBase *xadMasterBase))
#endif

#if !defined(XADMASTERFILE) && defined(CPUCHECKGI)
#define XADGETINFO(name) INLINE xadERROR _name##_GetInfo( \
          struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase); \
          static ASM(xadERROR) name##_GetInfo( \
          REG(a0, struct xadArchiveInfo *ai), \
          REG(a6, struct xadMasterBase *xadMasterBase)) \
          { CPUCHECKGI return _name##_GetInfo(ai,xadMasterBase); } \
          INLINE xadERROR _name##_GetInfo( \
          struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
#else
#define XADGETINFO(name)   static ASM(xadERROR) name##_GetInfo( \
          REG(a0, struct xadArchiveInfo *ai), \
          REG(a6, struct xadMasterBase *xadMasterBase))
#endif

#define XADUNARCHIVE(name) static ASM(xadERROR) name##_UnArchive( \
          REG(a0, struct xadArchiveInfo *ai), \
          REG(a6, struct xadMasterBase *xadMasterBase))

#define XADFREE(name)      static ASM(void) name##_Free( \
          REG(a0, struct xadArchiveInfo *ai), \
          REG(a6, struct xadMasterBase *xadMasterBase))

#define XADRECOGDATAP(name) (xadBOOL (*)()) name##_RecogData

#define XADGETINFOP(name)   (xadERROR (*)()) name##_GetInfo

#define XADUNARCHIVEP(name) (xadERROR (*)()) name##_UnArchive

#define XADFREEP(name)      (void (*)()) name##_Free

#ifdef XADMASTERFILE
  #define XADFIRSTCLIENT(name)  static const struct xadClient name##_Client =
  #define XADCLIENTVERSTR(text)
#else
  #define XADFIRSTCLIENT(name)  const struct xadClient FirstClient =
  #define XADCLIENTVERSTR(text)                                         \
  const xadSTRING version[] = "$VER: " text CPUTEXT;
#endif

#define XADCLIENT(name)         static const struct xadClient name##_Client =
#define XADNEXTCLIENT           0

#define XADNEXTCLIENTNAME(name) (struct xadClient *) &name##_Client

#endif /* XADMASTER_XADCLIENT_H */
