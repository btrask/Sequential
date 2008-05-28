#ifndef XADMASTER_LIBINIT_C
#define XADMASTER_LIBINIT_C

/*  $Id: libinit.c,v 1.12 2005/06/23 14:54:40 stoecker Exp $
    all the library initialization stuff

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

#if defined(__GNUC__) && defined(__mc68000__)
#if (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ > 3)) || defined(DEBUG)
__asm__ ("jra _ReturnError");
#endif
#endif

#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/resident.h>
#include <exec/initializers.h>
#include <exec/execbase.h>
#include <clib/alib_protos.h>
#include <libraries/xadmaster.h>

#include "functions.h"
#include "version.h"
#include "privdefs.h"

#ifdef __MORPHOS__
  #define SETHOOK(HOOK, FUNC) \
    (HOOK).h_Entry=(HOOKFUNC)HookEntry,(HOOK).h_SubEntry=(HOOKFUNC)FUNC
#else
  #define SETHOOK(HOOK, FUNC) \
    (HOOK).h_Entry=(HOOKFUNC)FUNC
#endif
#ifndef __amigaos4__
#define DeleteLibrary(LIB) \
  FreeMem((STRPTR)(LIB)-(LIB)->lib_NegSize, (ULONG)((LIB)->lib_NegSize+(LIB)->lib_PosSize))
#endif

/************************************************************************/

static void InitClients(struct xadMasterBaseP * xadMasterBase); /* proto for DEBUG */

/* First executable routine of this library; must return an error
   to the unsuspecting caller */
#ifdef DEBUG
struct Args {
  ULONG clients;
  ULONG resource;
};

void xadLibExpunge(void);
#if defined(__SASC)
#pragma libcall xadMasterBase xadLibExpunge 012 00
#elif defined(__GNUC__)
#define xadLibExpunge() LP0NR(0x12,xadLibExpunge,,xadMasterBase)
#endif

ASM(LONG) ReturnError(REG(a0, STRPTR args), REG(d0, ULONG length))
{
  /* DEBUG work:
  args may be
  CLIENTS:
    remove extern clients from list and reinit list entries. This does not
    remove the old clients from memory!
  RESOURCE:
    show current memory resource allocations
  */

  struct ExecBase *SysBase;
  struct DOSBase *DOSBase;
  struct xadMasterBaseP *xadMasterBase;
  struct Process *task;
  struct Message *msg = 0;

  SysBase = (*((struct ExecBase **) 4));
  if(!(task = (struct Process *) FindTask(0))->pr_CLI)
  {
    WaitPort(&task->pr_MsgPort);
    msg = GetMsg(&task->pr_MsgPort);
  }

  if((DOSBase = (struct DOSBase *) OpenLibrary("dos.library", 37)))
  {
    if((xadMasterBase = (struct xadMasterBaseP *) OpenLibrary("xadmaster.library", 6)))
    {
      struct Args args;
      struct RDArgs *rda;

      args.clients = args.resource = 0;
      if((rda = ReadArgs("CLIENTS/S,RESOURCE/S", (LONG *) &args, 0)))
      {
        if(args.resource)
        {
          Printf("Trying to activate resource tracker output.\n");
          xadLibExpunge();
        }
        if(args.clients)
        {
          struct xadClient *cl;

          Printf("Reloading external client database (DANGEROUS).\n");
          cl = xadMasterBase->xmb_FirstClient;
          while(cl->xc_Next)
          {
            if(cl->xc_Next->xc_Flags & XADCF_EXTERN)
              cl->xc_Next = cl->xc_Next->xc_Next;
            else
              cl = cl->xc_Next;
          }

          if(xadMasterBase->xmb_FirstClient->xc_Flags & XADCF_EXTERN)
            xadMasterBase->xmb_FirstClient = xadMasterBase->xmb_FirstClient->xc_Next;

          InitClients(xadMasterBase);
        }
        FreeArgs(rda);
      }
      CloseLibrary((struct Library *) xadMasterBase);
    }
    CloseLibrary((struct Library *) DOSBase);
  }

  if(msg)
  {
    Forbid();
    ReplyMsg(msg);
  }
  return 0;
}

#else

/* just to make the linker happy;) */
#ifdef __amigaos4__
#define ReturnError _start
#endif

