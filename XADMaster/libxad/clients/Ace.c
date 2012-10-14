#ifndef XADMASTER_ACE_C
#define XADMASTER_ACE_C

/*  $Id: Ace.c,v 1.9 2005/06/23 14:54:40 stoecker Exp $
    Ace file archiver client

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


#include "../unix/xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("Ace 1.2 (22.02.2004)")

#define ACE_VERSION             1
#define ACE_REVISION            2
#define ACEEXE_VERSION          ACE_VERSION
#define ACEEXE_REVISION         ACE_REVISION

#define ACETYPE_MAIN            0
#define ACETYPE_FILE            1
#define ACETYPE_RECOVERY        2

#define ACEFLAG_ADDSIZE         (1<< 0)
#define ACEFLAG_COMMENT         (1<< 1)

#define ACEMFLAG_SFXARCHIVE     (1<<( 9-8))
#define ACEMFLAG_DICTLIM256     (1<<(10-8))
#define ACEMFLAG_MULTIVOLUME    (1<<(11-8))
#define ACEMFLAG_AVSTRING       (1<<(12-8))
#define ACEMFLAG_RECOVERY       (1<<(13-8))
#define ACEMFLAG_LOCKED         (1<<(14-8))
#define ACEMFLAG_SOLID          (1<<(15-8))

#define ACEFFLAG_CONTPREVIOUS   (1<<(12-8))     /* file is continued from last volume */
#define ACEFFLAG_CONTNEXT       (1<<(13-8))     /* file is continued in next volume */
#define ACEFFLAG_PASSWORD       (1<<(14-8))
#define ACEFFLAG_SOLID          (1<<(15-8))

#define ACEHOST_MSDOS           0
#define ACEHOST_OS2             1
#define ACEHOST_WIN32           2
#define ACEHOST_UNIX            3
#define ACEHOST_MAC_OS          4
#define ACEHOST_WIN NT          5
#define ACEHOST_PRIMOS          6
#define ACEHOST_APPLE_GS        7
#define ACEHOST_ATARI           8
#define ACEHOST_VAX_VMS         9
#define ACEHOST_AMIGA           10
#define ACEHOST_NEXT            11

#define ACECOMP_STORED          0
#define ACECOMP_LZ77            1
#define ACECOMP_BLOCKED         2

#define ACEBLOCK_LZ77_NORM         0
#define ACEBLOCK_LZ77_DELTA        1
#define ACEBLOCK_LZ77_EXE          2
#define ACEBLOCK_SOUND_8           3
#define ACEBLOCK_SOUND_16          4
#define ACEBLOCK_SOUND_32_1        5
#define ACEBLOCK_SOUND_32_2        6
#define ACEBLOCK_PIC               7

#define ACECOMPQUALITY_FASTEST  0
#define ACECOMPQUALITY_FAST     1
#define ACECOMPQUALITY_NORMAL   2
#define ACECOMPQUALITY_GOOD     3
#define ACECOMPQUALITY_BEST     4

/* AceHead:
  xadUINT16 HeaderCRC;          // start at HeaderType!
  xadUINT16 HeaderSize;

  xadUINT8 HeaderType;          // 00           // ACETYPE_MAIN
  xadUINT8 HeaderFlags[2];      // 01
  xadUINT8 AceSign[7];          // 03           // **ACE**
  xadUINT8 ExtractVersion;      // 10
  xadUINT8 CreaterVersion;      // 11
  xadUINT8 Host;                // 12
  xadUINT8 VolumeNumber;        // 13
  xadUINT32 Date;               // 14
  xadUINT8 Reserved[8];         // 18

  xadUINT8 AVSize;              // 26
  ...   Advert string

  xadUINT16 CommentSize;        // compressed
  ...   Comment string
*/

