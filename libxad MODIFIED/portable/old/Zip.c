#ifndef XADMASTER_ZIP_C
#define XADMASTER_ZIP_C

/*  $Id: Zip.c,v 1.15 2005/06/23 14:54:41 stoecker Exp $
    Zip file archiver client

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

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 13
#endif

XADCLIENTVERSTR("Zip 1.12 (29.03.2004)")

#define ZIP_VERSION             1
#define ZIP_REVISION            12
#define WINZIP_VERSION          ZIP_VERSION
#define WINZIP_REVISION         ZIP_REVISION
#define GZIP_VERSION            ZIP_VERSION
#define GZIP_REVISION           ZIP_REVISION
#define ZIPEXE_VERSION          ZIP_VERSION
#define ZIPEXE_REVISION         ZIP_REVISION
#define GZIPSFX_VERSION         ZIP_VERSION
#define GZIPSFX_REVISION        ZIP_REVISION

#define ZIPMULTI        0x504B0708
#define ZIPSTRANGE      0x504B3030

#define ZIPEND          0x504B0506
#define ZIPLOCAL        0x504B0304
#define ZIPCENTRAL      0x504B0102

#define ZIPM_STORED     0
#define ZIPM_SHRUNK     1
#define ZIPM_REDUCED1   2
#define ZIPM_REDUCED2   3
#define ZIPM_REDUCED3   4
#define ZIPM_REDUCED4   5
#define ZIPM_IMPLODED   6
#define ZIPM_TOKENIZED  7
#define ZIPM_DEFLATED   8

#define ZIPM_COPY       50

struct ZipQDirect {
  xadUINT8 Length[4];   /* file length */
  xadUINT8 Access;      /* file access type */
  xadUINT8 Type;        /* file type */
  xadUINT8 DataLen[4];  /* data length */
  xadUINT8 Reserved[4];
  xadUINT8 NameSize[2]; /* size of filename */
  xadUINT8 Name[36];    /* filename */
  xadUINT8 UpdTime[4];  /* time of last update */
  xadUINT8 RefDate[4];  /* file version number */
  xadUINT8 BakTime[4];  /* time of last backup (archive date) */
};

#define ZIPPRIVFLAG_OWNCOMMENT  (1<<0)

struct ZipPrivate {
  xadUINT8 CompressionMethod;
  xadUINT8 PrivFlags;
  xadUINT16 Flags;
  xadUINT32 CRC32;
  xadUINT32 Date;
  xadUINT32 Offset;
};

struct ZipLocal {
  xadUINT8 ExtractVersion[2];
  xadUINT8 Flags[2];
  xadUINT8 CompressionMethod[2];
  xadUINT8 Date[4];
  xadUINT8 CRC32[4];
  xadUINT8 CompSize[4];
  xadUINT8 UnCompSize[4];
  xadUINT8 NameLength[2];
  xadUINT8 ExtraLength[2];
  /* followed by filename and extra field */
};

struct ZipNoSeekData { /* for no seek archives */
  xadUINT8 CRC32[4];
  xadUINT8 CompSize[4];
  xadUINT8 UnCompSize[4];
};

struct ZipCentral {
  xadUINT8 CreaterVersion;
  xadUINT8 System;
  xadUINT8 ExtractVersion[2];
  xadUINT8 Flags[2];
  xadUINT8 CompressionMethod[2];
  xadUINT8 Date[4];
  xadUINT8 CRC32[4];
  xadUINT8 CompSize[4];
  xadUINT8 UnCompSize[4];
  xadUINT8 NameLength[2];
  xadUINT8 ExtraLength[2];
  xadUINT8 CommentLength[2];
  xadUINT8 StartDisk[2];
  xadUINT8 IntFileAttrib[2];
  xadUINT8 ExtFileAttrib[4];
  xadUINT8 LocHeaderOffset[4];
  /* followed by filename, extra field and comment */
};

struct ZipExtra {
  xadUINT8 ID[2];
  xadUINT8 Size[2];
};

struct ZipEnd {
  xadUINT8 DiskNumber[2];
  xadUINT8 CentralDirStartDisk[2];
  xadUINT8 NumEntriesDisk[2];
  xadUINT8 NumEntries[2];
  xadUINT8 CentralSize[4];
  xadUINT8 CentralOffset[4];
  xadUINT8 CommentLength[2];
  /* followed by comment */
};

#define ZIPPI(a) ((struct ZipPrivate *) ((a)->xfi_PrivateInfo))

static const xadSTRPTR ziptypes[] = {
"stored", "shrunk", "reduced 1", "reduced 2", "reduced 3", "reduced 4",
"imploded", 0, "deflated"};

XADRECOGDATA(Zip)
{
  if(data[0] == 'P' && data[1] == 'K' && ((data[2] == 3 && data[3] == 4) ||
  (data[4] == 'P' && data[5] == 'K' && data[6] == 3 && data[7] == 4)))
    return 1;
  return 0;
}

static xadINT32 ParseZipExt(xadUINT32 len, struct xadFileInfo *fi,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadINT32 err = 0;
  xadUINT32 j;
  struct ZipExtra ze;

  while(len >= 9 && !err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, &ze, ai)))
    {
      len -= 4; j = EndGetI16(ze.Size);
      if((xadUINT32)j > len)
        break;
      else if(EndGetM16(ze.ID) == 0x5554 && j == 5)
      {
        xadUINT8 r[5];

        if(!(err = xadHookAccess(XADM XADAC_READ, 5, r, ai)))
        {
          len -= 5;
          if(r[0] == 1)
          {
            xadConvertDates(XADM XAD_DATEUNIX, (r[1])+(r[2]<<8)+(r[3]<<16)
            +(r[4]<<24), XAD_GETDATEXADDATE, &fi->xfi_Date, XAD_MAKELOCALDATE,
            XADTRUE, TAG_DONE);
            break;
          }
        }
      }
      else if(EndGetM16(ze.ID) == 0x4AFB && j >= 64+4)
      {
        xadUINT32 r, s = 0;
        xadUINT8 buf[4];
        if(!(err = xadHookAccess(XADM XADAC_READ, 4, &buf, ai)))
        {
          s = 4;
          r = EndGetM32(buf);
          if(r == 0x515A4844 || r == 0x51444F53)
          {
            struct ZipQDirect zd;

            if(r == 0x51444F53)
            {
              xadHookAccess(XADM XADAC_INPUTSEEK, 4, 0, ai);
              s += 4;
            }

            if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct ZipQDirect),
            &zd, ai)))
            {
              s += sizeof(struct ZipQDirect);
              if(!fi->xfi_Comment && (fi->xfi_Comment =
              (xadSTRPTR) xadAllocVec(XADM 25, XADMEMF_PUBLIC)))
              {
                ZIPPI(fi)->PrivFlags |= ZIPPRIVFLAG_OWNCOMMENT;
                sprintf(fi->xfi_Comment, "QL_TASK:0406%08lx",
                (long)EndGetM32(zd.DataLen));
              }
            }
          }
        }
        if(s < j)
          err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) j-s, 0, ai);
        len -= j;
      }
      else
      {
        err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) j, 0, ai);
        len -= j;
      }
    }
  }

  if(len && !err)
    err = xadHookAccess(XADM XADAC_INPUTSEEK, len, 0, ai);

  return err;
}

#define ZIPBUFFSIZE 10240
static xadINT32 ZIPScanNext(xadSize *lastpos, struct xadArchiveInfo *ai,
struct xadMasterBase *xadMasterBase)
{
  xadINT32 err = 0, found = 0;
  xadSTRPTR buf;
  xadUINT32 i, bufsize, fsize, spos = 0;

  if((fsize = ai->xai_InSize-*lastpos) < 15)
    return 0;

  if((i = *lastpos - ai->xai_InPos))
  {
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai)))
      return err;
  }

  if((bufsize = ZIPBUFFSIZE) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && !found && fsize >= 15)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
    {
      for(i = 0; i < bufsize - 10 && !found; ++i)
      {
        if(buf[i] == 'P' && buf[i+1] == 'K' && (
        (buf[i+2] == 3 && buf[i+3] == 4 && buf[i+4] >= 10 && buf[i+4] < 40
        && !buf[i+9]) ||
        (buf[i+2] == 1 && buf[i+3] == 2 && buf[i+4] >= 10 && buf[i+4] < 40)))
          found = 1;
      }
      if(!found)
      {
        xadCopyMem(XADM buf+i, buf, 10);
        spos = 10;
        fsize -= bufsize - 10;
        if(fsize < bufsize)
          bufsize = fsize;
      }
    }
  }

  xadFreeObjectA(XADM buf, 0);

  if(found)
  {
    err = xadHookAccess(XADM XADAC_INPUTSEEK, i-1-bufsize, 0, ai);
    *lastpos = ai->xai_InPos + 2;
  }

  return err;
}

static xadINT32 ZIPScanSize(struct xadArchiveInfo *ai, struct xadFileInfo *fi,
struct xadMasterBase *xadMasterBase)
{
  xadINT32 err = 0, found = 0;
  xadSTRPTR buf;
  xadSize i=0,bufsize, fsize, spos = 0, size = 0;

  if((fsize = ai->xai_InSize-ai->xai_InPos) < 20)
    return 0;

  if((bufsize = ZIPBUFFSIZE) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && !found && fsize >= 20)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
    {
      for(i = 0; i < bufsize - 16 && !found; ++i)
      {
        if(buf[i] == 'P' && buf[i+1] == 'K' && buf[i+2] == 7 && buf[i+3] == 8
        && (xadSize)EndGetI32(buf+i+8) == size)
          found = 2;
        else if((xadSize)EndGetI32(buf+i+4) == size)
          found = 1;
        ++size;
      }
      if(!found)
      {
        xadCopyMem(XADM buf+i, buf, 16);
        spos = 16;
        fsize -= bufsize - 16;
        if(fsize < bufsize)
          bufsize = fsize;
      }
    }
  }

  if(found)
  {
    --i;
    if(found == 2)
      i += 4;
    fi->xfi_Size = EndGetI32(buf+i+8);
    fi->xfi_CrunchSize = EndGetI32(buf+i+4);
    ZIPPI(fi)->CRC32 = EndGetI32(buf+i);
    i += 12;
    err = xadHookAccess(XADM XADAC_INPUTSEEK, i-bufsize, 0, ai);
  }

  xadFreeObjectA(XADM buf, 0);

  return err;
}

