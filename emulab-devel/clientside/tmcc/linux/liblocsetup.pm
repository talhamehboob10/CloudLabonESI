#!/usr/bin/perl -wT
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

#
# Linux specific routines and constants for the client bootime setup stuff.
#
package liblocsetup;
use Exporter;
@ISA = "Exporter";
@EXPORT =
    qw ( $CP $EGREP $NFSMOUNT $UMOUNT $TMPASSWD $SFSSD $SFSCD $RPMCMD
	 $HOSTSFILE $LOOPBACKMOUNT $TMGROUP $TMSHADOW $TMGSHADOW $CHMOD
	 os_account_cleanup os_ifconfig_line os_etchosts_line
	 os_setup os_groupadd os_useradd os_userdel os_usermod os_mkdir
	 os_ifconfig_veth os_viface_name os_modpasswd
	 os_routing_enable_forward os_routing_enable_gated
	 os_routing_add_manual os_routing_del_manual os_homedirdel
	 os_groupdel os_getnfsmounts os_islocaldir os_mountextrafs
	 os_fwconfig_line os_fwrouteconfig_line os_config_gre
	 os_get_disks os_get_disk_size os_get_partition_info os_nfsmount
	 os_get_ctrlnet_ip
	 os_getarpinfo os_createarpentry os_removearpentry
	 os_getstaticarp os_setstaticarp os_ismounted os_unmount os_mount
       );

sub VERSION()	{ return 1.0; }

# Must come after package declaration!
use English;
use Fcntl;

# Load up the paths. Its conditionalized to be compatabile with older images.
# Note this file has probably already been loaded by the caller.
BEGIN
{
    if (-e "/etc/emulab/paths.pm") {
	require "/etc/emulab/paths.pm";
	import emulabpaths;
    }
    else {
	my $ETCDIR  = "/etc/rc.d/testbed";
	my $BINDIR  = "/etc/rc.d/testbed";
	my $VARDIR  = "/etc/rc.d/testbed";
	my $BOOTDIR = "/etc/rc.d/testbed";
    }
}

# Convenience.
sub REMOTE()	{ return libsetup::REMOTE(); }
sub REMOTEDED()	{ return libsetup::REMOTEDED(); }
sub PLAB()	{ return libsetup::PLAB(); }
sub LINUXJAILED()  { return libsetup::LINUXJAILED(); }
sub GENVNODE()     { return libsetup::GENVNODE(); }
sub GENVNODETYPE() { return libsetup::GENVNODETYPE(); }
sub INXENVM()   { return libsetup::INXENVM(); }
sub INVZVM()    { return libsetup::INVZVM(); }
sub INDOCKERVM()    { return libsetup::INDOCKERVM(); }

#
# Various programs and things specific to Linux and that we want to export.
#
$CP		= "/bin/cp";
$DF		= "/bin/df";
$EGREP		= "/bin/egrep -q";
# Note that we try multiple versions in os_nfsmount below; this is for legacy
# code, or code where the mount is best done in the caller itself... or code
# I didn't want to convert!
$NFSMOUNT	= "/bin/mount -o nolock,udp";
$LOOPBACKMOUNT	= "/bin/mount -n -o bind ";
$UMOUNT		= "/bin/umount";
$MOUNT		= "/bin/mount";
$TMPASSWD	= "$ETCDIR/passwd";
$TMGROUP	= "$ETCDIR/group";
$TMSHADOW       = "$ETCDIR/shadow";
$TMGSHADOW      = "$ETCDIR/gshadow";
$SFSSD		= "/usr/local/sbin/sfssd";
$SFSCD		= "/usr/local/sbin/sfscd";
$RPMCMD		= "/bin/rpm";
$HOSTSFILE	= "/etc/hosts";
$WGET		= "/usr/bin/wget";
$CHMOD		= "/bin/chmod";
$ARP		= "/sbin/arp";

#
# These are not exported
#
my $TMGROUP	= "$ETCDIR/group";
my $TMSHADOW    = "$ETCDIR/shadow";
my $TMGSHADOW   = "$ETCDIR/gshadow";
my $USERADD     = "/usr/sbin/useradd";
my $USERDEL     = "/usr/sbin/userdel";
my $USERMOD     = "/usr/sbin/usermod";
my $GROUPADD	= "/usr/sbin/groupadd";
my $GROUPDEL	= "/usr/sbin/groupdel";
my $IPBIN       = "/sbin/ip";
my $IFCONFIGBIN = "/sbin/ifconfig";
my $IFCONFIG    = "$IFCONFIGBIN %s inet %s netmask %s %s";
my $VLANCONFIG  = "/sbin/vconfig";
# XXX 10000 is probably not right, but we don't use mii-tool here
my $IFC_10000MBS = "10000baseTx";
my $IFC_1000MBS  = "1000baseTx";
my $IFC_100MBS  = "100baseTx";
my $IFC_10MBS   = "10baseT";
my $IFC_FDUPLEX = "FD";
my $IFC_HDUPLEX = "HD";
my $IFC_AUTO    = "$IFC_1000MBS,$IFC_100MBS,$IFC_10MBS";
my $IFC_1500MTU = "mtu 1500";
my $IFC_9000MTU = "mtu 9000";
my @LOCKFILES   = ("/etc/group.lock", "/etc/gshadow.lock");
my $MKDIR	= "/bin/mkdir";
my $GATED	= "/usr/sbin/gated";
my $ROUTE	= "/sbin/route";
my $SHELLS	= "/etc/shells";
my $DEFSHELL	= "/bin/tcsh";
my $IWCONFIG    = '/usr/local/sbin/iwconfig';
my $WLANCONFIG  = '/usr/local/bin/wlanconfig';
my $RMMOD       = '/sbin/rmmod';
my $MODPROBE    = '/sbin/modprobe';
my $IWPRIV      = '/usr/local/sbin/iwpriv';
my $BRCTL       = "/usr/sbin/brctl";
my $ISCSI	= "/sbin/iscsiadm";

my $PASSDB   = "$VARDIR/db/passdb";
my $GROUPDB  = "$VARDIR/db/groupdb";
my $SYSETCDIR = "/etc";

my $debug = 0;

#
# OS dependent part of cleanup node state.
#
sub os_account_cleanup($)
{
    # XXX this stuff should be lifted up into rc.accounts, sigh
    my ($updatemasterpasswdfiles) = @_;
    if (!defined($updatemasterpasswdfiles)) {
	$updatemasterpasswdfiles = 0;
    }

    #
    # Don't just splat the master passwd/group files into place from $ETCDIR.
    # Instead, grab the current Emulab uids/gids, grab the current group/passwd
    # files and their shadow counterparts, remove any emulab u/gids from the
    # loaded instance of the current files, then push any new/changed uid/gids
    # into the master files in $ETCDIR.  Also, we remove accounts from the
    # master files if they no longer appear in the current files.  Finally, we
    # strip deleted uids from any groups they might appear in (!).
    #
    # And now we only do the merge if told to do so.  This is the default 
    # coming from prepare, now.  If not merging, we just overwrite the real 
    # files with the master files -- we do not update the master files.
    #
    # We *do* output the diff to say what *would* have changed, so that
    # an operator can know that they need to manually add a user to the 
    # master files.
    #
    my %PDB;
    my %GDB;

    dbmopen(%PDB, $PASSDB, 0660) or
	die "Cannot open $PASSDB: $!";
    dbmopen(%GDB, $GROUPDB, 0660) or
	die "Cannot open $GROUPDB: $!";

    if ($debug) {
	use Data::Dumper;
	print Dumper(%PDB) . "\n\n";
	print Dumper(%GDB) . "\n\n";
    }

    my %lineHash = ();
    my %lineList = ();

    foreach my $file ("$SYSETCDIR/passwd","$SYSETCDIR/group",
		      "$SYSETCDIR/shadow","$SYSETCDIR/gshadow",
		      "$ETCDIR/passwd","$ETCDIR/group",
		      "$ETCDIR/shadow","$ETCDIR/gshadow") {
	open(FD,$file)
	    or die "open($file): $!";
	my $i = 0;
	my $lineCounter = 1;
	while (my $line = <FD>) {
	    chomp($line);

	    # store the line in the list
	    if (!defined($lineList{$file})) {
		$lineList{$file} = [];
	    }
	    $lineList{$file}->[$i] = $line;

	    # fill the hash for fast lookups, and place the array idx of the
	    # element in the lineList as the hash value so that we can undef
	    # it if deleting it, while still preserving the line orderings in
	    # the original files.  whoo!
	    if ($line ne '' && $line =~ /^([^:]+):.*$/) {
		if (!defined($lineHash{$file})) {
		    $lineHash{$file} = {};
		}
		$lineHash{$file}->{$1} = $i++;
	    }
	    else {
		print STDERR "malformed line $lineCounter in $file, ignoring!\n";
	    }
	    ++$lineCounter;
	}
    }

    print Dumper(%lineHash) . "\n\n\n"
	if ($debug);

    # remove emulab groups first (save a bit of work):
    while (my ($group,$gid) = each(%GDB)) {
	print "DEBUG: $group/$gid\n"
	    if ($debug);
	foreach my $file ("$SYSETCDIR/group","$SYSETCDIR/gshadow") {
	    if (defined($lineHash{$file}->{$group})) {
		# undef its line
		$lineList{$file}->[$lineHash{$file}->{$group}] = undef;
		delete $lineHash{$file}->{$group};
		print "DEBUG: deleted group $group from $file\n"
		    if ($debug);
	    }
	}
    }

    # now remove emulab users from users files, AND from the group list
    # in any groups :-)
    while (my ($user,$uid) = each(%PDB)) {
	foreach my $file ("$SYSETCDIR/passwd","$SYSETCDIR/shadow") {
	    if (defined($lineHash{$file}->{$user})) {
		# undef its line
		$lineList{$file}->[$lineHash{$file}->{$user}] = undef;
		delete $lineHash{$file}->{$user};
		print "DEBUG: deleted user  $user from $file\n"
		    if ($debug);
	    }
	}

	# this is indeed a lot of extra text processing, but whatever
	foreach my $file ("$SYSETCDIR/group","$SYSETCDIR/gshadow") {
	    foreach my $group (keys(%{$lineHash{$file}})) {
		my $groupLine = $lineList{$file}->[$lineHash{$file}->{$group}];
		# grab the fields
		# split using -1 to make sure our empty trailing fields are
		# added!
		my @elms = split(/\s*:\s*/,$groupLine,-1);
		# grab the user list
		my @ulist = split(/\s*,\s*/,$elms[scalar(@elms)-1]);
		# build a new list
		my @newulist = ();
		my $j = 0;
		my $k = 0;
		for ($j = 0; $j < scalar(@ulist); ++$j) {
		    # only add to the new user list if it's not the user we're
		    # removing.
		    my $suser = $ulist[$j];
		    if ($suser ne $user) {
			$newulist[$k++] = $suser;
		    }
		}
		# rebuild the user list
		$elms[scalar(@elms)-1] = join(',',@newulist);
		# rebuild the line from the fields
		$groupLine = join(':',@elms);
		# stick the line back into the "file"
		$lineList{$file}->[$lineHash{$file}->{$group}] = $groupLine;
	    }
	}
    }

    # now, merge current files into masters.
    foreach my $pairRef (["$SYSETCDIR/passwd","$ETCDIR/passwd"],
			 ["$SYSETCDIR/group","$ETCDIR/group"],
			 ["$SYSETCDIR/shadow","$ETCDIR/shadow"],
			 ["$SYSETCDIR/gshadow","$ETCDIR/gshadow"]) {
	my ($real,$master) = @$pairRef;

	foreach my $ent (keys(%{$lineHash{$real}})) {
	    # push new entities into master
	    if (!defined($lineHash{$master}->{$ent})) {
		# append new "line"
		$lineHash{$master}->{$ent} = scalar(@{$lineList{$master}});
		$lineList{$master}->[$lineHash{$master}->{$ent}] =
		    $lineList{$real}->[$lineHash{$real}->{$ent}];
		print "DEBUG: adding $ent to $master\n"
		    if ($debug);
	    }
	    # or replace modified entities
	    elsif ($lineList{$real}->[$lineHash{$real}->{$ent}]
		   ne $lineList{$master}->[$lineHash{$master}->{$ent}]) {
		$lineList{$master}->[$lineHash{$master}->{$ent}] =
		    $lineList{$real}->[$lineHash{$real}->{$ent}];
		print "DEBUG: updating $ent in $master\n"
		    if ($debug);
	    }
	}

	# now remove stale lines from the master
	my @todelete = ();
	foreach my $ent (keys(%{$lineHash{$master}})) {
	    if (!defined($lineHash{$real}->{$ent})) {
		# undef its line
		$lineList{$master}->[$lineHash{$master}->{$ent}] = undef;
		push @todelete, $ent;
	    }
	}
	foreach my $delent (@todelete) {
	    delete $lineHash{$master}->{$delent};
	}
    }

    # now write the masters to .new files so we can diff, do the diff for
    # files that are world-readable, then mv into place over the masters.
    my %modes = ( "$ETCDIR/passwd" => 0644,"$ETCDIR/group" => 0644,
		  "$ETCDIR/shadow" => 0600,"$ETCDIR/gshadow" => 0600 );
    foreach my $file (keys(%modes)) {
	sysopen(FD,"${file}.new",O_CREAT | O_WRONLY | O_TRUNC,$modes{$file})
	    # safe to die here cause we haven't moved any .new files into
	    # place
	    or die "sysopen(${file}.new): $!";
	for (my $i = 0; $i < scalar(@{$lineList{$file}}); ++$i) {
	    # remember, some lines may be undef cause we deleted them
	    if (defined($lineList{$file}->[$i])) {
		print FD $lineList{$file}->[$i] . "\n";
	    }
	}
	close(FD);
    }
    foreach my $file (keys(%modes)) {
	my $retval;
	if ($modes{$file} == 0644) {
	    print STDERR "Running 'diff -u $file ${file}.new'\n";
	    $retval = system("diff -u $file ${file}.new");
	    if ($retval) {
		if ($updatemasterpasswdfiles) {
		    print STDERR "Files ${file}.new and $file differ; updating $file.\n";
		    system("mv ${file}.new $file");
		}
		else {
		    print STDERR "Files ${file}.new and $file differ, but I was told not to update the master files!.\n";
		    system("rm -f ${file}.new");
		}
	    }
	    else {
		system("rm -f ${file}.new");
	    }
	}
	else {
	    print STDERR "Running 'diff -q -u $file ${file}.new'\n";
	    $retval = system("diff -q -u $file ${file}.new");
	    if ($retval) {
		if ($updatemasterpasswdfiles) {
		    print STDERR "Files ${file}.new and $file differ, but we can't show the changes!  Updating $file anyway!\n";
		    system("mv ${file}.new $file");
		}
		else {
		    print STDERR "Files ${file}.new and $file differ, but we can't show the changes, and I was told not to update the master files!\n";
		    system("rm -f ${file}.new");
		}
	    }
	    else {
		system("rm -f ${file}.new");
	    }
	}
    }

    dbmclose(%PDB);
    dbmclose(%GDB);

    #
    # Splat the new files into place, doh
    #
    unlink @LOCKFILES;

    printf STDOUT "Resetting passwd and group files\n";
    if (system("$CP -f $TMGROUP $TMPASSWD /etc") != 0) {
        print STDERR "Could not copy default group file into place: $!\n";
        return -1;
    }

    if (system("$CP -f $TMSHADOW $TMGSHADOW /etc") != 0) {
        print STDERR "Could not copy default passwd file into place: $!\n";
        return -1;
    }

    return 0;
}

