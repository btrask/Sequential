#ifndef XADMASTER_LHA_C
#define XADMASTER_LHA_C

/*  $Id: LhA.c,v 1.15 2005/06/23 14:54:41 stoecker Exp $
    LhA file archiver client

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

#include "xadClient.h"
#define XADIOGETBITSHIGH
#define XADIOGETBITSLOW
#include "xadIO.c"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      13
#endif

XADCLIENTVERSTR("LhA 1.13 (21.02.2004)")

#define LHA_VERSION             1
#define LHA_REVISION            13

#define LHASFX_VERSION          LHA_VERSION
#define LHASFX_REVISION         LHA_REVISION
#define LHAC64SFX_VERSION       LHA_VERSION
#define LHAC64SFX_REVISION      LHA_REVISION
#define LHAEXE_VERSION          LHA_VERSION
#define LHAEXE_REVISION         LHA_REVISION
#define ZOO_VERSION             LHA_VERSION
#define ZOO_REVISION            LHA_REVISION
#define ARJ_VERSION             LHA_VERSION
#define ARJ_REVISION            LHA_REVISION
#define ARJEXE_VERSION          LHA_VERSION
#define ARJEXE_REVISION         LHA_REVISION
#define SAVAGE_VERSION          LHA_VERSION
#define SAVAGE_REVISION         LHA_REVISION

#define LZHUFF0_METHOD          0x2D6C6830      /* -lh0- */
#define LZHUFF1_METHOD          0x2D6C6831      /* -lh1- */
#define LZHUFF2_METHOD          0x2D6C6832      /* -lh2- */
#define LZHUFF3_METHOD          0x2D6C6833      /* -lh3- */
#define LZHUFF4_METHOD          0x2D6C6834      /* -lh4- */
#define LZHUFF5_METHOD          0x2D6C6835      /* -lh5- */
#define LZHUFF6_METHOD          0x2D6C6836      /* -lh6- */
#define LZHUFF7_METHOD          0x2D6C6837      /* -lh7- */
#define LZHUFF8_METHOD          0x2D6C6838      /* -lh8- */
#define LARC_METHOD             0x2D6C7A73      /* -lzs- */
#define LARC5_METHOD            0x2D6C7A35      /* -lz5- */
#define LARC4_METHOD            0x2D6C7A34      /* -lz4- */
#define PMARC0_METHOD           0x2D706D30      /* -pm0- */
#define PMARC2_METHOD           0x2D706D32      /* -pm2- */

#define LHAPI(a)        ((struct LhAPrivate *) ((a)->xfi_PrivateInfo))

struct LhAPrivate {
  xadUINT32 Method;
  xadUINT16 CRC;
  xadUINT8 NamePart[6]; /* -xxx-,0 */
};

#define LHABUFFSIZE     10240

XADRECOGDATA(LhA)
{
  return (xadBOOL) (data[2] == '-' && data[6] == '-' &&
  ((data[3] == 'l' && (data[4] == 'z' || data[4] == 'h')) ||
  ((data[3] == 'p' && data[4] == 'm'))));
}

static struct xadFileInfo *LhAParseExt(xadSTRPTR head, struct xadArchiveInfo *ai,
struct xadMasterBase *xadMasterBase)
{
  xadINT32 extsize = 0, nextsize, i;
  xadSTRPTR filename = 0, dirname = 0, comment = 0, groupname = 0, username = 0;
  /* alls sizes include termination char */
  xadSTRPTR filename2 = 0, comment2 = 0;
  xadINT32 namesize = 0, dirsize = 0, commentsize = 0, groupsize = 0, usersize = 0;
  xadUINT32 userid = 0, groupid = 0;
  xadINT32 time = 0, prot, err = 0;
  xadUINT8 buf[128];
  xadSTRPTR buf2 = 0;
  xadUINT8 *bufptr;
  struct xadFileInfo *fi = 0;

  if(head[20] == 1)
    nextsize = EndGetI16(&head[25+head[21]]);
  else
  {
    nextsize = EndGetI16(&head[24]);
    time = EndGetI32(&head[15]);
  }

  prot = head[19];

  while(nextsize && !err)
  {
    extsize += nextsize;
    if(nextsize > 128)
    {
      if(!(buf2 = (xadSTRPTR) (bufptr = (xadUINT8 *) xadAllocVec(XADM (xadUINT32)nextsize, XADMEMF_PUBLIC))))
      {
        err = XADERR_NOMEMORY;
        break;
      }
    }
    else
      bufptr = buf;

    if(!(err = xadHookAccess(XADM XADAC_READ, (xadUINT32) nextsize, bufptr, ai)))
    {
      switch(bufptr[0])
      {
//      case 0x00: /* CRC-16 of header */ break;
      case 0x01: /* Filename */
        if(!filename)
        {
          if((filename = xadAllocVec(XADM (xadUINT32) nextsize-3, XADMEMF_ANY)))
          {
            namesize = nextsize-3+1;
            xadCopyMem(XADM bufptr+1, filename, (xadUINT32) namesize-1);
          }
          else
            err = XADERR_NOMEMORY;
        }
        break;
      case 0x02: /* Directoryname */
        if(!dirname)
        {
          if((dirname = xadAllocVec(XADM (xadUINT32) nextsize-3, XADMEMF_ANY)))
          {
            dirsize = nextsize-3+1;
            xadCopyMem(XADM bufptr+1, dirname, (xadUINT32)dirsize-1);
            if((xadUINT8)dirname[dirsize-2] == 0xFF)
              --dirsize;
          }
          else
            err = XADERR_NOMEMORY;
        }
        break;
      case 0x71:
      case 0x3F: /* Comment */
        if(!comment)
        {
          if((comment = xadAllocVec(XADM (xadUINT32) nextsize-3, XADMEMF_ANY)))
          {
            commentsize = nextsize-3+1;
            xadCopyMem(XADM bufptr+1, comment, (xadUINT32)commentsize-1);
          }
          else
            err = XADERR_NOMEMORY;
        }
        break;
      case 0x50: /* File permission */
        xadConvertProtection(XADM XAD_PROTUNIX, EndGetI16(&bufptr[1]), XAD_GETPROTAMIGA,
        &prot, TAG_DONE);
        break;
      case 0x51: /* ID's */
        groupid = EndGetI16(&bufptr[1]);
        userid = EndGetI16(&bufptr[3]);
        break;
      case 0x52: /* Group Name */
        if(!groupname)
        {
          if((groupname = xadAllocVec(XADM (xadUINT32) nextsize-3, XADMEMF_ANY)))
          {
            groupsize = nextsize-3+1;
            xadCopyMem(XADM bufptr+1, groupname, (xadUINT32) groupsize-1);
          }
          else
            err = XADERR_NOMEMORY;
        }
        break;
      case 0x53: /* User Name */
        if(!username)
        {
          if((username = xadAllocVec(XADM (xadUINT32) nextsize-3, XADMEMF_ANY)))
          {
            usersize = nextsize-3+1;
            xadCopyMem(XADM bufptr+1, username, (xadUINT32)usersize-1);
          }
          else
            err = XADERR_NOMEMORY;
        }
        break;
      case 0x54: /* Time stamp */
        time = EndGetI32(&bufptr[1]);
        break;
      }
    }
    nextsize = EndGetI16(&bufptr[nextsize-2]);
    if(buf2)
    {
      xadFreeObjectA(XADM buf2, 0);
      buf2 = 0;
    }
  }

  if(!filename && head[20] == 1 && head[21])
  {
    namesize = head[21];
    filename2 = head + 22;

    for(i = 0; i < namesize; ++i)
    {
      if(!filename2[i])
      {
        namesize = i+1;
        if(!comment)
        {
          commentsize = head[21]-i-1+1;
          comment2 = filename2+i+1;
        }
      }
    }
    ++namesize;
  }

  if(!err)
  {
    if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
    XAD_OBJNAMESIZE, namesize+dirsize, commentsize ? XAD_OBJCOMMENTSIZE :
    TAG_IGNORE, commentsize, XAD_OBJPRIVINFOSIZE, sizeof(struct LhAPrivate)
    + groupsize + usersize, TAG_DONE)))
    {
      fi->xfi_Protection = prot;
      if(time)
        xadConvertDates(XADM XAD_DATEUNIX, time, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
      else
        xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(&head[15]),
        XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

      fi->xfi_OwnerUID = userid;
      fi->xfi_OwnerGID = groupid;
      if(groupname)
      {
        fi->xfi_GroupName = ((xadSTRPTR) fi->xfi_PrivateInfo)+sizeof(struct LhAPrivate);
        xadCopyMem(XADM groupname, fi->xfi_GroupName, groupsize-1);
      }
      if(username)
      {
        fi->xfi_UserName = ((xadSTRPTR) fi->xfi_PrivateInfo)+sizeof(struct LhAPrivate)+groupsize;
        xadCopyMem(XADM username, fi->xfi_UserName, usersize-1);
      }
      if(comment)
        xadCopyMem(XADM comment, fi->xfi_Comment, commentsize-1);
      else if(comment2)
        xadCopyMem(XADM comment2, fi->xfi_Comment, commentsize-1);
      if(!filename && !filename2)
      {
        xadCopyMem(XADM dirname, fi->xfi_FileName, dirsize-1);
        fi->xfi_Flags |= XADFIF_DIRECTORY;
      }
      else
      {
        if(dirname)
        {
          xadCopyMem(XADM dirname, fi->xfi_FileName, dirsize-1);
          fi->xfi_FileName[dirsize-1] = '/';
        }
        if(filename)
          xadCopyMem(XADM filename, fi->xfi_FileName+dirsize, namesize-1);
        else if(filename2)
          xadCopyMem(XADM filename2, fi->xfi_FileName+dirsize, namesize-1);
      }
      for(filename2 = fi->xfi_FileName; *filename2; ++filename2)
      {
        if((xadUINT8)*filename2 == '\\' || (xadUINT8)*filename2 == 0xFF)
          *filename2 = '/';
        else if((*filename2&0x7F) <= 0x20 || *filename2 == 0x7F)
          *filename2 = '_';
      }
      fi->xfi_Size = EndGetI32(&head[11]);
      fi->xfi_CrunchSize = EndGetI32(&head[7]) - (head[20] == 1 ? extsize : 0);
      fi->xfi_DataPos = ai->xai_InPos;
      fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
      if(head[20] == 1)
        LHAPI(fi)->CRC = EndGetI16(&head[22+head[21]]);
      else
        LHAPI(fi)->CRC = EndGetI16(&head[21]);
      xadCopyMem(XADM head+2, LHAPI(fi)->NamePart, 5); /* 0 byte already there! */
      fi->xfi_EntryInfo = (xadSTRPTR) LHAPI(fi)->NamePart;
      LHAPI(fi)->Method = EndGetM32(head+2);
      if(!fi->xfi_FileName[0])
      {
        fi->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai, XAD_EXTENSION,
        ".lha", XAD_EXTENSION, ".lzh", TAG_DONE);
        fi->xfi_Flags |= XADFIF_NOFILENAME|XADFIF_XADSTRFILENAME;
      }
    }
    else
      err = XADERR_NOMEMORY;
  }
  if(username)          xadFreeObjectA(XADM username, 0);
  if(groupname)         xadFreeObjectA(XADM groupname, 0);
  if(filename)          xadFreeObjectA(XADM filename, 0);
  if(dirname)           xadFreeObjectA(XADM dirname, 0);
  if(comment)           xadFreeObjectA(XADM comment, 0);

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return fi;
}

static xadINT32 LhAScanNext(xadUINT32 *lastpos, struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadINT32 i, err = 0, found = 0;
  xadSTRPTR buf;
  xadUINT32 bufsize, fsize, spos = 0;

  if((fsize = ai->xai_InSize-*lastpos) < 15)
    return 0;

  if((i = *lastpos - ai->xai_InPos))
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai)))
      return err;

  if((bufsize = LHABUFFSIZE) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && !found && fsize >= 15)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
    {
      for(i = 0; i < bufsize - 5 && !found; ++i)
      {
        if(buf[i] == '-' && buf[i+1] == 'l' && buf[i+4] == '-')
          found = 1;
      }
      if(!found)
      {
        xadCopyMem(XADM buf+i, buf, 5);
        spos = 5;
        fsize -= bufsize - 5;
        if(fsize < bufsize)
          bufsize = fsize;
      }
    }
  }

  xadFreeObjectA(XADM buf, 0);

  if(found)
  {
    err = xadHookAccess(XADM XADAC_INPUTSEEK, i-1-bufsize-2, 0, ai);
    *lastpos = ai->xai_InPos + 5;
  }

  return err;
}