/* FIXME: Should use charset conversion */
/* remap the 0x80 to 0x9F chars of PC8. This should fix some name problems */
static const xadUINT8 remapPC8[32-5] = {
  199,252,233,226,228,224,229,231,234,235,232,239,238,236,196,197,
  201,230,198,244,246,242,251,249,255,214,220
};

XADGETINFO(Zip)
{
  struct xadFileInfo *fi = 0, *fi2;
  struct ZipLocal zl;
  struct ZipCentral zc;
  struct ZipEnd ze;
  xadINT32 err = 0, stop = 0;
  xadUINT32 lastpos, o;
  xadUINT8 id[4];

  lastpos = ai->xai_InPos;
  while(ai->xai_InPos + 3 < ai->xai_InSize && !stop)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, id, ai)))
    {
      switch(EndGetM32(id))
      {
      case ZIPLOCAL: lastpos = ai->xai_InPos;
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct ZipLocal), &zl, ai)))
        {
          xadUINT32 i;
          i = EndGetI16(zl.NameLength);

          if(EndGetI16(zl.CompressionMethod) > 20)
            err = XADERR_ILLEGALDATA;
          else if(!(fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, i ? XAD_OBJNAMESIZE : TAG_IGNORE, i+1,
          XAD_OBJPRIVINFOSIZE, sizeof(struct ZipPrivate), TAG_DONE)))
            return XADERR_NOMEMORY;
          else
          {
            if(i && (err = xadHookAccess(XADM XADAC_READ, i, fi2->xfi_FileName, ai)))
              xadFreeObjectA(XADM fi2, 0);
            else
            {
              for(o = 0; o < i; ++o)
              {
                if((xadUINT8)fi2->xfi_FileName[o] >= 0x80 && (xadUINT8)fi2->xfi_FileName[o] < 0x9B)
                  fi2->xfi_FileName[o] = remapPC8[fi2->xfi_FileName[o]-0x80];
                if((fi2->xfi_FileName[o]&0x7F) < 0x20)
                {
                  fi2->xfi_FileName[o] = 0;
                  i = o;
                }
              }

              if(!i)
              {
                fi2->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai,
                XAD_EXTENSION, ".zip", TAG_DONE);
                fi2->xfi_Flags |= XADFIF_NOFILENAME|XADFIF_XADSTRFILENAME;
              }
              else if(fi2->xfi_FileName[--i] == '/' && !fi2->xfi_Size)
              {
                fi2->xfi_FileName[i] = 0;
                fi2->xfi_Flags |= XADFIF_DIRECTORY;
              }
              else if(fi && !fi->xfi_Size && !(fi->xfi_Flags & XADFIF_DIRECTORY))
              {
                for(i = 0; fi2->xfi_FileName[i] && fi->xfi_FileName[i] == fi2->xfi_FileName[i]; ++i)
                  ;
                if(!fi->xfi_FileName[i] && fi2->xfi_FileName[i] == '/')
                  fi->xfi_Flags |= XADFIF_DIRECTORY;
              }

              xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(zl.Date), XAD_GETDATEXADDATE,
              &fi2->xfi_Date, TAG_DONE);

              if((i = EndGetI16(zl.ExtraLength)))
                err = ParseZipExt(i, fi2, ai, xadMasterBase);

              ZIPPI(fi2)->Offset = lastpos-4;
              ZIPPI(fi2)->CompressionMethod = EndGetI16(zl.CompressionMethod);
#ifdef DEBUG
  if(ZIPPI(fi2)->CompressionMethod == 2 || ZIPPI(fi2)->CompressionMethod == 3
  || ZIPPI(fi2)->CompressionMethod == 4 || ZIPPI(fi2)->CompressionMethod == 7)
    DebugFileSearched(ai, "Untested compression method %d",
    ZIPPI(fi2)->CompressionMethod);
#endif

              fi2->xfi_EntryInfo = ziptypes[ZIPPI(fi2)->CompressionMethod];
              ZIPPI(fi2)->Flags = EndGetI16(zl.Flags);
              if(ZIPPI(fi2)->Flags & (1<<0))
              {
                fi2->xfi_Flags |= XADFIF_CRYPTED;
                ai->xai_Flags |= XADAIF_CRYPTED;
              }
              fi2->xfi_DataPos = ai->xai_InPos;
              fi2->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_ENTRYMAYCHANGE|XADFIF_EXTRACTONBUILD;

              if(ZIPPI(fi2)->Flags & (1<<3))
                err = ZIPScanSize(ai, fi2, xadMasterBase);
              else
              {
                fi2->xfi_Size = EndGetI32(zl.UnCompSize);
                fi2->xfi_CrunchSize = EndGetI32(zl.CompSize);
                ZIPPI(fi2)->Date = EndGetI32(zl.Date);
                ZIPPI(fi2)->CRC32 = EndGetI32(zl.CRC32);
              }

              if(err)
                xadFreeObjectA(XADM fi2, 0);
              else
              {
                err = xadAddFileEntry(XADM fi2, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
                fi = fi2;
              }

              if(err)
                stop = 1;
              else if(!(ZIPPI(fi2)->Flags & (1<<3)))
              {
                if(fi2->xfi_CrunchSize+ai->xai_InPos > ai->xai_InSize)
                {
                  ai->xai_Flags |= XADAIF_FILECORRUPT; /* cannot seek, scan for next! */
                }
                else if((err = xadHookAccess(XADM XADAC_INPUTSEEK, fi2->xfi_CrunchSize, 0, ai)))
                  stop = 1;
              }
            }
          }
        }
        else
          stop = 1;
        break;
      case ZIPCENTRAL: lastpos = ai->xai_InPos;
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct ZipCentral), &zc, ai)))
        {
          xadUINT32 i;

          if(zc.NameLength)
            err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetI16(zc.NameLength), 0, ai);
          o = EndGetI32(zc.LocHeaderOffset);
          if((i = EndGetI16(zc.StartDisk)) && ai->xai_MultiVolume)
          {
            xadUINT32 j;

            for(j = 1; j < i && ai->xai_MultiVolume[j]; ++j) /* security loop for field access */
              ;
            j = ai->xai_MultiVolume[j] + o;
            /* This either results in o (when not enough entries) or in correct pos */

            for(fi2 = ai->xai_FileInfo; fi2 && ZIPPI(fi2)->Offset != o &&
            ZIPPI(fi2)->Offset != j; fi2 = fi2->xfi_Next)
              ;
          }
          else
          {
            for(fi2 = ai->xai_FileInfo; fi2 && ZIPPI(fi2)->Offset != o; fi2 = fi2->xfi_Next)
              ;
          }

          if(fi2 && !err)
          {
            if(EndGetI32(zc.Date))
              ZIPPI(fi2)->Date = EndGetI32(zc.Date);
            if(EndGetI32(zc.CRC32) && !ZIPPI(fi2)->CRC32)
              ZIPPI(fi2)->CRC32 = EndGetI32(zc.CRC32);
            if(zc.System == 1)
              fi2->xfi_Protection = ((EndGetI32(zc.ExtFileAttrib)>>16)^15)&0xFF;
            else if(!zc.System)
            {
              xadConvertProtection(XADM XAD_PROTMSDOS, EndGetI32(zc.ExtFileAttrib), XAD_GETPROTAMIGA,
              &fi2->xfi_Protection, TAG_DONE);
              if(EndGetI32(zc.ExtFileAttrib) & (1<<4))
                fi2->xfi_Flags |= XADFIF_DIRECTORY;
            }
            else if(zc.System == 2)
              xadConvertProtection(XADM XAD_PROTUNIX, EndGetI32(zc.ExtFileAttrib), XAD_GETPROTAMIGA,
              &fi2->xfi_Protection, TAG_DONE);

            if((i = EndGetI16(zc.ExtraLength)))
              err = ParseZipExt(i, fi2, ai, xadMasterBase);
            if(!err && (i = EndGetI16(zc.CommentLength)))
            {
              if(!fi2->xfi_Comment && (fi2->xfi_Comment = (xadSTRPTR)
              xadAllocVec(XADM i+1, XADMEMF_CLEAR|XADMEMF_PUBLIC)))
              {
                err = xadHookAccess(XADM XADAC_READ, i, fi2->xfi_Comment, ai);
                ZIPPI(fi2)->PrivFlags |= ZIPPRIVFLAG_OWNCOMMENT;
              }
              else
                err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai);
            }
          }
          else if(!err)
          {
            if(EndGetI16(zc.ExtraLength))
              if((err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetI16(zc.ExtraLength), 0, ai)))
                stop = 1;
            if(EndGetI16(zc.CommentLength) && !err)
              if((err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetI16(zc.CommentLength), 0, ai)))
                stop = 1;
          }
        }
        else
          stop = 1;
        break;
      case ZIPEND:
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct ZipEnd), &ze, ai)))
        {
          xadINT32 i;

          if((i = EndGetI16(ze.CommentLength)))
          {
            if(!(fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
            XAD_OBJPRIVINFOSIZE, sizeof(struct ZipPrivate), TAG_DONE)))
              return XADERR_NOMEMORY;
            else
            {
              xadConvertDates(XADM XAD_DATECURRENTTIME, XADTRUE, XAD_GETDATEXADDATE, &fi2->xfi_Date, TAG_DONE);

              fi2->xfi_FileName = "ZipInfo.TXT";
              fi2->xfi_Size = fi2->xfi_CrunchSize = i;

              ZIPPI(fi2)->CompressionMethod = ZIPM_COPY;
              fi2->xfi_DataPos = ai->xai_InPos;
              fi2->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_INFOTEXT|XADFIF_NOFILENAME|XADFIF_EXTRACTONBUILD;

              if((err = xadAddFileEntry(XADM fi2, ai, XAD_SETINPOS, ai->xai_InPos+i, TAG_DONE)))
                stop = 1;
              fi = fi2;
            }
          }
        }
        else
          stop = 1;
      case ZIPMULTI: case ZIPSTRANGE: /* ignore these, use break of ZIPEND */
        lastpos = ai->xai_InPos;
        break;
      default: err = XADERR_DATAFORMAT; break;
      }
    }
    else
      stop = 1;

    if(err)
    {
      ai->xai_Flags |= XADAIF_FILECORRUPT;
      ai->xai_LastError = err;
      if(!stop)
      {
        if((err = ZIPScanNext(&lastpos, ai, xadMasterBase)))
          stop = 1;
      }
    }
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/**************************************************************************************************/

