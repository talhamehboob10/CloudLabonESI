#!/usr/bin/perl
use strict;
use Getopt::Std;
use POSIX qw(strftime);
use File::Basename;
use lib "/usr/testbed/lib";
use emutil;

#  wap /usr/testbed/sbin/update_sitevars 
#  wap /usr/testbed/bin/editnodetype ../emulab-devel/install/ctrltype.xml 
#  wap /usr/testbed/sbin/addservers 
#  wap setsitevar general/arplockdown staticonly

sub usage {
    print "Usage: $0 [options] [rack]\n";
    print "Options:\n";
    print "-r      - Rsync software to rack.\n";
    print "-R dir  -   (rsync specific directory (say, install/genirack)\n";
    print "-b      - Build the software (with reconfig).\n";
    print "-i      - Install on each rack.\n";
    print "-p arg  - Update shared pool on each rack.\n";
    print "          arg is type,func where type=xen|openvz\n";
    print "-u      - Do Utah rack.\n";
    print "-d      - Do DDC rack.\n";
    print "-a      - Do APT rack.\n";
    print "-l      - Do Cloudlab (Utah) rack.\n";
    print "-U      - Skip Utah rack.\n";
    print "-D      - Skip DDC rack.\n";
    print "-7      - Just G7 racks.\n";
    print "-8      - Just G8 racks.\n";
    print "-f      - Run function instead. Add -F to shutdown testbed\n";
    print "          Add -o to ssh to ops instead\n";
    print "          Add -c to ssh to control instead\n";
    print "-s      - No parallelization in -r, -f, or -b.\n";
    print "-t      - Tag source with instageni-YYYYMMDD\n";
    print "-S dir  - Directory where src directories are stored\n";
    print "rack    - Specific rack, or all racks\n";
    exit(1);
}
my $optlist    = "binuUdDhfForlc78tsp:aAR:CLS:I:";
my $rebuild    = 0;
my $install    = 0;
my $installdir;
my $rsync      = 0;
my $rsyncdir;
my $dofunc     = 0;
my $dofuncops  = 0;
my $doscp      = 0;
my $dotag      = 0;
my $nopar      = 0;
my $doctrl     = 0;
my $dopool;
my $rack;

my $TB            = "/usr/testbed";
my $UTAHBOSS      = "boss.utah.geniracks.net";
my $UTAHCTRL      = "control.utah.geniracks.net";
my $DDCBOSS       = "boss.utahddc.geniracks.net";
my $DDCCTRL       = "control.utahddc.geniracks.net";
my $STITCHBOSS    = "boss.stitch.geniracks.net";
my $APTBOSS       = "boss.apt.emulab.net";
my $APTCTRL       = "";
my $UTAHCLOUDBOSS = "boss.utah.cloudlab.us";
my $UTAHCLOUDCTRL = "";
my $CLEMCLOUDBOSS = "boss.clemson.cloudlab.us";
my $CLEMCLOUDCTRL = "";
my $WISCCLOUDBOSS = "boss.wisc.cloudlab.us";
my $WISCCLOUDCTRL = "";

