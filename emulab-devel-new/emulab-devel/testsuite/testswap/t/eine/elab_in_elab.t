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
use TBConfig;
use TestBed::TestSuite;
use TestBed::TestSuite::Experiment;
use Test::More tests => 2;
use Data::Dumper;

my $ns = <<'NSEND';
source tb_compat.tcl
set ns [new Simulator]

tb-elab-in-elab 1
tb-elabinelab-singlenet

namespace eval TBCOMPAT {
    set elabinelab_maxpcs 3
    set elabinelab_hardware("boss") pc3000
    set elabinelab_hardware("ops") pc3000
    set elabinelab_nodeos("boss") FBSD62-STD
    set elabinelab_nodeos("ops") FBSD62-STD
}

$ns run 
NSEND

my $eid='eine';
my $e = e($eid);

#ok($e->startrun($ns, \&run_inside_exper), 'e-in-e started');

sub run_inside_exper {
  my $boss_name = $e->node('myboss.eine.tbres.emulab.net')->name;
  my $boss_url = "https://$boss_name:3069/usr/testbed";
  say $boss_url;
  my $cmd = "./tbts -d -x '$boss_url' t/xmlrpc/experiment.t";
  say $cmd;
  ok(!system($cmd), 'eine single node experiment');
}
run_inside_exper;
