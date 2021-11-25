#!/usr/bin/perl -w

#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
# TODO: Signal handlers for protecting db files.

#
# Common routines and constants for the client bootime setup stuff.
#
package libsetup;
use Exporter;
@ISA = "Exporter";
@EXPORT =
    qw ( libsetup_init libsetup_setvnodeid libsetup_settimeout cleanup_node
	 getifconfig getrouterconfig gettrafgenconfig gettunnelconfig
	 check_nickname	bootsetup startcmdstatus whatsmynickname
	 TBForkCmd vnodejailsetup plabsetup vnodeplabsetup
	 jailsetup dojailconfig findiface libsetup_getvnodeid
	 ixpsetup libsetup_refresh gettopomap getfwconfig gettiptunnelconfig
	 gettraceconfig genhostsfile getmotelogconfig calcroutes fakejailsetup
	 getlocalevserver genvnodesetup getgenvnodeconfig stashgenvnodeconfig
         getlinkdelayconfig getloadinfo getbootwhat getnodeattributes
	 copyfilefromnfs getnodeuuid getarpinfo
	 getstorageconfig getstoragediskinfo getimagesize
         getrcmanifest fetchrcmanifestblobs runbootscript runhooks 
         build_fake_macs getenvvars getpnetnodeattrs
         sortedlistallfilesindir sortedreadallfilesindir genhostslistfromtopo

	 TBDebugTimeStamp TBDebugTimeStampWithDate
	 TBDebugTimeStampsOn TBDebugTimeStampsOff

	 MFS REMOTE REMOTEDED CONTROL FSNODE WINDOWS JAILED PLAB LOCALROOTFS
	 IXP USESFS SHADOW FSRVTYPE PROJDIR EXPDIR

	 SIMTRAFGEN SIMHOST ISDELAYNODEPATH JAILHOST DELAYHOST STARGATE
	 ISFW FAKEJAILED LINUXJAILED GENVNODE GENVNODETYPE GENVNODEHOST
	 SHAREDHOST SUBBOSS STORAGEHOST

	 CONFDIR LOGDIR TMDELAY TMBRIDGES TMJAILNAME TMSIMRC TMCC TMCCBIN
	 TMNICKNAME TMSTARTUPCMD FINDIF
	 TMROUTECONFIG TMLINKDELAY TMDELMAP
	 TMTOPOMAP TMLTMAP TMLTPMAP TMLTMAPGZ TMLTPMAPGZ
	 TMGATEDCONFIG TMSYNCSERVER TMKEYHASH TMNODEID TMNODEUUID TMEVENTKEY
	 TMCREATOR TMSWAPPER TMFWCONFIG TMGENVNODECONFIG
	 TMSTORAGEMAP TMDISKINFO TMEXTRAFS
	 INXENVM INVZVM INDOCKERVM TMNODETYPE
       );

# Must come after package declaration!
use English;
use Errno;

my $debug = 0;

# The tmcc library.
use libtmcc;
use librc;

#
# This is the VERSION. We send it through to tmcd so it knows what version
# responses this file is expecting.
#
# BE SURE TO BUMP THIS AS INCOMPATIBILE CHANGES TO TMCD ARE MADE!
#
# IMPORTANT NOTE: if you change the version here, you must also change it
# in clientside/lib/tmcd/tmcd.h!
#
sub TMCD_VERSION()	{ 44; };
libtmcc::configtmcc("version", TMCD_VERSION());

# Control tmcc timeout.
sub libsetup_settimeout($) { libtmcc::configtmcc("timeout", $_[0]); };

# Refresh tmcc cache.
sub libsetup_refresh()	   { libtmcc::tmccgetconfig(); };

#
# For virtual (multiplexed nodes). If defined, tack onto tmcc command.
# and use in pathnames. Used in conjunction with jailed virtual nodes.
# I am also using this for subnodes; eventually everything will be subnodes.
#
my $vnodeid;
sub libsetup_setvnodeid($)
{
    my ($vid) = @_;

    if ($vid =~ /^([-\w]+)$/) {
	$vid = $1;
    }
    else {
	die("Bad data in vnodeid: $vid");
    }

    $vnodeid = $vid;
    libtmcc::configtmcc("subnode", $vnodeid);
}
sub libsetup_getvnodeid()
{
    return $vnodeid;
}

#
# True if running inside a jail. Set just below.
#
my $injail;

#
# True if $injail == TRUE and running on Linux.
# Right now this means vserves on RHL.
#
my $inlinuxjail;

#
# True if running inside a vm.
#
my $ingenvnode;

#
# True if running as a fake jail (no jail, just processes).
#
my $nojail;

#
# True if running in a Plab vserver.
#
my $inplab;

#
# Ditto for IXP, although currently there is no "in" IXP setup; it
# is all done from outside.
#
my $inixp;

#
# Shadow mode. Run the client side against a remote tmcd.
#
my $shadow;
my $SHADOWDIR = "$VARDIR/shadow";

#
# Fileserver type.
# Default is "racy NFS" (the historical only choice) until proven otherwise
# (via "mounts" tmcc call).
#
my $fsrvtype = "NFS-RACY";

#
# The role of this pnode
#
my $role;

# Load up the paths. Its conditionalized to be compatabile with older images.
# Note this file has probably already been loaded by the caller.
BEGIN
{
    if (! -e "/etc/emulab/paths.pm") {
	die("Yikes! Could not require /etc/emulab/paths.pm!\n");
    }
    require "/etc/emulab/paths.pm";
    import emulabpaths;
    $SHADOWDIR = "$VARDIR/shadow";

    # Make sure these exist! They will not exist on a PLAB vserver initially.
    mkdir("$VARDIR", 0775);
    mkdir("$VARDIR/jails", 0775);
    mkdir("$VARDIR/vms", 0775);
    mkdir("$VARDIR/db", 0755);
    mkdir("$VARDIR/logs", 0775);
    mkdir("$VARDIR/boot", 0775);
    mkdir("$VARDIR/lock", 0775);
    mkdir("$SHADOWDIR", 0775);
    mkdir("$SHADOWDIR/db", 0755);
    mkdir("$SHADOWDIR/logs", 0775);
    mkdir("$SHADOWDIR/boot", 0775);
    mkdir("$SHADOWDIR/lock", 0775);

    #
    # Shadow mode allows the client side to run against remote tmcd.
    #
    if (exists($ENV{'SHADOW'})) {
	$shadow = $ENV{'SHADOW'};
	my ($server,$idkey) = split(',', $shadow);
	#
	# Need to taint check these to avoid breakage later.
	#
	if ($server =~ /^([-\w\.]+)$/) {
	    $server = $1;
	}
	else {
	    die("Bad data in server: $server");
	}
	if ($idkey =~ /^([-\w\+\:\.]*)$/) {
	    $idkey = $1;
	}
	else {
	    die("Bad data in urn: $idkey");
	}

	# The cache needs to go in a difference location.
	libtmcc::configtmcc("cachedir", $SHADOWDIR);
	libtmcc::configtmcc("server", $server);
	libtmcc::configtmcc("idkey", $idkey);
	# No proxy.
	libtmcc::configtmcc("noproxy", 1);
    }
    #
    # Determine if running inside a jail. This affects the paths below.
    #
    if (-e "$BOOTDIR/jailname") {
	open(VN, "$BOOTDIR/jailname");
	my $vid = <VN>;
	close(VN);

	libsetup_setvnodeid($vid);
	$injail = 1;
	if ($^O eq "linux") {
	    $inlinuxjail = 1;
	}
    }
    elsif (exists($ENV{'FAKEJAIL'})) {
	# Fake jail.
	libsetup_setvnodeid($ENV{'FAKEJAIL'});
	$nojail = 1;
    }
    elsif (-e "$BOOTDIR/plabname") {
	# Running inside a Plab vserver.
	open(VN, "$BOOTDIR/plabname");
	my $vid = <VN>;
	close(VN);

	libsetup_setvnodeid($vid);
	$inplab = 1;
    }
    elsif (-e "$BOOTDIR/vmname") {
	open(VN, "$BOOTDIR/vmname");
	my $vid = <VN>;
	close(VN);

	libsetup_setvnodeid($vid);
	$ingenvnode = 1;

    }

    $role = "";
    # Get our role.
    if (-e "$BOOTDIR/role") {
	open(VN, "$BOOTDIR/role");
	$role = <VN>;
	close(VN);
	chomp($role);
    }
}

#
# This "local" library provides the OS dependent part.
#
use liblocsetup;

#
# These are the paths of various files and scripts that are part of the
# setup library.
#
sub TMCC()		{ "$BINDIR/tmcc"; }
sub TMCCBIN()		{ "$BINDIR/tmcc.bin"; }
sub FINDIF()		{ "$BINDIR/findif"; }
sub TMUSESFS()		{ "$BOOTDIR/usesfs"; }
sub ISSIMTRAFGENPATH()	{ "$BOOTDIR/simtrafgen"; }
sub ISDELAYNODEPATH()	{ "$BOOTDIR/isdelaynode"; }
sub TMTOPOMAP()		{ "$BOOTDIR/topomap";}
sub TMLTMAP()		{ "$BOOTDIR/ltmap";}
sub TMLTPMAP()		{ "$BOOTDIR/ltpmap";}
sub TMLTMAPGZ()		{ "$BOOTDIR/ltmap.gz";}
sub TMLTPMAPGZ()	{ "$BOOTDIR/ltpmap.gz";}
sub TMSTORAGEMAP()	{ "$BOOTDIR/storagemap";}
sub TMDISKINFO()	{ "$BOOTDIR/diskinfo";}
sub TMEXTRAFS()		{ "$BOOTDIR/extrafs";}

#
# This path is valid only *outside* the jail when its setup.
#
sub JAILDIR()		{ "$VARDIR/jails/$vnodeid"; }

#
# This path is valid only *outside* the vm.  Sucks, but this is the best we
# can do.  Probably the only way to make this vm-specific if necessary is to
# have them create their dir and symlink.
#
sub GENVNODEDIR()	{ "$VARDIR/vms/$vnodeid"; }

#
# XXX: eventually this needs to come from tmcd, but that's not ready yet.
#
sub GENVNODETYPE() {
    if (-e "$ETCDIR/genvmtype") {
	my $vmtype = `cat $ETCDIR/genvmtype`;
	chomp($vmtype);
	return $vmtype;
    }

    return undef;
}

#
# Also valid outside the jail, this is where we put local project storage.
#
sub LOCALROOTFS() {
    return "/users/local"
	if (REMOTE());
    return "$VARDIR/jails/local"
	if (JAILED());
    return "$VARDIR/vms/local"
	if (GENVNODE());
    return "/local";
}

#
# Okay, here is the path mess. There are three environments.
# 1. A local node where everything goes in one place ($VARDIR/boot).
# 2. A virtual node inside a jail or a Plab vserver ($VARDIR/boot).
# 3. A virtual (or sub) node, from the outside.
#
# As for #3, whether setting up a old-style (fake) virtual node or a new style
# jailed node, the code that sets it up needs a different per-vnode path.
#
sub CONFDIR() {
    return "$SHADOWDIR/boot"
	if ($shadow);
    return $BOOTDIR
	if ($injail || $inplab || $ingenvnode);
    return GENVNODEDIR()
	if ($vnodeid && GENVNODETYPE());
    return JAILDIR()
	if ($vnodeid);
    return $BOOTDIR;
}
# Cause of fakejails, we want log files in the right place.
sub LOGDIR() {
    return "$SHADOWDIR/logs"
	if ($shadow);
    return $LOGDIR
	if ($injail || $inplab || $ingenvnode);
    return GENVNODEDIR()
	if ($vnodeid && GENVNODETYPE());
    return JAILDIR()
	if ($vnodeid);
    return $LOGDIR;
}

#
# The rest of these depend on the environment running in (inside/outside jail).
#
sub TMNICKNAME()	{ CONFDIR() . "/nickname";}
sub TMJAILNAME()	{ CONFDIR() . "/jailname";}
sub TMFAKEJAILNAME()	{ CONFDIR() . "/fakejail";}
sub TMJAILCONFIG()	{ CONFDIR() . "/jailconfig";}
sub TMGENVNODECONFIG()  { CONFDIR() . "/genvnodeconfig";}
sub TMSTARTUPCMD()	{ CONFDIR() . "/startupcmd";}
sub TMROUTECONFIG()     { CONFDIR() . "/rc.route";}
sub TMGATEDCONFIG()     { CONFDIR() . "/gated.conf";}
sub TMBRIDGES()		{ CONFDIR() . "/rc.bridges";}
sub TMDELAY()		{ CONFDIR() . "/rc.delay";}
sub TMLINKDELAY()	{ CONFDIR() . "/rc.linkdelay";}
sub TMDELMAP()		{ CONFDIR() . "/delay_mapping";}
sub TMSYNCSERVER()	{ CONFDIR() . "/syncserver";}
sub TMKEYHASH()		{ CONFDIR() . "/keyhash";}
sub TMEVENTKEY()	{ CONFDIR() . "/eventkey";}
sub TMNODEID()		{ CONFDIR() . "/nodeid";}
sub TMNODETYPE()	{ CONFDIR() . "/nodetype";}
sub TMNODEUUID()	{ CONFDIR() . "/nodeuuid";}
sub TMROLE()		{ CONFDIR() . "/role";}
sub TMSIMRC()		{ CONFDIR() . "/rc.simulator";}
sub TMCREATOR()		{ CONFDIR() . "/creator";}
sub TMSWAPPER()		{ CONFDIR() . "/swapper";}
sub TMFWCONFIG()	{ CONFDIR() . "/rc.fw";}

#
# This is a debugging thing for my home network.
#
my $NODE = "";
if (defined($ENV{'TMCCARGS'})) {
    if ($ENV{'TMCCARGS'} =~ /^([-\w\s]*)$/) {
	$NODE .= " $1";
    }
    else {
	die("Tainted TMCCARGS from environment: $ENV{'TMCCARGS'}!\n");
    }
}

# Locals
my $pid		= "";
my $eid		= "";
my $vname	= "";
my $TIMESTAMPS  = 0;

# Allow override from the environment;
if (defined($ENV{'TIMESTAMPS'})) {
    $TIMESTAMPS = $ENV{'TIMESTAMPS'};
}

#
# Any reason NOT to hardwire these?
#
sub PROJDIR() {
    my $p = $pid;
    if (!$p) {
	($p, undef, undef) = check_nickname();
	return ""
	    if (!$p);
    }
    return "/proj/$p";
}

sub EXPDIR() {
    my $p = $pid;
    my $e = $eid;
    if (!$p || !$e) {
	($p, $e, undef) = check_nickname();
	return ""
	    if (!$p || !$e);
    }
    return "/proj/$p/exp/$e";
}

# When on the MFS, we do a much smaller set of stuff.
# Cause of the way the packages are loaded (which I do not understand),
# this is computed on the fly instead of once.
sub MFS()	{ if (-e "$ETCDIR/ismfs") { return 1; } else { return 0; } }

#
# Same for a remote node.
#
sub REMOTE()	{ if (-e "$ETCDIR/isrem") { return 1; } else { return 0; } }

#
# Same for a dedicated remote node.
#
sub REMOTEDED()	{ if (-e "$ETCDIR/isremded") { return 1; } else { return 0; } }

#
# Same for a control node.
#
sub CONTROL()	{ if (-e "$ETCDIR/isctrl") { return 1; } else { return 0; } }

#
# Same for an FS node.
#
sub FSNODE()	{ if (-e "$ETCDIR/isfs") { return 1; } else { return 0; } }

#
# Same for a Windows (CygWinXP) node.
#
# XXX  If you change this, look in libtmcc::tmccgetconfig() as well.
sub WINDOWS()	{ if (-e "$ETCDIR/iscygwin") { return 1; } else { return 0; } }

#
# Same for a stargate/garcia node.
#
sub STARGATE()  { if (-e "$ETCDIR/isstargate") { return 1; } else { return 0; } }

