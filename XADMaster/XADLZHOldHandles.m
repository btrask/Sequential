#import "XADLZHOldHandles.h"




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


#undef UCHAR_MAX
#undef CHAR_BIT

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

#define PMARC2_OFFSET (0x100 - 2)
struct PMARC2_Tree {
  xadUINT8 *leftarr;
  xadUINT8 *rightarr;
  xadUINT8 root;
};

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

struct LhADecrPM {
  struct PMARC2_Tree tree1;
  struct PMARC2_Tree tree2;

  xadUINT16         lastupdate;
  xadUINT16         dicsiz1;
  xadUINT8         gettree1;
  xadUINT8         tree1left[32];
  xadUINT8         tree1right[32];
  xadUINT8         table1[32];

  xadUINT8         tree2left[8];
  xadUINT8         tree2right[8];
  xadUINT8         table2[8];

  xadUINT8         tree1bound;
  xadUINT8         mindepth;

  /* Circular double-linked list. */
  xadUINT8         prev[0x100];
  xadUINT8         next[0x100];
  xadUINT8         parentarr[0x100];
  xadUINT8         lastbyte;
};

struct LhADecrLZ {
  xadINT32              matchpos;               /* LARC */
  xadINT32              flag;                   /* LARC */
  xadINT32              flagcnt;                /* LARC */
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
    struct LhADecrPM pm;
    struct LhADecrLZ lz;
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

static void LHAstart_p_dyn(struct LhADecrData *dat)
{
  dat->d.st.freq[ROOT_P] = 1;
  dat->d.st.child[ROOT_P] = ~(N_CHAR);
  dat->d.st.s_node[N_CHAR] = ROOT_P;
  dat->d.st.edge[dat->d.st.block[ROOT_P] = dat->d.st.stock[dat->d.st.avail++]] = ROOT_P;
  dat->d.st.most_p = ROOT_P;
  dat->d.st.total_p = 0;
  dat->d.st.nn = 1 << dat->DicBit;
  dat->nextcount = 64;
}

static void LHAstart_c_dyn(struct LhADecrData *dat)
{
  xadINT32 i, j, f;

  dat->d.st.n1 = (dat->d.st.n_max >= 256 + dat->d.st.maxmatch - THRESHOLD + 1) ? 512 : dat->d.st.n_max - 1;
  for(i = 0; i < TREESIZE_C; i++)
  {
    dat->d.st.stock[i] = i;
    dat->d.st.block[i] = 0;
  }
  for(i = 0, j = dat->d.st.n_max * 2 - 2; i < (xadINT32) dat->d.st.n_max; i++, j--)
  {
    dat->d.st.freq[j] = 1;
    dat->d.st.child[j] = ~i;
    dat->d.st.s_node[i] = j;
    dat->d.st.block[j] = 1;
  }
  dat->d.st.avail = 2;
  dat->d.st.edge[1] = dat->d.st.n_max - 1;
  i = dat->d.st.n_max * 2 - 2;
  while(j >= 0)
  {
    f = dat->d.st.freq[j] = dat->d.st.freq[i] + dat->d.st.freq[i - 1];
    dat->d.st.child[j] = i;
    dat->d.st.parent[i] = dat->d.st.parent[i - 1] = j;
    if(f == dat->d.st.freq[j + 1])
    {
      dat->d.st.edge[dat->d.st.block[j] = dat->d.st.block[j + 1]] = j;
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[j] = dat->d.st.stock[dat->d.st.avail++]] = j;
    }
    i -= 2;
    j--;
  }
}

static void LHAdecode_start_dyn(struct LhADecrData *dat)
{
  dat->d.st.n_max = 286;
  dat->d.st.maxmatch = MAXMATCH;
  LHAinit_getbits(dat);
  LHAstart_c_dyn(dat);
  LHAstart_p_dyn(dat);
}

