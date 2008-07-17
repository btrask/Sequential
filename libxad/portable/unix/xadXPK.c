#ifndef XADMASTER_XADXPK_C
#define XADMASTER_XADXPK_C

/*  $Id: xadXPK.c,v 1.5 2005/06/23 14:54:43 stoecker Exp $
    xpk decrunch handling for Unix

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

/* Will be replaced by xadIO_XPK.c !!! */
static xadINT32 xpkDecrunch(xadSTRPTR *str, xadUINT32 *size, struct xadArchiveInfo *ai,
struct xadMasterBase *xadMasterBase)
{
  return XADERR_NOTSUPPORTED;
}

#endif /* XADMASTER_XADXPK_C */
