#ifndef XADMASTER_LZX_C
#define XADMASTER_LZX_C

/*  $Id: LZX.c,v 1.12 2005/06/23 14:54:41 stoecker Exp $
    LZX file archiver client

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
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("LZX 1.10 (21.2.2004)")

#define LZX_VERSION             1
#define LZX_REVISION            10

/* ---------------------------------------------------------------------- */

#define LZXINFO_DAMAGE_PROTECT 1
#define LZXINFO_FLAG_LOCKED 2

struct LZXInfo_Header
{
  xadUINT8 ID[3];                       /* "LZX" */
  xadUINT8 Flags;                       /* LZXINFO_FLAG_#? */
  xadUINT8 Unknown[6];
};

#define LZXHDR_FLAG_MERGED      (1<<0)

#define LZXHDR_PROT_READ        (1<<0)
#define LZXHDR_PROT_WRITE       (1<<1)
#define LZXHDR_PROT_DELETE      (1<<2)
#define LZXHDR_PROT_EXECUTE     (1<<3)
#define LZXHDR_PROT_ARCHIVE     (1<<4)
#define LZXHDR_PROT_HOLD        (1<<5)
#define LZXHDR_PROT_SCRIPT      (1<<6)
#define LZXHDR_PROT_PURE        (1<<7)

#define LZXHDR_TYPE_MSDOS       0
#define LZXHDR_TYPE_WINDOWS     1
#define LZXHDR_TYPE_OS2         2
#define LZXHDR_TYPE_AMIGA       10
#define LZXHDR_TYPE_UNIX        20

#define LZXHDR_PACK_STORE       0
#define LZXHDR_PACK_NORMAL      2
#define LZXHDR_PACK_EOF         32

struct LZXArc_Header
{
  xadUINT8 Attributes;          /*  0 - LZXHDR_PROT_#? */
  xadUINT8 pad1;                /*  1 */
  xadUINT8 FileSize[4];         /*  2 (little endian) */
  xadUINT8 CrSize[4];           /*  6 (little endian) */
  xadUINT8 MachineType;         /* 10 - LZXHDR_TYPE_#? */
  xadUINT8 PackMode;            /* 11 - LZXHDR_PACK_#? */
  xadUINT8 Flags;               /* 12 - LZXHDR_FLAG_#? */
  xadUINT8 pad2;                /* 13 */
  xadUINT8 CommentSize;         /* 14 - length (0-79) */
  xadUINT8 ExtractVersion;      /* 15 - version needed to extract */
  xadUINT8 pad3;                /* 16 */
  xadUINT8 pad4;                /* 17 */
  xadUINT8 Date[4];             /* 18 - Packed_Date */
  xadUINT8 DataCRC[4];          /* 22 (little endian) */
  xadUINT8 HeaderCRC[4];        /* 26 (little endian) */
  xadUINT8 FilenameSize;        /* 30 - filename length */
}; /* SIZE = 31 */

/* Header CRC includes filename and comment. */

#define LZXHEADERSIZE   31

/* Packed date [4 BYTES, bit 0 is MSB, 31 is LSB]
  bit  0 -  4   Day
       5 -  8   Month   (January is 0)
       9 - 14   Year    (start 1970)
      15 - 19   Hour
      20 - 25   Minute
      26 - 31   Second
*/

struct LZXEntryData {
  xadUINT32 CRC;                /* CRC of uncrunched data */
  xadUINT32 PackMode;   /* CrunchMode */
  xadUINT32 ArchivePos; /* Position is source file */
  xadUINT32 DataStart;  /* Position in merged buffer */
};

#define LZXPE(a)        ((struct LZXEntryData *) ((a)->xfi_PrivateInfo))
#define LZXDD(a)        ((struct LZXDecrData *) ((a)->xai_PrivateClient))
struct LZXDecrData {
  xadUINT32 ArchivePos; /* The Archive-Pos to detect if it is correct buffer */
  xadUINT32 DataPos;    /* must be lower or equal to current entry or reinit is necessary */

  xadUINT8 *source;
  xadUINT8 *destination;
  xadUINT8 *source_end;
  xadUINT8 *destination_end;
  xadUINT8 *pos;

  xadUINT32 decrunch_method;
  xadUINT32 decrunch_length;
  xadUINT32 pack_size;
  xadUINT32 last_offset;
  xadUINT32 control;
  xadINT32  shift;