my %CLOUDCLUSTERS = ("apt"     => [ $APTBOSS, $APTCTRL ],
		     "utah"    => [ $UTAHCLOUDBOSS, $UTAHCLOUDCTRL ],
		     "wisc"    => [ $WISCCLOUDBOSS, $WISCCLOUDCTRL ],
		     "clemson" => [ $CLEMCLOUDBOSS, $CLEMCLOUDCTRL ],
		     "utahddc" => [ $DDCBOSS, $DDCCTRL ],
		     "stitch"  => [ $STITCHBOSS, $DDCCTRL ],
#		     "onelab"  => [ "boss.lab.onelab.eu", "" ],
);
my %UTAHCLUSTERS =  ("utahig"  => [ $UTAHBOSS, $UTAHCTRL ],
		     "utahddc" => [ $DDCBOSS, $DDCCTRL ],
		     "stitch"  => [ $STITCHBOSS, $DDCCTRL ],
		     "cisco"   => [ "cisco.boss.geniracks.net",
				    "cisco.control-nodes.geniracks.net" ],
);
my %G7RACKS  = (
		"bbn"       => [ "boss.instageni.gpolab.bbn.com",
				 "gpolab.control-nodes.geniracks.net" ],
		"nwu"       => [ "boss.instageni.northwestern.edu",
				 "nu.control-nodes.geniracks.net" ],
		"uky"       => [ "boss.lan.sdn.uky.edu",
				 "uky.control-nodes.geniracks.net" ],
		"kettering" => [ "boss.geni.kettering.edu",
				 "kettering.control-nodes.geniracks.net"],
#		"gatech"    => [ "boss.instageni.rnoc.gatech.edu",
#				 "gatech.control-nodes.geniracks.net" ],
		"princeton" => [ "boss.instageni.cs.princeton.edu",
				 "princeton.control-nodes.geniracks.net" ],
		"clemson"   => [ "boss.instageni.clemson.edu",
				 "clemson.control-nodes.geniracks.net" ],
		"kansas"    => [ "boss.instageni.ku.gpeni.net",
				 "kansas.control-nodes.geniracks.net" ],
		"nyu"       => [ "boss.genirack.nyu.edu",
				 "nyu.control-nodes.geniracks.net" ],
# Off the air.
#		"idaho"     => [ "boss.instageni.uidaho.edu",
#				 "idaho.control-nodes.geniracks.net" ],
);
my %G8RACKS = ("max"        => [ "boss.instageni.maxgigapop.net",
				 "max.control-nodes.geniracks.net" ],
	       "nysernet"   => [ "boss.instageni.nysernet.org",
				 "nysernet.control-nodes.geniracks.net" ],
#	       "sox"        => [ "boss.instageni.sox.net",
#				 "sox.control-nodes.geniracks.net" ],
	       "urbana"     => [ "boss.instageni.illinois.edu",
				 "urbana.control-nodes.geniracks.net" ],
	       "missouri"   => [ "boss.instageni.rnet.missouri.edu",
				 "missouri.control-nodes.geniracks.net" ],
	       "wisc"       => [ "boss.instageni.wisc.edu",
				 "wisc.control-nodes.geniracks.net" ],
	       "rutgers"    => [ "boss.instageni.rutgers.edu",
				 "rutgers.control-nodes.geniracks.net" ],
	       "stanford"   => [ "boss.instageni.stanford.edu",
				 "stanford.control-nodes.geniracks.net" ],
	       "cornell"    => [ "boss.geni.it.cornell.edu",
				 "cornell.control-nodes.geniracks.net" ],
	       "lsu"	    => [ "boss.instageni.lsu.edu",
				 "lsu.control-nodes.geniracks.net" ],
	       "case"	    => [ "boss.geni.case.edu",
				 "casewestern.control-nodes.geniracks.net" ],
	       "moxi"	    => [ "boss.instageni.iu.edu",
				 "moxi.control-nodes.geniracks.net" ],
	       "chicago"    => [ "boss.geni.uchicago.edu",
				 "chicago.control-nodes.geniracks.net" ],
	       "metro"	    => [ "boss.instageni.metrodatacenter.com",
				 "dublin.control-nodes.geniracks.net" ],
	       "nps"        => [ "boss.instageni.nps.edu",
				 "nps.control-nodes.geniracks.net" ],
# Off the air
#	       "ohio"       => [ "boss.instageni.osu.edu",
#				 "ohio.control-nodes.geniracks.net" ],
	       "umkc"       => [ "boss.instageni.umkc.edu",
				 "umkc.control-nodes.geniracks.net" ],
	       "ucla"	    => [ "boss.instageni.idre.ucla.edu",
				 "ucla.control-nodes.geniracks.net" ],
	       "uky2"       => [ "boss.pks2.sdn.uky.edu",
				 "uky2.control-nodes.geniracks.net" ],
	       "uky3"       => [ "boss.mcv.sdn.uky.edu",
				 "uky3.control-nodes.geniracks.net" ],
	       "boulder"    => [ "boss.instageni.colorado.edu",
				 "boulder.control-nodes.geniracks.net" ],
	       "cenic"      => [ "boss.instageni.cenic.net",
				 "cenic.control-nodes.geniracks.net" ],
	       "uw"         => [ "boss.instageni.washington.edu",
				 "uw.control-nodes.geniracks.net" ],
	       "utc"        => [ "boss.instageni.utc.edu",
				 "utc.control-nodes.geniracks.net" ],
	       "vt"         => [ "boss.instageni.arc.vt.edu",
				 "vt.control-nodes.geniracks.net" ],
	       "vcu"        => [ "boss.vcu.instageni.net",
				 "vcu.control-nodes.geniracks.net" ],
	       "umich"      => [ "boss.instageni.research.umich.edu",
				 "umich.control-nodes.geniracks.net" ],
	       "hawaii"     => [ "boss.instageni.hawaii.edu",
				 "usignite.control-nodes.geniracks.net" ],
	       "uvm"        => [ "boss.instageni.uvm.edu",
				 "uvm.control-nodes.instageni.net" ],
	      "dallas"     => [ "boss.instageni.utdallas.edu",
				"utdallas.control-nodes.instageni.net" ],
	      "lafayette"  => [ "boss.instageni.louisiana.edu",
				"ullafayette.control-nodes.instageni.net" ],
);

