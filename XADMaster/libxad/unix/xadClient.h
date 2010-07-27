#ifndef XADMASTER_XADCLIENT_H
#define XADMASTER_XADCLIENT_H

/*  $Id: xadClient.h,v 1.16 2005/06/23 14:54:43 stoecker Exp $
    UNIX part of client interface to get portable clients

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

/* we want xad's external prototypes for clients */
#include "../include/xadmaster.h"

#include <ctype.h>
#include <string.h>
#include "../include/ConvertE.c"

#define XADRECOGDATA(name) static xadBOOL name##_RecogData( \
          xadSize size, \
          const xadUINT8 *data, \
          struct xadMasterBase *xadMasterBase)

#define XADGETINFO(name)   static xadERROR name##_GetInfo( \
          struct xadArchiveInfo *ai, \
          struct xadMasterBase *xadMasterBase)

#define XADUNARCHIVE(name) static xadERROR name##_UnArchive( \
          struct xadArchiveInfo *ai, \
          struct xadMasterBase *xadMasterBase)

#define XADFREE(name)      static void name##_Free( \
          struct xadArchiveInfo *ai, \
          struct xadMasterBase *xadMasterBase)

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
  const xadSTRING *xad_GetClientVersion() { return text; }              \
  extern const struct xadClient FirstClient;                            \
  const struct xadClient *xad_GetClient() { return &FirstClient; }
#endif

#define XADCLIENT(name)         static const struct xadClient name##_Client =
#define XADNEXTCLIENT           0

#define XADNEXTCLIENTNAME(name) (struct xadClient *) &name##_Client

#endif /* XADMASTER_XADCLIENT_H */
