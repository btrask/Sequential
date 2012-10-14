#ifndef XADMASTER_PACKDEV_C
#define XADMASTER_PACKDEV_C

/*  $Id: PackDev.c,v 1.6 2005/06/23 14:54:41 stoecker Exp $
    PackDev disk archiver client

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

/* For now SectorLabel information is ignored, as current
PackDev has empty labels always. */


#include "../unix/xadClient.h"
#include "xadXPK.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("PackDev 1.5 (23.2.2004)")

#define PACKDEV_VERSION         1
#define PACKDEV_REVISION        5

#ifndef TD_LABELSIZE
  #define TD_LABELSIZE 16
#endif

struct PackDevHead {
  xadUINT8              pd_Header[4];   /* equals 'PKD\x13' */
  xadUINT32             pd_BlockNum;    /* Number of blocks */
  xadUINT32             pd_BlockSize;   /* size of one block */
  xadUINT32             pd_Reserved;    /* Reserved blocks */
  xadUINT32             pd_TrackLength; /* Length of one track*/
  xadUINT32             pd_xpkBufferSize; /* in byte */
  xadUINT32             pd_xpkPacker;   /* XPK packer type */
  xadUINT32 pad1;       /* These are fields containing the XPK packer name */
  xadUINT32 pad2;       /* Don't know, why the author used 24bytes instead */
  xadUINT32 pad3;       /* of the required 4. */
  xadUINT32 pad4;       /* The fields are ignored by that client */
  xadUINT32 pad5;
  xadUINT16             pd_xpkMode;      /* XPK mode Number 0..100 */
  xadUINT16             pd_KnownFileSys; /* When all data stored, this is 0, else 1 */
};

struct PackDevHeadOld {
  xadUINT8              pd_Header[4];   /* equals 'PKD\x11' */
  xadUINT32             pd_BlockNum;    /* Number of blocks */
  xadUINT32             pd_BlockSize;   /* size of one block */
  xadUINT32             pd_Reserved;    /* Reserved blocks */
  xadUINT32             pd_TrackLength; /* Length of one track*/
  xadUINT32             pd_xpkBufferSize; /* in byte */
  xadUINT32             pd_xpkPacker;   /* XPK packer type */
  xadUINT16             pd_xpkMode;      /* XPK mode Number 0..100 */
  xadUINT16             pd_KnownFileSys; /* When all data stored, this is 0, else 1 */
};

/* Every block has following structure:
 xadUINT32 size
 xadUINT32 data[...]
 xadUINT32 checksum

Where data are the blocks and additionally the SectorLabels (16 Byte).

Checksum is missing in PackDev11 Version.
*/

#define PKD_XPKPACKED   (1<<0)
#define PKD_OLDMODE     (1<<1)

XADRECOGDATA(PackDev)
{
  if(((xadUINT32 *)data)[0] == 0x504B4413 || ((xadUINT32 *)data)[0] == 0x504B4411)
    return 1;
  else
    return 0;
}

static xadINT32 PKDdecrBuf(xadSTRPTR *buf, xadUINT32 *i, struct xadArchiveInfo *ai,
struct xadMasterBase *xadMasterBase, xadUINT32 oldmode)
{
  xadINT32 err, size;
  if(!(err = xadHookAccess(XADM XADAC_READ, 4, &size, ai)))
  {
    if(!(err = xpkDecrunch(buf, i, ai, xadMasterBase)))
    {
      if(!oldmode)
        err = xadHookAccess(XADM XADAC_READ, 4, &size, ai);
    }
  }
  return err;
}

/* maybe there are some errors in that code, not tested yet */
XADGETINFO(PackDev)
{
  struct PackDevHead h;
  xadINT32 err;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct PackDevHeadOld), &h, ai)))
  {
    if(h.pd_Header[3] == 0x11 || !(err = xadHookAccess(XADM XADAC_READ,
    sizeof(struct PackDevHead)-sizeof(struct PackDevHeadOld), ((xadSTRPTR) &h) +
    sizeof(struct PackDevHeadOld), ai)))
    {
      struct xadDiskInfo *xdi;
      xadUINT32 blksiz = 0, i, dat[10], spos;
      xadSTRPTR buf = 0;

      if(h.pd_Header[3] == 0x11)
      {
        h.pd_KnownFileSys = ((struct PackDevHeadOld *) &h)->pd_KnownFileSys;
/*      h.pd_xpkMode = ((struct PackDevHeadOld *) &h)->pd_xpkMode; */
      }

      /* check for password flag */
      if(h.pd_xpkPacker && !err && !(err = xadHookAccess(XADM XADAC_READ, 40, dat, ai))
      && !(err = xadHookAccess(XADM XADAC_INPUTSEEK, -40, 0, ai)))
      {
        if(dat[9] & (1<<25))
          ai->xai_Flags |= XADAIF_CRYPTED;
      }

      spos = ai->xai_InPos;

      if(h.pd_KnownFileSys)
      {
        blksiz = h.pd_BlockNum;
        if(h.pd_xpkPacker)
          err = PKDdecrBuf(&buf, &i, ai, xadMasterBase, h.pd_Header[3] == 0x11);
        else
        {
          if(!(buf = (xadSTRPTR) xadAllocVec(XADM (i = blksiz>>3), XADMEMF_ANY)))
            err = XADERR_NOMEMORY;
          else
          {
            err = xadHookAccess(XADM XADAC_READ, i, buf, ai);
            spos = ai->xai_InPos;
          }
        }
      }

      if(!err)
      {
        if((xdi = (struct xadDiskInfo *) xadAllocObject(XADM XADOBJ_DISKINFO,
        blksiz ? XAD_OBJBLOCKENTRIES : TAG_DONE, blksiz, TAG_DONE)))
        {
          if(ai->xai_Flags & XADAIF_CRYPTED)
            xdi->xdi_Flags |= XADDIF_CRYPTED;
          xdi->xdi_Flags |= XADDIF_NOCYLINDERS|XADDIF_NOLOWCYL|XADDIF_SEEKDATAPOS|
                            XADDIF_NOHIGHCYL|XADDIF_NOHEADS|XADDIF_NOCYLSECTORS;
          xdi->xdi_TotalSectors = h.pd_BlockNum;
          xdi->xdi_SectorSize = h.pd_BlockSize;
          xdi->xdi_TrackSectors = h.pd_TrackLength / h.pd_BlockSize;
          xdi->xdi_EntryNumber = 1;
          xdi->xdi_DataPos = spos;
          i = 0;
          if(h.pd_xpkPacker)
            i |= PKD_XPKPACKED;
          if(h.pd_Header[3] == 0x11)
            i |= PKD_OLDMODE;
          xdi->xdi_PrivateInfo = (xadPTR) i;
          ai->xai_DiskInfo = xdi;

          /* does nothing if blksiz == 0 */
          if(blksiz)
          {
            blksiz -= h.pd_Reserved;
            for(i = 0; i < blksiz;)
            {
              xadUINT32 l, j;

              l = EndGetM32(buf+(i>>3));
              for(j = 0; j < 32; ++j)
              {
                if(l & (1 << j))
                  xdi->xdi_BlockInfo[i+h.pd_Reserved] |= XADBIF_CLEARED;
                ++i;
              }
            }
          }
        }
        else
          err = XADERR_NOMEMORY;
      }
      if(buf)
        xadFreeObjectA(XADM buf, 0);
    }
  }

  return err;
}

