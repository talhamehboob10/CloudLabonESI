#
# Run an image I through its paces:
#
# 1. ensure image has a valid signature I.sig, make one if not
# 2. create a memdisk and load image on it
# 3. compare image on disk with signature I.sig (imagehash)
# 4. recapture image with signature to I.new (imagezip)
# 5. compare old and new signatures (imagehash)
#
my $TMPDIR = "/local/tmp";
my $LOGDIR = "/local/logs";
my @NEEDBINS = ("imagezip", "imageunzip", "imagehash", "imagedump");

my $MAXSECTORS = (20 * 1024 * 1024 * 2);
my $LVMSTRIPE = 6;

my $checksig = 0;
my $cleanonfail = 0;

my $os = `uname`;
chomp($os);
if ($os !~ /^(Linux|FreeBSD)$/) {
    die "Unknown OS '$os'\n";
}
my $arch = `uname -m`;
chomp($arch);
if ($arch !~ /^(x86_32|x86_64|aarch64|i386|amd64)$/) {
    die "Unknown arch '$arch'\n";
}
my $bindir = "/images/bin/${os}_${arch}";

foreach my $bin (@NEEDBINS) {
    if (! -x "$bindir/$bin") {
	die "Cannot find $bindir/$bin\n";
    }
}

if (@ARGV == 0) {
    print STDERR "Usage: testimage.pl image1.ndz [ image2.ndz ... ]\n";
    exit(1);
}

my $tstamp = time();
print "Logs will be $LOGDIR/$tstamp.*.log ...\n";

my $rv = 0;
foreach my $image (@ARGV) {
    $rv += testimage($image);
}
exit($rv);

sub testimage($)
{
    my $image = shift;

    print "$image: START signature check\n";
    if (sigcheck($image)) {
	print "$image: ERROR signature check\n";
	return 1;
    }
    print "$image: END signature check\n";

    print "$image: START image unzip\n";
    # create a memdisk for the image
    my $ssize = imagesize($image);
    my $dev = makedisk($image, $ssize);
    if (!$dev) {
	print "$image: ERROR image unzip\n";
	return 1;
    }
    # and load it
    if (mysystem("$bindir/imageunzip -f $image $dev")) {
	print "$image: ERROR image unzip\n";
	unmakedisk($image, $dev) if ($cleanonfail);
	return 1;
    }
    print "$image: END image unzip\n";

    print "$image: START loaded image verify\n";
    if (mysystem("$bindir/imagehash -q $image $dev")) {
	print "$image: ERROR image verify\n";
	unmakedisk($image, $dev) if ($cleanonfail);
	return 1;
    }
    print "$image: END loaded image verify\n";

    #
    # XXX gak! Without an MBR/GPT, imagezip cannot (yet) figure out
    # what the filesystem is. We make a wild guess here based on image name.
    #
    my ($ifile,$itype);
    if ($image =~ /([^\/]+)$/) {
	$ifile = $1;
    } else {
	$ifile = $image;
    }
    if ($ifile =~ /\+/) {
	# full image, don't need anything
	$itype = "";
    } elsif ($image =~ /FBSD/) {
	# FreeBSD
	$itype = "-S 165 -c $ssize";
    } elsif ($ifile =~ /WIN/) {
	# WIN XP or 7 are full disk images
	$itype = "";
    } else {
	# assume Linux
	$itype = "-S 131 -c $ssize";
    }

    my $nimage = "$image.new";
    print "$image: START image rezip\n";
    if (mysystem("$bindir/imagezip $itype -U $nimage.sig $dev $nimage")) {
	print "$image: ERROR image rezip\n";
	unmakedisk($image, $dev) if ($cleanonfail);
	return 1;
    }
    print "$image: END image rezip\n";

    print "$image: START image sigfile compare\n";
    if (comparesigfiles($image, $nimage)) {
	print "$image: ERROR image sigfile compare\n";
	unmakedisk($image, $dev) if ($cleanonfail);
	return 1;
    }
    print "$image: END image sigfile compare\n";

    unmakedisk($image, $dev);
    return 0;
}

sub comparesigfiles($$)
{
    my ($image1,$image2) = @_;

    if (mysystem("$bindir/imagehash -Rq -o $image1.sig > $image1.sig.txt")) {
	print "$image1: could not dump signature\n";
	return 1;
    }
    if (mysystem("$bindir/imagehash -Rq -o $image2.sig > $image2.sig.txt")) {
	print "$image2: could not dump signature\n";
	return 1;
    }
    if (mysystem("diff -q $image1.sig.txt $image2.sig.txt")) {
	print "*** signatures differ (diff $image1.sig.txt $image2.sig.txt)\n";
	return 1;
    }

    unlink("$image1.sig.txt", "$image2.sig.txt");
    return 0;
}

