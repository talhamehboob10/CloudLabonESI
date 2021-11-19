#!/usr/bin/perl -T
#
# Copyright (c) 2008-2019 University of Utah and the Flux Group.
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
# Implements the libvnode API for Docker support in Emulab.
#
# Note that there is no distinguished first or last call of this library
# in the current implementation.  Every vnode creation (through mkvnode.pl)
# will invoke all the root* and vnode* functions.  It is up to us to make
# sure that "one time" operations really are executed only once.
#
package libvnode_docker;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( init setDebug rootPreConfig
              rootPreConfigNetwork rootPostConfig
	      vnodeCreate vnodeDestroy vnodeState vnodePoll vnodePollCleanup
	      vnodeBoot vnodePreBoot vnodeHalt vnodeReboot
	      vnodeUnmount
	      vnodePreConfig vnodePreConfigControlNetwork
              vnodePreConfigExpNetwork vnodeConfigResources
              vnodeConfigDevices vnodePostConfig vnodeExec vnodeTearDown VGNAME
	    );
use vars qw($VGNAME);

%ops = ( 'init' => \&init,
         'setDebug' => \&setDebug,
         'rootPreConfig' => \&rootPreConfig,
         'rootPreConfigNetwork' => \&rootPreConfigNetwork,
         'rootPostConfig' => \&rootPostConfig,
         'vnodeCreate' => \&vnodeCreate,
         'vnodeDestroy' => \&vnodeDestroy,
	 'vnodeTearDown' => \&vnodeTearDown,
         'vnodeState' => \&vnodeState,
	 'vnodePoll' => \&vnodePoll,
	 'vnodePollCleanup' => \&vnodePollCleanup,
         'vnodeBoot' => \&vnodeBoot,
         'vnodeHalt' => \&vnodeHalt,
         'vnodeUnmount' => \&vnodeUnmount,
         'vnodeReboot' => \&vnodeReboot,
         'vnodeExec' => \&vnodeExec,
         'vnodePreConfig' => \&vnodePreConfig,
         'vnodePreConfigControlNetwork' => \&vnodePreConfigControlNetwork,
         'vnodePreConfigExpNetwork' => \&vnodePreConfigExpNetwork,
         'vnodeConfigResources' => \&vnodeConfigResources,
         'vnodeConfigDevices' => \&vnodeConfigDevices,
         'vnodePostConfig' => \&vnodePostConfig,
       );


use strict;
use warnings;
use English;
use Data::Dumper;
use Socket;
use IO::Handle;
use IO::Select;
use File::Basename;
use File::Path;
use File::Copy;
use File::Temp qw(tempdir);
use POSIX;
use JSON::PP;
use Digest::SHA qw(sha1_hex);
use LWP::Simple;
use MIME::Base64;

# Pull in libvnode
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }
use libutil;
use libgenvnode;
use libvnode;
use libtestbed;
use libsetup;
use libtmcc;
use liblocsetup;

#
# Turn off line buffering on output
#
$| = 1;

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 

##
## Standard utilities and files section
##

my $DOCKER = "/usr/bin/docker";
my $CURL = "/usr/bin/curl";
my $BRCTL = "brctl";
my $IP = "/sbin/ip";
my $IFCONFIG = "/sbin/ifconfig";
my $ETHTOOL = "/sbin/ethtool";
my $ROUTE = "/sbin/route";
my $SYSCTL = "/sbin/sysctl";
my $VLANCONFIG = "/sbin/vconfig";
my $MODPROBE = "/sbin/modprobe";
my $IPTABLES	= "/sbin/iptables";
my $NETSTAT     = "/bin/netstat";
my $IMAGEZIP    = "/usr/local/bin/imagezip";
my $IMAGEUNZIP  = "/usr/local/bin/imageunzip";
my $IMAGEDUMP   = "/usr/local/bin/imagedump";

##
## Runtime configuration options.
##
my $debug  = 0;
my $apidebug = 5;
my $lockdebug = 0;
my $sleepdebug = 0;

#
# Set to enable vnodesetup to exit before vnode is completely up
# (see vnodesetup::hackwaitandexit). Allows more parallelism during
# boot-time vnode setup. Note that concurrency may still be constrained
# by $MAXCONCURRENT (defined below) which limits how many new VMs can
# be created at once.
#
my $vsrelease = "immediate";	# or "early" or "none"

#
# If Docker is not already installed, which one should we use?  If it's
# not installed, we default to the community edition.  This is a
# runtime-checked param, so we'll use whatever is installed by default,
# not necessarily what is specified here.
#
# You really don't want to use docker.io <= 1.12, because it will take
# too many liberties with the control net bridge.  For instance, if you
# attempt a `systemctl restart docker.service`, you may be SOL and no
# longer on the control net!  docker-ce has patches against this rolled
# in already.
#
my $USE_DOCKER_CE = 1;
#
# Should we use LVM for extra storage space?  This should remain set.
#
my $USE_LVM = 1;
#
# Which docker storage driver should we use; see rootPreConfig().  Note,
# if you change this, you should change USE_DOCKER_LVM to 0 if
# !devicemapper; 1 if devicemapper.
#
my $DOCKER_STORAGE_DRIVER = 'overlay2';
#
# Should we use the Docker devicemapper direct-lvm storage backend?
# This should remain set, so that it is used for shared hosts.  User
# should be able to change to the default AUFS backend on dedicated
# hosts.
#
my $USE_DOCKER_LVM = 0;
#
# Default NFS mounts to read-only for now so that nothing in the
# container can blow them away accidentally!
#
my $NFS_MOUNTS_READONLY = 0;
#
# Should we use libvnode's network data structure caching/indexing
# powers.  We do not by default, because we can effectively use quick
# operations in /sys for everything we need -- no need to index to avoid
# slow calls to brctl or whatnot.
#
my $USE_LIBVNODE_NETCACHE = 0;
#
# Should we log packets the firewall rejects?
#
my $IPTABLES_PACKET_LOG = 1;
#
# Defaults for the default docker bridge (not our control net bridge).
#
my $DOCKER_DEFAULT_BRIDGE_IP = '192.168.254.1';
my $DOCKER_DEFAULT_BRIDGE_CIDR = '192.168.254.1/24';
#
# Docker supports both macvlan and regular bridging, but we use regular
# bridges because we need to impose traffic control on the host context
# half of the veth.
#
my $USE_MACVLAN = 0;
#
# We support macvlans on the control net, but we don't use them because
# we need to apply iptables rules outside the containers, so we need the
# host context half of the veth to use as a source interface.  It is
# tempting to use a cgroup ID plus net_cls, but apparently the markings
# only hold within the container's netns, and don't make it into the
# root (i.e. https://github.com/docker/docker/issues/19802).  So we're
# really stuck with real bridges -- and thus this should not be enabled,
# unless someone else can find a way around this.
#
my $USE_MACVLAN_CNET = 0;
#
# We try to use $IP instead of $BRCTL.
#
my $USE_BRCTL = 0;
#
# Attempt to replace simple COPY instructions from Dockerfile- fragments
# in image augmentation/emulabization with a single COPY.
#
my $COPY_OPTIMIZE = 1;

##
## Detected configuration variables.
##

#
# Is this our customized version of Docker?
#
my $ISOURDOCKER = 0;

#
# Is this our customized version with support for multiple networks
# (ipv4 subnets) on a single bridged network?
#
my $ISMULTINETWORK = 0;

#
# Does this docker support the DOCKER-USER iptables chain?
#
my $HASDOCKERUSERCHAIN = 0;

#
# Some commands/subsystems have evolved in incompatible ways over time,
# these vars keep track of such things.
#
my $NEW_LVM = 0;

##
## Various constants.
##

#
# Image wait time.  How long (seconds) we will wait to when trying to
# grab a lock on an image. Should be set to the max time you think it
# could take to pull a large Docker image.  This is a wild guess, obviously.
#
my $MAXIMAGEWAIT = 1800;

#
# Serial console handling. We fire up a capture per active vnode.
# We use a fine assortment of capture options:
#
#	-i: standalone mode, don't try to contact capserver directly
#	-l: (added later) set directory where log, ACL, and pid files are kept.
#	-C: use a circular buffer to capture activity while no user
#	    is connected. This gets dumped to the user when they connect.
#	-T: Put out a timestamp if there has been no previous output
#	    for at least 10 seconds.
#	-L: In conjunction with -T, the timestamp message includes how
#	    long it has been since the last output.
#	-R: Retry interval of 1 second. When capture is disconnected
#	    from the pty (due to container reboot/shutdowns), this is how
#	    long we wait between attempts to reconnect.
#       -y: When capture disconnects from the pty, we retry forever to reopen.
#       -A: tell capture not to prepend '/dev' to the device path we supply.
#
my $CAPTURE     = "/usr/local/sbin/capture-nossl";
my $CAPTUREOPTS	= "-i -C -L -T 10 -R 1000 -y -1 -A";
my $C2P = "/usr/local/etc/emulab/container2pty.py";

#
# Create a thin pool with the name $POOL_NAME using not more
# than $POOL_FRAC of any disk.
# 
my $USE_THIN_LVM = 1;
my $POOL_NAME = "disk-pool";
my $POOL_FRAC = 0.75;
#
# Minimum acceptible size (in GB) of LVM VG for containers.
#
# XXX we used to calculate this in terms of anticipated maximum number
# of vnodes and minimum vnode images size, blah, blah. Now we just pick
# a value that allows us to use a pc3000 node with a single 144GB disk!
#
my $DOCKER_MIN_VGSIZE = 120;
# Striping
my $STRIPE_COUNT   = 1;
# Avoid using SSDs unless there are only SSDs
my $LVM_AVOIDSSD = 1;
# Whether or not to use only unpartitioned (unused) disks to form the Xen VG.
my $LVM_FULLDISKONLY = 0;
# Whether or not to use partitions only when they are big.
my $LVM_ONLYLARGEPARTS = 1;
my $LVM_LARGEPARTPCT = 10;
# In general, you only want to use one partition per disk since we stripe.
my $LVM_ONEPARTPERDISK = 1;
#
# Flags for allocating LVs
#
sub ALLOC_NOPOOL()	{ return 0; }
sub ALLOC_INPOOL()	{ return 1; }
sub ALLOC_PREFERNOPOOL	{ return 2; }
sub ALLOC_PREFERINPOOL	{ return 3; }

##
## Randomly chosen convention section
##

# Locks.
my $GLOBAL_CONF_LOCK = "emulabdockerconf";
my $GLOBAL_MOUNT_LOCK = "emulabmounts";
my $SSHD_EXEC_LOCK = "sshdockerexec";

my $DOCKER_EXEC_SSHD_CONFIGFILE = "/etc/ssh/sshd_config-docker-exec";
my $DOCKER_EXEC_SSHD_CONFIGFILE_HEAD = "/etc/ssh/sshd_config-docker-exec.head";
my $DOCKER_EXEC_SSHD_CONFIGDIR = "/etc/ssh/docker-exec.conf.d";

# Config done file.
my $READYFILE = "/var/run/emulab.docker.ready";

# default image to load on logical disks
# Just symlink /boot/vmlinuz-xenU and /boot/initrd-xenU
# to the kernel and ramdisk you want to use by default.
my %defaultImage = (
    'name'      => "ubuntu:16.04",
#    'hub'    => "",
);

# Where we store all our config files.
my $VMS    = "/var/emulab/vms";
my $VMDIR  = "$VMS/vminfo";
# Extra space for VM info.
my $EXTRAFS = "/vms";
# Extra space for vminfo (/var/emulab/vms) between reloads.
my $INFOFS = "/vminfo";

# Docker LVM volume group name. Accessible outside this file.
$VGNAME = "docker";
# So we can ask this from outside;
sub VGNAME()  { return $VGNAME; }
    
my $CTRLIPFILE = "/var/emulab/boot/myip";
# XXX needs lifting up
my $JAILCTRLNET = "172.16.0.0";
my $JAILCTRLNETMASK = "255.240.0.0";

#
# NB: Total hack.  Docker doesn't give you control over default gateway
# for a multi-homed container, other than to ensure that virtual NICs
# are added in lexical order of name, and to promise that the default
# gateway set by the first-added network will remain.  So make sure the
# control net has a lexical name at the beginning of everything.
#
my $DOCKERCNET = "_dockercnet";
#
# Docker does not allow you to map multiple networks to a single bridge.
# However, if $ISMULTINETWORK is true later on, we are running our
# custom version which does.  In that case, we *can* support public
# control net addresses for containers; without it, we cannot.
#
my $DOCKERCNETPUB = "_dockercnetpub";

#
# Some of the core dirs for Emulabization existing Docker images.
#
my $EMULABSRC = "$EXTRAFS/emulab-devel";
my $PUBSUBSRC = "$EXTRAFS/pubsub";
my $RUNITSRC = "$EXTRAFS/runit";
my $CONTEXTDIR = "$EXTRAFS/contexts";
my $DOCKERFILES = "/etc/emulab/docker/dockerfiles";

# IFBs
my $IFBDB      = "/var/emulab/db/ifbdb";

# Use openvswitch for gre tunnels.
# Use a custom version if present, the standard version otherwise.
my $OVSCTL   = "/usr/local/bin/ovs-vsctl";
my $OVSSTART = "/usr/local/share/openvswitch/scripts/ovs-ctl";
if (! -x "$OVSCTL") {
    $OVSCTL   = "/usr/bin/ovs-vsctl";
    $OVSSTART = "/usr/share/openvswitch/scripts/ovs-ctl";
}

my $ISREMOTENODE = REMOTEDED();

##
## Emulab constants.
##
my $TMCD_PORT	 = 7777;
my $SLOTHD_PORT  = 8509;
my $EVPROXY_PORT = 16505;

##
## Docker constants.
##
#
# The options as far as what to install in an image to support its use
# in Emulab.
#
#   none: we do not alter the image at all!
#   basic: install only sshd and syslogd, and whatever init the user wants
#   core: basic + install a custom-build of the clientside, using a buildenv of
#     the image, but only installing the DESTDIR clientside binaries/fs stuff;
#     also install a whole bunch of packages the clientside stuff needs.
#   buildenv: basic + full + install all build tools for clientside, and
#     install the clientside.
#   full: buildenv + packages to make the image identical to a normal Emulab
#     disk image.
#
sub DOCKER_EMULABIZE_NONE() { return "none"; }
sub DOCKER_EMULABIZE_BASIC() { return "basic"; }
sub DOCKER_EMULABIZE_CORE() { return "core"; }
sub DOCKER_EMULABIZE_BUILDENV() { return "buildenv"; }
sub DOCKER_EMULABIZE_FULL() { return "full"; }
#
# Most of the Linux images that users will use will be generic images
# whose startup command is sh or bash.  We need something that (at
# minimum) runs infinitely, reaps processes like init, and allows remote
# logins via ssh, syslogs, etc.  Users are free to specify no
# emulabization to cover the cases where the image runs a bona fide
# daemon or pre-configured init.  But we cannot help them with those
# cases automatically.
#
#sub DOCKER_EMULABIZE_DEFAULT() { return DOCKER_EMULABIZE_BASIC(); }
sub DOCKER_EMULABIZE_DEFAULT() { return DOCKER_EMULABIZE_NONE(); }

#
# On modern (ie.e. 2016) Linux images, systemd is already installed (on
# Ubuntu/Debian, and Fedora/CentOS).  We really want to let people use
# it if it's there, instead of falling back to runit (which we install
# during Emulabization).  However, the problem is that we cannot use
# systemd as the init on shared nodes -- systemd requires at least
# read-only access to /sys/fs/cgroup, and docker as of 1.26 does not
# virtualize the cgroup mount (although it's in kernels >= 4.4) -- even
# if Docker did, it might not work; I don't know what systemd wants out
# of /sys/fs/cgroup.
#
# Thus, we must default to runit so that users have images that work on
# both shared and dedicated container hosts.  Ugh!
#
sub DOCKER_INIT_INSTALLED() { return "installed"; }
sub DOCKER_INIT_RUNIT() { return "runit"; }

#
# Either we always pull the reference image when setting up a new
# container, or we only pull the first time.  Simple.
#
sub DOCKER_PULLPOLICY_LATEST() { return "latest"; }
sub DOCKER_PULLPOLICY_CACHED() { return "cached"; }

# Local functions
sub findRoot();
sub copyRoot($$);
sub replace_hacks($);
sub disk_hacks($);
sub hostMemory();
sub hostResources();
sub hostIP($);
sub fixupMac($);
sub lvmVGSize($);
sub lvmVGMaxPossibleLVSize($;$);
sub checkForInterrupt();
sub genhostspairlist($$);
sub addMounts($$);
sub removeMounts($);
sub bindNetNS($$);
sub moveNetDeviceToNetNS($$$);
sub moveNetDeviceFromNetNS($$$);
sub unbindNetNS($$);
sub setupImage($$$$$$$$$$$);
sub pullImage($$$$;$);
sub emulabizeImage($;$$$$$$$$$);
sub analyzeImage($$;$);
sub AllocateIFBs($$$);
sub ReleaseIFBs($$);
sub CreateShapingScripts($$$$;$);
sub RunShapingScripts($$);
sub CreateRoutingScripts($$);
sub RunRoutingScripts($$);
sub RunWithSignalsBlocked($@);
sub RunProxies($$);
sub AreProxiesRunning($$);
sub KillProxies($$);
sub InsertPostBootIptablesRules($$$$);
sub RemovePostBootIptablesRules($$$$);
sub captureRunning($);
sub captureStart($$);

#
# A single client object per load of this file is safe.
#
my $_CLIENT;

sub getClient()
{
    return $_CLIENT
	if (defined($_CLIENT));
    # Load late, because this requires a bunch of deps we might have
    # installed in ensureDeps().
    require dockerclient;
    $_CLIENT = dockerclient->new();
    $_CLIENT->debug($apidebug);
    return $_CLIENT;
}

#
# Historic concurrency value. Should get overwritten in setConcurrency.
#
my $MAXCONCURRENT = 5;

#
# Number of concurrent containers set up in parallel.  Lifted from
# libvnode_xen; will be changed later.
#
sub setConcurrency($)
{
    my ($maxval) = @_;
   
    if ($maxval) {
	$MAXCONCURRENT = 5;
    } else {
	my ($ram,$cpus) = hostResources();
	my $disks = $STRIPE_COUNT;
	my $hasswapped = hostSwapping();

	print STDERR "setConcurrency: cpus=$cpus, ram=$ram, disks=$disks".
	    " hasswapped=$hasswapped\n"
	    if ($debug);

	if ($cpus > 0 && $disks > 0 && $ram > 0) {
	    if ($ram < 1024 || (!SHAREDHOST() && $hasswapped)) {
		$MAXCONCURRENT = 3;
	    } elsif ($cpus <= 2 || $disks == 1 || $ram <= 2048) {
		$MAXCONCURRENT = 5;
	    } else {
		$MAXCONCURRENT = 16;
	    }
	}
    }
    print STDERR "Limiting to $MAXCONCURRENT concurrent vnode creations.\n";
}

sub setDebug($)
{
    $debug = shift;
    libvnode::setDebug($debug);
    $lockdebug = 1;
    if ($debug > 1) {
	$sleepdebug = 1;
	$apidebug = 5;
    }
    print "libvnode_docker: debug=$debug, apidebug=$apidebug\n"
	if ($debug);
}

sub ImageLockName($)
{
    my ($imagename) = @_;

    my $ln = "dockerimage." .
	(defined($imagename) ? $imagename : $defaultImage{'name'});
    $ln =~ tr/\//-/;

    return $ln;
}

sub ImageLVName($)
{
    my ($imagename) = @_;

    return "image+" . $imagename;
}

#
# Apt constants and helper functions.
#
my $APTGET = "/usr/bin/apt-get";
my $APTGETINSTALL = "$APTGET -o Dpkg::Options::='--force-confold'".
    " -o Dpkg::Options::='--force-confdef' install -y ";
my $APTLOCK = "emulab.apt.running";
my $APTLOCK_REF;
my $APTUPDATEDFILE = "/var/run/emulab.apt.updated";

sub aptLock()
{
    TBDebugTimeStamp("aptLock: grabbing global lock $APTLOCK")
	if ($lockdebug);
    my $locked = TBScriptLock($APTLOCK,
			      TBSCRIPTLOCK_GLOBALWAIT(),900,\$APTLOCK_REF);
    if ($locked != TBSCRIPTLOCK_OKAY()) {
	return 0
	    if ($locked == TBSCRIPTLOCK_IGNORE());
	print STDERR "Could not get the apt-get lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got global lock $APTLOCK")
	if ($lockdebug);
    return 0;
}

sub aptUnlock()
{
    return TBScriptUnlock($APTLOCK_REF);
}

# Only run once per boot.
sub aptGetUpdate()
{
    if (-f $APTUPDATEDFILE) {
	return 0;
    }
    aptLock();
    mysystem2("apt-get update");
    if (!$?) {
	mysystem("touch $APTUPDATEDFILE");
    }
    my $rc = $?;
    aptUnlock();
    return $rc;
}

#
# Returns 0 if all packages are installed; else the number of
# non-installed packages.
#
sub aptNotInstalled(@)
{
    my @packages = @_;
    my $rc = 0;

    foreach my $P (@packages) {
	my $pstat = `dpkg-query -L $P 2>&1 >/dev/null`;
	if ($pstat) {
	    ++$rc;
	}
    }

    return $rc;
}

sub aptGetInstall(@)
{
    my @packages = @_;
    my $rc = 0;

    aptGetUpdate();

    $ENV{DEBIAN_FRONTEND} = 'noninteractive';
    aptLock();
    foreach my $P (@packages) {
	mysystem2("$APTGETINSTALL $P");
	if ($?) {
	    ++$rc;
	}
    }
    aptUnlock();
    $ENV{DEBIAN_FRONTEND} = undef;

    return $rc;
}

sub aptGetEnsureInstalled(@)
{
    my @packages = @_;
    my $rc = 0;

    foreach my $P (@packages) {
	$rc += aptGetInstall($P)
	    if (aptNotInstalled($P));
    }

    return $rc;
}

sub refreshLibVnodeNetCache()
{
    return
	if (!$USE_LIBVNODE_NETCACHE);

    makeIfaceMaps();
    if (!$USE_MACVLAN) {
	makeBridgeMaps();
    }
    else {
	makeMacvlanMaps();
    }
}

sub ensureDeps()
{
    if (aptNotInstalled("libwww-perl")) {
	aptGetInstall("libwww-perl");
    }
    if (aptNotInstalled("liburi-perl")) {
	aptGetInstall("liburi-perl");
    }
    if (aptNotInstalled("libhash-merge-perl")) {
	aptGetInstall("libhash-merge-perl");
    }
    if (aptNotInstalled("libmime-base64-urlsafe-perl")) {
	aptGetInstall("libmime-base64-urlsafe-perl");
    }
    eval {
	use LWP::Protocol::http::SocketUnixAlt;
    };
    if ($@) {
	mysystem("cpan -i LWP::Protocol::http::SocketUnixAlt");
    }
    if (aptNotInstalled("python-docker")) {
	aptGetInstall("python-docker");
    }
}

# (Must be called only after refreshLibVnodeNetCache() is called for
# the first time in init.)
sub ensureDockerInstalled()
{
    if (!aptNotInstalled("docker.io")) {
	TBDebugTimeStamp("docker.io installed; using that");
	$USE_DOCKER_CE = 0;
    }
    elsif (!aptNotInstalled("docker-ce")) {
	TBDebugTimeStamp("docker-ce installed; using that");
	$USE_DOCKER_CE = 1;
    }

    if (!$USE_DOCKER_CE) {
	TBDebugTimeStamp("Ensuring docker.io installed...");
	if (aptNotInstalled("docker.io")) {
	    TBDebugTimeStamp("Installing docker.io...");
	    if (aptGetInstall("docker.io")) {
		die("Failed to install docker.io; aborting!\n");
	    }

	    mysystem2("service docker restart");

	    # Remap, cause Docker creates some ifaces.
	    refreshLibVnodeNetCache();
	}

	#
	# Check which docker this is.
	#
	my $rc = system('grep -q PrivatePoolId `which dockerd`');
	if ($rc == 0) {
	    $ISOURDOCKER = 1;
	    TBDebugTimeStamp("init: ISOURDOCKER=1");
	}
    }
    else {
	TBDebugTimeStamp("Ensuring docker-ce installed...");
	# Ensure the Docker CE repo is configured.
	system("grep -q docker.com /etc/apt/sources.list /etc/apt/sources.list.d");
	if ($?) {
	    TBDebugTimeStamp("Installing docker-ce Apt repos...");
	    aptGetEnsureInstalled("apt-transport-https","ca-certificates",
				  "curl","software-properties-common");
	    mysystem("curl -fsSL https://download.docker.com/linux/ubuntu/gpg".
		     " | sudo apt-key add -");
	    my $release = `lsb_release -cs`;
	    chomp($release);
	    my $arch = `uname -m`;
	    chomp($arch);
	    if ($arch eq 'x86_64' || $arch eq 'amd64') {
		$arch = "amd64";
	    }
	    elsif ($arch eq 'armhf') {
		;
	    }
	    else {
		fatal("currently docker CE is only available on amd64/armhf!");
	    }
	    mysystem("add-apt-repository".
		     " \"deb [arch=$arch] https://download.docker.com/linux/ubuntu $release stable\"");
	    aptGetUpdate();
	}

	if (aptNotInstalled("docker-ce")) {
	    TBDebugTimeStamp("Installing docker-ce...");
	    if (aptGetInstall("docker-ce")) {
		warn("Failed to install docker-ce; retrying in 8 seconds!\n");
		sleep(8);
		system("systemctl restart docker.service");
		sleep(2);
		system("apt-get install -y docker-ce");
		if ($?) {
		    fatal("Failed to install docker-ce; aborting!\n");
		}
	    }

	    mysystem2("service docker restart");

	    # Remap, cause Docker creates some ifaces.
	    refreshLibVnodeNetCache();
	}

	#
	# Check which docker this is.
	#
	my $rc = system('grep -q PrivatePoolId `which dockerd`');
	if ($rc == 0) {
	    $ISOURDOCKER = 1;
	    TBDebugTimeStamp("init: ISOURDOCKER=1");
	}
    }
    if ($ISOURDOCKER) {
	my $rc = system('grep -q MultiNetwork `which dockerd`');
	if ($rc == 0) {
	    $ISMULTINETWORK = 1;
	    TBDebugTimeStamp("init: ISMULTINETWORK=1");
	}
	$rc = system('grep -q DOCKER-USER `which dockerd`');
	if ($rc == 0) {
	    $HASDOCKERUSERCHAIN = 1;
	    TBDebugTimeStamp("init: HASDOCKERUSERCHAIN=1");
	}
    }

    #
    # Wait for docker to be running and responding; this may take awhile if
    # we are running hundreds of containers.
    #
    my @lines = `systemctl is-active docker.service 2>&1`;
    my $needrestart = 0;
    if (!($? == 0 || (@lines > 0 && $lines[0] =~ /^activ/))) {
	$needrestart = 1;
    }
    if ($needrestart) {
	mysystem2("systemctl try-restart docker.service");
    }
    my $startwaittime = time();
    while ((time() - $startwaittime) < 900) {
	my $rc = system("docker info");
	if (!$rc) {
	    TBDebugTimeStamp("docker appears to be running");
	    last;
	}
	else {
	    TBDebugTimeStamp("docker is not yet running; waiting...");
	    sleep(1);
	}
    }

    #if (aptNotInstalled("systemd-container")
    #	&& aptGetInstall("systemd-container")) {
    #	die("Failed to install systemd-container; aborting!\n");
    #}

    #
    # Check or create the Docker config file; if we have to modify it,
    # restart Docker.
    #
    mkdir("/etc")
	if (! -d "/etc");
    mkdir("/etc/docker")
	if (! -d "/etc/docker");
    my $origjsontext = '';
    my $json = {};
    my $changed = 0;
    if (-e "/etc/docker/daemon.json") {
	open(FD,"/etc/docker/daemon.json")
	    or die("could not open /etc/docker/daemon.json: $!");
	my @lines = <FD>;
	close(FD);
	$origjsontext = join("",@lines);
	$json = decode_json($origjsontext);
    }

    # Check to ensure the docker iface has a non-172.16 subnet, unless
    # we already fixed that:
    if (!exists($json->{'bip'})
	|| $json->{'bip'} ne $DOCKER_DEFAULT_BRIDGE_CIDR) {
	TBDebugTimeStamp("Moving docker0 to $DOCKER_DEFAULT_BRIDGE_CIDR");

	# Blast our docker opts into the right place:
	$json->{'bip'} = $DOCKER_DEFAULT_BRIDGE_CIDR;
	$changed = 1;
    }

    # Check to ensure we're doing the right thing w.r.t. iptables:
    my $iptval = ($HASDOCKERUSERCHAIN) ? JSON::PP::true : JSON::PP::false;
    my $ichanged = 0;
    if (!defined($json) || !exists($json->{"iptables"})
	|| $json->{'iptables'} != $iptval) {
	$json->{'iptables'} = $iptval;
	$changed = 1;
	$ichanged = 1;
    }
    if (!defined($json) || !exists($json->{"ip-masq"})
	|| $json->{'ip-masq'} != $iptval) {
	$json->{'ip-masq'} = $iptval;
	$changed = 1;
	$ichanged = 1;
    }

    if ($changed) {
	TBDebugTimeStamp("Updating /etc/docker/daemon.json");

	my $newjsontext = encode_json($json);

	open(FD,">/etc/docker/daemon.json")
	    or die("could not write /etc/docker/daemon.json: $!");
	print FD $newjsontext;
	close(FD);

	mysystem2("service docker stop");

	if ($ichanged && !$HASDOCKERUSERCHAIN) {
	    #
	    # Make sure all the Docker stuff is undone, if this is not
	    # our Docker.
	    #
	    mysystem("$IPTABLES -P FORWARD ACCEPT");
	    mysystem("$IPTABLES -F INPUT");
	    mysystem("$IPTABLES -F OUTPUT");
	    mysystem("$IPTABLES -F FORWARD");
	    mysystem("$IPTABLES -F DOCKER");
	    mysystem2("$IPTABLES -X DOCKER");
	    mysystem2("$IPTABLES -F DOCKER-ISOLATION");
	    mysystem2("$IPTABLES -X DOCKER-ISOLATION");
	    mysystem2("$IPTABLES -F DOCKER-ISOLATION-STAGE-1");
	    mysystem2("$IPTABLES -X DOCKER-ISOLATION-STAGE-1");
	    mysystem2("$IPTABLES -F DOCKER-ISOLATION-STAGE-2");
	    mysystem2("$IPTABLES -X DOCKER-ISOLATION-STAGE-2");
	}

	mysystem2("service docker start");

	# Remap, cause Docker creates some ifaces.
	refreshLibVnodeNetCache();
    }

    return 0;
}

sub setupDockerExecSSH() {
    #
    # We need to read the default sshd config; comment out any Port or
    # ListenAddress lines; and write it out to the head config file.
    # Note, we blow away the head file when first configuring the phost
    # to support docker.
    #
    my @newlines = ();
    open(FD,"/etc/ssh/sshd_config");
    my @lines = <FD>;
    close(FD);
    foreach my $line (@lines) {
	if ($line =~ /^\s*(Port|ListenAddress)/) {
	    $line = "#$line";
	}
	push(@newlines,$line);
    }
    open(FD,">$DOCKER_EXEC_SSHD_CONFIGFILE_HEAD");
    print FD @newlines;
    close(FD);

    #
    # Then make the dir where we put the per-vhost sshd config bits.
    #
    mysystem("mkdir -p $DOCKER_EXEC_SSHD_CONFIGDIR");

    return 0;
}

sub rebuildAndReloadDockerExecSSH() {
    my $retval;

    TBDebugTimeStamp("rebuildAndReloadDockerExecSSH: grabbing sshd lock".
		     " $SSHD_EXEC_LOCK")
	if ($lockdebug);
    my $locked = TBScriptLock($SSHD_EXEC_LOCK,TBSCRIPTLOCK_GLOBALWAIT(), 900);
    if ($locked != TBSCRIPTLOCK_OKAY()) {
	return 0
	    if ($locked == TBSCRIPTLOCK_IGNORE());
	print STDERR "Could not get the $SSHD_EXEC_LOCK lock".
	    " after a long time!\n";
	return -1;
    }

    #
    # Our private Docker Exec sshd listens on the private VM ports and
    # when a user authenticates, we use the ForceCommand directive in a
    # Match block to gateway them into the container that is supposed to
    # be reachable via ssh on that port.  However, only Match blocks may
    # follow other Match blocks -- in particular, a Port directive (to
    # listen on) must precede the Match blocks.  Thus, for each
    # container, we create one file in the configdir like
    # 0.$vnode_id.port with the Port line, and another like
    # 1.$vnode_id.match with the match and command directives).
    #
    # Thus, we need an rcsorted order of files in $DOCKER_EXEC_SSHD_CONFIGDIR.
    #
    my @pmlines = ();
    if (sortedreadallfilesindir($DOCKER_EXEC_SSHD_CONFIGDIR,\@pmlines)) {
	$retval = -1;
	goto out;
    }

    open(FD,"$DOCKER_EXEC_SSHD_CONFIGFILE_HEAD");
    my @hlines = <FD>;
    close(FD);

    open(FD,">$DOCKER_EXEC_SSHD_CONFIGFILE");
    print FD "".join('',@hlines)."\n".join('',@pmlines)."\n";
    close(FD);

    #
    # But, if there were no port/match lines, *stop* the service instead of
    # restarting -- because it would probably try to start on port 22, which
    # of course will just fail it.
    #
    if (@pmlines == 0) {
	TBDebugTimeStamp("No more ports/commands in sshd_config-docker-exec;".
			 " stopping service!");
	mysystem2("systemctl stop sshd-docker-exec.service");
    }
    else {
	TBDebugTimeStamp("Restarting sshd-docker-exec.service for changes to".
			 " sshd_config-docker-exec");
	mysystem2("systemctl restart sshd-docker-exec.service");
    }
    $retval = 0;

  out:
    TBScriptUnlock();
    return $retval;
}

