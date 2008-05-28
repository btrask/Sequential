#ifndef XADMASTER_HOOK_DISK_C
#define XADMASTER_HOOK_DISK_C

/*  $Id: hook_disk.c,v 1.8 2005/06/23 14:54:40 stoecker Exp $
    device IO hooks

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
#undef IDOS

#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/xadmaster.h>
#include <proto/utility.h>
#include <dos/filehandler.h>
#include <exec/io.h>
#include <devices/trackdisk.h>
#include "functions.h"

#define IDOS xadMasterBase->xmb_IDOS

struct DiskHookPrivate {
  xadSTRPTR              DosName;
  xadUINT8 *             Buffer;
  xadSize                BufferSize;   /* only inhook */
  xadSize                BufferStart;  /* only inhook */
  xadSize                BufferEnd;    /* only inhook */
  xadSize                FullSize;     /* only inhook */
  xadSize                BlockSize;
  xadSize                Offset;
  struct MsgPort *       MsgPort;
  struct IOStdReq *      Request;
};

static void disk_busy(const struct xadArchiveInfoP *ai, xadUINT32 onflag,
xadSTRPTR dosname)
{
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) ai->xaip_MasterBase;

  if(dosname)
  {
    struct DosLibrary *DOSBase;
    struct MsgPort *m;

    DOSBase = xadMasterBase->xmb_DOSBase;

#ifdef DEBUG
    DebugRunTime("disk_busy: Inhibit %s - %s", dosname, onflag ?
    "true" : "false");
#endif

    if((m = DeviceProc(dosname)))
    {
      DoPkt1(m, ACTION_INHIBIT, onflag ? DOSTRUE : DOSFALSE);
    }
  }
}

static xadERROR writedisk(struct IOStdReq *io, xadUINT8 *data, xadSize size,
xadSize ofs, const struct xadArchiveInfoP *ai, xadPTR sec)
{
  struct ExecBase *SysBase;
  struct xadMasterBaseP *xadMasterBase;
  xadERROR e = 0;

  xadMasterBase = ai->xaip_MasterBase;
  SysBase = xadMasterBase->xmb_SysBase;

  io->io_Length = size;
  io->io_Data = data;
  io->io_Offset = ofs;
  if((ai->xaip_ArchiveInfo.xai_Flags & XADAIF_USESECTORLABELS) && sec)
  {
    if(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_FORMAT)
    /* or Sector labels are ignored */
    {
      io->io_Command = ETD_FORMAT;
      if(DoIO((struct IORequest *)io))
        return XADERR_OUTPUT;
    }
    io->io_Command = ETD_WRITE;
    ((struct IOExtTD *) io)->iotd_SecLabel = (xadUINT32) sec;
    ((struct IOExtTD *) io)->iotd_Count = 0xFFFFFFFF;
  }
  else
  {
    io->io_Command = (ai->xaip_ArchiveInfo.xai_Flags & XADAIF_FORMAT)
    ? TD_FORMAT : CMD_WRITE;
  }
  if(DoIO((struct IORequest *)io))
    return XADERR_OUTPUT;
  io->io_Command = CMD_UPDATE;
  if(DoIO((struct IORequest *)io))
    return XADERR_OUTPUT;
  if(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_VERIFY)
  {
    xadUINT8 *buf;
    xadSize i;

    if(!(buf = (xadUINT8 *) xadAllocVec(XADM size, XADMEMF_PUBLIC)))
      return XADERR_NOMEMORY;

    io->io_Command = CMD_READ;
    io->io_Length = size;
    io->io_Data = buf;
    io->io_Offset = ofs;
    if(!DoIO((struct IORequest *)io))
    {
      for(i = 0; !e && i < size; ++i)
        if(data[i] != buf[i])
          e = XADERR_VERIFY;
    }
    else
      e = XADERR_OUTPUT;
    xadFreeObjectA(XADM buf, 0);
  }
  return e;
}

