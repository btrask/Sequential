#ifndef _VBCCINLINE_XADMASTER_H
#define _VBCCINLINE_XADMASTER_H

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif

xadPTR __xadAllocObjectA(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 type, __reg("a0") const struct TagItem * tags)="\tjsr\t-30(a6)";
#define xadAllocObjectA(type, tags) __xadAllocObjectA(xadMasterBase, (type), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadPTR __xadAllocObject(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 type, Tag tags, ...)="\tmove.l\ta0,-(a7)\n\tlea\t4(a7),a0\n\tjsr\t-30(a6)\n\tmovea.l\t(a7)+,a0";
#define xadAllocObject(type, ...) __xadAllocObject(xadMasterBase, (type), __VA_ARGS__)
#endif

void __xadFreeObjectA(__reg("a6") struct xadMasterBase *, __reg("a0") xadPTR object, __reg("a1") const struct TagItem * tags)="\tjsr\t-36(a6)";
#define xadFreeObjectA(object, tags) __xadFreeObjectA(xadMasterBase, (object), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
void __xadFreeObject(__reg("a6") struct xadMasterBase *, __reg("a0") xadPTR object, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-36(a6)\n\tmovea.l\t(a7)+,a1";
#define xadFreeObject(object, ...) __xadFreeObject(xadMasterBase, (object), __VA_ARGS__)
#endif

struct xadClient * __xadRecogFileA(__reg("a6") struct xadMasterBase *, __reg("d0") xadSize size, __reg("a0") const void * memory, __reg("a1") const struct TagItem * tags)="\tjsr\t-42(a6)";
#define xadRecogFileA(size, memory, tags) __xadRecogFileA(xadMasterBase, (size), (memory), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
struct xadClient * __xadRecogFile(__reg("a6") struct xadMasterBase *, __reg("d0") xadSize size, __reg("a0") const void * memory, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-42(a6)\n\tmovea.l\t(a7)+,a1";
#define xadRecogFile(size, memory, ...) __xadRecogFile(xadMasterBase, (size), (memory), __VA_ARGS__)
#endif

xadERROR __xadGetInfoA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-48(a6)";
#define xadGetInfoA(ai, tags) __xadGetInfoA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadGetInfo(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-48(a6)\n\tmovea.l\t(a7)+,a1";
#define xadGetInfo(ai, ...) __xadGetInfo(xadMasterBase, (ai), __VA_ARGS__)
#endif

void __xadFreeInfo(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai)="\tjsr\t-54(a6)";
#define xadFreeInfo(ai) __xadFreeInfo(xadMasterBase, (ai))

xadERROR __xadFileUnArcA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-60(a6)";
#define xadFileUnArcA(ai, tags) __xadFileUnArcA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadFileUnArc(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-60(a6)\n\tmovea.l\t(a7)+,a1";
#define xadFileUnArc(ai, ...) __xadFileUnArc(xadMasterBase, (ai), __VA_ARGS__)
#endif

xadERROR __xadDiskUnArcA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-66(a6)";
#define xadDiskUnArcA(ai, tags) __xadDiskUnArcA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadDiskUnArc(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-66(a6)\n\tmovea.l\t(a7)+,a1";
#define xadDiskUnArc(ai, ...) __xadDiskUnArc(xadMasterBase, (ai), __VA_ARGS__)
#endif

xadSTRPTR __xadGetErrorText(__reg("a6") struct xadMasterBase *, __reg("d0") xadERROR errnum)="\tjsr\t-72(a6)";
#define xadGetErrorText(errnum) __xadGetErrorText(xadMasterBase, (errnum))

struct xadClient * __xadGetClientInfo(__reg("a6") struct xadMasterBase *)="\tjsr\t-78(a6)";
#define xadGetClientInfo() __xadGetClientInfo(xadMasterBase)

xadERROR __xadHookAccess(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 command, __reg("d1") xadSignSize data, __reg("a0") xadPTR buffer, __reg("a1") struct xadArchiveInfo * ai)="\tjsr\t-84(a6)";
#define xadHookAccess(command, data, buffer, ai) __xadHookAccess(xadMasterBase, (command), (data), (buffer), (ai))

xadERROR __xadConvertDatesA(__reg("a6") struct xadMasterBase *, __reg("a0") const struct TagItem * tags)="\tjsr\t-90(a6)";
#define xadConvertDatesA(tags) __xadConvertDatesA(xadMasterBase, (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadConvertDates(__reg("a6") struct xadMasterBase *, Tag tags, ...)="\tmove.l\ta0,-(a7)\n\tlea\t4(a7),a0\n\tjsr\t-90(a6)\n\tmovea.l\t(a7)+,a0";
#define xadConvertDates(...) __xadConvertDates(xadMasterBase, __VA_ARGS__)
#endif

xadUINT16 __xadCalcCRC16(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 id, __reg("d1") xadUINT32 init, __reg("d2") xadSize size, __reg("a0") const xadUINT8 * buffer)="\tjsr\t-96(a6)";
#define xadCalcCRC16(id, init, size, buffer) __xadCalcCRC16(xadMasterBase, (id), (init), (size), (buffer))

xadUINT32 __xadCalcCRC32(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 id, __reg("d1") xadUINT32 init, __reg("d2") xadSize size, __reg("a0") const xadUINT8 * buffer)="\tjsr\t-102(a6)";
#define xadCalcCRC32(id, init, size, buffer) __xadCalcCRC32(xadMasterBase, (id), (init), (size), (buffer))

xadPTR __xadAllocVec(__reg("a6") struct xadMasterBase *, __reg("d0") xadSize size, __reg("d1") xadUINT32 flags)="\tjsr\t-108(a6)";
#define xadAllocVec(size, flags) __xadAllocVec(xadMasterBase, (size), (flags))

void __xadCopyMem(__reg("a6") struct xadMasterBase *, __reg("a0") const void * src, __reg("a1") xadPTR dest, __reg("d0") xadSize size)="\tjsr\t-114(a6)";
#define xadCopyMem(src, dest, size) __xadCopyMem(xadMasterBase, (src), (dest), (size))

xadERROR __xadHookTagAccessA(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 command, __reg("d1") xadSignSize data, __reg("a0") xadPTR buffer, __reg("a1") struct xadArchiveInfo * ai, __reg("a2") const struct TagItem * tags)="\tjsr\t-120(a6)";
#define xadHookTagAccessA(command, data, buffer, ai, tags) __xadHookTagAccessA(xadMasterBase, (command), (data), (buffer), (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadHookTagAccess(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 command, __reg("d1") xadSignSize data, __reg("a0") xadPTR buffer, __reg("a1") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta2,-(a7)\n\tlea\t4(a7),a2\n\tjsr\t-120(a6)\n\tmovea.l\t(a7)+,a2";
#define xadHookTagAccess(command, data, buffer, ai, ...) __xadHookTagAccess(xadMasterBase, (command), (data), (buffer), (ai), __VA_ARGS__)
#endif

xadERROR __xadConvertProtectionA(__reg("a6") struct xadMasterBase *, __reg("a0") const struct TagItem * tags)="\tjsr\t-126(a6)";
#define xadConvertProtectionA(tags) __xadConvertProtectionA(xadMasterBase, (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadConvertProtection(__reg("a6") struct xadMasterBase *, Tag tags, ...)="\tmove.l\ta0,-(a7)\n\tlea\t4(a7),a0\n\tjsr\t-126(a6)\n\tmovea.l\t(a7)+,a0";
#define xadConvertProtection(...) __xadConvertProtection(xadMasterBase, __VA_ARGS__)
#endif

xadERROR __xadGetDiskInfoA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-132(a6)";
#define xadGetDiskInfoA(ai, tags) __xadGetDiskInfoA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadGetDiskInfo(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-132(a6)\n\tmovea.l\t(a7)+,a1";
#define xadGetDiskInfo(ai, ...) __xadGetDiskInfo(xadMasterBase, (ai), __VA_ARGS__)
#endif

xadERROR __xadGetHookAccessA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-144(a6)";
#define xadGetHookAccessA(ai, tags) __xadGetHookAccessA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadGetHookAccess(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-144(a6)\n\tmovea.l\t(a7)+,a1";
#define xadGetHookAccess(ai, ...) __xadGetHookAccess(xadMasterBase, (ai), __VA_ARGS__)
#endif

void __xadFreeHookAccessA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, __reg("a1") const struct TagItem * tags)="\tjsr\t-150(a6)";
#define xadFreeHookAccessA(ai, tags) __xadFreeHookAccessA(xadMasterBase, (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
void __xadFreeHookAccess(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta1,-(a7)\n\tlea\t4(a7),a1\n\tjsr\t-150(a6)\n\tmovea.l\t(a7)+,a1";
#define xadFreeHookAccess(ai, ...) __xadFreeHookAccess(xadMasterBase, (ai), __VA_ARGS__)
#endif

xadERROR __xadAddFileEntryA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadFileInfo * fi, __reg("a1") struct xadArchiveInfo * ai, __reg("a2") const struct TagItem * tags)="\tjsr\t-156(a6)";
#define xadAddFileEntryA(fi, ai, tags) __xadAddFileEntryA(xadMasterBase, (fi), (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadAddFileEntry(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadFileInfo * fi, __reg("a1") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta2,-(a7)\n\tlea\t4(a7),a2\n\tjsr\t-156(a6)\n\tmovea.l\t(a7)+,a2";
#define xadAddFileEntry(fi, ai, ...) __xadAddFileEntry(xadMasterBase, (fi), (ai), __VA_ARGS__)
#endif

xadERROR __xadAddDiskEntryA(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadDiskInfo * di, __reg("a1") struct xadArchiveInfo * ai, __reg("a2") const struct TagItem * tags)="\tjsr\t-162(a6)";
#define xadAddDiskEntryA(di, ai, tags) __xadAddDiskEntryA(xadMasterBase, (di), (ai), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadAddDiskEntry(__reg("a6") struct xadMasterBase *, __reg("a0") struct xadDiskInfo * di, __reg("a1") struct xadArchiveInfo * ai, Tag tags, ...)="\tmove.l\ta2,-(a7)\n\tlea\t4(a7),a2\n\tjsr\t-162(a6)\n\tmovea.l\t(a7)+,a2";
#define xadAddDiskEntry(di, ai, ...) __xadAddDiskEntry(xadMasterBase, (di), (ai), __VA_ARGS__)
#endif

xadERROR __xadGetFilenameA(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 buffersize, __reg("a0") xadSTRPTR buffer, __reg("a1") const xadSTRING * path, __reg("a2") const xadSTRING * name, __reg("a3") const struct TagItem * tags)="\tjsr\t-168(a6)";
#define xadGetFilenameA(buffersize, buffer, path, name, tags) __xadGetFilenameA(xadMasterBase, (buffersize), (buffer), (path), (name), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadERROR __xadGetFilename(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 buffersize, __reg("a0") xadSTRPTR buffer, __reg("a1") const xadSTRING * path, __reg("a2") const xadSTRING * name, Tag tags, ...)="\tmove.l\ta3,-(a7)\n\tlea\t4(a7),a3\n\tjsr\t-168(a6)\n\tmovea.l\t(a7)+,a3";
#define xadGetFilename(buffersize, buffer, path, name, ...) __xadGetFilename(xadMasterBase, (buffersize), (buffer), (path), (name), __VA_ARGS__)
#endif

xadSTRPTR __xadConvertNameA(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 charset, __reg("a0") const struct TagItem * tags)="\tjsr\t-174(a6)";
#define xadConvertNameA(charset, tags) __xadConvertNameA(xadMasterBase, (charset), (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadSTRPTR __xadConvertName(__reg("a6") struct xadMasterBase *, __reg("d0") xadUINT32 charset, Tag tags, ...)="\tmove.l\ta0,-(a7)\n\tlea\t4(a7),a0\n\tjsr\t-174(a6)\n\tmovea.l\t(a7)+,a0";
#define xadConvertName(charset, ...) __xadConvertName(xadMasterBase, (charset), __VA_ARGS__)
#endif

xadSTRPTR __xadGetDefaultNameA(__reg("a6") struct xadMasterBase *, __reg("a0") const struct TagItem * tags)="\tjsr\t-180(a6)";
#define xadGetDefaultNameA(tags) __xadGetDefaultNameA(xadMasterBase, (tags))

#if !defined(NO_INLINE_STDARG) && (__STDC__ == 1L) && (__STDC_VERSION__ >= 199901L)
xadSTRPTR __xadGetDefaultName(__reg("a6") struct xadMasterBase *, Tag tags, ...)="\tmove.l\ta0,-(a7)\n\tlea\t4(a7),a0\n\tjsr\t-180(a6)\n\tmovea.l\t(a7)+,a0";
#define xadGetDefaultName(...) __xadGetDefaultName(xadMasterBase, __VA_ARGS__)
#endif

const struct xadSystemInfo * __xadGetSystemInfo(__reg("a6") struct xadMasterBase *)="\tjsr\t-186(a6)";
#define xadGetSystemInfo() __xadGetSystemInfo(xadMasterBase)

#endif /*  _VBCCINLINE_XADMASTER_H  */
