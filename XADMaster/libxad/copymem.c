#ifndef XADMASTER_COPYMEM_C
#define XADMASTER_COPYMEM_C

/*  $Id: copymem.c,v 1.7 2005/06/23 14:54:37 stoecker Exp $
    memory copy function

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

#define UNIX

#ifdef UNIX
#  include <string.h>
FUNCxadCopyMem /* const void *s, xadPTR d, xadSize size */
{
  memmove(d, s, (size_t) size);
}
ENDFUNC
#else

FUNCxadCopyMem /* const void *s, xadPTR d, xadSize size */
{
  if(!size || d == s) /* no need to copy */
    return;

  if(!(((xadSize)s|(xadSize)d|size)&3)) /* all longword aligned */
  {
    const xadUINT32 *a;
    xadUINT32 *b;

    if(d > s)
    {
      a = (const xadUINT32 *) ((const xadUINT8 *)s + size);
      b = (xadUINT32 *) ((xadUINT8 *)d + size);
      size >>= 2;
      while(size--)
        *(--b) = *(--a);
    }
    else
    {
      a = (const xadUINT32 *) s;
      b = (xadUINT32 *) d;
      size >>=2;
      while(size--)
        *(b++) = *(a++);
    }
  }
  else
  {
    const xadUINT8 *a;
    xadUINT8 *b;

    if(d > s)
    {
      a = (const xadUINT8 *) ((const xadUINT8 *)s + size);
      b = (xadUINT8 *) ((xadUINT8 *)d + size);
      while(size--)
        *(--b) = *(--a);
    }
    else
    {
      a = (const xadUINT8 *) s;
      b = (xadUINT8 *) d;
      while(size--)
        *(b++) = *(a++);
    }
  }
}
ENDFUNC
#endif /* !UNIX */

#endif  /* XADMASTER_COPYMEM_C */
