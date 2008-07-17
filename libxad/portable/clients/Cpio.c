#ifndef XADMASTER_CPIO_C
#define XADMASTER_CPIO_C

/*  $Id: Cpio.c,v 1.10 2005/06/23 14:54:40 stoecker Exp $
    Cpio file archiver client

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

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION        11
#endif

XADCLIENTVERSTR("Cpio 2.2 (30.3.2004)")

#define CPIO_VERSION            2
#define CPIO_REVISION           2

#define UP_IFMT         00170000
#define UP_IFSOCK        0140000
#define UP_IFLNK         0120000
#define UP_IFREG         0100000
#define UP_IFBLK         0060000
#define UP_IFDIR         0040000
#define UP_IFCHR         0020000
#define UP_IFIFO         0010000

#define UP_ISLNK(m)     (((m) & UP_IFMT) == UP_IFLNK)
#define UP_ISREG(m)     (((m) & UP_IFMT) == UP_IFREG)
#define UP_ISDIR(m)     (((m) & UP_IFMT) == UP_IFDIR)
#define UP_ISCHR(m)     (((m) & UP_IFMT) == UP_IFCHR)
#define UP_ISBLK(m)     (((m) & UP_IFMT) == UP_IFBLK)
#define UP_ISFIFO(m)    (((m) & UP_IFMT) == UP_IFIFO)
#define UP_ISSOCK(m)    (((m) & UP_IFMT) == UP_IFSOCK)

struct CpioHeaderNorm {
  xadUINT8 ch_INode[8];            /*   6 */
  xadUINT8 ch_Mode[8];             /*  14 */
  xadUINT8 ch_UserID[8];           /*  22 */
  xadUINT8 ch_GroupID[8];          /*  30 */
  xadUINT8 ch_LinkName[8];         /*  38 */
  xadUINT8 ch_MTime[8];            /*  46 */
  xadUINT8 ch_Size[8];             /*  54 */
  xadUINT8 ch_DevMajor[8];         /*  62 */
  xadUINT8 ch_DevMinor[8];         /*  70 */
  xadUINT8 ch_RDevMajor[8];        /*  78 */
  xadUINT8 ch_RDevMinor[8];        /*  86 */
  xadUINT8 ch_NameSize[8];         /*  94 */
  xadUINT8 ch_Checksum[8];         /* 102 */
};

struct CpioHeaderExt {
  xadUINT8 ch_Dev[6];              /* device number */
  xadUINT8 ch_Inode[6];            /* inode number */
  xadUINT8 ch_Mode[6];             /* file type/access */
  xadUINT8 ch_UserID[6];           /* owners uid */
  xadUINT8 ch_GroupID[6];          /* owners gid */
  xadUINT8 ch_NLink[6];            /* # of links at archive creation */
  xadUINT8 ch_DevMajor[3];         /* block/char major # */
  xadUINT8 ch_DevMinor[3];         /* block/char minor # */
  xadUINT8 ch_MTime[11];           /* modification time */
  xadUINT8 ch_NameSize[6];         /* length of pathname */
  xadUINT8 ch_Size[11];            /* length of file in bytes */
};

struct CpioHeader {             /* byte offset */
  xadUINT8 ch_Magic[6];            /*   0 */
  union {
    struct CpioHeaderNorm ch_Norm;
    struct CpioHeaderExt  ch_Ext;
  } ch_Data;
};

static xadUINT32 cpio_hextonum(xadSTRPTR hex, xadINT32 width, xadINT32 *ok)
{
  xadUINT32 i = 0;

  while(width-- && isxdigit(*hex))
   i = isdigit(*hex) ? (i*16)+*(hex++)-'0' : (i*16)+*(hex++)-'a'+10;

  if(width > 0)
    *ok = 0;

  return i;
}

static xadUINT32 cpio_octtonum(xadSTRPTR hex, xadINT32 width, xadINT32 *ok)
{
  xadUINT32 i = 0;

  while(width-- && *hex >= '0' && *hex <= '7')
    i = (i*8)+*(hex++)-'0';

  if(width > 0)       /* an error, set error flag */
    *ok = 0;

  return i;
}

XADRECOGDATA(Cpio)
{
  if(data[0] == '0' && data[1] == '7' && data[2] == '0' &&
  data[3] == '7' && data[4] == '0' && (data[5] == '1' || data[5] == '2'
  || data[5] == '7'))
    return 1;
  else
    return 0;
}

