#ifndef XADMASTER_TEST_C
#define XADMASTER_TEST_C

/*  $Id: TestSeek.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test client for xadHookAccessSeek

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
#include <proto/dos.h>
#include <exec/memory.h>
#include "SDI_compiler.h"

#ifndef XADMASTERFILE
#define Tar_Client		FirstClient
#define NEXTCLIENT		0
UBYTE version[] = "$VER: TestSeek 1.2 (29.08.1999)";
#endif
#define TEST_VERSION		1
#define TEST_REVISION		2

ASM(BOOL) Test_RecogData(REG(d0, ULONG size), REG(a0, STRPTR data),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  return 1;
}

struct DosLibrary *DOSBase;

void DoSeek(ULONG pos, LONG size, struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos+pos, 0, ai);
  if(ai->xai_InPos != pos)
    Printf("Normal Seek failed\n");
  xadHookAccessSkip(XADAC_INPUTSEEK, size, 0, ai);
  Printf("Seek at %04ld: was %5ld, is %5ld\n", pos, size, ai->xai_InPos-pos);
}

void DoRead(ULONG pos, LONG size, struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  APTR data;

  xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos+pos, 0, ai);
  if(ai->xai_InPos != pos)
    Printf("Normal Seek failed\n");
  if((data = xadAllocVec(size, MEMF_PUBLIC)))
  {
    xadHookAccessSkip(XADAC_READ, size, data, ai);
    Printf("Read at %04ld: was %5ld, is %5ld\n", pos, size, ai->xai_InPos-pos);
    xadFreeObjectA(data, 0);
  }
  else
    Printf("Could not get memory.\n");
}

ASM(LONG) Test_GetInfo(REG(a0, struct xadArchiveInfo *ai),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  struct xadSkipInfo *si;

  DOSBase = xadMasterBase->xmb_DOSBase;
  if((si = (struct xadSkipInfo *) xadAllocObjectA(XADOBJ_SKIPINFO, 0)))
  {
    ai->xai_SkipInfo = si;
    si->xsi_Position = 3000;
    si->xsi_SkipSize = 2000;
    Printf("Skip 2000 bytes at position 3000\n");
    if((si = (struct xadSkipInfo *) xadAllocObjectA(XADOBJ_SKIPINFO, 0)))
    {
      ai->xai_SkipInfo->xsi_Next = si;
      si->xsi_Position = 6000;
      si->xsi_SkipSize = 2000;
      Printf("Skip 2000 bytes at position 6000\n");
    }
  }
  
  DoSeek(1000, 1000, ai, xadMasterBase);
  DoSeek(1000, 2000, ai, xadMasterBase);
  DoSeek(2000, 1000, ai, xadMasterBase);
  DoSeek(2000, 2000, ai, xadMasterBase);
  DoSeek(2000, 3000, ai, xadMasterBase);
  DoSeek(2000, 4000, ai, xadMasterBase);
  DoSeek(3000, 1000, ai, xadMasterBase);
  DoSeek(3000, 2000, ai, xadMasterBase);
  DoSeek(3000, 3000, ai, xadMasterBase);
  DoSeek(3000, 4000, ai, xadMasterBase);
  DoSeek(4000, 1000, ai, xadMasterBase);
  DoSeek(4000, 2000, ai, xadMasterBase);
  DoSeek(4000, 3000, ai, xadMasterBase);
  DoSeek(5000, 1000, ai, xadMasterBase);

  DoSeek(2000, -1000, ai, xadMasterBase);
  DoSeek(6000, -2000, ai, xadMasterBase);
  DoSeek(6000, -1000, ai, xadMasterBase);
  DoSeek(7000, -1000, ai, xadMasterBase);
  DoSeek(7000, -2000, ai, xadMasterBase);
  DoSeek(8000, -3000, ai, xadMasterBase);
  DoSeek(8000, -2000, ai, xadMasterBase);
  DoSeek(8000, -1000, ai, xadMasterBase);
  DoSeek(9000, -5000, ai, xadMasterBase);
  DoSeek(9000, -4000, ai, xadMasterBase);
  DoSeek(9000, -3000, ai, xadMasterBase);
  DoSeek(9000, -2000, ai, xadMasterBase);
  DoSeek(9000, -1000, ai, xadMasterBase);

  DoRead(1000, 1000, ai, xadMasterBase);
  DoRead(2000, 1000, ai, xadMasterBase);
  DoRead(2000, 2000, ai, xadMasterBase);
  DoRead(2000, 3000, ai, xadMasterBase);
  DoRead(3000, 1000, ai, xadMasterBase);
  DoRead(3000, 2000, ai, xadMasterBase);
  DoRead(4000, 1000, ai, xadMasterBase);
  DoRead(4000, 2000, ai, xadMasterBase);
  DoRead(5000, 1000, ai, xadMasterBase);
  DoRead(5000, 2000, ai, xadMasterBase);
  DoRead(6000, 1000, ai, xadMasterBase);
  DoRead(6000, 2000, ai, xadMasterBase);

  return XADERR_NOTSUPPORTED;
}

ASM(LONG) Test_UnArchive(REG(a0, struct xadArchiveInfo *ai),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  return XADERR_NOTSUPPORTED;
}

struct xadClient FirstClient = {
0, XADCLIENT_VERSION, 3, TEST_VERSION, TEST_REVISION, 10000,
XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESKIPINFO, 0, "Test",
(BOOL (*)()) Test_RecogData, (LONG (*)()) Test_GetInfo,
(LONG (*)()) Test_UnArchive, 0};

#endif /* XADASTER_TEST_C */
