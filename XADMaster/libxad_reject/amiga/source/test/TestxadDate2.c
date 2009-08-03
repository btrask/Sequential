/*  $Id: TestxadDate2.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
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

  xd.xd_Micros = 0;
  xd.xd_Year = c;
  xd.xd_Month = b;
  xd.xd_Day = a;
  xd.xd_WeekDay = 0;
  xd.xd_Hour = 0;
  xd.xd_Minute = 0;
  xd.xd_Second = 0;

  if(xadConvertDates(XAD_DATEXADDATE, &xd, XAD_GETDATEXADDATE, &xd, TAG_DONE))
    Printf("err\n");
  else
    Printf("%ld.%ld.%ld - %ld.%ld.%ld - %ld\n", a, b, c, xd.xd_Day,
  xd.xd_Month, xd.xd_Year, xd.xd_WeekDay);
}

void dotest2(ULONG tag, ULONG a, ULONG tr)
{
  struct xadDate xd;
  ULONG i, f;

  if(xadConvertDates(tag, a, XAD_MAKELOCALDATE, tr, XAD_GETDATEXADDATE, &xd,
  TAG_DONE))
    Printf("err\n");
  else if(xadConvertDates(XAD_GETDATEUNIX, &i, XAD_MAKEGMTDATE, tr,
  XAD_DATEXADDATE, &xd, TAG_DONE))
    Printf("err3\n");
  else if(xadConvertDates(XAD_GETDATEAMIGA, &f, XAD_DATEXADDATE, &xd,
  TAG_DONE))
    Printf("err4\n");
  else
    Printf("%08lx - %08lx - %08lx - %ld.%ld.%ld - %ld - %02ld:%02ld:%02ld\n", a, i, f, 
  xd.xd_Day, xd.xd_Month, xd.xd_Year, xd.xd_WeekDay, xd.xd_Hour,
  xd.xd_Minute, xd.xd_Second);
}

void dotest3(ULONG d, ULONG m, ULONG y, ULONG h, ULONG min, ULONG sec, STRPTR txt)
{
  struct xadDate xd, xd2;
  ULONG i;

  xd.xd_WeekDay = 0;
  xd.xd_Day = d;
  xd.xd_Month = m;
  xd.xd_Year = y;
  xd.xd_Micros = 0;
  xd.xd_Second = sec;
  xd.xd_Minute = min;
  xd.xd_Hour = h;

  if(!txt)
    txt = "";

  Printf("%2ld.%2ld.%4ld %02ld:%02ld:%02ld : ", xd.xd_Day, xd.xd_Month, xd.xd_Year,
  xd.xd_Hour, xd.xd_Minute, xd.xd_Second);

  if(xadConvertDates(XAD_GETDATEAMIGA, &i, XAD_DATEXADDATE, &xd, TAG_DONE))
    Printf("Error XAD->AMIGA    - ");
  else if(xadConvertDates(XAD_DATEAMIGA, i, XAD_GETDATEXADDATE, &xd2, TAG_DONE))
    Printf("Error AMIGA->XAD    - ");
  else
    Printf("%2ld.%2ld.%4ld %02ld:%02ld:%02ld,%ld - ", xd2.xd_Day, xd2.xd_Month, xd2.xd_Year,
    xd2.xd_Hour, xd2.xd_Minute, xd2.xd_Second, xd2.xd_WeekDay);

  if(xadConvertDates(XAD_GETDATEUNIX, &i, XAD_DATEXADDATE, &xd, TAG_DONE))
    Printf("Error XAD->UNIX     - ");
  else if(xadConvertDates(XAD_DATEUNIX, i, XAD_GETDATEXADDATE, &xd2, TAG_DONE))
    Printf("Error UNIX->XAD     - ");
  else
    Printf("%2ld.%2ld.%4ld %02ld:%02ld:%02ld,%ld - ", xd2.xd_Day, xd2.xd_Month, xd2.xd_Year,
    xd2.xd_Hour, xd2.xd_Minute, xd2.xd_Second, xd2.xd_WeekDay);

  if(xadConvertDates(XAD_GETDATEMSDOS, &i, XAD_DATEXADDATE, &xd, TAG_DONE))
    Printf("Error XAD->MSDOS    (%s)\n", txt);
  else if(xadConvertDates(XAD_DATEMSDOS, i, XAD_GETDATEXADDATE, &xd2, TAG_DONE))
    Printf("Error MSDOS->XAD    (%s)\n", txt);
  else
    Printf("%2ld.%2ld.%4ld %02ld:%02ld:%02ld,%ld (%s)\n", xd2.xd_Day, xd2.xd_Month, xd2.xd_Year,
    xd2.xd_Hour, xd2.xd_Minute, xd2.xd_Second, xd2.xd_WeekDay, txt);
}

void main(void)
{
  if((xadMasterBase = (struct xadMasterBase *)
  OpenLibrary("xadmaster.library", 1)))
  {
    struct DateStamp d = {0x1433,0x28D,0x877};

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
    dotest2(XAD_DATEMAC,0x7c25b080,0);
    dotest2(XAD_DATEDATESTAMP,(ULONG) &d,0);
    Printf("Boundary tests, no local time conversion\n"
    "Test date             Amiga date              Unix date               MSDOS date\n");
    dotest3(31,12,1969,23,59,58,0);
    dotest3(31,12,1969,23,59,59,0);
    dotest3( 1, 1,1970, 0, 0, 0,"UNIX start ");
    dotest3(31,12,1977,23,59,58,0);
    dotest3(31,12,1977,23,59,59,0);
    dotest3( 1, 1,1978, 0, 0, 0,"AMIGA start");
    dotest3(31,12,1979,23,59,58,0);
    dotest3(31,12,1979,23,59,59,0);
    dotest3( 1, 1,1980, 0, 0, 0,"MSDOS start");
    dotest3(31,12,1999,23,59,58,0);
    dotest3(31,12,1999,23,59,59,0);
    dotest3( 1, 1,2000, 0, 0, 0,0);
    dotest3( 7, 2,2106, 6,28,14,0);
    dotest3( 7, 2,2106, 6,28,15,"UNIX end   ");
    dotest3( 7, 2,2106, 6,28,16,0);
    dotest3(31,12,2107,23,59,58,"MSDOS end  ");
    dotest3(31,12,2107,23,59,59,0);
    dotest3( 1, 1,2108, 0, 0, 0,0);
    dotest3( 7, 2,2114, 6,28,14,0);
    dotest3( 7, 2,2114, 6,28,15,"AMIGA end  ");
    dotest3( 7, 2,2114, 6,28,16,0);
    dotest3(25, 1,2000,12,00,00,"Tuesday");
    dotest3(29, 2,2000,12,00,00,"Tuesday");

    CloseLibrary((struct Library *) xadMasterBase);
  }
  else
    Printf("Could not open library\n");
}
