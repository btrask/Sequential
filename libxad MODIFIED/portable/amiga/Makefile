#   $Id: Makefile,v 1.2 2005/06/23 14:54:40 stoecker Exp $
#   makefile for GCC
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

ODIR = 

LDIR = ../
CDIR = $(LDIR)clients/
IDIR = $(LDIR)include/
ADIR = $(LDIR)amiga/

INCOPT= -I$(IDIR) -I$(CDIR) -I$(ADIR) -I../../amiga/include/C

CCOPT = -c $(INCOPT) -O2 -noixemul -fomit-frame-pointer -DNO_INLINE_STDARG
LNLIB = -lamiga
LNOPT = -nostartfiles -noixemul
CCTO  = -o
CC    = gcc
STRIP = strip

HFILES   = \
	$(IDIR)ConvertE.c \
	$(IDIR)functions.h \
	$(IDIR)privdefs.h \
	$(IDIR)version.h \
	$(IDIR)xadmaster.h

CFILES = \
	$(CDIR)Ace.c \
	$(CDIR)AMPK.c \
	$(CDIR)bzip2.c \
	$(CDIR)CAB.c \
	$(CDIR)Cpio.c \
	$(CDIR)CrunchDisk.c \
	$(CDIR)DMS.c \
	$(CDIR)DCS.c \
	$(CDIR)IFF-CDAF.c \
	$(CDIR)FS_Amiga.c \
        $(CDIR)FS_FAT.c \
        $(CDIR)FS_SOS.c \
        $(CDIR)LhA.c \
	$(CDIR)LhF.c \
	$(CDIR)LZX.c \
	$(CDIR)MDC.c \
	$(CDIR)MXM-SimpleArc.c \
	$(CDIR)PackDev.c \
	$(CDIR)PackDisk.c \
	$(CDIR)RPM.c \
	$(CDIR)StuffIt.c \
	$(CDIR)SuperDuper3.c \
	$(CDIR)Tar.c \
	$(CDIR)xDisk.c \
	$(CDIR)xMash.c \
	$(CDIR)Zip.c \
	$(CDIR)Zoom.c \
	$(CDIR)xadIO_Compress.c \
	$(CDIR)xadIO_XPK.c \
	$(CDIR)xadIO.h \
	$(CDIR)xadIO.c

CHARSET = \
	$(LDIR)cs_atarist_to_unicode.c \
	$(LDIR)cs_c64_to_unicode.c \
	$(LDIR)cs_ibmcp437_to_unicode.c \
	$(LDIR)cs_macroman_to_unicode.c \
	$(LDIR)cs_unicode_to_iso8859-1.c \
	$(LDIR)cs_windowscp1252_to_unicod.c

FILES = $(LDIR)all.c \
	$(LDIR)clientfunc.c \
	$(LDIR)copymem.c \
	$(LDIR)crc.c \
	$(LDIR)dates.c \
	$(LDIR)diskfile.c \
	$(LDIR)diskunarc.c \
        $(LDIR)error.c \
        $(LDIR)filename.c \
        $(LDIR)fileunarc.c \
        $(LDIR)hook.c \
        $(ADIR)hook_disk.c \
        $(LDIR)hook_diskarc.c \
        $(ADIR)hook_fh.c \
        $(LDIR)hook_mem.c \
        $(LDIR)hook_splitted.c \
        $(LDIR)hook_stream.c \
        $(LDIR)info.c \
        $(LDIR)objects.c \
        $(LDIR)protection.c \
	$(HFILES) $(CHARSET)

DEF:	LIB
LIB:    $(ODIR)xadmaster.library

# ******* object files *******

$(ODIR)libinit.o: $(HFILES) $(ADIR)libinit.c
	$(CC) $(ADIR)libinit.c $(CCOPT) $(CCTO) $@

$(ODIR)all.o: $(FILES)
	$(CC) $(LDIR)all.c $(CCOPT) $(CCTO) $@

$(ODIR)clients.o: $(HFILES) $(LDIR)clients.c $(CFILES)
	$(CC) $(LDIR)clients.c $(CCOPT) $(CCTO) $@

$(ODIR)stubs.o: stubs.c
	$(CC) stubs.c $(CCOPT) $(CCTO) $@

# ******* libraries creation *******

OBJS = $(ODIR)libinit.o $(ODIR)all.o $(ODIR)stubs.o $(ODIR)clients.o

$(ODIR)xadmaster.library: $(OBJS)
	$(CC) $(LNOPT) $(CCTO) $@ $(OBJS) $(LNLIB)