#
# Are we jailed? See above.
#
sub JAILED()	{ if ($injail) { return $vnodeid; } else { return 0; } }
sub FAKEJAILED(){ if ($nojail) { return $vnodeid; } else { return 0; } }
sub LINUXJAILED(){ if ($injail && $inlinuxjail) { return $vnodeid; } else { return 0; } }

#
# Are we using the generic vm abstraction for this vnode?  See above.
#
sub GENVNODE()  { if ($ingenvnode) { return $vnodeid; } else { return 0; } }

#
# Are we on plab?
#
sub PLAB()	{ if ($inplab) { return $vnodeid; } else { return 0; } }

#
# Are we on an IXP
#
sub IXP()	{ if ($inixp) { return $vnodeid; } else { return 0; } }

#
# Are we a firewall node
#
sub ISFW()	{ if (-e TMFWCONFIG()) { return 1; } else { return 0; } }

#
# Are we hosting a simulator or maybe just a NSE based trafgen.
#
sub SIMHOST()   { if ($role eq "simhost") { return 1; } else { return 0; } }
sub SIMTRAFGEN(){ if (-e ISSIMTRAFGENPATH())  { return 1; } else { return 0; } }

#
# Are we a subboss?
#
sub SUBBOSS()   { if ($role eq "subboss") { return 1; } else { return 0; } }

# A jail host?
sub JAILHOST()     { return (($role eq "virthost" ||
			      $role eq "sharedhost") ? 1 : 0); }
sub GENVNODEHOST() { if ($role eq "virthost") { return 1; } else { return 0; }}
sub SHAREDHOST()   { return ($role eq "sharedhost" ? 1 : 0); }
sub STORAGEHOST()  { return ($role eq "storagehost" ? 1 : 0); }

# A delay host?  Either a delay node or a node using linkdelays
sub DELAYHOST()	{ if (-e ISDELAYNODEPATH()) { return 1; } else { return 0; } }

# A shadow?
sub SHADOW()	   { return (defined($shadow) ? 1 : 0); }

#
# Is this node using SFS. Several scripts need to know this.
#
sub USESFS()	{ if (-e TMUSESFS()) { return 1; } else { return 0; } }

#
# What type of fileserver is this node using.  Choices are:
#
# NFS-RACY	FreeBSD NFS server with mountd race (the default)
# NFS		NFS server
# LOCAL		No shared filesystems
#
# XXX should come from tmcd
#
sub FSRVTYPE() {
    if (-e "$BOOTDIR/fileserver") {
	open(FD, "$BOOTDIR/fileserver");
	$fsrvtype = <FD>;
	close(FD);
	chomp($fsrvtype);
    }
    return $fsrvtype;
}

# XXX fer now hack: comes from rc.mounts
sub setFSRVTYPE($) {
    $fsrvtype = shift;
    if (open(FD, ">$BOOTDIR/fileserver")) {
	print FD "$fsrvtype\n";
	close(FD);
    }
}

#
# XXX fernow hack so I can readily identify code that is special to VMs
#
sub INXENVM()	{ return ($ingenvnode && GENVNODETYPE() eq "xen"); }
sub INVZVM()	{ return ($ingenvnode && GENVNODETYPE() eq "openvz"); }
sub INDOCKERVM(){ return ($ingenvnode && GENVNODETYPE() eq "docker"); }

#
# Reset to a moderately clean state.
#
sub cleanup_node ($) {
    my ($scrub) = @_;

    print STDOUT "Cleaning node; removing configuration files\n";
    unlink TMUSESFS, TMROLE, ISSIMTRAFGENPATH, ISDELAYNODEPATH;
    unlink TMSTORAGEMAP, TMDISKINFO;

    #
    # If scrubbing, also remove the password/group files and DBs so
    # that we revert to base set.
    #
    if ($scrub) {
	unlink TMNICKNAME;
	# XXX !scrub allows this to be initialized from outside (libvnode)
	unlink TMEXTRAFS;
    }
}

