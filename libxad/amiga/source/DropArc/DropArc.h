#ifndef DROPARC_H
#define DROPARC_H

/*  $Id: DropArc.h,v 1.2 2005/06/23 15:47:24 stoecker Exp $
    definitions for DropArc

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

#define DROPARCPATHSIZE 256
#define TXT(a,b) MyTexts[b]

enum ArcType    { ARCTYPE_AUTODETECT, ARCTYPE_ASK, ARCTYPE_LHA, ARCTYPE_ZIP, ARCTYPE_NONE };
enum Arc        { ARC_ASK, ARC_CONTENTS, ARC_FILE, ARC_EXTRACT };
enum Disk       { DISK_ASK, DISK_CONTENTS, DISK_IMAGE };
enum SubDirs    { SUBDIR_ASK, SUBDIR_NEVER, SUBDIR_ALWAYS };
enum FileExists { FILEEXISTS_ASK, FILEEXISTS_OVERWRITE, FILEEXISTS_SKIP };
enum ArcExists  { ARCEXISTS_ASK, ARCEXISTS_OVERWRITE, ARCEXISTS_APPEND };
enum ArcName    { ARCNAME_ASK, ARCNAME_DEFAULT, ARCNAME_LAST};
enum PathName   { PATHNAME_ASK, PATHNAME_DEFAULT, PATHNAME_LAST};
enum Icons      { ICONS_YES, ICONS_NO };

#define NUMGADG 16

struct PrefsTexts {
  STRPTR gadgtexts[NUMGADG];
  STRPTR buttontexts[3];
  STRPTR arctexts[5];
  STRPTR arctype[5];
  STRPTR subdirs[4];
  STRPTR disks[4];
  STRPTR fileexists[4];
  STRPTR archiveexists[4];
  STRPTR askname[4];
  STRPTR icons[3];
};

struct MyPrefs {
  struct PrefsTexts       PrefsTexts;
  STRPTR                  IconName;
  struct DiskObject *     DiskObject;
  WORD                    XPosition;
  WORD                    YPosition;
  WORD                    WindowTop;
  WORD                    WindowLeft;
  enum ArcType            ArcType;
  enum Arc                FileArc;
  enum Arc                DiskArc;
  enum Arc                DiskImage;
  enum Disk               Disk;
  enum SubDirs            SubDirs;
  enum FileExists         FileExists;
  enum ArcExists          ArcExists;
  enum ArcName            AskArcName;
  enum PathName           AskPathName;
  enum Icons              Icons;
  UBYTE                   ArcName[DROPARCPATHSIZE];
  UBYTE                   DestinationName[DROPARCPATHSIZE];
  UBYTE                   Name[30];
  UBYTE                   TempDir[3]; /* hidden option! */

  /* now some stuff for current archive */
  UBYTE                   LastArcName[DROPARCPATHSIZE];
  UBYTE                   LastDestinationName[DROPARCPATHSIZE];
  UBYTE                   TempName[DROPARCPATHSIZE];
  struct xadArchiveInfo * DestArchive;
  enum ArcType            DestArcType;
  BPTR                    DestFileHandle;
};

void SavePrefs(struct MyPrefs *prefs);
ULONG FileReq(STRPTR file, STRPTR text, ULONG size);
void ShowError(STRPTR text, ...);
void my_strncpy(STRPTR dbuf, STRPTR sbuf, LONG size);

#define my_strcpy(dbuf, sbuf) my_strncpy(dbuf, sbuf, sizeof(dbuf));

/* GUI stuff */
void OpenPrefs(struct MyPrefs *prefs);

/* stuff of locale.c */
extern char *MyTexts[];
extern const int MaxNumMyTexts;

/* stuff of lha.c */
BOOL CreateFileLHA(struct xadArchiveInfo *inai, struct xadFileInfo *fi,
struct xadArchiveInfo *outai);
/* returns XADERR, 0 if all valid or -1 for ignored files */

#endif
