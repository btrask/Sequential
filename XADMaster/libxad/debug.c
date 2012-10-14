#ifndef XADMASTER_DEBUG_C
#define XADMASTER_DEBUG_C

/*  $Id: debug.c,v 1.17 2005/06/23 14:54:37 stoecker Exp $
    the debug stuff

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

#include <stdarg.h>
#include "functions.h"
static void DoDebug(xadUINT32 mode, const xadSTRING *fmt, xadTAGPTR tags,
va_list va);

#ifdef AMIGA
#ifdef SysBase
#undef SysBase
#endif
#include <exec/types.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/utility.h>
#include <proto/xadmaster.h>
#include <utility/tagitem.h>
#include <dos/var.h>
#include "SDI_compiler.h"

#ifdef __MORPHOS__
#include <exec/rawfmt.h>

typedef APTR (*putchtype)(APTR, UBYTE);
APTR (*function)(APTR, UBYTE);

static xadUINT32 normfunc(xadUINT32 pd, UBYTE c)
{
  UBYTE d = c;
  if (c)
    Write(pd, &d, 1);

  return pd;
}

static xadUINT32 errfunc(xadUINT32 pd, UBYTE c)
{
  UBYTE d = c;
  if (c)
    Write(Output(), &d, 1);

  return pd;
}

#define OutputDebugVA(fmt,func,pd,args) VNewRawDoFmt(fmt,func,pd,args)
#else /* __MORPHOS__ */
typedef void (*putchtype) ();
ASM(void) (*function)(REG(d0, UBYTE), REG(a3, xadUINT32)) = 0;

extern LONG __stdargs KPutChar(LONG);
extern LONG __stdargs DPutChar(LONG);

static ASM(void) serfunc(REG(d0, UBYTE c), REG(a3, xadUINT32 pd))
{ if(c) KPutChar(c); }

static ASM(void) parfunc(REG(d0, UBYTE c), REG(a3, xadUINT32 pd))
{ if(c) DPutChar(c); }

static ASM(void) normfunc(REG(d0, UBYTE c), REG(a3, xadUINT32 pd))
{
  UBYTE d = c;
  if(c)
    Write(pd, &d, 1);
}

static ASM(void) errfunc(REG(d0, UBYTE c), REG(a3, xadUINT32 pd))
{
  UBYTE d = c;
  if(c)
    Write(Output(), &d, 1);
}

#define OutputDebugVA(fmt,func,pd,args) RawDoFmt(fmt,args,func,pd)
#endif /* __MORPHOS__ */
#define outfunc errfunc

#define OutputDebug(fmt,func,pd) OutputDebugArgs(fmt,func,pd)
static xadPTR STDARGS OutputDebugArgs(const xadSTRING *fmt, putchtype func,
xadPTR pd, ...)
{
  va_list args;
  xadPTR ret;

  va_start(args, pd);
  ret = OutputDebugVA(fmt,func,pd,args);
  va_end(args);

  return ret;
}

#ifdef DEBUG
static xadUINT32 DebugPrintFlag(putchtype func, xadPTR fh, xadUINT32 flag,
const xadSTRING *flagtext, xadUINT32 i)
{
  if(i & flag)
  {
    OutputDebug(flagtext, func, fh);
    i &= ~flag;
    if(i)
      OutputDebug("|", func, fh);
  }
  return i;
}
#define PrintFlag(a, b) DebugPrintFlag((putchtype) function, fh, a, #a, b)
#endif /* DEBUG */

#ifdef DEBUGRESOURCE
void DebugResource(struct xadMasterBaseP *xadMasterBase,
const xadSTRING *format, ...)
{
  if(format > (xadSTRPTR)1)
  {
    va_list va;
    va_start(va, format);
    DoDebug(DEBUGFLAG_RESOURCE, format, 0, va);
    va_end(va);
  }
  else
  {
    struct xadObject *obj;
    struct Task *t = 0;

    if(format != (xadSTRPTR)1)
      t = FindTask(NULL);
/*
    else
    {
      DebugResource(xadMasterBase, "LibExpunge: resource checkup");
    }
*/
    ObtainSemaphoreShared(&xadMasterBase->xmb_ResourceLock);
    for(obj = xadMasterBase->xmb_Resource; obj; obj = obj->xo_Last)
    {
      if(obj->xo_Cookie != XADOBJCOOKIE)
      {
        DebugResource(xadMasterBase,
        "xadFreeObjectA: %s ($%08lx) has cookie $%08lx",
        xadGetObjectTypeName(obj->xo_Type), obj+1, obj->xo_Cookie);
      }
      if(format || t == obj->xo_Task)
      {
        DebugResource(xadMasterBase, "Lib%s: %s ($%08lx) task $%08lx size %ld not freed",
        format ? "Expunge" : "Close",
        xadGetObjectTypeName(obj->xo_Type), obj+1, obj->xo_Task, obj->xo_Size);
      }
    }
    ReleaseSemaphore(&xadMasterBase->xmb_ResourceLock);
  }
}
#endif /* DEBUGRESOURCE */
#else /* AMIGA */

