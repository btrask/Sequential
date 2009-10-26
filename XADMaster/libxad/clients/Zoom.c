#ifndef XADMASTER_ZOOM_C
#define XADMASTER_ZOOM_C


/*  $Id: Zoom.c,v 1.13 2005/06/23 14:54:41 stoecker Exp $
    Zoom disk archiver client

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
#include "xadCRC_1021.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      13
#endif

XADCLIENTVERSTR("Zoom 1.11 (21.2.2004)")

#define ZOOM_VERSION            1
#define ZOOM_REVISION           11
#define ZOOM5_VERSION           ZOOM_VERSION
#define ZOOM5_REVISION          ZOOM_REVISION
#define LHPAK_VERSION           ZOOM_VERSION
#define LHPAK_REVISION          ZOOM_REVISION
#define PCOMP_VERSION           ZOOM_VERSION
#define PCOMP_REVISION          ZOOM_REVISION
#define SOMNI_VERSION           ZOOM_VERSION
#define SOMNI_REVISION          ZOOM_REVISION
#define LHSFX_VERSION           ZOOM_VERSION
#define LHSFX_REVISION          ZOOM_REVISION

#define BOXSIZE         5
#define TRACKSIZE       (512*11*2)

struct TrackHeader
{
  xadINT8       Tracks[BOXSIZE];
  xadUINT32     Bits[BOXSIZE];
  xadUINT16     Length;
  xadUINT16     SqueezedLength;
  xadUINT16     FatLength;
  xadUINT16     Packed;
  xadUINT32     CRC;
  xadUINT16     Bytes;
};

struct OldTrackHeader
{
  xadINT8       Tracks[BOXSIZE];
  xadUINT32     Bits[BOXSIZE];
  xadUINT16     Length;                 /* entry length */
  xadUINT8      Bytes[2];
  xadUINT16     SqueezedLength;         /* length after RLE */
  xadUINT16     FatLength;              /* Original size */
  xadUINT16     Packed;                 /* LH packed ? */
  xadUINT16     CRC;
};

struct ZoomNote
{
  xadUINT8 DateStamp[12];
  xadUINT8 Note[80];
};

struct ZoomHeader
{
  xadUINT32     HeaderID;       /* Should be `ZOM5' */
  xadINT8       From;
  xadINT8       To;             /* First and last track. */
  xadINT8       Version;        /* Which Zoom version created this file. */
  xadINT8       OnlyTracks;     /* TRUE if file only contains whole tracks. */
  xadUINT32     Flags;          /* Miscellaneous flag bits. */
  /* FIXME */
  xadUINT8      Date[12];       /* File creation date. */
  xadUINT32     TextLength;     /* Size of text attached to this file. */
  xadUINT32     PackedLength;   /* Compressed size of text attached to this file. */
  xadINT32      NoteOffset;     /* Notes attached to this file. */
  xadINT8       Encrypted;      /* TRUE if file is encrypted with password. */
  xadINT8       Format;
  xadINT16      Reserved1;      /* Reserved data. */
  xadUINT32     root;           /* Encryption key. */
  xadUINT32     Reserved2[7];   /* Reserved data. */
};

/* ZoomHeader->Flags */
#define USEHEADER                       1

/***************** LZSS Parameters ***************/

#define SeqMax          60              /* MaxSize of sequence  (look-ahead depth) */

/************* Huffman coding parameters *********/

#define AnzChar         (256+SeqMax+1)  /* character code (= 0..AnzChar-1) */
#define SizeTable       (AnzChar*2-1)   /* Size of table */
#define Root            (SizeTable-1)   /* root position */
#define frequenzlimit   0x8000          /* stop updating if cumulative frequency reaches to this value */

/* ------------- DECODE - TABELLE  (code,len) ----------------- */

static const xadUINT16 d_code_len[256] = {
  0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
  0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
  0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
  0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,

  0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,
  0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,0x0101,
  0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,
  0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,0x0201,
  0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,
  0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,0x0301,

  0x0402,0x0402,0x0402,0x0402,0x0402,0x0402,0x0402,0x0402,
  0x0502,0x0502,0x0502,0x0502,0x0502,0x0502,0x0502,0x0502,
  0x0602,0x0602,0x0602,0x0602,0x0602,0x0602,0x0602,0x0602,
  0x0702,0x0702,0x0702,0x0702,0x0702,0x0702,0x0702,0x0702,
  0x0802,0x0802,0x0802,0x0802,0x0802,0x0802,0x0802,0x0802,
  0x0902,0x0902,0x0902,0x0902,0x0902,0x0902,0x0902,0x0902,

  0x0A02,0x0A02,0x0A02,0x0A02,0x0A02,0x0A02,0x0A02,0x0A02,
  0x0B02,0x0B02,0x0B02,0x0B02,0x0B02,0x0B02,0x0B02,0x0B02,

  0x0C03,0x0C03,0x0C03,0x0C03,0x0D03,0x0D03,0x0D03,0x0D03,
  0x0E03,0x0E03,0x0E03,0x0E03,0x0F03,0x0F03,0x0F03,0x0F03,
  0x1003,0x1003,0x1003,0x1003,0x1103,0x1103,0x1103,0x1103,
  0x1203,0x1203,0x1203,0x1203,0x1303,0x1303,0x1303,0x1303,
  0x1403,0x1403,0x1403,0x1403,0x1503,0x1503,0x1503,0x1503,
  0x1603,0x1603,0x1603,0x1603,0x1703,0x1703,0x1703,0x1703,

  0x1804,0x1804,0x1904,0x1904,0x1A04,0x1A04,0x1B04,0x1B04,
  0x1C04,0x1C04,0x1D04,0x1D04,0x1E04,0x1E04,0x1F04,0x1F04,
  0x2004,0x2004,0x2104,0x2104,0x2204,0x2204,0x2304,0x2304,
  0x2404,0x2404,0x2504,0x2504,0x2604,0x2604,0x2704,0x2704,
  0x2804,0x2804,0x2904,0x2904,0x2A04,0x2A04,0x2B04,0x2B04,
  0x2C04,0x2C04,0x2D04,0x2D04,0x2E04,0x2E04,0x2F04,0x2F04,

  0x3005,0x3105,0x3205,0x3305,0x3405,0x3505,0x3605,0x3705,
  0x3805,0x3905,0x3A05,0x3B05,0x3C05,0x3D05,0x3E05,0x3F05,
};

