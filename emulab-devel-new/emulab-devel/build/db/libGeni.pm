#!/usr/bin/perl -wT
#
# Copyright (c) 2009-2016 University of Utah and the Flux Group.
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
# Merge internet nodes and links to them. 
#
package libGeni;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw();

# Configure variables
my $TB		= "/users/mshobana/emulab-devel/build";
my $BOSSNODE    = "boss.cloudlab.umass.edu";
my $TBDOCBASE   = "http://www.cloudlab.umass.edu";
#my $TBDOCBASE   = "http://www.emulab.net";
my $ELVIN_COMPAT= 0;
my $ASSIGN	= "$TB/libexec/assign";

use libdb;
use libtestbed;
use emutil;
use NodeType;
use Interface;
use Experiment;
use Lan;
use GeniEmulabUtil;
use GeniResource;
use GeniResponse;
use GeniAuthority;
use GeniXML;
use English;
use Socket;
use XML::Simple;
use XML::LibXML;
use XML::SemanticDiff;
use Data::Dumper;
use File::Temp;
use IO::File;
use POSIX qw(strftime);

sub Register($$)
{
    my ($experiment, $user) = @_;

    return GeniEmulabUtil::RegisterExperiment($experiment, $user);
}

sub UnRegister($)
{
    my ($experiment) = @_;

    return GeniEmulabUtil::UnRegisterExperiment($experiment);
}

sub RenewSlivers($;$)
{
    my ($experiment, $force) = @_;

    return GeniResource::RenewExperimentResources($experiment, $force);
}

#
# Map rspec to resources using assign. 
#
sub MapResources($$$$$)
{
    my ($experiment, $user, $topo, $rspecref, $verbose) = @_;
    my %cmurn2res   = ();
    my %cmurn2nodes = ();
    my %cmurn2links = ();
    my %cmurn2frags = ();
    my %vname2res   = ();
    my %vname2doc   = ();
	
    Register($experiment, $user) == 0
	or return -1;

    #
    # Build up rspec fragments from the "intermediate" representation
    # that libvtop passed in. Ick.
    #
    foreach my $ref (@{ $topo->{'node'} }) {
	# Skip non geni nodes; handled in libvtop
	next
	    if (! (exists($ref->{'isgeninode'}) && $ref->{'isgeninode'}));
	
	my $resource;
	my $node_urn    = $ref->{'request_urn'};
	my $manager_urn = $ref->{'manager_urn'};
	my $virtual_id  = $ref->{'virtual_id'};
	my (undef,undef,$node_id) = GeniHRN::Parse($node_urn);
	
	#
	# Get the resource object.
	#
	if (!exists($cmurn2res{$manager_urn})) {
	    $resource = GeniResource->Lookup($experiment->idx(), $manager_urn);
	    if (!defined($resource)) {
		$resource = GeniResource->Create($experiment, $manager_urn);
		if (!defined($resource)) {
		    print STDERR
			"Could not create GeniResource for $manager_urn\n";
		    return -1;
		}
	    }
	    $cmurn2res{$manager_urn} = $resource;
	}
	$resource = $cmurn2res{$manager_urn};
	$vname2res{$virtual_id} = $resource;

	#
	# The point of this is to split the rspec apart, since at present
	# assign cannot handle multiple advertisements, and it will not work
	# to pass in an rspec that references CMs other then the one
	# advertisement being passed in.
	#
	my $fragment;
	if (!exists($cmurn2frags{$manager_urn})) {
	    $fragment = CreateNewRspec("request");
	    return -1
		if (!defined($fragment));

	    $cmurn2frags{$manager_urn} = $fragment;
	}
	$fragment = $cmurn2frags{$manager_urn};

	my $rspecdoc = AddNodeToRspec($fragment, $ref);
	return -1
	    if (!defined($rspecdoc));
	$vname2doc{$virtual_id} = $rspecdoc;
    }

    #
    # As above, need to split the interfaces into the correct fragments.
    #
    if (exists($topo->{'link'})) {
	foreach my $ref (@{ $topo->{'link'} }) {
	    my $linkname   = $ref->{'virtual_id'};

	    # Skip tunnels until rspec stitching in place.
	    next
		if (exists($ref->{'link_type'}) &&
		    $ref->{'link_type'} eq "tunnel");

	    my $ifaceref0 = $ref->{'interface_ref'}->[0];
	    my $ifaceref1 = $ref->{'interface_ref'}->[1];
	    # Do not want to add this twice.
	    my $virtid0   = $ifaceref0->{'virtual_node_id'};
	    my $resource0 = $vname2res{$virtid0};
	    my $fragment0 = $cmurn2frags{$resource0->manager_urn()};

	    my $rspecdoc = AddLinkToRspec($fragment0, $ref);
	    return -1
		if (!defined($rspecdoc));
	    # Only one of these in the array, for building combined rspec.
	    $vname2doc{$linkname} = $rspecdoc;
	    
	    my $virtid1   = $ifaceref1->{'virtual_node_id'};
	    my $resource1 = $vname2res{$virtid1};
	    my $fragment1 = $cmurn2frags{$resource1->manager_urn()};
	    if ($resource0->manager_urn() ne $resource1->manager_urn()) {
		$rspecdoc = AddLinkToRspec($fragment1, $ref);
		return -1
		    if (!defined($rspecdoc));
	    }
	}
    }
    if ($verbose) {
	print STDERR "Rspec Fragments:\n";

	foreach my $fragment (values(%cmurn2frags)) {
	    my $rspecstr = GeniXML::Serialize($fragment, 1);
	    print STDERR "$rspecstr\n";
	}
    }
    
    #
    # Discover resources in parallel and run assign, writing the solution
    # to a file.
    #
    my $coderef   = sub {
	my ($resource, $fragment, $tmp) = @{ $_[0] };
	my $advertisement;

	print STDERR "Asking for resource list from $resource\n";
	if ($resource->Discover($user, \$advertisement)) {
		print STDERR "Could not get resource list for $resource\n";
		return -1;
	}
	#
	# Is the advertisement from a non-conforming manager, such as the SFA?
	# If so, must convert it to something assign can grok.
	#
	if ($resource->IsSFA()) {
	    $advertisement = ConvertSFAtoPG($advertisement, "ad",
					    $resource->manager_urn());
	    return -1
		if (!defined($advertisement));
	    $advertisement = GeniXML::Serialize($advertisement, 1);
	}
	
	my $soln = $tmp . ".soln";
	my $log  = $tmp . ".log";
	my $ptop = $tmp . ".ptop";
	my $vtop = $tmp . ".vtop";

	my $reqstring = GeniXML::Serialize($fragment);
	my $vtopfh = new IO::File "> $vtop";
	my $ptopfh = new IO::File "> $ptop";
	if (! (defined($vtopfh) && defined($ptopfh))) {
	    print STDERR "Could not create temporary files for ptop/vtop\n";
	    return -1;
	}
	print $vtopfh $reqstring;
	print $ptopfh $advertisement;
	$vtopfh->close();
	$ptopfh->close();

	my $cmd = "nice $ASSIGN -uod -c .75 ".
	    "-f rspec/rspec -W $soln $ptop $vtop > $log 2>&1";
	if ($verbose) {
	    print STDERR "$cmd\n";
	}
	system($cmd);
	
	if ($?) {
	    print STDERR "Could not map to physical resources on $resource\n";
	    my $logstuff = `cat $log`;
	    print STDERR "\n" . $logstuff . "\n";
	    my $string = GeniXML::Serialize($fragment, 1);
	    print STDERR "$string\n";
	    return -1;
	}
	return 0;
    };

    #
    # Figure out which resources still need to be mapped. 
    #
    my @todo     = ();
    my @results = ();

    foreach my $manager_urn (keys(%cmurn2res)) {
	my $resource = $cmurn2res{$manager_urn};
	my $fragment = $cmurn2frags{$manager_urn};

	#
	# We got the ticket on a previous loop.
	#
	if ($resource->HaveTicket()) {
	    print STDERR "Already have a ticket for $resource; skipping ...\n";
	    next;
	}
	my $tmp  = File::Temp::mktemp("XXXXX");
	push(@todo, [$resource, $fragment, $tmp]);
    }

    print STDERR "Mapping resources in parallel ...\n";
    if (ParRun({'maxwaittime' => 600, 'maxchildren' => 4},
	       \@results, $coderef, @todo)) {
	print STDERR "*** MapResources: Internal error mapping resources\n";
	return -1;
    }
    
    #
    # Check the exit codes. 
    #
    my $errors   = 0;
    my $count    = 0;
    foreach my $result (@results) {
	my ($resource, $fragment, $tmp) = @{ $todo[$count] };

	#
	# ParRun does a fork; so need to refresh the resource object
	# to sync it to the DB.
	#
	if ($resource->Refresh()) {
	    print STDERR "*** MapResources: Error synchronizing $resource\n";
	    $errors++;
	}
	elsif ($result != 0) {
	    print STDERR "*** Error mapping resources for $resource\n";
	    $errors++;
	}
	$count++;
    }
    return -1
	if ($errors);
    
    #
    # Since everything mapped, read the solutions and write back to the rspec
    #
    foreach my $ref (@todo) {
	my ($resource, $fragment, $tmp) = @{ $ref };
	my $soln = $tmp . ".soln";
	
	my $solution =
	    eval { XMLin($soln, KeyAttr => [],
			 ForceArray => ["node", "link", "interface",
					"interface_ref", "linkendpoints",
					"component_manager"]) };
	if ($@) {
	    print STDERR "XMLin error reading $soln: $@\n";
	    return -1;
	}
	if ($verbose) {
	    print STDERR "Solution for $resource\n";
	    print STDERR Dumper($solution);
	}

	foreach my $ref (@{ $solution->{'node'} }) {
	    my $virtual_id = $ref->{'virtual_id'};
	    my $node_urn   = $ref->{'component_uuid'};
	    my $cm_urn     = $ref->{'component_manager_uuid'};
	    my $rspecdoc   = $vname2doc{$virtual_id};

	    #
	    # This writes the solution back into the fragment.
	    #
	    $rspecdoc->setAttribute("component_uuid", $node_urn);
	    $rspecdoc->setAttribute("component_urn", $node_urn);
	    $rspecdoc->setAttribute("component_manager_uuid", $cm_urn);
	    $rspecdoc->setAttribute("component_manager_urn", $cm_urn);

	    if (exists($ref->{'interface'})) {
		my $interfaces = $ref->{'interface'};

		foreach my $ifaceref (@{ $interfaces }) {
		    my $virtid = $ifaceref->{'virtual_id'};
		    my $compid = $ifaceref->{'component_id'};

		    # Not supposed to happen, but does cause of issues
		    # with tunnels and rspec stitching. 
		    next
			if (!defined($compid));

		    foreach my $linkref (GeniXML::FindNodes("n:interface",
						$rspecdoc)->get_nodelist()) {
			my $ovirtid = GeniXML::GetText("virtual_id", $linkref);
			if ($ovirtid eq $virtid) {
			    $linkref->setAttribute("component_id", $compid);
			    last;
			}
		    }
		}
	    }
	}
    }
    #
    # One last chore; we had to skip tunnels above since assign does
    # not know how to deal with them.
    #
    if (exists($topo->{'link'})) {
	foreach my $ref (@{ $topo->{'link'} }) {
	    my $linkname   = $ref->{'virtual_id'};

	    # Skip non-tunnels.
	    next
		if (! (exists($ref->{'link_type'}) &&
		       $ref->{'link_type'} eq "tunnel"));

	    my $ifaceref0 = $ref->{'interface_ref'}->[0];
	    my $ifaceref1 = $ref->{'interface_ref'}->[1];
	    # Do not want to add this twice.
	    my $virtid0   = $ifaceref0->{'virtual_node_id'};
	    my $resource0 = $vname2res{$virtid0};
	    my $fragment0 = $cmurn2frags{$resource0->manager_urn()};

	    my $rspecdoc = AddLinkToRspec($fragment0, $ref);
	    return -1
		if (!defined($rspecdoc));
	    # Only one of these in the array, for building combined rspec.
	    $vname2doc{$linkname} = $rspecdoc;
	    
	    my $virtid1   = $ifaceref1->{'virtual_node_id'};
	    my $resource1 = $vname2res{$virtid1};
	    my $fragment1 = $cmurn2frags{$resource1->manager_urn()};
	    if ($resource0->manager_urn() ne $resource1->manager_urn()) {
		$rspecdoc = AddLinkToRspec($fragment1, $ref);
		return -1
		    if (!defined($rspecdoc));
	    }
	}
    }

    #
    # Compare to previous rspec; this tells us if we need to request
    # a new ticket. Easier to use the rspec then the manifest since
    # the CM added a ton of cruft to it.
    #
    foreach my $manager_urn (keys(%cmurn2res)) {
	my $resource = $cmurn2res{$manager_urn};

	# We got the ticket on a previous loop.
	next
	    if ($resource->HaveTicket());

	my $fragment    = $cmurn2frags{$manager_urn};
	my $frag_string = GeniXML::Serialize($fragment);
	# Must stash for redeemticket.
	$resource->stashrspec($frag_string);
	
	next
	    if (! $resource->HaveRspec());

	#
	# The idea is to do a diff of the rspec. If there are no
	# meaningful changes, then we can skip trying to get a new
	# ticket.
	#
	my $rspec    = $resource->Rspec();
	my $diff     = XML::SemanticDiff->new();
	my $rspec_string = GeniXML::Serialize($rspec);
	$resource->setmodified(0);

	print STDERR "Comparing old and new rspecs for $resource\n"; 
	foreach my $change ($diff->compare($rspec_string, $frag_string)) {
	    print STDERR " $change->{message} in context $change->{context}\n";
	    $resource->setmodified(1);
	}
	if ($resource->modified() && $resource->ApiLevel() == 0) {
	    print STDERR "*** Difference to rspec for level 0 $resource. ".
		"Not allowed, aborting\n";
	    return -1;
	}
    }

    #
    # Combine the fragments into final rspec document.
    #
    my $rspec = CombineRspecDocs("request", values(%vname2doc));
    return -1
	if (!defined($rspec));

    # Make sure all that namespace stuff is done correctly. 
    $rspec = GeniXML::Parse(GeniXML::Serialize($rspec));
    
    if ($verbose) {
	print STDERR "Final rspec:\n";
	my $rspecstr = GeniXML::Serialize($rspec, 1);
	print STDERR "$rspecstr\n";
    }
    $$rspecref = $rspec;
    return 0;
}

