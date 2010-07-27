#ifndef XADMASTER_DATES_C
#define XADMASTER_DATES_C

/*  $Id: dates.c,v 1.11 2005/06/23 14:54:37 stoecker Exp $
    date and time conversion stuff

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>

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

#ifdef AMIGA
#undef IExec
#undef IDOS
#include <proto/exec.h>
#include <proto/intuition.h>
#include <proto/locale.h>
#define IExec xadMasterBase->xmb_IExec
#define IDOS xadMasterBase->xmb_IDOS
#else
#include <time.h>
#endif

#include "include/functions.h"
#include "include/ConvertE.c"

struct MyClockData
{
  xadUINT8 sec[2];
  xadUINT8 min[2];
  xadUINT8 hour[2];
  xadUINT8 mday[2];
  xadUINT8 month[2];
  xadUINT8 year[2];
  xadUINT8 wday[2];
};

struct MyDateStamp
{
  xadUINT8 ds_Days[4];
  xadUINT8 ds_Minute[4];
  xadUINT8 ds_Tick[4];
};

static const xadUINT16 msize[13] =
{365, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

static xadUINT32 longyear(xadUINT32 year, xadUINT32 month)
{
  xadUINT32 i;

  i = msize[month];

  if(!month || month == 2)
    i += ((year % 4) || ((!(year % 100)) && (year % 400))) ? 0UL : 1UL;

  return i;
}

#define NUM400DAYS      ((400*365)+100-3)

static void getwday(struct xadDate *xad)
{
  xadUINT32 j = 1, i = 1;   /* 1.1.0001 is a Monday */

  while(j < xad->xd_Year - 400)
    j += 400; /* does not change weekday! */

  while(j < xad->xd_Year)
    i = (i + longyear(j++, 0)) % 7;
  for(j = 1; j < xad->xd_Month; ++j)
    i += longyear(xad->xd_Year, j);
  i = (i + xad->xd_Day-1)%7;

  xad->xd_WeekDay = i ? i : XADDAY_SUNDAY;
}

static void daystoxad(xadUINT32 d, struct xadDate *xad, xadUINT32 year)
{
  xadUINT32 i, j;

  while(d > NUM400DAYS)
  {
    year += 400; d-= NUM400DAYS;
  }

  while(d > (i = longyear(year, 0)) - 1)
  {
    ++year; d -= i;
  }
  ++d;

  for(i = 1; d > (j = longyear(year, i)); ++i)
    d -= j;

  xad->xd_Month = i;
  xad->xd_Day = d;
  xad->xd_Year = year;
}

static void sectoxad(xadUINT32 d, struct xadDate *xad, xadUINT32 y)
{
  xad->xd_Second = d % 60;
  d /= 60;
  xad->xd_Minute = d % 60;
  d /= 60;
  xad->xd_Hour = d % 24;
  d /= 24;
  daystoxad(d, xad, y);
}

static xadUINT32 xadtodays(const struct xadDate *xad, xadUINT32 year)
{
  xadUINT32 i, j, m;

  if(xad->xd_Year < year) /* underflow */
    return 0x00000000;

  i = xad->xd_Day-1;
  for(m = 1; m < xad->xd_Month; ++m)
    i += longyear(xad->xd_Year, m);

  while(year < xad->xd_Year)
  {
    j = longyear(year++, 0);
    if(i+j < i) /* overflow */
      return 0xFFFFFFFF;
    else
      i += j;
  }

  return i;
}

static xadUINT32 xadtosec(const struct xadDate *xad, xadUINT32 year)
{
  xadUINT32 i, j;

  if(xad->xd_Year < year) /* underflow */
    return 0x00000000;
  if((i = xadtodays(xad, year)) > (0xFFFFFFFF/24/60/60)) /* overflow */
    return 0xFFFFFFFF;

  j = (((i*24)+xad->xd_Hour)*60+xad->xd_Minute)*60+xad->xd_Second;

  return j < i ? 0xFFFFFFFF : j;
}

