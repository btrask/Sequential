#ifndef XADMASTER_PROTECTION_C
#define XADMASTER_PROTECTION_C

/*  $Id: protection.c,v 1.6 2005/06/23 14:54:37 stoecker Exp $
    protection bit conversion

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

#include "include/functions.h"

/* Other Unix information bits */
#define UP_IFMT         00170000
#define UP_IFSOCK        0140000
#define UP_IFLNK         0120000
#define UP_IFREG         0100000
#define UP_IFBLK         0060000
#define UP_IFDIR         0040000
#define UP_IFCHR         0020000
#define UP_IFIFO         0010000

#define UP_ISLNK(m)     (((m) & UP_IFMT) == UP_IFLNK)
#define UP_ISREG(m)     (((m) & UP_IFMT) == UP_IFREG)
#define UP_ISDIR(m)     (((m) & UP_IFMT) == UP_IFDIR)
#define UP_ISCHR(m)     (((m) & UP_IFMT) == UP_IFCHR)
#define UP_ISBLK(m)     (((m) & UP_IFMT) == UP_IFBLK)
#define UP_ISFIFO(m)    (((m) & UP_IFMT) == UP_IFIFO)
#define UP_ISSOCK(m)    (((m) & UP_IFMT) == UP_IFSOCK)

#define UP_IFUID        (1<<11)
#define UP_IFGID        (1<<10)
#define UP_IFVTX        (1<<9)
/* File permissions */
#define UP_UREAD        (1<<8) /* Read by owner */
#define UP_UWRITE       (1<<7) /* Write by owner */
#define UP_UEXEC        (1<<6) /* Execute/search by owner */
#define UP_GREAD        (1<<5) /* Read by group */
#define UP_GWRITE       (1<<4) /* Write by group */
#define UP_GEXEC        (1<<3) /* Execute/search by group */
#define UP_OREAD        (1<<2) /* Read by other */
#define UP_OWRITE       (1<<1) /* Write by other */
#define UP_OEXEC        (1<<0) /* Execute/search by other */

#define MP_READONLY     (1<<0)
#define MP_HIDDEN       (1<<1)
#define MP_SYSTEM       (1<<2)
#define MP_VOLUMENAME   (1<<3) /* filesystem private */
#define MP_DIRECTORY    (1<<4) /* filesystem private */
#define MP_ARCHIVE      (1<<5)

#define AMIG_DELETE      (1<<0)  /* prevent file from being deleted */
#define AMIG_EXECUTE     (1<<1)  /* ignored by system, used by Shell */
#define AMIG_WRITE       (1<<2)  /* ignored by old filesystem */
#define AMIG_READ        (1<<3)  /* ignored by old filesystem */
#define AMIG_ARCHIVE     (1<<4)  /* cleared whenever file is changed */
#define AMIG_PURE        (1<<5)  /* program is reentrant and rexecutable */
#define AMIG_SCRIPT      (1<<6)  /* program is a script (execute) file */
#define AMIG_HOLD        (1<<7)
#define AMIG_GRP_DELETE  (1<<8)  /* Group: prevent file from being deleted */
#define AMIG_GRP_EXECUTE (1<<9)  /* Group: file is executable */
#define AMIG_GRP_WRITE   (1<<10) /* Group: file is writable */
#define AMIG_GRP_READ    (1<<11) /* Group: file is readable */
#define AMIG_OTR_DELETE  (1<<12) /* Other: prevent file from being deleted */
#define AMIG_OTR_EXECUTE (1<<13) /* Other: file is executable */
#define AMIG_OTR_WRITE   (1<<14) /* Other: file is writable */
#define AMIG_OTR_READ    (1<<15) /* Other: file is readable */

#define UNIXPROT        (AMIG_READ|AMIG_WRITE|AMIG_EXECUTE|AMIG_GRP_READ|AMIG_GRP_WRITE| \
                        AMIG_GRP_EXECUTE|AMIG_OTR_READ|AMIG_OTR_WRITE|AMIG_OTR_EXECUTE)
#define MSDOSPROT       (AMIG_READ|AMIG_WRITE|AMIG_ARCHIVE|AMIG_DELETE)

#define REVUNIXPROT     (UP_UREAD|UP_UWRITE|UP_UEXEC|UP_GREAD|UP_GWRITE|UP_GEXEC| \
                        UP_OREAD|UP_OWRITE|UP_OEXEC)
#define REVMSDOSPROT    (MP_READONLY|MP_ARCHIVE)

