#ifndef XADMASTER_MXM_SIMPLEARC_C
#define XADMASTER_MXM_SIMPLEARC_C

/*  $Id: MXM-SimpleArc.c,v 1.6 2005/06/23 14:54:41 stoecker Exp $
    MXM-Simple Archive SFX file archiver client

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
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/


#include "../unix/xadClient.h"

#ifndef  XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("MXM-SimpleArc 1.5 (22.02.2004)")

#define MXMSIMPLEARC_VERSION            1
#define MXMSIMPLEARC_REVISION           5

XADRECOGDATA(MXMSimpleArc)
{
  if(((xadUINT32 *)data)[00] == 0x000003F3 && /* HUNK_HEADER */
     ((xadUINT32 *)data)[15] == 0x4EAEFDD8 &&
     ((xadUINT32 *)data)[17] == 0x4A806700 &&
     ((xadUINT32 *)data)[19] == 0x01142E28 &&
     ((xadUINT32 *)data)[20] == 0x00A07254 &&
     ((xadUINT32 *)data)[21] == 0x2F410020)
  {
    return 1;
  }
  return 0;
}

struct MXMSimpleArcData {
  xadUINT32 SkipSize;
  xadUINT32 Size;
  xadUINT8  Name[17];
};

XADGETINFO(MXMSimpleArc)
{
  xadINT32 err, i, j, num = 1;
  struct MXMSimpleArcData sd;
  struct xadFileInfo *fi = 0, *fi2;

  sd.SkipSize = 1;
  sd.Name[16] = 0; /* for names with 16 bytes */

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x264, 0, ai)))
    return err;
  while(!err && sd.SkipSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 24, &sd, ai)))
    {
      j = ai->xai_InPos;
      if(!(i = strlen((char *)sd.Name)))
        break; /* last entry */
      if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, sd.SkipSize-24, 0, ai)))
      {
        if((fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        XAD_OBJNAMESIZE, i, TAG_DONE)))
        {
          fi2->xfi_DataPos = j; /* file position */
          fi2->xfi_Size = sd.Size;
          fi2->xfi_EntryNumber = num++;
          fi2->xfi_CrunchSize = sd.Size;
          fi2->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS;
          for(j = 0; j < i; ++j)
            fi2->xfi_FileName[j] = sd.Name[j];
          err = xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
          &fi2->xfi_Date, TAG_DONE);
          if(fi)
            fi->xfi_Next = fi2;
          else
            ai->xai_FileInfo = fi2;
          fi = fi2;
        }
        else
          err = XADERR_NOMEMORY;
      }
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return fi ? 0 : XADERR_ILLEGALDATA;
}

XADUNARCHIVE(MXMSimpleArc)
{
  return xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size, 0, ai);
}

XADFIRSTCLIENT(MXMSimpleArc) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  MXMSIMPLEARC_VERSION,
  MXMSIMPLEARC_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_MXMSIMPLEARC,
  "MXM-Simple Archive SFX",
  XADRECOGDATAP(MXMSimpleArc),
  XADGETINFOP(MXMSimpleArc),
  XADUNARCHIVEP(MXMSimpleArc),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(MXMSimpleArc)

#endif /* XADMASTER_MXM_SIMPLEARC_C */
