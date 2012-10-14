#import "XADCrunchHandles.h"
#import "Checksums.h"

#define xadIOPutFuncRLE90TYPE2 ((xadPTR) 0x80000000)
/* xx9000 --> xx90 */
/* xx90yy --> xx(yy times) */
/* io->xio_PutFuncPrivate may be initialized with 0x80000000 for Type 2 mode */
/* Type 2 mode: xx9001 --> xx90 instead of xx */
static xadUINT8 xadIOPutFuncRLE90(struct xadInOut *io, xadUINT8 data)
{
  xadUINT32 a, num;

  a = (xadUINT32)(uintptr_t) io->xio_PutFuncPrivate;

  if(a & 0x100) /* was RLE mode */
  {
    if(!data || (data == 1 && (a & 0x80000000))) { a = 0x90; num = 1; }
    else { a &= 0xFF; num = data-1; }
  }
  else if(data == 0x90) { num = 0; a |= 0x100; }
  else { num = 1; a = data; }

  io->xio_PutFuncPrivate = (xadPTR)(uintptr_t) a;

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

  return data;
}

static void xadIOChecksum(struct xadInOut *io, xadUINT32 size)
{
  xadUINT32 s, i;

  s = (xadUINT32)(uintptr_t) io->xio_OutFuncPrivate;

  for(i = 0; i < size; i++)
    s += io->xio_OutBuffer[i];
  /* byte sum */

  io->xio_OutFuncPrivate  = (xadPTR)(uintptr_t) s;
}

/* Crunch algorithm *******************************************************************************/

#define CRUNCH_TABLE_SIZE  4096 /* size of main lzw table for 12 bit codes */
#define CRUNCH_XLATBL_SIZE 5003 /* size of physical translation table */

/* special values for predecessor in table */
#define CRUNCH_NOPRED 0x3fff     /* no predecessor in table */
#define CRUNCH_EMPTY  0x8000     /* empty table entry (xlatbl only) */
#define CRUNCH_REFERENCED 0x2000 /* table entry referenced if this bit set */
#define CRUNCH_IMPRED 0x7fff     /* impossible predecessor */

#define CRUNCH_EOFCOD 0x100      /* special code for end-of-file */
#define CRUNCH_RSTCOD 0x101      /* special code for adaptive reset */
#define CRUNCH_NULCOD 0x102      /* special filler code */
#define CRUNCH_SPRCOD 0x103      /* spare special code */

struct CrunchEntry
{
  xadUINT16 predecessor;         /* index to previous entry, if any */
  xadUINT8 suffix;                   /* character suffixed to previous entries */
};

struct CrunchData
{
  struct xadInOut *  io;
  xadUINT16              lastpr;    /* last predecessor (in main loop) */
  xadUINT16              entry; /* next available main table entry */
  xadUINT16              xlatbl[CRUNCH_XLATBL_SIZE]; /* auxilliary physical translation table */
  struct CrunchEntry table[CRUNCH_TABLE_SIZE];   /* main table */
  xadUINT8              stack[CRUNCH_TABLE_SIZE];   /* byte string stack used by decode */
  xadUINT8              codlen;    /* variable code length in bits (9-12) */
  xadUINT8              fulflg;    /* full flag - set once main table is full */
  xadUINT8              entflg;    /* inhibit main loop from entering this code */
  xadUINT8              finchar;   /* first character of last substring output */
};

/* enter the next code into the lzw table */
static void CRUNCHenterxOLD(struct CrunchData *cd, xadUINT16 pred, xadUINT8 suff)
{
  xadINT32 lasthash,hashval,a;

  if(pred == CRUNCH_NOPRED && !suff)
    hashval=0x800; /* special case (leaving the zero code free for EOF) */
  else
  {
    /* normally we do a slightly awkward mid-square thing */
    a = (((pred+suff)|0x800)&0x1FFF);
    hashval = (a>>1);
    hashval = (((hashval*(hashval+(a&1)))>>4)&0xfff);
  }

  /* first, check link chain from there */
  while(cd->xlatbl[hashval] != CRUNCH_EMPTY)
  {
    hashval = cd->xlatbl[hashval];
  }

  if(hashval >= CRUNCH_TABLE_SIZE)
  {
    cd->io->xio_Error = XADERR_DECRUNCH;
    return;
  }

  if(cd->table[hashval].predecessor != CRUNCH_EMPTY)
  {
    lasthash=hashval;
    /* slightly odd approach if it's not in that - first try skipping
     * 101 entries, then try them one-by-one. If should be impossible
     * for this to loop indefinitely, if the table isn't full. (And we
     * shouldn't have been called if it was full...)
     */
    hashval += 101;
    hashval &= 0xfff;
    for(a = 0; cd->table[hashval].predecessor != CRUNCH_EMPTY
    && a < CRUNCH_TABLE_SIZE; ++a)
    {
      ++hashval;
      hashval &= 0xfff;
    }

    /* add link to here from the end of the chain */
    cd->xlatbl[lasthash] = hashval;
  }

  /* make the new entry */
  cd->table[hashval].predecessor = pred;
  cd->table[hashval].suffix = suff;
  ++cd->entry;
}

