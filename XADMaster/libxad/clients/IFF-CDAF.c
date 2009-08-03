#ifndef XADMASTER_IFF_CDAF_C
#define XADMASTER_IFF_CDAF_C

/*  $Id: IFF-CDAF.c,v 1.12 2005/06/23 14:54:41 stoecker Exp $
    IFF-CDAF format archivers (XpkArchive and Shrink)

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>


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
#include "xadIO.c"
#include "xadIO_XPK.c"

#ifndef  XADMASTERVERSION
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("IFF-CDAF 1.3 (23.2.2004)")

#define XPKARCHIVE_VERSION              1
#define XPKARCHIVE_REVISION             3
#define SHRINK_VERSION                  XPKARCHIVE_VERSION
#define SHRINK_REVISION                 XPKARCHIVE_REVISION

/* Shrink *****************************************************************************************/

struct ShrinkBuf {
  struct xadInOut *io;
  xadUINT16   data[1056];
  xadUINT32   bitcount;
  xadUINT32   bitbuf;
};

static const xadUINT16 ShrinkData[15] =
  {0x0000, 0x0004, 0x000C, 0x001C, 0x003C, 0x007C, 0x00FC, 0x01FC,
   0x03FC, 0x07FC, 0x0FFC, 0x1FFC, 0x3FFC, 0x7FFC, 0xFFFC};

static xadUINT16 ShrinkGetBits(xadUINT16 num, struct ShrinkBuf *sb)
{
  xadUINT16 ret = 0, i;

  while(num--)
  {
    i = 0;
    sb->bitcount >>= 1;
    if(sb->bitbuf >= sb->bitcount)
    {
      i = 1;
      sb->bitbuf -= sb->bitcount;
    }
    while(sb->bitcount < 0x1000000)
    {
      sb->bitbuf = (sb->bitbuf << 8) | xadIOGetChar(sb->io);
      sb->bitcount <<= 8;
    }
    ret = (ret << 1) | i;
  }
  return ret;
}

static void ShrinkSub1(struct ShrinkBuf *sb)
{
  xadINT32 i;

  for(i = 504; i < 1008; ++i)
  {
    if(sb->data[i])
      sb->data[i] = (sb->data[i] >> 1)+1;
  }

  for(i = 503; i > 0; --i)
    sb->data[i] = sb->data[2*i] + sb->data[2*i+1];
}

static void ShrinkSub2(xadUINT16 arg, struct ShrinkBuf *sb)
{
  arg += 504;
  while(arg)
  {
    ++sb->data[arg];
    arg >>= 1;
  }
  if(sb->data[1] >= 0x2000)
    ShrinkSub1(sb);
}

static xadUINT32 ShrinkSub3(xadUINT32 a, struct ShrinkBuf *sb)
{
  xadUINT16 d1, d2;
  xadUINT32 res, j;

  if(!a)
    return 0;

  a <<= 16;
  d1 = a/sb->data[1];
  d2 = ((a%sb->data[1])<<16)/sb->data[1];
  j = sb->bitcount;
  res = (xadUINT16) (((xadUINT16)j * d1) >> 16);
  j >>= 16;
  return res + ((xadUINT16)(((xadUINT16)j*d2) >> 16)) + (d1 * j);
}

