#ifndef XADMASTER_RPM_C
#define XADMASTER_RPM_C

/*  $Id: RPM.c,v 1.8 2005/06/23 14:54:41 stoecker Exp $
    RPM Package Manager (RPM) extractor

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
    Client Copyright (C) 2000 Stuart Caie <kyzer@4u.net>

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

/* RPM is the concatenation of two things - some tag-based headers, and
 * an archive. The headers are stored in central databases on people's
 * machines and places like rpmfind.net. The archive is a gzip compressed
 * cpio archive. All this client does is skip past the headers and then
 * pretend to be just like the gzip slave (as far as possible)
 */

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 11
#endif

XADCLIENTVERSTR("RPM 1.3 (04.04.2004)")

#define RPM_VERSION     1
#define RPM_REVISION    3

#define RPMSKIP(offset) if ((err = xadHookAccess(XADM XADAC_INPUTSEEK, \
  (xadUINT32)(offset), NULL, ai))) goto exit_handler
#define RPMSEEK(offset) RPMSKIP((offset) - ai->xai_InPos)
#define RPMREAD(buffer,length) if ((err = xadHookAccess(XADM XADAC_READ, \
  (xadUINT32)(length), (xadPTR)(buffer), ai))) goto exit_handler
#define RPMALLOC(t,v,l) \
  if (!((v) = (t) xadAllocVec(XADM (l),0))) RPMERROR(NOMEMORY)
#define RPMALLOCOBJ(t,v,kind,tags) \
  if (!((v) = (t) xadAllocObjectA(XADM (kind),(tags)))) RPMERROR(NOMEMORY)
#define RPMFREE(obj) xadFreeObjectA(XADM (obj),NULL)
#define RPMERROR(error) { err = XADERR_##error; goto exit_handler; }

XADRECOGDATA(RPM) {
  return (xadBOOL) (data[0]==0xED && data[1]==0xAB && data[2]==0xEE && data[3]==0xDB);
}

static const xadSTRPTR RPM_arch[] = {
  ".i386", ".alpha", ".sparc", ".mips", ".ppc", ".m68k",
  ".sgi", ".rs6000", "", ".sparc64", ".mips", ".arm"
};

