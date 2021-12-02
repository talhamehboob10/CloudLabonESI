#!/usr/bin/perl -w

package power_esi;

print "Hello World\n";

use strict;
use warnings;
use REST::Client;
use JSON::XS;
use Try::Tiny;
use Data::Dumper::Concise;


sub new {

  my $class = shift;
  my $devicetype = shift;
  my $devicename = shift;
  my $debug = shift;
  
  $debug = 1;
  
  if (!defined($debug)) {
    $debug = 0;
  }
  
  if ($debug) {
    print "power_ipmi module initializing... debug level $debug\n";
  }
  
  my $self = {};
  
  $self->{DEBUG} = $debug;
  $self->{DEVICETYPE} = $devicetype;
  $self->{DEVICENAME} = $devicename;
  
  bless($self,$class);
  return $self;
}

sub status {

   my $client = REST::Client->new();
   $client->GET('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock');
   my @response = @{JSON::XS::decode_json($client->responseContent())};
   my $array_size = scalar @response;
   print "SIZE:$array_size\n";
   my $hashStatus = {};
   my $hashName = {};
   for( $a = 0; $a < $array_size; $a = $a + 1 ) {
        my $nodeId = $response[$a]->{'nodeID'};
	my $name = $response[$a]->{'nodeName'};
	my $status = $response[$a]->{'nodeStatus'};
	$hashName->{$nodeId} = $name;
	if ($status) {
		$hashStatus->{$nodeId} = 'on'; 
	} else {
		$hashStatus->{$nodeId} = 'off';
	}

	#print "$hashStatus->{$nodeId}\n";
   }	
}

sub power {

   my $self = shift;
   my $action = shift;
   my $outlets = shift;
   
   print "In power\n got action:$action\n";

   my $client = REST::Client->new();
   $client->GET('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock');
   my @response = @{JSON::XS::decode_json($client->responseContent())};
   
   my $array_size = scalar @response;
   
   my $hashStatus = {};
   my $hashName = {};
   
   for( $a = 0; $a < $array_size; $a = $a + 1 ) {
        my $nodeId = $response[$a]->{'nodeID'};
	my $name = $response[$a]->{'nodeName'};
	my $status = $response[$a]->{'nodeStatus'};
	$hashName->{$nodeId} = $name;
	if ($status) {
		$hashStatus->{$nodeId} = 'on'; 
	} else {
		$hashStatus->{$nodeId} = 'off';
	}
   }
   
   my $devicename = $self->{DEVICENAME};
   my $device_status = $hashName->{$devicename};
   
   if ($device_status eq 'on') {
   	if ($action eq 'on'){
	    print "\n Node already powered on! \n";
	} else {
	    print "\n Powering off node \n";
	}
   } else {
   	if ($action eq 'on'){
	    print "\n Powering on node! \n";
	} else {
	    print "\n Already powered off node \n";
	} 
   }
   
   # TODO: call API to perform POST to change status of node
}
