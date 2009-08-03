/* Unreal package extractor client (music only) for XAD.
 * Copyright (C) 2002 Stuart Caie <kyzer@4u.net>
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

/* The "Unreal" PC game uses its own special format for serialising
 * textures, objects, scripts, music, etc.
 *
 * This XAD client only supports extracting music files (.UMX files) at
 * the moment. In future, it might support extraction (read: conversion
 * to a usable format) of other things like scripts, textures, etc.
 *
 * Unreal file have 3 main tables: the name table, the import table
 * and the export table.
 *
 * The name table is simply a list of ASCII strings and 32-bit flags. All
 * entries in the import and export table refer to the name table for
 * textual names.
 *
 * The import table gives the names of Unreal classes that are required to
 * interpret the data in this package. Objects in the export table refer
 * to import table objects, which lets us know what kind of object they
 * are (without this, they'd just be raw data).
 *
 * The specification for the file format is available at Antonio Cordero's
 * homepage, http://www.acordero.org/
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
#define UMX_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: Unreal 1.0 (07.11.2002)";
#endif
#define UMX_VERSION		1
#define UMX_REVISION		0

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

#define SEEK(offset) if ((err = xadHookAccess(XADAC_INPUTSEEK, \
  (ULONG)(offset) - ai->xai_InPos, NULL, ai))) goto exit_handler
#define READ(buffer,length) if ((err = xadHookAccess(XADAC_READ, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define ERROR(error) do { err = XADERR_##error; goto exit_handler; } while(0)
#define ALLOC(t,v,l) \
  if (!((v) = (t) xadAllocVec((l),0x10000))) ERROR(NOMEMORY)
#define FREE(obj) xadFreeObjectA((obj),NULL)

/* will read a compact index value from UBYTE buffer[offset]
 * and will advance offset to the byte following the completed
 * index value. The value will be stored in LONG value.
 */
#define READ_COMPACT_INDEX(buffer, offset, value) do {		\
  char neg = (buffer)[(offset)] & 0x80;				\
  (value) = (buffer)[(offset)] & 0x3F;				\
  if ((buffer)[(offset)++] & 0x40) {				\
    (value) |= ((buffer)[(offset)] & 0x7F) << 6;		\
    if ((buffer)[(offset)++] & 0x80) {				\
      (value) |= ((buffer)[(offset)] & 0x7F) << 13;		\
      if ((buffer)[(offset)++] & 0x80) {			\
        (value) |= ((buffer)[(offset)] & 0x7F) << 20;		\
        if ((buffer)[(offset)++] & 0x80) {			\
          (value) |= ((buffer)[(offset)++] & 0x1F) << 27;	\
        }							\
      }								\
    }								\
  }								\
  if (neg) (value) = -(value);					\
} while (0)

#define head_Tag             (0x00)
#define head_FileVersion     (0x04)
#define head_PackageFlags    (0x08)
#define head_NameCount       (0x0c)
#define head_NameOffset      (0x10)
#define head_ExportCount     (0x14)
#define head_ExportOffset    (0x18)
#define head_ImportCount     (0x1c)
#define head_ImportOffset    (0x20)
#define head_SIZEOF          (0x24)
/* the header is longer than this, but this is all we care about. */

/* the maximum size of an import file entry */
#define import_SIZEOF  (19)
/* the maximum size of an export file entry */
#define export_SIZEOF  (33)

/* for our little nametable state machine */
#define STATE_NAMELEN   (0)
#define STATE_NAMECHARS (1)
#define STATE_NAMEFLAGS (2)

/* an import table entry */
struct UMX_import {
  LONG class_package;   /* package of the class  (name table ref) */
  LONG class_name;      /* class of the object   (name table ref) */
  LONG object_package;  /* package of the object (import/export table ref) */
  LONG object_name;     /* name of the object    (name table ref) */
};


ASM(BOOL) UMX_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (BOOL) ((EndGetI32(&d[head_Tag]) == 0x9E2A83C1) &&
                 (EndGetI32(&d[head_FileVersion]) >= 60) );
}

