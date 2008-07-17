#ifndef XADMASTER_STUFFIT_C
#define XADMASTER_STUFFIT_C

/*  $Id: StuffIt.c,v 1.13 2005/06/23 14:54:41 stoecker Exp $
    StuffIt file archiver client

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>

    little based on macutils 2.0b3 macunpack by Dik T. Winter
    Copyright (C) 1992 Dik T. Winter <dik@cwi.nl>

    algorithm 15 is based on the work of  Matthew T. Russotto
    Copyright (C) 2002 Matthew T. Russotto <russotto@speakeasy.net>
    http://www.speakeasy.org/~russotto/arseniccomp.html

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
  #define XADMASTERVERSION 12
#endif

#define XADIOGETBITSHIGH
#define XADIOGETBITSLOW
#define XADIOREADBITSLOW
#include "xadIO.c"
#include "xadCRC_1021.c"
#include "xadIO_Compress.c"

XADCLIENTVERSTR("StuffIt 1.12 (21.2.2004)")

#define SIT_VERSION             1
#define SIT_REVISION            12
#define SIT5_VERSION            SIT_VERSION
#define SIT5_REVISION           SIT_REVISION
#define SIT5EXE_VERSION         SIT_VERSION
#define SIT5EXE_REVISION        SIT_REVISION
#define MACBINARY_VERSION       SIT_VERSION
#define MACBINARY_REVISION      SIT_REVISION
#define PACKIT_VERSION          SIT_VERSION
#define PACKIT_REVISION         SIT_REVISION

#define SITFH_COMPRMETHOD    0 /* xadUINT8 rsrc fork compression method */
#define SITFH_COMPDMETHOD    1 /* xadUINT8 data fork compression method */
#define SITFH_FNAMESIZE      2 /* xadUINT8 filename size */
#define SITFH_FNAME          3 /* xadUINT8 83 byte filename */
#define SITFH_FTYPE         66 /* xadUINT32 file type */
#define SITFH_CREATOR       70 /* xadUINT32 file creator */
#define SITFH_FNDRFLAGS     74 /* xadUINT16 Finder flags */
#define SITFH_CREATIONDATE  76 /* xadUINT32 creation date */
#define SITFH_MODDATE       80 /* xadUINT32 modification date */
#define SITFH_RSRCLENGTH    84 /* xadUINT32 decompressed rsrc length */
#define SITFH_DATALENGTH    88 /* xadUINT32 decompressed data length */
#define SITFH_COMPRLENGTH   92 /* xadUINT32 compressed rsrc length */
#define SITFH_COMPDLENGTH   96 /* xadUINT32 compressed data length */
#define SITFH_RSRCCRC      100 /* xadUINT16 crc of rsrc fork */
#define SITFH_DATACRC      102 /* xadUINT16 crc of data fork */ /* 6 reserved bytes */
#define SITFH_HDRCRC       110 /* xadUINT16 crc of file header */
#define SIT_FILEHDRSIZE    112

#define SITAH_SIGNATURE    0 /* xadUINT32 signature = 'SIT!' */
#define SITAH_NUMFILES     4 /* xadUINT16 number of files in archive */
#define SITAH_ARCLENGTH    6 /* xadUINT32 arcLength length of entire archive incl. header */
#define SITAH_SIGNATURE2  10 /* xadUINT32 signature2 = 'rLau' */
#define SITAH_VERSION     14 /* xadUINT8 version number */
#define SIT_ARCHDRSIZE    22 /* +7 reserved bytes */

/* compression methods */
#define SITnocomp       0       /* just read each byte and write it to archive */
#define SITrle          1       /* RLE compression */
#define SITlzc          2       /* LZC compression */
#define SIThuffman      3       /* Huffman compression */

#define SITlzah         5       /* LZ with adaptive Huffman */
#define SITfixhuf       6       /* Fixed Huffman table */

#define SITmw           8       /* Miller-Wegman encoding */

#define SITprot         16      /* password protected bit */
#define SITsfolder      32      /* start of folder */
#define SITefolder      33      /* end of folder */

struct SITPrivate {
  xadUINT16 CRC;
  xadUINT8 Method;
};

#define SITPI(a)        ((struct SITPrivate *) ((a)->xfi_PrivateInfo))

/*****************************************************************************/

#define STUFFITMAXALGO  15
static const xadSTRPTR sittypes[] = {
"NoComp", "RLE", "LZC", "Huffmann", "4", "LZAH", "FixHuff", "7", "MW",
"9", "10", "11", "12", "TableHuff", "Installer", "Arsenic"};

XADRECOGDATA(SIT)
{
  if(EndGetM32(data+10) == 0x724C6175)
  {
    if(EndGetM32(data) == 0x53495421)
      return 1;
    /* Installer archives? */
    if(data[0] == 'S' && data[1] == 'T')
    {
      if(data[2] == 'i')
      {
        if(data[3] == 'n' || (data[3] >= '0' && data[3] <= '9'))
          return 1;
      }
      else if(data[2] >= '0' && data[2] <= '9' && data[3] >= '0' && data[3] <= '9')
        return 1;
    }
  }
  return 0;
}

/*****************************************************************************/

static xadSTRPTR MACname(struct xadMasterBase *xadMasterBase, struct xadFileInfo *dir, xadSTRPTR file, xadUINT32 size, xadUINT32 rsrc)
{
  return xadConvertName(XADM CHARSET_HOST,
  XAD_XADSTRING, dir ? dir->xfi_FileName : 0,
  XAD_CHARACTERSET, CHARSET_MACOS,
  XAD_STRINGSIZE, size,
  XAD_CSTRING, file,
  XAD_CHARACTERSET, CHARSET_ISO_8859_1,          /* the .rsrc ending */
  XAD_ADDPATHSEPERATOR, XADFALSE,
  rsrc ? XAD_CSTRING : TAG_IGNORE, ".rsrc",
  TAG_DONE);
}

static xadINT32 SITmakecomment(xadSTRPTR txt, xadUINT16 creatorflags, xadSTRPTR comment, xadUINT32 csize, xadSTRPTR dest)
{
  xadINT32 i, res = 0;

  if(csize)
    res = 15+csize+1;
  else
  {
    for(i = 0; i < 8 && txt[i] >= 0x20 && txt[i] <= 0x7E; ++i)
      ;
    if(i == 8)
      res = 15;
  }
  if(res && dest)
  {
    for(i = 0; i < 4; ++i)
      *(dest++) = txt[i] >= 0x20 && txt[i] <= 0x7E ? txt[i] : '_';
    *(dest++) = '/';
    for(; i < 8; ++i)
      *(dest++) = txt[i] >= 0x20 && txt[i] <= 0x7E ? txt[i] : '_';
    *(dest++) = ' ';
    for(i = 0; i < 4 ; ++i)
    {
      creatorflags &= 0xFFFF; /* security */
      *(dest++) = (creatorflags >= 0xA000 ? 'A'-10 : '0') + (creatorflags >> 12);
      creatorflags <<= 4;
    }
    if(csize)
    {
      *(dest++) = ' ';
      while(csize--)
      {
        *(dest++) = *comment >= 0x20 && *comment <= 0x7E ? *comment : '_';
        ++comment;
      }
    }
    *dest = 0;
  }
  return res;
}

XADGETINFO(SIT)
{
  xadUINT8 sithdr[SIT_FILEHDRSIZE];
  struct xadFileInfo *fi, *ldir = 0, *lfi = 0;
  xadINT32 err;
  xadUINT32 nsize, csize, fullsize;


  fullsize = ai->xai_InSize;
  if(!(err =  xadHookAccess(XADM XADAC_READ, 22, sithdr, ai)))
  {
    if(sithdr[2] == 'i')
    {
      csize = EndGetM32(sithdr+SITAH_ARCLENGTH);
      if(csize < fullsize)
        fullsize = csize;
    }

#ifdef DEBUG
#define MAKESIT(a,b,c,d) ((xadUINT32) ((a)<<24) | (xadUINT32) ((b)<<16) | (xadUINT32) ((c)<<8) | (xadUINT32) (d))
switch(EndGetM32(sithdr))
{
case MAKESIT('S','I','T','!'):
case MAKESIT('S','T','4','6'):
case MAKESIT('S','T','5','0'):
case MAKESIT('S','T','6','0'):
case MAKESIT('S','T','6','5'):
case MAKESIT('S','T','i','n'):
case MAKESIT('S','T','i','2'):
case MAKESIT('S','T','i','3'):
case MAKESIT('S','T','i','4'):
  break;
default: DebugFileSearched(ai, "File has unknown identifier.");
}
#endif
    while(!err && ai->xai_InPos+SIT_FILEHDRSIZE <= fullsize)
    {
      if(!(err =  xadHookAccess(XADM XADAC_READ, SIT_FILEHDRSIZE, sithdr, ai)))
      {
        if(EndGetM16(sithdr+SITFH_HDRCRC) == xadCalcCRC16(XADM XADCRC16_ID1, 0, 110, sithdr))
        {
          for(nsize = 0; nsize < 8; ++nsize)
          {
            if(sithdr[SITFH_FTYPE+nsize] < 0x20 || sithdr[SITFH_FTYPE+nsize] > 0x7E)
              sithdr[SITFH_FTYPE+nsize] = '?';
          }

          if(sithdr[SITFH_FNAMESIZE] > 83)
            nsize = 83; /* prevent errors */
          else
            nsize = sithdr[SITFH_FNAMESIZE];
          if(sithdr[SITFH_COMPRMETHOD] == SITefolder || sithdr[SITFH_COMPDMETHOD] == SITefolder)
          {
            ldir = (struct xadFileInfo *) ldir->xfi_PrivateInfo;
          }
          else if(sithdr[SITFH_COMPRMETHOD] == SITsfolder || sithdr[SITFH_COMPDMETHOD] == SITsfolder)
          {
            if((fi = xadAllocObjectA(XADM XADOBJ_FILEINFO, 0)))
            {
              if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR) sithdr+SITFH_FNAME, nsize, 0)))
              {
                fi->xfi_Flags |= XADFIF_DIRECTORY|XADFIF_XADSTRFILENAME;
                xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&sithdr[SITFH_MODDATE]), XAD_GETDATEXADDATE,
                &fi->xfi_Date, TAG_DONE);
                fi->xfi_PrivateInfo = (xadPTR) ldir;
                ldir = fi;
                err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
              }
              else
              {
                xadFreeObjectA(XADM fi, 0);
                err = XADERR_NOMEMORY;
              }
            }
            else
              err = XADERR_NOMEMORY;
          }
          else
          {
            csize = SITmakecomment((xadSTRPTR) sithdr + SITFH_FTYPE, EndGetM16(&sithdr[SITFH_FNDRFLAGS]), 0, 0, 0);

            if(EndGetM32(&sithdr[SITFH_RSRCLENGTH]))
            {
              if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE, sizeof(struct SITPrivate),
              EndGetM32(&sithdr[SITFH_DATALENGTH]) || !csize ?
              TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
              {
                if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR) sithdr+SITFH_FNAME, nsize, 1)))
                {
                  /* if comment field is zero, nothing is done! */
                  SITmakecomment((xadSTRPTR) sithdr + SITFH_FTYPE, EndGetM16(&sithdr[SITFH_FNDRFLAGS]), 0, 0, fi->xfi_Comment);

                  fi->xfi_CrunchSize = EndGetM32(&sithdr[SITFH_COMPRLENGTH]);
                  fi->xfi_Size = EndGetM32(&sithdr[SITFH_RSRCLENGTH]);

                  fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
                  fi->xfi_DataPos = ai->xai_InPos;
                  lfi = fi;

                  SITPI(fi)->CRC = EndGetM16(&sithdr[SITFH_RSRCCRC]);
                  SITPI(fi)->Method = sithdr[SITFH_COMPRMETHOD]&15;

                  if(!fi->xfi_Size && !SITPI(fi)->Method)
                    fi->xfi_Size = fi->xfi_CrunchSize;

#ifdef DEBUG
  if(SITPI(fi)->Method != 0 && SITPI(fi)->Method != 2 && SITPI(fi)->Method != 3 &&
  SITPI(fi)->Method != 5 && SITPI(fi)->Method != 8 && SITPI(fi)->Method != 13 && SITPI(fi)->Method != 14
  && SITPI(fi)->Method != 15)
  {
    DebugFileSearched(ai, "Unknown or untested compression method %ld.",
    SITPI(fi)->Method);
  }
#endif
                  xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&sithdr[SITFH_MODDATE]), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

                  if(SITPI(fi)->Method <= STUFFITMAXALGO)
                    fi->xfi_EntryInfo = sittypes[SITPI(fi)->Method];
                  if(sithdr[SITFH_COMPRMETHOD]&SITprot)
                  {
                    fi->xfi_Flags |= XADFIF_CRYPTED;
                    ai->xai_Flags |= XADAIF_CRYPTED;
                  }

                  err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                }
                else
                {
                  xadFreeObjectA(XADM fi, 0);
                  err = XADERR_NOMEMORY;
                }
              }
              else
                err = XADERR_NOMEMORY;
            }

            if(!err && (EndGetM32(&sithdr[SITFH_DATALENGTH]) || !EndGetM32(&sithdr[SITFH_RSRCLENGTH])))
            {
              if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE, sizeof(struct SITPrivate),
              csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize, TAG_DONE)))
              {
                if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR) sithdr+SITFH_FNAME, nsize, 0)))
                {
                  SITmakecomment((xadSTRPTR)sithdr + SITFH_FTYPE, EndGetM16(&sithdr[SITFH_FNDRFLAGS]), 0, 0, fi->xfi_Comment);

                  fi->xfi_CrunchSize = EndGetM32(&sithdr[SITFH_COMPDLENGTH]);
                  fi->xfi_Size = EndGetM32(&sithdr[SITFH_DATALENGTH]);

                  fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
                  fi->xfi_DataPos = ai->xai_InPos;

                  if(EndGetM32(&sithdr[SITFH_RSRCLENGTH]))
                  {
                    fi->xfi_MacFork = lfi;
                    lfi->xfi_MacFork = fi;
                  }

                  SITPI(fi)->CRC = EndGetM16(&sithdr[SITFH_DATACRC]);
                  SITPI(fi)->Method = sithdr[SITFH_COMPDMETHOD]&15;

                  if(!fi->xfi_Size && !SITPI(fi)->Method)
                    fi->xfi_Size = fi->xfi_CrunchSize;

#ifdef DEBUG
  if(SITPI(fi)->Method != 0 && SITPI(fi)->Method != 2 && SITPI(fi)->Method != 3 &&
  SITPI(fi)->Method != 5 && SITPI(fi)->Method != 8 && SITPI(fi)->Method != 13 && SITPI(fi)->Method != 14
  && SITPI(fi)->Method != 15)
  {
    DebugFileSearched(ai, "Unknown or untested compression method %ld.",
    SITPI(fi)->Method);
  }
#endif
                  xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&sithdr[SITFH_MODDATE]),
                  XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

                  if(SITPI(fi)->Method <= STUFFITMAXALGO)
                    fi->xfi_EntryInfo = sittypes[SITPI(fi)->Method];
                  if(sithdr[SITFH_COMPDMETHOD]&SITprot)
                  {
                    fi->xfi_Flags |= XADFIF_CRYPTED;
                    ai->xai_Flags |= XADAIF_CRYPTED;
                  }

                  err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                }
                else
                {
                  xadFreeObjectA(XADM fi, 0);
                  err = XADERR_NOMEMORY;
                }
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
        }
        else
          err = XADERR_CHECKSUM;
      }
    }

    if(!err && ai->xai_InPos < fullsize)
      err = XADERR_ILLEGALDATA;
    if(err)
    {
      ai->xai_Flags |= XADAIF_FILECORRUPT;
      ai->xai_LastError = err;
    }
  }

