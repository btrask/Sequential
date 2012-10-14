#ifndef XADMASTER_IO_C
#define XADMASTER_IO_C

/*  $Id: xadIO.c,v 1.11 2005/06/23 14:54:41 stoecker Exp $
    input/output functions

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

/* In case you are calling this file directly from source, you may use this
defines to make the functions static, inlined or whatever else. In case it
should be used a sobject file, they must be cleared, as they default to
static. */

/* the main functions */
#ifndef XADIOFUNCMODE
#define XADIOFUNCMODE static
#endif

/* the bit functions */
#ifndef XADIOFUNCMODEBITS
#define XADIOFUNCMODEBITS XADIOFUNCMODE
#endif

#define XADIODIRECTMODE
#include "xadIO.h"

#define XIDBUFSIZE              10240

static xadUINT8 xadIOPutFunc(struct xadInOut *io, xadUINT8 data)
{
  if(!io->xio_Error)
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
      io->xio_OutBuffer[io->xio_OutBufferPos++] = data;
      if(!--io->xio_OutSize)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }
  }
  return data;
}

static xadUINT8 xadIOGetFunc(struct xadInOut *io)
{
  xadUINT8 res = 0;

  if(!io->xio_Error)
  {
    if(!io->xio_InSize)
    {
      if(!(io->xio_Flags & XADIOF_NOINENDERR))
      {
        io->xio_Error = XADERR_DECRUNCH;
        io->xio_Flags |= XADIOF_ERROR;
      }
    }
    else
    {
      if(io->xio_InBufferPos >= io->xio_InBufferSize)
      {
        xadUINT32 i;
        struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

        if((i = io->xio_InBufferSize) > io->xio_InSize)
          i = io->xio_InSize;
        if(!io->xio_ArchiveInfo)
        {
          io->xio_Flags |= XADIOF_ERROR;
          io->xio_Error = XADERR_DECRUNCH;
        }
        else
        {
          xadUINT32 j;
#ifdef DEBUG
  DebugClient(io->xio_ArchiveInfo,
  "xadIOGetFunc NeedData BufferPos %ld InSize %ld Load %ld BufferSize %ld",
  io->xio_InBufferPos, io->xio_InSize, i, io->xio_InBufferSize);
#endif
          j = io->xio_ArchiveInfo->xai_InSize-io->xio_ArchiveInfo->xai_InPos;
          if(i > j)
            i = j;
          if(!i)
          {
            io->xio_Flags |= XADIOF_ERROR;
            io->xio_Error = XADERR_INPUT;
          }
          else if(!(io->xio_Error = xadHookTagAccess(XADM XADAC_READ, i,
          io->xio_InBuffer, io->xio_ArchiveInfo,
          XAD_USESKIPINFO, 1, TAG_DONE)))
          {
            if(io->xio_InFunc)
              (*(io->xio_InFunc))(io, i);
            res = *io->xio_InBuffer;
          }
          else
            io->xio_Flags |= XADIOF_ERROR;
#ifdef DEBUG
  if(io->xio_Error)
  {
    DebugClient(io->xio_ArchiveInfo, "xadIOGetFunc Load Error '%s' (%ld)",
    xadGetErrorText(XADM io->xio_Error), io->xio_Error);
  }
#endif
        }
        io->xio_InBufferPos = 1;
      }
      else
        res = io->xio_InBuffer[io->xio_InBufferPos++];
      --io->xio_InSize;
    }
    if(!io->xio_InSize)
      io->xio_Flags |= XADIOF_LASTINBYTE;
  }

  return res;
}

