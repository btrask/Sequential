/* Magic Shadow Archiver (MSA) disk archiver client for XAD.
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

/* This XAD client reads 'Magic Shadow Archiver' disk images and writes
 * them out as '.ST' (raw Atari ST disk) files, or allows them to be
 * written to MSDOS/GEM-formatted disks.
 *
 * $VER: MSA.c 1.1 (06.08.2000)
 *
 * File format info from Damien Burke,
 * see http://www.jetman.dircon.co.uk/st/
 */

#include <libraries/xadmaster.h>
#include <proto/xadmaster.h>

#include "SDI_compiler.h"
#include "ConvertE.c"

#ifndef XADMASTERFILE
#define MSA_Client      FirstClient
#define NEXTCLIENT      NULL
const UBYTE version[] = "$VER: MSA 1.1 (06.08.2000)";
#endif
#define MSA_VERSION     1
#define MSA_REVISION    1

#define XADBASE REG(a6, struct xadMasterBase *xadMasterBase)

/* work-doing macros */
#define SKIP(offset) if ((err = xadHookAccess(XADAC_INPUTSEEK, \
  (ULONG)(offset), NULL, ai))) goto exit_handler
#define READ(buffer,length) if ((err = xadHookAccess(XADAC_READ, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define WRITE(buffer,length) if ((err = xadHookAccess(XADAC_WRITE, \
  (ULONG)(length), (APTR)(buffer), ai))) goto exit_handler
#define COPY(length) if ((err = xadHookAccess(XADAC_COPY, \
  (ULONG)(length), NULL, ai))) goto exit_handler
#define ALLOC(t,v,l) if (!((v) = (t) xadAllocVec((l),0))) ERROR(NOMEMORY)
#define FREE(obj) xadFreeObjectA((APTR)(obj),NULL)
#define ERROR(error) do { err = XADERR_##error; goto exit_handler; } while(0)



ASM(BOOL) MSA_RecogData(REG(d0, ULONG size), REG(a0, UBYTE *d), XADBASE) {
  return (BOOL) (d[0]==0x0E &&d[1]==0x0F && d[4]==0 && d[5]<2);
}

ASM(LONG) MSA_GetInfo(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  struct xadDiskInfo *xdi;
  UBYTE buffer[10];
  LONG err;

  /* it's so simple here, I won't use the normal ALLOCOBJ/READ macros */
  xdi = (struct xadDiskInfo *) xadAllocObjectA(XADOBJ_DISKINFO, NULL);
  if (!(ai->xai_DiskInfo = xdi)) return XADERR_NOMEMORY;
  if ((err = xadHookAccess(XADAC_READ, 10, (APTR)&buffer, ai))) return err;

  xdi->xdi_EntryNumber  = 1;
  xdi->xdi_TrackSectors = EndGetM16(&buffer[2]);
  xdi->xdi_Heads        = EndGetM16(&buffer[4]) + 1;
  xdi->xdi_LowCyl       = EndGetM16(&buffer[6]);
  xdi->xdi_HighCyl      = EndGetM16(&buffer[8]);
  xdi->xdi_SectorSize   = 512;
  xdi->xdi_Cylinders    = xdi->xdi_HighCyl + 1;
  xdi->xdi_CylSectors   = xdi->xdi_TrackSectors * xdi->xdi_Heads;
  xdi->xdi_TotalSectors = xdi->xdi_Cylinders * xdi->xdi_CylSectors;
  xdi->xdi_Flags        = XADDIF_SEEKDATAPOS | XADDIF_GUESSCYLINDERS;
  xdi->xdi_DataPos      = 10;
  return XADERR_OK;
}

ASM(LONG) MSA_UnArchive(REG(a0, struct xadArchiveInfo *ai), XADBASE) {
  UBYTE buffer[2], *in = NULL, *out, *i, *o, *end, code;
  struct xadDiskInfo *di = ai->xai_CurDisk;
  UWORD inlen = 0, outlen = di->xdi_TrackSectors << 9;
  UWORD trklen, run, cyl, head;
  LONG err = XADERR_OK;

  /* allocate output buffer */
  ALLOC(UBYTE *, out, outlen);

  for (cyl = di->xdi_LowCyl; cyl <= ai->xai_HighCyl; cyl++) {
    for (head = 0; head < di->xdi_Heads; head++) {
      READ(&buffer, 2);
      trklen = EndGetM16(buffer);
      if (cyl >= ai->xai_LowCyl) {
        if (trklen >  outlen) { ERROR(OUTPUT); }
        if (trklen == outlen) { COPY(trklen);  }
        else {
          /* (re)allocate input buffer if necessary */
          if (trklen > inlen) {
            if (in) FREE(in);
            ALLOC(UBYTE *, in, (inlen = trklen));
          }

          /* read and un-RLE this track's data */
          READ(in, trklen);
          i   = in;
          o   = out;
          end = out + outlen;
          while (o < end) {
            if ((code = *i++) != 0xE5) *o++ = code;
            else {
              code = *i; run = EndGetM16(i+1); i += 3;
              if (o+run > end) ERROR(OUTPUT);
              while (run--) *o++ = code;
            }
          }
          WRITE(out, outlen);
        }
      }
      else {
        SKIP(trklen);
      }
    }
  }

exit_handler:
  if (in)  FREE(in);
  if (out) FREE(out);
  return err;
}

const struct xadClient MSA_Client = {
  NEXTCLIENT, XADCLIENT_VERSION, 4, MSA_VERSION, MSA_REVISION,
  10, XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  0, "MSA",
  (BOOL (*)()) MSA_RecogData,
  (LONG (*)()) MSA_GetInfo,
  (LONG (*)()) MSA_UnArchive,
  NULL
};