/* enter the next code into the lzw table */
static void CRUNCHenterx(struct CrunchData *cd, xadUINT16 pred, xadUINT8 suff)
{
  struct CrunchEntry *ep = cd->table + cd->entry;
  xadINT32 disp;
  xadUINT16 *p;
  /* update xlatbl to point to this entry */
  /* find an empty entry in xlatbl which hashes from this predecessor/suffix */
  /* combo, and store the index of the next available lzw table entry in it */

  disp = ((((pred>>4) & 0xff) ^suff) | ((pred&0xf)<<8)) + 1;
  p = cd->xlatbl+disp;
  disp -= CRUNCH_XLATBL_SIZE;

  /*follow secondary hash chain as necessary to find an empty slot*/
  while(*p != CRUNCH_EMPTY)
  {
    p += disp;
    if(p < cd->xlatbl || p > cd->xlatbl+CRUNCH_XLATBL_SIZE)
      p += CRUNCH_XLATBL_SIZE;
  }

  /* stuff next available index into this slot */
  *p = cd->entry;

  /* make the new entry */
  ep->predecessor = pred;
  ep->suffix = suff;
  ++cd->entry;

  /* if only one entry of the current code length remains, update to */
  /* next code length because main loop is reading one code ahead */
  if(cd->entry >= ((1<<cd->codlen)-1))
  {
    if(cd->codlen < 12)
    {
      /* table not full, just make length one more bit */
      ++cd->codlen;
    }
    else
    {
      /* table almost full (fulflg==0) or full (fulflg==1) */
      /* just increment fulflg - when it gets to 2 we will */
      /* never be called again */
      ++cd->fulflg;
    }
  }
}

/* initialize the lzw and physical translation tables */
static void CRUNCHinitb2(struct CrunchData *cd)
{
  xadINT32 i;

  cd->entry  = 0;
  cd->fulflg = 0;
  cd->codlen = 9;
  cd->entflg = 1;

  /* first mark all entries of xlatbl as empty */
  for(i = 0; i < CRUNCH_XLATBL_SIZE; ++i)
    cd->xlatbl[i] = CRUNCH_EMPTY;
  /* enter atomic and reserved codes into lzw table */
  for(i = 0; i < 0x100; ++i)
    CRUNCHenterx(cd, CRUNCH_NOPRED, i); /* first 256 atomic codes */
  for(i=0; i < 4; ++i)
    CRUNCHenterx(cd, CRUNCH_IMPRED, 0); /* reserved codes */
}

/* attempt to reassign an existing code which has */
/* been defined, but never referenced */
static void CRUNCHentfil(struct CrunchData *cd, xadUINT16 pred, xadUINT8 suff)
{
  xadINT32 disp;
  struct CrunchEntry *ep;
  xadUINT16 *p;

  disp = ((((pred>>4) & 0xff) ^suff) | ((pred&0xf)<<8)) + 1;
  p = cd->xlatbl+disp;
  disp -= CRUNCH_XLATBL_SIZE;

  /* search the candidate codes (all those which hash from this new */
  /* predecessor and suffix) for an unreferenced one */
  while(*p != CRUNCH_EMPTY)
  {
    /* candidate code */
    ep = cd->table + *p;
    if(((ep->predecessor)&CRUNCH_REFERENCED)==0)
    {
      /* entry reassignable, so do it! */
      ep->predecessor = pred;
      ep->suffix = suff;
      /* discontinue search */
      break;
    }
    /* candidate unsuitable - follow secondary hash chain */
    /* and keep searching */
    p += disp;
    if(p < cd->xlatbl || p > cd->xlatbl+CRUNCH_XLATBL_SIZE)
      p += CRUNCH_XLATBL_SIZE;
  }
}

