#ifndef XADMASTER_FS_FAT_C
#define XADMASTER_FS_FAT_C

/*  $Id: FS_FAT.c,v 1.8 2005/06/23 14:54:40 stoecker Exp $
    FAT filesytem client

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
  #define XADMASTERVERSION      8
#endif

XADCLIENTVERSTR("FS_FAT 1.2 (22.2.2004)")

#define FSFAT_VERSION           1
#define FSFAT_REVISION          2

/* Boot block FAT 12/16
  xadUINT8      Jump[3];        // Boot strap short or near jump
  xadUINT8 SystemID[8];         // Name - can be used to special case partition manager volumes
  xadUINT16 SectorSize;         // bytes per logical sector -- normally 512
  xadUINT8 ClusterSize;         // sectors/cluster
  xadUINT16 Reserved;           // reserved sectors

  xadUINT8 FATs;                // number of FATs
  xadUINT16 RootDirEntries;     // root directory entries
  xadUINT16 Sectors;            // number of sectors
  xadUINT8 Media;               // media code
  xadUINT16 FAT_Length;         // sectors/FAT
  xadUINT16 Secs_Track;         // sectors per track
  xadUINT16 Heads;              // number of heads
  xadUINT32 Hidden;             // hidden sectors (unused)

  xadUINT32 TotalSectors;       // number of sectors (if Sectors == 0)
  xadUINT8 DriveNumber;         // BIOS drive number
  xadUINT8 RESERVED;
  xadUINT8 ExtBootSign;         // 0x29 if fields below exist (DOS 3.3+)
  xadUINT32 VolumeID[4];        // Volume ID number
  xadUINT8 VolumeLabel[11];     // Volume label
  xadUINT8 FSType[8];           // Typically FAT12 or FAT16
  xadUINT8 BootCode[448];       // Boot code (or message)
  xadUINT16 BootSign;           // 0xAA55
*/

/* Boot block FAT 32
  xadUINT8      Jump[3];        // Boot strap short or near jump
  xadUINT8 SystemID[8];         // Name - can be used to special case partition manager volumes
  xadUINT16 SectorSize;         // bytes per logical sector -- normally 512
  xadUINT8 ClusterSize;         // sectors/cluster
  xadUINT16 Reserved;           // reserved sectors

  xadUINT8 FATs;                // number of FATs
  xadUINT16 RootDirEntries;     // root directory entries
  xadUINT16 Sectors;            // number of sectors
  xadUINT8 Media;               // media code
  xadUINT16 FAT_Length;         // sectors/FAT
  xadUINT16 Secs_Track;         // sectors per track
  xadUINT16 Heads;              // number of heads
  xadUINT32 Hidden;             // hidden sectors (unused)

  xadUINT32 TotalSectors;       // number of sectors (if Sectors == 0)
  xadUINT32 SectorsFAT32;       // sectors/FAT
  xadUINT16 FlagsFAT;           // valid FAT flags
  xadUINT16 VersionFAT32;       // FAT32 version (0)
  xadUINT32 StartCluster;       // normally 2

  xadUINT16 InfoSector;         // number of FSINFO sector
  xadUINT16 BackupSector;       // boot backup sector, normally 6
  xadUINT8 RESERVED32[12];

  xadUINT8 DriveNumber;         // BIOS drive number
  xadUINT8 RESERVED;
  xadUINT8 ExtBootSign;         // 0x29 if fields below exist (DOS 3.3+)
  xadUINT32 VolumeID[4];        // Volume ID number
  xadUINT8 VolumeLabel[11];     // Volume label
  xadUINT8 FSType[8];           // Typically FAT12 or FAT16
  xadUINT8 BootCode[420];       // Boot code (or message)
  xadUINT16 BootSign;           // 0xAA55
*/

/* file name entry
  xadUINT8 Name[8];             // the file name
  xadUINT8 Ext[3];              // the name extension
  xadUINT8 Attributes;          // file attributes
  xadUINT8 RESERVED;
  xadUINT8 Second10;            // 10th of seconds
  xadUINT32 Date;               // MSDOS format (including time)
  xadUINT16 LastAccessDate;     // date bits only
  xadUINT16 UpperCluster;
  xadUINT16 LastWriteDate;      // last write access date
  xadUINT16 LowerCluster;
  xadUINT32 FileSize;
*/

/* long file name entry
  xadUINT8 SeqNumber;           // running sequence number
  xadUINT16 Name1[2];           // the file name, 5 chars
  xadUINT8 Attributes;          // file attributes, set to 0x0F
  xadUINT8 RESERVED;            // 0
  xadUINT8 ChecksumShort;       // Checksum of short filename
  xadUINT16 Name2[6];           // the file name, 6 chars
  xadUINT16 Zero;               // 0
  xadUINT16 Name3[2];           // the file name, 2 chars
*/

