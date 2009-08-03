#ifndef STUBS_H
#define STUBS_H 1

#ifdef NO_INLINE_STDARG

#include <proto/xpkmaster.h>

LONG _xpkExamineTags (APTR,struct XpkFib *,Tag,...);
#undef XpkExamineTags
#define XpkExamineTags(fib,tag...) _xpkExamineTags(XpkBase,fib,tag)

LONG _xpkUnpackTags(APTR,ULONG,...);
#undef XpkUnpackTags
#define XpkUnpackTags(tag...) _xpkUnpackTags(XpkBase,tag)

#include <proto/xadmaster.h>

xadERROR _xadAddDiskEntry(APTR,struct xadDiskInfo *,struct xadArchiveInfo *,xadTag,...);
#undef xadAddDiskEntry
#define xadAddDiskEntry(di,ai,tag...) _xadAddDiskEntry(xadMasterBase,di,ai,tag)

xadERROR _xadAddFileEntry(APTR,struct xadFileInfo *,struct xadArchiveInfo *,xadTag,...);
#undef xadAddFileEntry
#define xadAddFileEntry(fi,ai,tag...) _xadAddFileEntry(xadMasterBase,fi,ai,tag)

xadPTR _xadAllocObject(APTR,xadUINT32,xadTag,...);
#undef xadAllocObject
#define xadAllocObject(type,tag...) _xadAllocObject(xadMasterBase,type,tag)

xadERROR _xadConvertDates(APTR,xadTag,...);
#undef xadConvertDates
#define xadConvertDates(tag...) _xadConvertDates(xadMasterBase,tag)

xadSTRPTR _xadConvertName(APTR,xadUINT32,xadTag,...);
#undef xadConvertName
#define xadConvertName(charset,tag...) _xadConvertName(xadMasterBase,charset,tag)

xadERROR _xadConvertProtection(APTR,xadTag,...);
#undef xadConvertProtection
#define xadConvertProtection(tag...) _xadConvertProtection(xadMasterBase,tag)

xadERROR _xadDiskUnArc(APTR,struct xadArchiveInfo *,xadTag,...);
#undef xadDiskUnArc
#define xadDiskUnArc(ai,tag...) _xadDiskUnArc(xadMasterBase,ai,tag)

void _xadFreeHookAccess(APTR,struct xadArchiveInfo *,xadTag,...);
#undef xadFreeHookAccess
#define xadFreeHookAccess(ai,tag...) _xadFreeHookAccess(xadMasterBase,ai,tag)

xadSTRPTR _xadGetDefaultName(APTR,xadTag,...);
#undef xadGetDefaultName
#define xadGetDefaultName(tag...) _xadGetDefaultName(xadMasterBase,tag)

xadERROR _xadHookTagAccess(APTR,xadUINT32,xadSignSize,xadPTR,struct xadArchiveInfo *,xadTag,...);
#undef xadHookTagAccess
#define xadHookTagAccess(command,data,buffer,ai,tag...) _xadHookTagAccess(xadMasterBase,command,data,buffer,ai,tag)

#ifdef DEBUG

#include <proto/dos.h>

LONG _Printf(APTR,CONST_STRPTR,...);
#undef Printf
#define Printf(fmt...) _Printf(DOSBase,fmt)

#endif /* DEBUG */

#endif /* NO_INLINE_STDARG */

#endif /* STUBS_H */
