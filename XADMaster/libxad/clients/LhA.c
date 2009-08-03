#ifndef XADMASTER_LHA_C
#define XADMASTER_LHA_C

/*  $Id: LhA.c,v 1.15 2005/06/23 14:54:41 stoecker Exp $
    LhA file archiver client

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
#define XADIOGETBITSHIGH
#define XADIOGETBITSLOW
#include "xadIO.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      13
#endif

XADCLIENTVERSTR("LhA 1.13 (21.02.2004)")

#define LHA_VERSION             1
#define LHA_REVISION            13

#define ZOO_VERSION             LHA_VERSION
#define ZOO_REVISION            LHA_REVISION
#define SAVAGE_VERSION          LHA_VERSION
#define SAVAGE_REVISION         LHA_REVISION

#define LZHUFF0_METHOD          0x2D6C6830      /* -lh0- */
#define LZHUFF1_METHOD          0x2D6C6831      /* -lh1- */
#define LZHUFF2_METHOD          0x2D6C6832      /* -lh2- */
#define LZHUFF3_METHOD          0x2D6C6833      /* -lh3- */
#define LZHUFF4_METHOD          0x2D6C6834      /* -lh4- */
#define LZHUFF5_METHOD          0x2D6C6835      /* -lh5- */
#define LZHUFF6_METHOD          0x2D6C6836      /* -lh6- */
#define LZHUFF7_METHOD          0x2D6C6837      /* -lh7- */
#define LZHUFF8_METHOD          0x2D6C6838      /* -lh8- */
#define LARC_METHOD             0x2D6C7A73      /* -lzs- */
#define LARC5_METHOD            0x2D6C7A35      /* -lz5- */
#define LARC4_METHOD            0x2D6C7A34      /* -lz4- */
#define PMARC0_METHOD           0x2D706D30      /* -pm0- */
#define PMARC2_METHOD           0x2D706D32      /* -pm2- */

#define LHABUFFSIZE     10240

/* ------------------------------------------------------------------------ */

#define UCHAR_MAX       ((1<<(sizeof(xadUINT8)*8))-1)
#define MAX_DICBIT      16
#define CHAR_BIT        8
#define USHRT_BIT       16              /* (CHAR_BIT * sizeof(ushort)) */
#define MAXMATCH        256             /* not more than UCHAR_MAX + 1 */
#define NC              (UCHAR_MAX + MAXMATCH + 2 - THRESHOLD)
#define THRESHOLD       3               /* choose optimal value */
#define NPT             0x80
#define CBIT            9               /* $\lfloor \log_2 NC \rfloor + 1$ */
#define TBIT            5               /* smallest integer such that (1 << TBIT) > * NT */
#define NT              (USHRT_BIT + 3)
#define N_CHAR          (256 + 60 - THRESHOLD + 1)
#define TREESIZE_C      (N_CHAR * 2)
#define TREESIZE_P      (128 * 2)
#define TREESIZE        (TREESIZE_C + TREESIZE_P)
#define ROOT_C          0
#define ROOT_P          TREESIZE_C
#define N1              286             /* alphabet size */
#define EXTRABITS       8               /* >= log2(F-THRESHOLD+258-N1) */
#define BUFBITS         16              /* >= log2(MAXBUF) */
#define NP              (MAX_DICBIT + 1)
#define LENFIELD        4               /* bit size of length field for tree output */
#define MAGIC0          18
#define MAGIC5          19


struct LhADecrST {
  xadINT32              pbit;
  xadINT32              np;
  xadINT32              nn;
  xadINT32              n1;
  xadINT32              most_p;
  xadINT32              avail;
  xadUINT32             n_max;
  xadUINT16             maxmatch;
  xadUINT16     total_p;
  xadUINT16             blocksize;
  xadUINT16             c_table[4096];
  xadUINT16             pt_table[256];
  xadUINT16             left[2 * NC - 1];
  xadUINT16             right[2 * NC - 1];
  xadUINT16             freq[TREESIZE];
  xadUINT16             pt_code[NPT];
  xadINT16              child[TREESIZE];
  xadINT16              stock[TREESIZE];
  xadINT16              s_node[TREESIZE / 2];
  xadINT16              block[TREESIZE];
  xadINT16              parent[TREESIZE];
  xadINT16              edge[TREESIZE];
  xadUINT8              c_len[NC];
  xadUINT8              pt_len[NPT];
};

