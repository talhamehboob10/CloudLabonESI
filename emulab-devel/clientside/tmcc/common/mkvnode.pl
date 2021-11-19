#!/usr/bin/perl -w
#
# Copyright (c) 2009-2019 University of Utah and the Flux Group.
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

#
# This is the top-level vnode creation script, called via the vnodesetup
# wrapper.  It is os independent, calling into routines defined
# in liblocsetup or elsewhere for os-dependent functionality.  Libraries
# contained in modules named like libvnode_<type>.pm are hooked in to
# obtain setup operations that are specific to the vnode type.
#
# This script was specific to Linux host environments, but has been modified
# to be used under FreeBSD for certain vnode-like containers.  Eventually
# all vnode/jail/etc. setups under any host OS should flow through this.
#

use strict;
use Getopt::Std;
use English;
use Errno;
use POSIX qw(strftime);
use POSIX qw(:sys_wait_h);
use POSIX qw(:signal_h);
use POSIX qw(setsid);
use Data::Dumper;
use Storable;
use vars qw($vnstate);

sub usage()
{
    print "Usage: mkvnode [-d] vnodeid\n" . 
          "  -d   Debug mode.\n" .
	  "  -c   Cleanup stale container\n".
	  "  -s   Show state for container\n".
          "";
    exit(1);
}
my $optlist  = "dcs";
my $debug    = 1;
my $cleanup  = 0;
my $showstate= 0;
my $vnodeid;

#
# Turn off line buffering on output
#
$| = 1;

# Drag in path stuff so we can find emulab stuff.
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 
use libsetup;
use libtmcc;
use libutil;
use libtestbed;
    
# Pull in vnode stuff
use libgenvnode;
use libvnode;

# Helpers
sub MyFatal($);
sub hasLibOp($);
sub safeLibOp($$$$;@);
sub blockOurSignals($);
sub unblockOurSignals($);
sub CleanupVM();
sub TearDownStaleVM();
sub StoreState();
sub ReadState();
sub BackendVnodePoll();
sub DefaultVnodePoll();

# Locals
my $CTRLIPFILE = "/var/emulab/boot/myip";
my $VMPATH     = "/var/emulab/vms/vminfo";
my $VNDIR;
my $leaveme    = 0;
my $running    = 0;
my $cleaning   = 0;
my $rebooting  = 0;
my $reload     = 0;
my ($vmid,$vmtype,$ret,$err);
my $ISXENVM    = (GENVNODETYPE() eq "xen" ? 1 : 0);
my $ISDOCKERVM = (GENVNODETYPE() eq "docker" ? 1 : 0);

# Flags for leaveme.
my $LEAVEME_REBOOT = 0x1;
my $LEAVEME_HALT   = 0x2;

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (defined($options{"d"})) {
    $debug = 1;
}
if (defined($options{"c"})) {
    $cleanup = 1;
}
if (defined($options{"s"})) {
    $showstate = 1;
    $debug     = 0;
}
usage()
    if (@ARGV != 1);

$vnodeid = $ARGV[0];
$VNDIR   = "$VMPATH/$vnodeid";

#
# Must be root.
# 
if ($UID != 0) {
    die("*** $0:\n".
	"    Must be root to run this script!\n");
}

#
# Deal with VIFROUTING flag from the server. Do this before we switch
# our vnode_id below since it is a physical host attribute. This will
# go away at some point.
#
my %attributes = ();
if (getnodeattributes(\%attributes)) {
    die("*** $0:\n".
	"Could not get node attributes");
}
if (exists($attributes{"xenvifrouting"})) {
    # Gack, tell backend network scripts.
    system("touch $ETCDIR/xenvifrouting");
}

# Tell the library what vnode we are messing with.
libsetup_setvnodeid($vnodeid);

# Can set this after above line. 
my $RUNNING_FILE = CONFDIR() . "/running";

#
# Turn on debug timestamps if desired.
#
if ($debug) {
    TBDebugTimeStampsOn();
}

#
# Remove old state files at boot.
#
if (! -e "/var/run/mkvnode.ready") {
    system("rm -f $VARDIR/vms/*/vnode.state");
    system("touch /var/run/mkvnode.ready");
}

#
# XXX: for now, support only a single vnode type per phys node.  This is bad,
# but it's the current assumption.  For now, we also assume the nodetype since
# we only have pcvm.  Later, we need to get this info from tmcd so we know 
# lib to load.
#
my @nodetypes = ( GENVNODETYPE() );

#
# Need the domain, but no conistent way to do it. Ask tmcc for the
# boss node and parse out the domain. 
#
my ($DOMAINNAME,$BOSSIP) = tmccbossinfo();
die("Could not get bossname from tmcc!")
    if (!defined($DOMAINNAME));

if ($DOMAINNAME =~ /^[-\w]+\.(.*)$/) {
    $DOMAINNAME = $1;
}
else {
    die("Could not parse domain name!");
}
if ($BOSSIP !~ /^\d+\.\d+\.\d+\.\d+$/) {
    die "Bad bossip '$BOSSIP' from bossinfo!";
}

