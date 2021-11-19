#!/usr/bin/perl -w
#
# Copyright (c) 2008-2011 University of Utah and the Flux Group.
# 
# {{{GENIPUBLIC-LICENSE
# 
# GENI Public License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
# 
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
# 
# }}}
#
use strict;
use English;
use Getopt::Std;
use IO::Socket::INET;

# un-taint path
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin:/usr/site/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

#
# Turn off line buffering on output
#
$| = 1;

# Protos
sub Reflector();

print STDERR "Emulab initialization continuing. ...\n";
system("date > /tmp/emulab_boot.log");

if (0) {
    Reflector();
    exit(0);
}

#
# All we have is our hostname and our slice name, so Emulab has to
# figure out from that, what to do. 
#
exit(0);

sub Reflector()
{
    my ($socket,$received_data);
    my ($peeraddress,$peerport);

    # we call IO::Socket::INET->new() to create the UDP Socket and bound
    # to specific port number mentioned in LocalPort and there is no need
    # to provide LocalAddr explicitly as in TCPServer.

    $socket = new IO::Socket::INET (LocalPort => '31576',
				    Proto => 'udp')
	or die "ERROR in Socket Creation : $!\n";

    while(1) {
	# read operation on the socket
	$socket->recv($recieved_data,1024);

	#get the peerhost and peerport at which the recent data received.
	$peer_address = $socket->peerhost();
	$peer_port = $socket->peerport();
	print "($peer_address , $peer_port) said : $recieved_data";

	#send the data to the client at which the read/write operations done
	#recently.
	$data = "data from server\n";
	$socket->send($data);
    }
    $socket->close();
}
