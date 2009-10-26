#ifndef XADMASTER_CLIENTFUNC_C
#define XADMASTER_CLIENTFUNC_C

/*  $Id: clientfunc.c,v 1.19 2005/06/23 14:54:36 stoecker Exp $
    the client support functions

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

#include "functions.h"
#include "version.h"
#include <ctype.h> /* needed for isprint() */

FUNCxadGetClientInfo /* no args */
{
  return xadMasterBase->xmb_FirstClient;
}
ENDFUNC

FUNCxadAddDiskEntry /* struct xadDiskInfo *di, struct xadArchiveInfoP *ai,
  xadTAGPTR tags */
{
  struct xadDiskInfo *ldi;
  xadTAGPTR ti;
  xadUINT32 i;
  xadERROR ret = 0;

#ifdef DEBUG
  DebugHookTagList("xadAddDiskEntry()", tags);
#endif

  di->xdi_EntryNumber = ++ai->xaip_LastEntryNumber;
  if((ldi = ai->xaip_LastDiskEntry))
    ldi->xdi_Next = di;
  else
    ai->xaip_ArchiveInfo.xai_DiskInfo = di;
  ai->xaip_LastDiskEntry = di;
  di->xdi_Next = 0;
  /* never return errors before this point! */

  ldi = ai->xaip_ArchiveInfo.xai_CurDisk;
  ai->xaip_ArchiveInfo.xai_CurDisk = di;
  if(!((i = callprogress(ai, 0, XADPMODE_NEWENTRY, xadMasterBase)) & XADPIF_OK))
    ret = XADERR_BREAK;
  ai->xaip_ArchiveInfo.xai_CurDisk = ldi; /* reset */
  if(!ret && (ti = FindTagItem(XAD_SETINPOS, tags)) &&
  (ai->xaip_ArchiveInfo.xai_InPos != ti->ti_Data
  || FindTagItem(XAD_USESKIPINFO, tags)))
  {
    ret = xadHookTagAccessA(XADM_PRIV XADAC_INPUTSEEK,
    ti->ti_Data-ai->xaip_ArchiveInfo.xai_InPos, 0, XADM_AI(ai), tags);
  }

  return ret;
}
ENDFUNC

FUNCxadAddFileEntry /* struct xadFileInfo *fi, struct xadArchiveInfoP *ai,
  xadTAGPTR tags */
{
  struct xadFileInfo *lfi;
  xadTAGPTR ti;
  xadUINT32 i;
  xadERROR ret = 0;

#ifdef DEBUG
  DebugHookTagList("xadAddFileEntry()", tags);
  if(fi->xfi_Special)
    DebugRunTime("LIBxadAddFileEntry: entry '%s' has special info",
    fi->xfi_FileName);
#endif

  lfi = ai->xaip_LastFileEntry;
  fi->xfi_EntryNumber = ++ai->xaip_LastEntryNumber;
  if(lfi && (fi->xfi_Flags & XADFIF_DIRECTORY)
  && GetTagData(XAD_INSERTDIRSFIRST, 0, tags))
  {
    struct xadFileInfo *lfi2 = 0;

    lfi = ai->xaip_ArchiveInfo.xai_FileInfo;

    while(lfi && (lfi->xfi_Flags & XADFIF_DIRECTORY) &&
    stricmp(lfi->xfi_FileName, fi->xfi_FileName) <= 0)
    {
      lfi2 = lfi; lfi = lfi->xfi_Next;
    }
    if(lfi2)
      lfi2->xfi_Next = fi;
    else
      ai->xaip_ArchiveInfo.xai_FileInfo = fi;
    if(!(fi->xfi_Next = lfi))
      ai->xaip_LastFileEntry = fi;
  }
  else
  {
    if(lfi)
      lfi->xfi_Next = fi;
    else
      ai->xaip_ArchiveInfo.xai_FileInfo = fi;
    fi->xfi_Next = 0;
    ai->xaip_LastFileEntry = fi;
  }
  /* never return errors before this point! */

  lfi = ai->xaip_ArchiveInfo.xai_CurFile;
  ai->xaip_ArchiveInfo.xai_CurFile = fi;
  if(!((i = callprogress(ai, 0, XADPMODE_NEWENTRY, xadMasterBase))
  & XADPIF_OK))
    ret = XADERR_BREAK;
  ai->xaip_ArchiveInfo.xai_CurFile = lfi; /* reset */
  if(!ret && (ti = FindTagItem(XAD_SETINPOS, tags)) &&
  (ai->xaip_ArchiveInfo.xai_InPos != ti->ti_Data
  || FindTagItem(XAD_USESKIPINFO, tags)))
    ret = xadHookTagAccessA(XADM XADAC_INPUTSEEK,
    ti->ti_Data-ai->xaip_ArchiveInfo.xai_InPos, 0,
    XADM_AI(ai), tags);

  return ret;
}
ENDFUNC

