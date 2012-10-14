#import "XADStuffItOldHandles.h"
#import "Checksums.h"

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
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

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
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
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



@implementation XADStuffItMWHandle

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32];
	xadINT32 err=SIT_mw(io);
	if(!err) err=xadIOWriteBuf(io);
	return err;
}

@end

@implementation XADStuffIt14Handle

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32];
	xadINT32 err=SIT_14(io);
	if(!err) err=xadIOWriteBuf(io);
	return err;
}
@end

