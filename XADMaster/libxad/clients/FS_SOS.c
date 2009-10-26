#ifndef XADMASTER_FS_SOS_C
#define XADMASTER_FS_SOS_C

/*  $Id: FS_SOS.c,v 1.6 2005/06/23 14:54:41 stoecker Exp $
    SanityOS filesystem client

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
    Copyright (C) 1998 and later by Kyzer/CSG <kyzer@4u.net>

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

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("FS_SOS 1.4 (22.2.2004)")

#define SOS_VERSION             1
#define SOS_REVISION            4

/* SOS disk structure:
 * Block size = 512
 *
 * Block    0: bootblock - longword 'SOS1' at offset 16
 * Blocks 1-n: SOS operating system code
 * Block    n: first directory block. first file is always "loader"
 */

struct SOSfile
{
  xadUINT8 offset[4];
  xadUINT8 size[4];
  xadUINT8 name[24];
};

struct SOSboot
{
  xadUINT8 dostype[4];
  xadUINT8 cksum[4];
  xadUINT8 magic[4];
  xadUINT8 branch[4];
  xadUINT8 id[4];       /* always 'SOS1' */
};

#define SOSSEEK1 (512 - 20 + 32)
#define SOSSEEK2 (512 - 32)

XADGETINFO(SOS)
{
  struct xadFileInfo *fi;
  struct SOSfile file;
  struct SOSboot boot;
  xadINT32 err;
  int n = 2;

  /* check the image */
  if(ai->xai_ImageInfo->xii_SectorSize != 512 || ai->xai_InSize < 2048)
    return XADERR_FILESYSTEM;

  /* check the bootblock */
  if((err = xadHookAccess(XADM XADAC_READ, 20, &boot, ai)) ||
  (err = xadHookAccess(XADM XADAC_INPUTSEEK, SOSSEEK1, 0, ai)))
    return err;

  if(EndGetM32(boot.dostype) != 0x444f5300 || EndGetM32(boot.id) != 0x534f5331)
    return XADERR_FILESYSTEM;

  /* search the first blocks for the first directory block */
  do
  {
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, SOSSEEK2, 0, ai)) ||
    (err = xadHookAccess(XADM XADAC_READ, 32, &file, ai)))
       return err;

    /* break if this is the "loader" file entry */
    if(!strncmp("loader", (const char *)file.name, 24))
      break;
  } while(++n < 35); /* block 2-29 and some security */
  if(n == 35)
    return XADERR_FILESYSTEM;

  /* main directory entry loop */
  while(!err && (n = EndGetM32(file.offset)) > 0 && file.name[0] != '\0')
  {
    if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, 25, TAG_DONE)))
    {
      fi->xfi_Flags       = XADFIF_NODATE | XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
      fi->xfi_Size        =
      fi->xfi_CrunchSize  = EndGetM32(file.size);
      fi->xfi_DataPos     = n;
      xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
      &fi->xfi_Date, TAG_DONE);
      xadCopyMem(XADM file.name, fi->xfi_FileName, 24);

      if(!(err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE)))
        err = xadHookAccess(XADM XADAC_READ, sizeof(struct SOSfile), &file, ai);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? XADERR_OK : err;
}

XADUNARCHIVE(SOS)
{
  return xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size, 0, ai);
}

XADFIRSTCLIENT(FSSOS) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SOS_VERSION,
  SOS_REVISION,
  0,
  XADCF_FILESYSTEM | XADCF_FREEFILEINFO,
  XADCID_FSSANITYOS,
  "SanityOS FS",
  NULL,
  XADGETINFOP(SOS),
  XADUNARCHIVEP(SOS),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(FSSOS)

#endif /* XADMASTER_FS_SOS_C */