sub addContainerToDockerExecSSH($$$) {
    my ($vnode_id,$port,$shell)  = @_;

    open(FD,">$DOCKER_EXEC_SSHD_CONFIGDIR/0.${vnode_id}.port");
    print FD "Port $port\n";
    close(FD);

    open(FD,">$DOCKER_EXEC_SSHD_CONFIGDIR/1.${vnode_id}.match");
    print FD "Match LocalPort=$port\n";
    print FD "ForceCommand /usr/bin/sudo /usr/bin/docker exec -it $vnode_id $shell\n";
    close(FD);

    return rebuildAndReloadDockerExecSSH();
}

sub removeContainerFromDockerExecSSH($) {
    my ($vnode_id,) = @_;

    unlink("$DOCKER_EXEC_SSHD_CONFIGDIR/0.${vnode_id}.port");
    unlink("$DOCKER_EXEC_SSHD_CONFIGDIR/1.${vnode_id}.match");

    return rebuildAndReloadDockerExecSSH();
}

sub getDockerNetMemberIds($)
{
    my ($netname,) = @_;

    my ($code,$content,$resp) = getClient()->network_inspect($netname);
    if ($code) {
	return undef;
    }
    if (ref($content) eq 'ARRAY') {
	$content = $content->[0];
    }
    if (ref($content) ne 'HASH') {
	return undef;
    }
    if (!exists($content->{"Containers"})) {
	return ();
    }

    my @retval = ();
    foreach my $cid (keys(%{$content->{"Containers"}})) {
	next
	    if (!exists($content->{"Containers"}{$cid}{"Name"}));
	push(@retval,$cid);
    }
    return @retval;
}

sub setupLVM()
{

    print "Enabling LVM...\n"
	if ($debug);

    # We assume our kernels support this.
    mysystem2("$MODPROBE dm-snapshot");
    if ($?) {
	print STDERR "ERROR: could not load snaphot module!\n";
	return -1;
    }

    #
    # Make sure pieces are at least 32 GiB.
    #
    my $minpsize = 32 * 1024;
    my %devs = libvnode::findSpareDisks($minpsize, $LVM_AVOIDSSD);

    # if ignoring SSDs but came up with nothing, we have to use them!
    if ($LVM_AVOIDSSD && keys(%devs) == 0) {
	%devs = libvnode::findSpareDisks($minpsize, 0);
    }

    #
    # Turn on write caching. Hacky. 
    # XXX note we do not use the returned "path" here as we need to
    # change the setting on all devices, not just the whole disk devices.
    #
    my %diddev = ();
    foreach my $dev (keys(%devs)) {
	# only mess with the disks we are going to use
	if (!exists($diddev{$dev}) &&
	    (exists($devs{$dev}{"size"}) || $LVM_FULLDISKONLY == 0)) {
	    mysystem2("hdparm -W1 /dev/$dev");
	    $diddev{$dev} = 1;
	}
    }
    undef %diddev;

    #
    # See if our LVM volume group for VMs exists and create it if not.
    #
    my $vg = `vgs | grep $VGNAME`;
    if ($vg !~ /^\s+${VGNAME}\s/) {
	print "Creating volume group...\n"
	    if ($debug);

	#
	# Total up potential maximum size.
	# Also determine mix of SSDs and non-SSDs if required.
	#
	my $maxtotalSize = 0;
	my $sizeThreshold = 0;
	foreach my $dev (keys(%devs)) {
	    if (defined($devs{$dev}{"size"})) {
		$maxtotalSize += $devs{$dev}{"size"};
	    } else {
		foreach my $part (keys(%{$devs{$dev}})) {
		    $maxtotalSize += $devs{$dev}{$part}{"size"};
		}
	    }
	}
	if ($maxtotalSize > 0) {
	    $sizeThreshold = int($maxtotalSize * $LVM_LARGEPARTPCT / 100.0);
	}

	#
	# Find available devices of sufficient size, prepare them,
	# and incorporate them into a volume group.
	#
	my $totalSize = 0;
	my @blockdevs = ();
	foreach my $dev (sort keys(%devs)) {
	    #
	    # Whole disk is available, use it.
	    #
	    if (defined($devs{$dev}{"size"})) {
		push(@blockdevs, $devs{$dev}{"path"});
		$totalSize += $devs{$dev}{"size"};
		next;
	    }

	    #
	    # Disk contains partitions that are available.
	    #
	    my ($lpsize,$lppath);
	    foreach my $part (keys(%{$devs{$dev}})) {
		my $psize = $devs{$dev}{$part}{"size"};
		my $ppath = $devs{$dev}{$part}{"path"};

		#
		# XXX one way to avoid using the system disk, just ignore
		# all partition devices. However, in cases where the
		# remainder of the system disk represents the majority of
		# the available space (e.g., Utah d710s), this is a bad
		# idea.
		#
		if ($LVM_FULLDISKONLY) {
		    print STDERR
			"WARNING: not using partition $ppath for LVM\n";
		    next;
		}

		#
		# XXX Another heurstic to try to weed out the system
		# disk whenever feasible: if a partition device represents
		# less than some percentage of the max possible space,
		# avoid it. At Utah this one is tuned (10%) to avoid using
		# left over space on the system disk of d820s (which have
		# six other larger drives) or d430s (which have two large
		# disks) while using it on the pc3000s and d710s.
		#
		if ($LVM_ONLYLARGEPARTS && $psize < $sizeThreshold) {
		    print STDERR "WARNING: not using $ppath for LVM (too small)\n";
		    next;
		}

		#
		# XXX If we are only going to use one partition per disk,
		# record the largest one we find here. This check will
		# filter out the small "other OS" partition (3-6GB) in
		# favor of the larger "rest of the disk" partition.
		#
		if ($LVM_ONEPARTPERDISK) {
		    if (!defined($lppath) || $psize > $lpsize) {
			$lppath = $ppath;
			$lpsize = $psize;
		    }
		    next;
		}

		#
		# It ran the gauntlet of feeble filters, use it!
		#
		push(@blockdevs, $ppath);
		$totalSize += $psize;
	    }
	    if ($LVM_ONEPARTPERDISK && defined($lppath)) {
		push(@blockdevs, $lppath);
		$totalSize += $lpsize;
	    }
	}
	if (@blockdevs == 0) {
	    print STDERR "ERROR: findSpareDisks found no disks for LVM!\n";
	    return -1;
	}
		    
	my $blockdevstr = join(' ', sort @blockdevs);
	mysystem("pvcreate $blockdevstr");
	mysystem("vgcreate $VGNAME $blockdevstr");

	my $size = lvmVGSize($VGNAME);
	if ($size < $DOCKER_MIN_VGSIZE) {
	    print STDERR "WARNING: physical disk space below the desired ".
		" minimum value ($size < $DOCKER_MIN_VGSIZE), expect trouble.\n";
	}
    }
    $STRIPE_COUNT = computeStripeSize($VGNAME);
    
    #
    # Make sure our volumes are active -- they seem to become inactive
    # across reboots
    #
    mysystem("vgchange -a y $VGNAME");

    return 0;
}

#
# Bridge stuff
#
sub addbr($)
{
    my ($br) = @_;

    if ($USE_BRCTL) {
	system("$BRCTL addbr $br");
    }
    else {
	system("$IP link add $br type bridge");
    }
}
sub delbr($)
{
    my ($br) = @_;

    if ($USE_BRCTL) {
	mysystem2("$IP link set $br down");
	mysystem2("$BRCTL delbr $br");
    }
    else {
	mysystem2("$IP link del $br");
    }
}
sub addbrif($$)
{
    my ($br,$if) = @_;

    if ($USE_BRCTL) {
	system("$BRCTL addif $br $if");
    }
    else {
	system("$IP link set $if master $br");
    }
}
sub delbrif($$)
{
    my ($br,$if) = @_;

    if ($USE_BRCTL) {
	system("$BRCTL delif $br $if");
    }
    else {
	system("$IP link set $if nomaster");
    }
}

#
# Network support.
#

sub ifaceInfo($) {
    my ($iface) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	return libvnode::getIfaceInfo($iface);
    }
    else {
	return libvnode::getIfaceInfoNoCache($iface);
    }
}

sub findIfaceByMAC($) {
    my ($mac) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	return libvnode::findIface($mac);
    }
    else {
	if ($mac !~ /:/) {
	    $mac = fixupMac($mac);
	}
	my $line = `ip -br link | grep $mac`;
	if (defined($line) && $line =~ /^([^\@\s]+)/) {
	    return $1;
	}
	return undef;
    }
}

sub isIfaceInBridge($$) {
    my ($iface,$bridge) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	my $br = libvnode::findBridge($iface);
	return 1
	    if (defined($br) && $br eq $bridge);
	return 0;
    }
    else {
	if (-e "/sys/class/net/$iface/lower_$bridge") {
	    return 1;
	}
	return 0;
    }
}

sub getBridgeForIface($) {
    my ($iface) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	return libvnode::findBridge($iface);
    }
    else {
	opendir(DIR,"/sys/class/net/$iface")
	    or return undef;
	while (my $dir = readdir(DIR)) {
	    chomp($dir);
	    if ($dir =~ /upper_(.+)$/) {
		return $1;
	    }
	}
	return undef;
    }
}

sub getBridgeIfaces($) {
    my ($brname) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	return libvnode::findBridgeIfaces($brname);
    }
    else {
	my @ret = ();
	opendir(DIR,"/sys/class/net/$brname/")
	    or return undef;
	while (my $dir = readdir(DIR)) {
	    chomp($dir);
	    if ($dir =~ /lower_(.+)$/) {
		push(@ret,$1);
	    }
	}
	return @ret;
    }
}

sub getMacvlanIfaces($) {
    my ($brname) = @_;

    if ($USE_LIBVNODE_NETCACHE) {
	return libvnode::findMacvlanIfaces($brname);
    }
    else {
	my @ret = ();
	opendir(DIR,"/sys/class/net/$brname/")
	    or return undef;
	while (my $dir = readdir(DIR)) {
	    chomp($dir);
	    if ($dir =~ /lower_(.+)$/) {
		push(@ret,$1);
	    }
	}
	return @ret;
    }
}

sub getControlNet() {
    open(FD,"/var/emulab/boot/controlif")
	or return undef;
    my $controlif = <FD>;
    close(FD);
    chomp($controlif);
    return undef 
	if ($controlif eq '');
    open(FD,"/var/emulab/boot/routerip")
	or return undef;
    my $gw = <FD>;
    close(FD);
    chomp($gw);
    return undef 
	if ($gw eq '');
    open(FD,"/var/emulab/boot/myip")
	or return undef;
    my $ip = <FD>;
    close(FD);
    chomp($ip);
    return undef 
	if ($ip eq '');

    my $ref = getIfaceInfoNoCache($controlif);
    return undef
	if (!defined($ref));
    return undef
	if ($ref->{'ip'} ne $ip);

    return ($ref->{'iface'},$ref->{'ip'},$ref->{'mask'},$ref->{'maskbits'},
	    $ref->{'network'},$ref->{'mac'},$gw);
}

##
## libvnode API implementation
##

sub init($)
{
    my ($pnode_id,) = @_;

    if ($USE_LVM) {
	# See what version of LVM we have. Again, some commands are different.
	my $out = `lvm version | grep 'LVM version'`;
	if (defined($out) && $out =~ /LVM version:\s+(\d+)\.(\d+)\.(\d+)/) {
	    if (int($1) > 2 ||
		(int($1) == 2 && int($2) > 2) ||
		(int($1) == 2 && int($2) == 2 && int($3) >= 99)) {
		$NEW_LVM = 1;
	    }
	}

	# Compute the strip size for new lvms.
	if (-e "$READYFILE") {
	    $STRIPE_COUNT = computeStripeSize($VGNAME);
	}
    }

    #
    # Check which docker this is.
    #
    my $rc = system('grep -q PrivatePoolId `which dockerd`');
    if ($rc == 0) {
	$ISOURDOCKER = 1;
	TBDebugTimeStamp("init: ISOURDOCKER=1");

	$rc = system('grep -q MultiNetwork `which dockerd`');
	if ($rc == 0) {
	    $ISMULTINETWORK = 1;
	    TBDebugTimeStamp("init: ISMULTINETWORK=1");
	}
	$rc = system('grep -q DOCKER-USER `which dockerd`');
	if ($rc == 0) {
	    $HASDOCKERUSERCHAIN = 1;
	    TBDebugTimeStamp("init: HASDOCKERUSERCHAIN=1");
	}
    }

    return 0;
}

#
# Called on each vnode, but should only be executed once per boot.
# We use a file in /var/run (cleared on reboots) to ensure this.
#
sub rootPreConfig($;$)
{
    my ($bossip,$hostattributes) = @_;
    my ($code,$content,$resp);

    #
    # Haven't been called yet, grab the lock and double check that someone
    # didn't do it while we were waiting.
    #
    if (! -e "$READYFILE") {
	TBDebugTimeStamp("rootPreConfig: grabbing global lock $GLOBAL_CONF_LOCK")
	    if ($lockdebug);
	my $locked = TBScriptLock($GLOBAL_CONF_LOCK,
				  TBSCRIPTLOCK_GLOBALWAIT(), 1200);
	if ($locked != TBSCRIPTLOCK_OKAY()) {
	    return 0
		if ($locked == TBSCRIPTLOCK_IGNORE());
	    print STDERR "Could not get the $GLOBAL_CONF_LOCK lock".
		" after a long time!\n";
	    return -1;
	}
    }
    TBDebugTimeStamp("  got global lock")
	if ($lockdebug);
    if (-e "$READYFILE") {
	TBDebugTimeStamp("  releasing global lock")
	    if ($lockdebug);
        TBScriptUnlock();
        return 0;
    }
    
    TBDebugTimeStamp("Configuring root vhost context");

    #
    # Check if we are using an alternate storage driver.
    #
    if (defined($hostattributes)
	&& exists($hostattributes->{"DOCKER_STORAGE_DRIVER"})) {
	my $driver = $hostattributes->{"DOCKER_STORAGE_DRIVER"};
	if ($driver eq 'overlay2' || $driver eq 'aufs') {
	    $DOCKER_STORAGE_DRIVER = $driver;
	    $USE_DOCKER_LVM = 0;
	}
	elsif ($driver eq 'devicemapper') {
	    $DOCKER_STORAGE_DRIVER = $driver;
	    $USE_DOCKER_LVM = 1;
	}
	else {
	    warn("bogus storage driver $driver; ignoring!\n");
	}
    }

    #
    # Ensure we have the latest bridge/iface state!
    #
    refreshLibVnodeNetCache();

    #
    # Make sure we actually have Docker.
    #
    ensureDockerInstalled();

    #
    # Make sure we have all our Perl deps.
    #
    ensureDeps();

    #
    # Make sure we have a bunch of other common tools.
    #
    aptGetEnsureInstalled("lvm2","thin-provisioning-tools",
			  "bridge-utils","iproute2","vlan");

    #
    # Set up the docker exec sshd service.
    #
    setupDockerExecSSH();

    #
    # Setup our control net device if not already up.
    #
    if ($USE_MACVLAN_CNET || $USE_MACVLAN) {
	#
	# If we build dummy shortbridge nets atop either a physical
	# device, or atop a dummy device, load these!
	#
	mysystem("$MODPROBE macvlan");
	mysystem("$MODPROBE dummy");
    }
    if (!$USE_MACVLAN_CNET || !$USE_MACVLAN) {
	mysystem("$MODPROBE bridge");
    }

    my ($cnet_iface,$cnet_ip,$cnet_mask,
	$cnet_maskbits,$cnet_net,$cnet_mac,$cnet_gw) = getControlNet();
    if (!defined($cnet_iface) || !defined($cnet_ip)) {
	print STDERR "ERROR: failed to detect control network interface!\n";
	return -1;
    }
    my ($alias_ip,$alias_mask,$vmac) = hostControlNet($cnet_ip,$cnet_mask);
    my ($VCNET_NET,undef,$VCNET_GW,$VCNET_SLASHMASK) = findVirtControlNet();
    my $nettype = ($USE_MACVLAN_CNET) ? "macvlan" : "bridge";

    #
    # NB: in the case of !$USE_MACVLAN_CNET (i.e. using bridges for
    # control net) and !$ISREMOTENODE, we place the real routable
    # control net addr on the bridge and put the real control net dev in
    # the bridge.  So we want to track the orig_cnet_iface.  Once we
    # shuffle that dev into the bridge, we reset the
    # /var/emulab/boot/controlif file to point to the bridge -- and thus
    # if this gets re-run, it won't get the real control net dev as in
    # arg to this function.  So the code that handles this case is
    # careful to use orig_cnet_iface instead of cnet_iface!  None of the
    # other cases care, since they don't re-write
    # /var/emulab/boot/controlif.
    #
    my $orig_cnet_iface;
    #
    # Assume if this is not present, this is the first time running.  If
    # so, the real control net device must have the real control net IP;
    # not $DOCKERCNET!  So if you wipe this file out to retry, make sure
    # to reset the real controlif with proper info from dhclient.
    #
    if (! -e "/var/run/emulab-controlif-orig") {
	$orig_cnet_iface = $cnet_iface;
	open(FD,">/var/run/emulab-controlif-orig")
	    or fatal("could not open /var/run/emulab-controlif-orig: $!");
	print FD "$cnet_iface";
	close(FD);
    }
    else {
	open(FD,"/var/run/emulab-controlif-orig")
	    or fatal("could not open /var/run/emulab-controlif-orig: $!");
	$orig_cnet_iface = <FD>;
	chomp($orig_cnet_iface);
	close(FD);
    }

    my $dcnexists = 0;
    TBDebugTimeStamp("checking for docker network $DOCKERCNET...");
    ($code,$content,$resp) = getClient()->network_inspect($DOCKERCNET);
    if ($code == 0) {
	$dcnexists = 1;
    }

    if ($USE_MACVLAN_CNET && ! -e "/sys/class/net/$DOCKERCNET") {
	my $alias_net =
	    inet_ntoa(inet_aton($alias_ip) & inet_aton($alias_mask));

	if (!$ISREMOTENODE) {
            #
            # We first add a macvlan "alias" to the control net device
            # so that we (the physical host) are in the same subnet as
            # the vnodes.  With the macvlan interfaces, you cannot
            # directly alias the parent device and talk to/from the
            # other macvlan children on the parent.
            #
	    print "Creating $DOCKERCNET macvlan on $cnet_iface".
		" ($alias_ip,$alias_mask)...\n";
	    mysystem("$IP link add link $cnet_iface name $DOCKERCNET".
		     " address $vmac type macvlan mode bridge");
	    mysystem("$IP addr replace $alias_ip/$alias_mask dev $DOCKERCNET");
	    mysystem("$IP link set up $DOCKERCNET");

	    #my $isroutable = isRoutable($alias_ip);
	    ## Add a route to reach the vnodes. Do it for the entire
	    ## network, and no need to remove it.
	    #if (!$ISREMOTENODE && !$isroutable
	    #	&& system("$NETSTAT -r | grep -q $alias_net")) {
	    #	mysystem2("$ROUTE add -net $alias_net netmask $alias_mask dev $cnet_iface");
	    #	if ($?) {
	    #	    warn("could not add non-routable local virt control net route!");
	    #	    #return -1;
	    #	}
	    #}
	}
	else {
	    #
	    # XXX will this actually work? macvlan children can't talk to host?
	    # XXX probably need to add a dummy device to back the docker
	    # macvlan network!
	    # $alias_ip = $cnet_ip;
            #
            # Ok, since that won't work, in this case, we add a dummy
            # device to host our control net macvlan devices atop; we
            # don't want anything bridged to the outside world in the
            # remoteded case.  Then we add our control net alias like
            # above.
            #
	    $cnet_iface = "dummycnet";
	    mysystem2("$IP link add dummycnet type dummy");
	    print "Creating $DOCKERCNET macvlan on $cnet_iface".
		" ($alias_ip,$alias_mask)...\n";
	    mysystem("$IP link add link $cnet_iface".
		     " name $DOCKERCNET address $vmac type macvlan mode bridge");
	    mysystem("$IP addr replace $alias_ip/$alias_mask dev $DOCKERCNET");
	    mysystem("$IP link set up $DOCKERCNET");
	}
    }
    elsif (!$USE_MACVLAN_CNET
	   && (!$dcnexists || !isIfaceInBridge($orig_cnet_iface,$DOCKERCNET))) {
	my $alias_net =
	    inet_ntoa(inet_aton($alias_ip) & inet_aton($alias_mask));

	#
	# If the bridge doesn't exist, add it first.
	#
	if (! -e "/sys/class/net/$DOCKERCNET") {
	    addbr($DOCKERCNET);
	    if ($?) {
		fatal("failed to create $DOCKERCNET bridge!");
		return -1;
	    }
	}

	#
	# The $ISREMOTENODE case is easy, because the real control net
	# device doesn't go into the bridge, and we and Docker expect
	# the bridge to have the fake virtual control net address.  So
	# harmony ensues.
	#
	# The !$ISREMOTENODE case is very, very tricky.  The first time
	# we boot, the docker network doesn't exist; the bridge doesn't
	# exist; all the control net state is as dhclient left it.  The
	# correct order there is create bridge; flush control net ip
	# addr; move control net dev into bridge; add control net as
	# docker network; flush bridge ip addr Docker set; set our
	# proper public control net IP as the bridge ip addr; and add
	# the unroutable virtual control net addr (the docker network
	# gateway) as an alias.  NB: Docker will not accept or add the
	# virtual control net IP as an alias; it will error, or force
	# the IP to the virtual addr.  That is why we must fix it up
	# after creating the Docker network.
	#
	# On subsequent boots, the control net already exists as a
	# Docker network, and Docker will create the control net device
	# before we run.  However, Docker doesn't put the real control
	# net device into that bridge (it doesn't know that kind of
	# thing); but it does give the bridge the virtual control IP as
	# its primary IP.  So, we have to flush the bridge IP, and *not*
	# remake the Docker cnet.
	#
	# What a pain, all because Docker cannot just leave an existing
	# bridge alone (i.e.,
	# https://github.com/docker/docker/issues/20758).
	#
	if (!$ISREMOTENODE) {
	    my $ipandmaskbits = "$cnet_ip/$cnet_maskbits";

	    # First grab the default gateway.
	    my ($defroute,$defrouteiface);
	    open(ROUTEOUTPUT,"$IP route list |")
		or fatal("unable to get route list via 'ip'!");
	    while (!eof(ROUTEOUTPUT)) {
		my $line = <ROUTEOUTPUT>;
		chomp($line);
		if ($line =~ /^default via (\d+\.\d+\.\d+\.\d+)/) {
		    $defroute = $1;
		}
		if ($line =~ /^default via [\w\.\/]+\s+dev\s+([\w\.]+)/) {
		    $defrouteiface = $1;
		}
	    }
	    if (!$defroute) {
		fatal("could not find default route!");
	    }

	    #
	    # Undo the existing control net config we obtained on boot,
	    # and move that interface into our $DOCKERCNET bridge, IFF
	    # it's not in the bridge already.  If it's already in the
	    # bridge, no need to do any of this.
	    #
	    if (!isIfaceInBridge($orig_cnet_iface,$DOCKERCNET)) {
		mysystem2("$IP link set down $orig_cnet_iface");
		mysystem2("$IP addr del $ipandmaskbits dev $orig_cnet_iface");
		mysystem2("$IP addr flush dev $orig_cnet_iface");
		addbrif($DOCKERCNET,$orig_cnet_iface);
	    }

	    #
	    # If the Docker network does not exist in Docker itself, but
	    # it *does* exist as a device, flush its IP addr since
	    # Docker insists on setting that itself.
	    #
	    if (!$dcnexists && -e "/sys/class/net/$DOCKERCNET") {
		mysystem2("$IP addr flush dev $DOCKERCNET");
	    }

	    #
	    # If the docker network isn't yet built, do that now.
	    #
	    if (!$dcnexists) {
		TBDebugTimeStamp("creating bridged docker network $DOCKERCNET");
		($code,$content) = getClient()->network_create_bridge(
		    $DOCKERCNET,"${VCNET_NET}/${VCNET_SLASHMASK}",$alias_ip,
		    $DOCKERCNET);
		if ($code) {
		    fatal("failed to create bridged Docker $DOCKERCNET control net:".
			  " $content");
		}
		$dcnexists = 1;
	    }

	    #
	    # Always flush the bridge's Docker-imposed addr immediately,
	    # whether it existed or we created it.
	    #
	    mysystem("$IP addr flush dev $DOCKERCNET");

	    #
	    # Set the $DOCKERCNET configuration to one that both we and
	    # Docker are happy with.
	    #
	    mysystem2("$IP addr add $ipandmaskbits dev $DOCKERCNET");
	    if ($?) {
		mysystem("$IP addr replace $ipandmaskbits dev $DOCKERCNET");
	    }
	    mysystem("$IP link set up $DOCKERCNET");
	    mysystem("$IP link set up $orig_cnet_iface");
	    if ($defrouteiface eq $cnet_iface
		|| $defrouteiface eq $orig_cnet_iface) {
		mysystem("$IP route replace default via $defroute");
	    }
	    mysystem("$IP addr add $alias_ip/$alias_mask dev $DOCKERCNET".
		     " label $DOCKERCNET:1");

	    #
	    # Save the bridge as the real control net iface.
	    #
	    open(CONTROLIF,">$BOOTDIR/controlif");
	    print CONTROLIF "$DOCKERCNET\n";
	    close(CONTROLIF);
	}
	else {
	    #
	    # If this node is remote, then it gets a bridge without the
	    # control net.
	    #
	    mysystem("$IP addr replace $alias_ip/$alias_mask dev $DOCKERCNET");
	    mysystem("$IP link set up $DOCKERCNET");
	}
    }

    #
    # Now if the Docker control net still doesn't exist, create that.
    #
    if (!$dcnexists) {
	if ($USE_MACVLAN_CNET) {
	    #
	    # Next, we create a docker macvlan network to front for the
	    # virt control net.
	    #
	    TBDebugTimeStamp("creating macvlan Docker network $DOCKERCNET");
	    ($code,$content) = getClient()->network_create_macvlan(
		$DOCKERCNET,"${VCNET_NET}/${VCNET_SLASHMASK}",$alias_ip,
		$cnet_iface);
	    if ($code) {
		fatal("failed to create bridged Docker $DOCKERCNET control net:".
		      " $content");
	    }
	}
	else {
	    my $argref = undef;
	    if ($ISMULTINETWORK) {
		$argref = {
		    "com.docker.network.bridge.multi_network" => "True"
		};
	    }
	    TBDebugTimeStamp("creating bridged Docker network $DOCKERCNET");
	    ($code,$content) = getClient()->network_create_bridge(
		$DOCKERCNET,"${VCNET_NET}/${VCNET_SLASHMASK}",$alias_ip,
		$DOCKERCNET,$argref);
	    if ($code) {
		fatal("failed to create bridged Docker $DOCKERCNET control net:".
		      " $content");
	    }
	    if ($ISMULTINETWORK) {
		TBDebugTimeStamp("creating bridged public Docker network".
				 $DOCKERCNETPUB);
		($code,$content) = getClient()->network_create_bridge(
		    $DOCKERCNETPUB,"$cnet_net/$cnet_maskbits",$cnet_ip,
		    $DOCKERCNET,$argref);
		if ($code) {
		    fatal("failed to create public bridged Docker network".
			  "$DOCKERCNET control net: $content");
		}
	    }
	}
    }

    #
    # Mesh our iptables setup with docker's.  This is nontrivial because
    # Docker does one nasty thing: it continually forces its -j
    # DOCKER-ISOLATION rule into the top of the FORWARD chain on
    # significant operations (like creating a container).  This has
    # since been fixed in more recent versions (there is a DOCKER-USER
    # chain at the top of the forward chain that we hook into), so we
    # have two strategies.  First, if DOCKER-USER exists, we hook it;
    # second, if that is not available, we disable its use of iptables
    # and do all the stuff Docker would normally do that we actually
    # need (a subset of what Docker normally does).  However, in this
    # latter case, iptables won't behave as expected for regular
    # containers.  Nothing we can do about that.
    #
    # We use the same basic strategy in either case: what we want to do
    # is flow all packets on the control net bridge through our
    # EMULAB-ISOLATION chain.  But we do return to the DOCKER-ISOLATION
    # chain so that Docker rules can affect other Docker networks.
    #
    mysystem2("$IPTABLES -N EMULAB-ISOLATION");
    mysystem("$IPTABLES -F EMULAB-ISOLATION");
    mysystem("$IPTABLES -A EMULAB-ISOLATION -j RETURN");
    if ($HASDOCKERUSERCHAIN) {
	if (mysystem2("$IPTABLES -L DOCKER-USER") == 1) {
	    #
	    # There seems to be bugs where DOCKER-USER does not exist
	    # sometimes.  So make it exist, and set up the jump rules.
	    #
	    mysystem("$IPTABLES -N DOCKER-USER");
	    mysystem("$IPTABLES -A FORWARD -j DOCKER-USER");
	}
	mysystem("$IPTABLES -F DOCKER-USER");
	mysystem("$IPTABLES -I DOCKER-USER -j EMULAB-ISOLATION");
	#
	# In more recent versions of Docker, by default, bridge networks
	# are not allowed to leave the host (i.e. via masquerading).
	# So, fix that.
	#
	mysystem("$IPTABLES -A DOCKER-USER -o docker0 -j ACCEPT");
	mysystem("$IPTABLES -A DOCKER-USER -o _dockercnet -j ACCEPT");
	mysystem("$IPTABLES -A DOCKER-USER -j RETURN");
    }
    else {
	mysystem("$IPTABLES -I FORWARD -j EMULAB-ISOLATION");
    }

    #
    # Also, Docker handles MASQUERADING for us by default.  We don't
    # want to turn off Docker's iptables (it's on or off) functionality,
    # because people should be able to bring up Docker VMs manually if
    # they want, using the default Docker host network (or one of the
    # experiment networks, if they safely manage IP addr assignment).
    # However, as discussed above, we have to turn it off if it's not
    # our modified version.  So we have to add the MASQ rule if iptables
    # is off in Docker.
    #
    # If this is a local testbed node, we want to allow unroutable
    # packets on the control net.  So we have to add local control net
    # exceptions ahead of Docker's default MASQ-all rules.
    #
    if (!$ISREMOTENODE) {
	mysystem("$IPTABLES -t nat -I POSTROUTING".
		 " -s ${VCNET_NET}/${VCNET_SLASHMASK}".
		 " -d ${VCNET_NET}/${VCNET_SLASHMASK} -j ACCEPT");
	mysystem("$IPTABLES -t nat -I POSTROUTING".
		 " -s ${VCNET_NET}/${VCNET_SLASHMASK}".
		 " -d ${cnet_net}/${cnet_mask} -j ACCEPT");
	# NB: Ok, more recent versions of Docker no longer seem to allow
	# default outbound masquerading -- so always do it.
	if (1 || !$ISOURDOCKER) {
	    mysystem("$IPTABLES -t nat -A POSTROUTING".
		     " -s ${VCNET_NET}/${VCNET_SLASHMASK}".
		     " -j MASQUERADE");
	    # Also do the default docker0 bridge CIDR, since Docker
	    # won't be doing it and we want temp user containers to
	    # work.
	    mysystem("$IPTABLES -t nat -A POSTROUTING".
		     " -s $DOCKER_DEFAULT_BRIDGE_CIDR".
		     " -j MASQUERADE");
	}
    }

    #
    # XXX: antispoofing!  Can't do it with macvlan control net though.
    #
    # We also choose not to use the style here; instead, we are
    # draconian and drop everything that comes from the vnode that does
    # not have its IP.  We do that later.
    #
    # We want to change the below code not to DROP on the FORWARD chain
    # by default, but rather to drop anything that comes from a vnode's
    # cnet iface that is not sourced from its assigned control net IP.
    #
    if (0) {
	mysystem("$IPTABLES -P FORWARD DROP");
	mysystem("$IPTABLES -F FORWARD");
	# This says to forward traffic across the bridge.
	mysystem("$IPTABLES -A FORWARD ".
		 "-m physdev --physdev-in $cnet_iface -j ACCEPT");
    }

    # For tunnels
    mysystem("$MODPROBE ip_gre");

    # For VLANs
    mysystem("$MODPROBE 8021q");

    # We need this stuff for traffic shaping -- only root context can
    # modprobe.
    mysystem("$MODPROBE sch_netem");
    mysystem("$MODPROBE sch_htb");

    # For bandwidth contraints.
    mysystem("$MODPROBE ifb");

    # Create a DB to manage them. 
    my %MDB;
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	TBScriptUnlock();
	return -1;
    }
    dbmclose(%MDB);
    
    #
    # Ensure that LVM is loaded in the kernel and ready.
    #
    if ($USE_LVM) {
	# There are several reasons we might need a Docker restart in
	# this LVM setup bit; they will be noted along the way, and we
	# will restart if necessary.
	my $needdockerrestart = 0;

	#
	# Sets up our PVs and VG ($VGNAME).
	#
	setupLVM();

	#
	# Figure out how big various volumes should be.
	#
	# If we are using the aufs storage backend for Docker, we want
	# most of our space in $EXTRAFS (since /var/lib/docker gets
	# symlinked there, our heaviest space usage may be there); in
	# that case, we save a ~10%VG buffer of free space.  Wild guess.
	#
	# If we are instead using the devicemapper direct-lvm backend,
	# we need both $EXTRAFS and $INFOFS, but we also need a beefy
	# thinpool for Docker.  In this case, we use min(32GB,15%VG) LV
	# for $INFOFS; use min(32GB,15%remainingVG) for the $EXTRAFS;
	# then we provision the thin pool with 90% of the remaining
	# space (i.e., 0.90*(totalVG - sizeof($EXTRAFS) -
	# sizeof($INFOFS))).  This results in at least some spare space
	# in case some heavy usage happens, for autoextension of the
	# thinpool.  And we could even consider garbage-collecting
	# context build dirs in $EXTRAFS and downsizing that so that the
	# thin pool can grow more, for instance on a shared host, if
	# necessary.
	#
	my ($extrasize,$infosize,$thinpoolsize) = (0,0,0);
	#my $vgsize = lvmVGSize($VGNAME);
	my $vgsize = lvmVGMaxPossibleLVSize($VGNAME);
	my $remaining = $vgsize;

	if (!$USE_DOCKER_LVM) {
	    # We will only create $EXTRAFS and $INFOFS.
	    if (0.15 * $remaining < 32) {
		$infosize = 0.15 * $remaining;
	    }
	    else {
		$infosize = 32;
	    }
	    $remaining -= $infosize;
	    $extrasize = 0.90 * $remaining;
	    $remaining -= $extrasize;
	}
	else {
	    # We will create $EXTRAFS and $INFOFS, as well as the Docker
	    # thin pool.
	    if (0.15 * $remaining < 32) {
		$infosize = 0.15 * $remaining;
	    }
	    else {
		$infosize = 32;
	    }
	    $remaining -= $infosize;
	    if (0.15 * $remaining < 32) {
		$extrasize = 0.15 * $remaining;
	    }
	    else {
		$extrasize = 32;
	    }
	    $remaining -= $extrasize;
	    $thinpoolsize = 0.90 * $remaining;
	    $remaining -= $thinpoolsize;
	}

	print "LVM sizes: extra=$extrasize,info=$infosize,thinpool=$thinpoolsize\n";

	my $tmplvname;
	if ($INFOFS =~ /\/(.*)$/) {
	    $tmplvname = $1;
	}
	if (!libvnode::lvExists($VGNAME,$tmplvname)) {
	    print "Creating container info FS $tmplvname ...\n";
	}
	else {
	    print "Mounting container info FS $tmplvname ...\n";
	}
	if (createExtraFS($INFOFS, $VGNAME, "${infosize}G")) {
	    TBScriptUnlock();
	    return -1;
	}
	if ($EXTRAFS =~ /\/(.*)$/) {
	    $tmplvname = $1;
	}
	my $already = 0;
	if (!libvnode::lvExists($VGNAME,$tmplvname)) {
	    print "Creating scratch FS $tmplvname ...\n";
	    if (-d $EXTRAFS) {
		$already = 1;
		mysystem("mv $EXTRAFS ${EXTRAFS}.bak");
	    }
	}
	else {
	    print "Mounting scratch FS $tmplvname ...\n";
	}
	if (createExtraFS($EXTRAFS, $VGNAME, "${extrasize}G")) {
	    TBScriptUnlock();
	    return -1;
	}
	if ($already) {
	    my @files = glob("${EXTRAFS}.bak/*");
	    foreach my $file (@files) {
		my $base = basename($file);
		mysystem("/bin/mv $file $EXTRAFS")
		    if (! -e "$EXTRAFS/$base");
	    }
	    mysystem("/bin/rm -rf ${EXTRAFS}.bak");
	}
	if ($USE_DOCKER_LVM && !libvnode::lvExists($VGNAME,"thinpool")) {
	    print "Creating Docker Thin Pool...\n";
	    #
	    # Docker wants a thinpool and a metadata pool.  Size of the
	    # metadata pool cannot exceed 16GB.  So we create that as
	    # min(16,0.01*$thinpoolsize).
	    #
	    my ($tps,$tpms) = (0,0);
	    if (0.01 * $thinpoolsize < 16) {
		$tpms = 0.01 * $thinpoolsize;
	    }
	    else {
		$tpms = 16;
	    }
	    $tps = $thinpoolsize - $tpms;
	    # XXX: --wipesignatures y ?
	    mysystem("lvcreate -n thinpool $VGNAME -L ${tps}G");
	    mysystem("lvcreate -n thinpoolmeta $VGNAME -L ${tpms}G");
	    mysystem("lvconvert -y --zero n -c 512K".
		     " --thinpool $VGNAME/thinpool".
		     " --poolmetadata $VGNAME/thinpoolmeta");
	    mkdir("/etc/lvm/profile");
	    open(FD,">/etc/lvm/profile/$VGNAME-thinpool.profile")
		or fatal("could not open /etc/lvm/profile/$VGNAME-thinpool.profile: $@");
	    print FD "activation {\n".
		"  thin_pool_autoextend_threshold=90\n".
		"  thin_pool_autoextend_percent=10\n".
		"}\n";
	    close(FD);
	    mysystem("lvchange --metadataprofile $VGNAME-thinpool".
		     " $VGNAME/thinpool");
	    mysystem("lvs -o+seg_monitor");
	}
	if (defined($DOCKER_STORAGE_DRIVER)) {
	    #
	    # Setup the Docker storage backend.
	    # If devicemapper direct-lvm storage backend, like
	    # { "storage-driver": "devicemapper",
	    #   "storage-opts": [
	    #     "dm.thinpooldev=/dev/mapper/docker-thinpool",
	    #     "dm.use_deferred_removal=true",
	    #     "dm.use_deferred_deletion=true" ] }
	    #
	    my $origjsontext = '';
	    my $json = {};
	    if (-e "/etc/docker/daemon.json") {
		open(FD,"/etc/docker/daemon.json")
		    or die("could not open /etc/docker/daemon.json: $!");
		my @lines = <FD>;
		close(FD);
		$origjsontext = join("",@lines);
		$json = decode_json($origjsontext);
	    }

	    # If it exists, just delete it; we only want valid stuff in here.
	    if (defined($json->{"storage-driver"})) {
		delete($json->{"storage-driver"});
	    }
	    if (defined($json->{"storage-opts"})) {
		delete($json->{"storage-opts"});
	    }

	    # Write our config.
	    # Don't restart docker; that happens at the end of $USE_LVM.
	    $needdockerrestart = 1;
	    $json->{"storage-driver"} = "$DOCKER_STORAGE_DRIVER";
	    if ($DOCKER_STORAGE_DRIVER eq 'devicemapper') {
		$json->{"storage-opts"} = [
		    "dm.thinpooldev=/dev/mapper/${VGNAME}-thinpool",
		    "dm.use_deferred_removal=true",
		    "dm.use_deferred_deletion=true"
		    ];
	    }

	    TBDebugTimeStamp("Updating /etc/docker/daemon.json");

	    my $newjsontext = encode_json($json);

	    open(FD,">/etc/docker/daemon.json")
		or die("could not write /etc/docker/daemon.json: $!");
	    print FD $newjsontext;
	    close(FD);
	}
	if (! -l $VMS) {
	    #
	    # We need this stuff to be sticky across reloads, so move it
	    # into an lvm. If we lose the lvm, well then we are screwed.
	    #
	    my @files = glob("$VMS/*");
	    foreach my $file (@files) {
		my $base = basename($file);
		mysystem("/bin/mv $file $INFOFS")
		    if (! -e "$INFOFS/$base");
	    }
	    mysystem("/bin/rm -rf $VMS");
	    mysystem("/bin/ln -s $INFOFS $VMS");
	}
	if (! -l '/var/lib/docker') {
	    # Make sure Docker is stopped before we do this, if it
	    # wasn't stopped above already!
	    mysystem2("systemctl stop docker.service");
	    $needdockerrestart = 1;
	    if ($?) {
		warn("could not stop docker service before moving".
		     " /var/lib/docker to LVM; aborting!");
		TBScriptUnlock();
		return -1;
	    }
	    my $rca = mysystem2("mount -t aufs | grep /var/lib/docker/");
	    my $rco = mysystem2("mount -t overlay2 | grep /var/lib/docker/");
	    if ($? == 0) {
		warn("filesystems still mounted in /var/lib/docker; aborting!");
		TBScriptUnlock();
		return -1;
	    }
	    if (! -d "$EXTRAFS/var.lib.docker") {
		mkdir("$EXTRAFS/var.lib.docker");
		#
		# We need this stuff to be sticky across reloads, so move it
		# into an lvm. If we lose the lvm, well then we are screwed.
		#
		my @files = glob("/var/lib/docker/*");
		foreach my $file (@files) {
		    my $base = basename($file);
		    mysystem("/bin/mv $file $EXTRAFS/var.lib.docker")
			if (! -e "$EXTRAFS/var.lib.docker/$base");
		}
	    }
	    mysystem("/bin/rm -rf /var/lib/docker");
	    mysystem("/bin/ln -s $EXTRAFS/var.lib.docker /var/lib/docker");
	}

	if ($needdockerrestart) {
	    mysystem2("systemctl restart docker.service");
	    if ($?) {
		warn("could not restart docker service after LVM setup; aborting!");
		TBScriptUnlock();
		return -1;
	    }
	}

	#
	# Check the $DOCKERCNET again after LVM setup... if the move of
	# /var/lib/docker fails, all Docker state (including
	# $DOCKERCNET) will appear to have vanished!
	#
	TBDebugTimeStamp("checking docker network $DOCKERCNET after LVM move");
	($code,$content,$resp) = getClient()->network_inspect($DOCKERCNET);
	if ($code) {
	    fatal("$DOCKERCNET still does not appear as a Docker network;".
		  " something must have gone wrong in LVM setup!\n");
	}
    }
    else {
	mkdir($VMS);
	mkdir($INFOFS);
	mkdir($EXTRAFS);
    }

    #
    # Make sure IP forwarding is enabled on the host
    #
    mysystem2("$SYSCTL -w net.ipv4.conf.all.forwarding=1");

    #
    # Increase socket buffer size for frisbee download of images.
    #
    mysystem2("$SYSCTL -w net.core.rmem_max=1048576");
    mysystem2("$SYSCTL -w net.core.wmem_max=1048576");

    #
    # Need these to avoid overflowing the NAT tables.
    #
    mysystem2("$MODPROBE nf_conntrack");
    if ($?) {
	print STDERR "ERROR: could not load nf_conntrack module!\n";
	TBScriptUnlock();
	return -1;
    }
    mysystem2("$SYSCTL -w ".
	     "  net.netfilter.nf_conntrack_generic_timeout=120");
    mysystem2("$SYSCTL -w ".
	     "  net.netfilter.nf_conntrack_tcp_timeout_established=54000");
    mysystem2("$SYSCTL -w ".
	     "  net.netfilter.nf_conntrack_max=131071");
    mysystem2("echo 16384 > /sys/module/nf_conntrack/parameters/hashsize");
 
    # These might fail on new kernels.  
    mysystem2("$SYSCTL -w ".
	      " net.ipv4.netfilter.ip_conntrack_generic_timeout=120");
    mysystem2("$SYSCTL -w ".
	      " net.ipv4.netfilter.ip_conntrack_tcp_timeout_established=54000");

    #
    # Clone the emulab and pubsub src repos.  Make other dirs.
    #
    mkdir($CONTEXTDIR);
    if (! -d $EMULABSRC) {
	mysystem("git clone https://gitlab.flux.utah.edu/emulab/emulab-devel".
		 " $EMULABSRC");
    }
    if (! -d $PUBSUBSRC) {
	mysystem("git clone https://gitlab.flux.utah.edu/emulab/pubsub".
		 " $PUBSUBSRC");
    }
    if (! -d $RUNITSRC) {
	mysystem("git clone https://gitlab.flux.utah.edu/emulab/runit".
		 " $RUNITSRC");
    }

    # We're done; mark it.
    mysystem("touch $READYFILE");
    TBDebugTimeStamp("  releasing global lock")
	if ($lockdebug);
    TBScriptUnlock();
    return 0;
}

