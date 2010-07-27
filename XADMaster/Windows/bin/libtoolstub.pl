#!/usr/bin/perl

use strict;

my $filelist;
my $output;

foreach my $i (0..$#ARGV)
{
	$filelist=$ARGV[$i+1] if $ARGV[$i] eq "-filelist";
	$output=$ARGV[$i+1] if $ARGV[$i] eq "-o";
}

unlink $output;

open LIST,$filelist or die;
my @files=<LIST>;
close LIST;

chomp @files;

system(
	"/Developer/Cocotron/1.0/Windows/i386/gcc-4.3.1/bin/i386-mingw32msvc-ar",
	"rcs",
	$output,
	@files
);