#
# We go through this crap so that we can pull in multiple packages implementing
# the libvnode API so they (hopefully) won't step on our namespace too much.
#
my %libops = ();
foreach my $type (@nodetypes) {
    if ($type =~ /^([\w\d\-]+)$/) {
	$type = $1;
    }
    # load lib and initialize it
    my %ops;
    eval "use libvnode_$type; %ops = %libvnode_${type}::ops";
    if ($@) {
	die "while trying to load 'libvnode_$type': $@";
    }
    if (0 && $debug) {
	print "%ops($type):\n" . Dumper(%ops);
    }
    $libops{$type} = \%ops;
    if ($debug) {
	$libops{$type}{'setDebug'}->($debug);
    }
    $libops{$type}{'init'}->();

    # need to do this for each type encountered.
    TBDebugTimeStampWithDate("starting $type rootPreConfig()");
    $libops{$type}{'rootPreConfig'}->($BOSSIP,\%attributes);
    TBDebugTimeStampWithDate("finished $type rootPreConfig()");
}
if ($debug) {
    print "GENVNODETYPE " . GENVNODETYPE() . "\n";
    print "libops:\n" . Dumper(%libops);
}


#
# This holds the container state set up by the library. There is state
# added here, and state added in the library ("private"). We locally
# redefine this below, so cannot be a lexical.
#
# NOTE: There should be NO state in here that needs to survive reboot.
#       We just remove them all when rebooting. See above.
#
$vnstate = { "private" => {} };

#
# Quickie way to show the state.
#
if ($showstate) {
    if (! -e "$VNDIR/vnode.info") {
	fatal("No vnode.info file for $vnodeid");
    }
    my $str = `cat $VNDIR/vnode.info`;
    ($vmid, $vmtype, undef) = ($str =~ /^(\d*) (\w*) ([-\w]*)$/);
    
    my $tmp = eval { Storable::retrieve("$VNDIR/vnode.state"); };
    if ($@) {
	fatal("$@");
    }
    print Dumper($tmp);

    # So the lib op works.
    $vnstate = $tmp;

    ($ret,$err) = safeLibOp('vnodeState', 1, 0, 1);
    if ($err) {
	fatal("Failed to get status for existing container: $err");
    }
    if ($ret eq VNODE_STATUS_UNKNOWN()) {
	print "Cannot determine status container $vmid.\n";
    }
    print "Domain is $ret\n";
    exit(0);
}

#
# In most cases, the vnodeid directory will have been created by the
# caller, and a config file possibly dropped in.  When debugging, we
# have to create it here.
#
if (! -e $VMPATH) {
    mkdir($VMPATH, 0770) or
	fatal("Could not mkdir $VMPATH: $!");
}
chdir($VMPATH) or
    die("Could not chdir to $VMPATH: $!\n");

if (! -e $vnodeid) {
    mkdir($vnodeid, 0770) or
	fatal("Could not mkdir $vnodeid in $VMPATH: $!");
}
#
# The container description for the library routines. 
#
my %vnconfig = ( "vnodeid"   => $vnodeid,
                 "config"    => undef,
		 "ifconfig"  => undef,
		 "ldconfig"  => undef,
		 "tunconfig" => undef,
		 "attributes"=> undef,
		 "environment"   => undef,
                 "storageconfig" => undef,
		 "fwconfig"      => undef,
		 "hostattributes"=> \%attributes,
);
sub VNCONFIG($) { return $vnconfig{'config'}->{$_[0]}; }

#
# If cleanup requested, make sure the manager process is not running
# Must do this after the stuff above is defined.
#
if ($cleanup) {
    # This path is in vnodesetup. 
    my $pidfile = "/var/run/tbvnode-${vnodeid}.pid";
    if (-e $pidfile) {
	print STDERR "Manager process still running. Use that instead.\n";
	print STDERR "If the manager is really dead, first rm $pidfile.\n";
	exit(1);
    }
    exit(TearDownStaleVM());
}

#
# Now we can start doing something useful.
#
my ($pid, $eid, $vname) = check_nickname();
my $nodeuuid = getnodeuuid();
$nodeuuid = $vnodeid if (!defined($nodeuuid));

#
# Get all the config stuff we need.
#
my %tmp;
my @tmp;
my $tmp;
my %attrs;
my %envvars;
my $fwinfo;
my @fwrules;
my @fwhosts;

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
$vnconfig{"storageconfig"} = [ @tmp ];

fatal("getenvvars(): $!")
    if (getenvvars(\%envvars));
$vnconfig{"environment"} = \%envvars;

fatal("getfwconfig(): $!")
    if (getfwconfig(\$fwinfo, \@fwrules, \@fwhosts));

$vnconfig{"fwconfig"} = {"fwinfo"  => $fwinfo,
			 "fwrules" => \@fwrules,
			 "fwhosts" => \@fwhosts};

#
# see if we 1) are supposed to be "booting" into the reload mfs, and 2) if
# we have loadinfo.  Need both to reload!
#
fatal("getbootwhat($vnodeid): $!") 
    if (getbootwhat(\@tmp));