XADGETINFO(LhA)
{
  struct xadFileInfo *fi;
  xadINT32 err = 0;
  xadUINT32 lastokpos = 0;
  xadUINT8 buf[258];

  while(ai->xai_InPos + 21 < ai->xai_InSize && !err)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 21, buf, ai)))
    {
      if(buf[0] == 0)
        break;
      if(buf[2] != '-' || buf[6] != '-' || (buf[3] != 'l' && buf[3] != 'p'))
        err = XADERR_ILLEGALDATA;
      else
      {
        lastokpos = ai->xai_InPos - 21 + 7; /* position after header text */
        switch(buf[20])
        {
        case 0:
          if(!(err = xadHookAccess(XADM XADAC_READ, buf[0]-21+2, buf+21, ai)))
          {
            xadINT32 i, fs, cs = 0;
            xadUINT8 j = 0;

            for(i = 0; i < buf[0]; ++i)
              j += buf[2+i];

            fs = buf[21];
            for(i = 0; i < fs; ++i)
            {
              if(buf[22+i] == '\\')
                buf[22+i] = '/';
              else if(!buf[22+i])
              {
                fs = i;
                cs = buf[21]-i-1;
              }
            }

            if(j != buf[1])
              err = XADERR_CHECKSUM;
            else if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
            XAD_OBJNAMESIZE, fs+1, cs ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, cs+1,
            XAD_OBJPRIVINFOSIZE, sizeof(struct LhAPrivate), TAG_DONE)))
              err = XADERR_NOMEMORY;
            else
            {
              if(cs)
                xadCopyMem(XADM buf+22+fs+1, fi->xfi_Comment, cs);
              if(buf[22+fs-1] == '/' || buf[22+fs-1] == 0xFF || buf[22+fs-1] == '\\')
              {
                fi->xfi_Flags |= XADFIF_DIRECTORY;
                --fs;
              }
              xadCopyMem(XADM buf+22, fi->xfi_FileName, fs);
              if(!fs)
              {
                fi->xfi_FileName = xadGetDefaultName(XADM XAD_ARCHIVEINFO, ai,
                XAD_EXTENSION, ".lha", XAD_EXTENSION, ".lzh", TAG_DONE);
                fi->xfi_Flags |= XADFIF_NOFILENAME|XADFIF_XADSTRFILENAME;
              }
              xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(&buf[15]),
              XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
              fi->xfi_Size = EndGetI32(&buf[11]);
              fi->xfi_CrunchSize = EndGetI32(&buf[7]);
              fi->xfi_Protection = buf[19];
              fi->xfi_DataPos = ai->xai_InPos;
              fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
              LHAPI(fi)->CRC = EndGetI16(&buf[22+buf[21]]);
              xadCopyMem(XADM buf+2, LHAPI(fi)->NamePart, 5); /* 0 byte already there! */
              fi->xfi_EntryInfo = (xadSTRPTR) LHAPI(fi)->NamePart;
              LHAPI(fi)->Method = EndGetM32(buf+2);
#ifdef DEBUG
  if(LHAPI(fi)->Method == LZHUFF2_METHOD || LHAPI(fi)->Method == LZHUFF3_METHOD || LHAPI(fi)->Method == LZHUFF7_METHOD ||
  LHAPI(fi)->Method == LZHUFF8_METHOD || LHAPI(fi)->Method == LARC_METHOD)
  {
    DebugFileSearched(ai, "Unknown or untested compression method %ld.",
    LHAPI(fi)->Method);
  }
#endif

              if(buf[4] == 'h' && buf[5] == 'd')
                fi->xfi_Flags |= XADFIF_DIRECTORY;

              for(i = 0; fi->xfi_FileName[i]; ++i)
              {
                if((xadUINT8)fi->xfi_FileName[i] == 0xFF || (xadUINT8)fi->xfi_FileName[i] == '\\')
                  fi->xfi_FileName[i] = '/';
                if((fi->xfi_FileName[i]&0x7F) < 0x20 || fi->xfi_FileName[i] == 0x7F)
                  fi->xfi_FileName[i] = '_';
              }

              if(fi->xfi_Comment && (fi->xfi_Comment[0] == 'S' || fi->xfi_Comment[0] == 'U' ||
              fi->xfi_Comment[0] == 'P') && !fi->xfi_Comment[1])
              {
                if((fi->xfi_Special = xadAllocObjectA(XADM XADOBJ_SPECIAL, 0)))
                {
                  fi->xfi_Special->xfis_Type = XADSPECIALTYPE_CBM8BIT;
                  switch(fi->xfi_Comment[0])
                  {
                  case 'P': fi->xfi_Special->xfis_Data.xfis_CBM8bit.xfis_FileType = XADCBM8BITTYPE_PRG; break;
                  case 'S': fi->xfi_Special->xfis_Data.xfis_CBM8bit.xfis_FileType = XADCBM8BITTYPE_SEQ; break;
                  case 'U': fi->xfi_Special->xfis_Data.xfis_CBM8bit.xfis_FileType = XADCBM8BITTYPE_USR; break;
                  }
                }
              }

              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
            }
          }
          break;
        case 1:
          if(!(err = xadHookAccess(XADM XADAC_READ, buf[0]-21+2, buf+21, ai)))
          {
            xadINT32 i;
            xadUINT8 j = 0;

            for(i = 0; i < buf[0]; ++i)
              j += buf[2+i];

            if(j != buf[1])
              err = XADERR_CHECKSUM;
            else if(!(fi = LhAParseExt((xadSTRPTR)buf, ai, xadMasterBase)))
              err = ai->xai_LastError;
            else
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
          }
          break;
        case 2:
          if(!(err = xadHookAccess(XADM XADAC_READ, 5, buf+21, ai)))
          {
            if(!(fi = LhAParseExt((xadSTRPTR)buf, ai, xadMasterBase)))
              err = ai->xai_LastError;
            else
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
          }
          break;
        default:
          err = XADERR_DATAFORMAT;
          break;
        }
      }
    }

    if(err && err != XADERR_BREAK)
    {
      ai->xai_Flags |= XADAIF_FILECORRUPT;
      ai->xai_LastError = err;
      err = LhAScanNext(&lastokpos, ai, xadMasterBase);
    }
  }

  if(!err)
    err = ai->xai_LastError;

  return (ai->xai_FileInfo ? 0 : err);
}

/* ------------------------------------------------------------------------ */

#define UCHAR_MAX       ((1<<(sizeof(xadUINT8)*8))-1)
#define MAX_DICBIT      16
#define CHAR_BIT        8
#define USHRT_BIT       16              /* (CHAR_BIT * sizeof(ushort)) */
#define MAXMATCH        256             /* not more than UCHAR_MAX + 1 */
#define NC              (UCHAR_MAX + MAXMATCH + 2 - THRESHOLD)
#define THRESHOLD       3               /* choose optimal value */
#define NPT             0x80
#define CBIT            9               /* $\lfloor \log_2 NC \rfloor + 1$ */
#define TBIT            5               /* smallest integer such that (1 << TBIT) > * NT */
#define NT              (USHRT_BIT + 3)
#define N_CHAR          (256 + 60 - THRESHOLD + 1)
#define TREESIZE_C      (N_CHAR * 2)
#define TREESIZE_P      (128 * 2)
#define TREESIZE        (TREESIZE_C + TREESIZE_P)
#define ROOT_C          0
#define ROOT_P          TREESIZE_C
#define N1              286             /* alphabet size */
#define EXTRABITS       8               /* >= log2(F-THRESHOLD+258-N1) */
#define BUFBITS         16              /* >= log2(MAXBUF) */
#define NP              (MAX_DICBIT + 1)
#define LENFIELD        4               /* bit size of length field for tree output */
#define MAGIC0          18
#define MAGIC5          19

#define PMARC2_OFFSET (0x100 - 2)
struct PMARC2_Tree {
  xadUINT8 *leftarr;
  xadUINT8 *rightarr;
  xadUINT8 root;
};

struct LhADecrST {
  xadINT32              pbit;
  xadINT32              np;
  xadINT32              nn;
  xadINT32              n1;
  xadINT32              most_p;
  xadINT32              avail;
  xadUINT32             n_max;
  xadUINT16             maxmatch;
  xadUINT16     total_p;
  xadUINT16             blocksize;
  xadUINT16             c_table[4096];
  xadUINT16             pt_table[256];
  xadUINT16             left[2 * NC - 1];
  xadUINT16             right[2 * NC - 1];
  xadUINT16             freq[TREESIZE];
  xadUINT16             pt_code[NPT];
  xadINT16              child[TREESIZE];
  xadINT16              stock[TREESIZE];
  xadINT16              s_node[TREESIZE / 2];
  xadINT16              block[TREESIZE];
  xadINT16              parent[TREESIZE];
  xadINT16              edge[TREESIZE];
  xadUINT8              c_len[NC];
  xadUINT8              pt_len[NPT];
};

struct LhADecrPM {
  struct PMARC2_Tree tree1;
  struct PMARC2_Tree tree2;

  xadUINT16         lastupdate;
  xadUINT16         dicsiz1;
  xadUINT8         gettree1;
  xadUINT8         tree1left[32];
  xadUINT8         tree1right[32];
  xadUINT8         table1[32];

  xadUINT8         tree2left[8];
  xadUINT8         tree2right[8];
  xadUINT8         table2[8];

  xadUINT8         tree1bound;
  xadUINT8         mindepth;

  /* Circular double-linked list. */
  xadUINT8         prev[0x100];
  xadUINT8         next[0x100];
  xadUINT8         parentarr[0x100];
  xadUINT8         lastbyte;
};

struct LhADecrLZ {
  xadINT32              matchpos;               /* LARC */
  xadINT32              flag;                   /* LARC */
  xadINT32              flagcnt;                /* LARC */
};

struct LhADecrData {
  struct xadInOut *io;
  xadSTRPTR        text;
  xadUINT16             DicBit;

  xadUINT16             bitbuf;
  xadUINT8      subbitbuf;
  xadUINT8      bitcount;
  xadUINT32             loc;
  xadUINT32             count;
  xadUINT32             nextcount;

  union {
    struct LhADecrST st;
    struct LhADecrPM pm;
    struct LhADecrLZ lz;
  } d;
};

static void LHAfillbuf(struct LhADecrData *dat, xadUINT8 n) /* Shift bitbuf n bits left, read n bits */
{
  if(dat->io->xio_Error)
    return;

  while(n > dat->bitcount)
  {
    n -= dat->bitcount;
    dat->bitbuf = (dat->bitbuf << dat->bitcount) + (dat->subbitbuf >> (CHAR_BIT - dat->bitcount));
    dat->subbitbuf = xadIOGetChar(dat->io);
    dat->bitcount = CHAR_BIT;
  }
  dat->bitcount -= n;
  dat->bitbuf = (dat->bitbuf << n) + (dat->subbitbuf >> (CHAR_BIT - n));
  dat->subbitbuf <<= n;
}

static xadUINT16 LHAgetbits(struct LhADecrData *dat, xadUINT8 n)
{
  xadUINT16 x;

  x = dat->bitbuf >> (2 * CHAR_BIT - n);
  LHAfillbuf(dat, n);
  return x;
}

#define LHAinit_getbits(a)      LHAfillbuf((a), 2* CHAR_BIT)
/* this function can be replaced by a define!
static void LHAinit_getbits(struct LhADecrData *dat)
{
//  dat->bitbuf = 0;
//  dat->subbitbuf = 0;
//  dat->bitcount = 0;
  LHAfillbuf(dat, 2 * CHAR_BIT);
}
*/

/* ------------------------------------------------------------------------ */

