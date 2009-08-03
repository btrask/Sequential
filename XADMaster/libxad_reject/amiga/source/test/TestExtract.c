/*  $Id: TestExtract.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test program

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
#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/memory.h>
#include <dos/dosasl.h>
#include <utility/hooks.h>
#include "SDI_compiler.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

struct xadMasterBase *	xadMasterBase = 0;

#define MINPRINTSIZE	51200	/* 50KB */
#define NAMEBUFSIZE	512
#define PATBUFSIZE	(NAMEBUFSIZE*2+10)

ASM(ULONG) progrhook(REG(a0, struct Hook *), REG(a1, struct xadProgressInfo *));

struct xHookArgs {
  STRPTR name;
  ULONG disk;
  ULONG flags;
  ULONG finish;
  struct xadArchiveInfo *ai;
  ULONG lastprint;
};

int main(int argc, char **argv)
{
  struct xadMasterBase *xadmasterbase;
  struct Hook prhook;
  struct xHookArgs xh;
  struct xadArchiveInfo *ai;
  LONG i;

  if(argc != 2)
  {
    Printf("testextract <archive>\n");
    exit(0);
  }

  if((xadmasterbase = (struct xadMasterBase *) OpenLibrary("xadmaster.library", 10)))
  {
    xadMasterBase = xadmasterbase;
    xh.flags = xh.finish = xh.lastprint = xh.disk = 0;

    memset(&prhook, 0, sizeof(struct Hook));
    prhook.h_Entry = (ULONG (*)()) progrhook;
    prhook.h_Data = &xh;
    Flush(Input());
    if((ai = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO,0)))
    {
      xh.ai = ai;
      if(!(i = xadGetInfo(ai, XAD_INFILENAME, argv[1], XAD_PROGRESSHOOK, &prhook, TAG_DONE)))
        xadFreeInfo(ai);
      else
      {
        Printf("xadGetInfo returned %s%s.\n", xadGetErrorText(i), i == XADERR_FILETYPE ? ", trying as image": "");
        if(i == XADERR_FILETYPE)
        {
          xh.disk = 1;
          if(!(i = xadGetDiskInfo(ai, XAD_INFILENAME, argv[1], XAD_PROGRESSHOOK, &prhook, TAG_DONE)))
            xadFreeInfo(ai);
          else
            Printf("xadGetDiskInfo returned %s.\n", xadGetErrorText(i));
        }
      }
      xadFreeObjectA(ai, 0);
    }
    
    CloseLibrary((struct Library *)xadmasterbase);
  }
  return 0;
}

ASM(ULONG) SAVEDS progrhook(REG(a0, struct Hook *hook), REG(a1, struct xadProgressInfo *pi))
{
  STRPTR name = ((struct xHookArgs *) (hook->h_Data))->name;
  ULONG ret = 0;

  switch(pi->xpi_Mode)
  {
  case XADPMODE_ASK:
    ret |= ((struct xHookArgs *) (hook->h_Data))->flags;
    if((pi->xpi_Status & XADPIF_OVERWRITE) && !(ret & XADPIF_OVERWRITE))
    {
      LONG r;

      Printf("File '%s' already exists, overwrite? (Y|A|S|\033[1mN\033[0m|Q): ", pi->xpi_FileName);
      Flush(Output());
      SetMode(Input(), TRUE);
      r = FGetC(Input());
      SetMode(Input(), FALSE);
      switch(r)
      {
      case 'a': case 'A': ((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_OVERWRITE;
      case 'y': case 'Y': ret |= XADPIF_OVERWRITE; break;
      case 's': case 'S': ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': ((struct xHookArgs *) (hook->h_Data))->finish = 1; break;
      }
    }
    if((pi->xpi_Status & XADPIF_MAKEDIRECTORY) &&
    !(ret & XADPIF_MAKEDIRECTORY))
    {
      Printf("Directory of file '%s' does not exist, create? (Y|A|S|\033[1mN\033[0m|Q): ", name);
      Flush(Output());
      SetMode(Input(), TRUE);
      switch(FGetC(Input()))
      {
      case 'a': case 'A':
	((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_MAKEDIRECTORY;
      case 'y': case 'Y': ret |= XADPIF_MAKEDIRECTORY; break;
      case 's': case 'S': ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': ((struct xHookArgs *) (hook->h_Data))->finish = 1;
      }
      SetMode(Input(), FALSE);
    }
    break;
  case XADPMODE_PROGRESS:
    if(pi->xpi_CurrentSize - ((struct xHookArgs *) (hook->h_Data))->lastprint >= MINPRINTSIZE)
    {
      if(pi->xpi_FileInfo->xfi_Flags & XADFIF_NOUNCRUNCHSIZE)
        Printf("\r\033[KWrote %8ld bytes: %s", pi->xpi_CurrentSize, name);
      else
        Printf("\r\033[KWrote %8ld of %8ld bytes: %s",
        pi->xpi_CurrentSize, pi->xpi_FileInfo->xfi_Size, name);
      Flush(Output());
      ((struct xHookArgs *) (hook->h_Data))->lastprint = pi->xpi_CurrentSize;
    }
    break;
  case XADPMODE_END: Printf("\r\033[KWrote %8ld bytes: %s\n", pi->xpi_CurrentSize, name);
    break;
  case XADPMODE_ERROR: Printf("\r\033[K%s: %s\n", name, xadGetErrorText(pi->xpi_Error));
    break;
  case XADPMODE_NEWENTRY:
    if(pi->xpi_FileInfo)
    {
      if(pi->xpi_FileInfo->xfi_Flags & XADFIF_EXTRACTONBUILD)
      {
        ((struct xHookArgs *) (hook->h_Data))->lastprint = 0;
        ((struct xHookArgs *) (hook->h_Data))->name = pi->xpi_FileInfo->xfi_FileName;

	if(((struct xHookArgs *) (hook->h_Data))->disk)
          xadDiskFileUnArc(((struct xHookArgs *) (hook->h_Data))->ai, XAD_OUTFILENAME, pi->xpi_FileInfo->xfi_FileName,
          XAD_ENTRYNUMBER, pi->xpi_FileInfo->xfi_EntryNumber, XAD_PROGRESSHOOK, hook, TAG_DONE);
	else
          xadFileUnArc(((struct xHookArgs *) (hook->h_Data))->ai, XAD_OUTFILENAME, pi->xpi_FileInfo->xfi_FileName,
          XAD_ENTRYNUMBER, pi->xpi_FileInfo->xfi_EntryNumber, XAD_PROGRESSHOOK, hook, TAG_DONE);
      }
      else
      {
        Printf("New Entry %s added.\n", pi->xpi_FileInfo->xfi_FileName);
      }
    }
  }

  if(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C) && !(((struct xHookArgs *) (hook->h_Data))->finish)) /* clear ok flag */
    ret |= XADPIF_OK;

  return ret;
}
