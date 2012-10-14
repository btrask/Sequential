/*  $Id: emulation.h,v 1.7 2005/06/23 14:54:43 stoecker Exp $
    Old Amiga remains.

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

#ifndef EMULATION_H
#define EMULATION_H

#include "../include/functions.h"

xadTAGPTR NextTagItem(xadTAGPTR *tp);
xadTAGPTR FindTagItem(xadTag tagVal, xadTAGPTR tags);
xadUINT32 GetTagData(xadTag tagValue, xadUINT32 defVal, xadTAGPTR tags);
xadUINT32 CallHookPkt(struct Hook *hook, xadPTR object, xadPTR paramPacket);

#endif /* EMULATION_H */
