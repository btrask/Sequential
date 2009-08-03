/*  $Id: TestCopyMem.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test program to mem copy functions

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

#include <proto/xadmaster.h>
#include <proto/exec.h>
#include <proto/dos.h>

struct xadMasterBase *xadMasterBase;

void main(void)
{
  if((xadMasterBase = (struct xadMasterBase *)
  OpenLibrary("xadmaster.library", 1)))
  {
    UBYTE buf[40];
    LONG i;

    for(i = 0; i < 40; ++i)
      buf[i] = i;

    Printf("Bufferposition = %08lx (long aligned: %s)\n", buf, (((LONG)buf)&3) ? "NO" : "YES");

    xadCopyMem(buf, buf+10, 30);
    Printf("CopyMemLong forward (0->10, size 30)\n");
    for(i = 0; i < 40; ++i)
    {
      Printf("%02ld ", buf[i]); buf[i] = i;
    }
    Printf("\n");

    xadCopyMem(buf+10, buf, 30);
    Printf("CopyMemLong backward (10->0, size 30)\n");
    for(i = 0; i < 40; ++i)
    {
      Printf("%02ld ", buf[i]); buf[i] = i;
    }
    Printf("\n");

    xadCopyMem(buf, buf+10, 29);
    Printf("CopyMemLong byte (0->10, size 29)\n");
    for(i = 0; i < 40; ++i)
    {
      Printf("%02ld ", buf[i]); buf[i] = i;
    }
    Printf("\n");

    xadCopyMem(buf+10, buf, 29);
    Printf("CopyMemLong backward (10->0, size 29)\n");
    for(i = 0; i < 40; ++i)
    {
      Printf("%02ld ", buf[i]); buf[i] = i;
    }
    Printf("\n");

    CloseLibrary((struct Library *) xadMasterBase);
  }
  else
    Printf("Could not open library\n");
}
