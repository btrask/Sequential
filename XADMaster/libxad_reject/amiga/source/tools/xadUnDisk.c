#define NAME         "xadUnDisk"
#define DISTRIBUTION "(LGPL) "
#define REVISION     "16"
#define DATE         "23.09.2003"

/*  $Id: xadUnDisk.c,v 1.3 2005/06/23 15:47:25 stoecker Exp $
    xadUnDisk - dearchives disk archives

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
#include <proto/utility.h>
#include <exec/memory.h>
#include <devices/trackdisk.h>
#include <dos/dosasl.h>
#include <dos/filehandler.h>
#include <utility/hooks.h>
#include "SDI_version.h"
#include "SDI_compiler.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

struct xadMasterBase *   xadMasterBase = 0;
struct DosLibrary *      DOSBase = 0;
struct ExecBase *        SysBase  = 0;

#define PARAM   "FROM/A,TO,LOWCYL/N,HIGHCYL/N,ENTRY/N,PASSWORD,SAVETEXTS/K," \
                "NE=NOEXTERN/S,INFO=LIST/S,SHOWTEXTS/S,OW=OVERWRITE/S," \
                "IG=IGNOREGEOMETRY/S,FORMAT/S,DIMG=DISKIMAGE/S,NAI=NOASKINSERT/S," \
                "USL=USESECTORLABELS/S"

struct Args {
  STRPTR   from;
  STRPTR   to;
  LONG *   lowcyl;
  LONG *   highcyl;
  LONG *   entry;
  STRPTR   password;
  STRPTR   savetexts;
  ULONG    noextern;
  ULONG    info;
  ULONG    showtexts;
  ULONG    overwrite;
  ULONG    ignoregeometry;
  ULONG    format;
  ULONG    diskimage;
  ULONG    noaskinsert;
  ULONG    usesectorlabels;
};

ASM(ULONG) SAVEDS progrhook(REG(a0, struct Hook *),
  REG(a1, struct xadProgressInfo *));
static struct Hook prhook = {{0,0},(ULONG (*)()) progrhook, 0, 0};
static void ShowTexts(struct xadTextInfo *ti);
static void SaveTexts(struct xadTextInfo *ti, STRPTR name);
static LONG WriteDisk(struct Args *, struct TagItem *);
static void FreeMyTags(struct TagItem *ti);
static struct TagItem *GetMyTags(STRPTR name, LONG *reserr);
static LONG AskInsertDisk(STRPTR);

ULONG start(void)
{
  ULONG ret = RETURN_FAIL;
  struct DosLibrary *dosbase;

  SysBase = (*((struct ExecBase **) 4));
  { /* test for WB and reply startup-message */
    struct Process *task;
    if(!(task = (struct Process *) FindTask(0))->pr_CLI)
    {
      WaitPort(&task->pr_MsgPort);
      Forbid();
      ReplyMsg(GetMsg(&task->pr_MsgPort));
      return RETURN_FAIL;
    }
  }

  if((dosbase = (struct DosLibrary *) OpenLibrary("dos.library", 37)))
  {
    LONG err = 0;
    struct xadMasterBase *xadmasterbase;

    DOSBase = dosbase;
    if((xadmasterbase = (struct xadMasterBase *) OpenLibrary("xadmaster.library", 11)))
    {
      LONG def = 1;
      struct Args args;
      struct RDArgs *rda;
      
      memset(&args, 0 , sizeof(struct Args));
      args.entry = &def;

      xadMasterBase = xadmasterbase;
      if((rda = ReadArgs(PARAM, (LONG *) &args, 0)))
      {
        if(args.to || args.info)
        {
          struct xadArchiveInfo *ai;
          struct TagItem *ti;

          if((ti = GetMyTags(args.from, &err)))
          {
            LONG doit = 0;

            if(args.diskimage)
            {
              ret = 0;
              err = WriteDisk(&args, ti);
            }
            else if(ti[0].ti_Tag == XAD_INDEVICE)
            {
              LONG r;

              ret = 0;
              Printf("Device input. Press <I> to read and write disk as image: ");
              Flush(Output());
              SetMode(Input(), TRUE);
              r = FGetC(Input());
              SetMode(Input(), FALSE);
              if(r == 'i' || r == 'I')
                err = WriteDisk(&args, ti);
              else
              {
                Printf("\n"); doit = 1;
              }
            }
            else
              doit = 1;

            if(doit && (ai = (struct xadArchiveInfo *)
            xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
            {
              if(!err && !(err = xadGetInfo(ai, XAD_NOEXTERN, args.noextern,
              args.password ? XAD_PASSWORD : TAG_IGNORE, args.password,
              TAG_MORE, ti)))
              {
                if(ai->xai_Flags & XADAIF_FILECORRUPT)
                  Printf("!!! The archive file has some corrupt data. !!!\n");
                if(args.info)
                {
                  struct xadDiskInfo *xdi;
                  Printf("ArchiverName:   %s\n", ai->xai_Client->xc_ArchiverName);

                  xdi = ai->xai_DiskInfo;
                  while(xdi)
                  {
                    LONG a;

                    if(xdi->xdi_EntryNumber != 1 || xdi->xdi_Next)
                      Printf("\nEntry:          %lu\n", xdi->xdi_EntryNumber);
                    Printf("EntryInfo:      %s\n", xdi->xdi_EntryInfo ? xdi->xdi_EntryInfo : "<none>");
                    Printf("SectorSize:     %lu\n", xdi->xdi_SectorSize);
                    Printf("Sectors:        %lu\n", xdi->xdi_TotalSectors);
                    Printf("Cylinders:      %lu\n", xdi->xdi_Cylinders);
                    Printf("CylSectors:     %lu\n", xdi->xdi_CylSectors);
                    Printf("Heads:          %lu\n", xdi->xdi_Heads);
                    Printf("TrackSectors:   %lu\n", xdi->xdi_TrackSectors);
                    Printf("LowCyl:         %lu\n", xdi->xdi_LowCyl);
                    Printf("HighCyl:        %lu\n", xdi->xdi_HighCyl);
                    a = xdi->xdi_Flags & (XADDIF_CRYPTED|XADDIF_SECTORLABELS);
                    if(a)
                    {
                      Printf("Flags:          ");
                      if(a & XADDIF_CRYPTED)
                      {
                        a ^= XADDIF_CRYPTED;
                        Printf("encrypted%s", a ? ", " : "\n");
                      }
                      if(a & XADDIF_SECTORLABELS)
                      {
                        a ^= XADDIF_SECTORLABELS;
                        Printf("has SectorLabels%s", a ? ", " : "\n");
                      }
                    }
                    if(xdi->xdi_TextInfo)
                    {
                      STRPTR a;
                      struct xadTextInfo *ti;

                      for(ti = xdi->xdi_TextInfo; ti; ti = ti->xti_Next)
                      {
                        a = "TextInfo";
                        if(ti->xti_Flags & XADTIF_BANNER)
                          a = "Banner";
                        else if(ti->xti_Flags & XADTIF_FILEDIZ)
                          a = "DIZ-Text";

                        if(ti->xti_Size && ti->xti_Text)
                          Printf("There is a %s with size %lu.\n", a, ti->xti_Size);
                        else if(ti->xti_Flags & XADTIF_CRYPTED)
                          Printf("There is a crypted %s.\n", a);
                        else
                          Printf("There is an empty %s.\n", a);
                      }
                      if(args.showtexts)
                        ShowTexts(xdi->xdi_TextInfo);
                      if(args.savetexts)
                        SaveTexts(xdi->xdi_TextInfo, args.savetexts);
                    }
                    xdi = xdi->xdi_Next;
                  }
                  ret = 0;
                }
                else
                {
                  struct xadDeviceInfo *dvi = 0;

                  if(args.to[strlen(args.to)-1] == ':' && stricmp(args.to, "NIL:"))
                  {
                    if((dvi = (struct xadDeviceInfo *)
                    xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
                    {
                      args.to[strlen(args.to)-1] = 0; /* strip ':' */
                      dvi->xdi_DOSName = args.to;
                    }
                    else
                      err = XADERR_NOMEMORY;
                  }
                  if(args.showtexts || args.savetexts)
                  {
                    struct xadDiskInfo *xdi = ai->xai_DiskInfo;

                    while(xdi && xdi->xdi_EntryNumber < *args.entry)
                      xdi = xdi->xdi_Next;
                    if(xdi && xdi->xdi_TextInfo)
                    {
                      if(args.showtexts)
                        ShowTexts(xdi->xdi_TextInfo);
                      if(args.savetexts)
                        SaveTexts(xdi->xdi_TextInfo, args.savetexts);
                    }
                  }
                  if(dvi && !args.noaskinsert)
                    err = AskInsertDisk(args.to);

                  if(!err && !(err = xadDiskUnArc(ai, dvi ? XAD_OUTDEVICE :
                  XAD_OUTFILENAME, dvi ? (ULONG) dvi : (ULONG) args.to,
                  XAD_ENTRYNUMBER, *args.entry, args.lowcyl ?
                  XAD_LOWCYLINDER : TAG_IGNORE, args.lowcyl ? *args.lowcyl :
                  0, args.highcyl ? XAD_HIGHCYLINDER : TAG_IGNORE,
                  args.highcyl ? *args.highcyl : 0, XAD_OVERWRITE,
                  args.overwrite, XAD_IGNOREGEOMETRY, args.ignoregeometry,
                  XAD_FORMAT, args.format, XAD_VERIFY, TRUE, XAD_USESECTORLABELS,
                  args.usesectorlabels, XAD_PROGRESSHOOK, &prhook, TAG_DONE)))
                    ret = 0;
                  if(dvi)
                    xadFreeObjectA(dvi, 0);
                }
                xadFreeInfo(ai);
              } /* xadGetInfo */
              else if(err == XADERR_FILETYPE && !(ti[0].ti_Tag == XAD_INDEVICE))
              {
                UBYTE r;

                ret = 0;
                Printf("Unknown type. Press <I> to handle it as disk image: ");
                Flush(Output());
                SetMode(Input(), TRUE);
                r = FGetC(Input());
                SetMode(Input(), FALSE);
                if(r == 'i' || r == 'I')
                  err = WriteDisk(&args, ti);
                else
                  Printf("\n");
              }

              xadFreeObjectA(ai, 0);
            } /* xadAllocObject */
            FreeMyTags(ti);
          }
        }
        else
          SetIoErr(ERROR_REQUIRED_ARG_MISSING);

        FreeArgs(rda);
      } /* ReadArgs */

      if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
        SetIoErr(ERROR_BREAK);

      if(err)
        Printf("An error occured: %s\n", xadGetErrorText(err));
      else if(ret)
        PrintFault(IoErr(), 0);

      CloseLibrary((struct Library *) xadmasterbase);
    } /* OpenLibrary xadmaster */
    else
      Printf("Could not open xadmaster.library\n");
    CloseLibrary((struct Library *) dosbase);
  } /* OpenLibrary dos */
  return ret;
}

ASM(ULONG) SAVEDS progrhook(REG(a0, struct Hook *hook),
REG(a1, struct xadProgressInfo *pi))
{
  ULONG ret = 0;

  switch(pi->xpi_Mode)
  {
  case XADPMODE_ASK:
    {
      UBYTE r;
      if(pi->xpi_Status & XADPIF_OVERWRITE)
      {
        Printf("\r\033[KFile already exists, overwrite? (Y|S|\033[1mN\033[0m): ");
        Flush(Output());
        SetMode(Input(), TRUE);
        r = FGetC(Input());
        if(r == 'Y' || r == 'y')
          ret |= XADPIF_OVERWRITE;
        else if(r == 'S' || r == 's')
          ret |= XADPIF_SKIP;
        SetMode(Input(), FALSE);
      }
      if(pi->xpi_Status & XADPIF_IGNOREGEOMETRY)
      {
        Printf("\r\033[KDrive geometry not correct, ignore? (Y|S|\033[1mN\033[0m): ");
        Flush(Output());
        SetMode(Input(), TRUE);
        r = FGetC(Input());
        if(r == 'Y' || r == 'y')
          ret |= XADPIF_IGNOREGEOMETRY;
        else if(r == 'S' || r == 's')
          ret |= XADPIF_SKIP;
        SetMode(Input(), FALSE);
      }
    }
    break;
  case XADPMODE_PROGRESS:
    {
      if(!pi->xpi_DiskInfo)
        Printf("\r\033[KWrote %lu bytes", pi->xpi_CurrentSize);
      else if(pi->xpi_DiskInfo->xdi_Flags & (XADDIF_NOCYLINDERS|XADDIF_NOCYLSECTORS))
      {
        Printf("\r\033[KWrote %lu of %lu bytes (%lu/%lu sectors)",
        pi->xpi_CurrentSize, pi->xpi_DiskInfo->xdi_TotalSectors*
        pi->xpi_DiskInfo->xdi_SectorSize, pi->xpi_CurrentSize/
        pi->xpi_DiskInfo->xdi_SectorSize, pi->xpi_DiskInfo->xdi_TotalSectors);
      }
      else
      {
        ULONG numcyl, fullsize, curcyl, i;

        i = pi->xpi_DiskInfo->xdi_CylSectors *
            pi->xpi_DiskInfo->xdi_SectorSize;
        numcyl = pi->xpi_HighCyl+1-pi->xpi_LowCyl;
        fullsize = numcyl * i;
        curcyl = pi->xpi_CurrentSize/i;

        Printf("\r\033[KWrote %lu of %lu bytes (%lu/%lu cylinders)",
        pi->xpi_CurrentSize, fullsize, curcyl, numcyl);
      }
      Flush(Output());
    }
    break;
  case XADPMODE_END:
    if(!pi->xpi_DiskInfo)
      Printf("\r\033[KWrote %lu bytes\n", pi->xpi_CurrentSize);
    else if(pi->xpi_DiskInfo->xdi_Flags & (XADDIF_NOCYLINDERS|XADDIF_NOCYLSECTORS))
      Printf("\r\033[KWrote %lu bytes (%lu sectors)\n",
      pi->xpi_CurrentSize, pi->xpi_DiskInfo->xdi_TotalSectors);
    else
      Printf("\r\033[KWrote %lu bytes (%lu cylinders)\n",
      pi->xpi_CurrentSize, pi->xpi_HighCyl+1-pi->xpi_LowCyl);
    break;
  case XADPMODE_ERROR: Printf("\r\033[K");
    break;
  }

  if(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)) /* clear ok flag */
    ret |= XADPIF_OK;

  return ret;
}

static void ShowTexts(struct xadTextInfo *ti)
{
  ULONG i = 1, j;
  BPTR fh;
  STRPTR a;

  fh = Output();

  while(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C) && ti)
  {
    if(ti->xti_Size && ti->xti_Text)
    {
      Printf("»»»» TEXTINFO %lu ««««\n", i);
      a = ti->xti_Text;
      for(j = 0; !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C) && j < ti->xti_Size; ++j)
      {
        if(isprint(*a) || *a == '\n' || *a == '\t' || *a == '\033')
          FPutC(fh, *a);
        else
          FPutC(fh, '.');
        ++a;
      }
      if(*(--a) != '\n')
        FPutC(fh, '\n');
    }
    ti = ti->xti_Next;
    ++i;
  }
}

