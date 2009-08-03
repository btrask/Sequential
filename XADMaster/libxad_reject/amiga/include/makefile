#   $Id: makefile,v 13.2 2005/06/23 15:47:23 stoecker Exp $
#   makefile to build the includes
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

PATH    = 
AUTHOR  = "Dirk Stöcker"
BASE    = xadmaster

SFDNAME = $(PATH)SFD/$(BASE)_lib.sfd
AMIGAEENAME = $(PATH)AmigaE/libraries/$(BASE).e

default: all

PRAGMAPATH = $(PATH)C/pragma/
PRAGMANAME = $(PRAGMAPATH)$(BASE)_lib.h
$(PRAGMANAME): $(SFDNAME)
	fd2pragma SPECIAL   6 INFILE $(SFDNAME) TO $(PRAGMAPATH)

AMIGAEPATH = $(PATH)AmigaE/
AMIGAENAME = $(AMIGAEPATH)$(BASE).m
$(AMIGAENAME): $(SFDNAME)
	fd2pragma SPECIAL  18 INFILE $(SFDNAME) TO $(AMIGAEPATH)

GCCINLINEPATH = $(PATH)C/inline/
GCCINLINENAME = $(GCCINLINEPATH)$(BASE).h
$(GCCINLINENAME): $(SFDNAME)
	fd2pragma SPECIAL  40 INFILE $(SFDNAME) TO $(GCCINLINEPATH)

PROTOPATH = $(PATH)C/proto/
PROTONAME = $(PROTOPATH)$(BASE).h
$(PROTONAME): $(SFDNAME)
	fd2pragma SPECIAL  38 INFILE $(SFDNAME) TO $(PROTOPATH)

VBCCINLINEPATH = $(PATH)C/inline/
VBCCINLINENAME = $(VBCCINLINEPATH)$(BASE)_protos.h
$(VBCCINLINENAME): $(SFDNAME)
	fd2pragma SPECIAL  70 INFILE $(SFDNAME) TO $(VBCCINLINEPATH)

LVOPATH = $(PATH)ASM/lvo/
LVONAME = $(LVOPATH)$(BASE)_lib.i
$(LVONAME): $(SFDNAME)
	fd2pragma SPECIAL  23 INFILE $(SFDNAME) TO $(LVOPATH)

FDPATH = $(PATH)FD/
FDNAME = $(FDPATH)$(BASE)_lib.fd
$(FDNAME): $(SFDNAME)
	fd2pragma SPECIAL 110 INFILE $(SFDNAME) TO $(FDPATH) COMMENT

CLIBPATH = $(PATH)C/clib/
CLIBNAME = $(CLIBPATH)$(BASE)_protos.h
$(CLIBNAME): $(SFDNAME)
	fd2pragma SPECIAL 111 INFILE $(SFDNAME) TO $(CLIBPATH) COMMENT COPYRIGHT $(AUTHOR)

# Compile the AmigaE include

AMIGAEMNAME = $(PATH)AmigaE/libraries/$(BASE).m
$(AMIGAEMNAME): $(AMIGAEENAME)
	ec $(AMIGAEENAME)

all: $(PRAGMANAME) $(AMIGAENAME) $(GCCINLINENAME) $(PROTONAME) \
     $(VBCCINLINENAME) $(LVONAME) $(FDNAME) $(CLIBNAME) \
     $(AMIGAEMNAME)

