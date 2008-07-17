#ifdef MULTIFILE
  #define NAME         "xadUnFileM"
#else
  #define NAME         "xadUnFile"
#endif
#define DISTRIBUTION "(LGPL) "
#define REVISION     "25"
#define DATE	     "10.03.2002"

/*  $Id: xadUnFile.c,v 1.4 2005/06/23 15:47:25 stoecker Exp $
    xadUnFile - dearchives file archives

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
#include <exec/memory.h>
#include <dos/dosasl.h>
#include <utility/hooks.h>
#include "SDI_version.h"
#include "SDI_compiler.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

struct xadMasterBase *	xadMasterBase = 0;
struct DosLibrary *	 DOSBase = 0;
struct ExecBase *	 SysBase  = 0;

#define MINPRINTSIZE	51200	/* 50KB */
#define NAMEBUFSIZE	512
#define PATBUFSIZE	(NAMEBUFSIZE*2+10)

#ifdef MULTIFILE
#define PARAM	"FROM/A/M,DEST=DESTDIR/K,PASSWORD/K,FILE/K,"	\
		"NAMESIZE/K/N,FFS=OFS/S,SFS/S,"			\
		"INFO=LIST/S,Q=QUIET/S,AM=ASKMAKEDIR/S,"	\
		"OW=OVERWRITE/S,SP=SHOWPROT/S,VERBOSE/S,"	\
		"DARC=DISKARCHIVE/S,ENTRY/K/N,DIMG=DISKIMAGE/S,"\
		"NA=NOABS/S,NC=NOCOMMENT/S,ND=NODATE/S,"	\
		"NE=NOEXTERN/S,NKP=NOKILLPART/S,NP=NOPROT/S,"	\
		"NT=NOTREE/S"
#else
#define PARAM	"FROM/A,DEST=DESTDIR,PASSWORD/K,FILE/M,"	\
		"NAMESIZE/K/N,FFS=OFS/S,SFS/S,"			\
		"INFO=LIST/S,Q=QUIET/S,AM=ASKMAKEDIR/S,"	\
		"OW=OVERWRITE/S,SP=SHOWPROT/S,VERBOSE/S,"	\
		"DARC=DISKARCHIVE/S,ENTRY/K/N,DIMG=DISKIMAGE/S,"\
		"NA=NOABS/S,NC=NOCOMMENT/S,ND=NODATE/S,"	\
		"NE=NOEXTERN/S,NKP=NOKILLPART/S,NP=NOPROT/S,"	\
		"NT=NOTREE/S"
#endif

#ifdef MULTIFILE
#define OPTIONS1 \
  "FROM       The input archive file(s)\n"				\
  "DESTDIR    The destination directory, not needed with INFO\n"	\
  "PASSWORD   A password for encrypted archives\n"			\
  "FILE       Filename (with patterns) to be extracted\n"
#else
#define OPTIONS1 \
  "FROM       The input archive file (no patterns allowed)\n"		\
  "DESTDIR    The destination directory, not needed with INFO\n"	\
  "PASSWORD   A password for encrypted archives\n"			\
  "FILE       Filename(s) (with patterns) to be extracted\n"
#endif

#define OPTIONS2 \
  "NAMESIZE   Names with more characters result in rename request\n"	\
  "FFS=OFS    Sets NAMESIZE to 30\n"					\
  "SFS        Sets NAMESIZE to 100\n"					\
  "INFO       Shows archive information without extracting\n"		\
  "QUIET      Turns of progress report and user interaction\n"		\
  "ASKMAKEDIR You get asked before a directory is created\n"		\
  "OVERWRITE  Files are overwritten without asking\n"			\
  "SHOWPROT   Show protection information with LIST\n"			\
  "VERBOSE    Print some more information with INFO\n"			\
  "DARC       input file is an disk archive\n"				\
  "ENTRY      entry number for DARC, if not the first one\n"		\
  "DIMG	      input file is an disk image (ADF file)\n"			\
  "NOABS      Do not extract absolute path name parts\n"		\
  "NOCOMMENT  No filenote comments are extracted or displayed\n"	\
  "NODATE     Creation date information gets not extracted\n"		\
  "NOEXTERN   Turns off usage of external clients\n"			\
  "NOKILLPART Do not delete partial or corrupt output files.\n"		\
  "NOPROT     Protection information gets not extracted\n"		\
  "NOTREE     Files are extracted without subdirectories\n"

struct xHookArgs {
  STRPTR name;
  ULONG extractmode;
  ULONG flags;
  ULONG finish;
  ULONG lastprint;
};