static xadINT32 DeShrink(struct xadInOut *io, xadUINT8 bits)
{
  xadINT32 i, j = 0, k, l, m, err;
  xadUINT32 pos = 0, pos2, windowmask;
  xadSTRPTR window;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct ShrinkBuf *sb;

  if((sb = (struct ShrinkBuf *) xadAllocVec(XADM sizeof(struct ShrinkBuf), XADMEMF_CLEAR)))
  {
    if((window = (xadSTRPTR) xadAllocVec(XADM 1<<(10+bits), XADMEMF_CLEAR)))
    {
      sb->io = io;
      windowmask = (1<<(10+bits))-1;
      for(i = 0; i < 4; ++i)
        sb->bitbuf = (sb->bitbuf << 8) | xadIOGetChar(io);
      sb->bitcount = 0x80000000;

      for(i = 0; i < 261; ++i)
        sb->data[504 + i] = (i < 32 || i > 126) ? 1 : 3;
      sb->data[897] = sb->data[764] = 1;

      for(i = 503; i > 0; --i)
        sb->data[i] = sb->data[2*i] + sb->data[2*i+1];

      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
      {
        if(j <= pos)
        {
          if(j < 48)
            ShrinkSub2(j+261, sb);

          i = 4;
          for(k = 0; i < j+4; ++k)
           i <<= 1;

          if(i == j+4 && k < 14)
          {
            if(k < 13)
            {
              i = (k << 1) + 394;
              ShrinkSub2(i++, sb);
              ShrinkSub2(i, sb);
            }
            i = (k << 1) + 420;
            ShrinkSub2(i++, sb);
            ShrinkSub2(i, sb);
            i += 27;
            ShrinkSub2(i++, sb);
            ShrinkSub2(i, sb);
            i += 27;
            ShrinkSub2(i++, sb);
            ShrinkSub2(i, sb);
            if(k < 7)
            {
              for(i = 0; i < 4; ++i)
                ShrinkSub2((k << 2)+i+309, sb);
            }
            for(i = 0; i < 4; ++i)
              ShrinkSub2(14*i+k+337, sb);
          }
          if(++j >= 48)
            j = (j != 48) ? ((j+3)<<1)-4 : 60;
        }
        else
        {
          for(m = i = l = 0; m < 504;)
          {
            m <<= 1;
            if((k = ShrinkSub3(i + sb->data[m], sb)) <= sb->bitbuf)
            {
              l = k;
              i += sb->data[m++];
            }
          }

          sb->bitbuf -= l;
          sb->bitcount = ShrinkSub3(sb->data[m], sb);

          l = 3 + (sb->data[1] >> 10);
          for(i = m; i; i >>= 1)
            sb->data[i] += l;

          if(sb->data[1] >= 0x2000)
            ShrinkSub1(sb);

          while(sb->bitcount < 0x1000000)
          {
            sb->bitbuf = (sb->bitbuf << 8) | xadIOGetChar(io);;
            sb->bitcount <<= 8;
          }

          m -= 504;
          if(m < 0x100)
            window[(pos++)&windowmask] = xadIOPutChar(io, m);
          else
          {
            if(m < 261)
            {
              if(m < 260)
              {
                k = m - 256;
                l = 2 + ShrinkGetBits(k+2, sb) + ShrinkData[k];
              }
              else
                l = ShrinkGetBits(16, sb);

              pos2 = pos-1;
              while(l--)
                window[(pos++)&windowmask] = xadIOPutChar(io, window[(pos2++)&windowmask]);
            }
            else if(m < 309)
            {
              m -= 259;
              pos2 = pos-m;
              for(i = 0; i < 2; ++i)
                window[(pos++)&windowmask] = xadIOPutChar(io, window[(pos2++)&windowmask]);
            }
            else
            {
              if(m < 337)
              {
                k = m - 309;
                m = ((ShrinkGetBits(k>>2, sb) << 2) | (k&3)) + ShrinkData[k>>2] + 3;
                l = 3;
              }
              else if(m < 393)
              {
                m -= 337;
                k = m / 14;
                m %= 14;
                l = ShrinkGetBits(k+2, sb) + ShrinkData[k] + 8;
                m = ShrinkGetBits(m+2, sb) + ShrinkData[m] + l;
              }
              else if(m < 394)
              {
                l = ShrinkGetBits(16, sb);
                m = ShrinkGetBits(16, sb);
              }
              else
              {
                if(m < 420)
                {
                  l = 4;
                  k = 394;
                }
                else if(m < 448)
                {
                  l = 5;
                  k = 420;
                }
                else if(m < 476)
                {
                  l = 6;
                  k = 448;
                }
                else
                {
                  l = 7;
                  k = 476;
                }
                k = m - k;
                m = ((ShrinkGetBits(1 + (k >> 1), sb) << 1) | (k&1)) + ShrinkData[k >> 1] + l;
              }

              pos2 = pos-m;
              while(l--)
                window[(pos++)&windowmask] = xadIOPutChar(io, window[(pos2++)&windowmask]);
            }
          }
        }
      }
      err = io->xio_Error;
      xadFreeObjectA(XADM window, 0);
    }
    else
      err = XADERR_NOMEMORY;
    xadFreeObjectA(XADM sb, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

struct CDAFfile {
  xadUINT32 ID;         /* FILE */
  xadUINT32 ChunkSize;
  xadUINT8 Checksum;
  xadUINT8 Method;
  xadUINT8 Version;
  xadUINT8 Generation;      /* Generation of the file: 0=new .. 255=deleted */
  xadUINT16 SystemID;
  xadUINT32 Filesize;
  xadUINT8 Year; /* Since 1900 */
  xadUINT8 Month;
  xadUINT8 Day;
  xadUINT8 Hour;
  xadUINT8 Mins;
  xadUINT8 Secs;
  xadUINT16 CRC;                /* empty for XPK */
  xadUINT32 Protection;
};

#define CDAFSYSID_AMIGA         0x414D
#define CDAFSYSID_ATARI_ST      0x5354
#define CDAFSYSID_ARCHIMEDES    0x4152
#define CDAFSYSID_MS_DOS        0x4D53
#define CDAFSYSID_UNIX          0x5558
#define CDAFSYSID_MAC           0x4D41
#define CDAFSYSID_HELIOS        0x4845

struct CDAFinfo {
  xadUINT16 CRC;
  xadUINT8 Method;
  xadUINT8 Offset;
};

#define CDAFPI(a)       ((struct CDAFinfo *) ((a)->xfi_PrivateInfo))

XADGETINFO(IFF_CDAF)
{
  xadINT32 err, i;
  struct CDAFfile cf;
  xadUINT8 buffer[256];
  xadUINT32 a[2];
  xadSTRPTR name;
  struct xadFileInfo *fi;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 16, 0, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_READ, 4, a, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, a[0], 0, ai)))
    return err;
  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct CDAFfile), &cf, ai)))
    {
      i = ((cf.ChunkSize - (sizeof(struct CDAFfile) - 8))+1)&(~1);
      if(i <= 256)
        name = (xadSTRPTR) buffer;
      else if(!(name = xadAllocVec(XADM i, XADMEMF_ANY)))
        err = XADERR_NOMEMORY;

      if(!err)
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, i, name, ai)))
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, 8, a, ai)))
          {
            if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
            XAD_OBJPRIVINFOSIZE, sizeof(struct CDAFinfo), XAD_OBJNAMESIZE, i+1,
            a[0] == 0x4E4F5445 ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, a[1]+1, TAG_DONE)))
            {
              xadCopyMem(XADM name, fi->xfi_FileName, i);
              if(a[0] == 0x4E4F5445)
              {
                if(!(err = xadHookAccess(XADM XADAC_READ, (a[1]+1)&(~1), fi->xfi_Comment, ai)))
                  err = xadHookAccess(XADM XADAC_READ, 8, a, ai);
              }
              if(!err)
              {
                if(a[0] != 0x424F4459)
                  err = XADERR_ILLEGALDATA;
                else
                {
                  struct xadDate xd;
                  fi->xfi_DataPos = ai->xai_InPos; /* file position */
                  CDAFPI(fi)->Method = cf.Method;
                  CDAFPI(fi)->Offset = 4;
                  CDAFPI(fi)->CRC = cf.CRC;
                  fi->xfi_Size = cf.Filesize;
                  fi->xfi_Protection = cf.Protection;
                  fi->xfi_CrunchSize = a[1];
                  if(cf.Generation == 255)
                    fi->xfi_Flags = XADFIF_DELETED;
                  else
                    fi->xfi_Generation = cf.Generation;
                  fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
                  xd.xd_Second = cf.Secs;
                  xd.xd_Minute = cf.Mins;
                  xd.xd_Hour = cf.Hour;
                  xd.xd_Day = cf.Day;
                  xd.xd_Month = cf.Month;
                  xd.xd_Year = 1900 + cf.Year;
                  xd.xd_Micros = 0;
                  xadConvertDates(XADM XAD_DATEXADDATE, &xd, XAD_GETDATEXADDATE,
                  &fi->xfi_Date, TAG_DONE);
                }
              }
              if(err)
                xadFreeObjectA(XADM fi, 0);
              else
                err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+((a[1]+1)&(~1)), TAG_DONE);
            }
            else
              err = XADERR_NOMEMORY;
          }
        }
      }

      if(name && name != (xadSTRPTR) buffer)
        xadFreeObjectA(XADM name, 0);
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? 0 : err;
}

