#!/bin/sh
topdir=`pwd`
for x in `find . -name .cvsignore`
do
  cd `dirname $x`
  rm -vrf `cat .cvsignore`
  cd $topdir
done
