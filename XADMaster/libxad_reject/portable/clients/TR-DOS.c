#ifndef XADMASTER_TR_DOS_C
#define XADMASTER_TR_DOS_C

/*  $Id: TR-DOS.c,v 1.9 2005/06/23 14:54:41 stoecker Exp $
    TR-DOS FS this is a filesystem client for TR-DOS disk images

    XAD library system for archive handling
    Copyright (C) 2000 and later by Dirk Stöcker <soft@dstoecker.de>
    Copyright (C) 2002 and later by AmiS <amis@amiga.org.ru>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "xadClient.h"

#ifndef  XADMASTERVERSION
  #define XADMASTERVERSION 11
#endif

XADCLIENTVERSTR("TR-DOS 1.2 (24.02.2004) GPL by AmiS")

#define TRD_VERSION  1
#define TRD_REVISION 2

/*
struct TRD_File
{
  char Name[8];
  xadUINT8 Type;
  xadUINT16 Start;
  xadUINT16 Length;
  xadUINT8 Sectors;
  xadUINT8 FirstSector;
  xadUINT8 Track;
} fl[128];

struct ControlSector
{
  xadUINT8  Zero;
  xadUINT8  Reserv1[224];
  xadUINT8  FirstFreeSector;
  xadUINT8  TrackFirstFreeSector;
  xadUINT8  DiskType;
  xadUINT8  FilesCount;
  xadUINT16 FreeSectorsCount;
  xadUINT8  TRDOS_ID;
  xadUINT8  Reserv2[2];
  xadUINT8  Reserv3[9];
  xadUINT8  Reserv4;
  xadUINT8  FeleteFilesCount;
  xadUINT8  DiskName[8];
  xadUINT8  Reserv5[3];
} cs;
*/

/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
XADGETINFO(TRD)
{
  xadUINT8 fl[16], cs[256];
  xadERROR err;

  if(ai->xai_InSize == 655360)
  {
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 256*8, NULL, ai)))
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 256, cs, ai)))
      {
#ifdef DEBUG
  DebugClient(ai, "Inputfile size=%ld", ai->xai_InSize);
  DebugClient(ai, "Control Secor:");
  DebugClient(ai, " Zero = %ld", cs[0]);
  DebugClient(ai, " FirstFreeSector = %ld", cs[1+224]);
  DebugClient(ai, " TrackFirstFreeSector = %ld", cs[1+224+1]);
  DebugClient(ai, " DiskType = %ld", cs[1+224+1+1]);
  DebugClient(ai, " FilesCount = %ld", cs[1+224+1+1+1]);
  DebugClient(ai, " FreeSectorsCount = %ld", EndGetI16(&(cs[1+224+1+1+1+1])));
  DebugClient(ai, " TRDOS_ID = %ld", cs[1+224+1+1+1+1+2]);
#endif

        if(cs[1+224+1+1+1+1+2] == 0x10 && cs[1+224+1+1] == 0x16)
        {
          if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, -(256*8+256), NULL, ai)))
          {
            xadUINT32 filecount;
            struct xadFileInfo *fi;
            xadUINT16 CheckSum;

            for(filecount=1; !err && filecount<=cs[1+224+1+1+1]; filecount++)
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, 16, fl, ai)))
              {
                if((fi = (struct xadFileInfo *)xadAllocObject(XADM XADOBJ_FILEINFO,
                XAD_OBJPRIVINFOSIZE, 17, XAD_OBJNAMESIZE, 8+1+2+1,
                XAD_OBJCOMMENTSIZE, 10, TAG_DONE)))
                {
                  xadUINT32 i;
                  fi->xfi_EntryNumber = filecount;
                  fi->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS
                                  |XADFIF_EXTRACTONBUILD;
                  xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
                  &fi->xfi_Date, TAG_DONE);

                  fi->xfi_Size = fi->xfi_CrunchSize = fl[13]*256+17;
                  fi->xfi_DataPos = fl[14]*256+fl[15]*16*256;

                  /* Fill Header */
                  xadCopyMem(XADM fl, (xadUINT8 *)(fi->xfi_PrivateInfo), 13);
                  ((xadUINT8 *)(fi->xfi_PrivateInfo))[13] = 0;
                  ((xadUINT8 *)(fi->xfi_PrivateInfo))[14] = fl[13];
                  CheckSum=0;
                  for(i=0; i<=14; i++)
                    CheckSum += (((xadUINT8 *)(fi->xfi_PrivateInfo))[i] * 257) + i;
                  ((xadUINT8 *)(fi->xfi_PrivateInfo))[16] = CheckSum>>8;
                  ((xadUINT8 *)(fi->xfi_PrivateInfo))[15] = CheckSum&0x00ff;

                  sprintf(fi->xfi_Comment, "%ld", (long) EndGetI16(&(fl[11])));
                  sprintf(fi->xfi_FileName, "%.8s.!%lc", fl, fl[8]);

                  err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos,
                  TAG_DONE);
                }
                else err = XADERR_NOMEMORY;
              }
            }
          }
        }
        else err = XADERR_FILESYSTEM;
      }
    }
  }
  else
    err = XADERR_FILESYSTEM;

  if(err && ai->xai_FileInfo)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
    err = XADERR_OK;
  }

  return err;
}

/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
XADUNARCHIVE(TRD)
{
  xadERROR err;
  if(!(err = xadHookAccess(XADM XADAC_WRITE, 17, ai->xai_CurFile->xfi_PrivateInfo, ai)))
  {
    err = xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size-17, NULL, ai);
  }
  return err;
}

/*=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=*/
XADFIRSTCLIENT(TRD)
{
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  TRD_VERSION,
  TRD_REVISION,
  0,
  XADCF_FILESYSTEM|XADCF_FREEFILEINFO,
  XADCID_FSTRDOS,
  "TR-DOS FS",
  0,
  XADGETINFOP(TRD),
  XADUNARCHIVEP(TRD),
  0,
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(TRD)

#endif /* XADASTER_TR_DOS_C */