#ifdef DEBUG
static xadUINT32 DebugPrintFlag(FILE *fh, xadUINT32 flag,
const xadSTRING *flagtext, xadUINT32 i)
{
  if(i & flag)
  {
    fprintf(fh, flagtext);
    i &= ~flag;
    if(i)
      fprintf(fh, "|");
  }
  return i;
}

typedef xadUINT8 putchtype;
xadUINT8 function = 0;

#define OutputDebug(_fmt,_func,_fh) fprintf(_fh,_fmt)
#define OutputDebugArgs(_fmt,_func,_fh,...) fprintf(_fh,_fmt,##__VA_ARGS__)
#define OutputDebugVA(_fmt,_func,_fh,_va) vfprintf(_fh,_fmt,_va)
#define PrintFlag(a,b) DebugPrintFlag(fh, a, #a, b)

#define normfunc 'n'
#define errfunc 'e'
#define outfunc 'o'

#endif /* DEBUG */

#ifdef DEBUGRESOURCE
void DebugResource(struct xadMasterBaseP *xadMasterBase,
const xadSTRING *format, ...)
{
  if(format)
  {
    va_list va;
    va_start(va, format);
    DoDebug(DEBUGFLAG_RESOURCE, format, 0, va);
    va_end(va);
  }
  else
  {
    struct xadObject *obj;
    for(obj = xadMasterBase->xmb_Resource; obj; obj = obj->xo_Last)
    {
      if(obj->xo_Cookie != XADOBJCOOKIE)
      {
        DebugResource(xadMasterBase,
        "xadFreeObjectA: %s ($%08lx) has cookie $%08lx",
        xadGetObjectTypeName(obj->xo_Type), obj+1, obj->xo_Cookie);
      }
      DebugResource(xadMasterBase, "Lib: %s ($%08lx) size %ld not freed",
      xadGetObjectTypeName(obj->xo_Type), obj+1, obj->xo_Size);
    }
  }
}
#endif /* DEBUGRESOURCE */
#endif /* AMIGA */

#ifdef DEBUG
void DebugFlagged(xadUINT32 flags, const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(flags, format, 0, va);
  va_end(va);
}

void DebugTagList(const xadSTRING *format, xadTAGPTR tags, ...)
{
  va_list va;
  va_start(va, tags);
  DoDebug(DEBUGFLAG_RUNTIME|DEBUGFLAG_TAGLIST, format, tags, va);
  va_end(va);
}

void DebugTagListOther(const xadSTRING *format, xadTAGPTR tags, ...)
{
  va_list va;
  va_start(va, tags);
  DoDebug(DEBUGFLAG_OTHER|DEBUGFLAG_TAGLIST, format, tags, va);
  va_end(va);
}

void DebugTagListMem(const xadSTRING *format, xadTAGPTR tags, ...)
{
  va_list va;
  va_start(va, tags);
  DoDebug(DEBUGFLAG_MEM|DEBUGFLAG_RUNTIME|DEBUGFLAG_TAGLIST, format, tags, va);
  va_end(va);
}

void DebugFileSearched(const struct xadArchiveInfo *ai,
const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  if(ai->xai_InName)
    DebugFlagged(DEBUGFLAG_SEARCHED|DEBUGFLAG_CONTINUESTART,
    "The file %s is searched by client %s: ", ai->xai_InName,
    ai->xai_Client->xc_ArchiverName);
  else
    DebugFlagged(DEBUGFLAG_SEARCHED|DEBUGFLAG_CONTINUESTART,
    "The current file is searched by client %s: ",
    ai->xai_Client->xc_ArchiverName);
  DoDebug(DEBUGFLAG_SEARCHED|DEBUGFLAG_CONTINUEEND, format, 0, va);
  va_end(va);
}

