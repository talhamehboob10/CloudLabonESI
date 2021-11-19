#
# Right now, extract out the imagedelta numbers
#

my %deltas = ();

foreach my $file (@ARGV) {
    parse($file);
}

foreach my $delta (sort keys %deltas) {
    my $fsize = $deltas{$delta}{'fsize'};
    my $dsize = $deltas{$delta}{'dsize'};
    my $pct = $deltas{$delta}{'pct'};

    my $stime = 0;
    if ($deltas{$delta}{'sstamp'} =~ / (\d\d):(\d\d):(\d\d) /) {
	$stime = $1 * 3600 + $2 * 60 + $3;
    }
    my $etime = 0;
    if ($deltas{$delta}{'estamp'} =~ / (\d\d):(\d\d):(\d\d) /) {
	$etime = $1 * 3600 + $2 * 60 + $3;
    }
    $etime -= $stime;

    printf("%s: %s%% (%d -> %d) in %d seconds\n",
	   $delta, $pct, $fsize, $dsize, $etime);
}

sub parse($)
{
    my $file = shift;

    if (!open(FD, "<$file")) {
	print "$file: could not open\n";
	return;
    }

    my $curdelta = "";
    while (my $line = <FD>) {
	if ($line =~ /^==== (.*): \/images\/bin\/.*\/imagedelta -SVF (\S+)\s+(\S+)\s+(\S+)/) {
	    $deltas{$4}{'sstamp'} = $1;
	    $deltas{$4}{'from'} = $2;
	    $deltas{$4}{'to'} = $3;
	    $curdelta = $4;
	    next;
	}
	if ($line =~ /^$curdelta: (\d+) sectors, ([0-9\.]+)% of full image \((\d+) sectors\)$/) {
	    $deltas{$curdelta}{'dsize'} = $1;
	    $deltas{$curdelta}{'pct'} = $2;
	    $deltas{$curdelta}{'fsize'} = $3;
	    next;
	}
	if ($line =~ /^==== (.*): \/images\/bin\/.*\/imageundelta -SV (\S+)\s+(\S+)\s+(\S+)/) {
	    if ($curdelta eq $3) {
		$deltas{$curdelta}{'estamp'} = $1;
	    } else {
		print STDERR "$curdelta: could not find end stamp, ignored\n";
		delete $deltas{$curdelta};
	    }
	    $curdelta = "";
	}
    }
}
