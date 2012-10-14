#ifndef XADMASTER_FUNCTIONS_H
#define XADMASTER_FUNCTIONS_H

/*  $Id: functions.h.in,v 1.11 2005/06/23 14:54:42 stoecker Exp $
    declarations and prototypes

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

/* xadmaster.h is included without its public library prototypes, so we
 * can define them ourselves using xadMasterBaseP instead of xadMasterBase */
#define XAD_NO_PROTOTYPES 1
#include "xadmaster.h"

/* include all library-internal structures, including xadMasterBaseP */
#include "privdefs.h"

/************************************************************************
*                                                                       *
*    library accessable function                                        *
*                                                                       *
************************************************************************/

/*** BEGIN auto-generated section (INTERNAL VARARGS) */
#define PROTOHOOK(name) \
  xadINT32 name(struct Hook * hook, struct xadArchiveInfoP *ai, \
  struct xadHookParam * param)

#define FUNCHOOK(name) PROTOHOOK(name)

#define ENDFUNC

#ifdef HAVE_STDARG_H
#  include <stdarg.h>
#endif
#define XAD_MAX_CONVTAGS (64)
#define XAD_CONVTAGS \
  struct TagItem convtags[XAD_MAX_CONVTAGS]; \
  va_list ap; int x = 0; \
  va_start(ap, tag); \
  convtags[0].ti_Tag = tag; \
  while (tag != TAG_DONE) { \
    convtags[x++].ti_Data =  \
      ( (tag & TAG_PTR)  ? (xadSize)(uintptr_t)va_arg(ap, void *)  : \
	((tag & TAG_SIZ) ? va_arg(ap, xadSize) : \
	                   (xadSize)va_arg(ap, int))); \
    if (tag == TAG_MORE) break; \
    if (x >= XAD_MAX_CONVTAGS) { \
      convtags[XAD_MAX_CONVTAGS-1].ti_Tag = TAG_DONE; \
      break; \
    } \
    convtags[x].ti_Tag = tag = (xadTag) va_arg(ap, int); \
  } \
  va_end(ap);

xadERROR xadAddDiskEntry(struct xadMasterBaseP *xadMasterBase, struct xadDiskInfo *di, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadAddDiskEntryA(struct xadMasterBaseP *xadMasterBase, struct xadDiskInfo *di, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadAddDiskEntry \
  xadERROR xadAddDiskEntry( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadDiskInfo *di, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadAddDiskEntryA(xadMasterBase, di, ai, &convtags[0]); } \
  xadERROR xadAddDiskEntryA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadDiskInfo *di, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

xadERROR xadAddFileEntry(struct xadMasterBaseP *xadMasterBase, struct xadFileInfo *fi, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadAddFileEntryA(struct xadMasterBaseP *xadMasterBase, struct xadFileInfo *fi, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadAddFileEntry \
  xadERROR xadAddFileEntry( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadFileInfo *fi, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadAddFileEntryA(xadMasterBase, fi, ai, &convtags[0]); } \
  xadERROR xadAddFileEntryA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadFileInfo *fi, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

xadPTR xadAllocObject(struct xadMasterBaseP *xadMasterBase, xadUINT32 type, xadTag tag, ...);
xadPTR xadAllocObjectA(struct xadMasterBaseP *xadMasterBase, xadUINT32 type, xadTAGPTR tags);
#define FUNCxadAllocObject \
  xadPTR xadAllocObject( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 type, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadAllocObjectA(xadMasterBase, type, &convtags[0]); } \
  xadPTR xadAllocObjectA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 type, \
    xadTAGPTR tags)

xadPTR xadAllocVec(struct xadMasterBaseP *xadMasterBase, xadSize size, xadUINT32 flags);
#define FUNCxadAllocVec xadPTR xadAllocVec(struct xadMasterBaseP *xadMasterBase, xadSize size, xadUINT32 flags)
xadUINT16 xadCalcCRC16(struct xadMasterBaseP *xadMasterBase, xadUINT16 id, xadUINT16 init, xadSize size, const xadUINT8 *buffer);
#define FUNCxadCalcCRC16 xadUINT16 xadCalcCRC16(struct xadMasterBaseP *xadMasterBase, xadUINT16 id, xadUINT16 init, xadSize size, const xadUINT8 *buffer)
xadUINT32 xadCalcCRC32(struct xadMasterBaseP *xadMasterBase, xadUINT32 id, xadUINT32 init, xadSize size, const xadUINT8 *buffer);
#define FUNCxadCalcCRC32 xadUINT32 xadCalcCRC32(struct xadMasterBaseP *xadMasterBase, xadUINT32 id, xadUINT32 init, xadSize size, const xadUINT8 *buffer)
xadERROR xadConvertDates(struct xadMasterBaseP *xadMasterBase, xadTag tag, ...);
xadERROR xadConvertDatesA(struct xadMasterBaseP *xadMasterBase, xadTAGPTR tags);
#define FUNCxadConvertDates \
  xadERROR xadConvertDates( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadConvertDatesA(xadMasterBase, &convtags[0]); } \
  xadERROR xadConvertDatesA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTAGPTR tags)

xadSTRPTR xadConvertName(struct xadMasterBaseP *xadMasterBase, xadUINT32 charset, xadTag tag, ...);
xadSTRPTR xadConvertNameA(struct xadMasterBaseP *xadMasterBase, xadUINT32 charset, xadTAGPTR tags);
#define FUNCxadConvertName \
  xadSTRPTR xadConvertName( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 charset, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadConvertNameA(xadMasterBase, charset, &convtags[0]); } \
  xadSTRPTR xadConvertNameA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 charset, \
    xadTAGPTR tags)

xadERROR xadConvertProtection(struct xadMasterBaseP *xadMasterBase, xadTag tag, ...);
xadERROR xadConvertProtectionA(struct xadMasterBaseP *xadMasterBase, xadTAGPTR tags);
#define FUNCxadConvertProtection \
  xadERROR xadConvertProtection( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadConvertProtectionA(xadMasterBase, &convtags[0]); } \
  xadERROR xadConvertProtectionA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTAGPTR tags)

