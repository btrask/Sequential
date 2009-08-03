dnl -*- Autoconf -*-
dnl Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)
AC_INIT([libxad],[0.1],[soft@dstoecker.de])
AM_INIT_AUTOMAKE
AC_CONFIG_SRCDIR([debug.c])
AC_CONFIG_HEADER([config.h])

# --enable-gplclients and --disable-gplclients options
AC_ARG_ENABLE(gplclients,
  AC_HELP_STRING([--disable-gplclients],
                 [only use LGPL clients in the main library]),
  enable_gplclients=$enableval,
  enable_gplclients=yes)
if test x$enable_gplclients == xyes; then
  AC_DEFINE(XAD_GPLCLIENTS, 1, [Use GPL clients in the main library?])
fi
AM_CONDITIONAL(XAD_GPLCLIENTS, test x$enable_gplclients = 'xyes')

# --enable-debug and --disable-debug options
AC_ARG_ENABLE(debug,
  AC_HELP_STRING([--enable-debug], [enable debugging]),
  enable_debug=$enableval,
  enable_debug=no)
if test x$enable_debug == xyes; then
  AC_DEFINE(DEBUG, 1, [Turn debugging mode on?])
fi
AM_CONDITIONAL(DEBUG, test x$enable_debug = 'xyes')

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_EXEEXT

# libtool
AC_DISABLE_STATIC
AC_LIBTOOL_DLOPEN
AC_PROG_LIBTOOL
AC_DEFINE_UNQUOTED(SO_EXT, "$shrext_cmds", [file extension for shared objects])

# Checks for header files.
AC_HEADER_STDC
AC_HEADER_TIME
AC_HEADER_DIRENT
AC_CHECK_HEADERS([ctype.h dirent.h dlfcn.h errno.h fcntl.h getopt.h libintl.h \
  limits.h stdarg.h stddef.h stdlib.h string.h sys/stat.h sys/time.h \
  sys/types.h sys/wait.h unistd.h wchar.h wctype.h xpk/xpk.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_C_INLINE
AC_TYPE_OFF_T
AC_TYPE_SIZE_T

# Checks for libraries
AC_CHECK_LIB(xpk, XpkExamine)
AC_CHECK_LIB(c, dlopen, [LIB_DL=""],
  AC_CHECK_LIB(dl, dlopen, [LIB_DL="-ldl"],
    AC_MSG_ERROR(dynamic linker needed)))

# Checks for functions
AC_SYS_LARGEFILE
AC_FUNC_ALLOCA
AC_FUNC_FSEEKO
AC_CHECK_FUNCS([memcpy strcasecmp strchr utime utimes])
AC_CHECK_FUNCS([getopt_long],,[AC_CHECK_LIB([gnugetopt], [getopt_long],
  [AC_DEFINE([HAVE_GETOPT_LONG])],[AC_LIBOBJ(getopt) AC_LIBOBJ(getopt1)])])


# Can we assume varargs are passed in order on the stack and ints == ptrs?
#AC_RUN_IFELSE([AC_LANG_SOURCE([
##include <unistd.h>
#int vafunc(int a, ...) {
#  int *b = &a;
#  return (*(b+1) == 1234) && (*(b+3) == 5678) && (*(b+2) == *(b+4));
#}
#int main() {
#  int var;
#  if (! vafunc(0, 1234, &var, 5678, &var)) exit(1);
#  return 0;
#}
#])],[TAGMODE=DIRECTMEMORY],[TAGMODE=VARARGS],[TAGMODE=VARARGS])
TAGMODE=VARARGS


# Where should XAD install and look for its clients?
if test "x$prefix" == xNONE; then
  prefix='${ac_default_prefix}'
fi
if test "x$exec_prefix" == xNONE; then
  exec_prefix='${prefix}'
fi
CLIENTDIR=`eval eval eval eval echo "${libdir}/xad/clients"`
AC_DEFINE_UNQUOTED(CLIENTDIR, "$CLIENTDIR", [Path to XAD clients])


AC_SUBST([TAGMODE CLIENTDIR LIB_DL])
AC_CONFIG_FILES([Makefile include/Makefile clients/Makefile libxad.spec])
AC_OUTPUT