sub fatal($)
{
    my ($msg) = @_;

    die("*** $0:\n".
	"    $msg\n");
}
sub SSH($$);
sub TagSchema();

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
if (defined($options{"h"})) {
    usage();
}
# Look at "control" option before setting racks.
my $which    = (defined($options{"c"}) ? 1 : 0);
my $UTAHRACK = (defined($options{"c"}) ? $UTAHCTRL : $UTAHBOSS);
my $DDCRACK  = (defined($options{"c"}) ? $DDCCTRL  : $DDCBOSS);
my $APTRACK  = (defined($options{"c"}) ? $APTCTRL  : $APTBOSS);
my $CLOUDRACK= (defined($options{"c"}) ? $UTAHCLOUDCTRL  : $UTAHCLOUDBOSS);
my @G7RACKS  = map { $G7RACKS{$_}[$which] } keys(%G7RACKS);
my @G8RACKS  = map { $G8RACKS{$_}[$which] } keys(%G8RACKS);
my @ALLCLOUD = map { $CLOUDCLUSTERS{$_}[$which] } keys(%CLOUDCLUSTERS);
my @ALLRACKS = (@G7RACKS, @G8RACKS);
my @TODO     = @ALLRACKS;
my %SKIP     = ();

# Default.
my $HOME     = $ENV{"HOME"};
my $TBSRC    = "$HOME/emulab-devel";

if (defined($options{"i"})) {
    $install = 1;
}
if (defined($options{"I"})) {
    $install    = 1;
    $installdir = $options{"I"};
}
if (defined($options{"c"})) {
    $doctrl = 1;
}
if (defined($options{"s"})) {
    $nopar = 1;
}
if (defined($options{"S"})) {
    $TBSRC = $options{"S"};
}
if (defined($options{"f"})) {
    $dofunc = 1;
    if (defined($options{"F"})) {
	$dofunc++;
    }
    if (defined($options{"o"})) {
	$dofuncops++;
    }
}
if (defined($options{"b"})) {
    $rebuild = 1;
}
if (defined($options{"r"})) {
    $rsync = 1;
}
if (defined($options{"R"})) {
    $rsync    = 1;
    $rsyncdir = $options{"R"};
}
if (defined($options{"p"})) {
    $dopool = $options{"p"};
    $dofunc = 1;
}
if (defined($options{"u"}) || defined($options{"d"}) ||
    defined($options{"a"}) || defined($options{"l"})) {
    @TODO = ();
    push(@TODO, $CLOUDRACK)
	if (defined($options{"l"}));
    push(@TODO, $APTRACK)
	if (defined($options{"a"}));
    push(@TODO, $UTAHRACK)
	if (defined($options{"u"}));
    push(@TODO, $DDCRACK)
	if (defined($options{"d"}));
}
elsif (defined($options{"7"})) {
    @TODO = @G7RACKS;
}
elsif (defined($options{"8"})) {
    @TODO = @G8RACKS;
}
elsif (defined($options{"C"})) {
    if (@ARGV) {
	@TODO = ();
	foreach my $arg (@ARGV) {
	    if (exists($CLOUDCLUSTERS{$arg})) {
		push(@TODO, $CLOUDCLUSTERS{$arg}[$which]);
	    }
	    else {
		fatal("No such rack: $arg");
	    }
	}
    }
    else {
	@TODO = @ALLCLOUD;
    }
}
elsif (@ARGV) {
    @TODO = ();
    
    foreach my $arg (@ARGV) {
	if ($arg =~ /\./) {
	    push(@TODO, $arg);
	}
	elsif (exists($G7RACKS{$arg})) {
	    push(@TODO, $G7RACKS{$arg}[$which]);
	}
	elsif (exists($G8RACKS{$arg})) {
	    push(@TODO, $G8RACKS{$arg}[$which]);
	}
	elsif (exists($UTAHCLUSTERS{$arg})) {
	    push(@TODO, $UTAHCLUSTERS{$arg}[$which]);
	}
	else {
	    fatal("No such rack: $arg");
	}
    }
}
else {
    @TODO = @ALLRACKS;
}

if (! -e $TBSRC) {
    fatal("$TBSRC does not appear to exist. Use the -S option?");
}
foreach my $file ("emulab-devel", "pubsub", ".rsyncignore") {
    fatal("$file does not exist in $TBSRC")
	if (! -e "$TBSRC/$file");
}

if (defined($options{"t"})) {
    TagSchema();
}

