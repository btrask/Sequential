#ifndef XADMASTER_FILENAME_C
#define XADMASTER_FILENAME_C

/*  $Id: filename.c,v 1.12 2005/06/23 14:54:37 stoecker Exp $
    filename conversion

    XAD library system for archive handling
    Copyright (C) 1998 and later by Dirk Stˆcker <soft@dstoecker.de>

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

#include "cs_atarist_to_unicode.c"
#include "cs_c64_to_unicode.c"
#include "cs_ibmcp437_to_unicode.c"
#include "cs_macroman_to_unicode.c"
#include "cs_unicode_to_iso8859-1.c"
#include "cs_windowscp1252_to_unicod.c"

struct MyString {
  /* NOTE: The strings here are NOT zero ended! */
  xadSTRPTR   string;
  xadUINT16 * ucstring;
  xadUINT32   bufsize;
  xadUINT32   size;
  xadUINT32   ucsize;
  const xadUINT16 * pathsep;
  xadUINT8    addpathsep;
  xadUINT8    pad;
  xadUINT8    buffer[1];
};

#define PATHSIGN       '/'
#define PATHSIGNMAPPER '\\' /* maps the path sign if it represents no path */

//#ifndef NO_FILENAME_MANGLING
#if 0

/* converts string back to unicode */
/* NOTE: len is the character len and not byte len for unicode */
static xadERROR makestring(struct MyString *str, xadUINT32 charset,
const xadSTRING *buffer, xadUINT32 len)
{
  xadUINT16 i;
  const xadUINT16 *a;
  xadERROR err = 0;

  if(str->ucsize && str->addpathsep)
  {
    if(str->bufsize < 2)
      return XADERR_SHORTBUFFER;
    str->ucstring[str->ucsize++] = PATHSIGN;
    str->bufsize -= 2;
  }

  /* mainly table based stuff should be handled outside of this! */
  switch(charset)
  {
  case CHARSET_UNICODE_UCS2_HOST:
  case CHARSET_UNICODE_UCS2_BIGENDIAN:
    while(len && str->bufsize >= 2)
    {
      i = (buffer[0]<<8)+buffer[1];
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      buffer += 2;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_UNICODE_UCS2_LITTLEENDIAN:
    while(len && str->bufsize >= 2)
    {
      i = (buffer[1]<<8)+buffer[0];
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      buffer += 2;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_AMIGA:
  case CHARSET_ASCII:
  case CHARSET_ISO_8859_1:
    while(len && str->bufsize >= 2)
    {
      i = *(buffer++);
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_ISO_8859_15:
    while(len && str->bufsize >= 2)
    {
      i = *(buffer++);
      switch(i)
      {
      case 0xA4: i = 0x20AC; break; /* EURO SIGN */
      case 0xA6: i = 0x0160; break; /* LATIN CAPITAL LETTER S WITH CARON */
      case 0xA8: i = 0x0161; break; /* LATIN SMALL LETTER S WITH CARON */
      case 0xB4: i = 0x017D; break; /* LATIN CAPITAL LETTER Z WITH CARON */
      case 0xB8: i = 0x017E; break; /* LATIN SMALL LETTER Z WITH CARON */
      case 0xBC: i = 0x0152; break; /* LATIN CAPITAL LIGATURE OE */
      case 0xBD: i = 0x0153; break; /* LATIN SMALL LIGATURE OE */
      case 0xBE: i = 0x0178; break; /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
      }
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] == i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_UNICODE_UTF8:
    while(len && str->bufsize >= 2)
    {
      if(!(buffer[0] & 0x80)) i = *(buffer++);
      else if(((buffer[0]>>5) == 6) && ((buffer[1]>>6) == 2))
      {
        i = ((buffer[0]&0x1F)<<6)|(buffer[1]&0x3F);
        buffer += 2;
      }
      else if(((buffer[0]>>4) == 14) && ((buffer[1]>>6) == 2) && ((buffer[2]>>6) == 2))
      {
        i = ((buffer[0]&0xF)<<12)|((buffer[1]&0x3F)<<6)|(buffer[2]&0x3F);
        buffer += 3;
      }
      else
      {
        err = XADERR_ENCODING; break;
      }
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      if(!i)
        break;
      str->ucstring[str->ucsize++] == i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_MSDOS:
  case CHARSET_CODEPAGE_437:
    while(len && str->bufsize >= 2)
    {
      i = ibmcp437_to_unicode(*(buffer++));
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_MACOS:
    while(len && str->bufsize >= 2)
    {
      i = macroman_to_unicode(*(buffer++));
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_C64:
  case CHARSET_PETSCII_C64_LC:
    while(len && str->bufsize >= 2)
    {
      i = petsciilc_to_unicode(*(buffer++));
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_ATARI_ST:
  case CHARSET_ATARI_ST_US:
    while(len && str->bufsize >= 2)
    {
      i = atarist_to_unicode(*(buffer++));
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  case CHARSET_WINDOWS:
  case CHARSET_CODEPAGE_1252:
    while(len && str->bufsize >= 2)
    {
      i = windowscp1252_to_unicode(*(buffer++));
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  default: err = XADERR_NOTSUPPORTED; break;
  }

  if(len)
    err = XADERR_SHORTBUFFER;

  return err;
}

/*
- convert unicode to normal string
- sets unicode size to zero, if there is no need for a unicode representation
  (if the destination representation has no information loss)
- the string and ucstring entries maybe modified (e.g. for the unicode destination
  types)
There will not be that much supported destination types:
CHARSET_ASCII
CHARSET_ISO_8859_1
CHARSET_HOST
CHARSET_UNICODE_UCS2_HOST
CHARSET_UNICODE_UCS2_BIGENDIAN
CHARSET_UNICODE_UCS2_LITTLENDIAN
*/
static xadERROR makenormalstring(struct MyString *str, xadUINT32 charset)
{
  xadSTRING mchar = '_'; /* used for unconvertable, may get dynamic somewhen */
  xadINT32 i;
  xadERROR err = 0;
  xadBOOL  illg = XADFALSE;
  xadUINT16 a;

  for(i = 0; i < str->ucsize; ++i)
  {
    if(str->ucstring[i] >= 0xFFFE)
      break;
  }
  if(i != str->ucsize)
    illg = XADTRUE;

  switch(charset)
  {
  case CHARSET_ASCII:
    for(i = 0; i < str->ucsize && str->bufsize; ++i)
    {
      a = unicode_to_iso8859_1(str->ucstring[i], mchar);
      if(a > 0x7F)
      {
        /* handle exception conversion here */
        if(a >= 0x81 && a <= 0xA0) a -= 0x80;
        else if(a >= 0xC0 || a <= 0xC6) a = 'A';
        else if(a == 0xC7) a = 'C';
        else if(a >= 0xC8 && a <= 0xCB) a = 'E';
        else if(a >= 0xCC && a <= 0xCF) a = 'I';
        else if(a == 0xD0) a = 'D';
        else if(a == 0xD1) a = 'N';
        else if((a >= 0xD2 && a <= 0xD6) || a == 0xD8) a = 'O';
        else if(a >= 0xD9 && a <= 0xDC) a = 'U';
        else if(a == 0xDD) a = 'Y';
        else if(a >= 0xE0 && a <= 0xE6) a = 'a';
        else if(a == 0xE7) a = 'c';
        else if(a >= 0xE8 && a <= 0xEB) a = 'e';
        else if(a >= 0xEC && a <= 0xEF) a = 'i';
        else if(a == 0xF0) a = 'd';
        else if(a == 0xF1) a = 'n';
        else if((a >= 0xF2 && a <= 0xF6) || a == 0xF8) a = 'o';
        else if(a >= 0xF9 && a <= 0xFC) a = 'u';
        else if(a == 0xFD) a = 'y';
        else a = mchar; /* the default */
      }
      str->string[str->size++] = a;
    }
    if(i < str->ucsize)
      err = XADERR_SHORTBUFFER;
    break;
  case CHARSET_ISO_8859_1:
    for(i = 0; i < str->ucsize && str->bufsize; ++i)
      str->string[str->size++] = unicode_to_iso8859_1(str->ucstring[i], mchar);
    if(i < str->ucsize)
      err = XADERR_SHORTBUFFER;
    break;
  case CHARSET_HOST:
    for(i = 0; i < str->ucsize && str->bufsize; ++i)
    {
      a = unicode_to_iso8859_1(str->ucstring[i], mchar);
      if(a <= 0x1F || (a >= 0x7F && a <= 0x9F))
        a = mchar;
      str->string[str->size++] = a;
    }
    if(i < str->ucsize)
      err = XADERR_SHORTBUFFER;
    break;
  case CHARSET_UNICODE_UCS2_LITTLEENDIAN:
    if(illg)
    {
      for(i = 0; i < str->ucsize && str->bufsize > 1; ++i)
      {
        a = str->ucstring[i];
        if(a >= 0xFFFE)
          a = mchar;
        str->string[str->size++] = a;
        str->string[str->size++] = a>>8;
      }
      if(i < str->ucsize)
        err = XADERR_SHORTBUFFER;
    }
    else
    {
      /* this easy way only works for 16 bit unsigned types */
      for(i = 0; i < str->ucsize; ++i)
        str->ucstring[i] = (str->ucstring[i]>>8)|(str->ucstring[i]<<8);
      str->size = str->ucsize*sizeof(xadUINT16);
      str->string = (xadSTRPTR) str->ucstring;
      str->ucsize = 0;
    }
    break;
  case CHARSET_UNICODE_UCS2_HOST:
  case CHARSET_UNICODE_UCS2_BIGENDIAN:
    if(illg)
    {
      for(i = 0; i < str->ucsize && str->bufsize > 1; ++i)
      {
        a = str->ucstring[i];
        if(a >= 0xFFFE)
          a = mchar;
        str->string[str->size++] = a>>8;
        str->string[str->size++] = a;
      }
      if(i < str->ucsize)
        err = XADERR_SHORTBUFFER;
    }
    else
    {
      str->size = str->ucsize*sizeof(xadUINT16);
      str->string = (xadSTRPTR) str->ucstring;
      str->ucsize = 0;
    }
    break;
  default: err = XADERR_NOTSUPPORTED; break;
  }
  return err;
}

/* if negative it is an XAD error code */
static xadINT32 getlen(const xadUINT8 *str, xadUINT32 charset, xadUINT32 maxlen)
{
  xadINT32 len = 0;

  if(charset >= CHARSET_UNICODE_UCS2_HOST && charset <= CHARSET_UNICODE_UCS2_LITTLEENDIAN)
  {
    while((str[0] || str[1]) && len < maxlen)
    {
      ++len;
      str += 2;
    }
  }
  else if(charset == CHARSET_UNICODE_UTF8)
  {
    while(*str && len < maxlen)
    {
      if(!(*str & 0x80)) ++str;
      else if(((str[0]>>5) == 6) && ((str[1]>>6) == 2)) str += 2;
      else if(((str[0]>>4) == 14) && ((str[1]>>6) == 2) && ((str[2]>>6) == 2)) str += 3;
      else
        return -XADERR_ENCODING;
      ++len;
    }
  }
  else
  {
    while(*(str++) && len < maxlen)
      ++len;
  }
  return len;
}

#else

static xadERROR makestring(struct MyString *str, xadUINT32 charset,
const xadSTRING *buffer, xadUINT32 len)
{
  xadUINT16 i;
  const xadUINT16 *a;
  xadERROR err = 0;

  if(str->ucsize && str->addpathsep)
  {
    if(str->bufsize < 2)
      return XADERR_SHORTBUFFER;
    str->ucstring[str->ucsize++] = PATHSIGN;
    str->bufsize -= 2;
  }

  switch(charset)
  {
  case CHARSET_UNICODE_UCS2_HOST:
    while(len && str->bufsize >= 2)
    {
//      i = (buffer[0]<<8)+buffer[1];
      i = *((xadUINT16 *)buffer);
      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;
      str->ucstring[str->ucsize++] = i;
      buffer += 2;
      --len;
      str->bufsize -= 2;
    }
    break;
  default:
    while(len && str->bufsize >= 2)
    {
      i = *(buffer++);
/*      for(a = str->pathsep; *a && i != *a; ++a)
        ;
      if(*a) i = PATHSIGN;
      else if(i == PATHSIGN) i = PATHSIGNMAPPER;*/
      str->ucstring[str->ucsize++] = i;
      --len;
      str->bufsize -= 2;
    }
    break;
  }

  if(len)
    err = XADERR_SHORTBUFFER;

  return err;
}

static xadERROR makenormalstring(struct MyString *str, xadUINT32 charset)
{
  xadINT32 i;
  xadERROR err = 0;
  //xadUINT16 a;

  for(i = 0; i < str->ucsize && str->bufsize; ++i)
    str->string[str->size++] = str->ucstring[i];
  if(i < str->ucsize)
    err = XADERR_SHORTBUFFER;

  return err;
}

static xadINT32 getlen(const xadUINT8 *str, xadUINT32 charset, xadUINT32 maxlen)
{
  xadINT32 len = 0;

  while(*(str++) && len < maxlen)
    ++len;

  return len;
}


#endif

struct xadStringEnd {
  xadUINT16 xse_Charset;
  xadUINT16 xse_StringSize;  /* including zero byte */
  xadUINT16 xse_UnicodeSize; /* including zero bytes */
};
/* design of xadString block!
  xadObject header
  normal string + zero byte -- offset: start + header size
  (pad byte to reach word alignment)
  (unicode string + zero bytes) -- offset: stringend - unicodesize
  xadStringEnd structure -- offset: blocksize - sizeof(struct xadStringEnd)
*/

/* this function does internally an xxx to Unicode conversion and later a
   conversion back to the required type. The path seperators are replaced
   by '/' in any case.
*/
FUNCxadConvertName /* xadUINT32 charset, xadTAGPTR tags */
{
  xadERROR *errcode = 0, err = 0;
  xadUINT32 cset = CHARSET_ISO_8859_1, len = 1;
  xadINT32 i;
  xadUINT32 strs = 0xFFFFFFFF;
  xadSTRPTR str;
  struct xadObject *obj;
  struct xadStringEnd *se;
  xadTAGPTR ti, ti2 = tags;
  struct MyString *mystr;

#ifdef DEBUG
  DebugTagList("xadConvertName(%ld)", tags, charset);
#endif

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_CHARACTERSET: cset = ti->ti_Data; break;
    case XAD_ERRORCODE: errcode = (xadERROR *)(uintptr_t) ti->ti_Data; break;
    case XAD_STRINGSIZE: if(!(strs = ti->ti_Data)) strs = 0xFFFFFFFF; break;
    case XAD_XADSTRING:
      if(ti->ti_Data)
      {
        obj = ((struct xadObject *)(uintptr_t)ti->ti_Data)-1;
        se = ((struct xadStringEnd *)(((xadSTRPTR)obj)+obj->xo_Size))-1;
        len += (se->xse_UnicodeSize ? se->xse_UnicodeSize
        : se->xse_StringSize)-1+1;
      }
      strs = 0xFFFFFFFF;
      break;
    case XAD_PSTRING:
      if(ti->ti_Data)
      {
        len += 1 + ((xadSTRPTR)(uintptr_t) ti->ti_Data)[0];
      }
      strs = 0xFFFFFFFF;
      break;
    case XAD_CSTRING:
      if(ti->ti_Data)
      {
        ++len;
        if((i = getlen((xadUINT8 *)(uintptr_t)ti->ti_Data, cset, strs)) < 0)
          err = -i;
        else
          len += i;
      }
      strs = 0xFFFFFFFF;
      break;
    }
  }
  /* len now has the required maximum string size */
  /* buffer is 2*len for UNICODE and 2*len for final string */
  /* The final string is allocated later, as this depends on the fact
     if unicode part is really required! */
  obj = 0;
  len = len*(sizeof(xadUINT16)+2)+10;
  if((mystr = (struct MyString *) xadAllocVec(XADM sizeof(struct MyString)-1+len,
  XADMEMF_CLEAR)))
  {
    static const xadUINT16 psep[3] = {'/','\\',0};
    /* assumes 3 elements, fix the XAD_PATHSEPERATOR line if more elements
       are used */
    cset = CHARSET_ISO_8859_1;
    mystr->ucstring = (xadUINT16 *)mystr->buffer;
    mystr->bufsize = len;
    /* mystr->size = mystr->ucsize = 0; */
    mystr->pathsep = psep;
    mystr->addpathsep = XADTRUE;

    ti2 = tags;
    strs = 0xFFFFFFFF;
    while(!err && (ti = NextTagItem(&ti2)))
    {
      switch(ti->ti_Tag)
      {
      case XAD_STRINGSIZE: if(!(strs = ti->ti_Data)) strs = 0xFFFFFFFF; break;
      case XAD_ADDPATHSEPERATOR:
        mystr->addpathsep = ti->ti_Data ? XADTRUE : XADFALSE; break;
      case XAD_PATHSEPERATOR:
        mystr->pathsep = ti->ti_Data ? (const xadUINT16 *)(uintptr_t) ti->ti_Data
        : psep+2; break;
      case XAD_CHARACTERSET: cset = ti->ti_Data; break;
      case XAD_XADSTRING:
        if(ti->ti_Data)
        {
          obj = ((struct xadObject *)(uintptr_t)ti->ti_Data)-1;
          se = ((struct xadStringEnd *)(((xadSTRPTR)obj)+obj->xo_Size))-1;
          if(se->xse_UnicodeSize)
            err = makestring(mystr, CHARSET_UNICODE_UCS2_HOST,
            (xadSTRPTR)(((xadUINT16 *)se)
            -se->xse_UnicodeSize), strs < se->xse_UnicodeSize-1 ? strs :
            se->xse_UnicodeSize-1);
          else
            err = makestring(mystr, se->xse_Charset, (xadSTRPTR)(uintptr_t) ti->ti_Data,
            strs < se->xse_StringSize-1 ? strs : se->xse_StringSize-1);
        }
        strs = 0xFFFFFFFF;
        break;
      case XAD_PSTRING:
        if(ti->ti_Data)
        {
          str = (xadSTRPTR)(uintptr_t) ti->ti_Data;
          err = makestring(mystr, cset, str+1, strs < str[0] ? strs : str[0]);
        }
        strs = 0xFFFFFFFF;
        break;
      case XAD_CSTRING:
        if(ti->ti_Data)
        {
          str = (xadSTRPTR)(uintptr_t) ti->ti_Data;
          if((i = getlen((xadUINT8 *)str, cset, strs)) < 0)
            err = -i;
          else
            err = makestring(mystr, cset, str, i);
        }
        strs = 0xFFFFFFFF;
        break;
      }
    }
    obj = 0;

    if(!err)
    {
      mystr->string = (xadSTRPTR) (mystr->ucstring+mystr->ucsize);
      if(!(err = makenormalstring(mystr, charset)))
      {
        len = (mystr->ucsize?(mystr->ucsize+1)*sizeof(xadUINT16):0);
        if(charset >= CHARSET_UNICODE_UCS2_HOST && charset <= CHARSET_UNICODE_UCS2_LITTLEENDIAN)
          len += mystr->size+2;
        else
          len += ((mystr->size+1+1)&~(1));
        if((obj = (struct xadObject *) xadAllocVec(XADM sizeof(struct xadStringEnd)+
        len, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
        {
          xadUINT16 *uc;
          se = (struct xadStringEnd *)(((xadSTRPTR)obj)+len);
          se->xse_Charset = charset;
          se->xse_StringSize = mystr->size+1;
          se->xse_UnicodeSize = mystr->ucsize ? mystr->ucsize+1 : 0;
          str = (xadSTRPTR) obj;
          for(len = 0; len < mystr->size; ++len) /* copy normal string */
            str[len] = mystr->string[len];
          /* str[len] = 0; */
          uc = ((xadUINT16 *)se)-se->xse_UnicodeSize;
          for(len = 0; len < mystr->ucsize; ++len) /* copy unicode string */
            uc[len] = mystr->ucstring[len];
          (obj-1)->xo_Type = XADOBJ_STRING;
#ifdef DEBUG
  DebugOther("xadConvertName: res = $%08lx, size = %ld, ucsize  = %ld", obj,
  se->xse_StringSize, se->xse_UnicodeSize);
  if(se->xse_UnicodeSize)
  {
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUESTART, "xadConvertName: UnicodeString = '");
    for(i = 0; i < se->xse_UnicodeSize-1; ++i)
      DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUE, uc[i] <= 0xFF && ((uc[i]&0x7F) >= 0x20) ? "%lc" : "[%lx]", uc[i]);
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUEEND, "'");
  }
  if(se->xse_Charset >= CHARSET_UNICODE_UCS2_HOST && se->xse_Charset <= CHARSET_UNICODE_UCS2_LITTLEENDIAN)
  {
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUESTART, "xadConvertName: UCString = '");
    uc = (xadUINT16 *) str;
    for(i = 0; i < se->xse_StringSize-2; i += 2)
      DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUE, uc[i] <= 0xFF && ((uc[i]&0x7F) >= 0x20) ? "%lc" : "[%lx]", uc[i]);
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUEEND, "'");
  }
  else
  {
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUESTART, "xadConvertName: String = '");
    for(i = 0; i < se->xse_StringSize-1; ++i)
      DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUE, (str[i]&0x7F) >= 0x20 ? "%lc" : "[%lx]", str[i]);
    DebugFlagged(DEBUGFLAG_OTHER|DEBUGFLAG_CONTINUEEND, "'");
  }
#endif
        }
        else
          err = XADERR_NOMEMORY;
      }
      xadFreeObjectA(XADM mystr, 0);
    }
  }
  else
    err = XADERR_NOMEMORY;

  if(errcode) *errcode = err;
  return (xadSTRPTR) obj;
}
ENDFUNC

static const xadUINT8 statmask[256/8] = {
0xFE,0xFF,0xFF,0xFF,0x2C,0x07,0x00,0x84,
0x00,0x00,0x00,0x28,0x00,0x00,0x00,0xD0,
0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

FUNCxadGetFilename /* xadUINT32 buffersize, xadSTRPTR buffer,
  const xadSTRING *path, const xadSTRING *name, xadTAGPTR tags */
{
  xadERROR ret = 0;
  xadUINT32 *reqbufsize = 0;
  xadTAGPTR ti, ti2 = tags;
  xadUINT8 mask[256/8];
  xadSTRING maskchar = '_';
  xadBOOL nopath = XADFALSE, notrailingpath = XADFALSE;
  xadINT32 i, psize, nsize;

#ifdef DEBUG
  DebugTagList("xadGetFilenameA(%ld,$%08lx,'%s','%s')", tags, buffersize, buffer, path, name);
#endif

  xadCopyMem(XADM_PRIV (xadPTR) statmask, mask, sizeof(mask));

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_NOLEADINGPATH: nopath = ti->ti_Data ? XADTRUE : XADFALSE; break;
    case XAD_NOTRAILINGPATH: notrailingpath = ti->ti_Data
      ? XADTRUE : XADFALSE; break;
    case XAD_MASKCHARACTERS:
      {
        const xadSTRING *mm = (xadSTRPTR)(uintptr_t) ti->ti_Data;
        for(i = 0; i < 256/8; ++i)
          mask[i] = 0;
        while(mm && *mm)
        {
          mask[(*mm)>>3] |= (1<<((*mm)&7));
          ++mm;
        }
      }
      break;
    case XAD_MASKINGCHAR: maskchar = ti->ti_Data; break;
    case XAD_REQUIREDBUFFERSIZE: reqbufsize = (xadUINT32 *)(uintptr_t) ti->ti_Data; break;
    }
  }
  if(nopath)
  { /* skip .., . and / from path */
    for(;path[0];)
    {
      if(path[0] == PATHSIGN) ++path;
      else if(path[0] == '.')
      {
        if(!path[1] || path[1] == PATHSIGN ) path +=2;
        else if(path[1] == '.' && (!path[2] || path[2] == PATHSIGN)) path += 3;
      }
      else
        break;
    }
  }
  if(*path || nopath) /* only do if there is a previous path or nopath is given */
  { /* skip .., . and / from name */
    for(;name[0];)
    {
      if(name[0] == PATHSIGN) ++name;
      else if(name[0] == '.')
      {
        if(!name[1] || name[1] == PATHSIGN ) name +=2;
        else if(name[1] == '.' && (!name[2] || name[2] == PATHSIGN)) name += 3;
      }
      else
        break;
    }
  }
  psize = strlen((const char *)path);
  nsize = strlen((const char *)name);
  if(nsize || notrailingpath)
    while(psize && path[psize-1] == PATHSIGN) --psize;
  if(notrailingpath)
    while(nsize && name[nsize-1] == PATHSIGN) --nsize;
  i = psize + nsize + (psize && nsize ? 1 : 0);
  if((unsigned)i >= buffersize) ret = XADERR_SHORTBUFFER;
  if(reqbufsize) *reqbufsize = i+1;
  if(buffer)
  {
    buffer[((unsigned)i >= buffersize) ? buffersize-1 : (unsigned)i] = 0;
    --buffersize; /* the zero byte */
    i = (psize && nsize) ? 1 : 0; /* slash indicator */
    while(buffersize && psize)
    {
      *(buffer++) = (mask[(*path)>>3]&(1<<((*path)&3)) ? maskchar : *path);
      --buffersize; --psize; ++path;
    }
    if(buffersize && i)
    {
      *(buffer++) = PATHSIGN; --buffersize;
    }
    while(buffersize && nsize)
    {
      *(buffer++) = (mask[(*name)>>3]&(1<<((*name)&3)) ? maskchar : *name);
      --buffersize; --nsize; ++name;
    }
  }
  return ret;
}
ENDFUNC

FUNCxadGetDefaultName /* xadTAGPTR tags */
{
  xadTAGPTR ti, ti2 = tags;
  const struct xadArchiveInfo *ai = 0;
  xadERROR *errcode = 0;

#ifdef DEBUG
  DebugTagList("xadGetDefaultNameA()", tags);
#endif

  while((ti = NextTagItem(&ti2)))
  {
    switch(ti->ti_Tag)
    {
    case XAD_ARCHIVEINFO: ai = (struct xadArchiveInfo *)(uintptr_t) ti->ti_Data; break;
    case XAD_ERRORCODE: errcode = (xadERROR *)(uintptr_t) ti->ti_Data; break;
    }
  }

  if(!ai || !ai->xai_InName)
  {
    return xadConvertName(XADM CHARSET_HOST, XAD_CSTRING,
    xadMasterBase->xmb_DefaultName, errcode ? XAD_ERRORCODE : TAG_IGNORE,
    errcode, TAG_DONE);
  }
  else
  {
    xadUINT32 namesize, extsize;
    const xadSTRING *ext;

    namesize = strlen((const char *)ai->xai_InName);
    ti2 = tags;
    while((ti = NextTagItem(&ti2)))
    {
      if(ti->ti_Tag == XAD_EXTENSION)
      {
        ext = (xadSTRPTR)(uintptr_t) ti->ti_Data;
        for(extsize = 0; ext[extsize] && ext[extsize] != ';'; ++extsize)
          ;
        if(extsize < namesize && !strnicmp(ai->xai_InName+namesize-extsize,
        ext, extsize))
        { /* found */
          return xadConvertName(XADM CHARSET_HOST, errcode ?
          XAD_ERRORCODE : TAG_IGNORE, errcode, XAD_STRINGSIZE,
          namesize-extsize, XAD_CSTRING, ai->xai_InName,
          ext[extsize] != ';' ? TAG_DONE :
          XAD_ADDPATHSEPERATOR, XADFALSE, XAD_STRINGSIZE, 0,
          XAD_CSTRING, ext+extsize+1, TAG_DONE);
        }
      }
    }
  }
  return xadConvertName(XADM CHARSET_HOST, errcode ?
  XAD_ERRORCODE : TAG_IGNORE, errcode, XAD_CSTRING, ai->xai_InName,
  TAG_DONE);
}
ENDFUNC

#endif  /* XADMASTER_FILENAME_C */