  xadUINT8 offset_len[8];
  xadUINT16 offset_table[128];
  xadUINT8 huffman20_len[20];
  xadUINT16 huffman20_table[96];
  xadUINT8 literal_len[768];
  xadUINT16 literal_table[5120];

  xadUINT8 read_buffer[16384];          /* have a reasonable sized read buffer */
  xadUINT8 decrunch_buffer[258+65536+258];      /* allow overrun for speed */
};

XADRECOGDATA(LZX)
{
  if(data[0] == 'L' && data[1] == 'Z' && data[2] == 'X')
    return 1;
  else
    return 0;
}

#define XADFIBF_DELETE  (1<<0)
#define XADFIBF_EXECUTE (1<<1)
#define XADFIBF_WRITE   (1<<2)
#define XADFIBF_READ    (1<<3)
#define XADFIBF_PURE    (1<<4)

XADGETINFO(LZX)
{
  xadINT32 err;
  xadUINT32 bufpos = 0;
  struct xadFileInfo *fi, *fig = 0; /* fig - first grouped ptr */
  struct LZXArc_Header head;

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, sizeof(struct LZXInfo_Header), 0, ai)))
  {
    while(!err && ai->xai_InPos < ai->xai_InSize)
    {
      if(!(err = xadHookAccess(XADM XADAC_READ, LZXHEADERSIZE, &head, ai)))
      {
        xadUINT32 i, j, k, l, crc;
        i = head.CommentSize;
        j = head.FilenameSize;
        k = EndGetI32(head.HeaderCRC);
        head.HeaderCRC[0] = head.HeaderCRC[1] = head.HeaderCRC[2] = head.HeaderCRC[3] = 0;
        /* clear for CRC check */

        if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        XAD_OBJNAMESIZE, j+1, i ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, i+1,
        XAD_OBJPRIVINFOSIZE, sizeof(struct LZXEntryData), TAG_DONE)))
          err = XADERR_NOMEMORY;
        else if(!(err = xadHookAccess(XADM XADAC_READ, j, fi->xfi_FileName, ai)) &&
        (!i || !(err = xadHookAccess(XADM XADAC_READ, i, fi->xfi_Comment, ai))))
        {
          l = EndGetI32(head.CrSize);

          if(!l || !(err = xadHookAccess(XADM XADAC_INPUTSEEK, l, 0, ai)))
          {
            crc = xadCalcCRC32(XADM XADCRC32_ID1, (xadUINT32) ~0, LZXHEADERSIZE, (xadUINT8 *) &head);
            crc = xadCalcCRC32(XADM XADCRC32_ID1, crc, j, (xadUINT8 *) fi->xfi_FileName);
            if(i)
              crc = xadCalcCRC32(XADM XADCRC32_ID1, crc, i, (xadUINT8 *) fi->xfi_Comment);

            if(~crc != k)
              err = XADERR_CHECKSUM;
            else
            {
              if(!fig)
              {
                fig = fi; bufpos = 0;
              }
              fi->xfi_Size = EndGetI32(head.FileSize);
              if(!l && !fi->xfi_Size && fi->xfi_FileName[--j] == '/')
              {
                fi->xfi_FileName[j] = 0;
                fi->xfi_Flags |= XADFIF_DIRECTORY;
              }

              i = head.Attributes;
              j = 0;

              if(!(i & LZXHDR_PROT_READ))
                j |= XADFIBF_READ;
              if(!(i & LZXHDR_PROT_WRITE))
                j |= XADFIBF_WRITE;
              if(!(i & LZXHDR_PROT_DELETE))
                j |= XADFIBF_DELETE;
              if(!(i & LZXHDR_PROT_EXECUTE))
                j |= XADFIBF_EXECUTE;
              j |= (i & (LZXHDR_PROT_ARCHIVE|LZXHDR_PROT_SCRIPT));
              if(i & LZXHDR_PROT_PURE)
                j |= XADFIBF_PURE;
              if(i & LZXHDR_PROT_HOLD)
                j |= (1<<7);    /* not defined in <dos/dos.h> */
              fi->xfi_Protection = j;

              { /* Make the date */
                struct xadDate d;
                j = EndGetM32(head.Date);
                d.xd_Second = j & 63;
                j >>= 6;
                d.xd_Minute = j & 63;
                j >>= 6;
                d.xd_Hour = j & 31;
                j >>= 5;
                d.xd_Year = 1970 + (j & 63);
                if(d.xd_Year >= 2028)      /* Original LZX */
                  d.xd_Year += 2000-2028;
                else if(d.xd_Year < 1978) /* Dr.Titus */
                  d.xd_Year += 2034-1970;
                /* Dates from 1978 to 1999 are correct */
                /* Dates from 2000 to 2027 Mikolaj patch are correct */
                /* Dates from 2000 to 2005 LZX/Dr.Titus patch are correct */
                /* Dates from 2034 to 2041 Dr.Titus patch are correct */
                j >>= 6;
                d.xd_Month = 1 + (j & 15);
                j >>= 4;
                d.xd_Day = j;
                d.xd_Micros = 0;
                xadConvertDates(XADM XAD_DATEXADDATE, &d, XAD_GETDATEXADDATE,
                &fi->xfi_Date, TAG_DONE);
              }
              LZXPE(fi)->CRC = EndGetI32(head.DataCRC);
              LZXPE(fi)->DataStart = bufpos;
              bufpos += fi->xfi_Size;
              if(head.Flags & LZXHDR_FLAG_MERGED)
              {
                fi->xfi_Flags |= XADFIF_GROUPED;
                if(l)
                {
                  fi->xfi_Flags |= XADFIF_ENDOFGROUP;
                  fi->xfi_GroupCrSize = l;
                }
              }
              else
                fi->xfi_CrunchSize = l;

              if(l)
              {
                LZXPE(fi)->ArchivePos = ai->xai_InPos-l;
                LZXPE(fi)->PackMode = head.PackMode;
                while(fig)
                {
                  fig->xfi_GroupCrSize = l;
                  LZXPE(fig)->ArchivePos = ai->xai_InPos-l;
                  LZXPE(fig)->PackMode = head.PackMode;
                  fig = fig->xfi_Next;
                }
              }

              err = xadAddFileEntryA(XADM fi, ai, 0);
              fi = 0;
            } /* skip crunched data */
          } /* get filename and comment */
          if(fi)
            xadFreeObjectA(XADM fi,0);
        } /* xadFileInfo Allocation */
      } /* READ header */
    } /* while loop */
  } /* INPUTSEEK 3 bytes */

  if(err && ai->xai_FileInfo)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
    err = 0;
  }

  return err;
}