struct LhADecrData {
  struct xadInOut *io;
  xadSTRPTR        text;
  xadUINT16             DicBit;

  xadUINT16             bitbuf;
  xadUINT8      subbitbuf;
  xadUINT8      bitcount;
  xadUINT32             loc;
  xadUINT32             count;
  xadUINT32             nextcount;

  union {
    struct LhADecrST st;
  } d;
};

static void LHAfillbuf(struct LhADecrData *dat, xadUINT8 n) /* Shift bitbuf n bits left, read n bits */
{
  if(dat->io->xio_Error)
    return;

  while(n > dat->bitcount)
  {
    n -= dat->bitcount;
    dat->bitbuf = (dat->bitbuf << dat->bitcount) + (dat->subbitbuf >> (CHAR_BIT - dat->bitcount));
    dat->subbitbuf = xadIOGetChar(dat->io);
    dat->bitcount = CHAR_BIT;
  }
  dat->bitcount -= n;
  dat->bitbuf = (dat->bitbuf << n) + (dat->subbitbuf >> (CHAR_BIT - n));
  dat->subbitbuf <<= n;
}

static xadUINT16 LHAgetbits(struct LhADecrData *dat, xadUINT8 n)
{
  xadUINT16 x;

  x = dat->bitbuf >> (2 * CHAR_BIT - n);
  LHAfillbuf(dat, n);
  return x;
}

#define LHAinit_getbits(a)      LHAfillbuf((a), 2* CHAR_BIT)
/* this function can be replaced by a define!
static void LHAinit_getbits(struct LhADecrData *dat)
{
//  dat->bitbuf = 0;
//  dat->subbitbuf = 0;
//  dat->bitcount = 0;
  LHAfillbuf(dat, 2 * CHAR_BIT);
}
*/

/* ------------------------------------------------------------------------ */

static void LHAmake_table(struct LhADecrData *dat, xadINT16 nchar, xadUINT8 bitlen[], xadINT16 tablebits, xadUINT16 table[])
{
  xadUINT16 count[17];  /* count of bitlen */
  xadUINT16 weight[17]; /* 0x10000ul >> bitlen */
  xadUINT16 start[17];  /* first code of bitlen */
  xadUINT16 total;
  xadUINT32 i;
  xadINT32  j, k, l, m, n, avail;
  xadUINT16 *p;

  if(dat->io->xio_Error)
    return;

  avail = nchar;

  memset(count, 0, 17*2);
  for(i = 1; i <= 16; i++)
    weight[i] = 1 << (16 - i);

  /* count */
  for(i = 0; i < nchar; i++)
    count[bitlen[i]]++;

  /* calculate first code */
  total = 0;
  for(i = 1; i <= 16; i++)
  {
    start[i] = total;
    total += weight[i] * count[i];
  }
  if(total & 0xFFFF)
  {
    dat->io->xio_Error = XADERR_ILLEGALDATA;
    dat->io->xio_Flags |= XADIOF_ERROR;
    return;
  }

  /* shift data for make table. */
  m = 16 - tablebits;
  for(i = 1; i <= tablebits; i++) {
    start[i] >>= m;
    weight[i] >>= m;
  }

  /* initialize */
  j = start[tablebits + 1] >> m;
  k = 1 << tablebits;
  if(j != 0)
    for(i = j; i < k; i++)
      table[i] = 0;

  /* create table and tree */
  for(j = 0; j < nchar; j++)
  {
    k = bitlen[j];
    if(k == 0)
      continue;
    l = start[k] + weight[k];
    if(k <= tablebits)
    {
      /* code in table */
      for(i = start[k]; i < l; i++)
        table[i] = j;
    }
    else
    {
      /* code not in table */
      p = &table[(i = start[k]) >> m];
      i <<= tablebits;
      n = k - tablebits;
      /* make tree (n length) */
      while(--n >= 0)
      {
        if(*p == 0)
        {
          dat->d.st.right[avail] = dat->d.st.left[avail] = 0;
          *p = avail++;
        }
        if(i & 0x8000)
          p = &dat->d.st.right[*p];
        else
          p = &dat->d.st.left[*p];
        i <<= 1;
      }
      *p = j;
    }
    start[k] = l;
  }
}

