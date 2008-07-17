#!/usr/bin/perl

use strict;

my $path=$ARGV[0] or do { print "Usage: make_7zip.pl path_to_7zip\n"; exit 1; };

my @headers=map "$path/Archive/7z_C/$_",(
	"7zAlloc.h","7zTypes.h","7zMethodID.h","7zBuffer.h","7zHeader.h",
	"7zCrc.h","7zItem.h","7zIn.h","7zExtract.h","7zDecode.h",
);
my @sources=map "$path/Archive/7z_C/$_",(
	"7zAlloc.c","7zBuffer.c","7zCrc.c","7zDecode.c","7zExtract.c",
	"7zHeader.c","7zIn.c","7zItem.c","7zMethodID.c"
);


my @files=(
	"$path/Compress/LZMA_C/LzmaDecode.h",@headers,
	"$path/Compress/LZMA_C/LzmaDecode.c",@sources,
);

#print "#define _LZMA_IN_CB\n";

for my $file (@files)
{
	open FILE,$file or die "Couldn't read file $file.";
	while(<FILE>) { print unless /^#include "/ }
}