void DebugClient(const struct xadArchiveInfo *ai, const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DebugFlagged(DEBUGFLAG_CLIENT|DEBUGFLAG_CONTINUESTART,
  "Client %s: ", ai->xai_Client->xc_ArchiverName);
  DoDebug(DEBUGFLAG_CLIENT|DEBUGFLAG_CONTINUEEND, format, 0, va);
  va_end(va);
}

void DebugError(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_ERROR, format, 0, va);
  va_end(va);
}

void DebugRunTime(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_RUNTIME, format, 0, va);
  va_end(va);
}

void DebugOther(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_OTHER, format, 0, va);
  va_end(va);
}

void DebugMem(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_MEM, format, 0, va);
  va_end(va);
}

void DebugMemError(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_MEM|DEBUGFLAG_ERROR, format, 0, va);
  va_end(va);
}

void DebugHook(const xadSTRING *format, ...)
{
  va_list va;
  va_start(va, format);
  DoDebug(DEBUGFLAG_HOOK, format, 0, va);
  va_end(va);
}

void DebugHookTagList(const xadSTRING *format, xadTAGPTR taglist, ...)
{
  va_list va;
  va_start(va, taglist);
  DoDebug(DEBUGFLAG_HOOK|DEBUGFLAG_TAGLIST, format, taglist, va);
  va_end(va);
}
#endif /* DEBUG */

static xadUINT32 deb_flags = 0;

