/* id: WAD / WAD2 / PAK file archiver client for XAD.
 * Copyright (C) 2000 Stuart Caie <kyzer@4u.net>
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

/*
 * WAD header format
 * UBYTE recog[4]="IWAD" or "PWAD";
 * ULONG numentries;
 * ULONG diroffset;
 *
 * WAD2 header format
 * UBYTE recog[4]="WAD2";
 * ULONG numentries;
 * ULONG diroffset;
 *
 * PAK header format:
 * UBYTE recog[4]="PACK";
 * ULONG diroffset;
 * ULONG dirsize; (where numentries = dirsize/64)
 *
 * WAD entry format
 * ULONG offset;
 * ULONG size;
 * UBYTE name[8];
 *
 * WAD2 entry format
 * ULONG offset;
 * ULONG comp_size;
 * ULONG uncomp_size;
 * UBYTE magic_type;
 * UBYTE comp_mode; 0=none, 1=lzss
 * UWORD notused;
 * UBYTE name[16];
 *
 * PAK entries format:
 * UBYTE name[56];
 * ULONG offset;
 * ULONG size;
 *
 * all little-endian
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifndef XADMASTERFILE
#define PAK_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: id 1.0 (05.08.2000)";
#endif
#define ID_VERSION		1
#define ID_REVISION		0

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

ASM(BOOL) WAD_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (((d[0]=='P' || d[0]=='I') && d[1]=='W' && d[2]=='A' && d[3]=='D') &&
          EndGetI32(&d[4]) > 0) && (EndGetI32(&d[8]) >= 12 );
}

ASM(BOOL) WAD2_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return ((d[0]=='W' && d[1]=='A' && d[2]=='D' && d[3]=='2') &&
          EndGetI32(&d[4]) > 0 && EndGetI32(&d[8]) >= 12 );
}

ASM(BOOL) PAK_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  ULONG diroff  = EndGetI32(&d[4]);
  ULONG dirsize = EndGetI32(&d[8]);
  /* the arbitrary limit of 250Mb of PAK filesize is to stop PackDir
   * archives being recognised as PAK files. A PackDir file starts
   * 'P','A','C','K',0,[0-4],0,0,0,<ASCII text>, which leads to
   * a directory offset of $100 (perfectly valid for PAK files) and
   * a directory size of $XXXXXX00, where XX are ASCII characters,
   * therefore are around $21 to $7E each. As the value is always
   * a multiple of 64 (another thing we can't check), and we can't
   * find out in RecogData what the complete size of the file being
   * checked is (we could could check that dirsize+diroff is less
   * than that), we simply have to assume some maximum size for a
   * PAK file that would never be reached if the the MSB was an
   * ASCII character.
   */
  return ((d[0]=='P' && d[1]=='A' && d[2]=='C' && d[3]=='K') &&
          (dirsize & 0x3F)==0 && dirsize > 0 && diroff >= 12 &&
          (dirsize + diroff) < (250*1024*1024) );
}

#define ID_WAD  (0)
#define ID_WAD2 (1)
#define ID_PAK  (2)