struct LhData {
  xadUINT16 freq[SizeTable+1];
  xadINT16 par_back[AnzChar];
  xadINT16 parent[SizeTable];
  xadINT16 son[SizeTable];
};

static void Update(struct LhData *dat, xadINT16 pos)
{
  xadINT16 i, j, k, l;
  xadUINT16 *freq;

  i = dat->parent[pos];

  do
  {
    freq = &dat->freq[i];       /* Mutterknotenhäufigkeit */
    j = *freq;
    *(freq++) = ++j;            /* Mutterknotenhäfigkeit erhöhen */
    if(*(freq++) < j)           /* hat der Eintrag die Continuität beeinträchtigt ? */
    {
      /* dann müssen Knoten vertauscht werden, d.h. die Knoten werden umgehängt */
      /* i == Swap Knoten 1 */

      while(*freq < j)
        ++freq;                         /* swap Knoten 2 suchen */

      --freq;                           /* freq == Swapknoten 2 */
      k = freq - dat->freq;             /* k == (offset zum Swap 2) */
      dat->freq[i] = *freq;             /* freq(knot1)=freq(knot2) */
      *freq = j;                        /* freq(knot2)=freq(knot1) */
      if((j = dat->son[i]) >= 0)        /* wenn der l-sohn vom old knot ein code ist */
        dat->parent[j+1] = k;           /* dann neuer r-Vater=new knot */
      dat->parent[j] = k;               /* jf. neuer l-vater=new knot */
      if((l = dat->son[k]) >= 0)        /* wenn der l-sohn vom new knot ein code ist */
        dat->parent[l+1] = i;           /* dann neuer r-Vater=old knot */
      dat->son[k] = j;                  /* l-sohn(new knot)=l-sohn(old k) */
      dat->parent[l] = i;               /* l-vater von sohn vom new knot = old knot */
      dat->son[i] = l;                  /* l-sohn vom old knot= l-sohn vom new knot */
      i = dat->parent[k];               /* vater holen */
    }
    else
      i = dat->parent[i];               /* vater holen */
  } while(i);                           /* bis Root erreicht ist. */
}

static void InitFreqTree(struct LhData *dat)
{
  /* Ersteinmal müssen die Codes '-parent' in Verbindung mit 'son' gesetzt werden.
     Außerdem wird die globale Häufigkeit 'freq' auf eins initialisiert. */

  xadINT16 i, j, k;

  k = 0;        /* Zeigerwert von parent auf son */
  j = -1;       /* Zeigerwert von son auf parent */
  for(i = 0; i < AnzChar; ++i)
  {
    dat->freq[i] = 1;                   /* Häufigkeit = 1 */
    dat->son[i] = j--;                  /* leafs = SizeTable. SizeTable.+1.. */
    dat->parent[-i-1] = k++;            /* parentpointer initialisieren (T*2) */
  }

  k = 0;
  j = AnzChar;
  for(i = 0; i < Root-AnzChar+1; ++i)
  {
    dat->freq[j] = dat->freq[k] + dat->freq[k+1];
    dat->son[j] = k;                                    /* SONeinträge (ab AnzChar.) */
    dat->parent[k] = dat->parent[k+1] = j++;            /* Parenteinträge (ab 0.) */
    k += 2;
  }

  dat->freq[SizeTable] = 0xFFFF;
  dat->parent[Root] = 0;
}

static xadINT32 LhDecode(xadUINT16 *src, xadUINT32 srcsize, xadSTRPTR dest, xadUINT32 destsize, struct xadMasterBase *xadMasterBase)
{
  xadINT16 bitindex, i, j, k, l;
  xadINT32 err = 0;
  xadUINT32 bitbuf;
  xadUINT8 *str;
  struct LhData *dat;
  xadUINT16 *srcend;

  srcend = (xadUINT16 *) (((xadSTRPTR) src) + srcsize);

  if(!(dat = (struct LhData *) xadAllocVec(XADM sizeof(struct LhData), XADMEMF_ANY)))
    return XADERR_NOMEMORY;

  InitFreqTree(dat);

  bitindex = 15;                /* getlen = bitindex */
  bitbuf = *(src++);            /* prestore getbuf */
  while(!err)
  {
    /**** search FreqTree from root to leaves   ****/
    /**** choose node son() IF  bit == 0        ****/
    /**** else choose son()+1 IF  bit == 1      ****/

    l = dat->son[Root];         /* son(R)  erster Ast */
    do
    {
      l = dat->son[l + ((bitbuf&0x8000) ? 1 : 0)];
      bitbuf <<= 1;
      if(!(bitindex--))         /* bitcounter runterzählen */
      {
        bitindex = 15;
        bitbuf = *(src++);
      }
    } while(l >= 0);

    if(dat->freq[Root] != frequenzlimit)
      Update(dat, l);

    if(l >= -256)
    {
      if(!(destsize--))
        err = XADERR_DECRUNCH;
      else
        *(dest++) = -l - 1;
    }
    else if(l <= -(255+SeqMax+1)-1)
      break;    /* this is the leave point */
    else /***** DecodePosition *****/
    {
      bitindex -= 7;
      if(bitindex < 0)
      {
        bitbuf = (bitbuf << 8) | (*(src++) << -bitindex);
        bitindex += 15;                         /* correct bitindex */
        i = (xadUINT8) (bitbuf >> 16);                  /* get byte */
      }
      else
      {
        i = (xadUINT8) (bitbuf>>8);     /* get upper byte */
        bitbuf <<= 8;   /* shift byte out */
        if(!(bitindex--))
        {
          bitbuf = *(src++);
          bitindex = 15;
        }
      }

      k = d_code_len[i];
      j = (xadUINT8) k;         /* j: Anzahl der kommenden Bits */
      k = (k&0xFF00) >> 2;      /* k = (d_code(i) << 6) */

      do
      {
        i <<= 1;
        if(bitbuf & 0x8000)     /* bit einfuegen */
          ++i;
        bitbuf <<= 1;           /* und bit rausschieben */
        if(!(bitindex--))
        {
          bitbuf = *(src++);
          bitindex = 15;
        }
      } while(j--);

      str = (xadUINT8 *) dest - ((i&0x3F)|k);   /* source-position */

      l = -(l+256);
      if(l > destsize)
        err = XADERR_DECRUNCH;
      else
      {
        destsize -= l;
        while(l--)
          *(dest++) = *(str++);
      }
    }
  }
  if(src != srcend || destsize)
    err = XADERR_DECRUNCH;
  xadFreeObjectA(XADM dat, 0);

  return err;
}