#ifdef DEBUG
  if(err || (ai->xai_Flags & XADAIF_CRYPTED))
  {
    DebugFileSearched(ai, "Encrypted data.",
    SITPI(fi)->Method);
  }
#endif

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

#define SITESC  0x90    /* repeat packing escape */

static xadINT32 SIT_rle(struct xadInOut *io)
{
  xadINT32 ch, lastch = 0, n;

  while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
  {
    if((ch = xadIOGetChar(io)) == SITESC)
    {
      if((n = xadIOGetChar(io) - 1) < 0)
        lastch = xadIOPutChar(io, SITESC);
      else
        while(n--)
          xadIOPutChar(io, lastch);
    }
    else
      lastch = xadIOPutChar(io, ch);
  }
  return io->xio_Error;
}

/*****************************************************************************/

struct sithufnode {
  struct sithufnode *one;
  struct sithufnode *zero;
  xadUINT8              byte;
};

static xadINT32 SIT_huffman(struct xadInOut *io)
{
  struct sithufnode *np, *npb, *nodelist;
  xadINT32 numfreetree = 0; /* number of free np->one nodes */
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

   /* 515 because StuffIt Classic needs more than the needed 511 */
  if((nodelist = (struct sithufnode *) xadAllocVec(XADM sizeof(struct sithufnode)*515, XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    npb = nodelist;
    do /* removed recursion, optimized a lot */
    {
      do
      {
        np = npb++;
        if(xadIOGetBitsHigh(io, 1))
        {
          np->byte = xadIOGetBitsHigh(io, 8);
          np->zero = np->one = (struct sithufnode *) -1;
        }
        else
        {
          np->zero = npb;
          ++numfreetree;
        }
      } while(!np->one);
      if(numfreetree--)
      {
        while(np->one)
          --np;
        np->one = npb;
      }
    } while(numfreetree >= 0);

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      np = nodelist;
      while(np->one != (struct sithufnode *) -1)
        np = xadIOGetBitsHigh(io, 1) ? np->one : np->zero;
      xadIOPutChar(io, np->byte);
    }

    xadFreeObjectA(XADM nodelist, 0);
  }
  else
    return XADERR_NOMEMORY;

  return io->xio_Error;
}

/*****************************************************************************/

/* Note: compare with LZSS decoding in lharc! */
#define SITLZAH_N       314
#define SITLZAH_T       (2*SITLZAH_N-1)
/*      Huffman table used for first 6 bits of offset:
        #bits   codes
        3       0x000
        4       0x040-0x080
        5       0x100-0x2c0
        6       0x300-0x5c0
        7       0x600-0xbc0
        8       0xc00-0xfc0
*/

static const xadUINT8 SITLZAH_HuffCode[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
  0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
  0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
  0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c,
  0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
  0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
  0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24,
  0x28, 0x28, 0x28, 0x28, 0x28, 0x28, 0x28, 0x28,
  0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c,
  0x30, 0x30, 0x30, 0x30, 0x34, 0x34, 0x34, 0x34,
  0x38, 0x38, 0x38, 0x38, 0x3c, 0x3c, 0x3c, 0x3c,
  0x40, 0x40, 0x40, 0x40, 0x44, 0x44, 0x44, 0x44,
  0x48, 0x48, 0x48, 0x48, 0x4c, 0x4c, 0x4c, 0x4c,
  0x50, 0x50, 0x50, 0x50, 0x54, 0x54, 0x54, 0x54,
  0x58, 0x58, 0x58, 0x58, 0x5c, 0x5c, 0x5c, 0x5c,
  0x60, 0x60, 0x64, 0x64, 0x68, 0x68, 0x6c, 0x6c,
  0x70, 0x70, 0x74, 0x74, 0x78, 0x78, 0x7c, 0x7c,
  0x80, 0x80, 0x84, 0x84, 0x88, 0x88, 0x8c, 0x8c,
  0x90, 0x90, 0x94, 0x94, 0x98, 0x98, 0x9c, 0x9c,
  0xa0, 0xa0, 0xa4, 0xa4, 0xa8, 0xa8, 0xac, 0xac,
  0xb0, 0xb0, 0xb4, 0xb4, 0xb8, 0xb8, 0xbc, 0xbc,
  0xc0, 0xc4, 0xc8, 0xcc, 0xd0, 0xd4, 0xd8, 0xdc,
  0xe0, 0xe4, 0xe8, 0xec, 0xf0, 0xf4, 0xf8, 0xfc};

static const xadUINT8 SITLZAH_HuffLength[] = {
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8};

struct SITLZAHData {
  xadUINT8 buf[4096];
  xadUINT32 Frequ[1000];
  xadUINT32 ForwTree[1000];
  xadUINT32 BackTree[1000];
};

static void SITLZAH_move(xadUINT32 *p, xadUINT32 *q, xadUINT32 n)
{
  if(p > q)
  {
    while(n-- > 0)
      *q++ = *p++;
  }
  else
  {
    p += n;
    q += n;
    while(n-- > 0)
      *--q = *--p;
  }
}

static xadINT32 SIT_lzah(struct xadInOut *io)
{
  xadINT32 i, i1, j, k, l, ch, byte, offs, skip;
  xadUINT32 bufptr = 0;
  struct SITLZAHData *dat;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  if((dat = (struct SITLZAHData *) xadAllocVec(XADM sizeof(struct SITLZAHData), XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    /* init buffer */
    for(i = 0; i < SITLZAH_N; i++)
    {
      dat->Frequ[i] = 1;
      dat->ForwTree[i] = i + SITLZAH_T;
      dat->BackTree[i + SITLZAH_T] = i;
    }
    for(i = 0, j = SITLZAH_N; j < SITLZAH_T; i += 2, j++)
    {
      dat->Frequ[j] = dat->Frequ[i] + dat->Frequ[i + 1];
      dat->ForwTree[j] = i;
      dat->BackTree[i] = j;
      dat->BackTree[i + 1] = j;
    }
    dat->Frequ[SITLZAH_T] = 0xffff;
    dat->BackTree[SITLZAH_T - 1] = 0;

    for(i = 0; i < 4096; i++)
      dat->buf[i] = ' ';

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      ch = dat->ForwTree[SITLZAH_T - 1];
      while(ch < SITLZAH_T)
        ch = dat->ForwTree[ch + xadIOGetBitsHigh(io, 1)];
      ch -= SITLZAH_T;
      if(dat->Frequ[SITLZAH_T - 1] >= 0x8000) /* need to reorder */
      {
        j = 0;
        for(i = 0; i < SITLZAH_T; i++)
        {
          if(dat->ForwTree[i] >= SITLZAH_T)
          {
            dat->Frequ[j] = ((dat->Frequ[i] + 1) >> 1);
            dat->ForwTree[j] = dat->ForwTree[i];
            j++;
          }
        }
        j = SITLZAH_N;
        for(i = 0; i < SITLZAH_T; i += 2)
        {
          k = i + 1;
          l = dat->Frequ[i] + dat->Frequ[k];
          dat->Frequ[j] = l;
          k = j - 1;
          while(l < dat->Frequ[k])
            k--;
          k = k + 1;
          SITLZAH_move(dat->Frequ + k, dat->Frequ + k + 1, j - k);
          dat->Frequ[k] = l;
          SITLZAH_move(dat->ForwTree + k, dat->ForwTree + k + 1, j - k);
          dat->ForwTree[k] = i;
          j++;
        }
        for(i = 0; i < SITLZAH_T; i++)
        {
          k = dat->ForwTree[i];
          if(k >= SITLZAH_T)
            dat->BackTree[k] = i;
          else
          {
            dat->BackTree[k] = i;
            dat->BackTree[k + 1] = i;
          }
        }
      }

      i = dat->BackTree[ch + SITLZAH_T];
      do
      {
        j = ++dat->Frequ[i];
        i1 = i + 1;
        if(dat->Frequ[i1] < j)
        {
          while(dat->Frequ[++i1] < j)
            ;
          i1--;
          dat->Frequ[i] = dat->Frequ[i1];
          dat->Frequ[i1] = j;

          j = dat->ForwTree[i];
          dat->BackTree[j] = i1;
          if(j < SITLZAH_T)
            dat->BackTree[j + 1] = i1;
          dat->ForwTree[i] = dat->ForwTree[i1];
          dat->ForwTree[i1] = j;
          j = dat->ForwTree[i];
          dat->BackTree[j] = i;
          if(j < SITLZAH_T)
            dat->BackTree[j + 1] = i;
          i = i1;
        }
        i = dat->BackTree[i];
      } while(i != 0);

      if(ch < 256)
      {
        dat->buf[bufptr++] = xadIOPutChar(io, ch);
        bufptr &= 0xFFF;
      }
      else
      {
        byte = xadIOGetBitsHigh(io, 8);
        skip = SITLZAH_HuffLength[byte] - 2;
        offs = (SITLZAH_HuffCode[byte]<<4) | (((byte << skip)  + xadIOGetBitsHigh(io, skip)) & 0x3f);
        offs = ((bufptr - offs - 1) & 0xfff);
        ch = ch - 253;
        while(ch-- > 0)
        {
          dat->buf[bufptr++] = xadIOPutChar(io, dat->buf[offs++ & 0xfff]);
          bufptr &= 0xFFF;
        }
      }
    }
    xadFreeObjectA(XADM dat, 0);
  }
  else
    return XADERR_NOMEMORY;

  return io->xio_Error;
}

/*****************************************************************************/

struct SITMWData {
  xadUINT16 dict[16385];
  xadUINT16 stack[16384];
};

static void SITMW_out(struct xadInOut *io, struct SITMWData *dat, xadINT32 ptr)
{
  xadUINT16 stack_ptr = 1;

  dat->stack[0] = ptr;
  while(stack_ptr)
  {
    ptr = dat->stack[--stack_ptr];
    while(ptr >= 256)
    {
      dat->stack[stack_ptr++] = dat->dict[ptr];
      ptr = dat->dict[ptr - 1];
    }
    xadIOPutChar(io, (xadUINT8) ptr);
  }
}

static xadINT32 SIT_mw(struct xadInOut *io)
{
  struct SITMWData *dat;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  if((dat = (struct SITMWData *) xadAllocVec(XADM sizeof(struct SITMWData), XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    xadINT32 ptr, max, max1, bits;

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      max = 256;
      max1 = max << 1;
      bits = 9;
      ptr = xadIOGetBitsLow(io, bits);
      if(ptr < max)
      {
        dat->dict[255] = ptr;
        SITMW_out(io, dat, ptr);
        while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)) &&
        (ptr = xadIOGetBitsLow(io, bits)) < max)
        {
          dat->dict[max++] = ptr;
          if(max == max1)
          {
            max1 <<= 1;
            bits++;
          }
          SITMW_out(io, dat, ptr);
        }
      }
      if(ptr > max)
        break;
    }

    xadFreeObjectA(XADM dat, 0);
  }
  else
    return XADERR_NOMEMORY;

  return io->xio_Error;
}

/*****************************************************************************/

struct SIT13Buffer {
  xadUINT16 data;
  xadINT8  bits;
};

struct SIT13Store {
  xadINT16  freq;
  xadUINT16 d1;
  xadUINT16 d2;
};

struct SIT13Data {
  xadUINT16              MaxBits;
  struct SIT13Store  Buffer4[0xE08];
  struct SIT13Buffer Buffer1[0x1000];
  struct SIT13Buffer Buffer2[0x1000];
  struct SIT13Buffer Buffer3[0x1000];
  struct SIT13Buffer Buffer3b[0x1000];
  struct SIT13Buffer Buffer5[0x141];
  xadUINT8              TextBuf[658];
  xadUINT8              Window[0x10000];
};

