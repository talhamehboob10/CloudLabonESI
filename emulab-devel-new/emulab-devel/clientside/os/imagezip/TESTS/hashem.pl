#
# Create signature files where missing. Check others.
#

my $hashall = 0;

my $IMAGEHASH = "/tmp/imagehash";

if (@ARGV < 1) {
    print STDERR "Usage: $0 directory-of-images\n";
    exit(1);
}
my $imagedir = $ARGV[0];
if (! -d $imagedir) {
    print STDERR "$imagedir: not a directory\n";
    exit(1);
}

my $tstamp = "hashem." . time();
if (!open(ST, ">$imagedir/$tstamp")) {
    print STDERR "$imagedir: cannot write to directory\n";
    exit(1);
}

my $clogfile = "$imagedir/check.log";
my $glogfile = "$imagedir/generate.log";

system("echo '' >$clogfile; date >>$clogfile");
system("echo '' >$glogfile; date >>$glogfile");

my @files = `cd $imagedir; /bin/ls -1 *.ndz*`;
chomp @files;

#print "Found: ", join(' ', @files), "\n";

my @images = ();
foreach my $file (@files) {
    # no symlinks
    next if (-l "$imagedir/$file");

    # no sha1s
    next if ($file =~ /\.sha1$/);

    # straight up ndz
    if ($file =~ /\.ndz$/) {
	push @images, $file;
	next;
    }

    # versioned ndz
    if ($file =~ /\.ndz:\d+$/) {
	push @images, $file;
	next;
    }
}

print STDERR "Found ", int(@images), " images\n";
foreach my $file (@images) {
    print "$file: ";
    if (-e "$imagedir/$file.sig") {
	print "found sig...";
	if (checksig($file)) {
	    print "[OK]\n";
	    next;
	}
	print "[BAD]...re";
    }
    print "generating...";
    if (gensig($file)) {
	print "[OK]\n";
	next;
    }
    print "[FAIL]\n";
}

exit(0);

sub checksig($)
{
    my $file = shift;
    
    if (system("(echo $file; $IMAGEHASH -SX $imagedir/$file) >>$clogfile 2>&1")) {
	return 0;
    }
    return 1;
}

sub gensig($)
{
    my $file = shift;
    
    if (system("(echo $file; $IMAGEHASH -cX $imagedir/$file) >>$glogfile 2>&1")) {
	return 0;
    }
    return 1;
}