FUNCxadHookAccess /* xadUINT32 command, xadSignSize data, xadPTR buffer,
  struct xadArchiveInfoP *ai */
{
  return xadHookTagAccessA(XADM_PRIV command, data, buffer, XADM_AI(ai), 0);
}
ENDFUNC

static xadERROR skipread(xadUINT8 *buf, xadSize size,
struct xadArchiveInfoP *ai, xadUINT32 skip)
{
#ifdef AMIGA
  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) ai->xaip_MasterBase;
  struct UtilityBase *UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif
  struct xadHookParam *ihp;
  struct Hook *ih;
  const struct xadSkipInfo *si, *si2;
  xadERROR ret = 0;
  xadSize s;

  ihp = &(ai->xaip_InHookParam);
  ih = ai->xaip_InHook;

  if(ai->xaip_ArchiveInfo.xai_SkipInfo && skip)
  {
    while(!ret && size)
    {
      si2 = 0;
      for(si = ai->xaip_ArchiveInfo.xai_SkipInfo; si; si = si->xsi_Next)
      {
        /* skip buffer at start */
        if(si->xsi_Position <= ai->xaip_ArchiveInfo.xai_InPos &&
        si->xsi_Position+si->xsi_SkipSize > ai->xaip_ArchiveInfo.xai_InPos)
        {
          ihp->xhp_Command = XADHC_SEEK;
          ihp->xhp_CommandData = si->xsi_Position+si->xsi_SkipSize
          - ai->xaip_ArchiveInfo.xai_InPos;
          ret = CallHookPkt(ih, ai, ihp);
          ai->xaip_ArchiveInfo.xai_InPos  = ihp->xhp_DataPos;
        }
        else if(si->xsi_Position > ai->xaip_ArchiveInfo.xai_InPos &&
        (!si2 || si2->xsi_Position > si->xsi_Position))
          si2 = si;
      }

      if(!ret)
      {
        if(!si2 || (s = si2->xsi_Position - ai->xaip_ArchiveInfo.xai_InPos)
        > size)
          s = size;

        ihp->xhp_Command = XADHC_READ;
        ihp->xhp_BufferPtr  = buf;
        ihp->xhp_BufferSize = s;
        ret = CallHookPkt(ih, ai, ihp);
        buf += s;
        ai->xaip_ArchiveInfo.xai_InPos  = ihp->xhp_DataPos;
        size -= s;
      }
    }
  }
  else
  {
    ihp->xhp_Command = XADHC_READ;
    ihp->xhp_BufferPtr  = buf;
    ihp->xhp_BufferSize = size;
    ret = CallHookPkt(ih, ai, ihp);
    ai->xaip_ArchiveInfo.xai_InPos  = ihp->xhp_DataPos;
  }
  return ret;
}