#define ZIPWSIZE        0x8000  /* window size--must be a power of two, and at least 32K for zip's deflate method */
#define ZIPLBITS        9       /* bits in base literal/length lookup table */
#define ZIPDBITS        6       /* bits in base distance lookup table */
#define ZIPBMAX         16      /* maximum bit length of any code (16 for explode) */
#define ZIPN_MAX        288     /* maximum number of codes in any set */

struct ZipData {
  struct xadMasterBase *xadMasterBase;
  struct xadArchiveInfo *ai;
  xadUINT32 insize;
  xadUINT32 csize;     /* this stays unmodified! */
  xadUINT32 ucsize;
  xadUINT32 errcode;
  xadUINT32 CRC;
  xadUINT32 Flags;
  xadUINT32 Keys[3];
  xadSTRPTR Password;
  xadUINT8 *inpos;
  xadUINT8 *inend;

  /* inflate */
  xadUINT32  bb;               /* bit buffer */
  xadUINT32  bk;               /* bits in bit buffer */
  xadUINT32  wp;               /* current position in slide */
  xadUINT32  ll[288+32];       /* literal/length and distance code lengths */
  xadUINT32  c[ZIPBMAX+1];     /* bit length count table */
  xadINT32   lx[ZIPBMAX+1];    /* memory for l[-1..ZIPBMAX-1] */
  struct Ziphuft *u[ZIPBMAX];  /* table stack */
  xadUINT32  v[ZIPN_MAX];      /* values in order of bit length */
  xadUINT32  x[ZIPBMAX+1];     /* bit offsets, then code stack */

  xadUINT8   Stack[8192];      /* reduce uses only 256 byte of this! */
  xadUINT8   Slide[ZIPWSIZE];  /* explode(), inflate(), unreduce() */
  xadUINT8   inbuf[ZIPWSIZE];
};

static xadINT32 Zipgetbyte(struct ZipData *zd)
{
  xadINT32 res = -1;

  if(!zd->errcode)
  {
    struct xadMasterBase *xadMasterBase = zd->xadMasterBase;

    if(zd->inpos == zd->inend)
    {
      xadUINT32 s;

      if((s = zd->inend-zd->inbuf) > zd->insize)
        s = zd->insize;
      if(s && !(zd->errcode = xadHookAccess(XADM XADAC_READ, s, zd->inbuf, zd->ai)))
      {
        zd->inpos = zd->inbuf;
        zd->inend = zd->inbuf+s;
        zd->insize -= s;
        res = *(zd->inpos++);
      }
    }
    else
      res = *(zd->inpos++);

    if(res != -1 && (zd->Flags & (1<<0)))
    {
      xadUINT16 tmp;
      xadUINT8 a;

      tmp = zd->Keys[2] | 2;
      res ^= (xadUINT8)(((tmp * (tmp ^ 1)) >> 8));
      a = res;
      zd->Keys[0] = xadCalcCRC32(XADM XADCRC32_ID1, zd->Keys[0], 1, &a);
      zd->Keys[1] += (zd->Keys[0] & 0xFF);
      zd->Keys[1] = zd->Keys[1] * 134775813 + 1;
      a = zd->Keys[1] >> 24;
      zd->Keys[2] = xadCalcCRC32(XADM XADCRC32_ID1, zd->Keys[2], 1, &a);
    }
  }

  return res;
}

static void Zipflush(struct ZipData *zd, xadUINT32 size)
{
  struct xadMasterBase *xadMasterBase = zd->xadMasterBase;
  if(!zd->errcode)
  {
    zd->errcode = xadHookTagAccess(XADM XADAC_WRITE, size, zd->Slide, zd->ai, XAD_GETCRC32, &zd->CRC, TAG_DONE);
  }
}

/**************************************************************************************************/

struct Ziphuft {
  xadUINT8 e;             /* number of extra bits or operation */
  xadUINT8 b;             /* number of bits in this code or subcode */
  union {
    xadUINT16 n;          /* literal, length base, or distance base */
    struct Ziphuft *t;    /* pointer to next level of table */
  } v;
};

/* Tables for deflate from PKZIP's appnote.txt. */
static const xadUINT8 Zipborder[] = /* Order of the bit length code lengths */
{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
static const xadUINT16 Zipcplens[] = /* Copy lengths for literal codes 257..285 */
{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51,
 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0};
static const xadUINT16 Zipcplext[] = /* Extra bits for literal codes 257..285 */
{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4,
  4, 5, 5, 5, 5, 0, 99, 99}; /* 99==invalid */
static const xadUINT16 Zipcpdist[] = /* Copy offsets for distance codes 0..29 */
{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385,
513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
static const xadUINT16 Zipcpdext[] = /* Extra bits for distance codes */
{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10,
10, 11, 11, 12, 12, 13, 13};

/* And'ing with Zipmask[n] masks the lower n bits */

#ifndef XADMASTERFILE
static const xadUINT16 Zipmask[17] = {
 0x0000, 0x0001, 0x0003, 0x0007, 0x000f, 0x001f, 0x003f, 0x007f, 0x00ff,
 0x01ff, 0x03ff, 0x07ff, 0x0fff, 0x1fff, 0x3fff, 0x7fff, 0xffff
};
#else /* save space, as this is double used, except it is xadUINT32 now */
static const xadUINT32 DMS_mask_bits[25];
#define Zipmask DMS_mask_bits
#endif

#define ZIPNEEDBITS(n) {while(k<(n)){xadINT32 c=Zipgetbyte(zd);if(c==-1)break;\
    b|=((xadUINT32)c)<<k;k+=8;}}
#define ZIPDUMPBITS(n) {b>>=(n);k-=(n);}

static xadINT32 Ziphuft_free(struct ZipData *zd, struct Ziphuft *t)
{
  struct xadMasterBase *xadMasterBase = zd->xadMasterBase;
  register struct Ziphuft *p, *q;

  /* Go through linked list, freeing from the allocated (t[-1]) address. */
  p = t;
  while (p != (struct Ziphuft *)NULL)
  {
    q = (--p)->v.t;
    xadFreeObjectA(XADM p, 0);
    p = q;
  }
  return 0;
}

static xadINT32 Ziphuft_build(struct ZipData *zd, xadUINT32 *b,
xadUINT32 n, xadUINT32 s, xadUINT16 *d, xadUINT16 *e,
struct Ziphuft **t, xadINT32 *m)
{
  xadUINT32 a;                 /* counter for codes of length k */
  xadUINT32 el;                /* length of EOB code (value 256) */
  xadUINT32 f;                 /* i repeats in table every f entries */
  xadINT32 g;                  /* maximum code length */
  xadINT32 h;                  /* table level */
  register xadUINT32 i;        /* counter, current code */
  register xadUINT32 j;        /* counter */
  register xadINT32 k;         /* number of bits in current code */
  xadINT32 *l;                 /* stack of bits per table */
  register xadUINT32 *p;       /* pointer into zd->c[], zd->b[], or zd->v[] */
  register struct Ziphuft *q;  /* points to current table */
  struct Ziphuft r;            /* table entry for structure assignment */
  register xadINT32 w;         /* bits before this table == (l * h) */
  xadUINT32 *xp;               /* pointer into x */
  xadINT32 y;                  /* number of dummy codes added */
  xadUINT32 z;                 /* number of entries in current table */
  struct xadMasterBase *xadMasterBase = zd->xadMasterBase;

  l = zd->lx+1;

  /* Generate counts for each bit length */
  el = n > 256 ? b[256] : ZIPBMAX; /* set length of EOB code, if any */

  memset(zd->c, 0, sizeof(zd->c));
  p = b;  i = n;
  do
  {
    zd->c[*p]++; p++;               /* assume all entries <= ZIPBMAX */
  } while (--i);
  if (zd->c[0] == n)                /* null input--all zero length codes */
  {
    *t = (struct Ziphuft *)NULL;
    *m = 0;
    return 0;
  }

  /* Find minimum and maximum length, bound *m by those */
  for (j = 1; j <= ZIPBMAX; j++)
    if (zd->c[j])
      break;
  k = j;                        /* minimum code length */
  if ((xadUINT32)*m < j)
    *m = j;
  for (i = ZIPBMAX; i; i--)
    if (zd->c[i])
      break;
  g = i;                        /* maximum code length */
  if ((xadUINT32)*m > i)
    *m = i;

  /* Adjust last length count to fill out codes, if needed */
  for (y = 1 << j; j < i; j++, y <<= 1)
    if ((y -= zd->c[j]) < 0)
      return 2;                 /* bad input: more codes than bits */
  if ((y -= zd->c[i]) < 0)
    return 2;
  zd->c[i] += y;