#
# Generate and return an ifconfig line that is approriate for putting
# into a shell script (invoked at bootup).
#
sub os_ifconfig_line($$$$$$$$;$$$%)
{
    my ($iface, $inet, $mask, $speed, $duplex, $aliases, $iface_type, $lan,
	$mtu, $settings, $rtabid, $cookie) = @_;
    my ($miirest, $miisleep, $miisetspd, $media, $mtuopt);
    my ($uplines, $downlines);

    #
    # Inside a container, we get a regular interface, but tmcd sets the
    # type=gre so we know to set the MTU properly. This number seems to
    # work for both openvz and xen containers. 
    #
    if ($iface_type eq "gre" && GENVNODE()) {
	$uplines   = "$IFCONFIGBIN $iface $inet netmask $mask mtu 1450 up";
	$downlines = "$IFCONFIGBIN $iface down";
	return ($uplines, $downlines);
    }

    #
    # Special handling for new style interfaces (which have settings).
    # This should all move into per-type modules at some point.
    #
    if ($iface_type eq "ath" && defined($settings)) {

        # Get a handle on the "VAP" interface we will create when
        # setting up this interface.
        my ($ifnum) = $iface =~ /wifi(\d+)/;
        my $athiface = "ath" . $ifnum;

	#
	# Setting the protocol is special and appears to be card specific.
	# How stupid is that!
	#
	my $protocol = $settings->{"protocol"};
        my $privcmd = "/usr/local/sbin/iwpriv $athiface mode ";

        SWITCH1: for ($protocol) {
          /^80211a$/ && do {
              $privcmd .= "1";
              last SWITCH1;
          };
          /^80211b$/ && do {
              $privcmd .= "2";
              last SWITCH1;
          };
          /^80211g$/ && do {
              $privcmd .= "3";
              last SWITCH1;
          };
        }

	#
	# At the moment, we expect just the various flavors of 80211, and
	# we treat them all the same, configuring with iwconfig and iwpriv.
	#
	my $iwcmd = "/usr/local/sbin/iwconfig $athiface ";
        my $wlccmd = "/usr/local/bin/wlanconfig $athiface create ".
            "wlandev $iface ";

	#
	# We demand to be given an ssid.
	#
	if (!exists($settings->{"ssid"})) {
	    warn("*** WARNING: No SSID provided for $iface!\n");
	    return undef;
	}
	$iwcmd .= "essid ". $settings->{"ssid"};

	# If we do not get a channel, pick one.
	if (exists($settings->{"channel"})) {
	    $iwcmd .= " channel " . $settings->{"channel"};
	}
	else {
	    $iwcmd .= " channel 3";
	}

	# txpower and rate default to auto if not specified.
	if (exists($settings->{"rate"})) {
	    $iwcmd .= " rate " . $settings->{"rate"};
	}
	else {
	    $iwcmd .= " rate auto";
	}
	if (exists($settings->{"txpower"})) {
	    $iwcmd .= " txpower " . $settings->{"txpower"};
	}
	else {
	    $iwcmd .= " txpower auto";
	}
	# Allow this too.
	if (exists($settings->{"sens"})) {
	    $iwcmd .= " sens " . $settings->{"sens"};
	}

	# allow rts threshold and frag size
	if (exists($settings->{'rts'})) {
	    $iwcmd .= ' rts ' . $settings->{'rts'};
	}
	if (exists($settings->{'frag'})) {
	    $iwcmd .= ' frag ' . $settings->{'frag'};
	}

	#
	# We demand to be told if we are the master or a peon.
	# We might also be in another mode.  Thus, if accesspoint is specified,
	# we assume we are in either ap/sta (Master/Managed) mode.  If not,
	# we look for a 'mode' argument and assume adhoc if we don't get one.
	# The reason to assume adhoc is because we need accesspoint set to
	# know how to configure the device for ap/sta modes, and setting a
	# device to monitor mode by default sucks.
	#
	# This needs to be last for some reason.
	#
	if (exists($settings->{'accesspoint'})) {
	    my $accesspoint = $settings->{"accesspoint"};
	    my $accesspointwdots;

	    # Allow either dotted or undotted notation!
	    if ($accesspoint =~ /^(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})$/) {
		$accesspointwdots = "$1:$2:$3:$4:$5:$6";
	    }
	    elsif ($accesspoint =~
		   /^(\w{2}):(\w{2}):(\w{2}):(\w{2}):(\w{2}):(\w{2})$/) {
		$accesspointwdots = $accesspoint;
		$accesspoint      = "${1}${2}${3}${4}${5}${6}";
	    }
	    else {
		warn("*** WARNING: Improper format for MAC ($accesspoint) ".
		     "provided for $iface!\n");
		return undef;
	    }

	    if (libsetup::findiface($accesspoint) eq $iface) {
		$wlccmd .= " wlanmode ap";
		$iwcmd .= " mode Master";
	    }
	    else {
		$wlccmd .= " wlanmode sta";
		$iwcmd .= " mode Managed ap $accesspointwdots";
	    }
	}
	elsif (exists($settings->{'mode'})) {
	    if ($settings->{'mode'} =~ /ad[\s\-]*hoc/i) {
		$wlccmd .= " wlanmode adhoc";
		$iwcmd .= " mode Ad-Hoc";
	    }
	    elsif ($settings->{'mode'} =~ /monitor/i) {
		$wlccmd .= " wlanmode monitor";
		$iwcmd .= " mode Monitor";
	    }
	    elsif ($settings->{'mode'} =~ /ap/i
		   || $settings->{'mode'} =~ /access[\s\-]*point/i
		   || $settings->{'mode'} =~ /master/i) {
		$wlccmd .= " wlanmode ap";
		$iwcmd .= " mode Master";
	    }
	    elsif ($settings->{'mode'} =~ /sta/i
		   || $settings->{'mode'} =~ /managed/i) {
		$wlccmd .= " wlanmode sta";
		$iwcmd .= " mode Managed ap any";
	    }
	    else {
		warn("*** WARNING: Invalid mode provided for $iface!\n");
		return undef;
	    }
	}
	else {
	    warn("*** WARNING: No mode implied for $iface!\n");
	    return undef;
	}

        $uplines   = $wlccmd . "\n";
	$uplines  .= $privcmd . "\n";
	$uplines  .= $iwcmd . "\n";
	$uplines  .= sprintf($IFCONFIG, $athiface, $inet, $mask, "") . "\n";
	$downlines  = "$IFCONFIGBIN $athiface down\n";
	$downlines .= "$WLANCONFIG $athiface destroy\n";
	$downlines .= "$IFCONFIGBIN $iface down\n";
	return ($uplines, $downlines);
    }

    #
    # GNU Radio network interface on the flex900 daugherboard
    #
    if ($iface_type eq "flex900" && defined($settings)) {

        my $tuncmd =
            "/bin/env PYTHONPATH=/usr/local/lib/python2.4/site-packages ".
            "$BINDIR/tunnel.py";

        if (!exists($settings->{"mac"})) {
            warn("*** WARNING: No mac address provided for gnuradio ".
                 "interface!\n");
            return undef;
        }

        my $mac = $settings->{"mac"};

        if (!exists($settings->{"protocol"}) ||
            $settings->{"protocol"} ne "flex900") {
            warn("*** WARNING: Unknown gnuradio protocol specified!\n");
            return undef;
        }

        if (!exists($settings->{"frequency"})) {
            warn("*** WARNING: No frequency specified for gnuradio ".
                 "interface!\n");
            return undef;
        }

        my $frequency = $settings->{"frequency"};
        $tuncmd .= " -f $frequency";

        if (!exists($settings->{"rate"})) {
            warn("*** WARNING: No rate specified for gnuradio interface!\n");
            return undef;
        }

        my $rate = $settings->{"rate"};
        $tuncmd .= " -r $rate";

	if (exists($settings->{'carrierthresh'})) {
	    $tuncmd .= " -c " . $settings->{'carrierthresh'};
	}
	if (exists($settings->{'rxgain'})) {
	    $tuncmd .= " --rx-gain=" . $settings->{'rxgain'};
	}

        $uplines = $tuncmd . " > /dev/null 2>&1 &\n";
        $uplines .= "sleep 5\n";
        $uplines .= "$IFCONFIGBIN $iface hw ether $mac\n";
        $uplines .= sprintf($IFCONFIG, $iface, $inet, $mask, "") . "\n";
        $downlines = "$IFCONFIGBIN $iface down";
        return ($uplines, $downlines);
    }

    #
    # Only do this stuff if we have a physical interface, otherwise it doesn't
    # mean anything.  We need this for virtnodes whose networks must be
    # config'd from inside the container, vm, whatever.
    #
    $mtuopt = "";
    if ($iface_type ne 'veth') {
        #
        # Need to check units on the speed. Just in case.
        #
	if (!defined($speed)) {
	    warn("*** No speed defined, default to 100Mbps\n");
	    $speed = 100;
	}
	if ($speed =~ /(\d*)([A-Za-z]*)/) {
	    if ($2 eq "Mbps") {
		$speed = $1;
	    }
	    elsif ($2 eq "Kbps") {
		$speed = $1 / 1000;
	    }
	    else {
		warn("*** Bad speed units $2 in ifconfig, default to 100Mbps\n");
		$speed = 100;
	    }
	    if ($speed == 25000 || $speed == 40000) {
		$media = "";
	    }
	    elsif ($speed == 10000) {
		$media = $IFC_10000MBS;
	    }
	    elsif ($speed == 1000) {
		$media = $IFC_1000MBS;
	    }
	    elsif ($speed == 100) {
		$media = $IFC_100MBS;
	    }
	    elsif ($speed == 10) {
		$media = $IFC_10MBS;
	    }
	    elsif ($speed == 0) {
		warn("*** Speed was 0 in ifconfig, default to autoconfig\n");
		$media = "$IFC_AUTO";
	    }
	    else {
		warn("*** Bad Speed $speed in ifconfig, default to autoconfig\n");
		$speed = 0;
		$media = $IFC_AUTO;
	    }
	}
	if (!defined($duplex)) {
	    warn("*** No duplex defined, default to full\n");
	    $duplex = "full";
	}
	if ($media eq '' || $media eq $IFC_AUTO) {
	    ;
	}
	elsif ($duplex eq "full") {
	    $media = "$media-$IFC_FDUPLEX";
	}
	elsif ($duplex eq "half") {
	    $media = "$media-$IFC_HDUPLEX";
	}
	else {
	    warn("*** Bad duplex $duplex in ifconfig, default to full\n");
	    $duplex = "full";
	    $media = "$media-$IFC_FDUPLEX";
	}

        #
        # Linux is apparently changing from mii-tool to ethtool but some
	# drivers don't support the new interface (3c59x), some don't support
	# the old interface (e1000), and some (eepro100) support the new
	# interface just enough that they can report success but not actually
	# do anything. Sweet!
        #
	my $ethtool;
	if (-e "/sbin/ethtool") {
	    $ethtool = "/sbin/ethtool";
	} elsif (-e "/usr/sbin/ethtool") {
	    $ethtool = "/usr/sbin/ethtool";
	}
	if (defined($ethtool)) {
	    # this seems to work for returning an error on eepro100
	    $uplines =
		"if $ethtool $iface >/dev/null 2>&1; then\n    ";
	    #
	    # Special cases:
	    # - '0' means autoneg
	    # - '1000', aka gigabit, we *must* turn on autoneg--
	    #   it's part of the GbE protocol.
	    # - '10000', aka 10GE, don't try to set anything
	    #
	    if ($speed eq '0' || $speed eq '1000') {
		$uplines .= "  $ethtool -s $iface autoneg on\n    ";
	    }
	    else {
		$uplines .=
		    "  if $ethtool -s $iface autoneg off speed $speed duplex $duplex >/dev/null 2>&1 ; then\n    " .
		    "    sleep 2 # needed due to likely bug in e100 driver on pc850s\n    " .
		    "  else\n    " .
		    "    echo ERROR: failed to set speed $speed on iface $iface; falling back to autonegotiation!\n    " .
		    "    if ! $ethtool -s $iface autoneg on ; then\n    " .
		    "      echo ERROR: failed to fall back to autonegotiation on $iface!\n    " .
		    "    fi\n    " .
		    "  fi\n    ";
	    }
	    if ($media eq '') {
		$uplines .= 
		    "else\n    " .
		    "  echo WARNING: cannot set speed $speed for $iface via mii-tool!\n    " .
		    "fi\n    ";
	    }
	    elsif ($media eq $IFC_AUTO) {
		$uplines .= 
		    "else\n    " .
		    "  /sbin/mii-tool -A $IFC_AUTO\n    " .
		    "fi\n    ";
	    }
	    else {
		$uplines .= 
		    "else\n    " .
		    "  /sbin/mii-tool --force=$media $iface\n    " .
		    "fi\n    ";
	    }
	} else {
	    $uplines = "/sbin/mii-tool --force=$media $iface\n    ";
	}

	#
	# XXX only recognize 1500 and 9000 for MTUs.
	# Anything else results in the default (no explicit setting).
	#
	if (defined($mtu)) {
	    if ($mtu eq "1500") {
		$mtuopt = $IFC_1500MTU;
	    } elsif ($mtu eq "9000") {
		$mtuopt = $IFC_9000MTU;
	    }
	}
    }

    if ($inet eq "") {
	$uplines .= "$IFCONFIGBIN $iface up $mtuopt";
    }
    else {
	$uplines  .= sprintf($IFCONFIG, $iface, $inet, $mask, $mtuopt);
	$downlines = "$IFCONFIGBIN $iface down";
    }

    return ($uplines, $downlines);
}

