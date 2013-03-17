#ifndef XADMASTER_VERSION_C
#define XADMASTER_VERSION_C

/*  $Id: version.h,v 1.6 2005/06/23 14:54:42 stoecker Exp $
    the xad unarchiving library system version data

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

#define BETA
#define XADMASTERVERSION   13
#define XADMASTERREVISION  0
#define DATETXT            "31.03.2003"

#include "../config.h"

#define LIBNAME   "xadmaster.library"

#ifdef DEBUG
  #define ADDTXTDEB  " DEBUG"
#else
  #define ADDTXTDEB  ""
#endif

#ifdef BETA
  #define ADDTXTBETA " BETA"
#else
  #define ADDTXTBETA ""
#endif

#ifdef DEBUGRESOURCE
  #define ADDTXTRES " RESOURCETRACK"
#else
  #define ADDTXTRES ""
#endif

#ifdef __MORPHOS__
  #define ADDTXTCPU     " MorphOS"
#elif defined(_M68060)
  #define ADDTXTCPU     " 060"
#elif defined(_M68040)
  #define ADDTXTCPU     " 040"
#elif defined(_M68030)
  #define ADDTXTCPU     " 030"
#elif defined(_M68020)
  #define ADDTXTCPU     " 020"
#else
  #define ADDTXTCPU     ""
#endif

#ifdef XAD_GPLCLIENTS
  #define DISTRIBUTION " (GPL)"
#else
  #define DISTRIBUTION " (LGPL)"
#endif

#define IDSTRING "xadmaster " VERSION " (" DATETXT ")" ADDTXTDEB ADDTXTCPU ADDTXTBETA ADDTXTRES \
                 DISTRIBUTION " by Dirk Stöcker <soft@dstoecker.de>\r\n"

#endif /* XADMASTER_VERSION_C */
