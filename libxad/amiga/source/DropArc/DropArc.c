#define NAME         "DropArc"
#define VERSION      "1"
#define REVISION     "0"
#define DATE         "10.03.2002"
#define DISTRIBUTION "(LGPL) "
#define AUTHOR       "by Dirk Stöcker <soft@dstoecker.de>"

/*  $Id: DropArc.c,v 1.2 2005/06/23 15:47:24 stoecker Exp $
    creates LhA/Zip archives

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

#include <stdarg.h>
#include <string.h>

#include <clib/alib_stdio_protos.h>
#include <proto/asl.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/icon.h>
#include <proto/intuition.h>
#include <proto/locale.h>
#include <proto/wb.h>
#include <proto/xadmaster.h>
#include <workbench/startup.h>
#include "DropArc.h"

struct DosLibrary *     DOSBase = 0;
struct ExecBase *       SysBase  = 0;
struct Library *        WorkbenchBase = 0;
struct Library *        IconBase = 0;
struct IntuitionBase *  IntuitionBase = 0;
struct xadMasterBase *  xadMasterBase = 0;
struct LocaleBase *     LocaleBase = 0;

/* these 3 fields and MyTexts prevent this tool from being pure */
static struct Message * startmsg = 0;
static struct Locale *  locale = 0;
static struct Catalog * catalog = 0;

#define version "$VER: " NAME " " VERSION "." REVISION " (" DATE ") " \
                DISTRIBUTION AUTHOR

/*********************** function protos ************************************/

static void StartLocale(void);
static void EndLocale(void);
static BOOL ParsePrefs(STRPTR *tt, struct MyPrefs *prefs);
static BOOL OpenQuit(struct MyPrefs *prefs);
static void SetTexts(struct PrefsTexts *t);
static LONG MyEasyRequest(STRPTR buttons, STRPTR text, ...);
static BOOL HandleFiles(LONG num, struct WBArg *arg, struct MyPrefs *prefs);
static void ShowXADError(LONG error, STRPTR filename);
static BOOL HandleOneFile(struct xadArchiveInfo *ai, struct xadFileInfo *fi,
       struct MyPrefs *prefs);
static BOOL AddDirectory(struct xadFileInfo *fi, struct MyPrefs *prefs);

/*********************** main function **************************************/

ULONG __saveds start(void)
{
  ULONG ret = 0;
  struct Process *task;
  struct Library *lib;

  SysBase = (*((struct ExecBase **) 4));

  /* test for WB and reply startup-message */
  if(!(task = (struct Process *) FindTask(0))->pr_CLI)
  {
    WaitPort(&task->pr_MsgPort);
    startmsg = GetMsg(&task->pr_MsgPort);
  }

  if((lib = OpenLibrary("dos.library", 37)))
  {
    DOSBase = (struct DosLibrary *) lib;
    if((lib = OpenLibrary("intuition.library", 37)))
    {
      IntuitionBase = (struct IntuitionBase *) lib;
      if((lib = OpenLibrary("workbench.library", 37)))
      {
        WorkbenchBase = lib;
        if((lib = OpenLibrary("icon.library", 37)))
        {
          IconBase = lib;
          if((lib = OpenLibrary("xadmaster.library", 9)))
          {
            struct DiskObject *dob;
            BPTR dir = 0;
            STRPTR dest;

            xadMasterBase = (struct xadMasterBase *) lib;
            StartLocale();

            if(startmsg)
            {
              struct WBArg *wba = ((struct WBStartup *) startmsg)->sm_ArgList;
              dir = CurrentDir(wba->wa_Lock);
              dest = wba->wa_Name;
            }
            else
              dest = "PROGDIR:DropArc";
            if((dob = GetDiskObject(dest)))
            {
              struct MsgPort *msg;
              struct MyPrefs *prefs;
              if((prefs = AllocVec(sizeof(struct MyPrefs),
              MEMF_CLEAR|MEMF_ANY)))
              {
                prefs->DiskObject = dob;
                prefs->IconName = dest;
                SetTexts(&prefs->PrefsTexts);
                ParsePrefs((STRPTR *) dob->do_ToolTypes, prefs);
	        dob->do_Magic = 0;
	        dob->do_Version = 0;
	        dob->do_Gadget.NextGadget = 0;
                dob->do_Gadget.LeftEdge = 0;
                dob->do_Gadget.TopEdge = 0;
                dob->do_Gadget.Activation = 0;
                dob->do_Gadget.GadgetType = 0;
                ((struct Image *)(dob->do_Gadget.GadgetRender))->LeftEdge=0;
                ((struct Image *)(dob->do_Gadget.GadgetRender))->TopEdge=0;
                ((struct Image *)(dob->do_Gadget.GadgetRender))->PlaneOnOff=0;
                ((struct Image *)(dob->do_Gadget.GadgetRender))->NextImage=0;
                if(dob->do_Gadget.SelectRender)
                {
                  ((struct Image *)(dob->do_Gadget.SelectRender))->LeftEdge=0;
                  ((struct Image *)(dob->do_Gadget.SelectRender))->TopEdge=0;
                  ((struct Image *)(dob->do_Gadget.SelectRender))->
                  PlaneOnOff = 0;
                  ((struct Image *)(dob->do_Gadget.SelectRender))->
                  NextImage = 0;
                }
                dob->do_Gadget.GadgetText = 0;
                dob->do_Gadget.MutualExclude = 0;
                dob->do_Gadget.SpecialInfo = 0;
                dob->do_Gadget.GadgetID = 0;
                dob->do_Gadget.UserData = 0;
                dob->do_Type = 0;
                dob->do_DefaultTool = 0;
                dob->do_ToolTypes = 0;
                dob->do_CurrentX = prefs->XPosition < 0 ? NO_ICON_POSITION
                : prefs->XPosition;
                dob->do_CurrentY = prefs->YPosition < 0 ? NO_ICON_POSITION
                : prefs->YPosition;
                dob->do_DrawerData = 0;
                dob->do_ToolWindow = 0;
                dob->do_StackSize = 0;

                /* assignment removed by optimizer (but not text) */
                ret = (ULONG) (version);
                ret = RETURN_FAIL;
                if((msg = CreateMsgPort()))
                {
                  struct AppIcon *app;

                  /* lots of V44 stuff ignored on older systems */
                  if((app = AddAppIcon(0x41505001, 0x41505001, prefs->Name,
                  msg, 0, dob,
                  WBAPPICONA_SupportsSnapshot, TRUE,
                  WBAPPICONA_SupportsUnSnapshot, TRUE,
                  WBAPPICONA_SupportsRename, TRUE,
                  WBAPPICONA_SupportsInformation, TRUE,
                  WBAPPICONA_SupportsDelete, TRUE,
                  WBAPPICONA_PropagatePosition, TRUE,
                  TAG_DONE)))
                  {
                    ULONG sigs, ignore;
                    struct AppMessage *amsg;

                    do
                    {
                      sigs = Wait(SIGBREAKF_CTRL_C|(1<<msg->mp_SigBit));
                      ignore = 0;
                      while(!(sigs & SIGBREAKF_CTRL_C) &&
                      (amsg = (struct AppMessage *) GetMsg(msg)))
                      {
                        if(amsg->am_ID == 0x41505001 && amsg->am_Type
                        == AMTYPE_APPICON && !ignore)
                        {
                          switch(amsg->am_Class)
                          {
                          case AMCLASSICON_Open:
                            if(!amsg->am_NumArgs)
                            {
                              sigs |= OpenQuit(prefs) ? SIGBREAKF_CTRL_C : 0;
                              ignore = 1;
                            }
                            else
                              HandleFiles(amsg->am_NumArgs, amsg->am_ArgList,
                              prefs);
                            break;
                          case AMCLASSICON_Rename:
                          case AMCLASSICON_Information:
                            OpenPrefs(prefs); ignore = 1; break;
                          case AMCLASSICON_Snapshot:
                            prefs->XPosition = dob->do_CurrentX
                            == NO_ICON_POSITION ? -1 : dob->do_CurrentX;
                            prefs->YPosition = dob->do_CurrentY
                            == NO_ICON_POSITION ? -1 : dob->do_CurrentY;
                            break;
                          case AMCLASSICON_UnSnapshot:
                            prefs->XPosition = prefs->YPosition = -1; break;
                          case AMCLASSICON_Delete: sigs |= SIGBREAKF_CTRL_C;
                            break;
                          }
                        }
                        ReplyMsg((struct Message *) amsg);
                      }
                    } while(!(sigs & SIGBREAKF_CTRL_C)); 
                    RemoveAppIcon(app);
                  }
                  else ShowError(TXT("Could not create AppIcon."));

                  ret = 0;
                  DeleteMsgPort(msg);
                }
                else ShowError(TXT("Could not create Message-Port."));
                FreeVec(prefs);
              }
              else
                ShowError(TXT("Could not allocate preferences structure."));
              FreeDiskObject(dob);
            }
            else ShowError(TXT("Could not get Icon."));
            if(startmsg)
            {
              CurrentDir(dir);
            }
            EndLocale();
            CloseLibrary((struct Library *) xadMasterBase);
          }
          else ShowError(TXT("Could not open %s version %ld."),
          "xadmaster.library", 9);
          CloseLibrary(IconBase);
        }
        else ShowError(TXT("Could not open %s version %ld."),
        "icon.library", 37);
        CloseLibrary(WorkbenchBase);
      }
      else ShowError(TXT("Could not open %s version %ld."),
      "workbench.library", 37);
      CloseLibrary((struct Library *) IntuitionBase);
    }
    else ShowError(TXT("Could not open %s version %ld."),
    "intuition.library", 37);
    CloseLibrary((struct Library *) DOSBase);
  }
  if(startmsg)
  {
    Forbid();
    ReplyMsg(startmsg);
  }

  return ret;
}