sub MapResourcesNew($$$$$)
{
    my ($experiment, $user, $topo, $rspecref, $verbose) = @_;
    my %cmurn2res   = ();
    my %cmurn2links = ();
    my %cmurn2frags = ();
    my %vname2res   = ();
    my %vname2doc   = ();
    my %nodes2cmurn = ();
	
    Register($experiment, $user) == 0
	or return -1;

    #
    # Build up rspec fragments from the "intermediate" representation
    # that libvtop passed in. Ick.
    #
    foreach my $ref (@{ $topo->{'node'} }) {
	# Skip non geni nodes; handled in libvtop
	next
	    if (! (exists($ref->{'isgeninode'}) && $ref->{'isgeninode'}));
	
	my $resource;
	my $node_urn    = $ref->{'request_urn'};
	my $manager_urn = $ref->{'manager_urn'};
	my $virtual_id  = $ref->{'virtual_id'};
	my (undef,undef,$node_id) = GeniHRN::Parse($node_urn);
	
	#
	# Get the resource object.
	#
	if (!exists($cmurn2res{$manager_urn})) {
	    $resource = GeniResource->Lookup($experiment->idx(), $manager_urn);
	    if (!defined($resource)) {
		$resource = GeniResource->Create($experiment, $manager_urn);
		if (!defined($resource)) {
		    print STDERR
			"Could not create GeniResource for $manager_urn\n";
		    return -1;
		}
	    }
	    $cmurn2res{$manager_urn} = $resource;
	}
	$resource = $cmurn2res{$manager_urn};
	$vname2res{$virtual_id} = $resource;

	#
	# The point of this is to split the rspec apart, since at present
	# assign cannot handle multiple advertisements, and it will not work
	# to pass in an rspec that references CMs other then the one
	# advertisement being passed in.
	#
	my $fragment;
	if (!exists($cmurn2frags{$manager_urn})) {
	    $fragment = CreateNewRspec("request");
	    return -1
		if (!defined($fragment));

	    $cmurn2frags{$manager_urn} = $fragment;
	}
	$fragment = $cmurn2frags{$manager_urn};

	my $rspecdoc = AddNodeToRspec($fragment, $ref);
	return -1
	    if (!defined($rspecdoc));
	$vname2doc{$virtual_id} = $rspecdoc;
    }

    #
    # As above, need to split the interfaces into the correct fragments.
    #
    if (exists($topo->{'link'})) {
	foreach my $ref (@{ $topo->{'link'} }) {
	    my $linkname   = $ref->{'virtual_id'};

	    # Skip tunnels until rspec stitching in place.
	    next
		if (exists($ref->{'link_type'}) &&
		    $ref->{'link_type'} eq "tunnel");

	    my $ifaceref0 = $ref->{'interface_ref'}->[0];
	    my $ifaceref1 = $ref->{'interface_ref'}->[1];
	    # Do not want to add this twice.
	    my $virtid0   = $ifaceref0->{'virtual_node_id'};
	    my $resource0 = $vname2res{$virtid0};
	    my $fragment0 = $cmurn2frags{$resource0->manager_urn()};

	    my $rspecdoc = AddLinkToRspec($fragment0, $ref);
	    return -1
		if (!defined($rspecdoc));
	    # Only one of these in the array, for building combined rspec.
	    $vname2doc{$linkname} = $rspecdoc;
	    
	    my $virtid1   = $ifaceref1->{'virtual_node_id'};
	    my $resource1 = $vname2res{$virtid1};
	    my $fragment1 = $cmurn2frags{$resource1->manager_urn()};
	    if ($resource0->manager_urn() ne $resource1->manager_urn()) {
		$rspecdoc = AddLinkToRspec($fragment1, $ref);
		return -1
		    if (!defined($rspecdoc));
	    }
	}
    }

    #
    # Discover resources in parallel, writing the advertisement to a file.
    #
    my $coderef = sub {
	my ($resource, $tmp) = @{ $_[0] };
	my $advertisement;

	print STDERR "Asking for resource list from $resource\n";
	if ($resource->Discover($user, \$advertisement)) {
		print STDERR "Could not get resource list for $resource\n";
		return -1;
	}
	#
	# Is the advertisement from a non-conforming manager, such as the SFA?
	# If so, must convert it to something assign can grok.
	#
	if ($resource->IsSFA()) {
	    $advertisement = ConvertSFAtoPG($advertisement, "ad",
					    $resource->manager_urn());
	    return -1
		if (!defined($advertisement));
	    $advertisement = GeniXML::Serialize($advertisement, 1);
	}

	my $ptop   = $tmp . ".ad";
	my $ptopfh = new IO::File "> $ptop";
	if (! defined($ptopfh)) {
	    print STDERR "Could not create temporary files for ptop\n";
	    return -1;
	}
	print $ptopfh $advertisement;
	$ptopfh->close();

	return 0;
    };
    
    #
    # Get advertisements in parallel. Need to cache these for the case that the
    # resource request has not changed.
    #
    my @todo    = ();
    my @results = ();
    my $name    = time();
    my $count   = 0;

    foreach my $manager_urn (keys(%cmurn2res)) {
	my $resource = $cmurn2res{$manager_urn};

	my $tmp  = "$name-$count";
	push(@todo, [$resource, $tmp]);
	$count++;
    }
    
    print STDERR "Getting advertisements in parallel ...\n";
    if (ParRun({'maxwaittime' => 600, 'maxchildren' => 4},
	       \@results, $coderef, @todo)) {
	print STDERR "*** MapResources: Internal error mapping resources\n";
	return -1;
    }
    
    #
    # Check the exit codes. 
    #
    my $errors   = 0;
    $count = 0;
    foreach my $result (@results) {
	my ($resource, $tmp) = @{ $todo[$count] };

	#
	# ParRun does a fork; so need to refresh the resource object
	# to sync it to the DB.
	#
	if ($resource->Refresh()) {
	    print STDERR "*** MapResources: Error synchronizing $resource\n";
	    $errors++;
	}
	elsif ($result != 0) {
	    print STDERR "*** Error getting advertisement for $resource\n";
	    $errors++;
	}
	$count++;
    }
    return -1
	if ($errors);
    
    my $soln = $name . ".soln";
    my $log  = $name . ".log";
    my $vtop = $name . ".vtop";
    my $ptop = $name . ".ptop";

    my $vtopfh = new IO::File "> $vtop";
    my $ptopfh = new IO::File "> $ptop";
    if (! (defined($vtopfh) && defined($ptopfh))) {
	print STDERR "Could not create temporary files for ptop/vtop\n";
	return -1;
    }
    # Combine the fragments into a single rspec document.
    my $rspec = CombineRspecDocs("request", values(%vname2doc));
    return -1
	if (!defined($rspec));
    
    my $rspecstr = GeniXML::Serialize($rspec, 1);
    print $vtopfh $rspecstr;
    $vtopfh->close();

    if ($verbose) {
	print STDERR "Initial Request:\n";
	print STDERR "$rspecstr\n";
    }

    #
    # Combine all the advertisements into one big file. Hope assign
    # can handle this.
    #
    my %adfrags = ();
    foreach my $ref (@todo) {
	my ($resource, $tmp) = @{ $ref };

	my $ad = $tmp . ".ad";
	my $frag = GeniXML::ParseFile($ad);
	if (!defined($frag)) {
	    print STDERR "Cannot parse advertisement for $resource\n";
	    return -1;
	}
	$adfrags{$resource->manager_urn()} = $frag;
    }
    my $advertisement = CombineRspecDocs("advertisement",
					 map { $_->childNodes() }
					 values(%adfrags));
    my $adstr = GeniXML::Serialize($advertisement, 1);
    print $ptopfh $adstr;
    $ptopfh->close();

    my $cmd = "nice $ASSIGN -uod -c .75 ".
	"-f rspec/rspec -W $soln $ptop $vtop > $log 2>&1";
    if ($verbose) {
	print STDERR "$cmd\n";
    }
    system($cmd);
	
    if ($?) {
	print STDERR "Could not map to physical resources\n";
	my $logstuff = `cat $log`;
	print STDERR "\n" . $logstuff . "\n";
	print STDERR "$rspecstr\n";
	return -1;
    }

    #
    # Read the solutions and write back to the rspec.
    #
    my $solution =
	eval { XMLin($soln, KeyAttr => [],
		     ForceArray => ["node", "link", "interface",
				    "interface_ref", "linkendpoints",
				    "component_manager"]) };
    if ($@) {
	print STDERR "XMLin error reading $soln: $@\n";
	return -1;
    }
    if ($verbose) {
	print STDERR "Solution:\n";
	print STDERR Dumper($solution);
    }

    foreach my $ref (@{ $solution->{'node'} }) {
	my $virtual_id = $ref->{'virtual_id'};
	my $node_urn   = $ref->{'component_uuid'};
	my $cm_urn     = $ref->{'component_manager_uuid'};
	my $node_name  = $ref->{'component_name'};
	my $rspecdoc   = $vname2doc{$virtual_id};

	$nodes2cmurn{$node_urn} = $cm_urn;
	#
	# This writes the solution back into the fragment.
	#
	$rspecdoc->setAttribute("component_uuid", $node_urn);
	$rspecdoc->setAttribute("component_urn", $node_urn);
	$rspecdoc->setAttribute("component_name", $node_name);
	$rspecdoc->setAttribute("component_manager_uuid", $cm_urn);
	$rspecdoc->setAttribute("component_manager_urn", $cm_urn);

	if (exists($ref->{'interface'})) {
	    my $interfaces = $ref->{'interface'};

	    foreach my $ifaceref (@{ $interfaces }) {
		my $virtid = $ifaceref->{'virtual_id'};
		my $compid = $ifaceref->{'component_id'};

		# Not supposed to happen, but does cause of issues
		# with tunnels and rspec stitching. 
		next
		    if (!defined($compid));

		foreach my $linkref (GeniXML::FindNodes("n:interface",
						$rspecdoc)->get_nodelist()) {
		    my $ovirtid = GeniXML::GetText("virtual_id", $linkref);
		    if ($ovirtid eq $virtid) {
			$linkref->setAttribute("component_id", $compid);
			last;
		    }
		}
	    }
	}
    }

    #
    # One last chore; we had to skip tunnels above since assign does
    # not know how to deal with them.
    #
    if (exists($topo->{'link'})) {
	foreach my $ref (@{ $topo->{'link'} }) {
	    my $linkname   = $ref->{'virtual_id'};

	    # Skip non-tunnels.
	    next
		if (! (exists($ref->{'link_type'}) &&
		       $ref->{'link_type'} eq "tunnel"));

	    my $ifaceref0 = $ref->{'interface_ref'}->[0];
	    my $ifaceref1 = $ref->{'interface_ref'}->[1];
	    # Do not want to add this twice.
	    my $virtid0   = $ifaceref0->{'virtual_node_id'};
	    my $resource0 = $vname2res{$virtid0};
	    my $fragment0 = $cmurn2frags{$resource0->manager_urn()};

	    my $rspecdoc = AddLinkToRspec($fragment0, $ref);
	    return -1
		if (!defined($rspecdoc));
	    # Only one of these in the array, for building combined rspec.
	    $vname2doc{$linkname} = $rspecdoc;
	    
	    my $virtid1   = $ifaceref1->{'virtual_node_id'};
	    my $resource1 = $vname2res{$virtid1};
	    my $fragment1 = $cmurn2frags{$resource1->manager_urn()};
	    if ($resource0->manager_urn() ne $resource1->manager_urn()) {
		$rspecdoc = AddLinkToRspec($fragment1, $ref);
		return -1
		    if (!defined($rspecdoc));
	    }
	}
    }

    #
    # Compare to previous rspec; this tells us if we need to request
    # a new ticket. Easier to use the rspec then the manifest since
    # the CM added a ton of cruft to it.
    #
    foreach my $manager_urn (keys(%cmurn2res)) {
	my $resource = $cmurn2res{$manager_urn};

	# We got the ticket on a previous loop.
	next
	    if ($resource->HaveTicket());

	my $fragment    = $cmurn2frags{$manager_urn};
	my $frag_string = GeniXML::Serialize($fragment);
	# Must stash for redeemticket.
	$resource->stashrspec($frag_string);
	
	next
	    if (! $resource->HaveRspec());

	#
	# The idea is to do a diff of the rspec. If there are no
	# meaningful changes, then we can skip trying to get a new
	# ticket.
	#
	my $rspec    = $resource->Rspec();
	my $diff     = XML::SemanticDiff->new();
	my $rspec_string = GeniXML::Serialize($rspec);
	$resource->setmodified(0);

	print STDERR "Comparing old and new rspecs for $resource\n"; 
	foreach my $change ($diff->compare($rspec_string, $frag_string)) {
	    print STDERR " $change->{message} in context $change->{context}\n";
	    $resource->setmodified(1);
	}
	if ($resource->modified() && $resource->ApiLevel() == 0) {
	    print STDERR "*** Difference to rspec for level 0 $resource. ".
		"Not allowed, aborting\n";
	    return -1;
	}
    }

    #
    # Combine the updated fragments into final rspec document.
    #
    $rspec = CombineRspecDocs("request", values(%vname2doc));
    return -1
	if (!defined($rspec));

    # Make sure all that namespace stuff is done correctly. 
    $rspec = GeniXML::Parse(GeniXML::Serialize($rspec));
    
    if ($verbose) {
	print STDERR "Final rspec:\n";
	my $rspecstr = GeniXML::Serialize($rspec, 1);
	print STDERR "$rspecstr\n";

	my $tmp = ConvertReqPGtoSFA($rspec);
	$rspecstr = GeniXML::Serialize($tmp, 1);

	print STDERR "SFA Version:\n";
	print STDERR "$rspecstr\n";
    }
    $$rspecref = $rspec;

    #
    # Before we return, lets make sure all the proxy nodes exist.
    # This is probably not the best place to do this, but remember
    # that once a proxy node exists, it will be available next time.
    #
    foreach my $node_urn (keys(%nodes2cmurn)) {
	my $cm_urn = $nodes2cmurn{$node_urn};

	my $proxy = LookupProxyNode($node_urn);
	if (!defined($proxy)) {
	    $proxy = GeniEmulabUtil::CreatePhysNode($cm_urn, $node_urn);
	    if (!defined($proxy)) {
		#
		# It would be nice at this point to drop the node from
		# the set and try again.
		#
		print STDERR "Could not create proxy node $node_urn\n";
		return -1;
	    }
	}
    }
    return 0;
}