XADIOFUNCMODE struct xadInOut *xadIOAlloc(xadUINT32 flags,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadUINT32 size = sizeof(struct xadInOut);
  struct xadInOut *io;

#ifdef DEBUG
  DebugClient(ai, "xadIOAlloc Flags %lx", flags);
#endif

  if(flags & XADIOF_ALLOCINBUFFER)
    size += XIDBUFSIZE;
  if(flags & XADIOF_ALLOCOUTBUFFER)
    size += XIDBUFSIZE;
  if((io = (struct xadInOut *) xadAllocVec(XADM size,
  XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    xadSTRPTR b;

    b = (xadSTRPTR) (io+1);
    io->xio_Flags = flags;
    io->xio_PutFunc = xadIOPutFunc;
    io->xio_GetFunc = xadIOGetFunc;
    io->xio_ArchiveInfo = ai;
    io->xio_xadMasterBase = xadMasterBase;
    if(flags & XADIOF_ALLOCINBUFFER)
    {
      io->xio_InBuffer = (xadUINT8 *)b; b += XIDBUFSIZE;
      io->xio_InBufferSize = io->xio_InBufferPos = XIDBUFSIZE;
    }
    if(flags & XADIOF_ALLOCOUTBUFFER)
    {
      io->xio_OutBuffer = (xadUINT8 *)b;
      io->xio_OutBufferSize = XIDBUFSIZE;
    }
  }
  return io;
}

#ifdef XADIOGETBITSLOW
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  x = io->xio_BitBuf & ((1<<bits)-1);
  io->xio_BitBuf >>= bits;
  io->xio_BitNum -= bits;
  return x;
}
#endif

#ifdef XADIOGETBITSLOWR
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsLowR(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  x = 0;
  io->xio_BitNum -= bits;
  while(bits)
  {
    x = (x<<1) | (io->xio_BitBuf & 1);
    io->xio_BitBuf >>= 1;
    --bits;
  }
  return x;
}
#endif

#ifdef XADIOREADBITSLOW
XADIOFUNCMODEBITS xadUINT32 xadIOReadBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  return io->xio_BitBuf & ((1<<bits)-1);
}

XADIOFUNCMODEBITS void xadIODropBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  io->xio_BitBuf >>= bits;
  io->xio_BitNum -= bits;
}
#endif

#ifdef XADIOGETBITSHIGH
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf = (io->xio_BitBuf << 8) | xadIOGetChar(io);
    io->xio_BitNum += 8;
  }
  x = (io->xio_BitBuf >> (io->xio_BitNum-bits)) & ((1<<bits)-1);
  io->xio_BitNum -= bits;
  return x;
}
#endif

#ifdef XADIOREADBITSHIGH
XADIOFUNCMODEBITS xadUINT32 xadIOReadBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf = (io->xio_BitBuf << 8) | xadIOGetChar(io);
    io->xio_BitNum += 8;
  }
  return (io->xio_BitBuf >> (io->xio_BitNum-bits)) & ((1<<bits)-1);
}

XADIOFUNCMODEBITS void xadIODropBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  io->xio_BitNum -= bits;
}
#endif

XADIOFUNCMODE xadERROR xadIOWriteBuf(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

#ifdef DEBUG
  DebugClient(io->xio_ArchiveInfo,
  "xadIOWriteBuf BufferPos %ld OutSize %lu Error '%s' (%ld)",
  io->xio_OutBufferPos, io->xio_OutSize,
  xadGetErrorText(XADM io->xio_Error), io->xio_Error);
#endif
  if(!io->xio_Error && io->xio_OutBufferPos)
  {

    if(io->xio_OutFunc)
      io->xio_OutFunc(io, io->xio_OutBufferPos);
    if(!(io->xio_Flags & XADIOF_COMPLETEOUTFUNC))
    {
      if(!io->xio_ArchiveInfo)
      {
        io->xio_Flags |= XADIOF_ERROR;
        io->xio_Error = XADERR_DECRUNCH;
      }
      else if((io->xio_Error = xadHookTagAccess(XADM XADAC_WRITE,
      io->xio_OutBufferPos, io->xio_OutBuffer, io->xio_ArchiveInfo,
      io->xio_Flags & XADIOF_NOCRC16 ? TAG_IGNORE : XAD_GETCRC16, &io->xio_CRC16,
      io->xio_Flags & XADIOF_NOCRC32 ? TAG_DONE   : XAD_GETCRC32, &io->xio_CRC32,
      TAG_DONE)))
        io->xio_Flags |= XADIOF_ERROR;
    }
    io->xio_OutBufferPos = 0;
  }
#ifdef DEBUG
  if(io->xio_Error)
  {
    DebugClient(io->xio_ArchiveInfo,
    "xadIOWriteBuf BufferPos %ld OutSize %lu leaving with Error '%s' (%ld)",
    io->xio_OutBufferPos, io->xio_OutSize,
    xadGetErrorText(XADM io->xio_Error), io->xio_Error);
  }
#endif
  return io->xio_Error;
}

#endif /* XADMASTER_IO_C */