xadSignSize getskipsize(xadSignSize data, const struct xadArchiveInfoP *ai)
{
  const struct xadSkipInfo *si, *silo, *sihi, *sit;

#ifdef DEBUG
  xadSignSize sdata;
  sdata = data;
#endif

  for(si = silo = sihi = ai->xaip_ArchiveInfo.xai_SkipInfo; si;
  si = si->xsi_Next)
  {
    if(si->xsi_Position > sihi->xsi_Position)
      sihi = si;
    if(si->xsi_Position < silo->xsi_Position)
      silo = si;
  }
  if(data < 0) /* skip when entries are at buffer start or in buffer */
  {
    for(;;)
    {
      if(sihi->xsi_Position < ai->xaip_ArchiveInfo.xai_InPos)
      {
        if(sihi->xsi_Position + sihi->xsi_SkipSize
        > ai->xaip_ArchiveInfo.xai_InPos)
          data -= ai->xaip_ArchiveInfo.xai_InPos - sihi->xsi_Position;
        else if(sihi->xsi_Position + sihi->xsi_SkipSize
        > ai->xaip_ArchiveInfo.xai_InPos+data)
          data -= sihi->xsi_SkipSize;
      }
      if(silo == sihi)
        break;
      else
      {
        sit = silo;
        for(si = ai->xaip_ArchiveInfo.xai_SkipInfo; si; si = si->xsi_Next)
        {
          if(si->xsi_Position > sit->xsi_Position && si->xsi_Position
          < sihi->xsi_Position)
            sit = si;
        }
        sihi = sit;
      }
    }
  }
  else
  {
    for(;;)
    {
      if(silo->xsi_Position >= ai->xaip_ArchiveInfo.xai_InPos) /* in buffer */
      {
        if(silo->xsi_Position <= ai->xaip_ArchiveInfo.xai_InPos+data)
          data += silo->xsi_SkipSize;
      }
      else if(silo->xsi_Position+silo->xsi_SkipSize
      > ai->xaip_ArchiveInfo.xai_InPos) /* first border partial */
        data += silo->xsi_Position+silo->xsi_SkipSize
        -ai->xaip_ArchiveInfo.xai_InPos;
      if(silo == sihi)
        break;
      else
      {
        sit = sihi;
        for(si = ai->xaip_ArchiveInfo.xai_SkipInfo; si; si = si->xsi_Next)
        {
          if(si->xsi_Position < sit->xsi_Position && si->xsi_Position
          > silo->xsi_Position)
            sit = si;
        }
        silo = sit;
      }
    }
  }

#ifdef DEBUG
  if(sdata != data)
    DebugRunTime("getskipsize: changed seeksize from %ld to %ld", sdata, data);
#endif
  return data;
}

FUNCxadHookTagAccess /* xadUINT32 command, xadSignSize data, xadPTR buffer,
  struct xadArchiveInfo *ai, xadTAGPTR tags */
{
  xadERROR ret = 0;
  xadUINT32 skip = 0;
  struct xadHookParam *ihp, *ohp;
  struct Hook *ih, *oh;
  xadTAGPTR ti;
  struct TagItem tis[2];
  xadUINT32 *crc32 = 0, crc32ID = XADCRC32_ID1;
  xadUINT16 *crc16 = 0, crc16ID = XADCRC16_ID1;

#ifdef DEBUG
  static const xadSTRPTR comname[] = {"XADAC_READ", "XADAC_WRITE",
  "XADAC_COPY", "XADAC_INPUTSEEK", "XADAC_OUTPUTSEEK"};
  DebugHookTagList("xadHookAccess(%-16s, %7lld, %08lx, .) pos(%6lld|%6lld)", tags,
  comname[command-XADAC_READ], data, buffer, ai->xaip_ArchiveInfo.xai_InPos,
  ai->xaip_ArchiveInfo.xai_OutPos);
#endif

  tis[0].ti_Tag = XAD_SECTORLABELS;
  tis[0].ti_Data = 0;
  tis[1].ti_Tag = TAG_DONE;

  ihp = &(ai->xaip_InHookParam);
  ohp = &(ai->xaip_OutHookParam);
  ih = ai->xaip_InHook;
  oh = ai->xaip_OutHook;

  if((!ih && (command == XADAC_READ || command == XADAC_INPUTSEEK
  || command == XADAC_COPY)) || (!oh && (command == XADAC_WRITE
  || command == XADAC_OUTPUTSEEK || command == XADAC_COPY)))
    return XADERR_BADPARAMS;

