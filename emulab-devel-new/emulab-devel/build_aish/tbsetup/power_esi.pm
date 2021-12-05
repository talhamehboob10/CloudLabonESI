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

   my $self = shift;
   my $action = shift;
   my $outlets = shift; 
   my $devicename = $self->{DEVICENAME};
   my $client = REST::Client->new();
   my $url = "https://mockesi.herokuapp.com/status/$devicename/?format=json";
   $client->GET($url);
   my $response = decode_json($client->responseContent());
   print "\nDevice Name : $devicename\n";
   my $message = $response->{'message'};
   print "Status : $message\n";
}

sub power {

   my $self = shift;
   my $action = shift;
   my $outlets = shift;
  
   my $devicename = $self->{DEVICENAME};
   my $powerCommand = "powerOn";
   if ($action eq 'off') {
   	$powerCommand = "powerOff";
   }
   
   my $url = "https://mockesi.herokuapp.com/$powerCommand/$devicename/?format=json";
    my $client = REST::Client->new();
   $client->GET($url);
   my $response = decode_json($client->responseContent());
   my $message = $response->{'message'};
   print "Updating...";
   print "Updated Status : $message\n";
   
  
}