static xadINT32 CheckGeometry(const struct xadDiskInfo *di,
const struct DriveGeometry *dg)
{
  if(!di)
    return 0;

  if(!(di->xdi_Flags & XADDIF_GUESSSECTORSIZE) &&
  di->xdi_SectorSize != dg->dg_SectorSize)
    return 1;
  if(!(di->xdi_Flags & XADDIF_GUESSTOTALSECTORS) &&
  di->xdi_TotalSectors != dg->dg_TotalSectors)
    return 2;
  /* in case one of the flags was set, the product must be equal in any case */
  if(di->xdi_TotalSectors * di->xdi_SectorSize !=
  dg->dg_TotalSectors * dg->dg_SectorSize)
    return 3;
  if(!(di->xdi_Flags & (XADDIF_GUESSCYLINDERS|XADDIF_NOCYLINDERS)) &&
  di->xdi_Cylinders != dg->dg_Cylinders)
    return 4;
  if(!(di->xdi_Flags & (XADDIF_GUESSCYLSECTORS|XADDIF_NOCYLSECTORS)) &&
  di->xdi_CylSectors != dg->dg_CylSectors)
    return 5;
  if(!(di->xdi_Flags & (XADDIF_GUESSHEADS|XADDIF_NOHEADS)) &&
  di->xdi_Heads != dg->dg_Heads)
    return 6;
  if(!(di->xdi_Flags & (XADDIF_GUESSTRACKSECTORS|XADDIF_NOTRACKSECTORS)) &&
  di->xdi_TrackSectors != dg->dg_TrackSectors)
    return 7;

  return 0; /* no error */
}

/*************************** write-to-disk hook *************************/
FUNCHOOK(OutHookDisk) /* struct Hook *hook, struct xadArchiveInfoP *ai,
struct xadHookParam *param */
{
  struct ExecBase *SysBase;
  struct UtilityBase *UtilityBase;
  struct DiskHookPrivate *dhp;
  struct xadMasterBaseP *xadMasterBase;

  xadMasterBase = ai->xaip_MasterBase;
  SysBase = xadMasterBase->xmb_SysBase;
  UtilityBase = xadMasterBase->xmb_UtilityBase;
  dhp = (struct DiskHookPrivate *) param->xhp_PrivatePtr;

