#
# Parse a directory of images looking for those that follow our versioning
# convention. For those, start with the lowest numbered version and create
# deltas for all but the first and last, e.g.:
#
# imagedelta UBUNTU14-64-STD.ndz UBUNTU14-64-STD.ndz:1 UBUNTU14-64-STD.ddz:1
# rm UBUNTU14-64-STD.ndz:1
# ...
# imagedelta UBUNTU14-64-STD.ndz:8 UBUNTU14-64-STD.ndz:9 UBUNTU14-64-STD.ddz:9
# rm UBUNTU14-64-STD.ndz:9
#

my $frombase = 1;
my $removefull = 0;

my $IMAGEDELTA = "/tmp/imagedelta";

if (@ARGV < 1) {
    print STDERR "Usage: $0 directory-of-images\n";
    exit(1);
}
my $imagedir = $ARGV[0];
if (! -d $imagedir) {
    print STDERR "$imagedir: not a directory\n";
    exit(1);
}

my $tstamp = "deltafy." . time();
if (!open(ST, ">$imagedir/$tstamp")) {
    print STDERR "$imagedir: cannot write to directory\n";
    exit(1);
}

my @files = `cd $imagedir; /bin/ls -1 *.ndz*`;
chomp @files;
if (@files == 0) {
    print STDERR "$imagedir: no images found\n";
    unlink($tstamp);
    exit(1);
}

my %filehash = map { ("$_" => 1) } @files;
my %images = ();

#print STDERR "Files left #1: ", join(' ', keys %filehash), "\n\n";

# Find all the base files
foreach my $file (@files) {
    if ($file =~ /^(.*)\.ndz$/) {
	my $ibase = $1;
	if (-l "$imagedir/$file") {
	    print STDERR "$imagedir: ignoring symlink '$file'\n";
	    delete $filehash{$file};
	    delete $filehash{"$file.sig"};
	    delete $filehash{"$file.sha1"};
	    next;
	}
	$images{$ibase}{'name'} = $file;
	$images{$ibase}{'lastvers'} = 0;
	@{$images{$ibase}{'versions'}} = ();
	delete $filehash{$file};
    }
}

#print STDERR "Files left #2: ", join(' ', keys %filehash), "\n\n";

# Find all the versions
foreach my $file (@files) {
    next if (!exists($filehash{$file}));
    if ($file =~ /^(.*).ndz:(\d+)$/) {
	my ($ibase,$vers) = ($1,$2);
	if (exists($images{$ibase})) {
	    push @{$images{$ibase}{'versions'}}, $vers;
	    if ($vers > $images{$ibase}{'lastvers'}) {
		$images{$ibase}{'lastvers'} = $vers;
	    }
	    delete $filehash{$file};
	    next;
	}
	print STDERR "*** version with no base '$file', ignoring\n";
	delete $filehash{$file};
	delete $filehash{"$file.sig"};
	delete $filehash{"$file.sha1"};
	next;
    }
}

#print STDERR "Files left #3: ", join(' ', keys %filehash), "\n\n";

# Make sure all versions and signatures exist
foreach my $ibase (keys %images) {
    my $nukeit = 0;
    my %versions = map { ($_ => 1) } @{$images{$ibase}{'versions'}};
    foreach my $vers (0 .. $images{$ibase}{'lastvers'}) {
	my $fbase = "$ibase.ndz";
	my $vstr = "";
	if ($vers > 0) {
	    $vstr = ":$vers";
	    if (!exists($versions{$vers})) {
		if ($frombase) {
		    print STDERR "WARNING: ";
		} else {
		    print STDERR "*** ";
		}
		print STDERR "no version $vers of '$ibase' ('$fbase$vstr')";
		if (!$frombase) {
		    print STDERR ", ignoring\n";
		    $nukeit = 1;
		} else {
		    print STDERR "\n";
		    delete $filehash{"$fbase$vstr.sig"};
		    delete $filehash{"$fbase$vstr.sha1"};
		    next;
		}
	    } else {
		delete $filehash{"$fbase$vstr"};
	    }
	}
	# got sig?
	if (!exists($filehash{"$fbase$vstr.sig"})) {
	    if (!$frombase) {
		print STDERR "*** no signature for $fbase$vstr, ignoring\n";
		$nukeit = 1;
	    } else {
		print STDERR "WARNING: no signature for $fbase$vstr, ".
		    "ignoring version\n";
		delete $filehash{"$fbase$vstr.sha1"};
		next;
	    }
	} else {
	    delete $filehash{"$fbase$vstr.sig"};
	}

	# what about the hash?
	delete $filehash{"$fbase$vstr.sha1"};
    }
    if ($nukeit) {
	delete $images{$ibase};
    }
}

# warn about unknown files
if (scalar(keys %filehash) > 0) {
    print STDERR "WARNING: unknown files:\n";
}
foreach my $file (sort keys %filehash) {
    print STDERR "  $file\n";
}

# what do we have left
foreach my $ibase (sort keys %images) {
    my $lvers = $images{$ibase}{'lastvers'};
    print STDERR "$ibase: image and $lvers versions\n";

    foreach my $vers (1 .. $images{$ibase}{'lastvers'}) {
	my $base = "$ibase.ndz";
	if ($vers > 1 && !$frombase) {
	    $base = "$ibase.ndz:" . ($vers-1);
	}
	my $this = "$ibase.ndz:$vers";
	if ($frombase &&
	    (! -e "$imagedir/$this" || ! -e "$imagedir/$this.sig")) {
	    print STDERR "$ibase: version $vers skipped because of missing files\n";
	    next;
	}
	my $delta = "$ibase.ddz:$vers";
	if (system("$IMAGEDELTA -SF $imagedir/$base $imagedir/$this $imagedir/$delta\n")) {
	    print STDERR "*** '$IMAGEDELTA -SF $imagedir/$base $imagedir/$this $imagedir/$delta' failed!\n";
	}
    }
}

exit(0);
