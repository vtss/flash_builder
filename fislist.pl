#!/usr/bin/env perl

# Copyright (c) 2016 Microsemi Corporation "Microsemi".

use warnings;
use strict;
use Data::Dumper;

open(FILE, $ARGV[0]) or die "$ARGV[0]: $!";
my ($fis) = do {local $/; <FILE> };
close(FILE);

#open(I, '<', $ARGV[0]) || die("$!");

my ($len) = length($fis);

my(%layout);

while ($fis) {
    my ($name, $fbase, $mbase, $size, $entry, $dlen, $pad, $dcrc, $fcrc) = unpack("Z16V5a212V2", $fis);
    if(substr($name,0,1) ne "\377") {
        printf ("%-16s: Base 0x%08x, mem: 0x%08x, size 0x%08x, Data: 0x%08x, entry 0x%08x, dcrc: 0x%08x, fcrc: 0x%08x\n", $name, $fbase, $mbase, $size, $dlen, $entry, $dcrc, $fcrc);
        $layout{$name} = { flash => $fbase, size => $size, memory => $mbase, entry => $entry, datafile => 'xx' };
        
    }
    $fis = substr($fis, 256);
}

#print Data::Dumper->Dump([\%layout], ["layout"]), $/;