/* ------------------------------------------------------------------------ */

static void LHAread_pt_len(struct LhADecrData *dat, xadINT16 nn, xadINT16 nbit, xadINT16 i_special)
{
  xadINT16 i, c, n;

  if(!(n = LHAgetbits(dat, nbit)))
  {
    c = LHAgetbits(dat, nbit);
    for(i = 0; i < nn; i++)
      dat->d.st.pt_len[i] = 0;
    for(i = 0; i < 256; i++)
      dat->d.st.pt_table[i] = c;
  }
  else
  {
    i = 0;
    while(i < n)
    {
      c = dat->bitbuf >> (16 - 3);
      if(c == 7)
      {
        xadUINT16 mask;

        mask = 1 << (16 - 4);
        while(mask & dat->bitbuf)
        {
          mask >>= 1;
          c++;
        }
      }
      LHAfillbuf(dat, (c < 7) ? 3 : c - 3);
      dat->d.st.pt_len[i++] = c;
      if(i == i_special)
      {
        c = LHAgetbits(dat, 2);
        while(--c >= 0)
          dat->d.st.pt_len[i++] = 0;
      }
    }
    while(i < nn)
      dat->d.st.pt_len[i++] = 0;
    LHAmake_table(dat, nn, dat->d.st.pt_len, 8, dat->d.st.pt_table);
  }
}

static void LHAread_c_len(struct LhADecrData *dat)
{
  xadINT16 i, c, n;

  if(!(n = LHAgetbits(dat, CBIT)))
  {
    c = LHAgetbits(dat, CBIT);
    for(i = 0; i < NC; i++)
      dat->d.st.c_len[i] = 0;
    for(i = 0; i < 4096; i++)
      dat->d.st.c_table[i] = c;
  }
  else
  {
    i = 0;
    while(i < n)
    {
      c = dat->d.st.pt_table[dat->bitbuf >> (16 - 8)];
      if(c >= NT)
      {
        xadUINT16 mask;

        mask = 1 << (16 - 9);
        do
        {
          if(dat->bitbuf & mask)
            c = dat->d.st.right[c];
          else
            c = dat->d.st.left[c];
          mask >>= 1;
        } while(c >= NT);
      }
      LHAfillbuf(dat, dat->d.st.pt_len[c]);
      if(c <= 2)
      {
        if(!c)
          c = 1;
        else if(c == 1)
          c = LHAgetbits(dat, 4) + 3;
        else
          c = LHAgetbits(dat, CBIT) + 20;
        while(--c >= 0)
          dat->d.st.c_len[i++] = 0;
      }
      else
        dat->d.st.c_len[i++] = c - 2;
    }
    while(i < NC)
      dat->d.st.c_len[i++] = 0;
    LHAmake_table(dat, NC, dat->d.st.c_len, 12, dat->d.st.c_table);
  }
}

static xadUINT16 LHAdecode_c_st1(struct LhADecrData *dat)
{
  xadUINT16 j, mask;

  if(!dat->d.st.blocksize)
  {
    dat->d.st.blocksize = LHAgetbits(dat, 16);
    LHAread_pt_len(dat, NT, TBIT, 3);
    LHAread_c_len(dat);
    LHAread_pt_len(dat, dat->d.st.np, dat->d.st.pbit, -1);
  }
  dat->d.st.blocksize--;
  j = dat->d.st.c_table[dat->bitbuf >> 4];
  if(j < NC)
    LHAfillbuf(dat, dat->d.st.c_len[j]);
  else
  {
    LHAfillbuf(dat, 12);
    mask = 1 << (16 - 1);
    do
    {
      if(dat->bitbuf & mask)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      mask >>= 1;
    } while(j >= NC);
    LHAfillbuf(dat, dat->d.st.c_len[j] - 12);
  }
  return j;
}

