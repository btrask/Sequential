#ifndef XADMASTER_FS_AMIGA_C
#define XADMASTER_FS_AMIGA_C

/*  $Id: FS_Amiga.c,v 1.12 2006/06/01 06:55:03 stoecker Exp $
    amiga filesytem client

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>

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

#include "../unix/xadClient.h"

#ifndef XADMASTERVERSION
  #define XADMASTERVERSION      10
#endif

XADCLIENTVERSTR("FS_Amiga 1.2 (22.2.2004)")

#define FSAMIGA_VERSION         1
#define FSAMIGA_REVISION        2

#define T_SHORT          2
#define T_DATA           8
#define T_LIST          16
#define T_DIRCACHE      33
#define ST_ROOT          1
#define ST_USERDIR       2
#define ST_FILE         -3
#define ST_LINKFILE     -4
#define ST_LINKDIR       4
#define ST_SOFTLINK      3

/* all the structures have been rearranged to get variable size parts
to structure end. Therefor they cannot be copied from file directly, but need
to be modified! The afs_ structure elements are standard elements, which
offsets are equal in all structures! */

#define afs_SoftLinkName        afs_HashTable
#define afs_BlockList           afs_HashTable
#define afs_DirCache            afs_Extension

struct RootBlock
{
  xadUINT8 afs_Type[4];            /* T_SHORT */
  xadUINT8 afs_HeaderKey[4];       /* == 0 */
  xadUINT8 afs_BlockCount[4];      /* == 0 */
  xadUINT8 afs_HashTableSize[4];
  xadUINT8 afs_FirstBlock[4];      /* == 0 */
  xadUINT8 afs_CheckSum[4];

  xadINT8  afs_BitmapFlag[4];      /* signed, -1=valid, 0=invalid */
  xadUINT8 afs_BitmapKeys[25][4];
  xadUINT8 afs_BitmapExtend[4];
  xadUINT8 afs_Date[12];           /* last root alteration */
  xadUINT8 afs_Name[32];           /* BCPL name, max 30 chars */
  xadUINT8 Unused3[4];                 
  xadUINT8 Unused4[4];                 
  xadUINT8 afs_DiskDate[12];       /* last disk alteration */
  xadUINT8 afs_DiskMade[12];       /* disk creation date */
  xadUINT8 afs_HashChain[4];       /* == 0 */
  xadUINT8 afs_Parent[4];          /* == 0 */
  xadUINT8 afs_Extension[4];       /* dircache pointer */
  xadUINT8 afs_SecondaryType[4];   /* ST_ROOT */

  xadUINT8 afs_HashTable[72][4];
};

struct FileHeaderBlock
{
  xadUINT8 afs_Type[4];         /* T_SHORT */
  xadUINT8 afs_HeaderKey[4];
  xadUINT8 afs_BlockCount[4];
  xadUINT8 afs_DataSize[4];
  xadUINT8 afs_FirstBlock[4];
  xadUINT8 afs_CheckSum[4];

  xadUINT8 Unused1[4];
  xadUINT8 afs_OwnerInfo[4];
  xadUINT8 afs_Protection[4];
  xadUINT8 afs_Size[4];         /* real files only */
  xadUINT8 afs_Comment[92];     /* BCPL name, max 79 chars */
  xadUINT8 afs_Date[12];
  xadUINT8 afs_Name[32];        /* BCPL name, max 30 chars */
  xadUINT8 Unused2[4];
  xadUINT8 afs_LinkOriginal[4]; /* hard links only */
  xadUINT8 afs_LinkList[4];     /* not for soft links */
  xadUINT8 Unused3[5][4];
  xadUINT8 afs_HashList[4];
  xadUINT8 afs_Parent[4];
  xadUINT8 afs_Extension[4];    /* real files only, Dircache for DOS4,5 dirs */
  xadINT8  afs_SecondaryType[4];/* signed; ST_FILE, ST_LINKFILE, ST_LINKDIR, ST_USERDIR, ST_SOFTLINK */

  xadUINT8 afs_HashTable[72][4];/* maybe larger!, unused for links */
};

struct FileExtensionBlock
{
  xadUINT8  afs_Type[4];         /* T_SHORT */
  xadUINT8  afs_HeaderKey[4];
  xadUINT8  afs_BlockCount[4];
  xadUINT8  afs_DataSize[4];
  xadUINT8  afs_FirstBlock[4];
  xadUINT8  afs_CheckSum[4];
               
