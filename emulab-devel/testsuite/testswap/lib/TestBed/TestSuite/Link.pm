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
package TestBed::TestSuite::Link;
use SemiModern::Perl;
use Moose;
#use TestBed::XMLRPC::Client::Link;
use Tools::Network;
use Tools::TBSSH;
use Data::Dumper;
use TestBed::Wrap::tevc;

has 'name' => ( isa => 'Str', is => 'rw');
has 'experiment' => ( isa => 'TestBed::TestSuite::Experiment', is => 'rw');

=head1 NAME
TestBed::TestSuite::Link

=over 4

=item C<< $l->up >>

uses tevc to bring up a link
=cut
sub up { shift->tevc("up"); }

=item C<< $l->down >>

uses tevc to bring down a link
=cut
sub down { shift->tevc("down"); }

=item C<< $l->tevc($cmd) >>

uses tevc to control link
=cut
sub tevc {
  my ($self, $cmd) = @_;
  my $name = $self->name;
  TestBed::Wrap::tevc::tevc($self->experiment, "now $name $cmd");
}

=back 

=cut

1;