if (scalar(@tmp) && exists($tmp[0]->{"WHAT"})) {
    if ($tmp[0]->{"WHAT"} =~ /frisbee-pcvm/) {
	#
	# Ok, we're reloading, using the fake frisbee pcvm mfs.
	#
	$reload = 1;
	
	fatal("getloadinfo($vnodeid): $!") 
	    if (getloadinfo(\@tmp));
	if (!scalar(@tmp)) {
	    fatal("vnode $vnodeid in reloading, but got no loadinfo!");
	}
	#
	# Loadinfo can now be a list, when loading deltas. Actually, I suppose
	# we could support loading multiple partitions, but other stuff would
	# have to change for that to work, so not going there right now.
	#
	$vnconfig{"reloadinfo"} = \@tmp;
	#
	# But the image we eventually boot is in jailconfig.
	# Sheesh, LVM names cannot include comma or colon. 
	#
	if (VNCONFIG('IMAGENAME') =~ /^([-\w]+),([-\w]+),([-\w\.]+)$/) {
	    $vnconfig{"image"}      = "$1-$2-$3";
	}
	elsif (VNCONFIG('IMAGENAME') =~ /^([-\w]+),([-\w]+),([^:]+):(\d+)$/) {
	    $vnconfig{"image"}      = "$1-$2-$3-$4";
	}
	else {
	    fatal("vnode $vnodeid in reloading, but got bogus IMAGENAME " . 
		   VNCONFIG('IMAGENAME') . " from jailconf!");
	}
	#
	# Apply the same transform to each loadinfo so that we do not have
	# duplicate it in the library,
	#
	foreach my $ref (@tmp) {
	    if ($ref->{'IMAGEID'} =~ /^([-\w]+),([-\w]+),([-\w\.]+)$/) {
		$ref->{'IMAGENAME'} = "$1-$2-$3";
	    }
	    elsif ($ref->{'IMAGEID'} =~ /^([-\w]+),([-\w]+),([^:]+):(\d+)$/) {
		$ref->{'IMAGENAME'} = "$1-$2-$3-$4";
	    }
	    else {
		fatal("Bad IMAGEID in loadinfo");
	    }
	}
    }
    elsif ($tmp[0]->{"WHAT"} =~ /^\d*$/) {
	#
	# We are using bootwhat for a much different purpose then intended.
	# It tells us a partition number, but that is meaningless. Look at
	# the jailconfig to see what image should boot. That image better
	# be resident already. 
	#
	# Sheesh, LVM names cannot include comma or colon.
	#
	if (VNCONFIG('IMAGENAME') =~ /^([-\w]+),([-\w]+),([-\w\.]+)$/) {
	    $vnconfig{"image"}      = "$1-$2-$3";
	}
	elsif (VNCONFIG('IMAGENAME') =~ /^([-\w]+),([-\w]+),([^:]+):(\d+)$/) {
	    $vnconfig{"image"}      = "$1-$2-$3-$4";
	}
    }
    else {
	# The library will boot the default, whatever that is.
    }
}

if ($debug) {
    print "VN Config:\n";
    print Dumper(\%vnconfig);
}

#
# Install a signal handler. We can get signals from vnodesetup.
#
sub handler ($) {
    my ($signame) = @_;

    print STDERR "mkvnode ($PID) caught a SIG${signame}!\n";

    # No more interruptions during teardown.
    $SIG{INT}  = 'IGNORE';
    $SIG{USR1} = 'IGNORE';
    $SIG{USR2} = 'IGNORE';
    $SIG{HUP}  = 'IGNORE';

    my $str = "killed";
    if ($signame eq 'HUP') {
	$leaveme = $LEAVEME_HALT;
	$str = "halted";
    }
    elsif ($signame eq 'USR2') {
	$leaveme = $LEAVEME_REBOOT;
	$str = "rebooted";
    }

    #
    # XXX this is a woeful hack for vnodesetup.  At the end of rebootvnode,
    # vnodesetup calls hackwaitandexit which essentially waits for a vnode
    # to be well on the way back up before it returns.  This call was
    # apparently added for the lighter-weight "reconfigure a vnode"
    # (as opposed to reboot it) path, however it makes the semantics of
    # reboot on a vnode different than that for a pnode, where reboot returns
    # as soon as the node stops responding (i.e., when it goes down and not
    # when it comes back up).  Why do I care?  Because Xen vnodes cannot
    # always "reboot" under the current semantics in less than 30 seconds,
    # which is the timeout in libreboot.
    #
    # So by touching the "running" file here we force hackwaitandexit to
    # return when the vnode is shutdown in Xen (or OpenVZ), more closely
    # matching the pnode semantics while leaving the BSD jail case (which
    # doesn't use this code) alone.  This obviously needs to be revisited.
    #
    mysystem("touch $RUNNING_FILE")
	if ($leaveme && -e "$RUNNING_FILE");

    print STDERR "Container is being $str\n";
    MyFatal("Container has been $str by $signame");
}