  xadUINT8  Unused1[47][4];
               
  xadUINT8  afs_Parent[4];
  xadUINT8  afs_Extension[4];
  xadINT8   afs_SecondaryType[4];/* signed; ST_FILE */
               
  xadUINT8  afs_BlockList[72][4];/* maybe larger!, unused for links */
};

struct DirCacheBlock /* no reorder necessary */
{
  xadUINT8 afs_Type[4];
  xadUINT8 afs_HeaderKey[4];
  xadUINT8 afs_DCParent[4];
  xadUINT8 afs_DCRecords[4];
  xadUINT8 afs_NextDirCache[4];
  xadUINT8 afs_CheckSum[4];
  xadUINT8 afs_Records[488][4];  /* maybe larger! */
};

struct BitMapBlock /* no reorder necessary */
{
  xadUINT8 bm_CheckSum[4];
  xadUINT8 bm_Data[127][4];        /* maybe larger! */
};

struct BitmapExtensionBlock
{
  xadUINT8 be_NextBlock[4];

  xadUINT8 be_BMPages[127][4];         /* maybe larger! */
};

struct xadLink {
  struct xadLink *       xl_Next;
  struct xadFileInfo *   xl_Parent;
  struct FileHeaderBlock xl_Header;
};

struct DiskParseData
{
  xadUINT32               Corrupt;
  struct xadArchiveInfo * ai;
  struct xadMasterBase *  MasterBase;
  struct xadFileInfo *    DirList;
  struct xadFileInfo *    CurDir;
  struct xadLink *        LinkList;
  struct FileHeaderBlock *fh1; /* always the dir/root header */
  struct FileHeaderBlock *fh2;
  xadSTRPTR               BList;
};

static xadINT32 getdiskblock(struct xadMasterBase *xadMasterBase, struct xadArchiveInfo *ai,
xadUINT32 block, xadSTRPTR buf, xadUINT32 r)
{
  xadINT32 err = 0;
  xadSize i;
  struct xadImageInfo *ii;

  ii = ai->xai_ImageInfo;

  if(block < ii->xii_FirstSector || block > ii->xii_FirstSector+ii->xii_NumSectors-1)
    err = XADERR_ILLEGALDATA;
  else
  {
    if((i = ((block - ii->xii_FirstSector)*ii->xii_SectorSize)-ai->xai_InPos))
      err = xadHookAccess(XADM XADAC_INPUTSEEK, i, 0, ai);
    if(!err)
      err = xadHookAccess(XADM XADAC_READ, ii->xii_SectorSize, buf, ai);
  }

  if(r && !err)
  {
    xadUINT8 b[50*4];
    xadCopyMem(XADM buf+(ii->xii_SectorSize-(50*4)), b, 50*4);
    xadCopyMem(XADM buf+(6*4), buf+(56*4), (ii->xii_SectorSize-(56*4)));
    xadCopyMem(XADM b, buf+(6*4), 50*4);
  }
  return err;
}