/* ---------------------------------------------------------------------- */

static const xadUINT8 LZXtable_one[32] = {
  0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14
};

static const xadUINT32 LZXtable_two[32] = {
  0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,768,1024,
  1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,
};

static const xadUINT16 LZXmask_bits[16] = {
  0x0000,0x0001,0x0003,0x0007,0x000F,0x001F,0x003F,0x007F,
  0x00FF,0x01FF,0x03FF,0x07FF,0x0FFF,0x1FFF,0x3FFF,0x7FFF,
};

static const xadUINT8 LZXtable_four[34] = {
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
};

/* ---------------------------------------------------------------------- */

/* Build a fast huffman decode table from the symbol bit lengths.         */
/* There is an alternate algorithm which is faster but also more complex. */

static xadINT32 LZXmake_decode_table(xadINT32 number_symbols, xadINT32 LZXtable_size,
                      xadUINT8 *length, unsigned short *table)
{
 register xadUINT8 bit_num = 0;
 register xadINT32 symbol;
 xadUINT32 leaf; /* could be a register */
 xadUINT32 LZXtable_mask, bit_mask, pos, fill, next_symbol, reverse;
 xadINT32 abort = 0;

 pos = 0; /* consistantly used as the current position in the decode table */

 bit_mask = LZXtable_mask = 1 << LZXtable_size;

 bit_mask >>= 1; /* don't do the first number */
 bit_num++;

 while((!abort) && (bit_num <= LZXtable_size))
 {
  for(symbol = 0; symbol < number_symbols; symbol++)
  {
   if(length[symbol] == bit_num)
   {
    reverse = pos; /* reverse the order of the position's bits */
    leaf = 0;
    fill = LZXtable_size;
    do /* reverse the position */
    {
     leaf = (leaf << 1) + (reverse & 1);
     reverse >>= 1;
    } while(--fill);
    if((pos += bit_mask) > LZXtable_mask)
    {
     abort = 1;
     break; /* we will overrun the table! abort! */
    }
    fill = bit_mask;
    next_symbol = 1 << bit_num;
    do
    {
     table[leaf] = symbol;
     leaf += next_symbol;
    } while(--fill);
   }
  }
  bit_mask >>= 1;
  bit_num++;
 }

 if((!abort) && (pos != LZXtable_mask))
 {
  for(symbol = pos; (xadUINT32)symbol < LZXtable_mask; symbol++) /* clear the rest of the table */
  {
   reverse = symbol; /* reverse the order of the position's bits */
   leaf = 0;
   fill = LZXtable_size;
   do /* reverse the position */
   {
    leaf = (leaf << 1) + (reverse & 1);
    reverse >>= 1;
   } while(--fill);
   table[leaf] = 0;
  }
  next_symbol = LZXtable_mask >> 1;
  pos <<= 16;
  LZXtable_mask <<= 16;
  bit_mask = 32768;

  while((!abort) && (bit_num <= 16))
  {
   for(symbol = 0; symbol < number_symbols; symbol++)
   {
    if(length[symbol] == bit_num)
    {
     reverse = pos >> 16; /* reverse the order of the position's bits */
     leaf = 0;
     fill = LZXtable_size;
     do /* reverse the position */
     {
      leaf = (leaf << 1) + (reverse & 1);
      reverse >>= 1;
     } while(--fill);
     for(fill = 0; fill < (xadUINT32) bit_num - LZXtable_size; fill++)
     {
      if(table[leaf] == 0)
      {
       table[(next_symbol << 1)] = 0;
       table[(next_symbol << 1) + 1] = 0;
       table[leaf] = next_symbol++;
      }
      leaf = table[leaf] << 1;
      leaf += (pos >> (15 - fill)) & 1;
     }
     table[leaf] = symbol;
     if((pos += bit_mask) > LZXtable_mask)
     {
      abort = 1;
      break; /* we will overrun the table! abort! */
     }
    }
   }
   bit_mask >>= 1;
   bit_num++;
  }
 }
 if(pos != LZXtable_mask) abort = 1; /* the table is incomplete! */

 return(abort);
}

