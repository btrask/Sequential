/* this is included from filename.c, do not include directly */
#ifndef XADMASTER_CS_WINDOWSCP1252_TO_UNICODE_C
#define XADMASTER_CS_WINDOWSCP1252_TO_UNICODE_C

/*  $Id: cs_windowscp1252_to_unicod.c,v 1.4 2005/06/23 14:54:37 stoecker Exp $
    Character set conversion from Windows codepage 1252 to Unicode

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

#ifndef UUNDEF
#define UUNDEF 0xFFFF  /* Unicode undefined character code */
#endif

/*  The code 0xFFFF is illegal in Unicode. This means it may never
 *  be part of a Unicode string.
 */

static const xadUINT16 windowscp1252[] = {
0x20AC, /* EURO SIGN */
UUNDEF, /* UNDEFINED */
0x201A, /* SINGLE LOW-9 QUOTATION MARK */
0x0192, /* LATIN SMALL LETTER F WITH HOOK */
0x201E, /* DOUBLE LOW-9 QUOTATION MARK */
0x2026, /* HORIZONTAL ELLIPSIS */
0x2020, /* DAGGER */
0x2021, /* DOUBLE DAGGER */
0x02C6, /* MODIFIER LETTER CIRCUMFLEX ACCENT */
0x2030, /* PER MILLE SIGN */
0x0160, /* LATIN CAPITAL LETTER S WITH CARON */
0x2039, /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
0x0152, /* LATIN CAPITAL LIGATURE OE */
UUNDEF, /* UNDEFINED */
0x017D, /* LATIN CAPITAL LETTER Z WITH CARON */
UUNDEF, /* UNDEFINED */
UUNDEF, /* UNDEFINED */
0x2018, /* LEFT SINGLE QUOTATION MARK */
0x2019, /* RIGHT SINGLE QUOTATION MARK */
0x201C, /* LEFT DOUBLE QUOTATION MARK */
0x201D, /* RIGHT DOUBLE QUOTATION MARK */
0x2022, /* BULLET */
0x2013, /* EN DASH */
0x2014, /* EM DASH */
0x02DC, /* SMALL TILDE */
0x2122, /* TRADE MARK SIGN */
0x0161, /* LATIN SMALL LETTER S WITH CARON */
0x203A, /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
0x0153, /* LATIN SMALL LIGATURE OE */
UUNDEF, /* UNDEFINED */
0x017E, /* LATIN SMALL LETTER Z WITH CARON */
0x0178  /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
};

static xadUINT16 windowscp1252_to_unicode(xadUINT16 i)
{
    if (i > 0x7F && i < 0xA0)
        i = windowscp1252[i-0x80];

    return i;
}

#endif /* XADMASTER_CS_WINDOWSCP1252_TO_UNICODE_C */
