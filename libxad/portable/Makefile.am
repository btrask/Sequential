AUTOMAKE_OPTIONS = 	foreign
if DEBUG
extra_warnings =	-Wconversion -Wsign-compare
endif
AM_CFLAGS =	-std=c99 -Wall -pedantic -DUNIX $(extra_warnings) \
		-I$(top_srcdir)/include -I$(top_srcdir)/unix -I$(top_srcdir)

SUBDIRS =		include clients
lib_LTLIBRARIES =	libxad.la
bin_PROGRAMS =		checkx

libxad_la_SOURCES =	all.c clients.c unix/init.c unix/emulation.c
libxad_la_LDFLAGS =	-export-symbols-regex '^xad' -version-info 0:0:0
libxad_la_LIBADD =	@LIB_DL@

checkx_SOURCES =	tools/checkx.c libxad.la
checkx_LDADD =		libxad.la