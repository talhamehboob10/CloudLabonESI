#!/usr/bin/perl -w
print "Hello World\n";

use REST::Client;

my $client = REST::Client->new();
$client->GET('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock');
print $client->responseContent();