static xadUINT16 LHAdecode_p_st1(struct LhADecrData *dat)
{
  xadUINT16 j, mask;

  j = dat->d.st.pt_table[dat->bitbuf >> (16 - 8)];
  if(j < dat->d.st.np)
    LHAfillbuf(dat, dat->d.st.pt_len[j]);
  else
  {
    LHAfillbuf(dat, 8);
    mask = 1 << (16 - 1);
    do
    {
      if(dat->bitbuf & mask)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      mask >>= 1;
    } while(j >= dat->d.st.np);
    LHAfillbuf(dat, dat->d.st.pt_len[j] - 8);
  }
  if(j)
    j = (1 << (j - 1)) + LHAgetbits(dat, j - 1);
  return j;
}

static void LHAdecode_start_st1(struct LhADecrData *dat)
{
  if(dat->DicBit <= 13)
  {
    dat->d.st.np = 14;
    dat->d.st.pbit = 4;
  }
  else
  {
    if(dat->DicBit == 16)
      dat->d.st.np = 17; /* for -lh7- */
    else
      dat->d.st.np = 16;
    dat->d.st.pbit = 5;
  }
  LHAinit_getbits(dat);
//  dat->d.st.blocksize = 0; /* done automatically */
}


/**************************************************************************************************/

static xadINT32 LhA_Decrunch(struct xadInOut *io, xadUINT32 Method)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct LhADecrData *dd;
  xadINT32 err = 0;

  if((dd = xadAllocVec(XADM sizeof(struct LhADecrData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    void (*DecodeStart)(struct LhADecrData *);
    xadUINT16 (*DecodeC)(struct LhADecrData *);
    xadUINT16 (*DecodeP)(struct LhADecrData *);

    /* most often used stuff */
    dd->io = io;
    dd->DicBit = 13;
    DecodeStart = LHAdecode_start_st1;
    DecodeP = LHAdecode_p_st1;
    DecodeC = LHAdecode_c_st1;

    if(!err)
    {
      xadSTRPTR text;
      xadINT32 i, c, offset;
      xadUINT32 dicsiz;

      dicsiz = 1 << dd->DicBit;
      offset = (Method == LARC_METHOD || Method == PMARC2_METHOD) ? 0x100 - 2 : 0x100 - 3;

      if((text = dd->text = xadAllocVec(XADM dicsiz, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
/*      if(Method == LZHUFF1_METHOD || Method == LZHUFF2_METHOD || Method == LZHUFF3_METHOD ||
        Method == LZHUFF6_METHOD || Method == LARC_METHOD || Method == LARC5_METHOD)
*/
          memset(text, ' ', (size_t) dicsiz);

        DecodeStart(dd);
        --dicsiz; /* now used with AND */
        while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        {
          c = DecodeC(dd);
          if(c <= UCHAR_MAX)
          {
            text[dd->loc++] = xadIOPutChar(io, c);
            dd->loc &= dicsiz;
            dd->count++;
          }
          else
          {
            c -= offset;
            i = dd->loc - DecodeP(dd) - 1;
            dd->count += c;
            while(c--)
            {
              text[dd->loc++] = xadIOPutChar(io, text[i++ & dicsiz]);
              dd->loc &= dicsiz;
            }
          }
        }
        err = io->xio_Error;
        xadFreeObjectA(XADM text, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
    xadFreeObjectA(XADM dd, 0);
  }
  else
    err = XADERR_NOMEMORY;
  return err;
}

/****************************************************************************/

struct ZooDir {
  xadUINT8 ID[4];
  xadUINT8 EntryType;
  xadUINT8 Compression;
  xadUINT8 NextDir[4];
  xadUINT8 Offset[4];
  xadUINT8 Date[2];
  xadUINT8 Time[2];
  xadUINT8 CRC[2];
  xadUINT8 Size[4];
  xadUINT8 CompSize[4];
  xadUINT8 CompressVersion;
  xadUINT8 ExtractVersion;
  xadUINT8 Deleted;
  xadUINT8 Structure;
  xadUINT8 Commentoffset[4];
  xadUINT8 Commentlength[2];
  xadUINT8 Filename[13];
};

struct ZooPrivate {
  xadUINT16 CRC;
  xadUINT16 Method;
};


#define ZOOPI(a)        ((struct ZooPrivate *) ((a)->xfi_PrivateInfo))

XADGETINFO(Zoo)
{
  xadINT32 err, var;
  xadUINT8 data[4];
  struct ZooDir zd;
  struct xadFileInfo *fi;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 24, 0, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_READ, 4, data, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetI32(data)-28, 0, ai)))
    return err;
  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 51, &zd, ai)))
    {
      if((xadUINT32)EndGetM32(zd.ID) != 0xDCA7C4FD)
        err = XADERR_ILLEGALDATA;
      else if(!EndGetI32(zd.NextDir))
        break;
      else
      {
        xadUINT32 namesize = 0, commsize;
        xadSTRPTR varpart = 0, filename;

        filename = (xadSTRPTR) zd.Filename;
        while(namesize < 13 && filename[namesize])
          ++namesize;
        commsize = EndGetI16(zd.Commentlength);

        if(zd.EntryType == 2)
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, 2, data, ai)))
          {
            var = EndGetI16(data);
            if(var > 2)
            {
              if((varpart = (xadSTRPTR) xadAllocVec(XADM (xadUINT32)var+3, XADMEMF_PUBLIC)))
              {
                if(!(err = xadHookAccess(XADM XADAC_READ, (xadUINT32)var+3, varpart, ai)))
                {
                  if(varpart[3])
                  {
                    filename = varpart+5;
                    namesize = varpart[3]-1;
                  }
                  namesize += varpart[4]; /* directory size */
                }
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
        }

        if(!err)
        {
          if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
          XAD_OBJNAMESIZE, namesize+1, XAD_OBJPRIVINFOSIZE, sizeof(struct ZooPrivate),
          commsize ? XAD_OBJCOMMENTSIZE : TAG_DONE, commsize, TAG_DONE)))
          {
            if(commsize)
            {
              if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetI32(zd.Commentoffset)-ai->xai_InPos, 0, ai)))
                err = xadHookAccess(XADM XADAC_READ, commsize-1, fi->xfi_Comment, ai);
            }
            /* Every entry is preceeded by a header ( "@)#(\0" ) ! */
            ZOOPI(fi)->CRC = EndGetI16(zd.CRC);
            ZOOPI(fi)->Method = zd.Compression;
            fi->xfi_DataPos = EndGetI32(zd.Offset);
            fi->xfi_Size = EndGetI32(zd.Size);
            fi->xfi_CrunchSize = EndGetI32(zd.CompSize);
            if(varpart)
            {
              fi->xfi_Generation = EndGetI16(varpart+varpart[3]+varpart[4]+5+6);
              /* Protectionformat in EndGetI32(varpart+varpart[3]+varpart[4]+5+2) unknown! */
            }
            fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
            if(zd.Deleted)
              fi->xfi_Flags |= XADFIF_DELETED;
            if(varpart && varpart[4])
            {
              xadCopyMem(XADM varpart+varpart[3]+5, fi->xfi_FileName, (xadUINT32)varpart[4]);
              namesize -= varpart[4];
              fi->xfi_FileName[varpart[4]-1] = '/';
            }
            xadCopyMem(XADM filename, fi->xfi_FileName + (varpart ? varpart[4] : 0), namesize);

            xadConvertDates(XADM XAD_DATEMSDOS, (EndGetI16(zd.Date)<<16)+EndGetI16(zd.Time), XAD_GETDATEXADDATE,
            &fi->xfi_Date, TAG_DONE);

            if(!err)
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, EndGetI32(zd.NextDir), TAG_DONE);
            else
              xadFreeObjectA(XADM fi, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(varpart)
          xadFreeObjectA(XADM varpart, 0);
      }
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : XADERR_ILLEGALDATA);
}