/* decode this code */
static xadUINT8 CRUNCHdecode(struct CrunchData *cd, xadUINT16 code)
{
  xadUINT8 *stackp; /* byte string stack pointer */
  struct CrunchEntry *ep = cd->table + code;

  if(code >= cd->entry)
  {
    /* the ugly exception, "WsWsW" */
    cd->entflg = 1;
    CRUNCHenterx(cd, cd->lastpr, cd->finchar);
  }

  /* mark corresponding table entry as referenced */
  ep->predecessor |= CRUNCH_REFERENCED;

  /* walk back the lzw table starting with this code */
  stackp = cd->stack;
  while(ep > cd->table + 255) /* i.e. code not atomic */
  {
    *(stackp++) = ep->suffix;
    ep = cd->table + (ep->predecessor&0xFFF);
  }
  /* then emit all bytes corresponding to this code in forward order */
  cd->finchar = xadIOPutChar(cd->io, ep->suffix);
  while(stackp > cd->stack)     /* the rest */
    xadIOPutChar(cd->io, *(--stackp));
  return cd->entflg;
}

xadINT32 CRUNCHuncrunch(struct xadInOut *io, xadUINT32 mode)
{
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadUINT16 pred; /* current predecessor (in main loop) */
  struct CrunchData *cd;
  xadINT32 err, i;

  if((cd = (struct CrunchData *) xadAllocVec(XADM sizeof(struct CrunchData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    cd->io = io;

    /* main decoding loop */
    pred = CRUNCH_NOPRED;
    if(mode)
    {
      xadUINT8 *stackp, *stacke; /* byte string stack pointer */
      struct CrunchEntry *ep;

      stackp = cd->stack;
      stacke = cd->stack+CRUNCH_TABLE_SIZE-2;

      /* first mark all entries of xlatbl as empty */
      for(i = 0; i < CRUNCH_TABLE_SIZE; ++i)
        cd->xlatbl[i] = CRUNCH_EMPTY;
      cd->table[0].predecessor = CRUNCH_NOPRED;
      for(i = 1; i < CRUNCH_TABLE_SIZE; ++i)
        cd->table[i].predecessor = CRUNCH_EMPTY;
      /* enter atomic and reserved codes into lzw table */
      for(i = 0; i < 0x100; ++i)
        CRUNCHenterxOLD(cd, CRUNCH_NOPRED, i); /* first 256 atomic codes */

      while(!io->xio_Error)
      {
        /* remember last predecessor */
        cd->lastpr = pred;
        /* read and process one code */

        pred = xadIOGetBitsHigh(io, 12);

        if(pred == 0) /* end-of-file code */
          break; /* all lzw codes read */

        ep = cd->table + (cd->table[pred].predecessor == CRUNCH_EMPTY ? cd->lastpr : pred);

        /* walk back the lzw table starting with this code */
        while(ep->predecessor < CRUNCH_TABLE_SIZE)
        {
          if(stackp >= stacke)
          {
            cd->io->xio_Error = XADERR_DECRUNCH;
            break;
          }
          *(stackp++) = ep->suffix;
          ep = cd->table + ep->predecessor;
        }
        if(ep->predecessor != CRUNCH_EMPTY)
          *(stackp++) = ep->suffix;

        cd->finchar = *(stackp-1);

        /* then emit all bytes corresponding to this code in forward order */
        while(stackp > cd->stack)
          xadIOPutChar(cd->io, *(--stackp));

        if(cd->table[pred].predecessor == CRUNCH_EMPTY)
          xadIOPutChar(cd->io, cd->finchar);

        if(cd->entry < CRUNCH_TABLE_SIZE-1 &&
        cd->lastpr != CRUNCH_NOPRED) /* new code */
          CRUNCHenterxOLD(cd, cd->lastpr, cd->finchar);
      }
    }
    else
    {
      CRUNCHinitb2(cd);

      while(!io->xio_Error)
      {
        /* remember last predecessor */
        cd->lastpr = pred;
        /* read and process one code */

        pred = xadIOGetBitsHigh(io, cd->codlen);
        if(pred == CRUNCH_EOFCOD) /* end-of-file code */
        {
          break; /* all lzw codes read */
        }
        else if(pred == CRUNCH_RSTCOD) /* reset code */
        {
          pred = CRUNCH_NOPRED;
          CRUNCHinitb2(cd);
        }
        else if(pred == CRUNCH_NULCOD || pred == CRUNCH_SPRCOD)
        {
          pred = cd->lastpr;
        }
        else /* a normal code (nulls already deleted) */
        {
          /* check for table full */
          if(cd->fulflg != 2)
          {
            /* strategy if table not full */
            if(!CRUNCHdecode(cd, pred))
              CRUNCHenterx(cd, cd->lastpr, cd->finchar);
            else
              cd->entflg = 0;
          }
          else
          {
            /* strategy if table is full */
            CRUNCHdecode(cd, pred);
            CRUNCHentfil(cd, cd->lastpr, cd->finchar); /* attempt to reassign */
          }
        }
      }
    }
    err = io->xio_Error;
    xadFreeObjectA(XADM cd, 0);
  }
  else
    err = XADERR_NOMEMORY;
  return err;
}

/* AMPK3 - LZHUF **********************************************************************************/

static const xadUINT8 AMPK3_d_code[256] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,
  6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,
  10,10,10,10,10,10,10,10,11,11,11,11,11,11,11,11,
  12,12,12,12,13,13,13,13,14,14,14,14,15,15,15,15,
  16,16,16,16,17,17,17,17,18,18,18,18,19,19,19,19,
  20,20,20,20,21,21,21,21,22,22,22,22,23,23,23,23,
  24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,
  32,32,33,33,34,34,35,35,36,36,37,37,38,38,39,39,
  40,40,41,41,42,42,43,43,44,44,45,45,46,46,47,47,
  48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,
};

static const xadUINT8 AMPK3_d_len[256] = {
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
  4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
  5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
};

/* These defines need to reflect the largest values when thinking of
the field size (lowest threshold, highest lz_f and lz_n) */
#define AMPK3_LZ_N      4096
#define AMPK3_LZ_F      60
#define AMPK3_THRESHOLD 2

#define AMPK3_N_CHAR    (256 + 1 - AMPK3_THRESHOLD + AMPK3_LZ_F)
#define AMPK3_LZ_T      (AMPK3_N_CHAR * 2 - 1)  /* size of table */
#define AMPK3_LZ_R      (AMPK3_LZ_T - 1)  /* position of root */
#define AMPK3_MAX_FREQ  0x8000            /* updates tree when the */
                           /* root frequency comes to this value. */

struct AMPK3Data {
  xadUINT8      datfield[0x1000];
  xadUINT16     freq[AMPK3_LZ_T+1];
  xadUINT16     son[AMPK3_LZ_T];
  xadUINT16     parent[AMPK3_LZ_T+AMPK3_N_CHAR];
};

static xadINT32 DecrAMPK3(struct xadInOut *io, xadUINT32 type)
{
  xadUINT32 i, j, k, l, m, n, o;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct AMPK3Data *dat;
  xadUINT32 n_char, threshold, lz_t, lz_r, bitnum;

  switch(type)
  {
  case 2:
    threshold = 2;
    bitnum = 5;
    break;
  case 1:
    threshold = 2;
    bitnum = 6;
    break;
  default:
    threshold = 3;
    bitnum = 6;
    break;
  };

  n_char = 256 + 1 - threshold + AMPK3_LZ_F;
  lz_t = n_char * 2 - 1;
  lz_r = lz_t - 1;
  k = AMPK3_LZ_N-AMPK3_LZ_F;

  if(!(dat = (struct AMPK3Data *) xadAllocVec(XADM sizeof(struct AMPK3Data), XADMEMF_CLEAR)))
    return XADERR_NOMEMORY;

  for(i = 0; i < n_char; ++i)
  {
    dat->freq[i] = 1;
    dat->son[i] = lz_t+i;
    dat->parent[lz_t+i] = i;
  }
  /* i already has correct value n_char */
  for(j = 0; i <= lz_r; ++i)
  {
    dat->freq[i] = dat->freq[j] + dat->freq[j+1];
    dat->son[i] = j;
    dat->parent[j] = dat->parent[j+1] = i;
    j += 2;
  }
  dat->freq[i] = AMPK3_MAX_FREQ;

  memset(dat->datfield, ' ', k);

  while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
  {
    i = dat->son[lz_r];
    while(i < lz_t)
      i = dat->son[i+xadIOGetBitsHigh(io, 1)];

    if(dat->freq[lz_r] == 0x8000)
    {
      j = 0;
      for(n = 0; n < lz_t; ++n)
      {
        if(dat->son[n] >= lz_t)
        {
          dat->freq[j] = (dat->freq[n] + 1) >> 1;
          dat->son[j++] = dat->son[n];
        }
      }

      n = 0;
      for(j = n_char; j < lz_t; ++j)
      {
        o = dat->freq[j] = dat->freq[n] + dat->freq[n+1];
        for(l = j-1; o < dat->freq[l]; --l)
          ;
        ++l;

        for(m = j-1; m >= l; --m)
          dat->freq[m+1] = dat->freq[m];
        dat->freq[l] = o;

        for(m = j-1; m >= l; --m)
          dat->son[m+1] = dat->son[m];
        dat->son[l] = n;
        n += 2;
      }

      for(n = 0; n < lz_t; ++n)
      {
        j = dat->son[n];
        dat->parent[j] = n;
        if(j < lz_t)
          dat->parent[j+1] = n;
      }
    }

    o = dat->parent[i];
    do
    {
      j = ++dat->freq[o];
      l = o+1;
      if(j > dat->freq[l])
      {
        while(j > dat->freq[l+1])
          ++l;

        dat->freq[o] = dat->freq[l];
        dat->freq[l] = j;

        j = dat->son[o];
        dat->parent[j] = l;
        if(j < lz_t)
          dat->parent[j+1] = l;

        m = dat->son[l];

        dat->son[l] = j;
        dat->parent[m] = o;
        if(m < lz_t)
          dat->parent[m+1] = o;

        dat->son[o] = m;

        o = l;
      }
      o = dat->parent[o];
    } while(o);

    i -= lz_t;
    if(i < 0x100)
    {
      dat->datfield[k++] = xadIOPutChar(io, i);
      k &= 0xFFF;
    }
    else if((io->xio_Flags & XADIOF_NOOUTENDERR) && i == 0x100) /* crunch end indicator */
      break;
    else
    {
      l = xadIOGetBitsHigh(io,8);
      m = AMPK3_d_len[l] - (8-bitnum);
      l = k - (AMPK3_d_code[l] << bitnum | (((l << m) | xadIOGetBitsHigh(io, m)) & ((1<<bitnum)-1))) - 1;
      i -= 256-threshold;
      for(j = 0; j < i; ++j)
      {
        dat->datfield[k++] = xadIOPutChar(io, dat->datfield[(l+j)&0xFFF]);
        k &= 0xFFF;
      }
    }
  }

  xadFreeObjectA(XADM dat, 0);

  return io->xio_Error;
}






@implementation XADCrunchZHandle

-(id)initWithHandle:(CSHandle *)handle old:(BOOL)old hasChecksum:(BOOL)checksum
{
	if((self=[super initWithHandle:handle]))
	{
		oldversion=old;
		haschecksum=checksum;
		checksumcorrect=NO;
	}
	return self;
}


-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|
	XADIOF_ALLOCOUTBUFFER|XADIOF_NOOUTENDERR|XADIOF_NOCRC32|XADIOF_NOCRC16];

	io->xio_PutFunc=xadIOPutFuncRLE90;
	io->xio_PutFuncPrivate=xadIOPutFuncRLE90TYPE2;
	io->xio_OutFunc=xadIOChecksum;

	xadINT32 err=CRUNCHuncrunch(io,oldversion);
	if(!err) err=xadIOWriteBuf(io);

	if(haschecksum)
	{
		int correct=xadIOGetChar(io)+(xadIOGetChar(io)<<8);
		int checksum=((uintptr_t)io->xio_OutFuncPrivate)&0xffff;
		checksumcorrect=checksum==correct;
	}

	return err;
}

-(BOOL)hasChecksum { return haschecksum; }

-(BOOL)isChecksumCorrect { return checksumcorrect; }

@end




@implementation XADCrunchYHandle

-(id)initWithHandle:(CSHandle *)handle old:(BOOL)old hasChecksum:(BOOL)checksum
{
	if((self=[super initWithHandle:handle]))
	{
		oldversion=old;
		haschecksum=checksum;
	}
	return self;
}

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|
	XADIOF_ALLOCOUTBUFFER|XADIOF_NOOUTENDERR|XADIOF_NOCRC32|XADIOF_NOCRC16];

	io->xio_OutFunc=xadIOChecksum;

	xadINT32 err=DecrAMPK3(io,oldversion?1:2);
	if(!err) err=xadIOWriteBuf(io);

	if(haschecksum)
	{
		int correct=xadIOGetChar(io)+(xadIOGetChar(io)<<8);
		int checksum=((uintptr_t)io->xio_OutFuncPrivate)&0xffff;
		checksumcorrect=checksum==correct;
	}

	return err;
}

-(BOOL)hasChecksum { return haschecksum; }

-(BOOL)isChecksumCorrect { return checksumcorrect; }

@end
