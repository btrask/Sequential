#ifndef XADMASTER_EXAMPLE_C
#define XADMASTER_EXAMPLE_C

/*  $Id: ExampleClient.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    Example disk or file archiver client

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
#include <dos/dos.h>
#include "SDI_compiler.h"

#ifndef XADMASTERFILE
#define Example_Client		FirstClient
#define NEXTCLIENT		0
#define XADMASTERVERSION	11
UBYTE version[] = "$VER: Example 1.4 (02.12.2001)";
#endif
#define EXAMPLE_VERSION		1
#define EXAMPLE_REVISION	4

/* This is an empty example client! You should replace all "EXAMPLE"
texts with text related to your own client. */

/* NOTE: I normally use SAS-C. This compiler supports local base variables
for library calls, so all function calls to xadmaster.library can be done
using the argument passed in register A6.

If your compiler does not support that, insert a global base, rename the
argument of the functions to lower case xadmasterbase and add following
line in Example_GetInfo() function:

  xadMasterBase = xadmasterbase;

xadMasterBase also has a pointer to DOSBase and SysBase, but normally this
should not be necessary, but it is useful for debug output in test versions.
*/

/* See the included example clients as well! */

ASM(BOOL) Example_RecogData(REG(d0, ULONG size), REG(a0, STRPTR data),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  if(/* do some checks here (headerID, header checksum, ...) */)
    return 1; /* known file */
  else
    return 0; /* unknown file */
}

ASM(LONG) Example_GetInfo(REG(a0, struct xadArchiveInfo *ai),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  /* return an error code, as long as function is empty */
  return XADERR_NOTSUPPORTED;

  /* Always do this function first (after RecogData). Normally it's the
  easiest one.
  General style for file archivers:
  -Allocate "xadAllocObject(XADOBJ_FILEINFO, ...., TAG_DONE)" the
   xadFileInfo structure for every file and fill it's fields with
   correct values (date, size, protection, crunched size, flags, ...).
  -Add the allocated structure to a linked list, which is assigned to
   ai->xai_FileInfo.
   This is done using xadAddFileEntry or xadAddDiskEntry functions.
  -If an error occurs set "ai->xai_Flags & XADAIF_FILECORRUPT" or
   return the error if it is really serious. If there are already valid
   entries in linked list, there cannot be that serious!
  -Leave this function.
  General style for disk archivers:
  -Allocate "xadAllocObject(XADOBJ_DISKINFO, ...., TAG_DONE)" the
   xadDiskInfo structure for every file and fill it's fields with
   correct values (tracks, heads, flags, ...).
  -Add the allocated structure to a linked list, which is assigned to
   ai->xai_DiskInfo.
  -If there are information texts, create a linked list with xadTextInfo
   structures. These are allocated with xadAllocObjectA(XADOBJ_TEXTINFO, 0).
  -If an error occurs set "ai->xai_Flags & XADAIF_FILECORRUPT" or
   return the error if it is really serious. If there are already valid
   entries in linked list, it cannot be that serious!
  -Leave this function.

  For nearly all archivers it is necessary to store current file position
  (ai->xai_InPos), to be able to find the data in unarchive function.
  Therefor xid_DataPos and xfi_DataPos exists. You can use the flags
  XADFIF_SEEKDATAPOS or XADIF_SEEKDATAPOS and the seek is done automatically
  when unarchiving is called.

  Get data using "xadHookAccess(XADAC_READ, size, buf, ai)" and seek input
  data using "xadHookAccess(XADAC_INPUTSEEK, size, 0, ai)".
  */
}

ASM(LONG) Example_UnArchive(REG(a0, struct xadArchiveInfo *ai),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  /* return an error code, as long as function is empty */
  return XADERR_NOTSUPPORTED;

  /*
  -Either use ai->xai_CurDisk or ai->xai_CurFile and seek the input data
   to the position required to access the archived data for the wanted entry:
   "xadHookAccess(XADAC_INPUTSEEK, pos-ai->xai_InPos, 0, ai)".
   Alternatively you can use XADFIF_SEEKDATAPOS and XADIF_SEEKDATAPOS in
   GetInfo and the seek is done automatically.
  -Extract the data using XADAC_READ for reads, XADAC_WRITE for storing data
   or XADAC_COPY for copying the data directly.
  - Leave the function either returning 0 or an errorcode, which occured.
  */ 
}

ASM(void) Example_Free(REG(a0, struct xadArchiveInfo *ai),
REG(a6, struct xadMasterBase *xadMasterBase))
{
  /* This function needs to free all the stuff allocated in info or
  unarchive function. It may be called multiple times, so clear freed
  entries!
  */

  /* The following example frees file and disk archive data. It assumes,
  that disk archive information texts are allocated using xadAllocVec and all
  the other stuff (file names, comments, ...) is allocated using the tags
  of xadAllocObject function.

  If you only do that stuff, then set the responding XADCF_FREE flags and
  the master library does the stuff for you. In that case you do not even
  need that function (remove it totally!).

  In any other case you should modify that function to meet your special
  requirements. Remember. The function should leave all fields cleared!
  */

  struct xadFileInfo *fi, *fi2;
  struct xadDiskInfo *di, *di2;
  struct xadTextInfo *ti, *ti2;

  for(fi = ai->xai_FileInfo; fi; fi = fi2)
  {
    fi2 = fi->xfi_Next;
    xadFreeObjectA(fi, 0);
  }
  ai->xai_FileInfo = 0;

  for(di = ai->xai_DiskInfo; di; di = di2)
  {
    di2 = di->xdi_Next;
    
    for(ti = di->xdi_TextInfo; ti; ti = ti2)
    {
      ti2 = ti->xti_Next;
      if(ti->xti_Text)
        xadFreeObjectA(ti->xti_Text, 0);
      xadFreeObjectA(ti, 0);
    }
    xadFreeObjectA(di, 0);
  }
  ai->xai_DiskInfo = 0;
}

/* You need to complete following structure! */
const struct xadClient Example_Client = {
NEXTCLIENT, XADCLIENT_VERSION, XADMASTERVERSION, EXAMPLE_VERSION, EXAMPLE_REVISION,
/* Here the size the client really needs to detect the filetype must be
inserted */, /* XADCF_DISKARCHIVER and/or XADCF_FILEARCHIVER and some of
XADCF_FREEDISKINFO|XADCF_FREEFILEINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT */,
0 /* Type identifier. Normally should be zero */, "Example",
(BOOL (*)()) Example_RecogData, (LONG (*)()) Example_GetInfo,
(LONG (*)()) Example_UnArchive, /* 0 or (void (*)()) Example_Free */};

#endif /* XADASTER_EXAMPLE_C */