ASM(LONG) UMX_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG name_count, name_offset, export_count, export_offset, import_count;
  ULONG import_offset, offset, avail, i;
  UBYTE state, namelen, off, keep_file;
  UBYTE buf[64], **names = NULL, *name;
  struct UMX_import *imports = NULL;
  struct xadFileInfo *fi;
  LONG err = XADERR_OK, x;

  /* used to join object name (e.g. "blaster") and music type (e.g. "it")
   * with a ".", to give a filename (e.g. "blaster.it")
   */
  struct TagItem nametags[] = {
    { XAD_CHARACTERSET, CHARSET_WINDOWS },
    { XAD_ADDPATHSEPERATOR, 0 },
    { XAD_STRINGSIZE, 514 },
    { XAD_CSTRING, 0 },
    { XAD_CSTRING, (ULONG) "." },
    { XAD_CSTRING, 0 },
    { TAG_DONE, 0 }
  };

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  /* read the file header */
  READ(buf, head_SIZEOF);
  D(("FileVersion = %ld\n", EndGetI32(&buf[head_FileVersion])))
  name_count    = EndGetI32(&buf[head_NameCount]);
  name_offset   = EndGetI32(&buf[head_NameOffset]);
  import_count  = EndGetI32(&buf[head_ImportCount]);
  import_offset = EndGetI32(&buf[head_ImportOffset]);
  export_count  = EndGetI32(&buf[head_ExportCount]);
  export_offset = EndGetI32(&buf[head_ExportOffset]);

  /* there must be at least one name, import and export */
  if ((name_count == 0) || (export_count == 0) || (import_count == 0)) {
    ERROR(ILLEGALDATA);
  }

  /* allocate the name table */
  ALLOC(char **, names, name_count * sizeof(char *));

  /* allocate the import table */
  ALLOC(struct UMX_import *,imports,import_count * sizeof(struct UMX_import));

  /* read the name table
   *
   * to avoid lots of seeks/reads to read in the name table, we simply
   * keep reading 64 byte chunks and use a state machine so we can easily
   * keep track of what we're doing within those chunks
   */
  SEEK(name_offset);
  x = 0; state = STATE_NAMELEN;
  while (x < name_count) {
    /* read 64 bytes, or up to 64 bytes if near the end of the file */
    avail = ai->xai_InSize - ai->xai_InPos;
    if (avail > 64) avail = 64;
    READ(buf, avail);

    /* go through all the bytes */
    for (i = 0; i < avail; i++) {
      switch (state) {
      case STATE_NAMELEN:
        namelen = buf[i]; off = 0; state = STATE_NAMECHARS;
        ALLOC(char *, names[x], namelen+1);
        break;
      case STATE_NAMECHARS:
        names[x][off++] = buf[i];
        if (--namelen == 0) {
          names[x][off] = '\0'; namelen = 4; state = STATE_NAMEFLAGS;
        }
        break;
      case STATE_NAMEFLAGS:
        if (--namelen == 0) {
          /* "i = avail" breaks out of the for() loop */
          if (++x == name_count) i = avail; else state = STATE_NAMELEN;
        }
      }
    }
  }

  /* read the imports table */
  offset = import_offset;
  for (i = 0; i < import_count; i++) {
    /* go to next import entry and read up to the maximum size of one */
    SEEK(offset);
    avail = ai->xai_InSize - offset;
    if (avail > import_SIZEOF) avail = import_SIZEOF;
    READ(buf, avail);

    /* read the data for that import table entry */
    off = 0;
    READ_COMPACT_INDEX(buf, off, imports[i].class_package);
    READ_COMPACT_INDEX(buf, off, imports[i].class_name);
    imports[i].object_package = (LONG) EndGetI32(&buf[off]); off += 4; 
    READ_COMPACT_INDEX(buf, off, imports[i].object_name); 

    /* did we read past the end of the file? */
    if (off > avail) ERROR(ILLEGALDATA);

    offset += off;
  }

  /* read the exports table -- this is where the action happens */
  offset = export_offset;
  for (i = 0; i < export_count; i++) {
    /* read in up to the maximum bytes an export entry can require */
    SEEK(offset);
    avail = ai->xai_InSize - offset;
    if (avail > export_SIZEOF) avail = export_SIZEOF;
    READ(buf, avail);

    /* read object's class */
    off = 0;
    READ_COMPACT_INDEX(buf, off, x);

    /* we are looking for files whose class's object_name is "Music" */
    keep_file = 0;
    /* class index must be a reference to the import table */
    if (x < 0) {
      x = -x-1;
      /* must be a valid import table index */
      if (x >= 0 && x < import_count) {
        x = imports[x].object_name;
        /* name index in import able must be a valid name table index */
        if (x >= 0 && x < name_count) {
          /* is it called "Music" ? */
          if (strcmp("Music", names[x]) == 0) {
            keep_file = 1;
          }
        }
      }
    }

    READ_COMPACT_INDEX(buf, off, x); /* read object's superclass, skip it */
    off += 4;                        /* skip reading object's package */
    READ_COMPACT_INDEX(buf, off, x); /* read object's name */
    off += 4;                        /* skip reading object's flags */

    /* only keep music files with valid name indices */
    if ((x >= 0) && (x < name_count)) name = names[x]; else keep_file = 0;

    READ_COMPACT_INDEX(buf, off, x); /* read object's size */

    /* for a music file, we don't need the object's size, it's repeated
     * in a header where the object data is located.
     * if object's size was more than zero, read object's offset
     */
    if (x > 0) READ_COMPACT_INDEX(buf, off, x); else keep_file = 0;

    /* did we overshoot the end of the file? corrupt data! */
    if (off > avail) ERROR(ILLEGALDATA);

    /* if the object was a music file, we now add it to the file list! */
    if (keep_file) {
      /* first, we have to find out the real offset and size of the
       * music file. The actual music is preceeded by a header:
       *
       * offset | size | element
       * 0      | 2    | unknown. always equals 1
       * 2      | 4    | unknown
       * 6      | 1-5  | compact index: length of music module
       * 7-11   | any  | the music module itself
       */
      SEEK(x+6); READ(buf, 5); off = 0;
      READ_COMPACT_INDEX(buf, off, x); /* read music mod's size */

      /* now, actually add the music module to the xad filelist */
      fi = (struct xadFileInfo *) xadAllocObjectA(XADOBJ_FILEINFO, NULL);
      if (!fi) {
        err = XADERR_NOMEMORY;
        break;
      }
      fi->xfi_Size = fi->xfi_CrunchSize = x;
      fi->xfi_Flags = XADFIF_SEEKDATAPOS | XADFIF_EXTRACTONBUILD;
      fi->xfi_DataPos = ai->xai_InPos - 5 + off; /* after the compact index */

      /* join the object name and the first entry in the name table (for
       * umx files, this is always the music-type, eg "it", "xm", "mod")
       * with a "." in order to get "melody.xm", for example
       */
      nametags[3].ti_Data = (ULONG) name;
      nametags[5].ti_Data = (ULONG) names[0];
      if (!(fi->xfi_FileName = xadConvertNameA(CHARSET_HOST, nametags))) {
        err = XADERR_NOMEMORY;
        break;
      }

      /* set the date */
      datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
      xadConvertDatesA(datetags);

      /* add the file */
      if ((err = xadAddFileEntryA(fi, ai, NULL))) goto exit_handler;
    }

    offset += off;
  }

exit_handler:

  /* free the imports table */
  if (imports) xadFreeObjectA((APTR) imports, NULL);

  /* free the name-table */
  if (names) {
    for (i = 0; i < name_count; i++) {
      if (names[i]) xadFreeObjectA((APTR) names[i], NULL);
    }
    xadFreeObjectA((APTR) names, NULL);
  }

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

ASM(LONG) UMX_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  return xadHookAccess(XADAC_COPY, ai->xai_CurFile->xfi_Size, NULL, ai);
}

const struct xadClient UMX_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 12,
  UMX_VERSION, UMX_REVISION,
  8, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO | XADCF_FREEXADSTRINGS,
  0, "Unreal package",

  /* client functions */
  (BOOL (*)()) UMX_RecogData,
  (LONG (*)()) UMX_GetInfo,
  (LONG (*)()) UMX_UnArchive,
  NULL
};