static const xadUINT8 XPKArcString[] = "FORM\xFF\xFF\xFF\xFF" "CDAFNAME\0\0\0\x0AXPKArchive";

/**************************************************************************************************/

XADRECOGDATA(XPKArchive)
{
  xadUINT32 i;

  for(i = 0; i < 30 && (XPKArcString[i] == 0xFF || XPKArcString[i] == data[i]); ++i)
    ;

  if(i == 30)
    return 1;
  else
    return 0;
}

XADUNARCHIVE(XPKArchive)
{
  xadINT32 err;
  struct xadFileInfo *fi;
  struct xadInOut *io;

  fi = ai->xai_CurFile;
  if(fi->xfi_Size == fi->xfi_CrunchSize)
    return xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER
  |XADIOF_NOCRC16|XADIOF_NOCRC32, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;

    if(!(err = xadIO_XPK(io, ai->xai_Password)))
      err = xadIOWriteBuf(io);

    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

static const xadUINT8 ShrinkString[] = "FORM\xFF\xFF\xFF\xFF" "CDAFNAME\0\0\0\x06shrink";

XADRECOGDATA(Shrink)
{
  xadUINT32 i;

  for(i = 0; i < 24 && (ShrinkString[i] == 0xFF || ShrinkString[i] == data[i]); ++i)
    ;

  if(i == 24)
    return 1;
  else
    return 0;
}

XADUNARCHIVE(Shrink)
{
  xadINT32 err = 0;
  xadUINT16 crc = 0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;
  if(!CDAFPI(fi)->Method)
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_USESKIPINFO, XADTRUE, XAD_GETCRC16, &crc, TAG_DONE);
  else
  {
    struct xadInOut *io;

    if(CDAFPI(fi)->Offset)
      err = xadHookAccess(XADM XADAC_INPUTSEEK, CDAFPI(fi)->Offset, 0, ai);
    if(!err)
    {
      if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32, ai, xadMasterBase)))
      {
        io->xio_InSize = fi->xfi_CrunchSize-CDAFPI(fi)->Offset;
        io->xio_OutSize = fi->xfi_Size;

        if(!(err = DeShrink(io, CDAFPI(fi)->Method)))
          err = xadIOWriteBuf(io);

        crc = io->xio_CRC16;
        xadFreeObjectA(XADM io, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
  }

  if(!err && CDAFPI(fi)->CRC && crc != CDAFPI(fi)->CRC)
    err = XADERR_CHECKSUM;

  return err;
}

