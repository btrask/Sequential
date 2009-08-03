/*  $Id: TestxadDate.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    test program to test date functions

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

void dotest(ULONG a, ULONG b, ULONG c)
{
  struct xadDate xd;
  struct TagItem ti[] = {XAD_DATEXADDATE, (ULONG) &xd, XAD_GETDATEXADDATE, (ULONG) &xd, TAG_DONE, 0};

  xd.xd_Micros = 0;
  xd.xd_Year = c;
  xd.xd_Month = b;
  xd.xd_Day = a;
  xd.xd_WeekDay = 0;
  xd.xd_Hour = 0;
  xd.xd_Minute = 0;
  xd.xd_Second = 0;

  if((xadConvertDatesA(ti)))
    Printf("err\n");
  else
    Printf("%ld.%ld.%ld - %ld.%ld.%ld - %ld\n", a, b, c, xd.xd_Day,
  xd.xd_Month, xd.xd_Year, xd.xd_WeekDay);
}

void dotest2(ULONG tag, ULONG a, ULONG tr)
{
  struct xadDate xd;
  ULONG i, f;
  struct TagItem ti[] = {tag, a, XAD_MAKELOCALDATE, tr, XAD_GETDATEXADDATE,
  	(ULONG) &xd, TAG_DONE, 0};
  struct TagItem ti2[] = {XAD_GETDATEUNIX, (ULONG) &i, XAD_MAKEGMTDATE, tr,
  	XAD_DATEXADDATE, (ULONG) &xd, TAG_DONE, 0};
  struct TagItem ti3[] = {XAD_GETDATEAMIGA, (ULONG) &f, XAD_DATEXADDATE,
  	(ULONG) &xd, TAG_DONE, 0};

  if((xadConvertDatesA(ti)))
    Printf("err\n");
  else if((xadConvertDatesA(ti2)))
    Printf("err3\n");
  else if((xadConvertDatesA(ti3)))
    Printf("err4\n");
  else
    Printf("%08lx - %08lx - %08lx - %ld.%ld.%ld - %ld - %02ld:%02ld:%02ld\n", a, i, f, 
  xd.xd_Day, xd.xd_Month, xd.xd_Year, xd.xd_WeekDay, xd.xd_Hour,
  xd.xd_Minute, xd.xd_Second);
}

void main(void)
{
  if((xadMasterBase = (struct xadMasterBase *)
  OpenLibrary("xadmaster.library", 1)))
  {
    struct DateStamp d = {0x1E13, 0x50C, 0x10C};

    dotest(1,1,1);
    dotest(1,1,1700);
    dotest(1,1,1970);
    dotest(1,1,1978);
    dotest2(XAD_DATEUNIX,0x00000000,1);
    dotest2(XAD_DATEUNIX,0x01E13380,1);
    dotest2(XAD_DATEUNIX,0x7FFFFFFF,1);
    dotest2(XAD_DATEUNIX,0xFFFFFFFF,1);
    dotest2(XAD_DATEAMIGA,0x00000000,0);
    dotest2(XAD_DATEAMIGA,0x7FFFFFFF,0);
    dotest2(XAD_DATEAMIGA,0xFFFFFFFF,0);
    dotest2(XAD_DATEDATESTAMP,(ULONG) &d,0);

    CloseLibrary((struct Library *) xadMasterBase);
  }
  else
    Printf("err2\n");
}