static void LHAreconst(struct LhADecrData *dat, xadINT32 start, xadINT32 end)
{
  xadINT32  i, j, k, l, b = 0;
  xadUINT32 f, g;

  for(i = j = start; i < end; i++)
  {
    if((k = dat->d.st.child[i]) < 0)
    {
      dat->d.st.freq[j] = (dat->d.st.freq[i] + 1) / 2;
      dat->d.st.child[j] = k;
      j++;
    }
    if(dat->d.st.edge[b = dat->d.st.block[i]] == i)
    {
      dat->d.st.stock[--dat->d.st.avail] = b;
    }
  }
  j--;
  i = end - 1;
  l = end - 2;
  while(i >= start)
  {
    while(i >= l)
    {
      dat->d.st.freq[i] = dat->d.st.freq[j];
      dat->d.st.child[i] = dat->d.st.child[j];
      i--, j--;
    }
    f = dat->d.st.freq[l] + dat->d.st.freq[l + 1];
    for(k = start; f < dat->d.st.freq[k]; k++)
      ;
    while(j >= k)
    {
      dat->d.st.freq[i] = dat->d.st.freq[j];
      dat->d.st.child[i] = dat->d.st.child[j];
      i--, j--;
    }
    dat->d.st.freq[i] = f;
    dat->d.st.child[i] = l + 1;
    i--;
    l -= 2;
  }
  f = 0;
  for(i = start; i < end; i++)
  {
    if((j = dat->d.st.child[i]) < 0)
      dat->d.st.s_node[~j] = i;
    else
      dat->d.st.parent[j] = dat->d.st.parent[j - 1] = i;
    if((g = dat->d.st.freq[i]) == f) {
      dat->d.st.block[i] = b;
    }
    else
    {
      dat->d.st.edge[b = dat->d.st.block[i] = dat->d.st.stock[dat->d.st.avail++]] = i;
      f = g;
    }
  }
}

static xadINT32 LHAswap_inc(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 b, q, r, s;

  b = dat->d.st.block[p];
  if((q = dat->d.st.edge[b]) != p)
  { /* swap for leader */
    r = dat->d.st.child[p];
    s = dat->d.st.child[q];
    dat->d.st.child[p] = s;
    dat->d.st.child[q] = r;
    if(r >= 0)
      dat->d.st.parent[r] = dat->d.st.parent[r - 1] = q;
    else
      dat->d.st.s_node[~r] = q;
    if(s >= 0)
      dat->d.st.parent[s] = dat->d.st.parent[s - 1] = p;
    else
      dat->d.st.s_node[~s] = p;
    p = q;
    dat->d.st.edge[b]++;
    if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
    {
      dat->d.st.block[p] = dat->d.st.block[p - 1];
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[p] = dat->d.st.stock[dat->d.st.avail++]] = p;  /* create block */
    }
  }
  else if(b == dat->d.st.block[p + 1])
  {
    dat->d.st.edge[b]++;
    if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
    {
      dat->d.st.block[p] = dat->d.st.block[p - 1];
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[p] = dat->d.st.stock[dat->d.st.avail++]] = p;  /* create block */
    }
  }
  else if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
  {
    dat->d.st.stock[--dat->d.st.avail] = b; /* delete block */
    dat->d.st.block[p] = dat->d.st.block[p - 1];
  }
  return dat->d.st.parent[p];
}

static void LHAupdate_p(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q;

  if(dat->d.st.total_p == 0x8000)
  {
    LHAreconst(dat, ROOT_P, dat->d.st.most_p + 1);
    dat->d.st.total_p = dat->d.st.freq[ROOT_P];
    dat->d.st.freq[ROOT_P] = 0xffff;
  }
  q = dat->d.st.s_node[p + N_CHAR];
  while(q != ROOT_P)
  {
    q = LHAswap_inc(dat, q);
  }
  dat->d.st.total_p++;
}