static void LHAmake_table(struct LhADecrData *dat, xadINT16 nchar, xadUINT8 bitlen[], xadINT16 tablebits, xadUINT16 table[])
{
  xadUINT16 count[17];  /* count of bitlen */
  xadUINT16 weight[17]; /* 0x10000ul >> bitlen */
  xadUINT16 start[17];  /* first code of bitlen */
  xadUINT16 total;
  xadUINT32 i;
  xadINT32  j, k, l, m, n, avail;
  xadUINT16 *p;

  if(dat->io->xio_Error)
    return;

  avail = nchar;

  memset(count, 0, 17*2);
  for(i = 1; i <= 16; i++)
    weight[i] = 1 << (16 - i);

  /* count */
  for(i = 0; i < nchar; i++)
    count[bitlen[i]]++;

  /* calculate first code */
  total = 0;
  for(i = 1; i <= 16; i++)
  {
    start[i] = total;
    total += weight[i] * count[i];
  }
  if(total & 0xFFFF)
  {
    dat->io->xio_Error = XADERR_ILLEGALDATA;
    dat->io->xio_Flags |= XADIOF_ERROR;
    return;
  }

  /* shift data for make table. */
  m = 16 - tablebits;
  for(i = 1; i <= tablebits; i++) {
    start[i] >>= m;
    weight[i] >>= m;
  }

  /* initialize */
  j = start[tablebits + 1] >> m;
  k = 1 << tablebits;
  if(j != 0)
    for(i = j; i < k; i++)
      table[i] = 0;

  /* create table and tree */
  for(j = 0; j < nchar; j++)
  {
    k = bitlen[j];
    if(k == 0)
      continue;
    l = start[k] + weight[k];
    if(k <= tablebits)
    {
      /* code in table */
      for(i = start[k]; i < l; i++)
        table[i] = j;
    }
    else
    {
      /* code not in table */
      p = &table[(i = start[k]) >> m];
      i <<= tablebits;
      n = k - tablebits;
      /* make tree (n length) */
      while(--n >= 0)
      {
        if(*p == 0)
        {
          dat->d.st.right[avail] = dat->d.st.left[avail] = 0;
          *p = avail++;
        }
        if(i & 0x8000)
          p = &dat->d.st.right[*p];
        else
          p = &dat->d.st.left[*p];
        i <<= 1;
      }
      *p = j;
    }
    start[k] = l;
  }
}

/* ------------------------------------------------------------------------ */

static void LHAread_pt_len(struct LhADecrData *dat, xadINT16 nn, xadINT16 nbit, xadINT16 i_special)
{
  xadINT16 i, c, n;

  if(!(n = LHAgetbits(dat, nbit)))
  {
    c = LHAgetbits(dat, nbit);
    for(i = 0; i < nn; i++)
      dat->d.st.pt_len[i] = 0;
    for(i = 0; i < 256; i++)
      dat->d.st.pt_table[i] = c;
  }
  else
  {
    i = 0;
    while(i < n)
    {
      c = dat->bitbuf >> (16 - 3);
      if(c == 7)
      {
        xadUINT16 mask;

        mask = 1 << (16 - 4);
        while(mask & dat->bitbuf)
        {
          mask >>= 1;
          c++;
        }
      }
      LHAfillbuf(dat, (c < 7) ? 3 : c - 3);
      dat->d.st.pt_len[i++] = c;
      if(i == i_special)
      {
        c = LHAgetbits(dat, 2);
        while(--c >= 0)
          dat->d.st.pt_len[i++] = 0;
      }
    }
    while(i < nn)
      dat->d.st.pt_len[i++] = 0;
    LHAmake_table(dat, nn, dat->d.st.pt_len, 8, dat->d.st.pt_table);
  }
}

static void LHAread_c_len(struct LhADecrData *dat)
{
  xadINT16 i, c, n;

  if(!(n = LHAgetbits(dat, CBIT)))
  {
    c = LHAgetbits(dat, CBIT);
    for(i = 0; i < NC; i++)
      dat->d.st.c_len[i] = 0;
    for(i = 0; i < 4096; i++)
      dat->d.st.c_table[i] = c;
  }
  else
  {
    i = 0;
    while(i < n)
    {
      c = dat->d.st.pt_table[dat->bitbuf >> (16 - 8)];
      if(c >= NT)
      {
        xadUINT16 mask;

        mask = 1 << (16 - 9);
        do
        {
          if(dat->bitbuf & mask)
            c = dat->d.st.right[c];
          else
            c = dat->d.st.left[c];
          mask >>= 1;
        } while(c >= NT);
      }
      LHAfillbuf(dat, dat->d.st.pt_len[c]);
      if(c <= 2)
      {
        if(!c)
          c = 1;
        else if(c == 1)
          c = LHAgetbits(dat, 4) + 3;
        else
          c = LHAgetbits(dat, CBIT) + 20;
        while(--c >= 0)
          dat->d.st.c_len[i++] = 0;
      }
      else
        dat->d.st.c_len[i++] = c - 2;
    }
    while(i < NC)
      dat->d.st.c_len[i++] = 0;
    LHAmake_table(dat, NC, dat->d.st.c_len, 12, dat->d.st.c_table);
  }
}

static xadUINT16 LHAdecode_c_st1(struct LhADecrData *dat)
{
  xadUINT16 j, mask;

  if(!dat->d.st.blocksize)
  {
    dat->d.st.blocksize = LHAgetbits(dat, 16);
    LHAread_pt_len(dat, NT, TBIT, 3);
    LHAread_c_len(dat);
    LHAread_pt_len(dat, dat->d.st.np, dat->d.st.pbit, -1);
  }
  dat->d.st.blocksize--;
  j = dat->d.st.c_table[dat->bitbuf >> 4];
  if(j < NC)
    LHAfillbuf(dat, dat->d.st.c_len[j]);
  else
  {
    LHAfillbuf(dat, 12);
    mask = 1 << (16 - 1);
    do
    {
      if(dat->bitbuf & mask)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      mask >>= 1;
    } while(j >= NC);
    LHAfillbuf(dat, dat->d.st.c_len[j] - 12);
  }
  return j;
}

static xadUINT16 LHAdecode_p_st1(struct LhADecrData *dat)
{
  xadUINT16 j, mask;

  j = dat->d.st.pt_table[dat->bitbuf >> (16 - 8)];
  if(j < dat->d.st.np)
    LHAfillbuf(dat, dat->d.st.pt_len[j]);
  else
  {
    LHAfillbuf(dat, 8);
    mask = 1 << (16 - 1);
    do
    {
      if(dat->bitbuf & mask)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      mask >>= 1;
    } while(j >= dat->d.st.np);
    LHAfillbuf(dat, dat->d.st.pt_len[j] - 8);
  }
  if(j)
    j = (1 << (j - 1)) + LHAgetbits(dat, j - 1);
  return j;
}

static void LHAdecode_start_st1(struct LhADecrData *dat)
{
  if(dat->DicBit <= 13)
  {
    dat->d.st.np = 14;
    dat->d.st.pbit = 4;
  }
  else
  {
    if(dat->DicBit == 16)
      dat->d.st.np = 17; /* for -lh7- */
    else
      dat->d.st.np = 16;
    dat->d.st.pbit = 5;
  }
  LHAinit_getbits(dat);
//  dat->d.st.blocksize = 0; /* done automatically */
}

/* ------------------------------------------------------------------------ */

static void LHAstart_p_dyn(struct LhADecrData *dat)
{
  dat->d.st.freq[ROOT_P] = 1;
  dat->d.st.child[ROOT_P] = ~(N_CHAR);
  dat->d.st.s_node[N_CHAR] = ROOT_P;
  dat->d.st.edge[dat->d.st.block[ROOT_P] = dat->d.st.stock[dat->d.st.avail++]] = ROOT_P;
  dat->d.st.most_p = ROOT_P;
  dat->d.st.total_p = 0;
  dat->d.st.nn = 1 << dat->DicBit;
  dat->nextcount = 64;
}

static void LHAstart_c_dyn(struct LhADecrData *dat)
{
  xadINT32 i, j, f;

  dat->d.st.n1 = (dat->d.st.n_max >= 256 + dat->d.st.maxmatch - THRESHOLD + 1) ? 512 : dat->d.st.n_max - 1;
  for(i = 0; i < TREESIZE_C; i++)
  {
    dat->d.st.stock[i] = i;
    dat->d.st.block[i] = 0;
  }
  for(i = 0, j = dat->d.st.n_max * 2 - 2; i < (xadINT32) dat->d.st.n_max; i++, j--)
  {
    dat->d.st.freq[j] = 1;
    dat->d.st.child[j] = ~i;
    dat->d.st.s_node[i] = j;
    dat->d.st.block[j] = 1;
  }
  dat->d.st.avail = 2;
  dat->d.st.edge[1] = dat->d.st.n_max - 1;
  i = dat->d.st.n_max * 2 - 2;
  while(j >= 0)
  {
    f = dat->d.st.freq[j] = dat->d.st.freq[i] + dat->d.st.freq[i - 1];
    dat->d.st.child[j] = i;
    dat->d.st.parent[i] = dat->d.st.parent[i - 1] = j;
    if(f == dat->d.st.freq[j + 1])
    {
      dat->d.st.edge[dat->d.st.block[j] = dat->d.st.block[j + 1]] = j;
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[j] = dat->d.st.stock[dat->d.st.avail++]] = j;
    }
    i -= 2;
    j--;
  }
}

static void LHAdecode_start_dyn(struct LhADecrData *dat)
{
  dat->d.st.n_max = 286;
  dat->d.st.maxmatch = MAXMATCH;
  LHAinit_getbits(dat);
  LHAstart_c_dyn(dat);
  LHAstart_p_dyn(dat);
}
static void LHAreconst(struct LhADecrData *dat, xadINT32 start, xadINT32 end)
{
  xadINT32  i, j, k, l, b = 0;
  xadUINT32 f, g;

  for(i = j = start; i < end; i++)
  {
    if((k = dat->d.st.child[i]) < 0)
    {
      dat->d.st.freq[j] = (dat->d.st.freq[i] + 1) / 2;
      dat->d.st.child[j] = k;
      j++;
    }
    if(dat->d.st.edge[b = dat->d.st.block[i]] == i)
    {
      dat->d.st.stock[--dat->d.st.avail] = b;
    }
  }
  j--;
  i = end - 1;
  l = end - 2;
  while(i >= start)
  {
    while(i >= l)
    {
      dat->d.st.freq[i] = dat->d.st.freq[j];
      dat->d.st.child[i] = dat->d.st.child[j];
      i--, j--;
    }
    f = dat->d.st.freq[l] + dat->d.st.freq[l + 1];
    for(k = start; f < dat->d.st.freq[k]; k++)
      ;
    while(j >= k)
    {
      dat->d.st.freq[i] = dat->d.st.freq[j];
      dat->d.st.child[i] = dat->d.st.child[j];
      i--, j--;
    }
    dat->d.st.freq[i] = f;
    dat->d.st.child[i] = l + 1;
    i--;
    l -= 2;
  }
  f = 0;
  for(i = start; i < end; i++)
  {
    if((j = dat->d.st.child[i]) < 0)
      dat->d.st.s_node[~j] = i;
    else
      dat->d.st.parent[j] = dat->d.st.parent[j - 1] = i;
    if((g = dat->d.st.freq[i]) == f) {
      dat->d.st.block[i] = b;
    }
    else
    {
      dat->d.st.edge[b = dat->d.st.block[i] = dat->d.st.stock[dat->d.st.avail++]] = i;
      f = g;
    }
  }
}

static xadINT32 LHAswap_inc(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 b, q, r, s;

  b = dat->d.st.block[p];
  if((q = dat->d.st.edge[b]) != p)
  { /* swap for leader */
    r = dat->d.st.child[p];
    s = dat->d.st.child[q];
    dat->d.st.child[p] = s;
    dat->d.st.child[q] = r;
    if(r >= 0)
      dat->d.st.parent[r] = dat->d.st.parent[r - 1] = q;
    else
      dat->d.st.s_node[~r] = q;
    if(s >= 0)
      dat->d.st.parent[s] = dat->d.st.parent[s - 1] = p;
    else
      dat->d.st.s_node[~s] = p;
    p = q;
    dat->d.st.edge[b]++;
    if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
    {
      dat->d.st.block[p] = dat->d.st.block[p - 1];
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[p] = dat->d.st.stock[dat->d.st.avail++]] = p;  /* create block */
    }
  }
  else if(b == dat->d.st.block[p + 1])
  {
    dat->d.st.edge[b]++;
    if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
    {
      dat->d.st.block[p] = dat->d.st.block[p - 1];
    }
    else
    {
      dat->d.st.edge[dat->d.st.block[p] = dat->d.st.stock[dat->d.st.avail++]] = p;  /* create block */
    }
  }
  else if(++dat->d.st.freq[p] == dat->d.st.freq[p - 1])
  {
    dat->d.st.stock[--dat->d.st.avail] = b; /* delete block */
    dat->d.st.block[p] = dat->d.st.block[p - 1];
  }
  return dat->d.st.parent[p];
}

static void LHAupdate_p(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q;

  if(dat->d.st.total_p == 0x8000)
  {
    LHAreconst(dat, ROOT_P, dat->d.st.most_p + 1);
    dat->d.st.total_p = dat->d.st.freq[ROOT_P];
    dat->d.st.freq[ROOT_P] = 0xffff;
  }
  q = dat->d.st.s_node[p + N_CHAR];
  while(q != ROOT_P)
  {
    q = LHAswap_inc(dat, q);
  }
  dat->d.st.total_p++;
}