/* AceFile:
  xadUINT16 HeaderCRC;          // start at HeaderType!
  xadUINT16 HeaderSize;

  xadUINT8 HeaderType;          // 00           // ACETYPE_FILE
  xadUINT8 HeaderFlags[2];      // 01
  xadUINT32     PackSize;       // 03
  xadUINT32 OrigSize;           // 07
  xadUINT32 Date;               // 11
  xadUINT32 Attributes;         // 15
  xadUINT32 CRC32;              // 19
  xadUINT8 Compression;         // 23           // ACECOMP_xxx
  xadUINT8 CompQuality;         // 24           // ACECOMPQUALITY_xxx
  xadUINT16 DecompParam;        // 25
  xadUINT16     Reserved;

  xadUINT16 FilenameSize;       // 29
  ...   filename string

  xadUINT16 CommentSize;        // compressed
  ...   Comment string
*/

#define ACEPI(a)        ((struct AcePrivate *) ((a)->xfi_PrivateInfo))

struct AcePrivate {
  xadUINT32 CRC32;
  xadUINT8 Compression;
  xadUINT8 Quality;
  xadUINT16 DecompParam;
  struct xadFileInfo *Solid;
  xadUINT8 Flags;                               /* only password+solid needed */
};

#define ACEBUFSIZE 10240

/****************************************************************************/

#define ACEmaxdic      22
#define ACEmaxwd_mn    11
#define ACEmaxwd_lg    11
#define ACEmaxwd_svwd   7
#define ACEmaxlength  259
#define ACEmaxdis2    255
#define ACEmaxdis3   8191
#define ACEmaxcode   (255+4+ACEmaxdic)
#define ACEsvwd_cnt    15
#define ACEmax_cd_mn (256+4+(ACEmaxdic+1)-1)
#define ACEmax_cd_lg (256-1)

struct AceData {
  xadINT32   err;
  struct xadArchiveInfo *ai;
  struct xadMasterBase *xadMasterBase;
  struct xadFileInfo *lastfile;
  xadUINT32  insize;
  xadUINT32  inbufsize;
  xadSTRPTR inbuffer;
  xadUINT32 crc32;

  xadUINT8 *dcpr_text;
  xadUINT32 code_rd;
  xadUINT32 dcpr_dicsiz;
  xadUINT32 dcpr_dican;
  xadUINT32 dcpr_size;
  xadUINT32 dcpr_dpos;
  xadUINT32 rpos;

  xadUINT16 bits_rd;
  xadINT16  dcpr_dic;

  xadUINT16 dcpr_code_mn[1 << ACEmaxwd_mn];
  xadUINT16 sort_org[ACEmaxcode + 2];
  xadUINT16 dcpr_code_lg[1 << ACEmaxwd_lg];
  xadUINT8 dcpr_wd_mn[ACEmaxcode + 2];
  xadUINT8 wd_svwd[ACEsvwd_cnt];
  xadUINT8 sort_freq[(ACEmaxcode + 2) * 2];
  xadUINT8 dcpr_wd_lg[ACEmaxcode + 2];
};

static const xadINT8 ACEswapdata[4] = {3,1,-1,-3};

/* ACEaddbits(ad,0); initializes the stuff (together with ad->rpos = ad->inbufsize) */
static void ACEaddbits(struct AceData *ad, xadUINT16 bits)
{
  ad->code_rd <<= bits;
  ad->bits_rd -= bits;
  while(ad->bits_rd <= 24 && ad->insize) /* 3 byte */
  {
    if(ad->rpos == ad->inbufsize)
    {
      ad->rpos = 0;
      if(!ad->err && ad->ai)
      {
        xadUINT32 i;
        struct xadMasterBase *xadMasterBase = ad->xadMasterBase;

        if((i = ad->inbufsize) > ad->insize)
          i = ad->insize;
        ad->err = xadHookTagAccess(XADM XADAC_READ, i, ad->inbuffer, ad->ai, XAD_USESKIPINFO, XADTRUE, TAG_DONE);
      }
    }

    ad->code_rd |= ad->inbuffer[ad->rpos+ACEswapdata[ad->rpos&3]]<<(24-ad->bits_rd);
    ad->insize--;
    ad->rpos++;
    ad->bits_rd += 8;
  }
}

