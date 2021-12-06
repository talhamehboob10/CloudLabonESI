#!/usr/bin/perl -wT
#
# Copyright (c) 2013 University of Utah and the Flux Group.
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
# IP Address Range buddy allocator, a la memory management.
#
package IPBuddyAlloc;

use strict;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw ( );

use English;
use Tree::Binary;
use Net::IP;

# Global vars
my $debug    = 0;

# Prototypes
sub setSpace($$);
sub embedAddressRange($$);
sub requestAddressRange($$);
sub printTree($);
sub getRanges($);
sub _findFree($$$);

#
# Constructor takes the base address space (e.g. x.x.x.x/y) as a parameter.
#
sub new($$) {
    my ($class, $addr) = @_;
    my $self = {};

    my $ip = Net::IP->new($addr);
    if (!defined($ip)) {
	die Net::IP::Error();
    }

    $self->{'ROOT'} = Tree::Binary->new("*");
    $self->{'BASE_IPOBJ'} = $ip;

    bless($self,$class);
    return $self;
}

# Accessors
sub getobj($) { my $self = shift; return $self->{'BASE_IPOBJ'} }
sub getip($) { my $self = shift; return $self->getobj->ip() }
sub getprefix($) { my $self = shift; return $self->getobj()->prefixlen() }
sub getroot($) { my $self = shift; return $self->{'ROOT'} }

# Turn debugging on/off
sub setDebug($$) {
    my ($self,$dbg) = @_;

    $debug = defined($dbg) && $dbg ? $dbg : 0;
}

#
# Set the base IP space in which addresses will be embedded and
# requested.
#
sub setSpace($$) {
    my ($self, $addr) = @_;

    my $ip = Net::IP->new($addr);
    if (!defined($ip)) {
	die Net::IP::Error();
    }

    $self->{'BASE_IPOBJ'} = $ip;

    return 0;
}