#
# Check node allocation. If the nickname file has been created, use
# that to avoid load on tmcd.
#
# Returns 0 if node is free. Returns list (pid/eid/vname) if allocated.
#
sub check_status ()
{
    my @tmccresults;

    if (tmcc(TMCCCMD_STATUS, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get status from server!\n");
	return -1;
    }
    #
    # This is possible if the boss node does not now about us yet.
    # We want to appear free. Specifically, it could happen on the
    # MFS when trying to bring in brand new nodes. tmcd will not know
    # anything about us, and return no info.
    #
    return 0
	if (! @tmccresults);

    my $status = $tmccresults[0];

    if ($status =~ /^FREE/) {
	unlink TMNICKNAME;
	return 0;
    }

    if ($status =~ /ALLOCATED=([-\@\w]*)\/([-\@\w]*) NICKNAME=([-\@\w]*)/) {
	$pid   = $1;
	$eid   = $2;
	$vname = $3;
    }
    else {
	warn "*** WARNING: Error getting reservation status\n";
	return -1;
    }

    #
    # Stick our nickname in a file in case someone wants it.
    # Do not overwrite; we want to save the original info until later.
    # See bootsetup; indicates project change!
    #
    if (! -e TMNICKNAME()) {
	system("echo '$vname.$eid.$pid' > " . TMNICKNAME());
    }

    return ($pid, $eid, $vname);
}

#
# Check cached nickname. Its okay if we have been deallocated and the info
# is stale. The node will notice that later.
#
sub check_nickname()
{
    if (-e TMNICKNAME) {
	my $nickfile = TMNICKNAME;
	my $nickinfo = `cat $nickfile`;

	if ($nickinfo =~ /([-\@\w]*)\.([-\@\w]*)\.([-\@\w]*)/) {
	    $vname = $1;
	    $eid   = $2;
	    $pid   = $3;

	    return ($pid, $eid, $vname);
	}
    }
    return check_status();
}

#
# Do SFS hostid setup. If we have an SFS host key and we can get a hostid
# from the SFS daemon, then send it to TMCD.
#
sub initsfs()
{
    my $myhostid;

    # Default to no SFS unless we can determine we have it running.
    unlink TMUSESFS()
	if (-e TMUSESFS());

    # Do I have a host key?
    if (! -e "/etc/sfs/sfs_host_key") {
	return;
    }

    # Give hostid to TMCD
    if (-d "/usr/local/lib/sfs-0.6") {
	$myhostid = `sfskey hostid - 2>/dev/null`;
    }
    else {
	$myhostid = `sfskey hostid -s authserv - 2>/dev/null`;
    }
    if (! $?) {
	if ( $myhostid =~ /^([-\.\w_]*:[a-z0-9]*)$/ ) {
	    $myhostid = $1;
	    print STDOUT "  Hostid: $myhostid\n";
	    tmcc(TMCCCMD_SFSHOSTID, "$myhostid");
	}
	elsif ( $myhostid =~ /^(@[-\.\w_]*,[a-z0-9]*)$/ ) {
	    $myhostid = $1;
	    print STDOUT "  Hostid: $myhostid\n";
	    tmcc(TMCCCMD_SFSHOSTID, "$myhostid");
	}
	else {
	    warn "*** WARNING: Invalid hostid\n";
	    return;
	}
	system("touch " . TMUSESFS());
    }
    else {
	warn "*** WARNING: Could not retrieve this node's SFShostid!\n";
    }
}

#
# Get the role of the node and stash it for future libsetup load.
#
sub dorole()
{
    my @tmccresults;

    if (tmcc(TMCCCMD_ROLE, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get role from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    #
    # There should be just one string. Ignore anything else.
    #
    if ($tmccresults[0] =~ /([\w]*)/) {
	# Storing the value into the global variable
	$role = $1;
    }
    else {
	warn "*** WARNING: Bad role line: $tmccresults[0]";
	return -1;
    }
    system("echo '$role' > " . TMROLE());
    if ($?) {
	warn "*** WARNING: Could not write role to " . TMROLE() . "\n";
    }
    return 0;
}

#
# Get the nodeid
#
sub donodeid()
{
    my $nodeid;
    my @tmccresults;

    # Do this too.
    donodeuuid();
    donodetype();

    if (tmcc(TMCCCMD_NODEID, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get nodeid from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    #
    # There should be just one string. Ignore anything else.
    #
    if ($tmccresults[0] =~ /([-\w]*)/) {
	$nodeid = $1;
    }
    else {
	warn "*** WARNING: Bad nodeid line: $tmccresults[0]";
	return -1;
    }

    system("echo '$nodeid' > ". TMNODEID);
    if ($?) {
	warn "*** WARNING: Could not write nodeid to " . TMNODEID() . "\n";
    }
    return 0;
}

#
# Get the nodetype
#
sub donodetype()
{
    my $nodetype;
    my @tmccresults;

    if (tmcc(TMCCCMD_NODETYPE, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get nodetype from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    #
    # There should be just one string. Ignore anything else.
    #
    if ($tmccresults[0] =~ /([-\w]*)/) {
	$nodetype = $1;
    }
    else {
	warn "*** WARNING: Bad nodetype line: $tmccresults[0]";
	return -1;
    }

    system("echo '$nodetype' > ". TMNODETYPE);
    if ($?) {
	warn "*** WARNING: Could not write nodetype to " . TMNODETYPE() . "\n";
    }
    return 0;
}

#
# Get the nodeuuid
#
sub donodeuuid()
{
    my $nodeuuid;
    my @tmccresults;

    if (tmcc(TMCCCMD_NODEUUID, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get nodeuuid from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    #
    # There should be just one string. Ignore anything else.
    #
    if ($tmccresults[0] =~ /([-\w]*)/) {
	$nodeuuid = $1;
    }
    else {
	warn "*** WARNING: Bad nodeuuid line: $tmccresults[0]";
	return -1;
    }

    system("echo '$nodeuuid' > ". TMNODEUUID);
    if ($?) {
	warn "*** WARNING: Could not write nodeuuid to " . TMNODEUUID() . "\n";
    }
    return 0;
}

sub rcordersort($$) {
    my ($a,$b) = @_;
    my $ca = substr($a,0,1);
    my $cb = substr($b,0,1);
    my $na = ($ca ge '0' && $ca le '9');
    my $nb = ($cb ge '0' && $cb le '9');

    if ($na && $nb) {
	if ($a =~ /^(\d+)/) { $a = $1 }
	if ($b =~ /^(\d+)/) { $b = $1 }
	return int($a) <=> int($b);
    }
    elsif ($na && !$nb) {
	return -1;
    }
    elsif (!$na && $nb) {
	return 1;
    }
    else {
	return $a cmp $b;
    }
}

sub sortedlistallfilesindir($$;$) {
    my ($dir,$rptr,$qualify) = @_;

    my $DIRH;
    my $rc = opendir($DIRH,$dir);
    if (!$rc) {
	return $rc;
    }
    my @files = grep { /^[^\.\#].*[^\~]$/ && -f "$dir/$_" } readdir($DIRH);
    closedir($DIRH);
    my @sfiles = sort rcordersort @files;
    if (defined($qualify) && $qualify != 0) {
	my @tfiles = ();
	for my $file (@sfiles) {
	    push(@tfiles,"$dir/$file");
	}
	@sfiles = @tfiles;
    }
    @$rptr = @sfiles;

    return 0;
}

sub sortedreadallfilesindir($$) {
    my ($dir,$rptr) = @_;

    my @sfiles = ();
    my $rc = sortedlistallfilesindir($dir,\@sfiles,1);
    return $rc if ($rc);
    for my $file (@sfiles) {
	my $FH;
	if (!open($FH,"$file")) {
	    next;
	}
	my @lines = <$FH>;
	close($FH);
	push(@$rptr,@lines);
    }

    return 0;
}

#
# Get the boot script manifest -- whether scripts are enabled, or hooked, and 
# how and when they or their hooks run!
#
sub getrcmanifest($;$)
{
    my ($rptr,$nofetch) = @_;
    my @tmccresults = ();
    my %manifest = ();
    my $retval = 0;

    print "Checking manifest...\n";

    if (tmcc(TMCCCMD_MANIFEST, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get manifest from server!\n");
	%$rptr = ();
	$retval = -1;
    }
    # Always allow local manifests to be run, so add them into our results.
    sortedreadallfilesindir("$DYNRUNDIR/rcmanifest.d",\@tmccresults);
    sortedreadallfilesindir("$STATICRUNDIR/rcmanifest.d",\@tmccresults);
    if (@tmccresults == 0) {
	%$rptr = ();
	return $retval;
    }

    my $servicepat = q(SERVICE NAME=([\w\.\-]+) ENV=(\w+) WHENCE=(\w+));
    $servicepat   .= q( ENABLED=(0|1) HOOKS_ENABLED=(0|1));
    $servicepat   .= q( FATAL=(0|1) (BLOBID)=([\w\-]*));
    my $servicepatfile = q(SERVICE NAME=([\w\.\-]+) ENV=(\w+) WHENCE=(\w+));
    $servicepatfile   .= q( ENABLED=(0|1) HOOKS_ENABLED=(0|1));
    $servicepatfile   .= q( FATAL=(0|1) (FILE)=([^ ]*));

    my $hookpat = q(HOOK SERVICE=([\w\.\-]+) ENV=(\w+) WHENCE=(\w+));
    $hookpat   .= q( OP=(\w+) POINT=(\w+));
    $hookpat   .= q( FATAL=(0|1) (BLOBID)=([\w\-]+));
    $hookpat   .= q( ARGV="([^"]*)");
    my $hookpatfile = q(HOOK SERVICE=([\w\.\-]+) ENV=(\w+) WHENCE=(\w+));
    $hookpatfile   .= q( OP=(\w+) POINT=(\w+));
    $hookpatfile   .= q( FATAL=(0|1) (FILE)=([^ ]+));
    $hookpatfile   .= q( ARGV="([^"]*)");

    my @loadinforesults = ();
    if (tmcc(TMCCCMD_LOADINFO, undef, \@loadinforesults) < 0) {
	warn("*** WARNING: getrcmanifest could not get loadinfo from server,\n".
	     "             unsure if node is in MFS and reloading, continuing!\n");
    }

    #
    # Are we in a loading environment?  If yes, filter the manifest
    # so that only the service and hook settings that apply to the 
    # loading MFS apply.
    #
    if (@loadinforesults && MFS()) {
	$manifest{'_ENV'} = 'load';
    }
    #
    # Otherwise, if we're not in an MFS, we must be booting!
    # NOTE: we don't do any configuration of the image in the 
    # admin MFS!
    #
    elsif (!MFS()) {
	$manifest{'_ENV'} = 'boot';
    }
    #
    # Otherwise, don't return *anything* -- the admin mfs doesn't do any
    # config of the node.
    #
    else {
	%$rptr = ();
	return 0;
    }

    #
    # Process our results.
    #
    for (my $i = 0; $i < @tmccresults; ++$i) {
	my $line = $tmccresults[$i];
	my %service;

	if ($line =~ /^$servicepat/ || $line =~ /^$servicepatfile/) {
	    my %service = ( 'ENABLED' => $4,
			    'HOOKS_ENABLED' => $5,
			    "$7" => $8,
			    'WHENCE' => $3,
			    'FATAL' => $6 );
	    if (exists($service{'FILE'})) {
		$service{'BLOBPATH'} = $service{'FILE'};
	    }

	    #
	    # Filter the service part of the manifest so that only the 
	    # settings that apply here are passed to scripts.
	    #
	    if ($2 eq $manifest{'_ENV'}) {
		# assume that there might be a hook line that applied to this
		# service ahead of the service line!  Other possibility
		# is that there was already a service line for this env...
		# which is a bug -- so just silently stomp it in that case.
		#
		# anyway, just update the results pointer for this service
		foreach my $k (keys(%service)) {
		    $manifest{$1}{$k} = $service{$k};
		}

		if (!exists($manifest{$1}{'_PREHOOKS'})) {
		    $manifest{$1}{'_PREHOOKS'} = [];
		}
		if (!exists($manifest{$1}{'_POSTHOOKS'})) {
		    $manifest{$1}{'_POSTHOOKS'} = [];
		}
	    }
	    # Otherwise just skip this entry -- it doesn't apply to us.
	    else {
		next;
	    }
	}
	elsif ($line =~ /^$hookpat/ || $line =~ /^$hookpatfile/) {
	    #
	    # Filter the service part of the manifest so that only the 
	    # settings that apply here are passed to scripts.
	    #
	    if ($2 eq $manifest{'_ENV'}) {
		my $hookstr = "_" . uc($5) . "HOOKS";
		if (!exists($manifest{$1}) || !exists($manifest{$1}{$hookstr})) {
		    $manifest{$1}{$hookstr} = [];
		}

		my $hook = { "$7" => $8,
			     'OP' => $4, 
			     'WHENCE' => $3, 
			     'FATAL' => $6, 
			     'ARGV' => $9 };
		if (exists($hook->{'FILE'})) {
		    $hook->{'BLOBPATH'} = $hook->{'FILE'};
		}

		$manifest{$1}{$hookstr}->[@{$manifest{$1}{$hookstr}}] = $hook;
	    }
	    # Otherwise just skip this entry -- it doesn't apply to us.
	    else {
		next;
	    }
	}
	else {
	    warn("*** WARNING: did not recognize manifest line '$line'," . 
		 " continuing!\n");
	}
    }

    $retval = 0;

    if (!defined($nofetch) || $nofetch != 1) {
	print "Downloading any manifest blobs...\n";
	%$rptr = %manifest;
	$retval = fetchrcmanifestblobs($rptr,undef,'manifest');
    }

    %$rptr = %manifest;
    return $retval;
}

sub fetchrcmanifestblobs($;$$)
{
    my ($manifest,$savedir,$basename) = @_;
    if (!defined($savedir)) {
	$savedir = $BLOBDIR;
    }
    if (!defined($basename)) {
	$basename = '';
    }
    my $blobpath = "$savedir/$basename";
    my $retval;
    my $failed = 0;

    foreach my $script (keys(%$manifest)) {
	# first grab the script replacement...
	if (exists($manifest->{$script}{'BLOBID'})
	    && $manifest->{$script}{'BLOBID'} ne '') {
	    my $bpath = $blobpath . "." . $manifest->{$script}{'BLOBID'};
	    $retval = libtmcc::blob::getblob($manifest->{$script}{'BLOBID'},
					     $bpath);
	    if ($retval == -1) {
		print STDERR "ERROR(fetchrcmanifestblobs): could not fetch " . 
		    $manifest->{$script}{'BLOBID'} . "!\n";
		++$failed;
	    }
	    else {
		$manifest->{$script}{'BLOBPATH'} = $bpath;
		chmod(0755,$bpath);
	    }
	}

	# now do hooks...
	my @hooktypes = ('_PREHOOKS','_POSTHOOKS');
	foreach my $hooktype (@hooktypes) {
	    next 
		if (!exists($manifest->{$script}{$hooktype})
		    || !exists($manifest->{$script}{'BLOBID'}));

	    foreach my $hook (@{$manifest->{$script}{$hooktype}}) {
		my $bpath = $blobpath . "." . $hook->{'BLOBID'};
		$retval = libtmcc::blob::getblob($hook->{'BLOBID'},$bpath);
		if ($retval == -1) {
		    print STDERR "ERROR(fetchrcmanifestblobs): could not fetch " . 
			$hook->{'BLOBID'} . "!\n";
		    ++$failed;
		}
		else {
		    $hook->{'BLOBPATH'} = $bpath;
		    chmod(0755,$bpath);
		}
	    }
	}
		
    }

    return $failed;
}

sub runhooks($$$$)
{
    my ($manifest,$which,$script,$what) = @_;
    my $hookstr = "_".uc($which)."HOOKS";
    my $failed = 0;

    if (exists($manifest->{$script}) 
	# if hooks are enabled because of a service line
	&& ((exists($manifest->{$script}{'HOOKS_ENABLED'}) 
	     && $manifest->{$script}{'HOOKS_ENABLED'} == 1)
	    # or if there was no service line, in which case hooks are
	    # enabled by default
	    || !exists($manifest->{$script}{'HOOKS_ENABLED'}))
	&& exists($manifest->{$script}{$hookstr})) {
	print "  Running $script $which hooks\n"
	    if ($debug);

	for (my $i = 0; $i < @{$manifest->{$script}{$hookstr}}; ++$i) {
	    my $hook = $manifest->{$script}{$hookstr}->[$i];

	    if (!exists($hook->{'BLOBID'}) && exists($hook->{'BLOBPATH'})) {
		# This is a local manifest hook; turn the path into an ID.
		$hook->{'BLOBID'} = $hook->{'BLOBPATH'};
		$hook->{'BLOBID'} =~ tr/\//_/;
	    }

	    my $blobid = $hook->{'BLOBID'};
	    my $argv = $hook->{'ARGV'};
	    my $hookrunfile = "$VARDIR/db/$script.${which}hook.$blobid.run";

	    # if the path doesn't exist, probably we failed to fetch the blob
	    if (!exists($hook->{'BLOBPATH'})) {
		++$failed;
		if ($hook->{'FATAL'}) {
		    fatal("Failed running $script $which hook $blobid (no blobpath!)");
		}
		else {
		    warn("  $script $which hook $blobid failed! (no blobpath!)");
		}
		next;
	    }

	    my $blobpath = $hook->{'BLOBPATH'};

	    # Only run the hook if its operation matches the operation we're
	    # doing (boot,shutdown,reconfig,reset)
	    if ($hook->{'OP'} ne $what) {
		next;
	    }

	    # If this is a first-only hook, skip if we've already done it!
	    if ($hook->{'WHENCE'} eq 'first' && -e $hookrunfile) {
		print "  Not running $which hook $blobid (first config only)\n" 
		    if ($debug);
		next;
	    }

	    print "  Running $script $which hook $blobid\n";

	    # NOTE: the last arg is always $what (boot,shutdown,reconfig,reset)
	    system("$blobpath $argv $what");
	    if ($?) {
		++$failed;
		if ($hook->{'FATAL'} == 1) {
		    fatal("Failed running $script $which hook $blobid");
		}
		else {
		    warn("  $script $which hook $blobid failed! ($?)");
		}
		# Don't write the hook run file if the hook failed!
		next;
	    }

	    open(FD,">$hookrunfile")
		or warn("open($hookrunfile): $!");
	    close(FD);
	}
    }

    return $failed;
}

sub runbootscript($$$$;@)
{
    my ($manifest,$path,$script,$what,@args) = @_;
    my $failed = 0;
    my $runfile = "$VARDIR/db/$script.run";
    # do we have a manifest entry for this script, and is it more than
    # just hooks!
    my $havemanifest = 0;
    if (exists($manifest->{$script}) 
	&& exists($manifest->{$script}{'ENABLED'})) {
	$havemanifest = 1;
    }

    #
    # If the script does not exist, don't run it or any hooks specified for it!
    # If we don't have a path, it's a "virtual" script like TBSETUP or ISUP, so
    # don't skip the hooks.  Only skip the script.
    #
    return 0
	if (defined($path) && ! -x "$path/$script");

    #
    # Don't do anything if the script or its hooks are disabled!
    #
    if ($havemanifest && $manifest->{$script}{'ENABLED'} != 1
	&& $manifest->{$script}{'HOOKS_ENABLED'} != 1) {
	print "Not running $script or hooks (disabled)\n";
	return 0;
    }

    TBDebugTimeStamp("Executing $script");

    #
    # Handle any pre hooks
    #
    $failed += runhooks($manifest,'pre',$script,$what);

    #
    # Handle the script itself -- if there is a path defined.  If $path is
    # undef, it means that we don't really have a script to run here -- we
    # just want to run pre and post hooks around a bit of code -- like in 
    # rc.bootsetup where we tell tmcd we're in TBSETUP or ISUP.
    #
    if (defined($path) && (!$havemanifest
			   || $manifest->{$script}{'ENABLED'} == 1)) {
	# If this is a first-only script, skip if we've already done it!
	if ($havemanifest && $manifest->{$script}{'WHENCE'} eq 'first' 
	    && -e $runfile) {
	    print "  Not running $script (first config only)\n";
	    return 0;
	}
	
	# If there are no args, we pass $what as the single arg!
	# XXX actually pass user defined args!
	my $argv = "";
	if (@args) {
	    $argv .= " " . join(' ',@args);
	}
	else {
	    $argv .= " $what";
	}
	if ($havemanifest && $manifest->{$script}{'BLOBPATH'} ne '') {
	    my $blobpath = $manifest->{$script}{'BLOBPATH'};
	    print "  Running $blobpath (instead of $path/$script)\n";
	    system("$blobpath $argv");
	}
	else {
	    print "  Running $path/$script\n"
		if ($debug);
	    system("$path/$script $argv");
	}
	if ($?) {
	    ++$failed;
	    if (exists($manifest->{$script}) 
		&& exists($manifest->{$script}{'FATAL'}) 
		&& $manifest->{$script}{'FATAL'} == 1) {
		fatal("  Failed running $script ($?)!");
	    }
	    # XXX failure of the firewall script is always fatal
	    elsif ($script eq "rc.firewall") {
		fatal("  Failed running $script ($?)!");
	    }
	    else {
		warn("  Failed running $script ($?)!");
	    }
	    return 0;
	}

	open(FD,">$runfile")
	    or warn("open($runfile): $!");
	close(FD);
    }

    #
    # Handle any post hooks
    #
    $failed += runhooks($manifest,'post',$script,$what);

    return $failed;
}

#
# The server gives us random/unique macs. Well, as unique as can
# be expected, but that should be fine (this mostly matters on
# shared nodes where duplicate macs would be bad). 
#
# One wrinkle; when there is a root context device and a container
# context device, we need to distinguish them, so set a bit on the
# root context side (since we want the container mac to be what the
# user has been told elsewhere). Do that with 0x80 in the upper octet.
#
# XXX The server has also set the local admin flag (0x02), which is
# required for linux macvlans, but we set it anyway. This might cause
# confusion if the server neglects to do this.
#
sub build_fake_macs {
    my ($mac) = @_;
    my ($vethmac,$ethmac);

    if ($mac =~ /^(\w\w)(\w*)$/) {
	$ethmac  = sprintf("%02x%s", 0x82 | hex($1), $2);
	$vethmac = sprintf("%02x%s", 0x02 | hex($1), $2);
	return ($vethmac, $ethmac);
    }
    return undef;
}

#
# Parse the router config and return a hash. This leaves the ugly pattern
# matching stuff here, but lets the caller do whatever with it (as is the
# case for the IXP configuration stuff). This is inconsistent with many
# other config scripts, but at some point that will change.
#
sub getifconfig($;$)
{
    my ($rptr,$nocache) = @_;	# Return list to caller (reference).
    my @tmccresults  = ();
    my @ifacelist    = ();	# To be returned to caller.
    my %ifacehash    = ();

    my %tmccopts = ();
    if ($nocache) {
	$tmccopts{"nocache"} = 1;
    }

    if (tmcc(TMCCCMD_IFC, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get interface config from server!\n");
	@$rptr = ();
	return -1;
    }

    my $ethpat  = q(INTERFACE IFACETYPE=(\w*) INET=([0-9.]*) MASK=([0-9.]*) );
    $ethpat    .= q(MAC=(\w*) SPEED=(\w*) DUPLEX=(\w*) );
    $ethpat    .= q(IFACE=(\w*) RTABID=(\d*) LAN=([-\w\(\)]*) MTU=(\d*));

    my $vethpat = q(INTERFACE IFACETYPE=(\w*) INET=([0-9.]*) MASK=([0-9.]*) );
    $vethpat   .= q(ID=(\d*) VMAC=(\w*) PMAC=(\w*) RTABID=(\d*) );
    $vethpat   .= q(ENCAPSULATE=(\d*) LAN=([-\w\(\)]*) VTAG=(\d*) MTU=(\d*));

    my $setpat  = q(INTERFACE_SETTING MAC=(\w*) );
    $setpat    .= q(KEY='([-\w\.\:]*)' VAL='([-\w\.\:]*)');

    # XXX see very**3 special hack below
    my $hastvirt = 0;

    foreach my $str (@tmccresults) {
	my $ifconfig = {};

	if ($str =~ /^$setpat/) {
	    my $mac     = $1;
	    my $capkey  = $2;
	    my $capval  = $3;

	    #
	    # Stash the setting into the setting list, but must find the
	    #
	    if (!exists($ifacehash{$mac})) {
		warn("*** WARNING: ".
		     "Could not map $mac for its interface settings!\n");
		next;
	    }
	    $ifacehash{$mac}->{"SETTINGS"}->{$capkey} = $capval;
	}
	elsif ($str =~ /$ethpat/) {
	    my $ifacetype= $1;
	    my $inet     = $2;
	    my $mask     = $3;
	    my $mac      = $4;
	    my $speed    = $5;
	    my $duplex   = $6;
	    my $iface    = $7;
	    my $rtabid   = $8;
	    my $lan      = $9;
	    my $mtu	 = $10;

            #
            # XXX GNU Radio hack
            #
            # The GNU Radio interface has a randomly generated MAC addr when
            # it first comes up.  WE have to set it, so just tell the code
            # the name of the interface explicitly to avoid trying to look
            # it up (the iface doesn't even exist yet).
            #
            # We really need another interface flag, like 'ISGNURADIO' since
            # the only current GR iface type is hardwired below (which is bad).
            #
            if ($ifacetype eq "flex900") {
                $iface = "gr0";
            }

	    # The server can specify an iface.
	    if ($iface eq "" &&
		(! ($iface = findiface($mac)))) {
		warn("*** WARNING: Could not map $mac to an interface!\n");
		next;
	    }

	    $ifconfig->{"ISVIRT"}   = 0;
	    $ifconfig->{"TYPE"}     = $ifacetype;
	    $ifconfig->{"IPADDR"}   = $inet;
	    $ifconfig->{"IPMASK"}   = $mask;
	    $ifconfig->{"MAC"}      = $mac;
	    $ifconfig->{"SPEED"}    = $speed;
	    $ifconfig->{"DUPLEX"}   = $duplex;
	    $ifconfig->{"ALIASES"}  = "";	# gone as of version 27
	    $ifconfig->{"IFACE"}    = $iface;
	    $ifconfig->{"VIFACE"}   = $iface;
	    $ifconfig->{"RTABID"}   = $rtabid;
	    $ifconfig->{"LAN"}      = $lan;
	    $ifconfig->{"MTU"}      = $mtu;
	    $ifconfig->{"SETTINGS"} = {};
	    push(@ifacelist, $ifconfig);
	    $ifacehash{$mac}        = $ifconfig;
	}
	elsif ($str =~ /$vethpat/) {
	    my $ifacetype= $1;
	    my $inet     = $2;
	    my $mask     = $3;
	    my $id       = $4;
	    my $vmac     = $5;
	    my $pmac     = $6;
	    my $iface    = undef;
	    my $rtabid   = $7;
	    my $encap    = $8;
	    my $lan      = $9;
	    my $vtag	 = $10;
	    my $mtu	 = $11;

	    #
	    # Inside a jail, the vmac is really the pmac. That is, when the
	    # veth was created, it was given vmac as its ethernet address.
	    # The pmac refers to the underlying physical interface the veth
	    # is attached to, which we do not see from inside the jail.
	    #
	    if (JAILED() || GENVNODE()) {
		if (! ($iface = findiface($vmac))) {
		    if (defined($vnodeid) && $vnodeid =~ /.+\-(\d+)$/) {
			my ($vinmac,undef) = build_fake_macs($vmac);
			if (!defined($vinmac)) {
			    warn("*** WARNING: Could not map $vmac to a veth ".
				 "(build_fake_macs failed)!\n");
			    next;
			}
			elsif (! ($iface = findiface($vinmac))) {
			    warn("*** WARNING: Could not map $vinmac to a veth!\n");
			    next;
			}
		    }
		    else {
			warn("*** WARNING: Could not map $vmac to a veth!\n");
			next;
		    }
		}
	    } else {

		#
		# A veth might not have any underlying physical interface
		# if the link or lan is completely contained on the node.
		# tmcd tells us that by setting the pmac to "none". Note
		# that this obviously is relevant on the physnode, not when
		# called from inside a vnode.
		#
		if ($pmac ne "none") {
		    if (! ($iface = findiface($pmac))) {
			warn("*** WARNING: Could not map $pmac to an iface!\n");
			next;
		    }
		}
	    }

	    $hasvirt++;
	    $ifconfig->{"ISVIRT"}   = 1;
	    $ifconfig->{"ITYPE"}    = $ifacetype;
	    $ifconfig->{"IPADDR"}   = $inet;
	    $ifconfig->{"IPMASK"}   = $mask;
	    $ifconfig->{"ID"}       = $id;
	    $ifconfig->{"VMAC"}     = $vmac;
	    $ifconfig->{"MAC"}      = $vmac; # XXX
	    $ifconfig->{"PMAC"}     = $pmac;
	    $ifconfig->{"IFACE"}    = $iface;
	    $ifconfig->{"RTABID"}   = $rtabid;
	    $ifconfig->{"ENCAP"}    = $encap;
	    $ifconfig->{"LAN"}      = $lan;
	    $ifconfig->{"VTAG"}     = $vtag;
	    $ifconfig->{"MTU"}      = $mtu;

	    # determine the OS-specific virtual device name
	    $ifconfig->{"VIFACE"}   = os_viface_name($ifconfig);

	    push(@ifacelist, $ifconfig);
	}
	else {
	    warn "*** WARNING: Bad ifconfig line: $str\n";
	}
    }

    #
    # XXX "optimize" the interface list. We do this here rather than in the
    # interface configuration script so that the delay/linkdelay scripts will
    # get the same info.
    #
    # This is a very, very, very special case. If a non-encapsulating veth
    # interface (veth-ne) maps 1-to-1 with an underlying physical interface,
    # we want to just use the physical interface instead. This allows OSes
    # (on physical nodes) which don't support a veth device (i.e., most of
    # them) to talk to vnodes which are using veth-ne style.
    #
    # This can go away once we have separated the notion of multiplexing
    # links from encapsulating links (a historical conflation) so that we
    # don't have to force virtual devices onto physical nodes just because
    # some virtual nodes in the same experiment require multiplexed links.
    #
    if ($hasvirt && !JAILED() && !JAILHOST() && !GENVNODE() &&
	!REMOTE() && !PLAB()) {
	#
	# Prelim: find out how many virt interfaces mapped to each phys
	# interface and locate the entry for each phys interface.
	#
	my %vifcount = ();
	my %pifs = ();
	foreach my $ifconfig (@ifacelist) {
	    if ($ifconfig->{"ISVIRT"}) {
		if ($ifconfig->{"PMAC"} ne "none") {
		    $vifcount{$ifconfig->{"PMAC"}}++;
		}
	    } else {
		$pifs{$ifconfig->{"MAC"}} = $ifconfig;
	    }
	}
	#
	# Now for each 1-to-1 non-encap virt interface, move IP info
	# onto physical interface, remember VMAC and toss veth entry.
	#
	my @nifacelist = ();
	foreach my $ifconfig (@ifacelist) {
	    if ($ifconfig->{"ISVIRT"} && $ifconfig->{"ITYPE"} eq "veth" &&
		$ifconfig->{"ENCAP"} == 0 && $ifconfig->{"PMAC"} ne "none" &&
		$vifcount{$ifconfig->{"PMAC"}} == 1) {
		my $pif = $pifs{$ifconfig->{"PMAC"}};
		$pif->{"IPADDR"} = $ifconfig->{"IPADDR"};
		$pif->{"IPMASK"} = $ifconfig->{"IPMASK"};
		$pif->{"IFACE"} = $ifconfig->{"IFACE"};
		$pif->{"RTABID"} = $ifconfig->{"RTABID"};
		$pif->{"LAN"} = $ifconfig->{"LAN"};
		$pif->{"MTU"} = $ifconfig->{"MTU"};
		$pif->{"FROMVMAC"} = $ifconfig->{"VMAC"};
		print STDERR "NOTE: remapping ", $ifconfig->{"VIFACE"},
		" to ", $ifconfig->{"IFACE"}, "\n";
	    } else {
		push(@nifacelist, $ifconfig);
	    }
	}
	@ifacelist = @nifacelist;
    }

    @$rptr = @ifacelist;
    return 0;
}

#
# Parse the linkdelay config and return a hash. This leaves the ugly pattern
# matching stuff here, but lets the caller do whatever with it.
#
sub getlinkdelayconfig($;$)
{
    my ($rptr,$nocache) = @_;	# Return list to caller (reference).
    my @tmccresults  = ();
    my @ldlist       = ();	# To be returned to caller.

    my %tmccopts = ();
    if ($nocache) {
	$tmccopts{"nocache"} = 1;
    }

    if (tmcc(TMCCCMD_LINKDELAYS, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get linkdelay config from server!\n");
	@$rptr = ();
	return -1;
    }

    my $pat = q(LINKDELAY IFACE=([\d\w]+) TYPE=(simplex|duplex) );
    $pat .= q(LINKNAME=([-\d\w]+) VNODE=([-\d\w]+) );
    $pat .= q(INET=([0-9.]*) MASK=([0-9.]*) );
    $pat .= q(PIPE=(\d+) DELAY=([\d\.]+) BW=(\d+) PLR=([\d\.]+) );
    $pat .= q(RPIPE=(\d+) RDELAY=([\d\.]+) RBW=(\d+) RPLR=([\d\.]+) );
    $pat .= q(RED=(\d) LIMIT=(\d+) );
    $pat .= q(MAXTHRESH=(\d+) MINTHRESH=(\d+) WEIGHT=([\d\.]+) );
    $pat .= q(LINTERM=(\d+) QINBYTES=(\d+) BYTES=(\d+) );
    $pat .= q(MEANPSIZE=(\d+) WAIT=(\d+) SETBIT=(\d+) );
    $pat .= q(DROPTAIL=(\d+) GENTLE=(\d+));

    foreach my $str (@tmccresults) {
	my $ldc = {};

	if ($str =~ /^$pat/) {
	    $ldc->{"IFACE"} = $1;
	    $ldc->{"TYPE"} = $2;
	    $ldc->{"LINKNAME"} = $3;
	    $ldc->{"VNODE"} = $4;
	    $ldc->{"INET"} = $5;
	    $ldc->{"MASK"} = $6;
	    $ldc->{"PIPE"} = $7;
	    $ldc->{"DELAY"} = $8;
	    $ldc->{"BW"} = $9;
	    $ldc->{"PLR"} = $10;
	    $ldc->{"RPIPE"} = $11;
	    $ldc->{"RDELAY"} = $12;
	    $ldc->{"RBW"} = $13;
	    $ldc->{"RPLR"} = $14;
	    $ldc->{"RED"} = $15;
	    $ldc->{"LIMIT"} = $16;
	    $ldc->{"MAXTHRESH"} = $17;
	    $ldc->{"MINTHRESH"} = $18;
	    $ldc->{"WEIGHT"} = $19;
	    $ldc->{"LINTERM"} = $20;
	    $ldc->{"QINBYTES"} = $21;
	    $ldc->{"BYTES"} = $22;
	    $ldc->{"MEANPSIZE"} = $23;
	    $ldc->{"WAIT"} = $24;
	    $ldc->{"SETBIT"} = $25;
	    $ldc->{"DROPTAIL"} = $26;
	    $ldc->{"GENTLE"} = $27;

	    push(@ldlist, $ldc);
	}
	else {
	    warn "*** WARNING: Bad linkdelay line: $str\n";
	}
    }

    @$rptr = @ldlist;
    return 0;
}

#
# Read the topomap and return something.
#
sub gettopomap($)
{
    my ($rptr)       = @_;	# Return array to caller (reference).
    my $topomap	     = {};
    my $section;
    my @slots;

    if (! -e TMTOPOMAP()) {
	$rptr = {};
	return -1;
    }

    if (!open(TOPO, TMTOPOMAP())) {
	warn("*** WARNING: ".
	     "gettopomap: Could not open " . TMTOPOMAP() . "!\n");
	@$rptr = ();
	return -1;
    }

    #
    # First line of topo map describes the nodes.
    #
    while (<TOPO>) {
	if ($_ =~ /^\#\s*([-\w]*): ([-\w,]*)$/) {
	    $section = $1;
	    @slots = split(",", $2);

	    $topomap->{$section} = [];
	    next;
	}
	chomp($_);
	my @values = split(",", $_);
	my $rowref = {};

	for (my $i = 0; $i < scalar(@slots); $i++) {
	    $rowref->{$slots[$i]} = (defined($values[$i]) ? $values[$i] : undef);
	}
	push(@{ $topomap->{$section} }, $rowref);
    }
    close(TOPO);
    $$rptr = $topomap;
    return 0;
}

#
# Generate a hosts file given hostname info in tmcc hostinfo format
# Returns 0 on success, non-zero otherwise.
#
sub genhostsfile($@)
{
    my ($pathname, @hostlist) = @_;

    my $HTEMP = "$pathname.new";

    #
    # Note, we no longer start with the 'prototype' file here because we have
    # to make up a localhost line that's properly qualified.
    #
    if (!open(HOSTS, ">$HTEMP")) {
	warn("Could not create temporary hosts file $HTEMP\n");
	return 1;
    }

    #
    # Read any hosts.head files.  We prefer /etc/hosts.head ; then
    # $DYNRUNDIR/hosts.head ; then $STATICRUNDIR/hosts.head .  However,
    # we'll take from all three places, so all three had better be
    # correct!
    #
    my @hdirs = ("/etc",$DYNRUNDIR,$STATICRUNDIR);
    foreach my $dir (@hdirs) {
	next if (! -f "$dir/hosts.head");
	if (!open(my $FH,"$dir/hosts.head") == 0) {
	    my @lines = <$FH>;
	    close($FH);
	    print HOSTS @lines;
	}
    }

    my $localaliases = "loghost";

    #
    # Find out our domain name, so that we can qualify the localhost entry
    #
    my $hostname = `hostname`;
    if ($hostname =~ /[^.]+\.(.+)/) {
	$localaliases .= " localhost.$1";
    }

    #
    # First, write a localhost line into the hosts file - we have to know the
    # domain to use here
    #
    print HOSTS os_etchosts_line("localhost", "127.0.0.1",
				 $localaliases), "\n";

    #
    # Now convert each hostname into hosts file representation and write
    # it to the hosts file. Note that ALIASES is for backwards compat.
    # Should go away at some point.
    #
    my $pat  = q(NAME=([-\w\.]+) IP=([0-9\.]*) ALIASES=\'([-\w\. ]*)\');

    foreach my $str (@hostlist) {
	if ($str =~ /$pat/) {
	    my $name    = $1;
	    my $ip      = $2;
	    my $aliases = $3;

	    my $hostline = os_etchosts_line($name, $ip, $aliases);

	    print HOSTS "$hostline\n";
	}
	else {
	    warn("Ignoring bad hosts line: $str");
	}
    }

    #
    # Read any hosts.tail files.  We prefer /etc/hosts.tail ; then
    # $DYNRUNDIR/hosts.tail ; then $STATICRUNDIR/hosts.tail .  However,
    # we'll take from all three places, so all three had better be
    # correct!
    #
    foreach my $dir (@hdirs) {
	next if (! -f "$dir/hosts.tail");
	if (!open(my $FH,"$dir/hosts.tail") == 0) {
	    my @lines = <$FH>;
	    close($FH);
	    print HOSTS @lines;
	}
    }

    close(HOSTS);
    system("mv -f $HTEMP $pathname");
    if ($?) {
	warn("Could not move $HTEMP to $pathname\n");
	return 1;
    }

    return 0;
}

#
# Generate hosts list (as if it came from tmcd) locally if we have a topo file.
# You want to run the above genhostsfile on the result array of this, as
# rc.hostnames does.
#
sub genhostslistfromtopo($$)
{
    my ($mapfile,$rptr)	= @_;
    my @results = ();
    my $topomap;
    my ($pid, $eid, $vname) = check_nickname();
    my %nodes = ();
    my %lans  = ();;

    if (gettopomap(\$topomap)) {
	return -1;
    }

    # Special case of experiment with no lans; no hostfile stuff needed.
    if (! scalar(@{ $topomap->{"lans"} })) {
	@$rptr = ();
	return 0;
    }

    # The nodes section tells us the name of each node, and all its links.
    foreach my $noderef (@{ $topomap->{"nodes"} }) {
	my $vname  = $noderef->{"vname"};
	my $links  = $noderef->{"links"};
	my $count  = 0;

	next
	    if (!defined($links));

	$nodes{$vname} = [];

	# Links is a string of "$lan1:$ip1 $lan2:$ip2 ..."
	foreach my $link (split(" ", $links)) {
	    my ($lan,$ip) = split(":", $link);

	    push(@{ $nodes{$vname} }, "$count:$ip");
	    $lans{"$vname:$count"} = $lan;
	    $count++;
	}
    }

    #
    # Construct input for external program. 
    #
    if (! open(MAP, ">$mapfile")) {
	warn("*** WARNING: Could not create $mapfile!\n");
	@$rptr  = ();
	return -1;
    }

    #
    # First spit out virt_nodes
    #
    print MAP scalar(keys(%nodes)) . "\n";

    foreach my $node (keys(%nodes)) {
	my @members = @{ $nodes{$node} };

	print MAP "$node,";
	print MAP join(" ", @members);
	print MAP "\n";
    }
    #
    # Then spit out virt_lans.
    # 
    print MAP scalar(keys(%lans)) . "\n";

    foreach my $member (keys(%lans)) {
	my $lan = $lans{$member};

	print MAP "$lan,$member\n";
    }
    close(MAP);

    #
    # Now run the dijkstra program on the input. 
    # 
    if (!open(GENH, "cat $mapfile | $BINDIR/genhostsfile $vname |")) {
	warn("*** WARNING: Could not invoke genhostsfile on mapfile!\n");
	@$rptr  = ();
	return -1;
    }
    while (<GENH>) {
	push(@results, $_);
    }
    if (! close(GENH)) {
	if ($?) {
	    warn("*** WARNING: genhostsfile exited with status $?!\n");
	}
	else {
	    warn("*** WARNING: Error closing genhostsfile pipe: $!\n");
	}
	@$rptr  = ();
	return -1;
    }
    @$rptr = @results;
    return 0;
}

#
# Convert from MAC to iface name (eth0/fxp0/etc) using little helper program.
#
# If the optional second arg is set, it is an IP address with which we
# validate the interface.  If the queries by MAC and IP return different
# interfaces, we believe the latter.  We do this because some virtual
# interfaces (like vlans and IP aliases on Linux) use the MAC address of
# the underlying physical device.  Hence, look up by MAC on those will
# return the physical interface.
#
sub findiface($;$)
{
    my($mac,$ip) = @_;
    my($iface);

    open(FIF, FINDIF . " $mac |")
	or die "Cannot start " . FINDIF . ": $!";

    $iface = <FIF>;

    if (! close(FIF)) {
	if (!defined($ip)) {
	    return 0;
	}
	#
	# MAC was bogus, if we had an IP, look that up instead
	#
	$iface = "";
    }

    $iface =~ s/\n//g;

    if (defined($ip)) {
	open(FIF, FINDIF . " -i $ip |")
	    or die "Cannot start " . FINDIF . ": $!";
	my $ipiface = <FIF>;
	if (!close(FIF)) {
	    return 0;
	}
	$ipiface =~ s/\n//g;
	if ($ipiface ne "" && $ipiface ne $iface) {
	    $iface = $ipiface;
	}
    }

    return $iface;
}

#
# Return the router configuration. We parse tmcd output here and return
# a list of hash entries to the caller.
#
sub getrouterconfig($$)
{
    my ($rptr, $ptype) = @_;		# Return list and type to caller.
    my @tmccresults = ();
    my @routes      = ();
    my $type;

    if (tmcc(TMCCCMD_ROUTING, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get routes from server!\n");
	@$rptr  = ();
	$$ptype = undef;
	return -1;
    }

    #
    # Scan for router type. If "none" we are done.
    #
    foreach my $line (@tmccresults) {
	if ($line =~ /ROUTERTYPE=(.+)/) {
	    $type = $1;
	    last;
	}
    }
    if (!defined($type) || $type eq "none") {
	@$rptr  = ();
	$$ptype = "none";
	return 0;
    }

    #
    # ROUTERTYPE=manual
    # ROUTE DEST=192.168.2.3 DESTTYPE=host DESTMASK=255.255.255.0 \
    #	NEXTHOP=192.168.1.3 COST=0 SRC=192.168.4.5
    #
    # The SRC ip is used to determine which interface the routes are
    # associated with, since nexthop alone is not enough cause of the
    #
    my $pat = q(ROUTE DEST=([0-9\.]*) DESTTYPE=(\w*) DESTMASK=([0-9\.]*) );
    $pat   .= q(NEXTHOP=([0-9\.]*) COST=([0-9]*) SRC=([0-9\.]*));

    foreach my $line (@tmccresults) {
	if ($line =~ /ROUTERTYPE=(.+)/) {
	    next;
	}
	elsif ($line =~ /$pat/) {
	    my $dip   = $1;
	    my $rtype = $2;
	    my $dmask = $3;
	    my $gate  = $4;
	    my $cost  = $5;
	    my $sip   = $6;

	    #
	    # For IXP.
	    #
	    my $rconfig = {};

	    $rconfig->{"IPADDR"}   = $dip;
	    $rconfig->{"TYPE"}     = $rtype;
	    $rconfig->{"IPMASK"}   = $dmask;
	    $rconfig->{"GATEWAY"}  = $gate;
	    $rconfig->{"COST"}     = $cost;
	    $rconfig->{"SRCIPADDR"}= $sip;
	    push(@routes, $rconfig);
	}
	else {
	    warn("*** WARNING: Bad route config line: $line\n");
	}
    }

    # Special case for distributed route calculation.
    if ($type eq "static" || $type eq "static-ddijk") {
	if (calcroutes(\@routes)) {
	    warn("*** WARNING: Could not get routes from ddijkstra!\n");
	    @$rptr  = ();
	    $$ptype = undef;
	    return -1;
	}
	$type = "static";
    }

    @$rptr  = @routes;
    $$ptype = $type;
    return 0;
}

#
# Special case. If the routertype is "static-ddijk" then we run our
# dijkstra program on the linkmap, and use that to feed the code
# below (it outputs exactly the same goo).
#
# XXX: If we change the return from tmcd, the output of dijkstra will
# suddenly be wrong. Yuck, need a better solution.
#
# We have to generate the input file from the topomap.
#
sub calcroutes ($)
{
    my ($rptr)	= @_;
    my @routes  = ();
    my $linkmap = CONFDIR() . "/linkmap";	# Happens outside jail.
    my $topomap;
    my ($pid, $eid, $myname) = check_nickname();

    if (gettopomap(\$topomap)) {
	warn("*** WARNING: Could not get topomap!\n");
	return -1;
    }

    # Special case of experiment with no lans; no routes needed.
    if (! scalar(@{ $topomap->{"lans"} })) {
	@$rptr = ();
	return 0;
    }

    # Gather up all the link info from the topomap
    my %lans     = ();
    my $nnodes   = 0;
    my %noroute  = ();

    #
    # Prepass the lans section to see which lans are not routed.
    #
    foreach my $lanref (@{ $topomap->{"lans"} }) {
	#
	# look for no-route flag. They are in the topomap cause of
	# hostnames generation, but we do not want to run them through
	# the route calculator. Shared vlans are the only current
	# usage case.
	#
	if (exists($lanref->{"noroute"}) && $lanref->{"noroute"}) {
	    $noroute{$lanref->{"vname"}} = 1;
	}
    }

    # The nodes section tells us the name of each node, and all its links.
    foreach my $noderef (@{ $topomap->{"nodes"} }) {
	my $vname  = $noderef->{"vname"};
	my @links  = ();

	# Cull out non routable networks.
	if (defined($noderef->{"links"})) {
	    foreach my $link (split(" ", $noderef->{"links"})) {
		my ($lan,$ip) = split(":", $link);
		push(@links, $link)
		    if (! exists($noroute{$lan}));
	    }
	}

	if (!@links) {
	    # If we have no links, there are no routes to compute.
	    if ($vname eq $myname) {
		@$rptr = ();
		return 0;
	    }
	    next;
	}

	# Links is a string of "$lan1:$ip1 $lan2:$ip2 ..."
	foreach my $link (@links) {
	    my ($lan,$ip) = split(":", $link);

	    if (! defined($lans{$lan})) {
		$lans{$lan} = {};
		$lans{$lan}->{"members"} = {};
	    }
	    $lans{$lan}->{"members"}->{"$vname:$ip"} = $ip;
	}

	$nnodes++;
    }

    # The lans section tells us the masks and the costs.
    foreach my $lanref (@{ $topomap->{"lans"} }) {
	my $vname  = $lanref->{"vname"};
	my $cost   = $lanref->{"cost"};
	my $mask   = $lanref->{"mask"};

	$lans{$vname}->{"cost"} = $cost;
	$lans{$vname}->{"mask"} = $mask;
    }

    #
    # Construct input for Jon's dijkstra program.
    #
    if (! open(MAP, ">$linkmap")) {
	warn("*** WARNING: Could not create $linkmap!\n");
	@$rptr  = ();
	return -1;
    }

    # Count edges, but just once each.
    my $edges = 0;
    foreach my $lan (keys(%lans)) {
	my @members = sort(keys(%{ $lans{$lan}->{"members"} }));

	for (my $i = 0; $i < scalar(@members); $i++) {
	    for (my $j = $i; $j < scalar(@members); $j++) {
		my $member1 = $members[$i];
		my $member2 = $members[$j];

		$edges++
		    if ($member1 ne $member2);
	    }
	}
    }

    # Header line for Jon. numnodes numedges
    print MAP "$nnodes $edges\n";

    # And then a list of edges: node1 ip1 node2 ip2 cost
    foreach my $lan (keys(%lans)) {
	my @members = sort(keys(%{ $lans{$lan}->{"members"} }));
	my $cost    = $lans{$lan}->{"cost"};
	my $mask    = $lans{$lan}->{"mask"};

	for (my $i = 0; $i < scalar(@members); $i++) {
	    for (my $j = $i; $j < scalar(@members); $j++) {
		my $member1 = $members[$i];
		my $member2 = $members[$j];

		if ($member1 ne $member2) {
		    my ($node1,$ip1) = split(":", $member1);
		    my ($node2,$ip2) = split(":", $member2);

		    print MAP "$node1 " . $ip1 . " " .
			      "$node2 " . $ip2 . " $cost\n";
		}
	    }
	}
    }
    close(MAP);
    undef($topomap);
    undef(%lans);

    #
    # Now run the dijkstra program on the input.
    # --compress generates "net" routes
    #
    if (!open(DIJK, "cat $linkmap | $BINDIR/dijkstra --compress --source=$myname |")) {
	warn("*** WARNING: Could not invoke dijkstra on linkmap!\n");
	@$rptr  = ();
	return -1;
    }
    my $pat = q(ROUTE DEST=([0-9\.]*) DESTTYPE=(\w*) DESTMASK=([0-9\.]*) );
    $pat   .= q(NEXTHOP=([0-9\.]*) COST=([0-9]*) SRC=([0-9\.]*));

    while (<DIJK>) {
	if ($_ =~ /ROUTERTYPE=(.+)/) {
	    next;
	}
	if ($_ =~ /$pat/) {
	    my $dip   = $1;
	    my $rtype = $2;
	    my $dmask = $3;
	    my $gate  = $4;
	    my $cost  = $5;
	    my $sip   = $6;

	    my $rconfig = {};
	    $rconfig->{"IPADDR"}   = $dip;
	    $rconfig->{"TYPE"}     = $rtype;
	    $rconfig->{"IPMASK"}   = $dmask;
	    $rconfig->{"GATEWAY"}  = $gate;
	    $rconfig->{"COST"}     = $cost;
	    $rconfig->{"SRCIPADDR"}= $sip;
	    push(@routes, $rconfig);
	}
	else {
	    warn("*** WARNING: Bad route config line: $_\n");
	}
    }
    if (! close(DIJK)) {
	if ($?) {
	    warn("*** WARNING: dijkstra exited with status $?!\n");
	}
	else {
	    warn("*** WARNING: Error closing dijkstra pipe: $!\n");
	}
	@$rptr  = ();
	return -1;
    }
    @$rptr = @routes;
    return 0;
}

#
# Get trafgen configuration.
#
sub gettrafgenconfig($)
{
    my ($rptr)   = @_;
    my @trafgens = ();

    if (tmcc(TMCCCMD_TRAFFIC, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get trafgen config from server!\n");
	return -1;
    }

    my $pat  = q(TRAFGEN=([-\w.]+) MYNAME=([-\w.]+) MYPORT=(\d+) );
    $pat    .= q(PEERNAME=([-\w.]+) PEERPORT=(\d+) );
    $pat    .= q(PROTO=(\w+) ROLE=(\w+) GENERATOR=(\w+));

    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    my $trafgen = {};

	    $trafgen->{"NAME"}       = $1;
	    $trafgen->{"SRCHOST"}    = $2;
	    $trafgen->{"SRCPORT"}    = $3;
	    $trafgen->{"PEERHOST"}   = $4;
	    $trafgen->{"PEERPORT"}   = $5;
	    $trafgen->{"PROTO"}      = $6;
	    $trafgen->{"ROLE"}       = $7;
	    $trafgen->{"GENERATOR"}  = $8;
	    push(@trafgens, $trafgen);

	    #
	    # Flag node as doing NSE trafgens for other scripts.
	    #
	    if ($trafgen->{"GENERATOR"} eq "NSE") {
		system("touch " . ISSIMTRAFGENPATH);
		next;
	    }
	}
	else {
	    warn("*** WARNING: Bad traffic line: $str\n");
	}
    }
    @$rptr = @trafgens;
    return 0;
}

#
# Get trace configuration.
#
sub gettraceconfig($)
{
    my ($rptr)    = @_;
    my @traceinfo = ();

    if (tmcc(TMCCCMD_TRACEINFO, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get trace config from server!\n");
	return -1;
    }

    my $pat = q(TRACE LINKNAME=([-\d\w]+) IDX=(\d*) MAC0=(\w*) MAC1=(\w*) );
    $pat   .= q(VNODE=([-\d\w]+) VNODE_MAC=(\w*) );
    $pat   .= q(TRACE_TYPE=([-\d\w]+) );
    $pat   .= q(TRACE_EXPR='(.*)' );
    $pat   .= q(TRACE_SNAPLEN=(\d*));

    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    my $trace = {};

	    $trace->{"LINKNAME"}      = $1;
	    $trace->{"IDX"}           = $2;
	    $trace->{"MAC0"}          = $3;
	    $trace->{"MAC1"}          = $4;
	    $trace->{"VNODE"}         = $5;
	    $trace->{"VNODE_MAC"}     = $6;
	    $trace->{"TRACE_TYPE"}    = $7;
	    $trace->{"TRACE_EXPR"}    = $8;
	    $trace->{"TRACE_SNAPLEN"} = $9;
	    push(@traceinfo, $trace);
	}
	else {
	    warn("*** WARNING: Bad traceinfo line: $str\n");
	}
    }
    @$rptr = @traceinfo;
    return 0;
}

#
# Get tunnels configuration.
#
sub gettunnelconfig($)
{
    my ($rptr)   = @_;
    my @tmccresults = ();
    my $tunnels  = {};

    if (tmcc(TMCCCMD_TUNNEL, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get tunnel config from server!\n");
	return -1;
    }

    my $pat  = q(TUNNEL=([\w]+) MEMBER=([\w]+) KEY='(.*)' VALUE='(.*)');

    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    my $tunnel = $1;
	    my $member = $2;
	    my $key    = $3;
	    my $value  = $4;

	    $tunnels->{"$tunnel:$member"}->{$key} = $value;
	}
	else {
	    warn("*** WARNING: Bad tunnels line: $str\n");
	}
    }
    $$rptr = $tunnels;
    return 0;
}

#
# Get tiptunnels configuration.
#
sub gettiptunnelconfig($)
{
    my ($rptr)   = @_;
    my @tiptunnels = ();

    if (tmcc(TMCCCMD_TIPTUNNELS, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get tiptunnel config from server!\n");
	return -1;
    }

    my $pat  = q(VNODE=([-\w.]+) SERVER=([-\w.]+) PORT=(\d+) );
    $pat    .= q(KEYLEN=(\d+) KEY=([-\w.]+));

    my $ACLDIR = "/var/log/tiplogs";

    mkdir("$ACLDIR", 0755);
    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    if (!open(ACL, "> $ACLDIR/$1.acl")) {
		warn("*** WARNING: ".
		     "gettiptunnelconfig: Could not open $ACLDIR/$1.acl\n");
		return -1;
	    }

	    print ACL "host: $2\n";
	    print ACL "port: $3\n";
	    print ACL "keylen: $4\n";
	    print ACL "key: $5\n";
	    close(ACL);

	    push(@tiptunnels, $1);
	}
	else {
	    warn("*** WARNING: Bad tiptunnels line: $str\n");
	}
    }
    @$rptr = @tiptunnels;
    return 0;
}

#
# Get motelog configuration.
#
sub getmotelogconfig($)
{
    my ($rptr)   = @_;
    my @motelogs = ();

    if (tmcc(TMCCCMD_MOTELOG, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get motelog config from server!\n");
	return -1;
    }

    my $pat  = q(MOTELOGID=([-\w]+) CLASSFILE=([\.]+) SPECFILE=([\.]*));

    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    push(@motelogs, { "MOTELOGID" => $1,
			      "CLASSFILE" => $2,
			      "SPECFILE"  => $3
			    });
	}
	else {
	    warn("*** WARNING: Bad motelog line: $str\n");
	}
    }
    @$rptr = @motelogs;
    return 0;
}

#
# Get load info.
#
sub getloadinfo($)
{
    my ($rptr)   = @_;
    my @retval = ();
    my @tmccresults = ();
    # don't cache this stuff, can't get stale reload info!
    my %opthash = ( 'nocache' => 1 );

    if (tmcc(TMCCCMD_LOADINFO, undef, \@tmccresults, %opthash) < 0) {
	warn("*** WARNING: Could not get loadinfo from server!\n");
	return -1;
    }

    # accept any key/val pair with basic formatting
    foreach my $res (@tmccresults) {
	chomp($res);
	my @kvs = split(/\s+/,$res);
	my %resh = ();
	foreach my $kv (@kvs) {
	    my @kvpair = split(/=/,$kv);
	    if (scalar(@kvpair) != 2) {
		#
		# Ick. ADDR is a URL.
		#
		if ($kvpair[0] eq "ADDR") {
		    my $key = shift(@kvpair);
		    $resh{$key} = join("=", @kvpair);
		}
		else {
		    warn("*** WARNING: ".
			 "malformed key-val pair in loadinfo: $kv\n");
		}
	    }
	    else {
		$resh{$kvpair[0]} = $kvpair[1];
	    }
	}
	push @retval, \%resh;
    }

    @$rptr = @retval;
    return 0;
}

#
# Get load info.
#
sub getbootwhat($)
{
    my ($rptr)   = @_;
    my @retval = ();
    my @tmccresults = ();
    # don't cache this stuff, can't get stale boot info!
    my %opthash = ( 'nocache' => 1 );

    if (tmcc(TMCCCMD_BOOTWHAT, undef, \@tmccresults, %opthash) < 0) {
	warn("*** WARNING: Could not get bootwhat from server!\n");
	return -1;
    }

    # accept any key/val pair with basic formatting
    foreach my $res (@tmccresults) {
	chomp($res);
	my @kvs = split(/\s+/,$res);
	my %resh = ();
	foreach my $kv (@kvs) {
	    my @kvpair = split(/=/,$kv);
	    if (scalar(@kvpair) != 2) {
		warn("*** WARNING: malformed key-val pair in bootwhat: $kv\n");
	    }
	    else {
		$resh{$kvpair[0]} = $kvpair[1];
	    }
	}
	push @retval, \%resh;
    }

    @$rptr = @retval;
    return 0;
}

#
# Copy a file from an NFS filesystem.
# Supports retry on errors when the NFS filesystem is known to be "racy."
# On error, it is up to the caller to remove the target.
# Returns 1 on success, 0 otherwise.
#
sub copyfilefromnfs($$$)
{
    my ($ffile, $tfile, $showerrs) = @_;
    my $tries = 1;

    #
    # If the file server doesn't have the BSD mountd NFS export race
    # we just use the system cp command.
    #
    if (FSRVTYPE() ne "NFS-RACY") {
	my $redir = ">/dev/null 2>&1";
	if ($showerrs) {
	    $redir = "";
	}
	if (system("cp -fp $ffile $tfile $redir") == 0) {
	    return 1;
	}
	return 0;
    }

    if (!open(IN, "< $ffile")) {
	if ($showerrs) {
	    print STDERR "$ffile: could not open for read: $!\n";
	}
	return 0;
    }
    binmode IN;

    if (!open(OUT, "> $tfile")) {
	if ($showerrs) {
	    print STDERR "$tfile: could not open for write: $!\n";
	}
	return 0;
    }
    binmode OUT;

    #
    # Deal with NFS read failures
    #
    my $foffset = 0;
    my $retries = 5;
    my $rval = 1;

    while (1) {
	my $buf;

	my $rlen = sysread(IN, $buf, 8192);
	if (!defined($rlen)) {
	    #
	    # If we are copying the file via NFS, retry a few times
	    # on error to avoid the changing-exports-file server problem.
	    #
	    if ($retries > 0 && sysseek(IN, $foffset, 0)) {
		if ($showerrs) {
		    print STDERR "*** WARNING retrying read of $ffile ".
			"at offset $foffset\n";
		}
		$retries--;
		sleep(1);
		next;
	    }
	    if ($showerrs) {
		print STDERR "$ffile: error reading file: $!\n";
	    }
	    $rval = 0;
	    last;
	}
	if ($rlen == 0) {
	    last;
	}
	if (!syswrite(OUT, $buf)) {
	    if ($showerrs) {
		print STDERR "$tfile: error writing file: $!\n";
	    }
	    $rval = 0;
	    last;
	}
	$foffset += $rlen;
	$retries = 5;
    }
    close(OUT);
    close(IN);

    return $rval;
}

my %fwvars = ();

#
# Not pretty, but...
#
sub insubnet($$)
{
    my ($netspec,$addr) = @_;
    my ($net,$mask);
    my @NETMASKS = (
	0x10000000,						#  0
	0x80000000, 0xC0000000, 0xE0000000, 0xF0000000,		#  1 -	4
	0xF8000000, 0xFC000000, 0xFE000000, 0xFF000000,		#  5 -	8
	0xFF800000, 0xFFC00000, 0xFFE00000, 0xFFF00000,		#  9 - 12
	0xFFF80000, 0xFFFC0000, 0xFFFE0000, 0xFFFF0000,		# 13 - 16
	0xFFFF8000, 0xFFFFC000, 0xFFFFE000, 0xFFFFF000,		# 17 - 20
	0xFFFFF800, 0xFFFFFC00, 0xFFFFFE00, 0xFFFFFF00,		# 21 - 24
	0xFFFFFF80, 0xFFFFFFC0, 0xFFFFFFE0, 0xFFFFFFF0,		# 25 - 28
	0xFFFFFFF8, 0xFFFFFFFC, 0xFFFFFFFE, 0xFFFFFFFF		# 29 - 32
    );

    if ($netspec =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/) {
	return 0
	    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255 || $5 > 32);
	$mask = $NETMASKS[$5];
	$net = (($1 << 24) | ($2 << 16) | ($3 << 8) | $4);
	$net &= $mask;
    } else {
	return 0;
    }

    if ($addr =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	return 0
	    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255);
	$addr = (($1 << 24) | ($2 << 16) | ($3 << 8) | $4);
	$addr &= $mask;
    }

    return ($addr == $net);
}

#
# Substitute values of variables in a firewall rule.
#
sub expandfwvars($)
{
    my ($rule) = @_;

    if ($rule->{RULE} =~ /EMULAB_\w+/) {
	foreach my $key (keys %fwvars) {
	    $rule->{RULE} =~ s/$key/$fwvars{$key}/g
		if (defined($fwvars{$key}));
	}
	if ($rule->{RULE} =~ /EMULAB_\w+/) {
	    warn("*** WARNING: Unexpanded firewall variable in: \n".
		 "    $rule->{RULE}\n");
	    return 1;
	}
    }
    return 0;
}

#
# Return the firewall configuration. We parse tmcd output here and return
# a list of hash entries to the caller.
#
sub getfwconfig($$;$)
{
    my ($infoptr, $rptr, $hptr) = @_;
    my @tmccresults = ();
    my $fwinfo      = {};
    my @fwrules     = ();
    my @fwhosts	    = ();
    my %fwhostmacs  = ();
    my %fwhostips   = ();
    my %fwsrvmacs   = ();

    $$infoptr = undef;
    @$rptr = ();
    if (tmcc(TMCCCMD_FIREWALLINFO, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get firewall info from server!\n");
	return -1;
    }

    my $rempat = q(TYPE=remote FWIP=([\d\.]*));
    my $fwpat  = q(TYPE=([-\w]+) STYLE=(\w+) IN_IF=(\w*) OUT_IF=(\w*) IN_VLAN=(\d+) OUT_VLAN=(\d+));
    my $rpat   = q(RULENO=(\d*) RULE="(.*)");
    my $vpat   = q(VAR=(EMULAB_\w+) VALUE="(.*)");
    my $hpat   = q(HOST=([-\w]+) CNETIP=([\d\.]*) CNETMAC=([\da-fA-F]{12}));
    my $spat   = q(SERVER=([-\w]+) CNETIP=([\d\.]*) CNETMAC=([\da-fA-F]{12}));
    my $lpat   = q(LOG=([\w,]+));

    $fwinfo->{"TYPE"} = "none";
    foreach my $line (@tmccresults) {
	if ($line =~ /TYPE=([\w-]+)/) {
	    my $type = $1;
	    if ($type eq "none") {
		$fwinfo->{"TYPE"} = $type;
		$$infoptr = $fwinfo;
		return 0;
	    }
	    if ($line =~ /$rempat/) {
		my $fwip = $1;

		$fwinfo->{"TYPE"} = "remote"
		    if (!defined($fwinfo->{"TYPE"}));
		$fwinfo->{"FWIP"} = $fwip;
	    } elsif ($line =~ /$fwpat/) {
		my $style = $2;
		my $inif = $3;
		my $outif = $4;
		my $invlan = $5;
		my $outvlan = $6;

		$fwinfo->{"TYPE"} = $type;
		$fwinfo->{"STYLE"} = $style;
		$fwinfo->{"IN_IF"}  = $inif;
		$fwinfo->{"OUT_IF"} = $outif;
		$fwinfo->{"IN_VLAN"}  = $invlan
		    if ($invlan != 0);
		$fwinfo->{"OUT_VLAN"} = $outvlan
		    if ($outvlan != 0);
	    } else {
		warn("*** WARNING: Bad firewall info line: $line\n");
		return 1;
	    }
	} elsif ($line =~ /$rpat/) {
	    my $ruleno = $1;
	    my $rule = $2;

	    my $fw = {};
	    $fw->{"RULENO"} = $ruleno;
	    $fw->{"RULE"} = $rule;
	    push(@fwrules, $fw);
	} elsif ($line =~ /$vpat/) {
	    $fwvars{$1} = $2;
	} elsif ($line =~ /$hpat/) {
	    my $host = $1;
	    my $ip = $2;
	    my $mac = $3;

	    # create a tmcc hostlist format string
	    push(@fwhosts,
		 "NAME=$host IP=$ip ALIASES=''");

	    # and save off the MACs and IPs
	    $fwhostmacs{$host} = $mac;
	    $fwhostips{$host} = $ip;
	} elsif ($line =~ /$spat/) {
	    my $srv = $1;
	    my $ip = $2;
	    my $mac = $3;

	    #
	    # Save off the MACs. Note that since we hash by IP address
	    # we get a unique set of nodes. This is desirable for setups
	    # where, e.g., ops == fs.
	    #
	    $fwsrvmacs{$ip} = $mac;
	} elsif ($line =~ /$lpat/) {
	    for my $log (split(',', $1)) {
		if ($log =~ /^allow|accept$/) {
		    $fwinfo->{"LOGACCEPT"} = 1;
		} elsif ($log =~ /^deny|reject$/) {
		    $fwinfo->{"LOGREJECT"} = 1;
		} elsif ($log eq "tcpdump") {
		    $fwinfo->{"LOGTCPDUMP"} = 1;
		}
	    }
	} else {
	    #
	    # This used to be fatal. But having unexpected input lines blow
	    # up the firewall is probably worse than ignoring the lines.
	    # And it requires that we bump the tmcd version number and
	    # conditionalize tmcd when we add new line types (which I had
	    # to do when I added server lines).
	    #
	    warn("*** WARNING: Bad firewall info line: $line\n");
	}
    }

    @tmccresults = ();
    if (tmcc(TMCCCMD_PUBLICADDRINFO, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get public addr info from server;".
	     " ignoring!\n");
    }
    else {
	my @publicaddrs = ();
	my $papat = q(IP="([0-9\.]+)" MASK="([0-9\.]*)" NODE_ID="([-\w]*)" POOL_ID="([-\w]*)");
	foreach my $line (@tmccresults) {
	    if ($line =~ /$papat/) {
		# Just pass along the IP address for now; it's unclear
		# what the node_id and pool_id should mean to the
		# firewall.  So just treat all publicaddrs as equal.
		push(@publicaddrs,$1);
	    }
	    else {
		warn("*** WARNING: Bad public addr info line: $line\n");
	    }
	}
	$fwinfo->{"PUBLICADDRS"} = \@publicaddrs;
	$fwvars{"EMULAB_PUBLICADDRS"} = join(",",@publicaddrs);
    }

    #
    # Define the local experiment domain so that people can use
    # nickname-based FQDNs to refer to the control net IPs of nodes.
    #
    my $mydomain = `cat $BOOTDIR/mydomain`;
    chomp($mydomain);
    if (!defined($fwvars{"EMULAB_EXPDOMAIN"})) {
	my $nickname = `cat $BOOTDIR/nickname`;
	chomp($nickname);
	if ($nickname =~ /[^.]+\.(.+)/) {
	    $fwvars{"EMULAB_EXPDOMAIN"} = "${1}.${mydomain}";
	}
    }
    #
    # Define the local cluster domain so that people can use FQDNs to
    # refer to the control net IPs of key servers.
    #
    if (!defined($fwvars{"EMULAB_DOMAIN"})) {
	my $mydomain = `cat $BOOTDIR/mydomain`;
	chomp($mydomain);
	$fwvars{"EMULAB_DOMAIN"} = $mydomain;
    }

    #
    # XXX inner elab: make sure we have "myops" and "myfs" entries.
    #
    # If there is no myops we are doing ops-as-a-jail. Here we alias both
    # myops and myfs to myboss; not right, but good enough.
    # 
    # If just myfs is not defined, then ops is the file server and we
    # alias myfs to myops.
    #
    if (defined($fwhostmacs{"myboss"})) {
	if (!defined($fwhostmacs{"myops"})) {
	    for my $host (@fwhosts) {
		if ($host =~ /NAME=myboss/) {
		    $host =~ s/ALIASES=''/ALIASES='myops myfs'/;
		}
	    }
	} elsif (!defined($fwhostmacs{"myfs"})) {
	    for my $host (@fwhosts) {
		if ($host =~ /NAME=myops/) {
		    $host =~ s/ALIASES=''/ALIASES='myfs'/;
		}
	    }
	}
    }

    if (defined($fwvars{"EMULAB_GWIP"})) {
        # merge GW info into fwsrvmacs hash
        $fwsrvmacs{$fwvars{"EMULAB_GWIP"}} = $fwvars{"EMULAB_GWMAC"};
        $fwsrvmacs{$fwvars{"EMULAB_GWIP"}} =~ s/://g;
    }

    my $vgwip = "";
    if (defined($fwvars{"EMULAB_VGWIP"})) {
        # XXX assume vnode GW is just an alias for the real GW (same MAC)
        $fwsrvmacs{$fwvars{"EMULAB_VGWIP"}} = $fwvars{"EMULAB_GWMAC"};
        $fwsrvmacs{$fwvars{"EMULAB_VGWIP"}} =~ s/://g;
	$vgwip = $fwvars{"EMULAB_VGWIP"};
    }

    # info for proxy ARP, to publish inside...
    if (%fwsrvmacs) {
	#
	# Prune out any that are not on the EMULAB_CNET.
	#
	if (!exists($fwvars{"EMULAB_CNET"})) {
	    $fwinfo->{"SRVMACS"} = \%fwsrvmacs;
	} else {
	    my %lsrv = ();
	    foreach my $ip (keys %fwsrvmacs) {
		if (insubnet($fwvars{"EMULAB_CNET"}, $ip) ||
		    $ip eq $vgwip) {
		    $lsrv{$ip} = $fwsrvmacs{$ip};
		}
	    }
	    if (%lsrv) {
		$fwinfo->{"SRVMACS"} = \%lsrv;
	    }
	}
    }
    # ...and outside.
    if (%fwhostmacs) {
	$fwinfo->{"MACS"} = \%fwhostmacs;
    }
    if (%fwhostips) {
	$fwinfo->{"IPS"} = \%fwhostips;
    }
    

    # make a pass over the rules, expanding variables
    my $bad = 0;
    foreach my $rule (@fwrules) {
	$bad += expandfwvars($rule);
    }

    # return the variables too
    $fwinfo->{"VARS"} = \%fwvars;

    $$infoptr = $fwinfo;
    @$rptr = @fwrules;
    @$hptr = @fwhosts;
    return $bad;
}


#
# All we do is store it away in the file. This makes it avail later.
#
sub dojailconfig()
{
    my @tmccresults;

    if (tmcc(TMCCCMD_JAILCONFIG, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get jailconfig from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    if (!open(RC, ">" . TMJAILCONFIG)) {
	warn "*** WARNING: Could not write " . TMJAILCONFIG . "\n";
	return -1;
    }
    foreach my $str (@tmccresults) {
	print RC $str;
    }
    close(RC);
    chmod(0755, TMJAILCONFIG);
    return 0;
}

#
# Boot Startup code. This is invoked from the setup OS dependent script,
# and this fires up all the stuff above.
#
sub bootsetup()
{
    my $oldpid;

    # Tell libtmcc to forget anything it knows.
    tmccclrconfig();

    #
    # Watch for a change in project membership. This is not supposed
    # to happen, but it is good to check for this anyway just in case.
    # A little tricky though since we have to know what project we used
    # to be in. Use the nickname file for that.
    #
    if (-e TMNICKNAME) {
	($oldpid) = check_nickname();
	unlink TMNICKNAME;
    }

    #
    # Check allocation. Exit now if not allocated.
    #
    if (! check_status()) {
	print STDOUT "  Node is free!\n";
	cleanup_node(1);
	return undef;
    }

    #
    # Project Change?
    #
    if (defined($oldpid) && ($oldpid ne $pid)) {
	print STDOUT "  Node switched projects: $oldpid\n";
	# This removes the nickname file, so do it again.
	cleanup_node(1);
	check_status();
	# Must reset the passwd/group file. Yuck.
	system("$BINDIR/rc/rc.accounts reset");
    }
    else {
	#
	# Cleanup node. Flag indicates to gently clean ...
	#
	cleanup_node(0);
    }
    print STDOUT "  Allocated! $pid/$eid/$vname\n";

    #
    # Setup SFS hostid. Must do this before asking tmcd for config.
    #
    if (!MFS()) {
	print STDOUT "Setting up for SFS ... \n";
	initsfs();
    }

    #
    # Tell libtmcc to get the full config. Note that this must happen
    # AFTER initsfs() right above, since that changes what tmcd
    # is going to tell us.
    #
    tmccgetconfig();

    #
    # Get the role of this node from tmcc which can be one of
    # "node", "virthost", "delaynode" or "simhost".
    # Mainly useful for simulation (nse) stuff
    # Hopefully, this will come out of the tmcc cache and will not
    # be expensive.
    #
    dorole();

    #
    # And the nodeid.
    #
    donodeid();

    return ($pid, $eid, $vname);
}

#
# Shadow mode setup. The server argument is the remote boss we talk to.
#
sub shadowsetup($$)
{
    my ($server, $idkey) = @_;

    $shadow = 1;

    # This changes where tmcc is going to store the data.
    libtmcc::configtmcc("cachedir", $SHADOWDIR);
    libtmcc::configtmcc("server", $server);
    libtmcc::configtmcc("idkey", $idkey);

    # No proxy.
    libtmcc::configtmcc("noproxy", 1);

    # Tell children.
    $ENV{'SHADOW'} = "$server,$idkey";
    $ENV{'IDKEY'}  = $idkey;

    # Tell libtmcc to forget anything it knows.
    tmccclrconfig();

    #
    # Check allocation. Exit now if not allocated.
    #
    if (! check_status()) {
	return undef;
    }
    print STDOUT "  Allocated! $pid/$eid/$vname\n";

    #
    # Tell libtmcc to get the full config.
    #
    tmccgetconfig();

    #
    # Get the role of this node from tmcc which can be one of
    # "node", "virthost", "delaynode" or "simhost".
    # Mainly useful for simulation (nse) stuff
    # Hopefully, this will come out of the tmcc cache and will not
    # be expensive.
    #
    dorole();

    #
    # And the nodeid.
    #
    donodeid();

    my $eiddir = EXPDIR() . "/tbdata";
    os_mkdir($eiddir, "0777");

    return ($pid, $eid, $vname);
}

#
# This happens inside a jail.
#
sub jailsetup()
{
    #
    # Currently, we rely on the outer environment to set our vnodeid
    # into the environment so we can get it! See mkjail.pl.
    #
    my $vid = $ENV{'TMCCVNODEID'};

    #
    # Set global vnodeid for tmcc commands. Must be before all the rest!
    #
    libsetup_setvnodeid($vid);
    $injail   = 1;

    #
    # Create a file inside so that libsetup inside the jail knows its
    # inside a jail and what its ID is.
    #
    system("echo '$vnodeid' > " . TMJAILNAME());
    # Need to unify this with jailname.
    system("echo '$vnodeid' > " . TMNODEID());

    #
    # Always remove the old nickname file.  No need to worry about a project
    # change at this level (see bootsetup) but we do need to make sure we
    # pick up on a vnode/jail being reassigned to a different virtual node.
    #
    unlink TMNICKNAME;

    print STDOUT "Checking Testbed reservation status ... \n";
    if (! check_status()) {
	print STDOUT "  Free!\n";
	return 0;
    }
    print STDOUT "  Allocated! $pid/$eid/$vname\n";

    print STDOUT "Checking Testbed jail configuration ...\n";
    dojailconfig();

    return ($pid, $eid, $vname);
}

#
# Bogus emulation of jails without a jail,
#
sub fakejailsetup()
{
    $nojail = 1;

    # Stick this into the environment so that sub processes know.
    $ENV{'FAKEJAIL'} = $vnodeid;

    #
    # Create a file inside so that libsetup inside the jail knows its
    # inside a jail and what its ID is.
    #
    system("echo '$vnodeid' > " . TMFAKEJAILNAME());
    # Need to unify this with jailname.
    system("echo '$vnodeid' > " . TMNODEID());

    #
    # Always remove the old nickname file.  No need to worry about a project
    # change at this level (see bootsetup) but we do need to make sure we
    # pick up on a vnode/jail being reassigned to a different virtual node.
    #
    unlink TMNICKNAME;

    print STDOUT "Checking Testbed reservation status ... \n";
    if (! check_status()) {
	print STDOUT "  Free!\n";
	return 0;
    }
    print STDOUT "  Allocated! $pid/$eid/$vname\n";

    return ($pid, $eid, $vname);
}

#
# Remote Node virtual node jail setup. This happens outside the jailed
# env.
#
sub vnodejailsetup($)
{
    my ($vid) = @_;

    #
    # Set global vnodeid for tmcc commands.
    #
    libsetup_setvnodeid($vid);

    #
    # This is the directory where the rc files go.
    #
    if (! -e JAILDIR()) {
	die("*** $0:\n".
	    "    No such directory: " . JAILDIR() . "\n");
    }

    #
    # Always remove the old nickname file.  No need to worry about a project
    # change at this level (see bootsetup) but we do need to make sure we
    # pick up on a vnode/jail being reassigned to a different virtual node.
    #
    unlink TMNICKNAME;

    # Do not bother if somehow got released.
    if (! check_status()) {
	print "Node is free!\n";
	return undef;
    }

    #
    # Create /local directories for users.
    #
    if (! -e LOCALROOTFS()) {
	os_mkdir(LOCALROOTFS(), "0755");
    }
    if (-e LOCALROOTFS()) {
	my $piddir = LOCALROOTFS() . "/$pid";
	my $eiddir = LOCALROOTFS() . "/$pid/$eid";
	my $viddir = LOCALROOTFS() . "/$pid/$vid";

	if (! -e $piddir) {
	    mkdir($piddir, 0777) or
		die("*** $0:\n".
		    "    mkdir filed - $piddir: $!\n");
	}
	if (! -e $eiddir) {
	    mkdir($eiddir, 0777) or
		die("*** $0:\n".
		    "    mkdir filed - $eiddir: $!\n");
	}
	if (! -e $viddir) {
	    mkdir($viddir, 0775) or
		die("*** $0:\n".
		    "    mkdir filed - $viddir: $!\n");
	}
	chmod(0777, $piddir);
	chmod(0777, $eiddir);
	chmod(0775, $viddir);
    }

    #
    # Tell libtmcc to get the full config for the jail. At the moment
    # we do not use SFS inside jails, so okay to do this now (usually
    # have to call initsfs() first). The full config will be copied
    # to the proper location inside the jail by mkjail.
    #
    tmccgetconfig();

    #
    # Get jail config.
    #
    print STDOUT "Checking Testbed jail configuration ...\n";
    dojailconfig();

    return ($pid, $eid, $vname);
}

#
# All we do is store it away in the file. This makes it avail later.
#
sub stashgenvnodeconfig()
{
    my @tmccresults;

    # XXX: use GENVNODECONFIG once it's written!
    if (tmcc(TMCCCMD_JAILCONFIG, undef, \@tmccresults) < 0) {
	warn("*** WARNING: Could not get genvnodeconfig from server!\n");
	return -1;
    }
    return 0
	if (! @tmccresults);

    if (!open(RC, ">" . TMGENVNODECONFIG)) {
	warn "*** WARNING: Could not write " . TMGENVNODECONFIG . "\n";
	return -1;
    }
    foreach my $str (@tmccresults) {
	print RC $str;
    }
    close(RC);
    chmod(0755, TMGENVNODECONFIG);
    return 0;
}

#
# Return the generic vnode config info in a hash.  XXX: For now uses jailconfig.
#
sub getgenvnodeconfig($)
{
    my ($rptr) = @_;
    my @tmccresults = ();
    my %vconfig = ();
    my $issharedhost = SHAREDHOST();

    my %tmccopts = ();
    if ($issharedhost) {
	$tmccopts{"nocache"} = 1;
    }

    # XXX uses jailconfig instead of genvmconfig
    if (tmcc(TMCCCMD_JAILCONFIG, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get genvmconfig from server!\n");
	%$rptr = ();
	return -1;
    }

    foreach my $line (@tmccresults) {
	if ($line =~ /^(.*)="(.*)"$/ ||
	    $line =~ /^(.*)=(.+)$/) {
	    if ($1 eq 'JAILIP'
		&& $2 =~ /^(\d+\.\d+\.\d+\.\d+),(\d+\.\d+\.\d+\.\d+)$/) {
		$vconfig{"CTRLIP"} = $1;
		$vconfig{"CTRLMASK"} = $2;
	    }
	    else {
		$vconfig{$1} = $2;
	    }
	}
    }

    %$rptr = %vconfig;
    return 0;
}

#
# Virtual node vm setup. This happens outside in the root context.
#
sub genvnodesetup($;$$)
{
    my ($vid) = @_;
    my $issharedhost = (SHAREDHOST() || STORAGEHOST());

    #
    # Set global vnodeid for tmcc commands.
    #
    libsetup_setvnodeid($vid);

    #
    # This is the directory where the rc files go.
    #
    if (! -e GENVNODEDIR()) {
	os_mkdir(GENVNODEDIR(),"0755");
	#die("*** $0:\n".
	#    "    No such directory: " . GENVNODEDIR() . "\n");
    }

    #
    # Always remove the old nickname file.  No need to worry about a project
    # change at this level (see bootsetup) but we do need to make sure we
    # pick up on a vnode/jail being reassigned to a different virtual node.
    #
    unlink TMNICKNAME;

    # Do not bother if somehow got released.
    if (! check_status()) {
	print "Node is free!\n";
	return undef;
    }

    #
    # Create /local directories for users.
    #
    if (! -e LOCALROOTFS()) {
	os_mkdir(LOCALROOTFS(), "0755");
    }
    if (-e LOCALROOTFS()) {
	my $piddir = LOCALROOTFS() . "/$pid";
	my $eiddir = LOCALROOTFS() . "/$pid/$eid";
	my $viddir = LOCALROOTFS() . "/$pid/$vid";

	#
	# Watch for EEXIST cause of concurrency on shared node hosts.
	#
	if (! -e $piddir) {
	    if (! mkdir($piddir, 0777)) {
		die("*** $0:\n".
		    "    mkdir filed - $piddir: $!\n")
		    if ($! != Errno::EEXIST());
	    }
	}
	if (! -e $eiddir) {
	    if (! mkdir($eiddir, 0777)) {
		die("*** $0:\n".
		    "    mkdir filed - $eiddir: $!\n")
		    if ($! != Errno::EEXIST());
	    }
	}
	if (! -e $viddir) {
	    if (!mkdir($viddir, 0775)) {
		die("*** $0:\n".
		    "    mkdir filed - $viddir: $!\n")
		    if ($! != Errno::EEXIST());
	    }
	}
	chmod(0777, $piddir);
	chmod(0777, $eiddir);
	chmod(0775, $viddir);
    }

    #
    # Tell libtmcc to get the full config for the jail. The full config
    # will be copied to the proper location inside the jail by mkjail.
    #
    tmccclrconfig()
	if ($issharedhost);
    tmccgetconfig();

    donodeuuid();

    #
    # XXX: Get jail config.  For now we just snoop on this, but should do our
    # own later.
    #
    print STDOUT "Checking Testbed generic VM configuration ...\n";
    stashgenvnodeconfig();

    return ($pid, $eid, $vname);
}

#
# This happens inside a Plab vserver.
#
sub plabsetup()
{
    # Tell libtmcc to forget anything it knows.
    tmccclrconfig();

    #
    # vnodeid will either be found in BEGIN block or will be passed to
    # vnodeplabsetup, so it doesn't need to be found here
    #
    print STDOUT "Checking Testbed reservation status ... \n";
    if (! check_status()) {
	print STDOUT "  Free!\n";
	return 0;
    }
    print STDOUT "  Allocated! $pid/$eid/$vname\n";

    #
    # Setup SFS hostid.
    #
    print STDOUT "Setting up for SFS ... \n";
    initsfs();

    #
    # Tell libtmcc to get the full config. Note that this must happen
    # AFTER initsfs() right above, since that changes what tmcd
    # is going to tell us.
    #
    tmccgetconfig();

    return ($pid, $eid, $vname);
}

#
# Remote node virtual node Plab setup.  This happens inside the vserver
# environment (because on Plab you can't escape)
#
sub vnodeplabsetup($)
{
    my ($vid) = @_;

    #
    # Set global vnodeid for tmcc commands.
    #
    libsetup_setvnodeid($vid);
    $inplab   = 1;

    # Do not bother if somehow got released.
    if (! check_status()) {
	print "Node is free!\n";
	return undef;
    }

    #
    # Create a file so that libsetup knows it's inside Plab and what
    # its ID is.
    #
    system("echo '$vnodeid' > $BOOTDIR/plabname");
    # Need to unify this with plabname.
    system("echo '$vnodeid' > $BOOTDIR/nodeid");

    return ($pid, $eid, $vname);
}

#
# IXP config. This happens on the outside since there is currently no
# inside setup (until there is a reasonable complete environment).
#
sub ixpsetup($)
{
    my ($vid) = @_;

    #
    # Set global vnodeid for tmcc commands.
    #
    libsetup_setvnodeid($vid);

    #
    # Config files go here.
    #
    if (! -e CONFDIR()) {
	die("*** $0:\n".
	    "    No such directory: " . CONFDIR() . "\n");
    }

    # Do not bother if somehow got released.
    if (! check_status()) {
	print "Node is free!\n";
	return undef;
    }
    $inixp    = 1;

    #
    # Different approach for IXPs. The ixp setup code will call the routines
    # directly.
    #

    return ($pid, $eid, $vname);
}

#
# Report startupcmd status back to TMCD. Called by the runstartup
# script.
#
sub startcmdstatus($;$)
{
    my($status,$timeout) = @_;
    my %opthash;
    if (defined($timeout)) {
	$opthash{'timeout'} = $timeout;
    }

    return(tmcc(TMCCCMD_STARTSTAT, "$status", undef, %opthash));
}

#
# Early on in the boot, we want to reset the hostname. This gets the
# nickname and returns it.
#
# This is going to get invoked very early in the boot process, before the
# normal client initialization. So we have to do a few things to make
# things are consistent.
#
sub whatsmynickname()
{
    #
    # Check allocation. Exit now if not allocated.
    #
    if (! check_status()) {
	return 0;
    }

    return "$vname.$eid.$pid";
}

#
# Return uuid for node.
#
sub getnodeuuid()
{
    my $uuidfile = TMNODEUUID();
    my $nodeuuid = `cat $uuidfile`;
    return undef
	if ($?);
	    
    chomp($nodeuuid);
    return $nodeuuid;
}

#
# Return the node attributes in a key/value array.
#
sub getnodeattributes($)
{
    my ($rptr) = @_;
    my @tmccresults = ();
    my %result = ();
    my $issharedhost = SHAREDHOST();

    my %tmccopts = ();
    if ($issharedhost) {
	$tmccopts{"nocache"} = 1;
    }

    if (tmcc(TMCCCMD_NODEATTRIBUTES, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get node attributes from server!\n");
	%$rptr = ();
	return -1;
    }

    foreach my $line (@tmccresults) {
	if ($line =~ /^(.*)="(.*)"$/ ||
	    $line =~ /^(.*)=(.+)$/) {
	    $result{$1} = $2;
	}
    }

    %$rptr = %result;
    return 0;
}

#
# Return the environment variables in a key/value array.
#
sub getenvvars($)
{
    my ($rptr) = @_;
    my @tmccresults = ();
    my %result = ();
    my $issharedhost = SHAREDHOST();

    my %tmccopts = ();
    if ($issharedhost) {
	$tmccopts{"nocache"} = 1;
    }

    if (tmcc(TMCCCMD_USERENV, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get environment vars from server!\n");
	%$rptr = ();
	return -1;
    }

    foreach my $line (@tmccresults) {
	if ($line =~ /^(.*)="(.*)"$/ ||
	    $line =~ /^(.*)=(.+)$/) {
	    $result{$1} = $2;
	}
    }

    %$rptr = %result;
    return 0;
}

#
# Return the service info in a key/value array.
#
sub getserviceinfo($)
{
    my ($rptr) = @_;
    my @tmccresults = ();
    my %result = ();
    my $issharedhost = SHAREDHOST();

    my %tmccopts = ();
    if ($issharedhost) {
	$tmccopts{"nocache"} = 1;
    }

    if (tmcc(TMCCCMD_SERVINCEINFO, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get service info from server!\n");
	%$rptr = ();
	return -1;
    }

    foreach my $line (@tmccresults) {
	foreach my $token (split(/\s+/, $line)) {
	    if ($token =~ /^(.*)="(.*)"$/ ||
		$token =~ /^(.*)=(.+)$/) {
		$result{$1} = $2;
	    }
	}
    }

    %$rptr = %result;
    return 0;
}

#
# Return the hostname or IP to use for a local event server.
# Defaults to "localhost" for most nodes or the physical host IP for Xen VMs.
# The value can be overridden on a per-host basis via a local file.
#
sub getlocalevserver()
{
    my $evserver = "localhost";

    if (-e "$BOOTDIR/localevserver") {
	$evserver = `cat $BOOTDIR/localevserver`;
	chomp($evserver);
    }
    elsif (INXENVM()) {
	#
	# XXX gawdawful hack alert!
	# Will only work with Utah naming convention.
	#
	if ($vnodeid =~ /^pcvm(\d+)-\d+$/) {
	    $evserver = "pc$1";
	}
        elsif ($vnodeid =~ /^([-\w]+)vm\-(\d+)$/) {
	    $evserver = "$1";
	}
	else {
	    print STDERR "*** Could not determine event server!\n";
	}
    }
    return $evserver;
}

#
# Return a hash of arpinfo provided by boss in $rptr.
# Note that the hash key is the IP address and not the name.
# Function returns the type of the arp configuration or undef on error.
#
sub getarpinfo($;$)
{
    my ($rptr,$timo) = @_;
    my %arpinfo = ();
    my @tmccresults = ();
    # don't cache
    my %opthash = ( 'nocache' => 1 );
    if (defined($timo) && $timo > 0) {
	$opthash{'timeout'} = $timo;
    }

    if (tmcc(TMCCCMD_ARPINFO, undef, \@tmccresults, %opthash) < 0) {
	warn("*** WARNING: Could not get arpinfo from server!\n");
	return undef;
    }

    #
    # First line should be the type:
    #  ARPTYPE=(none|static|staticonly)
    #
    my $atype = "none";

    #
    # The remaining lines are entries for hosts and servers, e.g.:
    #  SERVER=gw CNETIP=155.98.36.1 CNETMAC=00d0bcf414f8
    #  SERVER=subboss CNETIP=155.98.38.162 CNETMAC=001f29329224
    #  HOST=pc271 CNETIP=155.98.39.71 CNETMAC=001143e43be6
    #
    my $pat = q((HOST|SERVER)=([-\w]+) CNETIP=([\d\.]*) CNETMAC=([\da-fA-F]{12}));

    foreach my $line (@tmccresults) {
	if ($line =~ /ARPTYPE=([-\w]+)/) {
	    $atype = $1;
	    if ($atype eq "static" || $atype eq "staticonly") {
		next;
	    }
	    if ($atype ne "none") {
		warn("*** WARNING: arpinfo: invalid type '$atype', assuming 'none'!\n");
		$atype = "none";
	    }
	    last;
	}
	if ($line =~ /$pat/) {
	    my $ntype = $1;
	    my $name = $2;
	    my $ip = $3;
	    my $mac = $4;

	    # canonicalize the MAC
	    $mac = lc($mac);
	    if ($mac =~ /^(..)(..)(..)(..)(..)(..)$/) {
		$mac = "$1:$2:$3:$4:$5:$6";
	    }

	    if (exists($arpinfo{$ip})) {
		# XXX subbosses may appear twice since they are testnodes
		# XXX boss may appear as both boss and gw in elabinelab
		if ($arpinfo{$ip}{'mac'} ne $mac) {
		    warn("*** WARNING: Conflicting arpinfo for $ip: '$line'\n");
		} else {
		    $arpinfo{$ip}{'type'} = $ntype
			if ($ntype eq "SERVER");
		}
	    } else {
		$arpinfo{$ip}{'type'} = $ntype;
		$arpinfo{$ip}{'name'} = $name;
		$arpinfo{$ip}{'mac'} = $mac;
	    }
	} else {
	    warn("*** WARNING: Bad arpinfo info line ignored: '$line'\n");
	}
    }

    if ($atype eq "none") {
	%$rptr = ();
    } else {
	%$rptr = %arpinfo;
    }
    return $atype;
}

#
# Grab and parse the storageconfig tmcd command output. Break each
# line into a hash, verifying the fields.  Return sorted (by index)
# list of storage commands hashes.
#
# ELEMENT format:
#
# CMD=ELEMENT IDX=<index> HOSTID=<some-storage-host> \
#   CLASS=(SAN|local) PROTO=(iSCSI|local) \
#   UUID=<unique-id> UUID_TYPE=<id-type> \
#   VOLNAME=<id> VOLSIZE=<size-in-MiB> PERMS=<permissions>
#
# Where:
#  
# if CLASS=="SAN" && PROTO=="iSCSI" :
# IDX :=
#   \d+ -- monotonically increasing number indicating order of operations
# HOSTID :=
#   <bs-vm-shortname> -- short name for blockstore pseudo-VM
# UUID :=
#   "iqn.2000-12.net.emulab:<pid>:<eid>:<bs-vname>" -- iSCSI qualified name
#   constructed from static prefix, pid, eid, and blockstore vname (from ns file).
# UUID_TYPE :=
#   "iqn" -- literal string
# VOLNAME :=
#   string -- Emulab name for the element
# VOLSIZE :=
#   \d+ -- size in mebibytes. Informational; could be used for sanity checking.
# PERMS :=
#   (RO|RW) -- i.e., read-only or read-write.
# PERSIST :=
#   (0|1) -- 1 if this is a persistent (across swapins) storage element.
# 
# if CLASS=="local" :
# IDX :=
#   \d+ -- monotonically increasing number indicating order of operations
# HOSTID :=
#   "localhost" -- literal string
# UUID :=
#   \w+ -- unique serial number of device
# UUID_TYPE :=
#   "serial" -- literal string
# VOLNAME :=
#   string -- Emulab name for the element
# VOLSIZE :=
#   \d+ -- size in mebibytes. Informational; could be used for sanity checking.
# PERMS :=
#   <notpresent> -- this field will not show up for local elements
#
# SLICE format:
#
# CMD=SLICE IDX=<index> CLASS=local PROTO=<SAS|SCSI|SATA|NVMe> \
#   BSID=<local-disk-id> VOLNAME=<id> VOLSIZE=<size-in-MiB> MOUNTPOINT=<dir>
#
# Where:
#  
# if CLASS=="local" :
# IDX :=
#   \d+ -- monotonically increasing number indicating order of operations
# BSID :=
#   (ANY|SYSVOL|NONSYSVOL) -- i.e. where to take space from
#   "ANY" will take from any disk, possibly from multiple disks via
#	use of a logical volume manager
#   "SYSVOL" will take from any remaining space on the boot disk
#   "NONSYSVOL" will take from any space on any non-boot disk, possibly
#	from multiple disks via a LVM.
# VOLNAME :=
#   string -- Emulab name for the element
# VOLSIZE :=
#   \d+ -- size in mebibytes
# MOUNTPOINT :=
#   If specified, implies the creation of a filesystem and mounting on
#   the indicated directory.
# 
sub getstorageconfig($;$) {
    my ($rptr,$nocache) = @_;
    my @tmccresults = ();
    my %opthash = ();

    if (defined($nocache) && $nocache) {
	$opthash{'nocache'} = 1;
    }

    if (tmcc(TMCCCMD_STORAGE, undef, \@tmccresults, %opthash) < 0) {
	warn("*** WARNING: Could not get storageconfig from server!\n");
	return -1;
    }

    my %fields = (
	'CMD'	  => '(ELEMENT|EXPORT|SLICE)',
	'IDX'	  => '\d+',
        'BSID'    => '[-\w]+',
	'CLASS'	  => '(SAN|local)',
	'HOSTID'  => '[-\w\.]+',
	'MOUNTPOINT' => '\/[-\w\/\.]+',
	'PERMS'	  => '(RO|RW|CLONE)',
	'PERSIST' => '(0|1)',
	'PROTO'	  => '(iSCSI|local|SCSI|SAS|SATA|PATA|IDE|NVMe)',
	'UUID'	  => '[-\w\.:]+',
	'UUID_TYPE'=> '(iqn|serial)',
	'VOLNAME' => '[-\w]+',
	'VOLSIZE' => '\d+',
	'DATASET' => '[-\w\/\.:]+',
	'SERVER'  => '[-\w\.]+',
	'HOSTIP'  => '|(\d+\.\d+\.\d+\.\d+)',
	'HOSTMASK'=> '|(\d+\.\d+\.\d+\.\d+)',
    );
    my @ops = ();

    #
    # Note that any error is fatal since these lines are interdependent.
    #
    foreach my $line (@tmccresults) {
	chomp($line);

	#
	# Break the line into a hash of key/values
	#
	my @kvs = split(/\s+/, $line);
	my %res = ();
	foreach my $kv (@kvs) {
	    my ($key,$val,$foo) = split(/=/, $kv);
	    if (defined($foo)) {
		warn("*** WARNING: malformed key-val pair in storageinfo: '$kv'\n");
		return -1;
	    }

	    #
	    # Validate the info and untaint.
	    #
	    # Ignore unknown keywords (for compat), fail on unknown values.
	    # XXX we could also ignore unknown values, but that might leave
	    # us with an undefined/unexpected/undesirable default value.
	    #
	    if (!exists($fields{$key})) {
		warn("*** WARNING: invalid keyword '$key' in storageinfo ignored\n");
		next;
	    }
	    if ($val !~ /^$fields{$key}$/) {
		warn("*** WARNING: invalid value for $key in storageinfo: '$val'\n");
		return -1;
	    }
	    $res{$key} = $val;
	}
	push(@ops, \%res);
    }

    #
    # return operations in decreasing order of IDX.
    #
    my @sortedops = sort {$a->{'IDX'} <=> $b->{'IDX'}} @ops;

    @$rptr = @sortedops;
    return 0;
}

#
# If the storage subsystem is in use, read the contents of the diskinfo
# file it creates and create a hash of info keyed by device name.
#
sub getstoragediskinfo()
{
    my $infofile = TMDISKINFO();
    my %dinfo = ();

    if (-f "$infofile" && open(FD, "<$infofile")) {
	while ($line = <FD>) {
	    chomp($line);
	    my @kvs = split(/\s+/, $line);
	    my %thisone = ();
	    foreach my $kv (@kvs) {
		my ($key,$val) = split(/=/, $kv);
		if (!defined($val)) {
		    warn("*** WARNING: malformed key-val pair in diskinfo: '$kv'\n");
		    close(FD);
		    return undef;
		}
		$thisone{$key} = $val;
	    }
	    if (exists($thisone{"NAME"})) {
		$dinfo{$thisone{"NAME"}} = \%thisone;
	    } else {
		warn("*** WARNING: malformed diskinfo line: '$line'\n");
		close(FD);
		return undef;
	    }
	}
	close(FD);
	return \%dinfo;
    }
    return undef;
}

sub getimagesize($$;$) {
    my ($iname,$rptr,$nocache) = @_;
    my @tmccresults = ();
    my %opthash = ();

    if (defined($nocache) && $nocache) {
	$opthash{'nocache'} = 1;
    }

    if (tmcc(TMCCCMD_IMAGESIZE, $iname, \@tmccresults, %opthash) < 0 ||
	@tmccresults == 0) {
	warn("*** WARNING: Could not get imagesize from server!\n");
	return -1;
    }

    my %fields = (
	'IMAGELOW'    => '\d+',
	'IMAGEHIGH'   => '\d+',
	'IMAGESSIZE'  => '\d+',
	'IMAGERELOC'  => '(0|1)',
    );

    #
    # Note that any error is fatal since these lines are interdependent.
    #
    my $line = shift(@tmccresults);
    chomp($line);

    #
    # Break the line into a hash of key/values
    #
    my @kvs = split(/\s+/, $line);
    my %res = ();
    foreach my $kv (@kvs) {
	my ($key,$val,$foo) = split(/=/, $kv);
	if (defined($foo)) {
	    warn("*** WARNING: ".
		 "malformed key-val pair in imagesize: '$kv'\n");
	    return -1;
	}

	#
	# Validate the info and untaint.
	#
	if (!exists($fields{$key})) {
	    warn("*** WARNING: invalid keyword in imagesize: '$key'\n");
	    return -1;
	}
	if ($val !~ /^$fields{$key}$/) {
	    warn("*** WARNING: invalid value for $key in imagesize: ".
		 "'$val'\n");
	    return -1;
	}
	$res{$key} = $val;
    }
    $$rptr = \%res;
    return 0;
}

#
# Return set of node attributes relevant for PhantomNet experiments.
#
sub getpnetnodeattrs($)
{
    my ($rptr) = @_;
    my @tmccresults = ();
    my %result = ();
    my %tmccopts = ();

    if (tmcc(TMCCCMD_PNETNODEATTRS, undef, \@tmccresults, %tmccopts) < 0) {
	warn("*** WARNING: Could not get PhantomNet node attrs from server!\n");
	%$rptr = ();
	return -1;
    }

    foreach my $line (@tmccresults) {
	chomp $line;
	if ($line =~ /^NODE_ID=(.+) KEY=(.+) VALUE=(.+)$/) {
	    $result{$1}->{$2} = $3;
	}
    }

    %$rptr = %result;
    return 0;
}


#
# Fork a process to exec a command. Return the pid to wait on.
#
sub TBForkCmd($) {
    my ($cmd) = @_;
    my($mypid);

    $mypid = fork();
    if ($mypid) {
	return $mypid;
    }

    system($cmd);
    exit($? >> 8);
}

#
# Return a timestamp. We don't care about day/date/year. Just the time mam.
#
# TBTimeStamp()
#
my $imported_hires = 0;
my $imported_POSIX = 0;

sub TBTimeStamp()
{
    # To avoid problems with images not having the module installed yet.
    if (! $imported_hires) {
	require Time::HiRes;
	import Time::HiRes;
	$imported_hires = 1;
    }
    my ($seconds, $microseconds) = Time::HiRes::gettimeofday();

    if (! $imported_POSIX) {
	require POSIX;
	import POSIX qw(strftime);
	$imported_POSIX = 1;
    }
    return POSIX::strftime("%H:%M:%S", localtime($seconds)) . "." .
	sprintf("%06d", $microseconds);
}

sub TBTimeStampWithDate()
{
    # To avoid problems with images not having the module installed yet.
    if (! $imported_hires) {
	require Time::HiRes;
	import Time::HiRes;
	$imported_hires = 1;
    }
    my ($seconds, $microseconds) = Time::HiRes::gettimeofday();

    if (! $imported_POSIX) {
	require POSIX;
	import POSIX qw(strftime);
	$imported_POSIX = 1;
    }

    return POSIX::strftime("%m/%d/20%y %H:%M:%S", localtime($seconds)) . "." .
	sprintf("%06d", $microseconds);
}

#
# Print out a timestamp if the TIMESTAMPS configure variable was set.
#
# usage: void TBDebugTimeStamp(@)
#
sub TBDebugTimeStamp(@)
{
    my @strings = @_;
    if ($TIMESTAMPS) {
	print "TIMESTAMP: ", TBTimeStamp(), " ", join("",@strings), "\n";
    }
}

sub TBDebugTimeStampWithDate(@)
{
    my @strings = @_;
    if ($TIMESTAMPS) {
	print "TIMESTAMP: ", TBTimeStampWithDate(), " ", join("",@strings), "\n";
    }
}

#
# Turn on timestamps locally. We could do this globally by using an
# env variable to pass it along, but lets see if we need that.
#
sub TBDebugTimeStampsOn()
{
    $TIMESTAMPS = 1;
    $ENV{'TIMESTAMPS'} = "1";
}
sub TBDebugTimeStampsOff()
{
    $TIMESTAMPS = 0;
    $ENV{'TIMESTAMPS'} = "0";
}

1;