FUNCxadConvertProtection /* xadTAGPTR tags */
{
  xadUINT32 prot = 0, flags = 0, numres = 0;
  xadUINT8 dosprot = 0;
  xadUINT16 unxprot = 0;
  xadERROR res = XADERR_OK;
  xadTAGPTR ti, ti2 = tags;
  struct xadFileInfo *fi;

#ifdef DEBUG
  DebugTagList("xadConvertProtectionA", tags);
#endif

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_PROTAMIGA: prot = ti->ti_Data; break;
    case XAD_PROTUNIX: unxprot = ti->ti_Data; flags |= XADFIF_UNIXPROTECTION;
      /* kill old settings of supported bits */
      prot &= ~UNIXPROT;

      if(!(unxprot & UP_UREAD))         prot |= AMIG_READ;
      if(!(unxprot & UP_UWRITE))        prot |= AMIG_WRITE|AMIG_DELETE;
      if(!(unxprot & UP_UEXEC))         prot |= AMIG_EXECUTE;
      if(unxprot & UP_GREAD)            prot |= AMIG_GRP_READ;
      if(unxprot & UP_GWRITE)           prot |= AMIG_GRP_WRITE|AMIG_GRP_DELETE;
      if(unxprot & UP_GEXEC)            prot |= AMIG_GRP_EXECUTE;
      if(unxprot & UP_OREAD)            prot |= AMIG_OTR_READ;
      if(unxprot & UP_OWRITE)           prot |= AMIG_OTR_WRITE|AMIG_OTR_DELETE;
      if(unxprot & UP_OEXEC)            prot |= AMIG_OTR_EXECUTE;
      break;
    case XAD_PROTMSDOS: dosprot = ti->ti_Data; flags |= XADFIF_DOSPROTECTION;
      /* kill old settings of supported bits */
      prot &= ~MSDOSPROT;

      if(dosprot & MP_READONLY)         prot |= AMIG_WRITE|AMIG_DELETE;
      /* if(dosprot & MP_HIDDEN)        prot |= AMIG_HOLD; */
      if(!(dosprot & MP_ARCHIVE))       prot |= AMIG_ARCHIVE;

      break;
    case XAD_PROTFILEINFO: fi = (struct xadFileInfo *)(uintptr_t) ti->ti_Data;
      prot = fi->xfi_Protection;
      if(fi->xfi_Flags & XADFIF_DOSPROTECTION)
      {
        flags |= XADFIF_DOSPROTECTION;
        dosprot = fi->xfi_DosProtect & ~(MP_DIRECTORY);
        if(fi->xfi_Flags & XADFIF_DIRECTORY)
          dosprot |= MP_DIRECTORY;
      }
      if(fi->xfi_Flags & XADFIF_UNIXPROTECTION)
      {
        flags |= XADFIF_UNIXPROTECTION;
        unxprot = fi->xfi_UnixProtect;
        if(UP_ISDIR(unxprot) || UP_ISLNK(unxprot))
          unxprot &= ~(UP_IFMT);
        if(fi->xfi_Flags & XADFIF_DIRECTORY)
          unxprot |= UP_IFDIR;
        if(fi->xfi_Flags & XADFIF_LINK)
          unxprot |= UP_IFLNK;
      }
      break;
    }
  }

  /* make dos protection */
  dosprot &= ~REVMSDOSPROT;
  if(prot & AMIG_WRITE)                 dosprot |= MP_READONLY;
  /* if(prot & AMIG_HOLD)               dosprot |= MP_HIDDEN; */
  if(!(prot & AMIG_ARCHIVE))            dosprot |= MP_ARCHIVE;

  /* make unix protection */
  unxprot &= ~REVUNIXPROT;
  if(!(prot & AMIG_READ))               unxprot |= UP_UREAD;
  if(!(prot & AMIG_WRITE))              unxprot |= UP_UWRITE;
  if(!(prot & AMIG_EXECUTE))            unxprot |= UP_UEXEC;
  if(prot & AMIG_GRP_READ)              unxprot |= UP_GREAD;
  if(prot & AMIG_GRP_WRITE)             unxprot |= UP_GWRITE;
  if(prot & AMIG_GRP_EXECUTE)           unxprot |= UP_GEXEC;
  if(prot & AMIG_OTR_READ)              unxprot |= UP_OREAD;
  if(prot & AMIG_OTR_WRITE)             unxprot |= UP_OWRITE;
  if(prot & AMIG_OTR_EXECUTE)           unxprot |= UP_OEXEC;

  ti2 = tags;
  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_GETPROTAMIGA:
      if(!ti->ti_Data) res = XADERR_BADPARAMS;
      else
      {
        *((xadUINT32 *)(uintptr_t) ti->ti_Data) = prot; ++numres;
      }
      break;
    case XAD_GETPROTUNIX:
      if(!ti->ti_Data) res = XADERR_BADPARAMS;
      else
      {
        *((xadUINT32 *)(uintptr_t) ti->ti_Data) = unxprot; ++numres;
      }
      break;
    case XAD_GETPROTMSDOS:
      if(!ti->ti_Data) res = XADERR_BADPARAMS;
      else
      {
        *((xadUINT32 *)(uintptr_t) ti->ti_Data) = dosprot; ++numres;
      }
      break;
    case XAD_GETPROTFILEINFO:
      if(!ti->ti_Data) res = XADERR_BADPARAMS;
      else
      {
        fi = (struct xadFileInfo *)(uintptr_t) ti->ti_Data; ++numres;
        fi->xfi_Flags |= flags;
        fi->xfi_Protection = prot;
        fi->xfi_UnixProtect = unxprot;
        fi->xfi_DosProtect = dosprot;
      }
      break;
    }
  }

  return numres ? res : XADERR_BADPARAMS;
}
ENDFUNC

#endif  /* XADMASTER_PROTECTION_C */
