#   $Id: makefile,v 1.3 2005/06/23 15:47:24 stoecker Exp $
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

ODIR = obj/gcc/

LDIR = ../../portable/
CDIR = $(LDIR)clients/
INCOPT= -Iinclude -I../include/C -I. -I$(LDIR) -I$(CDIR)

CCOPT = -c $(INCOPT) -O2 -noixemul -fomit-frame-pointer
LNOPT = -nostartfiles -noixemul
CCTO  = -o
CC    = gcc
STRIP = strip

CCOPTMOS = -DSDI_MORPHOSNOREG -c $(INCOPT) -I$(LDIR)morphos -I$(LDIR)amiga -O2 -noixemul -fomit-frame-pointer -mmultiple -mcpu=603e -DUSE_INLINE_STDARG
LNOPTMOS = -nostartfiles -noixemul

INCFILES = version.h ../include/C/libraries/xadmaster.h
HFILES   = functions.h privdefs.h $(INCFILES)

CFILES = clients/Ace.c clients/AMPK.c clients/Cpio.c clients/CrunchDisk.c \
        clients/DMS.c clients/DCS.c clients/IFF-CDAF.c clients/FS_Amiga.c \
        clients/FS_FAT.c clients/FS_SOS.c clients/LhA.c \
	clients/LhF.c clients/MDC.c clients/MXM-SimpleArc.c \
	clients/PackDev.c clients/PackDisk.c $(CDIR)SuperDuper3.c \
	$(CDIR)Tar.c clients/xDisk.c clients/xMash.c $(CDIR)Zip.c \
	$(CDIR)ConvertE.c $(CDIR)xadIO_XPK.c $(CDIR)xadIO.h $(CDIR)xadIO.c \
	clients/LZX.c clients/StuffIt.c clients/Zoom.c

CHARSET = $(LDIR)cs_atarist_to_unicode.c $(LDIR)cs_c64_to_unicode.c $(LDIR)cs_ibmcp437_to_unicode.c \
	$(LDIR)cs_macroman_to_unicode.c $(LDIR)cs_unicode_to_iso8859-1.c $(LDIR)cs_windowscp1252_to_unicod.c

FILES = $(LDIR)all.c $(LDIR)clientfunc.c $(LDIR)copymem.c $(LDIR)crc.c dates.c $(LDIR)diskfile.c $(LDIR)diskunarc.c \
        $(LDIR)error.c $(LDIR)filename.c $(LDIR)fileunarc.c $(LDIR)hook.c hook_disk.c hook_diskarc.c \
        hook_fh.c hook_mem.c hook_splitted.c hook_stream.c $(LDIR)info.c objects.c \
        $(LDIR)protection.c \
	$(HFILES) $(CHARSET)

DEF:	obj/gcc MOS #68K
68K:    $(ODIR)xadmaster.library
MOS:    $(ODIR)xadmaster.libraryMOS

obj/gcc:
	-@mkdir -p obj/gcc

# ******* object files *******

$(ODIR)libinit.o: $(LDIR)amiga/protodefs.h $(HFILES) libinit.c
	$(CC) libinit.c $(CCOPT) $(CCTO) $@

$(ODIR)clients.o: $(INCFILES) clients.c $(CFILES)
	$(CC) clients.c $(CCOPT) $(CCTO) $@

$(ODIR)all.o: $(FILES) $(LDIR)amiga/protodefs.h
	$(CC) $(LDIR)all.c $(CCOPT) $(CCTO) $@

# ******* libraries creation *******

$(ODIR)xadmaster.library: $(ODIR)libinit.o $(ODIR)all.o $(ODIR)clients.o
	$(CC) $(CCTO) $@ $(ODIR)libinit.o $(ODIR)all.o $(ODIR)clients.o $(LNOPT)

# ***********************
# ******* MorphOS *******
# ***********************

# ******* object files MorphOS *******

$(ODIR)libinitMOS.o: $(LDIR)morphos/protodefs.h $(HFILES) libinit.c
	$(CC) libinit.c $(CCOPTMOS) $(CCTO) $@

$(ODIR)clientsMOS.o: $(INCFILES) clients.c $(CFILES)
	$(CC) clients.c $(CCOPTMOS) $(CCTO) $@

$(ODIR)allMOS.o: $(FILES) $(LDIR)morphos/protodefs.h
	$(CC) $(LDIR)all.c $(CCOPTMOS) $(CCTO) $@

# ******* libraries creation MorphOS *******

$(ODIR)xadmaster.libraryMOS: $(ODIR)libinitMOS.o $(ODIR)allMOS.o $(ODIR)clientsMOS.o
	$(CC) $(CCTO) $@.db $(ODIR)libinitMOS.o $(ODIR)allMOS.o $(ODIR)clientsMOS.o $(LNOPTMOS)
	$(STRIP) -s -R .comment $@.db -o $@