#
# Specialized function for configing virtual ethernet devices:
#
#	'veth'	one end of an etun device embedded in a vserver
#	'vlan'	802.1q tagged vlan devices
#	'alias'	IP aliases on physical interfaces
#
sub os_ifconfig_veth($$$$$;$$$$$%)
{
    my ($iface, $inet, $mask, $id, $vmac,
	$rtabid, $encap, $vtag, $itype, $mtu, $cookie) = @_;
    my ($uplines, $downlines);

    if ($itype !~ /^(alias|vlan|veth)$/) {
	warn("Unknown virtual interface type $itype\n");
	return "";
    }

    #
    # Veth.
    #
    # Veths for Linux vservers mean vtun devices.  One end is outside
    # the vserver and is bridged with other veths and peths as appropriate
    # to form the topology.  The other end goes in the vserver and is
    # configured with an IP address.  This final step is not done here
    # as the vserver must be running first.
    #
    # In the current configuration, there is configuration that takes
    # place both inside and outside the vserver.
    #
    # Inside:
    # The inside case (LINUXJAILED() == 1) just configures the IP info on
    # the interface.
    #
    # Outside:
    # The outside actions are much more involved as described above.
    # The VTAG identifies a bridge device "ebrN" to be used.
    # The RTABID identifies the namespace, but we don't care here.
    #
    # To create a etun pair you do:
    #    echo etun0,etun1 > /sys/module/etun/parameters/newif
    # To destroy do:
    #    echo etun0 > /sys/module/etun/parameters/delif
    #
    if ($itype eq "veth") {
	#
	# We are inside a Linux jail.
	# We configure the interface pretty much like normal.
	#
	if (LINUXJAILED()) {
	    if ($inet eq "") {
		$uplines .= "$IFCONFIGBIN $iface up";
	    }
	    else {
		$uplines  .= sprintf($IFCONFIG, $iface, $inet, $mask, "");
		$downlines = "$IFCONFIGBIN $iface down";
	    }

	    return ($uplines, $downlines);
	}

	#
	# Outside jail.
	# Create tunnels and bridge and plumb them all together.
	#
	my $brdev = "ebr$vtag";
	my $iniface = "veth$id";
	my $outiface = "peth$id";
	my $devdir = "/sys/module/etun/parameters";

	# UP
	$uplines = "";

	# modprobe (should be done already for cnet setup, but who cares)
	$uplines .= "modprobe etun\n";

	# make sure bridge device exists and is up
	$uplines .= "    $IFCONFIGBIN $brdev >/dev/null 2>&1 || {";
	$uplines .= "        $BRCTL addbr $brdev\n";
	$uplines .= "        $IFCONFIGBIN $brdev up\n";
	$uplines .= "    }\n";

	# create the tunnel device
	$uplines .= "    echo $outiface,$iniface > $devdir/newif || exit 1\n";

	# bring up outside IF, insert into bridge device
	$uplines .= "    $IFCONFIGBIN $outiface up || exit 2\n";
	$uplines .= "    $BRCTL addif $brdev $outiface || exit 3\n";

	# configure the MAC address for the inside device
	$uplines .= "    $IFCONFIGBIN $iniface hw ether $vmac || exit 4\n";

	# DOWN
	$downlines = "";

	# remove IF from bridge device, down it (remove bridge if empty?)
	$downlines .= "$BRCTL delif $brdev $outiface || exit 13\n";
	$downlines .= "    $IFCONFIGBIN $outiface down || exit 12\n";

	# destroy tunnel devices (this will fail if inside IF in vserver still)
	$downlines .= "    echo $iniface > $devdir/delif || exit 11\n";

	return ($uplines, $downlines);
    }

    #
    # IP aliases
    #
    if ($itype eq "alias") {
	$uplines = "$IPBIN addr add $inet/$mask dev $iface";
	$downlines = "$IPBIN addr del $inet/$mask dev $iface";
	return ($uplines, $downlines);
    }

    #
    # VLANs
    #   modprobe 8021q (once only)
    #   vconfig set_name_type VLAN_PLUS_VID_NO_PAD (once only)
    #
    #	ifconfig eth0 up (should be done before we are ever called)
    #	vconfig add eth0 601
    #   ifconfig vlan601 inet ...
    #
    #   ifconfig vlan601 down
    #	vconfig rem vlan601
    #
    if ($itype eq "vlan") {
	if (!defined($vtag)) {
	    warn("No vtag in veth config\n");
	    return "";
	}

	#
	# XXX only recognize 1500 and 9000 for MTUs.
	# Anything else results in the default (no explicit setting).
	#
	my $mtuopt = "";
	if (defined($mtu)) {
	    if ($mtu eq "1500") {
		$mtuopt = $IFC_1500MTU;
	    } elsif ($mtu eq "9000") {
		$mtuopt = $IFC_9000MTU;
	    }
	}

	# XXX starting with CentOS7, vconfig is no longer
	my $useip = 0;
	if (! -x $VLANCONFIG) {
	    $useip = 1;
	}

	# one time stuff
	if (!exists($cookie->{"vlan"})) {
	    $uplines  = "/sbin/modprobe 8021q >/dev/null 2>&1\n    ";
	    $uplines .= "$VLANCONFIG set_name_type VLAN_PLUS_VID_NO_PAD\n    "
		if (!$useip);
	    $cookie->{"vlan"} = 1;
	}

	my $vdev = "vlan$vtag";

	if ($useip) {
	    $uplines   .= "/sbin/ip link add link $iface name $vdev type vlan id $vtag\n    ";
	} else {
	    $uplines   .= "$VLANCONFIG add $iface $vtag\n    ";
	}
	$uplines   .= sprintf($IFCONFIG, $vdev, $inet, $mask, $mtuopt);
	# configure the MAC address.
	$uplines   .= "\n    $IFCONFIGBIN $vdev hw ether $vmac"
	    if ($vmac);

	$downlines .= "$IFCONFIGBIN $vdev down\n    ";
	if ($useip) {
	    $downlines .= "/sbin/ip link delete $vdev";
	} else {
	    $downlines .= "$VLANCONFIG rem $vdev";
	}
    }

    return ($uplines, $downlines);
}

#
# Compute the name of a virtual interface device based on the
# information in ifconfig hash (as returned by getifconfig).
#
sub os_viface_name($)
{
    my ($ifconfig) = @_;
    my $piface = $ifconfig->{"IFACE"};

    #
    # Physical interfaces use their own name
    #
    if (!$ifconfig->{"ISVIRT"}) {
	return $piface;
    }

    #
    # Otherwise we have a virtual interface: alias, veth, vlan.
    #
    # alias: There is an alias device, but not sure what it is good for
    #        so for now we just return the phys device.
    # vlan:  vlan<VTAG>
    # veth:  veth<ID>
    #
    my $itype = $ifconfig->{"ITYPE"};
    if ($itype eq "alias") {
	return $piface;
    } elsif ($itype eq "vlan") {
	return $itype . $ifconfig->{"VTAG"};
    } elsif ($itype eq "veth") {
	return $itype . $ifconfig->{"ID"};
    }

    warn("Linux does not support virtual interface type '$itype'\n");
    return undef;
}

