#!/usr/bin/perl -w
#
# Copyright (c) 2005-2017 University of Utah and the Flux Group.
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
use Getopt::Std;
use English;

my $datafile = "fw-rules";

my $optlist = "eMIf:t:";
my $domysql = 0;
my $doiptables = 1;
my $expand = 0;
my $qualifiers = 0;
my $type = "iptables-vlan";
my @lines;

sub usage()
{
    print "Usage: genconfig-iptables [-MI] config ...\n".
	"  -e      expand EMULAB_ variables\n".
	"  -f file specify the input rules file\n".
	"  -q      include qualifiers\n".
	"  -M      generate mysql commands\n".
	"  -I      generate iptables commands\n".
	"  -t type defaults to iptables-vlan\n".
	"\n".
	" Valid configs are: open, closed, basic, elabinelab\n".
	" Valid types are: iptables-vlan, iptables-dom0\n";
    exit(1);
}

my %fwvars;

sub getfwvars()
{
    # XXX for Utah Emulab as of 02/17
    $fwvars{EMULAB_GWIP} = "155.98.36.1";
    $fwvars{EMULAB_GWMAC} = "c0:ea:e4:b1:b4:04";
    $fwvars{EMULAB_VGWIP} = "172.16.0.1";
    # XXX assume vnode GW MAC same as GW MAC
    $fwvars{EMULAB_NS} = "155.98.32.70";
    $fwvars{EMULAB_CNET} = "155.98.36.0/22";
    $fwvars{EMULAB_VCNET} = "172.16.0.0/12";
    $fwvars{EMULAB_VCNET_BOSS} = "172.17.254.254";
    $fwvars{EMULAB_VCNET_OPS} = "172.17.253.254";
    $fwvars{EMULAB_VCBOSS} = "172.17.254.254";
    $fwvars{EMULAB_VCOPS} = "172.17.253.254";
    $fwvars{EMULAB_FSIPS} = "155.98.33.74,172.17.253.254";
    $fwvars{EMULAB_BOSSES} = "boss,subboss,subboss2,subboss3";
    $fwvars{EMULAB_SERVERS} = "boss,subboss,subboss2,subboss3,ops";
    $fwvars{EMULAB_MCADDR} = "234.0.0.0/8,239.0.0.0/8";
    $fwvars{EMULAB_MCPORT} = "21700-21799";
}

sub expandfwvars($)
{
    my ($rule) = @_;

    getfwvars() if (!%fwvars);

    if ($rule =~ /EMULAB_\w+/) {
	foreach my $key (keys %fwvars) {
	    $rule =~ s/$key/$fwvars{$key}/g
		if (defined($fwvars{$key}));
	}
	if ($rule =~ /EMULAB_\w+/) {
	    warn("*** WARNING: Unexpanded firewall variable in: \n".
		 "    $rule\n");
	}
    }
    return $rule;
}

sub doconfig($$)
{
    my ($config,$type) = @_;
    my $ruleno = 1;
    my ($style, $enabled);

    if ($doiptables) {
	print "# $config\n";
	print "iptables -F\n";
	print "iptables -X\n";
    }
    if ($domysql) {
	$style = lc($config);
	# XXX
	$style = "emulab" if ($style eq "elabinelab");
	$enabled = 1;

	print "DELETE FROM `default_firewall_rules` WHERE ".
	    "type='$type' AND style='$style';\n";
    }

    foreach my $line (@lines) {
	next if ($line !~ /#.*$config/);
	next if ($line =~ /^#/);
	if ($line =~ /#\s*(\d+):.*/) {
	    $ruleno = $1;
	} else {
	    $ruleno++;
	}
	my $qual;
	if ($line =~ /#.*\+(\w+)/) {
	    $qual = $1;
	}

	($rule = $line) =~ s/\s*#.*//;
	chomp($rule);
	$rule = expandfwvars($rule) if ($expand);
	if ($doiptables) {
	    print "$rule # config=$config";
	    print ", $qual only)"
		if ($qualifiers && $qual);
	    print "\n";
	}
	if ($domysql) {
	    if ($qualifiers) {
		print "INSERT INTO `default_firewall_rules` VALUES (".
		    "'$type','$style',$enabled,$qual,$ruleno,'$rule');\n";
	    } else {
		print "INSERT INTO `default_firewall_rules` VALUES (".
		    "'$type','$style',$enabled,$ruleno,'$rule');\n";
	    }
	}
    }
}

%options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (defined($options{"M"})) {
    $domysql = 1;
    $doiptables = 0;
}
if (defined($options{"I"})) {
    $doiptables = 1;
    $domysql = 0;
}
if (defined($options{"e"})) {
    $expand = 1;
}
if (defined($options{"f"})) {
    $datafile = $options{"f"};
}
if (defined($options{"t"})) {
    $type = $options{"t"};
}
if (defined($options{"q"})) {
    $qualifiers = 1;
}

if (@ARGV == 0) {
    usage();
}
@lines = `cat $datafile`;
foreach my $config (@ARGV) {
    $config = uc($config);
    doconfig($config,$type);
}
exit(0);