static const xadUINT8 SIT13Bits[16] = {0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15};
static const xadUINT16 SIT13Info[37] = {
  0x5D8, 0x058, 0x040, 0x0C0, 0x000, 0x078, 0x02B, 0x014,
  0x00C, 0x01C, 0x01B, 0x00B, 0x010, 0x020, 0x038, 0x018,
  0x0D8, 0xBD8, 0x180, 0x680, 0x380, 0xF80, 0x780, 0x480,
  0x080, 0x280, 0x3D8, 0xFD8, 0x7D8, 0x9D8, 0x1D8, 0x004,
  0x001, 0x002, 0x007, 0x003, 0x008
};
static const xadUINT16 SIT13InfoBits[37] = {
  11,  8,  8,  8,  8,  7,  6,  5,  5,  5,  5,  6,  5,  6,  7,  7,
   9, 12, 10, 11, 11, 12, 12, 11, 11, 11, 12, 12, 12, 12, 12,  5,
   2,  2,  3,  4,  5
};
static const xadUINT16 SIT13StaticPos[5] = {0, 330, 661, 991, 1323};
static const xadUINT8 SIT13StaticBits[5] = {11, 13, 14, 11, 11};
static const xadUINT8 SIT13Static[1655] = {
  0xB8,0x98,0x78,0x77,0x75,0x97,0x76,0x87,0x77,0x77,0x77,0x78,0x67,0x87,0x68,0x67,0x3B,0x77,0x78,0x67,
  0x77,0x77,0x77,0x59,0x76,0x87,0x77,0x77,0x77,0x77,0x77,0x77,0x76,0x87,0x67,0x87,0x77,0x77,0x75,0x88,
  0x59,0x75,0x79,0x77,0x78,0x68,0x77,0x67,0x73,0xB6,0x65,0xB6,0x76,0x97,0x67,0x47,0x9A,0x2A,0x4A,0x87,
  0x77,0x78,0x67,0x86,0x78,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x77,0x77,
  0x68,0x77,0x77,0x77,0x67,0x87,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x68,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x67,0x87,
  0x68,0x77,0x77,0x77,0x68,0x77,0x68,0x63,0x86,0x7A,0x87,0x77,0x77,0x87,0x76,0x87,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x76,0x86,0x77,0x86,0x86,0x86,0x86,0x87,0x76,0x86,0x87,0x67,0x74,0xA7,0x86,
  0x36,0x88,0x78,0x76,0x87,0x76,0x96,0x87,0x77,0x84,0xA6,0x86,0x87,0x76,0x92,0xB5,0x94,0xA6,0x96,0x85,
  0x78,0x75,0x96,0x86,0x86,0x75,0xA7,0x67,0x87,0x85,0x87,0x85,0x95,0x77,0x77,0x85,0xA3,0xA7,0x93,0x87,
  0x86,0x94,0x85,0xA8,0x67,0x85,0xA5,0x95,0x86,0x68,0x67,0x77,0x96,0x78,0x75,0x86,0x77,0xA5,0x67,0x87,
  0x85,0xA6,0x75,0x96,0x85,0x87,0x95,0x95,0x87,0x86,0x94,0xA5,0x86,0x85,0x87,0x86,0x86,0x86,0x86,0x77,
  0x67,0x76,0x66,0x9A,0x75,0xA5,0x94,0x97,0x76,0x96,0x76,0x95,0x86,0x77,0x86,0x87,0x75,0xA5,0x96,0x85,
  0x86,0x96,0x86,0x86,0x85,0x96,0x86,0x76,0x95,0x86,0x95,0x95,0x95,0x87,0x76,0x87,0x76,0x96,0x85,0x78,
  0x75,0xA6,0x85,0x86,0x95,0x86,0x95,0x86,0x45,0x69,0x78,0x77,0x87,0x67,0x69,0x58,0x79,0x68,0x78,0x87,
  0x78,0x66,0x88,0x68,0x68,0x77,0x76,0x87,0x68,0x68,0x69,0x58,0x5A,0x4B,0x76,0x88,0x69,0x67,0xA7,0x70,
  0x9F,0x90,0xA4,0x84,0x77,0x77,0x77,0x89,0x17,0x77,0x7B,0xA7,0x86,0x87,0x77,0x68,0x68,0x69,0x67,0x78,
  0x77,0x78,0x76,0x87,0x77,0x76,0x73,0xB6,0x87,0x96,0x66,0x87,0x76,0x85,0x87,0x78,0x77,0x77,0x86,0x77,
  0x86,0x78,0x66,0x76,0x77,0x87,0x86,0x78,0x76,0x76,0x86,0xA5,0x67,0x97,0x77,0x87,0x87,0x76,0x66,0x59,
  0x67,0x59,0x77,0x6A,0x65,0x86,0x78,0x94,0x77,0x88,0x77,0x78,0x86,0x86,0x76,0x88,0x76,0x87,0x67,0x87,
  0x77,0x77,0x76,0x87,0x86,0x77,0x77,0x77,0x86,0x86,0x76,0x96,0x77,0x77,0x76,0x78,0x86,0x86,0x86,0x95,
  0x86,0x96,0x85,0x95,0x86,0x87,0x75,0x88,0x77,0x87,0x57,0x78,0x76,0x86,0x76,0x96,0x86,0x87,0x76,0x87,
  0x86,0x76,0x77,0x86,0x78,0x78,0x57,0x87,0x86,0x76,0x85,0xA5,0x87,0x76,0x86,0x86,0x85,0x86,0x53,0x98,
  0x78,0x78,0x77,0x87,0x79,0x67,0x79,0x85,0x87,0x69,0x67,0x68,0x78,0x69,0x68,0x69,0x58,0x87,0x66,0x97,
  0x68,0x68,0x76,0x85,0x78,0x87,0x67,0x97,0x67,0x74,0xA2,0x28,0x77,0x78,0x77,0x77,0x78,0x68,0x67,0x78,
  0x77,0x78,0x68,0x68,0x77,0x59,0x67,0x5A,0x68,0x68,0x68,0x68,0x68,0x68,0x67,0x77,0x78,0x68,0x68,0x78,
  0x59,0x58,0x76,0x77,0x68,0x78,0x68,0x59,0x69,0x58,0x68,0x68,0x67,0x78,0x77,0x78,0x69,0x58,0x68,0x57,
  0x78,0x67,0x78,0x76,0x88,0x58,0x67,0x7A,0x46,0x88,0x77,0x78,0x68,0x68,0x66,0x78,0x78,0x68,0x68,0x59,
  0x68,0x69,0x68,0x59,0x67,0x78,0x59,0x58,0x69,0x59,0x67,0x68,0x67,0x69,0x69,0x57,0x79,0x68,0x59,0x59,
  0x59,0x68,0x68,0x68,0x58,0x78,0x67,0x59,0x68,0x78,0x59,0x58,0x78,0x58,0x76,0x78,0x68,0x68,0x68,0x69,
  0x59,0x67,0x68,0x69,0x59,0x59,0x58,0x69,0x59,0x59,0x58,0x5A,0x58,0x68,0x68,0x59,0x58,0x68,0x66,0x47,
  0x88,0x77,0x87,0x77,0x87,0x76,0x87,0x87,0x87,0x77,0x77,0x87,0x67,0x96,0x78,0x76,0x87,0x68,0x77,0x77,
  0x76,0x86,0x96,0x86,0x88,0x77,0x85,0x86,0x8B,0x76,0x0A,0xF9,0x07,0x38,0x57,0x67,0x77,0x78,0x77,0x91,
  0x77,0xD7,0x77,0x7A,0x67,0x3C,0x68,0x68,0x77,0x68,0x78,0x59,0x77,0x68,0x77,0x68,0x76,0x77,0x69,0x68,
  0x68,0x68,0x68,0x67,0x68,0x68,0x77,0x87,0x77,0x67,0x78,0x68,0x67,0x58,0x78,0x68,0x77,0x68,0x78,0x67,
  0x68,0x68,0x67,0x78,0x77,0x77,0x87,0x77,0x76,0x67,0x86,0x85,0x87,0x86,0x97,0x58,0x67,0x79,0x57,0x77,
  0x87,0x77,0x87,0x77,0x76,0x59,0x78,0x77,0x77,0x68,0x77,0x77,0x76,0x78,0x77,0x77,0x77,0x76,0x87,0x77,
  0x77,0x68,0x77,0x77,0x77,0x67,0x78,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x76,0x68,0x87,0x77,
  0x77,0x77,0x77,0x68,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x77,0x76,0x78,0x77,0x77,0x76,0x87,0x77,0x77,
  0x67,0x78,0x77,0x77,0x76,0x78,0x67,0x68,0x68,0x29,0x77,0x88,0x78,0x78,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x4A,0x77,0x4A,0x74,0x77,0x77,0x68,0xA4,0x7A,0x47,0x76,0x86,0x78,0x76,0x7A,0x4A,
  0x83,0xB2,0x87,0x77,0x87,0x76,0x96,0x86,0x96,0x76,0x78,0x87,0x77,0x85,0x87,0x85,0x96,0x65,0xB5,0x95,
  0x96,0x77,0x77,0x86,0x76,0x86,0x86,0x87,0x86,0x86,0x76,0x96,0x96,0x57,0x77,0x85,0x97,0x85,0x86,0xA5,
  0x86,0x85,0x87,0x77,0x68,0x78,0x77,0x95,0x86,0x75,0x87,0x76,0x86,0x79,0x68,0x84,0x96,0x76,0xB3,0x87,
  0x77,0x68,0x86,0xA5,0x77,0x56,0xB6,0x68,0x85,0x93,0xB6,0x95,0x95,0x85,0x95,0xA5,0x95,0x95,0x69,0x85,
  0x95,0x85,0x86,0x86,0x97,0x84,0x85,0xB6,0x84,0xA5,0x95,0xA4,0x95,0x95,0x95,0x68,0x95,0x66,0xA6,0x95,
  0x95,0x95,0x86,0x93,0xB5,0x86,0x77,0x94,0x96,0x95,0x96,0x85,0x68,0x94,0x87,0x95,0x86,0x86,0x93,0xB4,
  0xA3,0xB3,0xA6,0x86,0x85,0x85,0x96,0x76,0x86,0x64,0x69,0x78,0x68,0x78,0x78,0x77,0x67,0x79,0x68,0x79,
  0x59,0x56,0x87,0x98,0x68,0x78,0x76,0x88,0x68,0x68,0x67,0x76,0x87,0x68,0x78,0x76,0x78,0x77,0x78,0xA6,
  0x80,0xAF,0x81,0x38,0x47,0x67,0x77,0x78,0x77,0x89,0x07,0x79,0xB7,0x87,0x86,0x86,0x87,0x86,0x87,0x76,
  0x78,0x77,0x87,0x66,0x96,0x86,0x86,0x74,0xA6,0x87,0x86,0x77,0x86,0x77,0x76,0x77,0x77,0x87,0x77,0x77,
  0x77,0x77,0x87,0x65,0x78,0x77,0x78,0x75,0x88,0x85,0x76,0x87,0x95,0x77,0x86,0x87,0x86,0x96,0x85,0x76,
  0x69,0x67,0x59,0x77,0x6A,0x65,0x86,0x78,0x94,0x77,0x88,0x77,0x78,0x85,0x96,0x65,0x98,0x77,0x87,0x67,
  0x86,0x77,0x87,0x66,0x87,0x86,0x86,0x86,0x77,0x86,0x86,0x76,0x87,0x86,0x77,0x76,0x87,0x77,0x86,0x86,
  0x86,0x87,0x76,0x95,0x86,0x86,0x87,0x65,0x97,0x86,0x87,0x76,0x86,0x86,0x87,0x75,0x88,0x76,0x87,0x76,
  0x87,0x76,0x77,0x77,0x86,0x78,0x76,0x76,0x96,0x78,0x76,0x77,0x86,0x77,0x77,0x76,0x96,0x75,0x95,0x56,
  0x87,0x87,0x87,0x78,0x88,0x67,0x87,0x87,0x58,0x87,0x77,0x87,0x77,0x76,0x87,0x96,0x59,0x88,0x37,0x89,
  0x69,0x69,0x84,0x96,0x67,0x77,0x57,0x4B,0x58,0xB7,0x80,0x8E,0x0D,0x78,0x87,0x77,0x87,0x68,0x79,0x49,
  0x76,0x78,0x77,0x5A,0x67,0x69,0x68,0x68,0x68,0x4A,0x68,0x69,0x67,0x69,0x59,0x58,0x68,0x67,0x69,0x77,
  0x77,0x69,0x68,0x68,0x66,0x68,0x87,0x68,0x77,0x5A,0x68,0x67,0x68,0x68,0x67,0x78,0x78,0x67,0x6A,0x59,
  0x67,0x57,0x95,0x78,0x77,0x86,0x88,0x57,0x77,0x68,0x67,0x79,0x76,0x76,0x98,0x68,0x75,0x68,0x88,0x58,
  0x87,0x5A,0x57,0x79,0x67,0x59,0x78,0x49,0x58,0x77,0x79,0x49,0x68,0x59,0x77,0x68,0x78,0x48,0x79,0x67,
  0x68,0x59,0x68,0x68,0x59,0x75,0x6A,0x68,0x76,0x4C,0x67,0x77,0x78,0x59,0x69,0x56,0x96,0x68,0x68,0x68,
  0x77,0x69,0x67,0x68,0x67,0x78,0x69,0x68,0x58,0x59,0x68,0x68,0x69,0x49,0x77,0x59,0x67,0x69,0x67,0x68,
  0x65,0x48,0x77,0x87,0x86,0x96,0x88,0x75,0x87,0x96,0x87,0x95,0x87,0x77,0x68,0x86,0x77,0x77,0x96,0x68,
  0x86,0x77,0x85,0x5A,0x81,0xD5,0x95,0x68,0x99,0x74,0x98,0x77,0x09,0xF9,0x0A,0x5A,0x66,0x58,0x77,0x87,
  0x91,0x77,0x77,0xE9,0x77,0x77,0x77,0x76,0x87,0x75,0x97,0x77,0x77,0x77,0x78,0x68,0x68,0x68,0x67,0x3B,
  0x59,0x77,0x77,0x57,0x79,0x57,0x86,0x87,0x67,0x97,0x77,0x57,0x79,0x77,0x77,0x75,0x95,0x77,0x79,0x75,
  0x97,0x57,0x77,0x79,0x58,0x69,0x77,0x77,0x77,0x77,0x77,0x75,0x86,0x77,0x87,0x58,0x95,0x78,0x65,0x8A,
  0x39,0x58,0x87,0x96,0x87,0x77,0x77,0x77,0x86,0x87,0x76,0x78,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x68,0x77,0x68,0x77,0x67,0x86,0x77,0x78,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x68,
  0x77,0x68,0x77,0x67,0x78,0x77,0x77,0x68,0x68,0x76,0x87,0x68,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x68,0x68,0x68,0x76,0x38,0x97,0x67,0x79,0x77,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x78,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,
  0x72,0xC5,0x86,0x86,0x98,0x77,0x86,0x78,0x1C,0x85,0x2E,0x77,0x77,0x77,0x87,0x86,0x76,0x86,0x86,0xA0,
  0xBD,0x49,0x97,0x66,0x48,0x88,0x48,0x68,0x86,0x78,0x77,0x77,0x78,0x66,0xA6,0x87,0x83,0x85,0x88,0x78,
  0x66,0xA7,0x56,0x87,0x6A,0x46,0x89,0x76,0xA7,0x76,0x87,0x74,0xA2,0x86,0x77,0x79,0x66,0xB6,0x48,0x67,
  0x8A,0x36,0x88,0x77,0xA5,0xA5,0xB1,0xE9,0x39,0x78,0x78,0x75,0x87,0x77,0x77,0x77,0x68,0x58,0x79,0x69,
  0x4A,0x59,0x29,0x6A,0x3C,0x3B,0x46,0x78,0x75,0x89,0x76,0x89,0x4A,0x56,0x88,0x3B,0x66,0x88,0x68,0x87,
  0x57,0x97,0x38,0x87,0x56,0xB7,0x84,0x88,0x67,0x57,0x95,0xA8,0x59,0x77,0x68,0x4A,0x49,0x69,0x57,0x6A,
  0x59,0x58,0x67,0x87,0x5A,0x75,0x78,0x69,0x56,0x97,0x77,0x73,0x08,0x78,0x78,0x77,0x87,0x78,0x77,0x78,
  0x77,0x77,0x87,0x78,0x68,0x77,0x77,0x87,0x78,0x76,0x86,0x97,0x58,0x77,0x78,0x58,0x78,0x77,0x68,0x78,
  0x75,0x95,0xB7,0x70,0x8F,0x80,0xA6,0x87,0x65,0x66,0x78,0x7A,0x17,0x77,0x70,
};