#
# Generate and return an string that is approriate for putting
# into /etc/hosts.
#
sub os_etchosts_line($$$)
{
    my ($name, $ip, $aliases) = @_;

    return sprintf("%s\t%s %s", $ip, $name, $aliases);
}

#
# Add a new group
#
sub os_groupadd($$)
{
    if (INVZVM()) {
	my $tries  = 10;
	my $result = 1;
	while ($tries-- > 0) {
	    $result = os_groupadd_real(@_);
	    last
		if (!$result || !$tries);

	    warn("$GROUPADD returned $result ... trying again in a bit\n");
	    sleep(10);
	}
	return $result;
    }
    else {
	return os_groupadd_real(@_);
    }
}

sub os_groupadd_real($$)
{
    my ($group, $gid) = @_;

    return system("$GROUPADD -g $gid $group");
}

#
# Delete an old group
#
sub os_groupdel($)
{
    my($group) = @_;

    return system("$GROUPDEL $group");
}

#
# Remove a user account.
#
sub os_userdel($)
{
    my($login) = @_;

    return system("$USERDEL $login");
}

#
# Modify user group membership.
#
sub os_usermod($$$$$$)
{
    my($login, $gid, $glist, $pswd, $root, $shell) = @_;

    if ($root) {
	$glist = join(',', split(/,/, $glist), "root");
    }
    if ($glist ne "") {
	$glist = "-G $glist";
    }
    # Map the shell into a full path.
    $shell = MapShell($shell);

    return system("$USERMOD -s $shell -g $gid $glist -p '$pswd' $login");
}

#
# Modify user password.
#
sub os_modpasswd($$)
{
    my($login, $pswd) = @_;

    if (system("$USERMOD -p '$pswd' $login") != 0) {
	warn "*** WARNING: resetting password for $login.\n";
	return -1;
    }
    # don't try to reset 'toor' if it doesn't exist
    if ($login eq "root" &&
	system("grep -q toor $TMPASSWD") == 0 &&
	system("$USERMOD -p '$pswd' toor") != 0) {
	warn "*** WARNING: resetting password for toor.\n";
	return -1;
    }
    return 0;
}

#
# Add a user.
#
sub os_useradd($$$$$$$$$)
{
    if (INVZVM()) {
	my $tries  = 10;
	my $result = 1;
	while ($tries-- > 0) {
	    $result = os_useradd_real(@_);
	    last
		if (!$result || !$tries);

	    warn("$USERADD returned $result ... trying again in a bit\n");
	    sleep(10);
	}
	return $result;
    }
    else {
	return os_useradd_real(@_);
    }
}

sub os_useradd_real($$$$$$$$$)
{
    my($login, $uid, $gid, $pswd, $glist, $homedir, $gcos, $root, $shell) = @_;
    my $args = "";

    if ($root) {
	$glist = join(',', split(/,/, $glist), "root");
    }
    if ($glist ne "") {
	$args .= "-G $glist ";
    }
    # If remote, let it decide where to put the homedir.
    if (!REMOTE()) {
	$args .= "-d $homedir ";

	# Locally, if directory exists and is populated, skip -m
	# and make sure no attempt is made to create.
	if (! -d $homedir || ! -e "$homedir/.profile") {
	    $args .= "-m ";
	}
	else {
	    #
	    # -M is Redhat only option?  Overrides default CREATE_HOME.
	    # So we see if CREATE_HOME is set and if so, use -M.
	    #
	    if (!system("grep -q CREATE_HOME /etc/login.defs")) {
		$args .= "-M ";
	    }
	}
    }
    elsif (!PLAB()) {
	my $marg = "-m";

	#
	# XXX DP hack
	# Only force creation of the homdir if the default homedir base
	# is on a local FS.  On the DP, all nodes share a homedir base
	# which is hosted on one of the nodes, so we create the homedir
	# only on that node.
	#
	$defhome = `$USERADD -D 2>/dev/null`;
	if ($defhome =~ /HOME=(.*)/) {
	    if (!os_islocaldir($1)) {
		$marg = "";
	    }
	}

	# populate on remote nodes. At some point will tar files over.
	$args .= $marg;
    }

    # Map the shell into a full path.
    $shell = MapShell($shell);
    my $oldmask = umask(0022);

    if (system("$USERADD -u $uid -g $gid $args -p '$pswd' ".
	       "-s $shell -c \"$gcos\" $login") != 0) {
	warn "*** WARNING: $USERADD $login error.\n";
	umask($oldmask);
	return -1;
    }
    umask($oldmask);
    return 0;
}

#
# Remove a homedir. Might someday archive and ship back.
#
sub os_homedirdel($$)
{
    return 0;
}

#
# Create a directory including all intermediate directories.
#
sub os_mkdir($$)
{
    my ($dir, $mode) = @_;

    if (system("$MKDIR -p -m $mode $dir")) {
	return 0;
    }
    return 1;
}

#
# OS Dependent configuration.
#
sub os_setup()
{
    return 0;
}

#
# OS dependent, routing-related commands
#
sub os_routing_enable_forward()
{
    my $cmd;

    $cmd = "sysctl -w net.ipv4.conf.all.forwarding=1";
    return $cmd;
}

sub os_routing_enable_gated($)
{
    my ($conffile) = @_;
    my $cmd;

    #
    # XXX hack to avoid gated dying with TCP/616 already in use.
    #
    # Apparently the port is used by something contacting ops's
    # portmapper (i.e., NFS mounts) and probably only happens when
    # there are a bazillion NFS mounts (i.e., an experiment in the
    # testbed project).
    #
    $cmd  = "for try in 1 2 3 4 5 6; do\n";
    $cmd .= "\tif `cat /proc/net/tcp | ".
	"grep -E -e '[0-9A-Z]{8}:0268 ' >/dev/null`; then\n";
    $cmd .= "\t\techo 'gated GII port in use, sleeping...';\n";
    $cmd .= "\t\tsleep 10;\n";
    $cmd .= "\telse\n";
    $cmd .= "\t\tbreak;\n";
    $cmd .= "\tfi\n";
    $cmd .= "    done\n";
    $cmd .= "    $GATED -f $conffile";
    return $cmd;
}

sub os_routing_add_manual($$$$$;$)
{
    my ($routetype, $destip, $destmask, $gate, $cost, $rtabid) = @_;
    my $cmd;

    if ($routetype eq "host") {
	$cmd = "$ROUTE add -host $destip gw $gate";
    } elsif ($routetype eq "net") {
	$cmd = "$ROUTE add -net $destip netmask $destmask gw $gate";
    } elsif ($routetype eq "default") {
	$cmd = "$ROUTE add default gw $gate";
    } else {
	warn "*** WARNING: bad routing entry type: $routetype\n";
	$cmd = "";
    }

    return $cmd;
}

sub os_routing_del_manual($$$$$;$)
{
    my ($routetype, $destip, $destmask, $gate, $cost, $rtabid) = @_;
    my $cmd;

    if ($routetype eq "host") {
	$cmd = "$ROUTE delete -host $destip";
    } elsif ($routetype eq "net") {
	$cmd = "$ROUTE delete -net $destip netmask $destmask gw $gate";
    } elsif ($routetype eq "default") {
	$cmd = "$ROUTE delete default";
    } else {
	warn "*** WARNING: bad routing entry type: $routetype\n";
	$cmd = "";
    }

    return $cmd;
}

# Map a shell name to a full path using /etc/shells
sub MapShell($)
{
   my ($shell) = @_;

   if ($shell eq "") {
       return $DEFSHELL;
   }

   #
   # May be multiple lines (e.g., /bin/sh, /usr/bin/sh, etc.) in /etc/shells.
   # Just use the first entry.
   #
   my @paths = `grep '/${shell}\$' $SHELLS`;
   if ($?) {
       return $DEFSHELL;
   }
   my $fullpath = $paths[0];
   chomp($fullpath);

   # Sanity Checks
   if ($fullpath =~ /^([-\w\/]*)$/ && -x $fullpath) {
       $fullpath = $1;
   }
   else {
       $fullpath = $DEFSHELL;
   }
   return $fullpath;
}

sub os_samefs($$)
{
    my ($d1,$d2) = @_;

    my $d1dev = `stat -c '%d' $d1`;
    chomp($d1dev) if ($? == 0);
    my $d2dev = `stat -c '%d' $d2`;
    chomp($d2dev) if ($? == 0);

    return ($d1dev && $d2dev && $d1dev == $d2dev) ? 1 : 0;
}