sub GetTickets($)
{
    my ($vtop) = @_;
    my $experiment = $vtop->experiment();
    my $verbose    = $vtop->verbose();
    my $user       = $vtop->user();
    my $rspec      = $vtop->genirspec();
    my $eventkey   = $experiment->eventkey();
    my $keyhash    = $experiment->keyhash();

    Register($experiment, $user) == 0
	or return -1;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    if (! @resources) {
	print STDERR "RedeemTickets: No resource objects\n";
	return 0;
    }
    my @todo = ();

    foreach my $resource (@resources) {
	next
	    if ($resource->HaveTicket() || !$resource->modified());

	push(@todo, $resource);
    }
    return 0
	if (! @todo);

    #
    # Before sending off the rspec, add the stuff that we need for
    # full cooked mode to work.
    #
    foreach my $ref (GeniXML::FindNodes("n:node",
					$rspec)->get_nodelist()) {
	my $vname   = GeniXML::GetVirtualId($ref);
	my $node    = $vtop->VnameToNode($vname);

	# XXX Boot mode; simple vs full. Have not decided the
	# proper interface for this yet.
	my $bootmode = $experiment->GetEnvVariable("${vname}_BOOTMODE");
	next
	    if (defined($bootmode) && lc($bootmode) eq "basic");
	
	if (!defined($node)) {
	    print STDERR "*** GetTickets: No proxy node for $vname\n";
	    return -1;
	}
	
	# Generate a key for the node if not already there. The caller
	# has created and allocated the proxy nodes by now.
	my $key;
	
	if (!defined($node->external_resource_key())) {
	    $key = TBGenSecretKey();
	    $node->ModifyReservation({"external_resource_key" => $key}) == 0
		or return -1;
	}
	else {
	    $key = $node->external_resource_key();
	}

	$ref->setAttribute("tarfiles",
			   "/usr/local/etc/emulab ".
			   "$TBDOCBASE/downloads/geniclient.tar");
	    
	my $cmd = "sudo /usr/local/etc/emulab/rc/rc.pgeni ".
	    "-s $BOSSNODE -k $eventkey,$keyhash -i '$key'";
	$cmd .= " -j " . $node->node_id()
	    if ($node->isvirtnode());
	$cmd .= " -e 16509"
	    if ($ELVIN_COMPAT);

	$ref->setAttribute("startup_command", "$cmd boot");
    }
    if ($verbose) {
	print STDERR "Rspec for GetTicket():\n";
	print STDERR GeniXML::Serialize($rspec, 1) . "\n";
    }
    my $rspecstr = GeniXML::Serialize($rspec);

    #
    # Get Tickets in parallel.
    #
    my @results   = ();
    my $coderef   = sub {
	my ($resource) = @_;

	if ($resource->ApiLevel() == 0) {
	    print STDERR "Creating sliver on level 0 API $resource\n";
	    if ($resource->IsSFA()) {
		my $tmp = ConvertReqPGtoSFA($rspec);
		$rspecstr = GeniXML::Serialize($tmp);
	    }
	    return 0
		if ($resource->CreateSliver($user, $rspecstr, 0) == 0);
	}
	else {
	    print STDERR "Asking for ticket from $resource\n";
	    return 0
		if ($resource->GetTicket($user, $rspecstr, 0) == 0);
	}
	#
	# Print this here since we do not save this in the
	# DB, and the parent side of the fork will not have
	# the error message.
	#
	if ($resource->last_rpc_error() &&
	    defined($resource->last_rpc_value()) &&
	    $resource->last_rpc_value()) {
	    print STDERR $resource->last_rpc_value() . "\n";
	}
	# Return indicator of possible forward progress.
	return 1
	    if (defined($resource->last_rpc_output()) &&
		$resource->last_rpc_output() =~ /Could not map to/i);
	
	return -1;
    };
    print STDERR "Getting all tickets/slivers in parallel ...\n";
    
    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @todo)) {
	print STDERR "*** GetTickets: Internal error getting tickets\n";
	#
	# Need to be careful here; some of the tickets might have been
	# redeemed, and that happened in the child of a fork. Sync with
	# the DB so the parent sees the current state.
	#
	map { $_->Refresh() } @resources;
	return -1;
    }
    #
    # Check the exit codes. Eventually return specific error info.
    #
    my $errors   = 0;
    my $count    = 0;
    my $progress = 0;
    foreach my $result (@results) {
	my $resource = $todo[$count];

	#
	# ParRun does a fork; so need to refresh the resource object
	# to sync it to the DB.
	#
	if ($resource->Refresh()) {
	    print STDERR "*** GetTickets: Error synchronizing $resource\n";
	    $errors++;
	}
	elsif ($result != 0) {
	    print STDERR "*** Error getting ticket for $resource\n";
	    $errors++;

	    # Watch for forward progress. Not being able to map actually
	    # means forward progress since we want to try again with
	    # different resources. The mapper will try a few times before
	    $progress++
		if ($result > 1);
	}
	else {
	    $progress++;
	    my $object;

	    if ($resource->ApiLevel() == 0) {
		#
		# Created the sliver; 
		#
		$object = $resource->Manifest();

		#
		# Convert SFA manifest to rspec format.
		#
		if ($object && $resource->IsSFA()) {
		    my $tmp = ConvertSFAtoPG($object, "manifest",
					     $resource->manager_urn());
		    if (!defined($tmp) ||
			$resource->UpdateManifest($tmp)) {
			print STDERR "Could not store manifest for $resource\n";
			$errors++;
			$object = undef;
		    }
		    else {
			# reload.
			$object = $tmp;
		    }
		}
		
		# File the rspec away since that is what we have.
		if ($resource->UpdateRspec($resource->stashedrspec())) {
		    print STDERR "Could not store rspec for $resource\n";
		    $errors++;
		}
		$resource->stashrspec(undef);
	    }
	    else {
		#
		# Got a ticket.
		#
		$object = $resource->Ticket();
		$object = $object->rspec()
		    if (defined($object));
	    }
	    return -1
		if (!$object);

	    #
	    # Mark the proxy nodes so that libvtop knows. Failure means we
	    # need to release the node up in libvtop.
	    #	    
	    foreach my $ref (GeniXML::FindNodes("n:node",
						$object)->get_nodelist()) {
		my $vname      = GeniXML::GetVirtualId($ref);
		my $manager_urn= GeniXML::GetManagerId($ref);

		next
		    if (!defined($manager_urn) ||
			$resource->manager_urn() ne $manager_urn);
	    
		my $node = $experiment->VnameToNode($vname);
		if (defined($node)) {
		    $node->ModifyReservation({"external_resource_index" =>
						  $resource->idx()})
			== 0 or return -1;
		}
	    }
	}
	$count++;
    }
    return 0
	if (!$errors);
    
    print STDERR Dumper($rspec) if ($errors);
    # Return indication of forward progress so caller knows to to stop.
    return ($progress ? 1 : -1);
}