struct Args {
#ifdef MULTIFILE
  STRPTR * from;
  STRPTR   destdir;
  STRPTR   password;
  STRPTR   file;
#else
  STRPTR   from;
  STRPTR   destdir;
  STRPTR   password;
  STRPTR * file;
#endif
  LONG *   namesize;
  ULONG    ffs;
  ULONG	   sfs;
  ULONG    info;
  ULONG    quiet;
  ULONG    askmakedir;
  ULONG    overwrite;
  ULONG	   showprot;
  ULONG    verbose;
  ULONG    diskarchive;
  LONG *   entry;
  ULONG    diskimage;
  ULONG    noabs;
  ULONG    nocomment;
  ULONG    nodate;
  ULONG    noextern;
  ULONG	   nokillpart;
  ULONG    noprot;
  ULONG    notree;
};

ASM(ULONG) progrhook(REG(a0, struct Hook *),
  REG(a1, struct xadProgressInfo *));

void ShowProt(ULONG i);
LONG CheckNameSize(STRPTR name, ULONG size);
void CalcPercent(ULONG cr, ULONG ucr, ULONG *p1, ULONG *p2);

#ifndef MULTIFILE
  LONG CheckName(STRPTR *pat, STRPTR name);
#else
  STRPTR *GetNames(STRPTR *names);
#endif