#
# Just a way to run some little bits of code on the target. 
#
if ($dofunc && !$install) {
    my $coderef = sub {
	my ($rack) = @_;

	print "Running function on $rack ...\n";

	if ($dofunc > 1) {
	    print "-> Shutting down testbed ...\n";
	    if (SSH($rack,
		  "(sudo $TB/sbin/testbed-control shutdown >& shutdown.log)")) {
		print STDERR "** could not shutdown!\n";
		return 1;
	    }
	}
	my $rackops = $rack;
	$rackops =~ s/^boss/ops/;
	my $devel  = "emulab-devel/emulab-devel";
	my $devobj = "emulab-devel/obj";
	my $wap    = "/usr/testbed/sbin/withadminprivs";
	my $sbin   = "/usr/testbed/sbin";
	my $import = "/usr/testbed/sbin/image_import";
	
	print "-> Running function ...\n";
	my $command = "";
	if (defined($dopool)) {
	    my ($type,$func,$limit) = split(',', $dopool);
	    usage()
		if (!(defined($type) && defined($func)));
	    
	    $command = "$devel/update-shared.pl -t $type -f $func ".
		(defined($limit) ? "-l $limit" : "");
	}
	elsif (0) {
	    $command = "sudo sed -i.bak -e ".
	     "'s/genirack-ops\@flux.utah.edu/instageni-ops\@googlegroups.com/' ".
	     "  /etc/mail/lists/testbed-ops";
	}
	elsif (0) {
	    if (0) {
		$command = "sudo mkadmin.pl codybum foo/cody.pub";
	    }
	    elsif (0) {
		$command = "/usr/testbed/sbin/wap /usr/testbed/sbin/newuser ".
		    "-s $devel/stuff/rhyat1.xml";
	    }
	    else {
		$command =
		    "cat $devel/stuff/uky.sql | mysql tbdb; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/modgroups ".
		    "-s -a emulab-ops:emulab-ops:group_root nasir; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/modgroups ".
		    "-s -a emulab-ops:emulab-ops:group_root codybum; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/modgroups ".
		    "-s -a emulab-ops:emulab-ops:group_root rhyat1; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/tbacct ".
		    "-f mod codybum; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/tbacct ".
		    "-f mod rhyat1; ".
		    "/usr/testbed/sbin/wap /usr/testbed/sbin/tbacct ".
		    "-f mod nasir ";
	    }
	}
	elsif (0) {
	    $command = "sudo /usr/local/etc/rc.d/tftpd-hpa.sh stop; sleep 2; ".
		"sudo /usr/local/etc/rc.d/tftpd-hpa.sh start";
	}
	elsif (0) {
	    $command = "sudo /usr/testbed/sbin/backup -c -y";
	}
	elsif (0) {
	    $command = "cd $devobj/firewall; gmake insertrules insertvars";
	}
	elsif (0) {
	    $command = "cd $devel/stuff; perl arch.pl";
	}
	elsif (0) {
	    $command = "cd $devobj/rc.d; gmake; sudo gmake install";
	}
	elsif (0) {
	    #$command = "cd pubsub; gmake clean; ./configure; gmake; ";
	    $command = 
		"cd pubsub; sudo gmake install; ".
		"sudo /usr/local/etc/rc.d/2.pubsubd.sh stop; ".
		"sudo /usr/local/etc/rc.d/4.igforwarder.sh stop; ".
		"sleep 1; ".
		"sudo /usr/local/etc/rc.d/2.pubsubd.sh start; ".
		"sleep 1; ".
		"sudo /usr/local/etc/rc.d/4.igforwarder.sh start";
	}
	elsif (0) {
	    $command = "cd pubsub; ./configure; gmake clean; ".
		"gmake; sudo gmake install";
	}
	elsif (0) {
	    $command = "cd $devel/stuff; ".
		"sudo pkg_delete bash-4.2.20; sudo pkg_add bash-4.3.27.tbz";
	}
	elsif (0) {
	    $command = "cd /tmp; wget http://www.emulab.net/downloads/ops-monitoring.tar.gz && cd /usr/local && sudo tar xf /tmp/ops-monitoring.tar.gz; mysqladmin create monitoring; cd /usr/local/ops-monitoring/local/unit-tests && python ./local_table_reset.py; sudo /usr/testbed/sbin/protogeni/mondbd";
	}
	elsif (0) {
	    $command = "scp -p /usr/testbed/etc/openvpn-server.pem elabman\@control:openvpn; scp -p /usr/testbed/etc/openvpn-dh.pem elabman\@control:openvpn; scp -p /usr/testbed/etc/emulab.pem elabman\@control:openvpn; scp -p $devel/openvpn/openvpn.conf elabman\@control:openvpn";
	}
	elsif (0) {
	    $command = "cd /etc/openvpn; sudo ln -s /home/elabman/openvpn/openvpn.conf emulab.conf; sudo /etc/rc3.d/S16openvpn start";
	}
	elsif (0) {
	    $command = "sudo -u elabman /usr/testbed/sbin/wap ".
		"/usr/testbed/sbin/image_import -g -p emulab-ops ".
		"https://www.utahddc.geniracks.net/image_metadata.php\\\?uuid=783273c6-57bb-11e4-a443-000000000000";
	}
	elsif (0) {
	    $command = "sudo scp /usr/testbed/images/ndngec21v4.ndz ".
		"  ops:/proj/ch-geni-net/images/ndngec21v4.ndz";
	}
	elsif (0) {
	    $command = "sudo ssh vhost1.shared-nodes.emulab-ops ".
		"sysctl -w net.netfilter.nf_conntrack_generic_timeout=120 ".
		" net.netfilter.nf_conntrack_tcp_timeout_established=54000 ".
		" net.netfilter.nf_conntrack_max=131071";
	}
	elsif (0) {
	    $command =
		"$wap $sbin/emulabfeature create NewOsload 'NewOsload'; ".
		"$wap $sbin/emulabfeature enable NewOsload";
	}
	elsif (0) {
	    $command =
		"cd /users/elabman/$devobj/install; ".
		"  sudo perl emulab-install -b -i ops/shellinabox ops";
	}
	elsif (0) {
	    $command =
		"cd /users/elabman/$devobj/install; ".
		"  sudo perl emulab-install -b -i boss/shellinabox boss";
	}
	elsif (0) {
	    $command =
		"cd emulab-devel/obj/named; rm -f mail.access; gmake; ".
		"sudo gmake install-head; /usr/testbed/sbin/named_setup";
	}
	elsif (0) {
	    $command = "/usr/testbed/sbin/check-shared-bw -f";
	}
	elsif (0) {
	    $command = "sudo /usr/local/etc/rc.d/apache22 graceful";
	}
	elsif (0) {
	    $command =
		"cd emulab-devel/obj/db; ".
		"gmake; sudo gmake install; ".
		"sudo /usr/local/etc/rc.d/apache22 graceful";
	}
	elsif (0) {
	    $command = "cd emulab-devel/obj/protogeni/lib; ".
		"gmake; sudo gmake /usr/testbed/lib/GeniCMV2.pm; ".
		"cd ../../db; ".
		"gmake; sudo gmake /usr/testbed/lib/OSImage.pm ";
	}
	elsif (0) {
	    $command = "cd emulab-devel/obj/protogeni/lib; ".
		"gmake; sudo gmake install; ".
		"sudo /usr/local/etc/rc.d/apache22 graceful geni";
	}
	elsif (0) {
	    $command = "cd emulab-devel/obj/xmlrpc; ".
		"gmake; sudo gmake install";
	}
	elsif (0) {
	    $command = "/usr/testbed/sbin/addpubkey -f -u elabman ".
		"$devel/stuff/nasir-elabman.pub";
	}
	elsif (0) {
	    $command = "cd emulab-devel/obj/assign; gmake";
	}
	elsif (0) {
	    $command = "cd emulab-devel/obj/apache; ".
		"sudo gmake control-install; ".
		"sudo /usr/local/etc/rc.d/apache22 restart ";
	    $command = "ssh ops \"($command)\"";
	}
	elsif (0) {
	    $command =
	    "chmod 664 emulab-devel/defs-genirack; ".
	    "  echo 'BROWSER_CONSOLE_ENABLE=1' >> emulab-devel/defs-genirack; ".
	    "  sudo scp $devel/capture-nossl ".
	    "    vhost3.shared-nodes.emulab-ops:/usr/local/etc/emulab/capture";
	}
	elsif (0) {
	    $command = "sudo /usr/testbed/sbin/protogeni/getcacerts ";
	}
	elsif (0) {
	    $command = "/usr/testbed/sbin/wap ".
	      "/usr/testbed/sbin/grantimage -a -x ".
	      "   emulab-ops,UBUNTU14-OVS2.31; ".
	      "/usr/testbed/sbin/wap ".
	      "  /usr/testbed/sbin/runsonxen emulab-ops,UBUNTU14-OVS2.31; ".
	      "/usr/testbed/sbin/imagevalidate -u emulab-ops,UBUNTU14-OVS2.31;".
	      "cat $devel/stuff/fee.sql | mysql tbdb";
	}
	elsif (0) {
	    $command = "cat $devel/stuff/i.sql | mysql tbdb; ";
	}
	elsif (0) {
	    $command = "/usr/testbed/sbin/wap /usr/testbed/bin/editnodetype ".
		"$devel/stuff/ubuntu.sql";
	}	    
	elsif (0) {
	    $command = "/usr/testbed/sbin/wap /usr/testbed/sbin/setsitevar ".
		"protogeni/default_osname UBUNTU14-64-STD; ".
		"$wap /usr/testbed/bin/editnodetype $devel/stuff/defimage.xml";
	}	    
	elsif (0) {
	    $command = "$wap /usr/testbed/sbin/setsitevar ".
		"general/root_keypair 1";
	}	    
	elsif (0) {
		$command = "sudo /usr/testbed/sbin/getimages";
	}	    
	elsif (0) {
	    $command =
		"cat emulab-devel/emulab-devel/stuff/novz.sql | ".
		"   mysql tbdb";
	}
	elsif (0) {
	    $command = 
		"$wap $import -g -r emulab-ops,CENTOS72-64-STD ";
	}
	elsif (0) {
	    # APT, wisc, clemson, utahddc
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU14-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU18-64-STD; ".
		"$wap $import -g -r emulab-ops,CENTOS7-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSCN-P; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSCP-P; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSNM-P ";
	}
	elsif (0) {
	    # Just for the OneLab cluster.
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU18-64-ARM; ";
		"$wap $import -g -r emulab-ops,UBUNTU16-64-ARM; ";
		"$wap $import -g -r emulab-ops,UBUNTU14-64-ARM ";
	}
	elsif (1) {
	    # Just for the Utah Moonshot cluster.
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU18-64-X86; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-X86; ".
		"$wap $import -g -r emulab-ops,UBUNTU14-64-X86; ".
		"$wap $import -g -r emulab-ops,CENTOS7-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-X86-OSCN-P; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-X86-OSCP-P; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-X86-OSNM-P ";
	}
	elsif (0) {
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU16-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU14-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU12-64-STD; ".
		"$wap $import -g -r emulab-ops,CENTOS71-64-STD; ".
		"$wap $import -g -r emulab-ops,CENTOS72-64-STD; ".
		"$wap $import -g -r emulab-ops,CENTOS7-64-STD; ".
		"$wap $import -g -r emulab-ops,XEN46-64-STD; ".
		"$wap $import -g -r emulab-ops,XEN44-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSCN; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSCP; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-OSNM ";
	}
	elsif (0) {
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU14-10-64-OSCP; ".
		"$wap $import -g -r emulab-ops,UBUNTU14-10-64-OSCN; ".
		"$wap $import -g -r emulab-ops,UBUNTU14-10-64-OSNM; ".
		"$wap $import -g -r emulab-ops,UBUNTU14-10-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-04-64-OSCP; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-04-64-OSCN; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-04-64-OSNM; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-04-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-10-64-OSCN; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-10-64-OSCP; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-10-64-OSNM; ".
		"$wap $import -g -r emulab-ops,UBUNTU15-10-64-STD";
	}
	elsif (0) {
	    # APT, wisc, clemson, utahddc
	    $command = 
		"$wap $import -g -r emulab-ops,UBUNTU14-64-STD; ".
		"$wap $import -g -r emulab-ops,UBUNTU16-64-STD; ".
		"$wap $import -g -r emulab-ops,CENTOS7-64-STD ";
	}
	elsif (0) {
	    $command = 
		"$wap $import -g ".
		"      https://www.emulab.net/image_metadata.php\\\?uuid=2d6bccd7-3011-11e7-ac8f-90e2ba22fee4";
	}
	else {
	    $command = "sudo /usr/testbed/sbin/testbed-control shutdown; ".
		"sleep 5; sudo /usr/testbed/sbin/testbed-control boot";
	}
	#$command = "($command >& /tmp/function.log)";

	if (SSH(($dofuncops ? $rackops : $rack), $command)) {
	    print STDERR "Error running '$command' on $rack\n";
	    return 2;
	}
	if ($dofunc > 1) {
	    print "-> Booting the testbed ...\n";
	    if (SSH($rack,
		    "(sudo $TB/sbin/testbed-control boot >& boot.log)")) {
		print STDERR "** could not boot!\n";
		return 3;
		next;
	    }
	}
    };

    # List of racks that we can proceed with.
    my @doracks = @TODO;
    # Return codes for each rack. 
    my @results = ();
    if (ParRun({"maxwaittime" => 99999, "maxchildren" => ($nopar ? 1 : 8)},
	       \@results, $coderef, @doracks)) {
	fatal("ParRun failed!");
    }

    #
    # Check the exit codes. 
    #
    my $count = 0;
    foreach my $result (@results) {
	my ($rack) = $doracks[$count];

	if ($result) {
	    $result = $result >> 8;
	    if ($result == 1) {
		$SKIP{$rack} = "could not shutdown";
	    }
	    elsif ($result == 2) {
		$SKIP{$rack} = "could not run function";
	    }
	    elsif ($result == 3) {
		$SKIP{$rack} = "could not retstart";
	    }
	}
	$count++;
    }
    
    if (keys(%SKIP)) {
	print "The following racks failed!\n";
	foreach my $rack (keys(%SKIP)) {
	    my $reason = $SKIP{$rack};
	    print "$rack: $reason\n";
	}
    }
    exit(scalar(keys(%SKIP)));
}

