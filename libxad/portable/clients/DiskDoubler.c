#ifndef XADMASTER_DISKDOUBLER_C
#define XADMASTER_DISKDOUBLER_C

/*  $Id: DiskDoubler.c,v 1.7 2006/06/21 07:20:01 stoecker Exp $
    DiskDoubler file archiver client

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
#define XADIOGETBITSHIGH
#include "xadIO.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION        12
#endif

XADCLIENTVERSTR("DiskDoubler 1.2 (24.2.2004)")

#define DISKDOUBLER1_VERSION    1
#define DISKDOUBLER1_REVISION   2
#define DISKDOUBLER1S_VERSION   DISKDOUBLER1_VERSION
#define DISKDOUBLER1S_REVISION  DISKDOUBLER1_REVISION
#define DISKDOUBLER2_VERSION    DISKDOUBLER1_VERSION
#define DISKDOUBLER2_REVISION   DISKDOUBLER1_REVISION
#define COMPACTOR_VERSION       DISKDOUBLER1_VERSION
#define COMPACTOR_REVISION      DISKDOUBLER1_REVISION

/*****************************************************************************/

static xadUINT16 crctable[256] = {
  0x0000,0x1021,0x2042,0x3063,0x4084,0x50A5,0x60C6,0x70E7,0x8108,0x9129,
  0xA14A,0xB16B,0xC18C,0xD1AD,0xE1CE,0xF1EF,0x1231,0x0210,0x3273,0x2252,
  0x52B5,0x4294,0x72F7,0x62D6,0x9339,0x8318,0xB37B,0xA35A,0xD3BD,0xC39C,
  0xF3FF,0xE3DE,0x2462,0x3443,0x0420,0x1401,0x64E6,0x74C7,0x44A4,0x5485,
  0xA56A,0xB54B,0x8528,0x9509,0xE5EE,0xF5CF,0xC5AC,0xD58D,0x3653,0x2672,
  0x1611,0x0630,0x76D7,0x66F6,0x5695,0x46B4,0xB75B,0xA77A,0x9719,0x8738,
  0xF7DF,0xE7FE,0xD79D,0xC7BC,0x48C4,0x58E5,0x6886,0x78A7,0x0840,0x1861,
  0x2802,0x3823,0xC9CC,0xD9ED,0xE98E,0xF9AF,0x8948,0x9969,0xA90A,0xB92B,
  0x5AF5,0x4AD4,0x7AB7,0x6A96,0x1A71,0x0A50,0x3A33,0x2A12,0xDBFD,0xCBDC,
  0xFBBF,0xEB9E,0x9B79,0x8B58,0xBB3B,0xAB1A,0x6CA6,0x7C87,0x4CE4,0x5CC5,
  0x2C22,0x3C03,0x0C60,0x1C41,0xEDAE,0xFD8F,0xCDEC,0xDDCD,0xAD2A,0xBD0B,
  0x8D68,0x9D49,0x7E97,0x6EB6,0x5ED5,0x4EF4,0x3E13,0x2E32,0x1E51,0x0E70,
  0xFF9F,0xEFBE,0xDFDD,0xCFFC,0xBF1B,0xAF3A,0x9F59,0x8F78,0x9188,0x81A9,
  0xB1CA,0xA1EB,0xD10C,0xC12D,0xF14E,0xE16F,0x1080,0x00A1,0x30C2,0x20E3,
  0x5004,0x4025,0x7046,0x6067,0x83B9,0x9398,0xA3FB,0xB3DA,0xC33D,0xD31C,
  0xE37F,0xF35E,0x02B1,0x1290,0x22F3,0x32D2,0x4235,0x5214,0x6277,0x7256,
  0xB5EA,0xA5CB,0x95A8,0x8589,0xF56E,0xE54F,0xD52C,0xC50D,0x34E2,0x24C3,
  0x14A0,0x0481,0x7466,0x6447,0x5424,0x4405,0xA7DB,0xB7FA,0x8799,0x97B8,
  0xE75F,0xF77E,0xC71D,0xD73C,0x26D3,0x36F2,0x0691,0x16B0,0x6657,0x7676,
  0x4615,0x5634,0xD94C,0xC96D,0xF90E,0xE92F,0x99C8,0x89E9,0xB98A,0xA9AB,
  0x5844,0x4865,0x7806,0x6827,0x18C0,0x08E1,0x3882,0x28A3,0xCB7D,0xDB5C,
  0xEB3F,0xFB1E,0x8BF9,0x9BD8,0xABBB,0xBB9A,0x4A75,0x5A54,0x6A37,0x7A16,
  0x0AF1,0x1AD0,0x2AB3,0x3A92,0xFD2E,0xED0F,0xDD6C,0xCD4D,0xBDAA,0xAD8B,
  0x9DE8,0x8DC9,0x7C26,0x6C07,0x5C64,0x4C45,0x3CA2,0x2C83,0x1CE0,0x0CC1,
  0xEF1F,0xFF3E,0xCF5D,0xDF7C,0xAF9B,0xBFBA,0x8FD9,0x9FF8,0x6E17,0x7E36,
  0x4E55,0x5E74,0x2E93,0x3EB2,0x0ED1,0x1EF0
};

static xadUINT16 DoCRC(xadUINT8 * Mem, xadINT32 Size)
{
  xadUINT16 CRC = 0;

  while(Size--)
    CRC = crctable[((CRC>>8) ^ *(Mem++)) & 0xFF] ^ (CRC<<8);

  return CRC;
}

static xadSTRPTR MACname(struct xadMasterBase *xadMasterBase, struct xadFileInfo *dir, xadSTRPTR file, xadUINT32 size, xadUINT32 rsrc);
/*{
  return xadConvertName(XADM CHARSET_HOST,
  XAD_XADSTRING, dir ? dir->xfi_FileName : 0,
  XAD_CHARACTERSET, CHARSET_MACOS,
  XAD_STRINGSIZE, size,
  XAD_CSTRING, file,
  XAD_CHARACTERSET, CHARSET_ISO_8859_1,          /* the .rsrc ending * /
  XAD_ADDPATHSEPERATOR, XADFALSE,
  rsrc ? XAD_CSTRING : TAG_IGNORE, ".rsrc",
  TAG_DONE);
}*/

static xadINT32 SITmakecomment(xadSTRPTR txt, xadUINT16 creatorflags, xadSTRPTR comment, xadUINT32 csize, xadSTRPTR dest);
/*{
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
      creatorflags &= 0xFFFF; /* security * /
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
}*/

struct DDARPrivate {
  xadUINT16 CRC;
  xadUINT8 Method;
};

#define DDARPI(a)       ((struct DDARPrivate *) ((a)->xfi_PrivateInfo))

/*****************************************************************************/

#define DDRLE_ESC1      0x81
#define DDRLE_ESC2      0x82