/* ---------------------------------------------------------------------- */
/* Read and build the decrunch tables. There better be enough data in the */
/* source buffer or it's stuffed. */

static xadINT32 LZX_read_literal_table(struct LZXDecrData *decr)
{
 register xadUINT32 control;
 register xadINT32 shift;
 xadUINT32 temp; /* could be a register */
 xadUINT32 symbol, pos, count, fix, max_symbol;
 xadUINT8 *source;
 xadINT32 abort = 0;

 source = decr->source;
 control = decr->control;
 shift = decr->shift;

 if(shift < 0) /* fix the control word if necessary */
 {
  shift += 16;
  control += *source++ << (8 + shift);
  control += *source++ << shift;
 }

/* read the decrunch method */

 decr->decrunch_method = control & 7;
 control >>= 3;
 if((shift -= 3) < 0)
 {
  shift += 16;
  control += *source++ << (8 + shift);
  control += *source++ << shift;
 }

/* Read and build the offset huffman table */

 if((!abort) && (decr->decrunch_method == 3))
 {
  for(temp = 0; temp < 8; temp++)
  {
   decr->offset_len[temp] = control & 7;
   control >>= 3;
   if((shift -= 3) < 0)
   {
    shift += 16;
    control += *source++ << (8 + shift);
    control += *source++ << shift;
   }
  }
  abort = LZXmake_decode_table(8, 7, decr->offset_len, decr->offset_table);
 }

/* read decrunch length */

 if(!abort)
 {
  decr->decrunch_length = (control & 255) << 16;
  control >>= 8;
  if((shift -= 8) < 0)
  {
   shift += 16;
   control += *source++ << (8 + shift);
   control += *source++ << shift;
  }
  decr->decrunch_length += (control & 255) << 8;
  control >>= 8;
  if((shift -= 8) < 0)
  {
   shift += 16;
   control += *source++ << (8 + shift);
   control += *source++ << shift;
  }
  decr->decrunch_length += (control & 255);
  control >>= 8;
  if((shift -= 8) < 0)
  {
   shift += 16;
   control += *source++ << (8 + shift);
   control += *source++ << shift;
  }
 }

/* read and build the huffman literal table */

 if((!abort) && (decr->decrunch_method != 1))
 {
  pos = 0;
  fix = 1;
  max_symbol = 256;

  do
  {
   for(temp = 0; temp < 20; temp++)
   {
    decr->huffman20_len[temp] = control & 15;
    control >>= 4;
    if((shift -= 4) < 0)
    {
     shift += 16;
     control += *source++ << (8 + shift);
     control += *source++ << shift;
    }
   }
   abort = LZXmake_decode_table(20, 6, decr->huffman20_len, decr->huffman20_table);

   if(abort) break; /* argh! table is corrupt! */

   do
   {
    if((symbol = decr->huffman20_table[control & 63]) >= 20)
    {
     do /* symbol is longer than 6 bits */
     {
      symbol = decr->huffman20_table[((control >> 6) & 1) + (symbol << 1)];
      if(!shift--)
      {
       shift += 16;
       control += *source++ << 24;
       control += *source++ << 16;
      }
      control >>= 1;
     } while(symbol >= 20);
     temp = 6;
    }
    else
    {
     temp = decr->huffman20_len[symbol];
    }
    control >>= temp;
    if((shift -= temp) < 0)
    {
     shift += 16;
     control += *source++ << (8 + shift);
     control += *source++ << shift;
    }
    switch(symbol)
    {
     case 17:
     case 18:
     {
      if(symbol == 17)
      {
       temp = 4;
       count = 3;
      }
      else /* symbol == 18 */
      {
       temp = 6 - fix;
       count = 19;
      }
      count += (control & LZXmask_bits[temp]) + fix;
      control >>= temp;
      if((shift -= temp) < 0)
      {
       shift += 16;
       control += *source++ << (8 + shift);
       control += *source++ << shift;
      }
      while((pos < max_symbol) && (count--))
       decr->literal_len[pos++] = 0;
      break;
     }
     case 19:
     {
      count = (control & 1) + 3 + fix;
      if(!shift--)
      {
       shift += 16;
       control += *source++ << 24;
       control += *source++ << 16;
      }
      control >>= 1;
      if((symbol = decr->huffman20_table[control & 63]) >= 20)
      {
       do /* symbol is longer than 6 bits */
       {
        symbol = decr->huffman20_table[((control >> 6) & 1) + (symbol << 1)];
        if(!shift--)
        {
         shift += 16;
         control += *source++ << 24;
         control += *source++ << 16;
        }
        control >>= 1;
       } while(symbol >= 20);
       temp = 6;
      }
      else
      {
       temp = decr->huffman20_len[symbol];
      }
      control >>= temp;
      if((shift -= temp) < 0)
      {
       shift += 16;
       control += *source++ << (8 + shift);
       control += *source++ << shift;
      }
      symbol = LZXtable_four[decr->literal_len[pos] + 17 - symbol];
      while((pos < max_symbol) && (count--))
       decr->literal_len[pos++] = symbol;
      break;
     }
     default:
     {
      symbol = LZXtable_four[decr->literal_len[pos] + 17 - symbol];
      decr->literal_len[pos++] = symbol;
      break;
     }
    }
   } while(pos < max_symbol);
   fix--;
   max_symbol += 512;
  } while(max_symbol == 768);

  if(!abort)
   abort = LZXmake_decode_table(768, 12, decr->literal_len, decr->literal_table);
 }

 decr->control = control;
 decr->shift = shift;
 decr->source = source;
 return(abort);
}