LONG ReturnError(void)
{
  return -1;
}
#endif

/************************************************************************/

struct LibInitData {
 UBYTE i_Type;     UBYTE o_Type;     UBYTE  d_Type;     UBYTE p_Type;
 UBYTE i_Name;     UBYTE o_Name;     STRPTR d_Name;
 UBYTE i_Flags;    UBYTE o_Flags;    UBYTE  d_Flags;    UBYTE p_Flags;
 UBYTE i_Version;  UBYTE o_Version;  UWORD  d_Version;
 UBYTE i_Revision; UBYTE o_Revision; UWORD  d_Revision;
 UBYTE i_IdString; UBYTE o_IdString; STRPTR d_IdString;
 ULONG endmark;
};

/************************************************************************/
static const ULONG LibInitTable[4]; /* the prototype */

/* The library loader looks for this marker in the memory
   the library code and data will occupy. It is responsible
   setting up the Library base data structure. */
const struct Resident RomTag = {
  RTC_MATCHWORD,                /* Marker value. */
  (struct Resident *)&RomTag,   /* This points back to itself. */
  (struct Resident *)&RomTag+1, /* This points behind this marker. */
#ifdef __MORPHOS__
  RTF_AUTOINIT | RTF_PPC | RTF_EXTENDED,
#elif defined(__amigaos4__)
  RTF_AUTOINIT | RTF_NATIVE,
#else
  RTF_AUTOINIT,                 /* The Library should be set up according to the given table. */
#endif
  XADMASTERVERSION,             /* The version of this Library. */
  NT_LIBRARY,                   /* This defines this module as a Library. */
  0,                            /* Initialization priority of this Library; unused. */
  LIBNAME,                      /* Points to the name of the Library. */
  IDSTRING,                     /* The identification string of this Library. */
#ifdef __amigaos4__
  (APTR)libCreateTags
#else
  (APTR)LibInitTable            /* This table is for initializing the Library. */
#ifdef __MORPHOS__
  ,
  XADMASTERREVISION,
  NULL
#endif
#endif
};

#ifdef __MORPHOS__
ULONG __abox__ = 1;
ULONG __amigappc__ = 1;
#endif

/************************************************************************/

/* The mandatory reserved library function */
ULONG LibReserved(void)
{
  return 0;
}

/* Open the library, as called via OpenLibrary() */

ASM(struct Library *) LibOpen(REG(a6, struct xadMasterBaseP * xadMasterBase))
{
  /* Prevent delayed expunge and increment opencnt */
  xadMasterBase->xmb_LibNode.lib_Flags &= ~LIBF_DELEXP;
  xadMasterBase->xmb_LibNode.lib_OpenCnt++;

  return &xadMasterBase->xmb_LibNode;
}

/* Closes all the libraries opened by LibInit() */
static void CloseLibraries(struct xadMasterBaseP * xadMasterBase)
{
  struct DosLibrary *DOSBase = xadMasterBase->xmb_DOSBase;
  struct ExecBase *SysBase = xadMasterBase->xmb_SysBase;

  xadFreeClients(xadMasterBase);
  if(xadMasterBase->xmb_ClientSegList)
    UnLoadSeg(xadMasterBase->xmb_ClientSegList);

#ifdef __amigaos4__
  /* free seglists of PPC clients */
  elfFreeAll(xadMasterBase);
  /* Can handle NULL */
  DropInterface((struct Interface *)IUtility);
  DropInterface((struct Interface *)IDOS);
  DropInterface((struct Interface *)IxadMaster);
  DropInterface((struct Interface *)xadMasterBase->xmb_IElf);
  CloseLibrary(xadMasterBase->xmb_ElfBase);
#endif

  if(xadMasterBase->xmb_UtilityBase)
    CloseLibrary((struct Library *) xadMasterBase->xmb_UtilityBase);
  if(xadMasterBase->xmb_DOSBase)
    CloseLibrary((struct Library *) xadMasterBase->xmb_DOSBase);
}