sub sigcheck($)
{
    my $image = shift;

    if (! -e "$image") {
	print STDERR "$image: does not exist\n";
	return 1;
    }
    if (! -e "$image.sig") {
	print STDERR "$image: signature does not exist\n";
	return 1;
    }

    if ($checksig) {
	if (mysystem("$bindir/imagehash -qSX $image")) {
	    print "$image: signature did not check\n";
	    return 1;
	}
	# gen a new format sig file and compare
	if (mysystem("$bindir/imagehash -qcX -o ${image}foo.sig $image")) {
	    print "$image: could not generate signature\n";
	    return 1;
	}
	if (comparesigfiles($image, "${image}foo")) {
	    print "$image: new signature does not match old\n";
	    return 1;
	}
    }

    return 0;
}

sub imagesize($)
{
    my $image = shift;

    my @output = `$bindir/imagedump $image`;
    if ($?) {
	print "$image: *** could not get size of image\n";
	return 0;
    }
    foreach my $line (@output) {
	chomp($line);
	if ($line =~ /covered sector range: \[(\d+)-(\d+)\]/) {
	    if ($1 != 0) {
		print "$image: WARNING: image does not start at 0\n";
	    }
	    $ssize = $2 + 1;
	    last;
	}
    }

    return $ssize;
}

sub makedisk($$)
{
    my ($image,$ssize) = @_;
    my ($istr,$dev);

    if ($image =~ /([^\/]+)\/([^\/]+)$/) {
	$istr = "$1-$2";
    } elsif ($image =~ /([^\/]+)$/) {
	$istr = $1;
    } else {
	print "$image: *** could not parse '$image'\n";
	return undef;
    }

    my $mb = int(($ssize + 2047) / 2048);
    $mb += 100;

    if ($os eq "Linux") {
	if ($ssize > $MAXSECTORS) {
	    print "$image: ERROR: image too large ($ssize) for ramdisk,".
		" using LV instead\n";
	    if (mysystem("lvcreate -i $LVMSTRIPE -L ${mb}m -n $istr emulab")) {
		print STDERR "could not create LV\n";
		return undef;
	    }
	    return "/dev/emulab/$istr";
	}

	# XXX there has to be a better way!
	#
	# mount -t tmpfs -o size=20580m tmpfs /mnt/FOO.ndz
	# dd if=/dev/zero of=/mnt/FOO.ndz/disk bs=1024k seek=20479 count=1
	# losetup -f
	# losetup /dev/loop0 /mnt/FOO.ndz/disk
	#
	my $mountpoint = "/mnt/$istr";
	if (!mkdir($mountpoint)) {
	    print STDERR "could not make mountpoint $mountpoint\n";
	    return undef;
	}
	if (mysystem("mount -t tmpfs -o size=${mb}m tmpfs $mountpoint")) {
	    rmdir($mountpoint);
	    return undef;
	}
	my $mbm1 = $mb - 1;
	if (mysystem("dd if=/dev/zero of=$mountpoint/disk bs=1024k seek=$mbm1 count=1")) {
	    mysystem("umount $mountpoint");
	    rmdir($mountpoint);
	    return undef;
	}
	$dev = `losetup -f`;
	chomp($dev);
	if (mysystem("losetup $dev $mountpoint/disk")) {
	    mysystem("umount $mountpoint");
	    rmdir($mountpoint);
	    return undef;
	}
    } else {
	print STDERR "Cannot do this under $os yet\n";
    }

    return $dev;
}

sub unmakedisk($$)
{
    my ($image,$dev) = @_;
    my $istr;

    if ($image =~ /([^\/]+)\/([^\/]+)$/) {
	$istr = "$1-$2";
    } elsif ($image =~ /([^\/]+)$/) {
	$istr = $1;
    } else {
	print "$image: *** could not parse '$image'\n";
	return undef;
    }

    if ($dev eq "/dev/emulab/$istr") {
	if (mysystem("lvremove -f emulab/$istr")) {
	    print STDERR "$image: could not destroy LV\n";
	    return -1;
	}
    } elsif (mysystem("losetup -d $dev") ||
	     mysystem("umount /mnt/$istr") ||
	     !rmdir("/mnt/$istr")) {
	print STDERR "$image: could not tear down ramdisk\n";
	return -1;
    }
    return 0;
}

sub mysystem($)
{
    my ($cmd) = @_;
    my $logfile = "$LOGDIR/testimage.$tstamp.log";
    my $now = localtime();
    my $redir;

    if (open(FD, ">>$logfile")) {
	print FD "==== $now: $cmd\n";
	close(FD);
    }

    if ($cmd =~ />/) {
	$redir = "2>>$logfile";
    } else {
	$redir = ">>$logfile 2>&1";
    }
    if (system("$cmd $redir")) {
	my $stat = $?;
	print STDERR "*** '$cmd' failed, see '$logfile'\n";
	return $stat;
    }

    return 0;
}
