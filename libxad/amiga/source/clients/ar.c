/* UNIX ar(1) file archiver client for XAD.
 * Copyright (C) 2000 Stuart Caie <kyzer@4u.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

/* this is very much based on the GNU binutils/bfd/archive.c,
 * written by Cygnus Support */

/* Assumes:
   o - all archive elements start on an even boundary, newline padded;
   o - all arch headers are char *;
   o - all arch headers are the same size (across architectures).
*/

/* Some formats provide a way to cram a long filename into the short
   (16 chars) space provided by a BSD archive.  The trick is: make a
   special "file" in the front of the archive, sort of like the SYMDEF
   entry.  If the filename is too long to fit, put it in the extended
   name table, and use its index as the filename.  To prevent
   confusion prepend the index with a space.  This means you can't
   have filenames that start with a space, but then again, many Unix
   utilities can't handle that anyway.

   This scheme unfortunately requires that you stand on your head in
   order to write an archive since you need to put a magic file at the
   front, and need to touch every entry to do so.  C'est la vie.

   We support two variants of this idea:
   The SVR4 format (extended name table is named "//"),
   and an extended pseudo-BSD variant (extended name table is named
   "ARFILENAMES/").  The origin of the latter format is uncertain.

   BSD 4.4 uses a third scheme:  It writes a long filename
   directly after the header.  This allows 'ar q' to work.
   We currently can read BSD 4.4 archives, but not write them.
*/

/* Summary of archive member names:

 Symbol table (must be first):
 "__.SYMDEF       " - Symbol table, Berkeley style, produced by ranlib.
 "/               " - Symbol table, system 5 style.

 Long name table (must be before regular file members):
 "//              " - Long name table, System 5 R4 style.
 "ARFILENAMES/    " - Long name table, non-standard extended BSD (not BSD 4.4).

 Regular file members with short names:
 "filename.o/     " - Regular file, System 5 style (embedded spaces ok).
 "filename.o      " - Regular file, Berkeley style (no embedded spaces).

 Regular files with long names (or embedded spaces, for BSD variants):
 "/18             " - SVR4 style, name at offset 18 in name table.
 "#1/23           " - Long name (or embedded paces) 23 characters long,
		      BSD 4.4 style, full name follows header.
		      Implemented for reading, not writing.
 " 18             " - Long name 18 characters long, extended pseudo-BSD.
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "SDI_compiler.h"


#ifndef XADMASTERFILE
#define ar_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: ar 1.1 (05.08.2000)";
#endif
#define AR_VERSION		1
#define AR_REVISION		1

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

#define ARMAG  "!<arch>\012"	/* For COFF and a.out archives */
#define ARMAGB "!<bout>\012"	/* For b.out archives */
#define ARFMAG "`\012"

struct ar_hdr {
  char ar_name[16];		/* name of this member */
  char ar_date[12];		/* file mtime */
  char ar_uid[6];		/* owner uid; printed as decimal */
  char ar_gid[6];		/* owner gid; printed as decimal */
  char ar_mode[8];		/* file mode, printed as octal   */
  char ar_size[10];		/* file size, printed as decimal */
  char ar_fmag[2];		/* should contain ARFMAG */
};

#define AR_HDRSIZE (sizeof(struct ar_hdr))

char *ar_memchr(char *src, int c, int length) {
  while (length--) if (*src == c) return src; else src++;
  return NULL;
}

ULONG ar_readnum(char *str, int strl, int base) {
  ULONG result=0;
  int nums=0;
  
  while (strl--) {
    char c = *str++;
    if (nums) {
      if (c < '0' || c > '9') break;
      result *= base;
      result += c - '0';
    }
    else if (c >= '0' && c <= '9') nums=1, result = c - '0';
  }
  return result;
}


ASM(BOOL) ar_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (BOOL) (strncmp(d, ARMAG, 8) == 0 || strncmp(d, ARMAGB, 8) == 0);
}