/* Expunge the library, remove it from memory */
ASM(BPTR) LibExpunge(REG(a6, struct xadMasterBaseP * xadMasterBase))
{
  struct ExecBase *SysBase = xadMasterBase->xmb_SysBase;

#ifdef DEBUGRESOURCE
  DebugResource(xadMasterBase, (xadSTRPTR)1);
#endif

  if(!xadMasterBase->xmb_LibNode.lib_OpenCnt)
  {
    BPTR seglist;

    seglist = xadMasterBase->xmb_SegList;

    CloseLibraries(xadMasterBase);

    /* Remove the library from the public list */
    Remove((struct Node *) xadMasterBase);

    /* Free the vector table and the library data */
    DeleteLibrary(&xadMasterBase->xmb_LibNode);

    return seglist;
  }
  else
    xadMasterBase->xmb_LibNode.lib_Flags |= LIBF_DELEXP;

  /* Return the segment pointer, if any */
  return 0;
}

/* Close the library, as called by CloseLibrary() */
ASM(BPTR) LibClose(REG(a6, struct xadMasterBaseP * xadMasterBase))
{
#ifdef DEBUGRESOURCE
  DebugResource(xadMasterBase, NULL);
#endif
  if(!(--xadMasterBase->xmb_LibNode.lib_OpenCnt))
  {
    if(xadMasterBase->xmb_LibNode.lib_Flags & LIBF_DELEXP)
      return LibExpunge(xadMasterBase);
  }
  return 0;
}

#ifdef __MORPHOS__
static struct Library *STUBOpen(void)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *)REG_A6;

  return LibOpen(xadMasterBase);
}
#define LibOpen STUBOpen

static BPTR STUBExpunge(void)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *)REG_A6;

  return LibExpunge(xadMasterBase);
}
#define LibExpunge STUBExpunge

static BPTR STUBClose(void)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *)REG_A6;

  return LibClose(xadMasterBase);
}
#define LibClose STUBClose
#endif

static void InitClients(struct xadMasterBaseP * xadMasterBase)
{
  struct DosLibrary *DOSBase = xadMasterBase->xmb_DOSBase;
  struct FileInfoBlock *fib;

  if((fib = (struct FileInfoBlock *) AllocDosObject(DOS_FIB, 0)))
  {
    BPTR lock;

    if((lock = Lock("LIBS:xad", SHARED_LOCK)))
    {
      if(Examine(lock, fib))
      {
        if(fib->fib_DirEntryType > 0)
        {
          BPTR oldlock;

          oldlock = CurrentDir(lock);

          while(ExNext(lock, fib))
          {
            BPTR sl;

            if((sl = (LoadSeg(fib->fib_FileName)<<2)))
            {
              xadBOOL need = XADFALSE;

#ifdef __amigaos4__
              if (elfFindForeman(xadMasterBase, MKBADDR(sl), &need))
              {
                if (need) continue;
              }
              else
#endif
              {
                xadUINT32 i, size = *((xadUINT32 *) (sl-4))-16; /* 16 --> xadForman size */

                /* scan the first segment for a forman structure */
                for(i = 0; !need && i < size; i += 2)
                {
                  /* divided into 2 parts to disable recognition of
                    xadmaster.library as client */
                  if((*((xadUINT16 *) (sl+4+i)) == 0x5841) &&
                  (*((xadUINT16 *) (sl+6+i)) == 0x4446))
                  {
                    const struct xadClient *xcl;

                    xcl = ((struct xadForeman *) (sl+4+i-4))->xfm_FirstClient;
                    need = xadAddClients(xadMasterBase, xcl, XADCF_EXTERN);
                  }
                }
              }
              if(!need)
                UnLoadSeg(sl>>2);
              else /* add this seglist */
              {
                BPTR sl2 = sl;

                while(*((ULONG *)sl2))
                  sl2 = *((ULONG *)sl2)<<2;

                *((ULONG *)sl2) = xadMasterBase->xmb_ClientSegList;
                xadMasterBase->xmb_ClientSegList = sl>>2;
              }
            } /* LoadSeg */
          } /* ExNext */
          SetIoErr(0);
          CurrentDir(oldlock);
        } /* Is Directory ? */
      } /* Examine */
      UnLock(lock);
    } /* Lock */
    FreeDosObject(DOS_FIB, fib);
  } /* AllocDosObject */
}

struct ExecBase *      SysBase       = 0;

#if defined(DEBUG) || defined(DEBUGRESOURCE)
struct DosLibrary *    DOSBase       = 0;
struct UtilityBase *   UtilityBase   = 0;
struct xadMasterBase * xadMasterBase = 0;