#
# Redeem the tickets for an experiment. 
#
sub RedeemTickets($$)
{
    my ($experiment, $user) = @_;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    if (! @resources) {
	print STDERR "RedeemTickets: No resource objects\n";
	return 0;
    }
    my @todo = ();

    foreach my $resource (@resources) {
	push(@todo, $resource)
	    if ($resource->HaveTicket());
    }
    return 0
	if (! @todo);

    #
    # Redeem Tickets in parallel.
    #
    my @results   = ();
    my $coderef   = sub {
	my ($resource) = @_;

	print STDERR "Redeeming ticket for $resource\n";
	if ($resource->RedeemTicket($user)) {
	    return -1;
	}
	return 0;
    };
    print STDERR "Redeeming all tickets in parallel ...\n";

    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @todo)) {
	print STDERR "*** RedeemTickets: Internal error getting tickets\n";
	#
	# Need to be careful here; some of the tickets might have been
	# redeemed, and that happened in the child of a fork. Sync with
	# the DB so the parent sees the current state.
	#
	map { $_->Refresh() } @resources;
	return -1;
    }
    #
    # Check the exit codes. Eventually return specific error info.
    #
    my $errors = 0;
    my $count  = 0;
    foreach my $result (@results) {
	my $resource = $todo[$count];
	
	#
	# ParRun does a fork; so need to refresh the resource object
	# to sync it to the DB.
	#
	if ($resource->Refresh()) {
	    print STDERR "*** RedeemTicket: Error synchronizing $resource\n";
	    $errors++;
	}
	elsif ($result != 0) {
	    print STDERR "*** Error redeeming ticket for $resource\n";
	    $errors++;
	}
	else {
	    # File the rspec away since that is what we have.
	    if ($resource->UpdateRspec($resource->stashedrspec())) {
		print STDERR "Could not store rspec for $resource\n";
		$errors++;
	    }
	    $resource->stashrspec(undef);
	}
	$count++;
    }
    return $errors;
}

