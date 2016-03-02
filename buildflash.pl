#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use List::Util qw(sum min max);
use Getopt::Long;
use File::Basename;
use YAML::Tiny;

use CygCRC;

# Options
my ($verbose, $save_fis);
my (@types);

sub slurp {
    my ($file) = @_;
    open(F, '<:raw', $file) || die("$file: $!");
    my($fsize) = -s $file;
    my($fdata);
    die "$file: $!" unless(sysread(F, $fdata, $fsize) == $fsize);
    close(F);
    return $fdata;
}

sub mkfisentry {
    my ($name, $fbase, $mbase, $size, $entry, $dlen, $dcrc) = @_;
    my $data;
    # NB: desc_cksum is unused
    $data = pack("Z16V5Z212V2", $name, $fbase, $mbase, $size, $entry, $dlen, "", 0, $dcrc);
    return $data;
}

sub mkfis {
    my ($file, $entries) = @_;
    my ($fis) = pack("Z10CCV6Z212V2", ".FisValid", 0xa5, 0xa5, 1, (0) x 5, "", 0, 0);

    for my $f (@{$entries}) {
        # Update FIS
        my ($dcrc) = ($f->{dlen} && !($f->{name} =~ /linux/)) ? CygCRC::crc32($f->{data}) : 0;
        $fis .= mkfisentry($f->{name}, $f->{flash}, $f->{memory} || 0, $f->{size}, $f->{entry} || 0, $f->{dlen}, $dcrc);
    }

    $fis;
}

sub mkflash {
    my($file, $geometry, $entries) = @_;
    my($flashaddr, $offset) = (@{$entries}[0]->{flash}, 0);
    my($flash) = chr(0xff) x $geometry->{capacity};

    for my $f (@{$entries}) {
        substr($flash, $f->{flash} - $flashaddr, length($f->{data})) = $f->{data} if($f->{data});
    }

    return $flash;
}

# Preprocess to align size/address, read data from files
sub preprocess {
    my ($file, $geometry, $entries) = @_;
    my($last);

    for my $f (@{$entries}) {
        # Convert units
        $f->{size} = $1*1024 if ($f->{size} =~ /^([0-9]+)K$/);
        $f->{size} = $1*1024*1024 if ($f->{size} =~ /^([0-9]+)M$/);
        for my $t (qw(flash memory entry)) {
            $f->{$t} = hex($f->{$t}) if($f->{$t});
        }

        die(sprintf "%s: Entry must have a name, flash offset 0x%08x", $file, $f->{flash}) unless($f->{name});

        # Check entry data
        for my $t (qw(size flash)) {
            die(sprintf "%s:%s: Entry must have a '%s' value", $file, $f->{name}, $t) unless($f->{$t});
        }
        
        # Check block size(s)
        die(sprintf "%s:%s: Start address '%08x' is not block aligned", $file, $f->{name}, $f->{flash}) 
            unless(($f->{flash} % $geometry->{blocksize}) == 0);
        warn(sprintf "%s:%s: Size %d is not block aligned", $file, $f->{name}, $f->{size})
            unless($f->{name} eq "RedBoot config" || ($f->{size} % $geometry->{blocksize}) == 0);

        # Data from file
        if ($f->{datafile}) {
            $f->{data} = slurp($f->{datafile});
        }

        # Data length
        if ($f->{data}) {
            $f->{dlen} = length($f->{data});
            die sprintf("%s:%s: Data length (%d) exceeds defined size: %d", $file, $f->{name}, $f->{dlen}, $f->{size}) if ($f->{dlen} > $f->{size});
        } else {
            $f->{dlen} = 0;
            $f->{data} = "";
        }

        if ($last && $last->{end} > $f->{flash}) {
            die sprintf("%s: '%s': End of former (0x%08x) exceeds next block start: 0x%08x", $file, $last->{name}, $last->{end}, $f->{flash});
        }

        $f->{end} = $f->{flash} + $f->{size};
        $last = $f;
    }
}

sub find_fis {
    my ($f, $n) = @_;
    for my $e (@{$f}) {
        return $e if ($e->{name} eq $n);
    }
    undef;
}

sub do_image {
    my ($name, $layout) = @_;
    my (@entries) = @{$layout};
    my ($geometry) = shift @entries;

    die("First entry must define flash geometry") unless($geometry->{capacity});

    # Convert units
    for my $t (qw(blocksize capacity)) {
        $geometry->{$t} = $1*1024 if ($geometry->{$t} =~ /^([0-9]+)K$/);
        $geometry->{$t} = $1*1024*1024 if ($geometry->{$t} =~ /^([0-9]+)M$/);
    }

    preprocess($name, $geometry, \@entries);
    my ($fis) = mkfis($name, \@entries);

    my ($fisent) = find_fis(\@entries, "FIS directory");
    die ("$name: Must have a 'FIS directory' entry in template") unless($fisent);

    my ($flash) = mkflash($name, $geometry, \@entries); 

    substr($flash, $fisent->{flash} - $entries[0]->{flash}, length($fis)) = $fis;

    # Save FIS directory separately (debugging)
    if ($save_fis) {
        mkdir("fis") unless(-d "fis");
        open(O, ">:raw", "fis/${name}.fis") || die("$!");
        syswrite(O, $fis);
        close(O);
    }
        
    mkdir("images") unless(-d "images");
    open(B, ">:raw", "images/${name}.bin") || die("$!");
    syswrite(B, $flash);
    close(B);

    printf "Completed ${name}\n";
}

GetOptions ("type=s"     => \@types,
            "fis"        => \$save_fis,
            "verbose"    => \$verbose)
    or die("Error in command line arguments\n");

for my $t (@ARGV) {
    my ($basename, $dir, $suffix) = fileparse($t, qr/.[^.]*$/);
    my $yaml = YAML::Tiny->read( $t ) || die("$!");
    do_image($basename, $yaml);
}