XADGETINFO(RPM) {
  xadUINT8 *buffer;
  xadSTRPTR fname;
  struct xadArchiveInfo *ai2 = NULL;
  struct xadFileInfo *fi;
  xadINT32 err = XADERR_OK;
  int version, namelen;

  struct TagItem filetags[]  = {
    { XAD_OBJNAMESIZE, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct TagItem tags[] = {
    { XAD_INXADSTREAM, 0 },
    { TAG_DONE, 0 },
    { XAD_ARCHIVEINFO, 0 },
    { TAG_DONE, 0 }
  };

  tags[0].ti_Data = (xadSize) &tags[2];
  tags[2].ti_Data = (xadSize) ai;

  RPMALLOC(xadUINT8 *, buffer, 96+80); /* buffer = 96 bytes buffer for reading */
  fname = (xadSTRPTR) buffer + 96; /* fname = 80 bytes for final archive filename */

  /* read in the 'lead' of the RPM */
  RPMREAD(buffer, 96);

  /* create the archive name */
  strncpy(fname, (buffer[10]) ? (xadSTRPTR) buffer+10 : "unknown", 66);

  if (EndGetM16(buffer+6) == 1) strcat(fname, ".src");
  else {
    int arch = EndGetM16(buffer+8);
    if (arch >= 1 && arch <= 12) strcat(fname, RPM_arch[arch-1]);
  }
  strcat(fname, ".cpio");


  /* check file format version */
  version = buffer[4]; /* we support versions 2-4 only */
  if (version < 2 || version > 4) return XADERR_DATAFORMAT;

  /* check 'digital signature' version */
  switch (EndGetM16(buffer+78)) {
  case 0: /* no signature */
    break;

  case 1: /* fixed size signature */
    RPMSKIP(256);
    break;

  case 5: /* another 'header' for the sig */
    RPMREAD(buffer, 8);
    if ((xadUINT32)EndGetM32(buffer) != 0x8EADE801) return XADERR_DATAFORMAT;
    /* read tag count and data area length, skip them and align to 8 bytes */
    RPMREAD(buffer, 8);
    RPMSKIP(((16 * EndGetM32(buffer) + EndGetM32(buffer+4)) + 7) & -8);
    break;

  default: /* other versions not supported */
    return XADERR_DATAFORMAT;
  }

  /* normal header */
  if (version != 2) {
    RPMREAD(buffer, 8);
    if ((xadUINT32)EndGetM32(buffer) != 0x8EADE801) return XADERR_DATAFORMAT;
  }
  /* read tag count and data area length, skip them */
  RPMREAD(buffer, 8);
  RPMSKIP(16 * EndGetM32(buffer) + EndGetM32(buffer+4));


  /* NOW GENERATE THE FILEINFO */

  filetags[0].ti_Data = namelen = strlen(fname) + 1;
  RPMALLOCOBJ(struct xadArchiveInfo *, ai2, XADOBJ_ARCHIVEINFO, NULL);
  RPMALLOCOBJ(struct xadFileInfo *, fi, XADOBJ_FILEINFO, filetags);

  fi->xfi_Size        = fi->xfi_CrunchSize = ai->xai_InSize - ai->xai_InPos;
  fi->xfi_DataPos     = ai->xai_InPos;
  fi->xfi_Flags       = XADFIF_SEEKDATAPOS | XADFIF_NODATE;

  /* copy name */
  xadCopyMem(XADM fname, fi->xfi_FileName, (xadUINT32)namelen);

  /* fill in today's date */
  datetags[1].ti_Data = (xadSize) &fi->xfi_Date;
  xadConvertDatesA(XADM datetags);

  /* call 'get info' on embedded archive for accurate filesizes */
  if (!xadGetInfoA(XADM ai2, tags)) {
    struct xadFileInfo *fi2  = ai2->xai_FileInfo;
    if (fi2 && !fi2->xfi_Next) {
      /* get crunched and uncrunched size */
      fi->xfi_Size = fi2->xfi_Size;
      fi->xfi_CrunchSize = fi2->xfi_CrunchSize;

      /* copy the CRYPTED, NOUNCRUNCHSIZE and PARTIALFILE flags */
      fi->xfi_Flags |= fi2->xfi_Flags &
      (XADFIF_CRYPTED | XADFIF_NOUNCRUNCHSIZE | XADFIF_PARTIALFILE);
    }
    xadFreeInfo(XADM ai2);
  }

  err = xadAddFileEntryA(XADM fi, ai, NULL);

exit_handler:
  if (ai2) RPMFREE(ai2);
  if (buffer) RPMFREE(buffer);
  return err;
}

XADUNARCHIVE(RPM) {
  struct xadArchiveInfo *ai2;
  struct TagItem tags[5];
  xadINT32 err, recog = 0;

  tags[0].ti_Tag  = XAD_ARCHIVEINFO;
  tags[0].ti_Data = (xadUINT32) ai;
  tags[2].ti_Tag  = XAD_INXADSTREAM;
  tags[2].ti_Data = (xadUINT32) tags;
  tags[1].ti_Tag  = tags[3].ti_Tag = TAG_DONE;

  RPMALLOCOBJ(struct xadArchiveInfo *, ai2, XADOBJ_ARCHIVEINFO, NULL);
  if (!(err = xadGetInfoA(XADM ai2, &tags[2]))) {
    struct xadFileInfo *fi2  = ai2->xai_FileInfo;
    if (fi2 && !fi2->xfi_Next) {
      recog = 1;

      tags[2].ti_Tag  = XAD_OUTXADSTREAM; /* ti_Data is still &arcinfo tag */
      tags[3].ti_Tag  = XAD_ENTRYNUMBER;
      tags[3].ti_Data = ai2->xai_FileInfo->xfi_EntryNumber;
      tags[4].ti_Tag  = TAG_DONE;

      /* extract the first file */
      err = xadFileUnArcA(XADM ai2, &tags[2]);
    }
    else err = XADERR_DATAFORMAT;
  }
  xadFreeInfo(XADM ai2);

  /* if an error occured in 'extracting', try again 'copying' */
  if (err && recog) {
    RPMSEEK(ai->xai_CurFile->xfi_DataPos);
    err = xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_CrunchSize, NULL, ai);
  }

exit_handler:
  if (ai2) RPMFREE(ai2);
  return err;
}


XADFIRSTCLIENT(RPM) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  RPM_VERSION,
  RPM_REVISION,
  4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_RPM,
  "RPM",
  XADRECOGDATAP(RPM),
  XADGETINFOP(RPM),
  XADUNARCHIVEP(RPM),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(RPM)

#endif /* XADMASTER_RPM_C */