ULONG start(void)
{
  ULONG ret = RETURN_FAIL, numerr = 0;
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
    if((xadmasterbase = (struct xadMasterBase *)
    OpenLibrary("xadmaster.library", 13)))
    {
      struct Args args;
      struct RDArgs *rda;
      
      memset(&args, 0, sizeof(struct Args));
      xadMasterBase = xadmasterbase;

      if((rda = (struct RDArgs *) AllocDosObject(DOS_RDARGS, 0)))
      {
        rda->RDA_ExtHelp = OPTIONS1 OPTIONS2;

        if(ReadArgs(PARAM, (LONG *) &args, rda))
        {
          LONG namesize = 0;
	  struct Hook prhook;
	  UBYTE filename[NAMEBUFSIZE];
	  struct xHookArgs xh;

#ifdef MULTIFILE
	  STRPTR *argstring;
#endif

	  xh.name = filename;
	  xh.flags = xh.finish = xh.lastprint = xh.extractmode = 0;

	  /* Note! The hook may change the filename!!! */
          memset(&prhook, 0, sizeof(struct Hook));
          prhook.h_Entry = (ULONG (*)()) progrhook;
          prhook.h_Data = &xh;
          
          if(args.namesize && *args.namesize > 0)
            namesize = *args.namesize;
          else if(args.ffs)
            namesize = 30;
          else if(args.sfs)
            namesize = 100;

#ifdef MULTIFILE
	  if(!(args.from = argstring = GetNames(args.from))) /* correct the argument list */
            ;
          else if(!(*argstring))
            SetIoErr(ERROR_REQUIRED_ARG_MISSING);
	  else /* comes together with following if! */
#endif
	  if(args.destdir || args.info)
	  {
            ULONG numfile = 0, numdir = 0;
            struct xadDeviceInfo *dvi = 0;
	    struct xadArchiveInfo *ai;
            struct TagItem ti[5];
            struct TagItem ti2[5];
            LONG loop = 2;
            
            ti[1].ti_Tag = XAD_NOEXTERN;
	    ti[1].ti_Data = args.noextern;
	    ti[2].ti_Tag = args.password ? XAD_PASSWORD : TAG_IGNORE;
	    ti[2].ti_Data = (ULONG) args.password;
	    ti[3].ti_Tag = args.entry ? XAD_ENTRYNUMBER : TAG_IGNORE;
	    ti[3].ti_Data = args.entry ? *args.entry : 1;
	    ti[4].ti_Tag = TAG_DONE;

	    ti2[1].ti_Tag = XAD_NOEMPTYERROR;
	    ti2[1].ti_Data = TRUE;
	    ti2[2].ti_Tag = args.quiet ? TAG_IGNORE : XAD_PROGRESSHOOK;
	    ti2[2].ti_Data = (ULONG) &prhook;
	    ti2[3].ti_Tag = TAG_DONE;
	    ti2[4].ti_Tag = TAG_DONE; /* needed later for loop */

	    if((ai = (struct xadArchiveInfo *)
	    xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
	    {
#ifdef MULTIFILE
	      if(*(args.from+1))
	      {
	        struct xadSplitFile *sf = 0, *sf2, *sf0 = 0;
		while(*args.from && !err)
		{
		  if((sf2 = xadAllocObjectA(XADOBJ_SPLITFILE, 0)))
		  {
		    if(sf)
		    {
		      sf->xsf_Next = sf2; sf = sf2;
		    }
		    else
		      sf0 = sf = sf2;
		    sf->xsf_Type = XAD_INFILENAME;
		    sf->xsf_Data = (ULONG) *(args.from++);
		  }
		  else
		    err = XADERR_NOMEMORY;
		}
	        if(!err)
	        {
	          if(args.diskarchive)
	          {
	            ti[0].ti_Tag = XAD_INSPLITTED;
	            ti[0].ti_Data = (ULONG) sf0;

		    ti2[0].ti_Tag = XAD_INDISKARCHIVE;
		    ti2[0].ti_Data = (ULONG) ti;
	            if((err = xadGetDiskInfoA(ai, ti2)))
	            {
	              ti2[0].ti_Tag = XAD_INSPLITTED;
	              ti2[0].ti_Data = (ULONG) sf0;
	              if(!xadGetDiskInfoA(ai, ti2))
	                err = 0;
	            }
	          }
	          else if(args.diskimage)
	          {
	            ti2[0].ti_Tag = XAD_INSPLITTED;
	            ti2[0].ti_Data = (ULONG) sf0;
	            err = xadGetDiskInfoA(ai, ti2);
	          }
	          else
	          {
	            err = xadGetInfo(ai, XAD_INSPLITTED, sf0, XAD_NOEXTERN,
	            args.noextern, args.password ? XAD_PASSWORD : TAG_IGNORE,
	            args.password, args.quiet ? TAG_IGNORE : XAD_PROGRESSHOOK,
	            &prhook, TAG_DONE);
	            --loop;
	          }
	        }
	        while(sf0)
	        {
	          sf2 = sf0; sf0 = sf0->xsf_Next;
	          xadFreeObjectA(sf2, 0);
	        }
	      }
	      else if(args.diskarchive)
	      {
	        ti[0].ti_Tag = XAD_INFILENAME;
	        ti[0].ti_Data = (ULONG) *args.from;

		ti2[0].ti_Tag = XAD_INDISKARCHIVE;
		ti2[0].ti_Data = (ULONG) ti;
	        if((err = xadGetDiskInfoA(ai, ti2)))
	        {
	          ti2[0].ti_Tag = XAD_INFILENAME;
	          ti2[0].ti_Data = (ULONG) *args.from;
	          if(!xadGetDiskInfoA(ai, ti2))
	            err = 0;
	        }
	      }
	      else if(args.diskimage)
	      {
	        if(*args.from[strlen(*args.from)-1] == ':')
	        {
	          if((dvi = (struct xadDeviceInfo *) xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
	          {
	            *args.from[strlen(*args.from)-1] = 0; /* strip ':' */
	            dvi->xdi_DOSName = *args.from;
	            ti2[0].ti_Tag = XAD_INDEVICE;
	            ti2[0].ti_Data = (ULONG) dvi;
	            err = xadGetDiskInfoA(ai, ti2);
/*	            *args.from[strlen(*args.from)] = ':'; */
	          }
	          else
	            err = XADERR_NOMEMORY;
	        }
	        else
	        {
	          ti2[0].ti_Tag = XAD_INFILENAME;
	          ti2[0].ti_Data = (ULONG) *args.from;
	          err = xadGetDiskInfoA(ai, ti2);
	        }
	      }
	      else
	      {
	        err = xadGetInfo(ai, XAD_INFILENAME, *args.from,
	        XAD_NOEXTERN, args.noextern, args.password ? XAD_PASSWORD :
	        TAG_IGNORE, args.password, args.quiet ? TAG_IGNORE : XAD_PROGRESSHOOK,
	        &prhook, TAG_DONE);
	        --loop;
	      }
#else
	      if(args.diskarchive)
	      { 
	        ti[0].ti_Tag = XAD_INFILENAME;
	        ti[0].ti_Data = (ULONG) args.from;

		ti2[0].ti_Tag = XAD_INDISKARCHIVE;
		ti2[0].ti_Data = (ULONG) ti;
	        if((err = xadGetDiskInfoA(ai, ti2)))
	        {
	          ti2[0].ti_Tag = XAD_INFILENAME;
	          ti2[0].ti_Data = (ULONG) args.from;
	          if(!xadGetDiskInfoA(ai, ti2))
	            err = 0;
	        }
	      }
	      else if(args.diskimage)
	      {
	        if(args.from[strlen(args.from)-1] == ':')
	        {
	          if((dvi = (struct xadDeviceInfo *) xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
	          {
	            args.from[strlen(args.from)-1] = 0; /* strip ':' */
	            dvi->xdi_DOSName = args.from;
	            ti2[0].ti_Tag = XAD_INDEVICE;
	            ti2[0].ti_Data = (ULONG) dvi;
	            err = xadGetDiskInfoA(ai, ti2);
/*	            args.from[strlen(args.from)] = ':'; */
	          }
	          else
	            err = XADERR_NOMEMORY;
	        }
	        else
	        {
	          ti2[0].ti_Tag = XAD_INFILENAME;
	          ti2[0].ti_Data = (ULONG) args.from;
	          err = xadGetDiskInfoA(ai, ti2);
	        }
	      }
	      else
	      {
	        err = xadGetInfo(ai, XAD_INFILENAME, args.from,
	        XAD_NOEXTERN, args.noextern, args.password ? XAD_PASSWORD :
	        TAG_IGNORE, args.password, args.quiet ? TAG_IGNORE :
	        XAD_PROGRESSHOOK, &prhook, TAG_DONE);
	        --loop;
	      }
#endif

	      while(!err && loop)
	      {
	        if(ai->xai_Flags & XADAIF_FILECORRUPT)
	          Printf("!!! The archive file has some corrupt data. !!!\n");
	        if(args.info)
	        {
	          struct xadFileInfo *xfi;
	          ULONG grsize = 0;
	          if(ai->xai_Client)
	            Printf("ClientName: %s\n", ai->xai_Client->xc_ArchiverName);
		  Printf("Size     CrndSize Ratio Date       Time     %s%sName\n",
		  args.verbose ? "Info           " : "",args.showprot ? "Protection       " : "");

	          xfi = ai->xai_FileInfo;
	          while(xfi && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
	          {
	            if(!(xfi->xfi_Flags & XADFIF_GROUPED))
	              grsize = 0;
		    if(xfi->xfi_Flags & XADFIF_DIRECTORY)
		    {
	              Printf("   <dir>    <dir>       %02ld.%02ld.%04ld %02ld:%02ld:%02ld ",
	              xfi->xfi_Date.xd_Day, xfi->xfi_Date.xd_Month,
	              xfi->xfi_Date.xd_Year, xfi->xfi_Date.xd_Hour,
	              xfi->xfi_Date.xd_Minute, xfi->xfi_Date.xd_Second);
		      if(args.verbose)
		        Printf("%-15s", xfi->xfi_EntryInfo);
	              if(args.showprot)
	                ShowProt(xfi->xfi_Protection);
	              Printf("%s\n", args.notree ? FilePart(xfi->xfi_FileName) :
	              xfi->xfi_FileName);
	            }
		    else if(xfi->xfi_Flags & XADFIF_GROUPED)
		    {
	              Printf("%8lu   merged  n/a  %02ld.%02ld.%04ld %02ld:%02ld:%02ld ",
	              xfi->xfi_Size, xfi->xfi_Date.xd_Day, xfi->xfi_Date.xd_Month,
	              xfi->xfi_Date.xd_Year, xfi->xfi_Date.xd_Hour,
	              xfi->xfi_Date.xd_Minute, xfi->xfi_Date.xd_Second);
		      if(args.verbose)
		        Printf("%-15s", xfi->xfi_EntryInfo);
	              if(args.showprot)
	                ShowProt(xfi->xfi_Protection);
	              Printf("%s\n", args.notree ? FilePart(xfi->xfi_FileName) :
	              xfi->xfi_FileName);
	              grsize += xfi->xfi_Size;
	              if(xfi->xfi_Flags & XADFIF_ENDOFGROUP)
	              {
		        ULONG i, j;
		      
			CalcPercent(xfi->xfi_GroupCrSize, grsize, &i, &j);
	                Printf("%8ld %8ld %2ld.%1ld%%\n", grsize, xfi->xfi_GroupCrSize, i, j);
	                grsize = 0;
	              }
		    }
		    else if(xfi->xfi_Flags & XADFIF_NOUNCRUNCHSIZE)
		    {
	              Printf("<nosize> %8lu       %02ld.%02ld.%04ld %02ld:%02ld:%02ld ",
	              xfi->xfi_CrunchSize, xfi->xfi_Date.xd_Day, xfi->xfi_Date.xd_Month,
	              xfi->xfi_Date.xd_Year, xfi->xfi_Date.xd_Hour,
	              xfi->xfi_Date.xd_Minute, xfi->xfi_Date.xd_Second);
		      if(args.verbose)
		        Printf("%-15s", xfi->xfi_EntryInfo);
	              if(args.showprot)
	                ShowProt(xfi->xfi_Protection);
	              Printf("%s\n", args.notree ? FilePart(xfi->xfi_FileName) :
	              xfi->xfi_FileName);
	            }
		    else
		    {
		      ULONG i, j;
		      
		      CalcPercent(xfi->xfi_CrunchSize, xfi->xfi_Size, &i, &j);
	              Printf("%8lu %8lu %2ld.%1ld%% %02ld.%02ld.%04ld %02ld:%02ld:%02ld ",
	              xfi->xfi_Size, xfi->xfi_CrunchSize, i, j,
	              xfi->xfi_Date.xd_Day, xfi->xfi_Date.xd_Month,
	              xfi->xfi_Date.xd_Year, xfi->xfi_Date.xd_Hour,
	              xfi->xfi_Date.xd_Minute, xfi->xfi_Date.xd_Second);
		      if(args.verbose)
		        Printf("%-15s", xfi->xfi_EntryInfo);
	              if(args.showprot)
	                ShowProt(xfi->xfi_Protection);
	              Printf("%s\n", args.notree ? FilePart(xfi->xfi_FileName) :
	              xfi->xfi_FileName);
	            }
	            if(xfi->xfi_Flags & XADFIF_LINK)
	              Printf("link: %s\n", xfi->xfi_LinkName);
	            if(!args.nocomment)
	            {
	              if(xfi->xfi_Comment)
	                Printf(": %s\n", xfi->xfi_Comment);
	              if(xfi->xfi_Special && xfi->xfi_Special->xfis_Type ==
	              XADSPECIALTYPE_UNIXDEVICE)
	                Printf(": Unix %s device (%3ld | %3ld)\n", xfi->xfi_FileType ==
	                XADFILETYPE_UNIXBLOCKDEVICE ? "block" : "character",
	                xfi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MajorVersion,
	                xfi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MinorVersion);
	              if(xfi->xfi_FileType == XADFILETYPE_UNIXFIFO)
	                Printf(": Unix named pipe\n");
	            }
#ifdef DEBUG
		    if(xfi->xfi_Flags)
		    {
	              Printf("Flags: ");
	              if(xfi->xfi_Flags & XADFIF_CRYPTED)
	                Printf("XADFIF_CRYPTED ");
	              if(xfi->xfi_Flags & XADFIF_DIRECTORY)
	                Printf("XADFIF_DIRECTORY ");
	              if(xfi->xfi_Flags & XADFIF_LINK)
	                Printf("XADFIF_LINK ");
	              if(xfi->xfi_Flags & XADFIF_INFOTEXT)
	                Printf("XADFIF_INFOTEXT ");
	              if(xfi->xfi_Flags & XADFIF_GROUPED)
	                Printf("XADFIF_GROUPED ");
	              if(xfi->xfi_Flags & XADFIF_ENDOFGROUP)
	                Printf("XADFIF_ENDOFGROUP ");
	              if(xfi->xfi_Flags & XADFIF_NODATE)
	                Printf("XADFIF_NODATE ");
	              Printf("\n");
	            }
#endif
	            if(xfi->xfi_Flags & XADFIF_CRYPTED)
	              Printf("The entry is encrypted.\n");
	            if(xfi->xfi_Flags & XADFIF_PARTIALFILE)
	              Printf("The entry is no complete file.\n");
	            xfi = xfi->xfi_Next;
	          }
	          ret = 0;
	        }
	        else
	        {
		  struct xadFileInfo *fi;
#ifdef MULTIFILE
  		  UBYTE parsebuf[PATBUFSIZE];
#endif
		  ret = 0;
		  fi = ai->xai_FileInfo;

#ifdef MULTIFILE
  		  if(!args.file || ParsePatternNoCase(args.file, parsebuf, PATBUFSIZE) >= 0)
#endif
  		  {
		    while(fi && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C) && !xh.finish)
		    {
#ifdef MULTIFILE
		      if(!args.file || MatchPatternNoCase(parsebuf, args.notree ?
		      FilePart(fi->xfi_FileName) : fi->xfi_FileName))
#else
		      if(!args.file || CheckName(args.file, args.notree ?
		      FilePart(fi->xfi_FileName) : fi->xfi_FileName))
#endif
		      {
		        CopyMem(args.destdir, filename, strlen(args.destdir)+1);
			if(stricmp(args.destdir, "NIL:"))
			{
		          if(args.notree)
		            AddPart(filename, FilePart(fi->xfi_FileName), NAMEBUFSIZE);
		          else if(!args.noabs)
		            AddPart(filename, fi->xfi_FileName, NAMEBUFSIZE);
		          else
		          {
		            STRPTR fname = filename, f;

			    if(*args.destdir)
			    {
		              fname += strlen(args.destdir)-1;
		              if(*fname != ':' && *fname != '/')
		                *(++fname) = '/';
		              ++fname;
		            }
			    for(f = fi->xfi_FileName; *f == '/' || *f == ':'; ++f)
			      ;
		            for(; *f; ++f)
		              *(fname++) = *f == ':' ? '/' : *f;
		            *fname = 0;
		          }
		        }
		        if(fi->xfi_Flags & XADFIF_LINK)
		        {
		          if(!args.quiet)
		            Printf("Skipped Link\n");
		        }
		        else if(fi->xfi_Flags & XADFIF_DIRECTORY)
		        {
		          if(!args.notree)
		          {
		            BPTR a;
		            LONG err = 0, i = 0;
		            UBYTE r;
			    ++numdir;
    			    while(filename[i] && !err)
    			    {
      			      for(;filename[i] && filename[i] != '/'; ++i)
        		        ;
      			      r = filename[i];
      			      filename[i] = 0;
			      if((a = Lock(filename, SHARED_LOCK)))
          		        UnLock(a);
        		      else if((a = CreateDir(filename)))
            		        UnLock(a);
          		      else
            		        err = 1;
            		      filename[i++] = r;
		            }
		            if(!args.quiet)
		            {
		              if(err)
		              {
		                Printf("failed to create directory '%s'\n", fi->xfi_FileName);
		                ++numerr;
		              }
		              else
		                Printf("Created directory   : %s\n", filename);
		            }
	                    if(!err)
	                    {
		              struct DateStamp d;

	                      if(!args.nodate && !(fi->xfi_Flags & XADFIF_NODATE)
	                      && !xadConvertDates(XAD_DATEXADDATE, &fi->xfi_Date,
	                      XAD_GETDATEDATESTAMP, &d, TAG_DONE))
	                        SetFileDate(filename, &d);
	                      if(!args.noprot)
	                        SetProtection(filename, fi->xfi_Protection);
	                      if(fi->xfi_Comment && !args.nocomment)
	                        SetComment(filename, fi->xfi_Comment);
	                      /* SetOwner ??? */
	                    }
		          }
		        } 
		        else
		        {
		          struct DateStamp d;

			  if(namesize)
			    xh.finish = CheckNameSize(FilePart(filename), namesize);

			  if(!xh.finish)
			  {
			    LONG e;

			    ++numfile;

                            xh.extractmode = 1;
                            e = xadFileUnArc(ai, XAD_OUTFILENAME, filename,
                            XAD_ENTRYNUMBER, fi->xfi_EntryNumber, XAD_MAKEDIRECTORY,
                            !args.askmakedir, XAD_OVERWRITE, args.overwrite,
                            XAD_NOKILLPARTIAL, args.nokillpart,  args.quiet ? TAG_IGNORE :
                            XAD_PROGRESSHOOK, &prhook, TAG_DONE);
                            xh.extractmode = 0;

	                    if(!e)
	                    {
	                      if(!args.nodate && !(fi->xfi_Flags & XADFIF_NODATE)
	                      && !xadConvertDates(XAD_DATEXADDATE, &fi->xfi_Date,
	                      XAD_GETDATEDATESTAMP, &d, TAG_DONE))
	                        SetFileDate(filename, &d);
	                      if(!args.noprot)
	                        SetProtection(filename, fi->xfi_Protection);
	                      if(fi->xfi_Comment && !args.nocomment)
	                        SetComment(filename, fi->xfi_Comment);
	                      /* SetOwner ??? */
	                    }
	                    else
	                      ++numerr;
	                    /* IO-errors, abort */
	                    if(e == XADERR_INPUT || e == XADERR_OUTPUT)
	                      xh.finish = 1;
	                  }
	                }
	              }
	              fi = fi->xfi_Next;
	            }
	          }
	        }
	        ti2[3].ti_Tag = XAD_STARTCLIENT;
	        ti2[3].ti_Data = (ULONG) ai->xai_Client->xc_Next;
	        xadFreeInfo(ai);
	        if(--loop)
	        {
	          loop = 0;
	          if(ti2[3].ti_Data)
	          {
		    xadFreeObjectA(ai, 0); /* realloc ai structure */
	            if((ai = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
	            {
	              if(!xadGetDiskInfoA(ai, ti2))
	                loop = 2;
	            }
	          }
	        }
		if(!args.info && !loop && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
		{
		  Printf("Processed");
		  if(numfile)
		    Printf(" %ld file%s%s", numfile, numfile == 1 ? "" : "s", numdir ? " and" : "");
		  if(numdir)
		    Printf(" %ld director%s", numdir, numdir == 1 ? "y" : "ies");
		  if(!numfile && !numdir)
		    Printf(" nothing");
		  if(numerr)
		    Printf(", %ld error%s", numerr, numerr == 1 ? "" : "s");
		  Printf(".\n");
		}
	      } /* xadGetInfo, loop */

	      if(ai)
	        xadFreeObjectA(ai, 0);
	      if(dvi)
	        xadFreeObjectA(dvi, 0);
            } /* xadAllocObject */
          }
          else
            SetIoErr(ERROR_REQUIRED_ARG_MISSING);

#ifdef MULTIFILE
	  if(argstring)
	    FreeVec(argstring);
#endif

          FreeArgs(rda);
        } /* ReadArgs */
        FreeDosObject(DOS_RDARGS, rda);
      } /* AllocDosObject */

      if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
        SetIoErr(ERROR_BREAK);

      if(!args.quiet)
      {
        if(err)
	  Printf("An error occured: %s\n", xadGetErrorText(err));
        else if(ret)
          PrintFault(IoErr(), 0);
      }

      CloseLibrary((struct Library *) xadmasterbase);
    } /* OpenLibrary xadmaster */
    else
      Printf("Could not open xadmaster.library\n");
    CloseLibrary((struct Library *) dosbase);
  } /* OpenLibrary dos */

  if(!ret && numerr)
    ret = RETURN_ERROR;

  return ret;
}

/* Because of SAS-err, this cannot be SAVEDS */
ASM(ULONG) progrhook(REG(a0, struct Hook *hook),
REG(a1, struct xadProgressInfo *pi))
{
  ULONG ret = 0;
  STRPTR name = ((struct xHookArgs *) (hook->h_Data))->name;

  switch(pi->xpi_Mode)
  {
  case XADPMODE_ASK:
    ret |= ((struct xHookArgs *) (hook->h_Data))->flags;
    if((pi->xpi_Status & XADPIF_OVERWRITE) && !(ret & XADPIF_OVERWRITE))
    {
      LONG r;

      Printf("File '%s' already exists, overwrite? (Y|A|S|\033[1mN\033[0m|Q|R): ",
      pi->xpi_FileName);
      Flush(Output());
      SetMode(Input(), TRUE);
      r = FGetC(Input());
      SetMode(Input(), FALSE);
      switch(r)
      {
      case 'a': case 'A':
	((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_OVERWRITE;
      case 'y': case 'Y': ret |= XADPIF_OVERWRITE; break;
      case 's': case 'S': ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': ((struct xHookArgs *) (hook->h_Data))->finish = 1; break;
      case 'r': case 'R':
        Printf("\r\033[KEnter new (full) name for '%s':", pi->xpi_FileName);
        Flush(Output());
        FGets(Input(), name, NAMEBUFSIZE-1); /* 1 byte less to correct bug before V39 */
        r = strlen(name);
        if(name[r-1] == '\n') /* skip return character */
          name[--r] = 0;
        Printf("\033[1F\033[K"); /* go up one line and clear it */
        if((pi->xpi_NewName = xadAllocVec(++r, MEMF_PUBLIC)))
        {
          while(r--)
            pi->xpi_NewName[r] = name[r];
          ret |= XADPIF_RENAME;
        }
        else
          Printf("No memory to store new name\n");
      }
    }
    if((pi->xpi_Status & XADPIF_ISDIRECTORY))
    {
      LONG r;

      Printf("File '%s' exists as directory, rename? (R|S|\033[1mN\033[0m|Q): ",
      pi->xpi_FileName);
      Flush(Output());
      SetMode(Input(), TRUE);
      r = FGetC(Input());
      SetMode(Input(), FALSE);
      switch(r)
      {
      case 's': case 'S': ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': ((struct xHookArgs *) (hook->h_Data))->finish = 1; break;
      case 'r': case 'R':
        Printf("\r\033[KEnter new (full) name for '%s':", pi->xpi_FileName);
        Flush(Output());
        FGets(Input(), name, NAMEBUFSIZE-1); /* 1 byte less to correct bug before V39 */
        r = strlen(name);
        if(name[r-1] == '\n') /* skip return character */
          name[--r] = 0;
        Printf("\033[1F\033[K"); /* go up one line and clear it */
        if((pi->xpi_NewName = xadAllocVec(++r, MEMF_PUBLIC)))
        {
          while(r--)
            pi->xpi_NewName[r] = name[r];
          ret |= XADPIF_RENAME;
        }
        else
          Printf("No memory to store new name\n");
      }
    }
    if((pi->xpi_Status & XADPIF_MAKEDIRECTORY) &&
    !(ret & XADPIF_MAKEDIRECTORY))
    {
      Printf("Directory of file '%s' does not exist, create? (Y|A|S|\033[1mN\033[0m|Q): ",
      name);
      Flush(Output());
      SetMode(Input(), TRUE);
      switch(FGetC(Input()))
      {
      case 'a': case 'A':
	((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_MAKEDIRECTORY;
      case 'y': case 'Y': ret |= XADPIF_MAKEDIRECTORY; break;
      case 's': case 'S': ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': ((struct xHookArgs *) (hook->h_Data))->finish = 1;
      }
      SetMode(Input(), FALSE);
    }
    break;
  case XADPMODE_PROGRESS:
    if(pi->xpi_CurrentSize - ((struct xHookArgs *) (hook->h_Data))->lastprint >= MINPRINTSIZE)
    {
      if(pi->xpi_FileInfo->xfi_Flags & XADFIF_NOUNCRUNCHSIZE)
        Printf("\r\033[KWrote %8lu bytes: %s", pi->xpi_CurrentSize, name);
      else
        Printf("\r\033[KWrote %8lu of %8lu bytes: %s",
        pi->xpi_CurrentSize, pi->xpi_FileInfo->xfi_Size, name);
      Flush(Output());
      ((struct xHookArgs *) (hook->h_Data))->lastprint = pi->xpi_CurrentSize;
    }
    break;
  case XADPMODE_END: Printf("\r\033[KWrote %8ld bytes: %s\n",
    pi->xpi_CurrentSize, name);
    break;
  case XADPMODE_ERROR:
    if(((struct xHookArgs *) (hook->h_Data))->extractmode)
      Printf("\r\033[K%s: %s\n", name, xadGetErrorText(pi->xpi_Error));
    break;
/*
  case XADPMODE_GETINFOEND:
    break;
*/
  }

  if(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)) /* clear ok flag */
    ret |= XADPIF_OK;

  return ret;
}

void ShowProt(ULONG i)
{
  LONG j;
  UBYTE buf[16], *b = "rwedrwedhsparwed";
  
  for(j = 0; j <= 11; ++j)
    buf[j] = (i & (1<<(15-j))) ? b[j] : '-';
  for(; j <= 15; ++j)
    buf[j] = (i & (1<<(15-j))) ? '-' : b[j];

  Printf("%.16s ", buf);
}

LONG CheckNameSize(STRPTR name, ULONG size)
{
  LONG ret = 0;
  LONG r;

  if((r = strlen(name)) > size)
  {
    UBYTE buf[NAMEBUFSIZE];

    Printf("\r\033[KFilename '%s' exceeds name limit of %ld by %ld, rename? (Y|\033[1mN\033[0m|Q): ", name, size, r-size);

    Flush(Output());
    SetMode(Input(), TRUE);
    r = FGetC(Input());
    SetMode(Input(), FALSE);
    switch(r)
    {
    case 'q': case 'Q': ret = 1; break;
    case 'y': case 'Y':
      Printf("\r\033[KEnter new name for '%s':", name);
      Flush(Output());
      FGets(Input(), buf, NAMEBUFSIZE-1); /* 1 byte less to correct bug before V39 */
      r = strlen(buf);
      if(buf[r-1] == '\n') /* skip return character */
        buf[--r] = 0;
      Printf("\033[1F\033[K"); /* go up one line and clear it */
      if(!(ret = CheckNameSize(buf, size)))
      {
        for(r = 0; buf[r]; ++r)
          *(name++) = buf[r];
        *name = 0;
      }
      break;
    }
  }
  return ret;
}

void CalcPercent(ULONG cr, ULONG ucr, ULONG *p1, ULONG *p2)
{
  ULONG i = 0, j = 0;

  if(cr < ucr)
  {
    if(cr > (0xFFFFFFFF/1000))
      i = 1000 - cr / (ucr / 1000);
    else
      i = 1000 - (1000 * cr) / ucr;
    j = i % 10;
    i /= 10;
  }
  *p1 = i;
  *p2 = j;
}

#ifndef MULTIFILE
/* would be better to store the pattern parse stuff and do it only once,
but so it is a lot easier */
LONG CheckName(STRPTR *pat, STRPTR name)
{
  UBYTE buf[PATBUFSIZE];
  while(*pat)
  {
    if(ParsePatternNoCase(*(pat++), buf, PATBUFSIZE) >= 0)
    {
      if(MatchPatternNoCase(buf, name))
        return 1;
    } /* A scan failure means no recognition, should be an error print here */
  }
  return 0;
}
#else
STRPTR *GetNames(STRPTR *names)
{
  struct AnchorPath *APath;
  STRPTR *result = 0, s, f, *r;
  ULONG *filelist, *fl = 0, *a, *b, retval = 0, namesize = 0;
  LONG i;

  if((APath = (struct AnchorPath *) AllocMem(sizeof(struct AnchorPath)+512, MEMF_PUBLIC|MEMF_CLEAR)))
  {
    APath->ap_BreakBits = SIGBREAKF_CTRL_C;
    APath->ap_Strlen = 512;

    while(*names && !retval)
    {
      filelist = 0;
      for(retval = MatchFirst(*names, APath); !retval; retval = MatchNext(APath))
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
        retval = 0;
      ++names;
    }

    if(!retval)
    {
      i = 0;
      for(b = fl; b; b = (ULONG *) *b)
        ++i;
      if((result = (STRPTR *)AllocVec((i+1)*sizeof(STRPTR)+namesize, MEMF_ANY)))
      {
        s = ((STRPTR) result)+((i+1)*sizeof(STRPTR));
        i = 0;
        for(b = fl; b; b = (ULONG *) *b)
        {
          result[i++] = s;
          for(f = (STRPTR) (b+1); *f; ++f)
            *(s++) = *f;
          *(s++) = 0;
        }
        result[i] = 0;
      }
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
    Printf("Loading files in following order: ");

    for(r = result; *r; ++r)
      Printf("%s%s", *r, r[1] ? ", " : "\n");
  }

  return result;
}
#endif