static xadUINT32 NewKey(xadSTRPTR Key)
{
  xadUINT32     root, i = 1;

  root = *Key; /* use first entry as init value */

  while(Key[i])
    root *= Key[i++];

  return root;
}


static void CryptKeyBlock(xadSTRPTR Block, xadINT32 Length, xadSTRPTR Key)
{
  xadUINT32     root, i = 0;

  root = NewKey(Key);
  while(Length--)
  {
    root = (((root * 4253261) & 0xFFFFFF) + 372837) & 0xFFFFFF;
    *Block++ ^= (root % 256) ^ (~Key[i++]);
    if(!Key[i])
      i = 0;
  }
}

/* oldmode == 100, 101 means direct CRC check, 200 no check */
static xadINT32 CheckCRC(xadPTR buf, xadUINT32 size, xadUINT32 oldmode, xadUINT32 CRC,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadINT32 err = 0;

  if(oldmode == 200)
    err = 0;
  else if(oldmode == 100)
  {
    if(xadCalcCRC32(XADM XADCRC32_ID1, 0, size, buf) != CRC)
      err = XADERR_CHECKSUM;
  }
  else if(oldmode == 101)
  {
    if(xadCRC_1021_2(buf, size) != CRC)
      err = XADERR_CHECKSUM;
  }
  else if(oldmode)
  {
    xadUINT16 a;
    if(!(err = xadHookAccess(XADM XADAC_READ, 2, &a, ai)))
    {
      if(xadCRC_1021_2(buf, size) != a)

        err = XADERR_CHECKSUM;
    }
  }
  else
  {
    xadUINT32 a;
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, &a, ai)))
    {
      if(xadCalcCRC32(XADM XADCRC32_ID1, 0, size, buf) != a)
        err = XADERR_CHECKSUM;
    }
  }
  return err;
}