#define ACExchg_def(v1,v2) {tmp = v1; v1 = v2; v2 = tmp;}
static void ACEsortrange(struct AceData *ad, xadINT32 left, xadINT32 right)
{
  xadINT32 zl = left, zr = right, hyphen, tmp;

  hyphen = ad->sort_freq[right];

  /* divides by hyphen the given range into 2 parts */
  do
  {
    while(ad->sort_freq[zl] > hyphen)
      zl++;
    while(ad->sort_freq[zr] < hyphen)
      zr--;
    /* found a too small (left side) and a too big (right side) element-->exchange them */
    if(zl <= zr)
    {
      ACExchg_def(ad->sort_freq[zl], ad->sort_freq[zr]);
      ACExchg_def(ad->sort_org[zl], ad->sort_org[zr]);
      zl++;
      zr--;
    }
  } while(zl < zr);

  /* sort partial ranges - when very small, sort directly */
  if(left < zr)
  {
    if(left < zr - 1)
      ACEsortrange(ad, left, zr);
    else if(ad->sort_freq[left] < ad->sort_freq[zr])
    {
      ACExchg_def(ad->sort_freq[left], ad->sort_freq[zr]);
      ACExchg_def(ad->sort_org[left], ad->sort_org[zr]);
    }
  }

  if(right > zl)
  {
    if(zl < right - 1)
      ACEsortrange(ad, zl, right);
    else if(ad->sort_freq[zl] < ad->sort_freq[right])
    {
      ACExchg_def(ad->sort_freq[zl], ad->sort_freq[right]);
      ACExchg_def(ad->sort_org[zl], ad->sort_org[right]);
    }
  }
}

static xadINT32 ACEmakecode(struct AceData *ad, xadUINT32 maxwd, xadUINT32 size1_t, xadUINT8 *wd, xadUINT16 *code)
{
  xadUINT32 maxc, size2_t, l, c, i, max_make_code;
  struct xadMasterBase *xadMasterBase = ad->xadMasterBase;

  xadCopyMem(XADM wd, (xadPTR) &ad->sort_freq, (size1_t + 1) * sizeof(xadUINT8));
  if(size1_t)
  { /* quicksort */
    for(i = size1_t + 1; i--;)
      ad->sort_org[i] = i;
    ACEsortrange(ad, 0, size1_t);
  }
  else
    ad->sort_org[0] = 0;
  ad->sort_freq[size1_t + 1] = size2_t = c = 0;
  while(ad->sort_freq[size2_t])
    size2_t++;
  if(size2_t < 2)
  {
    i = ad->sort_org[0];
    wd[i] = 1;
    size2_t += (size2_t == 0);
  }
  size2_t--;

  max_make_code = 1 << maxwd;
  for(i = size2_t + 1; i-- && c < max_make_code;)
  {
    maxc = 1 << (maxwd - ad->sort_freq[i]);
    l = ad->sort_org[i];
    if(c + maxc > max_make_code)
      return 0;
    while(maxc--)
      code[c++] = l;
  }
  return 1;
}

static xadINT32 ACEread_wd(struct AceData *ad, xadUINT32 maxwd, xadUINT16 *code, xadUINT8 *wd, xadINT32 max_el)
{
  xadUINT32 c, i, j, num_el, l, uplim, lolim;

  memset(wd, 0, max_el * sizeof(xadINT8));
  memset(code, 0, (1 << maxwd) * sizeof(xadUINT16));

  num_el = ad->code_rd >> (32 - 9);
  ACEaddbits(ad, 9);
  if(num_el > max_el)
    num_el = max_el;

  lolim = ad->code_rd >> (32 - 4);
  ACEaddbits(ad, 4);
  uplim = ad->code_rd >> (32 - 4);
  ACEaddbits(ad, 4);

  for(i = -1; ++i <= uplim;)
  {
    ad->wd_svwd[i] = ad->code_rd >> (32 - 3);
    ACEaddbits(ad, 3);
  }
  if(!ACEmakecode(ad, ACEmaxwd_svwd, uplim, ad->wd_svwd, code))
    return 0;
  j = 0;
  while(j <= num_el)
  {
    c = code[ad->code_rd >> (32 - ACEmaxwd_svwd)];
    ACEaddbits(ad, ad->wd_svwd[c]);
    if(c < uplim)
      wd[j++] = c;
    else
    {
      l = (ad->code_rd >> 28) + 4;
      ACEaddbits(ad, 4);
      while(l-- && j <= num_el)
        wd[j++] = 0;
    }
  }
  if(uplim)
    for(i = 0; ++i <= num_el;)
      wd[i] = (wd[i] + wd[i - 1]) % uplim;
  for(i = -1; ++i <= num_el;)
    if(wd[i])
      wd[i] += lolim;

  return ACEmakecode(ad, maxwd, num_el, wd, code);
}