/* ---------------------------------------------------------------------- */

/* Fill up the decrunch buffer. Needs lots of overrun for both destination */
/* and source buffers. Most of the time is spent in this routine so it's  */
/* pretty damn optimized. */
static void LZXdecrunch(struct LZXDecrData *decr)
{
 register xadUINT32 control;
 register xadINT32 shift;
 xadUINT32 temp; /* could be a register */
 xadUINT32 symbol, count;
 xadUINT8 *string, *source, *destination;

 control = decr->control;
 shift = decr->shift;
 source = decr->source;
 destination = decr->destination;

 do
 {
  if((symbol = decr->literal_table[control & 4095]) >= 768)
  {
   control >>= 12;
   if((shift -= 12) < 0)
   {
    shift += 16;
    control += *source++ << (8 + shift);
    control += *source++ << shift;
   }
   do /* literal is longer than 12 bits */
   {
    symbol = decr->literal_table[(control & 1) + (symbol << 1)];
    if(!shift--)
    {
     shift += 16;
     control += *source++ << 24;
     control += *source++ << 16;
    }
    control >>= 1;
   } while(symbol >= 768);
  }
  else
  {
   temp = decr->literal_len[symbol];
   control >>= temp;
   if((shift -= temp) < 0)
   {
    shift += 16;
    control += *source++ << (8 + shift);
    control += *source++ << shift;
   }
  }
  if(symbol < 256)
  {
   *destination++ = symbol;
  }
  else
  {
   symbol -= 256;
   count = LZXtable_two[temp = symbol & 31];
   temp = LZXtable_one[temp];
   if((temp >= 3) && (decr->decrunch_method == 3))
   {
    temp -= 3;
    count += ((control & LZXmask_bits[temp]) << 3);
    control >>= temp;
    if((shift -= temp) < 0)
    {
     shift += 16;
     control += *source++ << (8 + shift);
     control += *source++ << shift;
    }
    count += (temp = decr->offset_table[control & 127]);
    temp = decr->offset_len[temp];
   }
   else
   {
    count += control & LZXmask_bits[temp];
    if(!count) count = decr->last_offset;
   }
   control >>= temp;
   if((shift -= temp) < 0)
   {
    shift += 16;
    control += *source++ << (8 + shift);
    control += *source++ << shift;
   }
   decr->last_offset = count;

   count = LZXtable_two[temp = (symbol >> 5) & 15] + 3;
   temp = LZXtable_one[temp];
   count += (control & LZXmask_bits[temp]);
   control >>= temp;
   if((shift -= temp) < 0)
   {
    shift += 16;
    control += *source++ << (8 + shift);
    control += *source++ << shift;
   }
   string = (decr->decrunch_buffer + decr->last_offset < destination) ?
            destination - decr->last_offset : destination + 65536 - decr->last_offset;
   do
   {
    *destination++ = *string++;
   } while(--count);
  }
 } while((destination < decr->destination_end) && (source < decr->source_end));

 decr->control = control;
 decr->shift = shift;
 decr->source = source;
 decr->destination = destination;
}

