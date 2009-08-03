/*  $Id: GadTools.c,v 1.2 2005/06/23 15:47:24 stoecker Exp $
    gadtools GUI for DropArc

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

#include <string.h>

#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/icon.h>
#include <proto/intuition.h>
#include <proto/gadtools.h>
#include <proto/graphics.h>
#include "DropArc.h"

#define SEPERATE_INTER	2
#define SEPERATE_BORD	5
enum GADGETIDS { GADID_ICONNAME=100, GADID_ARCHIVENAME, 
GADID_GETARCNAME, GADID_DESTINATIONNAME, GADID_GETDESTINATIONNAME,
GADID_ARCHIVETYPE, GADID_FILEARCHIVES, GADID_DISKARCHIVES,
GADID_DISKIMAGES, GADID_DISKS, GADID_SUBDIRS, GADID_FILEEXISTS,
GADID_ARCHIVEEXISTS, GADID_ASKARCNAME, GADID_ASKPATHNAME, GADID_ICONS,
GADID_WINXPOS, GADID_WINYPOS, GADID_WINGET, GADID_ICONXPOS, GADID_IXONYPOS,
GADID_ICONGET, GADID_SAVE, GADID_USE, GADID_CANCEL};

void OpenPrefs(struct MyPrefs *prefs)
{
  struct Window *win;
  ULONG sigs;
  struct Library * GadToolsBase;
  struct GfxBase * GfxBase;
  struct Gadget *gadg = 0;
  struct IntuiMessage *msg;
  struct Screen *scr;
  ULONG width, height;
  LONG i;

  if((GadToolsBase = OpenLibrary("gadtools.library", 39)))
  {
    if((GfxBase = (struct GfxBase *) OpenLibrary("graphics.library", 37)))
    {
      if((scr = LockPubScreen("Workbench")))
      {
        struct VisualInfo *VisualInfo;

        if((VisualInfo = GetVisualInfoA(scr, 0)))
        {
          struct Gadget *g;

          if((g = CreateContext(&gadg)))
          {
            LONG j, leftwidth, rightwidth, bwidth, bowidth, datwidth, k = 0;
            LONG err = 0;
            STRPTR get;
            struct PrefsTexts *t;
            struct NewGadget ng;
            struct Gadget *tgadg[NUMGADG+2];

            memset(tgadg, 0, sizeof(tgadg));
            t = &prefs->PrefsTexts;
            ng.ng_LeftEdge = scr->WBorLeft + SEPERATE_BORD;
            ng.ng_TopEdge = scr->WBorTop+scr->Font->ta_YSize+1+SEPERATE_BORD;
            ng.ng_Height = scr->Font->ta_YSize+5;
            ng.ng_TextAttr = scr->Font;
            ng.ng_GadgetID = 100;
            ng.ng_VisualInfo = VisualInfo;
            ng.ng_UserData = 0;
            ng.ng_Flags = PLACETEXT_LEFT;

            get = TXT("Get");
            datwidth = 10 + TextLength(&scr->RastPort, get, strlen(get));
            j = 10 + TextLength(&scr->RastPort, "9999", 3);
            if(j > datwidth) datwidth = j;

            bwidth = 0;
            for(i = 0; i < 3; ++i)
            {
              j = 10+TextLength(&scr->RastPort, t->buttontexts[i],
              strlen(t->buttontexts[i]));
              if(j > bwidth) bwidth = j;
            }
            bowidth = bwidth;
            leftwidth = 0;
            for(i = 0; i < NUMGADG; ++i)
            {
              j = 10+TextLength(&scr->RastPort, t->gadgtexts[i],
              strlen(t->gadgtexts[i]));
              if(j > leftwidth) leftwidth = j;
            }
            rightwidth = 0;
            for(i = 0; i < 4; ++i)
            {
              j = 30+TextLength(&scr->RastPort, t->arctexts[i],
              strlen(t->arctexts[i]));
              if(j > rightwidth) rightwidth = j;
            }
            for(i = 0; i < 4; ++i)
            {
              j = 30+TextLength(&scr->RastPort, t->arctype[i],
              strlen(t->arctype[i]));
              if(j > rightwidth) rightwidth = j;
            }
            if(datwidth*3+(SEPERATE_INTER*2) < rightwidth)
              datwidth = (rightwidth+2-(SEPERATE_INTER*2))/3;
            if(bwidth < datwidth+(leftwidth+2)/3)
              bwidth = datwidth+(leftwidth+2)/3;
            else
              datwidth = bwidth-(leftwidth+2)/3;
            leftwidth = (bwidth-datwidth)*3;
            rightwidth = datwidth*3+(SEPERATE_INTER*2);

            width = ng.ng_LeftEdge+rightwidth+leftwidth+SEPERATE_BORD
            + scr->WBorLeft;

            ng.ng_LeftEdge += leftwidth;
            ng.ng_GadgetText = t->gadgtexts[k];
            ng.ng_Width = rightwidth;
            if(!err && !(tgadg[k] = g = CreateGadget(STRING_KIND, g, &ng,
            GTST_MaxChars, 29, GTST_String, prefs->Name, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ng.ng_Width -= ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(STRING_KIND, g, &ng,
            GTST_MaxChars, DROPARCPATHSIZE-1, GTST_String, prefs->ArcName,
            TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_GadgetText = 0;
            ng.ng_LeftEdge += ng.ng_Width;
            ng.ng_Width = ng.ng_Height;
            if(!err && !(g = CreateGadgetA(BUTTON_KIND,g,&ng, 0)))
              ++err;
            ng.ng_Width = rightwidth-ng.ng_Height;
            ng.ng_LeftEdge -= ng.ng_Width;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(STRING_KIND, g, &ng,
            GTST_MaxChars, DROPARCPATHSIZE-1, GTST_String,
            prefs->DestinationName, TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_GadgetText = 0;
            ng.ng_LeftEdge += ng.ng_Width;
            ng.ng_Width = ng.ng_Height;
            if(!err && !(g = CreateGadgetA(BUTTON_KIND,g,&ng, 0)))
              ++err;
            ng.ng_Width = rightwidth;
            ng.ng_LeftEdge -= ng.ng_Width-ng.ng_Height;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->arctype, GTCY_Active, prefs->ArcType, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->arctexts, GTCY_Active, prefs->FileArc, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->arctexts, GTCY_Active, prefs->DiskArc, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->arctexts, GTCY_Active, prefs->DiskImage,
            TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->disks, GTCY_Active, prefs->Disk, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->subdirs, GTCY_Active, prefs->SubDirs, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->fileexists, GTCY_Active, prefs->FileExists,
            TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->archiveexists, GTCY_Active, prefs->ArcExists,
            TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->askname, GTCY_Active, prefs->AskArcName,
            TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->askname, GTCY_Active, prefs->AskPathName,
            TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(CYCLE_KIND, g, &ng,
            GTCY_Labels, t->icons, GTCY_Active, prefs->Icons, TAG_DONE)))
              ++err;

            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ng.ng_Width = datwidth;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k] = g = CreateGadget(INTEGER_KIND, g, &ng,
            GTIN_MaxChars, 4, STRINGA_Justification, GACT_STRINGRIGHT,
            GTIN_Number, prefs->WindowLeft, TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_LeftEdge += ng.ng_Width+SEPERATE_INTER;
            ng.ng_GadgetText = 0;
            if(!err && !(tgadg[k+1] = g = CreateGadget(INTEGER_KIND, g, &ng,
            GTIN_MaxChars, 4, STRINGA_Justification, GACT_STRINGRIGHT,
            GTIN_Number, prefs->WindowTop, TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_LeftEdge += ng.ng_Width+SEPERATE_INTER;
            ng.ng_GadgetText = TXT("Get");
            ng.ng_Flags = PLACETEXT_IN;
            if(!err && !(g = CreateGadgetA(BUTTON_KIND, g, &ng, 0)))
              ++err;

            ng.ng_LeftEdge = scr->WBorLeft + SEPERATE_BORD + leftwidth;
            ng.ng_Flags = PLACETEXT_LEFT;
            ng.ng_TopEdge += SEPERATE_INTER+ng.ng_Height;
            ng.ng_Width = datwidth;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->gadgtexts[++k];
            if(!err && !(tgadg[k+1] = g = CreateGadget(INTEGER_KIND, g, &ng,
            GTIN_MaxChars, 4, STRINGA_Justification, GACT_STRINGRIGHT,
            GTIN_Number, prefs->XPosition, TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_LeftEdge += ng.ng_Width+SEPERATE_INTER;
            ng.ng_GadgetText = 0;
            if(!err && !(tgadg[k+2] = g = CreateGadget(INTEGER_KIND, g, &ng,
            GTIN_MaxChars, 4, STRINGA_Justification, GACT_STRINGRIGHT,
            GTIN_Number, prefs->YPosition, TAG_DONE)))
              ++err;

            ++ng.ng_GadgetID;
            ng.ng_LeftEdge += ng.ng_Width+SEPERATE_INTER;
            ng.ng_GadgetText = TXT("Get");
            ng.ng_Flags = PLACETEXT_IN;
            if(!err && !(g = CreateGadgetA(BUTTON_KIND, g, &ng, 0)))
              ++err;

            ng.ng_TopEdge += (SEPERATE_INTER*4)+ng.ng_Height;

            ng.ng_LeftEdge = scr->WBorLeft+SEPERATE_BORD + (bwidth-bowidth)/2;
            ng.ng_Flags = PLACETEXT_IN;
            ng.ng_Width = bowidth;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->buttontexts[0];
            if(!err && !(g = CreateGadgetA(BUTTON_KIND, g, &ng, TAG_DONE)))
              ++err;

            ng.ng_LeftEdge += bwidth+SEPERATE_INTER;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->buttontexts[1];
            if(!err && !(g = CreateGadgetA(BUTTON_KIND, g, &ng, TAG_DONE)))
              ++err;

            ng.ng_LeftEdge += bwidth+SEPERATE_INTER;
            ++ng.ng_GadgetID;
            ng.ng_GadgetText = t->buttontexts[2];
            if(!err && !(g = CreateGadgetA(BUTTON_KIND, g, &ng, TAG_DONE)))
              ++err;

            height = ng.ng_TopEdge+ng.ng_Height+SEPERATE_BORD+scr->WBorBottom;

            if(err)
              ShowError(TXT("Could not create gadgets."));
            else if((win = OpenWindowTags(0, WA_CloseGadget, TRUE, WA_DragBar, TRUE,
            WA_Gadgets, gadg, WA_IDCMP, IDCMP_CLOSEWINDOW|IDCMP_GADGETUP,
            WA_Width, width, WA_Height, height, WA_PubScreen, scr,
            WA_Activate, TRUE, WA_Title, TXT("DropArc Preferences"),
            WA_AutoAdjust, TRUE, WA_MinWidth, width, WA_MinHeight, height,
            WA_Top, prefs->WindowTop < 0 ? scr->BarHeight + 1 : prefs->WindowTop,
            prefs->WindowLeft >= 0 ? WA_Left : TAG_IGNORE, prefs->WindowLeft,
            WA_DepthGadget, TRUE, TAG_DONE)))
            {
              GT_RefreshWindow(win,0);
              do
              {
                sigs = Wait(SIGBREAKF_CTRL_C|(1<<win->UserPort->mp_SigBit));
                if(sigs&SIGBREAKF_CTRL_C) Signal(FindTask(0), SIGBREAKF_CTRL_C);
                else
                {
                  while(!(sigs & SIGBREAKF_CTRL_C) && (msg =
                  GT_GetIMsg(win->UserPort)))
                  {
                    switch(msg->Class)
                    {
                    case IDCMP_CLOSEWINDOW: sigs |= SIGBREAKF_CTRL_C; break;
                    case IDCMP_GADGETUP:
                      switch(((struct Gadget *) msg->IAddress)->GadgetID)
	              {
	              case GADID_GETARCNAME:
	                FileReq(prefs->ArcName,
	                TXT("Select default archive name"), DROPARCPATHSIZE);
	                GT_SetGadgetAttrs(tgadg[1], win, 0, GTST_String,
	                prefs->ArcName, TAG_DONE);
	                break;
	              case GADID_GETDESTINATIONNAME:
	                FileReq(prefs->DestinationName,
	                TXT("Select destination path"), DROPARCPATHSIZE);
	                GT_SetGadgetAttrs(tgadg[2], win, 0, GTST_String,
	                prefs->DestinationName, TAG_DONE);
	                break;
                      case GADID_WINGET:
                        GT_SetGadgetAttrs(tgadg[14], win, 0, GTIN_Number,
                        win->LeftEdge, TAG_DONE);
                        GT_SetGadgetAttrs(tgadg[15], win, 0, GTIN_Number,
                        win->TopEdge, TAG_DONE);
                        break;
                      case GADID_ICONGET:
                        GT_SetGadgetAttrs(tgadg[16], win, 0, GTIN_Number,
                        (prefs->DiskObject->do_CurrentX == NO_ICON_POSITION ? -1
                        : prefs->DiskObject->do_CurrentX), TAG_DONE);
                        GT_SetGadgetAttrs(tgadg[17], win, 0, GTIN_Number,
                        (prefs->DiskObject->do_CurrentY == NO_ICON_POSITION ? -1
                        : prefs->DiskObject->do_CurrentY), TAG_DONE);
                        break;
                      case GADID_SAVE:
                      case GADID_USE:
                        k = 0;
                        GT_GetGadgetAttrs(tgadg[k], win, 0, GTST_String, &get,
                        TAG_DONE);
                        my_strcpy(prefs->Name, get);
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTST_String, &get,
                        TAG_DONE);
                        my_strcpy(prefs->ArcName, get);
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTST_String, &get,
                        TAG_DONE);
                        my_strcpy(prefs->DestinationName, get);
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->ArcType = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->FileArc = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->DiskArc = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->DiskImage = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->Disk = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->SubDirs = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->FileExists = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->ArcExists = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->AskArcName = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->AskPathName = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTCY_Active, &i,
                        TAG_DONE);
                        prefs->Icons = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTIN_Number, &i,
                        TAG_DONE);
                        prefs->WindowLeft = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTIN_Number, &i,
                        TAG_DONE);
                        prefs->WindowTop = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTIN_Number, &i,
                        TAG_DONE);
                        prefs->XPosition = i;
                        GT_GetGadgetAttrs(tgadg[++k], win, 0, GTIN_Number, &i,
                        TAG_DONE);
                        prefs->YPosition = i;
                        sigs |= SIGBREAKF_CTRL_C;
                        if(((struct Gadget *) msg->IAddress)->GadgetID == GADID_SAVE)
                          SavePrefs(prefs);
                        break;
                      case GADID_CANCEL:
                        sigs |= SIGBREAKF_CTRL_C;
                        break;
	              }
                    }
                    GT_ReplyIMsg(msg);
                  }
                }
              } while(!(sigs & SIGBREAKF_CTRL_C));
              CloseWindow(win);
            }
            else ShowError(TXT("Could not open preferences window."));
            FreeGadgets(gadg);
          }
          else ShowError(TXT("Could not create gadgets."));
          FreeVisualInfo(VisualInfo);
        }
        else ShowError(TXT("Could not get screen information."));
        UnlockPubScreen(0, scr);
      }
      else ShowError(TXT("Could not lock screen."));
    }
    else ShowError(TXT("Could not open %s version %ld."),
    "graphics.library", 37);
  }
  else ShowError(TXT("Could not open %s version %ld."),
  "gadtools.library", 39);
}

