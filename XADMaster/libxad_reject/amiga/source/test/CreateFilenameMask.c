#include <stdio.h>

/*  $Id: CreateFilenameMask.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test program to test protection bit handling

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

unsigned char mask[256/8];

void fillmask(unsigned char *mask, char *bytes)
{
  int i;

  for(i = 0; i < 256/8; ++i)
    mask[i] = 0;
  while(*bytes)
  {
    mask[(*bytes)>>3] |= (1<<((*bytes)&7));
    ++bytes;
  }
}

void main(void)
{
  int i;

  fillmask(mask,
  "\x01\x02\x03\x04\x05\x06\x07\x08"
  "\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10"
  "\x11\x12\x13\x14\x15\x16\x17\x18"
  "\x19\x1A\x1B\x1C\x1D\x1E\x1F"
  "#?()[]~%*:|\x7F\""
  "\x80\x81\x82\x83\x84\x85\x86\x87"
  "\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F"
  "\x90\x91\x92\x93\x94\x95\x96\x97"
  "\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F"
  "\xA0");
  
  printf("UBYTE statmask[256/8] = {");
  for(i = 0; i < 256/8; ++i)
  {
    if(!(i&7))
      printf("\n");
    printf("0x%02lX%s", mask[i], i < 256/8-1 ? "," : "\n};\n");
  }
}
