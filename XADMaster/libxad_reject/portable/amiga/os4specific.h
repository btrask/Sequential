#ifndef XADMASTER_OS4SPECIFIC_H
#define XADMASTER_OS4SPECIFIC_H

/*  $Id: os4specific.h,v 1.4 2005/06/23 14:54:40 stoecker Exp $
    OS4 specific library initialization stuff

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

#include <proto/xadmaster.h>

#ifndef STDARG_H
#include <stdarg.h>
#endif

xadPTR VARARGS68K LIBxadAllocObject(
  struct xadMasterIFace *IxadMaster,
  xadUINT32 type,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, type);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  (xadPTR)xadAllocObjectA(
    type,
    varargs);
}

void VARARGS68K LIBxadFreeObject(
  struct xadMasterIFace *IxadMaster,
  xadPTR object,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, object);
  varargs = va_getlinearva(ap, const struct TagItem *);
    xadFreeObjectA(
    object,
    varargs);
}

struct xadClient * VARARGS68K LIBxadRecogFile(
  struct xadMasterIFace *IxadMaster,
  xadSize size,
  const void * memory,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, memory);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  (struct xadClient *) xadRecogFileA(
    size,
    memory,
    varargs);
}

xadERROR VARARGS68K LIBxadGetInfo(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadGetInfoA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadFileUnArc(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadFileUnArcA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadDiskUnArc(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadDiskUnArcA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadConvertDates(
  struct xadMasterIFace *IxadMaster,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, IxadMaster);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadConvertDatesA(
    varargs);
}

xadERROR VARARGS68K LIBxadHookTagAccess(
  struct xadMasterIFace *IxadMaster,
  xadUINT32 command,
  xadSignSize data,
  xadPTR buffer,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadHookTagAccessA(
    command,
    data,
    buffer,
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadConvertProtection(
  struct xadMasterIFace *IxadMaster,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, IxadMaster);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadConvertProtectionA(
    varargs);
}

xadERROR VARARGS68K LIBxadGetDiskInfo(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadGetDiskInfoA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadDiskFileUnArc(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadDiskFileUnArcA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadGetHookAccess(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadGetHookAccessA(
    ai,
    varargs);
}

void VARARGS68K LIBxadFreeHookAccess(
  struct xadMasterIFace *IxadMaster,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
    xadFreeHookAccessA(
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadAddFileEntry(
  struct xadMasterIFace *IxadMaster,
  struct xadFileInfo * fi,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadAddFileEntryA(
    fi,
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadAddDiskEntry(
  struct xadMasterIFace *IxadMaster,
  struct xadDiskInfo * di,
  struct xadArchiveInfo * ai,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, ai);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadAddDiskEntryA(
    di,
    ai,
    varargs);
}

xadERROR VARARGS68K LIBxadGetFilename(
  struct xadMasterIFace *IxadMaster,
  xadUINT32 buffersize,
  xadSTRPTR buffer,
  const xadSTRING * path,
  const xadSTRING * name,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, name);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  xadGetFilenameA(
    buffersize,
    buffer,
    path,
    name,
    varargs);
}

xadSTRPTR VARARGS68K LIBxadConvertName(
  struct xadMasterIFace *IxadMaster,
  xadUINT32 charset,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, charset);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  (xadSTRPTR) xadConvertNameA(
    charset,
    varargs);
}

xadSTRPTR VARARGS68K LIBxadGetDefaultName(
  struct xadMasterIFace *IxadMaster,
  ...
)
{
  va_list ap;
  const struct TagItem * varargs;
  va_startlinear(ap, IxadMaster);
  varargs = va_getlinearva(ap, const struct TagItem *);
  return  (xadSTRPTR) xadGetDefaultNameA(
    varargs);
}

#include <proto/elf.h>

STATIC VOID elfFreeAll(struct xadMasterBaseP *xadMasterBase)
{
  struct Node *ln;

  while (ln = RemHead((struct List *)&xadMasterBase->xmb_ElfList))
  {
    UnLoadSeg((BPTR)ln->ln_Name);
    FreeMem(ln, sizeof(*ln));
  }
}

xadBOOL elfFindForeman(struct xadMasterBaseP *xadMasterBase, BPTR sl, xadBOOL *need)
{
  Elf32_Handle hElf = NULL;

  if (GetSegListInfoTags(sl,GSLI_ElfHandle,&hElf,TAG_DONE))
  {
    struct ElfIFace *IElf = xadMasterBase->xmb_IElf;

    if (hElf = OpenElfTags(OET_ElfHandle, hElf, TAG_DONE))
    {
      struct Elf32_SymbolQuery sq;

      memset(&sq, 0, sizeof(sq));

      sq.Flags = ELF32_SQ_BYNAME;
      sq.Name  = "xadForeman";

      SymbolQuery(hElf, 1, &sq);
      if (sq.Found)
      {
        struct Node *ln;

        if (ln = AllocMem(sizeof(*ln), MEMF_CLEAR|MEMF_SHARED))
        {
          struct xadForeman *xfm = (struct xadForeman *) sq.Value;
          struct xadClient  *xcl = xfm->xfm_FirstClient;

          if (*need = xadAddClients(xadMasterBase, xcl, XADCF_EXTERN))
          {
            ln->ln_Name = (char *) sl;
            AddTail((struct List *)&xadMasterBase->xmb_ElfList, ln);
          }
          else
          {
            FreeMem(ln, sizeof(*ln));
          }
        }
      }

      CloseElfTags(hElf, CET_ReClose, TRUE, TAG_DONE);
    }

    return XADTRUE; /* is ELF */
  }

  return XADFALSE; /* not an ELF */
}