static void LHAmake_new_node(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q, r;

  r = dat->d.st.most_p + 1;
  q = r + 1;
  dat->d.st.s_node[~(dat->d.st.child[r] = dat->d.st.child[dat->d.st.most_p])] = r;
  dat->d.st.child[q] = ~(p + N_CHAR);
  dat->d.st.child[dat->d.st.most_p] = q;
  dat->d.st.freq[r] = dat->d.st.freq[dat->d.st.most_p];
  dat->d.st.freq[q] = 0;
  dat->d.st.block[r] = dat->d.st.block[dat->d.st.most_p];
  if(dat->d.st.most_p == ROOT_P)
  {
    dat->d.st.freq[ROOT_P] = 0xffff;
    dat->d.st.edge[dat->d.st.block[ROOT_P]]++;
  }
  dat->d.st.parent[r] = dat->d.st.parent[q] = dat->d.st.most_p;
  dat->d.st.edge[dat->d.st.block[q] = dat->d.st.stock[dat->d.st.avail++]] =
  dat->d.st.s_node[p + N_CHAR] = dat->d.st.most_p = q;
  LHAupdate_p(dat, p);
}

static void LHAupdate_c(struct LhADecrData *dat, xadINT32 p)
{
  xadINT32 q;

  if(dat->d.st.freq[ROOT_C] == 0x8000)
  {
    LHAreconst(dat, 0, (xadINT32) dat->d.st.n_max * 2 - 1);
  }
  dat->d.st.freq[ROOT_C]++;
  q = dat->d.st.s_node[p];
  do
  {
    q = LHAswap_inc(dat, q);
  } while(q != ROOT_C);
}

static xadUINT16 LHAdecode_c_dyn(struct LhADecrData *dat)
{
  xadINT32 c;
  xadINT16 buf, cnt;

  c = dat->d.st.child[ROOT_C];
  buf = dat->bitbuf;
  cnt = 0;
  do
  {
    c = dat->d.st.child[c - (buf < 0)];
    buf <<= 1;
    if(++cnt == 16)
    {
      LHAfillbuf(dat, 16);
      buf = dat->bitbuf;
      cnt = 0;
    }
  } while(c > 0);
  LHAfillbuf(dat, cnt);
  c = ~c;
  LHAupdate_c(dat, c);
  if(c == dat->d.st.n1)
    c += LHAgetbits(dat, 8);
  return (xadUINT16) c;
}

static xadUINT16 LHAdecode_p_dyn(struct LhADecrData *dat)
{
  xadINT32 c;
  xadINT16 buf, cnt;

  while(dat->count > dat->nextcount)
  {
    LHAmake_new_node(dat, (xadINT32) dat->nextcount / 64);
    if((dat->nextcount += 64) >= (xadUINT32)dat->d.st.nn)
      dat->nextcount = 0xffffffff;
  }
  c = dat->d.st.child[ROOT_P];
  buf = dat->bitbuf;
  cnt = 0;
  while(c > 0)
  {
    c = dat->d.st.child[c - (buf < 0)];
    buf <<= 1;
    if(++cnt == 16)
    {
      LHAfillbuf(dat, 16);
      buf = dat->bitbuf;
      cnt = 0;
    }
  }
  LHAfillbuf(dat, cnt);
  c = (~c) - N_CHAR;
  LHAupdate_p(dat, c);

  return (xadUINT16) ((c << 6) + LHAgetbits(dat, 6));
}


/* ------------------------------------------------------------------------ */

static const xadINT32 LHAfixed[2][16] = {
  {3, 0x01, 0x04, 0x0c, 0x18, 0x30, 0}, /* old compatible */
  {2, 0x01, 0x01, 0x03, 0x06, 0x0D, 0x1F, 0x4E, 0}  /* 8K buf */
};

static void LHAready_made(struct LhADecrData *dat, xadINT32 method)
{
  xadINT32  i, j;
  xadUINT32 code, weight;
  xadINT32 *tbl;

  tbl = (xadINT32 *) LHAfixed[method];
  j = *tbl++;
  weight = 1 << (16 - j);
  code = 0;
  for(i = 0; i < dat->d.st.np; i++)
  {
    while(*tbl == i)
    {
      j++;
      tbl++;
      weight >>= 1;
    }
    dat->d.st.pt_len[i] = j;
    dat->d.st.pt_code[i] = code;
    code += weight;
  }
}

static void LHAdecode_start_fix(struct LhADecrData *dat)
{
  dat->d.st.n_max = 314;
  dat->d.st.maxmatch = 60;
  LHAinit_getbits(dat);
  dat->d.st.np = 1 << (12 - 6);
  LHAstart_c_dyn(dat);
  LHAready_made(dat, 0);
  LHAmake_table(dat, dat->d.st.np, dat->d.st.pt_len, 8, dat->d.st.pt_table);
}

static xadUINT16 LHAdecode_p_st0(struct LhADecrData *dat)
{
  xadINT32 i, j;

  j = dat->d.st.pt_table[dat->bitbuf >> 8];
  if(j < dat->d.st.np)
  {
    LHAfillbuf(dat, dat->d.st.pt_len[j]);
  }
  else
  {
    LHAfillbuf(dat, 8);
    i = dat->bitbuf;
    do
    {
      if((xadINT16) i < 0)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      i <<= 1;
    } while(j >= dat->d.st.np);
    LHAfillbuf(dat, dat->d.st.pt_len[j] - 8);
  }
  return (xadUINT16)((j << 6) + LHAgetbits(dat, 6));
}

static void LHAdecode_start_st0(struct LhADecrData *dat)
{
  dat->d.st.n_max = 286;
  dat->d.st.maxmatch = MAXMATCH;
  LHAinit_getbits(dat);
  dat->d.st.np = 1 << (MAX_DICBIT - 6);
}

static void LHAread_tree_c(struct LhADecrData *dat) /* read tree from file */
{
  xadINT32 i, c;

  i = 0;
  while(i < N1)
  {
    if(LHAgetbits(dat, 1))
      dat->d.st.c_len[i] = LHAgetbits(dat, LENFIELD) + 1;
    else
      dat->d.st.c_len[i] = 0;
    if(++i == 3 && dat->d.st.c_len[0] == 1 && dat->d.st.c_len[1] == 1 && dat->d.st.c_len[2] == 1)
    {
      c = LHAgetbits(dat, CBIT);
      memset(dat->d.st.c_len, 0, N1);
      for(i = 0; i < 4096; i++)
        dat->d.st.c_table[i] = c;
      return;
    }
  }
  LHAmake_table(dat, N1, dat->d.st.c_len, 12, dat->d.st.c_table);
}

static void LHAread_tree_p(struct LhADecrData *dat) /* read tree from file */
{
  xadINT32 i, c;

  i = 0;
  while(i < NP)
  {
    dat->d.st.pt_len[i] = LHAgetbits(dat, LENFIELD);
    if(++i == 3 && dat->d.st.pt_len[0] == 1 && dat->d.st.pt_len[1] == 1 && dat->d.st.pt_len[2] == 1)
    {
      c = LHAgetbits(dat, MAX_DICBIT - 6);
      for(i = 0; i < NP; i++)
        dat->d.st.c_len[i] = 0;
      for(i = 0; i < 256; i++)
        dat->d.st.c_table[i] = c;
      return;
    }
  }
}

static xadUINT16 LHAdecode_c_st0(struct LhADecrData *dat)
{
  xadINT32 i, j;

  if(!dat->d.st.blocksize) /* read block head */
  {
    dat->d.st.blocksize = LHAgetbits(dat, BUFBITS); /* read block blocksize */
    LHAread_tree_c(dat);
    if(LHAgetbits(dat, 1))
    {
      LHAread_tree_p(dat);
    }
    else
    {
      LHAready_made(dat, 1);
    }
    LHAmake_table(dat, NP, dat->d.st.pt_len, 8, dat->d.st.pt_table);
  }
  dat->d.st.blocksize--;
  j = dat->d.st.c_table[dat->bitbuf >> 4];
  if(j < N1)
    LHAfillbuf(dat, dat->d.st.c_len[j]);
  else
  {
    LHAfillbuf(dat, 12);
    i = dat->bitbuf;
    do
    {
      if((xadINT16) i < 0)
        j = dat->d.st.right[j];
      else
        j = dat->d.st.left[j];
      i <<= 1;
    } while(j >= N1);
    LHAfillbuf(dat, dat->d.st.c_len[j] - 12);
  }
  if (j == N1 - 1)
    j += LHAgetbits(dat, EXTRABITS);
  return (xadUINT16) j;
}

/* ------------------------------------------------------------------------ */

static const xadINT32 PMARC2_historyBits[8] = { 3,  3,  4,  5,  5,  5,  6,  6};
static const xadINT32 PMARC2_historyBase[8] = { 0,  8, 16, 32, 64, 96,128,192};
static const xadINT32 PMARC2_repeatBits[6]  = { 3,  3,  5,  6,  7,  0};
static const xadINT32 PMARC2_repeatBase[6]  = {17, 25, 33, 65,129,256};

static void PMARC2_hist_update(struct LhADecrData *dat, xadUINT8 data)
{
  if(data != dat->d.pm.lastbyte)
  {
    xadUINT8 oldNext, oldPrev, newNext;

    /* detach from old position */
    oldNext = dat->d.pm.next[data];
    oldPrev = dat->d.pm.prev[data];
    dat->d.pm.prev[oldNext] = oldPrev;
    dat->d.pm.next[oldPrev] = oldNext;

    /* attach to new next */
    newNext = dat->d.pm.next[dat->d.pm.lastbyte];
    dat->d.pm.prev[newNext] = data;
    dat->d.pm.next[data] = newNext;

    /* attach to new prev */
    dat->d.pm.prev[data] = dat->d.pm.lastbyte;
    dat->d.pm.next[dat->d.pm.lastbyte] = data;

    dat->d.pm.lastbyte = data;
  }
}

static xadINT32 PMARC2_tree_get(struct LhADecrData *dat, struct PMARC2_Tree *t)
{
  xadINT32 i;
  i = t->root;

  while (i < 0x80)
  {
    i = (LHAgetbits(dat, 1) == 0 ? t->leftarr[i] : t->rightarr[i] );
  }
  return i & 0x7F;
}

static void PMARC2_tree_rebuild(struct LhADecrData *dat, struct PMARC2_Tree *t,
xadUINT8 bound, xadUINT8 mindepth, xadUINT8 * table)
{
  xadUINT8 d;
  xadINT32 i, curr, empty, n;

  t->root = 0;
  memset(t->leftarr, 0, bound);
  memset(t->rightarr, 0, bound);
  memset(dat->d.pm.parentarr, 0, bound);

  for(i = 0; i < dat->d.pm.mindepth - 1; i++)
  {
    t->leftarr[i] = i + 1;
    dat->d.pm.parentarr[i+1] = i;
  }

  curr = dat->d.pm.mindepth - 1;
  empty = dat->d.pm.mindepth;
  for(d = dat->d.pm.mindepth; ; d++)
  {
    for(i = 0; i < bound; i++)
    {
      if(table[i] == d)
      {
        if(t->leftarr[curr] == 0)
          t->leftarr[curr] = i | 128;
        else
        {
          t->rightarr[curr] = i | 128;
          n = 0;
          while(t->rightarr[curr] != 0)
          {
            if(curr == 0) /* root? -> done */
              return;
            curr = dat->d.pm.parentarr[curr];
            n++;
          }
          t->rightarr[curr] = empty;
          for(;;)
          {
            dat->d.pm.parentarr[empty] = curr;
            curr = empty;
            empty++;

            n--;
            if(n == 0)
              break;
            t->leftarr[curr] = empty;
          }
        }
      }
    }
    if(t->leftarr[curr] == 0)
      t->leftarr[curr] = empty;
    else
      t->rightarr[curr] = empty;

    dat->d.pm.parentarr[empty] = curr;
    curr = empty;
    empty++;
  }
}

static xadUINT8 PMARC2_hist_lookup(struct LhADecrData *dat, xadINT32 n)
{
  xadUINT8 i;
  xadUINT8 *direction = dat->d.pm.prev;

  if(n >= 0x80)
  {
    /* Speedup: If you have to process more than half the ring,
                it's faster to walk the other way around. */
    direction = dat->d.pm.next;
    n = 0x100 - n;
  }
  for(i = dat->d.pm.lastbyte; n != 0; n--)
    i = direction[i];
  return i;
}

