#ifndef XADMASTER_ALL_C
#define XADMASTER_ALL_C

/*  $Id: all.c,v 1.4 2005/06/23 14:54:36 stoecker Exp $
    all-in-one file for short code

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

#include "config.h"

#include "include/functions.h"
#include "clientfunc.c"
#include "copymem.c"
#include "crc.c"
#include "dates.c"
#include "diskfile.c"
#include "diskunarc.c"
#include "error.c"
#include "filename.c"
#include "fileunarc.c"
#include "hook.c"
#ifdef AMIGA
#include "hook_disk.c"
#endif
#include "hook_diskarc.c"
#include "unix/hook_fh.c"
#include "hook_mem.c"
#include "hook_splitted.c"
#include "hook_stream.c"
#include "info.c"
#include "objects.c"
#include "protection.c"
#if defined(DEBUG) || defined(DEBUGRESOURCE)
#include "debug.c"
#endif

#endif /* XADMASTER_ALL_C */
