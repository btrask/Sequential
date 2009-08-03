#define NAME         "exe2arc"
#define DISTRIBUTION "(LGPL) "
#define REVISION     "5"
#define DATE	     "24.04.2002"

/*  $Id: exe2arc.c,v 1.2 2005/06/23 15:47:25 stoecker Exp $
    exe2arc - strips executable header from exe files

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

#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/memory.h>
#include "SDI_version.h"
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"

struct DosLibrary *	 DOSBase = 0;
struct ExecBase *	 SysBase  = 0;

#define PARAM	"FROM/A,TO,TYPE/K"

struct Args {
  STRPTR   from;
  STRPTR   to;
  STRPTR   type;
};

#define BUFSIZE 102400

#define EndConvI32(a)	(((a)>>24)|(((a)>>8)&0xFF00)|(((a)<<8)&0xFF0000)|((a)<<24))
#define EndConvI16(a)	((UWORD)(((a)>>8)|((a)<<8)))

typedef BOOL (* SCANFUNC)(BPTR infh, STRPTR buffer, ULONG filesize, ULONG buffersize);
typedef ULONG (* EXTRACTFUNC)(BPTR infh, BPTR outfh, STRPTR buffer, ULONG filesize, ULONG buffersize);

struct ScanData {
  SCANFUNC	ScanFunc;
  EXTRACTFUNC	ExtractFunc;
  STRPTR	Extension; /* and type specifier */
  STRPTR	Name; /* and type specifier */
};

/* a) It is not the very best method to do scan loop again and again, but easy
      to implement :-)
   b) The buffer can be used to pass data from scanner to extractor.
*/

struct ScanData ScanFuncs[]; /* declaration, real field see file end */

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
    struct Args args;
    struct RDArgs *rda;

    DOSBase = dosbase;

    args.to = args.type = 0;
    if((rda = ReadArgs(PARAM, (LONG *) &args, 0)))
    {
      BPTR infh;

      if((infh = Open(args.from, MODE_OLDFILE)))
      {
        struct FileInfoBlock *fib;

        if((fib = (struct FileInfoBlock *) AllocDosObject(DOS_FIB, 0)))
        {
          if(ExamineFH(infh, fib))
          {
            STRPTR buf, name = args.to;

            if((buf = AllocMem(BUFSIZE+1024, MEMF_ANY)))
            {
	      ULONG i, j;
	      LONG stop = 0, found = 0;

	      for(i = 0; !stop && ScanFuncs[i].ScanFunc; ++i)
	      {
		if(args.type && stricmp(ScanFuncs[i].Extension, args.type) && stricmp(ScanFuncs[i].Name, args.type))
		  ; /* skip the entry */
                else if(Seek(infh, 0, OFFSET_BEGINNING) >= 0)
                {
		  if(args.type)
		    found = 1;
                  Printf("Scanning for %s-Archive.", ScanFuncs[i].Name);
                  Flush(Output());
                  if(ScanFuncs[i].ScanFunc(infh, buf, fib->fib_Size, BUFSIZE))
                  {
                    BPTR outfh;
                    STRPTR tmp = buf+BUFSIZE;
                    ULONG k;

                    if(!args.to) name = tmp;
                    for(j = 0; args.from[j]; ++j)
                      tmp[j] = args.from[j];
                    k = j;

		    do
		    {
		      if(tmp[--j] == '.')
		        k = j;
		    } while(j && tmp[j] != '.' && tmp[j] != '/' && tmp[j] != ':');
		    tmp[k++] = '.';
		    for(j = 0; ScanFuncs[i].Extension[j]; ++j)
		      tmp[k++] = ScanFuncs[i].Extension[j];
		    tmp[k] = 0;
                    stop = 1;
		    Printf(" Found.\n");
                    if(!(outfh = Open(name, MODE_NEWFILE)) && args.to)
                    {
                      name = buf+BUFSIZE+512;
                      *name = 0;
                      AddPart(name, args.to, 512);
                      tmp = buf+BUFSIZE; k = 0;
                      for(j = 0; tmp[j]; ++j)
                      {
                        if(tmp[j] == '/' || tmp[j] == ':')
                          k = j+1;
                      }
                      AddPart(name, tmp+k, 512);
                      outfh = Open(name, MODE_NEWFILE);
                    }
                    if(outfh)
                    {
                      if((j = ScanFuncs[i].ExtractFunc(infh, outfh, buf, fib->fib_Size, BUFSIZE)))
                      {
                        Printf("Saved %ld byte to %s\nBe careful and test the file for correctness.\n", j, name);
                        ret = 0;
                      }
                      Close(outfh);
                      if(ret)
                        DeleteFile(name);
                    }
                    else
                      Printf("\nFailed to open output file.\n");
                  }
                  else
                  {
                    Printf("\r\033[K");
                    Flush(Output());
                  }
                }
                else
                {
                  stop = 1;
                  Printf("Failed to seek to file start.\n");
                }
              }
              if(!stop)
              {
                if(args.type)
                {
                  Printf("\r\033[KDid not find archive of type '%s'.\n", args.type);
                  if(found)
                    Printf("Maybe it is an archive of another type?\n");
                  Printf("Valid types are: ");
                  for(i = 0; !stop && ScanFuncs[i].ScanFunc; ++i)
                    Printf("%s (%s)%s", ScanFuncs[i].Extension, ScanFuncs[i].Name, ScanFuncs[i+1].ScanFunc ? ", " : "\n");
                }
                else
                  Printf("\r\033[KDid not find archive data.\n");
              }
              FreeMem(buf, BUFSIZE+1024);
            }
            else
              Printf("Failed to open temporary buffer.\n");
          }
          else
            Printf("Failed to examine file.\n");
          FreeDosObject(DOS_FIB, 0);
        }
        else
          Printf("Failed to open file information object.\n");
        Close(infh);
      }
      else
        Printf("Failed to open input file.\n");
      FreeArgs(rda);
    }
    else
      PrintFault(IoErr(), 0);
    CloseLibrary((struct Library *) dosbase);
  } /* OpenLibrary dos */
  return ret;
}

