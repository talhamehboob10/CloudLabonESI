#
# Check SHA1 hash file against image.
#

my $hashall = 0;

if (@ARGV < 1) {
    print STDERR "Usage: $0 directory-of-images\n";
    exit(1);
}
my $imagedir = $ARGV[0];
if (! -d $imagedir) {
    print STDERR "$imagedir: not a directory\n";
    exit(1);
}

my @files = `cd $imagedir; /bin/ls -1 *.ndz*`;
chomp @files;

#print "Found: ", join(' ', @files), "\n";

my @images = ();
foreach my $file (@files) {
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
    if (! -e "$imagedir/$file.sha1") {
	print "[FAIL] no signature!\n";
	next;
    }

    # make sure it is the right format:
    # SHA1 (fname) = 9f2a0f8160f70a7b29b0e1de2088a38d0f2bc229
    my $sha1 = `cat $imagedir/$file.sha1`;
    chomp($sha1);
    if ($sha1 =~ /^SHA1 .* = ([0-9a-f]{40})$/) {
	$sha1 = $1;
    } else {
	print "[FAIL] bogus .sha1 file\n";
	next;
    }

    my $nsha1 = `sha1 $imagedir/$file`;
    chomp($nsha1);
    if ($nsha1 =~ /^SHA1 .* = ([0-9a-f]{40})$/) {
	$nsha1 = $1;
    } else {
	print "[FAIL] did not correctly compute sha1!\n";
	next;
    }
    
    if ($sha1 eq $nsha1) {
	print "[OK]\n";
    } else {
	print "[BAD]\n";
    }
}

exit(0);
