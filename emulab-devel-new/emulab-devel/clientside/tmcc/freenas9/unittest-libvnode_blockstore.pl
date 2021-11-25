#!/usr/bin/perl -wT

BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

use libutil;
use libsetup;
use libtmcc;
use libvnode_blockstore;
use Getopt::Std;
use Data::Dumper;

# func protos
sub mkvnconfig($);


my $setup = 0;
my $teardown = 0;
my %opts = ();

if (!getopts("st", \%opts)) {
    print STDERR "Usage: $0 [-s|-t]\n";
    exit 1;
}

$setup = 1
    if exists($opts{'s'});

$teardown = 1
    if exists($opts{'t'});

# Set debugging in library
libvnode_blockstore::setDebug(1);

# Test FreeNAS list parsing
my @list = libvnode_blockstore::parseFreeNASListing("ist_extent");
print "Dump of FreeNAS ist_extent:\n" . Dumper(@list);

# List off slice info
my $sliceh = libvnode_blockstore::getSliceList();
print "Dump of FreeNAS slices:\n" . Dumper(%$sliceh);

# List off pools
my $pools = libvnode_blockstore::getPoolList();
print "Dump of FreeNAS pools:\n" . Dumper(%$pools);

# Grab and stash away storageconfig stuff for some vnode.
my $vnodeid = "dboxvm1-1";
my $vnconfig = mkvnconfig($vnodeid);

# do full, bottom-up slice setup
if ($setup) {
    libvnode_blockstore::vnodeCreate($vnodeid, undef, $vnconfig, 
				     $vnconfig->{'private'});
}

# Sleep for a bit...
#sleep 30;

# Tear it down!
if ($teardown) {
    libvnode_blockstore::vnodeDestroy($vnodeid, undef, $vnconfig,
				      $vnconfig->{'private'});
}

exit(0);

# Try to allocate a slice.
my %sconf = (
    'CMD' => "SLICE",
    'IDX' => "1",
    'BSID' => "rz-1",
    'VOLNAME' => "d-1",
    'VOLSIZE' => "51200",
    );
libvnode_blockstore::allocSlice($vnodeid, \%sconf, $vnconfig,
				$vnconfig->{'private'});

# Try to export it!
my %sconf2 = (
    'CMD' => "EXPORT",
    'IDX' => "2",
    'CLASS' => "SAN",
    'PROTO' => "iSCSI",
    'VOLNAME' => "d-1",
    'VOLSIZE' => "51200",
    'PERMS' => "rw",
    'UUID' => "iqn.2000-10.net.emulab:tbres:sandev:d-1",
    'UUID_TYPE' => "iqn",
    );
libvnode_blockstore::exportSlice($vnodeid, \%sconf2, $vnconfig, 
				 $vnconfig->{'private'});

sub mkvnconfig($) {
    my $vnodeid = shift;

    libsetup_setvnodeid($vnodeid);

    my %vnconfig = ( "vnodeid"   => $vnodeid,
		     "config"    => undef,
		     "ifconfig"  => undef,
		     "ldconfig"  => undef,
		     "tunconfig" => undef,
		     "attributes"=> undef,
	);

    $vnconfig{'private'} = {};
 
    my %tmp;
    my @tmp;
    my $tmp;
    my %attrs;

    #libtmcc::configtmcc("portnum",7778);

    fatal("Could not get vnode config for $vnodeid")
	if (getgenvnodeconfig(\%tmp));
    $vnconfig{"config"} = \%tmp;

    fatal("getifconfig($vnodeid): $!")
	if (getifconfig(\@tmp));
    $vnconfig{"ifconfig"} = [ @tmp ];

    fatal("getlinkdelayconfig($vnodeid): $!") 
	if (getlinkdelayconfig(\@tmp));
    $vnconfig{"ldconfig"} = [ @tmp ];

    fatal("gettunnelconfig($vnodeid): $!")
	if (gettunnelconfig(\$tmp));
    $vnconfig{"tunconfig"} = $tmp;

    fatal("getnodeattributes($vnodeid): $!")
	if (getnodeattributes(\%attrs));
    $vnconfig{"attributes"} = \%attrs;

    fatal("getstorageconfig($vnodeid): $!")
	if (getstorageconfig(\@tmp));
    $vnconfig{"storageconfig"} = \@tmp;

    print "vnconfig:\n" . Dumper(%vnconfig);

    return \%vnconfig;
}
