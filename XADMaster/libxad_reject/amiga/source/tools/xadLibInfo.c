#define NAME         "xadLibInfo"
#define DISTRIBUTION "(LGPL) "
#define REVISION     "6"
#define DATE	     "07.08.2002"

/*  $Id: xadLibInfo.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    xadLibInfo - show informations about xad Clients

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
#include <dos/dosasl.h>
#include "SDI_version.h"

#ifdef __SASC
  #define dosbase	 DOSBase 
  #define xadmasterbase	 xadMasterBase 
  #define ASSIGN_DOS
  #define ASSIGN_XAD
  #define ASSIGN_SYS	 struct ExecBase * SysBase; \
			 SysBase = (*((struct ExecBase **) 4));
#else
  struct DosLibrary *	 DOSBase = 0;
  struct ExecBase *	 SysBase  = 0;
  struct xadMasterBase * xadMasterBase = 0;

  #define ASSIGN_DOS	 DOSBase = dosbase;
  #define ASSIGN_XAD	 xadMasterBase = xadmasterbase;
  #define ASSIGN_SYS	 SysBase = (*((struct ExecBase **) 4));
#endif

ULONG start(void)
{
  ULONG ret = RETURN_FAIL;
  struct DosLibrary *dosbase;

  ASSIGN_SYS
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
    struct xadMasterBase *xadmasterbase;
    ASSIGN_DOS
    if((xadmasterbase = (struct xadMasterBase *) 
    OpenLibrary("xadmaster.library", 1)))
    {
      ULONG fl;
      struct xadClient *xc;

      ASSIGN_XAD
      ret = 0;
      if((xc = xadGetClientInfo()))
        Printf("\033[4mClients of xadmaster.library %ld.%ld\033[0m\n\n"
	"Name                      |  ID  | MV |  VER  | Flags\n"
	"--------------------------+------+----+-------+------------------------------\n",
	xadmasterbase->xmb_LibNode.lib_Version,
	xadmasterbase->xmb_LibNode.lib_Revision);
      
      while(xc && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
      {
        fl = xc->xc_Flags;

        Printf("%-26s| ", xc->xc_ArchiverName);
        Printf(xc->xc_Identifier ? "%04ld" : "----", xc->xc_Identifier);
        Printf(" | %2ld |%3ld.%ld%s| ", xc->xc_MasterVersion,
        xc->xc_ClientVersion, xc->xc_ClientRevision, xc->xc_ClientRevision
        >= 100 ? "" : xc->xc_ClientRevision >= 10 ? " " : "  ");
        if(fl & XADCF_FILEARCHIVER)
        {
          fl &= ~XADCF_FILEARCHIVER;
          Printf("FILE%s", fl ? "," : "");
        }
        if(fl & XADCF_DISKARCHIVER)
        {
          fl &= ~XADCF_DISKARCHIVER;
          Printf("DISK%s", fl ? "," : "");
        }
        if(fl & XADCF_FILESYSTEM)
        {
          fl &= ~XADCF_FILESYSTEM;
          Printf("FILESYS%s", fl ? "," : "");
        }
        if(fl & XADCF_EXTERN)
        {
          fl &= ~XADCF_EXTERN;
          Printf("EXTERN%s", fl ? "," : "");
        }
        if(fl & XADCF_NOCHECKSIZE)
        {
          fl &= ~XADCF_NOCHECKSIZE;
          Printf("NOCHECKSIZE%s", fl ? "," : "");
        }
        if(fl & XADCF_DATACRUNCHER)
        {
          fl &= ~XADCF_DATACRUNCHER;
          Printf("DATACRUNCHER%s", fl ? "," : "");
        }
        if(fl & XADCF_EXECRUNCHER)
        {
          fl &= ~XADCF_EXECRUNCHER;
          Printf("EXECRUNCHER%s", fl ? "," : "");
        }
        if(fl & XADCF_ADDRESSCRUNCHER)
        {
          fl &= ~XADCF_ADDRESSCRUNCHER;
          Printf("ADDRESSCRUNCHER%s", fl ? "," : "");
        }
        if(fl & XADCF_LINKER)
        {
          fl &= ~XADCF_LINKER;
          Printf("LINKER%s", fl ? "," : "");
        }
        fl &= XADCF_FREEFILEINFO|XADCF_FREEDISKINFO|XADCF_FREETEXTINFO|XADCF_FREESKIPINFO|XADCF_FREETEXTINFOTEXT|
              XADCF_FREESPECIALINFO|XADCF_FREEXADSTRINGS;
        if(fl)
        {
          Printf("FREE(");
          if(fl & XADCF_FREEFILEINFO)
          {
            fl &= ~XADCF_FREEFILEINFO;
            Printf("FI%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREEDISKINFO)
          {
            fl &= ~XADCF_FREEDISKINFO;
            Printf("DI%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREETEXTINFO)
          {
            fl &= ~XADCF_FREETEXTINFO;
            Printf("TI%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREESKIPINFO)
          {
            fl &= ~XADCF_FREESKIPINFO;
            Printf("SI%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREESPECIALINFO)
          {
            fl &= ~XADCF_FREESPECIALINFO;
            Printf("SP%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREEXADSTRINGS)
          {
            fl &= ~XADCF_FREEXADSTRINGS;
            Printf("STR%s", fl ? "," : ")");
          }
          if(fl & XADCF_FREETEXTINFOTEXT)
            Printf("TEXT)");
        }

        Printf("\n");
	xc = xc->xc_Next;
      }
      if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
        PrintFault(ERROR_BREAK,0 );

      CloseLibrary((struct Library *) xadmasterbase);
    }
    else
      Printf("Could not open xadmaster.library\n");
    CloseLibrary((struct Library *) dosbase);
  }
  return ret;
}
