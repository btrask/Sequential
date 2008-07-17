/* Wrapster file archiver client for XAD.
 * Copyright (C) 2000-2002 Stuart Caie <kyzer@4u.net>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/* Wrapster is a way of using the Napster MP3 sharing system to not only
 * share MP3s, but any files you like.
 * See http://www.unwrapper.com/ for more information, or do a Google
 * search on "Wrapster".
 *
 * The CRC32 feature of Wrapster is ignored completely, for two reasons:
 * - the Wrapster authors haven't told anybody what the CRC calculation is
 * - because of this, other wrapper authors have used different CRCs!!!!
 * Therefore, there's no real point checking.
 */

/* From the Wrapster 2.0 .HLP file:
 * Wrapster File Format for v1.0 and v2.0
 *
 * Ok... here is the official specification for the layout of a Wrapster
 * file. This section is intended for programmers and anyone who might be
 * curious about how this whole thing works. The reasons for including this
 * specification is to encourage other programmers to write their own
 * Wrapster clones for other Operating Systems, or to extend the features
 * of the Windows version of Wrapster itself. If you extend the features of
 * Wrapster, use some of the unused bytes so that your client can easily
 * identify those files which it creates.
 * 
 * A Wrapster file will have the following format on disk:
 * 
 * Header
 *   FrameHeader           4 bytes         0xFF, 0xFB, 0x18, 0x0C
 *   Reserved (Unused)     6 bytes
 *   Signature             10 bytes        "wrapster"#0#0
 *   Version               8 bytes         "2.0"#0#0#0#0#0
 *   FileCount             4 bytes
 * 
 * Wrapster File Entry
 * 
 * Immediately following the header of the file you will find FileCount
 * entries each containing the following data
 * 
 *   OriginalFileName      256 bytes
 *   Reserved (Unused)     32 bytes
 *   CRC32                 4 bytes
 *   Size                  4 bytes
 *   FileData              Size bytes
 * 
 * Padding
 * 
 * After all file entries in the Wrapster file you will encounter padding
 * that helps to assure that the files contained within the archive remain
 * intact. This was done as a precaution since many downloads across
 * Napster tend to get the last few bytes cut off.
 * 
 * ID3 Tag
 * The last 128 bytes of the padding contain an MP3 identification tag that
 * will show up in the play-list of programs like Winamp as an ID3 tag. You
 * may put any values in here that you like. See the MP3 specification for
 * more information.
 */

/* Wrapster v3.0 format - reverse engineered
 *
 * Format is entirely encapsulated in MP3 frames:
 * 0xFF,0xFB,0x90,0x04,{413 bytes of actual data}
 *
 * Header
 *   Reserved (Unused)     6 bytes
 *   Signature             10 bytes        "wwapster"#0#0
 *   Version               8 bytes         "3.0"#0#0#0#0#0
 *   FileCount             4 bytes
 *
 * Then follows [FileCount] file headers:
 *
 * File Header
 *   OriginalFileName      256 bytes
 *   Reserved (Unused)     32 bytes
 *   CRC32                 4 bytes
 *   Size                  4 bytes
 *
 * Then follows the file data for each file, in the same order as the
 * file headers.
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifdef DEBUG
void KPrintF(char *fmt, ...);
#define D(x) { KPrintF x ; }
#else
#define D(x)
#endif

#ifndef XADMASTERFILE
#define Wrap_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: Wrapster 1.3 (17.08.2002)";
#endif
#define WRAP_VERSION		1
#define WRAP_REVISION		3

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

#define head_magic      (0x00)
#define head_reserved   (0x04)
#define head_signature  (0x0a)
#define head_version    (0x14)
#define head_filecount  (0x1c)
#define head_SIZEOF     (0x20)

#define file_name       (0x000)
#define file_reserved   (0x100)
#define file_crc32      (0x120)
#define file_size       (0x124)
#define file_SIZEOF     (0x128)

ASM(BOOL) Wrap_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (BOOL) (d[0]==0xFF && d[1]==0xFB && d[2]==0x18 && d[3]==0x0C
                 && (memcmp(&d[10], "wrapster\0", 10) == 0)) ? 1 : 0;
}

#ifdef DEBUG
static void debug_data_dumper(unsigned char *buffer, int length) {
  int pos, x;
  char hexbuf[40], charbuf[20], digits[] = "0123456789ABCDEF";

  for (pos = 0; length > 0; length -= 16, pos += 16) {
    char *hb = hexbuf, *cb = charbuf;
    int y = 0;
    for (x = (length > 15) ? 0 : 16-length; x < 16; x++) {
      int c = *buffer++;
      if (y++ & 0x3 == 0) *hb++ = ' ';
      *hb++ = digits[(c>>4) & 0xf];
      *hb++ = digits[c & 0xf];
      *cb++ = (c>=32 && c<127) ? (char) c : '.';
    }
    *hb = *cb = '\0';
    KPrintF("%04lx:%-38s%s\n", pos, hexbuf, charbuf);
    /*printf("%04x:%-38s%s\n", pos, hexbuf, charbuf);*/
  }
}
#endif