static void SIT13_Func1(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT32 info, xadUINT16 bits, xadUINT16 num)
{
  xadUINT32 i, j;

  if(bits <= 12)
  {
    for(i = 0; i < (1<<12); i += (1<<bits))
    {
      buf[info+i].data = num;
      buf[info+i].bits = bits;
    }
  }
  else
  {
    j = bits-12;

    if(buf[info & 0xFFF].bits != 0x1F)
    {
      buf[info & 0xFFF].bits = 0x1F;
      buf[info & 0xFFF].data = s->MaxBits++;
    }
    bits = buf[info & 0xFFF].data;
    info >>= 12;

    while(j--)
    {
      xadUINT16 *a;

      a = info & 1 ? &s->Buffer4[bits].d2 : &s->Buffer4[bits].d1;
      if(!*a)
        *a = s->MaxBits++;
      bits = *a;
      info >>= 1;
    }
    s->Buffer4[bits].freq = num;
  }
}

static void SIT13_SortTree(struct SIT13Data *s, struct SIT13Buffer *buf, struct SIT13Buffer *buf2)
{
  xadUINT16 td;
  xadINT8 tb;

  struct SIT13Buffer *a, *b;

  while(buf2-1 > buf)
  {
    a = buf;
    b = buf2;

    for(;;)
    {
      while(++a < buf2)
      {
        tb = a->bits - buf->bits;
        if(tb > 0 || (!tb && (a->data >= buf->data)))
          break;
      }
      while(--b > buf)
      {
        tb = b->bits - buf->bits;
        if(tb < 0 || (!tb && (b->data <= buf->data)))
          break;
      }
      if(b < a)
        break;
      else
      {
        tb = a->bits;
        td = a->data;
        a->bits = b->bits;
        a->data = b->data;
        b->bits = tb;
        b->data = td;
      }
    }
    if(b == buf)
      ++buf;
    else
    {
      tb = buf->bits;
      td = buf->data;
      buf->bits = b->bits;
      buf->data = b->data;
      b->bits = tb;
      b->data = td;
      if(buf2-b-1 > b-buf)
      {
        SIT13_SortTree(s, buf, b);
        buf = b+1;
      }
      else
      {
        SIT13_SortTree(s, b+1, buf2);
        buf2 = b;
      }
    }
  }
}

static void SIT13_Func2(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT16 bits, struct SIT13Buffer *buf2)
{
  xadINT32 i, j, k, l, m, n;

  SIT13_SortTree(s, buf2, buf2 + bits);

  l = k = j = 0;
  for(i = 0; i < bits; ++i)
  {
    l += k;
    m = buf2[i].bits;
    if(m != j)
    {
      if((j = m) == -1)
        k = 0;
      else
        k = 1 << (32-j);
    }
    if(j > 0)
    {
      for(n = m = 0; n < 8*4; n += 4)
        m += SIT13Bits[(l>>n)&0xF]<<(7*4-n);
      SIT13_Func1(s, buf, m, j, buf2[i].data);
    }
  }
}

static void SIT13_CreateStaticTree(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT16 bits, xadUINT8 *bitsbuf)
{
  xadUINT32 i;

  for(i = 0; i < bits; ++i)
  {
    s->Buffer5[i].data = i;
    s->Buffer5[i].bits = bitsbuf[i];
  }
  SIT13_Func2(s, buf, bits, s->Buffer5);
}

static void SIT13InitInfo(struct SIT13Data *s, xadUINT8 id)
{
  xadINT32 i;
  xadUINT8 k, l = 0, *a, *b;

  a = s->TextBuf;
  b = (xadUINT8 *) SIT13Static+SIT13StaticPos[id-1];
  id &= 1;

  for(i = 658; i; --i)
  {
    k = id ? *b >> 4 : *(b++) & 0xF; id ^=1;

    if(!k)
    {
      l -= id ? *b >> 4 : *(b++) & 0xF; id ^= 1;
    }
    else
    {
      if(k == 15)
      {
        l += id ? *b >> 4 : *(b++) & 0xF; id ^= 1;
      }
      else
        l += k-7;
    }
    *(a++) = l;
  }
}

static void SIT13_Extract(struct SIT13Data *s, struct xadInOut *io)
{
  xadUINT32 wpos = 0, j, k, l, size;
  struct SIT13Buffer *buf = s->Buffer3;

  while(!io->xio_Error)
  {
    k = xadIOReadBitsLow(io, 12);
    if((j = buf[k].bits) <= 12)
    {
      l = buf[k].data;
      xadIODropBitsLow(io, j);
    }
    else
    {
      xadIODropBitsLow(io, 12);

      j = buf[k].data;
      while(s->Buffer4[j].freq == -1)
        j = xadIOGetBitsLow(io, 1) ? s->Buffer4[j].d2 : s->Buffer4[j].d1;
      l = s->Buffer4[j].freq;
    }
    if(l < 0x100)
    {
      s->Window[wpos++] = xadIOPutChar(io, l);
      wpos &= 0xFFFF;
      buf = s->Buffer3;
    }
    else
    {
      buf = s->Buffer3b;
      if(l < 0x13E)
        size = l - 0x100 + 3;
      else
      {
        if(l == 0x13E)
          size = xadIOGetBitsLow(io, 10);
        else
        {
          if(l == 0x140)
            return;
          size = xadIOGetBitsLow(io, 15);
        }
        size += 65;
      }
      j = xadIOReadBitsLow(io, 12);
      k = s->Buffer2[j].bits;
      if(k <= 12)
      {
        l = s->Buffer2[j].data;
        xadIODropBitsLow(io, k);
      }
      else
      {
        xadIODropBitsLow(io, 12);
        j = s->Buffer2[j].data;
        while(s->Buffer4[j].freq == -1)
          j = xadIOGetBitsLow(io, 1) ? s->Buffer4[j].d2 : s->Buffer4[j].d1;
        l = s->Buffer4[j].freq;
      }
      k = 0;
      if(l--)
        k = (1 << l) | xadIOGetBitsLow(io, l);
      l = wpos+0x10000-(k+1);
      while(size--)
      {
        l &= 0xFFFF;
        s->Window[wpos++] = xadIOPutChar(io, s->Window[l++]);
        wpos &= 0xFFFF;
      }
    } /* l >= 0x100 */
  }
}

static void SIT13_CreateTree(struct SIT13Data *s, struct xadInOut *io, struct SIT13Buffer *buf, xadUINT16 num)
{
  struct SIT13Buffer *b;
  xadUINT32 i;
  xadUINT16 data;
  xadINT8 bi = 0;

  for(i = 0; i < num; ++i)
  {
    b = &s->Buffer1[xadIOReadBitsLow(io, 12)];
    data = b->data;
    xadIODropBitsLow(io, b->bits);

    switch(data-0x1F)
    {
    case 0: bi = -1; break;
    case 1: ++bi; break;
    case 2: --bi; break;
    case 3:
      if(xadIOGetBitsLow(io, 1))
        s->Buffer5[i++].bits = bi;
      break;
    case 4:
      data = xadIOGetBitsLow(io, 3)+2;
      while(data--)
        s->Buffer5[i++].bits = bi;
      break;
    case 5:
      data = xadIOGetBitsLow(io, 6)+10;
      while(data--)
        s->Buffer5[i++].bits = bi;
      break;
    default: bi = data+1; break;
    }
    s->Buffer5[i].bits = bi;
  }
  for(i = 0; i < num; ++i)
    s->Buffer5[i].data = i;
  SIT13_Func2(s, buf, num, s->Buffer5);
}

static xadINT32 SIT_13(struct xadInOut *io)
{
  xadUINT32 i, j;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SIT13Data *s;

  if((s = xadAllocVec(XADM sizeof(struct SIT13Data), XADMEMF_CLEAR)))
  {
    s->MaxBits = 1;
    for(i = 0; i < 37; ++i)
      SIT13_Func1(s, s->Buffer1, SIT13Info[i], SIT13InfoBits[i], i);
    for(i = 1; i < 0x704; ++i)
    {
      /* s->Buffer4[i].d1 = s->Buffer4[i].d2 = 0; */
      s->Buffer4[i].freq = -1;
    }

    j = xadIOGetChar(io);
    i = j>>4;
    if(i > 5)
      io->xio_Error = XADERR_ILLEGALDATA;
    else if(i)
    {
      SIT13InitInfo(s, i--);
      SIT13_CreateStaticTree(s, s->Buffer3, 0x141, s->TextBuf);
      SIT13_CreateStaticTree(s, s->Buffer3b, 0x141, s->TextBuf+0x141);
      SIT13_CreateStaticTree(s, s->Buffer2, SIT13StaticBits[i], s->TextBuf+0x282);
    }
    else
    {
      SIT13_CreateTree(s, io, s->Buffer3, 0x141);
      if(j&8)
        xadCopyMem(XADM (xadPTR) s->Buffer3, (xadPTR) s->Buffer3b, 0x1000*sizeof(struct SIT13Buffer));
      else
        SIT13_CreateTree(s, io, s->Buffer3b, 0x141);
      j = (j&7)+10;
      SIT13_CreateTree(s, io, s->Buffer2, j);
    }
    if(!io->xio_Error)
      SIT13_Extract(s, io);
    xadFreeObjectA(XADM s, 0);
  }
  return io->xio_Error;
}

/*****************************************************************************/

struct SIT14Data {
  struct xadInOut *io;
  xadUINT8 code[308];
  xadUINT8 codecopy[308];
  xadUINT16 freq[308];
  xadUINT32 buff[308];

  xadUINT8 var1[52];
  xadUINT16 var2[52];
  xadUINT16 var3[75*2];

  xadUINT8 var4[76];
  xadUINT32 var5[75];
  xadUINT8 var6[1024];
  xadUINT16 var7[308*2];
  xadUINT8 var8[0x4000];

  xadUINT8 Window[0x40000];
};

static void SIT14_Update(xadUINT16 first, xadUINT16 last, xadUINT8 *code, xadUINT16 *freq)
{
  xadUINT16 i, j;

  while(last-first > 1)
  {
    i = first;
    j = last;

    do
    {
      while(++i < last && code[first] > code[i])
        ;
      while(--j > first && code[first] < code[j])
        ;
      if(j > i)
      {
        xadUINT16 t;
        t = code[i]; code[i] = code[j]; code[j] = t;
        t = freq[i]; freq[i] = freq[j]; freq[j] = t;
      }
    } while(j > i);

    if(first != j)
    {
      {
        xadUINT16 t;
        t = code[first]; code[first] = code[j]; code[j] = t;
        t = freq[first]; freq[first] = freq[j]; freq[j] = t;
      }

      i = j+1;
      if(last-i <= j-first)
      {
        SIT14_Update(i, last, code, freq);
        last = j;
      }
      else
      {
        SIT14_Update(first, j, code, freq);
        first = i;
      }
    }
    else
      ++first;
  }
}