XADGETINFO(Cpio)
{
  struct CpioHeader ch;
  struct xadFileInfo *fi;
  xadINT32 err = 0, size, ok = 1, a, b, type;
  xadSTRPTR ch_Name;               /* 110 */

  while(!err && ai->xai_InPos+sizeof(struct CpioHeader) < ai->xai_InSize &&
  !(err = xadHookAccess(XADM XADAC_READ, 6, &ch, ai)) &&
  !(err = xadHookAccess(XADM XADAC_READ, ch.ch_Magic[5] == '7' ?
  sizeof(struct CpioHeaderExt) : sizeof(struct CpioHeaderNorm), &ch.ch_Data, ai)))
  {
    if(ch.ch_Magic[5] == '7')
    {
      a = cpio_octtonum((xadSTRPTR) ch.ch_Data.ch_Ext.ch_NameSize, 6, &ok);
    }
    else
    {
      a = cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_NameSize, 8, &ok);
      a = ((2+a+3)&(~3))-2;
    }

    if(!(ch_Name = (xadSTRPTR) xadAllocVec(XADM (xadUINT32) a, XADMEMF_ANY|XADMEMF_CLEAR)))
      err = XADERR_NOMEMORY;
    else
      err = xadHookAccess(XADM XADAC_READ, (xadUINT32) a, ch_Name, ai);
    if(ch_Name && strcmp(ch_Name, "TRAILER!!!"))
    {
      if(ch.ch_Magic[5] == '7')
      {
        size = cpio_octtonum((xadSTRPTR) ch.ch_Data.ch_Ext.ch_Size, 11, &ok);
        type = cpio_octtonum((xadSTRPTR) ch.ch_Data.ch_Ext.ch_Mode, 6, &ok);
      }
      else
      {
        size = cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_Size, 8, &ok);
        type = cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_Mode, 8, &ok);
      }
      if(ok)
      {
        b = UP_ISLNK(type) ? size+1 : 0;
        if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
        XAD_OBJNAMESIZE, a+b, TAG_DONE)))
        {
          fi->xfi_DataPos = ai->xai_InPos;
          fi->xfi_Flags = XADFIF_SEEKDATAPOS;

          if(UP_ISDIR(type))
          {
            fi->xfi_Flags |= XADFIF_DIRECTORY;
          }
          else if(UP_ISLNK(type))
          {
            fi->xfi_Flags |= XADFIF_LINK;
            fi->xfi_LinkName = fi->xfi_FileName + a;
            err = xadHookAccess(XADM XADAC_READ, (xadUINT32) size, fi->xfi_LinkName, ai);
            if(ch.ch_Magic[5] == '7')
              size = 0;
          }
          else if(UP_ISFIFO(type))
          {
            fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
            fi->xfi_FileType = XADFILETYPE_UNIXFIFO;
          }
          else if(UP_ISCHR(type) || UP_ISBLK(type))
          {
            fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
            fi->xfi_FileType = UP_ISBLK(type) ? XADFILETYPE_UNIXBLOCKDEVICE
            : XADFILETYPE_UNIXCHARDEVICE;
            /* do not care if this fails, as it is not that important */
            if((fi->xfi_Special = xadAllocObjectA(XADM XADOBJ_SPECIAL, 0)))
            {
              fi->xfi_Special->xfis_Type = XADSPECIALTYPE_UNIXDEVICE;
              if(ch.ch_Magic[5] == '7')
              {
                fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MajorVersion =
                cpio_octtonum((xadSTRPTR) ch.ch_Data.ch_Ext.ch_DevMajor, 3, &ok);
                fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MinorVersion =
                cpio_octtonum((xadSTRPTR) ch.ch_Data.ch_Ext.ch_DevMinor, 3, &ok);
              }
              else
              {
                fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MajorVersion =
                cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_DevMajor, 8, &ok);
                fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MinorVersion =
                cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_DevMinor, 8, &ok);
              }
            }
          }
          else
          {
            fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
            fi->xfi_CrunchSize = fi->xfi_Size = size;
          }

          if(!err)
          {
            xadCopyMem(XADM ch_Name, fi->xfi_FileName, (xadUINT32)a);
            if(ch.ch_Magic[5] == '7')
            {
              fi->xfi_OwnerUID = cpio_octtonum((xadSTRPTR)ch.ch_Data.ch_Ext.ch_UserID, 6, &ok);
              fi->xfi_OwnerGID = cpio_octtonum((xadSTRPTR)ch.ch_Data.ch_Ext.ch_GroupID, 6, &ok);
              a = cpio_octtonum((xadSTRPTR)ch.ch_Data.ch_Ext.ch_Mode, 6, &ok);
              b = cpio_octtonum((xadSTRPTR)ch.ch_Data.ch_Ext.ch_MTime, 11, &ok);
            }
            else
            {
              fi->xfi_OwnerUID = cpio_hextonum((xadSTRPTR)ch.ch_Data.ch_Norm.ch_UserID, 8, &ok);
              fi->xfi_OwnerGID = cpio_hextonum((xadSTRPTR)ch.ch_Data.ch_Norm.ch_GroupID, 8, &ok);
              a = cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_Mode, 8, &ok);
              b = cpio_hextonum((xadSTRPTR) ch.ch_Data.ch_Norm.ch_MTime, 8, &ok);
              size = (size+3)&(~3);
            }

            xadConvertProtection(XADM XAD_PROTUNIX, a, XAD_GETPROTFILEINFO, fi,
            TAG_DONE);
            xadConvertDates(XADM XAD_DATEUNIX, b, XAD_MAKELOCALDATE, 1,
            XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

            err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, fi->xfi_DataPos+size,
            TAG_DONE);
          }
          else
            xadFreeObjectA(XADM fi, 0);
        }
        else
          err = XADERR_NOMEMORY;
      }
      else
        err = XADERR_ILLEGALDATA;
    }
    if(ch_Name)
    {
      ok = strcmp(ch_Name, "TRAILER!!!");
      xadFreeObjectA(XADM ch_Name, 0);
      if(!ok)
        break; /* stop after trailer block */
    }
  }

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

XADUNARCHIVE(Cpio)
{
  return xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size, 0, ai);
}

XADFIRSTCLIENT(Cpio) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  CPIO_VERSION,
  CPIO_REVISION,
  6,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_CPIO,
  "Cpio",
  XADRECOGDATAP(Cpio),
  XADGETINFOP(Cpio),
  XADUNARCHIVEP(Cpio),
  NULL
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Cpio)

#endif /* XADASTER_CPIO_C */