  /* Generate starting offsets LONGo the value table for each length */
  zd->x[1] = j = 0;
  p = zd->c + 1;  xp = zd->x + 2;
  while (--i)
  {                 /* note that i == g from above */
    *xp++ = (j += *p++);
  }

  /* Make a table of values in order of bit lengths */
  p = b;  i = 0;
  do{
    if ((j = *p++) != 0)
      zd->v[zd->x[j]++] = i;
  } while (++i < n);


  /* Generate the Huffman codes and for each, make the table entries */
  zd->x[0] = i = 0;             /* first Huffman code is zero */
  p = zd->v;                    /* grab values in bit order */
  h = -1;                       /* no tables yet--level -1 */
  w = l[-1] = 0;                /* no bits decoded yet */
  zd->u[0] = (struct Ziphuft *)NULL;   /* just to keep compilers happy */
  q = (struct Ziphuft *)NULL;      /* ditto */
  z = 0;                        /* ditto */

  /* go through the bit lengths (k already is bits in shortest code) */
  for (; k <= g; k++)
  {
    a = zd->c[k];
    while (a--)
    {
      /* here i is the Huffman code of length k bits for value *p */
      /* make tables up to required level */
      while (k > w + l[h])
      {
        w += l[h++];            /* add bits already decoded */

        /* compute minimum size table less than or equal to *m bits */
        z = (z = g - w) > (xadUINT32)*m ? (xadUINT32)*m : z;        /* upper limit */
        if ((f = 1 << (j = k - w)) > a + 1)     /* try a k-w bit table */
        {                       /* too few codes for k-w bit table */
          f -= a + 1;           /* deduct codes from patterns left */
          xp = zd->c + k;
          while (++j < z)       /* try smaller tables up to z bits */
          {
            if ((f <<= 1) <= *++xp)
              break;            /* enough codes to use up j bits */
            f -= *xp;           /* else deduct codes from patterns */
          }
        }
        if ((xadUINT32)w + j > el && (xadUINT32)w < el)
          j = el - w;           /* make EOB code end at table */
        z = 1 << j;             /* table entries for j-bit table */
        l[h] = j;               /* set table size in stack */

        /* allocate and link in new table */
        if (!(q = (struct Ziphuft *) xadAllocVec(XADM (z + 1)
        *sizeof(struct Ziphuft), XADMEMF_PUBLIC)))
        {
          if(h)
            Ziphuft_free(zd, zd->u[0]);
          zd->errcode = XADERR_NOMEMORY;
          return 3;             /* not enough memory */
        }
        *t = q + 1;             /* link to list for Ziphuft_free() */
        *(t = &(q->v.t)) = (struct Ziphuft *)NULL;
        zd->u[h] = ++q;             /* table starts after link */

        /* connect to last table, if there is one */
        if (h)
        {
          zd->x[h] = i;             /* save pattern for backing up */
          r.b = (xadUINT8)l[h-1];    /* bits to dump before this table */
          r.e = (xadUINT8)(16 + j);  /* bits in this table */
          r.v.t = q;            /* pointer to this table */
          j = (i & ((1 << w) - 1)) >> (w - l[h-1]);
          zd->u[h-1][j] = r;        /* connect to last table */
        }
      }

      /* set up table entry in r */
      r.b = (xadUINT8)(k - w);
      if (p >= zd->v + n)
        r.e = 99;               /* out of values--invalid code */
      else if (*p < s)
      {
        r.e = (xadUINT8)(*p < 256 ? 16 : 15);    /* 256 is end-of-block code */
        r.v.n = *p++;           /* simple code is just the value */
      }
      else
      {
        r.e = (xadUINT8)e[*p - s];   /* non-simple--look up in lists */
        r.v.n = d[*p++ - s];
      }

      /* fill code-like entries with r */
      f = 1 << (k - w);
      for (j = i >> w; j < z; j += f)
        q[j] = r;

      /* backwards increment the k-bit code i */
      for (j = 1 << (k - 1); i & j; j >>= 1)
        i ^= j;
      i ^= j;

      /* backup over finished tables */
      while ((i & ((1 << w) - 1)) != zd->x[h])
        w -= l[--h];            /* don't need to update q */
    }
  }

  /* return actual size of base table */
  *m = l[0];

  /* Return true (1) if we were given an incomplete table */
  return y != 0 && g != 1;
}

static xadINT32 Zipinflate_codes(struct ZipData *zd, struct Ziphuft *tl,
struct Ziphuft *td, xadINT32 bl, xadINT32 bd)
{
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */

  /* make local copies of globals */
  b = zd->bb;                       /* initialize bit buffer */
  k = zd->bk;
  w = zd->wp;                       /* initialize window position */

