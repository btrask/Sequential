#define NAME         "xadUnTar"
#define DISTRIBUTION "(LGPL) "
#define REVISION     "8"
#define DATE         "04.02.2005"

/*  $Id: xadUnTar.c,v 1.5 2006/02/15 17:52:35 stoecker Exp $
    xadUnTar - dearchives tar archives (also gzipped, bzipped, compressed)

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

struct xadMasterBase *  xadMasterBase = 0;
struct DosLibrary *     DOSBase = 0;
struct ExecBase *       SysBase = 0;

#define MINPRINTSIZE    51200   /* 50KB */
#define NAMEBUFSIZE     512
#define PATBUFSIZE      (NAMEBUFSIZE*2+10)

#define PARAM \
  "FROM/A,DEST=DESTDIR,PASSWORD/K,FILE/M,"      \
  "NAMESIZE/K/N,FFS=OFS/S,SFS/S,"               \
  "INFO=LIST/S,Q=QUIET/S,AM=ASKMAKEDIR/S,"      \
  "OW=OVERWRITE/S,NA=NOABS/S,ND=NODATE/S,"      \
  "NE=NOEXTERN/S,NKP=NOKILLPART/S,NP=NOPROT/S," \
  "NT=NOTREE/S,SHORTNAME/S,NOPAXHEADER/S"

#define OPTIONS \
  "FROM        The input archive file (no patterns allowed)\n"          \
  "DESTDIR     The destination directory, not needed with INFO\n"       \
  "PASSWORD    A password for encrypted archives\n"                     \
  "FILE        Filename(s) (with patterns) to be extracted\n"           \
  "NAMESIZE    Names with more characters result in rename request\n"   \
  "FFS=OFS     Sets NAMESIZE to 30\n"                                   \
  "SFS         Sets NAMESIZE to 100\n"                                  \
  "INFO        Shows archive information without extracting\n"          \
  "QUIET       Turns of progress report and user interaction\n"         \
  "ASKMAKEDIR  You get asked before a directory is created\n"           \
  "OVERWRITE   Files are overwritten without asking\n"                  \
  "NOABS       Do not extract absolute path name parts\n"               \
  "NODATE      Creation date information gets not extracted\n"          \
  "NOEXTERN    Turns off usage of external clients\n"                   \
  "NOKILLPART  Do not delete partial or corrupt output files.\n"        \
  "NOPROT      Protection information gets not extracted\n"             \
  "NOTREE      Files are extracted without subdirectories\n"            \
  "SHORTNAME   Do not display path in progress report\n"                \
  "NOPAXHEADER Do not extract unhandled PaxHeader extension as file\n"

struct xHookArgs {
  STRPTR name;
  ULONG size;
  ULONG flags;
  ULONG lastprint;
  ULONG shortname;
};

struct Args {
  STRPTR   from;
  STRPTR   destdir;
  STRPTR   password;
  STRPTR * file;
  LONG *   namesize;
  ULONG    ffs;
  ULONG    sfs;
  ULONG    info;
  ULONG    quiet;
  ULONG    askmakedir;
  ULONG    overwrite;
  ULONG    noabs;
  ULONG    nodate;
  ULONG    noextern;
  ULONG    nokillpart;
  ULONG    noprot;
  ULONG    notree;
  ULONG    shortname;
  ULONG    nopaxheader;

  /* parameter, no ReadArgs part */
  ULONG    directrun;
  ULONG    printerr;
  ULONG    numextract;
};