void xadCopyMem(struct xadMasterBaseP *xadMasterBase, const void *s, xadPTR d, xadSize size);
#define FUNCxadCopyMem void xadCopyMem(struct xadMasterBaseP *xadMasterBase, const void *s, xadPTR d, xadSize size)
xadERROR xadDiskUnArc(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadDiskUnArcA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadDiskUnArc \
  xadERROR xadDiskUnArc( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadDiskUnArcA(xadMasterBase, ai, &convtags[0]); } \
  xadERROR xadDiskUnArcA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

xadERROR xadFileUnArc(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadFileUnArcA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadFileUnArc \
  xadERROR xadFileUnArc( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadFileUnArcA(xadMasterBase, ai, &convtags[0]); } \
  xadERROR xadFileUnArcA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

void xadFreeHookAccess(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
void xadFreeHookAccessA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadFreeHookAccess \
  void xadFreeHookAccess( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS   xadFreeHookAccessA(xadMasterBase, ai, &convtags[0]); } \
  void xadFreeHookAccessA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

void xadFreeInfo(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai);
#define FUNCxadFreeInfo void xadFreeInfo(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai)
void xadFreeObject(struct xadMasterBaseP *xadMasterBase, xadPTR object, xadTag tag, ...);
void xadFreeObjectA(struct xadMasterBaseP *xadMasterBase, xadPTR object, xadTAGPTR tags);
#define FUNCxadFreeObject \
  void xadFreeObject( \
    struct xadMasterBaseP *xadMasterBase, \
    xadPTR object, \
    xadTag tag, ...) \
  { XAD_CONVTAGS   xadFreeObjectA(xadMasterBase, object, &convtags[0]); } \
  void xadFreeObjectA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadPTR object, \
    xadTAGPTR tags)

struct xadClient * xadGetClientInfo(struct xadMasterBaseP *xadMasterBase);
#define FUNCxadGetClientInfo struct xadClient * xadGetClientInfo(struct xadMasterBaseP *xadMasterBase)
xadSTRPTR xadGetDefaultName(struct xadMasterBaseP *xadMasterBase, xadTag tag, ...);
xadSTRPTR xadGetDefaultNameA(struct xadMasterBaseP *xadMasterBase, xadTAGPTR tags);
#define FUNCxadGetDefaultName \
  xadSTRPTR xadGetDefaultName( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadGetDefaultNameA(xadMasterBase, &convtags[0]); } \
  xadSTRPTR xadGetDefaultNameA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadTAGPTR tags)

xadERROR xadGetDiskInfo(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadGetDiskInfoA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadGetDiskInfo \
  xadERROR xadGetDiskInfo( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadGetDiskInfoA(xadMasterBase, ai, &convtags[0]); } \
  xadERROR xadGetDiskInfoA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

xadSTRPTR xadGetErrorText(struct xadMasterBaseP *xadMasterBase, xadERROR errnum);
#define FUNCxadGetErrorText xadSTRPTR xadGetErrorText(struct xadMasterBaseP *xadMasterBase, xadERROR errnum)
xadERROR xadGetFilename(struct xadMasterBaseP *xadMasterBase, xadUINT32 buffersize, xadSTRPTR buffer, const xadSTRING *path, const xadSTRING *name, xadTag tag, ...);
xadERROR xadGetFilenameA(struct xadMasterBaseP *xadMasterBase, xadUINT32 buffersize, xadSTRPTR buffer, const xadSTRING *path, const xadSTRING *name, xadTAGPTR tags);
#define FUNCxadGetFilename \
  xadERROR xadGetFilename( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 buffersize, \
    xadSTRPTR buffer, \
    const xadSTRING *path, \
    const xadSTRING *name, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadGetFilenameA(xadMasterBase, buffersize, buffer, path, name, &convtags[0]); } \
  xadERROR xadGetFilenameA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 buffersize, \
    xadSTRPTR buffer, \
    const xadSTRING *path, \
    const xadSTRING *name, \
    xadTAGPTR tags)

xadERROR xadGetInfo(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadGetInfoA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadGetInfo \
  xadERROR xadGetInfo( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadGetInfoA(xadMasterBase, ai, &convtags[0]); } \
  xadERROR xadGetInfoA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

xadERROR xadGetHookAccess(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadGetHookAccessA(struct xadMasterBaseP *xadMasterBase, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadGetHookAccess \
  xadERROR xadGetHookAccess( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadGetHookAccessA(xadMasterBase, ai, &convtags[0]); } \
  xadERROR xadGetHookAccessA( \
    struct xadMasterBaseP *xadMasterBase, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

struct xadSystemInfo * xadGetSystemInfo(struct xadMasterBaseP *xadMasterBase);
#define FUNCxadGetSystemInfo struct xadSystemInfo * xadGetSystemInfo(struct xadMasterBaseP *xadMasterBase)
xadERROR xadHookAccess(struct xadMasterBaseP *xadMasterBase, xadUINT32 command, xadSignSize data, xadPTR buffer, struct xadArchiveInfoP *ai);
#define FUNCxadHookAccess xadERROR xadHookAccess(struct xadMasterBaseP *xadMasterBase, xadUINT32 command, xadSignSize data, xadPTR buffer, struct xadArchiveInfoP *ai)
xadERROR xadHookTagAccess(struct xadMasterBaseP *xadMasterBase, xadUINT32 command, xadSignSize data, xadPTR buffer, struct xadArchiveInfoP *ai, xadTag tag, ...);
xadERROR xadHookTagAccessA(struct xadMasterBaseP *xadMasterBase, xadUINT32 command, xadSignSize data, xadPTR buffer, struct xadArchiveInfoP *ai, xadTAGPTR tags);
#define FUNCxadHookTagAccess \
  xadERROR xadHookTagAccess( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 command, \
    xadSignSize data, \
    xadPTR buffer, \
    struct xadArchiveInfoP *ai, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadHookTagAccessA(xadMasterBase, command, data, buffer, ai, &convtags[0]); } \
  xadERROR xadHookTagAccessA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadUINT32 command, \
    xadSignSize data, \
    xadPTR buffer, \
    struct xadArchiveInfoP *ai, \
    xadTAGPTR tags)

struct xadClient * xadRecogFile(struct xadMasterBaseP *xadMasterBase, xadSize size, const void *mem, xadTag tag, ...);
struct xadClient * xadRecogFileA(struct xadMasterBaseP *xadMasterBase, xadSize size, const void *mem, xadTAGPTR tags);
#define FUNCxadRecogFile \
  struct xadClient * xadRecogFile( \
    struct xadMasterBaseP *xadMasterBase, \
    xadSize size, \
    const void *mem, \
    xadTag tag, ...) \
  { XAD_CONVTAGS  return  xadRecogFileA(xadMasterBase, size, mem, &convtags[0]); } \
  struct xadClient * xadRecogFileA( \
    struct xadMasterBaseP *xadMasterBase, \
    xadSize size, \
    const void *mem, \
    xadTAGPTR tags)

/*** END auto-generated section */

PROTOHOOK(InHookFH);       /* hook_fh.c */
PROTOHOOK(OutHookFH);      /* hook_fh.c */
PROTOHOOK(InHookMem);      /* hook_mem.c */
PROTOHOOK(OutHookMem);     /* hook_mem.c */
PROTOHOOK(InHookStream);   /* hook_stream.c */
PROTOHOOK(OutHookStream);  /* hook_stream.c */
PROTOHOOK(InHookDisk);     /* hook_disk.c */
PROTOHOOK(OutHookDisk);    /* hook_disk.c */
PROTOHOOK(InHookSplitted); /* hook_splitted.c */
PROTOHOOK(InHookDiskArc);  /* hook_diskarc.c */

/* clientfunc.c */
xadUINT32 callprogress(
                const struct xadArchiveInfoP *ai,
                xadUINT32 stat, xadUINT32 mode,
                struct xadMasterBaseP *xadMasterBase);

xadUINT32 callprogressFN(
                const struct xadArchiveInfoP *ai,
                xadUINT32 stat, xadUINT32 mode, xadSTRPTR *filename,
                struct xadMasterBaseP *xadMasterBase);

xadSignSize getskipsize(
                xadSignSize data,
                const struct xadArchiveInfoP *ai);

xadBOOL xadAddClients(struct xadMasterBaseP *xadMasterBase,
                      const struct xadClient *clients,
                      xadUINT32 add_flags);

void xadFreeClients(struct xadMasterBaseP *xadMasterBase);

void MakeCRC16(xadUINT16 *buf, xadUINT16 ID);
void MakeCRC32(xadUINT32 *buf, xadUINT32 ID);

extern const struct xadClient * const RealFirstClient;

#ifdef DEBUG
void DebugFlagged(xadUINT32 flags, const xadSTRING *fmt, ...);

void DebugTagList(const xadSTRING *, xadTAGPTR, ...);           /* print with 'R' and tags with 'T' */
void DebugTagListOther(const xadSTRING *, xadTAGPTR, ...);      /* print with 'O' and tags with 'T' */
void DebugTagListMem(const xadSTRING *, xadTAGPTR, ...);        /* print with 'R' or 'M' and tags with 'T' */
void DebugError(const xadSTRING *, ...);                        /* print with 'E' */
void DebugHook(const xadSTRING *, ...);                         /* print with 'H' */
void DebugHookTagList(const xadSTRING *, xadTAGPTR, ...);       /* print with 'H' and tags with 'T' */
void DebugRunTime(const xadSTRING *, ...);                      /* print with 'R' */
void DebugOther(const xadSTRING *, ...);                        /* print with 'O' */
void DebugMem(const xadSTRING *, ...);                          /* print with 'M' */
void DebugMemError(const xadSTRING *, ...);                     /* print with 'M' or 'E' */
void DebugFileSearched(const struct xadArchiveInfo *ai, const xadSTRING *, ...); /* print with 'D' */
void DebugClient(const struct xadArchiveInfo *ai, const xadSTRING *, ...);       /* print with 'D' */
#endif
#ifdef DEBUGRESOURCE
#define XADOBJCOOKIE 0x58414494
void DebugResource(struct xadMasterBaseP *, const xadSTRING *, ...);       /* print with 'C' */
/* called with 0 does end result check for this task */
/* called with 1 does end result check for all tasks */
#endif
#if defined(DEBUG) || defined(DEBUGRESOURCE)
#define DEBUGFLAG_ERROR         (1<<0)
#define DEBUGFLAG_RUNTIME       (1<<1)
#define DEBUGFLAG_TAGLIST       (1<<2)
#define DEBUGFLAG_HOOK          (1<<3)
#define DEBUGFLAG_OTHER         (1<<4)
#define DEBUGFLAG_MEM           (1<<5)
#define DEBUGFLAG_FLAGS         (1<<6)
#define DEBUGFLAG_RESOURCE      (1<<7)
#define DEBUGFLAG_CLIENT        (1<<8)
#define DEBUGFLAG_SEARCHED      (1<<9)
#define DEBUGFLAG_STATIC        (1<<10)
#define DEBUGFLAG_CONTINUESTART (1<<11)
#define DEBUGFLAG_CONTINUE      (1<<12)
#define DEBUGFLAG_CONTINUEEND   (1<<13)


xadSTRPTR xadGetObjectTypeName(xadUINT32 type); /* objects.c */
#endif

#endif /* XADMASTER_FUNCTIONS_H */