#
# First do all of the rsyncs.
#
if ($rsync) {
    my $coderef = sub {
	my ($rack) = @_;

	print "rsyncing $rack ...\n";

	if (defined($rsyncdir)) {
	    $rsyncdir = "install/genirack"
		if ($rsyncdir eq "");
	    my $dir = dirname($rsyncdir);

	    if ($doctrl) {
		print "-> rsyncing $rsyncdir\n";
		system("rsync -a --timeout=60 --delete ".
		       "--exclude-from $TBSRC/.rsyncignore ".
		       "     $TBSRC/$rsyncdir ".
		       "  elabman\@${rack}:$dir");
		if ($?) {
		    print STDERR "** $rack: ".
			"error rsyncing emulab-devel/$rsyncdir\n";
		    return 1;
		}
	    }
	    else {
		print "-> rsyncing emulab-devel/$rsyncdir\n";
		system("rsync -a --timeout=60 --delete ".
		       "--exclude-from $TBSRC/.rsyncignore ".
		       "     $TBSRC/emulab-devel/$rsyncdir ".
		       "  elabman\@${rack}:emulab-devel/emulab-devel/$dir");
		if ($?) {
		    print STDERR "** $rack: ".
			"error rsyncing emulab-devel/$rsyncdir\n";
		    return 1;
		}
	    }
	    return 0;
	}
	if ($doscp) {
	    if (0) {
		$rack =~ s/^boss/ops/;
	    
		system("scp /share/freebsd/9.3/src.tar.gz ".
		       "    /share/freebsd/9.3/obj.tar.gz ".
		       "    /share/freebsd/9.3/kernel-9.3.xen ".
		       "    elabman\@${rack}:/share");
	    }
	    else {
		system("scp /usr/testbed/images/ndngec21v4.ndz ".
		       "    elabman\@${rack}:/usr/testbed/images");
	    }
	    if ($?) {
		print STDERR "** $rack: error doing scp\n";
		return 1;
	    }
	    return 0;
	}
	print "-> rsyncing emulab-devel\n";
	system("rsync -a --timeout=60 --delete ".
	       "--exclude-from $TBSRC/.rsyncignore ".
	       "     $TBSRC/emulab-devel ".
	       "     $TBSRC/reconfig.rack ".
	       "  elabman\@${rack}:emulab-devel");
	if ($?) {
	    print STDERR "** $rack: error rsyncing emulab-devel\n";
	    return 1;
	}
	print "-> rsyncing pubsub\n";
	system("rsync -a --timeout=60 --delete ".
	       "--exclude-from $TBSRC/.rsyncignore ".
	       "     $TBSRC/pubsub elabman\@${rack}:");
	if ($?) {
	    print STDERR "** $rack: error rsyncing pubsub\n";
	    return 1;
	}
	if (-e "$TBSRC/shellinabox") {
	    print "-> rsyncing shellinabox\n";
	    system("rsync -a --timeout=60 --delete ".
		   "--exclude-from $TBSRC/.rsyncignore ".
		   "     $TBSRC/shellinabox elabman\@${rack}:");
	    if ($?) {
		print STDERR "** $rack: error rsyncing shellinabox\n";
		return 1;
	    }
	}
	return 0;
    };

    # List of racks that we can proceed with.
    my @doracks = @TODO;
    # Return codes for each rack. 
    my @results = ();
    if (ParRun({"maxwaittime" => 99999, "maxchildren" => ($nopar ? 1 : 8)},
	       \@results, $coderef, @doracks)) {
	fatal("ParRun failed!");
    }

    #
    # Check the exit codes. 
    #
    my $count = 0;
    foreach my $result (@results) {
	my ($rack) = $doracks[$count];

	if ($result) {
	    $SKIP{$rack} = "could not rsync";
	}
	$count++;
    }
    
    if (keys(%SKIP)) {
	print "The following racks failed!\n";
	foreach my $rack (keys(%SKIP)) {
	    my $reason = $SKIP{$rack};
	    print "$rack: $reason\n";
	}
    }
}