static void PMARC2_maketree1(struct LhADecrData *dat)
{
  xadINT32 i, nbits, x;

  dat->d.pm.tree1bound = LHAgetbits(dat, 5);
  dat->d.pm.mindepth = LHAgetbits(dat, 3);

  if(dat->d.pm.mindepth == 0)
    dat->d.pm.tree1.root = 128 | (dat->d.pm.tree1bound - 1);
  else
  {
    memset(dat->d.pm.table1, 0, 32);
    nbits = LHAgetbits(dat, 3);
    for(i = 0; i < dat->d.pm.tree1bound; i++)
    {
      if((x = LHAgetbits(dat, nbits)))
        dat->d.pm.table1[i] = x - 1 + dat->d.pm.mindepth;
    }
    PMARC2_tree_rebuild(dat, &dat->d.pm.tree1, dat->d.pm.tree1bound,
    dat->d.pm.mindepth, dat->d.pm.table1);
  }
}

static void PMARC2_maketree2(struct LhADecrData *dat, xadINT32 par_b)
/* in use: 5 <= par_b <= 8 */
{
  xadINT32 i, count, index;

  if(dat->d.pm.tree1bound < 10)
    return;
  if(dat->d.pm.tree1bound == 29 && dat->d.pm.mindepth == 0)
    return;

  for(i = 0; i < 8; i++)
    dat->d.pm.table2[i] = 0;
  for(i = 0; i < par_b; i++)
    dat->d.pm.table2[i] = LHAgetbits(dat, 3);
  index = 0;
  count = 0;
  for(i = 0; i < 8; i++)
  {
    if(dat->d.pm.table2[i] != 0)
    {
      index = i;
      count++;
    }
  }

  if(count == 1)
  {
    dat->d.pm.tree2.root = 128 | index;
  }
  else if (count > 1)
  {
    dat->d.pm.mindepth = 1;
    PMARC2_tree_rebuild(dat, &dat->d.pm.tree2, 8, dat->d.pm.mindepth, dat->d.pm.table2);
  }
  /* Note: count == 0 is possible! */
}

static void LHAdecode_start_pm2(struct LhADecrData *dat)
{
  xadINT32 i;

  dat->d.pm.tree1.leftarr = dat->d.pm.tree1left;
  dat->d.pm.tree1.rightarr = dat->d.pm.tree1right;
/*  dat->d.pm.tree1.root = 0; */
  dat->d.pm.tree2.leftarr = dat->d.pm.tree2left;
  dat->d.pm.tree2.rightarr = dat->d.pm.tree2right;
/*  dat->d.pm.tree2.root = 0; */

  dat->d.pm.dicsiz1 = (1 << dat->DicBit) - 1;
  LHAinit_getbits(dat);

  /* history init */
  for(i = 0; i < 0x100; i++)
  {
    dat->d.pm.prev[(0xFF + i) & 0xFF] = i;
    dat->d.pm.next[(0x01 + i) & 0xFF] = i;
  }
  dat->d.pm.prev[0x7F] = 0x00; dat->d.pm.next[0x00] = 0x7F;
  dat->d.pm.prev[0xDF] = 0x80; dat->d.pm.next[0x80] = 0xDF;
  dat->d.pm.prev[0x9F] = 0xE0; dat->d.pm.next[0xE0] = 0x9F;
  dat->d.pm.prev[0x1F] = 0xA0; dat->d.pm.next[0xA0] = 0x1F;
  dat->d.pm.prev[0xFF] = 0x20; dat->d.pm.next[0x20] = 0xFF;
  dat->d.pm.lastbyte = 0x20;

/*  dat->nextcount = 0; */
/*  dat->d.pm.lastupdate = 0; */
  LHAgetbits(dat, 1); /* discard bit */
}

static xadUINT16 LHAdecode_c_pm2(struct LhADecrData *dat)
{
  /* various admin: */
  while(dat->d.pm.lastupdate != dat->loc)
  {
    PMARC2_hist_update(dat, dat->text[dat->d.pm.lastupdate]);
    dat->d.pm.lastupdate = (dat->d.pm.lastupdate + 1) & dat->d.pm.dicsiz1;
  }
  while(dat->count >= dat->nextcount)
  /* Actually it will never loop, because count doesn't grow that fast.
     However, this is the way LHA does it.
     Probably other encoding methods can have repeats larger than 256 bytes.
     Note: LHA puts this code in LHAdecode_p...
  */
  {
    if(dat->nextcount == 0x0000)
    {
      PMARC2_maketree1(dat);
      PMARC2_maketree2(dat, 5);
      dat->nextcount = 0x0400;
    }
    else if(dat->nextcount == 0x0400)
    {
      PMARC2_maketree2(dat, 6);
      dat->nextcount = 0x0800;
    }
    else if(dat->nextcount == 0x0800)
    {
      PMARC2_maketree2(dat, 7);
      dat->nextcount = 0x1000;
    }
    else if(dat->nextcount == 0x1000)
    {
      if(LHAgetbits(dat, 1) != 0)
        PMARC2_maketree1(dat);
      PMARC2_maketree2(dat, 8);
      dat->nextcount = 0x2000;
    }
    else
    { /* 0x2000, 0x3000, 0x4000, ... */
      if(LHAgetbits(dat, 1) != 0)
      {
        PMARC2_maketree1(dat);
        PMARC2_maketree2(dat, 8);
      }
      dat->nextcount += 0x1000;
    }
  }
  dat->d.pm.gettree1 = PMARC2_tree_get(dat, &dat->d.pm.tree1); /* value preserved for LHAdecode_p */

  /* direct value (ret <= UCHAR_MAX) */
  if(dat->d.pm.gettree1 < 8)
  {
    return (xadUINT16) (PMARC2_hist_lookup(dat, PMARC2_historyBase[dat->d.pm.gettree1]
    + LHAgetbits(dat, PMARC2_historyBits[dat->d.pm.gettree1])));
  }

  /* repeats: (ret > UCHAR_MAX) */
  if(dat->d.pm.gettree1 < 23)
  {
    return (xadUINT16) (PMARC2_OFFSET + 2 + (dat->d.pm.gettree1 - 8));
  }

  return (xadUINT16) (PMARC2_OFFSET + PMARC2_repeatBase[dat->d.pm.gettree1 - 23]
  + LHAgetbits(dat, PMARC2_repeatBits[dat->d.pm.gettree1 - 23]));
}

static xadUINT16 LHAdecode_p_pm2(struct LhADecrData *dat)
{
  /* gettree1 value preserved from LHAdecode_c */
  xadINT32 nbits, delta, gettree2;

  if(dat->d.pm.gettree1 == 8)
  { /* 2-byte repeat with offset 0..63 */
    nbits = 6; delta = 0;
  }
  else if(dat->d.pm.gettree1 < 28)
  { /* n-byte repeat with offset 0..8191 */
    if(!(gettree2 = PMARC2_tree_get(dat, &dat->d.pm.tree2)))
    {
      nbits = 6;
      delta = 0;
    }
    else
    { /* 1..7 */
      nbits = 5 + gettree2;
      delta = 1 << nbits;
    }
  }
  else
  { /* 256 bytes repeat with offset 0 */
    nbits = 0;
    delta = 0;
  }
  return (xadUINT16) (delta + LHAgetbits(dat, nbits));
}

/* ------------------------------------------------------------------------ */

static xadUINT16 LHAdecode_c_lzs(struct LhADecrData *dat)
{
  if(LHAgetbits(dat, 1))
  {
    return LHAgetbits(dat, 8);
  }
  else
  {
    dat->d.lz.matchpos = LHAgetbits(dat, 11);
    return (xadUINT16) (LHAgetbits(dat, 4) + 0x100);
  }
}

static xadUINT16 LHAdecode_p_lzs(struct LhADecrData *dat)
{
  return (xadUINT16) ((dat->loc - dat->d.lz.matchpos - MAGIC0) & 0x7ff);
}

static void LHAdecode_start_lzs(struct LhADecrData *dat)
{
  LHAinit_getbits(dat);
}

static xadUINT16 LHAdecode_c_lz5(struct LhADecrData *dat)
{
  xadINT32 c;

  if(!dat->d.lz.flagcnt)
  {
    dat->d.lz.flagcnt = 8;
    dat->d.lz.flag = xadIOGetChar(dat->io);
  }
  dat->d.lz.flagcnt--;
  c = xadIOGetChar(dat->io);
  if((dat->d.lz.flag & 1) == 0)
  {
    dat->d.lz.matchpos = c;
    c = xadIOGetChar(dat->io);
    dat->d.lz.matchpos += (c & 0xf0) << 4;
    c &= 0x0f;
    c += 0x100;
  }
  dat->d.lz.flag >>= 1;
  return (xadUINT16) c;
}

static xadUINT16 LHAdecode_p_lz5(struct LhADecrData *dat)
{
  return (xadUINT16) ((dat->loc - dat->d.lz.matchpos - MAGIC5) & 0xfff);
}

static void LHAdecode_start_lz5(struct LhADecrData *dat)
{
  xadINT32 i;
  xadSTRPTR text;

  text = dat->text;

  dat->d.lz.flagcnt = 0;

  for(i = 0; i < 256; i++)
    memset(text + i * 13 + 18, i, 13);

  for(i = 0; i < 256; i++)
    text[256 * 13 + 18 + i] = i;

  for(i = 0; i < 256; i++)
    text[256 * 13 + 256 + 18 + i] = 255 - i;

  memset(text + 256 * 13 + 512 + 18, 0, 128);
  memset(text + 256 * 13 + 512 + 128 + 18, ' ', 128-18);
}

/**************************************************************************************************/

static void LhAUnRegister(struct xadInOut *io, xadUINT32 size)
{
  xadUINT32 j;
  xadSTRPTR a;

  j = (xadUINT32) io->xio_InFuncPrivate;
  a = io->xio_InBuffer;
  while(size--)
  {
    j = (j << 8) + ((j >> 24)&0xFF);
    *(a++) ^= j;
  }
  io->xio_InFuncPrivate = (xadPTR) j;
}