  switch(param->xhp_Command)
  {
  /* This function always writes complete blocks. If a block is partially
  accessed, it first reads the block from device and after that writes it
  back again. This may slow down the work a lot (especially, when 2 partial
  blocks exists), so it is recommended to use full disk blocks always. */
  case XADHC_WRITE:
    {
      struct IOStdReq *io;
      xadUINT32 i, j, k, s, bs;
      xadUINT8 *b, *p;
      xadERROR e;

      i = param->xhp_DataPos + dhp->Offset;
      s = param->xhp_BufferSize;
      bs = dhp->BlockSize;
      b = (xadUINT8 *) dhp->Buffer;
      p = (xadUINT8 *) param->xhp_BufferPtr;
      io = dhp->Request;

      if(s + param->xhp_DataPos > ai->xaip_OutSize)
        s = ai->xaip_OutSize - param->xhp_DataPos;

      if((j = (i % bs)))
      {
        io->io_Command = CMD_READ;
        io->io_Length = bs;
        io->io_Data = b;
        io->io_Offset = i - j;
        if(DoIO((struct IORequest *)io))
          return XADERR_OUTPUT;
        if((k = bs-j) > s)
          k = s;
        xadCopyMem(XADM p, ((xadUINT8 *)b)+j, k);
        if((e = writedisk(io, b, bs, i-j, ai, 0)))
          return e;
        s -= k;
        i += k;
        p += k;
      }
      if((k = s - (s % bs)))
      {
        if((e = writedisk(io, p, k, i, ai, (xadPTR)
        GetTagData(XAD_SECTORLABELS, 0, param->xhp_TagList))))
          return e;
        s -= k;
        i += k;
        p += k;
      }
      if(s)
      {
        io->io_Command = CMD_READ;
        io->io_Length = bs;
        io->io_Data = b;
        io->io_Offset = i;
        if(DoIO((struct IORequest *)io))
          return XADERR_OUTPUT;
        xadCopyMem(XADM p, b, s);
        if((e = writedisk(io, b, bs, i, ai, 0)))
          return e;
      }

      param->xhp_DataPos += param->xhp_BufferSize;
      if(param->xhp_DataPos > ai->xaip_OutSize)
      {
        param->xhp_DataPos = ai->xaip_OutSize;
        return XADERR_OUTPUT;
      }
    }
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) ||
    (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_OutSize))
      return XADERR_OUTPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_ABORT:
    break;
  case XADHC_FREE: /* free allocated stuff */
    if(dhp)
    {
      if(dhp->Buffer)
        xadFreeObjectA(XADM dhp->Buffer, 0);
      /* close device */
      if(dhp->Request)
      {
        if(dhp->Request->io_Device)
        {
          disk_busy(ai, XADFALSE, dhp->DosName);
          CloseDevice((struct IORequest *) dhp->Request);
        }
        DeleteIORequest((struct IORequest *) dhp->Request);
      }
      if(dhp->MsgPort)
      DeleteMsgPort(dhp->MsgPort);
      xadFreeObjectA(XADM dhp, 0);
      param->xhp_PrivatePtr = 0;
    }
    break;
  case XADHC_INIT:
    {
      xadSize namesize;
#ifdef DEBUG
  DebugHook("OutHookDisk: XADHC_INIT");
#endif

      namesize = ai->xaip_OutDevice->xdi_DOSName
      ? strlen(ai->xaip_OutDevice->xdi_DOSName)+2 : 0;
      if(!(dhp = param->xhp_PrivatePtr = (struct HookDiskPrivate *)
      xadAllocVec(XADM sizeof(struct DiskHookPrivate)+namesize,
      XADMEMF_CLEAR|XADMEMF_PUBLIC)) ||
      !(dhp->MsgPort = CreateMsgPort()) ||
      !(dhp->Request = (struct IOStdReq *)
      CreateIORequest(dhp->MsgPort, sizeof(struct IOExtTD))))
        return XADERR_NOMEMORY;
      else
      {
        xadINT32 i;
        struct IOStdReq *io;
        struct DriveGeometry dg;
        io = dhp->Request;

        dg.dg_SectorSize = 0;
        dg.dg_TotalSectors = 0;
        dg.dg_BufMemType = 0;
        if(ai->xaip_OutDevice->xdi_DOSName)
        {
          struct DosLibrary *DOSBase;
          struct DosList *dsl;
          xadERROR err = XADERR_RESOURCE;

          dhp->DosName = (xadSTRPTR)(dhp+1);
          for(i = 0; i < namesize-2; ++i)
            dhp->DosName[i] = ai->xaip_OutDevice->xdi_DOSName[i];
          dhp->DosName[i] = ':';
#ifdef DEBUG
  DebugRunTime("OutHookDisk: dos device name %s", dhp->DosName);
#endif

          DOSBase = ai->xaip_MasterBase->xmb_DOSBase;
          if((dsl = LockDosList(LDF_DEVICES|LDF_READ)))
          {
            if((dsl = FindDosEntry(dsl, ai->xaip_OutDevice->xdi_DOSName,
            LDF_DEVICES)))
            {
              struct FileSysStartupMsg *fssm;

              fssm = (struct FileSysStartupMsg *) BADDR(dsl->dol_misc.
                     dol_handler.dol_Startup);
              if((xadINT32) fssm > 200)
              {
                const struct DosEnvec *denv;
                denv = ((struct DosEnvec *) BADDR(fssm->fssm_Environ));

                /* test if the entry is a correct fssm -> check for valid data */
                if(denv && denv->de_TableSize < 64 && !(denv->de_SizeBlock &
                0x127) && (denv->de_LowCyl <= denv->de_HighCyl))
                {
                  if(!OpenDevice(((xadSTRPTR)(fssm->fssm_Device<<2))+1,
                  fssm->fssm_Unit, (struct IORequest *)io, 0))
                  {
#ifdef DEBUG
  DebugRunTime("OutHookDisk: opened device");
#endif
                    dg.dg_SectorSize    = denv->de_SizeBlock<<2;
                    dg.dg_Heads         = denv->de_Surfaces;
                    dg.dg_TrackSectors  = denv->de_BlocksPerTrack;
                    dg.dg_Cylinders     = denv->de_HighCyl-denv->de_LowCyl+1;
                    dg.dg_CylSectors    = dg.dg_Heads*dg.dg_TrackSectors;
                    dg.dg_TotalSectors  = dg.dg_Cylinders * dg.dg_CylSectors;
                    dg.dg_BufMemType    = denv->de_BufMemType;
                    dhp->Offset = denv->de_LowCyl*dg.dg_CylSectors*
                    dg.dg_SectorSize;
                    err = 0;
                  }
                }
              }
            }
            UnLockDosList(LDF_DEVICES|LDF_READ);
          }
          if(err)
            return err;
        }
        else
        {
#ifdef DEBUG
  DebugRunTime("OutHookDisk: device name %s, unit %ld",
  ai->xaip_OutDevice->xdi_DeviceName, ai->xaip_OutDevice->xdi_Unit);
#endif
          if(OpenDevice(ai->xaip_OutDevice->xdi_DeviceName,
          ai->xaip_OutDevice->xdi_Unit, (struct IORequest *) io, 0))
            return XADERR_RESOURCE;

          dhp->Offset = 0;

          io->io_Command = TD_GETGEOMETRY;
          io->io_Length = sizeof(struct DriveGeometry);
          io->io_Data = &dg;
          if(DoIO((struct IORequest *)io))
            return XADERR_OUTPUT;
        }
        ai->xaip_OutSize = dg.dg_SectorSize * dg.dg_TotalSectors;
        if(CheckGeometry(ai->xaip_ArchiveInfo.xai_CurDisk, &dg))
        {
          if(!(ai->xaip_ArchiveInfo.xai_Flags & XADAIF_IGNOREGEOMETRY))
          {
            if(!((i = callprogress(ai, XADPIF_IGNOREGEOMETRY, XADPMODE_ASK,
            ai->xaip_MasterBase)) & XADPIF_OK))
              return XADERR_BREAK;
            else if(i & XADPIF_SKIP)
              return XADERR_SKIP;
            else if(!(i & XADPIF_IGNOREGEOMETRY))
              return XADERR_GEOMETRY;
          }
        }

        dhp->BlockSize = dg.dg_SectorSize;
        if(ai->xaip_ArchiveInfo.xai_CurDisk) /* add start offset */
        {
          if((i = ai->xaip_ArchiveInfo.xai_LowCyl *
          ai->xaip_ArchiveInfo.xai_CurDisk->xdi_CylSectors *
          ai->xaip_ArchiveInfo.xai_CurDisk->xdi_SectorSize) >=
          ai->xaip_OutSize)
            return XADERR_OUTPUT;
          dhp->Offset += i;
          ai->xaip_OutSize -= i;
        }

#ifdef DEBUG
  DebugRunTime("OutHookDisk: outsize %ld, blocksize %ld, offset %ld",
  ai->xaip_OutSize, dhp->BlockSize, dhp->Offset);
#endif
        if(!(dhp->Buffer =  xadAllocVec(XADM dhp->BlockSize,
        dg.dg_BufMemType)))
          return XADERR_NOMEMORY;
        disk_busy(ai, TRUE, dhp->DosName);
      }
    }
    break;
  default: return XADERR_NOTSUPPORTED;
  }
  return 0;
}
ENDFUNC