static void myputbyte(struct xadInOut *io, xadUINT8 a, xadUINT32 num)
{
  while(num-- && !io->xio_Error)
  {
    if(!io->xio_OutSize && !(io->xio_Flags & XADIOF_NOOUTENDERR))
    {
      io->xio_Error = XADERR_DECRUNCH;
      io->xio_Flags |= XADIOF_ERROR;
    }
    else
    {
      if(io->xio_OutBufferPos >= io->xio_OutBufferSize)
        xadIOWriteBuf(io);
      io->xio_OutBuffer[io->xio_OutBufferPos++] = a;
      if(!--io->xio_OutSize)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }
  }
}

static xadUINT8 xadIOPutFuncRLE8182(struct xadInOut *io, xadUINT8 data)
{
  xadUINT32 a;

  a = (xadUINT32) io->xio_PutFuncPrivate;

  if(a & 0x200) /* DDRLE_ESC2 was last */
  {
    if(data)
    {
      myputbyte(io, a, data-1); a &= 0xFF;
    }
    else
    {
      myputbyte(io, DDRLE_ESC1, 1);
      myputbyte(io, (a = DDRLE_ESC2), 1);
    }
  }
  else if(a & 0x100) /* DDRLE_ESC1 was last */
  {
    if(data == DDRLE_ESC2)
      a |= 0x200;
    else
    {
      myputbyte(io, (a = DDRLE_ESC1), 1);
      if(data != DDRLE_ESC1)
        myputbyte(io, (a = data), 1);
      else
        a |= 0x100;
    }
  }
  else if(data == DDRLE_ESC1)
     a |= 0x100;
  else
    myputbyte(io, (a = data), 1);

  io->xio_PutFuncPrivate = (xadPTR) a;
  return data;
}

/*****************************************************************************/

#define CPT_CIRCSIZE    8192
#define CPT_SLACK       6

struct cpt_node
{
  xadINT32             flag;
  xadINT32             byte;
  struct cpt_node *one;
  struct cpt_node *zero;
};

struct cpt_sf_entry
{
  xadINT32 Value;
  xadINT32 BitLength;
};

struct DD8Data {
  struct xadInOut *io;

  xadUINT8            LZbuff[CPT_CIRCSIZE];
  struct cpt_node  Hufftree[512 + CPT_SLACK];
  struct cpt_node  LZlength[128 + CPT_SLACK];
  struct cpt_node  LZoffs[256 + CPT_SLACK];

  /* private for CPT_readHuff! */
  struct cpt_sf_entry tree_entry[256 + CPT_SLACK]; /* maximal number of elements */
};

static xadINT32 CPT_readHuff(struct DD8Data *dat, xadINT32 size, struct cpt_node *Hufftree)
{
  xadINT32 tree_entries;
  xadINT32 tree_MaxLength; /* finishes local declaration of tree */
  xadINT32 tree2Bytes, i, len;  /* declarations from ReadLengths */
  struct cpt_sf_entry *ejm1, tmp;
  xadINT32 j, codelen, lvlstart, next, parents;
  xadUINT32 a, b;
  xadINT32 tree_count[32];

  tree2Bytes = xadIOGetBitsHigh(dat->io, 8)<<1;
  if(size < tree2Bytes)
    return (dat->io->xio_Error = XADERR_ILLEGALDATA);

  for(i = 0; i < 32; i++)
    tree_count[i] = 0;
  i = 0;
  tree_MaxLength = 0;
  tree_entries = 0;
  while(tree2Bytes-- > 0)
  {
    len = xadIOGetBitsHigh(dat->io, 4);
    if(len)
    {
      if(len > tree_MaxLength)
        tree_MaxLength = len;
      tree_count[len]++;
      dat->tree_entry[tree_entries].Value = i;
      dat->tree_entry[tree_entries++].BitLength = len;
    }
    i++;
  }

  /* Compactor allows unused trailing codes in its Huffman tree! */
  j = 0;
  for(i = 0; i <= tree_MaxLength; i++)
    j = (j << 1) + tree_count[i];

  j = (1<<tree_MaxLength) - j;
  /* Insert the unused entries for sorting purposes. */

  for(i = 0; i < j; i++)
  {
    dat->tree_entry[tree_entries].Value = size;
    dat->tree_entry[tree_entries++].BitLength = tree_MaxLength;
  }

  for(i = 0; ++i < tree_entries;)
  {
    tmp = dat->tree_entry[i];
    b = tmp.BitLength;
    j = i;
    while((j > 0) && ((a = (ejm1 = &(dat->tree_entry[j - 1]))->BitLength) >= b))
    {
      if((a == b) && (ejm1->Value <= tmp.Value))
        break;
      *(ejm1 + 1) = *ejm1;
      --j;
    }
    dat->tree_entry[j] = tmp;
  }

  i = tree_entries - 1;
  /* starting at the upper end (and reversing loop) */
  lvlstart = next = size * 2 + CPT_SLACK - 1;
  for(codelen = tree_MaxLength; codelen >= 1; --codelen)
  {
    while((i >= 0) && (dat->tree_entry[i].BitLength == codelen))
    {
      Hufftree[next].byte = dat->tree_entry[i--].Value;
      Hufftree[next--].flag = 1;
    }
    parents = next;
    if(codelen > 1)
    {
      /* reversed loop */
      for(j = lvlstart; j > parents + 1; j-= 2)
      {
        Hufftree[next].one = Hufftree + j;
        Hufftree[next].zero = Hufftree + j-1;
        Hufftree[next--].flag = 0;
      }
    }
    lvlstart = parents;
  }
  Hufftree[0].one = Hufftree + next+2;
  Hufftree[0].zero = Hufftree + next+1;
  Hufftree[0].flag = 0;
  return XADERR_OK;
}

static xadINT32 CPT_gethuffbyte(struct xadInOut *io, struct cpt_node *l_nodelist)
{
  struct cpt_node *np;

  np = l_nodelist;
  while(!np->flag)
   np = xadIOGetBitsHigh(io, 1) ? np->one : np->zero;
  return np->byte;
}

