/* MakeSFX file archiver client for XAD.
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

/* MakeSFX is an AmigaDOS shell script that generates the assembler
 * source code of a program that would save blocks of data to files.
 * It then assembles this program to create a self-extracting archive.
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifndef XADMASTERFILE
#define MSFX_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: MakeSFX 1.1 (07.04.2002)";
#endif
#define MSFX_VERSION		1
#define MSFX_REVISION		1

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

/* MakeSFX 1.0 code from offset 32 (start of hunk) */
static const UBYTE msfx10_code[] = {
  0x2C, 0x78, 0x00, 0x04, /* 2c 78 00 04      movea.l 4.w,a6     */
  0x43, 0xFA, 0x00, 0x10, /* 43 fa 00 10      lea     dos(pc),a1 */
  0x4E, 0xAE, 0xFE, 0x68, /* 4e ae fe 68      jsr     -$198(a6)  */
  0x2C, 0x40,             /* 2c 40            movea.l d0,a6      */
  0x4A, 0x80,             /* 4a 80            tst.l   d0         */
  0x66, 0x10,             /* 66 10            bne.b   .ok        */
  0x70, 0x14,             /* 70 14            moveq   #20,d0     */
  0x4E, 0x75,             /* 4e 75            rts                */
  0x64, 0x6F, 0x73, 0x2E, /* 64 6f 73 2e dos: dc.b    "dos."     */
  0x6C, 0x69, 0x62, 0x72, /* 6c 69 62 72      dc.b    "libr"     */
  0x61, 0x72, 0x79, 0x00  /* 61 72 79 00      dc.b    "ary",0    */
};

ASM(BOOL) SAVEDS MSFX10_RecogData(REG(d0,ULONG s),REG(a0,STRPTR d),XADBASE) {
  return (EndGetM32(d)==0x3f3 && memcmp(&d[32], msfx10_code, 34) == 0) ? 1:0;
}

/* MakeSFX 1.2 code from offset 40 (hunk starts at offset 32) */
static const UBYTE msfx12_code[] = {
  0x70, 0x21,             /* 70 21          moveq   #33,d0      */
  0x4E, 0xAE, 0xFD, 0xD8, /* 4e ae fd d8    jsr     -$228(a6)   */
  0x4A, 0x80,             /* 4a 80          tst.l   d0          */
  0x66, 0x04,             /* 66 04          bne.b   .ok         */
  0x70, 0x14,             /* 70 14          moveq   #20,d0      */
  0x4E, 0x75,             /* 4e 75          rts                 */
  0x2C, 0x40,             /* 2c 40     .ok: movea.l d0,a6       */
  0x2A, 0x4F,             /* 2a 4f          movea.l sp,a5       */
  0x49, 0xFA              /* 49 fa xx xx    lea     xxxx(pc),a4 */
};

ASM(BOOL) SAVEDS MSFX12_RecogData(REG(d0,ULONG s),REG(a0,STRPTR d),XADBASE) {
  return (EndGetM32(d)==0x3f3 && memcmp(&d[40], msfx12_code, 20)==0) ? 1:0;
}

