#define NAME         "xadList"
#define DISTRIBUTION "(Freeware) "
#define REVISION     "0"

/* Programmheader

	Name:		xadList
	Author:		SDI
	Distribution:	Freeware
	Description:	shows the directory contents and archive type
	Compileropts:	-
	Linkeropts:	-gsi -l amiga

 1.0   18.11.98 : first version
*/

#include <proto/xadmaster.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/memory.h>
#include <dos/dosasl.h>
#include "SDI_system.h"
#include "SDI_version.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

SDI_LIBBASE(struct DosLibrary, DOSBase, struct DOSIFace, IDOS)
SDI_LIBBASE(struct xadMasterBase, xadMasterBase, struct xadMasterIFace, IxadMaster)
SDI_GLOBALLIBBASE(struct ExecBase, SysBase, ExecIFace, IExec)

#define PARAM	"FILE/M,ALL/S,NE=NOEXTERN/S,ONLYKNOWN/S"

struct Args {
  STRPTR *file;
  ULONG   all;
  ULONG   noextern;
  ULONG	  onlyknown;
};

ULONG _start(void)
{
  ULONG ret = RETURN_FAIL;

  SDI_SETSYSBASE
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

  SDI_OPENLIB(struct DosLibrary, DOSBase, struct DOSIFace, IDOS, "dos.library", 37)
  if(SDI_CHECKOPEN(DOSBase, IDOS))
  {
    SDI_OPENLIB(struct xadMasterBase, xadMasterBase, struct xadMasterIFace,
            IxadMaster, "xadmaster.library", 1)
    if(SDI_CHECKOPEN(xadMasterBase, IxadMaster))
    {
      struct Args args;
      struct RDArgs *rda;
      STRPTR a[2];
      
      a[0] = "";
      a[1] = 0;
      args.file = a;
      args.all = args.noextern = args.onlyknown = 0;
      
      if((rda = ReadArgs(PARAM, (LONG *) &args, 0)))
      {
        struct AnchorPath *ap;

        if(!args.file)		/* a bug in ReadArgs */
          args.file = a;

        if((ap = (struct AnchorPath *)
        AllocVec(sizeof(struct AnchorPath) + 300, MEMF_PUBLIC|MEMF_CLEAR)))
        {
          APTR buf;
          ULONG size, first;

          ap->ap_BreakBits = SIGBREAKF_CTRL_C;
          ap->ap_Strlen = 300;
          size = xadMasterBase->xmb_RecogSize;

	  if((buf = AllocVec(size, MEMF_ANY|MEMF_PUBLIC)))
	  {
            ret = RETURN_OK;
	    while(ret <= RETURN_WARN && *args.file)
	    {
	      LONG retval, deep = 0;
	      UBYTE txt[130];
	      BPTR lock;

	      first = 0;
	      if((lock = Lock(*args.file, SHARED_LOCK)))
	      {
	        if(Examine(lock, &ap->ap_Info))
	          if(ap->ap_Info.fib_DirEntryType >0)
	            first = 1;
	        UnLock(lock);
	      }      

              for(retval = MatchFirst(*args.file, ap); !retval;
              retval = MatchNext(ap))
              {
		strcpy(txt, "          ");
		sprintf(&txt[deep%10], "%-108s", ap->ap_Info.fib_FileName);
                if(ap->ap_Flags & APF_DIDDIR)
                {
                  ap->ap_Flags &= ~APF_DIDDIR; --deep;
                }
                else if(ap->ap_Info.fib_DirEntryType > 0)
                {
                  if(!first)
                  {
                    Printf("%.53s <DIR>\n", txt);
		    if(args.all)
                      ++deep;
                  }
                  if(args.all || first)
                    ap->ap_Flags |= APF_DODIR;
                }
                else
                {
		  STRPTR res = "could not check";
		  ULONG s;
		  BPTR fh;
		
		  if((s = ap->ap_Info.fib_Size) > size)
		    s = size;
		  
		  if((fh = Open(ap->ap_Buf, MODE_OLDFILE)))
		  {
		    if(Read(fh, buf, s) == s)
		    {
		      struct xadClient *xc;

		      if((xc = xadRecogFile(s, buf, XAD_NOEXTERN, 
		      args.noextern, TAG_DONE)))
		        res = xc->xc_ArchiverName;
		      else
		        res = 0;
		    }
		    else
		      ret = RETURN_WARN;
		    Close(fh);
		  }
		  else
		    ret = RETURN_WARN;

		  if(!args.onlyknown || res)
		  {
		    if(!res)
		      res = "unknown";
                    Printf("%.48s %10ld %s\n", txt,
                    ap->ap_Info.fib_Size, res);
                  }
                }
                first = 0;
              }
              MatchEnd(ap);

              if(retval != ERROR_NO_MORE_ENTRIES)
                ret = RETURN_ERROR;
	      if(*(++args.file) && ret <= RETURN_WARN)
	        Printf("\n");
	    } /* while */
	    FreeVec(buf);
	  } /* AllocVec */
          FreeVec(ap);
	} /* AllocVec */
        FreeArgs(rda);
      } /* ReadArgs */

      if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
        SetIoErr(ERROR_BREAK);

      if(ret)
        PrintFault(IoErr(), 0);
    }
    else
      Printf("Could not open xadmaster.library\n");
    SDI_CLOSELIB(xadMasterBase, IxadMaster)
  }
  SDI_CLOSELIB(DOSBase, IDOS)
  return ret;
}