XADRECOGDATA(Zoo)
{
  if(data[0] == 'Z' && data[1] == 'O' && data[2] == 'O' && data[3] == ' ' &&
  data[8] == ' ' && data[9] == 'A' && data[10] == 'r' && data[11] == 'c' &&
  data[12] == 'h' && data[13] == 'i' && data[14] == 'v' && data[15] == 'e' &&
  data[16] == '.' && data[17] == 0x1A && !data[18] && !data[19] &&
  data[20] == 0xDC && data[21] == 0xA7 && data[22] == 0xC4 && data[23] == 0xFD)
    return 1;
  else
    return 0;
}

/**************************************************************************************************/

#define ZOOBUFSIZE      8196
#define ZOOSTACKSIZE    8000
#define ZOOMAXMAX       8192        /* max code + 1 */
#define ZOOMAXBITS      13
#define ZOOCLEAR        256         /* clear code */
#define ZOOZ_EOF        257         /* end of file marker */
#define ZOOFIRST_FREE   258         /* first free code */

struct ZOOtabentry
{
  xadUINT16 next;
  xadUINT8 z_ch;
};

struct ZooData {
  struct ZOOtabentry  table[ZOOMAXMAX+10];
  xadUINT8               stack[ZOOSTACKSIZE+20];
};