static void LHAmake_new_node(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q, r;

  r = dat->d.st.most_p + 1;
  q = r + 1;
  dat->d.st.s_node[~(dat->d.st.child[r] = dat->d.st.child[dat->d.st.most_p])] = r;
  dat->d.st.child[q] = ~(p + N_CHAR);
  dat->d.st.child[dat->d.st.most_p] = q;
  dat->d.st.freq[r] = dat->d.st.freq[dat->d.st.most_p];
  dat->d.st.freq[q] = 0;
  dat->d.st.block[r] = dat->d.st.block[dat->d.st.most_p];
  if(dat->d.st.most_p == ROOT_P)
  {
    dat->d.st.freq[ROOT_P] = 0xffff;
    dat->d.st.edge[dat->d.st.block[ROOT_P]]++;
  }
  dat->d.st.parent[r] = dat->d.st.parent[q] = dat->d.st.most_p;
  dat->d.st.edge[dat->d.st.block[q] = dat->d.st.stock[dat->d.st.avail++]] =
  dat->d.st.s_node[p + N_CHAR] = dat->d.st.most_p = q;
  LHAupdate_p(dat, p);
}

static void LHAupdate_c(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q;

  if(dat->d.st.freq[ROOT_C] == 0x8000)
  {
    LHAreconst(dat, 0, (xadINT32) dat->d.st.n_max * 2 - 1);
  }
  dat->d.st.freq[ROOT_C]++;
  q = dat->d.st.s_node[p];
  do
  {
    q = LHAswap_inc(dat, q);
  } while(q != ROOT_C);
}

static xadUINT16 LHAdecode_c_dyn(struct LhADecrData *dat)
{
  xadINT32 c;
  xadINT16 buf, cnt;

  c = dat->d.st.child[ROOT_C];
  buf = dat->bitbuf;
  cnt = 0;
  do
  {
    c = dat->d.st.child[c - (buf < 0)];
    buf <<= 1;
    if(++cnt == 16)
    {
      LHAfillbuf(dat, 16);
      buf = dat->bitbuf;
      cnt = 0;
    }
  } while(c > 0);
  LHAfillbuf(dat, cnt);
  c = ~c;
  LHAupdate_c(dat, c);
  if(c == dat->d.st.n1)
    c += LHAgetbits(dat, 8);
  return (xadUINT16) c;
}

static xadUINT16 LHAdecode_p_dyn(struct LhADecrData *dat)
{
  xadINT32 c;
  xadINT16 buf, cnt;

  while(dat->count > dat->nextcount)
  {
    LHAmake_new_node(dat, (xadINT32) dat->nextcount / 64);
    if((dat->nextcount += 64) >= (xadUINT32)dat->d.st.nn)
      dat->nextcount = 0xffffffff;
  }
  c = dat->d.st.child[ROOT_P];
  buf = dat->bitbuf;
  cnt = 0;
  while(c > 0)
  {
    c = dat->d.st.child[c - (buf < 0)];
    buf <<= 1;
    if(++cnt == 16)
    {
      LHAfillbuf(dat, 16);
      buf = dat->bitbuf;
      cnt = 0;
    }
  }
  LHAfillbuf(dat, cnt);
  c = (~c) - N_CHAR;
  LHAupdate_p(dat, c);

  return (xadUINT16) ((c << 6) + LHAgetbits(dat, 6));
}


/* ------------------------------------------------------------------------ */

static const xadINT32 LHAfixed[2][16] = {
  {3, 0x01, 0x04, 0x0c, 0x18, 0x30, 0}, /* old compatible */
  {2, 0x01, 0x01, 0x03, 0x06, 0x0D, 0x1F, 0x4E, 0}  /* 8K buf */
};

static void LHAready_made(struct LhADecrData *dat, xadINT32 method)
{
  xadINT32  i, j;
  xadUINT32 code, weight;
  xadINT32 *tbl;

  tbl = (xadINT32 *) LHAfixed[method];
  j = *tbl++;
  weight = 1 << (16 - j);
  code = 0;
  for(i = 0; i < dat->d.st.np; i++)
  {
    while(*tbl == i)
    {
      j++;
      tbl++;
      weight >>= 1;
    }
    dat->d.st.pt_len[i] = j;
    dat->d.st.pt_code[i] = code;
    code += weight;
  }
}