static xadINT32 LhA_Decrunch(struct xadInOut *io, xadUINT32 Method)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct LhADecrData *dd;
  xadINT32 err = 0;

  if((dd = xadAllocVec(XADM sizeof(struct LhADecrData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    void (*DecodeStart)(struct LhADecrData *);
    xadUINT16 (*DecodeC)(struct LhADecrData *);
    xadUINT16 (*DecodeP)(struct LhADecrData *);

    /* most often used stuff */
    dd->io = io;
    dd->DicBit = 13;
    DecodeStart = LHAdecode_start_st1;
    DecodeP = LHAdecode_p_st1;
    DecodeC = LHAdecode_c_st1;

    switch(Method)
    {
    case LZHUFF1_METHOD:
      dd->DicBit = 12;
      DecodeStart = LHAdecode_start_fix;
      DecodeC = LHAdecode_c_dyn;
      DecodeP = LHAdecode_p_st0;
      break;
    case LZHUFF2_METHOD:
      DecodeStart = LHAdecode_start_dyn;
      DecodeC = LHAdecode_c_dyn;
      DecodeP = LHAdecode_p_dyn;
      break;
    case LZHUFF3_METHOD:
      DecodeStart = LHAdecode_start_st0;
      DecodeP = LHAdecode_p_st0;
      DecodeC = LHAdecode_c_st0;
      break;
    case PMARC2_METHOD:
      DecodeStart = LHAdecode_start_pm2;
      DecodeP = LHAdecode_p_pm2;
      DecodeC = LHAdecode_c_pm2;
      break;
    case LZHUFF4_METHOD:
      dd->DicBit = 12;
//      break;
    case LZHUFF5_METHOD:
      break;
    case LZHUFF6_METHOD:
      dd->DicBit = 15;
      break;
    case LZHUFF7_METHOD:
      dd->DicBit = 16;
      break;
    case LZHUFF8_METHOD:
      dd->DicBit = 17;
      break;
    case LARC_METHOD:
      dd->DicBit = 11;
      DecodeStart = LHAdecode_start_lzs;
      DecodeC = LHAdecode_c_lzs;
      DecodeP = LHAdecode_p_lzs;
      break;
    case LARC5_METHOD:
      dd->DicBit = 12;
      DecodeStart = LHAdecode_start_lz5;
      DecodeC = LHAdecode_c_lz5;
      DecodeP = LHAdecode_p_lz5;
      break;
    default:
      err = XADERR_DATAFORMAT; break;
    }
    if(!err)
    {
      xadSTRPTR text;
      xadINT32 i, c, offset;
      xadUINT32 dicsiz;

      dicsiz = 1 << dd->DicBit;
      offset = (Method == LARC_METHOD || Method == PMARC2_METHOD) ? 0x100 - 2 : 0x100 - 3;

      if((text = dd->text = xadAllocVec(XADM dicsiz, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
      {
/*      if(Method == LZHUFF1_METHOD || Method == LZHUFF2_METHOD || Method == LZHUFF3_METHOD ||
        Method == LZHUFF6_METHOD || Method == LARC_METHOD || Method == LARC5_METHOD)
*/
          memset(text, ' ', (size_t) dicsiz);

        DecodeStart(dd);
        --dicsiz; /* now used with AND */
        while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
        {
          c = DecodeC(dd);
          if(c <= UCHAR_MAX)
          {
            text[dd->loc++] = xadIOPutChar(io, c);
            dd->loc &= dicsiz;
            dd->count++;
          }
          else
          {
            c -= offset;
            i = dd->loc - DecodeP(dd) - 1;
            dd->count += c;
            while(c--)
            {
              text[dd->loc++] = xadIOPutChar(io, text[i++ & dicsiz]);
              dd->loc &= dicsiz;
            }
          }
        }
        err = io->xio_Error;
        xadFreeObjectA(XADM text, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
    xadFreeObjectA(XADM dd, 0);
  }
  else
    err = XADERR_NOMEMORY;
  return err;
}

XADUNARCHIVE(LhA)
{
  xadINT32 err;
  xadUINT16 crc = 0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(LHAPI(fi)->Method == LZHUFF0_METHOD || LHAPI(fi)->Method == LARC4_METHOD || LHAPI(fi)->Method == PMARC0_METHOD)
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC16, &crc, TAG_DONE);
  else
  {
    struct xadInOut *io;

    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOINENDERR, ai, xadMasterBase)))
    {
      io->xio_InSize = fi->xfi_CrunchSize;
      io->xio_OutSize = fi->xfi_Size;

      if(ai->xai_PrivateClient)
      {
        io->xio_InFunc = LhAUnRegister;
        io->xio_InFuncPrivate = ai->xai_PrivateClient;
      }

      err = LhA_Decrunch(io, LHAPI(fi)->Method);
      if(!err)
        err = xadIOWriteBuf(io);

      crc = io->xio_CRC16;
      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && crc != LHAPI(fi)->CRC)
    err = XADERR_CHECKSUM;

  return err;
}

/****************************************************************************/

XADRECOGDATA(LhAEXE)
{
  if(data[9*4] == 'L' && data[9*4+1] == 'H' && data[9*4+3] == 0x27
  && EndGetM32(data + 10*4) == 0x73205346)
    return XADTRUE;
  else if(EndGetM32(data+8*4) == 0x4C5A5353 && EndGetM32(data+9*4) == 0x2073656C)
    return XADTRUE;
  else if(EndGetM32(data+6) == 0x53465820 && EndGetM32(data+10) == 0x6F66204C &&
  EndGetM32(data+14) == 0x48617263)
    return XADTRUE;
  else if(data[9*4+1] == 'L' && data[9*4+2] == 'H' && EndGetM32(data+19*4) == 0x6E616D65
  && EndGetM32(data+20*4) == 0x20746F20)
    return XADTRUE;
  else
    return XADFALSE;
}

XADGETINFO(LhAEXE)
{
  xadUINT32 lastpos = 0;
  xadINT32 err;

  if(!(err = LhAScanNext(&lastpos, ai, xadMasterBase)))
    err = LhA_GetInfo(ai, xadMasterBase);

  return err;
}

/****************************************************************************/

XADRECOGDATA(LhASFX)
{
  return (xadBOOL) (EndGetM32(data+11*4) == 0x53465821);
}

XADGETINFO(LhASFX)
{
  xadINT32 err;
  xadUINT32 i;
  xadUINT8 dat[4];

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 0x34, 0, ai)))
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, &dat, ai)))
    {
      if((i = EndGetM32(dat)) == 0x1914) /* lha1.50r archive */
        ai->xai_PrivateClient = (xadPTR) 0x424F410F;
      if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, i-0x38, 0, ai)))
        err = LhA_GetInfo(ai, xadMasterBase);
    }
  }
  return err;
}

XADFREE(LhASFX)
{
  ai->xai_PrivateClient = 0;
}

/****************************************************************************/

XADRECOGDATA(LhAC64SFX)
{
  if(data[0] == 0x01 && data[2] == 0x28 && data[3] == 0x1C &&
     data[0xD30] == '1' && data[0xD44] == 'L' && data[0xD45] == 'H' &&
     data[0xD46] == 'A' && data[0xE8B] == '-' && data[0xE8C] == 'l' &&
     data[0xE8D] == 'h' && data[0xE8F] == '-')
    return XADTRUE;
  return XADFALSE;
}

XADGETINFO(LhAC64SFX)
{
  xadINT32 err;

  if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, 0xE89, 0, ai)))
    err = LhA_GetInfo(ai, xadMasterBase);

  return err;
}

/****************************************************************************/

struct ZooDir {
  xadUINT8 ID[4];
  xadUINT8 EntryType;
  xadUINT8 Compression;
  xadUINT8 NextDir[4];
  xadUINT8 Offset[4];
  xadUINT8 Date[2];
  xadUINT8 Time[2];
  xadUINT8 CRC[2];
  xadUINT8 Size[4];
  xadUINT8 CompSize[4];
  xadUINT8 CompressVersion;
  xadUINT8 ExtractVersion;
  xadUINT8 Deleted;
  xadUINT8 Structure;
  xadUINT8 Commentoffset[4];
  xadUINT8 Commentlength[2];
  xadUINT8 Filename[13];
};

struct ZooPrivate {
  xadUINT16 CRC;
  xadUINT16 Method;
};


#define ZOOPI(a)        ((struct ZooPrivate *) ((a)->xfi_PrivateInfo))

XADGETINFO(Zoo)
{
  xadINT32 err, var;
  xadUINT8 data[4];
  struct ZooDir zd;
  struct xadFileInfo *fi;

  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, 24, 0, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_READ, 4, data, ai)))
    return err;
  if((err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32) EndGetI32(data)-28, 0, ai)))
    return err;
  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 51, &zd, ai)))
    {
      if((xadUINT32)EndGetM32(zd.ID) != 0xDCA7C4FD)
        err = XADERR_ILLEGALDATA;
      else if(!EndGetI32(zd.NextDir))
        break;
      else
      {
        xadUINT32 namesize = 0, commsize;
        xadSTRPTR varpart = 0, filename;

        filename = (xadSTRPTR) zd.Filename;
        while(namesize < 13 && filename[namesize])
          ++namesize;
        commsize = EndGetI16(zd.Commentlength);

        if(zd.EntryType == 2)
        {
          if(!(err = xadHookAccess(XADM XADAC_READ, 2, data, ai)))
          {
            var = EndGetI16(data);
            if(var > 2)
            {
              if((varpart = (xadSTRPTR) xadAllocVec(XADM (xadUINT32)var+3, XADMEMF_PUBLIC)))
              {
                if(!(err = xadHookAccess(XADM XADAC_READ, (xadUINT32)var+3, varpart, ai)))
                {
                  if(varpart[3])
                  {
                    filename = varpart+5;
                    namesize = varpart[3]-1;
                  }
                  namesize += varpart[4]; /* directory size */
                }
              }
              else
                err = XADERR_NOMEMORY;
            }
          }
        }

        if(!err)
        {
          if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
          XAD_OBJNAMESIZE, namesize+1, XAD_OBJPRIVINFOSIZE, sizeof(struct ZooPrivate),
          commsize ? XAD_OBJCOMMENTSIZE : TAG_DONE, commsize, TAG_DONE)))
          {
            if(commsize)
            {
              if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, EndGetI32(zd.Commentoffset)-ai->xai_InPos, 0, ai)))
                err = xadHookAccess(XADM XADAC_READ, commsize-1, fi->xfi_Comment, ai);
            }
            /* Every entry is preceeded by a header ( "@)#(\0" ) ! */
            ZOOPI(fi)->CRC = EndGetI16(zd.CRC);
            ZOOPI(fi)->Method = zd.Compression;
            fi->xfi_DataPos = EndGetI32(zd.Offset);
            fi->xfi_Size = EndGetI32(zd.Size);
            fi->xfi_CrunchSize = EndGetI32(zd.CompSize);
            if(varpart)
            {
              fi->xfi_Generation = EndGetI16(varpart+varpart[3]+varpart[4]+5+6);
              /* Protectionformat in EndGetI32(varpart+varpart[3]+varpart[4]+5+2) unknown! */
            }
            fi->xfi_Flags |= XADFIF_SEEKDATAPOS|XADFIF_EXTRACTONBUILD;
            if(zd.Deleted)
              fi->xfi_Flags |= XADFIF_DELETED;
            if(varpart && varpart[4])
            {
              xadCopyMem(XADM varpart+varpart[3]+5, fi->xfi_FileName, (xadUINT32)varpart[4]);
              namesize -= varpart[4];
              fi->xfi_FileName[varpart[4]-1] = '/';
            }
            xadCopyMem(XADM filename, fi->xfi_FileName + (varpart ? varpart[4] : 0), namesize);

            xadConvertDates(XADM XAD_DATEMSDOS, (EndGetI16(zd.Date)<<16)+EndGetI16(zd.Time), XAD_GETDATEXADDATE,
            &fi->xfi_Date, TAG_DONE);

            if(!err)
              err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, EndGetI32(zd.NextDir), TAG_DONE);
            else
              xadFreeObjectA(XADM fi, 0);
          }
          else
            err = XADERR_NOMEMORY;
        }
        if(varpart)
          xadFreeObjectA(XADM varpart, 0);
      }
    }
  }
  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : XADERR_ILLEGALDATA);
}

XADRECOGDATA(Zoo)
{
  if(data[0] == 'Z' && data[1] == 'O' && data[2] == 'O' && data[3] == ' ' &&
  data[8] == ' ' && data[9] == 'A' && data[10] == 'r' && data[11] == 'c' &&
  data[12] == 'h' && data[13] == 'i' && data[14] == 'v' && data[15] == 'e' &&
  data[16] == '.' && data[17] == 0x1A && !data[18] && !data[19] &&
  data[20] == 0xDC && data[21] == 0xA7 && data[22] == 0xC4 && data[23] == 0xFD)
    return 1;
  else
    return 0;
}

/**************************************************************************************************/

#define ZOOBUFSIZE      8196
#define ZOOSTACKSIZE    8000
#define ZOOMAXMAX       8192        /* max code + 1 */
#define ZOOMAXBITS      13
#define ZOOCLEAR        256         /* clear code */
#define ZOOZ_EOF        257         /* end of file marker */
#define ZOOFIRST_FREE   258         /* first free code */

struct ZOOtabentry
{
  xadUINT16 next;
  xadUINT8 z_ch;
};

struct ZooData {
  struct ZOOtabentry  table[ZOOMAXMAX+10];
  xadUINT8               stack[ZOOSTACKSIZE+20];
};

static xadINT32 ZOOlzd(struct xadInOut *io)
{
  xadUINT16 max_code = 512, free_code = ZOOFIRST_FREE, stack_pointer = 0;
  xadUINT16 cur_code = 0, in_code, old_code = 0;
  xadINT8 fin_char = 0, k, nbits;
  struct ZooData *zd;
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadINT32 err;

  if((zd = (struct ZooData *) xadAllocVec(XADM sizeof(struct ZooData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    nbits = 9;
    while(cur_code != ZOOZ_EOF && !io->xio_Error)
    {
      cur_code = xadIOGetBitsLow(io, nbits);
      if(cur_code != ZOOZ_EOF)
      {
        if(cur_code == ZOOCLEAR)
        {
          nbits = 9;
          max_code = 512;
          free_code = ZOOFIRST_FREE;

          fin_char = k = old_code = cur_code = xadIOGetBitsLow(io, nbits);
          if(cur_code != ZOOZ_EOF)
            xadIOPutChar(io, k);
        }
        else
        {
          in_code = cur_code;
          if(cur_code >= free_code) /* if code not in table (k<w>k<w>k) */
          {
            cur_code = old_code;                /* previous code becomes current */
            zd->stack[stack_pointer++] = fin_char;
          }

          while(cur_code > 255) /* if code, not character */
          {
            zd->stack[stack_pointer++] = zd->table[cur_code].z_ch;      /* push suffix char */
            cur_code = zd->table[cur_code].next;                        /* <w> := <w>.code */
          }

          xadIOPutChar(io, k = fin_char = cur_code);

          while(stack_pointer)
            xadIOPutChar(io, zd->stack[--stack_pointer]);

          zd->table[free_code].z_ch = k;                /* save suffix char */
          zd->table[free_code].next = old_code;         /* save prefix code */
          if(++free_code >= max_code)
          {
            if(nbits < ZOOMAXBITS)
            {
              nbits++;
              max_code = max_code << 1;         /* double max_code */
            }
          }
          old_code = in_code;
        }
      }
    }
    err = io->xio_Error;
    xadFreeObjectA(XADM zd, 0);
  }
  else
    err = XADERR_NOMEMORY;
  return err;
}

/****************************************************************************/

XADUNARCHIVE(Zoo)
{
  xadINT32 err;
  xadUINT16 crc = 0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(!ZOOPI(fi)->Method)
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC16, &crc, TAG_DONE);
  else
  {
    struct xadInOut *io;
    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32, ai, xadMasterBase)))
    {
      io->xio_InSize = fi->xfi_CrunchSize;
      io->xio_OutSize = fi->xfi_Size;
      switch(ZOOPI(fi)->Method)
      {
      case 1: err = ZOOlzd(io); break;
      case 2: io->xio_Flags |= XADIOF_NOINENDERR; err = LhA_Decrunch(io, LZHUFF5_METHOD); break;
      default: err = XADERR_DATAFORMAT; break;
      }

      if(!err)
        err = xadIOWriteBuf(io);

      crc = io->xio_CRC16;
      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && crc != ZOOPI(fi)->CRC)
    err = XADERR_CHECKSUM;
  return err;
}