static xadINT32 AceDecrComment(xadUINT8 *src, xadUINT8 *dest, xadINT32 comm_size, struct xadMasterBase *xadMasterBase)
{
  xadINT32 err = XADERR_NOMEMORY;
  xadUINT16 *hash;
  struct AceData *ad;
  xadINT32 dpos = 0, c, pos = 0, len, hs;

  if((hash = (xadUINT16 *) xadAllocVec(XADM (255+255+1)*sizeof(xadUINT16), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    if((ad = (struct AceData *) xadAllocVec(XADM sizeof(struct AceData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      ad->insize = ad->inbufsize = comm_size;
      ad->inbuffer = (xadSTRPTR) src;
      ad->xadMasterBase = xadMasterBase;

      ACEaddbits(ad,0); /* initialize */
      len = ad->code_rd >> (32 - 15);
      ACEaddbits(ad,15);
      if(ACEread_wd(ad, ACEmaxwd_mn, ad->dcpr_code_mn, ad->dcpr_wd_mn, ACEmax_cd_mn))
      {
        do
        {
          if(dpos > 1)
          {
            pos = hash[hs = dest[dpos - 1] + dest[dpos - 2]];
            hash[hs] = dpos;
          }
          ACEaddbits(ad, ad->dcpr_wd_mn[(c = ad->dcpr_code_mn[ad->code_rd >> (32 - ACEmaxwd_mn)])]);
          if(c > 255)
          {
             c = c - 256 + 2;
             while(c--)
               dest[dpos++] = dest[pos++];
          }
          else
            dest[dpos++] = c;
        } while(dpos < len);
        err = 0;
      }

      xadFreeObjectA(XADM ad, 0);
    }
    xadFreeObjectA(XADM hash, 0);
  }
  return err;
}

static xadINT32 ACEdecompress(struct AceData *ad, xadUINT32 save)
{
  xadUINT32 startpos, num = 0;
  xadINT32  c, lg, i, k;
  xadUINT32 dist, mpos, olddist[4];
  xadINT16  oldnum = 0, blocksize = 0;
  struct xadMasterBase *xadMasterBase = ad->xadMasterBase;

  startpos = ad->dcpr_dpos;
  memset(&olddist, 0, 4*4);
  while(num < ad->dcpr_size && !ad->err)
  {
    if(!blocksize)
    {
      if(!ACEread_wd(ad, ACEmaxwd_mn, ad->dcpr_code_mn, ad->dcpr_wd_mn, ACEmax_cd_mn) ||
      !ACEread_wd(ad, ACEmaxwd_lg, ad->dcpr_code_lg, ad->dcpr_wd_lg, ACEmax_cd_lg))
        return XADERR_DECRUNCH;
      blocksize = ad->code_rd >> (32 - 15);
      ACEaddbits(ad, 15);
    }

    ACEaddbits(ad, ad->dcpr_wd_mn[(c = ad->dcpr_code_mn[ad->code_rd >> (32 - ACEmaxwd_mn)])]);
    blocksize--;
    if(c > 255)
    {
      if(c > 259)
      {
        if((c -= 260) > 1)
        {
          dist = (ad->code_rd >> (33 - c)) + (1L << (c - 1));
          ACEaddbits(ad, c - 1);
        }
        else
          dist = c;
        olddist[(oldnum = (oldnum + 1) & 3)] = dist;
        i = 2;
        if(dist > ACEmaxdis2)
        {
          i++;
          if(dist > ACEmaxdis3)
            i++;
        }
      }
      else
      {
        dist = olddist[(oldnum - (c &= 255)) & 3];
        for(k = c + 1; k--;)
          olddist[(oldnum - k) & 3] = olddist[(oldnum - k + 1) & 3];
        olddist[oldnum] = dist;
        i = 2;
        if(c > 1)
          i++;
      }
      ACEaddbits(ad, ad->dcpr_wd_lg[(lg = ad->dcpr_code_lg[ad->code_rd >> (32 - ACEmaxwd_lg)])]);
      lg += i;
      mpos = ad->dcpr_dpos - ++dist;
      num += lg;
      while(lg--)
      {
        mpos &= ad->dcpr_dican;
        ad->dcpr_text[ad->dcpr_dpos++] = ad->dcpr_text[mpos++];
        if(ad->dcpr_dpos > ad->dcpr_dican)
        {
          ad->crc32 = xadCalcCRC32(XADM XADCRC32_ID1, ad->crc32, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos);
          if(save)
            ad->err = xadHookAccess(XADM XADAC_WRITE, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos, ad->ai);
          startpos = (ad->dcpr_dpos &= ad->dcpr_dican);
        }
      }
    }
    else
    {
      ad->dcpr_text[ad->dcpr_dpos++] = c;
      ++num;
      if(ad->dcpr_dpos > ad->dcpr_dican)
      {
        ad->crc32 = xadCalcCRC32(XADM XADCRC32_ID1, ad->crc32, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos);
        if(save)
          ad->err = xadHookAccess(XADM XADAC_WRITE, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos, ad->ai);
        startpos = (ad->dcpr_dpos &= ad->dcpr_dican);
      }
    }
  }
  ad->crc32 = xadCalcCRC32(XADM XADCRC32_ID1, ad->crc32, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos);
  if(!ad->err && save)
    ad->err = xadHookAccess(XADM XADAC_WRITE, ad->dcpr_dpos-startpos, ad->dcpr_text+startpos, ad->ai);
  return ad->err;
}

static xadINT32 AceExtractEntry(struct AceData *ad, struct xadFileInfo *fi)
{
  struct xadMasterBase *xadMasterBase = ad->xadMasterBase;
  xadINT32 err;
  xadUINT32 i;
  struct xadFileInfo *fis;

  if(ACEPI(fi)->Flags & ACEFFLAG_PASSWORD)
    return XADERR_NOTSUPPORTED;

  fis = fi;
  if(ad->lastfile)
  {
    while(ACEPI(fis)->Solid && fis != ad->lastfile->xfi_Next)
      fis = ACEPI(fis)->Solid;
  }
  else
    while(ACEPI(fis)->Solid)
      fis = ACEPI(fis)->Solid;

  if(!ACEPI(fis)->Solid)
    ad->dcpr_dpos = 0;

  do
  {
    ad->crc32 = ~0;
    ad->insize = fis->xfi_CrunchSize;

    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, fis->xfi_DataPos-ad->ai->xai_InPos, 0, ad->ai)))
    {
      switch(ACEPI(fis)->Compression)
      {
      case ACECOMP_STORED:
        while(!err && ad->insize)
        {
          i = ad->insize;
          if(ad->dcpr_dpos + i > ad->dcpr_dicsiz)
            i = ad->dcpr_dicsiz - ad->dcpr_dpos;
          if(!(err = xadHookTagAccess(XADM XADAC_READ, i, ad->dcpr_text+ad->dcpr_dpos,  ad->ai, XAD_GETCRC32, &ad->crc32,
          XAD_USESKIPINFO, 1, TAG_DONE)))
          {
            if(fis == fi)
              err = xadHookAccess(XADM XADAC_WRITE, i, ad->dcpr_text+ad->dcpr_dpos, ad->ai);
          }
          ad->dcpr_dpos = (ad->dcpr_dpos+i) & ad->dcpr_dican;
          ad->insize -= i;
        }
        break;
      case ACECOMP_LZ77:
        if((ACEPI(fis)->DecompParam & 15) + 10 > ad->dcpr_dic)
         err = XADERR_NOMEMORY;
        else
        {
          ad->dcpr_size = fis->xfi_Size;
          ad->bits_rd = 0;
          ad->rpos = ad->inbufsize; /* enforce start read */
          ACEaddbits(ad,0);
          err = ACEdecompress(ad, fis == fi ? 1 : 0);
        }
        break;
      default: err = XADERR_DATAFORMAT;
      }
      if(!err && ad->crc32 != ACEPI(fis)->CRC32)
        err = XADERR_CHECKSUM;
    }
    fis = fis->xfi_Next;
  } while(!err && fis != fi->xfi_Next);

  ad->lastfile = fi;

  return err;
}

/****************************************************************************/

static const xadSTRPTR acetypes[2] = {(xadSTRPTR)"stored", (xadSTRPTR)"lz77"};

XADGETINFO(Ace)
{
  xadINT32 err = 0;
  xadUINT8 blockdata[256], *bptr;
  struct xadFileInfo *fi = 0, *fi2;
  xadUINT32 i, num = 1, lastpos = 0;
  xadUINT8 ac[4];

  while(ai->xai_InPos + 3 < ai->xai_InSize && !err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, &ac, ai)))
    {
      i = EndGetI16(ac+2); /* Size */
      if(i <= 256)
        bptr = blockdata;
      else if(!(bptr = (xadUINT8 *) xadAllocVec(XADM i+1, XADMEMF_PUBLIC)))
        err = XADERR_NOMEMORY;

      if(!err && !(err = xadHookAccess(XADM XADAC_READ, i, bptr, ai)))
      {
        if(EndGetI16(ac) != (xadUINT16) xadCalcCRC32(XADM XADCRC32_ID1, ~0, i, bptr))
          err = XADERR_CHECKSUM;
        else
        {
          if(bptr[0] == ACETYPE_MAIN)
          {
            if(bptr[1] & ACEFLAG_COMMENT)
            {
              if((fi2 = xadAllocObjectA(XADM XADOBJ_FILEINFO, 0)))
              {
                fi2->xfi_FileName = (xadSTRPTR)"AceInfo.TXT";
                fi2->xfi_EntryNumber = num++;
                fi2->xfi_DataPos = ai->xai_InPos-i+29+bptr[26];
                fi2->xfi_CrunchSize = EndGetI16(bptr+bptr[26]+27);
                fi2->xfi_Size = EndGetI16(bptr+31+bptr[26])>>1;
                fi2->xfi_Flags = XADFIF_NODATE|XADFIF_SEEKDATAPOS|XADFIF_INFOTEXT|XADFIF_NOFILENAME;
                xadConvertDates(XADM XAD_DATECURRENTTIME, 1, XAD_GETDATEXADDATE, &fi2->xfi_Date, TAG_DONE);
                if(!fi)
                  ai->xai_FileInfo = fi2;
                else
                  fi->xfi_Next = fi2;
                fi = fi2;
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
          else if(bptr[0] == ACETYPE_FILE)
          {
            xadUINT32 namesize, commentsize = 0;

            namesize = EndGetI16(bptr+29);
            if(bptr[1] & ACEFLAG_COMMENT)
              commentsize = EndGetI16(bptr+35+namesize)>>1;

            if((bptr[2] & ACEFFLAG_CONTPREVIOUS) && fi && (ACEPI(fi)->Flags & ACEFFLAG_CONTNEXT) &&
            fi->xfi_Size == EndGetI32(bptr+7))
            {
              struct xadSkipInfo *si;
              if((si = (struct xadSkipInfo *) xadAllocObjectA(XADM XADOBJ_SKIPINFO, 0)))
              {
                si->xsi_Next = ai->xai_SkipInfo;
                ai->xai_SkipInfo = si;
                si->xsi_SkipSize = ai->xai_InPos - lastpos;
                si->xsi_Position = lastpos;
                ACEPI(fi)->CRC32 = EndGetI32(bptr+19);
                fi->xfi_CrunchSize += EndGetI32(bptr+3);
                lastpos = ai->xai_InPos + EndGetI32(bptr+3);
              }
              else
                err = XADERR_NOMEMORY;
            }
            else if((fi2 = xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE, namesize+1,
            commentsize ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, commentsize+1,
            XAD_OBJPRIVINFOSIZE, sizeof(struct AcePrivate), TAG_DONE)))
            {
              xadCopyMem(XADM bptr+31, fi2->xfi_FileName, namesize);
              for(i = 0; i < namesize; ++i)
              {
                if(fi2->xfi_FileName[i] == '\\')
                  fi2->xfi_FileName[i] = '/';
              }
              if(commentsize)
                AceDecrComment((xadUINT8 *)bptr+33+namesize, (xadUINT8 *)fi2->xfi_Comment, EndGetI16(bptr+31+namesize), xadMasterBase);

              fi2->xfi_EntryNumber = num++;
              fi2->xfi_Size = EndGetI32(bptr+7);
              fi2->xfi_CrunchSize = EndGetI32(bptr+3);
              ACEPI(fi2)->CRC32 = EndGetI32(bptr+19);
              ACEPI(fi2)->Compression = bptr[23];
              ACEPI(fi2)->Quality = bptr[24];
              ACEPI(fi2)->Flags = bptr[2];
              ACEPI(fi2)->DecompParam = EndGetI16(bptr+25);
              if(bptr[23] <= 1)
                fi2->xfi_EntryInfo = acetypes[bptr[23]];
              i = EndGetI32(bptr+15);
              if(i & 0x10)
                fi2->xfi_Flags |= XADFIF_DIRECTORY;
              //xadConvertProtection(XADM XAD_PROTMSDOS, EndGetI32(bptr+15), XAD_GETPROTAMIGA, &fi2->xfi_Protection, TAG_DONE);
              xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(bptr+11), XAD_GETDATEXADDATE, &fi2->xfi_Date, TAG_DONE);
              if(bptr[2] & ACEFFLAG_PASSWORD)
              {
                fi2->xfi_Flags |= XADFIF_CRYPTED;
                ai->xai_Flags |= XADAIF_CRYPTED;
              }
              fi2->xfi_DataPos = ai->xai_InPos;
              if(bptr[2] & ACEFFLAG_SOLID)
              {
                ACEPI(fi2)->Solid = fi;
              }

              if(!fi)
                ai->xai_FileInfo = fi2;
              else
                fi->xfi_Next = fi2;
              fi = fi2;
              lastpos = fi2->xfi_DataPos + fi->xfi_CrunchSize;
            }
            else
              err = XADERR_NOMEMORY;
          }
          if(bptr[1] & ACEFLAG_ADDSIZE)
            err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetI32(bptr+3), 0, ai);
        }
      }

      if(bptr && bptr != blockdata)
        xadFreeObjectA(XADM bptr, 0);
    }
  }

  if(err && ai->xai_FileInfo)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
    err = 0;
  }

  return err;
}