static xadUINT16 LHAdecode_p_st0(struct LhADecrData *dat)
{
  xadINT32 i, j;

  j = dat->d.st.pt_table[dat->bitbuf >> 8];
  if(j < dat->d.st.np)
  {
    LHAfillbuf(dat, dat->d.st.pt_len[j]);
  }
  else
  {
    LHAfillbuf(dat, 8);
    i = dat->bitbuf;
    do
    {
      if((xadINT16) i < 0)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      i <<= 1;
    } while(j >= dat->d.st.np);
    LHAfillbuf(dat, dat->d.st.pt_len[j] - 8);
  }
  return (xadUINT16)((j << 6) + LHAgetbits(dat, 6));
}

static void LHAdecode_start_st0(struct LhADecrData *dat)
{
  dat->d.st.n_max = 286;
  dat->d.st.maxmatch = MAXMATCH;
  LHAinit_getbits(dat);
  dat->d.st.np = 1 << (MAX_DICBIT - 6);
}

static void LHAread_tree_c(struct LhADecrData *dat) /* read tree from file */
{
  xadINT32 i, c;

  i = 0;
  while(i < N1)
  {
    if(LHAgetbits(dat, 1))
      dat->d.st.c_len[i] = LHAgetbits(dat, LENFIELD) + 1;
    else
      dat->d.st.c_len[i] = 0;
    if(++i == 3 && dat->d.st.c_len[0] == 1 && dat->d.st.c_len[1] == 1 && dat->d.st.c_len[2] == 1)
    {
      c = LHAgetbits(dat, CBIT);
      memset(dat->d.st.c_len, 0, N1);
      for(i = 0; i < 4096; i++)
        dat->d.st.c_table[i] = c;
      return;
    }
  }
  LHAmake_table(dat, N1, dat->d.st.c_len, 12, dat->d.st.c_table);
}

static void LHAread_tree_p(struct LhADecrData *dat) /* read tree from file */
{
  xadINT32 i, c;

  i = 0;
  while(i < NP)
  {
    dat->d.st.pt_len[i] = LHAgetbits(dat, LENFIELD);
    if(++i == 3 && dat->d.st.pt_len[0] == 1 && dat->d.st.pt_len[1] == 1 && dat->d.st.pt_len[2] == 1)
    {
      c = LHAgetbits(dat, MAX_DICBIT - 6);
      for(i = 0; i < NP; i++)
        dat->d.st.c_len[i] = 0;
      for(i = 0; i < 256; i++)
        dat->d.st.c_table[i] = c;
      return;
    }
  }
}

static xadUINT16 LHAdecode_c_st0(struct LhADecrData *dat)
{
  xadINT32 i, j;

  if(!dat->d.st.blocksize) /* read block head */
  {
    dat->d.st.blocksize = LHAgetbits(dat, BUFBITS); /* read block blocksize */
    LHAread_tree_c(dat);
    if(LHAgetbits(dat, 1))
    {
      LHAread_tree_p(dat);
    }
    else
    {
      LHAready_made(dat, 1);
    }
    LHAmake_table(dat, NP, dat->d.st.pt_len, 8, dat->d.st.pt_table);
  }
  dat->d.st.blocksize--;
  j = dat->d.st.c_table[dat->bitbuf >> 4];
  if(j < N1)
    LHAfillbuf(dat, dat->d.st.c_len[j]);
  else
  {
    LHAfillbuf(dat, 12);
    i = dat->bitbuf;
    do
    {
      if((xadINT16) i < 0)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      i <<= 1;
    } while(j >= N1);
    LHAfillbuf(dat, dat->d.st.c_len[j] - 12);
  }
  if (j == N1 - 1)
    j += LHAgetbits(dat, EXTRABITS);
  return (xadUINT16) j;
}

/* ------------------------------------------------------------------------ */

static const xadINT32 PMARC2_historyBits[8] = { 3,  3,  4,  5,  5,  5,  6,  6};
static const xadINT32 PMARC2_historyBase[8] = { 0,  8, 16, 32, 64, 96,128,192};
static const xadINT32 PMARC2_repeatBits[6]  = { 3,  3,  5,  6,  7,  0};
static const xadINT32 PMARC2_repeatBase[6]  = {17, 25, 33, 65,129,256};