#
# Map the local nodes to the external nodes. This just sets some DB
# state for now.
#
sub MapNodes($$)
{
    my ($experiment, $verbose) = @_;
    my %ifacemap = ();
    my $manifest_string;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    if (! @resources) {
	return 0;
    }

    foreach my $resource (@resources) {
	my $manifest = $resource->Manifest();
	return -1
	    if (!defined($manifest));
	my $rspec = $resource->Rspec();
	return -1
	    if (!defined($rspec));
	
	$manifest_string = GeniXML::Serialize($manifest, 1);

	if ($verbose) {
	    print STDERR "$manifest_string\n"
	}

	foreach my $ref (GeniXML::FindNodes("n:node",
					    $manifest)->get_nodelist()) {
	    my $sliver_urn = GeniXML::GetText("sliver_urn", $ref);
	    my $vname      = GeniXML::GetVirtualId($ref);
	    my $sshdport   = GeniXML::GetText("sshdport", $ref);
	    my $manager_urn= GeniXML::GetText("component_manager_urn", $ref);

	    #
	    # The manifest can include nodes from other CMs. There will not
	    # be a sliver urn in that case.
	    #
	    next
		if (!defined($sliver_urn));

	    # Hmm, still need to check this. 
	    next
		if (!defined($manager_urn) ||
		    $manager_urn ne $resource->manager_urn());
	    
	    my $node = $experiment->VnameToNode($vname);
	    if (!defined($node)) {
		print STDERR
		    "MapNodes: Could not locate node $vname in $experiment\n";
		goto bad;
	    }
	    $node->ModifyReservation({"external_resource_index" =>
					  $resource->idx(),
				      "external_resource_id"    =>
				          $sliver_urn})
		== 0 or return -1;

	    if (defined($sshdport)) {
		$node->Update({'sshdport' => $sshdport});
	    }

	    # Interface map for loop below.
	    if (defined(GeniXML::FindFirst("n:interface", $ref))) {
		foreach my $ifaceref (GeniXML::FindNodes("n:interface",
						$ref)->get_nodelist()) {
		    my $virtid = GeniXML::GetText("virtual_id", $ifaceref);
		    my $compid = GeniXML::GetText("component_id", $ifaceref);

		    $ifacemap{$virtid} = [$node, $compid];
		}
	    }
	}
	foreach my $ref (GeniXML::FindNodes("n:link",
					    $manifest)->get_nodelist()) {
	    my $linkname   = GeniXML::GetVirtualId($ref);
	    my $link_type  = GeniXML::GetText("link_type", $ref);
	    my $vlantag    = GeniXML::GetText("vlantag", $ref);
	    my @ifacerefs  = GeniXML::FindNodes("n:interface_ref",
						$ref)->get_nodelist();
	    my %managers   = ();

	    if (GeniXML::FindNodes("n:component_manager", $ref)) {
		%managers = map { GetLinkManager($_) => $_ } 
		                  GeniXML::FindNodes("n:component_manager",
						     $ref)->get_nodelist();
	    }

	    # Skip tunnels in this loop for now.
	    next
		if (defined($link_type) && $link_type eq "tunnel");

	    #
	    # The manifest can include links for other CMs. Skip those
	    # for now.
	    #
	    next 
		if (!exists($managers{$resource->manager_urn()}));

	    if (defined($vlantag)) {
		my $TAG = $vlantag;
		
		if (defined($TAG)) {
		    if (!($TAG =~ /^[\w]*$/)) {
			print STDERR "Bad vlantag '$TAG' for $linkname\n";
			goto bad;
		    }
		    my $lan = Lan->Lookup($experiment, $linkname, 1);
		    if (!defined($lan)) {
			print STDERR "Could not find vlan for $linkname\n";
			goto bad;
		    }
		    #
		    # XXX This seems backwards. If the lan is pointing
		    # to another lan, then we really want to change that
		    # one. 
		    #
		    if ($lan->type() eq "emulated" && defined($lan->link())) {
			$lan = Lan->Lookup($lan->link());
			if (!defined($lan)) {
			    print STDERR 
				"Could not find linked vlan for $linkname\n";
			    return -1;
			}
		    }
		    return -1
			if ($lan->SetAttribute("vlantag", $TAG));
		}
	    }

	    foreach my $ifaceref (@ifacerefs) {
		my $vname    = GeniXML::GetText("virtual_node_id", $ifaceref);
		my $iface_id = GeniXML::GetText("virtual_interface_id",
						$ifaceref);
		my $MAC      = GeniXML::GetText("MAC", $ifaceref);
		my $VMAC     = GeniXML::GetText("VMAC", $ifaceref);
		my ($node, $compid) = @{ $ifacemap{$iface_id} };
		my $iface;

		if (GeniHRN::IsValid($compid)) {
		    (undef,undef,$iface) = GeniHRN::ParseInterface($compid);
		}
		else {
		    $iface = $compid;
		}
		if (!defined($iface)) {
		    print STDERR "Could not determine iface for" .
			"$vname,$iface_id\n";
		    goto bad;
		}
		#
		# If this is a virtual node, then we want to set the
		# MACs of the underlying physical node. The vinterface
		# (VMAC) will be handled below.
		#
		if ($node->isvirtnode()) {
		    my $pnode = $node->GetPhysHost();
		    if (!defined($pnode)) {
			print STDERR "Could not physical node for $node\n";
			goto bad;
		    }
		    $node = $pnode;
		}

		#
		# If the interface is the loopback, then we do not need
		# to do this.
		#
		if ($iface ne "lo0" && $iface ne "loopback") {
		    my $interface = Interface->LookupByIface($node,$iface);
		    if (!defined($interface)) {
			print STDERR "Could not map iface for $node,$iface\n";
			goto bad;
		    }
		    if (!defined($MAC)) {
			print STDERR "No mac (or vmac) for $node,$iface\n";
			goto bad;
		    }
		    if (! ($MAC =~ /^[\w]*$/)) {
			print STDERR "Bad mac '$MAC' for $node,$iface\n";
			goto bad;
		    }
		    if ($interface->Update({"mac" => "$MAC"})) {
			print STDERR "Could not update $node,$iface\n";
			goto bad;
		    }
		}
		if (defined($VMAC)) {
		    my $vinterface =
			Interface::VInterface->LookupByVirtLan($experiment,
							       $linkname,
							       $vname);
		    if (!defined($vinterface)) {
			print STDERR
			    "Could not map vinterface for $linkname,$vname\n";
			goto bad;
		    }
		    if (! ($VMAC =~ /^[\w]*$/)) {
			print STDERR "Bad vmac '$VMAC' for $linkname,$vname\n";
			goto bad;
		    }
		    if ($vinterface->Update({"mac" => "$VMAC"})) {
			print STDERR "Could not update $linkname,$vname\n";
			goto bad;
		    }
		}
	    }
	}
	if ($verbose) {
	    my $string = GeniXML::Serialize($manifest, 1);
	    print STDERR "$string\n";
	}
	
	# The manifest was changed above.
	if ($resource->UpdateManifest($manifest)) {
	    print STDERR "Could not store manifest for $resource\n";
	    return -1;
	}
    }
    return 0;

  bad:
    if ($manifest_string) {
	print STDERR "$manifest_string\n";
    }
    return -1;
}

#
# Boot (Start) all of the slivers. This does the entire set, and blocks
# till done. Expressly for use from os_setup.
#
sub StartSlivers($$$)
{
    my ($experiment, $user, $verbose) = @_;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    if (! @resources) {
	return 0;
    }

    #
    # Start slivers in parallel.
    # 
    my @results = ();
    my $coderef = sub {
	my ($resource) = @_;

	# The sliver was auto started. We just need to wait for it.
	if ($resource->Api() eq "AM" ||
	    $resource->ApiLevel() == 0) {
	    print STDERR
		"Skipping start sliver on level 0 resource $resource\n";
	    return 0;
	}

	if ($resource->Version() >= 2) {
	    #
	    # First get the state; we might not need to start it
	    # (would be wrong) if the sliver is in the started
	    # start. We deal with restart later.
	    #
	    print STDERR "Getting current sliver status for $resource\n";
	    my $status;
	
	    while (1) {
		my $retval = $resource->SliverStatus($user, \$status);
		last
		    if ($retval == 0);

		if ($resource->last_rpc_error() &&
		    $resource->last_rpc_error() == GENIRESPONSE_BUSY()) {
		    sleep(10);
		    next;
		}
		else {
		    print STDERR "Error getting sliver status for $resource\n";
		    # Tell the parent error.
		    return -1;
		}
	    }
	    if ($status->{'state'} eq "started") {
		print STDERR "Skipping start on already started $resource.\n";
		return 0;
	    }
	}
	print STDERR "Starting sliver $resource\n";
	while (1) {
	    my $retval = $resource->StartSliver($user);
	    last
		if (!$retval);
	    return -1
		if (!$resource->last_rpc_error() ||
		    $resource->last_rpc_error() != GENIRESPONSE_BUSY());
	    
	    sleep(10);
	}
	#
	# Grab a new manifest;
	#
	if ($resource->Version() == 2.0) {
	    while (1) {
		print STDERR "Getting ($$) new manifest for $resource\n";
		my $retval = $resource->GetManifest($user);
		last
		    if (!$retval);
		return -1
		    if (!$resource->last_rpc_error() ||
			$resource->last_rpc_error() != GENIRESPONSE_BUSY());
	    
		sleep(10);
	    }

	}
	return 0;
    };
    print STDERR "Starting all slivers in parallel ...\n";

    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @resources)) {
	print STDERR "*** StartSlivers: Internal error starting slivers.\n";
	return -1;
    }
    #
    # Check the exit codes. Eventually return specific error info.
    #
    my $errors = 0;
    my $count  = 0;
    my @tmp    = ();
    my @failed = ();
    foreach my $result (@results) {
	my $resource = $resources[$count];
	
	if ($result != 0) {
	    print STDERR "*** Error starting slivers for $resource\n";
	    $errors++;
	    push(@failed, $resource);
	}
	else {
	    #
	    # ParRun does a fork; so need to refresh the resource object
	    # to sync it to the DB.
	    #
	    if ($resource->Refresh()) {
		print STDERR
		    "*** StartSlivers: Error synchronizing $resource\n";
		$errors++;
	    }
	    push(@tmp, $resource);
	}
	$count++;
    }
    #
    # Set the nodes to TBFAILED to avoid waiting in os_setup.
    #
    if (@failed) {
	foreach my $resource (@failed) {
	    my $manager_urn = $resource->manager_urn();
	    my $manifest    = $resource->Manifest();
	    return -1
		if (!defined($manifest));

	    foreach my $ref (GeniXML::FindNodes("n:node",
						$manifest)->get_nodelist()) {
		my $vname            = GeniXML::GetVirtualId($ref);
		my $this_manager_urn = GeniXML::GetManagerId($ref);

		next
		    if (!defined($this_manager_urn) ||
			$manager_urn ne $this_manager_urn);
		
		my $node = $experiment->VnameToNode($vname);
		next
		    if (!defined($node));

		if ($node->eventstate() ne TBDB_NODESTATE_TBFAILED()) {
		    $node->SetEventState(TBDB_NODESTATE_TBFAILED());
		}
	    }
	}
    }
    # Everything failed, stop now. 
    return -1
	if (!@tmp);
    
    MapNodes($experiment, $verbose);
    
    return WaitForSlivers($experiment, $user, $verbose, @tmp);
}