static xadINT32 DD_8(struct xadInOut *io, xadUINT32 blocksize)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct DD8Data *dat;

  if((dat = (struct DD8Data *) xadAllocVec(XADM sizeof(struct DD8Data),
  XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    xadUINT32 block_count, store, winptr = 0, bptr, LZlength, LZoffs;

    dat->io = io;

    /* dat->LZbuff[CPT_CIRCSIZE - 3] = 0; */
    /* dat->LZbuff[CPT_CIRCSIZE - 2] = 0; */
    /* dat->LZbuff[CPT_CIRCSIZE - 1] = 0; */
    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      CPT_readHuff(dat, 256, dat->Hufftree);
      CPT_readHuff(dat, 64, dat->LZlength);
      CPT_readHuff(dat, 128, dat->LZoffs);

      block_count = 0;
      store = io->xio_InSize;
      while(block_count < blocksize && !(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
      {
        if(xadIOGetBitsHigh(io, 1))
        {
          dat->LZbuff[winptr++] = xadIOPutChar(io, CPT_gethuffbyte(io, dat->Hufftree));
          winptr &= (CPT_CIRCSIZE-1);
          block_count += 2;
        }
        else
        {
          LZlength = CPT_gethuffbyte(io, dat->LZlength);
          LZoffs = CPT_gethuffbyte(io, dat->LZoffs);
          LZoffs = (LZoffs << 6) | xadIOGetBitsHigh(io, 6);
          bptr = winptr - LZoffs;
          while(LZlength--)
          {
            bptr &= (CPT_CIRCSIZE-1);
            dat->LZbuff[winptr++] = xadIOPutChar(io, dat->LZbuff[bptr++]);
            winptr &= (CPT_CIRCSIZE-1);
          }
          block_count += 3;
        }
      }
      if(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
      {
        xadIOGetBitsHigh(io, (store-io->xio_InSize)&1 ? 24 : 16);
        xadIOByteBoundary(io);
        /* this rounds up to next 16bit boundary starting from huff header */
      }
    }
    xadFreeObjectA(XADM dat, 0);
  }
  return io->xio_Error;
}


/*****************************************************************************/

#define DDAR_MAGIC         0
#define DDAR_FILL1         4
#define DDAR_FNAMESIZE     8
#define DDAR_FNAME         9
#define DDAR_ISDIR        72
#define DDAR_ENDDIR       73
#define DDAR_DATALENGTH   74
#define DDAR_RSRCLENGTH   78
#define DDAR_CTIME        82
#define DDAR_MTIME        86
#define DDAR_FTYPE        90
#define DDAR_CREATOR      94
#define DDAR_FNDRFLAGS    98
#define DDAR_FILL2       100
#define DDAR_DATACRC     118
#define DDAR_RSRCCRC     120
#define DDAR_HDRCRC      122
#define DDAR_FILEHDRSIZE 124

#define DDARC_MAGIC        0
#define DDARC_DATALENGTH   4
#define DDARC_DATACLENGTH  8
#define DDARC_RSRCLENGTH  12
#define DDARC_RSRCCLENGTH 16
#define DDARC_DATAMETHOD  20
#define DDARC_RSRCMETHOD  21
#define DDARC_INFO1       22
#define DDARC_MTIME       24
#define DDARC_CTIME       28
#define DDARC_FTYPE       32
#define DDARC_CREATOR     36
#define DDARC_FNDRFLAGS   40
#define DDARC_FILL1       42
#define DDARC_DATACRC     48
#define DDARC_RSRCCRC     50
#define DDARC_INFO2       52
#define DDARC_DATAINFO    54
#define DDARC_RSRCINFO    56
#define DDARC_FILL2       58
#define DDARC_DATACRC2    78
#define DDARC_RSRCCRC2    80
#define DDARC_HDRCRC      82
#define DDARC_FILEHDRSIZE 84

#define DDAR_MAXALGO    10
static const xadSTRPTR ddartypes[] = {
"NoComp", "LZC", "2", "RLE", "Huffmann", "5", "6", "LZSS", "RLE/LZH", "9", "10"};

XADRECOGDATA(DiskDoubler1)
{
  if(data[0] == 'D' && data[1] == 'D' && data[2] == 'A' && data[3] == 'R')
    return 1;
  return 0;
}

XADGETINFO(DiskDoubler1)
{
  struct xadFileInfo *fi, *lfi = 0, *ldir = 0;
  xadINT32 err, nsize, csize;
  xadINT32 dsize, dcsize, rsize, rcsize, rmethod, dmethod, offs, rcrc, dcrc, finderflags;
  xadUINT32 pos;
  xadUINT8 header[DDAR_FILEHDRSIZE];
  xadUINT8 header2[DDARC_FILEHDRSIZE];
  xadSTRPTR ftype;

  if(!(err = xadHookAccess(XADM XADAC_READ, 78, header, ai)))
  {
    if(header[0] != 'D' || header[1] != 'D' || header[2] != 'A' || header[3] != 'R' ||
    DoCRC(header, 76) != EndGetM16(header+76))
      err = XADERR_ILLEGALDATA;
    else
    {
      while(!err && ai->xai_InPos + DDAR_FILEHDRSIZE <= ai->xai_InSize)
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, DDAR_FILEHDRSIZE, header, ai)))
        {
          if(header[0] != 'D' || header[1] != 'D' || header[2] != 'A' || header[3] != 'R' ||
          DoCRC(header, DDAR_FILEHDRSIZE-2) != EndGetM16(header+DDAR_HDRCRC))
            err = XADERR_ILLEGALDATA;
          else
          {
            for(nsize = 0; nsize < 8; ++nsize)
            {
              if(header[DDAR_FTYPE+nsize] < 0x20 || header[DDAR_FTYPE+nsize] > 0x7E)
                header[DDAR_FTYPE+nsize] = '?';
            }

            if(header[DDAR_FNAMESIZE] > 83)
              nsize = 83; /* prevent errors */
            else
              nsize = header[DDAR_FNAMESIZE];
            if(header[DDAR_ENDDIR])
            {
              if(ldir)
                ldir = (struct xadFileInfo *) ldir->xfi_PrivateInfo;
            }
            else if(header[DDAR_ISDIR])
            {
              if((fi = xadAllocObjectA(XADM XADOBJ_FILEINFO, 0)))
              {
                if((fi->xfi_FileName = MACname(xadMasterBase, ldir, header+DDAR_FNAME, nsize, 0)))
                {
                  fi->xfi_Flags |= XADFIF_DIRECTORY;
                  xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDAR_MTIME]), XAD_GETDATEXADDATE,
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
              rsize = rcsize = EndGetM32(&header[DDAR_RSRCLENGTH]);
              dsize = dcsize = EndGetM32(&header[DDAR_DATALENGTH]);
              rmethod = dmethod = 0;
              rcrc = EndGetM16(&header[DDAR_RSRCCRC]);
              dcrc = EndGetM16(&header[DDAR_DATACRC]);
              ftype = header+DDAR_FTYPE;
              finderflags = EndGetM16(&header[DDAR_FNDRFLAGS]);
              offs = 0;
              if(!(header[DDAR_FNDRFLAGS] & 0x20))
              {
                if(!(err = xadHookAccess(XADM XADAC_READ, DDARC_FILEHDRSIZE, header2, ai)))
                {
                  if(header2[0] == 0xAB && header2[1] == 0xCD && !header2[2] && header2[3] == 0x54 &&
                  DoCRC(header2, DDARC_FILEHDRSIZE-2) == EndGetM16(header2+DDARC_HDRCRC))
                  {
#ifdef DEBUG
DebugClient(ai, "INFO1    = $%08lx\n", EndGetM32(header2+DDARC_INFO1));
DebugClient(ai, "FILL1    = $%08lx%04lx\n", EndGetM32(header2+DDARC_FILL1), EndGetM16(header2+DDARC_FILL1+4));
DebugClient(ai, "INFO2    = $%04lx\n", EndGetM16(header2+DDARC_INFO2));
DebugClient(ai, "DATAINFO = $%04lx\n", EndGetM16(header2+DDARC_DATAINFO));
DebugClient(ai, "RSRCINFO = $%04lx\n", EndGetM16(header2+DDARC_RSRCINFO));
DebugClient(ai, "FILL2    = $%08lx%08lx%08lx%08lx%08lx\n", EndGetM32(header2+DDARC_FILL2),EndGetM32(header2+DDARC_FILL2+4),
EndGetM32(header2+DDARC_FILL2+8),EndGetM32(header2+DDARC_FILL2+12),EndGetM32(header2+DDARC_FILL2+16));
DebugClient(ai, "DATACRC2 = $%04lx\n", EndGetM16(header2+DDARC_DATACRC2));
DebugClient(ai, "RSRCCRC2 = $%04lx\n", EndGetM16(header2+DDARC_RSRCCRC2));
DebugClient(ai, "%s\n\n", header+DDAR_FNAME);
#endif

                    for(rsize = 0; rsize < 8; ++rsize)
                    {
                      if(header2[DDARC_FTYPE+rsize] < 0x20 || header2[DDARC_FTYPE+rsize] > 0x7E)
                      header2[DDARC_FTYPE+rsize] = '?';
                    }

                    rsize = EndGetM32(&header2[DDARC_RSRCLENGTH]);
                    rcsize = EndGetM32(&header2[DDARC_RSRCCLENGTH]);
                    dsize = EndGetM32(&header2[DDARC_DATALENGTH]);
                    dcsize = EndGetM32(&header2[DDARC_DATACLENGTH]);
                    rmethod = header2[DDARC_RSRCMETHOD];
                    dmethod = header2[DDARC_DATAMETHOD];
                    offs = DDARC_FILEHDRSIZE;
                    ftype = header2+DDARC_FTYPE;
                    finderflags = EndGetM16(&header2[DDARC_FNDRFLAGS]);
                    dcrc = EndGetM16(header2+DDARC_DATACRC);
                    rcrc = EndGetM16(header2+DDARC_RSRCCRC);
                  }
                  else
                    err = XADERR_ILLEGALDATA;
                }
              }

              csize = SITmakecomment(ftype, finderflags, 0, 0, 0);
              pos = ai->xai_InPos;

              if(dsize || !rsize)
              {
                if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                sizeof(struct DDARPrivate), csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize,
                TAG_DONE)))
                {
                  if((fi->xfi_FileName = MACname(xadMasterBase, ldir, header+DDAR_FNAME, nsize, 0)))
                  {
                    SITmakecomment(ftype, finderflags, 0, 0, fi->xfi_Comment);

                    fi->xfi_CrunchSize = dcsize;
                    fi->xfi_Size = dsize;
                    lfi = fi;

                    fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD;
                    fi->xfi_DataPos = pos;

                    DDARPI(fi)->CRC = dcrc;
                    if((DDARPI(fi)->Method = dmethod) <= DDAR_MAXALGO)
                      fi->xfi_EntryInfo = ddartypes[dmethod];

                    xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDAR_MTIME]), XAD_GETDATEXADDATE,
                    &fi->xfi_Date, TAG_DONE);

                    err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+rcsize+dcsize+offs, TAG_DONE);
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

              if(!err && rsize)
              {
                if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                sizeof(struct DDARPrivate), dsize || !csize ?
                TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
                {
                  if((fi->xfi_FileName = MACname(xadMasterBase, ldir, header+DDAR_FNAME, nsize, 1)))
                  {
                    /* if comment field is zero, nothing is done! */
                    SITmakecomment(ftype, finderflags, 0, 0, fi->xfi_Comment);

                    fi->xfi_CrunchSize = rcsize;
                    fi->xfi_Size = rsize;
                    fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD;
                    fi->xfi_DataPos = pos+dcsize;

                    if(dsize)
                    {
                      fi->xfi_MacFork = lfi;
                      lfi->xfi_MacFork = fi;
                    }

                    DDARPI(fi)->CRC = rcrc;
                    if((DDARPI(fi)->Method = rmethod) <= DDAR_MAXALGO)
                      fi->xfi_EntryInfo = ddartypes[rmethod];

                    xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDAR_MTIME]), XAD_GETDATEXADDATE,
                    &fi->xfi_Date, TAG_DONE);

                    err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+rcsize+dcsize+offs, TAG_DONE);
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

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

XADRECOGDATA(DiskDoubler1S)
{
  if(data[0] == 0xAB && data[1] == 0xCD && !data[2] && data[3] == 0x54)
    return 1;
  return 0;
}

XADGETINFO(DiskDoubler1S)
{
  xadUINT8 header[DDARC_FILEHDRSIZE];
  struct xadFileInfo *fi, *lfi = 0;
  xadSTRPTR name;
  xadINT32 err, nsize, csize, rsize, dsize;

  if(!(err = xadHookAccess(XADM XADAC_READ, DDARC_FILEHDRSIZE, header, ai)))
  {
    if(DoCRC(header, DDARC_FILEHDRSIZE-2) == EndGetM16(header+DDARC_HDRCRC))
    {
      name = ai->xai_InName ? ai->xai_InName : xadGetDefaultName(XADM
      XAD_ARCHIVEINFO, ai, TAG_DONE);
      rsize = EndGetM32(&header[DDARC_RSRCLENGTH]);
      dsize = EndGetM32(&header[DDARC_DATALENGTH]);

      for(nsize = 0; nsize < 8; ++nsize)
      {
        if(header[DDARC_FTYPE+nsize] < 0x20 || header[DDARC_FTYPE+nsize] > 0x7E)
        header[DDARC_FTYPE+nsize] = '?';
      }

#ifdef DEBUG
DebugClient(ai, "INFO1    = $%08lx\n", EndGetM32(header+DDARC_INFO1));
DebugClient(ai, "FILL1    = $%08lx%04lx\n", EndGetM32(header+DDARC_FILL1), EndGetM16(header+DDARC_FILL1+4));
DebugClient(ai, "INFO2    = $%04lx\n", EndGetM16(header+DDARC_INFO2));
DebugClient(ai, "DATAINFO = $%04lx\n", EndGetM16(header+DDARC_DATAINFO));
DebugClient(ai, "RSRCINFO = $%04lx\n", EndGetM16(header+DDARC_RSRCINFO));
DebugClient(ai, "FILL2    = $%08lx%08lx%08lx%08lx%08lx\n", EndGetM32(header+DDARC_FILL2),EndGetM32(header+DDARC_FILL2+4),
EndGetM32(header+DDARC_FILL2+8),EndGetM32(header+DDARC_FILL2+12),EndGetM32(header+DDARC_FILL2+16));
DebugClient(ai, "DATACRC2 = $%04lx\n", EndGetM16(header+DDARC_DATACRC2));
DebugClient(ai, "RSRCCRC2 = $%04lx\n", EndGetM16(header+DDARC_RSRCCRC2));
#endif

      nsize = strlen(name);
      csize = SITmakecomment(header + DDARC_FTYPE, EndGetM16(header+DDARC_FNDRFLAGS), 0, 0, 0);

      if(dsize || !rsize)
      {
        if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE, sizeof(struct DDARPrivate),
        csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize, TAG_DONE)))
        {
          if((fi->xfi_FileName = MACname(xadMasterBase, 0, name, nsize, 0)))
          {
            SITmakecomment(header + DDARC_FTYPE, EndGetM16(header+DDARC_FNDRFLAGS), 0, 0, fi->xfi_Comment);

            fi->xfi_CrunchSize = EndGetM32(&header[DDARC_DATACLENGTH]);
            fi->xfi_Size = dsize;
            lfi = fi;

            fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD;
            fi->xfi_DataPos = DDARC_FILEHDRSIZE;

            DDARPI(fi)->CRC = EndGetM16(header+DDARC_DATACRC);
            if((DDARPI(fi)->Method = header[DDARC_DATAMETHOD]) <= DDAR_MAXALGO)
              fi->xfi_EntryInfo = ddartypes[header[DDARC_DATAMETHOD]];

            xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDARC_MTIME]), XAD_GETDATEXADDATE,
            &fi->xfi_Date, TAG_DONE);

            err = xadAddFileEntryA(XADM fi, ai, 0);
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
      if(!err && rsize)
      {
        if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
        sizeof(struct DDARPrivate), dsize || !csize ?
        TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
        {
          if((fi->xfi_FileName = MACname(xadMasterBase, 0, name, nsize, 1)))
          {
            /* if comment field is zero, nothing is done! */
            SITmakecomment(header + DDARC_FTYPE, EndGetM16(header+DDARC_FNDRFLAGS), 0, 0, fi->xfi_Comment);

            fi->xfi_CrunchSize = EndGetM32(&header[DDARC_RSRCCLENGTH]);
            fi->xfi_Size = rsize;
            fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD;
            fi->xfi_DataPos = ai->xai_InPos+EndGetM32(&header[DDARC_DATACLENGTH]);

            if(dsize)
            {
              fi->xfi_MacFork = lfi;
              lfi->xfi_MacFork = fi;
            }

            DDARPI(fi)->CRC = EndGetM16(header+DDARC_RSRCCRC);
            if((DDARPI(fi)->Method = header[DDARC_RSRCMETHOD]) <= DDAR_MAXALGO)
              fi->xfi_EntryInfo = ddartypes[header[DDARC_RSRCMETHOD]];

            xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDARC_MTIME]), XAD_GETDATEXADDATE,
            &fi->xfi_Date, TAG_DONE);

            err = xadAddFileEntryA(XADM fi, ai, 0);
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
    else
      err = XADERR_ILLEGALDATA;
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

XADRECOGDATA(DiskDoubler2)
{
  if(data[0] == 'D' && data[1] == 'D' && data[2] == 'A' && data[3] == '2')
    return 1;
  return 0;
}

/*****************************************************************************/

#define DDA2_MAGIC         0 /*  4 */
#define DDA2_ENTRYTYPE     4 /*  1 */

#define DDA2_FNAMESIZE     6 /*  1 */
#define DDA2_FNAME         7 /* 31 */
#define DDA2_DIRLEVEL     38 /*  4 */
#define DDA2_ENTRYSIZE    42 /*  4 */

#define DDA2_FILEHDRCRC   54 /*  2 */
#define DDA2_FILEHDRSIZE  56 /* end of file header */

#define DDA2_CTIME        54 /*  4 */
#define DDA2_MTIME        58 /*  4 */

#define DDA2_DIRHDRCRC    86 /*  2 */
#define DDA2_DIRHDRSIZE   88

struct DDA2Private {
  xadUINT32 Level;
  struct xadFileInfo *Parent;
};

#define DDA2PI(a)       ((struct DDA2Private *) ((a)->xfi_PrivateInfo))

XADGETINFO(DiskDoubler2)
{
  xadINT32 err;
  xadUINT8 header[DDA2_DIRHDRSIZE];
  xadUINT8 header2[DDARC_FILEHDRSIZE];
  struct xadFileInfo *fi, *lfi = 0, *ldir = 0;
  xadINT32 nsize, csize, dirlevel = 1;
  xadUINT32 pos;

  if(!(err = xadHookAccess(XADM XADAC_READ, 62, header, ai)))
  {
    if(header[0] != 'D' || header[1] != 'D' || header[2] != 'A' || header[3] != '2' ||
    DoCRC(header, 60) != EndGetM16(header+60))
      err = XADERR_ILLEGALDATA;
    else
    {
      while(!err && ai->xai_InPos + DDA2_FILEHDRSIZE <= ai->xai_InSize)
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, DDA2_FILEHDRSIZE, header, ai)))
        {
          if(header[DDA2_FNAMESIZE] > 31)
            nsize = 31; /* prevent errors */
          else
            nsize = header[DDA2_FNAMESIZE];

          if(header[0] != 'D' || header[1] != 'D' || header[2] != 'A' || header[3] != '2')
            err = XADERR_ILLEGALDATA;
          else if(header[DDA2_ENTRYTYPE] == 0xBB)
            break; /* end */
          else
          {
            csize = EndGetM32(header+DDA2_DIRLEVEL);
            if(ldir && csize != DDA2PI(ldir)->Level)
            {
              while(ldir && csize != DDA2PI(ldir)->Level)
                ldir = DDA2PI(ldir)->Parent;
            }

            if(header[DDA2_ENTRYTYPE] & 0x80)
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, DDA2_DIRHDRSIZE-DDA2_FILEHDRSIZE,
              header+DDA2_FILEHDRSIZE, ai)))
              {
                if(DoCRC(header, DDA2_DIRHDRSIZE-2) != EndGetM16(header+DDA2_DIRHDRCRC))
                  err = XADERR_ILLEGALDATA;
                else if(dirlevel == 1 && (!strncmp(header+DDA2_FNAME+nsize-4, ".sea", 4)
                || !strncmp(header+DDA2_FNAME+nsize-3, ".dd", 3)))
                  dirlevel = 2; /* skip this dir */
                else
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                  sizeof(struct DDA2Private), TAG_DONE)))
                  {
                    if((fi->xfi_FileName = MACname(xadMasterBase, ldir, header+DDA2_FNAME,
                    nsize, 0)))
                    {
                      fi->xfi_Flags |= XADFIF_DIRECTORY;
                      xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header[DDA2_CTIME]), XAD_GETDATEXADDATE,
                      &fi->xfi_Date, TAG_DONE);
                      DDA2PI(fi)->Parent = (xadPTR) ldir;
                      ldir = fi;
                      DDA2PI(fi)->Level = ++dirlevel;
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
                } /* check dir header */
              } /* read dir header */
            } /* handle dir */
            else
            {
              if(DoCRC(header, DDA2_FILEHDRSIZE-2) != EndGetM16(header+DDA2_FILEHDRCRC))
                err = XADERR_ILLEGALDATA;
              else
              {
                if(!(err = xadHookAccess(XADM XADAC_READ, DDARC_FILEHDRSIZE, header2, ai)))
                {
                  if(header2[0] != 0xAB || header2[1] != 0xCD || header2[2] || header2[3] != 0x54 ||
                  DoCRC(header2, DDARC_FILEHDRSIZE-2) != EndGetM16(header2+DDARC_HDRCRC))
                    err = XADERR_ILLEGALDATA;
                  else
                  {
                    xadUINT32 rsize, dsize, rcsize, dcsize;

#ifdef DEBUG
DebugClient(ai, "INFO1    = $%08lx\n", EndGetM32(header2+DDARC_INFO1));
DebugClient(ai, "FILL1    = $%08lx%04lx\n", EndGetM32(header2+DDARC_FILL1), EndGetM16(header2+DDARC_FILL1+4));
DebugClient(ai, "INFO2    = $%04lx\n", EndGetM16(header2+DDARC_INFO2));
DebugClient(ai, "DATAINFO = $%04lx\n", EndGetM16(header2+DDARC_DATAINFO));
DebugClient(ai, "RSRCINFO = $%04lx\n", EndGetM16(header2+DDARC_RSRCINFO));
DebugClient(ai, "FILL2    = $%08lx%08lx%08lx%08lx%08lx\n", EndGetM32(header2+DDARC_FILL2),EndGetM32(header2+DDARC_FILL2+4),
EndGetM32(header2+DDARC_FILL2+8),EndGetM32(header2+DDARC_FILL2+12),EndGetM32(header2+DDARC_FILL2+16));
DebugClient(ai, "DATACRC2 = $%04lx\n", EndGetM16(header2+DDARC_DATACRC2));
DebugClient(ai, "RSRCCRC2 = $%04lx\n", EndGetM16(header2+DDARC_RSRCCRC2));
DebugClient(ai, "%s\n\n", header+DDA2_FNAME);
#endif
                    for(csize = 0; csize < 8; ++csize)
                    {
                      if(header2[DDARC_FTYPE+csize] < 0x20 || header2[DDARC_FTYPE+csize] > 0x7E)
                      header2[DDARC_FTYPE+csize] = '?';
                    }
                    csize = SITmakecomment(header2+DDARC_FTYPE, EndGetM16(header2+DDARC_FNDRFLAGS), 0, 0, 0);

                    rsize = EndGetM32(&header2[DDARC_RSRCLENGTH]);
                    dsize = EndGetM32(&header2[DDARC_DATALENGTH]);
                    rcsize = EndGetM32(&header2[DDARC_RSRCCLENGTH]);
                    dcsize = EndGetM32(&header2[DDARC_DATACLENGTH]);
                    pos = ai->xai_InPos;

                    if(dsize || !rsize)
                    {
                      if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE, sizeof(struct DDARPrivate),
                      csize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, csize, TAG_DONE)))
                      {
                        if((fi->xfi_FileName = MACname(xadMasterBase, ldir,
                        header+DDA2_FNAME, nsize, 0)))
                        {
                          SITmakecomment(header2+DDARC_FTYPE, EndGetM16(header2+DDARC_FNDRFLAGS), 0, 0, fi->xfi_Comment);

                          fi->xfi_CrunchSize = dcsize;
                          fi->xfi_Size = dsize;
                          lfi = fi;

                          fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD;
                          fi->xfi_DataPos = pos;

                          DDARPI(fi)->CRC = EndGetM16(header2+DDARC_DATACRC);
                          if((DDARPI(fi)->Method = header2[DDARC_DATAMETHOD]) <= DDAR_MAXALGO)
                            fi->xfi_EntryInfo = ddartypes[header2[DDARC_DATAMETHOD]];

                          xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header2[DDARC_MTIME]), XAD_GETDATEXADDATE,
                          &fi->xfi_Date, TAG_DONE);

                          err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+rcsize+dcsize, TAG_DONE);
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

                    if(!err && rsize)
                    {
                      if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                      sizeof(struct DDARPrivate), dsize || !csize ?
                      TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
                      {
                        if((fi->xfi_FileName = MACname(xadMasterBase, ldir, header+DDA2_FNAME,
                        nsize, 1)))
                        {
                          /* if comment field is zero, nothing is done! */
                          SITmakecomment(header2+DDARC_FTYPE, EndGetM16(header2+DDARC_FNDRFLAGS), 0, 0, fi->xfi_Comment);

                          fi->xfi_CrunchSize = rcsize;
                          fi->xfi_Size = rsize;
                          fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD;
                          fi->xfi_DataPos = pos+dcsize;

                          if(dsize)
                          {
                            fi->xfi_MacFork = lfi;
                            lfi->xfi_MacFork = fi;
                          }

                          DDARPI(fi)->CRC = EndGetM16(header2+DDARC_RSRCCRC);
                          if((DDARPI(fi)->Method = header2[DDARC_RSRCMETHOD]) <= DDAR_MAXALGO)
                            fi->xfi_EntryInfo = ddartypes[header2[DDARC_RSRCMETHOD]];

                          xadConvertDates(XADM XAD_DATEMAC, EndGetM32(&header2[DDARC_MTIME]), XAD_GETDATEXADDATE,
                          &fi->xfi_Date, TAG_DONE);

                          err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, pos+rcsize+dcsize, TAG_DONE);
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
                  } /* check crunched header */
                } /* read crunched header */
              } /* check file header */
            } /* handle file */
          } /* check header id */
        } /* read file header */
      } /* main entry loop */
    } /* check archive header */
  } /* read archive header */

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

