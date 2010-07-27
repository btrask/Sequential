#ifndef XADMASTER_CRC_C
#define XADMASTER_CRC_C

/*  $Id: crc.c,v 1.5 2005/06/23 14:54:37 stoecker Exp $
    Information handling functions

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

#include "include/functions.h"

/* NOTE: using (size--) as test in while condition produces a SAS-C bug */

FUNCxadCalcCRC16 /* xadUINT16 id, xadUINT16 init, xadSize size,
const xadUINT8 *buffer */
{
  xadUINT16 crc;
  xadSize s = 0;

  crc = init;
  if(id == XADCRC16_ID1)
  {
    const xadUINT16 *tab;
    tab = xadMasterBase->xmb_CRCTable1;
    while(s++ < size)
      crc = tab[(crc ^ *buffer++) & 0xFF] ^ (crc >> 8);
  }
  else
  {
    xadUINT16 tab[256];
    MakeCRC16(tab, id);
    while(s++ < size)
      crc = tab[(crc ^ *buffer++) & 0xFF] ^ (crc >> 8);
  }
  return crc;
}
ENDFUNC

FUNCxadCalcCRC32 /* xadUINT32 id, xadUINT32 init, xadSize size,
const xadUINT8 *buffer */
{
  xadUINT32 crc;
  xadSize s = 0;

  crc = init;
  if(id == XADCRC32_ID1)
  {
    const xadUINT32 *tab;
    tab = xadMasterBase->xmb_CRCTable2;
    while(s++ < size)
      crc = tab[(crc ^ *buffer++) & 0xFF] ^ (crc >> 8);
  }
  else
  {
    xadUINT32 tab[256];
    MakeCRC32(tab, id);
    while(s++ < size)
      crc = tab[(crc ^ *buffer++) & 0xFF] ^ (crc >> 8);
  }
  return crc;
}
ENDFUNC

void MakeCRC16(xadUINT16 *buf, xadUINT16 ID)
{
  xadUINT16 i, j, k;

  for(i = 0; i < 256; ++i)
  {
    k = i;

    for(j = 0; j < 8; ++j)
    {
      if(k & 1)
        k = (k >> 1) ^ ID;
      else
        k >>= 1;
    }
    buf[i] = k;
  }
}

void MakeCRC32(xadUINT32 *buf, xadUINT32 ID)
{
  xadUINT32 i, j, k;

  for(i = 0; i < 256; ++i)
  {
    k = i;

    for(j = 0; j < 8; ++j)
    {
      if(k & 1)
        k = (k >> 1) ^ ID;
      else
        k >>= 1;
    }
    buf[i] = k;
  }
}

#endif  /* XADMASTER_CRC_C */