/*********************** stdio functions ************************************/

void my_strncpy(STRPTR dbuf, STRPTR sbuf, LONG size)
{
  if(size)
  {
    while(--size && *sbuf)
      *(dbuf++) = *(sbuf++);
    *dbuf = '\0';
  }
}

struct mysprintf {
  STRPTR str;
  LONG   size;
  LONG   len;
};

#include "SDI_compiler.h"

ASM(static void) putfunc(REG(d0, UBYTE data), REG(a3, struct mysprintf *a))
{
  if(a->size)
  {
    if(a->size > 1)
      *(a->str++) = data;
    else
      *(a->str++) = '\0';
    ++a->len;
    --a->size;
  }
}

static int my_snprintf(STRPTR buf, LONG size, STRPTR format, ...)
{
  if(size)
  {
    struct mysprintf d;

    d.size = size;
    d.len = 0;
    d.str = buf;
    RawDoFmt(format, (APTR) ((ULONG)&format+sizeof(STRPTR)),
    (void(*)()) putfunc, &d);
    return (d.len-1);
  }
  return -1;
}

/*********************** other functions ************************************/

static void StartLocale(void)
{
  struct Library *lib;

  if((lib = OpenLibrary("locale.library", 38)))
  {
    LocaleBase = (struct LocaleBase *) lib;

    if((locale = OpenLocale(0)))
    {
      if((catalog = OpenCatalogA(locale, "DropArc.catalog", 0)))
      {
        LONG i;
        for(i = 0; i < MaxNumMyTexts; ++i)
        {
          if(MyTexts[i])
            MyTexts[i] = GetCatalogStr(catalog, i, MyTexts[i]);
        }
      }
    }
  }
}

static void EndLocale(void)
{
  if(catalog)
    CloseCatalog(catalog);
  if(locale)
    CloseLocale(locale);
  if(LocaleBase)
    CloseLibrary((struct Library *) LocaleBase);
}

void ShowError(STRPTR text, ...)
{
  va_list arg;
  
  va_start(arg, text);
  if(IntuitionBase)
  {
    struct EasyStruct easystruct;

    easystruct.es_StructSize = sizeof(struct EasyStruct);
    easystruct.es_Flags = 0;
    easystruct.es_Title = TXT("DropArc requester");
    easystruct.es_TextFormat = text;
    easystruct.es_GadgetFormat = TXT("OK");
    EasyRequestArgs(0, &easystruct, 0, arg);
  }
  else
  {
    VPrintf(text, arg);
    Printf("\n");
  }
  va_end(arg);
}

