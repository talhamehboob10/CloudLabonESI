#
# Parse a directory of images looking for those that follow our versioning
# convention and for which the intermediate versions are deltas (identified
# here by using the all-new-convention of a .ddz suffix!)
#
# For each of those deltas use the base and delta to produce a new version
# of the full image file that we can compare to the original.
#

my $frombase = 0;
my $removefull = 0;

my $IMAGEDELTA = "/tmp/imageundelta";

if (@ARGV < 1) {
    print STDERR "Usage: $0 directory-of-images\n";
    exit(1);
}
my $imagedir = $ARGV[0];
if (! -d $imagedir) {
    print STDERR "$imagedir: not a directory\n";
    exit(1);
}

my $tstamp = "undeltafy." . time();
if (!open(ST, ">$imagedir/$tstamp")) {
    print STDERR "$imagedir: cannot write to directory\n";
    exit(1);
}

my @files = `cd $imagedir; /bin/ls -1 *.ddz* 2>/dev/null`;
chomp @files;
if (@files == 0) {
    print STDERR "$imagedir: no deltas found\n";
    unlink($tstamp);
    exit(1);
}

my %filehash = map { ("$_" => 1) } @files;
my %images = ();

#print STDERR "Files left #1: ", join(' ', keys %filehash), "\n\n";

# Find all the bases and associate versions with them
foreach my $file (@files) {
    if ($file =~ /^(.*).ddz:(\d+)$/) {
	my ($ibase,$vers) = ($1,$2);
	if (!exists($images{$ibase})) {
	    $images{$ibase}{'versions'} = ();
	    if (! -e "$imagedir/$ibase.ndz") {
		print STDERR
		    "*** cannot find base image '$ibase.ndz' for '$file'\n";
	    }
	}
	push @{$images{$ibase}{'versions'}}, $vers;
	if ($vers > $images{$ibase}{'lastvers'}) {
	    $images{$ibase}{'lastvers'} = $vers;
	}
	delete $filehash{$file};
    }
}

#print STDERR "Files left #3: ", join(' ', keys %filehash), "\n\n";

# Make sure all version deltas and their signatures exist
foreach my $ibase (keys %images) {
    my %versions = map { ($_ => 1) } @{$images{$ibase}{'versions'}};
    foreach my $vers (0 .. $images{$ibase}{'lastvers'}) {
	my $fbase = "$ibase.ndz";
	my $vstr = "";
	if ($vers > 0) {
	    $vstr = ":$vers";
	    if (!exists($versions{$vers})) {
		print STDERR "*** no version $vers of base '$ibase' ('$fbase$vstr'), ignoring\n";
		delete $images{$ibase};
		last;
	    }
	}
	# got sig?
	if (!exists($filehash{"$fbase$vstr.sig"})) {
	    print STDERR "*** no signature for $fbase$vstr, ignoring\n";
	    delete $images{$ibase};
	    last;
	}
	delete $filehash{"$fbase$vstr.sig"};

	# what about the hash?
	delete $filehash{"$fbase$vstr.sha1"};
    }
}

# warn about unknown files
if (scalar(keys %filehash) > 0) {
    print STDERR "WARNING: unknown files:\n";
}
foreach my $file (sort keys %filehash) {
    print STDERR "  $file\n";
}

exit(0);

# what do we have left
foreach my $ibase (sort keys %images) {
    my $lvers = $images{$ibase}{'lastvers'};
    print STDERR "$ibase: image and $lvers versions\n";

    foreach my $vers (1 .. $images{$ibase}{'lastvers'} - 1) {
	my $base = "$ibase.ndz";
	if ($vers > 1 && !$frombase) {
	    $base = "$ibase.ndz:" . ($vers-1);
	}
	my $this = "$ibase.ndz:$vers";
	my $delta = "$ibase.ddz:$vers";
	if (system("$IMAGEDELTA -S $imagedir/$base $imagedir/$this $imagedir/$delta\n")) {
	    print STDERR "*** '$IMAGEDELTA -S $imagedir/$base $imagedir/$this $imagedir/$delta' failed!\n";
	}
    }
}

exit(0);
