xadmaster.library got a design which is a result of programming for
xfdmaster.library, programming xpkmaster.library and fd2pragma tool. I got
some problems with these and tried to fix them for xadmaster.library.
I hope I got all :-) We will see in some years.

The library has a very open interface allowing future enhancements easily.
Nearly all funtions get their arguments through TagItem structures and
all structures must be allocated through xadmaster.library which ensures
the ability to expand them. The functions using Tag arrays end with A.
Related varargs functions end without A, but are not supported on all
compilers directly. Use fd2pragma to create link libraries for e.g.
MaxonC++ compiler.

The library is done in pure C code compiled with SAS-C. It does not use
global variables and library bases or the ExecBase pointer from 4.W. All
the necessary data is stored locally. All library functions use the normal
library interface for their work (e.g. xadGetInfo does not call
xadAllocObject internally, but with normal library call).

The library base pointers stored in xadMasterBase should be used from
clients only. No other programs should access them to ensure future
compatibility!

If you need additionally include files, use fd2pragma utility. It can be
found in Aminet under name dev/misc/fd2pragma.lha.

It is able to produce stub libraries, lvo, proto and pragma files and a lot
of other stuff.

The inline files in directory inline will work with GCC and VBCC.
The pragma files will work with SAS, Maxon, Storm, Dice and Aztec compiler.
The proto files will work with all of these compilers!

Most of these files were automatically created with fd2pragma (2.139 or
better):
fd2pragma SPECIAL   6 INFILE SFD/xadmaster_lib.sfd TO C/pragma
fd2pragma SPECIAL  18 INFILE SFD/xadmaster_lib.sfd TO AmigaE/
fd2pragma SPECIAL  40 INFILE SFD/xadmaster_lib.sfd TO C/inline
fd2pragma SPECIAL  38 INFILE SFD/xadmaster_lib.sfd TO C/proto
fd2pragma SPECIAL  70 INFILE SFD/xadmaster_lib.sfd TO C/inline
fd2pragma SPECIAL  23 INFILE SFD/xadmaster_lib.sfd TO ASM/lvo
fd2pragma SPECIAL 110 INFILE SFD/xadmaster_lib.sfd TO FD COMMENT
fd2pragma SPECIAL 111 INFILE SFD/xadmaster_lib.sfd TO C/clib COMMENT COPYRIGHT "Dirk Stöcker"

For GCC you may delete the pragma directory.
For all the other C compilers you may delete the inline directory,
but use pragma instead. Do not rename pragma to pragmas or change
the file names! When pragma does not exist, please create it.

Always call files in proto directory instead of clib, inline or pragma
directory! This makes usage of different compilers possible.

You need not to modify any of the include files or change their names!


Dirk Stöcker <soft@dstoecker.de>

13th December 2001
