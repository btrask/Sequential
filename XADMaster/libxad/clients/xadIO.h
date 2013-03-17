#ifndef XADMASTER_XADIO_H
#define XADMASTER_XADIO_H

/*  $Id: xadIO.h,v 1.4 2005/06/23 14:54:41 stoecker Exp $
    Input/output function header

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk St�cker <soft@dstoecker.de>


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

/* These are used to keep definitions in sync when called in source
   direct mode */
#ifndef XADIODIRECTMODE
#define XADIOFUNCMODE     extern
#define XADIOFUNCMODEBITS extern
#endif

struct xadInOut {
  struct xadArchiveInfo * xio_ArchiveInfo;   /* filled by xadIOAlloc */
  struct xadMasterBase *  xio_xadMasterBase; /* filled by xadIOAlloc */
  xadERROR                xio_Error;         /* cleared */
  xadUINT32               xio_Flags;         /* filled by xadIOAlloc, functions or user */

  /* xio_GetFunc and xio_PutFunc are filled by xadIOAlloc or user */
  xadUINT8 (*xio_GetFunc)(struct xadInOut *);
  xadPTR                  xio_GetFuncPrivate;
  xadUINT8 (*xio_PutFunc)(struct xadInOut *, xadUINT8);
  xadPTR                  xio_PutFuncPrivate;

  void (*xio_InFunc)(struct xadInOut *, xadUINT32);
  xadPTR                  xio_InFuncPrivate;
  xadSize                 xio_InSize;
  xadSize                 xio_InBufferSize;
  xadSize                 xio_InBufferPos;
  xadUINT8 *              xio_InBuffer;
  xadUINT32               xio_BitBuf;        /* for xadIOGetBits functions */
  xadUINT16               xio_BitNum;        /* for xadIOGetBits functions */

  xadUINT16               xio_CRC16;         /* crc16 from output functions */
  xadUINT32               xio_CRC32;         /* crc32 from output functions */

  void (*xio_OutFunc)(struct xadInOut *, xadUINT32);
  xadPTR                  xio_OutFuncPrivate;
  xadSize                 xio_OutSize;
  xadSize                 xio_OutBufferSize;
  xadSize                 xio_OutBufferPos;
  xadUINT8 *              xio_OutBuffer;

  /* These 3 can be reused. Algorithms should be prepared to find this
     initialized! The window, alloc always has to use xadAllocVec. */
  xadSize                 xio_WindowSize;
  xadSize                 xio_WindowPos;
  xadUINT8 *              xio_Window;

  /* If the algorithms need to remember additional data for next run, this
     should be passed as argument structure of type (void **) and allocated
     by the algorithms themself using xadAllocVec(). */
};

/* setting BufferPos to buffer size activates first time read! */

#define XADIOF_ALLOCINBUFFER    (1<<0)  /* allocate input buffer */
#define XADIOF_ALLOCOUTBUFFER   (1<<1)  /* allocate output buffer */
#define XADIOF_NOINENDERR       (1<<2)  /* xadIOGetChar does not produce err at buffer end */
#define XADIOF_NOOUTENDERR      (1<<3)  /* xadIOPutChar does not check out size */
#define XADIOF_LASTINBYTE       (1<<4)  /* last byte was read, set by xadIOGetChar */
#define XADIOF_LASTOUTBYTE      (1<<5)  /* output length was reached, set by xadIOPutChar */
#define XADIOF_ERROR            (1<<6)  /* an error occured */
#define XADIOF_NOCRC16          (1<<7)  /* calculate no CRC16 */
#define XADIOF_NOCRC32          (1<<8)  /* calculate no CRC32 */
#define XADIOF_COMPLETEOUTFUNC  (1<<9)  /* outfunc completely replaces write stuff */

/* allocates the xadInOut structure and the buffers */
XADIOFUNCMODE struct xadInOut *xadIOAlloc(xadUINT32 flags,
struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase);

/* writes the buffer out */
XADIOFUNCMODE xadERROR xadIOWriteBuf(struct xadInOut *io);

#define xadIOGetChar(io)   (*((io)->xio_GetFunc))((io))      /* reads one byte */
#define xadIOPutChar(io,a) (*((io)->xio_PutFunc))((io), (a)) /* stores one byte */

/* This skips any left bits and rounds up the whole to next byte boundary. */
/* Sometimes needed for block-based algorithms, where there blocks are byte aligned. */
#define xadIOByteBoundary(io) ((io)->xio_BitNum = 0)

/* The read bits function only read the bits without flushing from buffer. This is
done by DropBits. Some compressors need this method, as the flush different amount
of data than they read in. Normally the GetBits functions are used.
When including the source file directly, do not forget to set the correct defines
to include the necessary functions. */

#if !defined(XADIODIRECTMODE) || defined(XADIOGETBITSLOW)
/* new bytes inserted from left, get bits from right end, max 32 bits, no checks */
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsLow(struct xadInOut *io, xadUINT8 bits);
#endif
#if !defined(XADIODIRECTMODE) || defined(XADIOGETBITSLOWR)
/* new bytes inserted from left, get bits from right end, max 32 bits, no checks, bits reversed */
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsLowR(struct xadInOut *io, xadUINT8 bits);
#endif

#if !defined(XADIODIRECTMODE) || defined(XADIOREADBITSLOW)
XADIOFUNCMODEBITS xadUINT32 xadIOReadBitsLow(struct xadInOut *io, xadUINT8 bits);
XADIOFUNCMODEBITS void xadIODropBitsLow(struct xadInOut *io, xadUINT8 bits);
#endif

#if !defined(XADIODIRECTMODE) || defined(XADIOGETBITSHIGH)
/* new bytes inserted from right, get bits from left end, max 32 bits, no checks */
XADIOFUNCMODEBITS xadUINT32 xadIOGetBitsHigh(struct xadInOut *io, xadUINT8 bits);
#endif

#if !defined(XADIODIRECTMODE) || defined(XADIOREADBITSHIGH)
XADIOFUNCMODEBITS xadUINT32 xadIOReadBitsHigh(struct xadInOut *io, xadUINT8 bits);
XADIOFUNCMODEBITS void xadIODropBitsHigh(struct xadInOut *io, xadUINT8 bits);
#endif

#endif /* XADMASTER_XADIO_H */