ASM(LONG) MSFX_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG offset, nameoff, dataoff, filelen;
  struct xadFileInfo *fi;
  BOOL is_v12, file_ok;
  LONG err = XADERR_OK;
  UBYTE buffer[32];
  UWORD x, y;

  struct TagItem filetags[]  = {
    { XAD_OBJNAMESIZE, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  struct TagItem addtags[] = {
    { XAD_SETINPOS, 0 },
    { TAG_DONE, 0 }
  };

  /* read and identify header again to determine MakeSFX v1.0 from v1.2 */
  if ((err = xadHookAccess(XADAC_INPUTSEEK, 40, NULL, ai))) return err;
  if ((err = xadHookAccess(XADAC_READ, 32, (APTR) buffer, ai))) return err;
  is_v12  = (memcmp(buffer, msfx12_code, 20) == 0);

  if (is_v12) {
    /* MakeSFX 1.2 - find offset of main file-writing list, by examining the
     * BSR instruction [at file offset 64, buffer offset 24] that jumps to it
     */
    y = EndGetM16(&buffer[24]);
    if (y == 0x6100) {
      offset = 66 + EndGetM16(&buffer[26]); /* 61 00 xx xx  bsr.w xxxx */
      y = 28;                               /* next instruction offset */
    }
    else if (y >= 0x6102 && y <= 0x61FE && !(y & 1)) {
      offset = 66 + (y & 0xFF);             /* 61 xx        bsr.b xx   */
      y = 26;                               /* next instruction offset */
    }
    else {
      return XADERR_DATAFORMAT;
    }

    /* check instruction after the BSR - if it's "lea xxxx(pc),a0", then an
     * auto-execute script is in this archive. the offset pointed to by the
     * LEA gives the start of the script, and it goes on until the
     * file-writing offset
     */
    x = EndGetM16(&buffer[y]);
    if (x == 0x41FA) {
      /* create another file entry called "AutoRun.script" */
      filetags[0].ti_Data = 15;
      fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, filetags);
      if (fi == NULL) return XADERR_NOMEMORY;
      xadCopyMem("AutoRun.script", fi->xfi_FileName, 15);

      fi->xfi_DataPos     = EndGetM16(&buffer[y+2]) + y + 40  + 2;
      fi->xfi_Size        = fi->xfi_CrunchSize = offset - fi->xfi_DataPos;
      fi->xfi_Flags       = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
      datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
      xadConvertDatesA(datetags);

      if ((err = xadAddFileEntryA(fi, ai, NULL))) return err;
    }
  }
  else {
    /* MakeSFX 1.0 - file writing always at offset 66 */
    offset = 66;
  }


  /* skip to first file header */
  if ((err = xadHookAccess(XADAC_INPUTSEEK, offset - ai->xai_InPos,
                           NULL, ai))) return err;

  do {
    /* read the next file header */
    if ((err = xadHookAccess(XADAC_READ, 26, (APTR) buffer, ai))) break;

    file_ok = 0;

    if (is_v12) {
      /* examine file header for MakeSFX 1.2 */
      if ( (EndGetM16(&buffer[0]) == 0x47FA) &&
           (EndGetM16(&buffer[4]) == 0x4E94) )
      {
        /* lea    file_info(pc),a3   ;0000: 47 FA XX XX
         * jsr    (a4)               ;0004: 4E 94
         *then one of
         * jmp    next_file_header   ;0006: 4E F9 XX XX XX XX
         * bra.b  next_file_header   ;0006: 60 XX
         * bra.w  next_file_header   ;0006: 60 00 XX XX
         *then file_info:
         * dc.l   file_name          ;????: XX XX XX XX
         * dc.l   file_data          ;????: XX XX XX XX
         * dc.l   file_length        ;????: XX XX XX XX
         */

        x       = EndGetM16(&buffer[2])   + 2;
        nameoff = EndGetM32(&buffer[x])   + 32;
        dataoff = EndGetM32(&buffer[x+4]) + 32;
        filelen = EndGetM32(&buffer[x+8]) + 32;

        /* work out the next file's offset from the bra/jmp instruction */
        x = EndGetM16(&buffer[6]);
             if (x == 0x4EF9) offset  = EndGetM32(&buffer[8]) + 32;
        else if (x == 0x6000) offset += EndGetM16(&buffer[8]) + 8;
        else if (x >= 0x6002 && x <= 0x60FE && !(x&1))
          offset += (x & 0xFF) + 8;
        else { err = XADERR_DATAFORMAT; break; }

        file_ok = 1;
      }
    }
    else {
      /* examine file header for MakeSFX 1.0 */
      if ( (EndGetM16(&buffer[0x00]) == 0x203c) &&
           (EndGetM16(&buffer[0x06]) == 0x41fa) &&
           (EndGetM16(&buffer[0x0a]) == 0x43fa) )
      {
        /* move.l #file_length,d0    ;0000: 20 3C XX XX XX XX
         * lea    file_name(pc),a0   ;0006: 41 FA XX XX
         * lea    file_data(pc),a1   ;000A: 43 FA XX XX
         *then 1 of...
         * jsr    write_file         ;000E: 4E B9 XX XX XX XX
         * bsr.b  write_file         ;000E: 61 XX
         * bsr.w  write_file         ;000E: 61 00 XX XX
         *then 1 of...
         * jmp    next_file_header   ;????: 4E F9 XX XX XX XX
         * bra.b  next_file_header   ;????: 60 XX
         * bra.w  next_file_header   ;????: 60 00 XX XX
         */

        filelen = EndGetM32(&buffer[2]);
        nameoff = EndGetM16(&buffer[8])  + 8  + offset;
        dataoff = EndGetM16(&buffer[12]) + 12 + offset;

        /* skip past the first bsr/jsr instruction */
        y = EndGetM16(&buffer[14]);
             if (y == 0x4EB9) y = 20;
        else if (y == 0x6100) y = 18;
        else if (y >= 0x6102 && y <= 0x61FE && !(y & 1)) y = 16;
        else { err = XADERR_DATAFORMAT; break; }

        /* work out the next file's offset from the bra/jmp instruction */
        x = EndGetM16(&buffer[y]);
             if (x == 0x4EF9) offset  = EndGetM32(&buffer[y+2]) + 32;
        else if (x == 0x6000) offset += EndGetM16(&buffer[y+2]) + y+2;
        else if (x >= 0x6002 && x <= 0x60FE && !(x&1))
          offset += (x & 0xFE) + y+2;
        else { err = XADERR_DATAFORMAT; break; }

        file_ok = 1;
      }
    }

    if (file_ok) {
      filetags[0].ti_Data = dataoff - nameoff;
      fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, filetags);
      if (fi == NULL) {
        err = XADERR_NOMEMORY;
        break;
      }

      fi->xfi_Size    = fi->xfi_CrunchSize = filelen;
      fi->xfi_Flags   = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
      fi->xfi_DataPos = dataoff;

      /* read in filename */
      if ((err = xadHookAccess(XADAC_INPUTSEEK, nameoff - ai->xai_InPos,
                               NULL, ai))) break;
      if ((err = xadHookAccess(XADAC_READ, filetags[0].ti_Data,
                               (APTR) fi->xfi_FileName, ai))) break;

      /* fill in today's date */
      datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
      xadConvertDatesA(datetags);

      /* add the file entry, and skip to the next file header */
      addtags[0].ti_Data = offset;
      if ((err = xadAddFileEntryA(fi, ai, addtags))) break;
    }
  } while (file_ok);

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}


ASM(LONG) MSFX_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  return xadHookAccess(XADAC_COPY, ai->xai_CurFile->xfi_Size, NULL, ai);
}

const struct xadClient MSFX12_Client = {
  NEXTCLIENT,
  XADCLIENT_VERSION, 10, MSFX_VERSION, MSFX_REVISION,
  190, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO,
  0, "MakeSFX 1.2",

  /* client functions */
  (BOOL (*)()) MSFX12_RecogData,
  (LONG (*)()) MSFX_GetInfo,
  (LONG (*)()) MSFX_UnArchive,
  NULL
};

const struct xadClient MSFX_Client = {
  (struct xadClient *) &MSFX12_Client,
  XADCLIENT_VERSION, 10, MSFX_VERSION, MSFX_REVISION,
  66, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO,
  0, "MakeSFX 1.0",

  /* client functions */
  (BOOL (*)()) MSFX10_RecogData,
  (LONG (*)()) MSFX_GetInfo,
  (LONG (*)()) MSFX_UnArchive,
  NULL
};