ASM(LONG) ar_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE *ext_names = NULL, *bsd_name = NULL, *namep, *pend;
  ULONG filenum = 1, skiplen = 8, namelen, extnameslen;
  struct xadFileInfo *link = NULL,  *fi;
  LONG err = XADERR_OK;
  struct ar_hdr hdr;

  struct TagItem filetags[]  = {
    { XAD_OBJNAMESIZE, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATEUNIX, 0 },
    { XAD_GETDATEXADDATE, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem prottags[] = {
    { XAD_PROTUNIX, 0 },
    { XAD_GETPROTAMIGA, 0 },
    { TAG_DONE, 0 }
  };

  while (1) {
    /* normal exit-point - will we skip out of the file? */
    if ((ai->xai_InPos+skiplen) & 1) skiplen++; /* alignment */
    if ((ai->xai_InPos+skiplen+AR_HDRSIZE) >= ai->xai_InSize) break;

    /* skip to next header, read it in (note initial skip of 8 bytes) */
    if ((err = xadHookAccess(XADAC_INPUTSEEK, skiplen, NULL, ai))) break;
    if ((err = xadHookAccess(XADAC_READ, AR_HDRSIZE, (APTR)&hdr, ai))) break;

    /* check magic header number */
    if (hdr.ar_fmag[0] != 0x60 || hdr.ar_fmag[1] != 0x0A) {
      err = XADERR_DATAFORMAT; break;
    }

    /* ignore the symbol offsets magic file */
    if (filenum == 1
    && (strncmp(hdr.ar_name, "__.SYMDEF       ", 16) == 0
    ||  strncmp(hdr.ar_name, "/               ", 16) == 0)) {
      skiplen = ar_readnum(hdr.ar_size, 10, 10);
      continue;
    }

    /* read in extended filenames file */
    if (filenum <= 2
    && (strncmp(hdr.ar_name, "ARFILENAMES/    ", 16) == 0
    ||  strncmp(hdr.ar_name, "//              ", 16) == 0)) {

      skiplen = 0; /* because we're reading it in, not skipping it */
      extnameslen = namelen = ar_readnum(hdr.ar_size, 10, 10);
      if (!namelen) { err = XADERR_DATAFORMAT; break; }

      ext_names = xadAllocVec(namelen, 0);
      if (!ext_names) { err = XADERR_NOMEMORY; break; }
      if ((err = xadHookAccess(XADAC_READ, namelen, (APTR) ext_names, ai))) {
        break;
      }

      /* turn newlines or slash-newlines to null bytes */
      for (namep = ext_names; namelen--; namep++) {
        if (*namep == 0x0A) namep[(namep[-1] == '/') ? -1 : 0] = '\0';
      }
      continue;
    }
    

    /* 'real' filenames processing */
    namep = NULL;

    /* if there is an extended names file read in, and the name begins
     * with a slash or space (except when it ends in a slash)
     */
    if (ext_names && (hdr.ar_name[0] == '/' || (hdr.ar_name[0] == ' '
    && !ar_memchr(hdr.ar_name, '/', 16)))) {

      /* extended filename in extended filenames header */
      namelen = ar_readnum(&hdr.ar_name[1], 15, 10); /* name offset */
      if (namelen < extnameslen) {
        namep = ext_names + namelen;
        namelen = strlen(namep);
      }
    }
    /* if the name begins "#1/x" where x is a number */
    else if (hdr.ar_name[0] == '#'
         &&  hdr.ar_name[1] == '1'
         &&  hdr.ar_name[2] == '/'
         && (hdr.ar_name[3] >= '0' && hdr.ar_name[3] <= '9') ) {

      /* extended filename after header */
      if ((namelen = ar_readnum(&hdr.ar_name[3], 13, 10))) {
        if (namelen < ar_readnum(hdr.ar_size, 10, 10)) {
          /* allocate space to read in name */
          bsd_name = xadAllocVec(namelen, 0);
          if (!bsd_name) { err = XADERR_NOMEMORY; break; }

          /* read in extended name */
          if ((err = xadHookAccess(XADAC_READ, namelen, (APTR) bsd_name, ai)))
            break;

          namep = bsd_name;
        }
      }
    }

    if (!namep) {
      /* normal filename */
      namep = hdr.ar_name;

      /* look for terminator - null, slash or space (in that order) */
      if (!(pend = ar_memchr(namep, '\0', 16))
      &&  !(pend = ar_memchr(namep, '/',  16)))
            pend = ar_memchr(namep, ' ',  16);

      namelen = (pend) ? pend-namep : 16;
    }


    filetags[0].ti_Data = namelen + 1;
    fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, filetags);
    if (!fi) { err = XADERR_NOMEMORY; break; }

    fi->xfi_EntryNumber = filenum++;
    fi->xfi_OwnerUID    = ar_readnum(hdr.ar_uid, 6, 10);
    fi->xfi_OwnerGID    = ar_readnum(hdr.ar_gid, 6, 10);
    fi->xfi_Size        = ar_readnum(hdr.ar_size, 10, 10);
    fi->xfi_Flags       = XADFIF_SEEKDATAPOS;
    fi->xfi_DataPos     = ai->xai_InPos;

    /* copy filename */
    xadCopyMem(namep, fi->xfi_FileName, namelen);
    fi->xfi_FileName[namelen] = '\0';

    /* bsd extended filename consumes part of the file size! */
    if (bsd_name) {
      xadFreeObjectA(bsd_name, NULL); bsd_name = NULL;
      fi->xfi_Size -= namelen;
    }
    fi->xfi_CrunchSize  = skiplen = fi->xfi_Size;

    /* fix MS-DOS filenames */
    for (namep = fi->xfi_FileName; namelen--; namep++) {
      if (*namep == '\\') *namep = '/';
    }

    prottags[0].ti_Data = ar_readnum(hdr.ar_mode, 8, 8);
    prottags[1].ti_Data = (ULONG) &fi->xfi_Protection;
    xadConvertProtectionA(prottags);

    datetags[0].ti_Data = ar_readnum(hdr.ar_date, 12, 10);
    datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
    xadConvertDatesA(datetags);

    if (link) link->xfi_Next = fi; else ai->xai_FileInfo = fi;
    link = fi;
  }

  if (ext_names) xadFreeObjectA(ext_names, NULL);
  if (bsd_name)  xadFreeObjectA(bsd_name,  NULL);

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

ASM(LONG) ar_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  return xadHookAccess(XADAC_COPY, ai->xai_CurFile->xfi_Size, NULL, ai);
}

const struct xadClient ar_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 6, AR_VERSION, AR_REVISION,
  8, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO,
  0, "Ar",

  /* client functions */
  (BOOL (*)()) ar_RecogData,
  (LONG (*)()) ar_GetInfo,
  (LONG (*)()) ar_UnArchive,
  NULL
};