/* ---------------------------------------------------------------------- */

static xadINT32 LZXextract(struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase,
xadUINT32 unpack_size, xadUINT32 rescrc)
{
  xadUINT8 *temp;
  xadUINT32 count, crc = (xadUINT32) ~0;
  xadINT32 err;
  struct LZXDecrData *decr;

  decr = (struct LZXDecrData *) ai->xai_PrivateClient;

  while(unpack_size > 0)
  {
    if(decr->pos == decr->destination) /* time to fill the buffer? */
    {
      /* check if we have enough data and read some if not */
      if(decr->source >= decr->source_end) /* have we exhausted the current read buffer? */
      {
        temp = decr->read_buffer;
        if((count = temp - decr->source + 16384))
        {
          do /* copy the remaining overrun to the start of the buffer */
          {
            *temp++ = *(decr->source++);
          } while(--count);
        }
        decr->source = decr->read_buffer;
        count = decr->source - temp + 16384;

        if(decr->pack_size < count)
          count = decr->pack_size; /* make sure we don't read too much */

        if((err = xadHookAccess(XADM XADAC_READ, count, temp, ai)))
          return err;
        decr->pack_size -= count;

        temp += count;
        if(decr->source >= temp)
          return XADERR_DECRUNCH; /* argh! no more data! */
      } /* if(decr->source >= decr->source_end) */

    /* check if we need to read the tables */
    if(decr->decrunch_length <= 0)
    {
      if(LZX_read_literal_table(decr))
        return XADERR_DECRUNCH; /* argh! can't make huffman tables! */
    }

    /* unpack some data */
    if(decr->destination >= decr->decrunch_buffer + 258 + 65536)
    {
      if((count = decr->destination - decr->decrunch_buffer - 65536))
      {
        temp = (decr->destination = decr->decrunch_buffer) + 65536;
        do /* copy the overrun to the start of the buffer */
        {
          *(decr->destination++) = *temp++;
        } while(--count);
      }
      decr->pos = decr->destination;
    }
    decr->destination_end = decr->destination + decr->decrunch_length;
    if(decr->destination_end > decr->decrunch_buffer + 258 + 65536)
      decr->destination_end = decr->decrunch_buffer + 258 + 65536;
    temp = decr->destination;

    LZXdecrunch(decr);

    decr->decrunch_length -= (decr->destination - temp);
   }

/* calculate amount of data we can use before we need to fill the buffer again */
   count = decr->destination - decr->pos;
   if(count > unpack_size)
     count = unpack_size; /* take only what we need */

   if(rescrc) /* when no CRC given, then skip writing */
   {
     crc = xadCalcCRC32(XADM XADCRC32_ID1, crc, count, decr->pos);
     if((err = xadHookAccess(XADM XADAC_WRITE, count, decr->pos, ai)))
       return err;
   }
   unpack_size -= count;
   decr->pos += count;
   decr->DataPos += count;
 }

 if(rescrc && ~crc != rescrc)
   return XADERR_CHECKSUM;

 return 0;
}

