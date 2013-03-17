#ifndef XADMASTER_TAR_C
#define XADMASTER_TAR_C

/*  $Id: Tar.c,v 1.10 2005/06/23 14:54:41 stoecker Exp $
    Tar file archiver client

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
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION 11
#endif

XADCLIENTVERSTR("Tar 1.11 (21.02.2004)")

#define TAR_VERSION             1
#define TAR_REVISION            11

struct TarHeader
{                               /* byte offset */
  xadUINT8 th_Name[100];           /*   0 */
  xadUINT8 th_Mode[8];             /* 100 */
  xadUINT8 th_UserID[8];           /* 108 */
  xadUINT8 th_GroupID[8];          /* 116 */
  xadUINT8 th_Size[12];            /* 124 */
  xadUINT8 th_MTime[12];           /* 136 */
  xadUINT8 th_Checksum[8];         /* 148 */
  xadUINT8 th_Typeflag;            /* 156 */
  xadUINT8 th_LinkName[100];       /* 157 */
  xadUINT8 th_Magic[6];            /* 257 */
  xadUINT8 th_Version[2];          /* 263 */
  xadUINT8 th_UserName[32];        /* 265 */
  xadUINT8 th_GroupName[32];       /* 297 */
  xadUINT8 th_DevMajor[8];         /* 329 */
  xadUINT8 th_DevMinor[8];         /* 337 */
  xadUINT8 th_Prefix[155];         /* 345 */
  xadUINT8 th_Pad[12];             /* 500 */
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
#define TF_LONGLINK     'K'  /* longlinkname block, preceedes the full block */
#define TF_LONGNAME     'L'  /* longname block, preceedes the full block */

