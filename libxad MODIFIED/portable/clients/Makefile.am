AUTOMAKE_OPTIONS =      foreign
if DEBUG
extra_warnings =	-Wconversion -Wsign-compare
endif
AM_CFLAGS =	-std=c99 -Wall -pedantic -DUNIX $(extra_warnings) \
		-I$(top_srcdir)/include -I$(top_srcdir)/unix


# XAD clients which are incompatible with GPL or LGPL licenses
nongpl_clients =		

# XAD clients which are GPL licensed
gpl_clients =		libHA.la \
                        libTRDOS.la

# XAD clients which are LGPL licensed
lgpl_clients =		libAce.la \
                        libAmigaFS.la \
                        libAMPK.la \
                        libBzip2.la \
                        libCAB.la \
                        libCpio.la \
                        libCrunchDisk.la \
                        libDCS.la \
                        libDMS.la \
                        libFATFS.la \
                        libIFFCDAF.la \
                        libLhA.la \
                        libLhF.la \
                        libLZX.la \
                        libMDC.la \
                        libMXMSimpleArc.la \
                        libPackDev.la \
                        libPackDisk.la \
                        libRPM.la \
                        libSOSFS.la \
                        libStuffIt.la \
                        libSuperDuper3.la \
                        libTar.la \
                        libxDisk.la \
                        libxMash.la \
                        libZip.la \
                        libZoom.la

# Some clients are commented out. These haven't been
# uploaded to CVS yet. PLEASE DON'T REMOVE COMMENTED LINES!
#                       libAr.la
#                       libBzip.la              # DONE
#                       libCOP.la               # DONE
#                       libDiskDoubler.la
#                       libDImp.la              # DONE
#                       libId.la                # DONE
#                       libSFS.la
#                       libMakeSFX.la
#                       libMSTNEF.la
#                       libPackDir.la
#                       libUnrealUMX.la
#                       libWrapster.la
#                       libZAP.la
#                       libMSA.la               # DONE

if DEBUG
# compile and install all libraries anyway, to make sure they do compile
# externally and dynamically load
build_libs = $(gpl_clients) $(lgpl_clients) $(nongpl_clients)
else
# only compile clients that are not in the library
if XAD_GPLCLIENTS
build_libs = $(nongpl_clients)
else
build_libs = $(gpl_clients) $(nongpl_clients)
endif
endif


