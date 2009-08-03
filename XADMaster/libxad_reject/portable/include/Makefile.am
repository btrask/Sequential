include_HEADERS = xadmaster.h
noinst_HEADERS = functions.h

xadmaster.h: xadmaster.h.in ../functions.def mkproto.pl
	perl mkproto.pl EXTERNAL @TAGMODE@ ../functions.def <xadmaster.h.in >$@

functions.h: functions.h.in ../functions.def mkproto.pl
	perl mkproto.pl INTERNAL @TAGMODE@ ../functions.def <functions.h.in >$@

