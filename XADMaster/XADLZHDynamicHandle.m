#import "XADLZHDynamicHandle.h"
#import "XADException.h"

@implementation XADLZHDynamicHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:4096])
	{
		static const int lengths[64]=
		{
			3,4,4,4,5,5,5,5,5,5,5,5,6,6,6,6,
			6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,
			7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
			8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		};

		distancecode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:64
		maximumLength:8 shortestCodeIsZeros:YES];
	}
	return self;
}

-(void)dealloc
{
	[distancecode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	int numleaves=314;
	int numnodes=numleaves*2-1;

	memset(nodestorage,0,sizeof(nodestorage));

	for(int i=0;i<numnodes;i++) nodes[i]=&nodestorage[i];

	for(int i=0;i<numleaves;i++)
	{
		int index=numnodes-1-i;
		nodes[index]->index=index;
		nodes[index]->freq=1;
		nodes[index]->value=i;
	}

	for(int i=numleaves-2;i>=0;i--)
	{
		nodes[i]->index=i;
		nodes[i]->leftchild=nodes[2*i+1];
		nodes[i]->rightchild=nodes[2*i+2];
		nodes[i]->leftchild->parent=nodes[i];
		nodes[i]->rightchild->parent=nodes[i];
		nodes[i]->freq=nodes[i]->leftchild->freq+nodes[i]->rightchild->freq;
	}

	for(int i=0;i<256;i++) memset(&windowbuffer[i*13+18],i,13);
	for(int i=0;i<256;i++) windowbuffer[256*13+18+i]=i;
	for(int i=0;i<256;i++) windowbuffer[256*13+256+18+i]=255-i;
	memset(&windowbuffer[256*13+512+18],0,128);
	memset(&windowbuffer[256*13+512+128+18],' ',128-18);
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	XADLZHDynamicNode *node=&nodestorage[0];
	while(node->leftchild||node->rightchild)
	{
		if(CSInputNextBit(input)) node=node->leftchild;
		else node=node->rightchild;
		if(!node) [XADException raiseIllegalDataException];
	}

	[self updateNode:node];

	int lit=node->value;

	if(lit<0x100) return lit;
	else
	{
		*length=lit-0x100+3;

		int highbits=CSInputNextSymbolUsingCode(input,distancecode);
		int lowbits=CSInputNextBitString(input,6);
		*offset=(highbits<<6)+lowbits+1;

		return XADLZSSMatch;
	}
}

-(void)updateNode:(XADLZHDynamicNode *)node
{
	if(nodestorage[0].freq==0x8000) [self reconstructTree];

	for(;;)
	{
		node->freq++;
		if(!node->parent) break;
		[self rearrangeNode:node];
		node=node->parent;
	}
}

-(void)rearrangeNode:(XADLZHDynamicNode *)node
{
	XADLZHDynamicNode *p=node;

	int p_index=p->index;
	int q_index=p->index;
	while(q_index>0 && nodes[q_index-1]->freq<p->freq) q_index--;

	if(q_index<p_index)
	{
		// Swap the nodes p and q
		XADLZHDynamicNode *q=nodes[q_index];

		XADLZHDynamicNode *new_q_parent=p->parent;
		XADLZHDynamicNode *new_p_parent=q->parent;
		BOOL p_is_rightchild=(p->parent->rightchild==p);
		BOOL q_is_rightchild=(q->parent->rightchild==q);

		if(p_is_rightchild) p->parent->rightchild=q;
		else p->parent->leftchild=q;

		if(q_is_rightchild) q->parent->rightchild=p;
		else q->parent->leftchild=p;

		p->parent=new_p_parent;
		q->parent=new_q_parent;

		nodes[p_index]=q;
		nodes[p_index]->index=p_index;

		nodes[q_index]=p;
		nodes[q_index]->index=q_index;
	}
}

-(void)reconstructTree
{
	int numleaves=314;
	int numnodes=numleaves*2-1;

	XADLZHDynamicNode *leafs[numleaves];
	int n=0;
	for(int i=0;i<numnodes;i++)
	{
		if(!nodes[i]->leftchild&&!nodes[i]->rightchild)
		{
			XADLZHDynamicNode *leaf=nodes[i];
			leaf->freq=(leaf->freq+1)/2;
			leafs[n++]=leaf;
		}
	}

	int leaf_index=numleaves-1;
	int branch_index=numleaves-2;
	int node_index=numnodes-1;
	int pair_index=numnodes-2;

	while(node_index>=0)
	{
		while(node_index>=pair_index)
		{
			nodes[node_index]=leafs[leaf_index];
			nodes[node_index]->index=node_index;
			node_index--;
			leaf_index--;
		}

		XADLZHDynamicNode *branch=&nodestorage[branch_index--];
		branch->leftchild=nodes[pair_index];
		branch->rightchild=nodes[pair_index+1];
		branch->leftchild->parent=branch;
		branch->rightchild->parent=branch;
		branch->freq=branch->leftchild->freq+branch->rightchild->freq;

		while(leaf_index>=0 && leafs[leaf_index]->freq<=branch->freq)
		{
			nodes[node_index]=leafs[leaf_index];
			nodes[node_index]->index=node_index;
			node_index--;
			leaf_index--;
		}

		nodes[node_index]=branch;
		nodes[node_index]->index=node_index;
		node_index--;
		pair_index-=2;
	}
	nodes[0]->parent=NULL;
}

@end

// TODO: This libxad implementation might be faster.

#if 0

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
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

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

#endif