static xadINT32 parsedir(struct DiskParseData *parse)
{
  xadINT32 err = 0;
  xadUINT32 blk, i, j, c, curnamesize = 0;
  xadSTRPTR curdirname = 0, str;
  struct xadLink *l;
  struct FileHeaderBlock *fh;
  struct xadFileInfo *fi;
  struct xadMasterBase *xadMasterBase;
  struct xadImageInfo *ii;

  if(parse->CurDir)
  {
    curdirname = parse->CurDir->xfi_FileName;
    curnamesize = strlen((const char *)curdirname);
  }

  ii = parse->ai->xai_ImageInfo;
  xadMasterBase = parse->MasterBase;
  blk = (ii->xii_SectorSize>>2)-56;
  fh = parse->fh2;
  for(i = 0; !err && i < blk; ++i)
  {
    if((j = EndGetM32(parse->fh1->afs_HashTable[i])))
    {
      c = 0;
      do
      {
        xadUINT32 b, a = 0, e = 1;

        if(j >= ii->xii_FirstSector && j <= ii->xii_FirstSector+ii->xii_NumSectors-1)
        {
          b = j - ii->xii_FirstSector;
          if(!(parse->BList[b>>3]&(1<<(b&7))))
          {
            parse->BList[b>>3] |= (1<<(b&7));
            if(!(err = getdiskblock(xadMasterBase, parse->ai, j, (xadSTRPTR) parse->fh2, 1)) &&
            EndGetM32(parse->fh2->afs_Type) == T_SHORT)
            {
              if(EndGetM32(parse->fh2->afs_HeaderKey) != j)
                ++c;
              for(b = 0; b < ii->xii_SectorSize; b += 4)
                a += EndGetM32(((xadUINT8 *)parse->fh2) + b);
              if(!a)
                e = 0;
            }
          }
        }
        if(!e)
        {
          switch(EndGetM32(fh->afs_SecondaryType))
          {
          case ST_LINKFILE: case ST_LINKDIR:
            if((l = xadAllocVec(XADM sizeof(struct xadLink)-512+ii->xii_SectorSize, XADMEMF_CLEAR|XADMEMF_PUBLIC)))
            {
              xadCopyMem(XADM (xadPTR) fh, (xadPTR) &l->xl_Header, ii->xii_SectorSize);
              l->xl_Next = parse->LinkList;
              l->xl_Parent = parse->CurDir;
              parse->LinkList = l;
            }
            else
              err = XADERR_NOMEMORY;
            break;
          case ST_SOFTLINK:
            j = strlen((const char *)fh->afs_SoftLinkName)+1;
            if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
            fh->afs_Name[0] + curnamesize+1+1+j,fh->afs_Comment[0] ? XAD_OBJCOMMENTSIZE :
            TAG_DONE, fh->afs_Comment[0]+1, TAG_DONE)))
            {
              fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) j; /* store block number */
              str = fi->xfi_FileName;
              if(curnamesize)
              {
                xadCopyMem(XADM curdirname, str, curnamesize);
                str += curnamesize;
                *(str++) = '/';
              }
              xadCopyMem(XADM fh->afs_Name+1,str,fh->afs_Name[0]);
              fi->xfi_LinkName = str + fh->afs_Name[0] +1;
              fi->xfi_Flags |= XADFIF_DIRECTORY|XADFIF_LINK;
              xadCopyMem(XADM (xadPTR) fh->afs_SoftLinkName,fi->xfi_LinkName,j);
              if(fh->afs_Comment[0])
                xadCopyMem(XADM fh->afs_Comment+1,fi->xfi_Comment,fh->afs_Comment[0]);
              xadConvertDates(XADM XAD_DATEDATESTAMP, &fh->afs_Date, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
              fi->xfi_Size = fi->xfi_CrunchSize = EndGetM32(fh->afs_Size);
              fi->xfi_Protection = EndGetM32(fh->afs_Protection);
              fi->xfi_OwnerUID = EndGetM32(fh->afs_OwnerInfo) >> 16;
              fi->xfi_OwnerGID = EndGetM32(fh->afs_OwnerInfo) & 0xFFFF;
              err = xadAddFileEntry(XADM fi, parse->ai, XAD_INSERTDIRSFIRST, XADTRUE, TAG_DONE);
            }
            else
              err = XADERR_NOMEMORY;
            break;
          case ST_USERDIR:
            if((str = (xadSTRPTR) xadAllocVec(XADM ii->xii_SectorSize, XADMEMF_PUBLIC)))
            {
              if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
              fh->afs_Name[0] + curnamesize+1+1, fh->afs_Comment[0] ? XAD_OBJCOMMENTSIZE :
              TAG_DONE, fh->afs_Comment[0]+1, TAG_DONE)))
              {
                fi->xfi_PrivateInfo = str;
                xadCopyMem(XADM (xadPTR) fh, str, ii->xii_SectorSize); /* store the dir block */
                fi->xfi_Next = parse->DirList;
                parse->DirList = fi;
                str = fi->xfi_FileName;
                if(curnamesize)
                {
                  xadCopyMem(XADM curdirname, str, curnamesize);
                  str += curnamesize;
                  *(str++) = '/';
                }
                xadCopyMem(XADM fh->afs_Name+1,str,fh->afs_Name[0]);
                if(fh->afs_Comment[0])
                  xadCopyMem(XADM fh->afs_Comment+1,fi->xfi_Comment,fh->afs_Comment[0]);
                xadConvertDates(XADM XAD_DATEDATESTAMP, &fh->afs_Date, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
                fi->xfi_Size = fi->xfi_CrunchSize = EndGetM32(fh->afs_Size);
                fi->xfi_Flags |= XADFIF_DIRECTORY;
                fi->xfi_Protection = EndGetM32(fh->afs_Protection);
                fi->xfi_OwnerUID = EndGetM32(fh->afs_OwnerInfo) >>16;
                fi->xfi_OwnerGID = EndGetM32(fh->afs_OwnerInfo) & 0xFFFF;
              }
              else
              {
                err = XADERR_NOMEMORY;
                xadFreeObjectA(XADM str, 0);
              }
            }
            else
              err = XADERR_NOMEMORY;
            break;
          case ST_FILE:
            if((fi = (struct xadFileInfo *) xadAllocObject(XADM  XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
            fh->afs_Name[0] + curnamesize+1+1, fh->afs_Comment[0] ? XAD_OBJCOMMENTSIZE :
            TAG_DONE, fh->afs_Comment[0]+1, TAG_DONE)))
            {
              fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) j; /* store block number */
              str = fi->xfi_FileName;
              if(curnamesize)
              {
                xadCopyMem(XADM curdirname, str, curnamesize);
                str += curnamesize;
                *(str++) = '/';
              }
              xadCopyMem(XADM fh->afs_Name+1,str,fh->afs_Name[0]);
              if(fh->afs_Comment[0])
                xadCopyMem(XADM fh->afs_Comment+1,fi->xfi_Comment,fh->afs_Comment[0]);
              xadConvertDates(XADM XAD_DATEDATESTAMP, &fh->afs_Date, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
              fi->xfi_Size = fi->xfi_CrunchSize = EndGetM32(fh->afs_Size);
              fi->xfi_Protection = EndGetM32(fh->afs_Protection);
              fi->xfi_OwnerUID = EndGetM32(fh->afs_OwnerInfo) >> 16;
              fi->xfi_OwnerGID = EndGetM32(fh->afs_OwnerInfo) & 0xFFFF;
              fi->xfi_Flags |= XADFIF_EXTRACTONBUILD;
              err = xadAddFileEntryA(XADM fi, parse->ai, 0);
            }
            else
              err = XADERR_NOMEMORY;
            break;
          default: ++c;
          }
        }
        else
          ++c;
      } while(!c && !err && (j = EndGetM32(fh->afs_HashList)));
      parse->Corrupt += c;
    }
  }
  return err;
}