static xadINT32 ZOOlzd(struct xadInOut *io)
{
  xadUINT16 max_code = 512, free_code = ZOOFIRST_FREE, stack_pointer = 0;
  xadUINT16 cur_code = 0, in_code, old_code = 0;
  xadINT8 fin_char = 0, k, nbits;
  struct ZooData *zd;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadINT32 err;

  if((zd = (struct ZooData *) xadAllocVec(XADM sizeof(struct ZooData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    nbits = 9;
    while(cur_code != ZOOZ_EOF && !io->xio_Error)
    {
      cur_code = xadIOGetBitsLow(io, nbits);
      if(cur_code != ZOOZ_EOF)
      {
        if(cur_code == ZOOCLEAR)
        {
          nbits = 9;
          max_code = 512;
          free_code = ZOOFIRST_FREE;

          fin_char = k = old_code = cur_code = xadIOGetBitsLow(io, nbits);
          if(cur_code != ZOOZ_EOF)
            xadIOPutChar(io, k);
        }
        else
        {
          in_code = cur_code;
          if(cur_code >= free_code) /* if code not in table (k<w>k<w>k) */
          {
            cur_code = old_code;                /* previous code becomes current */
            zd->stack[stack_pointer++] = fin_char;
          }

          while(cur_code > 255) /* if code, not character */
          {
            zd->stack[stack_pointer++] = zd->table[cur_code].z_ch;      /* push suffix char */
            cur_code = zd->table[cur_code].next;                        /* <w> := <w>.code */
          }

          xadIOPutChar(io, k = fin_char = cur_code);

          while(stack_pointer)
            xadIOPutChar(io, zd->stack[--stack_pointer]);

          zd->table[free_code].z_ch = k;                /* save suffix char */
          zd->table[free_code].next = old_code;         /* save prefix code */
          if(++free_code >= max_code)
          {
            if(nbits < ZOOMAXBITS)
            {
              nbits++;
              max_code = max_code << 1;         /* double max_code */
            }
          }
          old_code = in_code;
        }
      }
    }
    err = io->xio_Error;
    xadFreeObjectA(XADM zd, 0);
  }
  else
    err = XADERR_NOMEMORY;
  return err;
}

/****************************************************************************/

XADUNARCHIVE(Zoo)
{
  xadINT32 err;
  xadUINT16 crc = 0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(!ZOOPI(fi)->Method)
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC16, &crc, TAG_DONE);
  else
  {
    struct xadInOut *io;
    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32, ai, xadMasterBase)))
    {
      io->xio_InSize = fi->xfi_CrunchSize;
      io->xio_OutSize = fi->xfi_Size;
      switch(ZOOPI(fi)->Method)
      {
      case 1: err = ZOOlzd(io); break;
      case 2: io->xio_Flags |= XADIOF_NOINENDERR; err = LhA_Decrunch(io, LZHUFF5_METHOD); break;
      default: err = XADERR_DATAFORMAT; break;
      }

      if(!err)
        err = xadIOWriteBuf(io);

      crc = io->xio_CRC16;
      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && crc != ZOOPI(fi)->CRC)
    err = XADERR_CHECKSUM;
  return err;
}