static void addoffset(struct xadDate *xad, xadINT32 ofs)
{
  xadINT32 sec, min, h, d, m, y;

  sec = xad->xd_Second + ofs;
  min = xad->xd_Minute;
  h = xad->xd_Hour;
  d = xad->xd_Day;
  m = xad->xd_Month;
  y = xad->xd_Year;
  if(sec >= 60)
  {
    while(sec >= 60)
    { sec -= 60; ++min; }
    while(min >= 60)
    { min -= 60; ++h; }
    while(h >= 24)
    { h -= 24; ++d; }
    while(d > longyear(y, m))
    {
      d -= longyear(y, m);
      if(++m > 12)
      {
        ++y; m -= 12;
      }
    }
  }
  else if(sec < 0)
  {
    while(sec < 0)
    { sec += 60; --min; }
    while(min < 0)
    { min += 60; --h; }
    while(h < 0)
    { h += 24; --d; }
    while(d <= 0)
    {
      if(--m <= 0)
      {
        --y; m += 12;
      }
      d += longyear(y, m);
    }
  }

  if(y <= 0xFFFF && y > 0)
  {
    xad->xd_Second = sec;
    xad->xd_Minute = min;
    xad->xd_Hour = h;
    xad->xd_Day = d;
    xad->xd_Month = m;
    xad->xd_Year = y;
  }
}

FUNCxadConvertDates /* xadTAGPTR tags */
{
  xadINT32 am = 0, mac = 0, cpm = 0, cpm2 = 0, unx = 0, dats = 0,
  xad = 0, cd = 0, msdos = 0, gmt = 0, iso = 0;
  const struct xadDate *xadp = 0;
  struct xadDate xadi;
  const struct MyClockData *cdp = 0;
  xadUINT8 *cpmdate = 0, *isodate = 0;
  xadUINT32 timeval = 0;
  xadINT32 gmtoffs = 0, gmttst = 0;
  xadTAGPTR ti, ti2;
  const struct MyDateStamp *datsp = 0;

#ifdef AMIGA
  struct ExecBase *SysBase = xadMasterBase->xmb_SysBase;
#endif

#ifdef DEBUG
  DebugTagList("xadConvertDatesA", tags);
#endif

  memset(&xadi, 0, sizeof(struct xadDate));

  ti2 = tags;
  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_DATEMAC: ++mac; timeval = ti->ti_Data; break;
    case XAD_DATEUNIX: ++unx; timeval = ti->ti_Data; break;
    case XAD_DATEAMIGA: ++am; timeval = ti->ti_Data; break;
    case XAD_DATEDATESTAMP: ++dats; datsp = (struct MyDateStamp *)(uintptr_t)
      ti->ti_Data; break;
    case XAD_DATEXADDATE: ++xad; xadp = (struct xadDate *)(uintptr_t) ti->ti_Data;
      break;
    case XAD_DATECLOCKDATA: ++cd; cdp = (struct MyClockData *)(uintptr_t) ti->ti_Data;
      break;
    case XAD_DATECURRENTTIME:
#ifdef AMIGA
      {
        struct IntuitionBase *IntuitionBase;

        ++am;
        if((IntuitionBase = (struct IntuitionBase *)
        OpenLibrary("intuition.library", 37)))
        {
#ifdef __amigaos4__
          struct IntuitionIFace *IIntuition;
          if (IIntuition = (struct IntuitionIFace *)GetInterface((struct Library *)IntuitionBase,"main",1,NULL))
          {
            CurrentTime(&timeval, &xadi.xd_Micros);
            DropInterface((struct Interface *)IIntuition);
          }
#else
          CurrentTime(&timeval, &xadi.xd_Micros);
#endif
          
          CloseLibrary((struct Library *) IntuitionBase);
        }
        else
          return XADERR_RESOURCE;
      }
#endif /* AMIGA */
      break;
    case XAD_DATEMSDOS: ++msdos; timeval = ti->ti_Data; break;
    case XAD_DATECPM2: ++cpm2; timeval = ti->ti_Data; break;
    case XAD_DATECPM: ++cpm; cpmdate = (xadUINT8 *)(uintptr_t) ti->ti_Data; break;
    case XAD_DATEISO9660: ++iso; isodate = (xadUINT8 *)(uintptr_t) ti->ti_Data; break;
    case XAD_MAKELOCALDATE: ++gmt; if(ti->ti_Data) gmttst = 1; break;
    case XAD_MAKEGMTDATE: ++gmt; if(ti->ti_Data) gmttst = 2; break;
    }
  }

  if(am+unx+dats+xad+cd+msdos+mac+cpm+cpm2+iso != 1 || gmt > 1)
    return XADERR_BADPARAMS;