static void PMARC2_hist_update(struct LhADecrData *dat, xadUINT8 data)
{
  if(data != dat->d.pm.lastbyte)
  {
    xadUINT8 oldNext, oldPrev, newNext;

    /* detach from old position */
    oldNext = dat->d.pm.next[data];
    oldPrev = dat->d.pm.prev[data];
    dat->d.pm.prev[oldNext] = oldPrev;
    dat->d.pm.next[oldPrev] = oldNext;

    /* attach to new next */
    newNext = dat->d.pm.next[dat->d.pm.lastbyte];
    dat->d.pm.prev[newNext] = data;
    dat->d.pm.next[data] = newNext;

    /* attach to new prev */
    dat->d.pm.prev[data] = dat->d.pm.lastbyte;
    dat->d.pm.next[dat->d.pm.lastbyte] = data;

    dat->d.pm.lastbyte = data;
  }
}

static xadINT32 PMARC2_tree_get(struct LhADecrData *dat, struct PMARC2_Tree *t)
{
  xadINT32 i;
  i = t->root;

  while (i < 0x80)
  {
    i = (LHAgetbits(dat, 1) == 0 ? t->leftarr[i] : t->rightarr[i] );
  }
  return i & 0x7F;
}

static void PMARC2_tree_rebuild(struct LhADecrData *dat, struct PMARC2_Tree *t,
xadUINT8 bound, xadUINT8 mindepth, xadUINT8 * table)
{
  xadUINT8 d;
  xadINT32 i, curr, empty, n;

  t->root = 0;
  memset(t->leftarr, 0, bound);
  memset(t->rightarr, 0, bound);
  memset(dat->d.pm.parentarr, 0, bound);

  for(i = 0; i < dat->d.pm.mindepth - 1; i++)
  {
    t->leftarr[i] = i + 1;
    dat->d.pm.parentarr[i+1] = i;
  }

  curr = dat->d.pm.mindepth - 1;
  empty = dat->d.pm.mindepth;
  for(d = dat->d.pm.mindepth; ; d++)
  {
    for(i = 0; i < bound; i++)
    {
      if(table[i] == d)
      {
        if(t->leftarr[curr] == 0)
          t->leftarr[curr] = i | 128;
        else
        {
          t->rightarr[curr] = i | 128;
          n = 0;
          while(t->rightarr[curr] != 0)
          {
            if(curr == 0) /* root? -> done */
              return;
            curr = dat->d.pm.parentarr[curr];
            n++;
          }
          t->rightarr[curr] = empty;
          for(;;)
          {
            dat->d.pm.parentarr[empty] = curr;
            curr = empty;
            empty++;

            n--;
            if(n == 0)
              break;
            t->leftarr[curr] = empty;
          }
        }
      }
    }
    if(t->leftarr[curr] == 0)
      t->leftarr[curr] = empty;
    else
      t->rightarr[curr] = empty;

    dat->d.pm.parentarr[empty] = curr;
    curr = empty;
    empty++;
  }
}

static xadUINT8 PMARC2_hist_lookup(struct LhADecrData *dat, xadINT32 n)
{
  xadUINT8 i;
  xadUINT8 *direction = dat->d.pm.prev;

  if(n >= 0x80)
  {
    /* Speedup: If you have to process more than half the ring,
                it's faster to walk the other way around. */
    direction = dat->d.pm.next;
    n = 0x100 - n;
  }
  for(i = dat->d.pm.lastbyte; n != 0; n--)
    i = direction[i];
  return i;
}

static void PMARC2_maketree1(struct LhADecrData *dat)
{
  xadINT32 i, nbits, x;

  dat->d.pm.tree1bound = LHAgetbits(dat, 5);
  dat->d.pm.mindepth = LHAgetbits(dat, 3);

  if(dat->d.pm.mindepth == 0)
    dat->d.pm.tree1.root = 128 | (dat->d.pm.tree1bound - 1);
  else
  {
    memset(dat->d.pm.table1, 0, 32);
    nbits = LHAgetbits(dat, 3);
    for(i = 0; i < dat->d.pm.tree1bound; i++)
    {
      if((x = LHAgetbits(dat, nbits)))
        dat->d.pm.table1[i] = x - 1 + dat->d.pm.mindepth;
    }
    PMARC2_tree_rebuild(dat, &dat->d.pm.tree1, dat->d.pm.tree1bound,
    dat->d.pm.mindepth, dat->d.pm.table1);
  }
}