ASM(LONG) id_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE buf[64], fmt, entrysz;
  ULONG numfiles, diroffset;
  struct xadFileInfo *fi;
  LONG err = XADERR_OK;

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct TagItem nametags[] = {
    { XAD_CHARACTERSET, CHARSET_WINDOWS },
    { XAD_STRINGSIZE, 0 },
    { XAD_CSTRING, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem addtags[] = {
    { XAD_SETINPOS, 0 },
    { TAG_DONE, 0 }
  };

  /* read the file header */
  if ((err = xadHookAccess(XADAC_READ, 12, buf, ai))) return err;
  switch (EndGetI32(&buf[0])) {
    case 0x44415750: /* pwad */
    case 0x44415749: /* iwad */
    fmt = ID_WAD;
    entrysz = 16;
    nametags[1].ti_Data = 8;
    nametags[2].ti_Data = (ULONG) &buf[8];
    numfiles  = EndGetI32(&buf[4]);
    diroffset = EndGetI32(&buf[8]);
    break;

    case 0x32444157: /* wad2 */
    fmt = ID_WAD2;
    entrysz = 32;
    nametags[1].ti_Data = 16;
    nametags[2].ti_Data = (ULONG) &buf[16];
    numfiles  = EndGetI32(&buf[4]);
    diroffset = EndGetI32(&buf[8]);
    break;

    case 0x4B434150: /* pack */
    fmt = ID_PAK;
    entrysz = 64;
    nametags[1].ti_Data = 56;
    nametags[2].ti_Data = (ULONG) &buf[0];
    numfiles  = EndGetI32(&buf[8]) / 64;
    diroffset = EndGetI32(&buf[4]);
    break;

  default:
    return XADERR_DATAFORMAT;
  }

  /* go to directory block */
  err = xadHookAccess(XADAC_INPUTSEEK, diroffset - ai->xai_InPos, NULL, ai);
  if (err) return err;

  while (numfiles--) {
    /* read the file header */
    if ((err = xadHookAccess(XADAC_READ, entrysz, buf, ai))) break;

    fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, NULL);
    if (!fi) { err = XADERR_NOMEMORY; break; }

    switch (fmt) {
    case ID_WAD:
      fi->xfi_DataPos     = EndGetI32(&buf[0]);
      fi->xfi_Size        = EndGetI32(&buf[4]);
      fi->xfi_CrunchSize  = fi->xfi_Size;
      break;

    case ID_WAD2:
      fi->xfi_DataPos     = EndGetI32(&buf[0]);
      fi->xfi_CrunchSize  = EndGetI32(&buf[4]);
      fi->xfi_Size        = EndGetI32(&buf[8]);
      switch (buf[12]) {
      case 0x40:
        fi->xfi_EntryInfo = "Colour Palette"; break;
      case 0x42:
        fi->xfi_EntryInfo = "Status Bar"; break;
      case 0x44:
        fi->xfi_EntryInfo = "MIP Texture"; break;
      case 0x46:
        fi->xfi_EntryInfo = "Console picture"; break;
      }
      break;
    case ID_PAK:
      fi->xfi_DataPos     = EndGetI32(&buf[56]);
      fi->xfi_Size        = EndGetI32(&buf[60]);
      fi->xfi_CrunchSize  = fi->xfi_Size;
      break;
    }

    fi->xfi_Flags = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;

    /* copy filename */
    if (!(fi->xfi_FileName = xadConvertNameA(CHARSET_HOST, nametags))) {
      err = XADERR_NOMEMORY; break;
    }

    /* fill in today's date */
    datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
    xadConvertDatesA(datetags);

    /* add the file */
    addtags[0].ti_Data = ai->xai_InPos;
    if ((err = xadAddFileEntryA(fi, ai, addtags))) break;
  }

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

ASM(LONG) id_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  /* todo:
   * - actually decode data into some useful format
   * - wad2 LZSS compression
   */
  if (ai->xai_CurFile->xfi_Size != ai->xai_CurFile->xfi_CrunchSize) {
    return XADERR_NOTSUPPORTED;
  }
  return xadHookAccess(XADAC_COPY, ai->xai_CurFile->xfi_Size, NULL, ai);
}

const struct xadClient WAD_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 10, ID_VERSION, ID_REVISION,
  12, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "id WAD",

  /* client functions */
  (BOOL (*)()) WAD_RecogData,
  (LONG (*)()) id_GetInfo,
  (LONG (*)()) id_UnArchive,
  NULL
};

const struct xadClient WAD2_Client = {
  (struct xadClient *) &WAD_Client,
  XADCLIENT_VERSION, 10, ID_VERSION, ID_REVISION,
  12, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "id WAD2",

  /* client functions */
  (BOOL (*)()) WAD2_RecogData,
  (LONG (*)()) id_GetInfo,
  (LONG (*)()) id_UnArchive,
  NULL
};

const struct xadClient PAK_Client = {
  (struct xadClient *) &WAD2_Client,
  XADCLIENT_VERSION, 10, ID_VERSION, ID_REVISION,
  12, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "id PAK",

  /* client functions */
  (BOOL (*)()) PAK_RecogData,
  (LONG (*)()) id_GetInfo,
  (LONG (*)()) id_UnArchive,
  NULL
};
