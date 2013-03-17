#ifndef XADMASTER_ERROR_C
#define XADMASTER_ERROR_C

/*  $Id: error.c,v 1.6 2005/06/23 14:54:37 stoecker Exp $
    error text handling stuff

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

#include "include/functions.h"

static const char *errtxt[] = {
"no error",
"unknown error",
"error reading input",
"error writing output",
"function call with bad parameters",
"not enough memory",
"input data is illegal or corrupted",
"command is not supported",
"missing required resource",
"error on decrunching data",
"filetype is unknown",
"opening file failed",
"file has been skipped",
"user break",
"file already exists",
"missing or wrong password",
"could not create directory",
"wrong checksum",
"verify failed",
"wrong drive geometry",
"unknown data format",
"source contains no files",
"unknown filesystem",
"name of file exists as directory",
"buffer too short",
"text encoding defective",
};

FUNCxadGetErrorText /* xadERROR errnum */
{
  /* Warning: xadMasterBase may be NULL at this point.
     DoDebug() in debug.c needs to pass NULL. */

  if(errnum < XADERR_OK || errnum > XADERR_ENCODING)
    errnum = XADERR_UNKNOWN;

  return (xadSTRPTR)errtxt[errnum];
}
ENDFUNC

#endif  /* XADMASTER_ERROR_C */