#
# Prepare any network stuff in the root context for a specific vnode.
# Run once at boot/create, or at reconfigure.  For Docker, this consists
# of creating bridges and/or macvlans, configuring them as necessary,
# and binding them to Docker networks.
#
# NOTE: This function must clean up any side effects if it fails partway.
#
sub rootPreConfigNetwork($$$$)
{
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    my ($code,$content,$resp);

    TBDebugTimeStamp("rootPreConfigNetwork: grabbing global lock".
		     " $GLOBAL_CONF_LOCK")
	if ($lockdebug);
    if (TBScriptLock($GLOBAL_CONF_LOCK,
		     TBSCRIPTLOCK_INTERRUPTIBLE(), 1200) != TBSCRIPTLOCK_OKAY()){
	print STDERR "Could not get the global lock!\n";
	return -1;
    }
    TBDebugTimeStamp("  got global lock")
	if ($lockdebug);

    #
    # If we blocked, it would be because vnodes have come or gone,
    # so we need to rebuild the maps.
    #
    # It is important that we do this once we have the global lock!  Our
    # cleanup code in bad: depends on us having the lock before we call
    # thi
    #
    refreshLibVnodeNetCache();

    my $vmid;
    if ($vnode_id =~ /^[-\w]+\-(\d+)$/) {
	$vmid = $1;
    }
    else {
	print STDERR "vz_rootPreConfigNetwork: bad vnode_id $vnode_id, aborting!";
	goto badbad;
    }
    
    my @node_ifs = @{ $vnconfig->{'ifconfig'} };
    my @node_lds = @{ $vnconfig->{'ldconfig'} };

    #
    # See if we have we have blockstore links.  We do not add them as
    # virtual docker networks; instead we handle the iscsi stuff outside
    # the container.  We just bind mount into the container stuff from
    # the root context.  We have to do this because parts of the iscsi
    # layer in the kernel are not network-namespace-aware, so we cannot
    # run the iscsi userspace tools in the network namespace, and do the
    # mount ourselves.  This way, we also reuse almost all the
    # rc.storage*/liblocstorage code, too.
    #
    my %blockstoreIPs = ();
    if (exists($vnconfig->{'storageconfig'})
	&& defined($vnconfig->{"storageconfig"})) {
	foreach my $bsref (@{$vnconfig->{'storageconfig'}}) {
	    if (exists($bsref->{"HOSTIP"})) {
		$blockstoreIPs{$bsref->{"HOSTIP"}} =
		    inet_aton($bsref->{"HOSTIP"});
	    }
	}
	TBDebugTimeStamp("blockstoreIPs: ".Dumper(%blockstoreIPs)."\n")
	    if ($debug > 1);
    }

    #
    # If we're using veths, figure out what bridges we need to make:
    # we need a bridge for each physical iface that is a multiplex pipe,
    # and one for each VTAG given PMAC=none (i.e., host containing both sides
    # of a link, or an entire lan).
    #
    my %brs = ();
    my $prefix;
    if ($USE_MACVLAN) {
	$prefix = "mv";
    }
    else {
	$prefix = "br";
    }

    foreach my $ifc (@node_ifs) {
	# XXX
	#next if (!$ifc->{ISVIRT});

	print "$vnode_id interface " . Dumper($ifc) . "\n"
	    if ($debug > 1);

	my $isblockstorelink = 0;
	if (keys(%blockstoreIPs) > 0
	    && exists($ifc->{IPMASK}) && exists($ifc->{IPADDR})) {
	    my ($nip,$nmask) =
		(inet_aton($ifc->{IPADDR}),inet_aton($ifc->{IPMASK}));
	    foreach my $k (keys(%blockstoreIPs)) {
		if (($nip & $nmask) eq ($blockstoreIPs{$k} & $nmask)) {
		    $isblockstorelink = 1;
		    last;
		}
	    }
	}
	if ($isblockstorelink) {
	    print "$vnode_id interface $ifc->{IPMASK} is a blockstore link;".
		" we will not create a virtual network for it.\n"
		if ($debug > 1);
	}

	#
	# In the era of shared nodes, we cannot name the bridges
	# using experiment local names (e.g., the link name).
	# Bridges are now named after either the physical interface
	# they are associated with or the "tag" if there is no physical
	# interface.
	#
	my $brname;
	my $physdev;

	if ($ifc->{ITYPE} eq "loop") {
	    my $vtag  = $ifc->{VTAG};

	    #
	    # No physical device. It's a loopback (trivial) link/lan
	    # All we need is a common bridge to put the veth ifaces into,
	    # or a dummy device to host the macvlan devices on.
	    #
	    $physdev = $brname = "${prefix}$vtag";
	    $brs{$brname}{ENCAP} = 0;
	    $brs{$brname}{SHORT} = 0;
	}
	elsif ($ifc->{ITYPE} eq "vlan") {
	    my $iface = $ifc->{IFACE};
	    my $vtag  = $ifc->{VTAG};
	    my $vdev  = "${iface}.${vtag}";

	    if (! -d "/sys/class/net/$vdev") {
		mysystem2("$VLANCONFIG set_name_type DEV_PLUS_VID_NO_PAD");
		mysystem2("$VLANCONFIG add $iface $vtag");
		goto bad
		    if ($?);
		mysystem2("$VLANCONFIG set_name_type VLAN_PLUS_VID_NO_PAD");

		#
		# We do not want the vlan device to have the same
		# mac as the physical device, since that will confuse
		# findif later.
		#
		my $bmac = fixupMac(GenFakeMac());
		mysystem2("$IP link set $vdev address $bmac");
		goto bad
		    if ($?);

		mysystem2("$IFCONFIG $vdev up");
		# XXX
		#mysystem2("$ETHTOOL -K $vdev tso off gso off");
		refreshLibVnodeNetCache();

		# XXX
		# Another thing that seems to screw up, causing the ciscos
		# to drop packets with an undersize error.
		#mysystem2("$ETHTOOL -K $iface txvlan off");
	    }
	    # XXX
	    # Temporary, to get existing devices after upgrade.
	    #mysystem2("$ETHTOOL -K $vdev tso off gso off");

	    $physdev =  $vdev;
	    $brname  = $prefix . $vdev;

	    # We save this so we can garbage-collect it in vnodeDestroy.
	    # But we don't remove it here if there's a failure.
	    $private->{'vlandevs'}->{$brname} = $vdev;
	    $brs{$brname}{ENCAP} = 1;
	    $brs{$brname}{SHORT} = 0;
	    $brs{$brname}{PHYSDEV} = $vdev;
	    $brs{$brname}{IFC} = $ifc;
	}
	#
	# These final two cases should only be ITYPE==veth .
	# We will never see a veth on a shared node, thus they
	# have already been created during the physnode config.
	#
	elsif ($ifc->{PMAC} eq "none") {
	    $physdev = $brname = $prefix . $ifc->{VTAG};
	    # if no PMAC, we don't need encap on the bridge
	    $brs{$brname}{ENCAP} = 0;
	    # count members below so we can figure out if this is a shorty
	    $brs{$brname}{MEMBERS} = 0;
	}
	else {
	    my $iface = findIfaceByMAC($ifc->{PMAC});
	    $physdev = $iface;
	    $brname  = $prefix . $iface;
	    $brs{$brname}{ENCAP} = 1;
	    $brs{$brname}{SHORT} = 0;
	    $brs{$brname}{IFC} = $ifc;
	    $brs{$brname}{PHYSDEV} = $iface;
	}
	# Stash for later phase.
	$ifc->{'PHYSDEV'} = $physdev
	    if (defined($physdev));
	$ifc->{'BRIDGE'} = $brname
	    if (defined($brname));

	if ($isblockstorelink) {
	    $brs{$brname}{ISBLOCKSTORELINK} = 1;
	    $ifc->{ISBLOCKSTORELINK} = 1;
	}

	#
	# Docker networks require a subnet (and a gateway; i.e.
	# https://github.com/docker/libnetwork/issues/1447#issuecomment-247368397).
	# This gateway assumption appears builtin to Docker at abstract
	# levels, and thus would take significant patching to
	# workaround.  So we don't do that.  Instead we have a hack, see below.
	#
	# Anyway, we have to extract and save off the cidr/gateway bits so that
	# when we create the Docker network, we have what we need.
	#
	# XXX: this of course won't work for shared nodes with
	# overlapping exp net subnets!  Docker/libnetwork has an
	# incredibly limited network model; it's ridiculous.
	#
	if (exists($ifc->{IPMASK}) && exists($ifc->{IPADDR})) {
	    # Figure out the subnet for this network:
	    my $ipaddr = inet_aton($ifc->{IPADDR});
	    my $netmask = inet_aton($ifc->{IPMASK});
	    my $maskbits = 0;
	    my $cval = unpack("N",$netmask);
	    for (my $i = 31; $i >= 0; --$i) {
		last if (($cval & 0x1) == 1);
		++$maskbits;
		$cval = $cval >> 1;
	    }
	    $maskbits = 32 - $maskbits;
	    $brs{$brname}{CIDR} = inet_ntoa($ipaddr & $netmask) . "/$maskbits";

	    #
	    # NB XXX: Use the final address in the subnet as the
	    # gateway.  (I considered using the penultimate address, to
	    # assume that some manually-assigning users will take the
	    # final non-broadcast address, but that is just a grosser
	    # hack -- we'll just document this). Obviously, if this
	    # address was used/assigned by Emulab or the user, that
	    # container will fail to boot!  I could check this in the
	    # single experiment case, but I'm not sure how to check for
	    # a shared LAN.  Anyway, we'll just document this too...
	    #
	    $brs{$brname}{GW} =
		inet_ntoa(pack("N",unpack("N",$ipaddr | ~$netmask) - 1));
	}
	else {
	    warn("Fatal: all Docker network interfaces *must* have an".
		 " IP address and subnet; aborting!");
	    goto bad;
	}
    }

    #
    # Make bridges and add phys ifaces.
    #
    # Or, in the macvlan case, create a dummy device if there is no
    # underlying physdev to "host" the macvlan.
    #
    foreach my $k (keys(%brs)) {
	my $cidr = $brs{$k}{CIDR};
	my $gw = $brs{$k}{GW};
	my $isblockstorelink = 0;
	if (exists($brs{$k}{ISBLOCKSTORELINK})) {
	    $isblockstorelink = $brs{$k}{ISBLOCKSTORELINK};
	}

	if (!$USE_MACVLAN) {
	    #
	    # This bridge might be shared with other containers, so difficult
	    # to delete. This really only matters on shared nodes though, where
	    # bridges and vlans could stack up forever (or just a long time).
	    #
	    if (! -d "/sys/class/net/$k/bridge") {
		addbr($k);
		goto bad
		    if ($?);

		#
		# Bad feature of bridges; they take on the lowest numbered
		# mac of the added interfaces (and it changes as interfaces
		# are added and removed!). But the main point is that we end
		# up with a bridge that has the same mac as a physical device
		# and that screws up findIface(). But if we "assign" a mac
		# address, it does not change and we know it will be unique.
		#
		my $bmac = fixupMac(GenFakeMac());
		mysystem2("$IP link set $k address $bmac");
		goto bad
		    if ($?);
	    }
	    # record bridge used
	    $private->{'physbridges'}->{$k} = $k;

	    # repetitions of this should not hurt anything
	    mysystem2("$IFCONFIG $k 0 up");

	    #
	    # Add a physical interface to the bridge if necessary.
	    #
	    if (exists($brs{$k}{PHYSDEV})) {
		my $physdev = $brs{$k}{PHYSDEV};

		#
		# This interface should not be a member of another bridge.
		# If it is, it is an error.
		#
		# Continuing the comment above, this bridge and this interface
		# might be shared with other containers, so we cannot remove it
		# unless it is the only one left. 
		#
		my $obr = getBridgeForIface($physdev);
		if (defined($obr) && $obr ne $k) {
		    # Avoid removing the device from the bridge if it
		    # is in the correct bridge. 
		    delbrif($obr, $physdev);
		    goto bad
			if ($?);
		    $obr = undef;
		}
		if (!defined($obr)) {
		    addbrif($k, $physdev);
		    goto bad
			if ($?);
		    # rebuild hashes
		    refreshLibVnodeNetCache();
		}

		$private->{'physbridgeifaces'}->{$k}->{$physdev} = $physdev;
	    }

	    #
	    # If this is a blockstore link, we just IP the bridge we
	    # just created; we do not expose this as a Docker virtual
	    # network.  This way, we can reuse all the existing network
	    # teardown code.
	    #
	    if ($isblockstorelink) {
		my ($bsa,$bsm) =
		    ($brs{$k}{IFC}->{IPADDR},$brs{$k}{IFC}->{IPMASK});
		mysystem2("$IP addr replace $bsa/$bsm dev $k");
		mysystem2("$IP link set $k up");
	    }
	    else {
		#
		# Now that the bridge exists, make the Docker network atop it.
		#
		TBDebugTimeStamp("checking existence of docker network $k");
		($code,$content,$resp) = getClient()->network_inspect($k);
		if ($code) {
		    my $ourdocker_extra_args = undef;
		    if ($ISOURDOCKER) {
			$ourdocker_extra_args = {
			    "Options" => { "com.docker.network.bridge.layer2_mode"
					       => "true" },
				"IPAM" => { "Options" => { "PrivatePoolId" => $k } },
			};
		    }
		    TBDebugTimeStamp("creating docker network $k");
		    ($code,$content,$resp) = getClient()->network_create_bridge(
			$k,$cidr,$gw,$k,$ourdocker_extra_args);
		    goto bad
			if ($code);
		}
		$private->{'dockernets'}->{$k} = $k;
		#
		# Also, if this is our Docker and we have iptables
		# enabled, we need a default-allow rule for all traffic
		# within the network -- Docker blocks by default.
		#
		if ($ISOURDOCKER) {
		    DoIPtablesNoFail("-A FORWARD -i $k -o $k -j ACCEPT");
		}
	    }
	}
	else {
	    my $basedev;
	    
	    #
	    # If there's a physical device, build the macvlan atop
	    # that.  Otherwise, need to create a dummy device to
	    # "host" the macvlan ports.
	    #
	    if (exists($brs{$k}{PHYSDEV})) {
		$basedev = $brs{$k}{PHYSDEV};
	    }
	    else {
		$basedev = $k;
		if (! -d "/sys/class/net/$k") {
		    mysystem2("$IP link add name $basedev type dummy");
		    goto bad
			if ($?);
		}
		# record dummy used
		$private->{'dummys'}->{$k} = $basedev;
	    }

	    if ($isblockstorelink) {
		my ($bsa,$bsm) =
		    ($brs{$k}{IFC}->{IPADDR},$brs{$k}{IFC}->{IPMASK});
		mysystem2("$IP addr replace $bsa/$bsm dev $k");
		mysystem2("$IP link set $k up");
	    }
	    else {
		#
		# Make the docker network if necessary.
		#
		TBDebugTimeStamp("checking existence of docker network $k");
		($code,$content,$resp) = getClient()->network_inspect($k);
		if ($code) {
		    # Now that the dummy device exists, make the Docker
		    # network atop it.
		    TBDebugTimeStamp("creating docker network $k");
		    ($code,$content,$resp) = getClient()->network_create_macvlan(
			$k,$cidr,$gw,$basedev);
		    goto bad
			if ($code);
		}
		$private->{'dockernets'}->{$k} = $k;
	    }
	}
    }

    #
    # We can handle linkdelays in two combinations.
    #
    # First, if we're not using macvlans and are using bridges, we place
    # a qdisc on the veth in the root context to handle egress shaping;
    # and we bind an IFB device to the veth and redirect ingress packets
    # to it, and place an egress qdisc on it, to handle ingress shaping.
    #
    # Second, the only way to do this with macvlans is to place the
    # qdiscs *in* the container, and to move an IFB into the container's
    # network namespace.  This is only secure for shared vnodes IFF the
    # container is unprivileged (not real root), and if it does not have
    # CAP_NET_ADMIN -- given both those restrictions, the user cannot
    # remove the traffic shaping inside the container.  On a shared
    # node, of course our containers are deprivileged, but they ought to
    # have CAP_NET_ADMIN and CAP_NET_RAW.
    #
    # This is unfortunate; we would like to use macvlans; but we prefer
    # to use the same mechanism for both the dedicated and share vnode
    # case -- thus we use bridges unless requested to use macvlans.
    #

    #
    # IFBs are a little tricky. Once they are mapped into a container,
    # we never get to see them again until the container is fully
    # destroyed or until we explicitly unmap them from the container.
    # We also want to hang onto them so we do not get into a situation
    # where we stopped to take a disk image, and then cannot start
    # again cause we ran out of resources (shared nodes). So, we have
    # to look for IFBs that are already allocated to the
    # container. See the allocate routines, which make use of the tag.
    #
    my $ifbs;
    if (@node_lds) {
	$ifbs = AllocateIFBs($vmid, \@node_lds, $private);
	goto bad
	    if (!(defined($ifbs)));
    }

    #
    # We cannot hold the global lock while we run CreateRoutingScripts.
    # For a large topo, this may call djikstra, and that can be quite
    # CPU-consuming.  Also, may as well avoid it on
    # CreateShapingScripts.
    #
    TBDebugTimeStamp("  releasing global lock")
	if ($lockdebug);
    TBScriptUnlock();

    #
    # Let vnodesetup exit early, so that bootvnodes delays minimally per
    # vnode.  I guess we figure if we can get through this call, we've
    # made it through the obvious failures in the overall preparatory
    # code in mkvnode.pl.
    #
    if ($vsrelease eq "immediate") {
	TBDebugTimeStamp("rootPreConfigNetwork: touching $VMS/$vnode_id/running");
	mysystem2("touch $VMS/$vnode_id/running");
    }

    #
    # Return to handling the allocated IFBs for shaping.
    #
    if (@node_lds) {
	foreach my $ldc (@node_lds) {
	    my $tag = "$vnode_id:" . $ldc->{'LINKNAME'};
	    my $ifb = pop(@$ifbs);
	    $private->{'ifbs'}->{$ifb} = $tag;
	    
	    # Stash for later.
	    $ldc->{'IFB'} = $ifb;
	}

	CreateShapingScripts($vnode_id,$private,\@node_ifs,\@node_lds);
    }

    # Setup our routing stuff.
    CreateRoutingScripts($vnode_id,$private);

    return 0;

  bad:
    #
    # Unwind anything we did. 
    #
    # Remove any Docker networks we would have used that are unused.
    if (exists($private->{'dockernets'})) {
	foreach my $name (keys(%{ $private->{'dockernets'} })) {
	    my @members = getDockerNetMemberIds($name);
	    if (@members == 0) {
		TBDebugTimeStamp("removing docker network $name");
		($code,) = getClient()->network_delete($name);
		if (!$code) {
		    delete($private->{'dockernets'}->{$name});
		    #
		    # Also, if this is our Docker and we have iptables
		    # enabled, we need to remove the default-allow rule
		    # for all traffic within the network.
		    #
		    if ($ISOURDOCKER) {
			DoIPtablesNoFail("-D FORWARD -i $name -o $name -j ACCEPT");
		    }
		}
	    }
	}
    }
    # Delete bridges we would have used that are unused.  If only the
    # physdevices we added to the bridge are in the bridge, remove them,
    # then remove the bridge.
    if (exists($private->{'physbridges'})) {
	foreach my $brname (keys(%{ $private->{'physbridges'} })) {
	    my @ifaces = getBridgeIfaces($brname);
	    if (@ifaces == 0) {
		TBDebugTimeStamp("removing unused $brname");
		mysystem2("$IFCONFIG $brname down");
		delbr($brname);
		if (!$?) {
		    delete($private->{'physbridges'}->{$brname});
		    delete($private->{'physbridgeifaces'}->{$brname});
		}
	    }
	    elsif (exists($private->{'physbridgeifaces'}->{$brname})) {
		#
		# Check for anything other than the physbridgeifaces we
		# would have added to this bridge; if only those are in
		# the bridge, remove them, then remove the bridge.
		#
		my %ifm = ();
		foreach my $ifc (@ifaces) {
		    $ifm{$ifc} = 1;
		}

		foreach my $physiface (keys(%{$private->{'physbridgeifaces'}->{$brname}})) {
		    delete($ifm{$physiface})
			if (exists($ifm{$physiface}));
		}

		# If only the physifaces were left in the bridge, nuke
		# them all, then dump the bridge.
		if (keys(%ifm) == 0) {
		    foreach my $ifc (@ifaces) {
			TBDebugTimeStamp("removing $ifc from unused $brname");
			delbrif($brname,$ifc);
			delete($private->{'physbridgeifaces'}->{$brname}->{$ifc});
		    }

		    TBDebugTimeStamp("removing unused $brname");
		    mysystem2("$IFCONFIG $brname down");
		    delbr($brname);
		    if (!$?) {
			delete($private->{'physbridges'}->{$brname});
			delete($private->{'physbridgeifaces'}->{$brname});
		    }
		}
	    }
	}
    }
    # Delete the dummy macvlan thingies we would have used, if no
    # one else is using them.
    if (exists($private->{'dummys'})) {
	foreach my $brname (keys(%{ $private->{'dummys'} })) {
	    my @mvs = getMacvlanIfaces($private->{'dummys'}->{$brname});
	    if (@mvs == 0) {
		mysystem2("$IP link del dev $brname");
		delete($private->{'dummys'}->{$brname})
		    if ($?);
	    }
	}
    }
    # Delete any vlan devices we would have used, if no one else is
    # using them (i.e. if they are not in a bridge, and are not a parent
    # of any other macvlan devices).
    if (exists($private->{'vlandevs'})) {
	foreach my $brname (keys(%{ $private->{'vlandevs'} })) {
	    my $viface = $private->{'vlandevs'}->{$brname};
	    next
		if (!defined($viface));
	    my $brv = getBridgeForIface($viface);
	    my @mvs = getMacvlanIfaces($viface);
	    if (!defined($brv) && @mvs == 0) {
		mysystem2("$IP link del dev $viface");
		delete($private->{'vlandevs'}->{$brname})
		    if ($?);
	    }
	}
    }

    # This shouldn't matter, but let's be complete; we might've deleted
    # some bridges and interfaces.
    refreshLibVnodeNetCache();

    # Release the IFBs
    ReleaseIFBs($vmid, $private)
	if (exists($private->{'ifbs'}));

  badbad:
    TBScriptUnlock();
    return -1;
}