ULONG DoCopy(BPTR infh, BPTR outfh, STRPTR buf, ULONG size, ULONG buffersize)
{
  ULONG s, err = 0;
  
  while(size && !err)
  {
    s = size;
    if(s > buffersize)
      s = buffersize;
    if(Read(infh, buf, s) != s)
      err = RETURN_FAIL;
    else if(Write(outfh, buf, s) != s)
      err = RETURN_FAIL;
    size -= s;
  }
  
  return err;
}

/******** exe2zip *********/

BOOL ScanZIP(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0, corr = 0;
  LONG stop = 0, i, j, k;

  if(Seek(fh, 0, OFFSET_END) >= 0)
  {
    while(size > 22 && !stop)
    {
      if(bufsize > size)
        bufsize = size;
      if(Seek(fh, size-bufsize, OFFSET_BEGINNING) < 0)
        ++stop;
      else if(Read(fh, buf, bufsize) != bufsize)
        ++stop;
      for(i = bufsize-22; i >= 0 && !stop; --i)
      {
        if(buf[i] == 'P' && buf[i+1] == 'K' && buf[i+2] == 5 && buf[i+3] == 6)
        {
          j = (((((buf[i+19]<<8)+buf[i+18])<<8)+buf[i+17])<<8)+buf[i+16];
          k = (((((buf[i+15]<<8)+buf[i+14])<<8)+buf[i+13])<<8)+buf[i+12];
          if(j != size-bufsize+i-k)
	  {
	    corr = (size-bufsize+i-k)-j;
	    j += corr;
	  }
          if(Seek(fh, j+4, OFFSET_BEGINNING) >= 0)
          {
            if(Read(fh, buf, 42) == 42)
              start = ((buf[38]) | (buf[39]<<8) | (buf[40]<<16) | (buf[41]<<24)) + corr;
          }
          ++stop;
        }
      }
      size -= (bufsize-21);
    }
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = corr; /* store this for extract */
  ((ULONG *)buf)[1] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

ULONG ExtractZIP(BPTR infh, BPTR outfh, STRPTR buf, ULONG filesize, ULONG buffersize)
{
  LONG start, corr, Type = 0, ret = 0, i;

  start = ((ULONG *)buf)[1];
  corr = ((ULONG *)buf)[0]-start;

  while(Type != 0x504B0506 && !ret && !(SetSignal(0L,0L) & SIGBREAKF_CTRL_C))
  {
    if(Read(infh, &Type, 4) == 4)
    {
      ret = RETURN_FAIL;
      switch(Type)
      {
      case 0x504B0304: /* local */
        if(Read(infh, buf+4, 26) == 26)
        {
          buf[0] = 'P'; buf[1] = 'K'; buf[2] = 3; buf[3] = 4;
          if(Write(outfh, buf, 30) == 30)
          {
            ret = DoCopy(infh, outfh, buf, ((buf[18]) | (buf[19]<<8) | (buf[20]<<16) | (buf[21]<<24)) +
            ((buf[26]) | (buf[27]<<8)) + ((buf[28]) | (buf[29]<<8)), buffersize);
          }
        }
        break;
      case 0x504B0102: /* central */
        if(Read(infh, buf+4, 42) == 42)
        {
          buf[0] = 'P'; buf[1] = 'K'; buf[2] = 1; buf[3] = 2;
          i = ((buf[42]) | (buf[43]<<8) | (buf[44]<<16) | (buf[45]<<24)) + corr;
	  buf[42] = i;
	  buf[43] = i>>8;
	  buf[44] = i>>16;
	  buf[45] = i>>24;
          if(Write(outfh, buf, 46) == 46)
          {
            ret = DoCopy(infh, outfh, buf, ((buf[28]) | (buf[29]<<8)) +
            ((buf[30]) | (buf[31]<<8)) + ((buf[32]) | (buf[33]<<8)), buffersize);
          }
        }
        break;
      case 0x504B0506: /* end */
        if(Read(infh, buf+4, 18) == 18)
        {
          buf[0] = 'P'; buf[1] = 'K'; buf[2] = 5; buf[3] = 6;
          i = ((buf[16]) | (buf[17]<<8) | (buf[18]<<16) | (buf[19]<<24)) + corr;
	  buf[16] = i;
	  buf[17] = i>>8;
	  buf[18] = i>>16;
	  buf[19] = i>>24;
          if(Write(outfh, buf, 22) == 22)
            ret = DoCopy(infh, outfh, buf, buf[20] | (buf[21]<<8), buffersize); /* copy comment */
        }
        break;
      default:
	Printf("Unknown or illegal data found.\n");
	break;
      }
    }
    else
      Printf("Unexpected end of data.\n");
  }
  if(SetSignal(0L,0L) & SIGBREAKF_CTRL_C)
    SetIoErr(ERROR_BREAK);

  return ret ? 0 : filesize-start;
}

/******** exe2ace *********/

BOOL ScanACE(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0;
  LONG i, pos = 0, stop = 0;

  while(size > 14 && !stop)
  {
    if(bufsize > size)
      bufsize = size;
    if(Seek(fh, pos, OFFSET_BEGINNING) < 0)
      ++stop;
    else if(Read(fh, buf, bufsize) != bufsize)
      ++stop;
    for(i = 0; i <= bufsize-14 && !stop; ++i)
    {
      if(buf[i+7] == '*' && buf[i+8] == '*' && buf[i+9] == 'A' && buf[i+10] == 'C' &&
      buf[i+11] == 'E' && buf[i+12] == '*' && buf[i+13] == '*')
      {
        if(Seek(fh, -i, OFFSET_CURRENT) >= 0)
          start = pos+i;
        ++stop;
      }
    }
    size -= i;
    pos += i;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

ULONG ExtractACE(BPTR infh, BPTR outfh, STRPTR buf, ULONG filesize, ULONG buffersize)
{
  LONG ret;

  filesize -= ((ULONG *)buf)[0];
  ret = DoCopy(infh, outfh, buf, filesize, buffersize);
  
  return ret ? 0 : filesize;
}

/******** exe2rar *********/

BOOL ScanRAR(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0;
  LONG i, pos = 0, stop = 0;

  while(size > 7 && !stop)
  {
    if(bufsize > size)
      bufsize = size;
    if(Seek(fh, pos, OFFSET_BEGINNING) < 0)
      ++stop;
    else if(Read(fh, buf, bufsize) != bufsize)
      ++stop;
    for(i = 0; i <= bufsize-7 && !stop; ++i)
    {
      if(buf[i] == 'R' && buf[i+1] == 'a' && buf[i+2] == 'r' && buf[i+3] == '!' &&
      buf[i+4] == 0x1A && buf[i+5] == 7 && buf[i+6] == 0)
      {
        if(Seek(fh, -i, OFFSET_CURRENT) >= 0)
          start = pos+i;
        ++stop;
      }
    }
    size -= i;
    pos += i;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

/******** exe2cab *********/

BOOL ScanCAB(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0, len = 0, foff;
  LONG i, pos = 0, stop = 0;

  while(size > 20 && !stop)
  {
    if(bufsize > size)
      bufsize = size;
    if(Seek(fh, pos, OFFSET_BEGINNING) < 0)
      ++stop;
    else if(Read(fh, buf, bufsize) != bufsize)
      ++stop;
    for(i = 0; i <= bufsize-20 && !stop; ++i)
    {
      if(buf[i] == 'M' && buf[i+1] == 'S' && buf[i+2] == 'C' && buf[i+3] == 'F')
      {
        len = (buf[i+8]) | (buf[i+9]<<8) | (buf[i+10]<<16) | (buf[i+11]<<24);
        foff = (buf[i+16]) | (buf[i+17]<<8) | (buf[i+18]<<16) | (buf[i+19]<<24);
        if(len <= size-i && foff < len)
        {
          if(Seek(fh, -i, OFFSET_CURRENT) >= 0)
            start = pos+i;
          ++stop;
        }
      }
    }
    size -= i;
    pos += i;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = len;

  return (BOOL) (start ? TRUE : FALSE);
}

ULONG ExtractCAB(BPTR infh, BPTR outfh, STRPTR buf, ULONG filesize, ULONG buffersize)
{
  LONG ret;

  ret = DoCopy(infh, outfh, buf, (filesize = ((ULONG *)buf)[0]), buffersize);
  
  return ret ? 0 : filesize;
}

/******** exe2arj *********/

BOOL ScanARJ(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0, len, cbuf[256], j, k, l;
  LONG i, pos = 0, stop = 0;
  STRPTR mem;

  while(size > 50 && !stop)
  {
    if(bufsize > size)
      bufsize = size;
    if(Seek(fh, pos, OFFSET_BEGINNING) < 0)
      ++stop;
    else if(Read(fh, buf, bufsize) != bufsize)
      ++stop;
    for(i = 0; i <= bufsize-50 && !stop; ++i)
    {
      if(buf[i] == 0x60 && buf[i+1] == 0xEA)
      {
        len = (buf[i+2]) | (buf[i+3]<<8);
        if(size-i > len+4)
        {
          if(bufsize-i < len+4)
            break;
          else
          {
            for(l = 0; l < 256; ++l)
            {
              k = l;

              for(j = 0; j < 8; ++j)
              {
                if(k & 1)
                  k = (k >> 1) ^ 0xEDB88320;
                else
                  k >>= 1;
              }
              cbuf[l] = k;
            }
            l = ~0;
            k = len;
            mem = buf+i+4;

            while(k--)
              l = cbuf[(l ^ *mem++) & 0xFF] ^ (l >> 8);
            if(~l == ((mem[0]) | (mem[1]<<8) | (mem[2]<<16) | (mem[3]<<24)))
            {
              if(Seek(fh, -i, OFFSET_CURRENT) >= 0)
                start = pos+i;
              ++stop;
            }
          }
        }
      }
    }
    size -= i;
    pos += i;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

/******** exe2lha *********/

BOOL ScanLHA(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0;

  if(Read(fh, buf, 100) < 0)
    return 0;
  if(!buf[0] && !buf[1] && buf[2] == 3 && buf[3] == 0xF3 && buf[44] == 'S'
  && buf[45] == 'F' && buf[46] == 'X' && buf[47] == '!')
  {
    start = (buf[55]) | (buf[54]<<8) | (buf[53]<<16) | (buf[52]<<24);
    if(Seek(fh, start, OFFSET_BEGINNING) < 0)
      start = 0;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

/******** exe2lzh *********/

BOOL ScanLZH(BPTR fh, STRPTR buf, ULONG size, ULONG bufsize)
{
  ULONG start = 0;
  LONG i, pos = 0, stop = 0;

  while(size > 21 && !stop)
  {
    if(bufsize > size)
      bufsize = size;
    if(Seek(fh, pos, OFFSET_BEGINNING) < 0)
      ++stop;
    else if(Read(fh, buf, bufsize) != bufsize)
      ++stop;
    for(i = 0; i <= bufsize-21 && !stop; ++i)
    {
      if(buf[i+2] == '-' && buf[i+3] == 'l' && (buf[i+4] == 'h' || buf[i+4] == 'z') &&
      buf[i+6] == '-' && buf[20] <= 2)
      {
        if(Seek(fh, -i, OFFSET_CURRENT) >= 0)
          start = pos+i;
        ++stop;
      }
    }
    size -= i;
    pos += i;
  }

  if(start)
    Seek(fh, start, OFFSET_BEGINNING);
  ((ULONG *)buf)[0] = start;

  return (BOOL) (start ? TRUE : FALSE);
}

/**************************/

struct ScanData ScanFuncs[] = {
{ScanZIP, ExtractZIP, "zip", "Zip"},
{ScanACE, ExtractACE, "ace", "Ace"},
{ScanRAR, ExtractACE, "rar", "Rar"}, /* reuse ExtractACE */
{ScanCAB, ExtractCAB, "cab", "Cabinet"},
{ScanARJ, ExtractACE, "arj", "Arj"}, /* reuse ExtractACE */
{ScanLHA, ExtractACE, "lha", "LhA"}, /* reuse ExtractACE */
{ScanLZH, ExtractACE, "lzh", "Amiga-LhA"}, /* reuse ExtractACE */
{0,0},
};

