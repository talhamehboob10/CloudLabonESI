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
package TestBed::Wrap::loghole;
use SemiModern::Perl;
use TBConfig;
use Data::Dumper;
use Tools;
use Tools::TBSSH;

=pod

loghole -e proj/expt [args ...]
=cut

=head1 NAME

TestBed::Wrap::loghole

=over 4

=item C<loghole($pid, $eid, $arg)>

executes loghole on $pid and $eid with $arg string such as "now link1 down"
by sshing to ops

=back

=cut

sub loghole {
  my ($e, @args) = @_;
  my ($pid, $eid) = ($e->pid, $e->eid);
  my $cmd = 'PATH=/usr/testbed/bin:$PATH loghole ' . "-e $pid/$eid " . join(" ", @args);
  #say $cmd;
  Tools::TBSSH::cmdsuccess($TBConfig::OPS_SERVER, $cmd);
}

1;