#define FATTYPE_FAT12   12
#define FATTYPE_FAT16   16
#define FATTYPE_FAT32   32

#define FATPI(ai)       ((struct FATPrivate *)ai->xai_PrivateClient)

struct FATPrivate {
  xadUINT32  Type;
  xadUINT32  SecSize;     /* normally 512 */
  xadUINT32  ClusterSize; /* Sectors per Cluster * sectorsize */
  xadUINT32  StartBlock;  /* the first data block */
  xadUINT32  FATSize;     /* the size of the following FAT */
  xadUINT32  MaxNumClusters; /* created of FAT space */
  xadUINT8  FAT[1];
};

struct FATDiskParseData
{
  xadUINT32               Corrupt;
  xadUINT32               MaxEntries;
  struct xadArchiveInfo * ai;
  struct xadMasterBase *  MasterBase;
  struct xadFileInfo *    FileList;
  struct xadFileInfo *    DirList;
  struct xadFileInfo *    CurDir;
  xadSTRPTR               Memory;
};

static xadUINT8 checksumLFN(xadSTRPTR name, xadINT32 size)
{
  xadUINT8 sum = 0;

  while(size--)
  {
    if(sum & 1)
      sum = (sum/2)+0x80;
    else
      sum = (sum/2);
    sum += *(name++);
  }
  return sum;
}