#
# Some environments do not give us a valid / mount (like Docker); thus,
# df -l does not work.  Thus we must rely on /proc/mounts to tell us if
# a dir is local or not.  Well, ok, /proc/mounts is hard (and potential
# bind mount chains would make it harder).  So instead, we assume that /
# is local, (well, we check to ensure it is not NFS in /proc/mounts),
# and use os_samefs above to ensure that $dir is on the same device as
# /.  If that is true, that is good enough to call it a local dir.
#
# We are *very* careful in this function.  If df -l / actually returns
# something, we bail out, since if df -l returns a local fs in that
# case, this function should not be used!
#
sub os_islocaldir_alt($)
{
    my ($dir,) = @_;

    my %mounttypes = ();
    my %mountdevs = ();
    open(FD,"/proc/mounts");
    if ($?) {
	warn "*** alt_os_is_localdir: could not open /proc/mounts; aborting!\n";
	return -1;
    }
    my @lines = <FD>;
    close(FD);
    foreach my $line (@lines) {
	chomp($line);
	if ($line =~ /^([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+.*$/) {
	    $mounttypes{$2} = $3;
	    $mountdevs{$2} = $1;
	}
    }

    if (exists($mounttypes{"/"}) && $mounttypes{"/"} =~ /nfs/i) {
	warn "*** os_islocaldir_alt: / appears to be NFS; not safe to use this!";
	return -1;
    }

    return os_samefs("/",$dir);
}

# Return non-zero if given directory is on a "local" filesystem
sub os_islocaldir($)
{
    my ($dir) = @_;
    my $rv = 0;

    if (INDOCKERVM()) {
	$rv = os_islocaldir_alt($dir);
	return $rv
	    if ($rv >= 0);
	# Otherwise ($rv == -1), we fall back to the old way, which will
	# not fail us (might be wrong, but it will be a false positive,
	# so we won't remove a remote dir or anything).
    }

    my @dfoutput = `$DF -l $dir 2>/dev/null`;
    if (grep(!/^filesystem/i, @dfoutput) > 0) {
	$rv = 1;
    }

    #
    # XXX hack for NFS-based MFS. We treat it as a local directory
    # if it is on the same FS as /.
    #
    if ($rv == 0 && libsetup::MFS() && os_samefs("/", $dir)) {
	$rv = 1;
    }

    return $rv;
}

sub os_getnfsmounts($)
{
    my ($rptr) = @_;
    my %mounted = ();

    #
    # Grab the output of the mount command and parse.
    #
    if (! open(MOUNT, "/bin/mount|")) {
	print "os_getnfsmounts: Cannot run mount command\n";
	return -1;
    }
    while (<MOUNT>) {
	if ($_ =~ /^([-\w\.\/:\(\)]+) on ([-\w\.\/]+) type (\w+) .*$/) {
	    # Check type for nfs string.
	    if ($3 eq "nfs") {
		# Key is the remote NFS path, value is the mount point path.
		$mounted{$1} = $2;
	    }
	}
    }
    close(MOUNT);
    %$rptr = %mounted;
    return 0;
}

sub os_fwconfig_line($@) {
	my ($fwinfo, @fwrules) = @_;
	my ($upline, $downline);
	my $pdev;
	my $vlandev;
	my $myip;
	my $mymask;

	$myip = `cat $BOOTDIR/myip`;
	chomp($myip);
	$mymask = `cat $BOOTDIR/mynetmask`;
	chomp($mymask);

	if ($fwinfo->{TYPE} ne "iptables" &&
	    $fwinfo->{TYPE} ne "iptables-vlan" &&
	    $fwinfo->{TYPE} ne "iptables-dom0") {
		warn "*** WARNING: unsupported firewall type '", $fwinfo->{TYPE}, "'\n";
		return ("false", "false");
	}

	# XXX debugging
	my $logaccept = defined($fwinfo->{LOGACCEPT}) ? $fwinfo->{LOGACCEPT} : 0;
	my $logreject = defined($fwinfo->{LOGREJECT}) ? $fwinfo->{LOGREJECT} : 0;
	my $dotcpdump = defined($fwinfo->{LOGTCPDUMP}) ? $fwinfo->{LOGTCPDUMP} : 0;

	#
	# Convert MAC info to a useable form and filter out the firewall itself
	#
	my $href = $fwinfo->{MACS};
	while (my ($node,$mac) = each(%$href)) {
		if ($mac eq $fwinfo->{OUT_IF}) {
			delete($$href{$node});
		} elsif ($mac =~ /^(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})$/) {
			$$href{$node} = "$1:$2:$3:$4:$5:$6";
		} else {
			warn "*** WARNING: Bad MAC returned for $node in fwinfo: $mac\n";
			return ("false", "false");
		}
	}
	$href = $fwinfo->{SRVMACS};
	while (my ($node,$mac) = each(%$href)) {
		if ($mac eq $fwinfo->{OUT_IF}) {
			delete($$href{$node});
		} elsif ($mac =~ /^(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})$/) {
			$$href{$node} = "$1:$2:$3:$4:$5:$6";
		} else {
			warn "*** WARNING: Bad MAC returned for $node in fwinfo: $mac\n";
			return ("false", "false");
		}
	}

	#
	# VLAN enforced layer2 firewall with Linux iptables
	#
	if ($fwinfo->{TYPE} eq "iptables-vlan") {
		if (!defined($fwinfo->{IN_VLAN})) {
			warn "*** WARNING: no VLAN for iptables-vlan firewall, NOT SETUP!\n";
			return ("false", "false");
		}
	
		$pdev    = `$BINDIR/findif $fwinfo->{IN_IF}`;
		chomp($pdev);
		my $vlanno  = $fwinfo->{IN_VLAN};
		$vlandev = $pdev . '.' . $vlanno;

		$upline  = "modprobe 8021q\n";
		$upline .= "vconfig add $pdev $vlanno > /dev/null\n";
		$upline .= "ifconfig $vlandev up\n";
		$upline .= "brctl addbr br0\n";
		$upline .= "brctl stp br0 off\n";
		#
		# As of 12/14/2017, these stp-type-specific rules have
		# no affect on STP packet forwarding across the bridge.
		# The unspecific drop-everything-destined-to-the-BGA
		# rule works effectively, however.  See
		# https://sourceforge.net/p/ebtables/mailman/message/5974070/
		# for same symptom; no resolution.
		#
		$upline .= "ebtables -A FORWARD -d BGA --stp-type 0x0 -j DROP\n";
		$upline .= "ebtables -A FORWARD -d BGA --stp-type 0x80 -j DROP\n";
		$upline .= "ebtables -A FORWARD -d BGA --stp-type 0x02 -j DROP\n";
		$upline .= "ebtables -A FORWARD -d BGA -j DROP\n";
		$upline .= "ifconfig br0 up\n";
		#
		# This is very, very messy.  We have to save the
		# existing routes for $pdev, but in an order that they
		# can be restored without failing, before we move
		# $pdev into br0.  Then the restored routes must be
		# rewritten in terms of br0 instead of $pdev.
		#
		# Finally, we have to collect these routes prior to 1)
		# assigning $pdev's IP to br0, and 2) moving $pdev
		# into br0, and 3) prior to *deleting* any routes.
		# All these conditions seem necessary to me.
		#
		# ip route show does not necessarily display routes in
		# restoreable order.  In particular, the thing that
		# bites is that the default route is (now, as of
		# Ubuntu16, at least) displayed *prior to* the scope
		# link (broadcast route) for a device).  So, we first
		# harvest the scope link routes for $pdev (i.e., the
		# natural ones that come into being as a side affect
		# of assiging an IP address to a link); then we
		# harvest all other routes associated with $pdev; then
		# we remove all routes associated with $pdev.  Then we
		# do the mucking about with bridge membership and
		# transfer IP from $pdev to bridge, and finally,
		# restore the routes we saved (modified to br0, of
		# course).
		#
		$upline .= "ROUTECMDS=\$(ip route show scope link | while read line; do\n";
		$upline .= "    echo \$line | grep 'dev $pdev' > /dev/null || continue\n";
		$upline .= "    echo 'ip route add '`echo \$line | sed s/$pdev/br0/`\n";
		$upline .= "done)\n";
		$upline .= "ROUTECMDS=\"\$ROUTECMDS\\n\"\$(ip route show | while read line; do\n";
		$upline .= "    echo \$line | grep 'dev $pdev' > /dev/null || continue\n";
		$upline .= "    echo \$line | grep 'scope link' > /dev/null && continue\n";
		$upline .= "    echo 'ip route add '`echo \$line | sed s/$pdev/br0/`\n";
		$upline .= "done)\n";
		$upline .= "ip route show | while read line; do\n";
		$upline .= "    echo \$line | grep 'dev $pdev' > /dev/null || continue\n";
		$upline .= "    ip route del \$line\n";
		$upline .= "done\n";
		$upline .= "brctl addif br0 $pdev\n";
		$upline .= "brctl addif br0 $vlandev\n";
		$upline .= "ifconfig br0 $myip netmask $mymask\n";
		$upline .= "ip route flush dev br0\n";
		$upline .= "ifconfig $pdev 0.0.0.0\n";
		$upline .= "/bin/echo -e \"\$ROUTECMDS\" | sh\n";

		$downline .= "ROUTECMDS=\$(ip route show scope link | while read line; do\n";
		$downline .= "    echo \$line | grep 'dev br0' > /dev/null || continue\n";
		$downline .= "    echo 'ip route add '`echo \$line | sed s/br0/$pdev/`\n";
		$downline .= "done)\n";
		$downline .= "ROUTECMDS=\"\$ROUTECMDS\\n\"\$(ip route show | while read line; do\n";
		$downline .= "    echo \$line | grep 'dev br0' > /dev/null || continue\n";
		$downline .= "    echo \$line | grep 'scope link' > /dev/null && continue\n";
		$downline .= "    echo 'ip route add '`echo \$line | sed s/br0/$pdev/`\n";
		$downline .= "done)\n";
		$downline .= "ip route show | while read line; do\n";
		$downline .= "    echo \$line | grep 'dev br0' > /dev/null || continue\n";
		$downline .= "    ip route del \$line\n";
		$downline .= "done\n";
		$downline .= "    ifconfig $pdev $myip netmask $mymask\n";
		$downline .= "    ip route flush dev $pdev\n";
		$downline .= "    ip route flush dev br0\n";
		$downline .= "/bin/echo -e \"\$ROUTECMDS\" | sh\n";
		$downline .= "    ifconfig br0 down\n";
		$downline .= "    ifconfig $vlandev down\n";
		$downline .= "    brctl delif br0 $vlandev\n";
		$downline .= "    brctl delif br0 $pdev\n";
		$downline .= "    brctl delbr br0\n";
		$downline .= "    vconfig rem $vlandev > /dev/null\n";

		#
		# Setup proxy ARP entries.
		#
		if (defined($fwinfo->{MACS}) || defined($fwinfo->{PUBLICADDRS})) {
			$upline .= "ebtables -t nat -F PREROUTING\n";
			# publish servers (including GW) on inside and for us on outside
			if (defined($fwinfo->{SRVMACS})) {
				my $href = $fwinfo->{SRVMACS};
				while (my ($ip,$mac) = each %$href) {
					$upline .= "ebtables -t nat -A PREROUTING -i $vlandev " .
					  "-p ARP --arp-opcode Request " .
					    "--arp-ip-dst $ip -j arpreply " .
					      "--arpreply-mac $mac\n";
				}
			}

			# provide node MACs to outside
			if (defined($fwinfo->{MACS})) {
			    my $href = $fwinfo->{MACS};
			    while (my ($node,$mac) = each %$href) {
				my $ip = $fwinfo->{IPS}{$node};
				$upline .= "ebtables -t nat -A PREROUTING -i $pdev " .
				  "-p ARP --arp-opcode Request " .
				    "--arp-ip-dst $ip -j arpreply " .
				      "--arpreply-mac $mac\n";
			    }
		        }

			$upline .= "ebtables -t nat -A PREROUTING -p ARP " .
			  "--arp-ip-dst $myip -j ACCEPT\n";

			#
			# Enable proxy arp for PUBLICADDRS, but only
			# allow requests/replies for them.  This allows
			# the PUBLICADDRS to be used by any physical
			# node in the expt, which is what we want by
			# default.
			#
			if (defined($fwinfo->{PUBLICADDRS})) {
			    $upline .= "echo 1 > /proc/sys/net/ipv4/conf/br0/proxy_arp\n";
			    foreach my $pip (@{$fwinfo->{PUBLICADDRS}}) {
				$upline .= "ip ro add $pip/32 dev br0\n";
				$upline .= "ebtables -t nat -A PREROUTING " .
				    "-i $pdev -p ARP --arp-opcode Request " .
				    "--arp-ip-dst $pip -j ACCEPT\n";
				$upline .= "ebtables -t nat -A PREROUTING " .
				    "-i $vlandev -p ARP --arp-opcode Reply " .
				    "--arp-ip-src $pip -j ACCEPT\n";
				$downline .= "ip ro del $pip/32 dev br0\n";
			    }
			    $downline .= "echo 0 > /proc/sys/net/ipv4/conf/br0/proxy_arp\n";
			}

			$upline .= "ebtables -t nat -A PREROUTING -p ARP -j DROP\n";

			if ($dotcpdump) {
				$upline .= "    tcpdump -i $vlandev ".
				  "-w $LOGDIR/in.tcpdump >/dev/null 2>&1 &\n";
				$upline .= "    tcpdump -i $pdev ".
				  "-w $LOGDIR/out.tcpdump not vlan >/dev/null 2>&1 &\n";
				$downline .= "    killall tcpdump >/dev/null 2>&1\n";
			}
		
		}

		# XXX HACK ALERT
		# The rules may contain hostnames which iptables will try to resolve.
		# Normally this isn't a problem, but if we've set up a bridge device
		# it may take a bit before the bridge starts letting packets through
		# again.
		$upline .= "sleep 30\n";

	} else {
		if ($fwinfo->{TYPE} ne "iptables-dom0") {
		    $upline .= "sysctl -w net.ipv4.ip_forward=1\n";
		    $downline .= "sysctl -w net.ipv4.ip_forward=0\n";
		}
	}

	# Sort the rules by provided rule number (tmcd doesn't order them).
	@fwrules = sort { $a->{RULENO} <=> $b->{RULENO}} @fwrules;

	# XXX This is ugly.  Older version of iptables can't handle source or
	# destination hosts or nets in the format a,b,c,d.  Newer versions of
	# iptables automatically expand this to separate rules for each host/net,
	# so we need to do the same thing here.  Since a rule could contain
	# multiple sources and multiple dests, we expand each separately.
	my @new_rules;
	foreach my $rule (@fwrules) {
		$rulestr = $rule->{RULE};
		if ($rulestr =~ /^(.+)\s+(-s|--source)\s+([\S]+)(.+)/) {
			push @new_rules, "$1 $2 $_ $4" for split(/,/, $3);
		} else {
			push @new_rules, $rulestr;
		}
	} 

	@fwrules = ();
	foreach my $rulestr (@new_rules) {
		if ($rulestr =~ /^(.+)\s+(-d|--destination)\s+([\S]+)(.+)/) {
			push @fwrules, "$1 $2 $_ $4" for split(/,/, $3);
		} else {
			push @fwrules, $rulestr;
		}
	}

	@new_rules = ();
	foreach my $rulestr (@fwrules) {
		$rulestr =~ s/pdev/$pdev/g;
		$rulestr =~ s/vlandev/$vlandev/g;
		$rulestr =~ s/\s+me\s+/ $myip /g;

		# Ugh. iptables wants port ranges in the form a:b, but
		# our firewall variable expansion can contain a-b.  Try
		# to fix it.
		$rulestr =~ s/\s+--dport\s+(\S+)-(\S+)/ --dport $1:$2/;
		$rulestr =~ s/\s+--sport\s+(\S+)-(\S+)/ --sport $1:$2/;
		
		if ($logaccept && $rulestr =~ /-j ACCEPT$/) {
			if ($rulestr =~ /^iptables\s+/) {
				push @new_rules, $rulestr;
				$rulestr =~ s/ACCEPT$/LOG/;
			} elsif ($rulestr =~ /^ebtables\s+/) {
				$rulestr =~ s/ACCEPT$/--log -j ACCEPT/;
			}
			push @new_rules, $rulestr;
		} elsif ($logreject && $rulestr =~ /-j (DENY|DROP)$/) {
			my $action = $1;
			if ($rulestr =~ /^iptables\s+/) {
				push @new_rules, $rulestr;
				$rulestr =~ s/$action$/LOG/;
			} elsif ($rulestr =~ /^ebtables\s+/) {
				$rulestr =~ s/$action$/--log -j $action/;
			}
			push @new_rules, $rulestr;
		} else {
			push @new_rules, $rulestr;
		}
	}
	@fwrules = @new_rules;

	#
	# For now, if a rule fails to load we fail partially open.
	# We allow all access to the FW itself but nothing inside.
	#
	foreach my $rulestr (@fwrules) {
		if ($rulestr =~ /^iptables\s+/) {
			$upline .= "    $rulestr || {\n";
			$upline .= "        echo 'WARNING: could not load iptables rule:'\n";
			$upline .= "        echo '  $rulestr'\n";
			$upline .= "        iptables -F\n"
			    if ($fwinfo->{TYPE} ne "iptables-dom0");
			$upline .= "        iptables -P FORWARD DROP\n";
			$upline .= "        iptables -P INPUT ACCEPT\n";
			$upline .= "        iptables -P OUTPUT ACCEPT\n";
			$upline .= "        exit 1\n";
			$upline .= "    }\n";
		} elsif ($rulestr =~ /^ebtables\s+/) {
			$upline .= "    $rulestr || {\n";
			$upline .= "        echo 'WARNING: could not load ebtables rule:'\n";
			$upline .= "        echo '  $rulestr'\n";
			$upline .= "        ebtables -F\n"
			    if ($fwinfo->{TYPE} ne "iptables-dom0");
			$upline .= "        ebtables -P FORWARD DROP\n";
			$upline .= "        ebtables -P INPUT ACCEPT\n";
			$upline .= "        ebtables -P OUTPUT ACCEPT\n";
			$upline .= "        exit 1\n";
			$upline .= "    }\n";
		}

	}

	#
	# In dom0, we cannot just flush the entire rule set, as below.
	#
	if ($fwinfo->{TYPE} eq "iptables-dom0") {
	        $downline .= "   iptables -P INPUT ACCEPT\n";
		$downline .= "   iptables -P OUTPUT ACCEPT\n";
	        $downline .=
		    "   iptables -F INPUT > /dev/null 2>&1 || true\n";
	        $downline .=
		    "   iptables -F OUTPUT > /dev/null 2>&1 || true\n";
	}

	# This is a brute-force way to flush all ebtables and iptables
	# rules, delete all custom chains, and restore all built-in
	# chains to their default policies.  This will produce errors
	# since not all tables exist for both tools, and not every
	# chain exists for all tables, so all output is sent to /dev/null.
	for my $table (qw/filter nat mangle raw broute/) {
		if ($fwinfo->{TYPE} ne "iptables-dom0") {
		    $downline .=
			"   iptables -t $table -F > /dev/null 2>&1 || true\n";
		    $downline .=
			"   iptables -t $table -X > /dev/null 2>&1 || true\n";
		}
		$downline .=
		  "   ebtables -t $table -F > /dev/null 2>&1 || true\n";
		$downline .=
		  "   ebtables -t $table -X > /dev/null 2>&1 || true\n";
		for my $chain (qw/INPUT OUTPUT FORWARD PREROUTING POSTROUTING BROUTING/) {
		        if ($fwinfo->{TYPE} ne "iptables-dom0") {
			    $downline .=
				"   iptables -t $table -P $chain ACCEPT > /dev/null 2>&1 || true\n";
			}
			$downline .=
			  "   ebtables -t $table -P $chain ACCEPT > /dev/null 2>&1 || true\n";
		}
	}
	
	return ($upline, $downline);
}