static void MakeGlobalLibs(struct xadMasterBaseP *xadBase)
{
  DOSBase = xadBase->xmb_DOSBase;
  UtilityBase = xadBase->xmb_UtilityBase;
  xadMasterBase = (struct xadMasterBase *) xadBase;
}
#endif

#if defined(__GNUC__) && !defined(__PPC__)
#define NEED__UTILITYBASE
#endif

#ifdef NEED__UTILITYBASE
struct Library *__UtilityBase;
#endif

/* Initialize library */
ASM(struct Library *) LibInit(REG(d0, struct xadMasterBaseP * xadMasterBase),
REG(a0, BPTR seglist), REG(a6, struct ExecBase *sysBase))
{
  SysBase = sysBase;

#ifdef _M68060
  if(!(sysBase->AttnFlags & AFF_68060))
    return 0;
#elif defined (_M68040)
  if(!(sysBase->AttnFlags & AFF_68040))
    return 0;
#elif defined (_M68030)
  if(!(sysBase->AttnFlags & AFF_68030))
    return 0;
#elif defined (_M68020)
  if(!(sysBase->AttnFlags & AFF_68020))
    return 0;
#endif

  /* Remember stuff */
  xadMasterBase->xmb_DefaultName = "unnamed.dat";
  xadMasterBase->xmb_SegList = seglist;
  xadMasterBase->xmb_SysBase = sysBase;
  SETHOOK(xadMasterBase->xmb_InHookFH,       InHookFH);
  SETHOOK(xadMasterBase->xmb_OutHookFH,      OutHookFH);
  SETHOOK(xadMasterBase->xmb_InHookMem,      InHookMem);
  SETHOOK(xadMasterBase->xmb_OutHookMem,     OutHookMem);
  SETHOOK(xadMasterBase->xmb_InHookStream,   InHookStream);
  SETHOOK(xadMasterBase->xmb_OutHookStream,  OutHookStream);
  SETHOOK(xadMasterBase->xmb_InHookDisk,     InHookDisk);
  SETHOOK(xadMasterBase->xmb_OutHookDisk,    OutHookDisk);
  SETHOOK(xadMasterBase->xmb_InHookSplitted, InHookSplitted);
  SETHOOK(xadMasterBase->xmb_InHookDiskArc,  InHookDiskArc);
  xadMasterBase->xmb_FirstClient = NULL;
  xadMasterBase->xmb_System.xsi_Version = XADMASTERVERSION;
  xadMasterBase->xmb_System.xsi_Revision = XADMASTERREVISION;

  if((xadMasterBase->xmb_DOSBase = (struct DosLibrary *)
  OpenLibrary("dos.library", 37)))
  {
    if((xadMasterBase->xmb_UtilityBase =
    (struct UtilityBase *) OpenLibrary("utility.library", 37)))
    {
      xadSize minsize = 0;
      const struct xadClient *cl;

#ifdef __amigaos4__
      xadMasterBase->xmb_LibNode.lib_Revision = XADMASTERREVISION;
      xadMasterBase->xmb_ElfBase = OpenLibrary("elf.library", 0);

      IxadMaster = (struct XadMasterIFace *) GetInterface((struct Library *)xadMasterBase, "main", 1L, NULL);
      IUtility = (struct UtilityIFace *) GetInterface((struct Library *)xadMasterBase->xmb_UtilityBase, "main", 1L, NULL);
      IDOS = (struct DOSIFace *) GetInterface((struct Library *)xadMasterBase->xmb_DOSBase, "main", 1L, NULL);
      xadMasterBase->xmb_IElf = (struct ElfIFace *) GetInterface((struct Library *)xadMasterBase->xmb_ElfBase, "main", 1L, NULL);

      if (!IDOS || !IxadMaster || !IUtility || !xadMasterBase->xmb_IElf)
        goto error;
#endif

#ifdef NEED__UTILITYBASE
      __UtilityBase = (struct Library *) xadMasterBase->xmb_UtilityBase;
#endif

#if defined(DEBUG) || defined(DEBUGRESOURCE)
      MakeGlobalLibs(xadMasterBase);
#endif
      /* add internal clients */
      xadAddClients(xadMasterBase, RealFirstClient, 0);
      /* load and add external clients */
      InitClients(xadMasterBase);

      for(cl = xadMasterBase->xmb_FirstClient; cl; cl = cl->xc_Next)
      {
        if(cl->xc_RecogSize > minsize)
          minsize = cl->xc_RecogSize;
      }
      xadMasterBase->xmb_RecogSize = minsize; /* obsolete, compatibility only */
      xadMasterBase->xmb_System.xsi_RecogSize = minsize;

      MakeCRC16(xadMasterBase->xmb_CRCTable1, XADCRC16_ID1);
      MakeCRC32(xadMasterBase->xmb_CRCTable2, XADCRC32_ID1);
#ifdef DEBUGRESOURCE
      xadMasterBase->xmb_Resource = 0;
      InitSemaphore(&xadMasterBase->xmb_ResourceLock);
#endif
      return &xadMasterBase->xmb_LibNode;
    }
 error:
    CloseLibraries(xadMasterBase);
  }

  /* Free the vector table and the library data */
  DeleteLibrary(&xadMasterBase->xmb_LibNode);

  return 0;
}