static xadINT32 FATparsedir(struct FATDiskParseData *pd, xadINT32 pos, xadINT32 block)
{
  struct xadMasterBase *xadMasterBase;
  struct xadArchiveInfo *ai;
  struct xadFileInfo *fi;
  xadINT32 err = 0, i, stop = 0, j, LFN = 0;
  xadUINT32 curnamesize = 0, namesize, numentr, cluster;
  xadSTRPTR mem, curdirname = 0, name, str;

  xadMasterBase = pd->MasterBase;
  mem = pd->Memory;
  ai = pd->ai;
  name = mem+512;

  if(pd->CurDir)
  {
    curdirname = pd->CurDir->xfi_FileName;
    curnamesize = strlen((const char *)curdirname);
  }

  while(!stop && !err)
  {
    if(pd->MaxEntries)
      numentr = pd->MaxEntries*32; /* FAT12 and FAT16 master directory is limited */
    else
      numentr = FATPI(ai)->ClusterSize;

    if(pos + numentr > ai->xai_InSize)
      ++pd->Corrupt;
    else
    {
      numentr /= FATPI(ai)->SecSize;

      if(ai->xai_InPos != (xadUINT32) pos && (err = xadHookAccess(XADM XADAC_INPUTSEEK, pos-ai->xai_InPos, 0, ai)))
       break;

      while(!err && !stop && numentr--)
      {
        if(ai->xai_InPos + 512 > ai->xai_InSize)
        {
          ++pd->Corrupt; stop = 1;
        }
        else if(!(err = xadHookAccess(XADM XADAC_READ, 512, mem, ai)))
        {
          for(i = 0; i < 512 && !err && !stop; i += 32)
          {
            cluster = EndGetI16(mem+i+26) + (EndGetI16(mem+i+20)<<16);

            if(!mem[i])
              stop = 1; /* the end of directory */
            else if(mem[i+11] == 0xF && !mem[i+12] && !mem[i+26] && !mem[i+27]) /* LFN-Entry */
            {
              if(mem[i]&0x40 || mem[i]+1 != (LFN >> 8) || (LFN&0xFF) != mem[i+13])
                LFN = 0;
              if(mem[i]&0x40 || mem[i]+1 == (LFN >> 8)) /* UTF conversion */
              {
                if(mem[i]&0x40)
                  name[13] = 0;
                else
                  xadCopyMem(XADM name, name+13, 512-13);
                str = name;
                LFN = ((mem[i]&0x3F)<<8)+mem[i+13];
                for(j =  1; j < 11; j += 2)
                  *(str++) = mem[i+j+1] ? '_' : mem[i+j];
                for(j += 3; j < 26; j += 2)
                  *(str++) = mem[i+j+1] ? '_' : mem[i+j];
                for(j += 2; j < 32; j += 2)
                  *(str++) = mem[i+j+1] ? '_' : mem[i+j];
              }
            }
            else if((xadUINT8) mem[i] == 0xE5 || (mem[i] == '.' && (mem[i+1] == 0x20 ||
            (mem[i+1] == '.' && mem[i+2] == 0x20))) ||
            (mem[i+11] & ((1<<3)|(1<<6)|(1<<7)) /* volume label, unused */) ||
            cluster > FATPI(ai)->MaxNumClusters)
              LFN = 0; /* unusable entries */
            else
            {
              if((LFN>>8) != 1 || checksumLFN(mem+i, 11) != (LFN&0xFF))
                LFN = 0; /* invalid entry */
              if(!LFN)
              {
                str = name;
                for(namesize = 0; namesize < 8 && mem[i+namesize] != 0x20; ++namesize)
                  *(str++) = mem[i+namesize];
                if(mem[i+8] != 0x20)
                {
                  *(str++) = '.';
                  for(namesize = 0; namesize < 3 && mem[i+8+namesize] != 0x20; ++namesize)
                    *(str++) = mem[i+8+namesize];
                }
                namesize = str-name;
              }
              else
                namesize = strlen((const char *)name);

              if((fi = (struct xadFileInfo *) xadAllocObject(XADM XADOBJ_FILEINFO, XAD_OBJNAMESIZE,
              namesize + curnamesize+1+1, TAG_DONE)))
              {
                if(mem[i+11] & (1<<4))
                {
                  fi->xfi_Next = pd->DirList;
                  pd->DirList = fi;
                  fi->xfi_Flags |= XADFIF_DIRECTORY;
                }
                else
                {
                  fi->xfi_Next = pd->FileList;
                  pd->FileList = fi;
                }
                fi->xfi_PrivateInfo = (xadPTR)(uintptr_t) cluster;
                str = fi->xfi_FileName;
                if(curnamesize)
                {
                  xadCopyMem(XADM curdirname, str, curnamesize);
                  str += curnamesize;
                  *(str++) = '/';
                }
                xadCopyMem(XADM name, str, namesize);
                if(xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(mem+i+14), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE))
                  xadConvertDates(XADM XAD_DATEMSDOS, EndGetI32(mem+i+22), XAD_GETDATEXADDATE, &fi->xfi_Date, TAG_DONE);
                fi->xfi_Date.xd_Second += mem[i+13]/10;
                fi->xfi_Date.xd_Micros = (mem[i+13]%10)*1000*100;
                fi->xfi_Size = fi->xfi_CrunchSize = EndGetI32(mem+i+28);
                //xadConvertProtection(XADM XAD_PROTMSDOS, mem[i+11], XAD_GETPROTAMIGA, &fi->xfi_Protection, TAG_DONE);
              }
              LFN = 0;
            } /* else */
          } /* for */
        } /* else */
      } /* while */
      if(block)
      {
        switch(FATPI(ai)->Type)
        {
        case FATTYPE_FAT12:
          i = EndGetI16(FATPI(ai)->FAT + block + (block>>1));
          if(block & 1)
            block = i>>4;
          else
            block = i&0xFFF;
          break;
        case FATTYPE_FAT16:
          block = EndGetI16(FATPI(ai)->FAT + block*2);
          break;
        case FATTYPE_FAT32:
          block = EndGetI32(FATPI(ai)->FAT + block*4);
          break;
        }
        if((xadUINT32)block > FATPI(ai)->MaxNumClusters)
          stop = 1;
        else
          pos = (block-2)*FATPI(ai)->ClusterSize+FATPI(ai)->StartBlock;
      }
      else
        stop = 1;
    } /* while */
  } /* else */
  return err;
}