/* ---------------------------------------------------------------------- */

XADUNARCHIVE(LZX)
{
  struct xadFileInfo *fi;
  struct LZXDecrData *decr = 0;
  xadINT32 ret = 0, i;
  xadUINT32 crc = (xadUINT32) ~0;

  fi = ai->xai_CurFile;
  if(!ai->xai_PrivateClient || LZXDD(ai)->ArchivePos != LZXPE(fi)->ArchivePos
  || LZXDD(ai)->DataPos > LZXPE(fi)->DataStart)
  {
    if(ai->xai_PrivateClient) /* free the unneeded data */
    {
      xadFreeObjectA(XADM ai->xai_PrivateClient, 0);
      ai->xai_PrivateClient = 0;
    }
    if((i = LZXPE(fi)->ArchivePos - ai->xai_InPos))
    {
      if((ret = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) i, 0, ai)))
        return ret;
    }
  }

  switch(LZXPE(fi)->PackMode)
  {
  case LZXHDR_PACK_STORE:
    if(!(ret = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC32, &crc, TAG_DONE)) && ~crc != LZXPE(fi)->CRC)
      ret = XADERR_CHECKSUM;
    break;
  case LZXHDR_PACK_NORMAL:
    if(!ai->xai_PrivateClient && !(decr = (struct LZXDecrData *)
    xadAllocVec(XADM sizeof(struct LZXDecrData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      ret = XADERR_NOMEMORY;
    else
    {
      if(decr)
      {
        decr->ArchivePos = LZXPE(fi)->ArchivePos;
        decr->DataPos = 0;
        decr->shift = -16;
        decr->last_offset = 1;
        decr->source_end = (decr->source = decr->read_buffer + 16384) - 1024;
        decr->pos = decr->destination_end = decr->destination = decr->decrunch_buffer + 258 + 65536;
        decr->pack_size = fi->xfi_Flags & XADFIF_GROUPED ?
        fi->xfi_GroupCrSize : fi->xfi_CrunchSize;
        ai->xai_PrivateClient = decr;
      }

      if((i = LZXPE(fi)->DataStart - LZXDD(ai)->DataPos))
        ret = LZXextract(ai, xadMasterBase, (xadUINT32)i, 0);

      if(!ret)
        ret = LZXextract(ai, xadMasterBase, fi->xfi_Size, LZXPE(fi)->CRC);

      /* free no longer needed temporary buffer and stuff structure */
      if(ret || !(fi->xfi_Flags & XADFIF_GROUPED) || (fi->xfi_Flags & XADFIF_ENDOFGROUP))
      {
        xadFreeObjectA(XADM ai->xai_PrivateClient, 0);
        ai->xai_PrivateClient = 0;
      }
    }
    break;
  default: ret = XADERR_DECRUNCH; break;
  }

  return ret;
}

XADFREE(LZX)
{
  if(ai->xai_PrivateClient) /* decrunch buffer */
  {
    xadFreeObjectA(XADM ai->xai_PrivateClient, 0);
    ai->xai_PrivateClient = 0;
  }
}

XADFIRSTCLIENT(LZX) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LZX_VERSION,
  LZX_REVISION,
  10,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_LZX,
  "LZX",
  XADRECOGDATAP(LZX),
  XADGETINFOP(LZX),
  XADUNARCHIVEP(LZX),
  XADFREEP(LZX)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(LZX)

#endif /* XADMASTER_LZX_C */