XADRECOGDATA(Ace)
{
  if(data[7] == '*' && data[8] == '*' && data[9] == 'A' && data[10] == 'C'
  && data[11] == 'E' && data[12] == '*' && data[13] == '*')
    return 1;
  else
    return 0;
}

/****************************************************************************/

XADUNARCHIVE(Ace)
{
  xadINT32 err = 0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(!fi->xfi_PrivateInfo) /* comment */
  {
    xadSTRPTR buf;

    if((buf = (xadSTRPTR) xadAllocVec(XADM fi->xfi_CrunchSize+fi->xfi_Size, XADMEMF_PUBLIC)))
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, fi->xfi_CrunchSize, buf, ai)))
      {
        if(!(err = AceDecrComment((xadUINT8 *)buf, (xadUINT8 *)(buf+fi->xfi_CrunchSize), fi->xfi_CrunchSize, xadMasterBase)))
          err = xadHookAccess(XADM XADAC_WRITE, fi->xfi_Size, buf+fi->xfi_CrunchSize, ai);
      }
      xadFreeObjectA(XADM buf, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }
  else if(ACEPI(fi)->Compression == ACECOMP_STORED && !(ACEPI(fi)->Flags & ACEFFLAG_PASSWORD))
  {
    /* this ensures we can always extract stored files, even if solid extraction fails */
    xadUINT32 crc32 = ~0;
    if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, fi->xfi_DataPos-ai->xai_InPos, 0, ai)))
      if(!(err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC32, &crc32, XAD_USESKIPINFO, 1, TAG_DONE)))
        if(crc32 != ACEPI(fi)->CRC32)
          err = XADERR_CHECKSUM;
  }
  else
  {
    struct AceData *ad;
    if(!(ad = (struct AceData *) ai->xai_PrivateClient))
    {
      if((ad = (struct AceData *) xadAllocVec(XADM sizeof(struct AceData)+ACEBUFSIZE, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
        ai->xai_PrivateClient = ad;
        ad->ai = ai;
        ad->inbufsize = ACEBUFSIZE;
        ad->inbuffer = (xadSTRPTR) (ad+1);
        ad->xadMasterBase = xadMasterBase;
        ad->dcpr_dic = 20;
        while(!(ad->dcpr_text = xadAllocVec(XADM ad->dcpr_dicsiz = (xadINT32) 1 << ad->dcpr_dic, XADMEMF_PUBLIC)))
          ad->dcpr_dic--;
        ad->dcpr_dican = ad->dcpr_dicsiz - 1;
      }
      else
        err = XADERR_NOMEMORY;
    }
    if(ad)
    {
      if((err = AceExtractEntry(ad, fi)))
      { /* allow restart for next entry */
        xadFreeObjectA(XADM ad->dcpr_text, 0);
        xadFreeObjectA(XADM ad, 0);
        ai->xai_PrivateClient = 0;
      }
    }
  }

  return err;
}

XADFREE(Ace)
{
  if(ai->xai_PrivateClient) /* decrunch buffer */
  {
    if(((struct AceData *) ai->xai_PrivateClient)->dcpr_text)
      xadFreeObjectA(XADM ((struct AceData *) ai->xai_PrivateClient)->dcpr_text, 0);
    xadFreeObjectA(XADM ai->xai_PrivateClient, 0);
    ai->xai_PrivateClient = 0;
  }
}

/****************************************************************************/

XADRECOGDATA(AceEXE)
{
  xadUINT32 i;

  if(size < 14 || data[0] != 0x4D || data[1] != 0x5A)
    return 0;

  data += 7;
  for(i = 7; i < size-6; ++i)
  {
    if(data[0] == '*' && data[1] == '*' && data[2] == 'A' && data[3] == 'C'
    && data[4] == 'E' && data[5] == '*' && data[6] == '*')
      return 1;
    ++data;
  }
  return 0;
}

XADGETINFO(AceEXE)
{
  xadINT32 i= 0, err = 0, found = 0;
  xadSTRPTR buf;
  xadUINT32 bufsize, fsize, spos = 0;

  if((fsize = ai->xai_InSize) < 20)
    return 0;

  if((bufsize = ACEBUFSIZE) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && !found && fsize >= 20)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
    {
      for(i = 0; i < bufsize - 15 && !found; ++i)
      {
        if(buf[i+7] == '*' && buf[i+8] == '*' && buf[i+9] == 'A' && buf[i+10] == 'C'
        && buf[i+11] == 'E' && buf[i+12] == '*' && buf[i+13] == '*')
          found = 1;
      }
      if(!found)
      {
        xadCopyMem(XADM buf+i, buf, 15);
        spos = 15;
        fsize -= bufsize - 15;
        if(fsize < bufsize)
          bufsize = fsize;
      }
    }
  }

  xadFreeObjectA(XADM buf, 0);

  if(found && !(err = xadHookAccess(XADM XADAC_INPUTSEEK, i-1-bufsize, 0, ai)))
    err = Ace_GetInfo(ai, xadMasterBase);

  return err;
}

/****************************************************************************/

XADCLIENT(AceEXE) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ACEEXE_VERSION,
  ACEEXE_REVISION,
  0x10000,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_NOCHECKSIZE|XADCF_FREESKIPINFO,
  XADCID_ACEEXE,
  "Ace MS-EXE",
  XADRECOGDATAP(AceEXE),
  XADGETINFOP(AceEXE),
  XADUNARCHIVEP(Ace),
  XADFREEP(Ace)
};

XADFIRSTCLIENT(Ace) {
  (struct xadClient *) &AceEXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ACE_VERSION,
  ACE_REVISION,
  14,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESKIPINFO,
  XADCID_ACE,
  "Ace",
  XADRECOGDATAP(Ace),
  XADGETINFOP(Ace),
  XADUNARCHIVEP(Ace),
  XADFREEP(Ace)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Ace)

#endif /* XADMASTER_ACE_C */