libdir                         = @CLIENTDIR@
lib_LTLIBRARIES                = $(build_libs)
libAce_la_SOURCES              = Ace.c
libAce_la_LDFLAGS              = -avoid-version -module
libAmigaFS_la_SOURCES          = FS_Amiga.c
libAmigaFS_la_LDFLAGS          = -avoid-version -module
libAMPK_la_SOURCES             = AMPK.c
libAMPK_la_LDFLAGS             = -avoid-version -module
#libAr_la_SOURCES               = ar.c
#libAr_la_LDFLAGS               = -avoid-version -module
libBzip2_la_SOURCES            = bzip2.c
libBzip2_la_LDFLAGS            = -avoid-version -module
#libBzip_la_SOURCES             = bzip.c
#libBzip_la_LDFLAGS             = -avoid-version -module
libCAB_la_SOURCES              = CAB.c
libCAB_la_LDFLAGS              = -avoid-version -module
#libCOP_la_SOURCES              = COP.c
#libCOP_la_LDFLAGS              = -avoid-version -module
libCpio_la_SOURCES             = Cpio.c
libCpio_la_LDFLAGS             = -avoid-version -module
libCrunchDisk_la_SOURCES       = CrunchDisk.c
libCrunchDisk_la_LDFLAGS       = -avoid-version -module
libDCS_la_SOURCES              = DCS.c
libDCS_la_LDFLAGS              = -avoid-version -module
#libDImp_la_SOURCES             = DImp.c
#libDImp_la_LDFLAGS             = -avoid-version -module
#libDiskDoubler_la_SOURCES      = DiskDoubler.c
#libDiskDoubler_la_LDFLAGS      = -avoid-version -module
libDMS_la_SOURCES              = DMS.c
libDMS_la_LDFLAGS              = -avoid-version -module
libFATFS_la_SOURCES            = FS_FAT.c
libFATFS_la_LDFLAGS            = -avoid-version -module
#libSFS_la_SOURCES              = FS_SFS.c
#libSFS_la_LDFLAGS              = -avoid-version -module
libHA_la_SOURCES               = HA.c
libHA_la_LDFLAGS               = -avoid-version -module
#libId_la_SOURCES               = id.c
#libId_la_LDFLAGS               = -avoid-version -module
libIFFCDAF_la_SOURCES          = IFF-CDAF.c
libIFFCDAF_la_LDFLAGS          = -avoid-version -module
libLhA_la_SOURCES              = LhA.c
libLhA_la_LDFLAGS              = -avoid-version -module
libLhF_la_SOURCES              = LhF.c
libLhF_la_LDFLAGS              = -avoid-version -module
libLZX_la_SOURCES              = LZX.c
libLZX_la_LDFLAGS              = -avoid-version -module
#libMakeSFX_la_SOURCES          = MakeSFX.c
#libMakeSFX_la_LDFLAGS          = -avoid-version -module
libMDC_la_SOURCES              = MDC.c
libMDC_la_LDFLAGS              = -avoid-version -module
#libMSA_la_SOURCES              = MSA.c
#libMSA_la_LDFLAGS              = -avoid-version -module
#libMSTNEF_la_SOURCES           = MS-TNEF.c
#libMSTNEF_la_LDFLAGS           = -avoid-version -module
libMXMSimpleArc_la_SOURCES     = MXM-SimpleArc.c
libMXMSimpleArc_la_LDFLAGS     = -avoid-version -module
libPackDev_la_SOURCES          = PackDev.c
libPackDev_la_LDFLAGS          = -avoid-version -module
#libPackDir_la_SOURCES          = PackDir.c
#libPackDir_la_LDFLAGS          = -avoid-version -module
libPackDisk_la_SOURCES         = PackDisk.c
libPackDisk_la_LDFLAGS         = -avoid-version -module
libRPM_la_SOURCES              = RPM.c
libRPM_la_LDFLAGS              = -avoid-version -module
libSOSFS_la_SOURCES            = FS_SOS.c
libSOSFS_la_LDFLAGS            = -avoid-version -module
libStuffIt_la_SOURCES          = StuffIt.c
libStuffIt_la_LDFLAGS          = -avoid-version -module
libSuperDuper3_la_SOURCES      = SuperDuper3.c
libSuperDuper3_la_LDFLAGS      = -avoid-version -module
libTar_la_SOURCES              = Tar.c
libTar_la_LDFLAGS              = -avoid-version -module
libTRDOS_la_SOURCES            = TR-DOS.c
libTRDOS_la_LDFLAGS            = -avoid-version -module
#libUnrealUMX_la_SOURCES        = UnrealUMX.c
#libUnrealUMX_la_LDFLAGS        = -avoid-version -module
#libWrapster_la_SOURCES         = Wrapster.c
#libWrapster_la_LDFLAGS         = -avoid-version -module
libxDisk_la_SOURCES            = xDisk.c
libxDisk_la_LDFLAGS            = -avoid-version -module
libxMash_la_SOURCES            = xMash.c
libxMash_la_LDFLAGS            = -avoid-version -module
#libZAP_la_SOURCES              = ZAP.c
#libZAP_la_LDFLAGS              = -avoid-version -module
libZip_la_SOURCES              = Zip.c
libZip_la_LDFLAGS              = -avoid-version -module
libZoom_la_SOURCES             = Zoom.c
libZoom_la_LDFLAGS             = -avoid-version -module