  ti = tags;
  while((tags = NextTagItem(&ti)))
  {
    switch(tags->ti_Tag)
    {
    case XAD_USESKIPINFO: skip = (xadUINT32) tags->ti_Data; break;
    case XAD_SECTORLABELS: tis[0].ti_Data = tags->ti_Data; break;
    case XAD_GETCRC32: crc32 = (xadUINT32 *)(uintptr_t) tags->ti_Data; break;
    case XAD_GETCRC16: crc16 = (xadUINT16 *)(uintptr_t) tags->ti_Data; break;
    case XAD_CRC32ID: crc32ID = (xadUINT32) tags->ti_Data; break;
    case XAD_CRC16ID: crc16ID = (xadUINT16)  tags->ti_Data; break;
    }
  }

  if(tis[0].ti_Data && (data&(512-1)))
    return XADERR_BADPARAMS;

  switch(command)
  {
    case XADAC_READ:
      ret = skipread(buffer, data, ai, skip);
      if(crc32)
        *crc32 = xadCalcCRC32(XADM_PRIV crc32ID, *crc32, data, buffer);
      if(crc16)
        *crc16 = xadCalcCRC16(XADM_PRIV crc16ID, *crc16, data, buffer);
      break;
    case XADAC_WRITE:
      ohp->xhp_Command    = XADHC_WRITE;
      ohp->xhp_BufferPtr  = buffer;
      ohp->xhp_BufferSize = data;
      if(tis[0].ti_Data)
      {
#ifdef DEBUG
        xadINT32 i, j;
        xadUINT8 r[16*2+1+16+1], *s;

        s = (xadUINT8 *) tis[0].ti_Data;
        for(i = 0; i < data; i += 512)
        {
          for(j = 0; j < 16; ++j)
          {
            r[j*2] = (*s/16 >= 10) ? (*s/16+'A'-10) : (*s/16+'0');
            r[j*2+1] = (*s%16 >= 10) ? (*s%16+'A'-10) : (*s%16+'0');
            r[32] = ' ';
            r[33+j] = isprint(*s) ? *s : '.';
            ++s;
            r[33+16] = 0;
          }
          DebugOther("SectorLabel: %s", r);
        }
#endif
        ohp->xhp_TagList = tis;
      }
      ret = CallHookPkt(oh, ai, ohp);
      ai->xaip_ArchiveInfo.xai_OutPos = ohp->xhp_DataPos;
      if(ohp->xhp_DataPos > ai->xaip_ArchiveInfo.xai_OutSize)
      {
        ai->xaip_ArchiveInfo.xai_OutSize = ohp->xhp_DataPos;
        if(!ret)
        {
          xadUINT32 i;
          if(!((i = callprogress(ai, 0, XADPMODE_PROGRESS, xadMasterBase))
          & XADPIF_OK))
            ret = XADERR_BREAK;
          else if(i & XADPIF_SKIP)
            ret = XADERR_SKIP;
        }
      }
      if(crc32)
        *crc32 = xadCalcCRC32(XADM crc32ID, *crc32, data, buffer);
      if(crc16)
        *crc16 = xadCalcCRC16(XADM crc16ID, *crc16, data, buffer);
      break;
    case XADAC_COPY:
      {
        xadSize bufsize;
        xadPTR buf;

        if((bufsize = data) > 51200)
          bufsize = 51200;
        if((buf = xadAllocVec(XADM bufsize, XADMEMF_PUBLIC)))
        {
          ohp->xhp_Command   = XADHC_WRITE;
          ohp->xhp_BufferPtr = buf;
          while(data > 0 && !ret)
          {
            ohp->xhp_BufferSize = data > bufsize ? bufsize : data;
            if(!(ret = skipread(buf, ohp->xhp_BufferSize, ai, skip)))
              ret = CallHookPkt(oh, ai, ohp);

            if(crc32)
              *crc32 = xadCalcCRC32(XADM crc32ID, *crc32, ohp->xhp_BufferSize,
              ohp->xhp_BufferPtr);
            if(crc16)
              *crc16 = xadCalcCRC16(XADM crc16ID, *crc16, ohp->xhp_BufferSize,
              ohp->xhp_BufferPtr);

            ai->xaip_ArchiveInfo.xai_OutPos = ohp->xhp_DataPos;
            if(ohp->xhp_DataPos > ai->xaip_ArchiveInfo.xai_OutSize)
            {
              ai->xaip_ArchiveInfo.xai_OutSize = ohp->xhp_DataPos;
              if(!ret)
              {
                xadUINT32 i;
                if(!((i = callprogress(ai, 0, XADPMODE_PROGRESS,
                xadMasterBase)) & XADPIF_OK))
                  ret = XADERR_BREAK;
                else if(i & XADPIF_SKIP)
                  ret = XADERR_SKIP;
              }
            }
            data -= ohp->xhp_BufferSize;
          }
          xadFreeObjectA(XADM buf, 0);
        }
        else
          ret = XADERR_NOMEMORY;
      }
      break;
    case XADAC_INPUTSEEK:
      if(skip)
        data = getskipsize(data, ai);

      ihp->xhp_Command     = XADHC_SEEK;
      ihp->xhp_CommandData = data;
      ret = CallHookPkt(ih, ai, ihp);
      ai->xaip_ArchiveInfo.xai_InPos = ihp->xhp_DataPos;
      break;
    case XADAC_OUTPUTSEEK:
      ohp->xhp_Command     = XADHC_SEEK;
      ohp->xhp_CommandData = data;
      ret = CallHookPkt(oh, ai, ohp);
      ai->xaip_ArchiveInfo.xai_OutPos = ohp->xhp_DataPos;
      break;
    default: ret = XADERR_NOTSUPPORTED; break;
  }

#ifdef DEBUG
  if(ret)
    DebugError("xadHookAccess returns \"%s\" (%ld)", xadGetErrorText(XADM ret), ret);
#endif

