#!/usr/bin/perl -w

package power_esi;

print "Hello World\n";

use REST::Client;

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
   print $client->responseContent();
  
}

sub power {

  print "in power"

}