if ($rebuild) {
    my $coderef = sub {
	my ($rack) = @_;

	print "rebuilding on $rack ...\n";
	print "-> $rack: Starting reconfig ...\n";
	if (SSH($rack,
		"(cd emulab-devel; ./reconfig.rack >& reconfig.log)")) {
	    print STDERR "** $rack: could not reconfig!\n";
	    return 1;
	}
	print "-> $rack: Starting clean ...\n";
	if (SSH($rack,
		"(cd emulab-devel/obj; sudo gmake clean >& clean.log)")) {
	    print STDERR "** $rack: could not clean!\n";
	    return 2;
	}
	print "-> $rack: Starting rebuild ...\n";
	if (SSH($rack,
		"(cd emulab-devel/obj; gmake >& rebuild.log)")) {
	    print STDERR "** $rack: could not rebuild!\n";
	    return 3;
	}
	print "-> $rack: Finished rebuild ...\n";
	return 0;
    };

    # List of racks that we can proceed with.
    my @doracks = ();
    foreach my $rack (@TODO) {
	if (exists($SKIP{$rack})) {
	    print "skipping rebuild on $rack\n";
	    next;
	}
	push(@doracks, $rack);
    }
    # Return codes for each rack. 
    my @results = ();
    if (ParRun({"maxwaittime" => 99999, "maxchildren" => ($nopar ? 1 : 8)},
	       \@results, $coderef, @doracks)) {
	fatal("ParRun failed!");
    }

    #
    # Check the exit codes. 
    #
    my $count = 0;
    foreach my $result (@results) {
	my ($rack) = $doracks[$count];

	if ($result) {
	    $result = $result >> 8;
	    if ($result == 1) {
		$SKIP{$rack} = "could not reconfig";
	    }
	    elsif ($result == 2) {
		$SKIP{$rack} = "could not clean";
	    }
	    elsif ($result == 3) {
		$SKIP{$rack} = "could not rebuild";
	    }
	}
	$count++;
    }
}