/* reads lh data from current input stream and stores a pointer to
decrunched file in *str */
static xadINT32 DoDecrunch(xadSTRPTR *str, xadUINT32 insize, xadUINT32 ressize, xadUINT32 oldmode,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase, xadUINT32 CRC)
{
  xadUINT16 *mem;
  xadINT32 err = XADERR_NOMEMORY;

  *str = 0;

  if((mem = (xadUINT16 *) xadAllocVec(XADM insize, XADMEMF_PUBLIC)))
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, insize, mem, ai)))
    {
      xadSTRPTR mem2;

      if(!(err = CheckCRC(mem, insize, oldmode, CRC, ai, xadMasterBase)))
      {
        if((mem2 = (xadSTRPTR) xadAllocVec(XADM ressize+1, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
        {
          if((err = LhDecode(mem, insize, mem2, ressize, xadMasterBase)))
            xadFreeObjectA(XADM mem2, 0);
          else
            *str = mem2;
        }
        else
          err = XADERR_NOMEMORY;
      } /* xadAllocVec */
    } /* Hook Read */
    xadFreeObjectA(XADM mem, 0);
  } /* xadAllocVec */

  return err;
}

static xadINT32 RunDecode(xadSTRPTR src, xadSTRPTR dest, xadUINT32 size)
{
  xadSTRPTR end;
  xadINT16 b, c, p;

  end = dest + (*(src++) << 16);        /* Get Size */
  end += *(src++) <<  8;
  end += *(src++);

  p = *(src++);         /* get packbyte */

  if(end-dest != size)
    return XADERR_DECRUNCH;

  while(dest < end)     /* reached end? */
  {
    b = *(src++);       /* get next byte */
    if(b == p)          /* is packbyte ? */
    {
      if((b = *(src++)))
      {
        c = *(src++);   /* get byte of sequenz */

        if(++b > end-dest)      /* prevent overwriting */
          b = end-dest;

        while(b--)      /* write it */
          *(dest++) = c;
      }
      else
        *(dest++) = p;  /* write packbyte one time */
    }
    else
      *(dest++) = b;    /* write byte */
  }

  return 0;
}

static xadINT32 RunDecodeOld(xadSTRPTR src, xadSTRPTR dest, xadUINT32 size, xadUINT32 srcsize, xadUINT16 Bytes)
{
  xadSTRPTR s, d;
  xadUINT32 cnt;
  xadUINT8 b1, b2, b;

  b1 = Bytes>>8;
  b2 = Bytes;

  s = src + srcsize;
  d = dest + size;

  while(d > dest)       /* reached end? */
  {
    b = *(--s);
    if(b == b1)
    {
      if(!(cnt = *(--s)))
        cnt = 0x100;
      b = *(--s);

      if(cnt > d-dest)
        return XADERR_DECRUNCH;

      while(cnt--)
        *(--d) = b;
    }
    else if(b == b2)
    {
      if(!(cnt = *(--s)))
        cnt = 0x100;
      while(cnt--)
        *(--d) = 0;
    }
    else
      *(--d) = b;       /* write byte */
  }

  if(s < src)
    return XADERR_DECRUNCH;
  return 0;
}

static xadINT32 DoDecrunchZoom(xadSTRPTR *str, struct TrackHeader *th, xadUINT32 oldmode, xadSTRPTR pwd,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadPTR mem;
  xadINT32 err = XADERR_NOMEMORY;

  *str = 0;

  if((mem = xadAllocVec(XADM th->Length, XADMEMF_PUBLIC)))
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, th->Length, mem, ai)))
    {
      if(!(err = CheckCRC(mem, th->Length, oldmode ? 101 : 100, th->CRC, ai, xadMasterBase)))
      {
        if(pwd)
          CryptKeyBlock(mem, th->Length, pwd);

        if(th->Packed)
        {
          xadSTRPTR mem2;
          xadUINT32 size;

          if(!(size = th->SqueezedLength))
            size = th->FatLength;

          if((mem2 = (xadSTRPTR) xadAllocVec(XADM size, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
          {
            err = LhDecode(mem, th->Length, mem2, size, xadMasterBase);
            xadFreeObjectA(XADM mem, 0);
            mem = mem2;
          }
          else
            err = XADERR_NOMEMORY;
        }

        if(!err && th->SqueezedLength)
        {
          xadPTR mem2;
          if((mem2 = xadAllocVec(XADM th->FatLength, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
          {
            if(oldmode)
              err = RunDecodeOld(mem, mem2, th->FatLength, th->SqueezedLength, th->Bytes);
            else
              err = RunDecode(mem, mem2, th->FatLength);
            xadFreeObjectA(XADM mem, 0);
            mem = mem2;
          }
          else
            err = XADERR_NOMEMORY;
        }
      } /* CRC check */
    } /* read data */
  } /* allocate buffer */

  if(mem)
  {
    if(err)
      xadFreeObjectA(XADM mem, 0);
    else
      *str = mem;
  }
  return err;
}

static void ClearMemLong(xadUINT32 *a, xadUINT32 size)
{
  while(size--)
    *(a++) = 0;
}

static void UnPackTrack(struct TrackHeader *th, xadSTRPTR buf, xadSTRPTR tmp, xadUINT32 pos,
struct xadMasterBase *xadMasterBase)
{
  xadINT32 i, j = 0, k, l;

  for(i = 0; i < pos; ++i)
  {
    l = th->Bits[i];
    for(k = 0; k < 22; ++k)
    {
      if(l & 1)
        ++j;
      l >>= 1;
    }
  }

  buf += j*512;

  l = th->Bits[pos];
  for(i = j = 0; i < 22 ; ++i)
  {
    if(l & (1<<i))
      xadCopyMem(XADM buf + 512*(j++), tmp + (512*i), 512);
    else
      ClearMemLong((xadUINT32 *) (tmp+(512*i)), 512/4);
  }
}

/**************************************************************************/

XADRECOGDATA(Zoom5)
{
  if(data[0] == 'Z' && data[1] == 'O' && data[2] == 'M' && data[3] == '5'
  && xadCalcCRC32(XADM XADCRC32_ID1, 0, sizeof(struct ZoomHeader), data)
  == (EndGetM32(data+72)))
    return 1;
  else
    return 0;
}

XADRECOGDATA(Zoom)
{
  if(data[0] == 'Z' && data[1] == 'O' && data[2] == 'O' && data[3] == 'M'
  && data[6] >= 3 && xadCRC_1021_2(data, sizeof(struct ZoomHeader)) ==
  EndGetM16(data+72))
    return 1;
  else
    return 0;
}

/**************************************************************************/

XADGETINFO(Zoom)
{
  struct xadDiskInfo *di;
  xadINT32 ret = XADERR_NOMEMORY;
  xadINT32 oldmode = 0;

  if((di = (struct xadDiskInfo *) xadAllocObject(XADM XADOBJ_DISKINFO,
  XAD_OBJPRIVINFOSIZE, sizeof(struct ZoomHeader), TAG_DONE)))
  {
    struct ZoomHeader *zh;

    ai->xai_DiskInfo = di;
    zh = (struct ZoomHeader *) di->xdi_PrivateInfo;

    if(!(ret = xadHookAccess(XADM XADAC_READ, sizeof(struct ZoomHeader), zh, ai)))
    {
      if(zh->HeaderID == 0x5A4F4F4D)
        oldmode = 1;

      if(!(ret = CheckCRC(zh, sizeof(struct ZoomHeader), oldmode, 0, ai,
      xadMasterBase)))
      {
        if(zh->Encrypted)
        {
          di->xdi_Flags |= XADDIF_CRYPTED;
          ai->xai_Flags |= XADAIF_CRYPTED;
        }

        di->xdi_EntryNumber = 1;
        di->xdi_SectorSize = 512;
        di->xdi_Cylinders = 80;
        di->xdi_Heads = 2;
        di->xdi_TrackSectors = 11;
        di->xdi_CylSectors = 22;
        di->xdi_TotalSectors = 80 * 22;
        di->xdi_LowCyl = 0;
        di->xdi_HighCyl = 79;

        if(zh->TextLength)
        {
          struct xadTextInfo *ti;

          if((ti = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
          {
            ti->xti_Size = zh->TextLength;
            if((ret = DoDecrunch(&ti->xti_Text, zh->PackedLength, zh->TextLength,
            oldmode, ai, xadMasterBase, 0)))
              xadFreeObjectA(XADM ti, 0);
            else
              di->xdi_TextInfo = ti;
          }
          else
            ret = XADERR_NOMEMORY;
        }
        di->xdi_DataPos = ai->xai_InPos;
        if(zh->Flags & USEHEADER)
          di->xdi_Flags |= XADDIF_SECTORLABELS;
        di->xdi_Flags |= XADDIF_SEEKDATAPOS;

        if(zh->NoteOffset)
        {
          struct ZoomNote zn;

          if(xadHookAccess(XADM XADAC_INPUTSEEK, zh->NoteOffset - ai->xai_InPos, 0, ai))
            ai->xai_Flags |= XADAIF_FILECORRUPT;
          else if(!(ret = xadHookAccess(XADM XADAC_READ, sizeof(struct ZoomNote), &zn, ai)))
          {
            struct xadTextInfo *ti;
            if((ti = (struct xadTextInfo *) xadAllocObjectA(XADM XADOBJ_TEXTINFO, 0)))
            {
              xadSTRPTR buf;
              if(di->xdi_TextInfo)
                di->xdi_TextInfo->xti_Next = ti;
              else
                di->xdi_TextInfo = ti;

              if((buf = (xadSTRPTR) xadAllocVec(XADM 80+22, XADMEMF_CLEAR|XADMEMF_PUBLIC)))
              {
                struct xadDate xd;
                xadSTRPTR Block;
                xadINT32 Tmp, Length, root;

                Block = (xadSTRPTR) zn.Note;
                Length = 80;
                root = EndGetM32(zn.DateStamp+8);

                while(Length-- > 0)
                {
                  root = (((root * EndGetM32(zn.DateStamp+4)) & 0xFFFFFF)
                  + EndGetM32(zn.DateStamp)) & 0xFFFFFF;
                  Tmp = root % 256;
                  *Block++ ^= Tmp;
                }

                ti->xti_Text = buf;
                ti->xti_Size = 80+21;
                xadConvertDates(XADM XAD_DATEDATESTAMP, &zn.DateStamp,
                XAD_GETDATEXADDATE, &xd, TAG_DONE);
                sprintf(buf, "%02d.%02d.%04d %02d:%02d:%02d\n\n",
                (xadUINT32)xd.xd_Day, (xadUINT32)xd.xd_Month,
                (xadUINT32)xd.xd_Year, (xadUINT32)xd.xd_Hour,
                (xadUINT32)xd.xd_Minute, (xadUINT32)xd.xd_Second);

                xadCopyMem(XADM (xadPTR) &zn.Note, buf+21, 80);
              }
              else
                ret = XADERR_NOMEMORY;
            }
            else
              ret = XADERR_NOMEMORY;
          } /* xadHokkAccess */
        } /* zh->NoteOffset */
      } /* CheckCRC */
    } /* XADAC_READ */
  } /* xadAllocObject */

  return ret;
}

static xadINT32 GetTrackHead(struct xadArchiveInfo *ai, struct TrackHeader *th,
xadUINT32 oldmode, xadUINT32 useheader, struct xadMasterBase *xadMasterBase)
{
  xadINT32 err;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct TrackHeader)-2, th, ai)))
  {
    if(!(err = CheckCRC(th, sizeof(struct TrackHeader)-2, oldmode, 0, ai, xadMasterBase)))
    {
      xadUINT32 i, j = 0, k, l;

      if(oldmode)
      {
        th->Bytes = th->SqueezedLength;
        th->SqueezedLength = th->FatLength;
//        th->FatLength = th->Packed;
        th->Packed = th->CRC >> 16;
        th->CRC = th->CRC & 0xFFFF;
      }

      /* as Zoom sets wrong FatLength sometimes, we need to recalculate it! */
      for(i = 0; i < BOXSIZE && th->Tracks[i] != -1; ++i)
      {
        l = th->Bits[i];
        for(k = 0; k < 22; ++k)
        {
          if(l & 1)
            ++j;
          l >>= 1;
        }
      }
      th->FatLength = j * (useheader ? 512 + 16 : 512);
    }
  }

  return err;
}

XADUNARCHIVE(Zoom)
{
  struct xadDiskInfo *di;
  struct ZoomHeader *zh;
  struct TrackHeader th;
  xadINT32 err = 0, i, j = -1, readdata = 0, oldmode;
  xadSTRPTR pwd = 0, buf = 0, ebuf;

  di = ai->xai_CurDisk;
  zh = (struct ZoomHeader *) di->xdi_PrivateInfo;
  oldmode = (zh->HeaderID == 0x5A4F4F4D);

  if(di->xdi_Flags & XADDIF_CRYPTED)
  {
    if(!ai->xai_Password || NewKey(ai->xai_Password) != zh->root)
      return XADERR_PASSWORD;
    else
      pwd = ai->xai_Password;
  }

  if(!(ebuf = xadAllocVec(XADM TRACKSIZE, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  for(i = ai->xai_LowCyl; !err && i <= ai->xai_HighCyl; ++i)
  {
    if(j >= 0 || !(err = GetTrackHead(ai, &th, oldmode, zh->Flags & USEHEADER, xadMasterBase)))
    {
      if(j == -1)
        j = 0;

      if(j > BOXSIZE || th.Tracks[j] > i)
      {
        ClearMemLong((xadUINT32 *) ebuf, TRACKSIZE/4);
        err = xadHookAccess(XADM XADAC_WRITE, TRACKSIZE, ebuf, ai);
      }
      else
      {
        if(th.Tracks[j] == i)
        {
          if(!readdata)
          {
            if(!(err = DoDecrunchZoom(&buf, &th, oldmode, pwd, ai, xadMasterBase)))
              readdata = 1;
          }
          if(readdata)
          {
            if(zh->Flags & USEHEADER)
              err = xadHookTagAccess(XADM XADAC_WRITE, TRACKSIZE,
              buf+(j * (TRACKSIZE + 22*16)), ai, XAD_SECTORLABELS,
              buf+(j * (TRACKSIZE + 22*16)) + TRACKSIZE, TAG_DONE);
            else
            {
              UnPackTrack(&th, buf, ebuf, j, xadMasterBase);
              err = xadHookAccess(XADM XADAC_WRITE, TRACKSIZE, ebuf, ai);
            }
          }
        }
        else
          --i;  /* was a back-track --> skipped, run this loop again */

        if(++j == BOXSIZE)
        {
          if(i < zh->To) /* if not, j runs over --> th is no longer accessable */
          {
            if(!readdata)
              err = xadHookAccess(XADM XADAC_INPUTSEEK, th.Length, 0, ai);
            else
              xadFreeObjectA(XADM buf, 0);
            j = -1; readdata = 0; buf = 0;
          }
        }
      } /* Tracks <= i */
    } /* read TrackHeader */
  } /* for loop */

  if(buf)
    xadFreeObjectA(XADM buf, 0);
  xadFreeObjectA(XADM ebuf, 0);

  return err;
}

/**************************************************************************/

struct LhPakEntry {
  xadUINT32     SkipSize;                       /*  0 */
  xadUINT16     CrunchedSize;                   /*  4 */
  xadUINT16     BlockNumber;                    /*  6 */
  xadUINT32     UnCrunchedSize;                 /*  8 */
  xadUINT32     CRC;                            /*  C */
  xadUINT32     CheckSum;                       /* 10 */
};

struct LhPakHead {
  struct LhPakEntry     Entry;          /*  0 */
  xadUINT32             Protection;     /* 14 */
  xadUINT32             Size;           /* 18 */
  xadUINT8  Date[12];           /* 1C */
  xadUINT16 pad1;                       /* 28 */
  xadUINT8              LengthFileName; /* 2A */
  xadUINT8              LengthComment;  /* 2B */
};

XADRECOGDATA(LhPak)
{
  if(((xadUINT32 *)data)[0] == 0x3F3 /* HUNK_HEADER */)
  {
    if(((xadUINT32 *)data)[10] == 0x4C534658 &&
       ((xadUINT32 *)data)[12] == 0x2C790000 &&
       ((xadUINT32 *)data)[14] == 0x01144AAA &&
       ((xadUINT32 *)data)[15] == 0x00AC6600 &&
       ((xadUINT32 *)data)[16] == 0x001841EA)
    {
      return 1;
    }
  }
  return 0;
}

/* maybe there are some errors in that code, not tested yet */
XADGETINFO(LhPak)
{
  xadINT32 err;
  xadUINT32 buffer[6];

  if(!(err = xadHookAccess(XADM XADAC_READ, 24, buffer, ai)))
  {
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x80+buffer[5]*4-24, 0, ai)))
    {
      struct xadFileInfo *fi = 0, *fi2;
      struct LhPakHead ph;
      xadINT32 goon = 1;
      xadUINT32 pos, num = 1;

      while(goon && !err)
      {
        pos = ai->xai_InPos;
        if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhPakHead), &ph, ai)))
        {
          if(!ph.Entry.SkipSize)
            goon = 0;
          if(!(fi2 = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
          4*ph.LengthFileName, ph.LengthComment ? XAD_OBJCOMMENTSIZE : TAG_DONE,
          4*ph.LengthComment, TAG_DONE)))
            err = XADERR_NOMEMORY;
          else
          {
            fi2->xfi_EntryNumber = num++;
            fi2->xfi_DataPos = pos;
            fi2->xfi_Flags |= XADFIF_SEEKDATAPOS;
            fi2->xfi_CrunchSize = ph.Entry.CrunchedSize;
            fi2->xfi_Protection = ph.Protection;
            xadConvertDates(XADM XAD_DATEDATESTAMP, &ph.Date, XAD_GETDATEXADDATE,
            &fi2->xfi_Date, TAG_DONE);
            fi2->xfi_Size = ph.Size;
            if(!(err = xadHookAccess(XADM XADAC_READ, 4*ph.LengthFileName, fi2->xfi_FileName, ai)))
            {
              if(!ph.LengthComment || !(err = xadHookAccess(XADM XADAC_READ, 4*ph.LengthComment, fi2->xfi_Comment, ai)))
              {
                xadUINT32 i = 0, j;

                for(pos = 0; pos < 11; ++pos)
                  i += ((xadUINT32 *) &ph)[pos];
                for(pos = 0; pos < ph.LengthFileName; ++pos)
                  i += ((xadUINT32 *) fi2->xfi_FileName)[pos];
                for(pos = 0; pos < ph.LengthComment; ++pos)
                  i += ((xadUINT32 *) fi2->xfi_Comment)[pos];
                if(i)
                  err = XADERR_CHECKSUM;
                else if(goon && !(err = xadHookAccess(XADM XADAC_INPUTSEEK, ph.Entry.SkipSize-
                sizeof(struct LhPakHead)-4*(ph.LengthFileName+ph.LengthComment), 0, ai)))
                {
                  i = ph.Entry.UnCrunchedSize;

                  while(i < ph.Size && !err && goon)
                  {
                    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhPakEntry), &ph, ai)))
                    {
                      for(j = pos = 0; pos < 5; ++pos)
                        j += ((xadUINT32 *) &ph)[pos];
                      if(j)
                        err = XADERR_CHECKSUM;
                      else
                      {
                        i += ph.Entry.UnCrunchedSize;
                        fi2->xfi_CrunchSize += ph.Entry.CrunchedSize;
                        if(!ph.Entry.SkipSize)
                          goon = 0;
                        else
                          err = xadHookAccess(XADM XADAC_INPUTSEEK, ph.Entry.SkipSize-sizeof(struct LhPakEntry), 0, ai);
                      }
                    }
                  }
                  if(!goon && i < ph.Size)
                    err = XADERR_ILLEGALDATA;
                }
              }
            }
            if(err)
              xadFreeObjectA(XADM fi2, 0);
            else if(fi)
            {
              fi->xfi_Next = fi2; fi = fi2;
            }
            else
              ai->xai_FileInfo = fi = fi2;
          }
        }
      }

      if(err && fi)
      {
        err = 0;
        ai->xai_Flags |= XADAIF_FILECORRUPT;
      }
    }
  }
  return err;
}