/*****************************************************************************/

XADUNARCHIVE(DiskDoubler)
{
  struct xadFileInfo *fi;
  struct xadInOut *io;
  xadUINT16 crc = 0;
  xadINT32 err;

  fi = ai->xai_CurFile;

  if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32, ai, xadMasterBase)))
  {
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_OutSize = fi->xfi_Size;

    switch(DDARPI(fi)->Method)
    {
    case 0:
      crc = 0;
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        crc += xadIOPutChar(io, xadIOGetChar(io));
      err = io->xio_Error;
      break;
    case 8:
      {
        xadUINT16 sub_method = 0;
        xadINT32 i;

        for(i = 0; i < 4*4; ++i)
          sub_method += (err = xadIOGetChar(io));
        io->xio_PutFunc = xadIOPutFuncRLE8182;
        if(!sub_method)
          err = DD_8(io, 0xFFF0);
        else /* RLE only */
        {
printf("8: RLE\n");
          while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
            xadIOPutChar(io, xadIOGetChar(io));
          err = io->xio_Error;
        }
      }
      break;
    default:
      err = XADERR_DATAFORMAT;
    }
    if(!err)
    {
      if(!(err = xadIOWriteBuf(io)))
      {
        if(DDARPI(fi)->Method)
          crc = io->xio_CRC16;

        if(crc != DDARPI(fi)->CRC)
          err = XADERR_CHECKSUM;
      }
    }
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

#define CPT_H1_SIGNATURE    0 /* == 1 */
#define CPT_H1_VOLUME       1 /* for multi-file archives */
#define CPT_H1_XMAGIC       2 /* verification multi-file consistency */
#define CPT_H1_IOFFSET      4 /* index offset */
#define CPT_HDR1SIZE        8

#define CPT_H2_HDRCRC       CPT_HDR1SIZE+0 /* header crc */
#define CPT_H2_ENTRIES      CPT_HDR1SIZE+4 /* number of index entries */
#define CPT_H2_COMMENT      CPT_HDR1SIZE+6 /* number of bytes comment that follow */
#define CPT_HDR2SIZE        7

#define CPT_VOLUME         0 /* for multi-file archives */
#define CPT_FILEPOS        1 /* position of data in file */
#define CPT_FTYPE          5 /* file type */
#define CPT_CREATOR        9
#define CPT_CREATIONDATE  13
#define CPT_MODDATE       17
#define CPT_FNDRFLAGS     21
#define CPT_FILECRC       23
#define CPT_CPTFLAG       27
#define CPT_RSRCLENGTH    29 /* decompressed lengths */
#define CPT_DATALENGTH    33
#define CPT_COMPRLENGTH   37 /* compressed lengths */
#define CPT_COMPDLENGTH   41
#define CPT_FILEHDRSIZE   45

/* file format is:
  cptArchiveHdr
    file1data
      file1RsrcFork
      file1DataFork
    file2data
      file2RsrcFork
      file2DataFork
    .
    .
    .
    fileNdata
      fileNRsrcFork
      fileNDataFork
  cptIndex
*/

/* cpt flags */
#define CPT_ENCRYPTED     1 /* file is encrypted */
#define CPT_RSRC_COMP     2 /* resource fork is compressed */
#define CPT_DATA_COMP     4 /* data fork is compressed */

struct CompactorPrivate {
  xadUINT32 CRC;
  xadUINT32 StartCRC;
  xadINT8  Method;
};

struct CompactorPrivDir {
  struct xadFileInfo *Parent;
  xadUINT16 NumEntries;
};

#define CPTPI(a)       ((struct CompactorPrivate *) ((a)->xfi_PrivateInfo))
#define CPTDIRPI(a)    ((struct CompactorPrivDir *) ((a)->xfi_PrivateInfo))

XADGETINFO(Compactor)
{
  xadINT32 err;
  struct xadFileInfo *fi, *lfi = 0, *ldir = 0;
  xadUINT8 header[CPT_HDR1SIZE+CPT_HDR2SIZE], data[CPT_FILEHDRSIZE+128];
  xadINT32 nsize;


  if(ai->xai_InSize < CPT_HDR1SIZE+CPT_HDR2SIZE)
    err = XADERR_FILESYSTEM;
  else if(!(err = xadHookAccess(XADM XADAC_READ, CPT_HDR1SIZE, header, ai)))
  {
    if(header[CPT_H1_SIGNATURE] != 1 || !header[CPT_H1_VOLUME]
    || (EndGetM32(header+CPT_H1_IOFFSET) + CPT_HDR2SIZE >= ai->xai_InSize))
      err = XADERR_FILESYSTEM;
    else if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetM32(header+CPT_H1_IOFFSET)
    -CPT_HDR1SIZE, 0, ai)))
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, CPT_HDR2SIZE, header+CPT_HDR1SIZE, ai)))
      {
printf("%lx, %ld, %ld, %08lx\n", ai->xai_InPos, ai->xai_InSize-ai->xai_InPos, EndGetM16(header+CPT_H2_ENTRIES),
EndGetM32(header+CPT_H2_HDRCRC));
/* check crc, sizes? */

        if(header[CPT_H2_COMMENT])
        {
          if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
          sizeof(struct CompactorPrivate), TAG_DONE)))
            return XADERR_NOMEMORY;
          else
          {
            xadConvertDates(XADM XAD_DATECURRENTTIME, XADTRUE, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

            fi->xfi_FileName = "CompactorInfo.TXT";
            fi->xfi_Size = fi->xfi_CrunchSize = header[CPT_H2_COMMENT];

            CPTPI(fi)->Method = -1;
            fi->xfi_DataPos = ai->xai_InPos;
            fi->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_INFOTEXT|XADFIF_NOFILENAME|XADFIF_EXTRACTONBUILD;

            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_Size, TAG_DONE);
          }
        }

        while(!err && ai->xai_InPos+5 < ai->xai_InSize)
        {
          if(ldir)
          {
            if(CPTDIRPI(ldir)->NumEntries)
              --CPTDIRPI(ldir)->NumEntries;
            else
            {
              while(ldir && !CPTDIRPI(ldir)->NumEntries)
                ldir = CPTDIRPI(ldir)->Parent;
            }
          }
          if(!(err = xadHookAccess(XADM XADAC_READ, 1, data, ai)))
          {
            nsize = data[0]&0x7F;
            if(data[0] &0x80) /* directory */
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, nsize+2, data, ai)))
              {
                if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                sizeof(struct CompactorPrivDir), TAG_DONE)))
                {
                  if((fi->xfi_FileName = MACname(xadMasterBase, ldir, data, nsize, 0)))
                  {
                    fi->xfi_Flags |= XADFIF_DIRECTORY|XADFIF_NODATE;
                    xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
                    CPTDIRPI(fi)->Parent = ldir;
                    CPTDIRPI(fi)->NumEntries = EndGetM16(data+nsize);
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
            }
            else
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, nsize+CPT_FILEHDRSIZE, data, ai)))
              {
                xadUINT32 csize, dcsize, rcsize, flags;

                for(csize = 0; csize < 8; ++csize)
                {
                  if(data[nsize+CPT_FTYPE+csize] < 0x20 || data[nsize+CPT_FTYPE+csize] > 0x7E)
                    data[nsize+CPT_FTYPE+csize] = '?';
                }
                csize = SITmakecomment(data+nsize+CPT_FTYPE, EndGetM16(data+nsize+CPT_FNDRFLAGS), 0, 0, 0);
                rcsize = EndGetM32(data+nsize+CPT_COMPRLENGTH);
                dcsize = EndGetM32(data+nsize+CPT_COMPDLENGTH);
                flags = EndGetM16(data+nsize+CPT_CPTFLAG);

                if(rcsize)
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO,
                  XAD_OBJPRIVINFOSIZE, sizeof(struct CompactorPrivate), dcsize || !csize ?
                  TAG_IGNORE : XAD_OBJCOMMENTSIZE, csize, TAG_DONE)))
                  {
                    if((fi->xfi_FileName = MACname(xadMasterBase, ldir, data, nsize, 1)))
                    {
                      /* if comment field is zero, nothing is done! */
                      SITmakecomment(data+nsize+CPT_FTYPE, EndGetM16(data+nsize+CPT_FNDRFLAGS), 0,
                      0, fi->xfi_Comment);

                      fi->xfi_CrunchSize = rcsize;
                      fi->xfi_Size = EndGetM32(data+nsize+CPT_RSRCLENGTH);
                      fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACRESOURCE|XADFIF_EXTRACTONBUILD;
                      fi->xfi_DataPos = EndGetM32(data+nsize+CPT_FILEPOS);
                      lfi = fi;

                      CPTPI(fi)->CRC = EndGetM32(data+nsize+CPT_FILECRC);
                      CPTPI(fi)->StartCRC = 0xFFFFFFFF;
                      if(flags & CPT_ENCRYPTED)
                      {
                        ai->xai_Flags |= XADAIF_CRYPTED;
                        fi->xfi_Flags |= XADFIF_CRYPTED;
                      }
                      if(flags & CPT_RSRC_COMP)
                      {
                        CPTPI(fi)->Method = 1;
                        fi->xfi_EntryInfo = "LZH";
                      }
                      else
                      {
                        CPTPI(fi)->Method = 0;
                        fi->xfi_EntryInfo = "RLE";
                      }

                      xadConvertDates(XADM XAD_DATEMAC, EndGetM32(data+nsize+CPT_MODDATE), XAD_GETDATEXADDATE,
                      &fi->xfi_Date, TAG_DONE);

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

                if(!err && (dcsize || !rcsize))
                {
                  if((fi = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJPRIVINFOSIZE,
                  sizeof(struct CompactorPrivate), csize ? XAD_OBJCOMMENTSIZE :
                  TAG_IGNORE, csize, TAG_DONE)))
                  {
                    if((fi->xfi_FileName = MACname(xadMasterBase, ldir, data, nsize, 0)))
                    {
                      SITmakecomment(data+nsize+CPT_FTYPE, EndGetM16(data+nsize+CPT_FNDRFLAGS), 0,
                      0, fi->xfi_Comment);

                      fi->xfi_CrunchSize = dcsize;
                      fi->xfi_Size = EndGetM32(data+nsize+CPT_DATALENGTH);
                      fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_MACDATA|XADFIF_EXTRACTONBUILD;
                      fi->xfi_DataPos = EndGetM32(data+nsize+CPT_FILEPOS)+rcsize;

                      CPTPI(fi)->CRC = EndGetM32(data+nsize+CPT_FILECRC);
                      if(!rcsize)
                        CPTPI(fi)->StartCRC = 0xFFFFFFFF;
                      if(flags & CPT_ENCRYPTED)
                      {
                        ai->xai_Flags |= XADAIF_CRYPTED;
                        fi->xfi_Flags |= XADFIF_CRYPTED;
                      }
                      if(flags & CPT_DATA_COMP)
                      {
                        CPTPI(fi)->Method = 1;
                        fi->xfi_EntryInfo = "LZH";
                      }
                      else
                      {
                        CPTPI(fi)->Method = 0;
                        fi->xfi_EntryInfo = "RLE";
                      }

                      if(rcsize)
                      {
                        fi->xfi_MacFork = lfi;
                        lfi->xfi_MacFork = fi;
                      }

                      xadConvertDates(XADM XAD_DATEMAC, EndGetM32(data+nsize+CPT_MODDATE), XAD_GETDATEXADDATE,
                      &fi->xfi_Date, TAG_DONE);

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
              }
            }
          }
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

XADUNARCHIVE(Compactor)
{
  struct xadFileInfo *fi;
  struct xadInOut *io;
  xadINT32 err;

  fi = ai->xai_CurFile;

  if(fi->xfi_Flags & XADFIF_CRYPTED) /* not yet */
    return XADERR_NOTSUPPORTED;

  if(CPTPI(fi)->Method == -1)
    err = xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC16, ai, xadMasterBase)))
  {
    io->xio_CRC32 = CPTPI(fi)->StartCRC;
    io->xio_InSize = fi->xfi_CrunchSize;
    io->xio_PutFunc = xadIOPutFuncRLE8182;
    io->xio_OutSize = fi->xfi_Size;

    switch(CPTPI(fi)->Method)
    {
    case 0:
      while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        xadIOPutChar(io, xadIOGetChar(io));
      err = io->xio_Error;
      break;
    case 1:
      err = DD_8(io, 0x1FFF0);
      break;
    default:
      err = XADERR_DATAFORMAT;
    }
    if(!err)
    {
      if(!(err = xadIOWriteBuf(io)))
      {
        /* The CRC is done using both parts. Thus CRC check is done
           on data part only using the CRC from previous run (if exists). */
        if(fi->xfi_MacFork && (fi->xfi_Flags & XADFIF_MACRESOURCE))
        {
          CPTPI(fi->xfi_MacFork)->StartCRC = io->xio_CRC32;
        }
        else if(CPTPI(fi)->StartCRC && io->xio_CRC32 != CPTPI(fi)->CRC)
          err = XADERR_CHECKSUM;
      }
    }
    xadFreeObjectA(XADM io, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/*****************************************************************************/

XADCLIENT(Compactor) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  COMPACTOR_VERSION,
  COMPACTOR_REVISION,
  9,
  XADCF_FILESYSTEM|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  0/*XADCID_COMPACTOR*/,
  "Compactor",
  0,
  XADGETINFOP(Compactor),
  XADUNARCHIVEP(Compactor),
  NULL
};

XADCLIENT(DiskDoubler2) {
  (struct xadClient *) &Compactor_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DISKDOUBLER2_VERSION,
  DISKDOUBLER2_REVISION, 4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  0/*XADCID_DISKDOUBLERNEW*/,
  "DiskDoubler 2",
  XADRECOGDATAP(DiskDoubler2),
  XADGETINFOP(DiskDoubler2),
  XADUNARCHIVEP(DiskDoubler),
  NULL
};

XADCLIENT(DiskDoubler1S) {
  (struct xadClient *) &DiskDoubler2_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DISKDOUBLER1S_VERSION,
  DISKDOUBLER1S_REVISION,
  4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  0/*XADCID_DISKDOUBLEROLDSINGLE*/,
  "DiskDoubler 1 Single",
  XADRECOGDATAP(DiskDoubler1S),
  XADGETINFOP(DiskDoubler1S),
  XADUNARCHIVEP(DiskDoubler),
  NULL
};

XADFIRSTCLIENT(DiskDoubler1) {
  (struct xadClient *) &DiskDoubler1S_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  DISKDOUBLER1_VERSION,
  DISKDOUBLER1_REVISION,
  4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREEXADSTRINGS,
  0/*XADCID_DISKDOUBLEROLD*/,
  "DiskDoubler 1",
  XADRECOGDATAP(DiskDoubler1),
  XADGETINFOP(DiskDoubler1),
  XADUNARCHIVEP(DiskDoubler),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(DiskDoubler1)

#endif /* XADMASTER_DISKDOUBLER_C */
