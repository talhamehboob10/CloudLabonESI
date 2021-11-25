#!/bin/perl
#
# Copyright (c) 2007 University of Utah and the Flux Group.
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

use Socket;

# node_mapping is the reverse mapping of the one in init-elabnodes.
# The keys are the PlanetLab node names. The values are the Emulab node names.
my %node_mapping = ();

my $eprefix = "elab-";
my $pprefix = "planet-";

$pid = $ARGV[0];
$eid = $ARGV[1];

@nodelist = split('\s+', `cat /proj/$pid/exp/$eid/tmp/node_list`);
chomp(@nodelist);

foreach my $mapping (@nodelist) {
    if ($mapping =~ /^(${pprefix}[\d]+)=([\w]*)$/) {
	# vnode is the virtual node name in emulab.
	my $vnode = $1;
	# pnode is the planetlab node name.
	my $pnode = $2.".emulab.net";
	$vnode =~ s/${pprefix}/${eprefix}/;
	$pnode = gethostbyname($pnode);
	$pnode = inet_ntoa($pnode);
	$node_mapping{$pnode} = $vnode
    }
}

$command = "./query_iplane_client iplane.cs.washington.edu 1 iplane_pairwise.rb \""
           .join(" ", keys(%node_mapping))."\"";

print $command."\n";

@replylist = `$command`;

print "$pid $eid\n";

foreach my $reply (@replylist) {
    if ($reply =~ /\s*source=([0-9.]*)\s*dest=([0-9.]*)\s*latency=([0-9.]*)\s*/) {
	my $source = $1;
	my $dest = $2;
	my $latency = $3;
	print $node_mapping{$source}." ".$node_mapping{$dest}." "."10000"." ".($latency/2)." 0.0\n";
	print $node_mapping{$dest}." ".$node_mapping{$source}." "."10000"." ".($latency/2)." 0.0\n";
    }
}