ASM(BOOL) Wrap3_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (BOOL) (d[0]==0xFF && d[1]==0xFB && d[2]==0x90 && d[3]==0x04
                 && (memcmp(&d[10], "wwapster\0", 10) == 0)) ? 1 : 0;
}

#define TRUE_OFFSET(x) (x + (((x/413)+1)*4))

ASM(LONG) Wrap_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE buf[file_SIZEOF], is_v3;
  struct xadSkipInfo *slink = NULL,  *si;
  struct xadFileInfo *fi;
  ULONG numfiles, offset, bytesread, offset_track;
  LONG err = XADERR_OK;

  struct TagItem nametags[] = {
    { XAD_CHARACTERSET, CHARSET_WINDOWS },
    { XAD_STRINGSIZE, 256 },
    { XAD_CSTRING, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct TagItem tags[] = {
    { XAD_USESKIPINFO, 1 },
    { TAG_DONE, 0 }
  };

  struct TagItem addtags[] = {
    { XAD_SETINPOS, 0 },
    { XAD_USESKIPINFO, 1 },
    { TAG_DONE, 0 }
  };

  /* read the file header */
  if ((err = xadHookAccess(XADAC_READ, head_SIZEOF, buf, ai))) return err;
bytesread=head_SIZEOF;

  /* is this a wrapster v3 file? */
  is_v3 = (buf[2] == 0x90);

  /* skip all the mp3 frame headers */
  if (is_v3) {
    for (numfiles = ai->xai_InSize / 417; numfiles--; offset += 417) {
      if (!(si = (struct xadSkipInfo *) xadAllocObjectA(XADOBJ_SKIPINFO,0)))
        return XADERR_NOMEMORY;
      si->xsi_Position = offset;
      si->xsi_SkipSize = 4;
      if (slink) slink->xsi_Next = si; else ai->xai_SkipInfo = si;
      slink = si;
    }
  }

  /* check the version - is it "1.0", "2.0" or "3.0" ? */
  if (buf[head_version] < '1' || buf[head_version] > '3') {
    return XADERR_DATAFORMAT;
  }

  /* get the number of files in this archive */
  numfiles = EndGetI32(&buf[head_filecount]);

  if (is_v3) {
    /* offset of the file data, NOT counting the mp3 headers */
    offset = (head_SIZEOF-4) + (file_SIZEOF * numfiles);
offset_track = head_SIZEOF-4;
  }

  while (numfiles-- && ((ai->xai_InPos+file_SIZEOF) < ai->xai_InSize)) {
    D(("actual header offset=%ld, should be %ld\n",ai->xai_InPos,TRUE_OFFSET(offset_track)))
    
    /* read the file header */
    if ((err = xadHookTagAccessA(XADAC_READ, file_SIZEOF, buf, ai, tags))) {
      break;
    }

    /* allocate a file entry */
    if (!(fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO,NULL))) {
      err = XADERR_NOMEMORY;
      break;
    }

    fi->xfi_Size  = fi->xfi_CrunchSize = EndGetI32(&buf[file_size]);
    fi->xfi_Flags = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
    if (is_v3) {
      fi->xfi_DataPos = offset + (((offset/413)+1)*4);
      offset += fi->xfi_Size;
    }
    else {
      fi->xfi_DataPos = ai->xai_InPos;
    }

#ifdef DEBUG
  debug_data_dumper(buf, file_SIZEOF);
#endif
    offset_track += file_SIZEOF;
    D(("after read=%ld, should be %ld\n",ai->xai_InPos,TRUE_OFFSET(offset_track)))

    /* copy filename (and convert if necessary) */
    nametags[2].ti_Data = (ULONG) &buf[file_name];
    if (!(fi->xfi_FileName = xadConvertNameA(CHARSET_HOST, nametags))) {
      err = XADERR_NOMEMORY;
      break;
    }

    /* fill in today's date */
    datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
    xadConvertDatesA(datetags);

    addtags[0].ti_Data = ai->xai_InPos + ((is_v3) ? 0 : fi->xfi_Size);
    if ((err = xadAddFileEntryA(fi, ai, addtags))) break;
  }

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

ASM(LONG) Wrap_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct TagItem tags[] = {
    { XAD_USESKIPINFO, 1 },
    { TAG_DONE, 0 }
  };
  return xadHookTagAccessA(XADAC_COPY,ai->xai_CurFile->xfi_Size,NULL,ai,tags);
}

const struct xadClient Wrap3_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 12,
  WRAP_VERSION, WRAP_REVISION,
  32, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO |
      XADCF_FREEXADSTRINGS | XADCF_FREESKIPINFO,
  0, "Wrapster 3",

  /* client functions */
  (BOOL (*)()) Wrap3_RecogData,
  (LONG (*)()) Wrap_GetInfo,
  (LONG (*)()) Wrap_UnArchive,
  (void (*)()) NULL
};

const struct xadClient Wrap_Client = {
  (struct xadClient *) &Wrap3_Client, XADCLIENT_VERSION, 12,
  WRAP_VERSION, WRAP_REVISION,
  32, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "Wrapster",

  /* client functions */
  (BOOL (*)()) Wrap_RecogData,
  (LONG (*)()) Wrap_GetInfo,
  (LONG (*)()) Wrap_UnArchive,
  NULL
};