XADGETINFO(FSFAT)
{
  xadINT32 err = XADERR_FILESYSTEM, type = 0;
  xadSTRPTR mem;

  if((mem = (xadSTRPTR) xadAllocVec(XADM 512*2, XADMEMF_ANY))) /* second part for long file name buffer */
  {
    if(!xadHookAccess(XADM XADAC_READ, 512, mem, ai))
    {
      if((xadUINT8)mem[0] == 0xEB && (xadUINT8)mem[2] == 0x90 && (xadUINT8)mem[510] == 0x55 && (xadUINT8)mem[511] == 0xAA)
      {
        if(mem[38] == 0x29 && !strncmp((const char *)mem+54, "FAT12   ", 8))
        {
          type = FATTYPE_FAT12;
        }
        else if(mem[38] == 0x29 && !strncmp((const char *)mem+54, "FAT16   ", 8))
        {
          type = FATTYPE_FAT16;
        }
        else if(mem[66] == 0x29 && !strncmp((const char *)mem+82, "FAT32   ", 8))
        {
          type = FATTYPE_FAT32;
        }
        else if(mem[38] != 0x29 && strncmp((const char *)mem+3, "NTFS    ", 8)) /* do not detect NTFS as FAT12 */
        {
          type = FATTYPE_FAT12;
        }
      }
      /* Atari format */
      else if((mem[0] == 0x60 || (xadUINT8)mem[0] == 0xEB) && !mem[11] && mem[12] == 2 && (mem[13] == 2 || mem[13] == 1)
      && mem[14] == 1 && !mem[15] &&  mem[16] == 2)
      {
        type = FATTYPE_FAT12;
      }

      if(type)
      {
        xadUINT32 s, i;

        if(type == FATTYPE_FAT12 || type == FATTYPE_FAT16)
        {
          if(!(s = EndGetI16(mem+22) * EndGetI16(mem+11)))
            err = XADERR_FILESYSTEM;
          else if((ai->xai_PrivateClient = xadAllocVec(XADM s-1+sizeof(struct FATPrivate), XADMEMF_CLEAR)))
          {
            FATPI(ai)->Type = type;
            FATPI(ai)->SecSize = EndGetI16(mem+11);
            FATPI(ai)->ClusterSize = mem[13] * FATPI(ai)->SecSize;
            FATPI(ai)->FATSize = s;
            s = EndGetI16(mem+14)*FATPI(ai)->SecSize+s*mem[16];
            FATPI(ai)->StartBlock = s + EndGetI16(mem+17)*32; /* size of root directory */
            if(type == FATTYPE_FAT12)
              FATPI(ai)->MaxNumClusters = (FATPI(ai)->FATSize << 1) / 3; /* 1.5 byte */
            else
              FATPI(ai)->MaxNumClusters = FATPI(ai)->FATSize >> 1; /* 2 byte */

            if(ai->xai_InPos == EndGetI16(mem+14)*FATPI(ai)->SecSize || !(err =
            xadHookAccess(XADM XADAC_INPUTSEEK, EndGetI16(mem+14)*FATPI(ai)->SecSize-ai->xai_InPos, 0, ai)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, FATPI(ai)->FATSize, FATPI(ai)->FAT, ai)))
              {
                struct FATDiskParseData pd;
                struct xadFileInfo *fi;

                pd.Corrupt = 0;
                pd.ai = ai;
                pd.FileList = pd.DirList = pd.CurDir = 0;
                pd.MasterBase = xadMasterBase;
                pd.Memory = mem;
                pd.MaxEntries = EndGetI16(mem+17);

                if(!(err = FATparsedir(&pd, (xadINT32) s, 0))) /* parse root directory */
                {
                  pd.MaxEntries = 0;
                  while(!err && pd.DirList) /* we want no recursion! */
                  {
                    fi = pd.DirList;
                    pd.DirList = fi->xfi_Next;
                    fi->xfi_Next = pd.FileList; /* add to list */
                    pd.FileList = pd.CurDir = fi;
                    err = FATparsedir(&pd, (xadINT32)(uintptr_t) ((((xadINT32)(uintptr_t) fi->xfi_PrivateInfo)-2)*FATPI(ai)->ClusterSize+
                    FATPI(ai)->StartBlock), (xadINT32)(uintptr_t) fi->xfi_PrivateInfo);
                  }
                }

                while(pd.DirList) /* free mem in case of error */
                {
                  fi = pd.DirList;
                  pd.DirList = fi->xfi_Next;
                  xadFreeObjectA(XADM fi, 0);
                }
                ai->xai_FileInfo = pd.FileList;

                if(pd.Corrupt)
                  ai->xai_Flags |= XADAIF_FILECORRUPT;
              }
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
        else /* FAT32 */
        {
          s = EndGetI32(mem+36) * EndGetI16(mem+11);
          if((ai->xai_PrivateClient = xadAllocVec(XADM s-1+sizeof(struct FATPrivate), XADMEMF_CLEAR)))
          {
            FATPI(ai)->Type = type;
            FATPI(ai)->SecSize = EndGetI16(mem+11);
            FATPI(ai)->ClusterSize = mem[13] * FATPI(ai)->SecSize;
            FATPI(ai)->FATSize = s;
            FATPI(ai)->StartBlock = EndGetI16(mem+14)*FATPI(ai)->SecSize+s*mem[16];
            FATPI(ai)->MaxNumClusters = FATPI(ai)->FATSize >> 2; /* 4 byte */

            s = EndGetI16(mem+14)*FATPI(ai)->SecSize;
            if((i = EndGetI16(mem+40)&(1<<7)))
              s += (i&15)*FATPI(ai)->FATSize; /* do not use first, but valid FAT */
            if(ai->xai_InPos == s || !(err = xadHookAccess(XADM XADAC_INPUTSEEK, s-ai->xai_InPos, 0, ai)))
            {
              if(!(err = xadHookAccess(XADM XADAC_READ, FATPI(ai)->FATSize, FATPI(ai)->FAT, ai)))
              {
                struct FATDiskParseData pd;
                struct xadFileInfo *fi;

                pd.Corrupt = 0;
                pd.ai = ai;
                pd.FileList = pd.DirList = pd.CurDir = 0;
                pd.MasterBase = xadMasterBase;
                pd.Memory = mem;
                pd.MaxEntries = 0;

                if(!(err = FATparsedir(&pd, (xadINT32) FATPI(ai)->StartBlock, EndGetI32(mem+44)))) /* parse root directory */
                {
                  while(!err && pd.DirList) /* we want no recursion! */
                  {
                    fi = pd.DirList;
                    pd.DirList = fi->xfi_Next;
                    fi->xfi_Next = pd.FileList; /* add to list */
                    pd.FileList = pd.CurDir = fi;
                    err = FATparsedir(&pd, (xadINT32) ((((xadINT32)(uintptr_t) fi->xfi_PrivateInfo)-2)*FATPI(ai)->ClusterSize+
                    FATPI(ai)->StartBlock), (xadINT32)(uintptr_t) fi->xfi_PrivateInfo);
                  }
                }

                while(pd.DirList) /* free mem in case of error */
                {
                  fi = pd.DirList;
                  pd.DirList = fi->xfi_Next;
                  xadFreeObjectA(XADM fi, 0);
                }
                ai->xai_FileInfo = pd.FileList;

                if(pd.Corrupt)
                  ai->xai_Flags |= XADAIF_FILECORRUPT;
              }
            }
          }
          else
            err = XADERR_NOMEMORY;
        }
      }
    }
    xadFreeObjectA(XADM mem, 0);
  }
  else
    err = XADERR_NOMEMORY;

  {
    struct xadFileInfo *fi;
    xadUINT32 n = 1;

    for(fi = ai->xai_FileInfo; fi; fi= fi->xfi_Next)
      fi->xfi_EntryNumber = n++;
  }

  return err;
}

XADUNARCHIVE(FSFAT)
{
  xadINT32 err = 0;
  xadUINT32 i, block, s;

  i = ai->xai_CurFile->xfi_Size;
  block = (xadUINT32)(uintptr_t) ai->xai_CurFile->xfi_PrivateInfo;
  while(i && !err)
  {
    s = FATPI(ai)->StartBlock+(block-2)*FATPI(ai)->ClusterSize;
    if(s + FATPI(ai)->ClusterSize > ai->xai_InSize)
      err = XADERR_ILLEGALDATA;
    else if(s == ai->xai_InPos || !(err = xadHookAccess(XADM XADAC_INPUTSEEK, s-ai->xai_InPos, 0, ai)))
    {
      s = FATPI(ai)->ClusterSize;
      if(s > i)
        s = i;
      if(!(err = xadHookAccess(XADM XADAC_COPY, s, 0, ai)))
      {
        i -= s;
        switch(FATPI(ai)->Type)
        {
        case FATTYPE_FAT12:
          s = EndGetI16(FATPI(ai)->FAT + block + (block>>1));
          if(block & 1)
            block = s>>4;
          else
            block = s&0xFFF;
          break;
        case FATTYPE_FAT16:
          block = EndGetI16(FATPI(ai)->FAT + block*2);
          break;
        case FATTYPE_FAT32:
          block = EndGetI32(FATPI(ai)->FAT + block*4);
          break;
        }
      }
    }
  }
  /* dos not check end condition for last block! */

  return err;
}

XADFREE(FSFAT)
{
  if(ai->xai_PrivateClient)
    xadFreeObjectA(XADM ai->xai_PrivateClient, 0);
  ai->xai_PrivateClient = 0; /* clear entry buffer */
}

XADFIRSTCLIENT(FSFAT) {
  XADNEXTCLIENT,
  XADCLIENT_VERSION,
  XADMASTERVERSION,
  FSFAT_VERSION,
  FSFAT_REVISION,
  0,
  XADCF_FILESYSTEM|XADCF_FREEFILEINFO,
  XADCID_FSFAT,
  "Microsoft FAT FS",
  NULL,
  XADGETINFOP(FSFAT),
  XADUNARCHIVEP(FSFAT),
  XADFREEP(FSFAT)
};

#undef XADNEXTCLIENT
#define XADNEXTCLIENT XADNEXTCLIENTNAME(FSFAT)

#endif  /* XADMASTER_FS_FAT_C */
