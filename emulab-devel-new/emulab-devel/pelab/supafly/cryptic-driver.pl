#!/usr/bin/perl

#
# Copyright (c) 2006 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

sub numerically($$);
sub smin(\@);
sub smax(\@);
sub smean(\@);
sub sstddev(\@;$);
sub svariance(\@;$);

use English;

my $CRYPTIC = shift(@ARGV);
my $block_sizes_list = shift(@ARGV);
my $block_count = shift(@ARGV);
my $h = `hostname`;
chomp($h);

my @bss = split(/,/,$block_sizes_list);

foreach my $bs (@bss) {
    my $cmd = "$CRYPTIC -s $bs -l $block_count";

    #print "DEBUG: cmd '$cmd'\n";

    my @output = `$cmd`;
    my @times = ();

    open RDF,">cryptic.raw-$bs.$h" 
	or die "could not open raw dump file\n";

    foreach my $o (@output) {
	chomp($o);
	if ($o =~ /(\d+)\s+(\d+)/) {
	    push @times,"$2";
	    #print "DEBUG: ok '$2'\n";
	}
	else {
	    #print "DEBUG: line '$o'\n";
	}

	print RDF "$o\n";
    }

    close RDF;

    ## stats...
    my $mean = smean(@times);
    my $max = smax(@times);
    my $min = smin(@times);
    my $sdev = sstddev(@times,$mean);
    my $svar = svariance(@times,$sdev);

    printf "bs=%d min=%.2f max=%.2f mean=%.2f stddev=%.2f var=%.2f\n",$bs,$min,$max,$mean,$sdev,$svar;

}




## subs...
sub numerically($$) { $x = shift; $y = shift; $x <=> $y }

sub smin(\@) {
    my $dref = shift;
    my $min = 4000000000;
    foreach my $i (@{$dref}) {
        my $n = 0.0 + $i;
        if ($i < $min) {
            $min = $i;
        }
    }

    return $min;
}

sub smax(\@) {
    my $dref = shift;
    my $max = -4000000000;
    foreach my $i (@{$dref}) {
        my $n = 0.0 + $i;
        if ($i > $max) {
            $max = $i;
        }
    }

    return $max;
}

sub smean(\@) {
    my $dref = shift;
    my $mean = 0;
    foreach my $i (@{$dref}) {
        $mean += (0.0 + $i);
    }
    $mean = $mean / scalar(@{$dref});

    return $mean;
}

sub sstddev(\@;$) {
    my $dref = shift;
    my $mean = shift;
    if (!$mean) {
        $mean = smean(@{$dref});
    }
    my $ssum = 0;
    foreach my $i (@{$dref}) {
        $ssum += ($i-$mean) ** 2;
    }

    my $stddev = sqrt($ssum/scalar(@{$dref}));

    return $stddev;
}

sub svariance(\@;$) {
    my $dref = shift;
    my $stddev = shift;
    if (!$stddev) {
        $stddev = sstddev(@{$dref});
    }

    my $variance = $stddev ** 2;

    return $variance;
}