#
# If this file exists, we are rebooting an existing container. But
# need to check if its a stale or aborted container (one that failed
# to setup or teardown) and got left behind. Another wrinkle is shared
# nodes, so we use the node uuid to determine if its another logical
# pcvm with the same name, and needs to be destroyed before setting up.
#
if (-e "$VNDIR/vnode.info") {
    my $uuid;
    my $teardown = 0;

    my $str = `cat $VNDIR/vnode.info`;
    ($vmid, $vmtype, $uuid) = ($str =~ /^(\d*) (\w*) ([-\w]*)$/);

    # Consistency check.
    fatal("No matching file: $VMPATH/vnode.$vmid")
	if (! -e "$VMPATH/vnode.$vmid");
    $str = `cat $VMPATH/vnode.$vmid`;
    chomp($str);
    if ($str ne $vnodeid) {
	fatal("Inconsistent vnodeid in $VMPATH/vnode.$vmid");
    }

    if ($uuid ne $nodeuuid) {
	print "UUID mismatch; tearing down stale vnode $vnodeid\n";
	$teardown = 1;
    }
    elsif ($reload) {
	print "Reload requested, tearing down old vnode\n";
	$teardown = 1;
    }
    else {
	# We (might) need this to discover the state. 
	local $vnstate = { "private" => {} };
	
	if (-e "$VNDIR/vnode.state") {
	    my $tmp = eval { Storable::retrieve("$VNDIR/vnode.state"); };
	    if ($@) {
		print STDERR "$@";
		$teardown = 1;
	    }
	    else {
		$vnstate->{'private'} = $tmp->{'private'};
	    }
	}
	($ret,$err) = safeLibOp('vnodeState', 1, 0, 1);
	if ($err) {
	    fatal("Failed to get status for existing container: $err");
	}
	if ($ret eq VNODE_STATUS_UNKNOWN()) {
	    print "Cannot determine status container $vmid. Deleting ...\n";
	    $teardown = 1;
	}
	elsif ($ret eq VNODE_STATUS_MOUNTED()) {
	    print("vnode $vnodeid still mounted. Unmounting then restarting\n");
	    $teardown = 1;
	    $leaveme  = $LEAVEME_REBOOT;
	}
	elsif ($ret ne VNODE_STATUS_STOPPED()) {
	    fatal("vnode $vnodeid not stopped, not booting!");
	}
    }
    if ($teardown) {
	if (TearDownStaleVM()) {
	    #
	    # This really sucks. We have to be careful that the caller
	    # (vnodesetup) does not remove the data directory, or else
	    # we will not be able to come back here next time for cleanup.
	    #
	    print STDERR "Could not tear down stale container\n";
	    exit(1);
	}
	# See MOUNTED case above; we set leaveme to keep the container
	# file systems, but must reset leaveme. 
	$leaveme = 0;
    }
    else {
	$rebooting = 1;
    }
}

#
# Install handlers *after* down stale container teardown, since we set
# them to IGNORE during the teardown.
# 
# Ignore TERM since we want our caller to catch it first and then send
# it down to us. 
#
$SIG{TERM} = 'IGNORE';
# Halt container and exit. Tear down transient state, leave disk.
$SIG{HUP} = \&handler;
# Halt container and exit. Leave all state intact (we are rebooting).
$SIG{USR2} = \&handler;
# Halt container and exit. Tear down all state including disk.
$SIG{USR1}  = \&handler;
$SIG{INT}  = \&handler;

#
# Initial pre config for the experimental network. We want to make sure
# we can allocate the required devices and whatever else before going
# any further. 
#
TBDebugTimeStampWithDate("starting rootPreConfigNetwork()");
$ret = eval {
    $libops{GENVNODETYPE()}{'rootPreConfigNetwork'}->($vnodeid, undef,
	\%vnconfig, $vnstate->{'private'});
};
if ($ret || $@) {
    print STDERR $@
	if ($@);
    
    # If this fails, we require the library to clean up after itself
    # so that we can just exit without worrying about cleanup.
    fatal("rootPreConfigNetwork failed!");
}
TBDebugTimeStampWithDate("finished rootPreConfigNetwork()");

if (! -e "$VNDIR/vnode.info") {
    #
    # XXX XXX XXX: need to get this from tmcd!
    # NOTE: we first put the type into vndb so that the create call can go!
    #
    $vmtype = GENVNODETYPE();

    #
    # Manually block signals for vnodeCreate, because we are vulnerable
    # to a race after we successfully create a vnode, until we have
    # written the vnode.info, $vnodeid files, and our state.
    #
    my $sigset;
    blockOurSignals(\$sigset);
    ($ret,$err) = safeLibOp('vnodeCreate',0,0,1);
    if ($err) {
	MyFatal("vnodeCreate failed: $err");
    }
    $vmid = $ret;

    mysystem("echo '$vmid $vmtype $nodeuuid' > $VNDIR/vnode.info");
    mysystem("echo '$vnodeid' > $VMPATH/vnode.$vmid");

    # bootvnodes wants this to be here...
    mysystem("mkdir -p /var/emulab/jails/$vnodeid");

    # Store the state to disk.
    if (StoreState()) {
	MyFatal("Could not store container state to disk");
    }

    # Ok, now safe to unblock our signals; we're consistent.
    unblockOurSignals($sigset);
}
else {
    #
    # Restore the state and throw away the private data. 
    #
    if (-e "$VNDIR/vnode.state") {
	my $tmp = eval { Storable::retrieve("$VNDIR/vnode.state"); };
	if ($@) {
	    print STDERR "$@";
	}
	else {
	    # Restore this from the saved state for vnodepreconfig.
	    $vnstate->{'private'}->{'os'} = $tmp->{'os'}
	        if (exists($tmp->{'os'}));
	    $vnstate->{'private'}->{'rootpartition'} = $tmp->{'rootpartition'}
	        if (exists($tmp->{'rootpartition'}));
	    $vnstate->{'private'}->{'ishvm'} = $tmp->{'ishvm'}
	        if (exists($tmp->{'ishvm'}));
	}
    }
}
# This state structure is saved to disk for TearDown and Reboot.
$vnstate->{"vmid"}   = $vmid;
$vnstate->{"vmtype"} = $vmtype;
$vnstate->{"uuid"}   = $nodeuuid;
# Save this for reboot. 
$vnstate->{'os'} = $vnstate->{'private'}->{'os'}
    if (exists($vnstate->{'private'}->{'os'}));