  return ret;
}
ENDFUNC

xadUINT32 callprogress(const struct xadArchiveInfoP *ai, xadUINT32 stat,
xadUINT32 mode, struct xadMasterBaseP * xadMasterBase)
{
  xadUINT32 ret = XADPIF_OK;
  struct xadProgressInfo *pi;
#ifdef AMIGA
  struct UtilityBase *UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif

#ifdef DEBUG
  DebugRunTime("callprogress: hook = $%08lx", ai->xaip_ProgressHook);
#endif

  if(ai->xaip_ProgressHook)
  {
    if((pi = (struct xadProgressInfo *) xadAllocObjectA(XADM
    XADOBJ_PROGRESSINFO, 0)))
    {
      pi->xpi_Mode = mode;
      pi->xpi_Client = ai->xaip_ArchiveInfo.xai_Client;
      pi->xpi_DiskInfo = ai->xaip_ArchiveInfo.xai_CurDisk;
      pi->xpi_FileInfo = ai->xaip_ArchiveInfo.xai_CurFile;
      pi->xpi_CurrentSize = ai->xaip_ArchiveInfo.xai_OutSize;
      pi->xpi_LowCyl = ai->xaip_ArchiveInfo.xai_LowCyl;
      pi->xpi_HighCyl = ai->xaip_ArchiveInfo.xai_HighCyl;
      if(mode == XADPMODE_ERROR)
      {
        pi->xpi_Error = stat; stat = 0;
      }
      pi->xpi_Status = stat;
      ret = CallHookPkt(ai->xaip_ProgressHook, 0, pi);
      xadFreeObjectA(XADM pi, 0);
    }
  }
  return ret;
}