#
# Embed an existing IP range reservation into the binary tree.  Create
# nodes as needed to represent it down to the depth of its prefix.
# 
sub embedAddressRange($$) {
    my ($self, $addr) = @_;

    my $bobj = $self->getobj();
    my $inobj = Net::IP->new($addr);
    if (!defined($inobj)) {
	die Net::IP::Error();
    }

    # Check that the incoming address range is inside the base range.
    if ($bobj->overlaps($inobj) != $IP_B_IN_A_OVERLAP) {
	die "range to embed (" . $inobj->prefix() .
	    ") must belong to base range: " . $bobj->prefix();
    }

    # Blow up bits representing input IP address into an array for
    # embedding in the binary tree.  Zap the leading bits corresponding
    # to the base range prefix.
    my $ibits   = $inobj->binip();
    my @ibitarr = split(//, $ibits);
    splice(@ibitarr, 0, $bobj->prefixlen());

    print "Inserting address: ". $inobj->prefix() ."\n".
	"bits: @ibitarr\n" if $debug;

    # Set initial depth value to base range address mask depth (prefix)
    # so that we skip over the common prefix bits.
    my $curdepth = $bobj->prefixlen();
    # Loop through the bits in the address, creating corresponding nodes in
    # the binary tree (as needed) and looking for collisions.
    my $tptr = $self->getroot();  # start embedding at the root, obviously!
    foreach my $bit (@ibitarr) {
	$curdepth++;
	# Are we at terminal depth for the input range?
	my $term = $inobj->prefixlen() == $curdepth ? 1 : 0;
	# Check bit, and go down correct path
	if ($bit) {
	    # Bit is a '1' - go right.
	    # First check to see if there is already a child node.
	    if ($tptr->hasRight()) {
		print "Visiting bit: $bit\n".
		    "Depth: $curdepth\n" if $debug > 1;
		# There is a child node.  Grab it.
		$tptr = $tptr->getRight();
		# Check to see if the child node conflicts.
		if ($term || $tptr->getNodeValue()->{'term'} == 1) {
		    die "found conflicting node while embedding!";
		}
	    } else {
		# No value exists yet at this location.
		$tptr->setRight(Tree::Binary->new({"value" => 1,
						   "term"  => $term}));
		$tptr = $tptr->getRight();
		print "Set bit: $bit\n".
		    "Depth: $curdepth\n" if $debug > 1;
		last if $term; # Bail if we are at prefix length depth.
	    }
	} else {
	    # Bit is a '0' - go left.
	    # First check to see if there is already a child node.
	    if ($tptr->hasLeft()) {
		print "Visiting bit: $bit\n".
		    "Depth: $curdepth\n" if $debug > 1;
		# There is a child node.  Grab it.
		$tptr = $tptr->getLeft();
		# Check to see if the child node conflicts.
		if ($term || $tptr->getNodeValue()->{'term'} == 1) {
		    die "found conflicting node while embedding!";
		}
	    } else {
		# No value exists yet at this location.
		$tptr->setLeft(Tree::Binary->new({"value" => 0,
						  "term"  => $term}));
		$tptr = $tptr->getLeft();
		print "Set bit: $bit\n".
		    "Depth: $curdepth\n" if $debug > 1;
		last if $term; # Bail if we are at prefix length depth.
	    }
	}
    }
    print "\n" if $debug;
    return 0;
}

#
# Top-level interface to ask for a free address range of the specified size
# (prefix length).  Returns the base address and embeds it in the tree,
# effectively marking it as allocated.
#
sub requestAddressRange($$) {
    my ($self, $prefix) = @_;

    my $bobj = $self->getobj();

    print "Looking for address range with prefix: $prefix\n" if $debug;

    my $reqdepth = $prefix - $bobj->prefixlen();
    # Can we fulfill the request?
    if ($reqdepth <= 0) {
	die "Prefix is too big for the base range.\n".
	    "Requested: $prefix\t Base Range: ". $bobj->prefix();
    }

    # Search the binary tree for a free address range.
    my $addrn = $self->_findFree($self->getroot(), $reqdepth);

    # No address range found - report failure.
    if (!defined($addrn)) {
	return undef;
    }

    # Free address range found!
    my @addrbits = ();
    # Walk backwards through the tree from the leaf, collecting up the
    # bits that make up this address.
    while (!$addrn->isRoot()) {
	unshift(@addrbits, $addrn->getNodeValue()->{'value'});
	$addrn = $addrn->getParent();
    }
    print "address bits found: @addrbits\n". 
	"length: " . scalar(@addrbits) . "\n" if $debug;
    # Put humpty dumpty back together and return.
    my $hbits =
	"0" x $bobj->prefixlen() .  # base range prefix bits.
	join("", @addrbits) .       # unique bits stored in binary tree.
	"0" x (length($bobj->binip()) - $prefix); # host address bits.
    my $hobj = Net::IP->new(Net::IP::ip_bintoip($hbits, 
						$bobj->version()));
    return $hobj->binadd($bobj)->ip();
}

# Helper method.
# Traverse the binary tree looking for an empty slot at the correct depth.
# Create nodes/branches as necesary to get to the requested depth.  This
# procedure walks down the "right side" of the tree, going left only when
# it must.
#
# $self - Object reference for this class 
# $cn - The "current" Tree::Binary node object in the recursive traversal.
# $reqdepth - The requested depth.  This should be the input prefix size with 
#             the base range prefix length subtracted.
#
sub _findFree($$$) {
    my ($self, $cn, $reqdepth) = @_;

    # Did we hit a terminal?  Go back if so!  Skip the tree's root.
    if (!$cn->isRoot() && $cn->getNodeValue()->{'term'} == 1) {
	return undef;
    }

    # Are we just above the requested depth (prefix length)?  If there
    # is a free slot underneath, we'll use/return it!
    if ($cn->getDepth() == $reqdepth-1) {
	if (!$cn->hasRight()) {
	    $cn->setRight(Tree::Binary->new({"value" => 1, 
					     "term"  => 1}));
	    return $cn->getRight();
	} elsif (!$cn->hasLeft()) {
	    $cn->setLeft(Tree::Binary->new({"value" => 0, 
					    "term"  => 1}));
	    return $cn->getLeft();
	} else {
	    # No free slot - dead end.
	    return undef;
	}
    }

    # Not at the terminal depth yet, so keep walking down (keeping
    # right), creating nodes as necessary.
    if (!$cn->hasRight()) {
	$cn->setRight(Tree::Binary->new({"value" => 1, 
					 "term"  => 0}));
    }
    my $rval = $self->_findFree($cn->getRight(), $reqdepth);
    if (!$rval) {
	# Nothing to the right, go left...
	if (!$cn->hasLeft()) {
	    $cn->setLeft(Tree::Binary->new({"value" => 0, 
					    "term"  => 0}));
	}
	$rval = $self->_findFree($cn->getLeft(), $reqdepth);
    }
    return $rval;
}

# print out a traversal of the tree using spaces to demarc levels.
sub printTree($) {
    my $self = shift;

    my $cn = $self->getroot();

    $cn->traverse(sub {
	my ($_tree) = @_;
	return if $_tree->isRoot();
	my $val = $_tree->getNodeValue()->{'value'};
	my $term = $_tree->getNodeValue()->{'term'} ? '*' : "";
	print " " x $_tree->getDepth() . "${val}${term}\n";
    });
}

# print out all ranges embedded in the tree.
sub getRanges($) {
    my $self = shift;

    my $cn = $self->getroot();
    my $bobj = $self->getobj();
    my $pflen = $bobj->prefixlen();
    my $bprebits = substr($bobj->binip(), 0, $pflen);
    my $postlen = length($bobj->binip()) - $pflen;
    my @addr = ();
    my @results = ();

    $cn->traverse(sub {
	my ($_tree) = @_;
	my $depth = $_tree->getDepth();
	return if $_tree->isRoot();
	splice(@addr, $depth-1);
	push @addr, $_tree->getNodeValue()->{'value'};
	if ($_tree->isLeaf()) {
	    my $hbits = "0" x ($postlen - $depth);
	    my $ipstr = 
		Net::IP::ip_bintoip($bprebits . join("", @addr) . $hbits,
				    $bobj->version());
	    push @results, "$ipstr/" . ($depth + $pflen);
	}
    });

    return @results;
}

#
# Destroy the object.  Must explicitly call DESTROY on the underlying
# Tree::Binary object.
#
sub DESTROY($) {
    my $self = shift;

    if ($self->{'ROOT'}) {
	$self->{'ROOT'}->DESTROY();
    }
    $self->{'ROOT'} = undef;
    $self->{'BASE_IPOBJ'} = undef;
}

# Required by perl
1;