if ($install) {
    foreach my $rack (@TODO) {
	if (exists($SKIP{$rack})) {
	    print "skipping install on $rack\n";
	    next;
	}
	print "installing on $rack ...\n";

	if (defined($installdir)) {
	    if (SSH($rack, "cd emulab-devel/obj/$installdir; ".
		    "         sudo gmake install")) {
		print STDERR "** could not install on boss!\n";
		$SKIP{$rack} = "could not install on boss";
		next;
	    }
	}

	print "-> Shutting down testbed ...\n";
	if (SSH($rack,
	     "(sudo $TB/sbin/testbed-control shutdown >& /tmp/shutdown.log)")) {
	    print STDERR "** could not shutdown!\n";
	    $SKIP{$rack} = "could not shutdown";
	    next;
	}
	print "-> Starting install on boss ...\n";
	if (SSH($rack, "(cd emulab-devel/obj; ".
		"    sudo gmake update-testbed-nostop >& /tmp/install.log)")) {
	    print STDERR "** could not install on boss!\n";
	    $SKIP{$rack} = "could not install on boss";
	    next;
	}
	print "-> Starting install on ops ...\n";
	my $rackops = $rack;
	$rackops =~ s/^boss/ops/;
	
	if (SSH($rackops, "(cd emulab-devel/obj/clientside; ".
		"        sudo gmake control-install >>& /tmp/install.log)")) {
	    print STDERR "** could not install on ops!\n";
	    $SKIP{$rack} = "could not install ops";
	    next;
	}
	if ($dofunc) {
	    print "-> Running function ...\n";
 	    my $command = "/bin/ls /";
	    if (1) {
		$command = "cd emulab-devel/obj/; sudo gmake update-rcd";
	    }
	    if (defined($command) &&
		SSH($rack, "($command >& /tmp/function.log)")) {
		print STDERR "Error running '$command' on $rack\n";
		$SKIP{$rack} = "could not run function";
		next;
	    }
	}
	print "-> Booting the testbed ...\n";
	if (SSH($rack,
		"(sudo $TB/sbin/testbed-control boot >& /tmp/boot.log)")) {
	    print STDERR "** could not boot!\n";
	    $SKIP{$rack} = "could not boot";
	    next;
	}
	if (defined($options{"C"})) {
	    print "-> Gracefully restarting apache ...\n";
	    if (SSH($rack, "(sudo /usr/local/etc/rc.d/apache22 graceful)")) {
		print STDERR "** could not restart apache!\n";
		$SKIP{$rack} = "could not restart apache";
		next;
	    }
	}
    }
}

if (keys(%SKIP)) {
    print "The following racks failed!\n";
    foreach my $rack (keys(%SKIP)) {
	my $reason = $SKIP{$rack};
	print "$rack: $reason\n";
    }
}

sub SSH($$)
{
    my ($host, $cmd, $timeout) = @_;
    $timeout = 2500 if (!defined($timeout));
    
    my $childpid = fork();

    if ($childpid) {
	local $SIG{ALRM} = sub { kill("TERM", $childpid); };
	alarm $timeout;
	waitpid($childpid, 0);
	alarm 0;

	my $stat = $?;

	#
	# Any failure, revert to plain reboot below.
	#
	if ($?) {
	    return -1;
	}
	return 0;
    }
    else {
	exec("ssh elabman\@${host} '$cmd'");
	exit(1);
    }
}

sub TagSchema()
{
    my $tag  = POSIX::strftime("instageni-20%y%m%d", localtime(time()));
    print "Tagging with $tag\n";
    system("git tag -f -m 'Push to InstaGeni Racks' $tag");
    fatal("Could not tag repo!")
	if ($?);
    system("git push --tags");
    fatal("Could not push tag up!")
	if ($?);
    return 0;
}