XADUNARCHIVE(LhPak)
{
  xadINT32 i, j, err;
  struct LhPakHead ph;
  xadSTRPTR buf;

  if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhPakHead), &ph, ai)))
  {
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, (ph.LengthFileName+ph.LengthComment)*4, 0, ai)))
    {
      i = 0;
      ph.Entry.SkipSize -= sizeof(struct LhPakHead) - sizeof(struct LhPakEntry) +
      (ph.LengthFileName+ph.LengthComment)*4;

      while(i < ph.Size && !err)
      {
        i += ph.Entry.UnCrunchedSize;
        if(!(err = DoDecrunch(&buf, ph.Entry.CrunchedSize, ph.Entry.UnCrunchedSize,
        100, ai, xadMasterBase, ph.Entry.CRC)))
        {
          err = xadHookAccess(XADM XADAC_WRITE, ph.Entry.UnCrunchedSize, buf, ai);
          xadFreeObjectA(XADM buf,0);
        }
        if(!err && i < ph.Size)
        {
          if((j = ph.Entry.SkipSize - ph.Entry.CrunchedSize - sizeof(struct LhPakEntry)))
            err = xadHookAccess(XADM XADAC_INPUTSEEK, j, 0, ai);
          if(!err)
            err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhPakEntry), &ph, ai);
        }
      }
    }
  }

  return err;
}