sub os_fwrouteconfig_line($$$)
{
    my ($orouter, $fwrouter, $routestr) = @_;
    my ($upline, $downline);

    #
    # XXX assume the original default route should be used to reach servers.
    #
    # For setting up the firewall, this means we create explicit routes for
    # each host via the original default route.
    #
    # For tearing down the firewall, we just remove the explicit routes
    # and let them fall back on the now re-established original default route.
    #
    $upline  = "for vir in $routestr; do\n";
    $upline .= "        $ROUTE delete \$vir >/dev/null 2>&1\n";
    $upline .= "        $ROUTE add -host \$vir gw $orouter || {\n";
    $upline .= "            echo \"Could not establish route for \$vir\"\n";
    $upline .= "            exit 1\n";
    $upline .= "        }\n";
    $upline .= "    done";

    $downline  = "for vir in $routestr; do\n";
    $downline .= "        $ROUTE delete \$vir >/dev/null 2>&1\n";
    $downline .= "    done";

    return ($upline, $downline);
}

# proto for a function used in os_ifdynconfig_cmds
sub getCurrentIwconfig($;$);

#
# Returns a list of commands needed to change the current device state to
# something matching the given configuration options.
#
sub os_ifdynconfig_cmds($$$$$)
{
    my ($ret_aref,$iface,$action,$optref,$ifcfg) = @_;
    my %opts = %$optref;
    my %flags = ();
    # this is the hash returned from getifconfig, but only for this interface
    my %emifc = %$ifcfg;

    my @cmds = ();

    # only handle the atheros case for now, since it's the only one
    # that can be significantly parameterized
    if (exists($emifc{'TYPE'}) && $emifc{'TYPE'} eq 'ath') {
	my ($ifnum) = $iface =~ /wifi(\d+)/;
        my $ath = "ath${ifnum}";
	my $wifi = $iface;

	# check flags
	my ($reset_wlan,$reset_kmod,$remember) = (0,0,0);
	if (exists($opts{'resetkmod'}) && $opts{'resetkmod'} == 1) {
	    $reset_kmod = 1;
	    # note that this forces a wlan reset too!
	    $reset_wlan = 1;
	    delete $opts{'resetkmod'};
	}
	if (exists($flags{'resetwlan'}) && $opts{'resetwlan'} == 1) {
	    $reset_wlan = 1;
	    delete $opts{'resetwlan'};
	}
	# we only want to try to keep similar config options
	# if the user tells us to...
	if (exists($flags{'usecurrent'}) && $opts{'usecurrent'} == 1) {
	    $remember = 1;
	    delete $opts{'usecurrent'};
	}

	# handle the up/down case right away.
	if (($action eq 'up' || $action eq 'down')
	    && scalar(keys(%opts)) == 0) {
	    push @cmds,"$IFCONFIGBIN $ath $action";
	    @$ret_aref = @cmds;
	    return 0;
	}

	# first grab as much current state as we can, so we don't destroy
	# previous state if we have to destroy the VAP (i.e., athX) interface
	#
	# NOTE that we don't bother grabbing current ifconfig state --
	# we assume that the current state is just what Emulab configured!
	my $iwc_ref = getCurrentIwconfig($ath);
	my %iwc = %$iwc_ref;

	# hash containing new config:
	my %niwc;

	# first, whack the emulab and user-supplied configs
	# so that the iwconfig params match what we need to give iwconfig
	# i.e., emulab specifies ssid and we need essid.
	if (exists($emifc{'ssid'})) {
	    $emifc{'essid'} = $emifc{'ssid'};
	    delete $emifc{'ssid'};
	}
	if (exists($opts{'ssid'})) {
	    $opts{'essid'} = $opts{'ssid'};
	    delete $opts{'ssid'};
	}
	if (exists($opts{'ap'})) {
	    $opts{'accesspoint'} = $opts{'ap'};
	    delete $opts{'ap'};
	}
	# we want this to be determined by the keyword 'freq' to iwconfig,
	# not channel
	if (exists($opts{'channel'}) && !exists($opts{'freq'})) {
	    $opts{'freq'} = $opts{'channel'};
	}

	for my $ok (keys(%opts)) {
	    print STDERR "opts kv $ok=".$opts{$ok}."\n";
	}
	for my $tk (keys(%iwc)) {
	    print STDERR "iwc kv $tk=".$iwc{$tk}."\n";
	}

	# here's how we set things up: we set niwc to emulab wireless data
	# (i.e., INTERFACE_SETTINGs), then add in any current state, then
	# add in any of the reconfig options.
	my $key;
	if ($remember) {
	    for $key (keys(%{$emifc{'SETTINGS'}})) {
		$niwc{$key} = $emifc{'SETTINGS'}->{$key};
	    }
	    for $key (keys(%iwc)) {
		$niwc{$key} = $iwc{$key};
	    }
	}
	for $key (keys(%opts)) {
	    $niwc{$key} = $opts{$key};
	}

	for my $nk (keys(%niwc)) {
	    print STDERR "niwc kv $nk=".$niwc{$nk}."\n";
	}

	# see what has changed and what we're going to have to do
	my ($mode_ch,$proto_ch) = (0,0);

	# first, change mode to a string matching those returned by iwconfig:
	if (exists($niwc{'mode'})) {
	    if ($niwc{'mode'} =~ /ad[\s\-]{0,1}hoc/i) {
		$niwc{'mode'} = 'Ad-Hoc';
	    }
	    elsif ($niwc{'mode'} =~ /monitor/i) {
		$niwc{'mode'} = "Monitor";
	    }
	    elsif ($niwc{'mode'} =~ /ap/i
		   || $niwc{'mode'} =~ /master/i) {
		$niwc{'mode'} = "Master";
	    }
	    elsif ($niwc{'mode'} =~ /sta/i
		   || $niwc{'mode'} =~ /managed/i) {
		$niwc{'mode'} = 'Managed';
	    }
	    else {
		print STDERR "ERROR: invalid mode '" . $niwc{'mode'} . "'\n";
		return 10;
	    }
	}

	# also change protocol, sigh
	if (exists($niwc{'protocol'})) {
	    if ($niwc{'protocol'} =~ /(802){0,1}11a/) {
		$niwc{'protocol'} = '80211a';
	    }
	    elsif ($niwc{'protocol'} =~ /(802){0,1}11b/) {
		$niwc{'protocol'} = '80211b';
	    }
	    elsif ($niwc{'protocol'} =~ /(802){0,1}11g/) {
		$niwc{'protocol'} = '80211g';
	    }
	    else {
		print STDERR "ERROR: invalid protocol '" . $niwc{'protocol'} .
		    "'\n";
		return 11;
	    }
	}

	# to be backwards compat:
	# If the user sets a mode, we will put the device in that mode.
	# If the user does not set a mode, but does set an accesspoint,
	#   we force the mode to either Managed or Master.
	# If the user sets neither a mode nor accesspoint, but we are told to
	#   "remember" the current state, we use that mode and ap.
	if (exists($opts{'mode'})) {
	    if ($niwc{'mode'} eq 'Managed' && exists($niwc{'accesspoint'})) {
		# strip colons and lowercase to check if we are the accesspoint
		# or a station:
		my $tap = $niwc{'accesspoint'};
		$tap =~ s/://g;
		$tap = lc($tap);

		my $tmac = lc($emifc{'MAC'});

		if ($tap eq $tmac) {
		    # we are going to be the accesspoint; switch our mode to
		    # master
		    $niwc{'mode'} = 'Master';
		}
		else {
		    $niwc{'mode'} = 'Managed';
		    $niwc{'ap'} = $tap;
		}
	    }
	}
	elsif (exists($opts{'accesspoint'})) {
	    # strip colons and lowercase to check if we are the accesspoint
	    # or a station:
	    my $tap = $niwc{'accesspoint'};
	    $tap =~ s/://g;
	    $tap = lc($tap);

	    my $tmac = lc($emifc{'MAC'});

	    if ($tap eq $tmac) {
		# we are going to be the accesspoint; switch our mode to
		# master
		$niwc{'mode'} = 'Master';
	    }
	    else {
		$niwc{'mode'} = 'Managed';
		$niwc{'ap'} = $tap;
	    }
	}
	elsif ($remember) {
	    # swipe first the old emulab config state, then the current
	    # iwconfig state:

	    # actually, this was already done above.
	}

	# get rid of ap option if we're the master:
	if (exists($niwc{'mode'}) && $niwc{'mode'} eq 'Master') {
	    delete $niwc{'ap'};
	}

	print STDERR "after whacking niwc into compliance:\n";
	for my $nk (keys(%niwc)) {
	    print STDERR "niwc kv $nk=".$niwc{$nk}."\n";
	}

	# assemble params to commands:
	my ($iwc_mode,$wlc_mode);
	my $iwp_mode;

	if (exists($niwc{'mode'}) && $niwc{'mode'} ne $iwc{'mode'}) {
	    $mode_ch = 1;
	}

	if (exists($niwc{'mode'})) {
	    $iwc_mode = $niwc{'mode'};
	    if ($niwc{'mode'} eq 'Ad-Hoc') {
		$wlc_mode = 'adhoc';
	    }
	    elsif ($niwc{'mode'} eq 'Managed') {
		$wlc_mode = 'sta';
	    }
	    elsif ($niwc{'mode'} eq 'Monitor') {
		$wlc_mode = 'monitor';
	    }
	    elsif ($niwc{'mode'} eq 'Master') {
		$wlc_mode = 'ap';
	    }
	}

	if (exists($niwc{'protocol'})) {
	    if ($niwc{'protocol'} ne $iwc{'protocol'}) {
		$proto_ch = 1;
	    }

	    if ($niwc{'protocol'} eq '80211a') {
		$iwp_mode = 1;
	    }
	    elsif ($niwc{'protocol'} eq '80211b') {
		$iwp_mode = 2;
	    }
	    elsif ($niwc{'protocol'} eq '80211g') {
		$iwp_mode = 3;
	    }
	}

	# for atheros cards, if we have to change the mode, we have to
	# first tear down the VAP and rerun wlanconfig, then reconstruct
	# and reconfig the VAP.
	if ($mode_ch == 1) {
	    $reset_wlan = 1;
	}

        # Log what we're going to do:
	if ($reset_wlan && defined($wlc_mode)) {
	    print STDERR "WLANCONFIG: iface=$wifi; mode=$wlc_mode\n";
	}
	if (($proto_ch || $reset_wlan) && defined($iwp_mode)) {
	    print STDERR "IWPRIV: proto=".$niwc{'protocol'}." ($iwp_mode)\n";
	}
	if ($reset_wlan) {
	    print STDERR "IFCONFIG: iface=$ath; ip=" . $emifc{'IPADDR'} .
		"; netmask=" . $emifc{'IPMASK'} . "\n";
	}

	# assemble iwconfig params:
	my $iwcstr = '';
	if (exists($niwc{'essid'})) {
	    $iwcstr .= ' essid ' . $niwc{'essid'};
	}
	if (exists($niwc{'freq'})) {
	    $iwcstr .= ' freq ' . $niwc{'freq'};
	}
	if (exists($niwc{'rate'})) {
	    $iwcstr .= ' rate ' . $niwc{'rate'};
	}
	if (exists($niwc{'txpower'})) {
	    $iwcstr .= ' txpower ' . $niwc{'txpower'};
	}
	if (exists($niwc{'sens'})) {
	    $iwcstr .= ' sens ' . $niwc{'sens'};
	}
	if (exists($niwc{'rts'})) {
	    $iwcstr .= ' rts ' . $niwc{'rts'};
	}
	if (exists($niwc{'frag'})) {
	    $iwcstr .= ' frag ' . $niwc{'frag'};
	}
	if (defined($iwc_mode) && $iwc_mode ne '') {
	    $iwcstr .= " mode $iwc_mode";

	    if ($iwc_mode eq 'Managed') {
		if (exists($niwc{'ap'})) {
		    if (!($niwc{'ap'} =~ /:/)) {
                        # I really dislike perl sometimes.
                        $iwcstr .= ' ap ' .
                            substr($niwc{'ap'},0,2) . ":" .
                            substr($niwc{'ap'},2,2) . ":" .
                            substr($niwc{'ap'},4,2) . ":" .
                            substr($niwc{'ap'},6,2) . ":" .
                            substr($niwc{'ap'},8,2) . ":" .
                            substr($niwc{'ap'},10,2);
                    }
                    else {
			$iwcstr .= ' ap ' . $niwc{'ap'};
		    }
		}
		else {
		    $iwcstr .= ' ap any';
		}
	    }
	}

	print STDERR "IWCONFIG: $iwcstr\n";

        #
        # Generate commands to reconfigure the device.
        #
	if ($action eq 'up') {
	    push @cmds,"$IFCONFIGBIN $ath $action";
	}

	if ($reset_wlan) {
	    push @cmds,"$IFCONFIGBIN $ath down";
	    push @cmds,"$IFCONFIGBIN $wifi down";
	    push @cmds,"$WLANCONFIG $ath destroy";

	    if ($reset_kmod) {
		## also "reset" the kernel modules:
		push @cmds,"$RMMOD ath_pci ath_rate_sample ath_hal";
		push @cmds,"$RMMOD wlan_scan_ap wlan_scan_sta wlan";
		push @cmds,"$MODPROBE ath_pci autocreate=none";
	    }

	    push @cmds,"$WLANCONFIG $ath create wlandev $wifi " .
		"wlanmode $wlc_mode";
	}
	if (($proto_ch || $mode_ch || $reset_wlan) && defined($iwp_mode)) {
	    push @cmds,"$IWPRIV $ath mode $iwp_mode";
	}
	push @cmds,"$IWCONFIG $ath $iwcstr";
	if ($reset_wlan) {
	    push @cmds,"$IFCONFIGBIN $ath inet " . $emifc{'IPADDR'} .
		" netmask " . $emifc{'IPMASK'} . " up";
	    # also make sure routing is up for this interface
	    push @cmds,"/var/emulab/boot/rc.route " . $emifc{'IPADDR'} . " up";
	}

	# We don't do this right now because when we have to reset
	# wlan state to force a new mode, we panic the kernel if we
	# do a wlanconfig without first destroying any monitor mode VAPs.
	# What's more, I haven't found a way to see which VAP is attached to
	# which real atheros device.

	#if ($do_mon_vdev) {
	#    $athmon = "ath" . ($iface_num + 10);
	#    push @cmds,"$WLANCONFIG $athmon create wlandev $wifi wlanmode monitor";
	#    push @cmds,"$IFCONFIGBIN $athmon up";
	#}

	if ($action eq 'down') {
	    push @cmds,"$IFCONFIGBIN $ath $action";
	}
    }
    elsif (exists($emifc{'TYPE'}) && $emifc{'TYPE'} eq 'flex900') {
	# see if we have any flags...
	$resetkmod = 0;
	if (exists($opts{'resetkmod'}) && $opts{'resetkmod'} == 1) {
	    $resetkmod = 1;
	}

	# check args -- we MUST have freq and rate.
	my ($freq,$rate,$carrierthresh,$rxgain);

	if (!exists($opts{'protocol'})
	    || $opts{'protocol'} ne 'flex900') {
	    warn("*** WARNING: Unknown gnuradio protocol specified, " .
		 "assuming flex900!\n");
        }

	if (exists($opts{'frequency'})) {
	    $freq = $opts{'frequency'};
	}
	elsif (exists($opts{'freq'})) {
            $freq = $opts{'freq'};
        }
	else {
	    warn("*** WARNING: No frequency specified for gnuradio ".
                 "interface!\n");
            return undef;
	}

	if (exists($opts{'rate'})) {
	    $rate = $opts{'rate'};
	}
	else {
	    warn("*** WARNING: No rate specified for gnuradio interface!\n");
            return undef;
        }

	if (exists($opts{'carrierthresh'})) {
	    $carrierthresh = $opts{'carrierthresh'};
	}
	if (exists($opts{'rxgain'})) {
	    $rxgain = $opts{'rxgain'};
	}

	#
	# Generate commands
	#
	push @cmds,"$IFCONFIGBIN $iface down";

	# find out if we have to kill the current tunnel process...
	my $tpid;
	if (!open(PSP, "ps axwww 2>&1 |")) {
	    print STDERR "ERROR: open: $!";
	    return 19;
	}
	while (my $psl = <PSP>) {
	    if ($psl =~ /\s*(\d+)\s*.*emulab\/tunnel\.py.*/) {
		$tpid = $1;
		last;
	    }
	}
	close(PSP);
	if (defined($tpid)) {
	    push @cmds,"kill $tpid";
	}

	if ($resetkmod) {
	    push @cmds,"/sbin/rmmod tun";
	    push @cmds,"/sbin/modprobe tun";
	}

	my $tuncmd =
	    "/bin/env PYTHONPATH=/usr/local/lib/python2.4/site-packages " .
	    "$BINDIR/tunnel.py -f $freq -r $rate";
	if (defined($carrierthresh)) {
	    $tuncmd .= " -c $carrierthresh";
	}
	if (defined($rxgain)) {
	    $tuncmd .= " -rx-gain=$rxgain";
	}
	$tuncmd .= " > /dev/null 2>&1 &";
	push @cmds,$tuncmd;

	# Give the tun device time to come up
	push @cmds,"sleep 2";

	my $mac = $emifc{'MAC'};
	push @cmds,"$IFCONFIGBIN $iface hw ether $mac";
	push @cmds,"$IFCONFIGBIN $iface inet " . $emifc{'IPADDR'} .
	    " netmask " . $emifc{'IPMASK'} . " up";
	# also make sure routing is up for this interface
	push @cmds,"/var/emulab/boot/rc.route " . $emifc{'IPADDR'} . " up";
    }

    @$ret_aref = @cmds;

    return 0;
}