sub _docker_get_ext_trans_mountpoint($)
{
    my ($mpoint,) = @_;

    my $confdir = CONFDIR();
    my $tmpoint = `readlink -f $confdir/mountpoints`;
    chomp($tmpoint);
    if ($mpoint =~ /^$tmpoint/) {
	return $mpoint;
    }
    else {
	$mpoint = $tmpoint.$mpoint;
    }
    if (! -e $mpoint) {
	my @dirs = split(/\//,$mpoint);
	my $tpath = CONFDIR()."/mountpoints";
	foreach my $dir (@dirs) {
	    $tpath .= "/$dir";
	    mkdir($tpath);
	}
    }

    return $mpoint;
}

#
# Create the basic context for the VM and give it a unique ID for identifying
# "internal" state.  If $raref is set, then we are in a RELOAD state machine
# and need to walk the appropriate states.
#
sub vnodeCreate($$$$)
{
    my ($vnode_id, undef, $vnconfig, $private) = @_;
    my $attributes = $vnconfig->{'attributes'};
    my $imagename = $vnconfig->{'image'};
    my $inreload = defined($imagename) ? 1 : 0;
    my $raref = $vnconfig->{'reloadinfo'};
    my $vninfo = $private;
    my %mounts = ();
    my $imagemetadata;
    my $lvname;
    my $rc;
    my $err = undef;
    my ($code,$content,$resp);

    my $vmid;
    if ($vnode_id =~ /^[-\w]+\-(\d+)$/) {
	$vmid = $1;
    }
    else {
	fatal("vnodeCreate: bad vnode_id $vnode_id!");
    }
    $vninfo->{'vmid'} = $vmid;

    my ($host_iface,$host_ip,$host_mask,$host_maskbits,$host_net,
	$host_mac,$host_gw) = getControlNet();

    my ($pid,$eid,$vname) = check_nickname();
    #
    # Need the domain, but no conistent way to do it. Ask tmcc for the
    # boss node and parse out the domain. 
    #
    my ($DOMAINNAME,$BOSSIP) = tmccbossinfo();
    fatal("vnodeCreate: Could not get bossname from tmcc!")
	if (!defined($DOMAINNAME));
    if ($DOMAINNAME =~ /^[-\w]+\.(.*)$/) {
	$DOMAINNAME = $1;
    }
    else {
        fatal("vnodeCreate: Could not parse domain name from bossinfo!");
    }
    my $longdomain = "${eid}.${pid}.${DOMAINNAME}";
    my $shortdomain = `cat /var/emulab/boot/mydomain`;
    chomp($shortdomain);

    if (defined($raref)) {
	TBDebugTimeStamp("inreload: " . Dumper($raref));
	$raref = $raref->[0];
	$inreload = 1;
    }

    #
    # A quick sanity check to prevent privileged containers on shared
    # nodes.  The frontend protects us against this, but have to be
    # sure.
    #
    my $privileged = 0;
    if (exists($attributes->{'DOCKER_PRIVILEGED'})
	&& $attributes->{'DOCKER_PRIVILEGED'} eq '1') {
	if (SHAREDHOST()) {
	    fatal("vnodeCreate: cannot spawn privileged container on shared host!");
	}
	$privileged = 1;
    }

    #
    # Figure out where/what we're pulling, and a username/password if
    # necessary.
    #
    my ($user,$pass);
    my $dockerfile;
    if ((!$imagename || $imagename =~ /^emulab-ops-emulab-ops-DOCKER-EXT/)
	&& exists($attributes->{'DOCKER_EXTIMAGE'})) {
	$imagename = $attributes->{'DOCKER_EXTIMAGE'};
	if (exists($attributes->{'DOCKER_EXTUSER'})) {
	    $user = $attributes->{'DOCKER_EXTUSER'};
	}
	if (exists($attributes->{'DOCKER_EXTPASS'})) {
	    $pass = $attributes->{'DOCKER_EXTPASS'};
	}
    }
    elsif ((!$imagename || $imagename =~ /^emulab-ops-emulab-ops-DOCKER-EXT/)
	   && exists($attributes->{'DOCKER_DOCKERFILE'})) {
	my @evkeyresults = ();
	if (libtmcc::tmcc(libtmcc::TMCCCMD_EVENTKEY,undef,\@evkeyresults) < 0
	    || @evkeyresults < 1) {
	    fatal("Could not get keyhash from server!");
	}
	my $eventkey;
	if ($evkeyresults[0] =~ /EVENTKEY KEY='?([\w\d]+)'?/) {
	    $eventkey = $1;
	}
	else {
	    fatal("could not extract eventkey from $evkeyresults[0]!");
	}
	$dockerfile = $attributes->{'DOCKER_DOCKERFILE'};
	my $urlhash = sha1_hex($dockerfile);
	$imagename = lc("$pid-$eid-$eventkey:$urlhash");
    }
    elsif ($inreload) {
	# For local reloads, username is physical host shortname;
	# password is the eventkey.
	open(FD,"$BOOTDIR/nodeid")
	    or die("open($BOOTDIR/nodeid): $!");
	$user = <FD>;
	chomp($user);
	close(FD);
	open(FD,"$BOOTDIR/eventkey")
	    or die("open($BOOTDIR/eventkey): $!");
	$pass = <FD>;
	chomp($pass);
	close(FD);

	if (exists($raref->{"PATH"}) && $raref->{"PATH"}) {
	    $imagename = $raref->{"PATH"};
	}
	elsif (exists($vnconfig->{"config"}->{'IMAGEPATH'})
	       && $vnconfig->{"config"}->{'IMAGEPATH'}) {
	    $imagename = $vnconfig->{"config"}->{'IMAGEPATH'};
	}
	else {
	    fatal("reload or image specified, but not external image," .
		  " and no image PATH nor jailconfig IMAGEPATH!");
	}
    }
    else {
	$imagename = $defaultImage{'name'};
    }

    #
    # XXX future optimization possibility.
    #
    # Try to be smart about holding the vnode creation lock which is not
    # a single lock, but rather a small set of locks intended to limit
    # concurrency in the vnode creation process. Specifically, if we grab
    # a create_vnode lock and then block waiting for our image lock, then
    # we might prevent someone else (using a different image) from making 
    # progress. So we could instead: grab a create_vnode lock, make a short
    # attempt (5-10 seconds) to grab the image lock and, failing that, back
    # off of the create_vnode lock, wait and then try the whole process again.
    #
    # The problem is that we may block again down in downloadOneImage when
    # we try to grab the image lock exclusively. Not sure we can back all
    # the way out easily in that case!
    #
    # This is also a bit of a de-optimization when we have a set of vnodes
    # all using the same image. We just cause a bit of excess context
    # switching in that (probably more common) case.
    #

    if (CreateVnodeLock() != 0) {
	fatal("CreateVnodeLock()");
    }

    if ($inreload) {
	# No real difference for us here; RELOADING has a longer timeout too.
	libutil::setState("RELOADSETUP");
	libutil::setState("RELOADING");
    }

    my ($newimagename,$newcreateargs,$newcmd,$newization);
    $rc = setupImage($vnode_id,$vnconfig,$private,$imagename,$user,$pass,
		     $dockerfile,
		     \$newimagename,\$newcreateargs,\$newcmd,\$newization);
    if ($rc) {
	libutil::setState("RELOADFAILED");
	fatal("Failed to setup $imagename for $vnode_id; aborting!");
    }
    $private->{'emulabization'} = $newization;
    if (!exists($vnconfig->{'attributes'}->{DOCKER_EMULABIZATION})) {
	$vnconfig->{'attributes'}->{DOCKER_EMULABIZATION} = $newization;
    }

    if ($inreload) {
	libutil::setState("RELOADDONE");
	# XXX why do we need to wait for this to take effect?
	TBDebugTimeStamp("waiting 4 sec after asserting RELOADDONE...");
	sleep(4);

	#
	# Finish off the state transitions as necessary.
	#
	libutil::setState("SHUTDOWN");
    }

    CreateVnodeUnlock();

    #
    # Make sure all the physical NFS mounts we're going to bind mount
    # are in place.
    #
    addMounts($vnode_id,\%mounts);

    #
    # Handle blockstores/datasets.
    #
    my %blockstoreMounts = ();
    if (exists($vnconfig->{"storageconfig"})
	&& defined($vnconfig->{"storageconfig"})) {
	foreach my $bsref (@{$vnconfig->{'storageconfig'}}) {
	    if (exists($bsref->{"MOUNTPOINT"})) {
		my $src = _docker_get_ext_trans_mountpoint($bsref->{"MOUNTPOINT"});
		$blockstoreMounts{$src} = $bsref->{"MOUNTPOINT"};
	    }
	}
	TBDebugTimeStamp("blockstoreMounts: ".Dumper(%blockstoreMounts)."\n")
	    if ($debug > 1);
	TBDebugTimeStamp("starting rc.storage")
	    if ($debug > 1);
	if (mysystem2("/usr/local/etc/emulab/rc/rc.storage -j $vnode_id boot")) {
	    fatal("Failed to setup storage in rc.storage; aborting!");
	}
	TBDebugTimeStamp("rc.storage finished successfully")
	    if ($debug > 1);
	$private->{'blockstores'} = scalar(keys(%blockstoreMounts));
    }

    #
    # Start building the 'docker create' args.  
    # (NB: see note below about why we have to put the container on the
    # network right away!)
    #
    my %args = ( "Tty" => JSON::PP::true,"Image" => $newimagename );
    # XXX: I wonder if not all containers will want this, but who knows.
    $args{'AttachStdin'} = JSON::PP::true;
    $args{'AttachStdout'} = JSON::PP::true;
    $args{'AttachStderr'} = JSON::PP::true;
    $args{'OpenStdin'} = JSON::PP::true;

    # Handle privileged containers.  NB: we already checked the sharedhost case above.
    if ($privileged) {
	$args{"HostConfig"}{"Privileged"} = JSON::PP::true;
    }

    my @hostspairs = ();
    genhostspairlist($vnode_id,\@hostspairs);
    if (@hostspairs) {
	$args{"HostConfig"}{"ExtraHosts"} = \@hostspairs;
    }

    #
    # Add NFS mounts.
    #
    $args{"HostConfig"}{"Binds"} = [];
    foreach my $path (values(%mounts)) {
	my $bind = "${path}:${path}";
	if ($NFS_MOUNTS_READONLY) {
	    $bind .= ":ro";
	}
	push(@{$args{"HostConfig"}{"Binds"}},$bind);
    }

    #
    # Add blockstore mounts.
    #
    foreach my $src (keys(%blockstoreMounts)) {
	my $dst = $blockstoreMounts{$src};
	my $bind = "${src}:${dst}";
	push(@{$args{"HostConfig"}{"Binds"}},$bind);
    }

    #
    # Add some Emulab-specific mount points that contain information:
    # /var/emulab/boot/{tmcc,tmcc.<vnodeid>}.
    #
    my $mntdir = CONFDIR()."/mountpoints";
    for my $dir ("$mntdir","$mntdir/var.emulab",
		 "$mntdir/var.emulab/boot","$mntdir/var.emulab/boot/tmcc",
		 "$mntdir/var.emulab/db","$mntdir/var.emulab/logs",
		 "$mntdir/var.emulab/lock") {
	mkdir($dir);
    }
    if ($newization eq DOCKER_EMULABIZE_CORE()
	|| $newization eq DOCKER_EMULABIZE_BUILDENV()
	|| $newization eq DOCKER_EMULABIZE_FULL()) {
	my ($boss_name,$boss_ip) = tmccbossinfo();
	open(FD,">$mntdir/bossnode");
	print FD "$boss_name\n";
	close(FD);
	push(@{$args{"HostConfig"}{"Binds"}},"$mntdir/bossnode:/etc/emulab/bossnode:ro");
    }
    # Populate the tmcc info.
    mysystem2("rsync -a /var/emulab/boot/tmcc.$vnode_id/".
	      " $mntdir/var.emulab/boot/tmcc/");
    push(@{$args{"HostConfig"}{"Binds"}},"$mntdir/var.emulab:/var/emulab:rw");

    #
    # Let the inside clientside know it is a GENVNODE().  NB: we do this
    # as an read-only mount because the container removes it on reboot,
    # and we don't want to have to rewrite it in time.
    #
    open(FD,">$mntdir/vmname")
	or fatal("could not open $mntdir/vmname: $!");
    print FD $vnode_id;
    close(FD);
    push(@{$args{"HostConfig"}{"Binds"}},
	 "$mntdir/vmname:/var/emulab/boot/vmname:ro");

    #
    # Tell the clientside to use the gzip'd versions of ltmap and
    # ltpmap; if we don't use these, on multi-thousand node topos, they
    # suck up too much space in the host.
    #
    open(FD,">$mntdir/ltmap-gzip");
    close(FD);
    push(@{$args{"HostConfig"}{"Binds"}},
	 "$mntdir/ltmap-gzip:/etc/emulab/ltmap-gzip:ro");

    #
    # Tell the inside clientside which event server to use.  NB: we do
    # this as an read-only mount because the container removes it on
    # reboot, and we don't want to have to rewrite it in time.
    #
    my $evip;
    if (isRoutable($vnconfig->{'config'}->{'CTRLIP'})) {
	$evip = $vnconfig->{'config'}->{'CTRLIP'};
    }
    else {
	$evip = $host_ip;
    }
    open(FD,">$mntdir/localevserver")
	or fatal("could not write $mntdir/localevserver: $!");
    print FD "$evip";
    close(FD);
    push(@{$args{"HostConfig"}{"Binds"}},
	 "$mntdir/localevserver:/var/emulab/boot/localevserver:ro");

    # Ugh, have to mount the certs into the container.  We can't just
    # mount over /etc/emulab entirely (well, we could, but it would not
    # be safe; the clientside allows the user to persistently update
    # stuff in that dir, so we don't want a mount over top what's in the
    # image, even if it's writeable).
    push(@{$args{"HostConfig"}{"Binds"}},
	 "/etc/emulab/client.pem:/etc/emulab/client.pem:ro");
    push(@{$args{"HostConfig"}{"Binds"}},
	 "/etc/emulab/emulab.pem:/etc/emulab/emulab.pem:ro");

    # piping through custom CMD and PATH variables for users of the docker
    # images. Just have to write them to a file and let the runit utility
    # do the rest
    my $ddir = "$mntdir/etc.emulab.docker";
    mkdir($ddir);
    if (exists($attributes->{'DOCKER_ENV'})) {
	my $envvars = $attributes->{'DOCKER_ENV'};
	if ($envvars =~ /^base64url:(.+)$/) {
	    $envvars = MIME::Base64::decode_base64url($1);
	}
	open(FD, ">$ddir/dockerenv.runtime");
	print FD "export $envvars\n";
	close(FD);
	push(@{$args{"HostConfig"}{"Binds"}},
	     "$ddir/dockerenv.runtime:/etc/emulab/docker/dockerenv.runtime:ro");
    }
    if (exists($attributes->{'DOCKER_CMD'})) {
	my $c = $attributes->{'DOCKER_CMD'};
	if ($c =~ /^base64url:(.+)$/) {
	    $c = MIME::Base64::decode_base64url($1);
	}
	TBDebugTimeStamp("runtime cmd: $c\n");
	if ($c =~ /^\[/) {
	    $c = decode_json($c);
	    $c = "array:" . join(",",map { unpack("H*",$_) } @{$c});
	}
	elsif ($c ne "") {
	    $c = "string:" . unpack("H*",$c);
	}
	if ($c ne "") {
	    open(FD, ">$ddir/cmd.runtime");
	    print FD "$c\n";
	    close(FD);
	}
	TBDebugTimeStamp("encoded runtime cmd: $c\n");
	push(@{$args{"HostConfig"}{"Binds"}},
	     "$ddir/cmd.runtime:/etc/emulab/docker/cmd.runtime:ro");
    }
    if (exists($attributes->{'DOCKER_ENTRYPOINT'})) {
	my $e = $attributes->{'DOCKER_ENTRYPOINT'};
	if ($e =~ /^base64url:(.+)$/) {
	    $e = MIME::Base64::decode_base64url($1);
	}
	TBDebugTimeStamp("runtime entrypoint: $e\n");
	if ($e =~ /^\[/) {
	    $e = decode_json($e);
	    $e = "array:" . join(",",map { unpack("H*",$_) } @{$e});
	}
	elsif ($e ne "") {
	    $e = "string:" . unpack("H*",$e);
	}
	if ($e ne "") {
	    open(FD, ">$ddir/entrypoint.runtime");
	    print FD "$e\n";
	    close(FD);
	}
	TBDebugTimeStamp("encoded runtime entrypoint: $e\n");
	push(@{$args{"HostConfig"}{"Binds"}},
	     "$ddir/entrypoint.runtime:/etc/emulab/docker/entrypoint.runtime:ro");
    }

    #
    # We allow the server to tell us how many VCPUs to allocate to the
    # guest. 
    #
    my $cpus = 0;
    if (exists($attributes->{'DOCKER_VCPUS'})
	&& $attributes->{'DOCKER_VCPUS'} > 1) {
	$cpus = $attributes->{'DOCKER_VCPUS'};
    }
    elsif (exists($attributes->{'VM_VCPUS'}) && $attributes->{'VM_VCPUS'} > 1) {
	$cpus = $attributes->{'VM_VCPUS'};
    }
    if ($cpus > 0) {
	#
	# Docker on non-windows doesn't really support the notion of a
	# whole VCPU (unless you pin specific CPUs to a container, which
	# we don't want to do, cause it's more bookkeeping).  So we
	# emulate that with a combination of cpu period and cpu quota.
	#
	$args{"HostConfig"}{"CpuPeriod"} = 100000;
	$args{"HostConfig"}{"CpuShares"} = 100000 * $cpus;
    }

    #
    # Give the vnode some memory. The server usually tells us how much. 
    #
    if (exists($attributes->{'DOCKER_MEMSIZE'})) {
	# Better be MB.  Docker wants bytes.
	$args{"HostConfig"}{"Memory"} = \
	    $attributes->{'DOCKER_MEMSIZE'} * 1024 * 1024;
    }
    elsif (exists($attributes->{'VM_MEMSIZE'})) {
	# Better be MB.  Docker wants bytes.
	$args{"HostConfig"}{"Memory"} = \
	    $attributes->{'VM_MEMSIZE'} * 1024 * 1024;
    }

    #
    # Attach the node to the control network.  NB: we would like to do
    # this in vnodePreConfigControlNetwork, but with docker, if you
    # specify --net=none as the initial "network", you cannot connect
    # your container to any other networks after create.  So we have to
    # do that initial connection here!
    #
    my ($ctrlip,$ctrlmask) = ($vnconfig->{config}{CTRLIP},
			      $vnconfig->{config}{CTRLMASK});
    my $ctrlmac;
    if (exists($vnconfig->{'config'}{CTRLMAC})) {
	$ctrlmac = $vnconfig->{'config'}{CTRLMAC};
    }
    else {
	$ctrlmac = ipToMac($ctrlip);
    }
    my $ctrlnetwork = inet_ntoa(inet_aton($ctrlip) & inet_aton($ctrlmask));
    my $fmac = fixupMac($ctrlmac);
    my $maskbits = 0;
    foreach my $octet (split(/\./,$ctrlmask)) {
	my $cval = int($octet);
	for (my $i = 0; $i < 8; ++$i) {
	    $maskbits += $cval & 1;
	    $cval = $cval >> 1;
	}
    }

    my %cnetconfig = (
	"IPAMConfig" => { "IPv4Address" => $ctrlip}
    );
    my $dcn = $DOCKERCNET;
    if ($ISMULTINETWORK && ($ctrlnetwork eq $host_net)) {
	$dcn = $DOCKERCNETPUB;
    }
    $args{"NetworkingConfig"}{"EndpointsConfig"}{$dcn} = \%cnetconfig;
    # This NetworkMode goo is apparently necessary to set the MacAddress
    # of the container's initial network.  Go figure -- it's not
    # documented this way -- but this is the way the CLI does it and it
    # works.  Needless to say, nothing else works!
    $args{"HostConfig"}{"NetworkMode"} = $dcn;
    $args{"MacAddress"} = $fmac;
    $args{"Hostname"} = "$vname.$longdomain";
    #
    # NB XXX: apparently --dns-search *does* work, but not --dns, when
    # you are using user-defined networks, or something.  Anyway, Docker
    # stuffs a 127.0.0.11 nameserver into /etc/resolv.conf even when
    # --dns is specified, so until that changes, I just mount the host's
    # resolv.conf into place.  Kill me now...
    #
    $args{"HostConfig"}{"DnsSearch"} = [ $shortdomain ];
    $args{"HostConfig"}{"Dns"} = [ $BOSSIP ];
    push(@{$args{"HostConfig"}{"Binds"}},
	 "/etc/resolv.conf:/etc/resolv.conf:ro");
    #
    # Tell the clientside in the VM what kind of machine it is.
    #
    push(@{$args{"HostConfig"}{"Binds"}},
	 "/etc/emulab/genvmtype:/etc/emulab/genvmtype:ro");

    #
    # XXX: safe on shared hosts?  Oh well, we have to have them.
    #
    $args{"HostConfig"}{"CapAdd"} = [ "NET_ADMIN","NET_BIND_SERVICE","NET_RAW" ];

    $args{"HostConfig"}{"CgroupParent"} = $vnode_id;

    # XXX: need to actually check to see if image has entrypoint/cmd,
    # and maybe emulate that stuff with a wrapper script.

    #
    # Finally, add in any of the extra args from setupImage, by merging
    # in the JSONish hashes into our config args.  They cannot override
    # the values we've already set (due to Hash::Merge's default policy
    # of left-precedence).
    #
    if (defined($newcreateargs)) {
	require Hash::Merge;
	if ($debug) {
	    print STDERR "DEBUG: pre-merge args = ".Dumper(%args)."\n";
	    print STDERR "DEBUG: pre-merge newcreateargs = ".Dumper(%$newcreateargs)."\n";
	}
	%args = %{Hash::Merge::merge(\%args,$newcreateargs)};
	if ($debug) {
	    print STDERR "DEBUG: merged createargs = ".Dumper(%args)."\n";
	}
    }
    if (defined($newcmd)) {
	require Hash::Merge;
	%args = %{Hash::Merge::merge(\%args,$newcmd)};
	if ($debug) {
	    print STDERR "DEBUG: merged createcmd = ".Dumper(%args)."\n";
	}
    }

    if ($debug) {
	print STDERR "container_create($vnode_id) args:\n".Dumper(%args)."\n";
    }
    
    #
    # Kill off a capture that might be running for this container.
    #
    if (-x "$CAPTURE") {
	my $rpid = captureRunning($vnode_id);
	if ($rpid) {
	    print STDERR "WARNING: capture already running ($rpid)!?".
		" Killing...\n";
	    kill("TERM", $rpid);
	    sleep(1);
	}
    }

    #
    # Go ahead and create.
    #
    TBDebugTimeStamp("creating docker container $vnode_id");
    ($code,$content,$resp) = getClient()->container_create($vnode_id,\%args);
    if ($code) {
	$err = "failed to create the container: $content";
	goto bad;
    }

    #
    # Finish off the state transitions as necessary.
    #
    if (defined($raref)) {
	libutil::setState("SHUTDOWN");
    }
    return $vmid;

  bad:
    removeMounts($vnode_id);
    fatal($err);
}

sub vnodePreConfig($$$$$){
    my ($vnode_id, $vmid, $vnconfig, $private, $callback) = @_;

    return 0;
}

#
# We already added the control net interface in vnodeCreate so that we
# could pass the network args via the docker create call.  So now just
# create associated root context stuff like firewall rules and port
# forwards.  We don't let Docker handle these port forwards because it
# is restrictive.
#
sub vnodePreConfigControlNetwork($$$$$$$$$$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private,
	$ip,$mask,$mac,$gw, $vname,$longdomain,$shortdomain,$bossip) = @_;
    my $vninfo = $private;

    # NB: the control net config is already associated with the
    # container, so we have no devices to create nor configure; Docker
    # will create them when it creates the container.

    # Maybe allow routable control network.
    my $isroutable = isRoutable($ip);

    my ($host_iface,$host_ip,$host_mask,$host_maskbits,$host_net,
	$host_mac,$host_gw) = getControlNet();
    my ($vip,undef,undef) = hostControlNet($host_ip,$host_mask);
    my ($bossdomain,$boss_ip) = tmccbossinfo();
    if (!$boss_ip) {
	$boss_ip = `cat $BOOTDIR/bossip`;
	chomp($boss_ip);
    }
    if (!$boss_ip) {
	warn("could not find bossip anywhere; aborting!");
	return -1;
    }
    my $retries = 4;
    my @addrs = ();
    my $uname = "users";
    while ($retries > 0) {
	(undef,undef,undef,undef,@addrs) = gethostbyname($uname);
	if ($? || @addrs == 0) {
	    warn("could not resolve $uname; retrying!");
	    sleep(4);
	}
	else {
	    last;
	}
	$uname = "users.$shortdomain";
	$retries -= 1;
    }
    my $ops_ip;
    if (@addrs == 0) {
	warn("could not resolve users.$bossdomain; sending name to iptables!");
	$ops_ip = "users";
    }
    else {
	$ops_ip = inet_ntoa($addrs[0]);
    }
    my $local_tmcd_port = $TMCD_PORT + $vmid;

    #
    # Set up the chains. We always create them, and if there is no
    # firewall, they default to accept. This makes things easier in
    # the control network script (emulab-cnet.pl).
    #
    # Do not worry if these fail; we will catch it below when we add
    # the rules. Or I could look to see if the chains already exist,
    # but why bother.
    #
    my @rules = ();

    # Ick, iptables has a 28 character limit on chain names. But we have to
    # be backwards compatible with existing chain names. See corresponding
    # code in emulab-cnet.pl
    my $IN_CHAIN = "IN_${vnode_id}";
    my $OUT_CHAIN = "OUT_${vnode_id}";
    if (length($IN_CHAIN) > 28) {
	$IN_CHAIN = "I_${vnode_id}";
	$OUT_CHAIN = "O_${vnode_id}";
    }
    push(@rules, "-N $IN_CHAIN");
    push(@rules, "-F $IN_CHAIN");
    push(@rules, "-N $OUT_CHAIN");
    push(@rules, "-F $OUT_CHAIN");

    # Match existing dynamic rules as early as possible.
    push(@rules, "-A $IN_CHAIN -m conntrack ".
	 "--ctstate RELATED,ESTABLISHED -j ACCEPT");
    push(@rules, "-A $OUT_CHAIN -m conntrack ".
	 "--ctstate RELATED,ESTABLISHED -j ACCEPT");

    # Do all the rules regardless of whether they fail
    DoIPtablesNoFail(@rules);
    
    # For the next set of rules we want to fail on first error
    @rules = ();

    if ($vnconfig->{'fwconfig'}->{'fwinfo'}->{'TYPE'} eq "none") {
	if ($IPTABLES_PACKET_LOG) {
	    push(@rules, "-A $IN_CHAIN -j LOG ".
		 "  --log-prefix 'IN-${vnode_id}: ' --log-level 5");
	    push(@rules, "-A $OUT_CHAIN -j LOG ".
		 "  --log-prefix 'OUT-${vnode_id}: ' --log-level 5");
	}

	push(@rules, "-A $IN_CHAIN -j ACCEPT");
	push(@rules, "-A $OUT_CHAIN -j ACCEPT");
    }
    else {
	if ($IPTABLES_PACKET_LOG) {
	    push(@rules, "-A $IN_CHAIN -j LOG ".
		 "  --log-prefix 'IN-${vnode_id}: ' --log-level 5");
	    push(@rules, "-A $OUT_CHAIN -j LOG ".
		 "  --log-prefix 'OUT-${vnode_id}: ' --log-level 5");
	}

	#
	# These rules allows the container to talk to the TMCC proxy.
	# If you change this port, change InsertPostBootIptablesRules too.
	#
	push(@rules,
	     "-A $OUT_CHAIN -p tcp ".
	     "-d $host_ip --dport $local_tmcd_port ".
	     "-m conntrack --ctstate NEW -j ACCEPT");
	push(@rules,
	     "-A $OUT_CHAIN -p udp ".
	     "-d $host_ip --dport $local_tmcd_port ".
	     "-m conntrack --ctstate NEW -j ACCEPT");

	#
	# Need to do some substitution first.
	#
	foreach my $rule (@{ $vnconfig->{'fwconfig'}->{'fwrules'} }) {
	    my $rulestr = $rule->{'RULE'};
	    $rulestr =~ s/\s+me\s+/ $ip /g;
	    $rulestr =~ s/\s+INSIDE\s+/ $OUT_CHAIN /g;
	    $rulestr =~ s/\s+OUTSIDE\s+/ $IN_CHAIN /g;
	    $rulestr =~ s/^iptables //;
	    push(@rules, $rulestr);
	}

	#
	# For debugging, we want to log any packets that get to the bottom,
	# since they are going to get dropped.
	#
	if ($IPTABLES_PACKET_LOG) {
	    push(@rules, "-A $IN_CHAIN -j LOG ".
		 "  --log-prefix 'IN ${vnode_id}: ' --log-level 5");
	    push(@rules, "-A $OUT_CHAIN -j LOG ".
	     "  --log-prefix 'OUT ${vnode_id}: ' --log-level 5");
	}
    }

    # Add some global rules (i.e. that cannot simply be flushed by
    # flushing one of the input/output chains for this vnode); and save
    # them for later deletion so we don't have to reconstruct them
    # later!
    my @grules = ();

    #
    # Finally, either allow direct ssh into the container (if it was
    # emulabized OR if user specifically requested direct ssh), or add
    # this port to our alternate sshd-docker-exec service (if not
    # emulabized or user requested ssh-attach).
    #
    if (exists($vnconfig->{'config'}->{'SSHDPORT'})) {
	my $attributes = $vnconfig->{'attributes'};
	my $emulabization = $attributes->{DOCKER_EMULABIZATION};
	my $ssh_style = $attributes->{DOCKER_SSH_STYLE};
	my $exec_shell = $attributes->{DOCKER_EXEC_SHELL};

	if (defined($exec_shell)) {
	    if ($exec_shell =~ /^([\/\w\d\-_]+)$/) {
		$exec_shell = $1;
	    }
	    else {
		warn("malformed shell: $exec_shell ; defaulting to /bin/sh");
		$exec_shell = '/bin/sh';
	    }
	}
	
	if (($emulabization ne DOCKER_EMULABIZE_NONE()
	     && (!defined($ssh_style) || $ssh_style eq ''
		 || $ssh_style eq 'direct'))
	    || (defined($ssh_style) && $ssh_style eq 'direct')) {
	    if (!isRoutable($ip)) {
		# Override the common/mkvnode.pl ssh portfw.  We want the
		# alt sshd port for this vnode to redirect from the public
		# host to port 22 on the inside, not to the alt port on the
		# inside, like mkvnode.pl assumes.  Ugh.
		push(@grules,
		     "-t nat -A PREROUTING -j DNAT -p tcp ".
		     "--dport $vnconfig->{config}->{SSHDPORT} -d $host_ip ".
		     "--to-destination $ip:22");
	    }
	    $private->{'ssh_style'} = 'direct';
	}
	else {
	    if (!defined($exec_shell)) {
		TBDebugTimeStamp("unspecified exec_shell: defaulting to /bin/sh");
		$exec_shell = '/bin/sh';
	    }

	    # Setup our docker exec via ssh.
	    addContainerToDockerExecSSH(
		$vnode_id,$vnconfig->{config}->{SSHDPORT},$exec_shell);
	    $private->{'ssh_style'} = 'exec';
	}
    }
    
    # Reroute tmcd calls to the proxy on the physical host
    push(@grules,
	 "-t nat -A PREROUTING -j DNAT -p tcp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $ip ".
	 "--to-destination $vip:$local_tmcd_port");

    push(@grules,
	 "-t nat -A PREROUTING -j DNAT -p udp ".
	 "--dport $TMCD_PORT -d $boss_ip -s $ip ".
	 "--to-destination $vip:$local_tmcd_port");

    # Reroute evproxy to use the local daemon.
    push(@grules,
	 "-t nat -A PREROUTING -j DNAT -p tcp ".
	 "--dport $EVPROXY_PORT -d $ops_ip -s $ip ".
	 "--to-destination $host_ip:$EVPROXY_PORT");

    push(@rules,@grules);

    my @deleterules = ();
    foreach my $rule (@grules) {
	if ($rule =~ /^(-t \w+\s+)?(-[AIR]\s+)([A-Za-z][-A-Za-z0-9]*)\s+(.+)$/) {
	    push(@deleterules,"$1 -D $3 $4");
	}
	elsif ($rule =~ /^(-t \w+\s+)?(-[IR]\s+)([A-Za-z][-A-Za-z0-9]*)\s+\d+\s+(.+)$/) {
	    push(@deleterules,"$1 -D $3 $4");
	}
    }
    $private->{'preboot_iptables_rules'} = \@deleterules;

    # Install the iptable rules
    TBDebugTimeStamp("vnodePreConfigControlNetwork: installing iptables rules");
    if (DoIPtables(@rules)) {
	TBDebugTimeStamp("  failed to install iptables rules");
	return -1;
    }
    TBDebugTimeStamp("  installed iptables rules");

    return 0;
}

#
# Since we already did the work of figuring out which exp networks this
# container is connected to above in rootPreConfigNetwork, the only
# thing we have to handle in this function is the runtime stuff of
# figuring what if any traffic shaping is necessary, and setting up
# those devices.
#
sub vnodePreConfigExpNetwork($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $ifs     = $vnconfig->{'ifconfig'};
    my $lds     = $vnconfig->{'ldconfig'};
    my $tunnels = $vnconfig->{'tunconfig'};

    #
    # Since network config with Docker is persistent, we add the
    # experiment net devices here, but have to check if any interfaces
    # have been modified, removed, or freshly added, and handle the
    # delta.
    #
    my $basetable;
    my $elabifs = "";
    my $elabroutes = "";
    my %netif_strs = ();
    foreach my $ifc (@$ifs) {
	# XXX
	#next if (!$ifc->{ISVIRT});

	TBDebugTimeStamp("vnodePreConfigExpNetwork: $vnode_id interface ".
			 Dumper($ifc))
	    if ($debug > 1);

	if (exists($ifc->{ISBLOCKSTORELINK}) && $ifc->{ISBLOCKSTORELINK}) {
	    TBDebugTimeStamp("vnodePreConfigExpNetwork: $vnode_id skipping blockstore interface!")
		if ($debug > 1);
	    next;
	}

	my $br       = $ifc->{"BRIDGE"};
	my $physdev  = $ifc->{"PHYSDEV"};
	my $ldinfo;

	#
	# Find associated delay info
	#
	foreach my $ld (@$lds) {
	    if ($ld->{"IFACE"} eq $ifc->{"MAC"}) {
		$ldinfo = $ld;
	    }
	}

	#
	# All the "hard" work (of creating bridges (or dummy devices for
	# macvlan support), and docker networks) was done in
	# rootPreConfigNetwork above.  So all we have to do here is add this
	# device and its configuration to the docker container we created 
	#
	my $nfmac = $ifc->{MAC};
	my $fmac = fixupMac($nfmac);
	my ($ip,$mask) = ($ifc->{IPADDR},$ifc->{IPMASK});
	my $network = inet_ntoa(inet_aton($ip) & inet_aton($mask));
	my $maskbits = 0;
	foreach my $octet (split(/\./,$mask)) {
	    my $cval = int($octet);
	    for (my $i = 0; $i < 8; ++$i) {
		$maskbits += $cval & 1;
		$cval = $cval >> 1;
	    }
	}

	#
	# Before anything else, we add a network interface to the
	# container for this exp net iface.  (We have to do this with
	# raw docker API access because as of 1.12.x, the docker CLI did
	# not support fixing a MAC address via 'docker network connect
	# ...'.)  Anyway, first we must find the docker network ID.
	#
	TBDebugTimeStamp("connecting docker container $vnode_id to".
			 " network ".$ifc->{BRIDGE});
	my ($code,$content,$resp) = getClient()->network_connect_container(
	    $ifc->{BRIDGE},$vnode_id,$ip,$maskbits,$fmac);
	if ($code) {
	    fatal("Could not connect $vnode_id to $ifc->{BRIDGE}".
		  " ($code,$content); aborting!");
	}
    }

    return 0;
}

sub vnodeConfigResources($$$$){
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $attributes = $vnconfig->{'attributes'};
    my $memory;

    return 0;
}

sub vnodeConfigDevices($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $vninfo = $private;

    return 0;
}

sub vnodeState($;$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    my $err = 0;
    my $out = VNODE_STATUS_UNKNOWN();

    TBDebugTimeStamp("getting state info for docker container $vnode_id");
    my ($code,$content) = getClient()->container_inspect($vnode_id);
    if ($code) {
	print STDERR "vnodeState: could not inspect container: $content ($code)!";
	return ($code, $out);
    }

    my $json = $content;
    my $jstate = $json->[0]->{'State'};

    if ($jstate->{"Running"} == JSON::PP::true) {
	$out = VNODE_STATUS_RUNNING();
    }
    elsif ($jstate->{"Restarting"} == JSON::PP::true) {
	$out = VNODE_STATUS_BOOTING();
    }
    elsif ($jstate->{"Paused"} == JSON::PP::true) {
	$out = VNODE_STATUS_PAUSED();
    }
    elsif ($jstate->{"Dead"} == JSON::PP::true) {
	$out = VNODE_STATUS_STOPPED();
    }
    elsif ($jstate->{"Status"} eq "exited"
	   || $jstate->{"Status"} eq "stopped") {
	$out = VNODE_STATUS_STOPPED();
    }
    else {
	# Else, it must be stopped!
	$out = VNODE_STATUS_STOPPED();
    }
    return ($err, $out);
}

sub vnodeBootHook($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $vninfo = $private;

    #
    # If the image is not emulabized, it cannot be expected to send
    # status, so we do it.
    #
    if ($private->{'emulabization'} eq DOCKER_EMULABIZE_NONE()) {
	libutil::setState("TBSETUP");
    }

    if (AreProxiesRunning($vnode_id,$vmid) != 1) {
	RunProxies($vnode_id,$vmid);
    }

    #
    # Start up our Docker-to-pty script for this container; the capture
    # will attach to it.  We always fire this off here; it cannot
    # survive when the container reboots or shuts down.
    #
    my $PTYLINKFILE = "$VMDIR/$vnode_id/vnode.pty";
    if (-e $PTYLINKFILE) {
	unlink($PTYLINKFILE);
    }
    TBDebugTimeStamp("vnodeBootHook: starting container2pty;".
		     " symlink $PTYLINKFILE");
    mysystem("$C2P $vnode_id $PTYLINKFILE &");
    # Wait 5 seconds to ensure $PTYLINKFILE appears...
    my $tries = 10;
    while (! -e $PTYLINKFILE && $tries > 0) {
	sleep(1);
	$tries -= 1;
	TBDebugTimeStamp("vnodeBootHook: waiting for $PTYLINKFILE...");
    }

    #
    # Start a capture if there isn't one running.
    #
    if (-x "$CAPTURE") {
	my $rpid = captureRunning($vnode_id);
	if ($rpid == 0) {
	    captureStart($vnode_id,$PTYLINKFILE);
	}
    }

    #
    # This function is not yet part of the libvnode API, but our
    # vnodeBoot and vnodeReboot functions call it.
    #
    # XXX: mkvnode.pl probably needs to call it when it notices a reboot
    # (i.e., reboot within the container, or a docker restart).
    #

    #
    # After boot or reboot, save off its network namespace (also removes
    # an old namespace from a previous boot).  This is very important
    # because we want to move our own network devices into the namespace
    # (which docker doesn't allow us to do), and if we move a device in,
    # we have to remove it before we lose a handle to the namespace.
    #
    bindNetNS($vnode_id,$private);

    #
    # First, install our runtime iptables rules (those that depend on
    # the veth, like antispoofing).
    #
    InsertPostBootIptablesRules($vnode_id,$vmid,$vnconfig,$private);

    #
    # Run the routing scripts we built earlier.
    #
    RunRoutingScripts($vnode_id,1);

    #
    # Run the shaping scripts we built earlier.
    #
    RunShapingScripts($vnode_id,1);

    #
    # If the image is not emulabized, it cannot be expected to send
    # status, so we do it.
    #
    if ($private->{'emulabization'} eq DOCKER_EMULABIZE_NONE()) {
	libutil::setState("ISUP");
    }

    return 0;
}

sub vnodeBoot($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $vninfo = $private;
 
    # notify stated that we are about to boot. We need this transition for
    # stated to do its thing, this state name is treated specially.
    libutil::setState("BOOTING");

    RunProxies($vnode_id,$vmid);

    TBDebugTimeStamp("Starting vnode $vnode_id...");
    my ($code,$content) = getClient()->container_start($vnode_id);
    if ($code) {
	print STDERR "container_start $vnode_id failed: $content ($code)\n";
	return -1;
    }

    #
    # We cannot wait until we can ping the node.  We must immediately
    # kick off our hooks so that container processes never send any
    # packets prior to their installation.  If this is too racy, we'll
    # have to launch the container's init process a bit more carefully
    # to coordinate this inside/outside dance.
    #
    TBDebugTimeStamp("Created container $vnode_id");
    vnodeBootHook($vnode_id,$vmid,$vnconfig,$private);
    
    #
    # XXX originally we had "-t 5", but -t is not a timeout
    # in Linux ping. So there was no timeout which resulted
    # in sending all 5 pings at 1 second intervals and then
    # waiting for the last one to not respond, a total of
    # 6 seconds. So this loop of 10 tries took about 60 seconds.
    #
    # If we fix the option ("-w 5"), we still don't timeout after
    # 5 seconds since in linux, we get a network error after 3
    # seconds if the node is down. So ironically, we were closer
    # to out timeout value with the wrong option!
    #
    # The worst part is in the common case where the node is
    # up and responding: we wind up waiting a little over 4
    # seconds til we get a response from 5 pings.
    #
    # So lets try fewer pings (1) so the successful case returns
    # immediately, and account for the 3 second node down timeout
    # by increasing the countdown to match the original ~60 seconds
    # before giving up.
    #
    my $ip = $vnconfig->{"config"}{CTRLIP};
    my $countdown = 8;
    while ($countdown > 0) {
	TBDebugTimeStamp("Pinging $ip for up to five seconds ...");
	system("ping -q -c 1 -w 5 $ip > /dev/null 2>&1");
	# Ping returns zero if any packets received.
	if (! $?) {
	    TBDebugTimeStamp("Container $vnode_id is up");
	    return 0;
	}
	$countdown--;
	last
	    if (checkForInterrupt());
    }

    #
    # Tear it down and try again. Use vnodeHalt cause it protects
    # itself with an alarm.
    #
    TBDebugTimeStamp("Container did not start, stopping for retry ...");
    vnodeHalt($vnode_id, $vmid, $vnconfig, $private);
    TBDebugTimeStamp("Container halted, waiting for it to stop ...");
    $countdown = 10;
    while ($countdown >= 0) {
	sleep(5);
	last
	    if (vnodeState($vnode_id,$vmid,$vnconfig,$private)
		eq VNODE_STATUS_STOPPED());
	$countdown--;
	TBDebugTimeStamp("Container not stopped yet");
    }
    TBDebugTimeStamp("Container is stopped ($countdown)!");
    last
	if (checkForInterrupt());

    return -1;
}

#
# Connects to the Docker events daemon to listen to events for this
# container.  We have two paths to get here.  First, if mkvnode.pl is
# signaled from our code, it might stop/restart/kill the vnode.  Second,
# if the user runs a docker command (i.e. docker stop/restart/start), we
# want to be able to fire up our monitor again, and most importantly to
# re-run our boot hooks.
#
# For the second case, a 'docker restart' will result in
# kill,kill,die,stop,start,restart container events.  A 'docker stop'
# results in kill,kill,die,stop events.  For restart, We may not catch
# container death via sleep poll, of course -- but we still have to
# apply our runtime boot hooks (like moving devices into the container,
# applying traffic shaping, etc) -- and docker doesn't help us with
# runtime hooks.  So we need to catch the restart event and run teardown
# and boot hooks.  Problem is in this case, we don't actually know until
# the final restart event if this is a restart!  How goofy.  So either
# we wait in mkvnode.pl (vnodePoll) and see if it comes back, then run
# the boot hook; or we just always exit from mkvnode.pl, and have a
# central monitor daemon that looks for container start/stop events and
# fires off a mkvnode.pl monitor to run the boot hook.  Probably the
# latter is most flexible, but maybe also wasted cycles or
# higher-latency... hard to know.
#

sub vnodePoll($$$$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private, $statusref, $eventref) = @_;

  reconnect:
    if (!exists($private->{DOCKER_EVENT_FD})
	|| !defined($private->{DOCKER_EVENT_FD})
	|| !$private->{DOCKER_EVENT_FD}->opened()) {
	TBDebugTimeStamp("connecting to docker event stream for $vnode_id");
	my $ccmd = "$CURL -sN --unix-socket /var/run/docker.sock".
	    " -H \"Content-Type: application/json\"".
	    " --data-urlencode 'filters=\{\"type\":\[\"container\"\],".
	    "                             \"container\":\[\"${vnode_id}\"\]\}'".
	    ' -G http:/events?filters={"type":["container"],"container":["'.$vnode_id.'"]}';
	pipe($private->{DOCKER_EVENT_FD},WRITER)
	    or fatal("popen docker event stream $vnode_id: $@");
	my $pid = fork();
	if (!$pid) {
	    close(STDIN);
	    open(STDOUT,">&WRITER");
	    close($private->{DOCKER_EVENT_FD});
	    if (0) {
		exec($ccmd);
	    }
	    else {
		# This just prints JSON events to STDOUT by default,
		# which is exactly what we want.
		getClient()->monitor_events(
		    {"type"=>["container"],"container"=>["$vnode_id"]});
	    }
	    exit(-1);
	}
	# Parent continues.
	close(WRITER);
	$private->{DOCKER_EVENT_CHILD} = $pid;
	$private->{DOCKER_EVENT_FD}->autoflush(1);
	my $oldfh = select($private->{DOCKER_EVENT_FD});
	$| = 1;
	select($oldfh);

	# We save off the last N events for an existing connection.  If the
	# connection drops, we dump the list.
	$private->{DOCKER_EVENT_HISTORY} = [];
    }

    #my $comp = Array::Compare->new();
    my $buf = '';
    while (1) {
	my $rc;
	my $sel = IO::Select->new($private->{DOCKER_EVENT_FD});
	my @ready = $sel->can_read(2);
	if ($?) {
	    TBDebugTimeStamp("error in select: $!");
	    if (!$private->{DOCKER_EVENT_FD}->opened()) {
		TBDebugTimeStamp("lost docker event stream connection;".
				 " reconnecting...");
		delete($private->{DOCKER_EVENT_FD});
		kill('KILL',$private->{DOCKER_EVENT_CHILD});
		delete($private->{DOCKER_EVENT_CHILD});
		goto reconnect;
	    }
	}
	if (!@ready) {
	    #TBDebugTimeStamp("nothing to read, continuing...");
	    next;
	}

	$rc = sysread($private->{DOCKER_EVENT_FD},$buf,4096,length($buf));
	if (!defined($rc)) {
	    warn("sysread on event stream failed; aborting poll loop!");
	    return libgenvnode::VNODE_POLL_ERROR();
	}
	while (1) {
	    my $pos = index($buf,"\n");
	    if ($pos < 0) {
		last;
	    }
	    my $line = substr($buf,0,$pos+1);
	    chomp($line);
	    $buf = substr($buf,$pos+1);
	    my $json = decode_json($line);
	    if (!exists($json->{"Type"}) || $json->{"Type"} ne "container"
		|| !exists($json->{"Actor"}{"Attributes"}{"name"})
		|| $json->{"Actor"}{"Attributes"}{"name"} ne $vnode_id) {
		TBDebugTimeStamp("event $line not for us; ignoring!");
		next;
	    }
	    if (!exists($json->{"status"})) {
		# We only want status change events.
		next;
	    }
	    
	    TBDebugTimeStamp("$vnode_id status: $json->{status}".
			     " ($json->{time}.$json->{timeNano}");

	    #
	    # NB: when we make library calls below, we block signals
	    # temporarily so that the whole thing finishes.
	    # vnodesetup/mkvnode keep trying :).
	    #
	    
	    my $status = $json->{"status"};
	    if ($status eq 'die') {
		TBDebugTimeStamp("$vnode_id died; tearing down");
		
		$rc = RunWithSignalsBlocked(\&vnodeTearDown,
					$vnode_id,$vmid,$vnconfig,$private);
		if ($rc) {
		    warn("vnodeTearDown failed; aborting poll loop with error!");
		    return libgenvnode::VNODE_POLL_ERROR();
		}
	    }
	    elsif ($status eq 'start') {
		TBDebugTimeStamp("$vnode_id started; running boot hooks");
		$rc = RunWithSignalsBlocked(\&vnodeBootHook,
					$vnode_id,$vmid,$vnconfig,$private);
		if ($rc) {
		    warn("vnodeBootHook failed; aborting poll loop with error!");
		    return libgenvnode::VNODE_POLL_ERROR();
		}
	    }
	}
    }

}

sub vnodePollCleanup($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    if (exists($private->{DOCKER_EVENT_FD})) {
	kill('KILL',$private->{DOCKER_EVENT_CHILD});
	if ($private->{DOCKER_EVENT_FD}->opened()) {
	    close($private->{DOCKER_EVENT_FD});
	}
	delete($private->{DOCKER_EVENT_CHILD});
	delete($private->{DOCKER_EVENT_FD});
    }
    if (exists($private->{DOCKER_EVENT_HISTORY})) {
	delete($private->{DOCKER_EVENT_HISTORY});
    }
    
    return 0;
}

sub vnodePostConfig($)
{
    return 0;
}

sub rootPostConfig($)
{
    return 0;
}

sub vnodeReboot($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    TBDebugTimeStamp("restarting vnode $vnode_id...");
    my ($code,$content) = getClient()->container_restart($vnode_id);
    if ($code) {
	warn("container_restart($vnode_id) failed: $content ($code)\n");
	return $code;
    }

    return vnodeBootHook($vnode_id, $vmid, $vnconfig, $private);
}

sub vnodeHalt($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    TBDebugTimeStamp("Stopping vnode $vnode_id...");
    my ($code,$content) = getClient()->container_stop($vnode_id);
    if ($code) {
	warn("container_stop($vnode_id) failed: $content ($code)\n");
	return $code;
    }

    return 0;
}

sub vnodeExec($$$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private, $command) = @_;

    TBDebugTimeStamp("Running command '$command' inside vnode $vnode_id...");
    my ($code,$content) = getClient()->container_exec($vnode_id,$command);
    if ($code) {
	warn("container_exec($vnode_id) failed: $content ($code)\n");
	return $code;
    }

    if (wantarray) {
	return ($code,$content);
    }
    else {
	return $code;
    }
}

