/*  $Id: emulation.c,v 1.6 2005/06/23 14:54:42 stoecker Exp $
    Amiga API Emulation for Unix-like systems.

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

#include "emulation.h"
#include <stddef.h>
#include <stdint.h>

xadUINT32 CallHookPkt(struct Hook *hook, xadPTR object, xadPTR paramPacket)
{
  typedef xadUINT32 (* FUNC)(struct Hook *, xadPTR, xadPTR);
  return ((FUNC)hook->h_Entry)(hook, object, paramPacket);
}

xadTAGPTR NextTagItem(xadTAGPTR *tp )
{
  if (tp == NULL || *tp == NULL) return NULL;

  for(;;)
  {
    xadUINT32 tag = (*tp)->ti_Tag;

    if (tag == TAG_IGNORE)
    {
      (*tp)++;
    }
    else if (tag == TAG_DONE)
    {
      *tp = NULL;
      return NULL;
    }
    else if (tag == TAG_MORE)
    {
        if ((*tp = (xadTAGPTR)(uintptr_t)(*tp)->ti_Data) == NULL)
          return NULL;

        continue;
    }
    else
    {
      return (*tp)++;
    }
  }
  return NULL;
}

xadTAGPTR FindTagItem(xadTag tagVal, xadTAGPTR tagList)
{
  xadTAGPTR tp = tagList, tag;

  while((tag = NextTagItem(&tp)))
  {
    if(tag->ti_Tag == tagVal)
    {
      return tag;
    }
  }

  return NULL;
}

xadUINT32 GetTagData(xadTag tagValue, xadUINT32 defVal, xadTAGPTR tagList)
{
  xadTAGPTR ti;

  if(tagList == NULL)
    return defVal;

  if((ti = FindTagItem(tagValue, tagList)) == NULL)
    return defVal;

  return ti->ti_Data;
}