xadUINT32 callprogressFN(const struct xadArchiveInfoP *ai, xadUINT32 stat,
xadUINT32 mode, xadSTRPTR *filename, struct xadMasterBaseP * xadMasterBase)
{
  xadUINT32 ret = XADPIF_OK;
  struct xadProgressInfo *pi;
#ifdef AMIGA
  struct UtilityBase *UtilityBase = xadMasterBase->xmb_UtilityBase;
#endif

#ifdef DEBUG
  DebugRunTime("callprogressFN: hook = $%08lx", ai->xaip_ProgressHook);
#endif

  if(ai->xaip_ProgressHook)
  {
    if((pi = (struct xadProgressInfo *) xadAllocObjectA(XADM
    XADOBJ_PROGRESSINFO, 0)))
    {
      pi->xpi_FileName = *filename;
      pi->xpi_Mode = mode;
      pi->xpi_Client = ai->xaip_ArchiveInfo.xai_Client;
      pi->xpi_DiskInfo = ai->xaip_ArchiveInfo.xai_CurDisk;
      pi->xpi_FileInfo = ai->xaip_ArchiveInfo.xai_CurFile;
      pi->xpi_CurrentSize = ai->xaip_ArchiveInfo.xai_OutSize;
      pi->xpi_LowCyl = ai->xaip_ArchiveInfo.xai_LowCyl;
      pi->xpi_HighCyl = ai->xaip_ArchiveInfo.xai_HighCyl;
      if(mode == XADPMODE_ERROR)
      {
        pi->xpi_Error = stat; stat = 0;
      }
      pi->xpi_Status = stat;
      ret = CallHookPkt(ai->xaip_ProgressHook, 0, pi);
      *filename = pi->xpi_NewName;
      xadFreeObjectA(XADM pi, 0);
    }
  }
  return ret;
}

/* Copies all clients given to the central list in xadMasterBase. If any
 * entries have xc_Identifier set, searches the list and overwrites the
 * first entry with the same identifier. The xc_Flags and add_flags are
 * ORed in any new entry. Returns XADTRUE if any client could be added,
 * XADFALSE if no client could be added.
 */
xadBOOL xadAddClients(struct xadMasterBaseP *xadMasterBase,
                      const struct xadClient *clients,
                      xadUINT32 add_flags)
{
  const struct xadClient *xc;
  struct xadClient *xc2, *new_xc, *tail;
  xadBOOL ok = XADFALSE;

  /* go to tail of client list */
  tail = xadMasterBase->xmb_FirstClient;
  while (tail && tail->xc_Next) tail = tail->xc_Next;

  /* for all clients */
  for (xc = clients; xc; xc = xc->xc_Next) {
    /* reject client if it is too new to be used */
    if (xc->xc_MasterVersion > XADMASTERVERSION) continue;

    /* if client has an ID, try and find if a client with that ID already
     * exists in the list, and overwrite it */
    if (xc->xc_Identifier) {
      /* loop through all clients */
      for (xc2 = xadMasterBase->xmb_FirstClient; xc2; xc2 = xc2->xc_Next) {
        /* if a matching ID is found */
        if (xc2->xc_Identifier == xc->xc_Identifier) {
          /* copy over existing client, but don't lose the list link */
          new_xc = xc2->xc_Next;
          xadCopyMem(XADM xc, xc2, sizeof(struct xadClient));
          xc2->xc_Next = new_xc;
          xc2->xc_Flags |= add_flags;
          ok = XADTRUE;
          break;
        }
      }
      /* if we found a match, this client has been added */
      if (xc2) continue;
    }

    /* there was no identifier or no match, so we have to add this client */
    if ((new_xc = xadAllocVec(XADM sizeof(struct xadClient), XADMEMF_PUBLIC))) {
      xadCopyMem(XADM xc, new_xc, sizeof(struct xadClient));
      new_xc->xc_Next = NULL;
      new_xc->xc_Flags |= add_flags;
      if (tail) tail->xc_Next = new_xc;
      else xadMasterBase->xmb_FirstClient = new_xc;
      tail = new_xc;
      ok = XADTRUE;
    }
  }
  return ok;
}

/* Removes all clients from the central list in xadMasterBase */
void xadFreeClients(struct xadMasterBaseP *xadMasterBase)
{
  struct xadClient *xc, *next;
  for (xc = xadMasterBase->xmb_FirstClient; xc; xc = next) {
    next = xc->xc_Next;
    xadFreeObjectA(XADM xc, 0);
  }
  xadMasterBase->xmb_FirstClient = NULL;
}

#endif /* XADMASTER_CLIENTFUNC_C */