static void PMARC2_maketree2(struct LhADecrData *dat, xadINT32 par_b)
/* in use: 5 <= par_b <= 8 */
{
  xadINT32 i, count, index;

  if(dat->d.pm.tree1bound < 10)
    return;
  if(dat->d.pm.tree1bound == 29 && dat->d.pm.mindepth == 0)
    return;

  for(i = 0; i < 8; i++)
    dat->d.pm.table2[i] = 0;
  for(i = 0; i < par_b; i++)
    dat->d.pm.table2[i] = LHAgetbits(dat, 3);
  index = 0;
  count = 0;
  for(i = 0; i < 8; i++)
  {
    if(dat->d.pm.table2[i] != 0)
    {
      index = i;
      count++;
    }
  }

  if(count == 1)
  {
    dat->d.pm.tree2.root = 128 | index;
  }
  else if (count > 1)
  {
    dat->d.pm.mindepth = 1;
    PMARC2_tree_rebuild(dat, &dat->d.pm.tree2, 8, dat->d.pm.mindepth, dat->d.pm.table2);
  }
  /* Note: count == 0 is possible! */
}

static void LHAdecode_start_pm2(struct LhADecrData *dat)
{
  xadINT32 i;

  dat->d.pm.tree1.leftarr = dat->d.pm.tree1left;
  dat->d.pm.tree1.rightarr = dat->d.pm.tree1right;
/*  dat->d.pm.tree1.root = 0; */
  dat->d.pm.tree2.leftarr = dat->d.pm.tree2left;
  dat->d.pm.tree2.rightarr = dat->d.pm.tree2right;
/*  dat->d.pm.tree2.root = 0; */

  dat->d.pm.dicsiz1 = (1 << dat->DicBit) - 1;
  LHAinit_getbits(dat);

  /* history init */
  for(i = 0; i < 0x100; i++)
  {
    dat->d.pm.prev[(0xFF + i) & 0xFF] = i;
    dat->d.pm.next[(0x01 + i) & 0xFF] = i;
  }
  dat->d.pm.prev[0x7F] = 0x00; dat->d.pm.next[0x00] = 0x7F;
  dat->d.pm.prev[0xDF] = 0x80; dat->d.pm.next[0x80] = 0xDF;
  dat->d.pm.prev[0x9F] = 0xE0; dat->d.pm.next[0xE0] = 0x9F;
  dat->d.pm.prev[0x1F] = 0xA0; dat->d.pm.next[0xA0] = 0x1F;
  dat->d.pm.prev[0xFF] = 0x20; dat->d.pm.next[0x20] = 0xFF;
  dat->d.pm.lastbyte = 0x20;

/*  dat->nextcount = 0; */
/*  dat->d.pm.lastupdate = 0; */
  LHAgetbits(dat, 1); /* discard bit */
}