static void ShowXADError(LONG error, STRPTR filename)
{
  struct EasyStruct easystruct;

  easystruct.es_StructSize = sizeof(struct EasyStruct);
  easystruct.es_Flags = 0;
  easystruct.es_Title = TXT("DropArc requester");
  easystruct.es_TextFormat = TXT("An XAD error occured with file %s:\n%s");
  easystruct.es_GadgetFormat = TXT("OK");
  EasyRequest(0, &easystruct, 0, filename, xadGetErrorText(error));
}

static LONG MyEasyRequest(STRPTR buttons, STRPTR text, ...)
{
  struct EasyStruct easystruct;
  LONG r;
  va_list arg;

  va_start(arg, text);

  easystruct.es_StructSize = sizeof(struct EasyStruct);
  easystruct.es_Flags = 0;
  easystruct.es_Title = TXT("DropArc requester");
  easystruct.es_TextFormat = text;
  easystruct.es_GadgetFormat = buttons;
  r = EasyRequestArgs(0, &easystruct, 0, arg);

  va_end(arg);

  return r;
}

static BOOL ParsePrefs(STRPTR *tt, struct MyPrefs *prefs)
{
  STRPTR t;
  /* defaults */
  prefs->XPosition = prefs->YPosition = -1;
  prefs->WindowTop = prefs->WindowLeft = -1;
  my_strcpy(prefs->ArcName, "RAM:DropArc.lha");
  my_strcpy(prefs->DestinationName, "RAM:");
  my_strcpy(prefs->Name, "DropArc");
  my_strcpy(prefs->TempDir, "T:");
  prefs->ArcType = ARCTYPE_AUTODETECT;
  prefs->FileArc = ARC_ASK;
  prefs->DiskArc = ARC_ASK;
  prefs->DiskImage = ARC_ASK;
  prefs->Disk = DISK_ASK;
  prefs->SubDirs = SUBDIR_ASK;
  prefs->FileExists = FILEEXISTS_ASK;
  prefs->ArcExists = ARCEXISTS_ASK;
  prefs->AskArcName = ARCNAME_ASK;
  prefs->AskPathName = PATHNAME_ASK;
  prefs->Icons = ICONS_YES;

  if((t = FindToolType(tt, "ARCTYPE")))
  {
    if(MatchToolValue(t, "AUTODETECT"))
      prefs->ArcType = ARCTYPE_AUTODETECT;
    else if(MatchToolValue(t, "ASK"))
      prefs->ArcType = ARCTYPE_ASK;
    else if(MatchToolValue(t, "LHA"))
      prefs->ArcType = ARCTYPE_LHA;
    else if(MatchToolValue(t, "ZIP"))
      prefs->ArcType = ARCTYPE_ZIP;
    else if(MatchToolValue(t, "NONE"))
      prefs->ArcType = ARCTYPE_NONE;
  }
  if((t = FindToolType(tt, "FILEARC")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->FileArc = ARC_ASK;
    if(MatchToolValue(t, "CONTENTS"))
      prefs->FileArc = ARC_CONTENTS;
    if(MatchToolValue(t, "FILE"))
      prefs->FileArc = ARC_FILE;
    if(MatchToolValue(t, "EXTRACT"))
      prefs->FileArc = ARC_EXTRACT;
  }
  if((t = FindToolType(tt, "DISKARC")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->DiskArc = ARC_ASK;
    if(MatchToolValue(t, "CONTENTS"))
      prefs->DiskArc = ARC_CONTENTS;
    if(MatchToolValue(t, "FILE"))
      prefs->DiskArc = ARC_FILE;
    if(MatchToolValue(t, "EXTRACT"))
      prefs->DiskArc = ARC_EXTRACT;
  }
  if((t = FindToolType(tt, "DISKIMAGE")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->DiskImage = ARC_ASK;
    if(MatchToolValue(t, "CONTENTS"))
      prefs->DiskImage = ARC_CONTENTS;
    if(MatchToolValue(t, "FILE"))
      prefs->DiskImage = ARC_FILE;
    if(MatchToolValue(t, "EXTRACT"))
      prefs->DiskImage = ARC_EXTRACT;
  }
  if((t = FindToolType(tt, "DISK")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->Disk = DISK_ASK;
    if(MatchToolValue(t, "CONTENTS"))
      prefs->Disk = DISK_CONTENTS;
    if(MatchToolValue(t, "IMAGE"))
      prefs->Disk = DISK_IMAGE;
  }
  if((t = FindToolType(tt, "SUBDIRS")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->SubDirs = SUBDIR_ASK;
    if(MatchToolValue(t, "NEVER"))
      prefs->SubDirs = SUBDIR_NEVER;
    if(MatchToolValue(t, "ALWAYS"))
      prefs->SubDirs = SUBDIR_ALWAYS;
  }
  if((t = FindToolType(tt, "FILEEXISTS")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->FileExists = FILEEXISTS_ASK;
    if(MatchToolValue(t, "OVERWRITE"))
      prefs->FileExists = FILEEXISTS_OVERWRITE;
    if(MatchToolValue(t, "SKIP"))
      prefs->FileExists = FILEEXISTS_SKIP;
  }
  if((t = FindToolType(tt, "ARCEXISTS")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->ArcExists = ARCEXISTS_ASK;
    if(MatchToolValue(t, "OVERWRITE"))
      prefs->ArcExists = ARCEXISTS_OVERWRITE;
    if(MatchToolValue(t, "APPEND"))
      prefs->ArcExists = ARCEXISTS_APPEND;
  }
  if((t = FindToolType(tt, "ASKARCNAME")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->AskArcName = ARCNAME_ASK;
    if(MatchToolValue(t, "DEFAULT"))
      prefs->AskArcName = ARCNAME_DEFAULT;
    if(MatchToolValue(t, "LAST"))
      prefs->AskArcName = ARCNAME_LAST;
  }
  if((t = FindToolType(tt, "ASKPATHNAME")))
  {
    if(MatchToolValue(t, "ASK"))
      prefs->AskPathName = PATHNAME_ASK;
    if(MatchToolValue(t, "DEFAULT"))
      prefs->AskPathName = PATHNAME_DEFAULT;
    if(MatchToolValue(t, "LAST"))
      prefs->AskPathName = PATHNAME_LAST;
  }
  if((t = FindToolType(tt, "ICONS")))
  {
    if(MatchToolValue(t, "YES"))
      prefs->Icons = ICONS_YES;
    if(MatchToolValue(t, "NO"))
      prefs->Icons = ICONS_NO;
  }
  if((t = FindToolType(tt, "ICONNAME")))
    my_strcpy(prefs->Name, t);
  if((t = FindToolType(tt, "ARCNAME")))
    my_strcpy(prefs->ArcName, t);
  if((t = FindToolType(tt, "DESTINATION")))
    my_strcpy(prefs->DestinationName, t);
  if((t = FindToolType(tt, "ICONPOSITION")))
  {
    LONG i = 0;

    if(t[0] == 'N' && t[1] == 'O') {prefs->XPosition = -1; t += 2;}
    else
    {
      while(*t >= '0' && *t <= '9') i = i*10 + *(t++)-'0';
      prefs->XPosition = i;
    }
    if(*(t++))
    {
      if(t[0] == 'N' && t[1] == 'O') prefs->YPosition = -1;
      else
      {
        i = 0;
        while(*t >= '0' && *t <= '9') i = i*10 + *(t++)-'0';
        prefs->YPosition = i;
      }
    }
  }
  if((t = FindToolType(tt, "WINDOWPOSITION")))
  {
    LONG i = 0;

    if(t[0] == 'N' && t[1] == 'O') {prefs->WindowLeft = -1; t += 2;}
    else
    {
      while(*t >= '0' && *t <= '9') i = i*10 + *(t++)-'0';
      prefs->WindowLeft = i;
    }
    if(*(t++))
    {
      if(t[0] == 'N' && t[1] == 'O') prefs->WindowTop = -1;
      else
      {
        i = 0;
        while(*t >= '0' && *t <= '9') i = i*10 + *(t++)-'0';
        prefs->WindowTop = i;
      }
    }
  }
  my_strcpy(prefs->LastArcName, prefs->ArcName);
  my_strcpy(prefs->LastDestinationName, prefs->DestinationName);
  return FALSE;
}

static BOOL OpenQuit(struct MyPrefs *prefs)
{
  struct EasyStruct easystruct;
  LONG res;

  easystruct.es_StructSize = sizeof(struct EasyStruct);
  easystruct.es_Flags = 0;
  easystruct.es_Title = TXT("DropArc requester");
  easystruct.es_TextFormat = TXT("What do you want to do?");
  easystruct.es_GadgetFormat = TXT("Quit|Open Prefs|Nothing");
  res = EasyRequestArgs(0, &easystruct, 0, 0);
  switch(res)
  {
  case 1: return 1; break;
  case 2: OpenPrefs(prefs);
  /* case 0: */
  /* default: */
  }
  return 0;
}

#define MAKESIZETEXT(a, b) {my_strncpy(mem+j, a, b); j += b;}
#define MAKETEXT(a) MAKESIZETEXT(a, sizeof(a))
#define NEWENTRY(a) {tt[i++] = mem+j; MAKETEXT(a); mem[j-1] = '=';}
#define MAKENUM(a) {LONG k = a, l; if(k > 9999 || k < 0) \
        { MAKESIZETEXT("NO", 2); } else { for(l=4; l--;) \
        {mem[j+l] = '0'+k%10; k/=10;} j+=4;}}
void SavePrefs(struct MyPrefs *prefs)
{
  STRPTR mem;
  if((mem = AllocVec(512+20*sizeof(STRPTR), MEMF_PUBLIC)))
  {
    STRPTR *tt;
    struct DiskObject *dob;
    LONG i = 0, j = 0, k;

    tt = (STRPTR *) (mem+512);

    NEWENTRY("ARCTYPE");
    switch(prefs->ArcType)
    {
    case ARCTYPE_AUTODETECT: MAKETEXT("AUTODETECT"); break;
    case ARCTYPE_ASK: MAKETEXT("ASK"); break;
    case ARCTYPE_LHA: MAKETEXT("LHA"); break;
    case ARCTYPE_ZIP: MAKETEXT("ZIP"); break;
    case ARCTYPE_NONE: MAKETEXT("NONE"); break;
    }
    NEWENTRY("FILEARC");
    switch(prefs->FileArc)
    {
    case ARC_ASK: MAKETEXT("ASK"); break;
    case ARC_CONTENTS: MAKETEXT("CONTENTS"); break;
    case ARC_FILE: MAKETEXT("FILE"); break;
    case ARC_EXTRACT: MAKETEXT("EXTRACT"); break;
    }
    NEWENTRY("DISKARC");
    switch(prefs->DiskArc)
    {
    case ARC_ASK: MAKETEXT("ASK"); break;
    case ARC_CONTENTS: MAKETEXT("CONTENTS"); break;
    case ARC_FILE: MAKETEXT("FILE"); break;
    case ARC_EXTRACT: MAKETEXT("EXTRACT"); break;
    }
    NEWENTRY("DISKIMAGE");
    switch(prefs->DiskImage)
    {
    case ARC_ASK: MAKETEXT("ASK"); break;
    case ARC_CONTENTS: MAKETEXT("CONTENTS"); break;
    case ARC_FILE: MAKETEXT("FILE"); break;
    case ARC_EXTRACT: MAKETEXT("EXTRACT"); break;
    }
    NEWENTRY("DISK");
    switch(prefs->Disk)
    {
    case DISK_ASK: MAKETEXT("ASK"); break;
    case DISK_CONTENTS: MAKETEXT("CONTENTS"); break;
    case DISK_IMAGE: MAKETEXT("IMAGE"); break;
    }
    NEWENTRY("SUBDIRS");
    switch(prefs->SubDirs)
    {
    case SUBDIR_ASK: MAKETEXT("ASK"); break;
    case SUBDIR_NEVER: MAKETEXT("NEVER"); break;
    case SUBDIR_ALWAYS: MAKETEXT("ALWAYS"); break;
    }
    NEWENTRY("FILEEXISTS");
    switch(prefs->FileExists)
    {
    case FILEEXISTS_ASK: MAKETEXT("ASK"); break;
    case FILEEXISTS_OVERWRITE: MAKETEXT("OVERWRITE"); break;
    case FILEEXISTS_SKIP: MAKETEXT("SKIP"); break;
    }
    NEWENTRY("ARCEXISTS");
    switch(prefs->ArcExists)
    {
    case ARCEXISTS_ASK: MAKETEXT("ASK"); break;
    case ARCEXISTS_OVERWRITE: MAKETEXT("OVERWRITE"); break;
    case ARCEXISTS_APPEND: MAKETEXT("APPEND"); break;
    }
    NEWENTRY("ASKARCNAME");
    switch(prefs->AskArcName)
    {
    case ARCNAME_ASK: MAKETEXT("ASK"); break;
    case ARCNAME_DEFAULT: MAKETEXT("DEFAULT"); break;
    case ARCNAME_LAST: MAKETEXT("LAST"); break;
    }
    NEWENTRY("ASKPATHNAME");
    switch(prefs->AskPathName)
    {
    case PATHNAME_ASK: MAKETEXT("ASK"); break;
    case PATHNAME_DEFAULT: MAKETEXT("DEFAULT"); break;
    case PATHNAME_LAST: MAKETEXT("LAST"); break;
    }
    NEWENTRY("ICONS");
    switch(prefs->Icons)
    {
    case ICONS_YES: MAKETEXT("YES"); break;
    case ICONS_NO: MAKETEXT("NO"); break;
    }
    NEWENTRY("ICONNAME");
    k = strlen(prefs->Name)+1;
    MAKESIZETEXT(prefs->Name, k);
    NEWENTRY("ARCNAME");
    k = strlen(prefs->ArcName)+1;
    MAKESIZETEXT(prefs->ArcName, k);
    NEWENTRY("DESTINATION");
    k = strlen(prefs->DestinationName)+1;
    MAKESIZETEXT(prefs->DestinationName, k);
    NEWENTRY("ICONPOSITION");
    MAKENUM(prefs->XPosition);
    mem[j++] = ',';
    MAKENUM(prefs->YPosition);
    mem[j++] = 0;
    NEWENTRY("WINDOWPOSITION");
    MAKENUM(prefs->WindowLeft);
    mem[j++] = ',';
    MAKENUM(prefs->WindowTop);
    mem[j] = 0;
    tt[i] = 0;
    if((dob = GetDiskObject(prefs->IconName)))
    {
      dob->do_ToolTypes = tt;
      PutDiskObject(prefs->IconName, dob);
      FreeDiskObject(dob);
    }
    else ShowError(TXT("Could not open Icon for writing."));
    FreeVec(mem);
  }
  else ShowError(TXT("Not enough memory to save preferences."));
}

static void SetTexts(struct PrefsTexts *t)
{
  t->gadgtexts[0] = TXT("Icon Name");
  t->gadgtexts[1] = TXT("Archive Name");
  t->gadgtexts[2] = TXT("Destination Path");
  t->gadgtexts[3] = TXT("Archive Type");
  t->gadgtexts[4] = TXT("File Archives");
  t->gadgtexts[5] = TXT("Disk Archives");
  t->gadgtexts[6] = TXT("Disk Images");
  t->gadgtexts[7] = TXT("Disks");
  t->gadgtexts[8] = TXT("Subdirectories");
  t->gadgtexts[9] = TXT("File exists");
  t->gadgtexts[10]= TXT("Archive exists");
  t->gadgtexts[11]= TXT("Ask Archive Name");
  t->gadgtexts[12]= TXT("Ask Path Name");
  t->gadgtexts[13]= TXT("Archive Icons");
  t->gadgtexts[14]= TXT("Window Position");
  t->gadgtexts[15]= TXT("Icon Position");

  t->arctexts[0] = TXT("Ask");
  t->arctexts[1] = TXT("Archive contents");
  t->arctexts[2] = TXT("Archive file");
  t->arctexts[3] = TXT("Extract");
  t->arctexts[4] = 0;

  t->arctype[0] = TXT("Autodect by extension");
  t->arctype[1] = t->arctexts[0];
  t->arctype[2] = "LhA";
  t->arctype[3] = "Zip";
  t->arctype[4] = TXT("None");
  t->arctype[5] = 0;

  t->disks[0] = t->arctexts[0];
  t->disks[1] = t->arctexts[1];
  t->disks[2] = TXT("Archive image");
  t->disks[3] = 0;

  t->subdirs[0] = t->arctexts[0];
  t->subdirs[1] = TXT("Archive never");
  t->subdirs[2] = TXT("Archive always");
  t->subdirs[3] = 0;

  t->fileexists[0] = t->arctexts[0];
  t->fileexists[1] = TXT("Overwrite");
  t->fileexists[2] = TXT("Skip");
  t->fileexists[3] = 0;

  t->archiveexists[0] = t->arctexts[0];
  t->archiveexists[1] = t->fileexists[1];
  t->archiveexists[2] = TXT("Append");
  t->archiveexists[3] = 0;

  t->askname[0] = TXT("Ask always");
  t->askname[1] = TXT("Use default");
  t->askname[2] = TXT("Use last");
  t->askname[3] = 0;

  t->icons[0] = TXT("Yes");
  t->icons[1] = TXT("No");
  t->icons[2] = 0;

  t->buttontexts[0] = TXT("Save");
  t->buttontexts[1] = TXT("Use");
  t->buttontexts[2] = TXT("Cancel");
}

ULONG FileReq(STRPTR file, STRPTR text, ULONG size)
{
  struct Library *AslBase;
  struct FileRequester *r;
  UBYTE str[110];
  STRPTR ptr = FilePart(file);
  ULONG res = FALSE;

  if(ptr)
    CopyMem(ptr, &str, strlen(ptr)+1);
  else
    str[0] = 0;

  if((AslBase = OpenLibrary("asl.library", 39)))
  {
    if((r = (struct FileRequester *) AllocAslRequest(ASL_FileRequest, 0)))
    {
      if(ptr) *ptr = '\0';
      if(AslRequestTags(r, ASLFR_TitleText, text,
      ASLFR_InitialFile, str, ASLFR_InitialDrawer, file, TAG_DONE))
      {
        my_strncpy(file, r->fr_Drawer, size);
        AddPart(file, r->fr_File, size);
        res = TRUE;
      }
      else
        *ptr = str[0];
      FreeAslRequest(r);
    }
    else ShowError(TXT("Could not open ASL request."));
    CloseLibrary(AslBase);
  }
  else ShowError(TXT("Could not open %s version %ld."), "asl.library", 39);
  return res;
}

static BOOL ArchiveFile(struct xadArchiveInfo *ai, struct xadFileInfo *fi,
struct MyPrefs *prefs)
{
  LONG err;

  if(!prefs->DestArchive)
  {
    if((prefs->DestArchive = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
    {
      BPTR lock;

      switch(prefs->AskArcName)
      {
      case ARCNAME_ASK:
        if(!FileReq(prefs->LastArcName, TXT("Select the archive file name."),
        sizeof(prefs->LastArcName)))
          return FALSE;
        break;
      case ARCNAME_DEFAULT:
        my_strcpy(prefs->LastArcName, prefs->ArcName);
      case ARCNAME_LAST:
        break;
      }

      if((lock = Lock(prefs->LastArcName, EXCLUSIVE_LOCK)))
      {
        enum ArcExists a;

        if((a = prefs->ArcExists) == ARCEXISTS_ASK)
        {
          LONG r;
          r = MyEasyRequest(TXT("Overwrite|Append|Skip"),
          TXT("The archive file '%s' already exists.\nWhat should be done?"),
          prefs->LastArcName);
          switch(r)
          {
          case 1: a = ARCEXISTS_OVERWRITE; break;
          case 2: a = ARCEXISTS_APPEND; break;
          case 0:
            UnLock(lock);
            xadFreeObjectA(prefs->DestArchive, 0);
            prefs->DestArchive = 0;
            return FALSE;
          }
        }
        if(!(prefs->DestFileHandle = OpenFromLock(lock)))
        {
          UnLock(lock);
          xadFreeObjectA(prefs->DestArchive, 0);
          prefs->DestArchive = 0;
          ShowXADError(XADERR_OPENFILE, prefs->LastArcName);
          return FALSE;
        }
        switch(a)
        {
        case ARCEXISTS_OVERWRITE:
          SetFileSize(prefs->DestFileHandle, 0, OFFSET_BEGINNING);
          break;
        case ARCEXISTS_APPEND:
          Seek(prefs->DestFileHandle, 0, OFFSET_END);
          break;
        default:
          break;
        }
        if((err = xadGetHookAccess(prefs->DestArchive, XAD_OUTFILEHANDLE,
        prefs->DestFileHandle, TAG_DONE)))
        {
          xadFreeObjectA(prefs->DestArchive, 0);
          Close(prefs->DestFileHandle);
          prefs->DestArchive = 0;
          prefs->DestFileHandle = 0;
          ShowXADError(err, prefs->LastArcName);
          return FALSE;
        }
      }
      else
      {
        if((err = xadGetHookAccess(prefs->DestArchive, XAD_OUTFILENAME,
        prefs->LastArcName, TAG_DONE)))
        {
          xadFreeObjectA(prefs->DestArchive, 0);
          prefs->DestArchive = 0;
          ShowXADError(err, prefs->LastArcName);
          return FALSE;
        }
      }
    }
  }

/* archive type checking */
  err = CreateFileLHA(ai, fi, prefs->DestArchive);
  if(err)
  {
    ShowXADError(err, prefs->LastArcName);
    return FALSE;
  }
  return TRUE;
}

/* we do not handle files in archives special! */
static BOOL HandleOneFile(struct xadArchiveInfo *ai, struct xadFileInfo *fi,
struct MyPrefs *prefs)
{
  LONG err, pos;
  BOOL res = FALSE;
  struct xadArchiveInfo *ain;
  struct TagItem ti[2];

  ti[0].ti_Tag = XAD_ARCHIVEINFO;
  ti[0].ti_Data = (ULONG) ai;
  ti[1].ti_Tag = TAG_DONE;

fi->xfi_Size = ai->xai_InSize;
Printf("Name: %s, %ld\n", fi->xfi_FileName, fi->xfi_Size);

  pos = ai->xai_InPos;
  if((ain = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
  {
    if(!(err = xadGetInfo(ain, XAD_INXADSTREAM, ti, TAG_DONE)))
    {
      enum Arc a = ARC_ASK;

      if(ain->xai_FileInfo)
      {
        if((a = prefs->FileArc) == ARC_ASK)
        {
          LONG r;
          r = MyEasyRequest(TXT("File|Contents|Extract"),
          TXT("A file archive '%s' was detected.\nWhat should be archived?"),
          fi->xfi_FileName);
          switch(r)
          {
          case 1: a = ARC_FILE; break;
          case 2: a = ARC_CONTENTS; break;
          case 0: a = ARC_EXTRACT; break;
          }
        }
        switch(a)
        {
        case ARC_FILE:
          xadFreeInfo(ain);
          xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos, 0, ai);
          res = ArchiveFile(ai, fi, prefs);
          break;
        case ARC_CONTENTS:
/* DO IT */
          break;
        case ARC_EXTRACT:
/* DO IT */
          break;
        default:
          break;
        }
      }
      if(ain && ain->xai_DiskInfo)
      {
        if(!ain->xai_FileInfo && (a = prefs->DiskArc) == ARC_ASK)
        {
          LONG r;
          r = MyEasyRequest(TXT("File|Contents|Extract"),
          TXT("A disk archive '%s' was detected.\nWhat should be archived?"),
          fi->xfi_FileName);
          switch(r)
          {
          case 1: a = ARC_FILE; break;
          case 2: a = ARC_CONTENTS; break;
          case 0: a = ARC_EXTRACT; break;
          }
        }
        switch(a)
        {
        case ARC_FILE:
          xadFreeInfo(ain);
          xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos, 0, ai);
          res = ArchiveFile(ai, fi, prefs);
          break;
        case ARC_CONTENTS:
/* DO IT */
          break;
        case ARC_EXTRACT:
/* DO IT */
          break;
        default:
          break;
        }
      }
      if(ain)
        xadFreeInfo(ain);
    }
    else 
    {
      if(pos != ai->xai_InPos)
        xadHookAccess(XADAC_INPUTSEEK, pos-ai->xai_InPos, 0, ai);
      if(!(err = xadGetDiskInfo(ain, XAD_INXADSTREAM, ti, TAG_DONE)))
      {
        enum Arc a = ARC_ASK;

        if((a = prefs->FileArc) == ARC_ASK)
        {
          LONG r;
          r = MyEasyRequest(TXT("File|Contents|Extract"),
          TXT("A disk image '%s' was detected.\nWhat should be archived?"),
          fi->xfi_FileName);
          switch(r)
          {
          case 1: a = ARC_FILE; break;
          case 2: a = ARC_CONTENTS; break;
          case 0: a = ARC_EXTRACT; break;
          }
        }
        switch(a)
        {
        case ARC_FILE:
          xadFreeInfo(ain);
          xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos, 0, ai);
          res = ArchiveFile(ai, fi, prefs);
          break;
        case ARC_CONTENTS:
/* DO IT */
          break;
        case ARC_EXTRACT:
/* DO IT */
          break;
        default:
          break;
        }
        if(ain)
          xadFreeInfo(ain);
      }
      else
      {
        xadHookAccess(XADAC_INPUTSEEK, -ai->xai_InPos, 0, ai);
        res = ArchiveFile(ai, fi, prefs);
      }
    }
    xadFreeObject(ain, 0);
  }
  else
    ShowXADError(XADERR_NOMEMORY, fi->xfi_FileName);

  return res;
}

static BOOL AddDirectory(struct xadFileInfo *fi, struct MyPrefs *prefs)
{
  BOOL res = FALSE;
  LONG err = XADERR_OK;
  struct FileInfoBlock *fib;

  if((fib = AllocDosObject(DOS_FIB, 0)))
  {
    BPTR l = 0;
    if((l = Lock(fi ? fi->xfi_FileName : "", SHARED_LOCK)))
    {
      if(Examine(l, fib))
      {
        res = fi ? ArchiveFile(0, fi, prefs) : TRUE;
        while(res && ExNext(l, fib))
        {
          struct xadFileInfo *fis;
          LONG i,j,k;

          i = strlen(fib->fib_FileName)+1;
          k = fi ? strlen(fi->xfi_FileName)+1 : 0;
          j = strlen(fib->fib_Comment);
        
          if((fis = xadAllocObject(XADOBJ_FILEINFO, XAD_OBJNAMESIZE, i+k,
          j ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, j+1,TAG_DONE)))
          {
            if(k)
            {
              my_strncpy(fis->xfi_FileName, fi->xfi_FileName, k);
              fis->xfi_FileName[k-1] = '/';
            }
            my_strncpy(fis->xfi_FileName+k, fib->fib_FileName, i);
            if(j) my_strncpy(fis->xfi_Comment, fib->fib_Comment, j+1);
            if(fib->fib_DirEntryType > 0)
              fis->xfi_Flags |= XADFIF_DIRECTORY;
            fis->xfi_Protection = fib->fib_Protection;
            fis->xfi_Size = fib->fib_Size;
            xadConvertDates(XAD_DATEDATESTAMP, &fib->fib_Date,
            XAD_GETDATEXADDATE, &fis->xfi_Date, TAG_DONE);
            fis->xfi_OwnerUID = fib->fib_OwnerUID;
            fis->xfi_OwnerGID = fib->fib_OwnerGID;
          }
          else
            ShowXADError((err = XADERR_NOMEMORY), fi ? fi->xfi_FileName : TXT("root directory"));
          if(fis->xfi_Flags & XADFIF_DIRECTORY)
          {
            enum SubDirs a;

            if((a = prefs->SubDirs) == SUBDIR_ASK)
            {
              LONG r;
              r = MyEasyRequest(TXT("Archive|Skip"),
              TXT("A subdirectory '%s' was detected.\nWhat should be done?"),
              fis->xfi_FileName);
              switch(r)
              {
              case 1: a = SUBDIR_ALWAYS; break;
              case 0: a = SUBDIR_NEVER; break;
              }
            }
            switch(a)
            {
            case SUBDIR_ALWAYS:
              res = AddDirectory(fis, prefs);
              break;
            case SUBDIR_NEVER:
              break;
            default:
              break;
            }
          }
          else
          {
            struct xadArchiveInfo *ai;
            if((ai = (struct xadArchiveInfo *)
            xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
            {
              if(!xadGetHookAccess(ai, XAD_INFILENAME, fis->xfi_FileName, TAG_DONE))
              {
                res = HandleOneFile(ai, fis, prefs);
                xadFreeHookAccessA(ai, 0);
              }
              xadFreeObjectA(ai,0);
            }
            else
              ShowXADError((err = XADERR_NOMEMORY), prefs->TempName);
          }
          xadFreeObjectA(fis, 0);            
        }
      }
      UnLock(l);
    }
    FreeDosObject(DOS_FIB, fib);
  }
  return res;
}

static struct xadFileInfo *GetFileInfo(STRPTR name, STRPTR path)
{
  LONG i, j, k;
  BPTR lock;
  struct xadFileInfo *fi = 0;
  struct FileInfoBlock *fib;

  if((fib = AllocDosObject(DOS_FIB, 0)))
  {
    if((lock = Lock(name, SHARED_LOCK)))
    {
      if(Examine(lock, fib))
      {
        i = strlen(name)+1;
        k = (path?strlen(path)+1:0);
        j = strlen(fib->fib_Comment);
        
        if((fi = xadAllocObject(XADOBJ_FILEINFO, XAD_OBJNAMESIZE, i+k,
        j ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, j+1,TAG_DONE)))
        {
          if(k)
          {
            my_strncpy(fi->xfi_FileName, path, k);
            fi->xfi_FileName[k-1] = '/';
          }
          my_strncpy(fi->xfi_FileName+k, name, i);
          if(j) my_strncpy(fi->xfi_Comment, fib->fib_Comment, j+1);
          if(fib->fib_DirEntryType > 0)
            fi->xfi_Flags |= XADFIF_DIRECTORY;
          fi->xfi_Protection = fib->fib_Protection;
          fi->xfi_Size = fib->fib_Size;
          xadConvertDates(XAD_DATEDATESTAMP, &fib->fib_Date,
          XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
          fi->xfi_OwnerUID = fib->fib_OwnerUID;
          fi->xfi_OwnerGID = fib->fib_OwnerGID;
        }
      }
      UnLock(lock);
    }
    FreeDosObject(DOS_FIB, fib);
  }
  return fi;
}

static BOOL HandleFiles(LONG num, struct WBArg *arg, struct MyPrefs *prefs)
{
  struct xadArchiveInfo *ai;
  struct xadFileInfo *fi;
  LONG err = 0;
  BOOL res = TRUE;
  BPTR lock;

  while(num-- && res && !err)
  {
    if(arg->wa_Name && *(arg->wa_Name))
    {
      lock = CurrentDir(arg->wa_Lock);
      if((ai = (struct xadArchiveInfo *) xadAllocObjectA(XADOBJ_ARCHIVEINFO,
      0)))
      {
        if(!(err = xadGetHookAccess(ai, XAD_INFILENAME, arg->wa_Name,
        TAG_DONE)))
        {
          if((fi = GetFileInfo(arg->wa_Name, 0)))
          {
            res = HandleOneFile(ai, fi, prefs);
            xadFreeObjectA(fi, 0);
          }
          xadFreeHookAccessA(ai, 0);
          if(res && prefs->Icons == ICONS_YES)
          {
            my_snprintf(prefs->TempName, sizeof(prefs->TempName), "%s.info",
            arg->wa_Name);
            if(!xadGetHookAccess(ai, XAD_INFILENAME, prefs->TempName,
            TAG_DONE))
            {
              if((fi = GetFileInfo(prefs->TempName, 0)))
              {
                res = HandleOneFile(ai, fi, prefs);
                xadFreeObjectA(fi, 0);
              }
              else
                ShowXADError((err = XADERR_NOMEMORY), arg->wa_Name);
              xadFreeHookAccessA(ai, 0);
            }
          }
        }
        else
          ShowXADError(err, arg->wa_Name);

        xadFreeObjectA(ai,0);
      }
      else
        ShowXADError((err = XADERR_NOMEMORY), arg->wa_Name);
      CurrentDir(lock);
    }
    else
    {
      BPTR pr;
      if((pr = ParentDir(arg->wa_Lock)))
      {
        struct xadFileInfo *fid;

        lock = CurrentDir(pr);
        prefs->TempName[0] = 0;
        NameFromLock(arg->wa_Lock, prefs->TempName, sizeof(prefs->TempName));
        /* NOTE, we use TempName as in and output
           --> only possible if unchanged */
        my_strcpy(prefs->TempName, FilePart(prefs->TempName));
        if((fid = GetFileInfo(prefs->TempName, 0)))
        {
          res = AddDirectory(fid, prefs);
          if(res && prefs->Icons == ICONS_YES)
          {
            if((ai = (struct xadArchiveInfo *)
            xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
            {
              /* NOTE, we use TempName as in and output
              --> only possible of unchanged */
              my_snprintf(prefs->TempName, sizeof(prefs->TempName), "%s.info",
              prefs->TempName);
              if(!xadGetHookAccess(ai, XAD_INFILENAME, prefs->TempName, TAG_DONE))
              {
                if((fi = GetFileInfo(prefs->TempName, 0)))
                {
                  res = HandleOneFile(ai, fi, prefs);
                  xadFreeObjectA(fi, 0);
                }
                else
                  ShowXADError((err = XADERR_NOMEMORY), prefs->TempName);
                xadFreeHookAccessA(ai, 0);
              }
              xadFreeObjectA(ai,0);
            }
          }
          xadFreeObjectA(fid,0);
        }
        else
          ShowXADError((err = XADERR_NOMEMORY), prefs->TempName);

        CurrentDir(lock);
        UnLock(pr);
      }
      else /* root directory */
      {
        enum Disk d;

        if((d = prefs->Disk) == DISK_ASK)
        {
          LONG r;
          NameFromLock(arg->wa_Lock, prefs->TempName, sizeof(prefs->TempName));
          r = MyEasyRequest(TXT("Contents|Image|Skip"),
          TXT("You selected the device '%s'.\nWhat should be archived?"),
          prefs->TempName);
          switch(r)
          {
          case 1: d = DISK_CONTENTS; break;
          case 2: d = DISK_IMAGE; break;
          }
        }
        switch(d)
        {
        case DISK_CONTENTS:
          lock = CurrentDir(arg->wa_Lock);
          res = AddDirectory(0, prefs);
          CurrentDir(lock);
          break;
        case DISK_IMAGE:
          NameFromLock(arg->wa_Lock, prefs->TempName, sizeof(prefs->TempName));

          if((ai = (struct xadArchiveInfo *)
          xadAllocObjectA(XADOBJ_ARCHIVEINFO, 0)))
          {
            struct xadDeviceInfo *dvi;

	    if((dvi = (struct xadDeviceInfo *)
	    xadAllocObjectA(XADOBJ_DEVICEINFO, 0)))
	    {
/* do this using SameDevice */
              dvi->xdi_DOSName = ((struct Task *)(((struct FileLock *)
              BADDR(arg->wa_Lock))->fl_Task->mp_SigTask))->tc_Node.ln_Name;
              if(!(err = xadGetHookAccess(ai, XAD_INDEVICE, dvi, TAG_DONE)))
              {
                if((fi = (struct xadFileInfo *)
                xadAllocObjectA(XADOBJ_FILEINFO, 0)))
                {
                  fi->xfi_FileName = prefs->TempName;
                  /* remove ':' */
                  prefs->TempName[strlen(prefs->TempName)-1] = 0;
                  fi->xfi_Size = ai->xai_InSize;
                  res = ArchiveFile(ai, fi, prefs);
                  xadFreeObjectA(fi, 0);
                }
                else err = XADERR_NOMEMORY;
                xadFreeHookAccessA(ai, 0);
              }
              xadFreeObjectA(dvi,0);
            }
            else err = XADERR_NOMEMORY;
            xadFreeObjectA(ai,0);
          }
          else err = XADERR_NOMEMORY;
          if(err)
            ShowXADError(err, prefs->TempName);
          break;
        default:
          break;
        }
      }
    }

    ++arg;
  }

  /* close the created archive */
  if(prefs->DestArchive)
  {
    xadFreeHookAccessA(prefs->DestArchive, 0);
    xadFreeObjectA(prefs->DestArchive, 0);
    if(prefs->DestFileHandle)
    {
      Close(prefs->DestFileHandle);
      prefs->DestFileHandle = 0;
    }
    prefs->DestArchive = 0;
  }

  MyEasyRequest(TXT("Ok"), err ? TXT("Work finished.\nThere were errors.") :
  TXT("Work finished succesfully"));
  return res;
}