XADGETINFO(FSAmiga)
{
  xadINT32 err = 0;
  struct xadImageInfo *ii;
  xadSTRPTR b1;
  xadUINT32 i;

  if(ai->xai_InSize < 2048)
    return XADERR_FILESYSTEM;

  ii = ai->xai_ImageInfo;

  if((b1 = (xadSTRPTR) xadAllocVec(XADM (ii->xii_SectorSize*2)+((ii->xii_NumSectors+7)>>3),XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    if(!ii->xii_FirstSector)
    {
      if(!(err = getdiskblock(xadMasterBase, ai, 0, b1, 0)))
      {
        if(b1[0] != 'D' || b1[1] != 'O' || b1[2] != 'S' || b1[3] > 5)
          err = XADERR_FILESYSTEM;
        else if(b1[3] & 1)
        ai->xai_PrivateClient = (xadPTR) 1; /* is FFS filesystem */
      }
    }
    if(!err)
    {
      i = ii->xii_TotalSectors/2;
      if(i < ii->xii_FirstSector || i > ii->xii_FirstSector+ii->xii_NumSectors-1)
        err = XADERR_FILESYSTEM;
      else
      {
        if(!(err = getdiskblock(xadMasterBase, ai, i, b1, 1)))
        {
          if(EndGetM32(((struct RootBlock *) b1)->afs_Type) != T_SHORT
          || EndGetM32(((struct RootBlock *) b1)->afs_SecondaryType) != ST_ROOT)
          {
            i = 880; /* standard floppy, useful for wrong-size-images */
            if(i < ii->xii_FirstSector || i > ii->xii_FirstSector+ii->xii_NumSectors-1)
              err = XADERR_FILESYSTEM;
            else if(!(err = getdiskblock(xadMasterBase, ai, i, b1, 1)))
            {
              if(EndGetM32(((struct RootBlock *) b1)->afs_Type) != T_SHORT
              || EndGetM32(((struct RootBlock *) b1)->afs_SecondaryType) != ST_ROOT)
                err = XADERR_FILESYSTEM;
            }
          }

          if(!err)
          {
            struct DiskParseData pd;
            struct xadFileInfo *fi, *ofi, *par;
            struct xadLink *l;

            pd.Corrupt      = 0;
            pd.ai           = ai;
            pd.fh1          = (struct FileHeaderBlock *) b1;
            pd.fh2          = (struct FileHeaderBlock *) (b1+ii->xii_SectorSize);
            pd.BList        = b1+(ii->xii_SectorSize<<1);
            pd.BList[i>>3] |= (1<<(i&7));
            pd.DirList      = pd.CurDir = 0;
            pd.LinkList     = 0;
            pd.MasterBase   = xadMasterBase;

            if(!(err = parsedir(&pd))) /* parse root block */
            {
              while(!err && pd.DirList)
              {
                pd.CurDir = fi = pd.DirList;
                pd.DirList = fi->xfi_Next;
                xadCopyMem(XADM fi->xfi_PrivateInfo, b1, ii->xii_SectorSize);
                xadFreeObjectA(XADM fi->xfi_PrivateInfo, 0); /* free stored block */
                fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) EndGetM32(pd.fh1->afs_HeaderKey); /* set blocknum */
                if(!(err = xadAddFileEntry(XADM fi, ai, XAD_INSERTDIRSFIRST, XADTRUE, TAG_DONE)))
                  err = parsedir(&pd);
              }
              while(!err && pd.LinkList)
              {
                l = pd.LinkList;
                pd.LinkList = l->xl_Next;
                xadCopyMem(XADM (xadPTR) &l->xl_Header, b1, ii->xii_SectorSize);
                par = l->xl_Parent;
                xadFreeObjectA(XADM l, 0);

                for(ofi = ai->xai_FileInfo; ofi; ofi=ofi->xfi_Next)
                {
                  if((xadUINT32)(uintptr_t) ofi->xfi_PrivateInfo == EndGetM32(pd.fh1->afs_LinkOriginal))
                    break;
                }
                if(ofi)
                {
                  xadUINT32 j, k;
                  xadSTRPTR str;

                  j = strlen((const char *)ofi->xfi_FileName)+1;
                  k = par ? strlen((const char *)par->xfi_FileName)+1 : 0;
                  if((fi = (struct xadFileInfo *) xadAllocObject(XADM  XADOBJ_FILEINFO,
                  XAD_OBJNAMESIZE, pd.fh1->afs_Name[0] + k+j+1, pd.fh1->afs_Comment[0] ?
                  XAD_OBJCOMMENTSIZE : TAG_DONE, pd.fh1->afs_Comment[0]+1, TAG_DONE)))
                  {
                    str = fi->xfi_FileName;
                    if(par)
                    {
                      xadCopyMem(XADM par->xfi_FileName, str, k);
                      str += k;
                      str[-1] = '/';
                    }
                    xadCopyMem(XADM pd.fh1->afs_Name+1,str,pd.fh1->afs_Name[0]);
                    fi->xfi_LinkName = str + pd.fh1->afs_Name[0] +1;
                    if(EndGetM32(pd.fh1->afs_SecondaryType) == ST_LINKDIR)
                      fi->xfi_Flags |= XADFIF_DIRECTORY;
                    fi->xfi_Flags |= XADFIF_LINK;
                    xadCopyMem(XADM ofi->xfi_FileName,fi->xfi_LinkName,j);
                    if(pd.fh1->afs_Comment[0])
                      xadCopyMem(XADM pd.fh1->afs_Comment+1,fi->xfi_Comment,pd.fh1->afs_Comment[0]);
                    xadConvertDates(XADM XAD_DATEDATESTAMP, &pd.fh1->afs_Date, XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
                    fi->xfi_Size = fi->xfi_CrunchSize = ofi->xfi_Size;
                    fi->xfi_Protection = EndGetM32(pd.fh1->afs_Protection);
                    fi->xfi_OwnerUID = EndGetM32(pd.fh1->afs_OwnerInfo) >> 16;
                    fi->xfi_OwnerGID = EndGetM32(pd.fh1->afs_OwnerInfo) & 0xFFFF;
                    err = xadAddFileEntry(XADM fi, ai, XAD_INSERTDIRSFIRST, XADTRUE, TAG_DONE);
                  }
                  else
                    err = XADERR_NOMEMORY;
                }
              }
            }

            while(pd.LinkList) /* free mem in case of error */
            {
              l = pd.LinkList;
              pd.LinkList = l->xl_Next;
              xadFreeObjectA(XADM l, 0);
            }
            while(pd.DirList) /* free mem in case of error */
            {
              fi = pd.DirList;
              pd.DirList = fi->xfi_Next;
              xadFreeObjectA(XADM fi->xfi_PrivateInfo, 0);
              xadFreeObjectA(XADM fi, 0);
            }

            if(pd.Corrupt)
              ai->xai_Flags |= XADAIF_FILECORRUPT;
          }
        }
      }
    }
    xadFreeObjectA(XADM b1,0);
  }
  else
    err = XADERR_NOMEMORY;

  if(err == XADERR_FILESYSTEM)
    ai->xai_PrivateClient = 0;

  return err;
}

XADUNARCHIVE(FSAmiga)
{
  xadINT32 err;
  xadSTRPTR buf;
  xadSize size, blksize;
  xadUINT32 blk;

  blksize = ai->xai_ImageInfo->xii_SectorSize;
  size = ai->xai_CurFile->xfi_Size;

  if((buf = (xadSTRPTR) xadAllocVec(XADM blksize*11, XADMEMF_PUBLIC)))
  {
    if(!(err = getdiskblock(xadMasterBase, ai, (xadUINT32)(uintptr_t) ai->xai_CurFile->xfi_PrivateInfo, buf, 1)))
    {
      struct FileExtensionBlock *fe;
      xadUINT8 *data;
      xadUINT32 usedblk = 0, blkcnt;

      fe = (struct FileExtensionBlock *) buf;
      data = (xadUINT8 *) buf+blksize; /* 10 blocks */
      blk = blkcnt = (blksize>>2)-56;

      if(!ai->xai_PrivateClient) /* OFS filesystem */
        blksize -= 6*4;
      do
      {
        if(usedblk == 10)
        {
          err = xadHookAccess(XADM XADAC_WRITE, 10*blksize, data, ai);
          size -= 10*blksize;
          usedblk = 0;
        }
        if(!blkcnt && !err)
        {
          if(!(err = getdiskblock(xadMasterBase, ai, EndGetM32(fe->afs_Extension), buf, 1)))
          {
            if(EndGetM32(fe->afs_Type) != T_LIST || EndGetM32(fe->afs_SecondaryType) != ST_FILE)
              err = XADERR_ILLEGALDATA;
          }
          blkcnt = blk;
        }
        if(!err)
        {
          xadSTRPTR a;
          a = (xadSTRPTR) data+(blksize*(usedblk++));
          --blkcnt;
          err = getdiskblock(xadMasterBase, ai, EndGetM32(fe->afs_BlockList[blkcnt]), a, 0);
          if(!ai->xai_PrivateClient && !err) /* OFS filesystem */
          {
            xadUINT32 i, j;
            for(i = j = 0; i < blksize+(4*6); i += 4)
              j += EndGetM32(a+i);
            if(j)
              err = XADERR_CHECKSUM;
            else /* copy buffer back */
              xadCopyMem(XADM a+6*4, a, blksize);
          }
        }
      } while(!err && size > blksize*usedblk);
      if(!err && size)
        err = xadHookAccess(XADM XADAC_WRITE, size, data, ai);
    }
    xadFreeObjectA(XADM buf, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}

XADFREE(FSAmiga)
{
  ai->xai_PrivateClient = 0; /* clear entry buffer */
}

XADFIRSTCLIENT(FSAmiga) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  FSAMIGA_VERSION,
  FSAMIGA_REVISION,
  0,
  XADCF_FILESYSTEM|XADCF_FREEFILEINFO,
  XADCID_FSAMIGA,
  "Amiga Standard FS",
  NULL,
  XADGETINFOP(FSAmiga),
  XADUNARCHIVEP(FSAmiga),
  XADFREEP(FSAmiga)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(FSAmiga)

#endif  /* XADMASTER_FS_AMIGA_C */
