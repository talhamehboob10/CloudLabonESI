#!/usr/bin/perl
#
# Copyright (c) 2009 University of Utah and the Flux Group.
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
package Tools::Network;
use SemiModern::Perl;
use Net::Ping;
use Tools::TBSSH;
use Data::Dumper;
use Test::More;

=head1 NAME

Tools::Network

=over 4

=item C<ping($hostname)>

pings $hostname returning 0 or 1

=cut

our $OPS_PATH = "/usr/testbed/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/usr/X11R6/bin:";

sub ping {
  my ($host) = @_;
  #system("ping -c 2 $host");
  #my $rc = $?;
  #returns 0 on success
  #$rc;
  #Net::Ping returns 0 on success
  my $p = Net::Ping->new('tcp', 2);
  my $rc = $p->ping($host);
  !$rc;
}

=item C<node_reboot(@ARGS)>

node_reboot('pc137');
node_reboot('-f', 'pc137');
=cut
sub node_reboot {
  Tools::TBSSH::cmdoutput($TBConfig::OPS_SERVER, "'sh -c \"PATH=$OPS_PATH node_reboot @_\"'", "node_reboot @_ failed"); 
}

=item C<traceroute($src, $dest, ['hop1_host', 'hop2_host', ...])>

ssh to host $src and executes a traceroute to $dest ensuring it follows the path specified
returns 0 or 1
=cut
sub traceroute {
  my ($src,$dest,@path) = @_;
  Tools::TBSSH::cmdcheckoutput($src, "'sh -c \"PATH=/bin:/usr/sbin:/usr/sbin:/sbin traceroute $dest\"'", 
  sub {
    my ($sshoutput) = @_;
    my @lines = grep {!/^traceroute/} split(/\n/, $sshoutput) ;
    if ( (scalar @lines) != (scalar @path) ) {
      die sprintf("*** traceroute $src->$dest: expected %d hops but got %d.\n$sshoutput", (scalar @path), (scalar @lines));
    }
    for (0 .. ((scalar @lines)-1) ) {
      my $hop = $path[$_];
      my $line = $lines[$_];
      my ($host) = ($line =~ /^\s*\d+\s*(\S+)/);
      next if $host eq $hop;
      die sprintf("*** traceroute $src->$dest: expected %s for hop %d but got %s\n$sshoutput", $hop, $_+1, $host);
    }
    return 1;
  });
}

=item C<ping_from_to($from, $to)>

ssh to $from and ping $to
=cut
sub ping_from_to($$){
 my ($from, $to) = @_;
 Tools::TBSSH::cmdsuccess($from, "'sh -c \"PATH=/bin:/usr/sbin:/usr/sbin:/sbin ping -c 5 $to\"'", );
}

sub traceroute_ok {
  my ($src,$dest,@path) = @_;
  ok(traceroute(@_), "traceroute $src to $dest");
}

=item C<traceroute_ok($src, $dest, ['hop1_host', 'hop2_host', ...])>

calls traceroute and ok if successfull

=back

=cut

1;