/**************************************************************************/

XADRECOGDATA(PCompPACK)
{
  if(*((xadUINT32 *) data) == 0x5041434B)
  {
    xadUINT32 i;

    for(i = 4; i < size; ++i)
    {
      if(data[i] == '\n')
      {
        if(++i < size && data[i]) /* too large file size */
          return 0;
        return 1;
      }
      else if((data[i] & 0x7F) < 32) /* printable ASCII name */
        return 0;
    }
    return 1;
  }
  return 0;
}

XADGETINFO(PCompPACK)
{
  xadINT32 err, i, j, k, num = 1;
  xadUINT8 buffer[512];
  struct xadFileInfo *fi = 0, *fi2;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 4, 0, ai)))
    return err;
  while(!err && ai->xai_InSize-ai->xai_InPos > 4)
  {
    if((j = ai->xai_InSize-ai->xai_InPos) > 512)
      j = 512;
    if(!(err = xadHookAccess(XADM XADAC_READ, j, buffer, ai)))
    {
      for(i = 0; i != j - 5 && buffer[i] != '\n'; ++i)
        ;
      if(buffer[i] == '\n')
      {
        k = (buffer[i+1]<<24)+(buffer[i+2]<<16)+(buffer[i+3]<<8)+buffer[i+4];

        j = ai->xai_InPos-j+i+5;

        if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, j-ai->xai_InPos+k, 0, ai)))
        {
          if((fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
          XAD_OBJNAMESIZE, i+1, TAG_DONE)))
          {
            fi2->xfi_DataPos = j; /* file position */
            fi2->xfi_CrunchSize = k;
            fi2->xfi_EntryNumber = num++;
            fi2->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS;
            for(j = 0; j < i; ++j)
              fi2->xfi_FileName[j] = buffer[j];
            err = xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
             &fi2->xfi_Date, TAG_DONE);
            if(k > 10)
            {
              i += 5;
              if(buffer[i] == 'L' && buffer[i+1] == 'H' && buffer[i+2] == 0 && buffer[i+6] == 0)
                k = (buffer[i+2]<<24)+(buffer[i+3]<<16)+(buffer[i+4]<<8)+buffer[i+5];
            }
            fi2->xfi_Size = k;
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
      else
        err = XADERR_ILLEGALDATA;
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return fi ? 0 : XADERR_ILLEGALDATA;
}

