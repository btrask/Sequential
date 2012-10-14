#ifndef XADMASTER_XADIO_COMPRESS_C
#define XADMASTER_XADIO_COMPRESS_C

/*  $Id: xadIO_Compress.c,v 1.6 2005/06/23 14:54:41 stoecker Exp $
    UNIX Compress

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

#define UCOMPMAXCODE(n) (((xadUINT32) 1 << (n)) - 1)
#define UCOMPBITS          16
#define UCOMPSTACKSIZE   8000
#define UCOMPFIRST        257           /* first free entry */
#define UCOMPCLEAR        256           /* table clear output code */
#define UCOMPINIT_BITS      9           /* initial number of bits/code */
#define UCOMPBIT_MASK    0x1f
#define UCOMPBLOCK_MASK  0x80

struct UCompData {
  xadINT16    clear_flg;
  xadUINT16   n_bits;                 /* number of bits/code */
  xadUINT16   maxbits;                /* user settable max # bits/code */
  xadUINT32   maxcode;                /* maximum code, given n_bits */
  xadUINT32   maxmaxcode;
  xadINT32    free_ent;
  xadINT32    offset;
  xadINT32    size;
  xadUINT16 * tab_prefixof;
  xadSTRPTR   tab_suffixof;
  xadUINT8    stack[UCOMPSTACKSIZE];
  xadUINT8    buf[UCOMPBITS];
};

/* Read one code from input. If EOF, return -1. */
static xadINT32 UCompgetcode(struct xadInOut *io, struct UCompData *cd)
{
  xadINT32 code, r_off, bits;
  xadUINT8 *bp = cd->buf;

  if(cd->clear_flg > 0 || cd->offset >= cd->size || cd->free_ent > cd->maxcode)
  {
    /*
     * If the next entry will be too big for the current code
     * size, then we must increase the size.  This implies reading
     * a new buffer full, too.
     */
    if(cd->free_ent > cd->maxcode)
    {
      if(++cd->n_bits == cd->maxbits)
        cd->maxcode = cd->maxmaxcode;   /* won't get any bigger now */
      else
        cd->maxcode = UCOMPMAXCODE(cd->n_bits);
    }
    if(cd->clear_flg > 0)
    {
      cd->maxcode = UCOMPMAXCODE(cd->n_bits = UCOMPINIT_BITS);
      cd->clear_flg = 0;
    }

    /* This reads maximum n_bits characters into buf */
    cd->size = 0;
    while(cd->size < cd->n_bits && !(io->xio_Flags
    & (XADIOF_LASTINBYTE|XADIOF_ERROR)))
      cd->buf[cd->size++] = xadIOGetChar(io);
    if(cd->size <= 0)
      return -1;

    cd->offset = 0;
    /* Round size down to integral number of codes */
    cd->size = (cd->size << 3) - (cd->n_bits - 1);
  }

  r_off = cd->offset;
  bits = cd->n_bits;

  /* Get to the first byte. */
  bp += (r_off >> 3);
  r_off &= 7;

  /* Get first part (low order bits) */
  code = (*bp++ >> r_off);
  bits -= (8 - r_off);
  r_off = 8 - r_off;                    /* now, offset into code word */

  /* Get any 8 bit parts in the middle (<=1 for up to 16 bits). */
  if(bits >= 8)
  {
    code |= *bp++ << r_off;
    r_off += 8;
    bits -= 8;
  }

  /* high order bits. */
  code |= (*bp & ((1<<bits)-1)) << r_off;
  cd->offset += cd->n_bits;

  return code;
}

/* Decompress. This routine adapts to the codes in the file building the
 * "string" table on-the-fly; requiring no table to be stored in the
 * compressed file.
 */
static xadINT32 xadIO_Compress(struct xadInOut *io, xadUINT8 bitinfo)
{
  xadINT32 err = 0;
  struct UCompData *cd;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  if((bitinfo & UCOMPBIT_MASK) < UCOMPINIT_BITS)
    return XADERR_ILLEGALDATA;

  if((cd = (struct UCompData *) xadAllocVec(XADM sizeof(struct UCompData),
  XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    xadINT32 finchar, code, oldcode, incode, blockcomp;
    xadSTRPTR stackp, stack, stackend;

    stackp = (xadSTRPTR) (stack = (xadSTRPTR) cd->stack);
    stackend = stack+UCOMPSTACKSIZE;
    cd->maxbits = bitinfo & UCOMPBIT_MASK;
    blockcomp = bitinfo & UCOMPBLOCK_MASK;
    cd->maxmaxcode = 1 << cd->maxbits;
    cd->maxcode = UCOMPMAXCODE(cd->n_bits = UCOMPINIT_BITS);
    cd->free_ent = blockcomp ? UCOMPFIRST : 256;
/*    cd->clear_flg = cd->offset = cd->size = 0; */

    if((cd->tab_prefixof = (xadUINT16 *) xadAllocVec(XADM sizeof(xadUINT16)
    *cd->maxmaxcode, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      if((cd->tab_suffixof = (xadSTRPTR) xadAllocVec(XADM cd->maxmaxcode,
      XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
        /* Initialize the first 256 entries in the table. */
        for(code = 255; code >= 0; code--)
        {
/*        cd->tab_prefixof[code] = 0; */
          cd->tab_suffixof[code] = (xadUINT8) code;
        }

        if((finchar = oldcode = UCompgetcode(io, cd)) == -1)
          err = XADERR_DECRUNCH;
        else
        {
          xadIOPutChar(io, finchar); /* first code must be 8 bits = xadUINT8 */

          while((code = UCompgetcode(io, cd)) > -1)
          {
            if((code == UCOMPCLEAR) && blockcomp)
            {
              for(code = 255; code >= 0; code--)
                cd->tab_prefixof[code] = 0;
              cd->clear_flg = 1;
              cd->free_ent = UCOMPFIRST - 1;
              if((code = UCompgetcode(io, cd)) == -1)
                break;                                /* O, untimely death! */
            }
            incode = code;

            /* Special case for KwKwK string. */
            if(code >= cd->free_ent)
            {
              if(code > cd->free_ent)
              {
                io->xio_Error =  XADERR_ILLEGALDATA;
                break;
              }
              *stackp++ = finchar;
              code = oldcode;
            }

            /* Generate output characters in reverse order */
            while(stackp < stackend && code >= 256)
            {
              *stackp++ = cd->tab_suffixof[code];
              code = cd->tab_prefixof[code];
            }
            if(stackp >= stackend)
            {
              err = XADERR_ILLEGALDATA;
              break;
            }
            *(stackp++) = finchar = cd->tab_suffixof[code];

            /* And put them out in forward order */
            do
            {
              xadIOPutChar(io, *(--stackp));
            } while(stackp > stack);

            /* Generate the new entry. */
            if((code = cd->free_ent) < cd->maxmaxcode)
            {
              cd->tab_prefixof[code] = (xadUINT16) oldcode;
              cd->tab_suffixof[code] = finchar;
              cd->free_ent = code+1;
            }
            /* Remember previous code. */
            oldcode = incode;
          }
          if(!err)
            err = io->xio_Error;
        }
        xadFreeObjectA(XADM cd->tab_suffixof, 0);
      }
      else
        err = XADERR_NOMEMORY;
      xadFreeObjectA(XADM cd->tab_prefixof, 0);
    }
    else
      err = XADERR_NOMEMORY;
    xadFreeObjectA(XADM cd, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

#endif /* XADMASTER_XADIO_COMPRESS_C */