#
# Docker doesn't support mount/unmount.
#
sub vnodeUnmount($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    return undef;
}

#
# Remove the transient state, but not the disk.  Basically, remove
# anything that happened in vnodeBoot and vnodeBootHook.
#
# NB: this function does not currently lock, since it doesn't do
# anything serious.  Be careful!
#
sub vnodeTearDown($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;

    KillProxies($vnode_id,$vmid);
    RemovePostBootIptablesRules($vnode_id,$vmid,$vnconfig,$private);
    
    #
    # Unwind anything we did in vnodeBootHook.
    #
    unbindNetNS($vnode_id,$private);

    return 0;
}

sub vnodeDestroy($$$$)
{
    my ($vnode_id, $vmid, $vnconfig, $private) = @_;
    my $vninfo = $private;

    # Always do this.
    return -1
	if (vnodeTearDown($vnode_id, $vmid, $vnconfig, $private));

    TBDebugTimeStamp("Removing vnode $vnode_id docker container...");
    my ($code,$content) = getClient()->container_delete($vnode_id);
    if ($code) {
	print STDERR "container_delete $vnode_id failed: $content ($code)\n";
    }

    #
    # NB: only lock after we do vnodeTearDown and container_delete.  We
    # cannot have the global lock while destroying the vnode in Docker;
    # that could take longer.
    #
    TBDebugTimeStamp("vnodeDestroy: grabbing global lock $GLOBAL_CONF_LOCK")
	if ($lockdebug);
    if (TBScriptLock($GLOBAL_CONF_LOCK, 0, 1200) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the global lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got global lock")
	if ($lockdebug);

    if (exists($private->{'blockstores'})) {
	TBDebugTimeStamp("starting rc.storage")
	    if ($debug > 1);
	if (mysystem2("/usr/local/etc/emulab/rc/rc.storage -j $vnode_id fullreset")) {
	    fatal("Failed to remove storage in rc.storage; aborting!");
	}
	TBDebugTimeStamp("rc.storage finished successfully")
	    if ($debug > 1);
    }

    #
    # Remove mounts.
    #
    removeMounts($vnode_id);

    #
    # Remove any global iptables rules (i.e., in chains other than our
    # per-vnode special input/output chains).
    #
    if (exists($private->{'preboot_iptables_rules'})
	&& @{$private->{'preboot_iptables_rules'}}) {
	DoIPtables(@{$private->{'preboot_iptables_rules'}});
	delete($private->{'preboot_iptables_rules'});
    }

    #
    # If user wanted 'exec' ssh_style, remove this vnode from the
    # private sshd.
    #
    if (exists($private->{'ssh_style'}) && $private->{'ssh_style'} eq 'exec') {
	delete($private->{'ssh_style'});
	removeContainerFromDockerExecSSH($vnode_id);
    }

    #
    # Shutdown the capture now that it is gone. We leave the log around
    # til next time this vnode comes back.
    #
    if (-x "$CAPTURE") {
	my $LOGPATH = "$VMDIR/$vnode_id";
	my $pidfile = "$LOGPATH/$vnode_id.pid";
	my $pid = 0;

	if (-r "$pidfile" && open(PID, "<$pidfile")) {
	    my $pid = <PID>;
	    close(PID);
	    chomp($pid);
	    if ($pid =~ /^(\d+)$/ && $1 > 1) {
		$pid = $1;
	    } else {
		print STDERR "WARNING: bogus pid in capture pidfile ($pid)\n";
		$pid = 0;
	    }
	}

	# XXX sanity: make sure pidfile matches reality
	my $rpid = captureRunning($vnode_id);
	if ($rpid == 0) {
	    print STDERR "WARNING: capture not running";
	    if ($pid > 0) {
		print STDERR ", should have been pid $pid";
		$pid = 0;
	    }
	    print STDERR "\n";
	} elsif ($pid != $rpid) {
	    if ($pid == 0) {
		print STDERR "WARNING: no recorded capture pid, ".
		    "but found process ($rpid)\n";
	    } else {
		print STDERR "WARNING: recorded capture pid ($pid) ".
		    "does not match actual pid ($rpid)\n";
	    }
	    $pid = $rpid;
	}

	if ($pid > 0) {
	    kill("TERM", $pid);
	}
    }

    # Kill the chains.
    # Ick, iptables has a 28 character limit on chain names. But we have to
    # be backwards compatible with existing chain names. See corresponding
    # code in emulab-cnet.pl
    my $IN_CHAIN = "IN_${vnode_id}";
    my $OUT_CHAIN = "OUT_${vnode_id}";
    if (length($IN_CHAIN) > 28) {
	$IN_CHAIN = "I_${vnode_id}";
	$OUT_CHAIN = "O_${vnode_id}";
    }
    DoIPtables("-F $IN_CHAIN");
    DoIPtables("-X $IN_CHAIN");
    DoIPtables("-F $OUT_CHAIN");
    DoIPtables("-X $OUT_CHAIN");

    #
    # Unwind anything we did. 
    #
    
    # Remove any Docker networks we would have used that are unused.
    if (exists($private->{'dockernets'})) {
	foreach my $name (keys(%{ $private->{'dockernets'} })) {
	    my @members = getDockerNetMemberIds($name);
	    if (@members == 0) {
		TBDebugTimeStamp("Deleting empty docker network $name...");
		($code) = getClient()->network_delete($name);
		if (!$code) {
		    delete($private->{'dockernets'}->{$name});
		    #
		    # Also, if this is our Docker and we have iptables
		    # enabled, we need to remove the default-allow rule
		    # for all traffic within the network.
		    #
		    if ($ISOURDOCKER) {
			DoIPtablesNoFail("-D FORWARD -i $name -o $name -j ACCEPT");
		    }
		}
	    }
	}
    }
    # Delete bridges we would have used that are unused.  If only the
    # physdevices we added to the bridge are in the bridge, remove them,
    # then remove the bridge.
    if (exists($private->{'physbridges'})) {
	foreach my $brname (keys(%{ $private->{'physbridges'} })) {
	    my @ifaces = getBridgeIfaces($brname);
	    if (@ifaces == 0) {
		TBDebugTimeStamp("removing unused $brname");
		if (-e "/sys/class/net/$brname") {
		    mysystem2("$IFCONFIG $brname down");
		    delbr($brname);
		}
		if (!$?) {
		    delete($private->{'physbridges'}->{$brname});
		    delete($private->{'physbridgeifaces'}->{$brname});
		}
	    }
	    elsif (exists($private->{'physbridgeifaces'}->{$brname})) {
		#
		# Check for anything other than the physbridgeifaces we
		# would have added to this bridge; if only those are in
		# the bridge, remove them, then remove the bridge.
		#
		my %ifm = ();
		foreach my $ifc (@ifaces) {
		    $ifm{$ifc} = 1;
		}

		foreach my $physiface (keys(%{$private->{'physbridgeifaces'}->{$brname}})) {
		    delete($ifm{$physiface})
			if (exists($ifm{$physiface}));
		}

		# If only the physifaces were left in the bridge, nuke
		# them all, then dump the bridge.
		if (keys(%ifm) == 0) {
		    foreach my $ifc (@ifaces) {
			TBDebugTimeStamp("removing $ifc from unused $brname");
			delbrif($brname,$ifc);
			delete($private->{'physbridgeifaces'}->{$brname}->{$ifc});
		    }

		    TBDebugTimeStamp("removing unused $brname");
		    if (-e "/sys/class/net/$brname") {
			mysystem2("$IFCONFIG $brname down");
			delbr($brname);
		    }
		    if (!$?) {
			delete($private->{'physbridges'}->{$brname});
			delete($private->{'physbridgeifaces'}->{$brname});
		    }
		}
	    }
	}
    }
    # Delete the dummy macvlan thingies we would have used, if no
    # one else is using them.
    if (exists($private->{'dummys'})) {
	foreach my $brname (keys(%{ $private->{'dummys'} })) {
	    my @mvs = getMacvlanIfaces($private->{'dummys'}->{$brname});
	    if (@mvs == 0) {
		mysystem2("$IP link del dev $brname");
		delete($private->{'dummys'}->{$brname})
		    if ($?);
	    }
	}
    }
    # Delete any vlan devices we would have used, if no one else is
    # using them (i.e. if they are not in a bridge, and are not a parent
    # of any other macvlan devices).
    if (exists($private->{'vlandevs'})) {
	foreach my $brname (keys(%{ $private->{'vlandevs'} })) {
	    my $viface = $private->{'vlandevs'}->{$brname};
	    next
		if (!defined($viface));
	    my $brv = getBridgeForIface($viface);
	    my @mvs = getMacvlanIfaces($viface);
	    if (!defined($brv) && @mvs == 0) {
		mysystem2("$IP link del dev $viface");
		delete($private->{'vlandevs'}->{$brname})
		    if ($?);
	    }
	}
    }

    # This shouldn't matter, but let's be complete; we might've deleted
    # some bridges and interfaces.
    refreshLibVnodeNetCache();

    #
    # We keep the IFBs until complete destruction. We do this cause we do
    # want to get into a situation where we stopped a container to do
    # something like take a disk snapshot, and then not be able to
    # restart it cause there are no more resources available (as might
    # happen on a shared node).
    #
    ReleaseIFBs($vmid, $private)
	if (exists($private->{'ifbs'}));

    TBDebugTimeStamp("  releasing global lock")
	if ($lockdebug);
    TBScriptUnlock();

    return 0;
}

##
## Utility and helper functions.
##

sub analyzeImageWithBusyboxCommand($$$@)
{
    my ($image,$configref,$outputref,@bargv) = @_;

    TBDebugTimeStamp("running static busybox (".join('',@bargv).")".
		     " for image $image...");
    my $args = {
	'HostConfig' => {
	    'Binds' => [ "/bin/busybox:/tmp/busybox:ro" ]
	},
	'Entrypoint' => '',
    };
    my @argv = ('/tmp/busybox',@bargv);
    if (defined($configref)) {
	require Hash::Merge;
	$args = Hash::Merge::merge($args,$configref);
	if ($debug) {
	    print STDERR "DEBUG: merged args = ".Dumper($args)."\n";
	}
    }
    my $tmpname = "busybox-analyzer-".int(rand(POSIX::INT_MAX));
    our $buf = '';
    my ($code,$json,$resp,$retval) = getClient->container_run(
	$tmpname,$image,\@argv,1,$args,sub { $buf .= $_[0]; });
    if ($code) {
	warn("failed to run busybox analysis container $tmpname for $image");
	return $code;
    }
    # Santize the output.  For whatever reason(s), under heavy load, it
    # comes with non-printable chars occasionally, and with CRLF.  Odd.
    $buf =~ s/[\000-\011\014\015-\037\176-\255]//g;

    TBDebugTimeStamp("busybox analyze output:\n$buf");
    open(FD,">/vms/contexts/$tmpname.log");
    print FD $buf;
    close(FD);

    if (defined($outputref)) {
	if (ref($outputref) eq 'ARRAY') {
	    @$outputref = split("\n",$buf);
	}
	else {
	    $outputref = $buf;
	}
    }

    return 0;
}

#
# Analyze an existing Docker image to extra image metadata,
# distro/version, and so on.
#
sub analyzeImage($$;$)
{
    my ($image,$rethash,$force) = @_;
    my $output;
    my @outlines;
    my ($code,$json,$resp,$retval);
    my $iid;
    if (!defined($force)) {
	$force = 0;
    }

    TBDebugTimeStamp("analyzing image $image...");

    TBDebugTimeStamp("inspecting image $image...");
    ($code,$json) = getClient()->image_inspect($image);

    if ($code) {
	warn("inspect $image failed -- attempting to continue anyway!");
    }
    else {
	my $jstate;
	if (ref($json) eq 'ARRAY') {
	    $jstate = $json->[0];
	}
	else {
	    $jstate = $json;
	}
	$iid = $jstate->{'Id'};
	$jstate = $jstate->{'Config'};

	if (exists($jstate->{'Cmd'})) {
	    $rethash->{DOCKER_CMD} = $jstate->{'Cmd'};
	}
	if (exists($jstate->{'Entrypoint'})) {
	    $rethash->{DOCKER_ENTRYPOINT} = $jstate->{'Entrypoint'};
	}
	if (exists($jstate->{'Env'})) {
	    $rethash->{DOCKER_ENV} = $jstate->{'Env'};
	}
	if (exists($jstate->{'WorkingDir'})) {
	    $rethash->{DOCKER_WORKINGDIR} = $jstate->{'WorkingDir'};
	}
	if (exists($jstate->{'ArgsEscaped'})) {
	    $rethash->{DOCKER_ARGSESCAPED} = int($jstate->{'ArgsEscaped'});
	}
	if (exists($jstate->{'Architecture'})) {
	    $rethash->{DOCKER_ARCH} = $jstate->{'Architecture'};
	}
	if (exists($jstate->{'User'})) {
	    $rethash->{DOCKER_USER} = $jstate->{'User'};
	}
    }
    my $needunlock = 0;
    if (defined($iid)) {
	if (! -f "/vms/contexts/analyze-$iid") {
	    if (TBScriptLock("analyze-$iid",
			     TBSCRIPTLOCK_INTERRUPTIBLE(),
			     1800) != TBSCRIPTLOCK_OKAY()) {
		fatal("Could not get analyze-$iid lock for $image analysis!");
	    }
	    TBDebugTimeStamp("  got image analysis lock analyze-$iid for $image")
		if ($lockdebug);
	    $needunlock = 1;
	}
	if (-f "/vms/contexts/analyze-$iid" && !$force) {
	    TBDebugTimeStamp("not running analysis script for image $image;".
		" already in /vms/contexts/analyze-$iid\n");
	    open(FD,"/vms/contexts/analyze-$iid");
	    @outlines = <FD>;
	    close(FD);
	    goto outlines;
	}
    }

    TBDebugTimeStamp("running analysis script for image $image...");
    my $args = {
	'HostConfig' => {
	    'Binds' => [ "/etc/emulab/docker/container-utils:/tmp/docker:ro" ]
	},
	'Entrypoint' => '',
	'User' => 'root',
    };
    my $tmpname = "analyzer-".int(rand(POSIX::INT_MAX));
    our $buf = '';
    ($code,$json,$resp,$retval) = getClient->container_run(
	$tmpname,$image,['/tmp/docker/analyze.sh'],1,$args,
	sub { $buf .= $_[0]; });
    if ($code) {
	warn("failed to run analysis script container $tmpname for $image");
	TBScriptUnlock()
	    if ($needunlock);
	return $code;
    }
    # Santize the output.  For whatever reason(s), under heavy load, it
    # comes with non-printable chars occasionally, and with CRLF.  Odd.
    #$buf =~ s/[^[:ascii:]]//g;
    #$buf =~ s/\r\n//g;
    $buf =~ s/[\000-\011\014\015-\037\176-\255]//g;

    TBDebugTimeStamp("analyze.sh output:\n$buf");
    open(FD,">/vms/contexts/analyze-$iid");
    print FD $buf;
    close(FD);
    @outlines = split("\n",$buf);

  outlines:
    TBScriptUnlock()
      if ($needunlock);
    for my $res (@outlines) {
	if ($res =~ /^[a-zA-Z0-9_]*=[^=]*$/) {
	    chomp($res);
	    my ($key,$value,) = split('=',$res);
	    $rethash->{$key} = $value;
	}
    }
    return 0;
}

sub buildImageFromDockerfile($$)
{
    my ($image,$dockerfile) = @_;

    #
    # We have to lock here, to avoid races.
    #
    my $imagelockname = ImageLockName($image);
    TBDebugTimeStamp("grabbing image lock $imagelockname writeable")
	if ($lockdebug);
    if (TBScriptLock($imagelockname,
		     TBSCRIPTLOCK_INTERRUPTIBLE(),
		     $MAXIMAGEWAIT) != TBSCRIPTLOCK_OKAY()) {
	fatal("Could not get $imagelockname lock for $image!");
    }
    TBDebugTimeStamp("  got image lock $imagelockname for $image")
	if ($lockdebug);

    TBDebugTimeStamp("inspecting image $image (dockerfile $dockerfile)...");
    my ($code,$content) = getClient()->image_inspect($image);
    if (!$code) {
	TBScriptUnlock();
	TBDebugTimeStamp("not rebuilding existing $image for $dockerfile");
	return 0;
    }

    TBDebugTimeStamp("$image does not exist; building!");
    my $cdir = "$CONTEXTDIR/$image";
    mkdir($cdir);

    if (!LWP::Simple::getstore($dockerfile,"$cdir/Dockerfile")) {
	TBScriptUnlock();
	warn("failed to download dockerfile $dockerfile to build $image");
	return -1;
    }

    # We could just send the bytes to the daemon (tar -C $cdir -c . |),
    # but we want to store the file on disk for provenance.
    my $tarfile = "$cdir-context-" . time() . ".tar";
    mysystem2("tar -cf $tarfile -C $cdir .");
    if ($?) {
	warn("failed to build tar archive of context dir $cdir; aborting!\n");
	TBScriptUnlock();
	return -1;
    }
    TBDebugTimeStamp("building new image $image");
    my $buf = '';
    open(our $fd,">$cdir-build.log");
    our $bytes = 0;
    sub bdf_json_log_printer {
	my ($data,$foo,$resp) = @_;
	if ($resp->header("content-type") eq 'application/json') {
	    eval {
		$data = decode_json($data);
	    };
	    if ($@) {
		warn("build log_printer: $! $@ ($data)\n");
	    }
	}
	print $data;
	print $fd $data;
	$bytes += length($data);
    }
    ($code,$content) = getClient()->image_build_from_tar_file(
	$tarfile,$image,undef,undef,\&bdf_json_log_printer);
    close($fd);
    if ($code) {
	warn("failed to build $image from $dockerfile: $content ($code)!");
	TBScriptUnlock();
	return -1;
    }
    if ($bytes == 0) {
	open(FD,">$cdir-build.log");
	if (defined($content) && ref($content) eq 'ARRAY'
	    && defined($content->[0]) && ref($content->[0]) eq 'HASH'
	    && defined($content->[0]->{'stream'})) {
	    foreach my $bit (@$content) {
		next
		    if (!defined($bit->{'stream'}));
		print FD $bit->{'stream'};
	    }
	}
	elsif (defined(ref($content)) && ref($content) ne '') {
	    print FD Dumper($content);
	}
	else {
	    print FD $content;
	}
	close(FD);
    }

    TBDebugTimeStamp("finished building new image $image from $dockerfile");

    TBScriptUnlock();
    return 0;
}

sub pullImage($$$$;$)
{
    my ($image,$user,$pass,$policy,$newref) = @_;
    my ($code,$content);

    if (SHAREDHOST()) {
	if (defined($policy) && $policy ne DOCKER_PULLPOLICY_LATEST()) {
	    warn("forcing pull policy for image $image on sharedhost to".
		 " latest, instead of cached!\n");
	    $policy = DOCKER_PULLPOLICY_LATEST();
	}
	elsif (!defined($policy) || $policy eq '') {
	    $policy = DOCKER_PULLPOLICY_LATEST();
	}
    }
    elsif (!defined($policy) || $policy eq '') {
	$policy = DOCKER_PULLPOLICY_CACHED();
    }

    if ($policy eq DOCKER_PULLPOLICY_CACHED()) {
	TBDebugTimeStamp("inspecting image $image...");
	($code,$content) = getClient()->image_inspect($image);
	if (!$code) {
	    return 0;
	}
    }

    #
    # We need to lock while messing with the image. But we can use
    # shared lock so that others can proceed in parallel. We will have
    # to promote to an exclusive lock if the image has to be changed.
    #
    my $imagelockname = ImageLockName($image);
    TBDebugTimeStamp("grabbing image lock $imagelockname shared")
	if ($lockdebug);
    if (TBScriptLock($imagelockname,
		     TBSCRIPTLOCK_INTERRUPTIBLE()|TBSCRIPTLOCK_SHAREDLOCK(),
		     $MAXIMAGEWAIT) != TBSCRIPTLOCK_OKAY()) {
	fatal("Could not get $imagelockname lock for $image!");
    }
    TBDebugTimeStamp("  got image lock $imagelockname for $image")
	if ($lockdebug);

    #
    # Try one more time to inspect, and release the lock if we have it.
    #
    if ($policy eq DOCKER_PULLPOLICY_CACHED()) {
	TBDebugTimeStamp("inspecting image $image...");
	($code,$content) = getClient()->image_inspect($image);
	if (!$code) {
	    TBDebugTimeStamp("  releasing image lock")
		if ($lockdebug);
	    TBScriptUnlock();
	    return 0;
	}
    }

    my $output = "";
    my $retries = 10;
    my $ret = 1;
    while ($ret && $retries > 0) {
	TBDebugTimeStamp("pulling image $image...");
	($code,$content) = getClient()->image_pull($image,$user,$pass);
	if ($code == 0) {
	    TBDebugTimeStamp("pull $image succeeded");
	    last;
	}
	my $ustr = "";
	if (defined($user)) {
	    $ustr = " as user $user";
	}
	TBDebugTimeStamp("pull $image failed$ustr ($code, $content);" .
			 " sleeping and retrying...");
	sleep(8);
	$retries -= 1;
    }
    if ($code) {
	TBDebugTimeStamp("failed to pull image $image!");
    }
    if ($code == 0 && defined($newref) && ref($content) eq 'ARRAY') {
	for my $cc (@$content) {
	    next 
		if (!exists($cc->{'status'}));
	    if ($cc->{'status'} =~ /downloaded newer image/i) {
		$$newref = 1;
		last;
	    }
	}
    }

    TBDebugTimeStamp("  releasing image lock")
	if ($lockdebug);
    TBScriptUnlock();

    return $code;
}

sub emulabizeImage($;$$$$$$$$$)
{
    my ($image,$newimageref,$emulabization,$newzationref,$update,
	$pullpolicy,$username,$password,$dockerfile,$iattrsref) = @_;
    my $rc;
    my ($code,$content);

    #
    # We take a lock for the pull of the base image; and for
    # emulabization, if any.  To create an emulabized image, we pull the
    # underlying image (if any), then inspect it using both docker
    # inspect and our analyzer, then create a name based on the hash of
    # our attributes for this node that affect the image build (and on
    # the project/group) with the global lock held, then lock that
    # image, then make it!
    #

    my $havenewbase = 0;
    if (!defined($dockerfile)) {
	#
	# If we're supposed to pull a new image, do it.
	#
	if (pullImage($image,$username,$password,$pullpolicy,\$havenewbase)) {
	    warn("failed to pull base Docker image $image");
	    return -1;
	}
    }
    else {
	#
	# Otherwise, check for existence of base image, else, build it.
	#
	if (buildImageFromDockerfile($image,$dockerfile)) {
	    warn("failed to build $image from $dockerfile");
	    return -1;
	}
    }

    #
    # Analyze the image to see what we'll need to do it, if anything.  Note
    # that if we have a new base image, we force the analysis.
    #
    my %iattrs = ();
    $rc = analyzeImage($image,\%iattrs,$havenewbase);
    if ($rc) {
	warn("analysis of image $image failed; continuing as best we can!");
    }
    my ($dist,$tag,$mintag) =
	($iattrs{'DIST'},$iattrs{'TAG'},$iattrs{'MINTAG'});
    TBDebugTimeStamp("analyzed $image, attrs:\n".Dumper(%iattrs));
    if (defined($iattrsref)) {
	$$iattrsref = \%iattrs;
    }

    my $curzation = $iattrs{'EMULABIZATION'};
    if (!defined($curzation) || $curzation eq '') {
	$curzation = DOCKER_EMULABIZE_NONE();
    }

    #
    # If the emulabization level was not commanded, and if the base
    # image was emulabized, we will just use it.  If not, we will use
    # our default (DOCKER_EMULABIZE_DEFAULT).
    #
    if (!defined($emulabization)) {
	if ($curzation eq DOCKER_EMULABIZE_NONE()) {
	    $emulabization = DOCKER_EMULABIZE_DEFAULT();
	}
	else {
	    $emulabization = $curzation;
	}
    }

    #
    # Do we need to Emulabize?
    #
    my $newzation = DOCKER_EMULABIZE_NONE();
    my @levels = ();
    if ($emulabization eq '' || $emulabization eq DOCKER_EMULABIZE_NONE()) {
	# Nothing to do.
	$emulabization = DOCKER_EMULABIZE_NONE();
    }
    elsif ($emulabization eq DOCKER_EMULABIZE_BASIC()
	   && ($update || $curzation eq DOCKER_EMULABIZE_NONE())) {
	#
	# Need to come up to basic.
	#
	$newzation = DOCKER_EMULABIZE_BASIC();
	@levels = (DOCKER_EMULABIZE_BASIC());
    }
    elsif ($emulabization eq DOCKER_EMULABIZE_CORE()
	   && ($update
	       || $curzation eq DOCKER_EMULABIZE_NONE()
	       || $curzation eq DOCKER_EMULABIZE_BASIC())) {
	#
	# Need to come up to core.
	#
	$newzation = DOCKER_EMULABIZE_CORE();
	@levels = (DOCKER_EMULABIZE_BASIC(),DOCKER_EMULABIZE_CORE());
    }
    elsif ($emulabization eq DOCKER_EMULABIZE_BUILDENV()
	   && ($update
	       || $curzation eq DOCKER_EMULABIZE_NONE()
	       || $curzation eq DOCKER_EMULABIZE_BASIC()
	       || $curzation eq DOCKER_EMULABIZE_CORE())) {
	#
	# Need to come up to buildenv.
	#
	$newzation = DOCKER_EMULABIZE_BUILDENV();
	@levels = (DOCKER_EMULABIZE_BASIC(),DOCKER_EMULABIZE_BUILDENV());
    }
    elsif ($emulabization eq DOCKER_EMULABIZE_FULL()
	   && ($update
	       || $curzation eq DOCKER_EMULABIZE_NONE()
	       || $curzation eq DOCKER_EMULABIZE_BASIC()
	       || $curzation eq DOCKER_EMULABIZE_CORE()
	       || $curzation eq DOCKER_EMULABIZE_BUILDENV())) {
	#
	# Need to come up to full.
	#
	$newzation = DOCKER_EMULABIZE_FULL();
	@levels = (DOCKER_EMULABIZE_BASIC(),DOCKER_EMULABIZE_BUILDENV(),
		   DOCKER_EMULABIZE_FULL());
    }
    else {
	# Nothing to do; just use existing base image.
	#$emulabization = DOCKER_EMULABIZE_NONE();
    }

    if ($newzation eq DOCKER_EMULABIZE_NONE()) {
	if ($debug) {
	    print STDERR "DEBUG: image $image will not be emulabized".
		" ($emulabization, new=$newzation, current=$curzation)\n";
	}
	if (defined($newimageref)) {
	    $$newimageref = $image;
	}
	if (defined($newzationref)) {
	    $$newzationref = $emulabization;
	}
	return 0;
    }

    #
    # Figure out the new image name and the context dir.  Let the caller
    # supply one in the $newimageref parameter, too.
    #
    my $newimage;
    my $newimagecdirname;
    if (!defined($newimageref) || !defined($$newimageref)
	|| $$newimageref eq '') {
	#
	# We are going to make a new image; give it a name.  For now, just
	# give it the current name:tag as the new name, then :, then
	# level.  We will retag it later with the real image name if
	# they want to save it.
	#
	# XXX: Later, for shared nodes, need to ensure we can't be
	# tricked into using a private image fro the wrong experiment!
	#
	$newimage = $image;
	$newimage =~ tr/:/-/;
	$newimagecdirname = $newimage;
	$newimagecdirname =~ tr/\//---/;
	$newimage .= ":emulab-$newzation";
	$newimagecdirname .= "--emulab-$newzation";
    }
    else {
	$newimage = $$newimageref;
	$newimagecdirname = "$newimage--emulab-$newzation";
	$newimagecdirname =~ tr/:/-/;
	$newimagecdirname =~ tr/\//---/;
    }

    #
    # We have to lock here, to avoid races.
    #
    my $imagelockname = ImageLockName($newimage);
    TBDebugTimeStamp("grabbing image lock $imagelockname writeable")
	if ($lockdebug);
    if (TBScriptLock($imagelockname,
		     TBSCRIPTLOCK_INTERRUPTIBLE(),
		     $MAXIMAGEWAIT) != TBSCRIPTLOCK_OKAY()) {
	fatal("Could not get $imagelockname lock for $newimage!");
    }
    TBDebugTimeStamp("  got image lock $imagelockname for $newimage")
	if ($lockdebug);

    #
    # Check to see if the image already exists, and if we need to
    # (re)build it.  If there's a new base, and we always want the
    # latest, we have to rebuild.  Else, if this image has the
    # Emulab code, and wants the latest, and is out of date
    # w.r.t. the cached source tree, we rebuild it too.
    #
    my $build = 0;
    TBDebugTimeStamp("inspecting image $newimage...");
    ($code,$content) = getClient()->image_inspect($newimage);
    if ($code) {
	TBDebugTimeStamp("$newimage does not exist; building!");
	$build = 1;
    }
    elsif ($pullpolicy eq DOCKER_PULLPOLICY_LATEST() && $havenewbase) {
	TBDebugTimeStamp("building new version of $newimage".
			 " because the base image was updated!");
	$build = 1;
    }
    elsif ($newzation ne DOCKER_EMULABIZE_NONE()
	   && $newzation ne DOCKER_EMULABIZE_BASIC()
	   && $pullpolicy eq DOCKER_PULLPOLICY_LATEST()) {
	my $installedvers = $iattrs{'EMULABVERSION'};
	my $currentvers = `cat $EMULABSRC/.git/refs/heads/master`;
	chomp($currentvers);
	if ($installedvers ne $currentvers) {
	    TBDebugTimeStamp("building new version of $newimage".
			     " because the Emulab src repo was updated".
			     " ($installedvers -> $currentvers)!");
	    $build = 1;
	}
    }

    if ($build) {
	if ($dist eq '' && $tag eq '' && $mintag eq '') {
	    warn("cannot emulabize image with unknown distro!");
	    goto badimage;
	}
	if (!(($mintag ne '' && -d "$DOCKERFILES/$mintag")
	      || ($tag ne '' && -d "$DOCKERFILES/$tag")
	      || ($tag ne '' && -d "$DOCKERFILES/$tag"))) {
	    warn("cannot emulabize image with unsupported auto-analyzed".
		 " tags $dist/$tag/$mintag!");
	    goto badimage;
	}

	#
	# Ok, finally, start the build.  Find all the Dockerfile
	# frags and shell scripts, and generate a Dockerfile and a
	# context directory.  If that dir exists already, remove it.
	# Build any artifacts first.
	#
	# To find the fragments, we go from most specific to least
	# (i.e., mintag -> tag -> dist).
	#
	# NB: we always copy the $mintag,$tag,$dist,common subdirs
	# of /etc/emulab/docker/dockerfiles into the context for the
	# image, because we want a script in say ubuntu16 to be able
	# to reference something in the common/ subdir.
	#
	my @copydirs = ();
	foreach my $td ('common',$dist,$tag,$mintag) {
	    if (-l "$DOCKERFILES/$td") {
		push(@copydirs,$td);
		my $linktarget = readlink("$DOCKERFILES/$td");
		if ($linktarget =~ /^\//) {
		    push(@copydirs,"$linktarget");
		}
		else {
		    push(@copydirs,"$linktarget");
		}
	    }
	    elsif (-d "$DOCKERFILES/$td") {
		push(@copydirs,$td);
	    }
	}
	my @dfiles = ();
	my @runscripts = ();
	my @artifactscripts = ();

	my $cwd = getcwd();
	chdir($DOCKERFILES);
	for my $l ('prepare',@levels) {
	    for my $t ($mintag,$tag,$dist) {
		my $found = 0;
		if (-f "$t/Dockerfile-$l") {
		    push(@dfiles,"$t/Dockerfile-$l");
		    $found = 1;
		}
		if (-f "$t/$l.sh") {
		    push(@runscripts,"$t/$l.sh");
		    $found = 1;
		}
		if ($found) {
		    if (-f "$t/$l-artifacts.sh") {
			push(@artifactscripts,"$t/$l-artifacts.sh");
		    }
		    #
		    # Ok, we found instructions for this level, so
		    # skip to the next level.
		    #
		    next;
		}
	    }
	}
	#
	# Now look for init-related goo.  We install all inits that
	# we know about that apply to this mintag/tag/dist/common.
	#
	for my $init ('runit','systemd','upstart','init') {
	    for my $t ($mintag,$tag,$dist) {
		my $found = 0;
		if (-f "$t/Dockerfile-$init") {
		    push(@dfiles,"$t/Dockerfile-$init");
		    $found = 1;
		}
		if (-f "$t/$init.sh") {
		    push(@runscripts,"$t/$init.sh");
		    $found = 1;
		}
		if ($found) {
		    if (-f "$t/$init-artifacts.sh") {
			push(@artifactscripts,"$t/$init-artifacts.sh");
		    }
		    #
		    # Ok, we found instructions for this level, so
		    # skip to the next level.
		    #
		    next;
		}
	    }
	}
	for my $l ('cleanup') {
	    for my $t ($mintag,$tag,$dist) {
		my $found = 0;
		if (-f "$t/$l.sh") {
		    push(@runscripts,"$t/$l.sh");
		    #
		    # Ok, we found instructions for this level, so
		    # skip to the next level.
		    #
		    next;
		}
	    }
	}
	chdir($cwd);

	#
	# Ok, we create a context dir that has two things.  First,
	# it has an artifacts subdir.  Dockerfile fragments are
	# responsible to copy stuff from artifacts into place.  The
	# fs/ subdir is intended to be a root filesystem fragment.
	# Anything in it is automatically copied to the image
	# rootfs.  The fs/ subdir is populated from $DOCKERFILES as
	# follows.  First, each mintag/tag/dist/common subdir in
	# DOCKERFILES is copied into fs/etc/emulab/CONTEXT --
	# excluding any fs subdir in the mintag/tag/dist/common
	# subdirs.  Those fs subdirs are copied into the primary fs
	# subdir, *in reverse order* (so that the most specific can
	# overwrite the least specific).  This is the best way to
	# minimize layers -- i.e., to have a single COPY
	# instruction, and a single RUN instruction, for two layers
	# total.  Ugh!
	#
	my $cdir = "$CONTEXTDIR/$newimagecdirname";
	my $adir = "$cdir/artifacts";
	my $hdir = "$cdir/fs";
	mkdir($cdir);
	mkdir($adir);
	mkdir($hdir);
	mkdir("$hdir/etc");
	mkdir("$hdir/etc/ssh");
	mkdir("$hdir/etc/emulab");
	mkdir("$hdir/etc/emulab/CONTEXT");
	mysystem2("rsync -a /etc/ssh/ssh_host* $hdir/etc/ssh/");
	mysystem2("rsync -a /etc/emulab/*.pem $hdir/etc/emulab/");
	for my $dir (@copydirs) {
	    mysystem2("rsync -a --exclude=$DOCKERFILES/$dir/fs".
		      " $DOCKERFILES/$dir $hdir/etc/emulab/CONTEXT/");
	    if (-d "$DOCKERFILES/$dir/fs") {
		mysystem2("rsync -a $DOCKERFILES/$dir/fs/ $hdir/");
	    }
	}

	#
	# We are overriding the image's default ENTRYPOINT and CMD by
	# running runit instead.  So we have to emulate them (as best we
	# can; runit is pid 1, not the entrypointcmd, etc) -- and set
	# ourselves up for any dynamic changes to entrypoint/cmd per
	# container at runtime.
	# See https://docs.docker.com/engine/reference/builder/#understand-how-cmd-and-entrypoint-interact
	# for a matrix of how ENTRYPOINT and CMD interact.  But here's
	# what we do.  Each emulabized image contains a runit service
	# (/etc/service/dockerentrypoint,
	# see dockerfiles/common/fs/etc/service/dockerentrypoint)
	# that handles the emulation of those cases.  We feed it by
	# populating
	# /etc/emulab/docker/{entrypoint.image.type,entrypoint.image,
	#   cmd.image.type,cmd.image,user,dockerenv.image} according to
	# what we find in the image.  Then, those files can be
	# "overridden" at runtime by
	# /etc/emulab/docker/{entrypoint.runtime.type,entrypoint.runtime,
	#   cmd.runtime.type,cmd.runtime}, and added to by
	# /etc/emulab/docker/dockerenv.runtime .
	#

	# First, set up the user file, and the USER env var.  NB: we
	# must set this up; normally Docker sets it prior to running
	# entrypoint/cmd.
	my @generatedEnvVars = ();
	my $ddir = "$hdir/etc/emulab/docker";
	mkdir("$ddir");
	if (exists($iattrs{DOCKER_USER}) && defined($iattrs{DOCKER_USER})
	    && $iattrs{DOCKER_USER} ne "") {
	    open(FD,">$ddir/user");
	    print FD $iattrs{DOCKER_USER}."\n";
	    close(FD);
	    push(@generatedEnvVars,"USER=$iattrs{DOCKER_USER}");
	}
	else {
	    push(@generatedEnvVars,"USER=root");
	}

	# Second, ensure that HOME and PATH are properly initialized for
	# the same reason as above for USER (so that any startup
	# commands that depend on these variables don't fail).
	my @retlines;
	my $foundit = 0;
	$rc = analyzeImageWithBusyboxCommand($image,{},\@retlines,"env");
	for my $line (@retlines) {
	    chomp($line);
	    if (substr($line, 0, index($line, '=')) eq "HOME") {
		push(@generatedEnvVars,$line);
		$foundit = 1;
		last;
	    }
	}
	if (!$foundit) {
	    push(@generatedEnvVars,"HOME=/");
	}
	push(@generatedEnvVars,
	     "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin");

	# Dump our generated (and image-builtin) env vars.  Note we
	# export them all!  This is what we want for the case where we
	# exec stuff on behalf of the user; and it arguably what any
	# user would want.
	open(FD,">$ddir/dockerenv.entrypoint");
	for my $var (@generatedEnvVars) {
	    print FD "export $var\n";
	}
	close(FD);
	if (exists($iattrs{DOCKER_ENV})) {
	    open(FD,">$ddir/dockerenv.image");
	    foreach my $elem (@{$iattrs{DOCKER_ENV}}) {
		print FD "export $elem\n";
	    }
	    close(FD);
	}

	# Dump the image's workingdir into another file that the
	# entrypoint service looks for.
	if (exists($iattrs{DOCKER_WORKINGDIR})
	    && $iattrs{DOCKER_WORKINGDIR} ne "") {
	    open(FD,">$ddir/workingdir");
	    print FD $iattrs{DOCKER_WORKINGDIR}."\n";
	    close(FD);
	}

	# Dump the image's entrypoint (and type of entrypoint).
	if (exists($iattrs{DOCKER_ENTRYPOINT})
	    && defined($iattrs{DOCKER_ENTRYPOINT})) {
	    my $e = $iattrs{DOCKER_ENTRYPOINT};
	    TBDebugTimeStamp("image entrypoint: ".Dumper($e).".\n");
	    if (ref($e) eq 'ARRAY') {
		$e = "array:" . join(",",map { unpack("H*",$_) } @{$e});
	    }
	    elsif ($e ne "") {
		$e = "string:" . unpack("H*",$e);
	    }
	    TBDebugTimeStamp("encoded image entrypoint: $e\n");
	    if ($e ne "") {
		open(FD,">$ddir/entrypoint.image");
		print FD "$e\n";
		close(FD);
	    }
	}

	# Dump the image's cmd (and type of cmd).
	if (exists($iattrs{DOCKER_CMD}) && defined($iattrs{DOCKER_CMD})) {
	    my $c = $iattrs{DOCKER_CMD};
	    TBDebugTimeStamp("image cmd: ".Dumper($c).".\n");
	    if (ref($c) eq 'ARRAY') {
		$c = "array:" . join(",",map { unpack("H*",$_) } @{$c});
	    }
	    elsif ($c ne "") {
		$c = "string:" . unpack("H*",$c);
	    }
	    TBDebugTimeStamp("encoded image cmd: $c\n");
	    if ($c ne "") {
		open(FD,">$ddir/cmd.image");
		print FD "$c\n";
		close(FD);
	    }
	}

	#
	# Before we start setting up the new image Dockerfile, run
	# all the artifact build scripts.
	#
	foreach my $ascript (@artifactscripts) {
	    my %args = ( 'Tty' => JSON::PP::true, 'User' => 'root');
	    $args{'HostConfig'}{'Binds'} = [
		"$hdir/etc/emulab/CONTEXT:/etc/emulab/CONTEXT:ro",
		"$adir:/artifacts:rw",
		"$EMULABSRC:/emulab:ro",
		"$PUBSUBSRC:/pubsub:ro",
		"$RUNITSRC:/runit:ro"
		];
	    $args{'Env'} = [
		"DESTDIR=/artifacts","EMULABSRC=/emulab","PUBSUBSRC=/pubsub",
		"RUNITSRC=/runit","CONTEXT=/etc/emulab/CONTEXT"
		];
	    $args{'Image'} = $image;
	    $args{'Cmd'} = ["/bin/sh","-c","cd \$CONTEXT && $ascript"];
	    $args{'Entrypoint'} = '';
	    $args{'User'} = 'root';
	    my $tmpname = "artifact-".sha1_hex($image . rand(POSIX::INT_MAX));
	    TBDebugTimeStamp("creating artifact container $tmpname for".
			     " artifact script $ascript...");
	    ($code,$content) = getClient()->container_create(
		$tmpname,\%args);
	    if ($code) {
		warn("failed to create image analysis container $tmpname".
		     " for image $image: $content ($code); aborting\n");
		goto badimage;
	    }
	    TBDebugTimeStamp("starting artifact container $tmpname");
	    ($code,$content) = getClient()->container_start($tmpname);
	    if ($code) {
		warn("failed to start artifact container $tmpname".
		     " for image $image: $content ($code); aborting\n");
		goto badimage;
	    }
	    open(our $fd,">$cdir-$tmpname.log");
	    sub log_printer {
		my ($data,$foo,$resp) = @_;
		print $data;
		if (defined($fd)) {
		    print $fd $data;
		}
	    }
	    # Purely for real-time logging purposes.
	    TBDebugTimeStamp("attaching to artifact container $tmpname;".
			     " stdout/stderr from container will follow...");
	    getClient()->container_attach($tmpname,1,1,0,1,1,1,\&log_printer);
	    close($fd);
	    TBDebugTimeStamp("waiting for artifact container $tmpname to stop");
	    ($code,$content) = getClient()->container_wait($tmpname);
	    print STDERR "DEBUG: $content " . ref($content) . "\n";
	    if ($code) {
		warn("failed to wait for artifact container $tmpname".
		     " for image $image: $content ($code); aborting\n");
		goto badimage;
	    }
	    elsif (ref($content) eq 'ARRAY') {
		foreach my $blurb (@$content) {
		    if (ref($blurb) eq 'HASH'
			&& exists($blurb->{'StatusCode'})
			&& $blurb->{'StatusCode'}) {
			warn("image artifact container $tmpname,image $image".
			     " exited non-zero (".$blurb->{'StatusCode'}.");".
			     " aborting\n");
			goto badimage;
		    }
		}
	    }
	    elsif (ref($content) eq 'HASH'
		   && exists($content->{'StatusCode'})
		   && $content->{'StatusCode'}) {
		warn("image artifact container $tmpname,image $image".
		     " exited non-zero (".$content->{'StatusCode'}.");".
		     " aborting\n");
		goto badimage;
	    }

	    TBDebugTimeStamp("removing artifact container $tmpname");
	    ($code,$content) = getClient()->container_delete($tmpname);
	    if ($code) {
		warn("failed to delete artifact script container".
		     " $tmpname,image $image: $content ($code);".
		     " ignoring!\n");
	    }
	}

	my $dockerfile = "$cdir/Dockerfile";
	open(DFD,">$dockerfile")
	    or fatal("could not open $dockerfile!");

	#
	# First, we are descended FROM the base image.
	#
	print DFD "FROM $image\n";

	#
	# When user is unspecified Docker defaults to root,
	# however if a user specifies another user we must
	# set it back to root in order to do our transformations.
	# However we also must set user back to the Dockerfile's spec 
	# for entrypoint/cmd ops
	#
	print DFD "USER root\n";

	#
	# Then, if this is emulabization core or full, add an
	# ONBUILD instruction that runs our prepare script.  And we
	# *always* save off new versions of the master passwd files.
	#
	if ($emulabization eq DOCKER_EMULABIZE_CORE()
	    || $emulabization eq DOCKER_EMULABIZE_FULL()) {
	    print DFD "ONBUILD RUN /usr/local/etc/emulab/prepare -M\n";
	}

	#
	# Second, copy in all the Dockerfile fragments.
	#
	my @copies = ();
	$cwd = getcwd();
	chdir($DOCKERFILES);
	foreach my $f (@dfiles) {
	    open(FD,"$f")
		or fatal("could not open $f to copy into $dockerfile");
	    my @lines = <FD>;
	    close(FD);
	    my @tlines = ();
	    foreach my $dfline (@lines) {
		chomp($dfline);
		if ($dfline =~ /^\s*COPY\s+([^\s]+)\s+(.+)$/) {
		    push(@copies,[$1,$2]);
		}
		else {
		    push(@tlines,$dfline);
		}
	    }
	    if (@tlines > 0) {
		print DFD join("\n",@tlines)."\n";
	    }
	}
	chdir($cwd);

	#
	# Next create COPY and RUN commands.
	#
	if ($COPY_OPTIMIZE) {
	    $cwd = getcwd();
	    chdir($cdir);
	    mkdir("combined-fs");
	    foreach my $sdref (@copies) {
		my ($src,$dst) = ($sdref->[0],$sdref->[1]);
		if ($dst =~ /^[^\/]/) {
		    $dst = "combined-fs/$dst";
		}
		else {
		    $dst = "combined-fs$dst";
		}
		mysystem("rsync -a $src $dst");
	    }
	    mysystem("rsync -a fs/ combined-fs/");
	    chdir($cwd);

	    print DFD "COPY combined-fs/ /\n";
	}
	else {
	    print DFD "COPY fs/ /\n";
	}
	my $runcmd = "";
	foreach my $ruc (@runscripts) {
	    my $dn = dirname($ruc);
	    my $bn = basename($ruc);
	    if ($runcmd ne '') {
		$runcmd .= " && ";
	    }
	    #$runcmd .= "cd /tmp/$dn && ./$bn && cd /tmp";
	    $runcmd .= "cd /etc/emulab/CONTEXT && $ruc";
	}
	if ($runcmd ne '') {
	    $runcmd .= " && ";
	}
	$runcmd .= "mkdir -p /etc/emulab".
	    " && echo $newzation > /etc/emulab/emulabization-type";
	#
	# If we are updating the Emulabization *or* if we are
	# Emulabizing for the first time, *always* overwrite the
	# Emulab master passwd files with the image's real files.
	# This ensures that the client-install only temporarily
	# overwrites the Emulab master passwd files; *and* ensures
	# we always use the image's files.  We cannot trust the
	# Emulab per-distro/per-version passwd files from git, since
	# they may not match what's installed; this is not our
	# image.
	#
	if ($update
	    || $curzation eq '' || $curzation eq DOCKER_EMULABIZE_NONE()) {
	    $runcmd .= " && cp -pv /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/emulab";
	}
	print DFD "RUN /bin/sh -c '$runcmd'\n";
	close(DFD);

	# We could just send the bytes to the daemon (tar -C $cdir -c . |),
	# but we want to store the file on disk for provenance.
	my $tarfile = "$cdir-context-" . time() . ".tar";
	mysystem2("tar -cf $tarfile -C $cdir .");
	if ($?) {
	    warn("failed to build tar archive of context dir $cdir;".
		 " aborting!\n");
	    goto badimage;
	}
	TBDebugTimeStamp("building new image $newimage");
	my $buf = '';
	open(our $fd,">$cdir-build.log");
	our $bytes = 0;
	sub json_log_printer {
	    my ($data,$foo,$resp) = @_;
	    if ($resp->header("content-type") eq 'application/json') {
		eval {
		    $data = decode_json($data);
		};
		if ($@) {
		    warn("build log_printer: $! $@ ($data)\n");
		}
	    }
	    print $data;
	    print $fd $data;
	    $bytes += length($data);
	}
	($code,$content) = getClient()->image_build_from_tar_file(
	    $tarfile,$newimage,undef,undef,\&json_log_printer);
	close($fd);
	if ($code) {
	    warn("failed to build $newimage from $image: $content ($code)!");
	    goto badimage;
	}
	if ($bytes == 0) {
	    open(FD,">$cdir-build.log");
	    if (defined($content) && ref($content) eq 'ARRAY'
		&& defined($content->[0]) && ref($content->[0]) eq 'HASH'
		&& defined($content->[0]->{'stream'})) {
		foreach my $bit (@$content) {
		    next
			if (!defined($bit->{'stream'}));
		    print FD $bit->{'stream'};
		}
	    }
	    elsif (defined(ref($content)) && ref($content) ne '') {
		print FD Dumper($content);
	    }
	    else {
		print FD $content;
	    }
	    close(FD);
	}
    }

    #
    # Unlock the emulabized image.
    #
    TBScriptUnlock();
    if (defined($newimageref)) {
	$$newimageref = $newimage;
    }
    if (defined($newzationref)) {
	$$newzationref = $emulabization;
    }
    if (defined($iattrsref)) {
	$$iattrsref = \%iattrs;
    }
    return 0;

  badimage:
    TBScriptUnlock();
    return -1;
}

sub setupImage($$$$$$$$$$$)
{
    my ($vnode_id,$vnconfig,$private,$image,$username,$password,$dockerfile,
	$newimageref,$newcreateargsref,$newcmdref,$newzationref) = @_;
    my $rc;
    my $cwd;
    my ($code,$content);

    TBDebugTimeStamp("setting up image $image for $vnode_id...");

    #
    # Check the emulabization value before we do anything, to save work.
    # We default to "basic" emulabization.
    #
    my $emulabization;
    my $update = 0;
    if (exists($vnconfig->{'attributes'}->{DOCKER_EMULABIZATION})) {
	$emulabization = $vnconfig->{'attributes'}->{DOCKER_EMULABIZATION};
	if ($emulabization ne DOCKER_EMULABIZE_FULL()
	    && $emulabization ne DOCKER_EMULABIZE_BUILDENV()
	    && $emulabization ne DOCKER_EMULABIZE_CORE()
	    && $emulabization ne DOCKER_EMULABIZE_BASIC()
	    && $emulabization ne DOCKER_EMULABIZE_NONE()
	    && $emulabization ne '') {
	    warn("invalid emulabization ($emulabization) specified for".
		 " $vnode_id/$image; aborting!");
	    return -1;
	}
	if ($emulabization eq '') {
	    $emulabization = DOCKER_EMULABIZE_NONE;
	}
	$vnconfig->{'attributes'}->{DOCKER_EMULABIZATION} = $emulabization;
    }
    if (exists($vnconfig->{'attributes'}->{DOCKER_EMULABIZATION_UPDATE})) {
	$update = $vnconfig->{'attributes'}->{DOCKER_EMULABIZATION_UPDATE};
    }

    #
    # Pull the image, according to the policy.  Force the pull policy to
    # the latest for shared nodes.
    #
    if (SHAREDHOST()) {
	$vnconfig->{'attributes'}->{DOCKER_PULLPOLICY} =
	    DOCKER_PULLPOLICY_LATEST();
    }
    my $pullpolicy;
    if (exists($vnconfig->{'attributes'}->{DOCKER_PULLPOLICY})) {
	$pullpolicy = $vnconfig->{'attributes'}->{DOCKER_PULLPOLICY};
    }
    if (!defined($pullpolicy)) {
	$pullpolicy = DOCKER_PULLPOLICY_CACHED();
    }

    # Save off a read-only version of this, for convenience.
    my %vnattrs = %{$vnconfig->{'attributes'}};

    my $newimage;
    my $iattrs;
    if (!defined($newzationref)) {
	my $tmp;
	$newzationref = \$tmp;
    }
    $rc = emulabizeImage($image,\$newimage,$emulabization,$newzationref,$update,
			 $pullpolicy,$username,$password,$dockerfile,\$iattrs);
    if ($rc) {
	warn("failed to emulabize image $image; aborting!\n");
	return $rc;
    }
    #print "DEBUG: setupImage iattrs = ".Dumper($iattrs)."\n";
    #print "DEBUG: setupImage ".$iattrs->{'DIST'}.",".$iattrs->{'TAG'}.",".$iattrs->{'MINTAG'}."\n";
    my ($dist,$tag,$mintag) =
	($iattrs->{'DIST'},$iattrs->{'TAG'},$iattrs->{'MINTAG'});

    #
    # Save off the emulabization level we're going to use, if it was undef.
    #
    if (!defined($emulabization)) {
	$emulabization = $$newzationref;
    }

    #
    # If we're not emulabizing, we don't mess with the cmd or
    # entrypoint, for now.
    #
    if ($emulabization eq DOCKER_EMULABIZE_NONE()) {
	$$newimageref = $newimage;
	$$newcreateargsref = {};
	$$newcmdref = {};

	return 0;
    }

    #
    # Ok.  Now figure out any changes to the 'docker create ...' command
    # line that we might need -- i.e. to change the command, or env
    # vars, or the container stop signal.
    #
    # If emulabized, they are using our init.  If a shared host, we need
    # to force runit.  If a dedicated host, we can do whichever they
    # want.  Either way, if we made the image, we *always* specify a
    # custom init path, and a custom stop signal.  Thus, we always get
    # the init we want.
    #
    # If not emulabized, but if we detect they are using a real init,
    # and that init is systemd, AND that the host is *not* shared, we
    # need to change the command, the stopsignal, set container=docker,
    # mount the cgroupfs ro.
    #
    my $init = DOCKER_INIT_RUNIT();
    if (((!exists($vnattrs{DOCKER_INIT}) && 0)
	 || (exists($vnattrs{DOCKER_INIT})
	     && $vnattrs{DOCKER_INIT} eq DOCKER_INIT_INSTALLED()))
	&& exists($iattrs->{INITPROG})
	&& $iattrs->{INITPROG} ne '') {
	$init = $iattrs->{INITPROG};
    }
    elsif (exists($vnattrs{DOCKER_INIT})
	   && $vnattrs{DOCKER_INIT} eq DOCKER_INIT_RUNIT()) {
	$init = DOCKER_INIT_RUNIT();
    }
    else {
	$init = DOCKER_INIT_RUNIT();
    }
    if (SHAREDHOST() && $init eq 'systemd') {
	$init = DOCKER_INIT_RUNIT();
	warn("forcing init from systemd to $init on sharedhost!");
    }

    #
    # Now look for init-related docker create args and cmd.  At this
    # point, we know which init we are going to run, so we look only for
    # that one.  NB: each file must be a JSON dict of args to the
    # /containers/create Docker Engine API call.
    #
    my %initargs = ();
    my %initcmd = ();
    $cwd = getcwd();
    chdir($DOCKERFILES);
    TBDebugTimeStamp("entering dir $DOCKERFILES");
    for my $t ($mintag,$tag,$dist) {
	next
	    if (!defined($t));

	my $found = 0;
	TBDebugTimeStamp("looking for $t/Dockercmd-$init");
	if (-f "$t/Dockercmd-$init") {
	    TBDebugTimeStamp("found $t/Dockercmd-$init");
	    open(FD,"$t/Dockercmd-$init")
		or fatal("could not open $t/Dockercmd-$init");
	    my @lines = <FD>;
	    close(FD);
	    my $jref;
	    eval {
		$jref = decode_json(join('',@lines));
		require Hash::Merge;
		%initcmd = %{Hash::Merge::merge(\%initcmd,$jref)};
		if ($debug) {
		    print STDERR "DEBUG: merged initcmd = ".Dumper(%initcmd)."\n";
		}
	    };
	    if ($@) {
		print STDERR "ERROR: invalid JSON in $t/Dockercmd-$init: $@\n";
		goto badimage;
	    }
	    $found = 1;
	}
	TBDebugTimeStamp("looking for $t/Dockerargs-$init");
	if (-f "$t/Dockerargs-$init") {
	    TBDebugTimeStamp("found $t/Dockerargs-$init");
	    open(FD,"$t/Dockerargs-$init")
		or fatal("could not open $t/Dockerargs-$init");
	    my @lines = <FD>;
	    close(FD);
	    my $jref;
	    eval {
		$jref = decode_json(join('',@lines));
		require Hash::Merge;
		%initargs = %{Hash::Merge::merge(\%initargs,$jref)};
		if ($debug) {
		    print STDERR "DEBUG: merged initargs = ".Dumper(%initargs)."\n";
		}
	    };
	    if ($@) {
		print STDERR "ERROR: invalid JSON in $t/Dockerargs-$init: $@\n";
		goto badimage;
	    }
	    $found = 1;
	}
    }
    if (keys(%initcmd) == 0) {
	chdir($cwd);
	warn("could not assemble init command; bug!");
	goto badimage;
    }
    chdir($cwd);

    $$newimageref = $newimage;
    $$newcreateargsref = \%initargs;
    $$newcmdref = \%initcmd;

    return 0;

  badimage:
    return -1;
}

#
# "Save" a docker (libcontainer) network namespace so that we can
# customize it (i.e., add/remove devices) without those devices
# disappearing into a black hole if Docker releases its filehandle to
# the netns.  On Linux, the only way I know of to preserve a namespace
# for access once all its pids go away is the same way the iproute2
# package does it (bind mount /proc/PID/ns/net into
# /var/run/netns/<NS-NAME> -- the ip command looks for netnses there).
# So we do the same thing: we bind mount the initial docker container's
# pid into that file; then later on, the ip command can actually be used
# on it.
#
sub bindNetNS($$)
{
    my ($vnode_id,$private) = @_;
    my ($code,$content);
    my $cpid;

    # First get the container pid:
    ($code,$content) = getClient()->container_state($vnode_id);
    if ($code) {
	warn("could not find init pid of container $vnode_id; aborting".
	     " ($content ($code))\n");
	return -1;
    }
    $cpid = $content->{"Pid"};
    chomp($cpid);

    # Check to see if a stale mount exists for this container;
    # delete if so.
    if (-f "/var/run/netns/$vnode_id") {
	TBDebugTimeStamp("removing stale network namespace for $vnode_id".
			 " prior to copy")
	    if ($debug);
	unbindNetNS($vnode_id,$private);
    }

    # Now do the bind mount (after creating the runtime netns
    # dir, and the file we'll mount to):
    if (! -d "/var/run/netns") {
	mkdir("/var/run/netns");
    }

    if (! -f "/var/run/netns/$vnode_id") {
	open(MFD,">/var/run/netns/$vnode_id");
	close(MFD);
    }
    
    # Grab the container pid; we need a pid to find the file
    # representing the netns (which in docker/libcontainer world is only
    # /proc/<PID>/ns/net):
    ($code,$content) = getClient()->container_state($vnode_id);
    if ($code) {
	warn("could not find init pid of container $vnode_id; aborting".
	     " ($content ($code))\n");
	return -1;
    }
    $cpid = $content->{"Pid"};
    chomp($cpid);

    # Now do the bind mount:
    mysystem2("mount -o bind /proc/$cpid/ns/net /var/run/netns/$vnode_id");

    return $? >> 8;
}

# Move a network device from the root netns *into* a vnode (container) netns.
sub moveNetDeviceToNetNS($$$)
{
    my ($vnode_id,$private,$dev) = @_;

    mysystem2("$IP link $dev set netns $vnode_id");
    if (!$?) {
	if (!exists($private->{"rawnetdevs"})) {
	    $private->{"rawnetdevs"} = {};
	}
	$private->{"rawnetdevs"}{"$dev"} = $dev;
    }

    return $? >> 8;
}

# Move a network device *from* a vnode (container) netns into the root netns.
sub moveNetDeviceFromNetNS($$$)
{
    my ($vnode_id,$private,$dev) = @_;

    if (!exists($private->{"rawnetdevs"})
	or !exists($private->{"rawnetdevs"}{"$dev"})) {
	warn("device $dev not in our data structures for $vnode_id;".
	     " attempting removal from netns anyway!");
    }

    mysystem2("$IP netns exec $vnode_id ip link $dev set netns 1");
    if (!$?) {
	warn("device $dev not in $vnode_id netns; removing from".
	     " our data structures anyway!");
    }
    delete($private->{"rawnetdevs"}{"$dev"});

    return $? >> 8;
}

# Move our devices (if any) out of the netns into the root, umount the
# netns bind mount, and remove the mount point.
sub unbindNetNS($$)
{
    my ($vnode_id,$private) = @_;

    if (! -f "/var/run/netns/$vnode_id") {
	warn("container $vnode_id does not appear to have a bound netns!");
	return -1;
    }

    if (exists($private->{"rawnetdevs"})) {
	my @devs = keys(%{$private->{"rawnetdevs"}});
	foreach my $dev (@devs) {
	    moveNetDeviceFromNetNS($vnode_id,$private,$dev);
	}
    }

    mysystem2("umount /var/run/netns/$vnode_id");
    unlink("/var/run/netns/$vnode_id");

    return 0;
}

#
# Returns a list of <name>:<ip> pairs (and <alias>:<ip>) in the same
# order as Emulab's classic /etc/hosts generation (i.e. genhostsfile).
#
# XXX: note that this does not support the new /etc/hosts.{head,tail}
# stuff; to do that, we'd have to grab it out of the image, and we don't
# do that for now.
#
sub genhostspairlist($$)
{
    my ($vnode_id,$rptr) = @_;
    my @tmccresults;

    #
    # First see if we have a topo file; we can generate our own hosts
    # file if we do, saving a lot of load on tmcd in big experiments.
    #
    # NB: for a dedicated host, genhostslistfromtopo is really reading
    # /var/emulab/boot/topomap, not the VM's copy of that!  Thus we
    # always take the second (slow) path for the SHAREDHOST case,
    # because in that case the hosts's topomap is irrelevant.  None of
    # this is desireable, but it's what we've got for now.  Plus, shared
    # container experiments are not going to be large, so this is only
    # minor overhead.
    #
    my $mapfile = "$VMS/$vnode_id/hostmap";
    if ((SHAREDHOST() || genhostslistfromtopo($mapfile,\@tmccresults) < 0) &&
	tmcc(TMCCCMD_HOSTS,undef,\@tmccresults) < 0) {
	warn("Could not get hosts file from server!");
	@$rptr = ();
	return -1;
    }
    # If no results then return nothing.
    if (!@tmccresults) {
	@$rptr = ();
	return 0;
    }

    #
    # First, write a localhost line into the hosts file - we have to know the
    # domain to use here, so that we can qualify the localhost entry
    #
    # XXX: getting the vnode's domain is harder for shared nodes, so just don't
    # do this for now...
    #
    #my $hostname = `hostname`;
    #my $ldomain;
    #if ($hostname =~ /[^.]+\.(.+)/) {
    #	$ldomain = "localhost.$1:127.0.0.1";
    #}
    @$rptr = ( "localhost:127.0.0.1","loghost:127.0.0.1" );
    #push(@$rptr,$ldomain)
    #	if (defined($ldomain));

    #
    # Now convert each hostname into hosts file representation and write
    # it to the hosts file.  For docker, we have to explode these out into
    # <name>:<ip> pairs; we can't set aliases.
    #
    my $pat = q(NAME=([-\w\.]+) IP=([0-9\.]*) ALIASES=\'([-\w\. ]*)\');
    foreach my $str (@tmccresults) {
	if ($str =~ /$pat/) {
	    my $name    = $1;
	    my $ip      = $2;
	    my $aliases = $3;

	    push(@$rptr,"${name}:${ip}");
	    foreach my $alias (split(/\s+/,$aliases)) {
		push(@$rptr,"${alias}:${ip}");
	    }
	}
	else {
	    warn("Ignoring bad hosts line: $str");
	}
    }

    return 0;
}

#
# For docker, we handle mounts at container creation by mounting
# everything necessary on the physical host, then bind-mounting it into
# the container (which docker does for us as it starts up the
# container).  This function ensures necessary things are mounted on the
# host, then returns a list of bind-mounts that should be configured for
# the container.
#
# On a remote host, we do nothing.  On a dedicated local host, we do the
# same thing that rc.mounts -j does -- we mount all NFS mounts already
# mounted on the physical host.  However, on a shared local host, we do
# slightly differently than rc.mounts -j would do, since all our docker
# mounts must be bind mounts, we have to mount all those mounts in the
# host, track who's using them, and umount them as containers are
# destroyed and the refcnts go to zero.
#
my $MOUNTDB = "$VARDIR/db/mountdb";
my $MOUNTREFDB = "$VARDIR/db/mountrefdb";

sub addMounts($$)
{
    my ($vnode_id,$retref,) = @_;
    my $JAILDB = CONFDIR() . "/mountdb";
    my $mountstr;
    my %MDB;
    my %MRDB;
    my %JDB;
    my ($mdb_open,$mrdb_open,$jdb_open) = (0,0,0);
    my $ret;

    #
    # No mounts on remote nodes.
    # 
    if (REMOTE()) {
	$retref = {};
	return 0;
    }

    #
    # If this is a shared node, we need to lock.  Oh, whatever, let's
    # just do it regardless...
    #
    TBDebugTimeStamp("setupMounts: grabbing lock $GLOBAL_MOUNT_LOCK")
	if ($lockdebug);
    if (TBScriptLock($GLOBAL_MOUNT_LOCK,
		     TBSCRIPTLOCK_INTERRUPTIBLE(), 900) != TBSCRIPTLOCK_OKAY()){
	print STDERR "Could not get the mount lock!\n";
	return -1;
    }
    TBDebugTimeStamp("  got mount lock")
	if ($lockdebug);

    #
    # Open the main mount databases (the mount tracker, and the refcnter).
    #
    if (! dbmopen(%MDB, $MOUNTDB, 0644)) {
	warn("Could not open $MOUNTDB!\n");
	goto bad;
    }
    $mdb_open = 1;
    if (! dbmopen(%MRDB, $MOUNTREFDB, 0644)) {
	warn("Could not open $MOUNTREFDB!\n");
	goto bad;
    }
    $mrdb_open = 1;

    #
    # First-time init code.  Basically, if the phys host has any NFS
    # volumes mounted, i.e., as it would for a dedicated or shared local
    # host, we need to mark those in use if they're not already
    # refcnt'd.  This will ensure that they don't get umounted if no
    # vnode is using them any longer.  We really should do this in the
    # global one-time init, but I'm here now.
    #
    while (my ($remote, $path) = each %MDB) {
	if (!defined($MRDB{$remote})) {
	    $MRDB{$remote} = 1;
	}
	TBDebugTimeStamp("initialized global host mount $remote at $path")
	    if ($debug);
    }

    #
    # We mount all the mounts that the physical node has mounted, into
    # the jail/VM. Since this is not going to be updated (no support for
    # updating mounts yet), we construct a copy of the DB in the jail
    # directory so we know exactly what we did when it comes time to do
    # the unmounts. In the meantime, the physical node might change its
    # mount set, but we will not care (of course, if a dir is unmounted
    # from the pnode, something is probably going to break). 
    #
    my %MOUNTS = ();
    if (! dbmopen(%JDB, $JAILDB,  0644)) {
	warn("Could not create $JAILDB!\n");
	goto bad;
    }

    if (SHAREDHOST()) {
	my @tmccresults;

	if (tmcc(TMCCCMD_MOUNTS, undef, \@tmccresults) < 0) {
	    warn("Could not get mount info from server!\n");
	    goto bad;
	}
	foreach my $str (@tmccresults) {
	    if ($str =~ /^REMOTE=([-:\@\w\.\/]+) LOCAL=([-\@\w\.\/]+)/) {
		$MOUNTS{$2} = $2;
	    }
	    else {
		warn("Unparseable tmcd mount string '$str'!\n");
	    }
	}

	while (my ($remote, $path) = each %MOUNTS) {
	    if (defined($MRDB{$remote})) {
		$MRDB{$remote} += 1;
		TBDebugTimeStamp("$vnode_id using existing $remote")
		    if ($debug);
	    }
	    else {
		if (! -e $path) {
		    if (! os_mkdir($path, "0770")) {
			warn("Could not make directory $path");
			next;
		    }
		}
	
		print STDOUT "  Mounting $remote on $path\n";
		if (system("$NFSMOUNT $remote $path")) {
		    warn("Could not $NFSMOUNT $remote on $path");
		    next;
		}
		TBDebugTimeStamp("$vnode_id using new $remote")
		    if ($debug);
		$MRDB{$remote} = 1;
	    }

	    # Record the container as using this remote.
	    $JDB{$remote} = $path;	
	}
    }
    else {
	while (my ($remote, $path) = each %MDB) {
	    $MOUNTS{$remote} = $path;
	    $MRDB{$remote} += 1;
	    TBDebugTimeStamp("$vnode_id using $remote")
		if ($debug);
	    # Record the container as using this remote.
	    $JDB{$remote} = $path;	
	}
    }

    # Populate our retref hash:
    %$retref = ();
    while (my ($remote, $path) = each %JDB) {
	$retref->{$remote} = $path;	
    }
    $ret = 0;

  out:
    dbmclose(%JDB)
	if ($jdb_open);
    dbmclose(%MDB)
	if ($mdb_open);
    dbmclose(%MRDB)
	if ($mrdb_open);

    TBScriptUnlock();
    return $ret;

  bad:
    $ret = -1;
    goto out;
}

sub removeMounts($)
{
    my ($vnode_id,) = @_;
    my $JAILDB = CONFDIR() . "/mountdb";
    my $mountstr;
    my %MDB;
    my %MRDB;
    my %JDB;
    my ($mdb_open,$mrdb_open,$jdb_open) = (0,0,0);
    my $ret;

    #
    # No mounts on remote nodes.
    # 
    if (REMOTE()) {
	return 0;
    }

    #
    # If this is a shared node, we need to lock.  Oh, whatever, let's
    # just do it regardless...
    #
    TBDebugTimeStamp("addMounts: grabbing lock $GLOBAL_MOUNT_LOCK")
	if ($lockdebug);
    if (TBScriptLock($GLOBAL_MOUNT_LOCK,
		     TBSCRIPTLOCK_INTERRUPTIBLE(), 900) != TBSCRIPTLOCK_OKAY()){
	print STDERR "Could not get the mount lock!\n";
	return -1;
    }
    TBDebugTimeStamp("  got mount lock")
	if ($lockdebug);

    #
    # Open the main mount databases (the mount tracker, and the refcnter).
    #
    if (! dbmopen(%MDB, $MOUNTDB, 0644)) {
	warn("Could not open $MOUNTDB!\n");
	goto bad;
    }
    $mdb_open = 1;
    if (! dbmopen(%MRDB, $MOUNTREFDB, 0644)) {
	warn("Could not open $MOUNTREFDB!\n");
	goto bad;
    }
    $mrdb_open = 1;

    #
    # We mount all the mounts that the physical node has mounted, into
    # the jail/VM. Since this is not going to be updated (no support for
    # updating mounts yet), we construct a copy of the DB in the jail
    # directory so we know exactly what we did when it comes time to do
    # the unmounts. In the meantime, the physical node might change its
    # mount set, but we will not care (of course, if a dir is unmounted
    # from the pnode, something is probably going to break). 
    #
    my %MOUNTS = ();
    if (! dbmopen(%JDB, $JAILDB,  0644)) {
	warn("Could not create $JAILDB!\n");
	goto bad;
    }

    while (my ($remote, $path) = each %JDB) {
	if (!defined($MRDB{$remote})) {
	    warn("$vnode_id had $remote mounted, but not in refcnt db;".
		 " skipping!\n");
	    next;
	}
	else {
	    $MRDB{$remote} -= 1;
	    TBDebugTimeStamp("reduced refcnt for $remote to ".$MRDB{$remote}.
			     " ($vnode_id)")
		if ($debug);
	    if ($MRDB{$remote} == 0) {
		TBDebugTimeStamp("$vnode_id: unmounting 0-refcnt mount $remote")
		    if ($debug);
		system("umount $remote");
		delete($MRDB{$remote});
		delete($MDB{$remote});
	    }
	}
    }

    $ret = 0;

  out:
    dbmclose(%JDB)
	if ($jdb_open);
    dbmclose(%MDB)
	if ($mdb_open);
    dbmclose(%MRDB)
	if ($mrdb_open);

    TBScriptUnlock();
    return $ret;

  bad:
    $ret = -1;
    goto out;
}

#
# This is almost directly out of rc.route, but there are several key
# differences.  First, our setup is such that we install the routes from
# outside the container, because we might not have the `route` or `ip`
# binaries inside the container!  Second, all our commands must be run
# in the container's netns, so all commands get prefixed with that.
# Finally, we don't support gated or ospf etc.
#
sub CreateRoutingScripts($$)
{
    my ($vnode_id,$private) = @_;
    my @routes   = ();
    my $type     = 0;
    my %upmap    = ();
    my %downmap  = ();

    print STDOUT "Checking Testbed route configuration ... \n";

    if (getrouterconfig(\@routes, \$type)) {
	warn("Could not get router configuration from libsetup!");
	return -1;
    }
    #
    # Remove this temp file that getrouterconfig/calcroutes created as
    # input for the dijkstra calculator; on a 2k-node topo, it can be
    # >80MB.
    #
    if (-f CONFDIR() . "/linkmap") {
	unlink(CONFDIR() . "/linkmap");
    }

    my $script = CONFDIR()."/routing.sh";

    #
    # Always generate a script file since other scripts depend on it,
    # even if no routing was requested (ifconfig, tunnel config).
    #
    unlink($script);
    if (!open(RC, ">$script")) {
	fatal("Could not open $script: $!\n");
    }

    print RC "#!/bin/sh\n";
    print RC "# auto-generated by $0, DO NOT EDIT\n";

    if ($type eq "none") {
	print RC "true\n";
	close(RC);
	chmod(0755, $script);
	return 0;
    }

    #
    # Now convert static route info into OS route commands
    # Also check for use of gated/manual and remember it.
    #
    my $usegated  = (($type eq "gated" || $type eq "ospf") ? 1 : 0);
    if ($usegated) {
	warn("gated/ospf style of routing not supported in Docker containers!");
	return -1;
    }
    my $usemanual = (($type eq "manual" ||
		      $type eq "static" || $type eq "static-old") ? 1 : 0);

    foreach my $rconfig (@routes) {
	my $dip   = $rconfig->{"IPADDR"};
	my $rtype = $rconfig->{"TYPE"};
	my $dmask = $rconfig->{"IPMASK"};
	my $gate  = $rconfig->{"GATEWAY"};
	my $cost  = $rconfig->{"COST"};
	my $sip   = $rconfig->{"SRCIPADDR"};
	my $rcline;

	if (! defined($upmap{$sip})) {
	    $upmap{$sip} = [];
	    $downmap{$sip} = [];
	}
	$rcline = os_routing_add_manual($rtype, $dip,
					$dmask, $gate, $cost, undef);
	push(@{$upmap{$sip}}, $rcline);
	$rcline = os_routing_del_manual($rtype, $dip,
					$dmask, $gate, $cost, undef);
	push(@{$downmap{$sip}}, $rcline);
    }

    my $prefix = "$IP netns exec $vnode_id ";

    print RC "case \"\$1\" in\n";
    foreach my $arg (keys(%upmap)) {
	print RC "  $arg)\n";
	print RC "    case \"\$2\" in\n";
	print RC "      up)\n";
	foreach my $rcline (@{$upmap{$arg}}) {
	    print RC "        ${prefix}$rcline\n";
	}
	print RC "      ;;\n";
	print RC "      down)\n";
	foreach my $rcline (@{$downmap{$arg}}) {
	    print RC "        ${prefix}$rcline\n";
	}
	print RC "      ;;\n";
	print RC "    esac\n";
	print RC "  ;;\n";
    }
    print RC "  enable)\n";

    #
    # Turn on IP forwarding
    #
    print RC "    ${prefix}" . os_routing_enable_forward() . "\n";
    print RC "  ;;\n";

    #
    # For convenience, allup and alldown.
    #
    print RC "  enable-routes)\n";
    foreach my $arg (keys(%upmap)) {
	foreach my $rcline (@{$upmap{$arg}}) {
	    print RC "    ${prefix}$rcline\n";
	}
    }
    print RC "  ;;\n";
    
    print RC "  disable-routes)\n";
    foreach my $arg (keys(%downmap)) {
	foreach my $rcline (@{$downmap{$arg}}) {
	    print RC "    ${prefix}$rcline\n";
	}
    }
    print RC "  ;;\n";
    print RC "esac\n";
    print RC "exit 0\n";
    close(RC);
    chmod(0755, $script);

    return 0;
}

sub RunRoutingScripts($$)
{
    my ($vnode_id,$updown) = @_;

    my $script = CONFDIR()."/routing.sh";
    if (! -e $script) {
	TBDebugTimeStamp("RunRoutingScripts: no $script file!")
	    if ($debug);
	return undef;
    }
    else {
	TBDebugTimeStamp("RunRoutingScripts: $script:")
	    if ($debug);
	my $cmd = $script;
	my @output;
	my $ret;
	if ($updown) {
	    @output = system("/bin/sh $cmd enable-routes");
	    $ret = $? >> 8;
	    push(@output,system("/bin/sh $cmd enable-routes"));
	    $ret |= $? >> 8;
	}
	else {
	    @output = system("/bin/sh $cmd disable-routes");
	    $ret = $? >> 8;
	}
	TBDebugTimeStamp("ret = $ret\n".join("\n",@output))
	    if ($debug);
	return $ret;
    }
}

sub RunShapingScripts($$)
{
    my ($vnode_id,$updown) = @_;

    my $script = CONFDIR()."/shaping-";
    if ($updown) {
	$script .= "up.sh";
    }
    else {
	$script .= "down.sh";
    }

    if (! -e $script) {
	TBDebugTimeStamp("RunShapingScripts: no $script file!")
	    if ($debug);
	return undef;
    }
    else {
	TBDebugTimeStamp("RunShapingScripts: $script:")
	    if ($debug);
	my @output = system("/bin/sh $script");
	my $ret = $? >> 8;
	TBDebugTimeStamp("ret = $ret\n".join("\n",@output))
	    if ($debug);
	return $ret;
    }
}

#
# Create scripts to enable and disable the endnodeshaping for a
# particular node.  These scripts are not static -- they must figure out
# which veths the docker runtime has assigned to each vnode.  They do
# this by running the `ip` command within the vnode's netns, finding the
# link associated with the vmac that is getting shaped, and then finding
# the peer device in the root context.  At that point, they can setup
# traffic shaping in the root context.  But it's a dynamic thing that
# changes each time the docker container boots.
#
# Also, note that we only support netem.
#
# Finally, if you set $ingress=0, that will disable output of ingress
# code EVEN IF it is a duplex link (i.e. we would normally use ingress
# shaping).
#
sub CreateShapingScripts($$$$;$)
{
    my ($vnode_id,$private,$node_ifs,$node_lds,$ingress) = @_;
    if (!defined($ingress)) {
	$ingress = 1;
    }
    my $uscript = CONFDIR()."/shaping-up.sh";
    my $dscript = CONFDIR()."/shaping-down.sh";

    if (! open(UFILE, ">$uscript")) {
	print STDERR "Error creating $uscript: $!\n";
	return -1;
    }
    if (! open(DFILE, ">$dscript")) {
	print STDERR "Error creating $dscript: $!\n";
	return -1;
    }
    print UFILE "#!/bin/sh\n\n";
    print DFILE "#!/bin/sh\n\n";
    print UFILE "set -x\n\n";
    print DFILE "set -x\n\n";

    my @ucmds = ();
    my @dcmds = ();
    my $cstr;

    $cstr = "vnodeid=$vnode_id";
    push(@ucmds,$cstr);
    push(@dcmds,$cstr);

    foreach my $ifc (@$node_ifs) {
	#
	# Find associated delay info
	#
	my $ldinfo;
	foreach my $ld (@$node_lds) {
	    if ($ld->{"IFACE"} eq $ifc->{"MAC"}) {
		$ldinfo = $ld;
	    }
	}
	next
	    if (!defined($ldinfo));

	my $type      = $ldinfo->{TYPE};
	my $linkname  = $ldinfo->{LINKNAME};
	#my $vnode     = $ldinfo->{VNODE};
	#my $inet      = $ldinfo->{INET};
	#my $mask      = $ldinfo->{MASK};
	my $pipeno    = $ldinfo->{PIPE};
	my $delay     = $ldinfo->{DELAY};
	my $bw        = $ldinfo->{BW};
	my $plr       = $ldinfo->{PLR};
	my $rpipeno   = $ldinfo->{RPIPE};
	my $rdelay    = $ldinfo->{RDELAY};
	my $rbw       = $ldinfo->{RBW};
	my $rplr      = $ldinfo->{RPLR};

	#
	# Delays are floating point numbers (unit is ms). ipfw does not
	# support floats, so apply a cheesy rounding function to convert
	# to an integer (since perl does not have a builtin way to
	# properly round a floating point number to an integer).
	#
	# NB: Linux doesn't support floats either, and wants usecs.
	#
	$delay  = int($delay + 0.5) * 1000;
	$rdelay = int($rdelay + 0.5) * 1000;

	#
	# Sweet! 'k' as in "kbit" means 1024, not 1000, to tc.
	# Just spell it out as bits here, they can't screw that up!
	#
	$bw *= 1000;
	$rbw *= 1000;

	# Packet loss in netem is percent.
	$plr *= 100;

	#
	# Set some variables enabling us to dynamically find the veth in
	# the root context when this runs.
	#
	$cstr = "vip=$ifc->{IPADDR}";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = "vmac=".fixupMac($ifc->{MAC});
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	if ($ingress && $type eq 'duplex') {
	    $cstr = "ifb=$ldinfo->{IFB}";
	    push(@ucmds,$cstr);
	    push(@dcmds,$cstr);
	}
	$cstr = "bw=$bw\nplr=$plr\ndelay=$delay";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = "rbw=$rbw\nrplr=$rplr\nrdelay=$rdelay";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);

	#
	# Figure out the root context half of the veth peer for this
	# docker container.  Tricky because Docker doesn't expose this
	# info.
	#
	$cstr = "IFIDX=`ip netns exec \$vnodeid ip -br link show".
	    " | sed -r -n -e \"s/^[^\@]+\@if([0-9]+).*\$vmac.*\$/\\1/p\"`";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = 'if [ "x$IFIDX" = "x" ]; then';
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = "    IFIDX=`ip netns exec \$vnodeid ip -br addr show".
	    " | sed -r -n -e \"s/^[^\@]+\@if([0-9]+).*\$vip.*\$/\\1/p\"`";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = 'fi';
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = 'if [ "x$IFIDX" = "x" ]; then echo "ERROR: could not find iface $vmac $vnodeid!"; exit 1; fi';
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = "VETH=`ip link show | sed -r -n -e \"s/^\$IFIDX: ([^\@]+)\@.*\$/\\1/p\"`";
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);
	$cstr = 'if [ "x$VETH" = "x" ]; then echo "ERROR: could not find host veth for container ifidx $IFIDX ($vmac $vnodeid)!"; exit 1; fi';
	push(@ucmds,$cstr);
	push(@dcmds,$cstr);

	push(@ucmds,"\n");
	push(@dcmds,"\n");

	#
	# Ok, finally get to the shaping.  First we do the egress case:
	#
	push(@ucmds, 'tc qdisc del dev $VETH root');
	push(@ucmds,'if [ ! $bw -eq 0 ]; then');
	push(@ucmds, '    tc qdisc add dev $VETH handle 1 root htb default 1');
	push(@ucmds, '    tc class add dev $VETH classid 1:1'.
	     ' parent 1 htb rate $bw ceil $bw');
	push(@ucmds,'    tc qdisc add dev $VETH handle 2 parent 1:1'.
	    ' netem drop $plr delay ${delay}us');
	push(@ucmds,'else');
	push(@ucmds,'    tc qdisc add dev $VETH handle 1 root'.
	    ' netem drop $plr delay ${delay}us');
	push(@ucmds,'fi');

	push(@dcmds, 'tc qdisc del dev $VETH root');

	if ($ingress && $type eq 'duplex') {
	    push(@ucmds, 'ifconfig $ifb up');
	    push(@ucmds, 'tc qdisc del dev $ifb root');
	    push(@ucmds, 'tc qdisc add dev $VETH handle ffff: ingress');
	    push(@ucmds, 'tc filter add dev $VETH parent ffff: protocol ip'.
		 ' u32 match u32 0 0 action mirred egress redirect dev $ifb');
	    push(@ucmds,'if [ ! $bw -eq 0 ]; then');
	    push(@ucmds,'    tc qdisc add dev $ifb root handle 2: htb default 1');
	    push(@ucmds,'    tc class add dev $ifb parent 2: classid 2:1'.
		 ' htb rate $rbw ceil $rbw');
	    push(@ucmds,'    tc qdisc add dev $ifb handle 3 parent 2:1'.
	    ' netem drop $rplr delay ${rdelay}us');
	    push(@ucmds,'else');
	    push(@ucmds,'    tc qdisc add dev $ifb handle 3 root'.
		 ' netem drop $rplr delay ${rdelay}us');
	    push(@ucmds,'fi');

	    push(@dcmds, 'tc qdisc del dev $ifb root');
	}
    }

    foreach my $cmd (@ucmds) {
	print UFILE "$cmd\n";
    }
    print UFILE "exit 0\n";
    foreach my $cmd (@dcmds) {
	print DFILE "$cmd\n";
    }
    print DFILE "exit 0\n";

    close(UFILE);
    chmod(0554, $uscript);
    close(DFILE);
    chmod(0554, $dscript);
    return 0;
}