static void SIT14_ReadTree(struct SIT14Data *dat, xadUINT16 codesize, xadUINT16 *result)
{
  xadUINT32 size, i, j, k, l, m, n, o;

  k = xadIOGetBitsLow(dat->io, 1);
  j = xadIOGetBitsLow(dat->io, 2)+2;
  o = xadIOGetBitsLow(dat->io, 3)+1;
  size = 1<<j;
  m = size-1;
  k = k ? m-1 : -1;
  if(xadIOGetBitsLow(dat->io, 2)&1) /* skip 1 bit! */
  {
    /* requirements for this call: dat->buff[32], dat->code[32], dat->freq[32*2] */
    SIT14_ReadTree(dat, size, dat->freq);
    for(i = 0; i < codesize; )
    {
      l = 0;
      do
      {
        l = dat->freq[l + xadIOGetBitsLow(dat->io, 1)];
        n = size<<1;
      } while(n > l);
      l -= n;
      if(k != l)
      {
        if(l == m)
        {
          l = 0;
          do
          {
            l = dat->freq[l + xadIOGetBitsLow(dat->io, 1)];
            n = size<<1;
          } while(n > l);
          l += 3-n;
          while(l--)
          {
            dat->code[i] = dat->code[i-1];
            ++i;
          }
        }
        else
          dat->code[i++] = l+o;
      }
      else
        dat->code[i++] = 0;
    }
  }
  else
  {
    for(i = 0; i < codesize; )
    {
      l = xadIOGetBitsLow(dat->io, j);
      if(k != l)
      {
        if(l == m)
        {
          l = xadIOGetBitsLow(dat->io, j)+3;
          while(l--)
          {
            dat->code[i] = dat->code[i-1];
            ++i;
          }
        }
        else
          dat->code[i++] = l+o;
      }
      else
        dat->code[i++] = 0;
    }
  }

  for(i = 0; i < codesize; ++i)
  {
    dat->codecopy[i] = dat->code[i];
    dat->freq[i] = i;
  }
  SIT14_Update(0, codesize, dat->codecopy, dat->freq);

  for(i = 0; i < codesize && !dat->codecopy[i]; ++i)
    ; /* find first nonempty */
  for(j = 0; i < codesize; ++i, ++j)
  {
    if(i)
      j <<= (dat->codecopy[i] - dat->codecopy[i-1]);

    k = dat->codecopy[i]; m = 0;
    for(l = j; k--; l >>= 1)
      m = (m << 1) | (l&1);

    dat->buff[dat->freq[i]] = m;
  }

  for(i = 0; i < codesize*2; ++i)
    result[i] = 0;

  j = 2;
  for(i = 0; i < codesize; ++i)
  {
    l = 0;
    m = dat->buff[i];

    for(k = 0; k < dat->code[i]; ++k)
    {
      l += (m&1);
      if(dat->code[i]-1 <= k)
        result[l] = codesize*2+i;
      else
      {
        if(!result[l])
        {
          result[l] = j; j += 2;
        }
        l = result[l];
      }
      m >>= 1;
    }
  }
  xadIOByteBoundary(dat->io);
}

