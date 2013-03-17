/* this is included from filename.c, do not include directly */
#ifndef XADMASTER_CS_UNICODE_TO_ISO8859_1_C
#define XADMASTER_CS_UNICODE_TO_ISO8859_1_C

/*  $Id: cs_unicode_to_iso8859-1.c,v 1.5 2005/06/23 14:54:37 stoecker Exp $
    Character set conversion from Unicode to ISO 8859-1

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

/*  Notes:
 *  o The characters are selected on visual similarity, or
 *    on functional similarity.
 *  o Letters with diacritics may be converted to the same
 *    letter with less or no diacritics
 *  o For best results, the Unicode string should be
 *    normalized to form C (i.e. Composed).
 */

static xadUINT16 unicode_to_iso8859_1(xadUINT16 a, xadUINT16 mchar)
{
    if (a > 0x00FF)
    {
        switch (a)
        {
            case 0x201C:         /* LEFT DOUBLE QUOTATION MARK */
            case 0x201D:         /* RIGHT DOUBLE QUOTATION MARK */
            case 0x201E:         /* DOUBLE LOW-9 QUOTATION MARK */
            case 0x201F:         /* DOUBLE HIGH-REVERSED-9 QUOTATION MARK */
                a = 0x22; break; /* QUOTATION MARK */

            case 0x2018:         /* LEFT SINGLE QUOTATION MARK */
            case 0x2019:         /* RIGHT SINGLE QUOTATION MARK */
            case 0x201B:         /* SINGLE HIGH-REVERSED-9 QUOTATION MARK */
                a = 0x27; break; /* APOSTROPHE */

            case 0x201A:         /* SINGLE LOW-9 QUOTATION MARK */
                a = 0x2C; break; /* COMMA */

            case 0x2010:         /* HYPHEN */
            case 0x2011:         /* NON-BREAKING HYPHEN */
            case 0x2012:         /* FIGURE DASH */
            case 0x2013:         /* EN DASH */
            case 0x2014:         /* EM DASH */
            case 0x2015:         /* HORIZONTAL BAR */
                a = 0x2D; break; /* HYPHEN-MINUS */

//            case 0x2044:         /* FRACTION SLASH */
//                a = 0x2F; break; /* SOLIDUS */

            case 0x2039:         /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
                a = 0x3C; break; /* LESS-THAN SIGN */

            case 0x203A:         /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
                a = 0x3E; break; /* GREATER-THAN SIGN */

            case 0x0160:         /* LATIN CAPITAL LETTER S WITH CARON */
                a = 0x53; break; /* LATIN CAPITAL LETTER S */

            case 0x02C6:         /* MODIFIER LETTER CIRCUMFLEX ACCENT */
            case 0x2038:         /* CARET */
                a = 0x5E; break; /* CIRCUMFLEX ACCENT */

            case 0x0178:         /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
                a = 0x59; break; /* LATIN CAPITAL LETTER Y */

            case 0x017D:         /* LATIN CAPITAL LETTER Z WITH CARON */
                a = 0x5A; break; /* LATIN CAPITAL LETTER Z */

            case 0x02CB:         /* MODIFIER LETTER GRAVE ACCENT */
                a = 0x60; break; /* GRAVE ACCENT */

            case 0x0192:         /* LATIN SMALL LETTER F WITH HOOK */
                a = 0x66; break; /* LATIN SMALL LETTER F */

            case 0x0131:         /* LATIN SMALL LETTER DOTLESS I */
                a = 0x69; break; /* LATIN SMALL LETTER I */

            case 0x0161:         /* LATIN SMALL LETTER S WITH CARON */
                a = 0x73; break; /* LATIN SMALL LETTER S */

            case 0x017E:         /* LATIN SMALL LETTER Z WITH CARON */
                a = 0x7A; break; /* LATIN SMALL LETTER Z */

            case 0x02DC:         /* SMALL TILDE */
                a = 0x7E; break; /* TILDE */

            case 0x02DA:         /* RING ABOVE */
                a = 0xB0; break; /* DEGREE SIGN */

            case 0x2022:         /* BULLET */
            case 0x2219:         /* BULLET OPERATOR */
                a = 0xB7; break; /* MIDDLE DOT */

            case 0x03B2:         /* GREEK SMALL LETTER BETA */
                a = 0xDF; break; /* LATIN SMALL LETTER SHARP S */

            default:
                a = mchar; break;
        }
    }
    return a;
}

#endif /* XADMASTER_CS_UNICODE_TO_ISO8859_1_C */