static xadUINT32 octtonum(xadSTRPTR oct, xadINT32 width, xadINT32 *ok)
{
  xadUINT32 i = 0;

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

static xadBOOL checktarsum(struct TarHeader *th)
{
  xadINT32 sc, i;
  xadUINT32 uc, checks;

  i = 1;
  checks = octtonum((xadSTRPTR)th->th_Checksum, 8, &i);
  if(!i)
    return 0;

  for(i = sc = uc = 0; i < 512; ++i)
  {
    sc += ((xadINT8 *) th)[i];
    uc += ((xadUINT8 *) th)[i];
  }

  for(i = 148; i < 156; ++i)
  {
    sc -= ((xadINT8 *) th)[i];
    uc -= ((xadUINT8 *) th)[i];
  }
  sc += 8 * ' ';
  uc += 8 * ' ';

  if(checks != uc && checks != (xadUINT32) sc)
    return 0;
  return 1;
}

XADRECOGDATA(Tar)
{
  if(data[0] > 0x1F && checktarsum((struct TarHeader *) data))
    return 1;
  else
    return 0;
}

XADGETINFO(Tar)
{
  struct TarHeader th;
  struct xadFileInfo *fi;
  xadINT32 err = 0, size, ok, a, b, d, i, pos;
  xadSTRPTR longname = 0, longlink = 0, name, link;

  while(!err && ai->xai_InPos < ai->xai_InSize &&
  !(err = xadHookAccess(XADM XADAC_READ, sizeof(struct TarHeader), &th, ai)))
  {
    if(!th.th_Name[0])
      break;
    ok = checktarsum(&th); /* check checksum and init ok */
    size = octtonum((xadSTRPTR)th.th_Size, 12, &ok);

    pos = ai->xai_InPos;
    if(ok && th.th_Typeflag == TF_LONGNAME)
    {
      if((longname = xadAllocVec(XADM (xadUINT32)size, XADMEMF_ANY)))
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, (xadUINT32)size, longname, ai)))
        {
          size %= 512;
          if(size)
            err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32)512-size, 0, ai);
        }
      }
      else
        err = XADERR_NOMEMORY;
    }
    else if(ok && th.th_Typeflag == TF_LONGLINK)
    {
      if((longlink = xadAllocVec(XADM (xadUINT32)size, XADMEMF_ANY)))
      {
        if(!(err = xadHookAccess(XADM XADAC_READ, (xadUINT32)size, longlink, ai)))
        {
          size %= 512;
          if(size)
            err = xadHookAccess(XADM XADAC_INPUTSEEK, (xadUINT32)512-size, 0, ai);
        }
      }
      else
        err = XADERR_NOMEMORY;
    }
    else if(ok && (th.th_Typeflag == TF_FILE || th.th_Typeflag == TF_AFILE ||
    th.th_Typeflag == TF_DIR || th.th_Typeflag == TF_SYM ||
    th.th_Typeflag == TF_LINK || th.th_Typeflag == TF_BLOCK ||
    th.th_Typeflag == TF_CHAR || th.th_Typeflag == TF_FIFO))
    {
      name = longname ? longname : (xadSTRPTR) th.th_Name;
      link = longlink ? longlink : (th.th_LinkName[0] ? (xadSTRPTR) th.th_LinkName : 0);
      a = strlen(name) + 1;

      if(name[a-2] == '/')
      {
        if(th.th_Typeflag == TF_AFILE || th.th_Typeflag == TF_FILE
        || th.th_Typeflag == TF_DIR)
        {
          name[--a-1] == 0;
          th.th_Typeflag = TF_DIR;
        }
      }

      if(!longname && th.th_Prefix[0])
        a += strlen((char *)th.th_Prefix)+1;

      b = link ? 1 + strlen(link) : 0;
      i = th.th_UserName[0] ? 1 + strlen((char *)th.th_UserName) : 0;
      d = th.th_GroupName[0] ? 1 + strlen((char *)th.th_GroupName) : 0;

      if(!(fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO,
      XAD_OBJNAMESIZE, a+b+i+d, TAG_DONE)))
        err = XADERR_NOMEMORY;
      else
      {
        fi->xfi_DataPos = pos;
        fi->xfi_Flags = XADFIF_SEEKDATAPOS;
        if(th.th_Typeflag == TF_LINK || th.th_Typeflag == TF_SYM)
          fi->xfi_Flags |= XADFIF_LINK;
        else if(th.th_Typeflag == TF_DIR)
        {
          fi->xfi_Flags |= XADFIF_DIRECTORY;
          size = 0;
        }
        else if(th.th_Typeflag == TF_FIFO)
        {
          fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
          fi->xfi_FileType = XADFILETYPE_UNIXFIFO;
        }
        else if(th.th_Typeflag == TF_BLOCK || th.th_Typeflag == TF_CHAR)
        {
          fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
          fi->xfi_FileType = th.th_Typeflag == TF_BLOCK ?
          XADFILETYPE_UNIXBLOCKDEVICE : XADFILETYPE_UNIXCHARDEVICE;
          /* do not care if this fails, as it is not that important */
          if((fi->xfi_Special = xadAllocObjectA(XADM XADOBJ_SPECIAL, 0)))
          {
            fi->xfi_Special->xfis_Type = XADSPECIALTYPE_UNIXDEVICE;
            fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MajorVersion
            = octtonum((xadSTRPTR)th.th_DevMajor, 8, &ok);
            fi->xfi_Special->xfis_Data.xfis_UnixDevice.xfis_MinorVersion
            = octtonum((xadSTRPTR)th.th_DevMinor, 8, &ok);
          }
        }
        else
        {
          fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
          fi->xfi_CrunchSize = fi->xfi_Size = size;
        }

        if(!longname && th.th_Prefix[0])
        {
          xadSTRPTR s, t;

          t = (xadSTRPTR) fi->xfi_FileName; s = (xadSTRPTR) th.th_Prefix;
          while(*s)
            *(t++) = *(s++);
          if(*(t-1) != '/')
            *(t++) = '/';
          s = (xadSTRPTR) th.th_Name;
          while(*s)
            *(t++) = *(s++);
          if(*(t-1) == '/')
            --t;
          *t = 0;
        }
        else
          xadCopyMem(XADM name, fi->xfi_FileName, (xadUINT32)a-1);
        if(b)
        {
          fi->xfi_LinkName = fi->xfi_FileName + a;
          xadCopyMem(XADM link, fi->xfi_LinkName, (xadUINT32)b-1);
        }
        if(i)
        {
          fi->xfi_UserName = fi->xfi_FileName + a + b;
          xadCopyMem(XADM th.th_UserName, fi->xfi_UserName, (xadUINT32)i-1);
        }
        if(d)
        {
          fi->xfi_GroupName = fi->xfi_FileName + a + b + i;
          xadCopyMem(XADM th.th_GroupName, fi->xfi_GroupName, (xadUINT32)d-1);
        }
        fi->xfi_OwnerUID = octtonum((xadSTRPTR)th.th_UserID, 8, &ok);
        fi->xfi_OwnerGID = octtonum((xadSTRPTR)th.th_GroupID, 8, &ok);

        xadConvertProtection(XADM XAD_PROTUNIX, octtonum((xadSTRPTR)th.th_Mode, 8, &ok),
        XAD_GETPROTFILEINFO, fi, TAG_DONE);

        xadConvertDates(XADM XAD_DATEUNIX, octtonum((xadSTRPTR)th.th_MTime, 12, &ok),
        XAD_MAKELOCALDATE, 0, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);

        if(th.th_Typeflag == TF_FILE || th.th_Typeflag == TF_AFILE)
          size = (size+511)&~511;
        else
          size = 0;

        err = xadAddFileEntry(XADM fi, ai, XAD_SETINPOS, ai->xai_InPos+size,
        TAG_DONE);
      }
      if(th.th_Typeflag != TF_LONGNAME && longname)
      {
        xadFreeObjectA(XADM longname, 0); longname = 0;
      }
    }
  }

  if(longname)
    xadFreeObjectA(XADM longname, 0);

  if(err)
  {
    ai->xai_Flags |= XADAIF_FILECORRUPT;
    ai->xai_LastError = err;
  }

  return (ai->xai_FileInfo ? 0 : err);
}

XADUNARCHIVE(Tar)
{
  return xadHookAccess(XADM XADAC_COPY, ai->xai_CurFile->xfi_Size, 0, ai);
}

XADFIRSTCLIENT(Tar)
{
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  TAR_VERSION,
  TAR_REVISION,
  512,
  XADCF_FILEARCHIVER|XADCF_FREEFILEINFO|XADCF_FREESPECIALINFO,
  XADCID_TAR,
  "Tar",
  XADRECOGDATAP(Tar),
  XADGETINFOP(Tar),
  XADUNARCHIVEP(Tar),
  0
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(Tar)

#endif /* XADMASTER_TAR_C */