struct TarHeader {              /* byte offset */
  UBYTE th_Name[100];           /*   0 */
  UBYTE th_Mode[8];             /* 100 */
  UBYTE th_UserID[8];           /* 108 */
  UBYTE th_GroupID[8];          /* 116 */
  UBYTE th_Size[12];            /* 124 */
  UBYTE th_MTime[12];           /* 136 */
  UBYTE th_Checksum[8];         /* 148 */
  UBYTE th_Typeflag;            /* 156 */
  UBYTE th_LinkName[100];       /* 157 */
  UBYTE th_Magic[6];            /* 257 */
  UBYTE th_Version[2];          /* 263 */
  UBYTE th_UserName[32];        /* 265 */
  UBYTE th_GroupName[32];       /* 297 */
  UBYTE th_DevMajor[8];         /* 329 */
  UBYTE th_DevMinor[8];         /* 337 */
  UBYTE th_Prefix[155];         /* 345 */
  UBYTE th_Pad[12];             /* 500 */
};

struct TarBlockInfo {
  struct Args *         Args;
  struct xadArchiveInfo *ArchiveInfo;
  UBYTE                 Block[512];
  UBYTE                 LongName[512*2];
  struct TarHeader      Header;
  ULONG                 CurSize;
  ULONG                 NumFile;
  ULONG                 NumDir;
  ULONG                 NumSpecial;
  LONG                  NeedToSkip; /* bytes */
  LONG                  NeedToSave; /* bytes */
  LONG                  EndBytes;
  struct Hook           Hook;
  struct xHookArgs      HookArgs;
  UBYTE                 Filename[NAMEBUFSIZE];
  UBYTE                 EndMode;
  UBYTE                 LongLinkMode;
  UBYTE                 LongNameMode;
};

/* Values used in Typeflag field.  */
#define TF_FILE         '0'  /* Regular file */
#define TF_AFILE        '\0' /* Regular file */
#define TF_LINK         '1'  /* Link */
#define TF_SYM          '2'  /* Reserved - but GNU tar uses this for links... */
#define TF_CHAR         '3'  /* Character special */
#define TF_BLOCK        '4'  /* Block special */
#define TF_DIR          '5'  /* Drawer */
#define TF_FIFO         '6'  /* FIFO special */
#define TF_CONT         '7'  /* Reserved */
#define TF_LONGNAME     'L'  /* longname block, preceedes the full block */
#define TF_LONGLINK     'K'  /* longlink block, preceedes the full block */
#define TF_EXTENSION    'x'  /* XXX */

ASM(ULONG SAVEDS) progrhook(REG(a0, struct Hook *), REG(a1, struct xadProgressInfo *));
ASM(ULONG SAVEDS) workhook(REG(a0, struct Hook *), REG(a1, struct xadHookParam *));
static ULONG octtonum(STRPTR oct, LONG width, LONG *ok);
static BOOL checktarsum(struct TarHeader *th);
static LONG handleblock(struct TarBlockInfo *t);
static void ShowProt(ULONG i);
static LONG CheckNameSize(STRPTR name, ULONG size);
static LONG CheckName(STRPTR *pat, STRPTR name);