sub WaitForSlivers($$$@)
{
    my ($experiment, $user, $verbose, @resources) = @_;
    my %nodemap = ();

    #
    # Get the resource objects.
    #
    @resources = GeniResource->LookupAll($experiment)
	if (!@resources);
    
    if (! @resources) {
	return 0;
    }

    print STDERR "Waiting for slivers ...\n";

    #
    # Build a map of the nodes. I made a real mess of this in Version 1.
    #
    foreach my $resource (@resources) {
	my $manifest = $resource->Manifest();
	return -1
	    if (!defined($manifest));

	foreach my $ref (GeniXML::FindNodes("n:node",
					    $manifest)->get_nodelist()) {
	    my $vname      = GeniXML::GetVirtualId($ref);
	    my $urn        = GeniXML::GetNodeId($ref);
	    my $node       = $experiment->VnameToNode($vname);

	    #
	    # The manifest can include nodes from other CMs. There will not
	    # be a sliver urn in that case.
	    #
	    my $sliver_urn = GeniXML::GetSliverId($ref);
	    next
		if (!defined($sliver_urn));
	    
	    if (!defined($node)) {
		print STDERR "*** WaitForSlivers: ".
		    "Could not locate node $vname in $experiment\n";
		return -1;
	    }
	    if ($resource->Version() == 1.0) {
		my ($domain,undef,$node_id) = GeniHRN::Parse($urn);
		$urn = GeniHRN::Generate($domain, "sliver", $node_id);
		$nodemap{$urn} = $node;
	    }
	    else {
		next
		    if (!defined($node->external_resource_id()) ||
			$node->external_resource_id() eq "");

		$nodemap{$node->external_resource_id()} = $node;
	    }
	    $node->Refresh();

	    # XXX Boot mode; simple vs full. Have not decided on the
	    # proper interface for this yet.
	    my $bootmode = $experiment->GetEnvVariable("${vname}_BOOTMODE");
	    # Stash it in the node object.
	    $node->_bootmode($bootmode || "");
	}
    }

    #
    # Now we use parrun again to get the sliver status. We are waiting
    # for them to become ready so we can send them into ISUP. 
    #
    my $coderef = sub {
	my ($resource) = @_;
	my $ref;
	my $failed   = 0;
	my $ready    = 0;
	my $count    = 0;

	print STDERR "Getting ($$) sliver status for $resource\n";

	if ($resource->SliverStatus($user, \$ref) != 0) {
	    # Tell the parent to keep trying.
	    return 1
		if ($resource->last_rpc_error() &&
		    $resource->last_rpc_error() == GENIRESPONSE_BUSY());
	    
	    print STDERR "Error getting sliver status for $resource\n";
	    # Tell the parent error.
	    return -1;
	}
	print STDERR Dumper($ref)
	    if ($verbose);

	foreach my $key (keys(%{ $ref->{'details'} })) {
	    my $val  = $ref->{'details'}->{$key};
	    my ($status, $node);

	    if ($resource->Api() eq "AM") {
		$node   = $nodemap{$key};
		$status = $val->{'status'};
	    }
	    elsif ($resource->Version() == 1.0) {
		$node   = $nodemap{$key};
		$status = $val;
	    }
	    elsif ($resource->Version() == 2.0) {
		$node   = $nodemap{$key};
		$status = $val->{'status'};
	    }
	    else {
		print STDERR
		    "*** WaitForSlivers: Unknown version on $resource\n";
		next;
	    }

	    if (!defined($node)) {
		print STDERR "No node in map for $key ($resource)\n";
		next;
	    }
	    # State was changed in a another process.
	    $node->Refresh();
	    
	    $count++;
	    if ($status eq "ready") {
		# print statement would be repeated.
		# Normal node waiting at this point, for ISUP to arrive.
		$ready++;

		# Basic mode; node is immediately ISUP.
		if (($node->_bootmode()) eq "basic" &&
		    $node->eventstate() ne TBDB_NODESTATE_ISUP()) {
		    $node->SetEventState(TBDB_NODESTATE_ISUP());
		}
	    }
	    elsif ($status eq "failed") {
		# print statement would be repeated.
		# We want to do something here, to avoid waiting
		# for something that failed, but might not report in any
		# status. os_setup might wait a really long time for the
		# timeout, and that is silly.
		#
		if ($node->eventstate() ne TBDB_NODESTATE_TBFAILED()) {
		    $node->SetEventState(TBDB_NODESTATE_TBFAILED());
		}
		$failed++;
	    }
	}
	# Tell the parent to stop if all nodes are ready.
	if ($ref->{'status'} eq "ready" || ($failed + $ready) == $count) {
	    return 0;
	}
	# Tell the parent not ready.
	return 1;
    };
    #
    # We want to watch for failures.
    #
    my @failed = ();
    
    print STDERR "Waiting for all slivers in parallel ...\n";

    while (@resources) {
	my @results = ();
	
	if (ParRun(undef, \@results, $coderef, @resources)) {
	    print STDERR
		"*** WaitForSlivers: Internal error waiting on slivers.\n";
	    return -1;
	}

	my @tmp = ();
	while (@results) {
	    my $result   = pop(@results);
	    my $resource = pop(@resources);
	    if ($result > 0) {
		push(@tmp, $resource);
	    }
	    elsif ($result < 0) {
		push(@failed, $resource);
	    }
	}
	@resources = @tmp;

	#
	# Check for cancelation. When canceled, go through and mark
	# any nodes that have not been marked, as failed. 
	#
	last
	    if ($experiment->canceled());

	sleep(15)
	    if (@resources);
    }
    #
    # If we get here, mark nodes in failed resources, with TBFAILED.
    # This will stop the waiting up in os_setup.
    #
    foreach my $resource (@failed) {	
	my $manifest = $resource->Manifest();
	next
	    if (!defined($manifest));

	foreach my $ref (GeniXML::FindNodes("n:node",
					    $manifest)->get_nodelist()) {
	    my $vname      = GeniXML::GetVirtualId($ref);
	    my $node       = $experiment->VnameToNode($vname);
	    next
		if (!defined($node));
	    # State was changed in child process.
	    $node->Refresh();

	    if ($node->eventstate() ne TBDB_NODESTATE_ISUP &&
		$node->eventstate() ne TBDB_NODESTATE_TBFAILED) {
		$node->SetEventState(TBDB_NODESTATE_TBFAILED());
	    }
	}
    }
    return 0;
}

#
# Reboot (restart) slivers. 
#
sub RestartNodes($$@)
{
    my ($user, $verbose, @nodes) = @_;

    my %resources = ();
    my @todo = ();

    #
    # Figure out which resources and slivers, from the set of nodes.
    #
    foreach my $node (@nodes) {
	my $index    = $node->external_resource_index();
	my $resource = GeniResource->Lookup($index);
	my $urn = $node->external_resource_id();

	if (!defined($resource)) {
	    print STDERR "*** RestartSlivers: No resource for $node\n";
	    return -1;
	}
	if (!exists($resources{"$index"})) {
	    $resources{"$index"} = [];
	}
	push(@{ $resources{"$index"} }, $urn);

	# XXX Move this. Force the node into the new state.
	$node->SetEventState(TBDB_NODESTATE_SHUTDOWN());
    }
    foreach my $index (keys(%resources)) {
	my $resource = GeniResource->Lookup($index);
	my $urns = $resources{"$index"};

	push(@todo, [$resource, $urns]);
    }
    
    #
    # Start slivers in parallel.
    # 
    my @results = ();
    my $coderef = sub {
	my ($argref) = @_;
	my ($resource, $urns) = @{ $argref };
	my @urns = @{ $urns };

	if ($resource->Api() eq "AM") {
	    print STDERR "Skipping restart on AM $resource\n";
	    return 0;
	}

	while (1) {
	    print STDERR "Restarting slivers on $resource\n";
	    my $retval = $resource->RestartSliver($user, @urns);
	    last
		if (!$retval);
	    return -1
		if (!$resource->last_rpc_error() ||
		    $resource->last_rpc_error() != GENIRESPONSE_BUSY());
	    
	    sleep(10);
	}
	return 0;
    };
    print STDERR "Restarting slivers in parallel ...\n";

    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @todo)) {
	print STDERR "*** StartSlivers: Internal error starting slivers.\n";
	return -1;
    }
    #
    # Check the exit codes. Eventually return specific error info.
    #
    my $errors = 0;
    my $count  = 0;
    my @tmp    = ();
    my @failed = ();
    foreach my $result (@results) {
	my ($resource) = @{ $todo[$count] };
	
	if ($result != 0) {
	    print STDERR "*** Error restarting slivers for $resource\n";
	    $errors++;
	    push(@failed, $resource);
	}
	else {
	    #
	    # ParRun does a fork; so need to refresh the resource object
	    # to sync it to the DB.
	    #
	    if ($resource->Refresh()) {
		print STDERR
		    "*** RestartSlivers: Error synchronizing $resource\n";
		$errors++;
	    }
	    push(@tmp, $resource);
	}
	$count++;
    }
    return $errors;
}

