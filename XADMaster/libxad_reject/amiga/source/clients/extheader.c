/*  $Id: extheader.c,v 1.3 2005/06/23 15:47:25 stoecker Exp $
    C header for xad externals

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

#include <libraries/xadmaster.h>

/* To make this a extern Object module it is necessary to force this
structure to be the really first stuff in the file. */

extern const xadSTRING version[];
extern const struct xadClient FirstClient;

const struct xadForeman ForeMan =
{ XADFOREMAN_SECURITY, XADFOREMAN_ID, XADFOREMAN_VERSION, 0, version,
&FirstClient };

