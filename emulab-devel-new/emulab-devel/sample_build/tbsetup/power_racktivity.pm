#!/usr/bin/perl -w

#
# EMULAB-COPYRIGHT
# Copyright (c) 2000-2003, 2006-2007 University of Utah and the Flux Group.
# All rights reserved.
#

#
# module for controlling Ractivity IPMI cards
# needs a working "/usr/local/bin/snmpset" binary installed
#
# supports new(ip), power(on|off|cyc[le]), status
#

package power_racktivity;

$| = 1; # Turn off line buffering on output

use strict;
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin'; # Required when using system() or backticks `` in combination with the perl -T taint checks

sub new($$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $devicename = shift;
    my $debug = shift;

    if (!defined($debug)) {
        $debug = 0;
    }

    if ($debug) {
        print "power_racktivity module initializing... debug level $debug\n";
    }

    my $self = {};

    $self->{DEBUG} = $debug;

    $self->{DEVICENAME} = $devicename;
    $self->{VAL_ON}  = 1;
    $self->{VAL_OFF} = 0;
    $self->{SNMP_VER} = "2c";
    $self->{SNMP_MIB} = "RACKTIVITY";
    $self->{SNMP_OID} = "enterprises.racktivity.port.portTable.portEntry.state";
    $self->{SNMP_COMMUNITY_READ}  = "public";
    $self->{SNMP_COMMUNITY_WRITE} = "private";

    bless($self,$class);
    return $self;
}

sub power {
    my $self = shift;
    my $op = shift;
    my @ports = @_;

    my $errors = 0;
    my ($retval, $output);

    my $op_val;

    if    ($op eq "on")  { $op_val = $self->{VAL_ON};  }
    elsif ($op eq "off") { $op_val = $self->{VAL_OFF}; }
    elsif ($op =~ /cyc/) { $op_val = "cycle"; }
    else { die "unsupported op: $op"; }


    foreach my $port (@ports)
    {
	if ( $port < 0 || $port > 7 )
	{
		die "Port number out of range: 0 <= port <= 7";
	}

	my $oid = sprintf("%s.%s", $self->{SNMP_OID}, $port);

	my $ret = -1;

	if ( $op_val eq "cycle" )
	{
		$op_val = $self->{VAL_OFF};
		$ret = $self->_execsnmpset($oid,$op_val);
		if ( $ret != $op_val )
		{
			$errors++;
			print STDERR $self->{DEVICENAME}, ": could not control power status of device on port $port\n";
		}
		sleep 5;
		$op_val = $self->{VAL_ON};
		$ret = $self->_execsnmpset($oid,$self->{VAL_ON});
		if ( $ret != $op_val )
		{
			$errors++;
			print STDERR $self->{DEVICENAME}, ": could not control power status of device on port $port\n";
		}
	}

	$ret = $self->_execsnmpset($oid,$op_val);
	if ( $ret != $op_val )
	{
		$errors++;
		print STDERR $self->{DEVICENAME}, ": could not control power status of device on port $port\n";
	}
    }

    return $errors;
}

sub status {
    my $self = shift;
    my $statusp = shift; # pointer to an associative (hashed) array (i.o.w. passed by reference)
    my %status;          # local associative array which we'll pass back through $statusp

    my $errors = 0;
    my ($retval, $output);


}

sub _execsnmpset { 
    my ($self,$oid,$value) = @_;

    my $snmpcmd = sprintf("snmpset -Oe -v %s -m %s -c %s %s %s i %i",
    			$self->{SNMP_VER},
 			$self->{SNMP_MIB},
			$self->{SNMP_COMMUNITY_WRITE},
			$self->{DEVICENAME},
			$oid, $value );


    open('SNMPCMD',"$snmpcmd |") or die "Cannot start $snmpcmd for read: $!";

    my $response = -255; 

    while(<SNMPCMD>)
    {
	chomp;
	my ($field,$value) = split(/ = /);
	print "field: $field \n" if ($self->{DEBUG});
	print "value: $value \n" if ($self->{DEBUG});
	
	if ( $field =~ /$oid/ )
	{
		print "found $oid in response\n" if ($self->{DEBUG});
		$response = $value ;
	}
    }

    return ($response);
}

sub _execsnmpget { 
    my ($self,$oid) = @_;

    my $snmpcmd = sprintf("snmpget -Oe -v %s -m %s -c %s %s %s",
    			$self->{SNMP_VER},
 			$self->{SNMP_MIB},
			$self->{SNMP_COMMUNITY_READ},
			$self->{DEVICENAME},
			$oid );


    open('SNMPCMD',"$snmpcmd |") or die "Cannot start $snmpcmd for read: $!";

    my $response = -255; 

    while(<SNMPCMD>)
    {
	chomp;
	my ($field,$value) = split(/ = /);
	print "field: $field \n" if ($self->{DEBUG});
	print "value: $value \n" if ($self->{DEBUG});

	if ( $field eq $oid.".0" )
	{
		print "found $oid in response\n" if ($self->{DEBUG});
		$response = $value ;
	}
    }

    return ($response);
}

# End with true
1;
