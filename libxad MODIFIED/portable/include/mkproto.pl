#!/usr/bin/perl -w
#
# Usage: perl mkproto.pl MODE TYPE functions.def <source >dest.h
# mode is one of EXTERNAL or INTERNAL
# type is one of AMIGA, AOS4 (AmigaOS4), MORPHOS, DIRECTMEMORY or VARARGS

#   $Id: mkproto.pl,v 1.15 2006/04/19 11:40:19 stoecker Exp $
#   script to add prototypes to include files
#
#   XAD library system for archive handling
#   Copyright (C) 1998 and later by Dirk Stöcker <soft@dstoecker.de>
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2.1 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
my $MODE = $ARGV[0];
die "$MODE invalid" unless ($MODE eq 'EXTERNAL') or ($MODE eq 'INTERNAL');
my $TYPE = $ARGV[1];
die "$TYPE invalid" unless ($TYPE eq 'AMIGA') or ($TYPE eq 'MORPHOS') or
  ($TYPE eq 'DIRECTMEMORY') or ($TYPE eq 'VARARGS') or ($TYPE eq 'AOS4');
open FUNCS, "<$ARGV[2]" or die "Can't open $ARGV[2] - $!";

# copy from stdin to stdout
my $inserted = 0;
my $amigamode = 0;
while (<STDIN>) {
  # if not a line with <INSERT>, just copy it verbatim
  # handle ifdef AMIGA sections as well and only copy the sections for
  # our current system
  if(/^.ifdef AMIGA/) {$amigamode = 1; next;}
  elsif(/^.ifndef AMIGA/) {$amigamode = 2; next;}
  elsif(/^.else .. AMIGA ../) {$amigamode = 2; next;}
  elsif(/^.endif .. AMIGA ../) {$amigamode = 0; next;}
  elsif($amigamode == 1 && !(($TYPE eq 'AMIGA') or ($TYPE eq 'AOS4') or ($TYPE eq 'MORPHOS')))
  { next; }
  elsif($amigamode == 2 && (($TYPE eq 'AMIGA') or ($TYPE eq 'AOS4') or ($TYPE eq 'MORPHOS')))
  { next }
  print unless /<INSERT>/ and not $inserted;
  next  unless /<INSERT>/ and not $inserted;
  $inserted = 1;

  # special case for Amiga/MorphOS external prototypes
  if (($MODE eq 'EXTERNAL') and (($TYPE eq 'AMIGA') or ($TYPE eq 'AOS4') or ($TYPE eq 'MORPHOS'))) {
    print "/* not needed -- include clib/xadmaster_protos.h */\n";
    next;
  }

  # otherwise, we insert all prototypes / functions
  print "/*** BEGIN auto-generated section ($MODE $TYPE) */\n";

  if ($MODE eq 'EXTERNAL') {
    # special headers for EXTERNAL
    print "extern struct xadMasterBase *xadOpenLibrary( xadINT32 version );\n";
    print "extern void xadCloseLibrary(struct xadMasterBase *);\n";
  }
  else {
    # special headers for INTERNAL
    if ($TYPE eq 'AMIGA') {
      print << 'EOF';
#include <proto/utility.h>
#define SDI_TO_ANSI
#include "SDI_ASM_STD_protos.h"
#include "SDI_compiler.h"
#ifdef NO_INLINE_STDARG
#include "stubs.h"
#endif

#define PROTOHOOK(name) \
  ASM(xadINT32) name( \
  REG(a0, struct Hook * hook), \
  REG(a2, struct xadArchiveInfoP *ai), \
  REG(a1, struct xadHookParam * param))

#define FUNCHOOK(name) PROTOHOOK(name) {

#define ENDFUNC }

EOF
    }

    if (($TYPE eq 'MORPHOS') || ($TYPE eq 'AOS4')) {
      print << 'EOF';
#include <proto/utility.h>
#include <proto/xadmaster.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

#define PROTOHOOK(name) \
  xadINT32 name( \
  struct Hook * hook, \
  struct xadArchiveInfoP *ai, \
  struct xadHookParam * param)

#define FUNCHOOK(name) PROTOHOOK(name) {

#define ENDFUNC }

EOF
    }

    if (($TYPE eq 'DIRECTMEMORY') or ($TYPE eq 'VARARGS')) {
      print << 'EOF';
#define PROTOHOOK(name) \
  xadINT32 name(struct Hook * hook, struct xadArchiveInfoP *ai, \
  struct xadHookParam * param)

#define FUNCHOOK(name) PROTOHOOK(name)

#define ENDFUNC

EOF
    }


    if ($TYPE eq 'VARARGS') {
      print <<'EOF';
#ifdef HAVE_STDARG_H
#  include <stdarg.h>
#endif
#define XAD_MAX_CONVTAGS (64)
#define XAD_CONVTAGS \
  struct TagItem convtags[XAD_MAX_CONVTAGS]; \
  va_list ap; int x = 0; \
  va_start(ap, tag); \
  convtags[0].ti_Tag = tag; \
  while (tag != TAG_DONE) { \
    convtags[x++].ti_Data = (xadSize) \
      ( (tag & TAG_PTR)  ? va_arg(ap, void *)  : \
	((tag & TAG_SIZ) ? va_arg(ap, xadSize) : \
	                   va_arg(ap, int))); \
    if (tag == TAG_MORE) break; \
    if (x >= XAD_MAX_CONVTAGS) { \
      convtags[XAD_MAX_CONVTAGS-1].ti_Tag = TAG_DONE; \
      break; \
    } \
    convtags[x].ti_Tag = tag = (xadTag) va_arg(ap, int); \
  } \
  va_end(ap);

EOF
    }
  }

  while (<FUNCS>) {
    next unless /^DEF/;
    s/xadArchiveInfoP/xadArchiveInfo/g if $MODE eq 'EXTERNAL';
    # split line in to ';' seperated fields
    chomp; my ($def, $flags, $name, $file, $ret, @args) = split /;/;

    # remove 'r=' from the return field
    $ret = substr $ret, 2;

    # $tag is true if the last argument is 'xadTAGPTR tags', otherwise false
    my $tag = (defined $args[$#args] and ($args[$#args] =~ /xadTAGPTR tags$/));

    # EXTERNAL prototypes, only DIRECTMEMORY and VARARGS
    if ($MODE eq 'EXTERNAL') {
      @args = map {substr $_, 3} @args; # remove all Amiga register names
      unshift @args, 'struct xadMasterBase *xadMasterBase'; # add lib base
      if ($tag) {
        pop @args; # remove tag argument
        print "extern $ret $name(".join(', ',(@args,'xadTag tag, ...')).");\n".
          "extern $ret ${name}A(".join(', ',(@args,'xadTAGPTR tags')).");\n";
      }
      else {
        print "extern $ret $name(".join(', ',@args).");\n";
      }
      next;
    }

    # INTERNAL prototypes
    if (($TYPE eq 'AMIGA') or ($TYPE eq 'AOS4') or ($TYPE eq 'MORPHOS')) {
      if ($TYPE eq 'AOS4') {
          unshift @args, 'a6=struct xadMasterIFace *IxadMaster';
      } 
      else {
          pop @args if $flags eq 'T';
          push @args, 'a6=struct xadMasterBaseP *xadMasterBase'
            unless $flags eq 'M';
      }
      
      my $tagA = ($tag ? 'A' : '');

      print "/* $name - $file */\n";
      my ($proto, $func);
      if ($TYPE eq 'AMIGA') {
        $proto = "ASM($ret) LIB$name$tagA(" .
          join(', ', map { sprintf 'REG(%s, %s)', split /=/ } @args) . ')';
        $func = '';
      }
      elsif ($TYPE eq 'AOS4') {
        $proto = "$ret LIB$name$tagA(" .
          join(', ', map { sprintf 'REG(%s, %s)', split /=/ } @args) . ')';
        $func = '';
      }
      else {
        $proto = "$ret LIB$name$tagA(void)";
        $func = " \\\n  " . join(" \\\n  ", map {
          my ($reg, $x) = split /=/;
          my @p = split /\b/, $x;
          my $type = join '', @p[0 .. ($#p-1)];
          my $var = $p[$#p];
          sprintf '%s%s = (%s) REG_%s;', $type, $var, $type, uc($reg)
        } @args);
      }
      print "$proto;\n#define FUNC$name $proto {$func";
      
      if ($TYPE eq 'AOS4') {
          print " \\\n  struct xadMasterBaseP *xadMasterBase = (struct xadMasterBaseP *) IxadMaster->Data.LibBase;\n";
      }
      else {
          print " \\\n  struct UtilityBase *UtilityBase = xadMasterBase->" .
            'xmb_UtilityBase;' if $tag and ($flags ne 'U') and ($flags ne 'T');
      }
      print "\n\n";
    }

    elsif (($TYPE eq 'DIRECTMEMORY') or ($TYPE eq 'VARARGS')) {
      @args = map {substr $_, 3} @args; # remove all Amiga register names
      unshift @args, 'struct xadMasterBaseP *xadMasterBase'; # add lib base

      if ($tag) {
        pop @args; # remove tag argument
        print "$ret $name(".join(', ',(@args,'xadTag tag, ...')).");\n".
          "$ret ${name}A(".join(', ',(@args,'xadTAGPTR tags')).");\n";

        # print tag function which calls tag array function,
        # then tag array function header
        my $tagp = ($TYPE eq 'VARARGS') ? '&convtags[0]' : '(xadTAGPTR) &tag';
        my $convtags = ($TYPE eq 'VARARGS') ? 'XAD_CONVTAGS ' : '';
        my $return = ($ret eq 'void') ? '' : 'return ';

        print "#define FUNC$name \\\n" .
          "  $ret $name( \\\n    " .
          join(", \\\n    ", (@args, 'xadTag tag, ...')) . ") \\\n" .
          "  { $convtags $return ${name}A(" .
          join(", ", ((map {/(\w+$)/||die; $1} @args), $tagp)) .
          "); } \\\n" .
          "  $ret ${name}A( \\\n    " .
          join(", \\\n    ", (@args, 'xadTAGPTR tags')) . ")\n\n";

      }
      else {
        print "$ret $name(".join(', ',@args).");\n";
        print "#define FUNC$name $ret $name(".join(', ',@args).")\n";
      }

    }
  }

  print "/*** END auto-generated section */\n";
}