/**************************************************************************************************/

XADRECOGDATA(Savage)
{
  if(data[0] == 29 && data[2] == '*' && data[3] == 'S' && data[4] == 'V' &&
  data[5] == 'G' && data[6] == '*' && EndGetI32(data+11) == 901120)
    return 1;
  else
    return 0;
}

XADGETINFO(Savage)
{
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_Cylinders = 80;
/*  xdi->xdi_LowCyl = 0; */
  xdi->xdi_HighCyl = 79;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_CylSectors = 22;
  xdi->xdi_Heads = 2;
  xdi->xdi_TotalSectors = 1760;
  xdi->xdi_Flags = XADDIF_SEEKDATAPOS;
/*  xdi->xdi_DataPos = 0; */

  return xadAddDiskEntryA(XADM xdi, ai, 0);
}

struct SavageOutPrivate {
  xadUINT32 start;
  xadUINT32 end;
  xadUINT32 pos;
};

static void SavageOutFunc(struct xadInOut *io, xadUINT32 size)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SavageOutPrivate *p;
  xadUINT32 o, s;

  io->xio_CRC16 = xadCalcCRC16(XADM XADCRC16_ID1, io->xio_CRC16, size, (xadUINT8 *) io->xio_OutBuffer);
  p = (struct SavageOutPrivate *) io->xio_OutFuncPrivate;

  if(p->pos+size >= p->start && p->pos < p->end)
  {
    if(p->start < p->pos)
      p->start = p->pos;
    o = p->start - p->pos;
    s = size - o;
    if(s > p->end - p->start)
      s = p->end - p->start;

    if((io->xio_Error = xadHookAccess(XADM XADAC_WRITE, s, io->xio_OutBuffer + o, io->xio_ArchiveInfo)))
      io->xio_Flags |= XADIOF_ERROR;
  }
  p->pos += size;
}

XADUNARCHIVE(Savage)
{
  xadUINT8 Data[31];
  xadINT32 err;
  struct SavageOutPrivate of;

  of.pos = 0;
  of.start = ai->xai_LowCyl*22*512;
  of.end = (ai->xai_HighCyl+1)*22*512;

  if(!(err = xadHookAccess(XADM XADAC_READ, 31, Data, ai)))
  {
    struct xadInOut *io;
    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_COMPLETEOUTFUNC|XADIOF_NOINENDERR,
    ai, xadMasterBase)))
    {
      io->xio_InSize = EndGetI32(Data+7);
      io->xio_OutSize = 901120;
      io->xio_OutFunc = SavageOutFunc;
      io->xio_OutFuncPrivate = &of;

      if(!(err = LhA_Decrunch(io, LZHUFF5_METHOD)))
        err = xadIOWriteBuf(io);

      if(!err && io->xio_CRC16 != EndGetI16(Data + 29))
       err = XADERR_CHECKSUM;

      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }
  return err;
}

/**************************************************************************************************/

XADCLIENT(Savage) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SAVAGE_VERSION,
  SAVAGE_REVISION,
  31,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_SAVAGECOMPRESSOR,
  "Savage Compressor",
  XADRECOGDATAP(Savage),
  XADGETINFOP(Savage),
  XADUNARCHIVEP(Savage),
  NULL
};

XADCLIENT(Zoo) {
  (struct xadClient *) &Savage_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZOO_VERSION,
  ZOO_REVISION,
  24,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_ZOO,
  "Zoo",
  XADRECOGDATAP(Zoo),
  XADGETINFOP(Zoo),
  XADUNARCHIVEP(Zoo),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Zoo)

#endif /* XADMASTER_LHA_C */