sub RunProxies($$)
{
    my ($vnode_id,$vmid) = @_;

    my (undef,$boss_ip) = tmccbossinfo();
    if (!$boss_ip) {
	$boss_ip = `cat $BOOTDIR/bossip`;
	chomp($boss_ip);
    }
    if (!$boss_ip) {
	warn("could not find bossip anywhere; aborting!");
	return -1;
    }
    my ($host_ip,$host_mask,$vmac) = hostControlNet();

    # Each container gets a tmcc proxy running on another port.  If this
    # changes, make sure to update iptables rules elsewhere in
    # SetupPostCreateIptables and SetupPostBootIptables.
    my $local_tmcd_port = $TMCD_PORT + $vmid;

    # Start a tmcc proxy (handles both TCP and UDP)
    my $tmccpid = fork();
    if ($tmccpid) {
	# Give child a chance to react.
	sleep(1);

	# Make sure it is alive.
	if (waitpid($tmccpid, &WNOHANG) == $tmccpid) {
	    print STDERR "$vnode_id: tmcc proxy failed to start\n";
	    return -1;
	}

	if (open(FD, ">/var/run/tmccproxy-$vnode_id.pid")) {
	    print FD "$tmccpid\n";
	    close(FD);
	}
    }
    else {
	POSIX::setsid();
	
	# XXX make sure we can kill the proxy when done
	local $SIG{TERM} = 'DEFAULT';

	exec("$BINDIR/tmcc.bin -d -t 15 -n $vnode_id ".
	       "  -X $host_ip:$local_tmcd_port -s $boss_ip -p $TMCD_PORT ".
	       "  -o $LOGDIR/tmccproxy.$vnode_id.log");
	die("Failed to exec tmcc proxy"); 
    }

    return 0;
}

