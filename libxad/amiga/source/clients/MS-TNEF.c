/* MS-TNEF message format decoder for XAD.
 * Copyright (C) 2000-2002 Stuart Caie <kyzer@4u.net>
 *
 * based on tnef-1.1.1 by Mark Simpson and Thomas Boll
 * Copyright (C)1999-2002 Mark Simpson <damned@world.std.com>
 * Copyright (C)1998 Thomas Boll  <tb@boll.ch>  [ORIGINAL AUTHOR]
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

/* TNEF files are basically a sequence of tuples. Each tuple has this
 * format (little-endian data):
 *
 * UBYTE level;        * LVL_MESSAGE or LVL_ATTACHMENT
 * ULONG typename;     * type << 16 | name
 * ULONG length;       * length of the data to follow
 * UBYTE data[length]; * the actual data of the tuple
 * UWORD cksum;        * 16 bit wrap addition of all chars in data[]
 *
 * The TNEF_ATTACHMENT attachment properties tuple is like so:
 * ULONG number_of_properties;
 * ...properties
 *
 * A property has this format:
 * UWORD type;
 * UWORD name;
 * ...type-specific data
 *
 * for the types MAPI_STRING, MAPI_UNICODE_STRING and MAPI_BINARY, the type
 * specific data is like so:
 * ULONG number_of_elements;
 * ULONG element_lengths[number_of_elements];
 * UBYTE all_elements_data[...];
 * 
 * For more info, read file-format.tex provided with tnef-1.1.1
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>
#include <string.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifndef XADMASTERFILE
#define TNEF_Client		FirstClient
#define NEXTCLIENT		0
const UBYTE version[] = "$VER: MS-TNEF 1.2 (23.02.2002)";
#endif
#define TNEF_VERSION		1
#define TNEF_REVISION		2

#define XADBASE  REG(a6, struct xadMasterBase *xadMasterBase)

#define SKIP(offset) if ((err = xadHookAccess(XADAC_INPUTSEEK, \
  (ULONG)(offset), NULL, ai))) goto exit_handler
#define SEEK(offset) SKIP((offset) - ai->xai_InPos)
#define READ(buffer,length) if ((err = xadHookAccess(XADAC_READ, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define ALLOC(t,v,l) if (!((v) = (t) xadAllocVec((l),0x10000))) ERROR(NOMEMORY)
#define ALLOCOBJ(t,v,kind,tags) \
  if (!((v) = (t) xadAllocObjectA((kind),(tags)))) ERROR(NOMEMORY)
#define FREE(x) (xadFreeObjectA((APTR)(x), NULL))
#define ERROR(error) do { err = XADERR_##error; goto exit_handler; } while (0)


#define TNEF_MESSAGE          0x01
#define TNEF_ATTACH           0x02

#define TNEF_ATTACHDATA       0x800f /* Attachment Data */
#define TNEF_ATTACHTITLE      0x8010 /* Attachment File Name */
#define TNEF_ATTACHMODIFYDATE 0x8013 /* Attachment Modification Date */
#define TNEF_ATTACHMENT       0x9005 /* Attachment meta-data */

/* MAPI types */
#define MAPI_SHORT            0x0002   /* MAPI short (16 bits) */
#define MAPI_INT              0x0003   /* MAPI integer (32 bits) */
#define MAPI_FLOAT            0x0004   /* MAPI float (4 bytes) */
#define MAPI_DOUBLE           0x0005   /* MAPI double */
#define MAPI_CURRENCY         0x0006   /* MAPI currency (64 bits) */
#define MAPI_APPTIME          0x0007   /* MAPI application time */
#define MAPI_ERROR            0x000a   /* MAPI error (32 bits) */
#define MAPI_BOOLEAN          0x000b   /* MAPI boolean (32 bits) */
#define MAPI_INT8BYTE         0x0014   /* MAPI 8 byte signed int */
#define MAPI_STRING           0x001e   /* MAPI string */
#define MAPI_UNICODE_STRING   0x001f   /* MAPI unicode-string */
#define MAPI_SYSTIME          0x0040   /* MAPI time */
#define MAPI_BINARY           0x0102   /* MAPI binary */

/* MAPI names (that we're interested in) */
#define MAPI_ATTACH_LONG_FILENAME  0x3707


ASM(BOOL) TNEF_RecogData(REG(d0, ULONG size), REG(a0, STRPTR d), XADBASE) {
  return (BOOL) (d[0]==0x78 && d[1]==0x9F && d[2]==0x3E && d[3]==0x22) ? 1 : 0;
}