static void SaveTexts(struct xadTextInfo *ti, STRPTR name)
{
  UBYTE namebuf[256];
  ULONG i = 1;
  BPTR fh;
  LONG err = 0;

  while(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C) && ti && !err)
  {
    if(ti->xti_Size && ti->xti_Text)
    {
      sprintf(namebuf, "%s.%lu", name, i);
      if((fh = Open(namebuf, MODE_NEWFILE)))
      {
        if(Write(fh, ti->xti_Text, ti->xti_Size) != ti->xti_Size)
          ++err;
        Close(fh);
      }
      else
        ++err;
    }
    ti = ti->xti_Next;
    ++i;
  }
  if(err)
    Printf("Failed to save information texts.\n");
}

static LONG WriteDisk(struct Args *args, struct TagItem *ti)
{
  LONG err = 0;
  struct xadArchiveInfo *ai;
  struct xadDeviceInfo *dvi = 0;

  if((ai = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
  {
    if(args->info)
    {  
      if(!(err = xadGetHookAccessA(ai, ti)))
      {
        UBYTE r;
        Printf("\r\033[KImage-Size is %lu\n", ai->xai_InSize);
        xadFreeHookAccess(ai, err ? XAD_WASERROR : TAG_DONE, err, TAG_DONE);

        Printf("Test input for known filesystem? <Y>es or <N>o: ");
        Flush(Output());
        SetMode(Input(), TRUE);
        r = FGetC(Input());
        SetMode(Input(), FALSE);
        if(r == 'y' || r == 'y')
        {
          if(!(xadGetDiskInfoA(ai, ti)))
          {
            Printf("\r\033[KImage-Type is '%s'\n", ai->xai_Client->xc_ArchiverName);
            xadFreeInfo(ai);
          }
          else
            Printf("\r\033[KImage-Type is unknown\n");
        }
        else
          Printf("\n");
      }
    }
    else
    {
      if(args->to[strlen(args->to)-1] == ':' && stricmp(args->to, "NIL:"))
      {
        if((dvi = (struct xadDeviceInfo *) xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
        {
          args->to[strlen(args->to)-1] = 0; /* strip ':' */
          dvi->xdi_DOSName = args->to;
        }
        else
          err = XADERR_NOMEMORY;
      }

      if(dvi && !args->noaskinsert)
        err = AskInsertDisk(args->to);

      if(!err)
      { 
        if(!(err = xadGetHookAccess(ai, XAD_OVERWRITE, args->overwrite,
        XAD_IGNOREGEOMETRY, args->ignoregeometry, XAD_FORMAT, args->format, XAD_VERIFY,
        TRUE, XAD_PROGRESSHOOK, &prhook, dvi ? XAD_OUTDEVICE : XAD_OUTFILENAME,
        dvi ? (ULONG) dvi : (ULONG) args->to, TAG_MORE, ti)))
        {
          err = xadHookAccess(XADAC_COPY, ai->xai_InSize, 0, ai);
          xadFreeHookAccess(ai, err ? XAD_WASERROR : TAG_DONE, err, TAG_DONE);
        }
        if(dvi)
          xadFreeObjectA(dvi, 0);
      }
    }
    xadFreeObjectA(ai,0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

static LONG AskInsertDisk(STRPTR name)
{
  UBYTE r;
  STRPTR b;
                  
  for(b = name; *b; ++b)
    *b = toupper(*b);

  Printf("\r\033[KInsert disk into %s: and press <ENTER> (any other key to abort): ", name);
  Flush(Output());
  SetMode(Input(), TRUE);
  r = FGetC(Input());
  SetMode(Input(), FALSE);
  if(r != '\r' && r != '\n')
  {
    Printf("\n");
    return XADERR_BREAK;
  }
  return 0;
}

static void FreeMyTags(struct TagItem *ti)
{
  switch(ti[0].ti_Tag)
  {
  case XAD_INDEVICE:
    xadFreeObjectA((APTR)ti[0].ti_Data, 0);
    break;
  case XAD_INSPLITTED:
    {
      struct xadSplitFile *sf0, *sf2;
      sf0 = (struct xadSplitFile *) ti[0].ti_Data;
      while(sf0)
      {
        sf2 = sf0; sf0 = sf0->xsf_Next;
        xadFreeObjectA(sf2, 0);
      }
    }
    break;
  }

  xadFreeObjectA(ti, 0);
}

static struct TagItem *GetMyTags(STRPTR name, LONG *reserr)
{
  struct TagItem *ti = 0;
  LONG i, err = 0;

  i = strlen(name);
  if(i && name[i-1] == ':') /* device input */
  {
    if((ti = (struct TagItem *) xadAllocVec(sizeof(struct TagItem)*2, MEMF_ANY|MEMF_CLEAR)))
    {
      if((ti[0].ti_Data = (ULONG) xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
      {
        name[i-1] = 0; /* strip ':' */
        ((struct xadDeviceInfo *)ti[0].ti_Data)->xdi_DOSName = name;
        ti[0].ti_Tag = XAD_INDEVICE;
      }
      else
        err = XADERR_NOMEMORY;
    }
    else
      err = XADERR_NOMEMORY;
  }
  else
  {
    struct AnchorPath *APath;
    STRPTR s, f;
    ULONG *filelist, *fl = 0, *a, *b, retval = 0, namesize = 0;

    if((APath = (struct AnchorPath *) AllocMem(sizeof(struct AnchorPath)+512, MEMF_PUBLIC|MEMF_CLEAR)))
    {
      APath->ap_BreakBits = SIGBREAKF_CTRL_C;
      APath->ap_Strlen = 512;

      while(!retval)
      {
        filelist = 0;
        for(retval = MatchFirst(name, APath); !retval; retval = MatchNext(APath))
        {
          if(APath->ap_Info.fib_DirEntryType < 0)
          {
            i = strlen(APath->ap_Buf)+1;
            if(!(a = (ULONG *) AllocVec(i+4, MEMF_ANY)))
              break;
            CopyMem(APath->ap_Buf, a+1, i);
            namesize += i;
            if(!filelist)
            {
              filelist = a; *a = 0;
            }
            else if(stricmp((STRPTR) (filelist+1), APath->ap_Buf) >= 0)
            {
              *a = (ULONG) filelist; filelist = a;
            }
            else
            {
              for(b = filelist; *b && (i = stricmp((STRPTR) (*b+4),
              APath->ap_Buf)) < 0; b = (ULONG *) *b)
                ;
              *a = *b; *b = (ULONG) a;
            }
          }
        }
        if(fl)
        {
          for(b = fl; *b; b = (ULONG *) *b)
            ;
          *b = (ULONG) filelist;
        }
        else
          fl = filelist;
        MatchEnd(APath);
        if(retval == ERROR_NO_MORE_ENTRIES)
        {
          retval = 0;
          break;
        }
      }

      if(!retval)
      {
        i = 0;
        for(b = fl; b; b = (ULONG *) *b)
          ++i;
        if((ti = (struct TagItem *) xadAllocVec(2*sizeof(struct TagItem)+namesize, MEMF_ANY|MEMF_CLEAR)))
        {
          s = ((STRPTR) ti)+(2*sizeof(struct TagItem));
          if(i == 1)
          {
            ti[0].ti_Tag = XAD_INFILENAME;
            ti[0].ti_Data = (ULONG) s;
            for(f = (STRPTR) (fl+1); *f; ++f)
              *(s++) = *f;
            /* *s = 0; */
          }
          else
          {
            struct xadSplitFile *sf = 0, *sf2;
            ti[0].ti_Tag = XAD_INSPLITTED;
            for(b = fl; !err && b; b = (ULONG *) *b)
            {
              if((sf2 = xadAllocObjectA(XADOBJ_SPLITFILE, 0)))
              {
                if(sf)
                  sf->xsf_Next = sf2;
                else
                  ti[0].ti_Data = (ULONG) sf2;
                sf = sf2;
                sf->xsf_Type = XAD_INFILENAME;
                sf->xsf_Data = (ULONG) s;
              }
              else
                err = XADERR_NOMEMORY;
              for(f = (STRPTR) (b+1); *f; ++f)
                *(s++) = *f;
              *(s++) = 0;
            }
          }
        }
        else
          err = XADERR_NOMEMORY;
      }

      while(fl)
      {
        a = (ULONG *) *fl;
        FreeVec(fl);
        fl = a;
      }

      FreeMem(APath, sizeof(struct AnchorPath)+512);
    }

    if(!retval)
    {
      if(ti[0].ti_Tag == XAD_INSPLITTED)
      {
        struct xadSplitFile *sf;
        Printf("Loading files in following order: ");

        for(sf = (struct xadSplitFile *) ti[0].ti_Data; sf; sf=sf->xsf_Next)
          Printf("%s%s", sf->xsf_Data, sf->xsf_Next ? ", " : "\n");
      }
    }
    else
      err = XADERR_INPUT;
  }

  if(err)
  {
    *reserr = err;
    if(ti)
    {
      FreeMyTags(ti); ti = 0;
    }
  }
  return ti;
}