struct PCompData {
  xadUINT16  ID;
  xadUINT32  Size;
  xadUINT32  CrunchedSize;
  xadUINT32  CRC;
};

XADUNARCHIVE(PCompPACK)
{
  xadINT32 i, err;

  i = ai->xai_CurFile->xfi_Size;
  if(i == ai->xai_CurFile->xfi_CrunchSize)
    err = xadHookAccess(XADM XADAC_COPY, i, 0, ai);
  else
  {
    struct PCompData pc;
    xadSTRPTR buf;

    if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct PCompData), &pc, ai)))
    {
      if(!(err = DoDecrunch(&buf, pc.CrunchedSize, pc.Size, 100, ai, xadMasterBase,
      pc.CRC)))
      {
        err = xadHookAccess(XADM XADAC_WRITE, pc.Size, buf, ai);
        xadFreeObjectA(XADM buf, 0);
      }
    }
  }

  return err;
}

/**************************************************************************/

XADRECOGDATA(SOmni)
{
  if(((xadUINT32 *)data)[0] == 0x3F3 /* HUNK_HEADER */)
  {
    if(((xadUINT32 *)data)[10] == 0x42ADFFF4 &&
       ((xadUINT32 *)data)[12] == 0x00044EAE &&
       ((xadUINT32 *)data)[14] == 0x4AAC00AC &&
       ((xadUINT32 *)data)[15] == 0x67026014 &&
       ((xadUINT32 *)data)[16] == 0x41EC005C)
    {
      return 1;
    }
  }
  return 0;
}

XADGETINFO(SOmni)
{
  xadINT32 err, i, j, num = 1;
  xadUINT16 a;
  xadUINT8 buffer[10];
  struct xadFileInfo *fi = 0, *fi2;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x208, 0, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_READ, 4, &i, ai)))
    return err;

  if(i == 0x51CDFFFC)
  {
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x7A8-0x208-4, 0, ai)))
      return err;
  }
  else if(i == 0x76002C7A)
  {
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x744-0x208-4, 0, ai)))
      return err;
  }
  else
    return XADERR_ILLEGALDATA;

  if((err = xadHookAccess(XADM XADAC_READ, 2, &a, ai)))
    return err;
  if(a == 1) /* skip command line */
  {
    if((err = xadHookAccess(XADM XADAC_READ, 2, &a, ai)))
      return err;
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, a, 0, ai)))
      return err;
  }
  while(!err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 2, &a, ai)) && a)
    {
      if((fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
      XAD_OBJNAMESIZE, a+1, TAG_DONE)))
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, a, fi2->xfi_FileName, ai)))
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, 4, &i, ai)))
          {
            fi2->xfi_DataPos = ai->xai_InPos; /* file position */
            fi2->xfi_CrunchSize = i;
            j = i+2;
            fi2->xfi_EntryNumber = num++;
            fi2->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS;
            err = xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE,
            &fi2->xfi_Date, TAG_DONE);

            if(i > 10)
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, 10, buffer, ai)))
              {
                if(buffer[0] == 'L' && buffer[1] == 'H' && buffer[2] == 0 && buffer[6] == 0)
                  i = (buffer[2]<<24)+(buffer[3]<<16)+(buffer[4]<<8)+buffer[5];
                j -= 10;
              }
            }
            fi2->xfi_Size = i;

            if(!err)
              err = xadHookAccess(XADM XADAC_INPUTSEEK, j, 0, ai);
          }
        }

        if(err)
          xadFreeObjectA(XADM fi2, 0);
        else
        {
          if(fi)
            fi->xfi_Next = fi2;
          else
            ai->xai_FileInfo = fi2;
          fi = fi2;
        }
      }
      else
        err = XADERR_NOMEMORY;
    }
    else if(!a)
      break;
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return fi ? 0 : XADERR_ILLEGALDATA;
}