ULONG SAVEDS start(void)
{
  ULONG ret = RETURN_FAIL;
  struct DosLibrary *dosbase;

  SysBase = (*((struct ExecBase **) 4));
  { /* test for WB and reply startup-message */
    struct Process *task = (struct Process *) FindTask(0);
    if(!task->pr_CLI)
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
    OpenLibrary("xadmaster.library", 9)))
    {
      struct Args args;
      struct RDArgs *rda;
      
      memset(&args, 0, sizeof(struct Args));
      xadMasterBase = xadmasterbase;

      if((rda = (struct RDArgs *) AllocDosObject(DOS_RDARGS, 0)))
      {
        rda->RDA_ExtHelp = OPTIONS;

        if(ReadArgs(PARAM, (LONG *) &args, rda))
        {
          LONG namesize = 0;

          if(args.namesize && *args.namesize > 0)
            namesize = *args.namesize;
          else if(args.ffs)
            namesize = 30;
          else if(args.sfs)
            namesize = 100;
          args.namesize = &namesize;

          if(args.destdir || args.info)
          {
            struct xadArchiveInfo *ai;

            if((ai = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
            {
              struct Hook outhook;
              struct xadFileInfo *fi;

              memset(&outhook, 0, sizeof(struct Hook));
              outhook.h_Entry = (ULONG (*)()) workhook;
              outhook.h_Data = &args;

              args.directrun = 1;
              /* Try as normal archive (plain tar). */
              if(!(err = xadGetHookAccess(ai, XAD_OUTHOOK, &outhook, XAD_INFILENAME, args.from, TAG_DONE)))
              {
                err = xadHookAccess(XADAC_COPY, ai->xai_InSize, 0, ai);
                xadFreeHookAccess(ai, err ? XAD_WASERROR : TAG_DONE, err, TAG_DONE);
              }

              if(!args.numextract && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
              {
                args.directrun = 0;
                if(!(err = xadGetInfo(ai, XAD_INFILENAME, args.from, XAD_NOEXTERN, args.noextern,
                args.password ? XAD_PASSWORD : TAG_IGNORE, args.password, TAG_DONE)))
                {
                  fi = ai->xai_FileInfo;

                  if(fi && ai->xai_Client->xc_Identifier != XADCID_TAR)
                    err = xadFileUnArc(ai, XAD_OUTHOOK, &outhook, XAD_ENTRYNUMBER, fi->xfi_EntryNumber, TAG_DONE);
                  xadFreeInfo(ai);
                }
              }

              if(!args.numextract)
                ret = RETURN_FAIL;
              else if(err)
                ret = RETURN_ERROR;
              else
                ret = 0;

              xadFreeObjectA(ai, 0);
            } /* xadAllocObject */
          }
          else
            SetIoErr(ERROR_REQUIRED_ARG_MISSING);

          FreeArgs(rda);
        } /* ReadArgs */
        FreeDosObject(DOS_RDARGS, rda);
      } /* AllocDosObject */

      if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
        SetIoErr(ERROR_BREAK);

      if(!args.quiet)
      {
        if(err && !args.printerr)
          Printf("\r\033[KAn error occured: %s\n", xadGetErrorText(err));
        else if(ret)
          PrintFault(IoErr(), 0);
      }

      CloseLibrary((struct Library *) xadmasterbase);
    } /* OpenLibrary xadmaster */
    else
      Printf("Could not open xadmaster.library\n");
    CloseLibrary((struct Library *) dosbase);
  } /* OpenLibrary dos */
  return ret;
}

static ULONG octtonum(STRPTR oct, LONG width, LONG *ok)
{
  ULONG i = 0;

  while(*oct == ' ' && width--)
    ++oct;

  if(!*oct)
    *ok = 0;
  else
  {
    while(width-- && *oct >= '0' && *oct <= '7')
     i = (i*8)+*(oct++)-'0';

    while(*oct == ' ' && width--)
      ++oct;

    if(width > 0 && *oct)       /* an error, set error flag */
      *ok = 0;
  }

  return i;
}

static BOOL checktarsum(struct TarHeader *th)
{
  LONG sc, i;
  ULONG uc, checks;
  
  i = 1;
  checks = octtonum(th->th_Checksum, 8, &i);
  if(!i)
    return 0;

  for(i = sc = uc = 0; i < 512; ++i)
  {
    sc += ((BYTE *) th)[i];
    uc += ((UBYTE *) th)[i];
  }
  
  for(i = 148; i < 156; ++i)
  {
    sc -= ((BYTE *) th)[i];
    uc -= ((UBYTE *) th)[i];
  }
  sc += 8 * ' ';
  uc += 8 * ' ';
  
  if(checks != uc && checks != (ULONG) sc)
    return 0;
  return 1;
}

static void FinishFile(struct TarBlockInfo *t)
{
  struct DateStamp d;
  LONG a, ok;

  if(!t->Args->nodate)
  {
    xadConvertDates(XAD_DATEUNIX, octtonum(t->Header.th_MTime, 12, &ok),
    XAD_MAKELOCALDATE, 1, XAD_GETDATEDATESTAMP, &d, TAG_DONE);
    SetFileDate(t->Filename, &d);
  }
  if(!t->Args->noprot)
  {
    xadConvertProtection(XAD_PROTUNIX, octtonum(t->Header.th_Mode, 8, &ok),
    XAD_GETPROTAMIGA, &a, TAG_DONE);
    SetProtection(t->Filename, a);
  }
}

static LONG handleblock(struct TarBlockInfo *t)
{
  LONG err = 0;

  if(t->CurSize != 512)
  {
    if(t->EndMode)
      t->EndBytes += t->CurSize;
    if(t->ArchiveInfo)
    {
      xadFreeHookAccess(t->ArchiveInfo, XAD_WASERROR, XADERR_INPUT, TAG_DONE);
      xadFreeObjectA(t->ArchiveInfo, 0);
      t->ArchiveInfo = 0;
    }
    if(!t->Args->info && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
    {
      if(!t->Args->directrun || t->NumFile || t->NumDir)
      {
        Printf("Processed");
        if(t->NumFile)
          Printf(" %ld file%s%s", t->NumFile, t->NumFile == 1 ? "" : "s", t->NumDir ? " and" : "");
        if(t->NumDir)
          Printf(" %ld director%s", t->NumDir, t->NumDir == 1 ? "y" : "ies");
        if(!t->NumFile && !t->NumDir)
          Printf(" nothing");
        Printf(".\n");
        if(t->EndBytes)
          Printf("There are %ld additional tar-bytes at fileend.\n", t->EndBytes);
      }
    }
  }
  else if(t->NeedToSkip)
  {
    if(t->NeedToSkip > 512)
      t->NeedToSkip -= 512;
    else
      t->NeedToSkip = 0;
  }
  else if(t->NeedToSave)
  {
    if(t->LongNameMode)
    {
      if(t->LongNameMode == 1)
        CopyMem(t->Block, t->LongName, 512);
      else if(t->LongNameMode == 2)
      {
        CopyMem(t->Block, t->LongName+512, 511);
      }
      ++t->LongNameMode;
      if(t->NeedToSave > 512)
        t->NeedToSave -= 512;
      else
        t->NeedToSave = 0;
    }
    else if(t->NeedToSave > 512)
    {
      t->NeedToSave -= 512;
      if((err = xadHookAccess(XADAC_WRITE, 512, t->Block, t->ArchiveInfo)))
      {
        xadFreeHookAccess(t->ArchiveInfo, XAD_WASERROR, err, TAG_DONE);
        xadFreeObjectA(t->ArchiveInfo, 0);
        t->NeedToSkip = t->NeedToSave;
        t->NeedToSave = 0;
        t->ArchiveInfo = 0;
      }
    }
    else
    {
      err = xadHookAccess(XADAC_WRITE, t->NeedToSave, t->Block, t->ArchiveInfo);
      xadFreeHookAccess(t->ArchiveInfo, err ? XAD_WASERROR : TAG_DONE, err, TAG_DONE);
      xadFreeObjectA(t->ArchiveInfo, 0);
      t->NeedToSave = 0;
      t->ArchiveInfo = 0;
      if(!err)
        FinishFile(t);
    }
  }
  else if(t->EndMode)
  {
    t->EndBytes += 512;
  }
  else /* a file header block */
  {
    xadCopyMem(t->Block, &t->Header, 512);

    if(t->Header.th_Name[0])
    {
      LONG ok, a;
      STRPTR name;

      t->HookArgs.lastprint = 0;
      t->HookArgs.shortname = t->Args->shortname;
      ok = checktarsum(&t->Header); /* check checksum and init ok */
      t->HookArgs.size = octtonum(t->Header.th_Size, 12, &ok);

      if(ok && (t->Header.th_Typeflag == TF_LONGLINK))
      {
        t->LongLinkMode = 1;
        t->NeedToSkip = t->HookArgs.size;
      }
      else if(ok && (t->Header.th_Typeflag == TF_LONGNAME))
      {
        t->LongNameMode = 1;
        t->NeedToSave = t->HookArgs.size;
      }
      else if(ok && (t->Header.th_Typeflag == TF_FILE || t->Header.th_Typeflag == TF_AFILE ||
      t->Header.th_Typeflag == TF_EXTENSION ||
      t->Header.th_Typeflag == TF_DIR || t->Header.th_Typeflag == TF_SYM || t->Header.th_Typeflag == TF_LINK
      || t->Header.th_Typeflag == TF_CHAR || t->Header.th_Typeflag == TF_BLOCK || t->Header.th_Typeflag == TF_FIFO))
      {
        if(!t->LongNameMode && t->Header.th_Prefix[0])
        {
          STRPTR s, u;

          name = u = t->LongName; s = t->Header.th_Prefix;
          while(*s)
            *(u++) = *(s++);
          if(*(u-1) != '/')
            *(u++) = '/';
          s = t->Header.th_Name;
          while(*s)
            *(u++) = *(s++);
          if(*(u-1) == '/')
            --u;
          *u = 0;
        }
        else
        {
          name = t->LongNameMode ? t->LongName : t->Header.th_Name;
          t->LongNameMode = 0;
        }
        a = strlen(name) + 1;
        if(name[a-2] == '/')
        {
          if(t->Header.th_Typeflag == TF_AFILE || t->Header.th_Typeflag == TF_FILE || t->Header.th_Typeflag == TF_DIR)
          {
            name[--a-1] = 0;
            t->Header.th_Typeflag = TF_DIR;
          }
        }
        if(t->Args->notree)
          name = FilePart(name);
        if(t->Args->noabs)
        {
          STRPTR f;
          while(*name == '/' || *name == ':')
            ++name;

          for(f = name; *f; ++f)
            *f = (*f == ':') ? '/' : *f;
        }
        ++t->Args->numextract;
        if(t->Args->info)
        {
          struct xadDate xd;

          xadConvertDates(XAD_DATEUNIX, octtonum(t->Header.th_MTime, 12, &ok),
          XAD_MAKELOCALDATE, 1, XAD_GETDATEXADDATE, &xd, TAG_DONE);
          xadConvertProtection(XAD_PROTUNIX, octtonum(t->Header.th_Mode, 8, &ok), XAD_GETPROTAMIGA, &a, TAG_DONE);

          if(!(t->NumFile + t->NumDir + t->NumSpecial))
            Printf("Size     Date       Time     Protection       Name\n");

          if(t->Header.th_Typeflag == TF_DIR)
          {
            Printf("   <dir>");
            ++t->NumDir;
          }
          else if(t->Header.th_Typeflag == TF_SYM || t->Header.th_Typeflag == TF_LINK)
          {
            Printf("  <link>");
            ++t->NumSpecial;
          }
          else if(t->Header.th_Typeflag == TF_CHAR || t->Header.th_Typeflag == TF_BLOCK)
          {
            Printf("   <dev>");
            ++t->NumSpecial;
          }
          else if(t->Header.th_Typeflag == TF_FIFO)
          {
            Printf("  <pipe>");
            ++t->NumSpecial;
          }
          else
          {
            if(t->Header.th_Typeflag == TF_EXTENSION)
              Printf("   <ext>");
            else
              Printf("%8ld", t->HookArgs.size);
            t->NeedToSkip = t->HookArgs.size;
            ++t->NumFile;
          }
          Printf(" %02ld.%02ld.%04ld %02ld:%02ld:%02ld ", xd.xd_Day, xd.xd_Month, xd.xd_Year,
          xd.xd_Hour, xd.xd_Minute, xd.xd_Second);
          ShowProt(a);

          Printf("%s\n", t->Args->shortname ? FilePart(name): name);
          if(t->Header.th_LinkName[0])
            Printf("link: %s%s\n", t->Header.th_LinkName, t->LongLinkMode ? "..." : "");
        }
        else
        {
          if(!t->Args->file || CheckName(t->Args->file, name))
          {
            CopyMem(t->Args->destdir, t->Filename, strlen(t->Args->destdir)+1);
            AddPart(t->Filename, name, NAMEBUFSIZE);
            if(t->Header.th_Typeflag == TF_SYM || t->Header.th_Typeflag == TF_LINK)
            {
              if(!t->Args->quiet)
              Printf("Skipped Link\n");
              ++t->NumSpecial;
            }
            else if(t->Header.th_Typeflag == TF_CHAR || t->Header.th_Typeflag == TF_BLOCK)
            {
              if(!t->Args->quiet)
              Printf("Skipped Device\n");
              ++t->NumSpecial;
            }
            else if(t->Header.th_Typeflag == TF_FIFO)
            {
              if(!t->Args->quiet)
              Printf("Skipped Pipe\n");
              ++t->NumSpecial;
            }
            else if(t->Header.th_Typeflag == TF_DIR)
            {
              if(!t->Args->notree)
              {
                BPTR a;
                LONG i = 0;
                UBYTE r;
                ++t->NumDir;
                while(t->Filename[i] && !err)
                {
                  for(;t->Filename[i] && t->Filename[i] != '/'; ++i)
                    ;
                  r = t->Filename[i];
                  t->Filename[i] = 0;
                  if((a = Lock(t->Filename, SHARED_LOCK)))
                    UnLock(a);
                  else if((a = CreateDir(t->Filename)))
                    UnLock(a);
                  else
                    err = 1;
                  t->Filename[i++] = r;
                }
                if(!t->Args->quiet)
                {
                  if(err)
                    Printf("failed to create directory '%s'\n", t->Args->shortname ? FilePart(t->Filename) : t->Filename);
                  else
                    Printf("Created directory   : %s\n", t->Args->shortname ? FilePart(t->Filename) : t->Filename);
                }
                if(!err)
                {
                  struct DateStamp d;
                  LONG a;

                  if(!t->Args->nodate)
                  {
                    xadConvertDates(XAD_DATEUNIX, octtonum(t->Header.th_MTime, 12, &ok),
                    XAD_MAKELOCALDATE, 1, XAD_GETDATEDATESTAMP, &d, TAG_DONE);
                    SetFileDate(t->Filename, &d);
                  }
                  if(!t->Args->noprot)
                  {
                    xadConvertProtection(XAD_PROTUNIX, octtonum(t->Header.th_Mode, 8, &ok),
                    XAD_GETPROTAMIGA, &a, TAG_DONE);
                    SetProtection(t->Filename, a);
                  }
                }
              }
            }
            else if(t->Header.th_Typeflag == TF_EXTENSION && t->Args->nopaxheader)
            {
              if(!t->Args->quiet)
              Printf("Skipped PaxHeader\n");
              t->NeedToSkip = t->HookArgs.size;
              ++t->NumFile;
            }
            else
            {
              t->NeedToSave = t->HookArgs.size;
              ++t->NumFile;
              if(*t->Args->namesize && CheckNameSize(FilePart(t->Filename), *t->Args->namesize))
                err = XADERR_BREAK;
              else if((t->ArchiveInfo = xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
              {
                if((err = xadGetHookAccess(t->ArchiveInfo, XAD_OUTFILENAME, t->Filename,
                XAD_MAKEDIRECTORY, !t->Args->askmakedir, XAD_OVERWRITE, t->Args->overwrite,
                XAD_NOKILLPARTIAL, t->Args->nokillpart,  t->Args->quiet ? TAG_IGNORE :
                XAD_PROGRESSHOOK, &t->Hook, TAG_DONE)))
                {
                  LONG r;

                  xadFreeObjectA(t->ArchiveInfo, 0);
                  t->ArchiveInfo = 0;

                  if(err == XADERR_SKIP)
                    err = 0;
                  else
                  {
                    Printf("An error occured. Continue? (\033[1mY\033[0m|N): ");
                    Flush(Output());
                    SetMode(Input(), TRUE);
                    r = FGetC(Input());
                    SetMode(Input(), FALSE);
                    switch(r)
                    {
                    case 'n': case 'N': case 'q': case 'Q': break;
                    default: err = 0;
                    }
                  }

                  if(!err)
                  {
                    t->NeedToSkip = t->NeedToSave;
                    t->NeedToSave = 0;
                  }
                }
                else if(!t->NeedToSave)
                {
                  xadFreeHookAccess(t->ArchiveInfo, TAG_DONE);
                  xadFreeObjectA(t->ArchiveInfo, 0);
                  t->ArchiveInfo = 0;
                  FinishFile(t);
                }
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
          else if(t->Header.th_Typeflag == TF_AFILE || t->Header.th_Typeflag == TF_FILE)
            t->NeedToSkip = t->HookArgs.size;
        }
        t->LongLinkMode = 0;
      }
      else
      {
        if(!(t->NumFile + t->NumDir))
        {
          if(!t->Args->directrun)
          {
            Printf("This is no Tar file.\n");
            t->Args->printerr = 1;
          }
        }
        err = XADERR_ILLEGALDATA;
      }
    }
    else
      t->EndMode = 1;
  }

  return err;
}

/* Because of SAS-err, this cannot be SAVEDS */
ASM(ULONG SAVEDS) workhook(REG(a0, struct Hook *hook),
REG(a1, struct xadHookParam *hp))
{
  ULONG err = 0;
  /* This hook gets the data and instead of saving, it calls the handleblock()
  function with 512 byte blocks (tar block size). It is an XAD output hook and
  used by the main routine as output. The hook structure contains an pointer
  to the argument information. output seeking is not supported. */

  switch(hp->xhp_Command)
  {
  case XADHC_WRITE:
    {
      ULONG i, j, k = 0;
      struct TarBlockInfo *t = (struct TarBlockInfo *) hp->xhp_PrivatePtr;

      for(j = hp->xhp_BufferSize; j && !err; j -= i)
      {
        if((i = 512-t->CurSize) > j)
          i = j;
        xadCopyMem(((STRPTR)hp->xhp_BufferPtr)+k, t->Block+t->CurSize, i);
        k += i; t->CurSize += i;
        if(t->CurSize == 512)
        {
          err = handleblock(t);
          t->CurSize = 0;
        }
      }
      hp->xhp_DataPos += hp->xhp_BufferSize;
    }
    break;
  case XADHC_INIT:
    if(!(hp->xhp_PrivatePtr = xadAllocVec(sizeof(struct TarBlockInfo), MEMF_CLEAR)))
      err = XADERR_NOMEMORY;
    else
    {
      struct TarBlockInfo *t = (struct TarBlockInfo *) hp->xhp_PrivatePtr;

      t->Args = (struct Args *) hook->h_Data;
      t->Hook.h_Entry = (ULONG (*)()) progrhook;
      t->Hook.h_Data = &t->HookArgs;
      t->HookArgs.name = t->Filename;
    }
    break;
  case XADHC_FREE:
    if(hp->xhp_PrivatePtr)
    {
      handleblock((struct TarBlockInfo *) hp->xhp_PrivatePtr); /* cleanup call */
      xadFreeObjectA(hp->xhp_PrivatePtr, 0);
      hp->xhp_PrivatePtr = 0;
    }
    /* break; */
  case XADHC_ABORT: /* do nothing */
    break;
  default: err = XADERR_NOTSUPPORTED;
  }

  if(!err && ((SetSignal(0L,0L) & SIGBREAKF_CTRL_C)))
    err = XADERR_BREAK;

  return err;
}

ASM(ULONG SAVEDS) progrhook(REG(a0, struct Hook *hook),
REG(a1, struct xadProgressInfo *pi))
{
  ULONG ret = 0;
  struct xHookArgs *h;
  STRPTR name;
  
  h = (struct xHookArgs *) (hook->h_Data);
  name = h->name;

  switch(pi->xpi_Mode)
  {
  case XADPMODE_ASK:
    ret |= ((struct xHookArgs *) (hook->h_Data))->flags;
    if((pi->xpi_Status & XADPIF_OVERWRITE) && !(ret & (XADPIF_OVERWRITE|XADPIF_SKIP)))
    {
      LONG r;

      Printf("\r\033[KFile '%s' already exists, overwrite? (Y|A|S|\033[1mN\033[0m|Q|R): ",
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
      default:
      case 's': case 'S': ((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_SKIP;
      case 'n': case 'N':
        ret |= XADPIF_SKIP; break;
      case 'q': case 'Q': SetSignal(SIGBREAKF_CTRL_C, SIGBREAKF_CTRL_C); break;
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
      case 'q': case 'Q': SetSignal(SIGBREAKF_CTRL_C, SIGBREAKF_CTRL_C); break;
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
      Printf("\r\033[KDirectory of file '%s' does not exist, create? (Y|A|S|\033[1mN\033[0m|Q): ",
      name);
      Flush(Output());
      SetMode(Input(), TRUE);
      switch(FGetC(Input()))
      {
      case 'a': case 'A':
        ((struct xHookArgs *) (hook->h_Data))->flags |= XADPIF_MAKEDIRECTORY;
      case 'y': case 'Y': ret |= XADPIF_MAKEDIRECTORY; break;
      case 'q': case 'Q': SetSignal(SIGBREAKF_CTRL_C, SIGBREAKF_CTRL_C); break;
      default:
      /*case 's': case 'S': case 'n': case 'N':*/ ret |= XADPIF_SKIP; break;
      }
      SetMode(Input(), FALSE);
    }
    break;
  case XADPMODE_PROGRESS:
    if(pi->xpi_CurrentSize - ((struct xHookArgs *) (hook->h_Data))->lastprint >= MINPRINTSIZE)
    {
      Printf("\r\033[KWrote %8ld of %8ld bytes: %s",
      pi->xpi_CurrentSize, ((struct xHookArgs *) (hook->h_Data))->size, h->shortname ? FilePart(name) : name);
      Flush(Output());
      ((struct xHookArgs *) (hook->h_Data))->lastprint = pi->xpi_CurrentSize;
    }
    break;
  case XADPMODE_END: Printf("\r\033[KWrote %8ld bytes: %s\n", pi->xpi_CurrentSize, h->shortname ? FilePart(name) : name);
    break;
  case XADPMODE_ERROR: Printf("\r\033[K%s: %s\n", h->shortname ? FilePart(name) : name, xadGetErrorText(pi->xpi_Error));
    break;
  }

  if(!(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)) /* clear ok flag */
    ret |= XADPIF_OK;

  return ret;
}

static void ShowProt(ULONG i)
{
  LONG j;
  UBYTE buf[16], *b = "rwedrwedhsparwed";
  
  for(j = 0; j <= 11; ++j)
    buf[j] = (i & (1<<(15-j))) ? b[j] : '-';
  for(; j <= 15; ++j)
    buf[j] = (i & (1<<(15-j))) ? '-' : b[j];

  Printf("%.16s ", buf);
}

static LONG CheckNameSize(STRPTR name, ULONG size)
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
    case 'q': case 'Q': SetSignal(SIGBREAKF_CTRL_C, SIGBREAKF_CTRL_C); ret = 1; break;
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

/* would be better to store the pattern parse stuff and do it only once,
but so it is a lot easier */
static LONG CheckName(STRPTR *pat, STRPTR name)
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