  /* inflate the coded data */
  ml = Zipmask[bl];             /* precompute masks for speed */
  md = Zipmask[bd];
  while(!zd->errcode)           /* do until end of block */
  {
    ZIPNEEDBITS((xadUINT32)bl)
    if((e = (t = tl + ((xadUINT32)b & ml))->e) > 16)
      do
      {
        if (e == 99)
          return 1;
        ZIPDUMPBITS(t->b)
        e -= 16;
        ZIPNEEDBITS(e)
      } while ((e = (t = t->v.t + ((xadUINT32)b & Zipmask[e]))->e) > 16);
    ZIPDUMPBITS(t->b)
    if (e == 16)                /* then it's a literal */
    {
      zd->Slide[w++] = (xadUINT8)t->v.n;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = 0;
      }
    }
    else                        /* it's an EOB or a length */
    {
      /* exit if end of block */
      if (e == 15)
        break;

      /* get length of block to copy */
      ZIPNEEDBITS(e)
      n = t->v.n + ((xadUINT32)b & Zipmask[e]);
      ZIPDUMPBITS(e);

      /* decode distance of block to copy */
      ZIPNEEDBITS((xadUINT32)bd)
      if ((e = (t = td + ((xadUINT32)b & md))->e) > 16)
        do {
          if (e == 99)
            return 1;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while ((e = (t = t->v.t + ((xadUINT32)b & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      ZIPNEEDBITS(e)
      d = w - t->v.n - ((xadUINT32)b & Zipmask[e]);
      ZIPDUMPBITS(e)

      /* do the copy */
      do
      {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        do
        {
          zd->Slide[w++] = zd->Slide[d++];
        } while (--e);
        if (w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = 0;
        }
      } while (n);
    }
  }

  /* restore the globals from the locals */
  zd->wp = w;                       /* restore global window pointer */
  zd->bb = b;                       /* restore global bit buffer */
  zd->bk = k;

  /* done */
  return 0;
}

/* "decompress" an inflated type 0 (stored) block. */
static xadINT32 Zipinflate_stored(struct ZipData *zd)
{
  xadUINT32 n;           /* number of bytes in block */
  xadUINT32 w;           /* current window position */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */

  /* make local copies of globals */
  b = zd->bb;                       /* initialize bit buffer */
  k = zd->bk;
  w = zd->wp;                       /* initialize window position */

  /* go to byte boundary */
  n = k & 7;
  ZIPDUMPBITS(n);

  /* get the length and its complement */
  ZIPNEEDBITS(16)
  n = ((xadUINT32)b & 0xffff);
  ZIPDUMPBITS(16)
  ZIPNEEDBITS(16)
  if (n != (xadUINT32)((~b) & 0xffff))
    return 1;                   /* error in compressed data */
  ZIPDUMPBITS(16)

  /* read and output the compressed data */
  while(n--)
  {
    ZIPNEEDBITS(8)
    zd->Slide[w++] = (xadUINT8)b;
    if (w == ZIPWSIZE)
    {
      Zipflush(zd, w);
      w = 0;
    }
    ZIPDUMPBITS(8)
  }

  /* restore the globals from the locals */
  zd->wp = w;                       /* restore global window pointer */
  zd->bb = b;                       /* restore global bit buffer */
  zd->bk = k;
  return 0;
}

static xadINT32 Zipinflate_fixed(struct ZipData *zd)
{
  struct Ziphuft *fixed_tl;
  struct Ziphuft *fixed_td;
  xadINT32 fixed_bl, fixed_bd;
  xadINT32 i;                /* temporary variable */
  xadUINT32 *l;

  l = zd->ll;

  /* literal table */
  for(i = 0; i < 144; i++)
    l[i] = 8;
  for(; i < 256; i++)
    l[i] = 9;
  for(; i < 280; i++)
    l[i] = 7;
  for(; i < 288; i++)          /* make a complete, but wrong code set */
    l[i] = 8;
  fixed_bl = 7;
  if((i = Ziphuft_build(zd, l, 288, 257, (xadUINT16 *) Zipcplens, (xadUINT16 *) Zipcplext, &fixed_tl, &fixed_bl)))
    return i;

  /* distance table */
  for(i = 0; i < 30; i++)      /* make an incomplete code set */
    l[i] = 5;
  fixed_bd = 5;
  if((i = Ziphuft_build(zd, l, 30, 0, (xadUINT16 *) Zipcpdist, (xadUINT16 *) Zipcpdext, &fixed_td, &fixed_bd)) > 1)
  {
    Ziphuft_free(zd, fixed_tl);
    return i;
  }

  /* decompress until an end-of-block code */
  i = Zipinflate_codes(zd, fixed_tl, fixed_td, fixed_bl, fixed_bd);

  Ziphuft_free(zd, fixed_td);
  Ziphuft_free(zd, fixed_tl);
  return i;
}

/* decompress an inflated type 2 (dynamic Huffman codes) block. */
static xadINT32 Zipinflate_dynamic(struct ZipData *zd)
{
  xadINT32 i;           /* temporary variables */
  xadUINT32 j;
  xadUINT32 *ll;
  xadUINT32 l;                  /* last length */
  xadUINT32 m;                  /* mask for bit lengths table */
  xadUINT32 n;                  /* number of lengths to get */
  struct Ziphuft *tl;      /* literal/length code table */
  struct Ziphuft *td;      /* distance code table */
  xadINT32 bl;              /* lookup bits for tl */
  xadINT32 bd;              /* lookup bits for td */
  xadUINT32 nb;                 /* number of bit length codes */
  xadUINT32 nl;                 /* number of literal/length codes */
  xadUINT32 nd;                 /* number of distance codes */
  register xadUINT32 b;     /* bit buffer */
  register xadUINT32 k; /* number of bits in bit buffer */

  /* make local bit buffer */
  b = zd->bb;
  k = zd->bk;
  ll = zd->ll;

  /* read in table lengths */
  ZIPNEEDBITS(5)
  nl = 257 + ((xadUINT32)b & 0x1f);      /* number of literal/length codes */
  ZIPDUMPBITS(5)
  ZIPNEEDBITS(5)
  nd = 1 + ((xadUINT32)b & 0x1f);        /* number of distance codes */
  ZIPDUMPBITS(5)
  ZIPNEEDBITS(4)
  nb = 4 + ((xadUINT32)b & 0xf);         /* number of bit length codes */
  ZIPDUMPBITS(4)
  if(nl > 288 || nd > 32)
    return 1;                   /* bad lengths */

  /* read in bit-length-code lengths */
  for(j = 0; j < nb; j++)
  {
    ZIPNEEDBITS(3)
    ll[Zipborder[j]] = (xadUINT32)b & 7;
    ZIPDUMPBITS(3)
  }
  for(; j < 19; j++)
    ll[Zipborder[j]] = 0;

  /* build decoding table for trees--single level, 7 bit lookup */
  bl = 7;
  if((i = Ziphuft_build(zd, ll, 19, 19, NULL, NULL, &tl, &bl)) != 0)
  {
    if(i == 1)
      Ziphuft_free(zd, tl);
    return i;                   /* incomplete code set */
  }

  /* read in literal and distance code lengths */
  n = nl + nd;
  m = Zipmask[bl];
  i = l = 0;
  while((xadUINT32)i < n && !zd->errcode)
  {
    ZIPNEEDBITS((xadUINT32)bl)
    j = (td = tl + ((xadUINT32)b & m))->b;
    ZIPDUMPBITS(j)
    j = td->v.n;
    if (j < 16)                 /* length of code in bits (0..15) */
      ll[i++] = l = j;          /* save last length in l */
    else if (j == 16)           /* repeat last length 3 to 6 times */
    {
      ZIPNEEDBITS(2)
      j = 3 + ((xadUINT32)b & 3);
      ZIPDUMPBITS(2)
      if((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = l;
    }
    else if (j == 17)           /* 3 to 10 zero length codes */
    {
      ZIPNEEDBITS(3)
      j = 3 + ((xadUINT32)b & 7);
      ZIPDUMPBITS(3)
      if ((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = 0;
      l = 0;
    }
    else                        /* j == 18: 11 to 138 zero length codes */
    {
      ZIPNEEDBITS(7)
      j = 11 + ((xadUINT32)b & 0x7f);
      ZIPDUMPBITS(7)
      if ((xadUINT32)i + j > n)
        return 1;
      while (j--)
        ll[i++] = 0;
      l = 0;
    }
  }

  /* free decoding table for trees */
  Ziphuft_free(zd, tl);

  /* restore the global bit buffer */
  zd->bb = b;
  zd->bk = k;

  /* build the decoding tables for literal/length and distance codes */
  bl = ZIPLBITS;
  if((i = Ziphuft_build(zd, ll, nl, 257, (xadUINT16 *) Zipcplens, (xadUINT16 *) Zipcplext, &tl, &bl)) != 0)
  {
    if(i == 1)
      Ziphuft_free(zd, tl);
    return i;                   /* incomplete code set */
  }
  bd = ZIPDBITS;
  Ziphuft_build(zd, ll + nl, nd, 0, (xadUINT16 *) Zipcpdist, (xadUINT16 *) Zipcpdext, &td, &bd);

  /* decompress until an end-of-block code */
  if(Zipinflate_codes(zd, tl, td, bl, bd))
    return 1;

  /* free the decoding tables, return */
  Ziphuft_free(zd, tl);
  Ziphuft_free(zd, td);
  return 0;
}

static xadINT32 Zipinflate_block(struct ZipData *zd, xadINT32 *e) /* e == last block flag */
{ /* decompress an inflated block */
  xadUINT32 t;                  /* block type */
  register xadUINT32 b;     /* bit buffer */
  register xadUINT32 k;     /* number of bits in bit buffer */

  /* make local bit buffer */
  b = zd->bb;
  k = zd->bk;

  /* read in last block bit */
  ZIPNEEDBITS(1)
  *e = (xadINT32)b & 1;
  ZIPDUMPBITS(1)

  /* read in block type */
  ZIPNEEDBITS(2)
  t = (xadUINT32)b & 3;
  ZIPDUMPBITS(2)

  /* restore the global bit buffer */
  zd->bb = b;
  zd->bk = k;

  /* inflate that block type */
  if(t == 2)
    return Zipinflate_dynamic(zd);
  if(t == 0)
    return Zipinflate_stored(zd);
  if(t == 1)
    return Zipinflate_fixed(zd);

  /* bad block type */
  return 2;
}

static xadINT32 Zipinflate(struct ZipData *zd) /* decompress an inflated entry */
{
  xadINT32 e;               /* last block flag */
  xadINT32 r;           /* result code */

  /* initialize window, bit buffer */
  /* zd->wp = 0; */
  /* zd->bk = 0; */
  /* zd->bb = 0; */

  /* decompress until the last block */
  do
  {
    if((r = Zipinflate_block(zd, &e)))
      return r;
  } while(!e);

  Zipflush(zd, zd->wp);

  /* return success */
  return 0;
}

/**************************************************************************************************/

struct ZIPshrinkleaf {
  struct ZIPshrinkleaf *parent;
  struct ZIPshrinkleaf *next_sibling;
  struct ZIPshrinkleaf *first_child;
  xadUINT8 value;
};

#define ZIPREADBITS(nbits,zdest) {if(nbits>bits_left) {xadUINT32 temp; zipeof=1;\
  while (bits_left<=8*(sizeof(bitbuf)-1) && (temp=Zipgetbyte(zd))!=~0) {\
  bitbuf|=temp<<bits_left; bits_left+=8; zipeof=0;}}\
  zdest=(xadINT32)((xadUINT16)bitbuf&Zipmask[nbits]);bitbuf>>=nbits;bits_left-=nbits;}

static void Zippartial_clear(struct ZIPshrinkleaf *cursib,
struct ZIPshrinkleaf *node)
{
  struct ZIPshrinkleaf *lastsib = 0;

  /* Loop over siblings, removing any without children; recurse on those
   * which do have children.  This hits even the orphans because they're
   * always adopted (parent node is reused) before tree becomes full and
   * needs clearing.
   */
  do
  {
    if(cursib->first_child)
    {
      Zippartial_clear(cursib->first_child, node);
      lastsib = cursib;
    }
    else if((cursib - node) > 256) /* no children (leaf):  clear it */
    {
      if(!lastsib)
        cursib->parent->first_child = cursib->next_sibling;
      else
        lastsib->next_sibling = cursib->next_sibling;
      cursib->parent = 0;
    }
    cursib = cursib->next_sibling;
  } while (cursib);
}

static void Zipunshrink(struct ZipData *zd)
{
  xadUINT8 *stacktop, *newstr, *outptr;
  struct ZIPshrinkleaf *node, *bogusnode, *lastfreenode, *freenode, *curnode, *lastnode, *oldnode;
  xadINT32 codesize=9, code, oldcode, len, KwKwK;
  xadUINT32 outcnt = 0, bitbuf = 0, zipeof = 0, bits_left = 0;
  struct xadMasterBase *xadMasterBase = zd->xadMasterBase;

  stacktop = zd->Stack + 8192 - 1;
  outptr = zd->Slide;

  if((node = (struct ZIPshrinkleaf *) xadAllocVec(XADM 8192
  *sizeof(struct ZIPshrinkleaf), XADMEMF_CLEAR)))
  {
    lastnode = node;
    bogusnode = node + 256;
    lastfreenode = node + 256;

    for(code = 0; code < 256; ++code)
    {
      node[code].value = code;
      node[code].parent = bogusnode;
      node[code].next_sibling = &node[code+1];
      /* node[code].first_child = 0; */
    }
    node[255].next_sibling = 0;
    /* for(code = 257; code < 8192; ++code) */
    /*   node[code].parent = node[code].next_sibling = 0; */

    /* Get and output first code, then loop over remaining ones. */

    ZIPREADBITS(codesize, oldcode)
    if(!zipeof)
    {
      *(outptr++) = (xadUINT8)oldcode;
      ++outcnt;
    }

    do
    {
      ZIPREADBITS(codesize, code)
      if(zipeof)
        break;
      if(code == 256)
      {
        ZIPREADBITS(codesize, code)
        if(code == 1)
        {
          ++codesize;
        }
        else if(code == 2)
        {
          Zippartial_clear(node, node);       /* recursive clear of leafs */
          lastfreenode = bogusnode;  /* reset start of free-node search */
        }
        continue;
      }

      /* Translate code:  traverse tree from leaf back to root. */

      curnode = &node[code];
      newstr = stacktop;

      if(curnode->parent)
        KwKwK = XADFALSE;
      else
      {
        KwKwK = XADTRUE;
        --newstr;   /* last character will be same as first character */
        curnode = &node[oldcode];
      }

      do
      {
        *newstr-- = curnode->value;
        curnode = curnode->parent;
      } while(curnode != bogusnode && curnode);

      if(!curnode)
      {
        zd->errcode = XADERR_ILLEGALDATA;
        break;
      }

      len = stacktop - newstr++;
      if(KwKwK)
        *stacktop = *newstr;

      /* Write expanded string in reverse order to output buffer. */

      {
        register xadUINT8 *p;

        for(p = newstr; p < newstr+len; ++p)
        {
          *outptr++ = *p;
          if(++outcnt == ZIPWSIZE)
          {
            Zipflush(zd, outcnt);
            outptr = zd->Slide;
            outcnt = 0;
          }
        }
      }

      /* Add new leaf (first character of newstr) to tree as child of oldcode. */

      /* search for freenode */
      freenode = lastfreenode + 1;
      while(freenode->parent)       /* add if-test before loop for speed? */
        ++freenode;
      lastfreenode = freenode;

      oldnode = &node[oldcode];
      if(!oldnode->first_child)   /* no children yet:  add first one */
      {
        if(!oldnode->parent)
        {
          oldnode->next_sibling = bogusnode;
        }
        oldnode->first_child = freenode;
      }
      else
      {
        curnode = oldnode->first_child;
        while(curnode)          /* find last child in sibling chain */
        {
          lastnode = curnode;
          curnode = curnode->next_sibling;
        }
        lastnode->next_sibling = freenode;
      }
      freenode->value = *newstr;
      freenode->parent = oldnode;
      if(freenode->next_sibling != bogusnode)  /* no adoptions today... */
        freenode->first_child = 0;
      freenode->next_sibling = 0;

      oldcode = code;
    } while(!zipeof);

    if(outcnt > 0)
      Zipflush(zd, outcnt);

    xadFreeObjectA(XADM node, 0);
  }
  else
    zd->errcode = XADERR_NOMEMORY;
}
/**************************************************************************************************/

/* Tables for length and distance */
static const xadUINT16 Zipcplen2[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
  18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34,
  35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,
  52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65};
static const xadUINT16 Zipcplen3[] = {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
  19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
  36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
  53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66};
static const xadUINT16 Zipextra[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  8};
static const xadUINT16 Zipcpdist4[] = {1, 65, 129, 193, 257, 321, 385, 449, 513, 577, 641, 705,
  769, 833, 897, 961, 1025, 1089, 1153, 1217, 1281, 1345, 1409, 1473,
  1537, 1601, 1665, 1729, 1793, 1857, 1921, 1985, 2049, 2113, 2177,
  2241, 2305, 2369, 2433, 2497, 2561, 2625, 2689, 2753, 2817, 2881,
  2945, 3009, 3073, 3137, 3201, 3265, 3329, 3393, 3457, 3521, 3585,
  3649, 3713, 3777, 3841, 3905, 3969, 4033};
static const xadUINT16 Zipcpdist8[] = {1, 129, 257, 385, 513, 641, 769, 897, 1025, 1153, 1281,
  1409, 1537, 1665, 1793, 1921, 2049, 2177, 2305, 2433, 2561, 2689,
  2817, 2945, 3073, 3201, 3329, 3457, 3585, 3713, 3841, 3969, 4097,
  4225, 4353, 4481, 4609, 4737, 4865, 4993, 5121, 5249, 5377, 5505,
  5633, 5761, 5889, 6017, 6145, 6273, 6401, 6529, 6657, 6785, 6913,
  7041, 7169, 7297, 7425, 7553, 7681, 7809, 7937, 8065};

static xadINT32 Zipget_tree(struct ZipData *zd, xadUINT32 *l, xadUINT32 n)
{
  xadUINT32 i;           /* bytes remaining in list */
  xadUINT32 k;           /* lengths entered */
  xadUINT32 j;           /* number of codes */
  xadUINT32 b;           /* bit length for those codes */

  /* get bit lengths */
  i = Zipgetbyte(zd) + 1;                     /* length/count pairs to read */
  k = 0;                                /* next code */
  do {
    b = ((j = Zipgetbyte(zd)) & 0xf) + 1;     /* bits in code (1..16) */
    j = ((j & 0xf0) >> 4) + 1;          /* codes with those bits (1..16) */
    if(k + j > n)
      return 4;                         /* don't overflow l[] */
    do {
      l[k++] = b;
    } while(--j);
  } while(--i);
  return k != n ? 4 : 0;                /* should have read n of them */
}

static void Zipexplode_lit8(struct ZipData *zd, struct Ziphuft *tb, struct Ziphuft *tl, struct Ziphuft *td, xadINT32 bb, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 mb, ml, md;  /* masks for bb, bl, and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  mb = Zipmask[bb];           /* precompute masks for speed */
  ml = Zipmask[bl];
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--decode it */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS((xadUINT32)bb)    /* get coded literal */
      if((e = (t = tb + ((~(xadUINT32)b) & mb))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      zd->Slide[w++] = (xadUINT8)t->v.n;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(7)               /* get distance low bits */
      d = (xadUINT32)b & 0x7f;
      ZIPDUMPBITS(7)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_lit4(struct ZipData *zd, struct Ziphuft *tb,
struct Ziphuft *tl, struct Ziphuft *td, xadINT32 bb, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 mb, ml, md;  /* masks for bb, bl, and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  mb = Zipmask[bb];           /* precompute masks for speed */
  ml = Zipmask[bl];
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--decode it */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS((xadUINT32)bb)    /* get coded literal */
      if((e = (t = tb + ((~(xadUINT32)b) & mb))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      zd->Slide[w++] = (xadUINT8)t->v.n;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(6)               /* get distance low bits */
      d = (xadUINT32)b & 0x3f;
      ZIPDUMPBITS(6)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_nolit8(struct ZipData *zd, struct Ziphuft *tl,
struct Ziphuft *td, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  ml = Zipmask[bl];           /* precompute masks for speed */
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--get eight bits */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS(8)
      zd->Slide[w++] = (xadUINT8)b;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
      ZIPDUMPBITS(8)
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(7)               /* get distance low bits */
      d = (xadUINT32)b & 0x7f;
      ZIPDUMPBITS(7)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_nolit4(struct ZipData *zd, struct Ziphuft *tl,
struct Ziphuft *td, xadUINT32 bl, xadUINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  ml = Zipmask[bl];           /* precompute masks for speed */
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--get eight bits */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS(8)
      zd->Slide[w++] = (xadUINT8)b;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
      ZIPDUMPBITS(8)
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(6)               /* get distance low bits */
      d = (xadUINT32)b & 0x3f;
      ZIPDUMPBITS(6)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode(struct ZipData *zd)
{
  xadUINT32 r;           /* return codes */
  struct Ziphuft *tb;      /* literal code table */
  struct Ziphuft *tl;      /* length code table */
  struct Ziphuft *td;      /* distance code table */
  xadINT32 bb;               /* bits for tb */
  xadINT32 bl;               /* bits for tl */
  xadINT32 bd;               /* bits for td */
  xadUINT32 *l;          /* bit lengths for codes */

  l = zd->ll;
  /* Tune base table sizes.  Note: I thought that to truly optimize speed,
     I would have to select different bl, bd, and bb values for different
     compressed file sizes.  I was suprised to find out the the values of
     7, 7, and 9 worked best over a very wide range of sizes, except that
     bd = 8 worked marginally better for large compressed sizes. */
  bl = 7;
  bd = zd->csize > 200000L ? 8 : 7;

  /* With literal tree--minimum match length is 3 */
  if(zd->Flags & 4)
  {
    bb = 9;                     /* base table size for literals */
    if(Zipget_tree(zd,l, 256))
      return;
    if((r = Ziphuft_build(zd, l, 256, 256, NULL, NULL, &tb, &bb)))
    {
      if(r == 1)
        Ziphuft_free(zd, tb);
      return;
    }
    if(Zipget_tree(zd,l, 64))
      return;
    if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcplen3,
    (xadUINT16 *) Zipextra, &tl, &bl)))
    {
      if(r == 1)
        Ziphuft_free(zd, tl);
      Ziphuft_free(zd, tb);
      return;
    }
    if(Zipget_tree(zd,l, 64))
      return;
    if(zd->Flags & 2)      /* true if 8K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist8,
      (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        Ziphuft_free(zd, tb);
        return;
      }
      Zipexplode_lit8(zd, tb, tl, td, bb, bl, bd);
    }
    else                                        /* else 4K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist4, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        Ziphuft_free(zd, tb);
        return ;
      }
      Zipexplode_lit4(zd, tb, tl, td, bb, bl, bd);
    }
    Ziphuft_free(zd, td);
    Ziphuft_free(zd, tl);
    Ziphuft_free(zd, tb);
  }
  else /* No literal tree--minimum match length is 2 */
  {
    if(Zipget_tree(zd,l, 64))
      return;
    if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcplen2, (xadUINT16 *) Zipextra, &tl, &bl)))
    {
      if(r == 1)
        Ziphuft_free(zd, tl);
      return;
    }
    if((r = Zipget_tree(zd,l, 64)))
      return;
    if(zd->Flags & 2)      /* true if 8K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist8, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        return;
      }
      Zipexplode_nolit8(zd, tl, td, bl, bd);
    }
    else                                        /* else 4K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist4, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        return;
      }
      Zipexplode_nolit4(zd, tl, td, (xadUINT32) bl, (xadUINT32) bd);
    }
    Ziphuft_free(zd, td);
    Ziphuft_free(zd, tl);
  }
}

/**************************************************************************************************/

#define ZIPDLE    144
typedef xadUINT8 Zipf_array[64];        /* for followers[256][64] */

static const xadUINT8 ZipL_table[] = {0, 0x7f, 0x3f, 0x1f, 0x0f};
static const xadUINT8 ZipD_shift[] = {0, 0x07, 0x06, 0x05, 0x04};
static const xadUINT8 ZipB_table[] = {
 8, 1, 1, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5,
 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6,
 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8
};

static void Zipunreduce(struct ZipData *zd, xadINT32 factor)   /* expand probabilistically reduced data */
{
  register xadINT32 lchar = 0;
  xadINT32 nchar, ExState = 0, V = 0, Len = 0;
  xadINT32 s = zd->ucsize;  /* number of bytes left to decompress */
  xadUINT32 w = 0;      /* position in output window slide[] */
  xadUINT32 u = 1;      /* true if slide[] unflushed */
  xadUINT32 zipeof = 0, bits_left = 0, bitbuf = 0;
  xadUINT8 *Slen, *slide;
  Zipf_array *followers;     /* shared work space */

  Slen = zd->Stack;
  slide = zd->Slide;
  followers = (Zipf_array *)(zd->Slide + 0x4000);
  --factor; /* factor is compression method - 1 */

  {
    register xadINT32 x;
    register xadINT32 i;

    for(x = 255; x >= 0; x--)
    {
       ZIPREADBITS(6, Slen[x])   /* ; */
       for(i = 0; (xadUINT8)i < Slen[x]; i++)
         ZIPREADBITS(8, followers[x][i])   /* ; */
    }
  }

  while(s > 0 && !zipeof)
  {
    if(Slen[lchar] == 0)
      ZIPREADBITS(8, nchar)   /* ; */
    else
    {
      ZIPREADBITS(1, nchar)   /* ; */
      if(nchar != 0)
        ZIPREADBITS(8, nchar)       /* ; */
      else
      {
        xadINT32 follower;
        xadINT32 bitsneeded = ZipB_table[Slen[lchar]];

        ZIPREADBITS(bitsneeded, follower)   /* ; */
        nchar = followers[lchar][follower];
      }
    }
    /* expand the resulting byte */
    switch(ExState)
    {
    case 0:
      if(nchar != ZIPDLE)
      {
        s--;
        slide[w++] = (xadUINT8)nchar;
        if(w == 0x4000)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      }
      else
        ExState = 1;
      break;
    case 1:
      if(nchar != 0)
      {
        V = nchar;
        Len = V & ZipL_table[factor];
        if(Len == ZipL_table[factor])
          ExState = 2;
        else
          ExState = 3;
      }
      else
      {
        s--;
        slide[w++] = ZIPDLE;
        if(w == 0x4000)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
        ExState = 0;
      }
      break;
    case 2:
      Len += nchar;
      ExState = 3;
      break;
    case 3:
      {
        register xadUINT32 e, n = Len + 3, d = w - ((((V >> ZipD_shift[factor]) & Zipmask[factor]) << 8) + nchar + 1);

        s -= n;
        do
        {
          n -= (e = (e = 0x4000 - ((d &= 0x3fff) > w ? d : w)) > n ? n : e);
          if(u && w <= d)
          {
            memset(slide + w, 0, e);
            w += e;
            d += e;
          }
          else /* or use xadCopyMem */
          {
            do
            {
              slide[w++] = slide[d++];
            } while(--e);
          }
          if(w == 0x4000)
          {
            Zipflush(zd, w);
            w = u = 0;
          }
        } while(n);

        ExState = 0;
      }
      break;
    }

    /* store character for next iteration */
    lchar = nchar;
  }

  /* flush out slide */
  Zipflush(zd, w);
}

/**************************************************************************************************/

static xadINT32 CheckZipPWD(struct ZipData *zd, struct xadMasterBase *xadMasterBase, xadUINT32 val)
{
  xadUINT32 k[3], i;
  xadSTRPTR pwd;
  xadUINT8 a, b = 0;
  xadUINT16 tmp;

  if(!(pwd = zd->Password) || !*pwd)
    return XADERR_PASSWORD;

  k[0] = 305419896;
  k[1] = 591751049;
  k[2] = 878082192;

  while(*pwd)
  {
    k[0] = xadCalcCRC32(XADM XADCRC32_ID1, k[0], 1, (xadUINT8 *) pwd++);
    k[1] += (k[0] & 0xFF);
    k[1] = k[1] * 134775813 + 1;
    a = k[1] >> 24;
    k[2] = xadCalcCRC32(XADM XADCRC32_ID1, k[2], 1, &a);
  }

  zd->Flags ^= (1<<0); /* temporary remove cryption flag ! */
  for(i = 0; i < 12; ++i)
  {
    tmp = k[2] | 2;
    b = Zipgetbyte(zd) ^ ((tmp * (tmp ^ 1)) >> 8);
    k[0] = xadCalcCRC32(XADM XADCRC32_ID1, k[0], 1, &b);
    k[1] += (k[0] & 0xFF);
    k[1] = k[1] * 134775813 + 1;
    a = k[1] >> 24;
    k[2] = xadCalcCRC32(XADM XADCRC32_ID1, k[2], 1, &a);
  }
  zd->Flags ^= (1<<0); /* reset cryption flag ! */

  zd->Keys[0] = k[0];
  zd->Keys[1] = k[1];
  zd->Keys[2] = k[2];

  return (val == b) ? XADERR_OK : XADERR_PASSWORD;
}

/**************************************************************************************************/

XADUNARCHIVE(Zip)
{
  xadINT32 err = 0;
  xadUINT32 crc = (xadUINT32) ~0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(ZIPPI(fi)->CompressionMethod == ZIPM_STORED && !(fi->xfi_Flags & XADFIF_CRYPTED))
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC32, &crc, TAG_DONE);
  else if(ZIPPI(fi)->CompressionMethod == ZIPM_COPY) /* crc is automatically 0 */
    err = xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else
  {
    struct ZipData *zd;

    if((zd = (struct ZipData *) xadAllocVec(XADM
    sizeof(struct ZipData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      zd->CRC = crc;
      zd->Password = ai->xai_Password;
      zd->insize = zd->csize = fi->xfi_CrunchSize;
      zd->ucsize = fi->xfi_Size;
      zd->Flags = ZIPPI(fi)->Flags;
      zd->xadMasterBase = xadMasterBase;
      zd->ai = ai;
      zd->inpos = zd->inend = zd->inbuf+ZIPWSIZE;

      if(zd->Flags & (1<<0))
        err = CheckZipPWD(zd, xadMasterBase, (zd->Flags & (1<<3) ?
        ZIPPI(fi)->Date>>8 : ZIPPI(fi)->CRC32>>24) & 0xFF);

      if(!err)
      {
        switch(ZIPPI(fi)->CompressionMethod)
        {
        case ZIPM_DEFLATED:
          if(Zipinflate(zd) && !zd->errcode)
            err = XADERR_ILLEGALDATA;
          break;
        case ZIPM_SHRUNK:
          Zipunshrink(zd); break;
        case ZIPM_IMPLODED:
          Zipexplode(zd); break;
        case ZIPM_REDUCED1: case ZIPM_REDUCED2: case ZIPM_REDUCED3: case ZIPM_REDUCED4:
          Zipunreduce(zd, ZIPPI(fi)->CompressionMethod); break;
        case ZIPM_STORED: /* for crypted files! */
          {
            xadUINT32 i, w = 0;
            for(i = zd->ucsize; i && !zd->errcode; --i)
            {
              zd->Slide[w++] = Zipgetbyte(zd);
              if(w >= ZIPWSIZE)
              {
                Zipflush(zd, w);
                w = 0;
              }
            }
            if(w && !zd->errcode)
              Zipflush(zd, w);
          }
          break;
        default:
          err = XADERR_DATAFORMAT;
          break;
        }
      }
      if(!err)
        err = zd->errcode;
      crc = zd->CRC;

      xadFreeObjectA(XADM zd,0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && ~crc != ZIPPI(fi)->CRC32)
    err = XADERR_CHECKSUM;
  return err;
}

XADFREE(Zip)
{
  struct xadFileInfo *fi, *fi2;

  for(fi = ai->xai_FileInfo; fi; fi = fi2)
  {
    fi2 = fi->xfi_Next;
    if(ZIPPI(fi)->PrivFlags & ZIPPRIVFLAG_OWNCOMMENT)
      xadFreeObjectA(XADM fi->xfi_Comment, 0);
    xadFreeObjectA(XADM fi, 0);
  }
  ai->xai_FileInfo = 0;
}

/**************************************************************************************************/

static const xadUINT8 WinZipTXT[] = "WinZip(R) Self-Extractor";
#define WinZipTXTSize   24

XADRECOGDATA(WinZip)
{
  xadUINT32 i, j;

  if(size < WinZipTXTSize+2 || data[0] != 0x4D || data[1] != 0x5A)
    return 0;

  for(i = 0; i < size-WinZipTXTSize; ++i)
  {
    j = 0;
    while(j < WinZipTXTSize && data[j] == WinZipTXT[j])
      ++j;
    if(j == WinZipTXTSize)
      return 1;
    ++data;
  }
  return 0;
}

XADGETINFO(WinZip)
{
  xadINT32 err, i;
  xadSTRPTR b;

  if((b = (xadSTRPTR) xadAllocVec(XADM 10240, XADMEMF_ANY)))
  {
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, ai->xai_InSize-10240, 0, ai)))
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 10240, b, ai)))
      {
        for(i = 10240-22; i; --i)
        {
          if(b[i] == 'P' && b[i+1] == 'K' && b[i+2] == 5 && b[i+3] == 6)
          {
            if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK,
            EndGetI32(((struct ZipEnd *) (b+i+4))->CentralOffset)-ai->xai_InPos+4, 0, ai)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct ZipCentral), b, ai)))
              {
                if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK,
                EndGetI32(((struct ZipCentral *) b)->LocHeaderOffset)-ai->xai_InPos, 0, ai)))
                  err = Zip_GetInfo(ai, xadMasterBase);
              }
            }
            break;
          }
        }
      }
    }
    xadFreeObjectA(XADM b, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

XADRECOGDATA(ZipEXE)
{
  xadUINT32 i;

  if(size < 11 || data[0] != 0x4D || data[1] != 0x5A)
    return 0;

  data += 2;
  for(i = 2; i < size-9; ++i)
  {
    if(data[0] == 'P' && data[1] == 'K' && data[2] == 3 && data[3] == 4 &&
    data[4] >= 10 && data[4] < 40 && !data[9])
      return 1;
    ++data;
  }
  return 0;
}

XADGETINFO(ZipEXE)
{
  xadUINT32 lastpos = 0;
  xadINT32 err;

  if(!(err = ZIPScanNext(&lastpos, ai, xadMasterBase)))
    err = Zip_GetInfo(ai, xadMasterBase);

  return err;
}

/**************************************************************************************************/

XADRECOGDATA(GZip)
{
  if(data[0] == 0x1F && (((data[1] == 0x8B || data[1] == 0x9E) && data[2] == 8) ||
  data[1] == 0xA1)) /* BSD-compress variant */
    return 1;
  return 0;
}

struct GZipHeader {
  xadUINT8 ID[2];
  xadUINT8 Method;
  xadUINT8 Flags;
  xadUINT8 Time[4];
  xadUINT8 ExtraFlags;
  xadUINT8 OS;
};

struct GZipBuf {
  xadINT32 err;
  xadUINT8 pos;
  xadUINT8 size;
  xadUINT8 buf[255];
};

struct GZipEndData {
  xadUINT8 CRC[4];
  xadUINT8 OutSize[4];
};

#define GZIPF_ASCII             (1<<0)
#define GZIPF_CONTINUATION      (1<<1)
#define GZIPF_EXTRA             (1<<2)
#define GZIPF_FILENAME          (1<<3)
#define GZIPF_COMMENT           (1<<4)
#define GZIPF_ENCRYPTED         (1<<5)

static xadUINT8 GZipGetByte(struct GZipBuf *gb, struct xadMasterBase *xadMasterBase, struct xadArchiveInfo *ai)
{
  xadUINT8 res = 0;
  xadUINT32 size;

  if(!gb->err)
  {
    if(gb->pos == 255)
    {
      if((size = ai->xai_InSize-ai->xai_InPos) > 255)
        size = 255;
      gb->size = size;
      gb->pos = 0;
      gb->err = xadHookAccess(XADM XADAC_READ, size, gb->buf, ai);
    }
    if(!gb->err)
      res = gb->buf[gb->pos++];
  }
  return res;
}

XADGETINFO(GZip)
{
  xadINT32 err, a, fsize = 0, csize = 0;
  struct gzData {
    struct GZipHeader gh;
    struct GZipBuf gb;
    struct GZipEndData ge;
    xadUINT8 FileName[256];
    xadUINT8 Comment[256];
  } *gz;

  if(!(gz = (struct gzData *) xadAllocVec(XADM sizeof(struct gzData),
  XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  gz->gb.pos = gz->gb.size = 255;
  gz->gb.err = 0;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct GZipHeader), &gz->gh, ai)))
  {
    if(EndGetM16(gz->gh.ID) != 0x1FA1)
    {
      if(gz->gh.Flags & GZIPF_CONTINUATION)
      {
        GZipGetByte(&gz->gb, xadMasterBase, ai);
        GZipGetByte(&gz->gb, xadMasterBase, ai);
      }
      if(gz->gh.Flags & GZIPF_EXTRA)
      {
        a = GZipGetByte(&gz->gb, xadMasterBase, ai) << 8;
        a += GZipGetByte(&gz->gb, xadMasterBase, ai);
        while(a--)
          GZipGetByte(&gz->gb, xadMasterBase, ai);
      }
      if(gz->gh.Flags & GZIPF_FILENAME)
      {
        while((a = GZipGetByte(&gz->gb, xadMasterBase, ai)))
        {
          if(fsize < 255)
            gz->FileName[fsize++] = a;
        }
        if(fsize)
          gz->FileName[fsize++] = 0;
      }
      if(gz->gh.Flags & GZIPF_COMMENT)
      {
        while((a = GZipGetByte(&gz->gb, xadMasterBase, ai)))
        {
          if(fsize < 255)
            gz->Comment[csize++] = a;
        }
        if(csize)
          gz->Comment[csize++] = 0;
      }
      a = ai->xai_InPos - gz->gb.size + gz->gb.pos;
    }
    else
      a = 2;

    err = gz->gb.err;
    if(!err && !(err = xadHookAccess(XADM XADAC_INPUTSEEK, ai->xai_InSize-8-ai->xai_InPos, 0, ai)))
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, 8, &gz->ge, ai)))
      {
        struct xadFileInfo *fi;

        if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        fsize ? XAD_OBJNAMESIZE : TAG_IGNORE, fsize, XAD_OBJPRIVINFOSIZE, sizeof(struct ZipPrivate),
        csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize, TAG_DONE)))
        {
          xadConvertDates(XADM XAD_DATEUNIX, EndGetI32(gz->gh.Time), XAD_GETDATEXADDATE,
          &fi->xfi_Date, TAG_DONE);
          fi->xfi_Size = EndGetI32(gz->ge.OutSize);
          fi->xfi_CrunchSize = ai->xai_InSize-a-8;
          if(fsize)
            xadCopyMem(XADM gz->FileName, fi->xfi_FileName, (xadUINT32) fsize);
          else
          {
            fi->xfi_Flags |= XADFIF_NOFILENAME|XADFIF_XADSTRFILENAME;
            fi->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai,
            XAD_EXTENSION, ".gz",
            XAD_EXTENSION, ".tgz;.tar",
            XAD_EXTENSION, ".z",
            XAD_EXTENSION, ".adz;.adf",
            XAD_EXTENSION, ".tcx",
            XAD_EXTENSION, ".tzx",
            TAG_DONE);
          }
          if(csize)
            xadCopyMem(XADM gz->Comment, fi->xfi_Comment, (xadUINT32) csize);

          ZIPPI(fi)->CRC32 = EndGetI32(gz->ge.CRC);
          ZIPPI(fi)->CompressionMethod = ZIPM_DEFLATED;
          if(gz->gh.Flags & GZIPF_ENCRYPTED)
          {
            ZIPPI(fi)->Flags = (1<<0);
            fi->xfi_Flags |= XADFIF_CRYPTED;
            ai->xai_Flags |= XADAIF_CRYPTED;
          }
          fi->xfi_DataPos = a;
          fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
          err = xadAddFileEntryA(XADM fi, ai, 0);
        }
        else
          err = XADERR_NOMEMORY;
      }
    }
  }

  xadFreeObjectA(XADM gz, 0);

  return err;
}