# Returns 1 if proxies are running; 0 if not; -1 on error.
sub AreProxiesRunning($$)
{
    my ($vnode_id,$vmid) = @_;

    if (-e "/var/run/tmccproxy-$vnode_id.pid") {
	open(FD,"/var/run/tmccproxy-$vnode_id.pid")
	    or return -1;
	my $pid = <FD>;
	close(FD);
	chomp($pid);
	if (kill(0,$pid) > 0) {
	    return 1;
	}
    }
    return 0;
}

sub KillProxies($$)
{
    my ($vnode_id,$vmid) = @_;

    if (-e "/var/run/tmccproxy-$vnode_id.pid") {
	open(FD,"/var/run/tmccproxy-$vnode_id.pid")
	    or return -1;
	my $pid = <FD>;
	close(FD);
	chomp($pid);
	mysystem2("/bin/kill $pid");
	my $rc = $? >> 8;
	if ($rc == 0) {
	    unlink("/var/run/tmccproxy-$vnode_id.pid");
	}
	return $rc;
    }

    return 0;
}

sub findControlNetVethInfo($$$$;$)
{
    my ($vnode_id,$vip,$vmac,$hostdevref,$hifidxref) = @_;
    my $ifidx;
    my $dev;

    open(FD,"$IP netns exec $vnode_id ip -br link show |");
    while (!eof(FD)) {
	my $line = <FD>;
	chomp($line);
	if ($line =~ /^[^\@]+\@if(\d+).*$vmac.*$/) {
	    $ifidx = $1;
	    last;
	}
    }
    close(FD);
    if (!$ifidx) {
	open(FD,"$IP netns exec $vnode_id ip -br addr show |");
	while (!eof(FD)) {
	    my $line = <FD>;
	    if ($line =~ /^[^\@]+\@if(\d+).*$vip.*$/) {
		$ifidx = $1;
		last;
	    }
	}
	close(FD);
    }
    if (!$ifidx) {
	warn("could not find host control net iface ifidx for $vnode_id!");
	return -1;
    }
    open(FD,"$IP link show |");
    while (!eof(FD)) {
	my $line = <FD>;
	if ($line =~ /^$ifidx: ([^\@]+)\@.*$/) {
	    $dev = $1;
	    last;
	}
    }
    close(FD);
    if (!$dev) {
	warn("could not find host veth iface for $vnode_id!");
	return -1;
    }

    if (defined($hostdevref)) {
	$$hostdevref = $dev;
    }
    if (defined($hifidxref)) {
	$$hifidxref = $ifidx;
    }

    return 0;
}