XADUNARCHIVE(PackDev)
{
  xadUINT32 i, j, trsec, numsecs = 0;
  xadINT32 err = 0, secsize;
  struct xadDiskInfo *di;
  xadSTRPTR temp;

  di = ai->xai_CurDisk;
  secsize = di->xdi_SectorSize;
  trsec = di->xdi_TrackSectors;

  if(!(temp = xadAllocVec(XADM di->xdi_SectorSize*di->xdi_TrackSectors, XADMEMF_ANY)))
    return XADERR_NOMEMORY;

  if(!(((xadUINT32) di->xdi_PrivateInfo) & PKD_XPKPACKED))
  {
    numsecs = 0;
    for(i = 0; !err && i < di->xdi_TotalSectors; ++i)
    {
      j = (i % trsec)*secsize;

      if(di->xdi_BlockInfo && di->xdi_BlockInfo[i])
        memset(temp+j, 0, secsize);
      else
      {
        err = xadHookAccess(XADM XADAC_READ, secsize, temp+j, ai);
        ++numsecs;
      }
      /* skip the empty sectorlabels and write data */
      if((i % trsec) == (trsec-1) && !err)
      {
        if(!numsecs || !(err = xadHookAccess(XADM XADAC_INPUTSEEK, TD_LABELSIZE*numsecs, 0, ai)))
          err = xadHookAccess(XADM XADAC_WRITE, trsec*secsize, temp, ai);
        numsecs = 0;
      }
    }
  }
  else
  {
    xadUINT32 size;
    xadINT32 pos = 0, ressize;
    xadSTRPTR buf = 0;

    err = PKDdecrBuf(&buf, &size, ai, xadMasterBase,
    (((xadUINT32) di->xdi_PrivateInfo) & PKD_OLDMODE));

    if(di->xdi_BlockInfo)
      pos += di->xdi_TotalSectors>>3;

    for(i = 0; !err && i < di->xdi_TotalSectors; ++i)
    {
      j = (i % trsec)*secsize;

      if(di->xdi_BlockInfo && di->xdi_BlockInfo[i])
        memset(temp+j, 0, secsize);
      else
      {
        ++numsecs;
        if((ressize = size-pos) >= secsize)
        {
          xadCopyMem(XADM buf+pos, temp+j, secsize);
          pos += secsize;
        }
        else
        {
          if(ressize > 0)
          {
            xadCopyMem(XADM buf+pos, temp+j, ressize);
            pos += ressize;
          }
          else if(ressize < 0)
            ressize = 0;
          xadFreeObjectA(XADM buf, 0);
          buf = 0;
          pos -= size;
          if(!(err = PKDdecrBuf(&buf, &size, ai, xadMasterBase,
          (((xadUINT32) di->xdi_PrivateInfo) & PKD_OLDMODE))))
          {
            xadCopyMem(XADM buf+pos, temp+j+ressize, secsize-ressize);
            pos += secsize-ressize;
          }
        }
      }
      /* skip the empty sectorlabels and write data */
      if((i % trsec) == (trsec-1) && !err)
      {
        pos += TD_LABELSIZE*numsecs;
        err = xadHookAccess(XADM XADAC_WRITE, trsec*secsize, temp, ai);
        numsecs = 0;
      }
    }
    if(buf)
      xadFreeObjectA(XADM buf, 0);
  }

  xadFreeObjectA(XADM temp, 0);

  return err;
}

XADFIRSTCLIENT(PackDev) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  PACKDEV_VERSION,
  PACKDEV_REVISION,
  4,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_PACKDEV,
  "PackDev",
  XADRECOGDATAP(PackDev),
  XADGETINFOP(PackDev),
  XADUNARCHIVEP(PackDev),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(PackDev)

#endif /* XADMASTER_PACKDEV_C */