my %def_iwconfig_regex = ( 'protocol' => '.+(802.*11[abg]{1}).*',
			   'essid'    => '.+SSID:\s*"*([\w\d_\-\.]+)"*.*',
			   'mode'     => '.+Mode:([\w\-]+)\s+',
			   'freq'     => '.+Frequency:(\d+\.\d+\s*\w+).*',
			   'ap'       => '.+Access Point:\s*([0-9A-Za-z\:]+).*',
			   'rate'     => '.+Rate[:|=]\s*(\d+\s*[\w\/]*)\s*',
			   'txpower'  => '.+ower[:|=](\d+\s*[a-zA-Z]+).*',
			   'sens'     => '.+Sensitivity[:|=](\d+).*',
                           # can't set this on our atheros cards
                           #'retry'    => '.+Retry[:|=](\d+|off).*',
			   'rts'      => '.+RTS thr[:|=](\d+|off).*',
			   'frag'     => '.+Fragment thr[:|=](\d+|off).*',
                           # don't care about this on our cards
                           #'power'    => '.+Power Management[:|=](\d+|off).*',
			 );

#
# Grab current iwconfig data for a specific interface, based on the
# specified regexps (which default to def_iwconfig_regex if unspecified).
# Postprocess the property values so that they can be stuck back into iwconfig.
#
sub getCurrentIwconfig($;$) {
    my ($dev,$regex_ref) = @_;
    my %regexps;

    if (!defined($dev) || $dev eq '') {
        return;
    }
    if (!defined($regex_ref)) {
	%regexps = %def_iwconfig_regex;
    }
    else {
	%regexps = %$regex_ref;
    }

    my %r = ();
    my @output = `$IWCONFIG`;

    my $foundit = 0;
    foreach my $line (@output) {
        if ($line =~ /^$dev/) {
            $foundit = 1;
        }
        elsif ($foundit && !($line =~ /^\s+/)) {
            last;
        }

        if ($foundit) {
            foreach my $iwprop (keys(%regexps)) {
                my $regexp = $regexps{$iwprop};
                if ($line =~ /$regexp/) {
                    $r{$iwprop} = $1;
                }
            }
        }
    }

    # postprocessing.
    # We change the values back to valid args to the iwconfig command
    if (defined($r{'protocol'})) {
        $r{'protocol'} =~ s/\.//g;
    }

    if (defined($r{'rate'})) {
        if ($r{'rate'} =~ /^(\d+) Mb\/s/) {
            $r{'rate'} = "${1}M";
        }
        else {
            $r{'rate'} = $1;
        }
    }

    if (defined($r{'txpower'})) {
        if ($r{'txpower'} =~ /^(\d+)/) {
            $r{'txpower'} = $1;
        }
        else {
            $r{'txpower'} = 'auto';
        }
    }

    if (defined($r{'freq'})) {
        $r{'freq'} =~ s/\s//g;
    }

    foreach my $rk (keys(%r)) {
	print STDERR "gci $rk=".$r{$rk}."\n";
    }

    return \%r;
}

