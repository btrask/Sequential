/*  $Id: TestFilename.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test program to test filename functions

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

#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/xadmaster.h>

struct xadMasterBase *xadMasterBase;

void PrintString(STRPTR str)
{
  if(!str)
    Printf("---EMPTY---\n");
  else
    Printf("%s\n", str);
}

void main(void)
{
  UBYTE buffer[300];
  STRPTR a, b, c;
  LONG err;
  ULONG size;
  UWORD path[2] = {0xFF,0};

  if((xadMasterBase = (struct xadMasterBase *)OpenLibrary("xadmaster.library", 12)))
  {
    a = xadConvertName(CHARSET_HOST, XAD_CSTRING, "Test\\Test2", XAD_PSTRING, "\x05HalloDu", TAG_DONE);
    PrintString(a);
    b = xadConvertName(CHARSET_HOST, XAD_XADSTRING, a, XAD_PATHSEPERATOR, path, XAD_CSTRING, "Hallo/Du EselÿDu daemlicher", TAG_DONE);
    PrintString(b);
    c = xadConvertName(CHARSET_HOST, XAD_CSTRING, "a", XAD_CSTRING, "b", XAD_ADDPATHSEPERATOR, FALSE,
    XAD_CSTRING, "c", XAD_CSTRING, "d", XAD_ADDPATHSEPERATOR, TRUE, XAD_CSTRING, "e", XAD_CSTRING, "f", TAG_DONE);
    PrintString(c);
    err = xadGetFilename(300, buffer, "../../MeinPath/Path/Path/", "../../Filename", 0);
    Printf("%ld - %s\n", err, buffer);
    err = xadGetFilename(300, buffer, "MeinPath", "Filename", XAD_REQUIREDBUFFERSIZE, &size, TAG_DONE);
    Printf("%ld - %ld - %s\n", err, size, buffer);
    xadFreeObjectA(a, 0);
    xadFreeObjectA(b, 0);
    xadFreeObjectA(c, 0);
    /* test the functions */
    CloseLibrary((struct Library *)xadMasterBase);
  }
}