ASM(LONG) TNEF_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  ULONG filenum=1, defnum=1, offset=6, tuplen, numprops;
  UBYTE buffer[14], *p, *defname, *fname=NULL;
  UBYTE date_set=0, rename_prev_file=0;
  struct xadFileInfo *link = NULL,  *fi=NULL;
  LONG err = XADERR_OK;
  struct xadDate date;

  struct TagItem datetags[] = {
    { XAD_DATECURRENTTIME, 1 },
    { XAD_GETDATEXADDATE,  0 },
    { TAG_DONE, 0 }
  };

  defname = (ai->xai_InName) ? ai->xai_InName : xadMasterBase->xmb_DefaultName;

  while (offset < ai->xai_InSize) {
    SEEK(offset);
    READ(buffer, 9);
    tuplen = EndGetI32(&buffer[5]);
    offset += tuplen + 11;

    if (buffer[0] == TNEF_ATTACH) {
      switch (EndGetI16(&buffer[1])) {

      case TNEF_ATTACHMENT:
        /* interpret this tuple as a set of MAPI properties */
        READ(buffer, 4);
        for (numprops = EndGetI32(&buffer[0]); numprops > 0; numprops--) {
          ULONG name, size, firstsize, numvals;
          READ(buffer, 4);
          name = EndGetI16(&buffer[2]);
          switch (EndGetI16(&buffer[0])) {
          case MAPI_SHORT:
            size = 2;
            break;

          case MAPI_INT:
          case MAPI_FLOAT:
          case MAPI_BOOLEAN:
          case MAPI_ERROR:
            size = 4;
            break;

          case MAPI_INT8BYTE:
          case MAPI_DOUBLE:
          case MAPI_SYSTIME:
          case MAPI_CURRENCY:
            size = 8;
            break;

          case MAPI_STRING:
          case MAPI_UNICODE_STRING:
          case MAPI_BINARY:
            size = 0;
            READ(buffer, 4);
            for (numvals = EndGetI32(&buffer[0]); numvals > 0; numvals--) {
              ULONG val_len;
              READ(buffer, 4);
              val_len = EndGetI32(&buffer[0]);
              if (size == 0) firstsize = val_len;
              val_len = (val_len + 3) & -4;
              size += val_len;
            }
            break;
          default:
            size = 0;
          }
          if (name == MAPI_ATTACH_LONG_FILENAME) {
            /* a long filename! Overwrite the previous filename */
            size -= firstsize;
            if (fname) FREE(fname);
            ALLOC(UBYTE *, fname, firstsize+1);
            READ(fname, firstsize);
            fname[firstsize] = '\0';
            if (link == NULL) ERROR(DATAFORMAT);
            FREE(link->xfi_FileName);
            link->xfi_FileName = fname;
          }
          if (size) SKIP(size);
        }
        break;

      case TNEF_ATTACHMODIFYDATE:
        if (tuplen >= 14) {
          READ(buffer, 14);
          date.xd_Micros  = 0;
          date.xd_Year    = EndGetI16(&buffer[0]);
          date.xd_Month   = EndGetI16(&buffer[2]);
          date.xd_Day     = EndGetI16(&buffer[4]);
          date.xd_Hour    = EndGetI16(&buffer[6]);
          date.xd_Minute  = EndGetI16(&buffer[8]);
          date.xd_Second  = EndGetI16(&buffer[10]);
          date.xd_WeekDay = EndGetI16(&buffer[12]);
          /* convert TNEF's "0=Sun to 6=Sat" to XAD's "1=Mon to 7=Sun" */
          if (date.xd_WeekDay == 0) date.xd_WeekDay = 7;          
          date_set = 1;
        }
        break;

      case TNEF_ATTACHTITLE:
        if (tuplen) {
          ALLOC(UBYTE *, fname, tuplen);
          READ(fname, tuplen);
          /* if an empty filename, get rid of it */
          if (fname[0] == '\0') { FREE(fname); fname = NULL; }
        }

        if (rename_prev_file) {
          if (fname) {
            FREE(link->xfi_FileName);
            link->xfi_FileName = fname;
            fname = NULL;
          }
          rename_prev_file = 0;
        }
        break;

      case TNEF_ATTACHDATA:
        ALLOCOBJ(struct xadFileInfo *, fi, XADOBJ_FILEINFO, NULL);
        fi->xfi_EntryNumber = filenum++;
        fi->xfi_Size        = tuplen;
        fi->xfi_Flags       = XADFIF_SEEKDATAPOS;
        fi->xfi_DataPos     = ai->xai_InPos;
        fi->xfi_CrunchSize  = fi->xfi_Size;

        if (fname) {
          /* fix MS-DOS filenames */
          for (p = fname; *p; p++) if (*p == '\\') *p = '/';
        }
        else {
          /* make default name */
          int i = strlen(defname);
          ALLOC(UBYTE *, fname, i+5);
          strcpy(fname, defname);
          fname[i++] = '.';
          fname[i++] = '0' + ((defnum/100) % 10);
          fname[i++] = '0' + ((defnum/10)  % 10);
          fname[i++] = '0' + ( defnum      % 10);
          fname[i] = '\0';
          defnum++;
          rename_prev_file = 1;
        }
        fi->xfi_FileName = fname;
        fname = NULL;

        if (date_set) {
          fi->xfi_Date = date;
          date_set = 0;
        }
        else {
          /* fill in today's date */
          fi->xfi_Flags |= XADFIF_NODATE;
          datetags[1].ti_Data = (ULONG) &fi->xfi_Date;
          xadConvertDatesA(datetags);
        }

        if (link) link->xfi_Next = fi; else ai->xai_FileInfo = fi;
        link = fi;
        fi = NULL;
      }
    }
    else {
      if (buffer[0] != TNEF_MESSAGE) ERROR(DATAFORMAT);
    }
  }

exit_handler:
  /* in case memory allocation fails for the filename */
  if (fi) FREE(fi);

  if (err) {
    if (!ai->xai_FileInfo) return err;
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }
  return XADERR_OK;
}

ASM(LONG) TNEF_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  return xadHookAccess(XADAC_COPY, ai->xai_CurFile->xfi_Size, NULL, ai);
}

ASM(void) TNEF_Free(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct xadFileInfo *fi;

  for (fi = ai->xai_FileInfo; fi; fi = fi->xfi_Next) {
    if (fi->xfi_FileName) {
      FREE(fi->xfi_FileName);
      fi->xfi_FileName = NULL;
    }
  }
}

const struct xadClient TNEF_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 6, TNEF_VERSION, TNEF_REVISION,
  32, XADCF_FILEARCHIVER | XADCF_FREEFILEINFO,
  0, "MS-TNEF",

  /* client functions */
  (BOOL (*)()) TNEF_RecogData,
  (LONG (*)()) TNEF_GetInfo,
  (LONG (*)()) TNEF_UnArchive,
  (void (*)()) TNEF_Free
};