static xadINT32 SIT_14(struct xadInOut *io)
{
  xadUINT32 i, j, k, l, m, n;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SIT14Data *dat;

  if((dat = (struct SIT14Data *) xadAllocVec(XADM sizeof(struct SIT14Data), XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    dat->io = io;

    /* initialization */
    for(i = k = 0; i < 52; ++i)
    {
      dat->var2[i] = k;
      k += (1<<(dat->var1[i] = ((i >= 4) ? ((i-4)>>2) : 0)));
    }
    for(i = 0; i < 4; ++i)
      dat->var8[i] = i;
    for(m = 1, l = 4; i < 0x4000; m <<= 1) /* i is 4 */
    {
      for(n = l+4; l < n; ++l)
      {
        for(j = 0; j < m; ++j)
          dat->var8[i++] = l;
      }
    }
    for(i = 0, k = 1; i < 75; ++i)
    {
      dat->var5[i] = k;
      k += (1<<(dat->var4[i] = (i >= 3 ? ((i-3)>>2) : 0)));
    }
    for(i = 0; i < 4; ++i)
      dat->var6[i] = i-1;
    for(m = 1, l = 3; i < 0x400; m <<= 1) /* i is 4 */
    {
      for(n = l+4; l < n; ++l)
      {
        for(j = 0; j < m; ++j)
          dat->var6[i++] = l;
      }
    }

    m = xadIOGetBitsLow(io, 16); /* number of blocks */
    j = 0; /* window position */
    while(m-- && !(io->xio_Flags & (XADIOF_ERROR|XADIOF_LASTOUTBYTE)))
    {
      /* these functions do not support access > 24 bit */
      xadIOGetBitsLow(io, 16); /* skip crunched block size */
      xadIOGetBitsLow(io, 16);
      n = xadIOGetBitsLow(io, 16); /* number of uncrunched bytes */
      n |= xadIOGetBitsLow(io, 16)<<16;
      SIT14_ReadTree(dat, 308, dat->var7);
      SIT14_ReadTree(dat, 75, dat->var3);

      while(n && !(io->xio_Flags & (XADIOF_ERROR|XADIOF_LASTOUTBYTE)))
      {
        for(i = 0; i < 616;)
          i = dat->var7[i + xadIOGetBitsLow(io, 1)];
        i -= 616;
        if(i < 0x100)
        {
          dat->Window[j++] = xadIOPutChar(io, i);
          j &= 0x3FFFF;
          --n;
        }
        else
        {
          i -= 0x100;
          k = dat->var2[i]+4;
          i = dat->var1[i];
          if(i)
            k += xadIOGetBitsLow(io, i);
          for(i = 0; i < 150;)
            i = dat->var3[i + xadIOGetBitsLow(io, 1)];
          i -= 150;
          l = dat->var5[i];
          i = dat->var4[i];
          if(i)
            l += xadIOGetBitsLow(io, i);
          n -= k;
          l = j+0x40000-l;
          while(k--)
          {
            l &= 0x3FFFF;
            dat->Window[j++] = xadIOPutChar(io, dat->Window[l++]);
            j &= 0x3FFFF;
          }
        }
      }
      xadIOByteBoundary(io);
    }
    xadFreeObjectA(XADM dat, 0);
  }
  return io->xio_Error;
}

/*****************************************************************************/

static const xadUINT16 SIT_rndtable[] = {
 0xee,  0x56,  0xf8,  0xc3,  0x9d,  0x9f,  0xae,  0x2c,
 0xad,  0xcd,  0x24,  0x9d,  0xa6, 0x101,  0x18,  0xb9,
 0xa1,  0x82,  0x75,  0xe9,  0x9f,  0x55,  0x66,  0x6a,
 0x86,  0x71,  0xdc,  0x84,  0x56,  0x96,  0x56,  0xa1,
 0x84,  0x78,  0xb7,  0x32,  0x6a,   0x3,  0xe3,   0x2,
 0x11, 0x101,   0x8,  0x44,  0x83, 0x100,  0x43,  0xe3,
 0x1c,  0xf0,  0x86,  0x6a,  0x6b,   0xf,   0x3,  0x2d,
 0x86,  0x17,  0x7b,  0x10,  0xf6,  0x80,  0x78,  0x7a,
 0xa1,  0xe1,  0xef,  0x8c,  0xf6,  0x87,  0x4b,  0xa7,
 0xe2,  0x77,  0xfa,  0xb8,  0x81,  0xee,  0x77,  0xc0,
 0x9d,  0x29,  0x20,  0x27,  0x71,  0x12,  0xe0,  0x6b,
 0xd1,  0x7c,   0xa,  0x89,  0x7d,  0x87,  0xc4, 0x101,
 0xc1,  0x31,  0xaf,  0x38,   0x3,  0x68,  0x1b,  0x76,
 0x79,  0x3f,  0xdb,  0xc7,  0x1b,  0x36,  0x7b,  0xe2,
 0x63,  0x81,  0xee,   0xc,  0x63,  0x8b,  0x78,  0x38,
 0x97,  0x9b,  0xd7,  0x8f,  0xdd,  0xf2,  0xa3,  0x77,
 0x8c,  0xc3,  0x39,  0x20,  0xb3,  0x12,  0x11,   0xe,
 0x17,  0x42,  0x80,  0x2c,  0xc4,  0x92,  0x59,  0xc8,
 0xdb,  0x40,  0x76,  0x64,  0xb4,  0x55,  0x1a,  0x9e,
 0xfe,  0x5f,   0x6,  0x3c,  0x41,  0xef,  0xd4,  0xaa,
 0x98,  0x29,  0xcd,  0x1f,   0x2,  0xa8,  0x87,  0xd2,
 0xa0,  0x93,  0x98,  0xef,   0xc,  0x43,  0xed,  0x9d,
 0xc2,  0xeb,  0x81,  0xe9,  0x64,  0x23,  0x68,  0x1e,
 0x25,  0x57,  0xde,  0x9a,  0xcf,  0x7f,  0xe5,  0xba,
 0x41,  0xea,  0xea,  0x36,  0x1a,  0x28,  0x79,  0x20,
 0x5e,  0x18,  0x4e,  0x7c,  0x8e,  0x58,  0x7a,  0xef,
 0x91,   0x2,  0x93,  0xbb,  0x56,  0xa1,  0x49,  0x1b,
 0x79,  0x92,  0xf3,  0x58,  0x4f,  0x52,  0x9c,   0x2,
 0x77,  0xaf,  0x2a,  0x8f,  0x49,  0xd0,  0x99,  0x4d,
 0x98, 0x101,  0x60,  0x93, 0x100,  0x75,  0x31,  0xce,
 0x49,  0x20,  0x56,  0x57,  0xe2,  0xf5,  0x26,  0x2b,
 0x8a,  0xbf,  0xde,  0xd0,  0x83,  0x34,  0xf4,  0x17
};

struct SIT_modelsym
{
  xadUINT16 sym;
  xadUINT32 cumfreq;
};

struct SIT_model
{
  xadINT32                increment;
  xadINT32                maxfreq;
  xadINT32                entries;
  xadUINT32               tabloc[256];
  struct SIT_modelsym *syms;
};

struct SIT_ArsenicData
{
  struct xadInOut *io;

  xadUINT16  csumaccum;
  xadUINT8 *window;
  xadUINT8 *windowpos;
  xadUINT8 *windowe;
  xadINT32   windowsize;
  xadINT32   tsize;
  xadUINT32  One;
  xadUINT32  Half;
  xadUINT32  Range;
  xadUINT32  Code;
  xadINT32   lastarithbits; /* init 0 */

  /* SIT_dounmntf function private */
  xadINT32   inited;        /* init 0 */
  xadUINT8  moveme[256];

  /* the private SIT_Arsenic function stuff */
  struct SIT_model initial_model;
  struct SIT_model selmodel;
  struct SIT_model mtfmodel[7];
  struct SIT_modelsym initial_syms[2+1];
  struct SIT_modelsym sel_syms[11+1];
  struct SIT_modelsym mtf0_syms[2+1];
  struct SIT_modelsym mtf1_syms[4+1];
  struct SIT_modelsym mtf2_syms[8+1];
  struct SIT_modelsym mtf3_syms[0x10+1];
  struct SIT_modelsym mtf4_syms[0x20+1];
  struct SIT_modelsym mtf5_syms[0x40+1];
  struct SIT_modelsym mtf6_syms[0x80+1];

  /* private for SIT_unblocksort */
  xadUINT32 counts[256];
  xadUINT32 cumcounts[256];
};

static void SIT_update_model(struct SIT_model *mymod, xadINT32 symindex)
{
  xadINT32 i;

  for (i = 0; i < symindex; i++)
    mymod->syms[i].cumfreq += mymod->increment;
  if(mymod->syms[0].cumfreq > mymod->maxfreq)
  {
    for(i = 0; i < mymod->entries ; i++)
    {
      /* no -1, want to include the 0 entry */
      /* this converts cumfreqs LONGo frequencies, then shifts right */
      mymod->syms[i].cumfreq -= mymod->syms[i+1].cumfreq;
      mymod->syms[i].cumfreq++; /* avoid losing things entirely */
      mymod->syms[i].cumfreq >>= 1;
    }
    /* then convert frequencies back to cumfreq */
    for(i = mymod->entries - 1; i >= 0; i--)
      mymod->syms[i].cumfreq += mymod->syms[i+1].cumfreq;
  }
}

static void SIT_getcode(struct SIT_ArsenicData *sa,
xadUINT32 symhigh, xadUINT32 symlow, xadUINT32 symtot) /* aka remove symbol */
{
  xadUINT32 lowincr;
  xadUINT32 renorm_factor;

  renorm_factor = sa->Range/symtot;
  lowincr = renorm_factor * symlow;
  sa->Code -= lowincr;
  if(symhigh == symtot)
    sa->Range -= lowincr;
  else
    sa->Range = (symhigh - symlow) * renorm_factor;

  sa->lastarithbits = 0;
  while(sa->Range <= sa->Half)
  {
    sa->Range <<= 1;
    sa->Code = (sa->Code << 1) | xadIOGetBitsHigh(sa->io, 1);
    sa->lastarithbits++;
  }
}

static xadINT32 SIT_getsym(struct SIT_ArsenicData *sa, struct SIT_model *model)
{
  xadINT32 freq;
  xadINT32 i;
  xadINT32 sym;

  /* getfreq */
  freq = sa->Code/(sa->Range/model->syms[0].cumfreq);
  for(i = 1; i < model->entries; i++)
  {
    if(model->syms[i].cumfreq <= freq)
      break;
  }
  sym = model->syms[i-1].sym;
  SIT_getcode(sa, model->syms[i-1].cumfreq, model->syms[i].cumfreq, model->syms[0].cumfreq);
  SIT_update_model(model, i);
  return sym;
}

static void SIT_reinit_model(struct SIT_model *mymod)
{
  xadINT32 cumfreq = mymod->entries * mymod->increment;
  xadINT32 i;

  for(i = 0; i <= mymod->entries; i++)
  {
    /* <= sets last frequency to 0; there isn't really a symbol for that
       last one  */
    mymod->syms[i].cumfreq = cumfreq;
    cumfreq -= mymod->increment;
  }
}

static void SIT_init_model(struct SIT_model *newmod, struct SIT_modelsym *sym,
xadINT32 entries, xadINT32 start, xadINT32 increment, xadINT32 maxfreq)
{
  xadINT32 i;

  newmod->syms = sym;
  newmod->increment = increment;
  newmod->maxfreq = maxfreq;
  newmod->entries = entries;
  /* memset(newmod->tabloc, 0, sizeof(newmod->tabloc)); */
  for(i = 0; i < entries; i++)
  {
    newmod->tabloc[(entries - i - 1) + start] = i;
    newmod->syms[i].sym = (entries - i - 1) + start;
  }
  SIT_reinit_model(newmod);
}

static xadUINT32 SIT_arith_getbits(struct SIT_ArsenicData *sa, struct SIT_model *model, xadINT32 nbits)
{
  /* the model is assumed to be a binary one */
  xadUINT32 addme = 1;
  xadUINT32 accum = 0;
  while(nbits--)
  {
    if(SIT_getsym(sa, model))
      accum += addme;
    addme += addme;
  }
  return accum;
}

static xadINT32 SIT_dounmtf(struct SIT_ArsenicData *sa, xadINT32 sym)
{
  xadINT32 i;
  xadINT32 result;

  if(sym == -1 || !sa->inited)
  {
    for(i = 0; i < 256; i++)
      sa->moveme[i] = i;
    sa->inited = 1;
  }
  if(sym == -1)
    return 0;
  result = sa->moveme[sym];
  for(i = sym; i > 0 ; i-- )
    sa->moveme[i] = sa->moveme[i-1];

  sa->moveme[0] = result;
  return result;
}

static xadINT32 SIT_unblocksort(struct SIT_ArsenicData *sa, xadUINT8 *block,
xadUINT32 blocklen, xadUINT32 last_index, xadUINT8 *outblock)
{
  xadUINT32 i, j;
  xadUINT32 *xform;
  xadUINT8 *blockptr;
  xadUINT32 cum;
  struct xadMasterBase *xadMasterBase = sa->io->xio_xadMasterBase;

  memset(sa->counts, 0, sizeof(sa->counts));
  if((xform = xadAllocVec(XADM sizeof(xadUINT32)*blocklen, XADMEMF_ANY)))
  {
    blockptr = block;
    for(i = 0; i < blocklen; i++)
      sa->counts[*blockptr++]++;

    cum = 0;
    for(i = 0; i < 256; i++)
    {
      sa->cumcounts[i] = cum;
      cum += sa->counts[i];
      sa->counts[i] = 0;
    }

    blockptr = block;
    for(i = 0; i < blocklen; i++)
    {
      xform[sa->cumcounts[*blockptr] + sa->counts[*blockptr]] = i;
      sa->counts[*blockptr++]++;
    }

    blockptr = outblock;
    for(i = 0, j = xform[last_index]; i < blocklen; i++, j = xform[j])
    {
      *blockptr++ = block[j];
//      block[j] = 0xa5; /* for debugging */
    }
    xadFreeObjectA(XADM xform, 0);
  }
  else
    return XADERR_NOMEMORY;
  return 0;
}

static void SIT_write_and_unrle_and_unrnd(struct xadInOut *io, xadUINT8 *block, xadUINT32 blocklen, xadINT16 rnd)
{
  xadINT32 count = 0;
  xadINT32 last = 0;
  xadUINT8 *blockptr = block;
  xadUINT32 i;
  xadUINT32 j;
  xadINT32 ch;
  xadINT32 rndindex;
  xadINT32 rndcount;

  rndindex = 0;
  rndcount = SIT_rndtable[rndindex];
  for(i = 0; i < blocklen; i++)
  {
    ch = *blockptr++;
    if(rnd && (rndcount == 0))
    {
      ch ^= 1;
      rndindex++;
      if (rndindex == sizeof(SIT_rndtable)/sizeof(SIT_rndtable[0]))
        rndindex = 0;
      rndcount = SIT_rndtable[rndindex];
    }
    rndcount--;

    if(count == 4)
    {
      for(j = 0; j < ch; j++)
        xadIOPutChar(io, last);
      count = 0;
    }
    else
    {
      xadIOPutChar(io, ch);
      if(ch != last)
      {
        count = 0;
        last = ch;
      }
      count++;
    }
  }
}

static xadINT32 SIT_Arsenic(struct xadInOut *io)
{
  xadINT32 err = 0;
  struct SIT_ArsenicData *sa;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  io->xio_Flags &= ~(XADIOF_NOCRC32);
  io->xio_Flags |= XADIOF_NOCRC16;
  io->xio_CRC32 = ~0;

  if((sa = (struct SIT_ArsenicData *) xadAllocVec(XADM sizeof(struct SIT_ArsenicData), XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    xadINT32 i, sym, sel;
    xadINT16 blockbits;
    xadUINT32 w, blocksize;
    xadINT32 stopme, nchars; /* 32 bits */
    xadINT32 repeatstate, repeatcount;
    xadINT32 primary_index; /* 32 bits */
    xadINT32 eob, rnd;
    xadUINT8 *block, *blockptr, *unsortedblock;

    sa->io = io;
    sa->Range = sa->One = 1<<25;
    sa->Half = 1<<24;
    sa->Code = xadIOGetBitsHigh(io, 26);

    SIT_init_model(&sa->initial_model, sa->initial_syms, 2, 0, 1, 256);
    SIT_init_model(&sa->selmodel, sa->sel_syms, 11, 0, 8, 1024);
    /* selector model: 11 selections, starting at 0, 8 increment, 1024 maxfreq */

    SIT_init_model(&sa->mtfmodel[0], sa->mtf0_syms, 2, 2, 8, 1024);
    /* model 3: 2 symbols, starting at 2, 8 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[1], sa->mtf1_syms, 4, 4, 4, 1024);
    /* model 4: 4 symbols, starting at 4, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[2], sa->mtf2_syms, 8, 8, 4, 1024);
    /* model 5: 8 symbols, starting at 8, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[3], sa->mtf3_syms, 0x10, 0x10, 4, 1024);
    /* model 6: $10 symbols, starting at $10, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[4], sa->mtf4_syms, 0x20, 0x20, 2, 1024);
    /* model 7: $20 symbols, starting at $20, 2 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[5], sa->mtf5_syms, 0x40, 0x40, 2, 1024);
    /* model 8: $40 symbols, starting at $40, 2 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[6], sa->mtf6_syms, 0x80, 0x80, 1, 1024);
    /* model 9: $80 symbols, starting at $80, 1 increment, 1024 maxfreq */
    if(SIT_arith_getbits(sa, &sa->initial_model, 8) != 0x41 ||
    SIT_arith_getbits(sa, &sa->initial_model, 8) != 0x73)
      err = XADERR_ILLEGALDATA;
    w = SIT_arith_getbits(sa, &sa->initial_model, 4);
    blockbits = w + 9;
    blocksize = 1<<blockbits;
    if(!err)
    {
      if((block = xadAllocVec(XADM blocksize, XADMEMF_ANY)))
      {
        if((unsortedblock = xadAllocVec(XADM blocksize, XADMEMF_ANY)))
        {
          eob = SIT_getsym(sa, &sa->initial_model);
          while(!eob && !err)
          {
            rnd = SIT_getsym(sa, &sa->initial_model);
            primary_index = SIT_arith_getbits(sa, &sa->initial_model, blockbits);
            nchars = stopme = repeatstate = repeatcount = 0;
            blockptr = block;
            while(!stopme)
            {
              sel = SIT_getsym(sa, &sa->selmodel);
              switch(sel)
              {
              case 0:
                sym = -1;
                if(!repeatstate)
                  repeatstate = repeatcount = 1;
                else
                {
                  repeatstate += repeatstate;
                  repeatcount += repeatstate;
                }
                break;
              case 1:
                if(!repeatstate)
                {
                  repeatstate = 1;
                  repeatcount = 2;
                }
                else
                {
                  repeatstate += repeatstate;
                  repeatcount += repeatstate;
                  repeatcount += repeatstate;
                }
                sym = -1;
                break;
              case 2:
                sym = 1;
                break;
              case 10:
                stopme = 1;
                sym = 0;
                break;
              default:
                if((sel > 9) || (sel < 3))
                { /* this basically can't happen */
                  err = XADERR_ILLEGALDATA;
                  stopme = 1;
                  sym = 0;
                }
                else
                  sym = SIT_getsym(sa, &sa->mtfmodel[sel-3]);
                break;
              }
              if(repeatstate && (sym >= 0))
              {
                nchars += repeatcount;
                repeatstate = 0;
                memset(blockptr, SIT_dounmtf(sa, 0), repeatcount);
                blockptr += repeatcount;
                repeatcount = 0;
              }
              if(!stopme && !repeatstate)
              {
                sym = SIT_dounmtf(sa, sym);
                *blockptr++ = sym;
                nchars++;
              }
              if(nchars > blocksize)
              {
                err = XADERR_ILLEGALDATA;
                stopme = 1;
              }
            }
            if(err)
              break;
            if((err = SIT_unblocksort(sa, block, nchars, primary_index, unsortedblock)))
              break;
            SIT_write_and_unrle_and_unrnd(io, unsortedblock, nchars, rnd);
            eob = SIT_getsym(sa, &sa->initial_model);
            SIT_reinit_model(&sa->selmodel);
            for(i = 0; i < 7; i ++)
              SIT_reinit_model(&sa->mtfmodel[i]);
            SIT_dounmtf(sa, -1);
          }
          if(!err)
          {
            err = xadIOWriteBuf(io);
            if(!err && SIT_arith_getbits(sa, &sa->initial_model, 32) != ~io->xio_CRC32)
              err = XADERR_CHECKSUM;
          }
          xadFreeObjectA(XADM unsortedblock, 0);
        }
        else
          err = XADERR_NOMEMORY;
        xadFreeObjectA(XADM block, 0);
      }
      else
        err = XADERR_NOMEMORY;
    } /* if(!err) */
    xadFreeObjectA(XADM sa, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

XADUNARCHIVE(SIT)
{
  struct xadFileInfo *fi;
  struct xadInOut *io;
  xadINT32 err;

  fi = ai->xai_CurFile;

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;

    switch(SITPI(fi)->Method)
    {
    case SITnocomp:
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        xadIOPutChar(io, xadIOGetChar(io));
      err = io->xio_Error;
      break;
    case SITrle: err = SIT_rle(io); break;
    case SITlzc: err = xadIO_Compress(io, 14|UCOMPBLOCK_MASK); break;
    case SIThuffman: err = SIT_huffman(io); break;
    case SITlzah: err = SIT_lzah(io); break;
    case SITmw: err = SIT_mw(io); break;
    case 13: io->xio_Flags |= XADIOF_NOINENDERR; err = SIT_13(io); break;
    case 14: err = SIT_14(io); break;
    case 15: err = SIT_Arsenic(io); break;
    default:
#ifdef DEBUG
      {
        xadUINT8 data[4];
        data[0] = 'S'; data[1] = 'I'; data[2] = 'T'; data[3] = SITPI(fi)->Method;
         xadHookAccess(XADM XADAC_WRITE, 4, data, ai);
         xadHookAccess(XADM XADAC_WRITE, 4, &fi->xfi_Size, ai);
         xadHookAccess(XADM XADAC_WRITE, 4, &fi->xfi_CrunchSize, ai);
         xadHookAccess(XADM XADAC_WRITE, 2, &(SITPI(fi)->CRC), ai);
         xadHookAccess(XADM XADAC_COPY, fi->xfi_CrunchSize, 0, ai);
      }
#endif
      err = XADERR_DATAFORMAT;
    }
    if(SITPI(fi)->Method != 15)
    {
      if(!err)
        err = xadIOWriteBuf(io);
      if(!err && io->xio_CRC16 != SITPI(fi)->CRC)
        err = XADERR_CHECKSUM;
    }
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

XADRECOGDATA(SIT5)
{
  {
    xadSTRPTR a = "StuffIt (c)1997-\xFF\xFF\xFF\xFF Aladdin Systems, Inc., http://www.aladdinsys.com/StuffIt/\x0d\x0a";

    while(*a && (*a == *data || (xadUINT8) *a == 0xFF))
    {
      ++a; ++data;
    }
    if(!*a)
      return 1;
  }
  return 0;
}

/*****************************************************************************/

#define SIT5_ID 0xA5A5A5A5

/* header format 20 byte
  xadUINT8[80] header text
  xadUINT32     ???
  xadUINT32     total archive size
  xadUINT32     offset of first entry
  xadUINT32     ???
  xadUINT32     ???
*/

#define SIT5AH_ARCSIZE          84
#define SIT5AH_FIRSTENTRY       88

/* archive block entry                          directory:
 0  xadUINT32     id = SIT5_ID                      <--
 4  xadUINT8     version                           <--
 5  xadUINT8     ???
 6  xadUINT16     header size                       <--
 8  xadUINT8     ??? (system ID?)
 9  xadUINT8     type                              <--
10  xadUINT32     creation date                     <--
14  xadUINT32     modification date                 <--
18  xadUINT32     offset of previous entry          <--
22  xadUINT32     offset of next entry              <--
26  xadUINT32     offset of directory entry         <--
30  xadUINT16     filename size                     <--
32  xadUINT16     header crc                        <--
34  xadUINT32     data file size                    offset of first entry
38  xadUINT32     data crunched size                size of complete directory
42  xadUINT16     data old crc16 (not with algo 15)
44  xadUINT16     ???
46  xadUINT8     data algorithm
                none    ==  0
                fastest == 13
                max     == 15
47  xadUINT8     password data len                 number of files
48  xadUINT8[..] password information
48+pwdlen            xadUINT8[..] filename         <--
48+pwdlen+namelen    xadUINT16     commentsize
48+pwdlen+namelen+2  xadUINT16     ????
48+pwdlen+namelen+4  xadUINT8[..] comment

  second block:
 0  xadUINT16     ??? (resource exists?)
 2  xadUINT16     ???
 4  xadUINT32     file type
 8  xadUINT32     file creator
12  xadUINT16     finder flags
14  xadUINT16     ???
16  xadUINT32     ??? (macintosh date variable - version 3)
20  xadUINT32     ???
24  xadUINT32     ???
28  xadUINT32     ???

32  xadUINT32     ??? (version 3 misses this one and following?)

36  xadUINT32     rsrc file size
40  xadUINT32     rsrc crunched size
44  xadUINT16     rsrc old crc16 (not with algo 15)
46  xadUINT16     ???
48  xadUINT8     rsrc algorithm

  followed by resource fork data
  followed by data fork data

  ! The header crc is CRC16 of header size with crc field cleared !
*/

#define SIT5FH_ID                0
#define SIT5FH_VERSION           4
#define SIT5FH_HEADERSIZE        6
#define SIT5FH_FLAGS             9
#define SIT5FH_CREATIONDATE     10
#define SIT5FH_MODDATE          14
#define SIT5FH_PREVFILE         18
#define SIT5FH_NEXTFILE         22
#define SIT5FH_DIRECTORY        26
#define SIT5FH_FILENAMESIZE     30
#define SIT5FH_HEADERCRC        32
#define SIT5FH_DATASIZE         34
#define SIT5FH_DATACRUNCHSIZE   38
#define SIT5FH_DATACRC16        42
#define SIT5FH_DATAALGORITHM    46
#define SIT5FH_PASSWORDSIZE     47
#define SIT5FH_FILENAME         48

#define SIT5FH_FILETYPE          4
#define SIT5FH_FILECREATOR       8
#define SIT5FH_FINDERFLAGS      12
#define SIT5FH_RSRCSIZE         36
#define SIT5FH_RSRCCRUNCHSIZE   40
#define SIT5FH_RSRCCRC16        44
#define SIT5FH_RSRCALGORITHM    48

#define SIT5FLAGS_DIRECTORY     0x40
#define SIT5FLAGS_CRYPTED       0x20
#define SIT5FLAGS_RSRC_FORK     0x10

XADGETINFO(SIT5)
{
  xadINT32 err, i, j;
  xadUINT32 nsize, csize, csize2;
  xadSTRPTR buffer;
  struct xadFileInfo *fi, *ldir = 0, *lfi = 0;

  if((buffer = (xadSTRPTR) xadAllocVec(XADM 2048, XADMEMF_PUBLIC)))
  {
    if(!(err =  xadHookAccess(XADM XADAC_READ, 100, buffer, ai)))
    {
      i = EndGetM32(buffer + SIT5AH_FIRSTENTRY)-100;
      if(!i || !(err =  xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai)))
      {
        while(!err && ai->xai_InPos < ai->xai_InSize)
        {
          if(!(err =  xadHookAccess(XADM XADAC_READ, 48, buffer, ai)))
          {
            if((buffer[SIT5FH_FLAGS] & SIT5FLAGS_DIRECTORY) && EndGetM32(buffer+SIT5FH_DATASIZE) == 0xFFFFFFFF)
            {
              ldir = (struct xadFileInfo *) ldir->xfi_PrivateInfo;
            }
            else
            {
              i = EndGetM16(buffer+SIT5FH_HEADERSIZE);
              j = buffer[SIT5FH_VERSION] == 1 ? 36 : 32;
              if(EndGetM32(buffer+SIT5FH_ID) != SIT5_ID || i + j > 2048-14)
                err = XADERR_DATAFORMAT;
              else if(!(err =  xadHookAccess(XADM XADAC_READ, i+j-48, buffer+48, ai)))
              {
                if(!buffer[i+1] || !(err =  xadHookAccess(XADM XADAC_READ, 14, buffer+i+j, ai)))
                {
                  nsize = EndGetM16(buffer+SIT5FH_FILENAMESIZE);
                  if(buffer[SIT5FH_FLAGS] & SIT5FLAGS_DIRECTORY)
                  {
                    if(i > SIT5FH_FILENAME + nsize)
                      csize = EndGetM16(buffer + SIT5FH_FILENAME + nsize);
                    else
                      csize = 0;

                    if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, csize ?
                    XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize + 1, TAG_DONE)))
                    {
                      if((fi->xfi_FileName = MACname(xadMasterBase, ldir, buffer+SIT5FH_FILENAME, nsize, 0)))
                      {
                        if(csize)
                          xadCopyMem(XADM buffer+SIT5FH_FILENAME+nsize+4, fi->xfi_Comment, csize);

                        xadConvertDates(XADM XAD_DATEMAC, EndGetM32(buffer+SIT5FH_MODDATE), XAD_GETDATEXADDATE,
                        &fi->xfi_Date, TAG_DONE);

                        fi->xfi_Flags |= XADFIF_DIRECTORY|XADFIF_XADSTRFILENAME;
                        fi->xfi_PrivateInfo = (xadPTR) ldir;
                        ldir = fi;

                        err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
                      }
                      else
                      {
                        xadFreeObjectA(XADM fi, 0);
                        err = XADERR_NOMEMORY;
                      }
                    }
                    else
                      err = XADERR_NOMEMORY;
                  }
                  else
                  {
                    if(i > SIT5FH_FILENAME + buffer[SIT5FH_PASSWORDSIZE] + nsize)
                      csize = EndGetM16(buffer + SIT5FH_FILENAME + buffer[SIT5FH_PASSWORDSIZE] + nsize);
                    else
                      csize = 0;

                    csize2 = SITmakecomment(buffer+i+SIT5FH_FILETYPE, EndGetM16(buffer+i+SIT5FH_FINDERFLAGS),
                    buffer+SIT5FH_FILENAME+buffer[SIT5FH_PASSWORDSIZE]+nsize+4, csize, 0);
                    if(buffer[i+1]) /* rsrc tree */
                    {
                      if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                      sizeof(struct SITPrivate), csize2 && !EndGetM32(buffer+SIT5FH_DATASIZE) ?
                      XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize2, TAG_DONE)))
                      {
                        if((fi->xfi_FileName = MACname(xadMasterBase, ldir, buffer+SIT5FH_FILENAME+buffer[SIT5FH_PASSWORDSIZE], nsize, 1)))
                        {
                          /* if comment field is zero, nothing is done! */
                          SITmakecomment(buffer+i+SIT5FH_FILETYPE, EndGetM16(buffer+i+SIT5FH_FINDERFLAGS),
                          buffer+SIT5FH_FILENAME+buffer[SIT5FH_PASSWORDSIZE]+nsize+4, csize, fi->xfi_Comment);

                          xadConvertDates(XADM XAD_DATEMAC, EndGetM32(buffer+SIT5FH_MODDATE), XAD_GETDATEXADDATE,
                          &fi->xfi_Date, TAG_DONE);

                          if(buffer[SIT5FH_FLAGS] & SIT5FLAGS_CRYPTED)
                          {
                            fi->xfi_Flags |= XADFIF_CRYPTED;
                            ai->xai_Flags |= XADAIF_CRYPTED;
                          }

                          fi->xfi_CrunchSize = EndGetM32(buffer+i+SIT5FH_RSRCCRUNCHSIZE);
                          fi->xfi_Size = EndGetM32(buffer+i+SIT5FH_RSRCSIZE);

                          fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
                          fi->xfi_DataPos = ai->xai_InPos;
                          lfi = fi;

                          SITPI(fi)->CRC = EndGetM16(buffer+i+SIT5FH_RSRCCRC16);
                          SITPI(fi)->Method = buffer[i+SIT5FH_RSRCALGORITHM];
#ifdef DEBUG
  if(SITPI(fi)->Method != 0 && SITPI(fi)->Method != 13 && SITPI(fi)->Method != 15)
  {
    DebugFileSearched(ai, "Unknown or untested compression method %ld.",
    SITPI(fi)->Method);
  }
#endif
                          if(SITPI(fi)->Method <= STUFFITMAXALGO)
                            fi->xfi_EntryInfo = sittypes[SITPI(fi)->Method];

                          err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                        }
                        else
                        {
                          xadFreeObjectA(XADM fi, 0);
                          err = XADERR_NOMEMORY;
                        }
                      }
                      else
                        err = XADERR_NOMEMORY;
                    }

                    if(!err && (EndGetM32(buffer+SIT5FH_DATASIZE) || !buffer[i+1]))
                    {
                      if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                      sizeof(struct SITPrivate), csize2 ? XAD_OBJCOMMENTSIZE : TAG_IGNORE,
                      csize2, TAG_DONE)))
                      {
                        if((fi->xfi_FileName = MACname(xadMasterBase, ldir, buffer+SIT5FH_FILENAME+buffer[SIT5FH_PASSWORDSIZE], nsize, 0)))
                        {
                          SITmakecomment(buffer+i+SIT5FH_FILETYPE, EndGetM16(buffer+i+SIT5FH_FINDERFLAGS),
                          buffer+SIT5FH_FILENAME+buffer[SIT5FH_PASSWORDSIZE]+nsize+4, csize, fi->xfi_Comment);
                          if(buffer[i+1])
                          {
                            fi->xfi_MacFork = lfi;
                            lfi->xfi_MacFork = fi;
                          }

                          xadConvertDates(XADM XAD_DATEMAC, EndGetM32(buffer+SIT5FH_MODDATE), XAD_GETDATEXADDATE,
                          &fi->xfi_Date, TAG_DONE);

                          if(buffer[SIT5FH_FLAGS] & SIT5FLAGS_CRYPTED)
                          {
                            fi->xfi_Flags |= XADFIF_CRYPTED;
                            ai->xai_Flags |= XADAIF_CRYPTED;
                          }

                          fi->xfi_CrunchSize = EndGetM32(buffer+SIT5FH_DATACRUNCHSIZE);
                          fi->xfi_Size = EndGetM32(buffer+SIT5FH_DATASIZE);

                          fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
                          fi->xfi_DataPos = ai->xai_InPos;

                          SITPI(fi)->CRC = EndGetM16(buffer+SIT5FH_DATACRC16);
                          SITPI(fi)->Method = buffer[SIT5FH_DATAALGORITHM];
#ifdef DEBUG
  if(SITPI(fi)->Method != 0 && SITPI(fi)->Method != 13 && SITPI(fi)->Method != 15)
  {
    DebugFileSearched(ai, "Unknown or untested compression method %ld.",
    SITPI(fi)->Method);
  }
#endif
                          if(SITPI(fi)->Method <= STUFFITMAXALGO)
                            fi->xfi_EntryInfo = sittypes[SITPI(fi)->Method];

                          err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                        }
                        else
                        {
                          xadFreeObjectA(XADM fi, 0);
                          err = XADERR_NOMEMORY;
                        }
                      }
                      else
                        err = XADERR_NOMEMORY;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    xadFreeObjectA(XADM buffer,0);
  }
  else
    err = XADERR_NOMEMORY;

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

#ifdef DEBUG
  if(err || (ai->xai_Flags & XADAIF_CRYPTED))
  {
    DebugFileSearched(ai, "Encrypted data.",
    SITPI(fi)->Method);
  }
#endif

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

XADRECOGDATA(SIT5EXE)
{
  if(data[0] == 'M' && data[1] == 'Z' && EndGetM32(data+4100) == 0x4203e853)
    return 1;
  return 0;
}

/*****************************************************************************/

XADGETINFO(SIT5EXE)
{
  xadINT32 err;

  if(!(err =  xadHookAccess(XADM XADAC_INPUTSEEK, 0x1A000, 0, ai)))
    err = SIT5_GetInfo(ai, xadMasterBase);
  return err;
}

/*****************************************************************************/

XADRECOGDATA(MacBinary)
{
  if(data[0] <= 1 && data[1] >= 1 && data[1] <= 63 && !data[74] && !data[82])
  {
    if(xadCRC_1021(data, 124) == EndGetM16(data+124))
    {
      if(data[102] == 'm' && data[103] == 'B' && data[104] == 'I' &&
      data[105] == 'N')
        return 3; /* is MacBinaryIII */
      return 2; /* MacBinaryII */
    }
    else if(!data[0]) /* test for MacBinary type I */
    {
      if(EndGetM32(data+83) <= 0xFFFFFF && EndGetM32(data+87) <= 0xFFFFFF)
      {
        xadINT32 i;

        for(i = 65; i < 65+8; ++i) /* check finder flags */
        {
          if(data[i] < 0x20)
            return 0;
        }
        for(i = 0; i < data[1]; ++i) /* there can be no zero in name! */
        {
          if(!data[i+2])
            return 0;
        }
        return 1;
      }
    }
  }

  return 0;
}

/*****************************************************************************/

XADGETINFO(MacBinary)
{
  struct xadFileInfo *fi, *lfi, *ldir = 0;
  xadINT32 err = 0, type, rsize, dsize, csize, i;
  xadUINT8 header[128];

  while(!err && ai->xai_InPos + 128 <= ai->xai_InSize)
  {
    if(!(err =  xadHookAccess(XADM XADAC_READ, 128, header, ai)))
    {
      type = MacBinary_RecogData(128, header, xadMasterBase);

#ifdef DEBUG
  if(header[0] == 1 || (ai->xai_InPos != 128 && type))
  {
    DebugFileSearched(ai, "Strange data.");
  }
#endif

      if(!type)
        err = XADERR_DATAFORMAT;
      else if(header[0] == 1 && header[65] == 'f' && header[66] == 'o' && header[67] == 'l' &&
      header[68] == 'd')
      {
        if(!header[1] && ldir) /* stop block????? - no clear standard description */
        {
          ldir = (struct xadFileInfo *) ldir->xfi_PrivateInfo;
        }
        else if((fi = xadAllocObjectA(XADM XADOBJ_FILEINFO, 0)))
        {
          if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR)header+2, header[1], 0)))
          {
            fi->xfi_Flags |= XADFIF_DIRECTORY|XADFIF_XADSTRFILENAME;
            xadConvertDates(XADM XAD_DATEMAC, EndGetM32(header+95), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
            fi->xfi_PrivateInfo = (xadPTR) ldir;
            ldir = fi;
            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos, TAG_DONE);
          }
          else
          {
            xadFreeObjectA(XADM fi, 0);
            err = XADERR_NOMEMORY;
          }
        }
        else
          err = XADERR_NOMEMORY;
      }
      else
      {
        csize = SITmakecomment((xadSTRPTR)header+65, (header[73]<<8)+(type>1 ? header[101] : 0), 0, 0, 0);
        rsize = EndGetM32(header+87);
        dsize = EndGetM32(header+83);
        lfi = 0;

        if(dsize) /* data fork */
        {
          if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, csize ? XAD_OBJCOMMENTSIZE
          : TAG_IGNORE, csize, TAG_DONE)))
          {
            if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR)header+2, header[1], 0)))
            {
              /* if comment field is zero, nothing is done! */
              SITmakecomment((xadSTRPTR) header+65, (header[73]<<8)+(type>1 ? header[101] : 0), 0, 0, fi->xfi_Comment);

              fi->xfi_CrunchSize = fi->xfi_Size = dsize;
              lfi = fi;

              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
              fi->xfi_DataPos = ai->xai_InPos;

              xadConvertDates(XADM XAD_DATEMAC, EndGetM32(header+95), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

              i = (fi->xfi_CrunchSize+127)&(~127);
              if(ai->xai_InSize-ai->xai_InPos == fi->xfi_CrunchSize)
               i = fi->xfi_CrunchSize;
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+i, TAG_DONE);
            }
            else
            {
              xadFreeObjectA(XADM fi, 0);
              err = XADERR_NOMEMORY;
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(!err && rsize) /* resource fork */
        {
          if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, dsize || !csize ? TAG_IGNORE
          : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
          {
            if((fi->xfi_FileName = MACname(xadMasterBase, ldir, (xadSTRPTR) header+2, header[1], 1)))
            {
              /* if comment field is zero, nothing is done! */
              SITmakecomment((xadSTRPTR)header+65, (header[73]<<8)+(type>1 ? header[101] : 0), 0, 0, fi->xfi_Comment);

              fi->xfi_CrunchSize = fi->xfi_Size = rsize;

              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
              fi->xfi_DataPos = ai->xai_InPos;

              if((fi->xfi_MacFork = lfi))
                lfi->xfi_MacFork = fi;

              xadConvertDates(XADM XAD_DATEMAC, EndGetM32(header+95), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

              i = (fi->xfi_CrunchSize+127)&(~127);
              if(ai->xai_InSize-ai->xai_InPos == fi->xfi_CrunchSize)
               i = fi->xfi_CrunchSize;
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+i, TAG_DONE);
            }
            else
            {
              xadFreeObjectA(XADM fi, 0);
              err = XADERR_NOMEMORY;
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(!err && type > 1 && (csize = EndGetM16(header+99)))
        {
          err =  xadHookAccess(XADM XADAC_INPUTSEEK, (csize+127)&(~127), 0, ai);
        }
      }
    }
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

XADUNARCHIVE(MacBinary)
{
  return  xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size, 0, ai);
}

/*****************************************************************************/

XADRECOGDATA(PackIt)
{
  if(data[0] == 'P' && data[1] == 'M' && data[2] == 'a' &&
  (data[3] == 'g' || (data[3] >= '0' && data[3] <= '9')))
    return 1;

  return 0;
}

/*****************************************************************************/

#define PIT_NLEN       0
#define PIT_NAME       1
#define PIT_TYPE      64
#define PIT_AUTH      68
#define PIT_FLAG      72
#define PIT_LOCK      74
#define PIT_DLEN      76
#define PIT_RLEN      80
#define PIT_CTIME     84
#define PIT_MTIME     88
#define PIT_HDRCRC    92
#define PIT_HDRBYTES  94

struct PITPrivate {
  xadUINT32 SkipHead;
  xadUINT32 SkipEnd;
  xadUINT8 Method;
};

#define PITPI(a)        ((struct PITPrivate *) ((a)->xfi_PrivateInfo))

/* This functions extracts the first header bytes form the data file
you selected */
static xadUINT8 PackIt_Put(struct xadInOut *io, xadUINT8 data)
{
  xadUINT32 a;

  a = (xadUINT32) io->xio_PutFuncPrivate;
  if(!io->xio_OutSize && !a)
  {
    io->xio_Error = XADERR_DECRUNCH;
    io->xio_Flags |= XADIOF_ERROR;
  }
  else
  {
    if(io->xio_OutSize)
    {
      io->xio_OutBuffer[io->xio_OutBufferPos++] = data;
      if(!--io->xio_OutSize)
      {
        if(xadCRC_1021((xadUINT8 *)io->xio_OutBuffer, PIT_HDRBYTES-2)
        != EndGetM16(io->xio_OutBuffer+PIT_HDRCRC))
        {
          io->xio_Error = XADERR_CHECKSUM;
          io->xio_Flags |= XADIOF_ERROR;
        }
        else
        {
          a = EndGetM32(io->xio_OutBuffer+PIT_RLEN)
             +EndGetM32(io->xio_OutBuffer+PIT_DLEN)+2;
        }
      }
    }
    else
    {
      if(!--a)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }

    io->xio_PutFuncPrivate = (xadPTR) a;
  }

  return data;
}

XADGETINFO(PackIt)
{
  struct xadFileInfo *fi, *lfi;
  xadINT32 err = 0;
  xadUINT32 rsize, dsize, csize, crsize = 0, pos;
  xadSTRPTR entryinfo;
  xadUINT8 header[PIT_HDRBYTES], type[4];

  while(!err && ai->xai_InPos + 4 <= ai->xai_InSize)
  {
    if(!(err =  xadHookAccess(XADM XADAC_READ, 4, type, ai)))
    {
      entryinfo = (xadSTRPTR) header; /* to silent compiler warnings */
      pos = ai->xai_InPos;
      if(type[0] == 'P' && type[1] == 'E' && type[2] == 'n' && type[3] == 'd')
        break;
      else if(type[0] != 'P' || type[1] != 'M' || type[2] != 'a')
        err = XADERR_DATAFORMAT;
      else if(type[3] == '4')
      {
        struct xadInOut *io;

        if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
        {
          io->xio_PutFunc = PackIt_Put;
          io->xio_InSize = ai->xai_InSize-ai->xai_InPos;
          io->xio_OutSize = PIT_HDRBYTES;
          io->xio_OutBuffer = (xadSTRPTR) header;
          entryinfo = "Huffmann";

          err = SIT_huffman(io);
          crsize = (ai->xai_InSize-io->xio_InSize)-pos;
          xadFreeObjectA(XADM io, 0);
        }
        else
          err = XADERR_NOMEMORY;
      }
      else if(type[3] == 'g')
      {
        if(!(err =  xadHookAccess(XADM XADAC_READ, PIT_HDRBYTES, header, ai)))
        {
          if(xadCRC_1021(header, PIT_HDRBYTES-2) != EndGetM16(header+PIT_HDRCRC))
            err = XADERR_CHECKSUM;
          else
          {
            entryinfo = "NoComp";
            crsize = PIT_HDRBYTES+EndGetM32(header+PIT_RLEN)+EndGetM32(header+PIT_DLEN)+2;
          }
        }
      }
      else
        err = XADERR_DATAFORMAT;

      if(!err)
      {
        csize = SITmakecomment((xadSTRPTR)header+PIT_TYPE, EndGetM16(header+PIT_FLAG), 0, 0, 0);
        rsize = EndGetM32(header+PIT_RLEN);
        dsize = EndGetM32(header+PIT_DLEN);
        lfi = 0;

        if(dsize) /* data fork */
        {
          if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
          sizeof(struct PITPrivate), csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE,
          csize, TAG_DONE)))
          {
            if((fi->xfi_FileName = MACname(xadMasterBase, 0, (xadSTRPTR)header+PIT_NAME, header[PIT_NLEN], 0)))
            {
              /* if comment field is zero, nothing is done! */
              SITmakecomment((xadSTRPTR)header+PIT_TYPE, EndGetM16(header+PIT_FLAG), 0, 0, fi->xfi_Comment);

              fi->xfi_Size = dsize;
              fi->xfi_CrunchSize = crsize;
              if(rsize)
              {
                fi->xfi_Flags |= XADFIF_GROUPED;
                fi->xfi_GroupCrSize = crsize;
              }
              lfi = fi;

              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
              fi->xfi_DataPos = pos;

              xadConvertDates(XADM XAD_DATEMAC, EndGetM32(header+PIT_MTIME), XAD_GETDATEXADDATE,
              &fi->xfi_Date, TAG_DONE);

              PITPI(fi)->Method   = type[3];
              PITPI(fi)->SkipHead = PIT_HDRBYTES;
              PITPI(fi)->SkipEnd = rsize+2;
              fi->xfi_EntryInfo = entryinfo;

              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+crsize, TAG_DONE);
            }
            else
            {
              xadFreeObjectA(XADM fi, 0);
              err = XADERR_NOMEMORY;
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(!err && rsize) /* resource fork */
        {
          if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE, sizeof(struct PITPrivate),
          dsize || !csize ? TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
          {
            if((fi->xfi_FileName = MACname(xadMasterBase, 0, (xadSTRPTR) header+PIT_NAME, header[PIT_NLEN], 1)))
            {
              /* if comment field is zero, nothing is done! */
              SITmakecomment((xadSTRPTR)header+PIT_TYPE, EndGetM16(header+PIT_FLAG), 0, 0, fi->xfi_Comment);

              fi->xfi_Size = rsize;
              fi->xfi_CrunchSize = crsize;
              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD|XADFIF_XADSTRFILENAME;
              fi->xfi_DataPos = pos;

              PITPI(fi)->Method   = type[3];
              PITPI(fi)->SkipHead = PIT_HDRBYTES+dsize;
              PITPI(fi)->SkipEnd = 2;
              fi->xfi_EntryInfo = entryinfo;

              if((fi->xfi_MacFork = lfi))
              {
                lfi->xfi_MacFork = fi;
                fi->xfi_GroupCrSize = crsize;
                fi->xfi_Flags |= XADFIF_ENDOFGROUP|XADFIF_GROUPED;
              }

              xadConvertDates(XADM XAD_DATEMAC, EndGetM32(header+PIT_MTIME), XAD_GETDATEXADDATE,
              &fi->xfi_Date, TAG_DONE);

              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+crsize, TAG_DONE);
            }
            else
            {
              xadFreeObjectA(XADM fi, 0);
              err = XADERR_NOMEMORY;
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
      }
    }
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

struct PackItOutPrivate {
  xadUINT32 Header;
  xadUINT32 SkipStart;
  xadUINT32 Data;
  xadUINT32 SkipEnd;
  xadUINT32 CRC;
  xadUINT16 CRCValue;
};

static void PackIt_Out(struct xadInOut *io, xadUINT32 size)
{
  struct PackItOutPrivate *p;
  xadUINT32 bufpos = 0, cursize, i;
  xadUINT16 crc;

  p = (struct PackItOutPrivate *) io->xio_OutFuncPrivate;
  if(p->Header)
  {
    if((cursize = p->Header) > size)
      cursize = size;
    size -= cursize;
    bufpos += cursize;
    p->Header -= cursize;
  }
  if(size)
  {
    if((cursize = p->SkipStart+p->Data+p->SkipEnd) > size)
      cursize = size;

    crc = io->xio_CRC16;
    for(i = 0; i < cursize; ++i)
      crc = xadCRC_1021_crctable[((crc>>8) ^ io->xio_OutBuffer[bufpos+i]) & 0xFF] ^ (crc<<8);
    io->xio_CRC16 = crc;

    if(p->SkipStart)
    {
      if((cursize = p->SkipStart) > size)
        cursize = size;
      size -= cursize;
      bufpos += cursize;
      p->SkipStart -= cursize;
    }
    if(size)
    {
      if(p->Data)
      {
        struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
        if((cursize = p->Data) > size)
          cursize = size;
        if((io->xio_Error =  xadHookAccess(XADM XADAC_WRITE, cursize, io->xio_OutBuffer
        + bufpos, io->xio_ArchiveInfo)))
          io->xio_Flags |= XADIOF_ERROR;
        size -= cursize;
        bufpos += cursize;
        p->Data -= cursize;
      }
      if(p->SkipEnd && size)
      {
        if((cursize = p->SkipEnd) > size)
          cursize = size;
        size -= cursize;
        bufpos += cursize;
        p->SkipEnd -= cursize;
      }
    }
  }
  /* if there is size left, this must be CRC */
  while(size && p->CRC)
  {
    p->CRCValue = (p->CRCValue<<8) | io->xio_OutBuffer[bufpos++];
    --p->CRC;
    --size;
  }
  if(!p->CRC && io->xio_CRC16 != p->CRCValue && !io->xio_Error)
  {
    io->xio_Error = XADERR_CHECKSUM;
    io->xio_Flags |= XADIOF_ERROR;
  }
}

XADUNARCHIVE(PackIt)
{
  struct xadFileInfo *fi;
  struct xadInOut *io;
  xadINT32 err;
  struct PackItOutPrivate p;

  fi = ai->xai_CurFile;

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|
  XADIOF_COMPLETEOUTFUNC|XADIOF_NOCRC32|XADIOF_NOCRC16, ai, xadMasterBase)))
  {
    p.Header = PIT_HDRBYTES;
    p.SkipStart = PITPI(fi)->SkipHead-p.Header;
    p.Data = fi->xfi_Size;
    p.SkipEnd = PITPI(fi)->SkipEnd-2;
    p.CRC = 2;
    p.CRCValue = 0;

    io->xio_OutFunc = PackIt_Out;
    io->xio_OutFuncPrivate = &p;
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = p.Header+p.SkipStart+p.Data+p.SkipEnd+p.CRC;

    switch(PITPI(fi)->Method)
    {
    case 'g':
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        xadIOPutChar(io, xadIOGetChar(io));
      err = io->xio_Error;
      break;
    case '4':
      err = SIT_huffman(io);
      break;
    default:
      err = XADERR_DATAFORMAT;
    }
    if(!err)
      err = xadIOWriteBuf(io);
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

XADCLIENT(PackIt) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  PACKIT_VERSION,
  PACKIT_REVISION,
  4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  XADCID_PACKIT,
  "PackIt",
  XADRECOGDATAP(PackIt),
  XADGETINFOP(PackIt),
  XADUNARCHIVEP(PackIt),
  NULL
};

XADCLIENT(MacBinary) {
  (struct xadClient *) &PackIt_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  MACBINARY_VERSION,
  MACBINARY_REVISION,
  128,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  XADCID_MACBINARY,
  "MacBinary",
  XADRECOGDATAP(MacBinary),
  XADGETINFOP(MacBinary),
  XADUNARCHIVEP(MacBinary),
  NULL
};

XADCLIENT(SIT5EXE) {
  (struct xadClient *) &MacBinary_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SIT5EXE_VERSION,
  SIT5EXE_REVISION,
  8192,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  XADCID_SIT5EXE,
  "StuffIt 5 MS-EXE",
  XADRECOGDATAP(SIT5EXE),
  XADGETINFOP(SIT5EXE),
  XADUNARCHIVEP(SIT),
  NULL
};

XADCLIENT(SIT5) {
  (struct xadClient *) &SIT5EXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SIT5_VERSION,
  SIT5_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  XADCID_SIT5,
  "StuffIt 5",
  XADRECOGDATAP(SIT5),
  XADGETINFOP(SIT5),
  XADUNARCHIVEP(SIT),
  NULL
};

XADFIRSTCLIENT(SIT) {
  (struct xadClient *) &SIT5_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SIT_VERSION,
  SIT_REVISION,
  22,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  XADCID_SIT,
  "StuffIt",
  XADRECOGDATAP(SIT),
  XADGETINFOP(SIT),
  XADUNARCHIVEP(SIT),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(SIT)

#endif /* XADMASTER_STUFFIT_C */