sub InsertPostBootIptablesRules($$$$)
{
    my ($vnode_id,$vmid,$vnconfig,$private) = @_;

    # Maybe allow routable control network.
    my @rules = ();

    my $IN_CHAIN = "IN_${vnode_id}";
    my $OUT_CHAIN = "OUT_${vnode_id}";
    if (length($IN_CHAIN) > 28) {
	$IN_CHAIN = "I_${vnode_id}";
	$OUT_CHAIN = "O_${vnode_id}";
    }

    my ($vnode_ip,$vnode_mask) =
	($vnconfig->{config}{CTRLIP},$vnconfig->{config}{CTRLMASK});
    my $vnode_mac = fixupMac(ipToMac($vnode_ip));

    #
    # Send packets from the veth into our chains, and vice versa.
    #
    if (!$USE_MACVLAN_CNET) {
	my ($veth,$ifidx);
	if (findControlNetVethInfo($vnode_id,$vnode_ip,$vnode_mac,
				   \$veth,\$ifidx)) {
	    warn("could not find control net veth; aborting!");
	    return -1;
	}
	
	push(@rules,
	     "-I EMULAB-ISOLATION -m physdev --physdev-is-bridged".
	     " --physdev-in $veth -s $vnode_ip -j $OUT_CHAIN");
	push(@rules,
	     "-I EMULAB-ISOLATION -m physdev --physdev-is-bridged".
	     " --physdev-out $veth -j $IN_CHAIN");

	#
	# Another wrinkle. We have to think about packets coming from
	# the container and addressed to the physical host. Send them
	# through OUTGOING chain for filtering, rather then adding
	# another chain. We make sure there are appropriate rules in
	# the OUTGOING chain to protect the host.
	#
	# XXX: We cannot use the input interface or bridge options, cause
	# if the vnode_ip is unroutable, the packet appears to come from
	# eth0, according to iptables logging. WTF!
	# 
	push(@rules,
	     "-A INPUT -s $vnode_ip -j $OUT_CHAIN");

	push(@rules,
	     "-A OUTPUT -d $vnode_ip -j ACCEPT");
    }
    else {
	#
	# XXX: obviously using the vnode's mac address is suboptimal,
	# but it's all we have if we can't label packets coming from a
	# cgroup.
	#
	push(@rules,
	     "-A EMULAB-ISOLATION -s $vnode_ip".
	     " -m mac --mac-source $vnode_mac -j $OUT_CHAIN");
	push(@rules,
	     "-A FORWARD -d $vnode_ip -j $IN_CHAIN");

	#
	# Another wrinkle. We have to think about packets coming from
	# the container and addressed to the physical host. Send them
	# through OUTGOING chain for filtering, rather then adding
	# another chain. We make sure there are appropriate rules in
	# the OUTGOING chain to protect the host.
	# 
	push(@rules,
	     "-A INPUT -s $vnode_ip".
	     " -m mac --mac-source $vnode_mac -j $OUT_CHAIN");
    }

    # Save for easy deletion later.
    my @deleterules = ();
    foreach my $rule (@rules) {
	if ($rule =~ /^(-[AIR]\s+)([A-Za-z][-A-Za-z0-9]*)\s+(.+)$/) {
	    push(@deleterules,"-D $2 $3");
	}
	elsif ($rule =~ /^(-[IR]\s+)([A-Za-z][-A-Za-z0-9]*)\s+\d+\s+(.+)$/) {
	    push(@deleterules,"-D $2 $3");
	}
    }
    if ($debug) {
	TBDebugTimeStamp("scheduling runtime iptables rules for later".
			 " deletion\n:".join("\n",@deleterules));
    }
    $private->{'postboot_iptables_rules'} = \@deleterules;
    print Dumper($private);

    # Install the iptables rules
    TBDebugTimeStamp("InsertPostBootIptablesRules: installing iptables rules");
    if (DoIPtables(@rules)) {
	TBDebugTimeStamp("  failed to install runtime iptables rules");
	return -1;
    }
    TBDebugTimeStamp("  installed runtime iptables rules");

    return 0;
}

sub RemovePostBootIptablesRules($$$$)
{
    my ($vnode_id,$vmid,$vnconfig,$private) = @_;

    # We simply remove whatever we added in InsertPostBootIptablesRules.
    if (exists($private->{'postboot_iptables_rules'})) {
	my @rules = @{$private->{'postboot_iptables_rules'}};

	# Uninstall the iptables rules
	TBDebugTimeStamp("RemovePostBootIptablesRules: removing iptables rules");
	if (DoIPtables(@rules)) {
	    TBDebugTimeStamp("  failed to remove runtime iptables rules");
	    return -1;
	}
	TBDebugTimeStamp("  removed runtime iptables rules");

	delete($private->{'postboot_iptables_rules'});
    }

    return 0;
}

#
# Return MB of memory used by dom0
# Give it at least 256MB of memory.
#
sub hostMemory()
{
    my $memtotal = `grep MemTotal /proc/meminfo`;
    if ($memtotal =~ /^MemTotal:\s*(\d+)\s(\w+)/) {
	my $num = $1;
	my $type = $2;
	if ($type eq "kB") {
	    $num /= 1024;
	}
	$num = int($num);
	return $num;
    }
    die("Could not find host total memory!");
}

#
# Return MB of memory and cores allocated to dom0.
#
sub hostResources()
{
    my $cpus = `grep processor /proc/cpuinfo | wc -l`;
    if ($cpus =~ /^(\d+)/) {
	$cpus = $1;
    }
    else {
	die("Could not find number of CPUs for host!");
    }

    return (hostMemory(),$cpus);
}

#
# Return non-zero if host has swapped to disk.
#
# XXX beware all ye callers! Note that this returns non-zero if host has
# *ever* swapped, not just if it has swapped as a result of recent activity.
# So once a node swaps that first time, for any reason, this will return
# non-zero til the next boot.
#
sub hostSwapping()
{
    my ($total,$free) = (0,0);
    my @lines = `grep Swap /proc/meminfo`;
    chomp(@lines);
    foreach my $line (@lines) {
	if ($line =~ /^SwapTotal:\s*(\d+)\s(\w+)/) {
	    my $num = $1;
	    my $type = $2;
	    if ($type eq "kB") {
		$num /= 1024;
	    }
	    $total = int($num);
	    next;
	}
	if ($line =~ /^SwapFree:\s*(\d+)\s(\w+)/) {
	    my $num = $1;
	    my $type = $2;
	    if ($type eq "kB") {
		$num /= 1024;
	    }
	    $free = int($num);
	    next;
	}
    }
    return ($free < $total) ? 1 : 0;
}

#
# Contruct and returns the jail control net IP of the physical host.
#
sub hostControlNet(;$$)
{
    my ($ctrlip,$ctrlmask) = @_;
    #
    # XXX we use a woeful hack to get the virtual control net address,
    # that is unique. I will assume that control network is never
    # bigger then /16 and so just combine the top of the jail network
    # with the lower half of the control network address.
    #
    my (undef,$vmask,$vgw) = findVirtControlNet();
    if (!defined($ctrlip) || !defined($ctrlip)) {
	(undef, $ctrlip, $ctrlmask) = getControlNet();
    }
    my ($a,$b);

    if ($vgw =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	$a = $1;
	$b = 31;

	my $tmp    = ~inet_aton("255.255.0.0") & inet_aton($ctrlip);
	my $ipbase = inet_ntoa($tmp);

	if ($ipbase =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	    my ($c,$d) = ($3,$4);
	    my ($m1,$m2,$m3,$m4) = (sprintf("%02x",$a),sprintf("%02x",$b),
				    sprintf("%02x",$c),sprintf("%02x",$d));
	    print STDERR "debug: $ipbase\n";
	    return ("$a.$b.$3.$4", $vmask, "02:00:$m1:$m2:$m3:$m4");
	}
    }
    die("hostControlNet: could not create control net virtual IP");
}


#
# If there is a capture running for the indicated vnode, return the pid.
# Otherwise return 0.
#
# Note: we do not use the pidfile here! This is all about sanity checking.
#
sub captureRunning($)
{
    my ($vnode_id) = @_;
    my $LOGPATH = "$VMDIR/$vnode_id";

    my $rpid = `pgrep -f '^$CAPTURE .*-l $LOGPATH $vnode_id'`;
    if ($? == 0) {
	chomp($rpid);
	if ($rpid =~ /^(\d+)$/) {
	    return $1;
	}
    }

    return 0;
}

sub captureStart($$)
{
    my ($vnode_id,$ptyfile) = @_;
    my $LOGPATH = "$VMDIR/$vnode_id";
    my $acl = "$LOGPATH/$vnode_id.acl";
    my $logfile = "$LOGPATH/$vnode_id.log";
    my $pidfile = "$LOGPATH/$vnode_id.pid";

    # unlink ACL file so that we know when capture has started
    unlink($acl)
	if (-e $acl);

    # remove old log file before start
    unlink($logfile)
	if (-e $logfile);

    # and old pid file
    unlink($pidfile)
	if (-e $pidfile);

    TBDebugTimeStamp("captureStart: starting capture on pty symlink $ptyfile");

    # XXX see start of file for meaning of the options
    mysystem2("$CAPTURE $CAPTUREOPTS -l $LOGPATH $vnode_id $ptyfile");

    #
    # We need to report the ACL info to capserver via tmcc. But do not
    # hang, use timeout. Also need to wait for the acl file, since
    # capture is running in the background. 
    #
    if (! $?) {
	for (my $i = 0; $i < 10; $i++) {
	    last
		if (-e $acl && -s $acl);
	    print "waiting 1 sec for capture ACL file...\n" if ($sleepdebug);
	    sleep(1);
	}
	if (! (-e $acl && -s $acl)) {
	    print STDERR "WARNING: $acl does not exist after 10 seconds; ".
		"capture may not have started correctly.\n";
	}
	else {
	    if (mysystem2("$BINDIR/tmcc.bin -n $vnode_id -t 5 ".
			  "   -f $acl tiplineinfo")) {
		print STDERR "WARNING: could not report tiplineinfo; ".
		    "remote console connections may not work.\n";
	    }
	}
    } else {
	print STDERR "WARNING: capture not started!\n";
    }
}

# convert 123456 into 12:34:56
sub fixupMac($)
{
    my ($x) = @_;
    $x =~ s/(\w\w)/$1:/g;
    chop($x);
    return $x;
}

#
# Create a thin pool that uses most of the VG space.
#
# This is tricky if there are multiple PVs and they are different sizes.
# We cannot create the pool larger than M * N where M is the number of
# disks and N is the free space on the smallest disk.
#
sub createThinPool($)
{
    my ($devs) = @_;

    #
    # Find the PV with the least available space
    #
    my $smallest;
    my $num = 0;
    my $tsize = 0;
    foreach my $dsize (`pvs --noheadings -o pv_free $devs`) {
	if ($dsize =~ /(\d+\.\d+)([mgt])/i) {
	    $dsize = $1;
	    my $u = lc($2);
	    if ($u eq "m") {
		$dsize /= 1000;
	    } elsif ($u eq "t") {
		$dsize *= 1000;
	    }
	    $tsize += $dsize;
	    if (!defined($smallest) || $dsize < $smallest) {
		$smallest = $dsize;
	    }
	} else {
	    print STDERR "createThinPool: could not parse PV size '$dsize'\n";
	    return -1;
	}
	$num++;
    }

    #
    # Arbitrary conventions:
    #   - don't use more than 80% of the smallest device
    #   - leave at least 50g total for others
    #   - pool should be at least 100g
    #
    my $poolsize = int($num * ($smallest * $POOL_FRAC));
    if ($poolsize > ($tsize - 50)) {
	$poolsize = $tsize - 50;
    }
    if ($poolsize < 100) {
	print STDERR "createThinPool: ${poolsize}g is not enough space ".
	    "for a reasonably sized thin pool\n";
	return -1;
    }

    # Try to make it
    if (mysystem2("lvcreate -i$num -L ${poolsize}g ".
		  "--type thin-pool --thinpool $POOL_NAME $VGNAME")) {
	print STDERR "createThinPool: could not create ${poolsize}g ".
	    "thin pool\n";
	return -1;
    }

    return 0;
}

sub lvmConvertSize($)
{
    my ($sizestr) = @_;
    my $size;

    if ($sizestr =~ /(\d+\.\d+)([mgt])/i) {
	$size = $1;
	my $u = lc($2);
	if ($u eq "m") {
	    $size /= 1000;
	} elsif ($u eq "t") {
	    $size *= 1000;
	}
    }

    return $size;
}

#
# Return size of volume group in (decimal, aka disk-manufactuer) GB.
#
sub lvmVGSize($)
{
    my ($vg) = @_;

    my $size = `vgs --noheadings -o size $vg`;
    $size = lvmConvertSize($size);
    return $size
	if (defined($size));
    die "libvnode_docker: cannot parse LVM volume group size";
}

sub lvmVGPVCount($)
{
    my ($vg) = @_;

    my @lines = `pvs -S "vg_name=$vg" --no-headings`;

    return scalar(@lines);
}

#
# Return the max LV size for the given VG, modulo stripe size -- but NB
# we only support the case where stripe size == # PVs in VG.  We are not
# going to play the game of emulating the choice of *which* PVs to
# stripe across if #stripes < #PVs in VG.  Anyway, this makes it simple;
# if #stripes == #PVs in VG, the max possible LV = least free space on
# any PV in the VG * #stripes.
#
sub lvmVGMaxPossibleLVSize($;$)
{
    my ($vg,$dofree) = @_;

    if (!defined($dofree)) {
	$dofree = 0;
    }
    my $stripes = computeStripeSize($vg);
    my $pvcount = lvmVGPVCount($vg);

    return undef
	if ($stripes != $pvcount);

    my $min;
    my $total = 0;
    my $kwname = "size";
    if ($dofree) {
	$kwname = "free";
    }
    foreach my $line (`pvs -S "vg_name=$vg" -o $kwname --no-headings`) {
	chomp($line);
	if ($line =~ /^\s*(\d+\.\d+[mgt])$/i) {
	    my $sz = lvmConvertSize($1);
	    if (defined($sz)) {
		if (!defined($min) || $sz < $min) {
		    $min = $sz;
		}
		$total += $sz;
	    }
	}
    }

    if ($stripes == 1) {
	return $total;
    }
    else {
	return $stripes * $min;
    }
}

#
# Deal with IFBs.  We add and remove them dynamically, per-VM.  They are
# named like ifb<VMID>-<i>.  We don't bother naming them per lanlink or
# anything; we might run into the 15-character limit too easily anyway.
#
my $IFB_LOCK = "ifblock";

sub AllocateIFBs($$$)
{
    my ($vmid, $node_lds, $private) = @_;
    my @ifbs = ();

    TBDebugTimeStamp("AllocateIFBs: grabbing global lock $IFB_LOCK")
	if ($lockdebug);
    if (TBScriptLock($IFB_LOCK, TBSCRIPTLOCK_INTERRUPTIBLE(),
		     1800) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the global lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got global lock")
	if ($lockdebug);

    my %MDB;
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	TBScriptUnlock();
	return undef;
    }

    #
    # We need an IFB for every ld; allocate them if they don't exist.
    # If they *do* exist, just steal them and warn; nothing else would
    # be using them except a stale vnode, and those should be garbage
    # collected before the new vnode of the same node comes into
    # existence.
    #
    my $needed = scalar(@$node_lds);
    for (my $i = 0; $i < $needed; ++$i) {
	my $iname = "ifb$vmid-$i";
	if (defined($MDB{"$iname"}) && $MDB{"$iname"} eq "$vmid") {
	    if (-e "/sys/class/net/$iname") {
		warn("$iname device already exists for linkdelay $i; stealing!");
	    }
	    else {
		warn("$iname DB entry already exists for linkdelay $i; stealing!");
	    }
	}
	if (! -e "/sys/class/net/$iname") {
	    mysystem("$IP link add $iname type ifb");
	}
	$MDB{"$iname"} = $vmid;
	# Record ifb in use
	$private->{'ifbs'}->{$iname} = $i;
	push(@ifbs, $iname);
    }
    dbmclose(%MDB);
    TBDebugTimeStamp("  releasing global lock")
	if ($lockdebug);
    TBScriptUnlock();
    return \@ifbs;
}

sub ReleaseIFBs($$)
{
    my ($vmid, $private) = @_;
    
    TBDebugTimeStamp("ReleaseIFBs: grabbing global lock $IFB_LOCK")
	if ($lockdebug);
    if (TBScriptLock($IFB_LOCK, 0, 1800) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get the global lock after a long time!\n";
	return -1;
    }
    TBDebugTimeStamp("  got global lock")
	if ($lockdebug);

    my %MDB;
    if (!dbmopen(%MDB, $IFBDB, 0660)) {
	print STDERR "*** Could not create $IFBDB\n";
	TBScriptUnlock();
	return -1;
    }

    if (exists($private->{'ifbs'})) {
	for my $iname (keys(%{$private->{'ifbs'}})) {
	    mysystem("$IP link del $iname");	
	delete($MDB{$iname});
	}
    }
    #
    # Make sure we have released everything assigned to this vmid. 
    #
    my @leftoverdbkeys = ();
    for my $iname (keys(%MDB)) {
	if ($MDB{$iname} eq "$vmid") {
	    push(@leftoverdbkeys,$iname);
	}
    }
    for my $iname (@leftoverdbkeys) {
	delete($MDB{$iname});
    }
    dbmclose(%MDB);
    TBDebugTimeStamp("  releasing global lock")
	if ($lockdebug);
    TBScriptUnlock();
    delete($private->{'ifbs'});
    return 0;
}

#
# Run a function with vnodesetup/mkvnode signals blocked.
#
sub RunWithSignalsBlocked($@) {
    my ($funcref,@args) = @_;
    
    #
    # Block signals that could kill us in the middle of some important
    # operation.  This ensure that if we have to tear down in the middle
    # of setting up, the state is consistent.
    #
    my $new_sigset = POSIX::SigSet->new(SIGHUP, SIGINT, SIGUSR1, SIGUSR2);
    my $old_sigset = POSIX::SigSet->new;
    if (! defined(sigprocmask(SIG_BLOCK, $new_sigset, $old_sigset))) {
	print STDERR "sigprocmask (BLOCK) failed!\n";
    }

    my $rc = $funcref->(@args);

    if (! defined(sigprocmask(SIG_SETMASK, $old_sigset))) {
	print STDERR "sigprocmask (UNBLOCK) failed!\n";
    }

    return $rc;
}

#
# Helper function to run a shell command wrapped by a lock.
#
sub RunWithLock($$)
{
    my ($token, $command) = @_;
    my $lockref;

    if (TBScriptLock($token, undef, 900, \$lockref) != TBSCRIPTLOCK_OKAY()) {
	print STDERR "Could not get $token lock after a long time!\n";
	return -1;
    }
    mysystem2($command);
    my $status = $?;
    print "waiting 1 sec after RunWithLock...\n" if ($sleepdebug);
    sleep(1);

    TBScriptUnlock($lockref);
    return $status;
}

sub checkForInterrupt()
{
    my $sigset = POSIX::SigSet->new;
    sigpending($sigset);

    # XXX Why isn't SIGRTMIN and SIGRTMAX defined in the POSIX module.
    for (my $i = 1; $i < 50; $i++) {
	if ($sigset->ismember($i)) {
	    print "checkForInterrupt: Signal $i is pending\n";
	    return 1;
	}
    }
    return 0;
}

#
# We need to control how many simultaneous creates happen at once.
#
my $createvnode_lockref;

sub CreateVnodeLock()
{
    my $tries = 1000;

    # Figure out how many vnodeCreates we can support at once
    setConcurrency(0);

    while ($tries) {
	for (my $i = 0; $i < $MAXCONCURRENT; $i++) {
	    my $token  = "createvnode_${i}";
	    TBDebugTimeStamp("grabbing vnode lock $token")
		if ($lockdebug);
	    my $locked = TBScriptLock($token, TBSCRIPTLOCK_NONBLOCKING(),
				      0, \$createvnode_lockref);

	    if ($locked == TBSCRIPTLOCK_OKAY()) {
		TBDebugTimeStamp("  got vnode lock")
		    if ($lockdebug);
		return 0
	    }
	    return -1
		if ($locked == TBSCRIPTLOCK_FAILED());
	}
	print "Still trying to get the create lock at " . time() . "\n"
	    if (($tries % 60) == 0);
	return -1
	    if (checkForInterrupt());
	sleep(4);
	return -1
	    if (checkForInterrupt());
	$tries--;
    }
    TBDebugTimeStamp("Could not get the createvnode lock after a long time!");
    return -1;
}

sub CreateVnodeUnlock()
{
    TBDebugTimeStamp("  releasing vnode lock")
	if ($lockdebug);
    TBScriptUnlock($createvnode_lockref);
}

sub CreateVnodeLockAll()
{
    my @locks;
    my $lockref;
    
    # Determine the maximum concurrency
    setConcurrency(1);

    for (my $i = 0; $i < $MAXCONCURRENT; $i++) {
	my $token  = "createvnode_${i}";
	if (TBScriptLock($token, TBSCRIPTLOCK_NONBLOCKING(), 0, \$lockref) ==
	    TBSCRIPTLOCK_OKAY()) {
	    push(@locks, $lockref);
	}
	else {
	    # Release all.
	    foreach my $ref (@locks) {
		TBScriptUnlock($ref);
	    }
	    return undef;
	}
    }
    return \@locks;
}

sub CreateVnodeUnlockAll($)
{
    my ($plocks) = @_;
    my @locks    = @$plocks;

    # Release all.
    foreach my $ref (@locks) {
	TBScriptUnlock($ref);
    }
}

1;