#ifdef AMIGA
  if(gmttst)
  {
    struct LocaleBase *LocaleBase;
    if((LocaleBase = (struct LocaleBase *)
    OpenLibrary("locale.library", 38)))
    {
      struct Locale *l;
      
#ifdef __amigaos4__
      struct LocaleIFace *ILocale;
      if (ILocale = (struct LocaleIFace *)GetInterface((struct Library *)LocaleBase, "main", 1L, NULL))
      {
#endif

      if((l = OpenLocale(0)))
      {
        gmtoffs = l->loc_GMTOffset;
        CloseLocale(l);
      }
      
#ifdef __amigaos4__
      DropInterface((struct Interface *)ILocale);
      }
#endif

      CloseLibrary((struct Library *) LocaleBase);
    }
    if(!gmtoffs)
      gmttst = 0;
  }
#else
#ifndef __MINGW32__
  if(gmttst)
  {
    time_t t = time(NULL);
    struct tm *tm = localtime(&t);
    gmtoffs = tm->tm_gmtoff/60;
  }
#else
  gmttst=0;
#endif
#endif

  if(am)
    sectoxad(timeval, &xadi, 1978);
  else if(mac)
    sectoxad(timeval, &xadi, 1904);
  else if(unx)
    sectoxad(timeval, &xadi, 1970);
  else if(xad)
    xadCopyMem(XADM xadp, &xadi, sizeof(struct xadDate));
  else if(dats)
  {
    xadUINT32 v;
    v = EndGetM32(datsp->ds_Tick);
    xadi.xd_Micros = (v%50)*20000;
    xadi.xd_Second = v/50;
    v = EndGetM32(datsp->ds_Minute);
    xadi.xd_Minute = v%60;
    xadi.xd_Hour = v/60;
    daystoxad(EndGetM32(datsp->ds_Days), &xadi, 1978);
  }
  else if(cd)
  {
    xadi.xd_Second = EndGetM16(cdp->sec);
    xadi.xd_Minute = EndGetM16(cdp->min);
    xadi.xd_Hour = EndGetM16(cdp->hour);
    xadi.xd_Day = EndGetM16(cdp->mday);
    xadi.xd_Month = EndGetM16(cdp->month);
    xadi.xd_Year = EndGetM16(cdp->year);
  }
  else if(msdos)
  {
    xadi.xd_Second = (timeval & 31)*2;
    timeval >>= 5;
    xadi.xd_Minute = timeval & 63;
    timeval >>= 6;
    xadi.xd_Hour = timeval & 31;
    timeval >>= 5;
    xadi.xd_Day = timeval & 31;
    timeval >>= 5;
    xadi.xd_Month = timeval & 15;
    timeval >>= 4;
    xadi.xd_Year = 1980 + timeval;
  }
  else if(cpm2)
  {
    xadi.xd_Second = (timeval & 31)*2;
    timeval >>= 5;
    xadi.xd_Minute = timeval & 63;
    timeval >>= 6;
    xadi.xd_Hour = timeval & 31;
    timeval >>= 5;
    daystoxad(timeval, &xadi, 1978);
    addoffset(&xadi, -24*60*60); /* correct their start date */
  }
  else if(cpm)
  {
    xadi.xd_Second = (cpmdate[4]&0xF) + ((cpmdate[4]>>4)*10);
    xadi.xd_Minute = (cpmdate[3]&0xF) + ((cpmdate[3]>>4)*10);
    xadi.xd_Hour = (cpmdate[2]&0xF) + ((cpmdate[2]>>4)*10);
    daystoxad(cpmdate[0]+(cpmdate[1]<<8), &xadi, 1978);
    addoffset(&xadi, -24*60*60); /* correct their start date */
  }
  else if(iso)
  {
    xadi.xd_Year = 1900+isodate[0];
    xadi.xd_Month = isodate[1];
    xadi.xd_Day = isodate[2];
    xadi.xd_Hour = isodate[3];
    xadi.xd_Minute = isodate[4];
    xadi.xd_Second = isodate[5];
  }

  /* check if the structure is filled with correct data */
  if(xadi.xd_Micros > 999999 || xadi.xd_Second > 59 || xadi.xd_Minute > 59 ||
  xadi.xd_Hour > 23 || xadi.xd_Year < 1 || !xadi.xd_Month ||
  xadi.xd_Month > 12 || !xadi.xd_Day || xadi.xd_Day > longyear(xadi.xd_Year, xadi.xd_Month))
  {
#ifdef DEBUG
  DebugError("xadConvertDates: %ld.%ld.%ld | %ld:%ld:%ld,%08ld",
  xadi.xd_Day, xadi.xd_Month, xadi.xd_Year, xadi.xd_Hour, xadi.xd_Minute,
  xadi.xd_Second,xadi.xd_Micros);
#endif
    return XADERR_BADPARAMS;
  }

  if(gmttst)
    addoffset(&xadi, 60*(gmttst == 1 ? -gmtoffs : gmtoffs));