extern struct Library * LibInit(struct xadMasterBaseP * xadMasterBase, BPTR seglist, struct ExecBase *sysBase);
extern struct Library * LibOpen(struct xadMasterBaseP * xadMasterBase);
extern BPTR LibClose(struct xadMasterBaseP * xadMasterBase);
extern BPTR LibExpunge(struct xadMasterBaseP * xadMasterBase);

struct xadMasterIFace *IxadMaster;

struct Library *StubLibOpen(struct Interface *Self)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) Self->Data.LibBase;
  return (struct Library *)LibOpen(xadMasterBase);
}

BPTR StubLibClose(struct Interface *Self)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) Self->Data.LibBase;
  return LibClose(xadMasterBase);
}

BPTR StubLibExpunge(struct Interface *Self)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) Self->Data.LibBase;
  return LibExpunge(xadMasterBase);
}

struct Library * StubLibInit(struct xadMasterBaseP * xadMasterBase, BPTR seglist, struct ExecIFace *pIExec)
{
  struct ExecBase *sysBase = (struct ExecBase *) pIExec->Data.LibBase;

  xadMasterBase->xmb_IExec = pIExec;
  NewMinList(&xadMasterBase->xmb_ElfList);
  return LibInit(xadMasterBase, seglist, sysBase);
}

STATIC ULONG LibObtain(struct Interface *Self)
{
  return(Self->Data.RefCount++);
}

STATIC ULONG LibRelease(struct Interface *Self)
{
  return(Self->Data.RefCount--);
}

STATIC CONST APTR LibManagerVectors[] =
{
  (APTR)LibObtain,
  (APTR)LibRelease,
  NULL,
  NULL,
  (APTR)StubLibOpen,
  (APTR)StubLibClose,
  (APTR)StubLibExpunge,
  NULL,
  (APTR)-1
};

STATIC CONST struct TagItem LibManagerTags[] =
{
  {MIT_Name,        (ULONG)"__library"},
  {MIT_VectorTable, (ULONG)LibManagerVectors},
  {MIT_Version,     1},
  {TAG_DONE,        0}
};

STATIC CONST VOID *MainVectors[] = {
  (void *)LibObtain,
  (void *)LibRelease,
  NULL,
  NULL,
  (void *)LIBxadAllocObjectA,
  (void *)LIBxadAllocObject,
  (void *)LIBxadFreeObjectA,
  (void *)LIBxadFreeObject,
  (void *)LIBxadRecogFileA,
  (void *)LIBxadRecogFile,
  (void *)LIBxadGetInfoA,
  (void *)LIBxadGetInfo,
  (void *)LIBxadFreeInfo,
  (void *)LIBxadFileUnArcA,
  (void *)LIBxadFileUnArc,
  (void *)LIBxadDiskUnArcA,
  (void *)LIBxadDiskUnArc,
  (void *)LIBxadGetErrorText,
  (void *)LIBxadGetClientInfo,
  (void *)LIBxadHookAccess,
  (void *)LIBxadConvertDatesA,
  (void *)LIBxadConvertDates,
  (void *)LIBxadCalcCRC16,
  (void *)LIBxadCalcCRC32,
  (void *)LIBxadAllocVec,
  (void *)LIBxadCopyMem,
  (void *)LIBxadHookTagAccessA,
  (void *)LIBxadHookTagAccess,
  (void *)LIBxadConvertProtectionA,
  (void *)LIBxadConvertProtection,
  (void *)LIBxadGetDiskInfoA,
  (void *)LIBxadGetDiskInfo,
  (void *)LIBxadFileUnArcA,
  (void *)LIBxadFileUnArc,
  (void *)LIBxadGetHookAccessA,
  (void *)LIBxadGetHookAccess,
  (void *)LIBxadFreeHookAccessA,
  (void *)LIBxadFreeHookAccess,
  (void *)LIBxadAddFileEntryA,
  (void *)LIBxadAddFileEntry,
  (void *)LIBxadAddDiskEntryA,
  (void *)LIBxadAddDiskEntry,
  (void *)LIBxadGetFilenameA,
  (void *)LIBxadGetFilename,
  (void *)LIBxadConvertNameA,
  (void *)LIBxadConvertName,
  (void *)LIBxadGetDefaultNameA,
  (void *)LIBxadGetDefaultName,
  (void *)LIBxadGetSystemInfo,
  (void *)-1
};

STATIC CONST struct TagItem MainTags[] =
{
  {MIT_Name,        (ULONG)"main"},
  {MIT_VectorTable, (ULONG)MainVectors},
  {MIT_Version,     1},
  {TAG_DONE,        0}
};

STATIC CONST ULONG LibInterfaces[] =
{
  (ULONG)LibManagerTags,
  (ULONG)MainTags,
  0
};

extern APTR VecTable68K[];

STATIC CONST struct TagItem libCreateTags[] =
{
  {CLT_DataSize,   (ULONG)(sizeof(struct xadMasterBaseP))},
  {CLT_Interfaces, (ULONG)LibInterfaces},
  {CLT_Vector68K,  (ULONG)&VecTable68K},
  {CLT_InitFunc,   (ULONG)StubLibInit},
  {TAG_DONE,       0}
};

#endif /* XADMASTER_OS4SPECIFIC_H */