/**************************************************************************/

XADRECOGDATA(LhSFX)
{
  if(((xadUINT32 *)data)[0] == 0x3F3 /* HUNK_HEADER */)
  {
    if(((xadUINT32 *)data)[10] == 0x43F90000 &&
       ((xadUINT32 *)data)[12] == 0x00000318 &&
       ((xadUINT32 *)data)[14] == 0x02EC2C79 &&
       ((xadUINT32 *)data)[15] == 0x00000004 &&
       ((xadUINT32 *)data)[16] == 0x4EAEFDD8)
    {
      return 1;
    }
  }
  return 0;
}

struct LhSFXData {
  xadUINT32 Size;
  xadUINT32 CrSize;
  xadUINT32 pad; /* don't know what that is! */
  xadUINT8 Name[48];
};

XADGETINFO(LhSFX)
{
  xadINT32 err, i, j, num = 1;
  struct LhSFXData sf;
  struct xadFileInfo *fi = 0, *fi2;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x918, 0, ai)))
    return err;

  while(!err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, &i, ai)) && i != -1)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, sizeof(struct LhSFXData), &sf, ai)))
      {
        j = ai->xai_InPos;
        if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, sf.CrSize, 0, ai)))
        {
          for(i = 0; i < 48 && sf.Name[i]; ++i)
            ;
          if((fi2 = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
          i ? XAD_OBJNAMESIZE : TAG_IGNORE, i+1, TAG_DONE)))
          {
            if(i)
              xadCopyMem(XADM sf.Name, fi2->xfi_FileName, i);
            else
            {
              fi2->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai,
              XAD_EXTENSION, ".sfx", TAG_DONE);
              fi2->xfi_Flags |= XADFIF_NOFILENAME|XADFIF_XADSTRFILENAME;
            }
            fi2->xfi_DataPos = j; /* file position */
            fi2->xfi_CrunchSize = sf.CrSize;
            fi2->xfi_Size = sf.Size;
            fi2->xfi_EntryNumber = num++;
            fi2->xfi_Flags |= XADFIF_NODATE|XADFIF_SEEKDATAPOS;
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
    else if(i == -1)
      break;
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return fi ? 0 : XADERR_ILLEGALDATA;
}

XADUNARCHIVE(LhSFX)
{
  xadSTRPTR buf;
  xadINT32 err;

  if(!(err = DoDecrunch(&buf, ai->xai_CurFile->xfi_CrunchSize,
  ai->xai_CurFile->xfi_Size, 200, ai, xadMasterBase, 0)))
  {
    err = xadHookAccess(XADM XADAC_WRITE, ai->xai_CurFile->xfi_Size, buf, ai);
    xadFreeObjectA(XADM buf, 0);
  }

  return err;
}

XADCLIENT(LhSFX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SOMNI_VERSION,
  SOMNI_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_LHSFX,
  "LhSFX",
  XADRECOGDATAP(LhSFX),
  XADGETINFOP(LhSFX),
  XADUNARCHIVEP(LhSFX),
  NULL
};

XADCLIENT(SOmni) {
  (struct xadClient *) &LhSFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SOMNI_VERSION,
  SOMNI_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_SOMNI,
  "S-Omni",
  XADRECOGDATAP(SOmni),
  XADGETINFOP(SOmni),
  XADUNARCHIVEP(PCompPACK),
  NULL
};

XADCLIENT(PCompPACK) {
  (struct xadClient *) &SOmni_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  PCOMP_VERSION,
  PCOMP_REVISION,
  50,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_PCOMPARC,
  "PCompress PACK",
  XADRECOGDATAP(PCompPACK),
  XADGETINFOP(PCompPACK),
  XADUNARCHIVEP(PCompPACK),
  NULL
};

XADCLIENT(LhPak) {
  (struct xadClient *) &PCompPACK_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHPAK_VERSION,
  LHPAK_REVISION,
  100,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_LHPAK,
  "LhPak SFX",
  XADRECOGDATAP(LhPak),
  XADGETINFOP(LhPak),
  XADUNARCHIVEP(LhPak),
  NULL
};

XADCLIENT(Zoom5) {
  (struct xadClient *) &LhPak_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZOOM_VERSION,
  ZOOM_REVISION,
  76,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_ZOOM5,
  "Zoom 5",
  XADRECOGDATAP(Zoom5),
  XADGETINFOP(Zoom),
  XADUNARCHIVEP(Zoom),
  NULL
};

XADFIRSTCLIENT(Zoom) {
  (struct xadClient *) &Zoom5_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZOOM_VERSION,
  ZOOM_REVISION,
  76,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREETEXTINFOTEXT,
  XADCID_ZOOM,
  "Zoom",
  XADRECOGDATAP(Zoom),
  XADGETINFOP(Zoom),
  XADUNARCHIVEP(Zoom),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Zoom)

#endif /* XADMASTER_ZOOM_C */