#
# Wait for specific nodes (slivers).
#
sub WaitForNodes($$$@)
{
    my ($user, $verbose, $options, @nodes) = @_;
    my %nodemap   = ();
    my %resources = ();
    my @todo = ();

    #
    # Figure out which resources from the set of nodes.
    #
    foreach my $node (@nodes) {
	$node->Refresh();
	
	my $index    = $node->external_resource_index();
	my $resource = GeniResource->Lookup($index);
	my $urn      = $node->external_resource_id();
	my $vname    = $node->vname();

	if (!defined($resource)) {
	    print STDERR "*** RestartSlivers: No resource for $node\n";
	    return -1;
	}
	if (!exists($resources{"$index"})) {
	    push(@todo, $resource);
	    $resources{"$index"} = $resource;
	}
	# Needed below.
	$nodemap{$urn} = $node;
	
	# XXX Boot mode; simple vs full. Have not decided on the
	# proper interface for this yet.
	my $experiment = $node->Reservation();
	if (!defined($experiment)) {
	    $node->_bootmode("basic");
	}
	else {
	    my $bootmode = $experiment->GetEnvVariable("${vname}_BOOTMODE");
	    # Stash it in the node object.
	    $node->_bootmode($bootmode || "");
	}
    }
    print STDERR "Waiting for protogeni nodes ...\n";

    #
    # Now we use parrun again to get the sliver status. We are waiting
    # for them to become ready so we can send them into ISUP. 
    #
    my $coderef = sub {
	my ($resource) = @_;
	my $ref;
	my $failed   = 0;
	my $ready    = 0;
	my $count    = 0;

	print STDERR "Getting sliver status for $resource\n";

	if ($resource->SliverStatus($user, \$ref) != 0) {
	    # Tell the parent to keep trying.
	    return 1
		if ($resource->last_rpc_error() &&
		    $resource->last_rpc_error() == GENIRESPONSE_BUSY());
	    
	    print STDERR "Error getting sliver status for $resource\n";
	    # Tell the parent error.
	    return -1;
	}
	print STDERR Dumper($ref)
	    if ($verbose);

	foreach my $key (keys(%{ $ref->{'details'} })) {
	    my $val  = $ref->{'details'}->{$key};
	    my ($status, $node);

	    if ($resource->Api() eq "AM") {
		$node   = $nodemap{$key};
		$status = $val->{'status'};
	    }
	    elsif ($resource->Version() == 1.0) {
		$node   = $nodemap{$key};
		$status = $val;
	    }
	    elsif ($resource->Version() == 2.0) {
		$node   = $nodemap{$key};
		$status = $val->{'status'};
	    }
	    else {
		print STDERR
		    "*** WaitForNodes: Unknown version on $resource\n";
		next;
	    }

	    if (!defined($node)) {
		# Not a node we are waiting for.
		next;
	    }
	    # State was changed in a another process.
	    $node->Refresh();
	    
	    $count++;
	    if ($status eq "ready") {
		# print statement would be repeated.
		# Normal node waiting at this point, for ISUP to arrive.
		$ready++;

		# Basic mode; node is immediately ISUP.
		if (($node->_bootmode()) eq "basic" &&
		    $node->eventstate() ne TBDB_NODESTATE_ISUP()) {
		    $node->SetEventState(TBDB_NODESTATE_ISUP());
		}
	    }
	    elsif ($status eq "failed") {
		# print statement would be repeated.
		# We want to do something here, to avoid waiting
		# for something that failed, but might not report in any
		# status. os_setup might wait a really long time for the
		# timeout, and that is silly.
		#
		if ($node->eventstate() ne TBDB_NODESTATE_TBFAILED()) {
		    $node->SetEventState(TBDB_NODESTATE_TBFAILED());
		}
		$failed++;
	    }
	}
	# Tell the parent to stop if all nodes are ready.
	if ($ref->{'status'} eq "ready" || ($failed + $ready) == $count) {
	    return 0;
	}
	# Tell the parent not ready.
	return 1;
    };
    
    print STDERR "Waiting for all protogeni nodes in parallel ...\n";

    while (@todo) {
	my @results = ();
	
	if (ParRun(undef, \@results, $coderef, @todo)) {
	    print STDERR
		"*** WaitForNodes: Internal error waiting on slivers.\n";
	    return -1;
	}

	my @tmp = ();
	while (@results) {
	    my $result   = pop(@results);
	    my $resource = pop(@todo);
	    if ($result > 0) {
		push(@tmp, $resource);
	    }
	}
	@todo = @tmp;

	sleep(15)
	    if (@todo);
    }
    return 0;
}

#
# Release outstanding tickets, as for a swapmod error.
#
sub ReleaseTickets($$)
{
    my ($experiment, $user) = @_;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    return 0
	if (! @resources);
    # Skip resources with no ticket.
    my @tmp = ();
    foreach my $resource (@resources) {
	push(@tmp, $resource)
	    if ($resource->newticket_idx());
    }
    @resources = @tmp;
    return 0
	if (!@resources);
    
    #
    # Delete tickets in parallel.
    # 
    my @results = ();
    my $coderef = sub {
	my ($resource) = @_;

	print STDERR "Releasing ticket for $resource\n";

	while (1) {
	    my $retval = $resource->ReleaseTicket($user);
	    last
		if (!$retval);
	    return -1
		if (!$resource->last_rpc_error() ||
		    ($resource->last_rpc_error() != GENIRESPONSE_BUSY() &&
		     $resource->last_rpc_error() != GENIRESPONSE_SEARCHFAILED()));
	    
	    sleep(10);
	}
	return 0;
    };
    print STDERR "Releasing outstanding tickets in parallel ...\n";

    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @resources)) {
	print STDERR
	    "*** ReleaseTickets: Internal error releasing tickets.\n";
	#
	# Need to be careful here; some of the tickets might have been
	# deleted, and that happened in the child of a fork. Sync with
	# the DB so the parent sees the current state.
	#
	map { $_->Refresh() } @resources;
	return -1;
    }
    # Ditto, above.
    map { $_->Refresh() } @resources;
    return 0;
}

#
# Delete all slivers for an Experiment.
#
sub DeleteAllSlivers($$)
{
    my ($experiment, $user) = @_;

    #
    # Get the resource objects.
    #
    my @resources = GeniResource->LookupAll($experiment);
    if (! @resources) {
	return 0;
    }
    #
    # Delete slivers in parallel.
    # 
    my @results = ();
    my $coderef = sub {
	my ($resource) = @_;

	print STDERR "Deleting ($$) sliver for $resource\n";

	while (1) {
	    my $retval = $resource->Clear($user);
	    last
		if (!$retval);
	    return -1
		if (!$resource->last_rpc_error() ||
		    ($resource->last_rpc_error() != GENIRESPONSE_BUSY() &&
		     $resource->last_rpc_error() != GENIRESPONSE_SEARCHFAILED()));
	    
	    sleep(10);
	}
	if ($resource->Delete()) {
	    print STDERR "DeleteSlivers: Could not delete $resource\n";
	    return -1;
	}
	return 0;
    };
    print STDERR "Deleting all slivers in parallel ...\n";

    if (ParRun({'maxwaittime' => 600}, \@results, $coderef, @resources)) {
	print STDERR
	    "*** DeleteAllSlivers: Internal error deleting slivers.\n";
	#
	# Need to be careful here; some of the tickets might have been
	# deleted, and that happened in the child of a fork. Sync with
	# the DB so the parent sees the current state.
	#
	map { $_->Refresh() } @resources;
	return -1;
    }
    # Ditto, above.
    map { $_->Refresh() } @resources;
    return 0;
}

#
# Find the proxy (widearea) node given a urn.
#
sub LookupProxyNode($)
{
    my ($node_urn) = @_;

    my $query_result =
	DBQueryWarn("select node_id,hostname from widearea_nodeinfo ".
		    "where external_node_id='$node_urn'");
    return undef
	if (!$query_result);

    if ($query_result->numrows) {
	my ($node_id,$hostname) = $query_result->fetchrow_array();
	my $node = Node->Lookup($node_id);
	if (!defined($node)) {
	    print STDERR "Could not get object for $node_id ($node_urn)\n";
	    return undef;
	}
	return $node;
    }
    return undef;
}

#
# Generate a new fragment.
#
sub CreateNewRspec($)
{
    my ($type) = @_;
    
    my $doc = XML::LibXML::Document->new();

    my $root = $doc->createElement("rspec");
    $root->setAttribute("type", $type);
    $root->setAttribute("generated_by", "libvtop");
    $root->setAttribute("xmlns",
			'http://www.protogeni.net/resources/rspec/0.2');
    $root->setAttribute("xmlns:xsi",
			"http://www.w3.org/2001/XMLSchema-instance");
    $root->setAttribute("xsi:schemaLocation",
		"http://www.protogeni.net/resources/rspec/0.2 ".
		"http://www.protogeni.net/resources/rspec/0.2/".
		  ($type eq "request" ? "request.xsd" : "ad.xsd"));

    $doc->setDocumentElement($root);
    return $doc;
}

