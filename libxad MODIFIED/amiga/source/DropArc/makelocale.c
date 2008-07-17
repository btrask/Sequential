#define NAME         "makelocale"
#define VERSION      "1"
#define REVISION     "0"
#define DATE         "09.03.2002"
#define DISTRIBUTION "(LGPL) "
#define AUTHOR       "by Dirk Stöcker <soft@dstoecker.de>"

/*  $Id: makelocale.c,v 1.2 2005/06/23 15:47:24 stoecker Exp $
    handles locale stuff of code

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

/* ToDo: Allow multiline texts */

/* This tool mainly allows mapping gettext string based methods to locale.library
ID based method. */

#define version "$VER: " NAME " " VERSION "." REVISION " (" DATE ") " DISTRIBUTION AUTHOR
#define MAXTEXTS 1000

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *mytexts[MAXTEXTS];
int mysizes[MAXTEXTS];
int maxnum = 0, fail = 0, warn = 0, err = 0;

int getnum(char *txt, int num, int size)
{
  int i;

  for(i = 1; i <= maxnum && (mysizes[i] != size ||
  strncmp(txt, mytexts[i], size)); ++i)
    ;

  if(num)
  {
    if(i > maxnum)
    {
      if(num >= i) i = num;
      else if(!mytexts[num]) i = num;
      else { fprintf(stderr, "Double use of ID %d for '%.*s'.\n", num, size, txt); ++warn; }
    }
    else if(i != num)
    { fprintf(stderr, "Mixed ID found for '%.*s'.\n", size, txt); ++warn; }
  }
  if(i > MAXTEXTS)
  {
    fprintf(stderr, "Maximum ID's exceeded.\n");
    ++err;
    i = 0;
  }

  mytexts[i] = txt;
  mysizes[i] = size;
  if(i > maxnum) maxnum = i;
  return i;
}

void parsebuf(char *buf, int bufsize, int print)
{
  char *txt, *t;
  int size, num;

  while(bufsize > 7)
  {
    txt = buf;
    while(bufsize > 7 && (*buf != 'T' || buf[1] != 'X'
    || buf[2] != 'T' || buf[3] != '('/*)*/ || buf[4] != '"'))
    { ++buf; --bufsize; }
    if(bufsize > 7) { buf += 5; bufsize -= 5; }
    else { buf += bufsize; bufsize = 0; }

    if(print) fwrite(txt, buf-txt, 1, stdout);

    txt = buf;
    while(bufsize && *buf != '"')
    { ++buf; --bufsize; }
    if(bufsize >= 2 && *buf == '"')
    {
      size = buf-txt;
      ++buf; --bufsize;
      if(print) fwrite(txt, buf-txt, 1, stdout);
      if(*buf == ',')
      {
        num = strtol(buf+1, &t, 10);
        if(t && t < buf+bufsize)
        {
          bufsize -= (t-buf);
          buf = t;
        }
      }
      else
        num = 0;
      if(*buf == /*(*/')')
      {
        num = getnum(txt, num, size);
        if(print)
          fprintf(stdout, /*(*/",%d)", num);
        ++buf; --bufsize;
      }
      else if(print)
        fwrite(txt, buf-txt, 1, stdout);
    }
    else if(print)
      fwrite(txt, buf-txt, 1, stdout);
    
  }
  if(print && bufsize)
    fwrite(buf, bufsize, 1, stdout);
}

char *dofile(char *name, int print)
{
  long bufsize;
  char *buf = 0;
  FILE *fh;

  if((fh = fopen(name, "r")))
  {
    if(!fseek(fh, 0, SEEK_END))
    {
      if((bufsize = ftell(fh)) != EOF)
      {
        if(!fseek(fh, 0, SEEK_SET))
        {
          if((buf = malloc(bufsize)))
          {
            if((bufsize = fread(buf, 1, bufsize, fh)) > 0)
            {
              parsebuf(buf, bufsize, print);
            }
          }
        }
      }
    }
    fclose(fh);
  }
  return buf;
}

int main(int argc, char **argv)
{
  FILE *fh;
  char *locfile, *buf1, *buf2;
  int i;

  if(argc > 4 || argc < 2)
  {
    fprintf(stderr, "makelocale <file> [<localefile>]\n");
    return 20;
  }
  locfile = (argc >= 3 ? argv[2] : "locale.c");
  if(!(buf1 = dofile(locfile, 0)))
  {
    fprintf(stderr, "Could not parse localefile %s.\n", locfile);
    ++err;
  }
  
  if(!(buf2 = dofile(argv[1], 1)))
  {
    free(buf1);
    fprintf(stderr, "Could not parse %s.\n", argv[1]);
    return 20;
  }

  if((fh = fopen(locfile, "w")))
  {
    fprintf(fh, "#define TXT(a,b) a\n\nconst int MaxNumMyTexts = %d;"
    "\n\nchar *MyTexts[] = {\n0,\n"/*}*/, maxnum);
    for(i = 1; i <= maxnum; ++i)
    {
      if(!mytexts[i]) fprintf(fh, "0%s\n", i == maxnum ? "" : ",");
      else
      {
        fprintf(fh, "TXT(\"%.*s\",%d)%s\n", mysizes[i], mytexts[i], i,
        i == maxnum ? "" : ",");
      }
    }

    fprintf(fh, /*{*/"};\n");
    fclose(fh);
  }
  else
  {
    fprintf(stderr, "Could not create localefile.\n"); ++err;
  }
  if(argc == 4)
  {
    if((fh = fopen(argv[3], "w")))
    {
      for(i = 1; i <= maxnum; ++i)
      {
        if(mytexts[i])
        {
          char data[51];
          int j, k, skip, t;
          char c, *d;

          d = mytexts[i];
          for(j = k = 0; j < mysizes[i] && k < 50; ++j)
          {
            skip = 0;
            c = d[j];
            /* the exceptions, handle format strings, ... */
            if(c == '\\')
            {
              if(d[j+1] == 'n' || d[j+1] == 't' || d[j+1] == 'r')
                skip = 2;
            }
            else if(c == '%')
            {
              t = j+1;
              while(d[t] >= '0' && d[t] <= '9') ++t;
              if(d[t] == 'l') ++t;
              if(d[t] == 'd' || d[t] == 'u' || d[t] == 's' || d[t] == 'x')
                skip = t+1-j;
            }
            c = toupper(c);
            if(!skip && ((c >= 'A' && c <= 'Z') || (c >= 0 && c <= 1)))
              data[k++] = c;
            else if(!k || data[k-1] != '_')
              data[k++] = '_';
            if(skip)
              j += skip-1;
          }
          if(data[k-1] == '_') --k;
          data[k] = 0;
          fprintf(fh, "TXT%04d_%s (%d//)\n%.*s\n", i, data, i, mysizes[i], mytexts[i]);
        }
      }
      fclose(fh);
    }
    else
    {
      fprintf(stderr, "Could not open catalog file %s.\n", argv[3]); ++err;
    }
  }
  free(buf1);
  free(buf2);
  return fail ? 20 : err ? 10 : warn ? 5 : 0;
}
