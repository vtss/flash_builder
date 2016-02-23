#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use List::Util 'sum';
use Getopt::Long;

use CygCRC;

use constant {
    SZ_1K     => 1    * 1024,
    SZ_4K     => 4    * 1024,
    SZ_64K    => 64   * 1024,
    SZ_256K   => 256  * 1024,
    SZ_1M     => 1024 * 1024,
    SZ_8M     => 8    * 1024 * 1024,
    SZ_16M    => 16   * 1024 * 1024,
    SZ_32M    => 32   * 1024 * 1024,
    SZ_64M    => 64   * 1024 * 1024,
};

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
    my ($file, $entries) = @_;
    my($last);
    my($flash) = "";

    for my $f (@{$entries}) {
        # Pad data - if needed
        if ($f->{size} != $f->{dlen}) {
            $f->{data} .= chr(0xff) x ($f->{size} - $f->{dlen});
        }
        # 
        if ($last && $last->{end} != $f->{flash}) {
            if ($last->{end} > $f->{flash}) {
                die sprintf("%s: '%s': End of former (0x%08x) exceeds next block start: 0x%08x", $file, $last->{name}, $last->{end}, $f->{flash});
            } else {
                my ($hole) = $f->{flash} - $last->{end};
                $flash .= chr(0xff) x $hole;
                printf ("%s: Hole of %d bytes after %08x - before %08x\n", $file, $hole, $last->{end}, $f->{flash});
            }
        }

        # Flash Image
        $flash .= $f->{data};

        # remember last entry
        $last = $f;
    }

    return $flash;
}

# Preprocess to align size/address, read data from files
sub preprocess {
    my ($file, $entries) = @_;
    my($last);

    for my $f (@{$entries}) {
        if ($last) {
            $f->{flash} = $last->{flash} + $last->{size} unless($f->{flash});
            $f->{size} = $f->{flash} - $last->{flash} unless($f->{size});
        }
        
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

        $f->{end} = $f->{flash} + $f->{size};
        $last = $f;
    }
}

sub block_round_down {
    my ($sz, $bsz) = @_;
    return $sz & ~($bsz - 1);
}

sub do_image {
    my ($board, $layout, $fsize, $bsize) = @_;
    my ($name) = sprintf("%s-%s-%dmb-%dkb", $layout, $board->{name}, $fsize/SZ_1M, $bsize/SZ_1K);
    my ($physflash, $ecosload, $ecosentry, $linuxload) = (0x40000000, 0x80040000, 0x800400BC, 0x80100000);
    my (@entries) = (
        {
            'name'     => 'RedBoot',
            'datafile' => $board->{redboot},
            'flash'    => $physflash,
            'size'     => SZ_256K,
        },
        {
            'name'     => 'conf',
            'size'     => SZ_256K,
            'data'     => "#@(#)VtssConfig\nMAC=00:01:c1:00:00:00\nBOARDID=1\nBOARDTYPE=0\0",
        },
        {
            'name'     => 'stackconf',
            'size'     => SZ_1M,
        });

    if ($layout eq "linux") {
        my ($imgsize) = (($fsize - 3*SZ_1M) / 2);
        push @entries, {
            'name'     => 'managed',
            'datafile' => $board->{ecos},
            'memory'   => $ecosload,
            'entry'    => $ecosentry,
            'size'     => 3.5 * SZ_1M,
        };
        my ($used) = sum(map { $_->{size} } @entries) + 3*$bsize;
        if ($fsize > SZ_16M) {
            my ($imgsize) = block_round_down(($fsize - $used)/2, $bsize);
            push @entries, (
                {
                    'name'     => 'linux',
                    'datafile' => $board->{linux},
                    'memory'   => $linuxload,
                    'entry'    => $linuxload,
                    'size'     => $imgsize,
                }, {
                    'name'     => 'linux.bk',
                    'datafile' => $board->{linux},
                    'memory'   => $linuxload,
                    'entry'    => $linuxload,
                    'size'     => $imgsize,
                });
        } else {
            # Single image - for now
            #printf "Single image: used %d, size %08x\n", $used, block_round_down($fsize - $used, $bsize);
            push @entries, {
                'name'     => 'linux',
                'datafile' => $board->{linux},
                'memory'   => $linuxload,
                'entry'    => $linuxload,
                'size'     => block_round_down($fsize - $used, $bsize),
            };
        }
    } else {
        # Ecos
        push @entries, (
            {
                'name'     => 'syslog',
                'size'     => SZ_256K,
            }, {
                'name'     => 'crashfile',
                'size'     => SZ_256K,
            });
        my ($used) = sum(map { $_->{size} } @entries) + 3*$bsize;
        my ($imgsize) = block_round_down(($fsize - $used)/2, $bsize);
        push @entries, (
            {
                'name'     => 'managed',
                'datafile' => $board->{ecos},
                'memory'   => $ecosload,
                'entry'    => $ecosentry,
                'size'     => $imgsize,
            }, {
                'name'     => 'managed.bk',
                'datafile' => $board->{ecos},
                'memory'   => $ecosload,
                'entry'    => $ecosentry,
                'size'     => $imgsize,
            });
    };

    # These are always the last entries
    my ($fisaddr) = $fsize - 3*$bsize;
    push @entries, (
        {
            'name'     => 'FIS directory',
            'flash'    => $physflash + $fisaddr,
            'size'     => $bsize,
        },
        {
            'name'     => 'RedBoot config',
            'datafile' => "files/fconfig-${layout}.bin",
            'size'     => SZ_4K,
        },
        {
            'name'     => 'Redundant FIS',
            'flash'    => $physflash + $fsize - $bsize,
            'size'     => $bsize,
        });
    
    preprocess($name, \@entries);

    my ($fis) = mkfis($name, \@entries);
    my ($flash) = mkflash($name, \@entries); 

    substr($flash, $fisaddr, length($fis)) = $fis;

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
}

my (@boards) = (
    {
        name       => "caracal1",
        geometries => [ [SZ_16M, SZ_64K], [SZ_32M, SZ_64K] ],
        redboot    => "artifacts/redboot-luton26.img",
        ecos       => "artifacts/web_switch_caracal1_l10_ref.gz",
        linux      => "artifacts/web_switch_caracal1_l10_ref_linux_icpu_brsdk-nor.mfi",
    },
    {
        name       => "caracal2",
        geometries => [ [SZ_16M, SZ_64K] ],
        redboot    => "artifacts/redboot-luton26.img",
        ecos       => "artifacts/web_switch_caracal2_l26_ref.gz",
        linux      => "artifacts/web_switch_caracal2_l26_ref_linux_icpu_brsdk-nor.mfi",
    },
    {
        name       => "serval1",
        geometries => [ [SZ_16M, SZ_256K] ],
        redboot    => "artifacts/redboot-serval1.img",
        ecos       => "artifacts/web_switch_serval_ref.gz",
        linux      => "artifacts/web_switch_serval_ref_linux_icpu_brsdk-nor.mfi",
    },
    );

GetOptions ("type=s"     => \@types,
            "fis"        => \$save_fis,
            "verbose"    => \$verbose)
    or die("Error in command line arguments\n");

@types = qw(linux) unless(@types);

for my $t (@types) {
    for my $b (@boards) {
        #print Dumper($b);
        for my $g (@{$b->{geometries}}) {
            do_image($b, $t, @{$g});
            #print Dumper($g);
        }
    }
}