#ifdef DEBUG
  DebugOther("xadConvertDates: %ld.%ld.%ld | %ld:%ld:%ld,%08ld",
  xadi.xd_Day, xadi.xd_Month, xadi.xd_Year, xadi.xd_Hour, xadi.xd_Minute,
  xadi.xd_Second,xadi.xd_Micros);
#endif

  getwday(&xadi);

  ti2 = tags;
  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_GETDATEUNIX:
      *((xadUINT32 *)(uintptr_t)ti->ti_Data) = xadtosec(&xadi, 1970);
      break;
    case XAD_GETDATEAMIGA:
      *((xadUINT32 *)(uintptr_t)ti->ti_Data) = xadtosec(&xadi, 1978);
      break;
    case XAD_GETDATEMAC:
      *((xadUINT32 *)(uintptr_t)ti->ti_Data) = xadtosec(&xadi, 1904);
      break;
#ifdef AMIGA
    case XAD_GETDATEDATESTAMP:
      {
        struct DateStamp *d;
        d = (struct DateStamp *) ti->ti_Data;
        d->ds_Tick = xadi.xd_Second*50+xadi.xd_Micros/20000;
        d->ds_Minute = xadi.xd_Minute + xadi.xd_Hour*60;
        d->ds_Days = xadtodays(&xadi, 1978);
      }
      break;
#endif
    case XAD_GETDATEXADDATE:
      xadCopyMem(XADM &xadi, (xadPTR)(uintptr_t) ti->ti_Data, sizeof(struct xadDate));
      break;
#ifdef AMIGA
    case XAD_GETDATECLOCKDATA:
      {
        struct ClockData *c;
        c = (struct ClockData *) ti->ti_Data;
        c->sec = xadi.xd_Second;
        c->min = xadi.xd_Minute;
        c->hour = xadi.xd_Hour;
        c->wday = xadi.xd_WeekDay == XADDAY_SUNDAY ? 0 : xadi.xd_WeekDay;
        c->mday = xadi.xd_Day;
        c->month = xadi.xd_Month;
        c->year = xadi.xd_Year > 0xFFFF ? 0xFFFF : xadi.xd_Year;
      }
      break;