/**************************************************************************************************/

XADRECOGDATA(SPack)
{
  xadUINT32 i;
  static const xadUINT8 *c = "PACKFI";

  for(i = 0; i < 6 && c[i] == data[i]; ++i)
    ;

  if(i == 6)
    return 1;
  else
    return 0;
}

struct SPackData {
  xadUINT16 ID;
  xadUINT16 Num;
  xadUINT32 UnCrSize;
  xadUINT32 CrSize;
  xadUINT16 CRC;
};

/* data format of INDX entry
  struct DateStamp

  for ever file:
  xadUINT16  DiskNumber
  xadUINT16  ID
  xadUINT16  NameSize
  [name]
  xadUINT32  UncrunchedSize
  xadUINT8  ZeroChar
*/

XADGETINFO(SPack)
{
  xadUINT32 i, b[3];
  xadINT32 err;
  struct xadFileInfo *fi;

  i = ai->xai_InPos; /* save StartPosition for BackSeek. */

  if(ai->xai_MultiVolume)
  {
    struct xadSkipInfo *si = 0, *si2;
    xadUINT32 *a;

    for(a = ai->xai_MultiVolume+1; *a; ++a)
    {
      if(!(si2 = (struct xadSkipInfo *) xadAllocObjectA(XADM XADOBJ_SKIPINFO, 0)))
        return XADERR_NOMEMORY;
      si2->xsi_Position = *a;
      si2->xsi_SkipSize = 6;
      if(si)
        si->xsi_Next = si2;
      else
        ai->xai_SkipInfo = si2;
      si = si2;
    }
  }

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, ai->xai_InSize-i-12, 0, ai)))
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 12, b, ai)))
    {
      if(b[0] == 0x494E4458)
        err = xadHookTagAccess(XADM XADAC_INPUTSEEK, -12-b[1], 0, ai, XAD_USESKIPINFO, XADTRUE, TAG_DONE);
      else if(b[1] == 0x494E4458)
      {
        b[1] = b[2];
        err = xadHookTagAccess(XADM XADAC_INPUTSEEK, -8-b[1], 0,  ai, XAD_USESKIPINFO, XADTRUE, TAG_DONE);
      }
      else
        err = XADERR_ILLEGALDATA;

      if(!err)
      {
        xadUINT8 buf[14];

        if(!(err = xadHookTagAccess(XADM XADAC_READ, 14, buf,  ai, XAD_USESKIPINFO, XADTRUE, TAG_DONE)))
        {
          if(EndGetM16(buf) == 0x4649)
          {
            xadSTRPTR buf2;
            xadUINT32 b2s;

            b2s = EndGetM32(buf+4);
            if((buf2 = (xadSTRPTR) xadAllocVec(XADM b2s, XADMEMF_ANY)))
            {
              struct xadInOut *io;

              if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
              {
                io->xio_InSize = EndGetM32(buf+8);
                io->xio_OutBufferSize = io->xio_OutSize = b2s;
                io->xio_OutBuffer = buf2;

                if(!(err = DeShrink(io, 7)) && EndGetM16(buf+12) != xadCalcCRC16(XADM XADCRC16_ID1, 0, b2s, (xadUINT8 *)buf2))
                  err = XADERR_CHECKSUM;
                xadFreeObjectA(XADM io, 0);
              }
              else
                err = XADERR_NOMEMORY;
              if(!err)
              {
                if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, -ai->xai_InPos+i+4, 0, ai)))
                {
                  xadSTRPTR dat;
                  struct SPackData sp;

                  dat = buf2+12; /* pointer to current buffer pos */

                  while(!err && dat < buf2+b2s)
                  {
                    if(!(err = xadHookTagAccess(XADM XADAC_READ, sizeof(struct SPackData), &sp, ai, XAD_USESKIPINFO,
                    XADTRUE, TAG_DONE)))
                    {
                      xadUINT16 i;

                      i = EndGetM16(dat+6);
                      if(sp.ID == 0x4649 && EndGetM16(dat+2) == 0x4649 &&
                      (sp.Num&0x7FFF) == EndGetM16(dat+4) && sp.UnCrSize == EndGetM32(dat+8+i))
                      {
                        dat += 8;

                        if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
                        XAD_OBJPRIVINFOSIZE, sizeof(struct CDAFinfo), XAD_OBJNAMESIZE, i+1, TAG_DONE)))
                        {
                          xadCopyMem(XADM dat, fi->xfi_FileName, i);
                          dat += i + 4 + 1;

                          xadConvertDates(XADM XAD_DATEDATESTAMP, buf2, XAD_GETDATEXADDATE,
                          &fi->xfi_Date, TAG_DONE);

                          fi->xfi_Size = sp.UnCrSize;
                          fi->xfi_Flags = XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;

                          if(sp.Num & 0x8000)
                          {
                            CDAFPI(fi)->Method = 0;
                            fi->xfi_DataPos = ai->xai_InPos - 6;
                            fi->xfi_CrunchSize = sp.UnCrSize;
                            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+sp.UnCrSize-6,
                            XAD_USESKIPINFO, 1, TAG_DONE);
                          }
                          else
                          {
                            CDAFPI(fi)->Method = 7;
                            CDAFPI(fi)->CRC = sp.CRC;
                            fi->xfi_DataPos = ai->xai_InPos;
                            fi->xfi_CrunchSize = sp.CrSize;
                            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+sp.CrSize,
                            XAD_USESKIPINFO, 1, TAG_DONE);
                          }
                        }
                        else
                          err = XADERR_NOMEMORY;
                      }
                      else
                        err = XADERR_ILLEGALDATA;
                    } /* XADAC_READ */
                  } /* while */
                } /* XADAC_INPUTSEEK */
              }
              xadFreeObjectA(XADM buf2, 0);
            } /* xadAllocObject */
            else
              err = XADERR_NOMEMORY;
          }
          else
            err = XADERR_ILLEGALDATA;
        }
      }
    }
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return ai->xai_FileInfo ? 0 : err;
}

