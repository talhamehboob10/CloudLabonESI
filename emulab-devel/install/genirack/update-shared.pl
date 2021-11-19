#!/usr/bin/perl -w
use strict;
use Getopt::Std;

use lib "/usr/testbed/lib";
use emdb;

sub usage {
    print "Usage: $0 [options] -t type -t func [node ...]\n";
    print "Options:\n";
    print "-l       - limit to N nodes of the type\n";
    print "-f func  - function to run\n";
    print "-t type  - xen or openvz\n";
    exit(1);
}
my $optlist    = "l:t:f:c";
my $limit      = 0;
my $docounts   = 0;
my $type;
my $fname;
my @nodes      = ();
my %osnames    = ();

#
# Turn off line buffering on output
#
$| = 1;

#
# Check args.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (defined($options{"l"})) {
    $limit = $options{"l"};
}
if (defined($options{"t"})) {
    $type = $options{"t"};
}
if (defined($options{"f"})) {
    $fname = $options{"f"};
    if ($fname eq "docounts") {
	$docounts = 1;
    }
}
if (defined($options{"c"})) {
    $docounts = 1;
}
usage()
    if (!defined($type) || !($type eq "xen" || $type eq "openvz"));
usage()
    if (!(defined($fname) || $docounts));

if (@ARGV) {
    @nodes = @ARGV;
}
else {
    #
    # Set the limit=1 when using the rebuild function.
    #
    if (defined($fname) && $fname eq "BuildClientSide") {
	$limit = 1;
    }

    #
    # Get list of nodes in the shared pool, for the given type.
    #
    my $osclause;
    if ($type eq "xen") {
	$osclause = "(o.osname='XEN43-64-STD' or o.osname='XEN44-64-BIGFS' or ".
	    "o.osname='XEN44-64-GENIRACK' or o.osname='XEN44-64-STD')";
    }
    else {
	$osclause = "o.osname='FEDORA15-OPENVZ-STD'";
    }
    my $query_result =
	DBQueryFatal("select r.node_id,r.vname,o.osname from reserved as r ".
		     "left join nodes as n on n.node_id=r.node_id ".
		     "left join os_info as o on o.osid=n.def_boot_osid ".
		     "where r.sharing_mode is not null and ".
		     "      n.phys_nodeid=n.node_id and ".
		     "      $osclause order by r.node_id ".
		     ($limit ? "limit $limit" : ""));
    while (my ($nodeid,undef,$osname) = $query_result->fetchrow_array()) {
	push(@nodes, $nodeid);
	$osnames{$nodeid} = $osname;
    }
}
if ($docounts) {
    foreach my $nodeid (@nodes) {
	my $query_result =
	    DBQueryFatal("select count(n.node_id) from nodes as n ".
			 "where n.phys_nodeid='$nodeid' and ".
			 "      n.phys_nodeid!=n.node_id");
	my ($count) = $query_result->fetchrow_array();
	my $osname  = $osnames{$nodeid};
	print "$nodeid ($osname): $count\n";
    }
    exit(0);
}
print "Updating shared node: @nodes\n";

my $opts   = "-q -o BatchMode=yes -o StrictHostKeyChecking=no";
my $eltb   = "/users/elabman/emulab-devel";
my $objdir = ($type eq "xen" ? "obj-xen" : "obj-fc15");

sub echo($)	{ print "echo\n"; }

#
# Build the client side.
#
sub BuildClientSide($)
{
    my ($node) = @_;

    system("mkdir $eltb/$objdir")
	if (! -e "$eltb/$objdir");

    system("sudo ssh $opts $node 'cd $eltb/$objdir; sudo -u elabman ".
	   "  ../emulab-devel/clientside/configure ".
	   "     --with-TBDEFS=../defs-genirack --disable-windows ".
	   "           >& /tmp/config.log'");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   "  'cd $eltb/$objdir; ".
	   "   sudo -u elabman make client >& /tmp/make.log'");
    return -1
	if ($?);
}

#
# Update the client side,
#
sub UpdateClientSide($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/tmcc; ".
	   "    make client-install >& /tmp/install.log'");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/tmcc/linux; ".
	   "    make ${type}-install >& /tmp/install-${type}.log' ");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/os; ".
	   "    make client-install >& /tmp/install-os.log'");
    
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/protogeni; ".
	   "    make client-install >& /tmp/install.log'");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/os/capture; ".
	   "    make client-install >& /tmp/install.log'");
    return -1
	if ($?);

    return 0;
}