/**************************************************************************************************/

XADRECOGDATA(GZipSFX)
{
  xadUINT32 i;

  if(size < 5)
    return 0;
  if(size > 5000)
    size = 5000;

  if(data[0] == '#' && data[1] == '!')
  {
    for(i = 2; i < size-3; ++i)
    {
      if(data[i] == 0x1F && (data[i+1] == 0x8B || data[i+1] == 0x9E) && data[i+2] == 8)
        return 1;
    }
  }
  return 0;
}

XADGETINFO(GZipSFX)
{
  xadUINT32 i = 0;
  xadINT32 err, found = 0;
  xadSTRPTR buf;
  xadUINT32 bufsize, fsize, spos = 0;

  fsize = ai->xai_InSize;

  if((bufsize = 5000) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
  {
    for(i = 0; i < bufsize - 2 && !found; ++i)
    {
      if(buf[i] == 0x1F && ((xadUINT8)buf[i+1] == 0x8B || (xadUINT8)buf[i+1] == 0x9E) && buf[i+2] == 8)
        found = 1;
    }
  }
  xadFreeObjectA(XADM buf, 0);

  if(found)
  {
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, i-1-bufsize, 0, ai)))
      err = GZip_GetInfo(ai, xadMasterBase);
  }

  return err;
}