#
# Combine a bunch of documents into a single rspec.
#
sub CombineRspecDocs($@)
{
    my ($type,@docs) = @_;
    my $rspec = CreateNewRspec($type);
    return -1
	if (!defined($rspec));
    my $root = $rspec->getDocumentElement();

    # These are probably not needed, but nice to do.
    my $creation   = time();
    my $expiration = $creation + (3600 * 6);
    $root->setAttribute("generated", 
			POSIX::strftime("20%y-%m-%dT%H:%M:%S",
					gmtime($creation)));
    $root->setAttribute("valid_until",
			POSIX::strftime("20%y-%m-%dT%H:%M:%S",
					gmtime($expiration)));
    foreach my $element (@docs) {
	$root->appendChild($element);
    }
    return $rspec;
}

#
# Creates a child node with name "nodeName" whose parent is "parent"
# in the XML document "document"
#
sub addChildToRspec($$$)
{
    my ($doc, $root, $name) = @_;
    my $newnode = $doc->createElement($name);
    $root->appendChild($newnode);
    return $newnode;
}

#
# Add a node to the fragment. Return the element. This creates a 0.2 rspec
# at the moment. Eventually replace with the code in libvtop that creates
# version 2, but not until all sites are running version 2. The libvtop code
# will need some minor changes though.
#
sub AddNodeToRspec($$)
{
    my ($doc, $node) = @_;
    my $root = $doc->getDocumentElement();
    my ($authority,undef,$node_id) = GeniHRN::Parse($node->{'request_urn'});

    my $rspecnode = addChildToRspec($doc, $root, 'node');
    $rspecnode->setAttribute('virtual_id', $node->{'virtual_id'});
    $rspecnode->setAttribute('component_manager_urn', $node->{'manager_urn'});
    if ($node_id ne "*") {
	$rspecnode->setAttribute('component_urn', $node->{'request_urn'});
    }
    if (exists($node->{'virtualization_type'})) {
	$rspecnode->setAttribute('virtualization_type',
				 $node->{'virtualization_type'});
    }
    if (exists($node->{'virtualization_subtype'})) {
	$rspecnode->setAttribute('virtualization_subtype',
				 $node->{'virtualization_subtype'});
    }
    if (exists($node->{'exclusive'})) {
	$rspecnode->setAttribute('exclusive', $node->{'exclusive'});
    }
    if (exists($node->{'node_type'})) {
	my $tmp = addChildToRspec($doc, $rspecnode, 'node_type');
	$tmp->setAttribute("type_name",  $node->{'node_type'});
	$tmp->setAttribute("type_slots", $node->{'type_slots'});
    }
    if (exists($node->{'disk_image'})) {
	my $osname = $node->{'disk_image'}->{'name'};
	my $osurn  = GeniHRN::Generate($authority, "image", "emulab-ops");
	$osurn .= "//" . $osname;

	my $tmp = addChildToRspec($doc, $rspecnode, 'disk_image');
	$tmp->setAttribute("name", $osurn);
    }
    # Add interfaces to the node
    if (exists($node->{'interfaces'})) {
	foreach my $interface (@{$node->{'interfaces'}}) {
	    my $virtid = $interface->{'virtual_id'};
	    my $compid = $interface->{'component_id'};
	
	    my $tmp = addChildToRspec($doc, $rspecnode, 'interface');
	    $tmp->setAttribute('virtual_id', $virtid);
	    if (defined($compid)) {
		$tmp->setAttribute('component_id', $compid);
	    }
	}
    }
    return $rspecnode;
}

sub AddLinkToRspec($$)
{
    my ($doc, $link) = @_;
    my $root = $doc->getDocumentElement();

    my $rspeclink = addChildToRspec($doc, $root, 'link');
    $rspeclink->setAttribute('virtual_id', $link->{'virtual_id'});
    if (exists($link->{'virtualization_type'})) {
	$rspeclink->setAttribute('virtualization_type',
				 $link->{'virtualization_type'});
    }

    if (0) {
	my $linktype = addChildToRspec($doc, $rspeclink, 'link_type');
	$linktype->setAttribute('name', $link->{'link_type'});
    }
    else {
	$rspeclink->setAttribute('link_type', $link->{'link_type'});
    }
    my $bandwidth = addChildToRspec($doc, $rspeclink, 'bandwidth');
    $bandwidth->appendText($link->{'capacity'});
    
    if (exists($link->{'manager_urn'})) {
	foreach my $urn (@{ $link->{'manager_urn'} }) {
	    my $tmp = addChildToRspec($doc, $rspeclink, 'component_manager');
	    $tmp->setAttribute('name', $urn);
	}
    }
    # Add the interface refs
    foreach my $ifaceref (@{ $link->{'interface_ref'} }) {
	my $nodeid  = $ifaceref->{'virtual_node_id'};
	my $ifaceid = $ifaceref->{'virtual_interface_id'};
	my $tmp = addChildToRspec($doc, $rspeclink, 'interface_ref');
	$tmp->setAttribute("virtual_node_id", $nodeid);
	$tmp->setAttribute("virtual_interface_id", $ifaceid);
	if (exists($ifaceref->{'tunnel_ip'})) {
	    $tmp->setAttribute("tunnel_ip", $ifaceref->{'tunnel_ip'});
	}
    }
    return $rspeclink;
}

sub ConvertSFAtoPG($$$)
{
    my ($rspec, $type, $manager_urn) = @_;

    # Parse if a string.
    if (! ref($rspec)) {
	$rspec = GeniXML::Parse($rspec);
	if (!defined($rspec)) {
	    print STDERR "*** ConvertRspec: Cannot parse rspec\n";
	    return undef;
	}
    }
    my $doc  = XML::LibXML::Document->new();
    my $root = $doc->createElement("rspec");
    my ($authority,undef,$which) = GeniHRN::Parse($manager_urn);

    $root->setAttribute("type", "advertisement");
    $root->setAttribute("xmlns",
			'http://www.protogeni.net/resources/rspec/0.2');
    $root->setAttribute("xmlns:xsi",
			"http://www.w3.org/2001/XMLSchema-instance");
    $root->setAttribute("xsi:schemaLocation",
		"http://www.protogeni.net/resources/rspec/0.2 ".
		"http://www.protogeni.net/resources/rspec/0.2/ad.xsd");
    $doc->setDocumentElement($root);

    my %names = ();

    foreach my $net (GeniXML::FindNodes("network",
					 $rspec)->get_nodelist()) {
	my $netid = GeniXML::GetText("name", $net);
	foreach my $site (GeniXML::FindNodes("site",
					     $net)->get_nodelist()) {
	    my $siteid = GeniXML::GetText("id", $site);
	    foreach my $node (GeniXML::FindNodes("node",
						 $site)->get_nodelist()) {
		# plc uses the qualified hostname in the URN.
		my $hostname  = GeniXML::GetText("hostname", $node);
		my $id        = GeniXML::GetText("id", $node);
		my $urn       = GeniXML::GetText("urn", $node);
		my $name      = GeniXML::GetText("name", $site);

		my $rspecnode = addChildToRspec($doc, $root, 'node');
		$rspecnode->setAttribute('component_manager_urn', $manager_urn);
		$rspecnode->setAttribute('component_manager_uuid',$manager_urn);
		$rspecnode->setAttribute('component_uuid', $urn);
		$rspecnode->setAttribute('component_urn', $urn);
		$rspecnode->setAttribute('component_name', "$id:$name");

		if ($type eq "ad") {
		    my $tmp = addChildToRspec($doc, $rspecnode, 'node_type');
		    $tmp->setAttribute("type_name",  "pc");
		    $tmp->setAttribute("type_slots", "1");

		    $tmp = addChildToRspec($doc, $rspecnode, 'available');
		    $tmp->appendText("true");
		    $tmp = addChildToRspec($doc, $rspecnode, 'exclusive');
		    $tmp->appendText("true");
		}
	    }
	}
    }
    return $root;
}

sub ConvertReqPGtoSFA($$)
{
    my ($rspec) = @_;

    # Parse if a string.
    if (! ref($rspec)) {
	$rspec = GeniXML::Parse($rspec);
	if (!defined($rspec)) {
	    print STDERR "*** ConvertRspec: Cannot parse rspec\n";
	    return undef;
	}
    }
    my $doc  = XML::LibXML::Document->new();
    my $root = $doc->createElement("RSpec");

    $root->setAttribute("type", "SFA");
    $doc->setDocumentElement($root);

    my $network;
    my $request;
    if (1) {
	$network = addChildToRspec($doc, $root, 'network');
	$network->setAttribute("name", "plc");
    }
    else {
	$request = addChildToRspec($doc, $root, 'request');
	$request->setAttribute("name", "plc");
    }

    foreach my $ref (GeniXML::FindNodes("n:node",
					$rspec)->get_nodelist()) {
	my $urn    = GeniXML::GetText("component_urn", $ref);
	my $comname= GeniXML::GetText("component_name", $ref);
	my ($auth,$which,$hostname) = GeniHRN::Parse($urn);
	my ($netid,$siteid) = split(":", $auth);
	my ($id,$name) = split(":", $comname);

	if (1) {
	    my $sitenode = addChildToRspec($doc, $network, 'site');
	    $sitenode->setAttribute("id", $siteid);

	    my $namenode = addChildToRspec($doc, $sitenode, 'name');
	    $namenode->appendText("$name");
	    
	    my $nodenode = addChildToRspec($doc, $sitenode, 'node');
	    $nodenode->setAttribute("id", $id);

	    my $tmp = addChildToRspec($doc, $nodenode, 'hostname');
	    $tmp->appendText("$hostname");
	    
	    $tmp = addChildToRspec($doc, $nodenode, 'urn');
	    $tmp->appendText("$urn");
	    addChildToRspec($doc, $nodenode, 'sliver');
	}
	else {
	    my $sliver = addChildToRspec($doc, $request, 'sliver');
	    $sliver->setAttribute("nodeid", $id);
	}
    }
    return $root;
}

1;