$vnstate->{'rootpartition'} = $vnstate->{'private'}->{'rootpartition'}
    if (exists($vnstate->{'private'}->{'rootpartition'}));
$vnstate->{'ishvm'} = $vnstate->{'private'}->{'ishvm'}
    if (exists($vnstate->{'private'}->{'ishvm'}));

# Store the state to disk.
if (StoreState()) {
    MyFatal("Could not store container state to disk");
}

my $cnet_mac = (defined(VNCONFIG('CTRLMAC')) ?
		VNCONFIG('CTRLMAC') : ipToMac(VNCONFIG('CTRLIP')));
my $ext_ctrlip = `cat $CTRLIPFILE`;
chomp($ext_ctrlip);
if ($ext_ctrlip !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
    # cannot/should not really go on if this happens.
    MyFatal("error prior to vnodePreConfigControlNetwork($vnodeid): " . 
	    " could not find valid ip in $CTRLIPFILE!");
}
my $longdomain = "${eid}.${pid}.${DOMAINNAME}";

#
# Call back to do things to the container before it boots.
#
sub callback($)
{
    my ($path) = @_;

    #
    # Set up sshd port to listen on. If the vnode has its own IP
    # then listen on both 22 and the per-vnode port.
    #
    if (defined(VNCONFIG('SSHDPORT')) && VNCONFIG('SSHDPORT') ne "") {
	my $sshdport = VNCONFIG('SSHDPORT');

	mysystem2("echo '# EmulabJail' >> $path/etc/ssh/sshd_config");
	mysystem2("echo 'Port $sshdport' >> $path/etc/ssh/sshd_config");
	if (VNCONFIG('CTRLIP') ne $ext_ctrlip) {
	    mysystem2("echo 'Port 22' >> $path/etc/ssh/sshd_config");
	}
	mysystem2("echo '# EndEmulabJail' >> $path/etc/ssh/sshd_config");
    }
    # Localize the timezone.
    mysystem2("cp -fp /etc/localtime $path/etc");

    return 0;
}

# OP: preconfig
if (safeLibOp('vnodePreConfig', 1, 1, 1, \&callback)) {
    MyFatal("vnodePreConfig failed");
}

# OP: control net preconfig
if (safeLibOp('vnodePreConfigControlNetwork',1,1,1,
	      VNCONFIG('CTRLIP'),
	      VNCONFIG('CTRLMASK'),$cnet_mac,
	      $ext_ctrlip,$vname,$longdomain,$DOMAINNAME,$BOSSIP)) {
    MyFatal("vnodePreConfigControlNetwork failed");
}

# OP: exp net preconfig
if (safeLibOp('vnodePreConfigExpNetwork', 1, 1, 1)) {
    MyFatal("vnodePreConfigExpNetwork failed");
}
if (safeLibOp('vnodeConfigResources', 1, 1, 1)) {
    MyFatal("vnodeConfigResources failed");
}
if (safeLibOp('vnodeConfigDevices', 1, 1, 1)) {
    MyFatal("vnodeConfigDevices failed");
}

#
# Route to inner ssh, but not if the IP is routable, no need to.
# We don't do this in this wrapper for Docker, because Docker handles it
# differently.
#
if (defined(VNCONFIG('SSHDPORT')) && VNCONFIG('SSHDPORT') ne "" &&
    !$ISDOCKERVM &&
    !isRoutable(VNCONFIG('CTRLIP'))) {
    my $ref = {};
    $ref->{'ext_ip'}   = $ext_ctrlip;
    $ref->{'ext_port'} = VNCONFIG('SSHDPORT');
    $ref->{'int_ip'}   = VNCONFIG('CTRLIP');
    $ref->{'int_port'} = VNCONFIG('SSHDPORT');
    $ref->{'protocol'} = "tcp";
    
    $vnstate->{'sshd_iprule'} = $ref
	if (libvnode::forwardPort($ref) == 0);
}