/**************************************************************************************************/

XADRECOGDATA(SPackSFX)
{
  if(EndGetM32(data) == 0x3F3 /*HUNK_HEADER*/)
  {
    if(EndGetM32(data+10*4) == 0x42ADFFFC && EndGetM32(data+12*4) == 0x2C780004
    && EndGetM32(data+13*4) == 0x4EAEFE68 && EndGetM32(data+15*4) == 0x208093C9
    && EndGetM32(data+16*4) == 0x4EAEFEDA)
      return 1;
  }
  return 0;
}

XADGETINFO(SPackSFX)
{
  xadINT32 err;
  xadUINT8 mem[12*4];

  if(!(err = xadHookAccess(XADM XADAC_READ, 12*4, mem, ai)))
  {
    /* err is misued here! */
    if(mem[11*4+3] == 0xF4)
      err = 6624 - 12*4;
    else
      err = 6616 - 12*4;
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, err, 0, ai)))
      err = SPack_GetInfo(ai, xadMasterBase);
  }
  return err;
}

/**************************************************************************************************/

XADCLIENT(SPackSFX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SHRINK_VERSION,
  SHRINK_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESKIPINFO,
  XADCID_SPACKSFX,
  "S-Pack SFX",
  XADRECOGDATAP(SPackSFX),
  XADGETINFOP(SPackSFX),
  XADUNARCHIVEP(Shrink),
  NULL
};

XADCLIENT(SPack) {
  (struct xadClient *) &SPackSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SHRINK_VERSION,
  SHRINK_REVISION,
  6,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESKIPINFO,
  XADCID_SPACK,
  "S-Pack",
  XADRECOGDATAP(SPack),
  XADGETINFOP(SPack),
  XADUNARCHIVEP(Shrink),
  NULL
};

XADCLIENT(Shrink) {
  (struct xadClient *) &SPack_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SHRINK_VERSION,
  SHRINK_REVISION,
  24,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_SHRINK,
  "Shrink",
  XADRECOGDATAP(Shrink),
  XADGETINFOP(IFF_CDAF),
  XADUNARCHIVEP(Shrink),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Shrink)

/* // Uses XPK only - not supported
XADFIRSTCLIENT(XPKArchive) {
  (struct xadClient *) &Shrink_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  XPKARCHIVE_VERSION,
  XPKARCHIVE_REVISION,
  30,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_XPKARCHIVE,
  "XPK Archive",
  XADRECOGDATAP(XPKArchive),
  XADGETINFOP(IFF_CDAF),
  XADUNARCHIVEP(XPKArchive),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(XPKArchive)
*/

#endif /* XADMASTER_IFF_CDAF_C */