static xadUINT16 LHAdecode_c_pm2(struct LhADecrData *dat)
{
  /* various admin: */
  while(dat->d.pm.lastupdate != dat->loc)
  {
    PMARC2_hist_update(dat, dat->text[dat->d.pm.lastupdate]);
    dat->d.pm.lastupdate = (dat->d.pm.lastupdate + 1) & dat->d.pm.dicsiz1;
  }
  while(dat->count >= dat->nextcount)
  /* Actually it will never loop, because count doesn't grow that fast.
     However, this is the way LHA does it.
     Probably other encoding methods can have repeats larger than 256 bytes.
     Note: LHA puts this code in LHAdecode_p...
  */
  {
    if(dat->nextcount == 0x0000)
    {
      PMARC2_maketree1(dat);
      PMARC2_maketree2(dat, 5);
      dat->nextcount = 0x0400;
    }
    else if(dat->nextcount == 0x0400)
    {
      PMARC2_maketree2(dat, 6);
      dat->nextcount = 0x0800;
    }
    else if(dat->nextcount == 0x0800)
    {
      PMARC2_maketree2(dat, 7);
      dat->nextcount = 0x1000;
    }
    else if(dat->nextcount == 0x1000)
    {
      if(LHAgetbits(dat, 1) != 0)
        PMARC2_maketree1(dat);
      PMARC2_maketree2(dat, 8);
      dat->nextcount = 0x2000;
    }
    else
    { /* 0x2000, 0x3000, 0x4000, ... */
      if(LHAgetbits(dat, 1) != 0)
      {
        PMARC2_maketree1(dat);
        PMARC2_maketree2(dat, 8);
      }
      dat->nextcount += 0x1000;
    }
  }
  dat->d.pm.gettree1 = PMARC2_tree_get(dat, &dat->d.pm.tree1); /* value preserved for LHAdecode_p */

  /* direct value (ret <= UCHAR_MAX) */
  if(dat->d.pm.gettree1 < 8)
  {
    return (xadUINT16) (PMARC2_hist_lookup(dat, PMARC2_historyBase[dat->d.pm.gettree1]
    + LHAgetbits(dat, PMARC2_historyBits[dat->d.pm.gettree1])));
  }

  /* repeats: (ret > UCHAR_MAX) */
  if(dat->d.pm.gettree1 < 23)
  {
    return (xadUINT16) (PMARC2_OFFSET + 2 + (dat->d.pm.gettree1 - 8));
  }

  return (xadUINT16) (PMARC2_OFFSET + PMARC2_repeatBase[dat->d.pm.gettree1 - 23]
  + LHAgetbits(dat, PMARC2_repeatBits[dat->d.pm.gettree1 - 23]));
}

static xadUINT16 LHAdecode_p_pm2(struct LhADecrData *dat)
{
  /* gettree1 value preserved from LHAdecode_c */
  xadINT32 nbits, delta, gettree2;

  if(dat->d.pm.gettree1 == 8)
  { /* 2-byte repeat with offset 0..63 */
    nbits = 6; delta = 0;
  }
  else if(dat->d.pm.gettree1 < 28)
  { /* n-byte repeat with offset 0..8191 */
    if(!(gettree2 = PMARC2_tree_get(dat, &dat->d.pm.tree2)))
    {
      nbits = 6;
      delta = 0;
    }
    else
    { /* 1..7 */
      nbits = 5 + gettree2;
      delta = 1 << nbits;
    }
  }
  else
  { /* 256 bytes repeat with offset 0 */
    nbits = 0;
    delta = 0;
  }
  return (xadUINT16) (delta + LHAgetbits(dat, nbits));
}

/* ------------------------------------------------------------------------ */




static xadINT32 LhA_Decrunch(struct xadInOut *io, xadUINT32 Method)
{
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

    switch(Method)
    {
    case LZHUFF2_METHOD:
      DecodeStart = LHAdecode_start_dyn;
      DecodeC = LHAdecode_c_dyn;
      DecodeP = LHAdecode_p_dyn;
      break;
    case LZHUFF3_METHOD:
      DecodeStart = LHAdecode_start_st0;
      DecodeP = LHAdecode_p_st0;
      DecodeC = LHAdecode_c_st0;
      break;
    case PMARC2_METHOD:
      DecodeStart = LHAdecode_start_pm2;
      DecodeP = LHAdecode_p_pm2;
      DecodeC = LHAdecode_c_pm2;
      break;
    default:
      err = XADERR_DATAFORMAT; break;
    }
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





@implementation XADLZH2Handle

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOINENDERR];
	xadINT32 err=LhA_Decrunch(io,LZHUFF2_METHOD);
	if(!err) err=xadIOWriteBuf(io);
	return err;
}

@end

@implementation XADLZH3Handle

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOINENDERR];
	xadINT32 err=LhA_Decrunch(io,LZHUFF3_METHOD);
	if(!err) err=xadIOWriteBuf(io);
	return err;
}
@end

@implementation XADPMArc2Handle

-(xadINT32)unpackData
{
	struct xadInOut *io=[self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOINENDERR];
	xadINT32 err=LhA_Decrunch(io,PMARC2_METHOD);
	if(!err) err=xadIOWriteBuf(io);
	return err;
}
@end