#
# Start the container. If all goes well, this will exit cleanly, with 
# it running in its new context. Still, lets protect it with a timer
# since it might get hung up inside and we do not want to get stuck here.
#
my $needschildmon;
if (!$ISXENVM) {
    $needschildmon = 1;
}
else {
    $needschildmon = 0;
}
if ($needschildmon) {
    my $childpid = fork();
    if ($childpid) {
	my $timedout = 0;
	local $SIG{ALRM} = sub { kill("TERM", $childpid); $timedout = 1; };
	alarm 180;
	waitpid($childpid, 0);
	alarm 0;

	#
	# If failure then cleanup.
	#
	if ($? || $timedout) {
	    MyFatal("$vnodeid container startup ".
		    ($timedout ? "timed out." : "failed."));
	}
    }
    else {
	#
	# We want to call this as clean as possible.
	#
	$SIG{TERM} = 'DEFAULT';
	$SIG{INT}  = 'DEFAULT';
	$SIG{USR1} = 'DEFAULT';
	$SIG{USR2} = 'DEFAULT';
	$SIG{HUP}  = 'DEFAULT';
	POSIX::setsid();

	if ($libops{$vmtype}{"vnodeBoot"}->($vnodeid, $vmid,
					    \%vnconfig, $vnstate->{'private'})){
	    print STDERR "*** ERROR: vnodeBoot failed\n";
	    exit(1);
	}
	# NB: store the state, so that vnodeBoot too has writable $private!
	if (StoreState()) {
	    MyFatal("Could not store container state to disk");
	}
	exit(0);
    }
}
elsif (safeLibOp('vnodeBoot', 1, 1, 1)) {
    MyFatal("$vnodeid container startup failed.");
}
if ($needschildmon) {
    # NB: before continuing, read the state stored in the child above
    # after vnodeBoot!
    if (ReadState()) {
	MyFatal("Could not read container state from disk after vnodeBoot");
    }
}
if (safeLibOp('vnodePostConfig', 1, 1, 1)) {
    MyFatal("vnodePostConfig failed");
}
# XXX: need to do this for each type encountered!
TBDebugTimeStampWithDate("starting $vmtype rootPostConfig()");
$libops{$vmtype}{'rootPostConfig'}->();
TBDebugTimeStampWithDate("finished $vmtype rootPostConfig()");

if ($debug) {
    print "VN State:\n";
    print Dumper($vnstate);
}

# Store the state to disk.
if (StoreState()) {
    MyFatal("Could not store container state to disk");
}
# This is for vnodesetup
mysystem("touch $RUNNING_FILE");
$running = 1;

#
# Poll as desired by the backend.  See comments below for
# BackendVnodePoll() and DefaultVnodePoll().
#
if (hasLibOp("vnodePoll")) {
    BackendVnodePoll();
}
else {
    DefaultVnodePoll();
}
exit(CleanupVM());

#
# Invoke the backend to poll the vnode for status changes that mkvnode
# should/must respond to.  This means that honoring the
# vnodesetup/mkvnode semantics is now in the hands of the backend, if it
# wants.  For instance, the backend can choose to allow this mkvnode
# monitor to continue waiting even if the vnode is stopped for long
# periods of time.
#
# (More recently, other backends (Docker) require that we catch VM state
# transitions more frequently than this loop allows.  Note the special
# case in the loop where there's a 15-second special case check to see
# if a Xen VM was reoboted from the inside, and ends up restarting
# successfully.  To handle these kinds of special cases, it's no problem
# to allow backends to control the loop; if we are interrupted via
# signal, and are supposed to be cleaning = 1 or whatever, we just don't
# call vnodePoll again (and just call vnodeState a final couple times),
# as in the original loop.  As long as backends don't override our
# signal handlers, we're good to follow the original semantics of
# vnodesetup/mkvnode.  We can also modify the semantics slightly,
# i.e. to allow the mkvnode monitor to hang around even if the vnode is
# down (like if the user manually invokes `docker stop`).
#
sub BackendVnodePoll()
{
    while (1) {
	my ($status,$event) = ('','');

	my $ret = eval {
	    $libops{$vmtype}{'vnodePoll'}->($vnodeid, $vmid,
					    \%vnconfig, $vnstate->{'private'},
					    \$status,\$event);
	};
	my $err = $@;
	if ($err) {
	    fatal("*** ERROR: vnodePoll: $err\n");
	    return (-1,$err);
	}

	if ($ret == libgenvnode::VNODE_POLL_STOP()) {
	    TBDebugTimeStamp("vnodePoll told us to stop polling; cleaning up!");
	    last;
	}
	elsif ($ret == libgenvnode::VNODE_POLL_ERROR()) {
	    TBDebugTimeStamp("vnodePoll errored ($err); cleaning up!".
			     " status=$status, event=$event");
	    last;
	}
	else {
	    TBDebugTimeStamp("vnodePoll told us to continue polling;".
			     " status=$status, event=$event");
	}
    }
}