sub os_config_gre($$$$$$$;$)
{
    my ($name, $unit, $inetip, $peerip, $mask, $srchost, $dsthost, $tag) = @_;

    require Socket;
    import Socket;

    my $dev = "$name$unit";

    if (GENVNODE() && GENVNODETYPE() eq "openvz") {
	$dev = "gre$unit";

	if (system("$IFCONFIGBIN $dev $inetip netmask $mask mtu 1472 up")) {
	    warn("Could not start tunnel $dev!\n");
	    return -1;
	}
	return 0;
    }
    # This gre key stuff is not ready yet. 
    my $keyopt = "";
    if (defined($tag)) {
	my $grekey = inet_ntoa(pack("N", $tag));
	$keyopt = "key $grekey";
    }
    
    if (system("ip tunnel add $dev mode gre ".
		  "remote $dsthost local $srchost $keyopt") ||
	   system("ip link set $dev up") ||
	   system("ip addr add $inetip dev $dev") ||
	   system("$IFCONFIGBIN $dev netmask $mask")) {
	warn("Could not start tunnel $dev!\n");
	return -1;
    }
    return 0;
}

sub os_get_disks()
{
	my @blockdevs;

	@blockdevs = map { s#/sys/block/##; $_ } glob('/sys/block/*');

	return @blockdevs;
}

sub os_get_ctrlnet_ip()
{
	my $iface;
	my $address;

	# just use recorded IP if available
	if (-e "$BOOTDIR/myip") {
	    $myip = `cat $BOOTDIR/myip`;
	    chomp($myip);
	    return $myip;
	}

	if (!open CONTROLIF, "$BOOTDIR/controlif") {
		return undef;
	}

	$iface = <CONTROLIF>;
	chomp $iface;

	$iface =~ /(.*)/;
	$iface = $1;

	close CONTROLIF;

	if (!open IFCFG, "$IFCONFIGBIN $iface|") {
		return undef;
	}

	while (<IFCFG>) {
		if (/inet addr: ([0-9.]*) /) {
			$address = $1;
			last;
		}
	}

	close IFCFG;

	return $address;
}

sub os_get_disk_size($)
{
	my ($disk) = @_;
	my $size;

	$disk =~ s#^/dev/##;

	if (!open SIZE, "/sys/block/$disk/size") {
		warn "Couldn't open /sys/block/$disk/size: $!\n";
		return undef;
	}
	$size = <SIZE>;
	close SIZE;
	chomp $size;

	$size = $size * 512 / 1024 / 1024;

	return $size;
}

sub os_get_partition_info($$)
{
    my ($bootdev, $partition) = @_;

    $bootdev =~ s#^/dev/##;

    if (!open(FDISK, "fdisk -l /dev/$bootdev |")) {
	print("Failed to run fdisk on /dev/$bootdev!");
	return -1;
    }

    while (<FDISK>) {
	    next if (!m#^/dev/$bootdev$partition\s+#);

	    s/\*//;

	    my ($length, $ptype) = (split /\s+/)[3,4];

	    $length =~ s/\+$//;
	    $ptype = hex($ptype);

	    close FDISK;

	    return ($length, $ptype);
    }

    print "No such partition in fdisk summary info for MBR on /dev/$bootdev!\n";
    close FDISK;

    return -1;
}

sub os_nfsmount($$$)
{
    my ($remote,$local,$transport) = @_;
    my $opts = "nolock";

    # XXX backward compat: force UDP
    if (!defined($transport)) {
	$opts .= ",udp";
    }
    elsif ($transport eq "TCP") {
	$opts .= ",tcp";
    }
    elsif ($transport eq "UDP") {
	$opts .= ",udp";
    }
    elsif ($transport eq "osdefault") {
	;
    }

    # XXX doesn't work without this
    if (INXENVM()) {
	$opts .= ",rsize=1024,wsize=1024";
    }

    #
    # XXX newer mount commands default to v4 and don't recognize "nolock".
    # Since we are not setup for v4 now anyway, explicitly try vers=3 first
    # and then fall back on vers=2 and then the default.
    #
    if (system("/bin/mount -o vers=3,$opts $remote $local") &&
	system("/bin/mount -o vers=2,$opts $remote $local") &&
	system("/bin/mount $remote $local")) {
	return 1;
    }

    return 0;
}

#
# Create/mount a local filesystem on the extra partition if it hasn't
# already been done.  Returns the resulting mount point (which may be
# different than what was specified as an argument if it already existed).
#
sub os_mountextrafs($)
{
    my $dir = shift;
    my $mntpt = "";
    my $log = "$VARDIR/logs/mkextrafs.log";
    my $disk = "";
    my $part = "";

    #
    # Parse /etc/fstab
    #
    my %fses = ();
    if (open(FD, "</etc/fstab")) {
	while (<FD>) {
	    if (/^#/) {
		next;
	    }
	    if (/^(\S+)\s+(\S+)/) {
		$fses{$2} = $1;
	    }
	}
	close(FD);
    }

    #
    # If the desired directory name is already a mount point, just use it.
    #
    if (exists($fses{$dir})) {
	return $dir;
    }

    #
    # Otherwise, if the extrafs file was written, use the info from there.
    #
    my $extrafs = libsetup::TMEXTRAFS();
    if (-f "$extrafs" && open(FD, "<$extrafs")) {
	my $line = <FD>;
	close(FD);
	chomp($line);
	if ($line =~ /^PART=(.*)/) {
	    $part = $1;
	    goto makeit;
	}
	if ($line =~ /^DISK=(.*)/) {
	    $disk = $1;
	    goto makeit;
	}
	if ($line =~ /^FS=(.*)/) {
	    $mntpt = $1;
	}

        return $mntpt;
    }

    #
    # Finally, we look for partition 4 of the root disk and use that!
    # XXX this is a most bogus hack.
    #
    foreach $mntpt (keys %fses) {
	if ($fses{$mntpt} =~ /^\/dev\/(hd|sd|xvd)a4$/) {
	    return $mntpt;
	}
    }

    print STDERR "os_mountextrafs: no suitable device found!\n";
    return "";

makeit:
    my $args = "-f";

    if ($part) {
	if ($part =~ /^((?:hd|sd|xvd)[a-z])(\d+)$/) {
	    $args .= " -r $1 -s $2";
	}
    } elsif ($disk) {
	$args .= " -r $disk -s 0";
    }

    if (!system("$BINDIR/mkextrafs.pl $args $dir >$log 2>&1")) {
	$mntpt = $dir;
    } else {
	print STDERR "mkextrafs failed, see $log\n";
    }

    return $mntpt;
}

#
# Read the current arp info and create a hash for it.
#
sub os_getarpinfo($$)
{
    my ($diface,$airef) = @_;
    my %arpinfo = ();

    if (!open(ARP, "$ARP -a|")) {
	print "os_getarpinfo: Cannot run arp command\n";
	return 1;
    }

    while (<ARP>) {
	if (/^(\S+) \(([\d\.]+)\) at (..:..:..:..:..:..) (.*) on (\S+) /) {
	    my $name = $1;
	    my $ip = $2;
	    my $mac = lc($3);
	    my $stuff = $4;
	    my $iface = $5;

	    # this is not the interface you are looking for...
	    if ($diface ne $iface) {
		next;
	    }

	    # Skip aliases.
	    next
		if (system("$BINDIR/findif -i $ip >/dev/null 2>&1") == 0);

	    if (exists($arpinfo{$ip})) {
		if ($arpinfo{$ip}{'mac'} ne $mac) {
		    print "os_getarpinfo: Conflicting arpinfo info for $ip:\n";
		    print "    '$_'!?\n";
		    return 1;
		}
	    }
	    $arpinfo{$ip}{'name'} = $name;
	    $arpinfo{$ip}{'mac'} = $mac;
	    $arpinfo{$ip}{'iface'} = $iface;
	    if ($stuff =~ /PERM/) {
		$arpinfo{$ip}{'static'} = 1;
	    } else {
		$arpinfo{$ip}{'static'} = 0;
	    }
	}
    }
    close(ARP);

    %$airef = %arpinfo;
    return 0;
}

#
# Create a static ARP entry given info in the supplied hash.
# Returns zero on success, non-zero otherwise.
#
sub os_createarpentry($$$)
{
    my ($iface, $ip, $mac) = @_;

    return system("$ARP -i $iface -s $ip $mac >/dev/null 2>&1");
}

sub os_removearpentry($;$)
{
    my ($iface, $ip) = @_;

    #
    # XXX ugh, Linux arp doesn't support clearing all entries.
    # Do it the hard way!
    #
    if (!defined($ip)) {
	my %info = ();
	if (!os_getarpinfo($iface, \%info)) {
	    my $err = 0;
	    foreach my $_ip (keys %info) {
		if (system("$ARP -i $iface -d $_ip >/dev/null 2>&1")) {
		    $err++;
		}
	    }
	    return $err;
	}
	return 0;
    }
    return system("$ARP -i $iface -d $ip >/dev/null 2>&1");
}

#
# Returns whether static ARP is enabled or not in the passed param.
# Return zero on success, an error otherwise.
#
sub os_getstaticarp($$)
{
    my ($iface,$isenabled) = @_;

    my $info = `$IFCONFIGBIN $iface 2>/dev/null`;
    return $?
	if ($?);

    if ($info =~ /NOARP/) {
	$$isenabled = 1;
    } else {
	$$isenabled = 0;
    }

    return 0;
}

#
# Turn on/off static ARP on the indicated interface.
# Return zero on success, an error otherwise.
#
sub os_setstaticarp($$)
{
    my ($iface,$enable) = @_;
    my $curenabled = 0;

    os_getstaticarp($iface, \$curenabled);
    if ($enable && !$curenabled) {
	return system("$IFCONFIGBIN $iface -arp >/dev/null 2>&1");
    }
    if (!$enable && $curenabled) {
	return system("$IFCONFIGBIN $iface arp >/dev/null 2>&1");
    }

    return 0;
}

# Is a device mounted.
sub os_ismounted($)
{
    my ($device) = @_;

    my $line = `$MOUNT | grep '^${device} on'`;

    return ($line ? 1 : 0);
}

sub os_unmount($)
{
    my ($mpoint) = @_;

    return system("$UMOUNT $mpoint");
}

sub os_mount($;$)
{
    my ($mpoint, $device) = @_;
    $device = "" if (!defined($device));

    return system("$MOUNT $mpoint $device");
}

1;
