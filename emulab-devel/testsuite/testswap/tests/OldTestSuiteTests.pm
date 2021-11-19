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
use SemiModern::Perl;
use TestBed::TestSuite;
use Test::More;
use Data::Dumper;
use OldTestSuite;

our @requires_db      = qw( db1 );
our @too_big          = qw( spinglass );
our @should_pass      = qw( fixed basic cbr complete5 delaylan1 delaylink multilink ixp lan1 nodes singlenode trafgen simplelink simplex setip red ping vtypes mininodes sharkshelf basicrsrv minisetip buddycache trivial minimultilink );
our @should_fail      = qw( negprerun toomanylinks toofast dnardshelf );
our @broken           = qw( spinglass2 minitbcmd tbcmd wideareatypes wideareamapped );

=pod
vtypes (may want to parameterize the vtypes)
fixed (you will have to change the ns file depending on which nodes are available)
=cut

#for (@should_fail) {
#for (@broken) {
for (@should_pass) {
  my $eid = $_;
  my $ns = $OldTestSuite::tests->{$_}->{'nsfile'};
  rege(e($_), $ns, sub { ok(shift->ping_test, $eid); }, 1, $_)
}

1;
