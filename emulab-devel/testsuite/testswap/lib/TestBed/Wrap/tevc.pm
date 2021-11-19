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
package TestBed::Wrap::tevc;
use SemiModern::Perl;
use TBConfig;
use Data::Dumper;
use Tools;
use Tools::TBSSH;

=pod

tevc -e proj/expt time objname event [args ...]

where the time parameter is one of:

* now
* +seconds (floating point or integer)
* [[[[yy]mm]dd]HH]MMss 

For example, you could issue this sequence of events.

tevc -e testbed/myexp now cbr0 set interval_=0.2
tevc -e testbed/myexp +10 cbr0 start
tevc -e testbed/myexp +15 link0 down
tevc -e testbed/myexp +17 link0 up
tevc -e testbed/myexp +20 cbr0 stop
=cut

=head1 NAME

TestBed::Wrap::tevc

=over 4

=item C<tevc($pid, $eid, @args)>

executes tevc on $pid and $eid with $arg string such as "now link1 down"
by sshing to ops

=item C<tevc_at_host($pid, $eid, $host, @args)>

executes tevc on $pid and $eid with $arg string such as "now link1 down"
by sshing to $host

=back

=cut

sub tevc { tevc_at_host(shift, $TBConfig::OPS_SERVER, @_); }

sub tevc_at_host {
  my ($e, $host, @args) = @_;
  my ($pid, $eid) = ($e->pid, $e->eid);
  my $cmd = 'PATH=/usr/testbed/bin:$PATH tevc ' . "-e $pid/$eid " . join(" ", @args);
  Tools::TBSSH::cmdsuccess($host, $cmd);
}

1;