#
# Update the client side,
#
sub UpdateXenInstall($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node ".
	   " 'cd $eltb/$objdir/tmcc/linux; ".
	   "    make ${type}-install >& /tmp/install-${type}.log' ");
    return -1
	if ($?);
}

#
# Update ssl for Heartbleed.
#
sub UpdateOpenSSL($)
{
    my ($node) = @_;

    if (0) {
    system("sudo ssh $opts $node ".
	   " 'iptables -P OUTPUT ACCEPT; apt-get update' ");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " 'apt-get install -y openssl libssl1.0.0' ");
    return -1
	if ($?);
    }
    else {
	system("sudo ssh $opts $node ".
	       " 'iptables -P OUTPUT DROP' ");
	return -1
	    if ($?);
    }

    return 0;
}

sub EnableFirewall($)
{
    my ($node) = @_;

    system("sudo ssh $opts $node ".
	   " '/usr/local/etc/emulab/tmcc -c firewallinfo'");
    return -1
	if ($?);

    system("sudo ssh $opts $node ".
	   " '/usr/local/etc/emulab/rc/rc.firewall boot'");
    return -1
	if ($?);

    return 0;
}

sub DisableFirewall($)
{
    my ($node) = @_;

    system("sudo ssh $opts $node ".
	   " '/var/emulab/boot/rc.fw disable'");
    return -1
	if ($?);

    return 0;
}

sub FixFirewall($)
{
    my ($node) = @_;

    system("sudo ssh $opts $node ".
	   " 'iptables -A INPUT -p tcp -d $node -s 172.16.0.0/12 ".
	   "    --dport 16505 -m conntrack --ctstate NEW -j ACCEPT");
    return -1
	if ($?);

    return 0;
}

sub JumboEnable($)
{
    my ($node) = @_;

    system("sudo ssh $opts $node ".
	   " 'ifconfig eth1 mtu 9000; ifconfig eth2 mtu 9000; ".
	   "  ifconfig eth3 mtu 9000; ifconfig eth1.1750 mtu 9000; ".
	   "  ifconfig eth2.1750 mtu 9000; ifconfig eth3.1750 mtu 9000 '");
    return -1
	if ($?);

    return 0;
}

sub UpdateVZGuest($)
{
    my ($node) = @_;
    
    system("sudo scp $opts $eltb/emulab-devel/stuff/emulab-default.tar.gz ".
	   "    ${node}:/vz/template/cache");
    return -1
	if ($?);

    system("sudo scp $opts $eltb/emulab-devel/stuff/emulab-default.tar.gz ".
	   "    ${node}:/vz.save/template/cache");
    return -1
	if ($?);

    return 0;
}

sub EnableVIFRouting($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node ".
	   " 'echo 1 >/proc/sys/net/ipv4/conf/xenbr0/proxy_arp; ".
	   "  echo 1 >/proc/sys/net/ipv4/ip_forward; ".
	   "  echo 1 >/proc/sys/net/ipv4/ip_nonlocal_bind'");
    
    return -1
	if ($?);

    return 0;
}

sub CheckVolumes($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node pvs");
    return -1
	if ($?);

    return 0;
}

sub RestartClusterd($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node killall clusterd");
    sleep(1);
    system("sudo ssh $opts $node /usr/local/libexec/clusterd -s event-server");
    return -1
	if ($?);

    return 0;
}

sub FixMounts($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node /usr/local/etc/emulab/rc/rc.mounts shutdown");
    return -1
	if ($?);
    system("sudo ssh $opts $node /usr/local/etc/emulab/rc/rc.mounts boot");
    return -1
	if ($?);

    return 0;
}

sub ClearLogs($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node rm -f /var/log/syslog /var/log/emulab.log");
    return -1
	if ($?);
    system("sudo ssh $opts $node 'kill -HUP `cat /var/run/rsyslogd.pid`'");
    return -1
	if ($?);

    return 0;
}

sub FixDHCP($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node ls -l /etc/dhcp/dhcpd.conf");
    return -1
	if ($?);

    return 0;
}

sub HaltAllVMs($)
{
    my ($node) = @_;
    
    system("sudo ssh $opts $node xl shutdown -a -w");
    return -1
	if ($?);

    return 0;
}

foreach my $node (@nodes) {
    print "Doing $node ...\n";

    # strict whines about something, so do it this way.
    my $foo = \&$fname;
    $foo->($node);
}
exit(0);