/************************************************************************/

#ifdef __amigaos4__

#include "os4specific.h"

#else

/* This is the table of functions that make up the library. The first
   four are mandatory, everything following it are user callable
   routines. The table is terminated by the value -1. */

static const APTR LibVectors[] = {
#ifdef __MORPHOS__
  (APTR) FUNCARRAY_32BIT_NATIVE,
#endif
  (APTR) LibOpen,
  (APTR) LibClose,
  (APTR) LibExpunge,
  (APTR) LibReserved,
  (APTR) LIBxadAllocObjectA,
  (APTR) LIBxadFreeObjectA,
  (APTR) LIBxadRecogFileA,
  (APTR) LIBxadGetInfoA,
  (APTR) LIBxadFreeInfo,
  (APTR) LIBxadFileUnArcA,
  (APTR) LIBxadDiskUnArcA,
  (APTR) LIBxadGetErrorText,
  (APTR) LIBxadGetClientInfo,
  (APTR) LIBxadHookAccess,
  (APTR) LIBxadConvertDatesA,
  (APTR) LIBxadCalcCRC16,
  (APTR) LIBxadCalcCRC32,
  (APTR) LIBxadAllocVec,
  (APTR) LIBxadCopyMem,
  (APTR) LIBxadHookTagAccessA,
  (APTR) LIBxadConvertProtectionA,
  (APTR) LIBxadGetDiskInfoA,
  (APTR) LIBxadFileUnArcA,
  (APTR) LIBxadGetHookAccessA,
  (APTR) LIBxadFreeHookAccessA,
  (APTR) LIBxadAddFileEntryA,
  (APTR) LIBxadAddDiskEntryA,
  (APTR) LIBxadGetFilenameA,
  (APTR) LIBxadConvertNameA,
  (APTR) LIBxadGetDefaultNameA,
  (APTR) LIBxadGetSystemInfo,
  (APTR) -1
};

#ifndef __MORPHOS__
static const struct LibInitData LibInitData = {
 0xA0, (UBYTE) OFFSET(Node,    ln_Type),      NT_LIBRARY,                0,
 0x80, (UBYTE) OFFSET(Node,    ln_Name),      LIBNAME,
 0xA0, (UBYTE) OFFSET(Library, lib_Flags),    LIBF_SUMUSED|LIBF_CHANGED, 0,
 0x90, (UBYTE) OFFSET(Library, lib_Version),  XADMASTERVERSION,
 0x90, (UBYTE) OFFSET(Library, lib_Revision), XADMASTERREVISION,
 0x80, (UBYTE) OFFSET(Library, lib_IdString), IDSTRING,
 0
};
#endif

/* The following data structures and data are responsible for
   setting up the Library base data structure and the library
   function vector.
*/
static const ULONG LibInitTable[4] = {
  (ULONG)sizeof(struct xadMasterBaseP), /* Size of the base data structure */
  (ULONG)LibVectors,             /* Points to the function vector */
#ifdef __MORPHOS__
  NULL,
#else
  (ULONG)&LibInitData,           /* Library base data structure setup table */
#endif
  (ULONG)LibInit                 /* The address of the routine to do the setup */
};

#endif /* !__amigaos4__ */

#endif /* XADMASTER_LIBINIT_C */