#
# The default polling implementation.
#
# This loop is to catch when the container stops. We used to run a sleep
# inside and wait for it to exit, but that is not portable across the
# backends, and the return value did not indicate how it exited. So, lets
# just loop, asking for the status every few seconds.
#
sub DefaultVnodePoll()
{
    # XXX Turn off debugging during this loop to keep the log file from
    # growing.
    TBDebugTimeStampsOff()
	if ($debug);

    while (1) {
	sleep(5);
    
	#
	# If the container exits, either it rebooted from the inside or
	# the physical node is rebooting, or we are actively trying to kill
	# it cause our parent (vnodesetup) told us to. In all cases, we just
	# exit and let the parent decide what to do. 
	#
	my ($ret,$err) = safeLibOp('vnodeState', 0, 0, 1);
	if ($err) {
	    fatal("*** ERROR: vnodeState: $err\n");
	}
	if ($ret ne VNODE_STATUS_RUNNING()) {
	    print "Container is no longer running.\n";
	    if (!$cleaning) {
		#
		# Rebooted from inside, but not cause we told it to, so
		# leave intact.
		#
		# But before we fold, lets wait a moment and check again
		# since in XEN, the user can type reboot, which causes the
		# domain to disappear for a while. We do not want to be
		# fooled by that. Halt is another issue; if the user halts
		# from inside the container it is never coming back and the 
		# user has screwed himself. Need to restart from the frontend.
		#
		sleep(15);
		($ret,$err) = safeLibOp('vnodeState', 0, 0, 1);
		if ($err) {
		    fatal("*** ERROR: vnodeState: $err\n");
		}
		if ($ret eq VNODE_STATUS_RUNNING()) {
		    print "Container has restarted itself.\n";
		    next;
		}
		$leaveme = $LEAVEME_REBOOT;
	    }
	    last;
	}
    }

    TBDebugTimeStampsOn()
	if ($debug);
}

#
# Teardown a container. This should not be used if the mkvnode process
# is still running; use vnodesetup instead. This is just for the case
# that the manager (vnodesetup,mkvnode) process is gone and the turds
# need to be cleaned up.
#
sub TearDownStaleVM()
{
    if (! -e "$VNDIR/vnode.info") {
	fatal("TearDownStaleVM: no vnode.info file for $vnodeid");
    }
    my $str = `cat $VNDIR/vnode.info`;
    ($vmid, $vmtype, undef) = ($str =~ /^(\d*) (\w*) ([-\w]*)$/);

    #
    # Load the state. Use a local so that we do not overwrite
    # the outer version. Just a precaution.
    #
    # The state might not exist, but we proceed anyway.
    #
    local $vnstate = { "private" => {} };

    if (-e "$VNDIR/vnode.state") {
	$vnstate = eval { Storable::retrieve("$VNDIR/vnode.state"); };
	if ($@) {
	    print STDERR "$@";
	    return -1;
	}
	if ($debug) {
	    print "vnstate:\n";
	    print Dumper($vnstate);
	}
    }

    # No interruptions during stale teardown.
    $SIG{INT}  = 'IGNORE';
    $SIG{USR1} = 'IGNORE';
    $SIG{USR2} = 'IGNORE';
    $SIG{HUP}  = 'IGNORE';

    #
    # if we fail to cleanup, store the state back to disk so that we
    # capture any changes. 
    #
    if (CleanupVM()) {
	StoreState();
	return -1;
    }
    $SIG{INT}  = 'DEFAULT';
    $SIG{USR1} = 'DEFAULT';
    $SIG{USR2} = 'DEFAULT';
    $SIG{HUP}  = 'DEFAULT';
    
    return 0;
}

#
# Clean things up.
#
sub CleanupVM()
{
    if ($cleaning) {
	die("*** $0:\n".
	    "    Oops, already cleaning!\n");
    }
    $cleaning = 1;

    # If the container was never built, there is nothing to do.
    return 0
	if (! -e "$VNDIR/vnode.info" || !defined($vmid));

    if (exists($vnstate->{'sshd_iprule'})) {
	my $ref = $vnstate->{'sshd_iprule'};
	libvnode::removePortForward($ref);
	# Update new state.
	delete($vnstate->{'sshd_iprule'});
	StoreState();
    }

    #
    # The tmcc proxy causes teardown problems, no idea why.
    # It used to be kill off from the unmount script, but lets
    # do it here.
    #
    my $PROXYPID = "/var/run/tmccproxy.${vnodeid}.pid";
    if (-e $PROXYPID) {
	my $ppid = `cat $PROXYPID`;
	chomp($ppid);
	# untaint
	if ($ppid =~ /^([-\@\w.]+)$/) {
	    $ppid = $1;
	}
	if (kill('TERM', $ppid) == 0) {
	    print"*** ERROR: Could not kill(TERM) proxy process $ppid: $!\n";
	}
	else {
	    unlink($PROXYPID);
	}
    }

    # If we might have been polling, make sure that is cleaned up.
    if (hasLibOp("vnodePollCleanup")) {
	safeLibOp("vnodePollCleanup",1,0,1);
    }

    # if not halted, try that first
    my ($ret,$err) = safeLibOp('vnodeState', 1, 0, 1);
    if ($err) {
	print STDERR "*** ERROR: vnodeState: ".
	    "failed to cleanup $vnodeid: $err\n";
	return -1;
    }
    if ($ret eq VNODE_STATUS_RUNNING()) {
	print STDERR "cleanup: $vnodeid not stopped, trying to halt it.\n";
	($ret,$err) = safeLibOp('vnodeHalt', 1, 1, 1);
	if ($err) {
	    print STDERR "*** ERROR: vnodeHalt: ".
		"failed to halt $vnodeid: $err\n";
	    return -1;
	}
    }
    elsif ($ret eq VNODE_STATUS_MOUNTED()) {
	print STDERR "cleanup: $vnodeid is mounted, trying to unmount it.\n";
	($ret,$err) = safeLibOp('vnodeUnmount', 1, 1, 1);
	if ($err) {
	    print STDERR "*** ERROR: vnodeUnmount: ".
		"failed to unmount $vnodeid: $err\n";
	    return -1;
	}
    }
    if ($leaveme) {
	if ($leaveme == $LEAVEME_HALT || $leaveme == $LEAVEME_REBOOT) {
	    #
	    # When halting, the disk state is left, but the transient state
	    # is removed since it will get reconstructed later if the vnode
	    # is restarted. This avoids leaking a bunch of stuff in case the
	    # vnode never starts up again. We of course leave the disk, but
	    # that will eventually get cleaned up if the pcvm is reused for
	    # a future experiment.
	    #
	    # XXX Reboot should be different; there is no reason to tear
	    # down the transient state, but we do not handle that yet.
	    # Not hard to add though.
	    #
	    ($ret,$err) = safeLibOp('vnodeTearDown', 1, 1, 1);
	    # Always store in case some progress was made. 
	    StoreState();
	    if ($err) {
		print STDERR "*** ERROR: failed to teardown $vnodeid: $err\n";
		return -1;
	    }
	}
	return 0;
    }

    # now destroy
    ($ret,$err) = safeLibOp('vnodeDestroy', 1, 1, 1);
    if ($err) {
	print STDERR "*** ERROR: failed to destroy $vnodeid: $err\n";
	return -1;
    }
    unlink("$VNDIR/vnode.info");
    unlink("$VNDIR/vnode.state");
    unlink("$VMPATH/vnode.$vmid");
    $cleaning = 0;
    return 0;
}
    
