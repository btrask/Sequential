#ifndef _INLINE_XADMASTER_H
#define _INLINE_XADMASTER_H

#ifndef CLIB_XADMASTER_PROTOS_H
#define CLIB_XADMASTER_PROTOS_H
#endif

#ifndef __INLINE_MACROS_H
#include <inline/macros.h>
#endif

#ifndef  UTILITY_TAGITEM_H
#include <utility/tagitem.h>
#endif
#ifndef  LIBRARIES_XADMASTER_H
#include <libraries/xadmaster.h>
#endif

#ifndef XADMASTER_BASE_NAME
#define XADMASTER_BASE_NAME xadMasterBase
#endif

#define xadAllocObjectA(type, tags) \
	LP2(0x1e, xadPTR, xadAllocObjectA, xadUINT32, type, d0, const struct TagItem *, tags, a0, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadAllocObject(type, tags...) \
	({ULONG _tags[] = {tags}; xadAllocObjectA((type), (const struct TagItem *) _tags);})
#endif

#define xadFreeObjectA(object, tags) \
	LP2NR(0x24, xadFreeObjectA, xadPTR, object, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadFreeObject(object, tags...) \
	({ULONG _tags[] = {tags}; xadFreeObjectA((object), (const struct TagItem *) _tags);})
#endif

#define xadRecogFileA(size, memory, tags) \
	LP3(0x2a, struct xadClient *, xadRecogFileA, xadSize, size, d0, const void *, memory, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadRecogFile(size, memory, tags...) \
	({ULONG _tags[] = {tags}; xadRecogFileA((size), (memory), (const struct TagItem *) _tags);})
#endif

#define xadGetInfoA(ai, tags) \
	LP2(0x30, xadERROR, xadGetInfoA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadGetInfo(ai, tags...) \
	({ULONG _tags[] = {tags}; xadGetInfoA((ai), (const struct TagItem *) _tags);})
#endif

#define xadFreeInfo(ai) \
	LP1NR(0x36, xadFreeInfo, struct xadArchiveInfo *, ai, a0, \
	, XADMASTER_BASE_NAME)

#define xadFileUnArcA(ai, tags) \
	LP2(0x3c, xadERROR, xadFileUnArcA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadFileUnArc(ai, tags...) \
	({ULONG _tags[] = {tags}; xadFileUnArcA((ai), (const struct TagItem *) _tags);})
#endif

#define xadDiskUnArcA(ai, tags) \
	LP2(0x42, xadERROR, xadDiskUnArcA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadDiskUnArc(ai, tags...) \
	({ULONG _tags[] = {tags}; xadDiskUnArcA((ai), (const struct TagItem *) _tags);})
#endif

#define xadGetErrorText(errnum) \
	LP1(0x48, xadSTRPTR, xadGetErrorText, xadERROR, errnum, d0, \
	, XADMASTER_BASE_NAME)

#define xadGetClientInfo() \
	LP0(0x4e, struct xadClient *, xadGetClientInfo, \
	, XADMASTER_BASE_NAME)

#define xadHookAccess(command, data, buffer, ai) \
	LP4(0x54, xadERROR, xadHookAccess, xadUINT32, command, d0, xadSignSize, data, d1, xadPTR, buffer, a0, struct xadArchiveInfo *, ai, a1, \
	, XADMASTER_BASE_NAME)

#define xadConvertDatesA(tags) \
	LP1(0x5a, xadERROR, xadConvertDatesA, const struct TagItem *, tags, a0, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadConvertDates(tags...) \
	({ULONG _tags[] = {tags}; xadConvertDatesA((const struct TagItem *) _tags);})
#endif

#define xadCalcCRC16(id, init, size, buffer) \
	LP4(0x60, xadUINT16, xadCalcCRC16, xadUINT32, id, d0, xadUINT32, init, d1, xadSize, size, d2, const xadUINT8 *, buffer, a0, \
	, XADMASTER_BASE_NAME)

#define xadCalcCRC32(id, init, size, buffer) \
	LP4(0x66, xadUINT32, xadCalcCRC32, xadUINT32, id, d0, xadUINT32, init, d1, xadSize, size, d2, const xadUINT8 *, buffer, a0, \
	, XADMASTER_BASE_NAME)

#define xadAllocVec(size, flags) \
	LP2(0x6c, xadPTR, xadAllocVec, xadSize, size, d0, xadUINT32, flags, d1, \
	, XADMASTER_BASE_NAME)

#define xadCopyMem(src, dest, size) \
	LP3NR(0x72, xadCopyMem, const void *, src, a0, xadPTR, dest, a1, xadSize, size, d0, \
	, XADMASTER_BASE_NAME)

#define xadHookTagAccessA(command, data, buffer, ai, tags) \
	LP5(0x78, xadERROR, xadHookTagAccessA, xadUINT32, command, d0, xadSignSize, data, d1, xadPTR, buffer, a0, struct xadArchiveInfo *, ai, a1, const struct TagItem *, tags, a2, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadHookTagAccess(command, data, buffer, ai, tags...) \
	({ULONG _tags[] = {tags}; xadHookTagAccessA((command), (data), (buffer), (ai), (const struct TagItem *) _tags);})
#endif

#define xadConvertProtectionA(tags) \
	LP1(0x7e, xadERROR, xadConvertProtectionA, const struct TagItem *, tags, a0, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadConvertProtection(tags...) \
	({ULONG _tags[] = {tags}; xadConvertProtectionA((const struct TagItem *) _tags);})
#endif

#define xadGetDiskInfoA(ai, tags) \
	LP2(0x84, xadERROR, xadGetDiskInfoA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadGetDiskInfo(ai, tags...) \
	({ULONG _tags[] = {tags}; xadGetDiskInfoA((ai), (const struct TagItem *) _tags);})
#endif

#define xadGetHookAccessA(ai, tags) \
	LP2(0x90, xadERROR, xadGetHookAccessA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadGetHookAccess(ai, tags...) \
	({ULONG _tags[] = {tags}; xadGetHookAccessA((ai), (const struct TagItem *) _tags);})
#endif

#define xadFreeHookAccessA(ai, tags) \
	LP2NR(0x96, xadFreeHookAccessA, struct xadArchiveInfo *, ai, a0, const struct TagItem *, tags, a1, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadFreeHookAccess(ai, tags...) \
	({ULONG _tags[] = {tags}; xadFreeHookAccessA((ai), (const struct TagItem *) _tags);})
#endif

#define xadAddFileEntryA(fi, ai, tags) \
	LP3(0x9c, xadERROR, xadAddFileEntryA, struct xadFileInfo *, fi, a0, struct xadArchiveInfo *, ai, a1, const struct TagItem *, tags, a2, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadAddFileEntry(fi, ai, tags...) \
	({ULONG _tags[] = {tags}; xadAddFileEntryA((fi), (ai), (const struct TagItem *) _tags);})
#endif

#define xadAddDiskEntryA(di, ai, tags) \
	LP3(0xa2, xadERROR, xadAddDiskEntryA, struct xadDiskInfo *, di, a0, struct xadArchiveInfo *, ai, a1, const struct TagItem *, tags, a2, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadAddDiskEntry(di, ai, tags...) \
	({ULONG _tags[] = {tags}; xadAddDiskEntryA((di), (ai), (const struct TagItem *) _tags);})
#endif

#define xadGetFilenameA(buffersize, buffer, path, name, tags) \
	LP5(0xa8, xadERROR, xadGetFilenameA, xadUINT32, buffersize, d0, xadSTRPTR, buffer, a0, const xadSTRING *, path, a1, const xadSTRING *, name, a2, const struct TagItem *, tags, a3, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadGetFilename(buffersize, buffer, path, name, tags...) \
	({ULONG _tags[] = {tags}; xadGetFilenameA((buffersize), (buffer), (path), (name), (const struct TagItem *) _tags);})
#endif

#define xadConvertNameA(charset, tags) \
	LP2(0xae, xadSTRPTR, xadConvertNameA, xadUINT32, charset, d0, const struct TagItem *, tags, a0, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadConvertName(charset, tags...) \
	({ULONG _tags[] = {tags}; xadConvertNameA((charset), (const struct TagItem *) _tags);})
#endif

#define xadGetDefaultNameA(tags) \
	LP1(0xb4, xadSTRPTR, xadGetDefaultNameA, const struct TagItem *, tags, a0, \
	, XADMASTER_BASE_NAME)

#ifndef NO_INLINE_STDARG
#define xadGetDefaultName(tags...) \
	({ULONG _tags[] = {tags}; xadGetDefaultNameA((const struct TagItem *) _tags);})
#endif

#define xadGetSystemInfo() \
	LP0(0xba, const struct xadSystemInfo *, xadGetSystemInfo, \
	, XADMASTER_BASE_NAME)

#endif /*  _INLINE_XADMASTER_H  */
