#ifndef XADMASTER_CONVERTE_C
#define XADMASTER_CONVERTE_C

/*  $Id: ConvertE.c,v 1.5 2005/06/23 14:54:41 stoecker Exp $
    endian conversion macros

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

/* EndGetXXX(a)  - returns value read direct from memory in fixed size and
 *                 endianness, returned to native order.
 *
 * Keep in mind, that the macros require calculation time, so avoid to use
 * them double time. Call them once and reuse results.
 *
 * XXX can be:
 * M64 - big-endian Motorola format, 64 bit value
 * M32 - big-endian Motorola format, 32 bit value
 * M24 - big-endian Motorola format, 24 bit value
 * M16 - big-endian Motorola format, 16 bit value
 *
 * I64 - little-endian Intel format, 64 bit value
 * I32 - little-endian Intel format, 32 bit value
 * I24 - little-endian Intel format, 24 bit value
 * I16 - little-endian Intel format, 16 bit value
 */

#define EndGetM32(a)  (((((unsigned char *) a)[0]) << 24) |             \
                       ((((unsigned char *) a)[1]) << 16) |             \
                       ((((unsigned char *) a)[2]) <<  8) |             \
                       ((((unsigned char *) a)[3])))
#define EndGetM24(a)  (((((unsigned char *) a)[0]) << 16) |             \
                       ((((unsigned char *) a)[1]) <<  8) |             \
                       ((((unsigned char *) a)[2])))
#define EndGetM16(a)  (((((unsigned char *) a)[0]) <<  8) |             \
                       ((((unsigned char *) a)[1])))

#define EndGetI32(a)  (((((unsigned char *) a)[3]) << 24) |             \
                       ((((unsigned char *) a)[2]) << 16) |             \
                       ((((unsigned char *) a)[1]) <<  8) |             \
                       ((((unsigned char *) a)[0])))
#define EndGetI24(a)  (((((unsigned char *) a)[2]) << 16) |             \
                       ((((unsigned char *) a)[1]) <<  8) |             \
                       ((((unsigned char *) a)[0])))
#define EndGetI16(a)  (((((unsigned char *) a)[1]) <<  8) |             \
                       ((((unsigned char *) a)[0])))

/* 64-bit support */
#define _convM32(a,n)(((((unsigned char *) a)[n+0]) << 24) |            \
                      ((((unsigned char *) a)[n+1]) << 16) |            \
                      ((((unsigned char *) a)[n+2]) <<  8) |            \
                      ((((unsigned char *) a)[n+3])))
#define _convI32(a,n)(((((unsigned char *) a)[n+3]) << 24) |            \
                      ((((unsigned char *) a)[n+2]) << 16) |            \
                      ((((unsigned char *) a)[n+1]) <<  8) |            \
                      ((((unsigned char *) a)[n+0])))

#if defined(AMIGA) /* AMIGA XAD has not 64 bit types yet */
#  define EndGetI64(a) ((unsigned int) _convi32(a,0))
#  define EndGetM64(a) ((unsigned int) _convm32(a,4))
#elif defined(HAVE_STDINT_H)
#  include <stdint.h>
  /* C99 -- use "uint64_t" as 64-bit type */
#  define EndGetI64(a) ((((uint64_t)    _convi32(a,4)) << 32) | \
                        ((unsigned int) _convi32(a,0)))
#  define EndGetM64(a) ((((uint64_t)    _convm32(a,0)) << 32) | \
                        ((unsigned int) _convm32(a,4)))
#else
/* GCC -- use "unsigned long long int" as 64-bit type */
#  define EndGetI64(a) ((((unsigned long long int) _convi32(a,4)) << 32) | \
                        ((unsigned int)            _convi32(a,0)))
#  define EndGetM64(a) ((((unsigned long long int) _convm32(a,0)) << 32) | \
                        ((unsigned int)            _convm32(a,4)))
#endif

#endif /* XADMASTER_CONVERTE_C */
