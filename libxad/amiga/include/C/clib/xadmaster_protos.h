#ifndef CLIB_XADMASTER_PROTOS_H
#define CLIB_XADMASTER_PROTOS_H


/*
**	$VER: xadmaster_protos.h 13.2 (03.07.2004)
**
**	C prototypes. For use with 32 bit integers only.
**
**	Copyright © 2004 Dirk Stöcker
**	All Rights Reserved
*/

#ifndef  UTILITY_TAGITEM_H
#include <utility/tagitem.h>
#endif
#ifndef  LIBRARIES_XADMASTER_H
#include <libraries/xadmaster.h>
#endif

xadPTR xadAllocObjectA(xadUINT32 type, const struct TagItem * tags);
xadPTR xadAllocObject(xadUINT32 type, Tag tags, ...);
void xadFreeObjectA(xadPTR object, const struct TagItem * tags);
void xadFreeObject(xadPTR object, Tag tags, ...);
struct xadClient * xadRecogFileA(xadSize size, const void * memory,
	const struct TagItem * tags);
struct xadClient * xadRecogFile(xadSize size, const void * memory, Tag tags, ...);
xadERROR xadGetInfoA(struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadGetInfo(struct xadArchiveInfo * ai, Tag tags, ...);
void xadFreeInfo(struct xadArchiveInfo * ai);
xadERROR xadFileUnArcA(struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadFileUnArc(struct xadArchiveInfo * ai, Tag tags, ...);
xadERROR xadDiskUnArcA(struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadDiskUnArc(struct xadArchiveInfo * ai, Tag tags, ...);
xadSTRPTR xadGetErrorText(xadERROR errnum);
struct xadClient * xadGetClientInfo(void);

/* This HookAccess function can be called from clients only! */

xadERROR xadHookAccess(xadUINT32 command, xadSignSize data, xadPTR buffer,
	struct xadArchiveInfo * ai);
xadERROR xadConvertDatesA(const struct TagItem * tags);
xadERROR xadConvertDates(Tag tags, ...);
xadUINT16 xadCalcCRC16(xadUINT32 id, xadUINT32 init, xadSize size,
	const xadUINT8 * buffer);
xadUINT32 xadCalcCRC32(xadUINT32 id, xadUINT32 init, xadSize size,
	const xadUINT8 * buffer);

/* --- functions in V2 or higher --- */

xadPTR xadAllocVec(xadSize size, xadUINT32 flags);
void xadCopyMem(const void * src, xadPTR dest, xadSize size);

/* --- functions in V3 or higher --- */

xadERROR xadHookTagAccessA(xadUINT32 command, xadSignSize data, xadPTR buffer,
	struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadHookTagAccess(xadUINT32 command, xadSignSize data, xadPTR buffer,
	struct xadArchiveInfo * ai, Tag tags, ...);

/* --- functions in V4 or higher --- */

xadERROR xadConvertProtectionA(const struct TagItem * tags);
xadERROR xadConvertProtection(Tag tags, ...);
xadERROR xadGetDiskInfoA(struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadGetDiskInfo(struct xadArchiveInfo * ai, Tag tags, ...);

/* --- functions in V8 or higher --- */

xadERROR xadGetHookAccessA(struct xadArchiveInfo * ai, const struct TagItem * tags);
xadERROR xadGetHookAccess(struct xadArchiveInfo * ai, Tag tags, ...);
void xadFreeHookAccessA(struct xadArchiveInfo * ai, const struct TagItem * tags);
void xadFreeHookAccess(struct xadArchiveInfo * ai, Tag tags, ...);

/* --- functions in V10 or higher --- */

xadERROR xadAddFileEntryA(struct xadFileInfo * fi, struct xadArchiveInfo * ai,
	const struct TagItem * tags);
xadERROR xadAddFileEntry(struct xadFileInfo * fi, struct xadArchiveInfo * ai, Tag tags, ...);
xadERROR xadAddDiskEntryA(struct xadDiskInfo * di, struct xadArchiveInfo * ai,
	const struct TagItem * tags);
xadERROR xadAddDiskEntry(struct xadDiskInfo * di, struct xadArchiveInfo * ai, Tag tags, ...);

/* --- functions in V12 or higher --- */

xadERROR xadGetFilenameA(xadUINT32 buffersize, xadSTRPTR buffer, const xadSTRING * path,
	const xadSTRING * name, const struct TagItem * tags);
xadERROR xadGetFilename(xadUINT32 buffersize, xadSTRPTR buffer, const xadSTRING * path,
	const xadSTRING * name, Tag tags, ...);
xadSTRPTR xadConvertNameA(xadUINT32 charset, const struct TagItem * tags);
xadSTRPTR xadConvertName(xadUINT32 charset, Tag tags, ...);

/* --- functions in V13 or higher --- */

xadSTRPTR xadGetDefaultNameA(const struct TagItem * tags);
xadSTRPTR xadGetDefaultName(Tag tags, ...);
const struct xadSystemInfo * xadGetSystemInfo(void);

#endif	/*  CLIB_XADMASTER_PROTOS_H  */
