#ifndef _INCLUDE_PRAGMA_XADMASTER_LIB_H
#define _INCLUDE_PRAGMA_XADMASTER_LIB_H

#ifndef CLIB_XADMASTER_PROTOS_H
#include <clib/xadmaster_protos.h>
#endif

#if defined(AZTEC_C) || defined(__MAXON__) || defined(__STORM__)
#pragma amicall(xadMasterBase,0x01e,xadAllocObjectA(d0,a0))
#pragma amicall(xadMasterBase,0x024,xadFreeObjectA(a0,a1))
#pragma amicall(xadMasterBase,0x02a,xadRecogFileA(d0,a0,a1))
#pragma amicall(xadMasterBase,0x030,xadGetInfoA(a0,a1))
#pragma amicall(xadMasterBase,0x036,xadFreeInfo(a0))
#pragma amicall(xadMasterBase,0x03c,xadFileUnArcA(a0,a1))
#pragma amicall(xadMasterBase,0x042,xadDiskUnArcA(a0,a1))
#pragma amicall(xadMasterBase,0x048,xadGetErrorText(d0))
#pragma amicall(xadMasterBase,0x04e,xadGetClientInfo())
#pragma amicall(xadMasterBase,0x054,xadHookAccess(d0,d1,a0,a1))
#pragma amicall(xadMasterBase,0x05a,xadConvertDatesA(a0))
#pragma amicall(xadMasterBase,0x060,xadCalcCRC16(d0,d1,d2,a0))
#pragma amicall(xadMasterBase,0x066,xadCalcCRC32(d0,d1,d2,a0))
#pragma amicall(xadMasterBase,0x06c,xadAllocVec(d0,d1))
#pragma amicall(xadMasterBase,0x072,xadCopyMem(a0,a1,d0))
#pragma amicall(xadMasterBase,0x078,xadHookTagAccessA(d0,d1,a0,a1,a2))
#pragma amicall(xadMasterBase,0x07e,xadConvertProtectionA(a0))
#pragma amicall(xadMasterBase,0x084,xadGetDiskInfoA(a0,a1))
#pragma amicall(xadMasterBase,0x090,xadGetHookAccessA(a0,a1))
#pragma amicall(xadMasterBase,0x096,xadFreeHookAccessA(a0,a1))
#pragma amicall(xadMasterBase,0x09c,xadAddFileEntryA(a0,a1,a2))
#pragma amicall(xadMasterBase,0x0a2,xadAddDiskEntryA(a0,a1,a2))
#pragma amicall(xadMasterBase,0x0a8,xadGetFilenameA(d0,a0,a1,a2,a3))
#pragma amicall(xadMasterBase,0x0ae,xadConvertNameA(d0,a0))
#pragma amicall(xadMasterBase,0x0b4,xadGetDefaultNameA(a0))
#pragma amicall(xadMasterBase,0x0ba,xadGetSystemInfo())
#endif
#if defined(_DCC) || defined(__SASC)
#pragma  libcall xadMasterBase xadAllocObjectA        01e 8002
#pragma  libcall xadMasterBase xadFreeObjectA         024 9802
#pragma  libcall xadMasterBase xadRecogFileA          02a 98003
#pragma  libcall xadMasterBase xadGetInfoA            030 9802
#pragma  libcall xadMasterBase xadFreeInfo            036 801
#pragma  libcall xadMasterBase xadFileUnArcA          03c 9802
#pragma  libcall xadMasterBase xadDiskUnArcA          042 9802
#pragma  libcall xadMasterBase xadGetErrorText        048 001
#pragma  libcall xadMasterBase xadGetClientInfo       04e 00
#pragma  libcall xadMasterBase xadHookAccess          054 981004
#pragma  libcall xadMasterBase xadConvertDatesA       05a 801
#pragma  libcall xadMasterBase xadCalcCRC16           060 821004
#pragma  libcall xadMasterBase xadCalcCRC32           066 821004
#pragma  libcall xadMasterBase xadAllocVec            06c 1002
#pragma  libcall xadMasterBase xadCopyMem             072 09803
#pragma  libcall xadMasterBase xadHookTagAccessA      078 a981005
#pragma  libcall xadMasterBase xadConvertProtectionA  07e 801
#pragma  libcall xadMasterBase xadGetDiskInfoA        084 9802
#pragma  libcall xadMasterBase xadGetHookAccessA      090 9802
#pragma  libcall xadMasterBase xadFreeHookAccessA     096 9802
#pragma  libcall xadMasterBase xadAddFileEntryA       09c a9803
#pragma  libcall xadMasterBase xadAddDiskEntryA       0a2 a9803
#pragma  libcall xadMasterBase xadGetFilenameA        0a8 ba98005
#pragma  libcall xadMasterBase xadConvertNameA        0ae 8002
#pragma  libcall xadMasterBase xadGetDefaultNameA     0b4 801
#pragma  libcall xadMasterBase xadGetSystemInfo       0ba 00
#endif
#ifdef __STORM__
#pragma tagcall(xadMasterBase,0x01e,xadAllocObject(d0,a0))
#pragma tagcall(xadMasterBase,0x024,xadFreeObject(a0,a1))
#pragma tagcall(xadMasterBase,0x02a,xadRecogFile(d0,a0,a1))
#pragma tagcall(xadMasterBase,0x030,xadGetInfo(a0,a1))
#pragma tagcall(xadMasterBase,0x03c,xadFileUnArc(a0,a1))
#pragma tagcall(xadMasterBase,0x042,xadDiskUnArc(a0,a1))
#pragma tagcall(xadMasterBase,0x05a,xadConvertDates(a0))
#pragma tagcall(xadMasterBase,0x078,xadHookTagAccess(d0,d1,a0,a1,a2))
#pragma tagcall(xadMasterBase,0x07e,xadConvertProtection(a0))
#pragma tagcall(xadMasterBase,0x084,xadGetDiskInfo(a0,a1))
#pragma tagcall(xadMasterBase,0x090,xadGetHookAccess(a0,a1))
#pragma tagcall(xadMasterBase,0x096,xadFreeHookAccess(a0,a1))
#pragma tagcall(xadMasterBase,0x09c,xadAddFileEntry(a0,a1,a2))
#pragma tagcall(xadMasterBase,0x0a2,xadAddDiskEntry(a0,a1,a2))
#pragma tagcall(xadMasterBase,0x0a8,xadGetFilename(d0,a0,a1,a2,a3))
#pragma tagcall(xadMasterBase,0x0ae,xadConvertName(d0,a0))
#pragma tagcall(xadMasterBase,0x0b4,xadGetDefaultName(a0))
#endif
#ifdef __SASC_60
#pragma  tagcall xadMasterBase xadAllocObject         01e 8002
#pragma  tagcall xadMasterBase xadFreeObject          024 9802
#pragma  tagcall xadMasterBase xadRecogFile           02a 98003
#pragma  tagcall xadMasterBase xadGetInfo             030 9802
#pragma  tagcall xadMasterBase xadFileUnArc           03c 9802
#pragma  tagcall xadMasterBase xadDiskUnArc           042 9802
#pragma  tagcall xadMasterBase xadConvertDates        05a 801
#pragma  tagcall xadMasterBase xadHookTagAccess       078 a981005
#pragma  tagcall xadMasterBase xadConvertProtection   07e 801
#pragma  tagcall xadMasterBase xadGetDiskInfo         084 9802
#pragma  tagcall xadMasterBase xadGetHookAccess       090 9802
#pragma  tagcall xadMasterBase xadFreeHookAccess      096 9802
#pragma  tagcall xadMasterBase xadAddFileEntry        09c a9803
#pragma  tagcall xadMasterBase xadAddDiskEntry        0a2 a9803
#pragma  tagcall xadMasterBase xadGetFilename         0a8 ba98005
#pragma  tagcall xadMasterBase xadConvertName         0ae 8002
#pragma  tagcall xadMasterBase xadGetDefaultName      0b4 801
#endif

#endif	/*  _INCLUDE_PRAGMA_XADMASTER_LIB_H  */
