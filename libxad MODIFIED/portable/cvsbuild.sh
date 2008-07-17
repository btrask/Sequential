#!/bin/sh
./cvsclean.sh
autoreconf -i
mkdir _install
./configure --prefix=`pwd`/_install --enable-debug
make
make install