#
# Print error and exit.
#
sub MyFatal($)
{
    my ($msg) = @_;

    #
    # If rebooting but never got a chance to run, we do not want
    # to kill off the container. Might lose user data.
    #
    $leaveme = $LEAVEME_REBOOT
	if ($rebooting && !$running);

    TBDebugTimeStampsOn()
	if ($debug);
    
    CleanupVM();
    die("*** $0:\n".
	"    $msg\n");
}

#
# Helpers:
#
sub hasLibOp($) {
    my ($op,) = @_;

    return 1
	if (exists($libops{$vmtype}{$op}) && defined($libops{$vmtype}{$op}));

    return 0;
}

sub blockOurSignals($) {
    my ($old_sigset_ref,) = @_;

    my $new_sigset = POSIX::SigSet->new(SIGHUP, SIGINT, SIGUSR1, SIGUSR2);
    $$old_sigset_ref = POSIX::SigSet->new;
    if (! defined(sigprocmask(SIG_BLOCK, $new_sigset, $$old_sigset_ref))) {
	print STDERR "sigprocmask (BLOCK) failed!\n";
	return -1;
    }

    return 0;
}

sub unblockOurSignals($) {
    my ($old_sigset,) = @_;

    if (! defined(sigprocmask(SIG_SETMASK, $old_sigset))) {
	print STDERR "sigprocmask (UNBLOCK) failed!\n";
	return -1;
    }

    return 0;
}

sub safeLibOp($$$$;@) {
    my ($op,$autolog,$autoerr,$blocksigs,@args) = @_;

    my $sargs = '';
    if (@args > 0) {
 	$sargs = join(',',@args);
    }
    TBDebugTimeStampWithDate("starting $vmtype $op($sargs)")
	if ($debug);

    my $old_sigset;
    if ($blocksigs) {
	#
	# Block signals that could kill us in the middle of a library call.
	# Might be better to do this down in the library, but this is an
	# easier place to do it. This ensure that if we have to tear down
	# in the middle of setting up, the state is consistent. 
	#
	blockOurSignals(\$old_sigset);
    }
    my $ret = eval {
	$libops{$vmtype}{$op}->($vnodeid, $vmid,
				\%vnconfig, $vnstate->{'private'}, @args);
    };
    my $err = $@;
    if ($blocksigs) {
	unblockOurSignals($old_sigset);
    }
    if ($err) {
	if ($autolog) {
	    ;
	}
	TBDebugTimeStampWithDate("failed $vmtype $op($sargs): $err")
	    if ($debug);
	return (-1,$err);
    }
    if ($autoerr && $ret) {
	$err = "$op($vnodeid) failed with exit code $ret!";
	if ($autolog) {
	    ;
	}
	TBDebugTimeStampWithDate("failed $vmtype $op($sargs): exited with $ret")
	    if ($debug);
	return ($ret,$err);
    }

    TBDebugTimeStampWithDate("finished $vmtype $op($sargs)")
	if ($debug);

    return $ret;
}

sub StoreState()
{
    # Store the state to disk.
    print "Storing state to disk ...\n"
	if ($debug);
    
    my $ret = eval { Storable::store($vnstate, "$VNDIR/vnode.state"); };
    if ($@) {
	print STDERR "$@";
	return -1;
    }
    return 0;
}

sub ReadState()
{
    # Read the state from disk.
    print "Reading state from disk ...\n"
	if ($debug);

    my $ret = eval { $vnstate = Storable::retrieve("$VNDIR/vnode.state"); };
    if ($@) {
	print STDERR "$@";
	return -1;
    }

    return 0;
}