#endif
    case XAD_GETDATEMSDOS:
      {
        struct xadDate xd;
        xadCopyMem(XADM &xadi, &xd, sizeof(struct xadDate));

        if(xd.xd_Second&1) /* correct uneven seconds */
          addoffset(&xd, 1);
        if(xd.xd_Year > 1980+127) /* 31.12.2107 23:59:59 */
          *((xadUINT32 *)(uintptr_t)ti->ti_Data) = (xadUINT32) (((((((((127<<4)+12)<<5)+31)<<5)+23)<<6)+59)<<5)+(59/2);
        else if(xd.xd_Year < 1980) /* 1.1.1980 00:00:00 */
          *((xadUINT32 *)(uintptr_t)ti->ti_Data) = (((((((((0<<4)+1)<<5)+1)<<5)+0)<<6)+0)<<5)+0;
        else
          *((xadUINT32 *)(uintptr_t)ti->ti_Data) = ((((((((((xd.xd_Year-1980)<<4)+xd.xd_Month)<<5)+
          xd.xd_Day)<<5)+xd.xd_Hour)<<6)+xd.xd_Minute)<<5)+(xd.xd_Second/2);
      }
      break;
    case XAD_GETDATECPM2:
      {
        struct xadDate xd;
        xadCopyMem(XADM &xadi, &xd, sizeof(struct xadDate));

        if(xd.xd_Second&1) /* correct uneven seconds */
          addoffset(&xd, 1);
        if(xd.xd_Year < 1978) /* 1.1.1978 00:00:00 */
          *((xadUINT32 *)(uintptr_t)ti->ti_Data) = (((((1<<5)+0)<<6)+0)<<5)+0;
        else
        {
          timeval = xadtodays(&xd, 1978)+1;
          if(timeval > 0xFFFF)
            *((xadUINT32 *)(uintptr_t)ti->ti_Data) = (xadUINT32) (((((0xFFFF<<5)+23)<<6)+59)<<5)+(59/2);
          else
            *((xadUINT32 *)(uintptr_t)ti->ti_Data) = (((((timeval<<5)+xd.xd_Hour)<<6)+xd.xd_Minute)<<5)+(xd.xd_Second/2);
        }
      }
      break;
    case XAD_GETDATECPM:
      cpmdate = (xadUINT8 *)(uintptr_t) ti->ti_Data;
      if(xadi.xd_Year < 1978) /* 1.1.1978 00:00:00 */
      {
        *(cpmdate++) = 0;
        *(cpmdate++) = 1;
        *(cpmdate++) = 0;
        *(cpmdate++) = 0;
        *cpmdate = 0;
      }
      else
      {
        timeval = xadtodays(&xadi, 1978)+1;
        if(timeval > 0xFFFF)
        {
          *(cpmdate++) = 0xFF;
          *(cpmdate++) = 0xFF;
          *(cpmdate++) = (2<<4)+3;
          *(cpmdate++) = (5<<4)+9;
          *cpmdate = (5<<4)+9;
        }
        else
        {
          *(cpmdate++) = (xadUINT8) timeval;
          *(cpmdate++) = (xadUINT8) (timeval>>8);
          *(cpmdate++) = ((xadi.xd_Hour/10)<<4)+(xadi.xd_Hour%10);
          *(cpmdate++) = ((xadi.xd_Minute/10)<<4)+(xadi.xd_Minute%10);
          *cpmdate = ((xadi.xd_Second/10)<<4)+(xadi.xd_Second%10);
        }
      }
      break;
    case XAD_GETDATEISO9660:
      isodate = (xadUINT8 *)(uintptr_t) ti->ti_Data;
      isodate[6] = 0;
      if(xadi.xd_Year < 1900)
      {
        isodate[0] = 0; isodate[1] = 1;
        isodate[2] = 1; isodate[3] = 0;
        isodate[4] = 0; isodate[5] = 0;
      }
      else if(xadi.xd_Year > 2155)
      {
        isodate[0] = 255; isodate[1] = 12;
        isodate[2] = 31; isodate[3] = 23;
        isodate[4] = 59; isodate[5] = 59;
      }
      else
      {
        isodate[0] = xadi.xd_Year - 1900;
        isodate[1] = xadi.xd_Month;
        isodate[2] = xadi.xd_Day;
        isodate[3] = xadi.xd_Hour;
        isodate[4] = xadi.xd_Minute;
        isodate[5] = xadi.xd_Second;
      }
      break;
    }
  }
  return XADERR_OK;
}
ENDFUNC

#endif  /* XADMASTER_DATES_C */