/************************** read-from-disk hook **************************/
FUNCHOOK(InHookDisk) /* struct Hook *hook, struct xadArchiveInfoP *ai,
struct xadHookParam *param */
{
  struct xadMasterBaseP *xadMasterBase;
  struct DosLibrary *DOSBase;
  struct DiskHookPrivate *dhp;
  struct ExecBase *SysBase;
  xadUINT32 i;

  xadMasterBase = ai->xaip_MasterBase;
  SysBase = xadMasterBase->xmb_SysBase;
  dhp = (struct DiskHookPrivate *) param->xhp_PrivatePtr;
  DOSBase = xadMasterBase->xmb_DOSBase;

  switch(param->xhp_Command)
  {
  case XADHC_READ:
    i = dhp->FullSize;
    if(i > ai->xaip_InSize)
      i = ai->xaip_InSize;
    if(param->xhp_DataPos + param->xhp_BufferSize > i)
      return XADERR_INPUT;
    else
    {
      struct IOStdReq *io;
      xadUINT8 *buf;
      xadINT32 size, pos, p, siz;

      io = dhp->Request;
      io->io_Command = CMD_READ;
      buf = param->xhp_BufferPtr;
      pos = param->xhp_DataPos;
      size = param->xhp_BufferSize;

#ifdef DEBUG
  DebugOther("InHookDisk: IS [%10ld - %10ld], NEED [%10ld - %10ld]",
  dhp->BufferStart, dhp->BufferEnd, pos, pos+size);
#endif

      if(pos >= dhp->BufferStart && pos < dhp->BufferEnd)
      {
        if((siz = dhp->BufferEnd-pos) > size)
          siz = size;
#ifdef DEBUG
  DebugOther("InHookDisk: Copy %ld bytes", siz);
#endif
        xadCopyMem(XADM dhp->Buffer + (pos - dhp->BufferStart), buf, siz);
        buf += siz;
        pos += siz;
        size -= siz;
      }
      while(size)
      {
        p = pos;
        if(size < dhp->BufferSize/2)
          p -= pos % (dhp->BufferSize/2); /* round down to half buffer */

        if(size > dhp->BufferSize && (p == pos))
        {
#ifdef DEBUG
  DebugOther("InHookDisk: DirectRead(., ., %ld) from %ld", size, pos);
#endif
          io->io_Length = size;
          io->io_Data = buf;
          io->io_Offset = param->xhp_DataPos+dhp->Offset;
          if(DoIO((struct IORequest *)io))
            return XADERR_INPUT;

          buf += size;
          pos += size;
          size = 0;
          xadCopyMem(XADM buf-dhp->BufferSize, dhp->Buffer, dhp->BufferSize);
          dhp->BufferStart = pos-dhp->BufferSize;
          dhp->BufferEnd = pos;
        }
        else
        {
          if((siz = ai->xaip_InSize - p) > dhp->BufferSize)
            siz = dhp->BufferSize;

          dhp->BufferStart = p;
          dhp->BufferEnd = dhp->BufferStart + siz;
#ifdef DEBUG
  DebugOther("InHookDisk: Read(., ., %ld) from %ld", siz, dhp->BufferStart);
#endif
          io->io_Length = siz;
          io->io_Data = dhp->Buffer;
          io->io_Offset = dhp->BufferStart+dhp->Offset;
          if(DoIO((struct IORequest *)io))
            return XADERR_INPUT;

          if((siz = dhp->BufferEnd-pos) > size)
            siz = size;
#ifdef DEBUG
  DebugOther("InHookDisk: Copy %ld bytes", siz);
#endif
          xadCopyMem(XADM dhp->Buffer + (pos - dhp->BufferStart), buf, siz);
          buf += siz;
          pos += siz;
          size -= siz;
        }
      }
      param->xhp_DataPos += param->xhp_BufferSize;
    }
    break;
  case XADHC_FULLSIZE:
    param->xhp_CommandData = dhp->FullSize;
    break;
  case XADHC_SEEK:
    if(((xadSignSize)param->xhp_DataPos + param->xhp_CommandData < 0) ||
    (param->xhp_DataPos + param->xhp_CommandData > ai->xaip_InSize))
      return XADERR_INPUT;
    param->xhp_DataPos += param->xhp_CommandData;
    break;
  case XADHC_ABORT:
    break;
  case XADHC_FREE: /* free allocated stuff */
    if(dhp)
    {
      if(dhp->Buffer)
        xadFreeObjectA(XADM dhp->Buffer, 0);
      /* close device */
      if(dhp->Request)
      {
        if(dhp->Request->io_Device)
        {
          disk_busy(ai, FALSE, dhp->DosName);
          CloseDevice((struct IORequest *) dhp->Request);
        }
        DeleteIORequest((struct IORequest *) dhp->Request);
      }
      if(dhp->MsgPort)
      DeleteMsgPort(dhp->MsgPort);
      xadFreeObjectA(XADM dhp, 0);
      param->xhp_PrivatePtr = 0;
    }
    break;
  case XADHC_IMAGEINFO:
    {
      struct xadImageInfo *ii;

      ii = (struct xadImageInfo *) param->xhp_CommandData;
      ii->xii_SectorSize = dhp->BlockSize;
      ii->xii_NumSectors = ii->xii_TotalSectors = dhp->FullSize
      / dhp->BlockSize;
      ii->xii_FirstSector = 0;
    }
    break;
  case XADHC_INIT:
    {
      xadSize namesize;
#ifdef DEBUG
  DebugHook("InHookDisk: XADHC_INIT");
#endif
      namesize = ai->xaip_InDevice->xdi_DOSName
      ? strlen(ai->xaip_InDevice->xdi_DOSName)+2 : 0;
      if(!(dhp = param->xhp_PrivatePtr = (struct HookDiskPrivate *)
      xadAllocVec(XADM sizeof(struct DiskHookPrivate)+namesize,
      XADMEMF_CLEAR|XADMEMF_PUBLIC)) ||
      !(dhp->MsgPort = CreateMsgPort()) ||
      !(dhp->Request = (struct IOStdReq *)
      CreateIORequest(dhp->MsgPort, sizeof(struct IOExtTD))))
        return XADERR_NOMEMORY;
      else
      {
        struct IOStdReq *io;
        struct DriveGeometry dg;
        io = dhp->Request;

        dg.dg_SectorSize = 0;
        dg.dg_CylSectors = 0;
        dg.dg_TotalSectors = 0;
        dg.dg_BufMemType = 0;
        if(ai->xaip_InDevice->xdi_DOSName)
        {
          struct DosList *dsl;
          xadERROR err = XADERR_RESOURCE;

          dhp->DosName = (xadSTRPTR)(dhp+1);
          for(i = 0; i < namesize-2; ++i)
            dhp->DosName[i] = ai->xaip_InDevice->xdi_DOSName[i];
          dhp->DosName[i] = ':';
#ifdef DEBUG
  DebugRunTime("InHookDisk: dos device name %s - %s", dhp->DosName);
#endif

          if((dsl = LockDosList(LDF_DEVICES|LDF_READ)))
          {
            if((dsl = FindDosEntry(dsl, ai->xaip_InDevice->xdi_DOSName,
            LDF_DEVICES)))
            {
              struct FileSysStartupMsg *fssm;

              fssm = (struct FileSysStartupMsg *) BADDR(dsl->dol_misc.
                      dol_handler.dol_Startup);
              if((xadINT32) fssm > 200)
              {
                const struct DosEnvec *denv;
                denv = ((struct DosEnvec *) BADDR(fssm->fssm_Environ));

                /* test if the entry is a correct fssm -> check for valid data */
                if(denv && denv->de_TableSize < 64 && !(denv->de_SizeBlock &
                0x127) && (denv->de_LowCyl <= denv->de_HighCyl))
                {
                  if(!OpenDevice(((xadSTRPTR)(fssm->fssm_Device<<2))+1,
                  fssm->fssm_Unit, (struct IORequest *)io, 0))
                  {
#ifdef DEBUG
  DebugRunTime("OutHookDisk: opened device");
#endif
                    dg.dg_SectorSize    = denv->de_SizeBlock<<2;
                    dg.dg_Heads         = denv->de_Surfaces;
                    dg.dg_TrackSectors  = denv->de_BlocksPerTrack;
                    dg.dg_Cylinders     = denv->de_HighCyl-denv->de_LowCyl+1;
                    dg.dg_CylSectors    = dg.dg_Heads*dg.dg_TrackSectors;
                    dg.dg_TotalSectors  = dg.dg_Cylinders * dg.dg_CylSectors;
                    dg.dg_BufMemType    = denv->de_BufMemType;
                    dhp->Offset = denv->de_LowCyl*dg.dg_CylSectors*
                    dg.dg_SectorSize;
                    err = 0;
                  }
                }
              }
            }
            UnLockDosList(LDF_DEVICES|LDF_READ);
          }
          if(err)
            return err;
        }
        else
        {
#ifdef DEBUG
  DebugRunTime("InHookDisk: device name %s, unit %ld",
  ai->xaip_InDevice->xdi_DeviceName, ai->xaip_InDevice->xdi_Unit);
#endif
          if(OpenDevice(ai->xaip_InDevice->xdi_DeviceName,
          ai->xaip_InDevice->xdi_Unit, (struct IORequest *) io, 0))
            return XADERR_RESOURCE;

          dhp->Offset = 0;

          io->io_Command = TD_GETGEOMETRY;
          io->io_Length = sizeof(struct DriveGeometry);
          io->io_Data = &dg;
          if(DoIO((struct IORequest *)io))
            return XADERR_OUTPUT;
        }
        dhp->FullSize = dg.dg_SectorSize * dg.dg_TotalSectors;
        dhp->BlockSize = dg.dg_SectorSize;
        dhp->BufferSize = dg.dg_CylSectors*2*dhp->BlockSize;
        while(dhp->BufferSize < (32*1024))
          dhp->BufferSize <<= 1;

#ifdef DEBUG
  DebugRunTime("InHookDisk: offset %ld, size %ld, block %ld, buffer %ld",
  dhp->Offset, dhp->FullSize, dhp->BlockSize, dhp->BufferSize);
#endif

        if(!(dhp->Buffer = xadAllocVec(XADM dhp->BufferSize, dg.dg_BufMemType)))
          return XADERR_NOMEMORY;
        disk_busy(ai, TRUE, dhp->DosName);
      }
    }
    break;

  default: return XADERR_NOTSUPPORTED;
  }
  return 0;
}
ENDFUNC

#endif /* XADMASTER_HOOK_DISK_C */