/****************************************************************************/

#define ARJOS_MSDOS             0
#define ARJOS_PRIMOS            1
#define ARJOS_UNIX              2
#define ARJOS_AMIGA             3
#define ARJOS_MACDOS            4
#define ARJOS_OS2               5
#define ARJOS_APPLEGS           6
#define ARJOS_ATARI             7
#define ARJOS_NEXT              8
#define ARJOS_VAX               9

#define ARJFLAG_GARBLED         (1<<0)
#define ARJFLAG_OLDSECURED      (1<<1)
#define ARJFLAG_VOLUME          (1<<2)
#define ARJFLAG_EXTFILE         (1<<3)
#define ARJFLAG_PATHSYM         (1<<4)
#define ARJFLAG_BACKUP          (1<<5)
#define ARJFLAG_SECURED         (1<<6)

#define ARJTYPE_BINARY          0
#define ARJTYPE_TEXT            1
#define ARJTYPE_COMMENTHEADER   2
#define ARJTYPE_DIRECTORY       3
#define ARJTYPE_LABEL           4

struct ArjHeader {              /* intel storage */
  xadUINT8 arj_ID[2];           /* 0x60,0xEA */
  xadUINT8 arj_HeaderSize[2];   /* FirstHeaderSize to ArchiveComment, 0 is end */
  xadUINT8 arj_FirstHeaderSize; /* upto Extra Data */
  xadUINT8 arj_ArchiverVersion;
  xadUINT8 arj_MinimumVersion;
  xadUINT8 arj_HostOS;
  xadUINT8 arj_Flags;
  xadUINT8 arj_Method;
  xadUINT8 arj_FileType;
  xadUINT8 arj_GarblePasswordModifier;
  xadUINT8 arj_Date[4];
  xadUINT8 arj_CompSize[4];
  xadUINT8 arj_Size[4];
  xadUINT8 arj_CRC[4];
  xadUINT8 arj_EntrynamePosition[2];    /* == PathPart position */
  xadUINT8 arj_FileAccessMode[2];
  xadUINT8 arj_HostData[2];
  /* extra data */
  xadUINT8 arj_ExtFilePos[4];

  /* filename */
  /* comment */
};

/* Some redifines for archive header */
#define arj_SecurityVersion     arj_Method       /* 2 == current */
#define arj_CreationDate        arj_Date
#define arj_ModificationDate    arj_CompSize
#define arj_ArchiveSize         arj_Size
#define arj_SecurityEnvelopePos arj_CRC
#define arj_SecurityLength      arj_FileAccessMode

/* After that commes following:
  xadUINT32 HeaderCRC;
  multiple:
   xadUINT16 Extended header size (0 if none)
   ..... Extended header
   xadUINT32 Extended header CRC
*/

struct ArjPrivate {
  struct ArjPrivate *Next;
  xadUINT32              CRC;
  xadUINT32                  DataPos;
  xadUINT32                  CrSize;
  xadUINT32                  Size;
  xadUINT32                  FileEndPos;
  xadUINT8              Method;
  xadUINT8              Flags;
  xadUINT8              PwdModifier;
};

static const xadSTRPTR arjtypes[] = {
"stored", "most", "medium", "fast", "fastest"};

XADRECOGDATA(Arj)
{
  if(*data == 0x60 && data[1] == 0xEA && EndGetI16(data+2) <= 2600)
    return 1;
  return 0;
}

#define ARJBUFFSIZE 10240

static xadINT32 ArjScanNext(xadUINT32 *lastpos, struct xadArchiveInfo *ai, struct xadMasterBase *xadMasterBase)
{
  xadUINT32 i;
  xadINT32 err = 0, found = 0;
  xadSTRPTR buf;
  xadUINT32 bufsize, fsize, spos = 0;

  if((i = *lastpos - ai->xai_InPos))
    if((err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai)))
      return err;

  if((fsize = ai->xai_InSize-ai->xai_InPos) < 15)
    return 0;

  if((bufsize = ARJBUFFSIZE) > fsize)
    bufsize = fsize;

  if(!(buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && !found && fsize >= 15)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, bufsize-spos, buf+spos, ai)))
    {
      for(i = 0; i < bufsize - 5 && !found; ++i)
      {
        if((xadUINT8)buf[i] == 0x60 && (xadUINT8)buf[i+1] == 0xEA && EndGetI16(buf+i+2) <= 2600)
          found = 1;
      }
      if(!found)
      {
        xadCopyMem(XADM buf+i, buf, 5);
        spos = 5;
        fsize -= bufsize - 5;
        if(fsize < bufsize)
          bufsize = fsize;
      }
    }
  }

  xadFreeObjectA(XADM buf, 0);

  if(found)
  {
    err = xadHookAccess(XADM XADAC_INPUTSEEK, i-1-bufsize, 0, ai);
    *lastpos = ai->xai_InPos + 2;
  }

  return err;
}

XADGETINFO(Arj)
{
  struct xadFileInfo *fi, *lfi = 0;
  xadINT32 err = 0;
  xadUINT32 lastpos = 0;
  struct ArjHeader *ah;
  struct ArjPrivate *ap = 0;

  if(!(ah = (struct ArjHeader *) xadAllocVec(XADM 2600, XADMEMF_PUBLIC)))
    return XADERR_NOMEMORY;

  while(!err && ai->xai_InPos < ai->xai_InSize)
  {
    if(!(err = xadHookAccess(XADM XADAC_READ, 4, ah, ai)))
    {
      xadUINT32 hs;
      hs = EndGetI16(ah->arj_HeaderSize);

      if(ah->arj_ID[0] != 0x60 || ah->arj_ID[1] != 0xEA || hs > 2600)
      {
        if(!ai->xai_LastError)
        {
          ai->xai_Flags |= XADAIF_FILECORRUPT;
          ai->xai_LastError = XADERR_ILLEGALDATA;
        }
        err = ArjScanNext(&lastpos, ai, xadMasterBase);
      }
      else if(hs) /* no file end */
      {
        lastpos = ai->xai_InPos;
        if(!(err = xadHookAccess(XADM XADAC_READ, hs+6, ((xadSTRPTR)ah)+4, ai)))
        {
          xadUINT16 nextsize;

          nextsize = EndGetI16(((xadSTRPTR)ah)+hs+8);
          while(nextsize && !err)
          {
            if(!(err = xadHookAccess(XADM XADAC_INPUTSEEK, nextsize, 0, ai)))
              err = xadHookAccess(XADM XADAC_READ, 2, &nextsize, ai);
          }
          if(ah->arj_FileType != ARJTYPE_COMMENTHEADER)
          {
            if((xadUINT32)EndGetI32(((xadSTRPTR)ah)+hs+4) != ~xadCalcCRC32(XADM XADCRC32_ID1, (xadUINT32) ~0, hs, ((xadUINT8 *)ah)+4))
              err = XADERR_CHECKSUM;
            else
            {
              xadUINT32 namelength, commentlength;
              xadSTRPTR n;

              n = ((xadSTRPTR)ah)+4+ah->arj_FirstHeaderSize;
              for(namelength = 0; n[namelength]; ++namelength)
                ;
              ++namelength;
              for(commentlength = 0; n[commentlength+namelength]; ++commentlength)
                ;
              if(lfi)
              {
                for(ap = (struct ArjPrivate *) lfi->xfi_PrivateInfo; ap->Next; ap = ap->Next)
                  ;
              }

              if(lfi && (ap->Flags & ARJFLAG_VOLUME) && (ah->arj_Flags & ARJFLAG_EXTFILE) &&
              !strcmp(n, lfi->xfi_FileName) && (ah->arj_FirstHeaderSize < 0x22 ||
              (xadUINT32)EndGetI32(ah->arj_ExtFilePos) == ap->FileEndPos))
              {
                if(!(ap->Next = (struct ArjPrivate *) xadAllocVec(XADM sizeof(struct ArjPrivate), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
                  err = XADERR_NOMEMORY;
                else
                {
                  ap = ap->Next;
                  ap->CRC = EndGetI32(ah->arj_CRC);
                  ap->Method = ah->arj_Method;
                  ap->Flags = ah->arj_Flags;
                  ap->PwdModifier = ah->arj_GarblePasswordModifier;
                  ap->DataPos = ai->xai_InPos;
                  ap->FileEndPos = ap->Size = EndGetI32(ah->arj_Size);
                  if(ah->arj_FirstHeaderSize >= 0x22)
                    ap->FileEndPos += EndGetI32(ah->arj_ExtFilePos);
                  else
                    ap->FileEndPos += lfi->xfi_Size;
                  ap->CrSize = EndGetI32(ah->arj_CompSize);
                  lfi->xfi_Size += ap->Size;
                  lfi->xfi_CrunchSize += ap->CrSize;
                  if(ah->arj_Flags & ARJFLAG_GARBLED)
                  {
                    lfi->xfi_Flags |= XADFIF_CRYPTED;
                    ai->xai_Flags |= XADAIF_CRYPTED;
                  }
                  if(ap->CrSize)
                    err = xadHookAccess(XADM XADAC_INPUTSEEK, ap->CrSize, 0, ai);
                }
              }
              else if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
              namelength, commentlength ? XAD_OBJCOMMENTSIZE : TAG_IGNORE, commentlength+1,
              XAD_OBJPRIVINFOSIZE, sizeof(struct ArjPrivate), TAG_DONE)))
                return XADERR_NOMEMORY;
              else
              {
                if(lfi)
                {
                  for(ap = (struct ArjPrivate *) lfi->xfi_PrivateInfo; ap->Next; ap = ap->Next)
                    ;
                  if(ap->Flags & ARJFLAG_VOLUME)
                    lfi->xfi_Flags |= XADFIF_PARTIALFILE;
                }
                if(ah->arj_Flags & ARJFLAG_EXTFILE)
                  fi->xfi_Flags |= XADFIF_PARTIALFILE;
                ap = (struct ArjPrivate *) fi->xfi_PrivateInfo;

                xadCopyMem(XADM n, fi->xfi_FileName, namelength);
                if(commentlength)
                  xadCopyMem(XADM n+namelength, fi->xfi_Comment, commentlength);
                xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(ah->arj_Date), XAD_GETDATEXADDATE,
                &fi->xfi_Date, TAG_DONE);
                xadConvertProtection(XADM XAD_PROTMSDOS, EndGetI16(ah->arj_FileAccessMode),
                XAD_GETPROTFILEINFO, fi, TAG_DONE);

                ap->CRC = EndGetI32(ah->arj_CRC);
                ap->Method = ah->arj_Method;
                ap->Flags = ah->arj_Flags;
                ap->PwdModifier = ah->arj_GarblePasswordModifier;
                ap->DataPos = ai->xai_InPos;
                ap->FileEndPos = fi->xfi_Size = ap->Size = EndGetI32(ah->arj_Size);
                if(ah->arj_FirstHeaderSize >= 0x22)
                  ap->FileEndPos += EndGetI32(ah->arj_ExtFilePos);
                fi->xfi_CrunchSize = ap->CrSize = EndGetI32(ah->arj_CompSize);
                if(ah->arj_FileType == ARJTYPE_DIRECTORY)
                  fi->xfi_Flags |= XADFIF_DIRECTORY;
                if(ah->arj_Flags & ARJFLAG_GARBLED)
                {
                  fi->xfi_Flags |= XADFIF_CRYPTED;
                  ai->xai_Flags |= XADAIF_CRYPTED;
                }

                fi->xfi_EntryInfo = arjtypes[ah->arj_Method];

                err = xadAddFileEntry(XADM fi,  ai, XAD_SETINPOS, ai->xai_InPos+fi->xfi_CrunchSize, TAG_DONE);
                lfi = fi;
              }
            } /* valid CRC ? */
          } /* is header ? */
        }
        if(err)
        {
          ai->xai_Flags |= XADAIF_FILECORRUPT;
          ai->xai_LastError = err;
          err = 0;
        }
      }
      else
      {
        lastpos = ai->xai_InPos;
        err = ArjScanNext(&lastpos, ai, xadMasterBase);
      }
    }
  }
  xadFreeObjectA(XADM ah, 0);

  if(err && ai->xai_FileInfo)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err = XADERR_ILLEGALDATA;
    return 0;
  }

  if(lfi)
  {
    for(ap = (struct ArjPrivate *) lfi->xfi_PrivateInfo; ap->Next; ap = ap->Next)
      ;
    if(ap->Flags & ARJFLAG_VOLUME)
      lfi->xfi_Flags |= XADFIF_PARTIALFILE;
  }

  return err;
}
/**************************************************************************************************/