static void DoDebug(xadUINT32 mode, const xadSTRING *fmt, xadTAGPTR tags,
va_list data)
{
  xadUINT32 i;
  xadUINT32 Flags = 0;

  if(!function && (deb_flags & DEBUGFLAG_STATIC))
    return;

#ifdef AMIGA
  Forbid();
#endif

  if((deb_flags & DEBUGFLAG_STATIC)
  || (mode & (DEBUGFLAG_CONTINUE|DEBUGFLAG_CONTINUEEND)))
    Flags = deb_flags;
  else
  {
    xadSTRING Mode[17] = "";
#ifdef AMIGA
    GetVar("XADDEBUG", (xadSTRPTR) &Mode, sizeof(Mode)-1, GVF_GLOBAL_ONLY);
#else
    const xadSTRING *modePtr = getenv("XADDEBUG");
    if (modePtr)
      strncpy(Mode, modePtr, sizeof(Mode)-1);
#endif
    function = 0;

    for(i=0; Mode[i] && i < 15; ++i)
    {
      switch(Mode[i])
      {
      case 'A': Flags |= DEBUGFLAG_TAGLIST|DEBUGFLAG_RUNTIME|DEBUGFLAG_HOOK
                        |DEBUGFLAG_ERROR|DEBUGFLAG_OTHER|DEBUGFLAG_MEM
                        |DEBUGFLAG_FLAGS|DEBUGFLAG_RESOURCE|DEBUGFLAG_CLIENT
                        |DEBUGFLAG_SEARCHED; break;
      case 'M': Flags |= DEBUGFLAG_MEM; break;
      case 'O': Flags |= DEBUGFLAG_OTHER; break;
      case 'E': Flags |= DEBUGFLAG_ERROR; break;
      case 'C': Flags |= DEBUGFLAG_RESOURCE; break;
      case 'D': Flags |= DEBUGFLAG_CLIENT|DEBUGFLAG_SEARCHED; break;
      case 'F': Flags |= DEBUGFLAG_FLAGS; break;
      case 'H': Flags |= DEBUGFLAG_HOOK; break;
      case 'R': Flags |= DEBUGFLAG_RUNTIME; break;
      case 'T': Flags |= DEBUGFLAG_TAGLIST; break;
      case 'S': Flags |= DEBUGFLAG_STATIC; break;

#ifdef __MORPHOS__
      case 's': function = RAWFMTFUNC_SERIAL; break;
#elif defined(AMIGA)
      case 's': function = serfunc; break;
      case 'p': function = parfunc; break;
#endif
      case 'f': function = normfunc; break;
      case 'e': function = errfunc; break;
      case 'o': function = outfunc; break;
      case 'n': function = 0; break;
      }
    }
    deb_flags = Flags;
  }

  mode &= Flags|DEBUGFLAG_CONTINUE|DEBUGFLAG_CONTINUEEND
  |DEBUGFLAG_CONTINUESTART;

  if(mode & (~(DEBUGFLAG_TAGLIST|DEBUGFLAG_STATIC|DEBUGFLAG_CONTINUE
  |DEBUGFLAG_CONTINUEEND|DEBUGFLAG_CONTINUESTART)))
  {
#ifdef AMIGA
    xadPTR fh = 0;

    if(function==normfunc)
    {
      if((fh = (xadPTR) Open("T:xadMasterOut", MODE_READWRITE)))
      {
        Seek((BPTR)fh, 0, OFFSET_END);
      }
      else
        function = 0;
    }
#else
    FILE *fh = NULL;

    switch(function)
    {
    case normfunc: fh = fopen(".libxad-debug", "a"); break;
    case outfunc: default: fh = stdout; break;
    case errfunc: fh = stderr; break;
    }
#endif

    if(function)
    {
#ifdef AMIGA
      if(!(mode & (DEBUGFLAG_CONTINUE|DEBUGFLAG_CONTINUEEND)))
      {
        i = (xadUINT32) FindTask(0);
        OutputDebugArgs("XadM(%08lx):", (putchtype) function, fh, i);
      }
#endif

      OutputDebugVA(fmt, (putchtype) function, fh, data);
      if(!(mode & (DEBUGFLAG_CONTINUESTART|DEBUGFLAG_CONTINUE))
      || (mode & DEBUGFLAG_CONTINUEEND))
        OutputDebug("\n", (putchtype) function, fh);

#ifdef DEBUG
      if(mode & DEBUGFLAG_TAGLIST)
      {
        xadTAGPTR ti;
        while((ti = NextTagItem(&tags)))
        {
          xadUINT32 i[2], dmode = 0;
          const xadSTRING *s;

          /* dmode == 1 - BOOL data, dmode == 2 - unknown, dmode == 3 - error text */
          switch(ti->ti_Tag)
          {
          case XAD_INSIZE:             s = "XAD_INSIZE, %lu"; break;
          case XAD_INFILENAME:         s = "XAD_INFILENAME, \"%s\" ($%08lx)"; break;
          case XAD_INFILEHANDLE:       s = "XAD_INFILEHANDLE, $%08lx"; break;
          case XAD_INMEMORY:           s = "XAD_INMEMORY, $%08lx"; break;
          case XAD_INHOOK:             s = "XAD_INHOOK, $%08lx"; break;
          case XAD_INSPLITTED:         s = "XAD_INSPLITTED, $%08lx"; break;
          case XAD_INDISKARCHIVE:      s = "XAD_INDISKARCHIVE, $%08lx"; break;
          case XAD_INXADSTREAM:        s = "XAD_INXADSTREAM, $%08lx"; break;
#ifdef AMIGA
          case XAD_INDEVICE:           s = "XAD_INDEVICE, $%08lx"; break;
#endif
          case XAD_OUTSIZE:            s = "XAD_OUTSIZE, %lu"; break;
          case XAD_OUTFILENAME:        s = "XAD_OUTFILENAME, \"%s\" ($%08lx)"; break;
          case XAD_OUTFILEHANDLE:      s = "XAD_OUTFILEHANDLE, $%08lx"; break;
          case XAD_OUTMEMORY:          s = "XAD_OUTMEMORY, $%08lx"; break;
          case XAD_OUTHOOK:            s = "XAD_OUTHOOK, $%08lx"; break;
#ifdef AMIGA
          case XAD_OUTDEVICE:          s = "XAD_OUTDEVICE, $%08lx"; break;
#endif
          case XAD_OUTXADSTREAM:       s = "XAD_OUTXADSTREAM, $%08lx"; break;
          case XAD_OBJNAMESIZE:        s = "XAD_OBJNAMESIZE, %lu"; break;
          case XAD_OBJCOMMENTSIZE:     s = "XAD_OBJCOMMENTSIZE, %lu"; break;
          case XAD_OBJBLOCKENTRIES:    s = "XAD_OBJBLOCKENTRIES, %lu"; break;
          case XAD_OBJPRIVINFOSIZE:    s = "XAD_OBJPRIVINFOSIZE, %lu"; break;
          case XAD_NOEXTERN:           s = "XAD_NOEXTERN, %s"; dmode = 1; break;
          case XAD_PASSWORD:           s = "XAD_PASSWORD, \"%s\" ($%08lx)"; break;
          case XAD_ENTRYNUMBER:        s = "XAD_ENTRYNUMBER, %lu"; break;
          case XAD_PROGRESSHOOK:       s = "XAD_PROGRESSHOOK, $%08lx"; break;
          case XAD_OVERWRITE:          s = "XAD_OVERWRITE, %s"; dmode = 1; break;
#ifdef AMIGA
          case XAD_IGNOREGEOMETRY:     s = "XAD_IGNOREGEOMETRY, %s"; dmode = 1; break;
          case XAD_USESECTORLABELS:    s = "XAD_USESECTORLABELS, %s"; dmode = 1; break;
#endif
          case XAD_LOWCYLINDER:        s = "XAD_LOWCYLINDER, %lu"; break;
          case XAD_HIGHCYLINDER:       s = "XAD_HIGHCYLINDER, %lu"; break;
#ifdef AMIGA
          case XAD_VERIFY:             s = "XAD_VERIFY, %s"; dmode = 1; break;
#endif
          case XAD_NOKILLPARTIAL:      s = "XAD_NOKILLPARTIAL, %s"; dmode = 1; break;
#ifdef AMIGA
          case XAD_FORMAT:             s = "XAD_FORMAT, %s"; dmode = 1; break;
#endif
          case XAD_MAKEDIRECTORY:      s = "XAD_MAKEDIRECTORY, %s"; dmode = 1; break;
          case XAD_DATEUNIX:           s = "XAD_DATEUNIX, %ld"; break;
          case XAD_DATEAMIGA:          s = "XAD_DATEAMIGA, %ld"; break;
          case XAD_DATECURRENTTIME:    s = "XAD_DATECURRENTTIME"; break;
          case XAD_DATEDATESTAMP:      s = "XAD_DATEDATESTAMP, $%08lx"; break;
          case XAD_DATEXADDATE:        s = "XAD_DATEXADDATE, $%08lx"; break;
          case XAD_DATECLOCKDATA:      s = "XAD_DATECLOCKDATA, $%08lx"; break;
          case XAD_DATEMSDOS:          s = "XAD_DATEMSDOS, $%08lx"; break;
          case XAD_DATEMAC:            s = "XAD_DATEMAC, $%08lx"; break;
          case XAD_DATECPM:            s = "XAD_DATECPM, $%08lx"; break;
          case XAD_DATECPM2:           s = "XAD_DATECPM2, $%08lx"; break;
          case XAD_GETDATEUNIX:        s = "XAD_GETDATEUNIX, $%08lx"; break;
          case XAD_GETDATEAMIGA:       s = "XAD_GETDATEAMIGA, $%08lx"; break;
#ifdef AMIGA
          case XAD_GETDATEDATESTAMP:   s = "XAD_GETDATEDATESTAMP, $%08lx"; break;
#endif
          case XAD_GETDATEXADDATE:     s = "XAD_GETDATEXADDATE, $%08lx"; break;
#ifdef AMIGA
          case XAD_GETDATECLOCKDATA:   s = "XAD_GETDATECLOCKDATA, $%08lx"; break;
#endif
          case XAD_GETDATEMSDOS:       s = "XAD_GETDATEMSDOS, $%08lx"; break;
          case XAD_GETDATEMAC:         s = "XAD_GETDATEMAC, $%08lx"; break;
          case XAD_GETDATECPM:         s = "XAD_GETDATECPM, $%08lx"; break;
          case XAD_GETDATECPM2:        s = "XAD_GETDATECPM2, $%08lx"; break;
          case XAD_PROTAMIGA:          s = "XAD_PROTAMIGA, $%08lx"; break;
          case XAD_PROTUNIX:           s = "XAD_PROTUNIX, $%08lx"; break;
          case XAD_PROTMSDOS:          s = "XAD_PROTMSDOS, $%08lx"; break;
          case XAD_PROTFILEINFO:       s = "XAD_PROTFILEINFO, $%08lx"; break;
          case XAD_GETPROTAMIGA:       s = "XAD_GETPROTAMIGA, $%08lx"; break;
          case XAD_GETPROTUNIX:        s = "XAD_GETPROTUNIX, $%08lx"; break;
          case XAD_GETPROTMSDOS:       s = "XAD_GETPROTMSDOS, $%08lx"; break;
          case XAD_GETPROTFILEINFO:    s = "XAD_GETPROTFILEINFO, $%08lx"; break;
          case XAD_MAKEGMTDATE:        s = "XAD_MAKEGMTDATE, %s", dmode = 1; break;
          case XAD_MAKELOCALDATE:      s = "XAD_MAKELOCALDATE, %s", dmode = 1; break;
          case XAD_STARTCLIENT:        s = "XAD_STARTCLIENT, $%08lx"; break;
          case XAD_NOEMPTYERROR:       s = "XAD_NOEMPTYERROR, %s"; dmode = 1; break;
          case XAD_ARCHIVEINFO:        s = "XAD_ARCHIVEINFO, $%08lx"; break;
          case XAD_WASERROR:           s = "XAD_WASERROR, \"%s\" (%ld)"; dmode = 3; break;
          case XAD_SECTORLABELS:       s = "XAD_SECTORLABELS, $%08lx"; break;
          case XAD_INSERTDIRSFIRST:    s = "XAD_INSERTDIRSFIRST, %s"; dmode = 1; break;
          case XAD_SETINPOS:           s = "XAD_SETINPOS, %ld"; break;
          case XAD_IGNOREFLAGS:        s = "XAD_IGNOREFLAGS, $%08lx"; dmode = 100; break;
          case XAD_ONLYFLAGS:          s = "XAD_ONLYFLAGS, $%08lx"; dmode=100; break;
          case XAD_ERRORCODE:          s = "XAD_ERRORCODE, $%08lx"; break;
          case XAD_PATHSEPERATOR:      s = "XAD_PATHSEPERATOR, $%08lx"; break;
          case XAD_CHARACTERSET:       s = "XAD_CHARACTERSET, %ld (%s)"; dmode = 4; break;
          case XAD_STRINGSIZE:         s = "XAD_STRINGSIZE, %ld"; break;
          case XAD_CSTRING:            s = "XAD_CSTRING, $%08lx"; break;
          case XAD_PSTRING:            s = "XAD_PSTRING, $%08lx"; break;
          case XAD_XADSTRING:          s = "XAD_XADSTRING, $%08lx"; break;
          case XAD_ADDPATHSEPERATOR:   s = "XAD_ADDPATHSEPERATOR, %s"; dmode = 1; break;
          case XAD_NOLEADINGPATH:      s = "XAD_NOLEADINGPATH, %s"; dmode = 1; break;
          case XAD_NOTRAILINGPATH:     s = "XAD_NOTRAILINGPATH, %s"; dmode = 1; break;
          case XAD_MASKCHARACTERS:     s = "XAD_MASKCHARACTERS, $%08lx"; break;
          case XAD_MASKINGCHAR:        s = "XAD_MASKINGCHAR, '%lc'"; break;
          case XAD_REQUIREDBUFFERSIZE: s = "XAD_REQUIREDBUFFERSIZE, $%08lx"; break;
          case XAD_USESKIPINFO:        s = "XAD_USESKIPINFO, %s"; dmode = 1; break;
          case XAD_EXTENSION:          s = "XAD_EXTENSION, \"%s\" ($%08lx)"; break;
          default:                     s = "$%08lx, $%08lx"; dmode = 2; break;
          }
          switch(dmode)
          {
          case 1: i[0] = ti->ti_Data ? (xadUINT32) "TRUE" : (xadUINT32) "FALSE"; break;
          case 2: i[0] = ti->ti_Tag; i[1] = ti->ti_Data; break;
          #ifdef AMIGA
          case 3: i[0] = (xadUINT32) xadGetErrorText(XADM ti->ti_Data); i[1] = ti->ti_Data; break;
          #else
          /* Special case: We pass a NULL to xadGetErrorText() since we don't have XMB as a global
             variable in Unix. xadGetErrorText() will make an exception for this. */
          case 3: i[0] = (xadUINT32) xadGetErrorText(NULL, ti->ti_Data); i[1] = ti->ti_Data; break;
          #endif
          case 4: i[0] = ti->ti_Data;
            switch(i[0])
            {
            case CHARSET_HOST: i[1] = (xadUINT32) "CHARSET_HOST"; break;
            case CHARSET_UNICODE_UCS2_HOST: i[1] = (xadUINT32) "CHARSET_UNICODE_UCS2_HOST"; break;
            case CHARSET_UNICODE_UCS2_BIGENDIAN: i[1] = (xadUINT32) "CHARSET_UNICODE_UCS2BIGENDIAN"; break;
            case CHARSET_UNICODE_UCS2_LITTLEENDIAN: i[1] = (xadUINT32) "CHARSET_UNICODE_UCS2_LITTLEENDIAN"; break;
            case CHARSET_UNICODE_UTF8: i[1] = (xadUINT32) "CHARSET_UNICODE_UTF8"; break;
            case CHARSET_AMIGA: i[1] = (xadUINT32) "CHARSET_AMIGA"; break;
            case CHARSET_MSDOS: i[1] = (xadUINT32) "CHARSET_MSDOS"; break;
            case CHARSET_MACOS: i[1] = (xadUINT32) "CHARSET_MACOS"; break;
            case CHARSET_C64: i[1] = (xadUINT32) "CHARSET_C64"; break;
            case CHARSET_ATARI_ST: i[1] = (xadUINT32) "CHARSET_ATARI_ST"; break;
            case CHARSET_WINDOWS: i[1] = (xadUINT32) "CHARSET_WINDOWS"; break;
            case CHARSET_ASCII: i[1] = (xadUINT32) "CHARSET_ASCII"; break;
            case CHARSET_ISO_8859_1: i[1] = (xadUINT32) "CHARSET_ISO_8859_1"; break;
            case CHARSET_ISO_8859_15: i[1] = (xadUINT32) "CHARSET_ISO_8859_15"; break;
            case CHARSET_ATARI_ST_US: i[1] = (xadUINT32) "CHARSET_ATARI_ST_US"; break;
            case CHARSET_PETSCII_C64_LC: i[1] = (xadUINT32) "CHARSET_PETSCII_C64_LC"; break;
            case CHARSET_CODEPAGE_437: i[1] = (xadUINT32) "CHARSET_CODEPAGE_437"; break;
            case CHARSET_CODEPAGE_1252: i[1] = (xadUINT32) "CHARSET_CODEPAGE_1252"; break;
            default: i[1] = (xadUINT32) "unknown"; break;
            }
            break;
          default: i[0] = i[1] = ti->ti_Data;
          }

          OutputDebug("   ", (putchtype) function, fh);
          OutputDebugArgs(s, (putchtype) function, fh, i[0], i[1]);
          if(dmode >= 100 && (Flags & DEBUGFLAG_FLAGS))
          {
            OutputDebug(" ("/*)*/, (putchtype) function, fh);
            switch(dmode)
            {
            case 100:
              i[1] = PrintFlag(XADCF_FILEARCHIVER, i[1]);
              i[1] = PrintFlag(XADCF_DISKARCHIVER, i[1]);
              i[1] = PrintFlag(XADCF_EXTERN, i[1]);
              i[1] = PrintFlag(XADCF_FILESYSTEM, i[1]);
              i[1] = PrintFlag(XADCF_NOCHECKSIZE, i[1]);
              i[1] = PrintFlag(XADCF_DATACRUNCHER, i[1]);
              i[1] = PrintFlag(XADCF_EXECRUNCHER, i[1]);
              i[1] = PrintFlag(XADCF_ADDRESSCRUNCHER, i[1]);
              i[1] = PrintFlag(XADCF_LINKER, i[1]);
              i[1] = PrintFlag(XADCF_FREESPECIALINFO, i[1]);
              i[1] = PrintFlag(XADCF_FREESKIPINFO, i[1]);
              i[1] = PrintFlag(XADCF_FREETEXTINFO, i[1]);
              i[1] = PrintFlag(XADCF_FREETEXTINFOTEXT, i[1]);
              i[1] = PrintFlag(XADCF_FREEFILEINFO, i[1]);
              i[1] = PrintFlag(XADCF_FREEDISKINFO, i[1]);
            }
            if(i[1])
            {
              OutputDebugArgs("$%lx", (putchtype) function, fh, i[1]);
            }
            OutputDebug(/*(*/")", (putchtype) function, fh);
          }
          OutputDebug("\n", (putchtype) function, fh);
        }
        OutputDebug("   TAG_DONE\n", (putchtype) function, fh);
      }
#endif
    }

#ifdef AMIGA
    if(fh)
      Close((BPTR)fh);
#else
    if(fh && function == normfunc)
      fclose(fh);
#endif
  }
#ifdef AMIGA
  Permit();
#endif
}

#endif /* XADMASTER_DEBUG_C */