/**************************************************************************************************/

XADCLIENT(GZipSFX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  GZIPSFX_VERSION,
  GZIPSFX_REVISION,
  5000,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_NOCHECKSIZE,
  XADCID_GZIPSFX,
  "GZip SFX",
  XADRECOGDATAP(GZipSFX),
  XADGETINFOP(GZipSFX),
  XADUNARCHIVEP(Zip),
  0
};

XADCLIENT(GZip) {
  (struct xadClient *) &GZipSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  GZIP_VERSION,
  GZIP_REVISION,
  3,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_GZIP,
  "GZip",
  XADRECOGDATAP(GZip),
  XADGETINFOP(GZip),
  XADUNARCHIVEP(Zip),
  0
};

XADCLIENT(ZipEXE) {
  (struct xadClient *) &GZip_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZIPEXE_VERSION,
  ZIPEXE_REVISION,
  0x10000,
  XADCF_FILEARCHIVER|XADCF_NOCHECKSIZE,
  XADCID_ZIPEXE,
  "Zip MS-EXE",
  XADRECOGDATAP(ZipEXE),
  XADGETINFOP(ZipEXE),
  XADUNARCHIVEP(Zip),
  XADFREEP(Zip)
};

XADCLIENT(WinZip) {
  (struct xadClient *) &ZipEXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  WINZIP_VERSION,
  WINZIP_REVISION,
  20480,
  XADCF_FILEARCHIVER|XADCF_NOCHECKSIZE,
  XADCID_WINZIPEXE,
  "WinZip MS-EXE",
  XADRECOGDATAP(WinZip),
  XADGETINFOP(WinZip),
  XADUNARCHIVEP(Zip),
  XADFREEP(Zip)
};

XADFIRSTCLIENT(Zip) {
  (struct xadClient *) &WinZip_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZIP_VERSION,
  ZIP_REVISION,
  8,
  XADCF_FILEARCHIVER,
  XADCID_ZIP,
  "Zip",
  XADRECOGDATAP(Zip),
  XADGETINFOP(Zip),
  XADUNARCHIVEP(Zip),
  XADFREEP(Zip)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Zip)

#endif /* XADMASTER_ZIP_C */