#define ARJSTRTP         9
#define ARJSTOPP        13

#define ARJSTRTL         0
#define ARJSTOPL         7

static xadINT32 ARJ_Decrunch(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadINT32 err;
  xadUINT32 dicsiz = (1<<15);
  xadSTRPTR text;
  xadINT16 i, c, width, pwr;
  xadUINT32 loc = 0;

  if((text = xadAllocVec(XADM dicsiz, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    --dicsiz;
    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      c = 0;
      pwr = 1 << (ARJSTRTL);
      for(width = (ARJSTRTL); width < (ARJSTOPL); width++)
      {
        if(!xadIOGetBitsHigh(io, 1))
          break;
        c += pwr;
        pwr <<= 1;
      }
      if(width)
        c += xadIOGetBitsHigh(io, width);

      if(!c)
      {
        text[loc++] = xadIOPutChar(io, xadIOGetBitsHigh(io, 8));
        loc &= dicsiz;
      }
      else
      {
        c += 3 - 1;

        i = 0;
        pwr = 1 << (ARJSTRTP);
        for(width = (ARJSTRTP); width < (ARJSTOPP); width++)
        {
          if(!xadIOGetBitsHigh(io, 1))
            break;
          i += pwr;
          pwr <<= 1;
        }
        if(width)
          i += xadIOGetBitsHigh(io, width);
        i = loc - i - 1;
        while(c--)
        {
          text[loc++] = xadIOPutChar(io, text[i++ & dicsiz]);
          loc &= dicsiz;
        }
      }
    }
    err = io->xio_Error;
    xadFreeObjectA(XADM text, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

/**************************************************************************************************/

struct ArjCrypt {
  xadUINT32 pos;
  xadUINT8 mod;
};

static void ARJDecrypt(struct xadInOut *io, xadUINT32 size)
{
  xadUINT32 j;
  xadSTRPTR a, b;
  xadUINT8 q;

  j = ((struct ArjCrypt *) io->xio_InFuncPrivate)->pos;
  q = ((struct ArjCrypt *) io->xio_InFuncPrivate)->mod;

  a = io->xio_InBuffer;
  b = io->xio_ArchiveInfo->xai_Password;
  while(size--)
  {
    if(!b[j]) j = 0;
    *(a++) ^= q+b[j++];
  }
  ((struct ArjCrypt *) io->xio_InFuncPrivate)->pos = j;
}

XADUNARCHIVE(Arj)
{
  xadINT32 err = 0;
  struct ArjCrypt ac;
  struct ArjPrivate *ap;

  for(ap = (struct ArjPrivate *) ai->xai_CurFile->xfi_PrivateInfo; ap && !err; ap = ap->Next)
  {
    xadUINT32 s;

    ac.pos = 0;
    ac.mod = ap->PwdModifier;
    if((ap->Flags & ARJFLAG_GARBLED) && !(ai->xai_Password && *ai->xai_Password))
      err = XADERR_PASSWORD;
    else if((s = ap->DataPos-ai->xai_InPos) && (err = xadHookAccess(XADM XADAC_INPUTSEEK, s, 0, ai)))
      ;
    else
    {
      struct xadInOut *io;

      if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC16, ai, xadMasterBase)))
      {
        io->xio_InSize = ap->CrSize;
        io->xio_OutSize = ap->Size;
        io->xio_CRC32 = (xadUINT32) ~0;
        if(ai->xai_Password)
        {
          io->xio_InFunc = ARJDecrypt;
          io->xio_InFuncPrivate = &ac;
        }

        switch(ap->Method)
        {
        case 0:
          while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
            xadIOPutChar(io, xadIOGetChar(io));
          break;
        case 1: case 2: case 3:
          io->xio_Flags |= XADIOF_NOINENDERR;
          err = LhA_Decrunch(io, LZHUFF6_METHOD);
          break;
        case 4: err = ARJ_Decrunch(io); break;
        default: err = XADERR_DATAFORMAT; break;
        }

        if(!err)
          err = xadIOWriteBuf(io);

        if(!err && io->xio_CRC32 != ~ap->CRC)
          err = XADERR_CHECKSUM;

        xadFreeObjectA(XADM io, 0);
      }
      else
        err = XADERR_NOMEMORY;
    }
  }
  return err;
}

XADFREE(Arj)
{
  struct xadFileInfo *fi, *fi2;
  struct ArjPrivate *ap, *ap2;

  for(fi = ai->xai_FileInfo; fi; fi = fi2)
  {
    fi2 = fi->xfi_Next;
    for(ap = ((struct ArjPrivate *) fi->xfi_PrivateInfo)->Next; ap; ap = ap2)
    {
      ap2 = ap->Next;
      xadFreeObjectA(XADM ap, 0);
    }
    xadFreeObjectA(XADM fi, 0);
  }
  ai->xai_FileInfo = 0;
}

/**************************************************************************************************/

XADRECOGDATA(ArjEXE)
{
  if(data[28] == 'R' && data[29] == 'J' && data[30] == 'S' && data[31] == 'X')
    return 1;
  return 0;
}

XADGETINFO(ArjEXE)
{
  xadUINT32 lastpos = 0;
  xadINT32 err;

  if(!(err = ArjScanNext(&lastpos, ai, xadMasterBase)))
    err = Arj_GetInfo(ai, xadMasterBase);

  return err;
}

/**************************************************************************************************/

XADRECOGDATA(Savage)
{
  if(data[0] == 29 && data[2] == '*' && data[3] == 'S' && data[4] == 'V' &&
  data[5] == 'G' && data[6] == '*' && EndGetI32(data+11) == 901120)
    return 1;
  else
    return 0;
}

XADGETINFO(Savage)
{
  struct xadDiskInfo *xdi;

  if(!(xdi = (struct xadDiskInfo *) xadAllocObjectA(XADM XADOBJ_DISKINFO, 0)))
    return XADERR_NOMEMORY;

  xdi->xdi_EntryNumber = 1;
  xdi->xdi_Cylinders = 80;
/*  xdi->xdi_LowCyl = 0; */
  xdi->xdi_HighCyl = 79;
  xdi->xdi_SectorSize = 512;
  xdi->xdi_TrackSectors = 11;
  xdi->xdi_CylSectors = 22;
  xdi->xdi_Heads = 2;
  xdi->xdi_TotalSectors = 1760;
  xdi->xdi_Flags = XADDIF_SEEKDATAPOS;
/*  xdi->xdi_DataPos = 0; */

  return xadAddDiskEntryA(XADM xdi, ai, 0);
}

struct SavageOutPrivate {
  xadUINT32 start;
  xadUINT32 end;
  xadUINT32 pos;
};

static void SavageOutFunc(struct xadInOut *io, xadUINT32 size)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SavageOutPrivate *p;
  xadUINT32 o, s;

  io->xio_CRC16 = xadCalcCRC16(XADM XADCRC16_ID1, io->xio_CRC16, size, (xadUINT8 *) io->xio_OutBuffer);
  p = (struct SavageOutPrivate *) io->xio_OutFuncPrivate;

  if(p->pos+size >= p->start && p->pos < p->end)
  {
    if(p->start < p->pos)
      p->start = p->pos;
    o = p->start - p->pos;
    s = size - o;
    if(s > p->end - p->start)
      s = p->end - p->start;

    if((io->xio_Error = xadHookAccess(XADM XADAC_WRITE, s, io->xio_OutBuffer + o, io->xio_ArchiveInfo)))
      io->xio_Flags |= XADIOF_ERROR;
  }
  p->pos += size;
}

XADUNARCHIVE(Savage)
{
  xadUINT8 Data[31];
  xadINT32 err;
  struct SavageOutPrivate of;

  of.pos = 0;
  of.start = ai->xai_LowCyl*22*512;
  of.end = (ai->xai_HighCyl+1)*22*512;

  if(!(err = xadHookAccess(XADM XADAC_READ, 31, Data, ai)))
  {
    struct xadInOut *io;
    if((io = xadIOAlloc(XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_COMPLETEOUTFUNC|XADIOF_NOINENDERR,
    ai, xadMasterBase)))
    {
      io->xio_InSize = EndGetI32(Data+7);
      io->xio_OutSize = 901120;
      io->xio_OutFunc = SavageOutFunc;
      io->xio_OutFuncPrivate = &of;

      if(!(err = LhA_Decrunch(io, LZHUFF5_METHOD)))
        err = xadIOWriteBuf(io);

      if(!err && io->xio_CRC16 != EndGetI16(Data + 29))
       err = XADERR_CHECKSUM;

      xadFreeObjectA(XADM io, 0);
    }
    else
      err = XADERR_NOMEMORY;
  }
  return err;
}

/**************************************************************************************************/

XADCLIENT(Savage) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  SAVAGE_VERSION,
  SAVAGE_REVISION,
  31,
  XADCF_DISKARCHIVER|XADCF_FREEDISKINFO,
  XADCID_SAVAGECOMPRESSOR,
  "Savage Compressor",
  XADRECOGDATAP(Savage),
  XADGETINFOP(Savage),
  XADUNARCHIVEP(Savage),
  NULL
};

XADCLIENT(ArjEXE) {
  (struct xadClient *) &Savage_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ARJEXE_VERSION,
  ARJEXE_REVISION,
  32,
  XADCF_FILEARCHIVER,
  XADCID_ARJEXE,
  "Arj MS-EXE",
  XADRECOGDATAP(ArjEXE),
  XADGETINFOP(ArjEXE),
  XADUNARCHIVEP(Arj),
  XADFREEP(Arj)
};

XADCLIENT(Arj) {
  (struct xadClient *) &ArjEXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ARJ_VERSION,
  ARJ_REVISION,
  4,
  XADCF_FILEARCHIVER,
  XADCID_ARJ,
  "Arj",
  XADRECOGDATAP(Arj),
  XADGETINFOP(Arj),
  XADUNARCHIVEP(Arj),
  XADFREEP(Arj)
};

XADCLIENT(Zoo) {
  (struct xadClient *) &Arj_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  ZOO_VERSION,
  ZOO_REVISION,
  24,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO,
  XADCID_ZOO,
  "Zoo",
  XADRECOGDATAP(Zoo),
  XADGETINFOP(Zoo),
  XADUNARCHIVEP(Zoo),
  NULL
};

XADCLIENT(LhAEXE) {
  (struct xadClient *) &Zoo_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHAEXE_VERSION,
  LHAEXE_REVISION,
  44,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_LHAEXE,
  "LhA MS-EXE",
  XADRECOGDATAP(LhAEXE),
  XADGETINFOP(LhAEXE),
  XADUNARCHIVEP(LhA),
  NULL
};

XADCLIENT(LhAC64SFX) {
  (struct xadClient *) &LhAEXE_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHAC64SFX_VERSION,
  LHAC64SFX_REVISION,
  0xE90,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_LHAC64SFX,
  "LhA C64 SFX",
  XADRECOGDATAP(LhAC64SFX),
  XADGETINFOP(LhAC64SFX),
  XADUNARCHIVEP(LhA),
  NULL
};

XADCLIENT(LhASFX) {
  (struct xadClient *) &LhAC64SFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHASFX_VERSION,
  LHASFX_REVISION,
  0x30,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_LHASFX,
  "LhA SFX",
  XADRECOGDATAP(LhASFX),
  XADGETINFOP(LhASFX),
  XADUNARCHIVEP(LhA),
  XADFREEP(LhASFX)
};

XADFIRSTCLIENT(LhA) {
  (struct xadClient *) &LhASFX_Client,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  LHA_VERSION,
  LHA_REVISION,
  4,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_LHA,
  "LhA",
  XADRECOGDATAP(LhA),
  XADGETINFOP(LhA),
  XADUNARCHIVEP(LhA),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(LhA)

#endif /* XADMASTER_LHA_C */
