#!/usr/bin/perl -wT
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
# Osload library. Basically the backend to the osload script, but also used
# where we need finer control of loading of nodes.
#
package libosload;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( osload osload_wait osload_setupswapinfo );

# Must come after package declaration!
use libtestbed; # for TBGenSecretKey();
use libdb;
use libreboot;
use libtblog_simple;
use Node;
use NodeType;
use OSImage;
use User;
use EmulabConstants;
use English;
use event;
use Data::Dumper;
use File::stat;
use IO::Handle;

# Configure variables
my $TB		= "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $TESTMODE    = 0;
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $ELABINELAB  = 0;
my $PROJROOT    = "/proj";
my $WITHPROVENANCE= 1;
my $WITHDELTAS	= 0;
my $IMAGEINFO	= "$TB/sbin/imageinfo";

# Max number of retries (per node) before its deemed fatal. This allows
# for the occasional pxeboot failure.
my $MAXRETRIES  = 1;

# Hack constant factor (slop) to add to the max reload wait time for any node
# This is set based on testbed-wide factors (like multicast being dog slow!)
my $TBLOADWAIT  = (10 * 60);

my $osselect	    = "$TB/bin/os_select";
my $TBUISP	    = "$TB/bin/tbuisp";
my $TBADB           = "$TB/bin/tbadb";

# Locals
my $debug           = 0;
my %children        = ();	# Child pids in when asyncmode=1
my $remote_mult     = 5;        # Wait lots longer for remote nodes!

sub osload ($$) {
    my ($args, $result) = @_;

    # These come in from the caller.
    my @imageids;
    my @reqimages;
    my $waitmode    = 1;
    my $usecurrent  = 0;
    my @nodes       = ();
    my $noreboot    = 0;
    my $asyncmode   = 0;
    my $zerofree    = 0;
    my $prepare     = 0; # Now a level (0,1,2)
    my $swapinfo    = 0;
    my %nodeflags   = ();

    # Reset
    $debug          = 0;
    %children       = ();

    # Locals
    my %retries	    = ();
    my $failures    = 0;
    my $usedefault  = 1;
    my $mereuser    = 0;
    my $this_user;

    if (!defined($args->{'nodelist'})) {
	tberror "Must supply a node list!"; # INTERNAL
	return -1;
    }
    @nodes = sort(@{ $args->{'nodelist'} });
    
    if (defined($args->{'waitmode'})) {
	$waitmode = $args->{'waitmode'};
    }
    if (defined($args->{'noreboot'})) {
	$noreboot = $args->{'noreboot'};
    }
    if (defined($args->{'debug'})) {
	$debug = $args->{'debug'};
    }
    if (defined($args->{'usecurrent'}) && $args->{'usecurrent'}) {
	$usecurrent = 1;
	$usedefault = 0;
    }
    if (defined($args->{'image'})) {
	@reqimages = split(/,/, $args->{'image'});
	$usedefault = $usecurrent = 0;
    }
    elsif (defined($args->{'images'})) {
	@reqimages = @{$args->{'images'}};
	$usedefault = $usecurrent = 0;
    }
    elsif (defined($args->{'imageids'})) {
	@imageids = @{$args->{'imageids'}};
	$usedefault = $usecurrent = 0;
    }
    elsif (defined($args->{'imageid'})) {
	@imageids = split(/,/, $args->{'imageid'});
	$usedefault = $usecurrent = 0;
    }
    if (defined($args->{'asyncmode'})) {
	$asyncmode = $args->{'asyncmode'};
    }
    if (defined($args->{'zerofree'})) {
	$zerofree = $args->{'zerofree'};
    }
    if (defined($args->{'prepare'})) {
	$prepare = $args->{'prepare'};
    }
    if (defined($args->{'swapinfo'})) {
	$swapinfo = $args->{'swapinfo'};
    }
    if (defined($args->{'nodeflags'})) {
	%nodeflags = %{$args->{'nodeflags'}};
    }

    #
    # Figure out who called us. Root and admin types can do whatever they
    # want. Normal users can only change nodes in experiments in their
    # own projects.
    #
    if ($UID) {
	$this_user = User->ThisUser();
	return -1
	    if (!defined($this_user));

	if (!$this_user->IsAdmin()) {
	    $mereuser = 1;

	    if (! TBNodeAccessCheck($UID, TB_NODEACCESS_LOADIMAGE, @nodes)) {
		tberror("Not enough permission to load images on one or ".
			"more nodes!");
		return -1;
	    }
	}
    }

    if (@imageids) {
	foreach my $imageid (@imageids) {
	    my $image = OSImage->Lookup($imageid);
	    if (!defined($image)) {
		tberror("No such imageid $imageid");
		return -1;
	    }
	    push(@reqimages, $image);
	}
    }

    foreach my $i (0 .. $#reqimages) {
	my $image = $reqimages[$i];

	#
	# Check permission to use the imageid.
	# 
	if ($mereuser &&
	    ! $image->AccessCheck($this_user, TB_IMAGEID_READINFO)) {
	    tberror "You do not have permission to load $image";
	    return -1;
	}

	#
	# If there's a maxiumum number of concurrent loads listed for the image,
	# check to see if we'll go over the limit, by checking to see how many
	# other nodes are currently booting thie image's default_osid. This is
	# NOT intended to be strong enforcement of license restrictions, just a
	# way to catch mistakes.
	#
	if (!TBImageLoadMaxOkay($image->imageid(), scalar(@nodes), @nodes)) {
	    tberror 
	    "Would exceed maxiumum concurrent instances ".
		"limitation for $image";
	    return -1;
	}
    }

    #
    # This is somewhat hackish. To promote parallelism during os_setup, we
    # want to fork off the osload from the parent so it can do other things.
    # The problem is how to return status via the results vector. Well,
    # lets do it with some simple IPC. Since the results vector is simply
    # a hash of node name to an integer value, its easy to pass that back.
    #
    # We return the pid to the caller, which it can wait on either directly
    # or by calling back into this library if it wants to actually get the
    # results from the child!
    # 
    if ($asyncmode) {
	#
	# Create a pipe to read back results from the child we will create.
	#
	my $PARENT_READER = new IO::Handle; # Need a new handle for each child
	if (! pipe($PARENT_READER, CHILD_WRITER)) {
	    tberror "creating pipe: $!";
	    return -1;
	}
	CHILD_WRITER->autoflush(1);

	if (my $childpid = fork()) {
	    close(CHILD_WRITER);
	    $children{$childpid} = [ $PARENT_READER, $result ];
	    return $childpid;
	}
	#
	# Child keeps going. 
	#
	close($PARENT_READER);
	TBdbfork();
    }

    # This will store information about each node, so that if we have to try
    # again later, we'll have it all.
    my %reload_info;

    # Loop for each node.
    foreach my $node (@nodes) {
	my @images;
	# All nodes start out as being successful; altered later as needed.
	$result->{$node} = 0;

	my $nodeobject = Node->Lookup($node);
	if (!defined($nodeobject)) {
	    tberror "$node: Could not map to object!";
	    goto failednode;
	}

	# Check to see if the node is tainted.  If so, then the disk
	# needs to be cleaned up (zeroed).  If there was an explicit request
	# to zero all node disks, then capture that here too.
	my $zeronode = 0;
	if ($nodeobject->IsTainted()) {
	    if ($nodeobject->TaintIs(TB_TAINTSTATE_MUSTRELOAD())) {
		$zeronode = $zerofree;
	    }
	    else {
		$zeronode = 2;
	    }
	}
	elsif ($zerofree) {
	    $zeronode = $zerofree;
	}
	
	# Get default imageid for this node.
	# NOTE that virtnodes don't have default imageids -- they are only 
	# loaded (and thus arrive here) if the user specifically set a loadable
	# subOS for the node.
	if ($usedefault) {
	    if ($nodeobject->isvirtnode()) {
		tberror("Virtnodes do not have default images!");
		goto failednode;
	    }
	    else {
		my $default_imageid = $nodeobject->default_imageid();
		if (! defined($default_imageid)) {
		    tberror "$node: No default imageid defined!";
		    goto failednode;
		}
		my @default_imageids = split(/,/, $default_imageid);
		my @default_images;
		foreach my $default_imageid (@default_imageids) {
		    my $default_image = OSImage->Lookup($default_imageid);
		    if (!defined($default_image)) {
			tberror("Could not find $default_imageid in the DB!");
			goto failednode;
		    }
		    push @default_images, $default_image;
		}
		# prepare is now a level (0,1,2). Force if not set. 
		$prepare  = 1 if (!$prepare); 
		@images   = @default_images;
	    }
	}
	elsif ($usecurrent) {
	    my $def_boot_osid  = $nodeobject->def_boot_osid();
	    my $def_boot_vers  = $nodeobject->def_boot_osid_vers();
	    my $osimage = OSImage->Lookup($def_boot_osid, $def_boot_vers);

	    if (! defined($osimage)) {
		tberror("Could not find OS $def_boot_osid in the DB!");
		goto failednode;
	    }
	    my $best_image = $osimage->MapToImage($nodeobject->type());
	    if (!defined($best_image)) {
		tberror("Could not map $osimage to an image for $node!");
		goto failednode;
	    }
	    @images   = ($best_image);
	}
	else {
	    foreach my $image (@reqimages) {
		if ($image->isImageAlias()) {
		    my $tmp = $image->MapToImage($nodeobject->type());
		    if (!defined($tmp)) {
			tberror("Could not map $image to an image for $node!");
			goto failednode;
		    }
		    $image = $tmp;
		}
		push(@images, $image);
	    }
	}
	
	my @imageidxs = (0 .. $#images);
	my $defosid;
	my $defvers;
	my $maxwait = 0;
	my @access_keys;

	#
	# Most of the DB work related to images is determining what
	# disk partitions should be clobbered and which should survive
	# the loading of all the images. To make this more efficient,
	# we loop through the images updating our parititions hash
	# and then just do one DB partitions table access at the end.
	#
	my %partitions = ();
	my $curmbrvers = 0;

	#
	# XXX assumes a DOS MBR, but this is ingrained in the DB schema
	# as well (i.e., the images.part[1234]_osid fields).
	#
	my $MINPART = 1;
	my $MAXPART = 4;

	#
	# If doing a prepare, all current partition info is going to
	# be invalidated, so we start with an empty hash. Otherwise
	# we read the current DB values to initialize it.
	#
	my $nodeprepare = $prepare;
	if (defined($nodeflags{$node}) 
	    && defined($nodeflags{$node}{'prepare'})) {
	    $nodeprepare = $nodeflags{$node}{'prepare'};
	}
	if (!$nodeprepare) {
	    my $dbresult =
		DBQueryWarn("select p.*,v.mbr_version ".
			    " from `partitions` as p,image_versions as v ".
			    " where p.imageid=v.imageid and ".
			    "       p.imageid_version=v.version and ".
			    "       v.deleted is null ".
			    "  and p.node_id='$node'");
	    if (!$dbresult) {
		tberror("$node: Could not read partition table!");
		goto failednode;
	    }
	    while (my $href = $dbresult->fetchrow_hashref()) {
		if (!$curmbrvers) {
		    $curmbrvers = $href->{'mbr_version'};
		} elsif ($href->{'mbr_version'} &&
			 $href->{'mbr_version'} != $curmbrvers) {
		    tbwarn("$node: inconsistent MBR version info, ".
			   "invalidating all partitions!");
		    %partitions = ();
		    last;
		}
		$partitions{$href->{'partition'}} = $href;
	    }
	}

	#
	# For each image, update the necessary node state.
	#
	foreach my $i (@imageidxs) {
	    my $image = $images[$i];
	
	    print STDERR "osload: Using $image for $node\n"
		if $debug;

	    #
	    # We can have both a full image and/or a delta image. We
	    # always prefer the full image if we have it.
	    #
	    if (! ($image->HaveFullImage() || $image->HaveDeltaImage())) {
		#
		# This should be an error, but until we run imagevalidate
		# over all images, we want to do it here.
		#
		if (GetImageSize($image, $node)) {
		    tberror "$node: no full or delta image file!";
		    goto failednode;
		}
	    }
	    my $isfull     = $image->HaveFullImage();
	    my $loadpart   = $image->loadpart();
	    my $loadlen    = $image->loadlength();
	    my $imagepid   = $image->pid();
	    my $imagesize  = ($isfull ? $image->size() : $image->deltasize());
	    #
	    # Compute a maxwait time based on the image size plus a constant
	    # factor for the reboot cycle.  This is used later in
	    # WaitTillReloadDone().  Arguably, this should be part of the
	    # image DB state, so we store it in the imageinfo array too.
	    #
	    # size may be > 2^31, shift is unsigned
	    #
	    my $chunks = $imagesize >> 20;
	    $maxwait += int((($chunks / 100.0) * 65)) + $TBLOADWAIT;
    
	    $access_keys[$i] = $image->access_key();

	    #
	    # Set the default boot OSID.
	    # Note: when loading multiple images, use the last image.
	    #
	    if ($i == $imageidxs[-1]) {
		print "osload ($node): Loading $image\n" if $i > 0;
		print "osload ($node): Changing default OS to $image\n";
		if (!$TESTMODE) {
		    if ($nodeobject->OSSelect($image, "def_boot_osid", 0)) {
			tberror "$node: os_select $image failed!";
			goto failednode;
		    }
		}
	    } else {
		print "osload ($node): Loading $image\n";
	    }
	    
	    #
	    # Assign partition table entries for each partition in the image
	    # that has an OSID associated with it.
	    #
	    # This is complicated by the fact that an image that covers only
	    # part of the slices should only change the partition table entries
	    # for the subset of slices that are written to disk...
	    #
	    # ...UNLESS, the new image requires a different version of the MBR
	    # in which case we must invalidate all existing partitions since
	    # the partition boundaries may have changed...
	    #
	    # ...OR, the prepare flag has been specified, which will tell the
	    # client to invalidate all partition metadata on the disk so we
	    # might as well mark the partition as "empty".  In particular,
	    # this case is used by the reload_daemon when a node is between
	    # experiments.  In this case we need to invalidate all existing
	    # partition(s) to ensure that a user later on doesn't accidentally
	    # get some left over partition OS when they should have been
	    # loading a new instance. This case was handled earlier.
	    #
	    my $startpart = $loadpart == 0 ? $MINPART : $loadpart;
	    my $endpart   = $startpart + $loadlen;
	    
	    #
	    # If image MBR is incompatible with what is on the disk right
	    # now, invalidate all the existing partitions ("...UNLESS" above).
	    #
	    if (defined($image->mbr_version())) {
		if ($image->mbr_version() && $curmbrvers &&
		    $image->mbr_version() != $curmbrvers) {
		    %partitions = ();
		}
		$curmbrvers = $image->mbr_version();
	    }

	    #
	    # Now we loop through the image partitions and set/clear
	    # the existing partition info as appropriate.
	    #
	    # NOTE: We no longer do multi-os images ... but this loop
	    # is harmless. 
	    #
	    for (my $i = $startpart; $i < $endpart; $i++) {
		my $partname = "part${i}_osid";
		my $partvers = "part${i}_vers";

		my $osid = $image->field($partname);
		my $vers = $image->field($partvers);
		if (defined($osid)) {
		    my $osimage = OSImage->Lookup($osid, $vers);
		    if (!defined($osimage)) {
			tberror "No OSImage found for $osid!\n";
			goto failednode;
		    }
		    my %part = (
			'node_id' => $node,
			'partition' => $i,
			'osid' => $osid,
			'osid_vers' => $osimage->version(),
			'imageid' => $osimage->imageid(),
			'imageid_version' => $osimage->version(),
			'imagepid' => $imagepid,
			'mbr_version' => $curmbrvers
		    );
		    $partitions{$i} = \%part;
		}
		else {
		    delete $partitions{$i};
		}
	    }
	}

	#
	# Now that we have processed all images, update the actual DB
	# partitions table entries for this node.
	#
	for (my $i = $MINPART; $i <= $MAXPART; $i++) {
	    my $dbresult;

	    if (exists($partitions{$i})) {
		my $href = $partitions{$i};
		my $osid = $href->{'osid'};
		my $osvers = $href->{'osid_vers'};
		my $imid = $href->{'imageid'};
		my $imvers = $href->{'imageid_version'};
		my $impid = $href->{'imagepid'};
		$dbresult =
		    DBQueryWarn("replace into `partitions` ".
				"(node_id,`partition`,osid,imageid,imagepid,".
				" osid_vers,imageid_version) ".
				"values ".
				"('$node','$i','$osid','$imid','$impid',".
				" '$osvers','$imvers')");
	    } else {
		$dbresult =
		    DBQueryWarn("delete from `partitions` ".
				"where node_id='$node' and `partition`='$i'");
	    }
	    if (!$dbresult) {
		tberror "$node: Could not update partitions table";
		goto failednode;
	    }
	}

	#
	# Change the node's default command line as necessary.
	# XXX we only do this for delay nodes.
	#
	if ($defosid && $nodeobject->erole() eq "delaynode") {
	    my $osimage = OSImage->Lookup($defosid, $defvers);
	    if ($osimage) {
		my ($ocmdline,$ncmdline);
		$ocmdline = $nodeobject->def_boot_cmd_line();
		$ocmdline = ""
		    if (!defined($ocmdline));
		$osimage->OSBootCmd("delay", \$ncmdline);
		$ncmdline = ""
		    if (!defined($ncmdline));
		if ($ocmdline ne $ncmdline) {
		    print "osload ($node): Changing cmdline: ".
			  "'$ocmdline' -> '$ncmdline'\n";
		    if (!DBQueryWarn("update nodes set ".
				     "def_boot_cmd_line='$ncmdline' ".
				     "where node_id='$node'")) {
			tbwarn "$node: Could not update command line";
		    }
		}
	    }
	}

	#
	# Setup swapinfo now after partitions have initialized but before
	# we setup the one-shot frisbee load.
	#
	if ($swapinfo) {
	    print "osload ($node): Updating image signature.\n";
	    osload_setupswapinfo(undef, undef, $node);
	}

	#
	# For each image to be loaded, we check and see if it is a delta
	# image. If so, we must follow its parent link backward til we
	# find the latest full version of the image, then load those in
	# reverse order.
	#
	my @allimages = ();
	if ($WITHPROVENANCE && $WITHDELTAS) {
	    my $founddelta = 0;
	    foreach my $image (@images) {
		if (!$image->HaveFullImage()) {
		    my $pimage = $image;
		    my @ilist = ();
		    do {
			# if it is a delta image, there had better be a parent!
			$pimage = $pimage->Parent();
			if (!$pimage) {
			    tberror "$node: delta image $image has no parent!";
			    goto failednode;
			}
			push(@ilist, $pimage);
		    } while (!$pimage->HaveFullImage());
		    push @allimages, reverse(@ilist);
		    $founddelta = 1;
		}
		push(@allimages, $image);
	    }
	    #
	    # If we added any images to the list, we need to recompute
	    # the access keys.
	    #
	    if ($founddelta) {
		@access_keys = ();
		foreach my $image (@allimages) {
		    push(@access_keys, $image->access_key());
		}
	    }
	} else {
	    @allimages = @images;
	}
	my @allimageidxs = (0 .. $#allimages);

	#
	# Determine which mode to use for reloading this node (note: this may
	# become an entry in node_capabilities or something like that in the
	# future - that would be cleaner)
	#
	my $type  = $nodeobject->type();
	my $class = $nodeobject->class();
	my $isremote = $nodeobject->isremotenode();
	my $isvirtnode = $nodeobject->isvirtnode();
	my $reload_mode;
	my $reload_func;
	my $reboot_required;
	my $wait_required = 1;
	if ($class eq "mote") {
	    $reload_mode = "UISP";
	    $reload_func = \&SetupReloadUISP;
	    $reboot_required = 0; # We don't reboot motes to reload them
	    $zeronode = 0; # and we don't zero "the disk"
	}
	elsif ($class eq "ue") {
	    $reload_mode = "UE";
	    $reload_func = \&SetupReloadUE;
	    $reboot_required = 0; # We don't reboot UEs to reload them
	    $zeronode = 0; # and we don't zero "the disk"
	} else {
	    $reload_mode = "Frisbee";
	    $reload_func = \&SetupReloadFrisbee;
	    $reboot_required = !$noreboot; # Reboot unless $noreboot flag set

	    if (defined($nodeflags{$node}) 
		&& defined($nodeflags{$node}{'noreboot'})) {
		$reboot_required = !$nodeflags{$node}{'noreboot'};
	    }

	    if (defined($nodeflags{$node}) 
		&& defined($nodeflags{$node}{'nowait'})) {
		$wait_required = !$nodeflags{$node}{'nowait'};
	    }

	    foreach my $i (@allimageidxs) {
		# This is passed along so that remote node can request the file.
		# Make sure the image object has an access key defined.
		if (($nodeobject->isremotenode() || $nodeobject->OnRemoteNode())
		    && !defined($access_keys[$i])) {
		    $access_keys[$i] = TBGenSecretKey();
		    
		    if ($allimages[$i]->Update({'access_key' => $access_keys[$i]}) != 0) {
			tberror "$node: Could not initialize image access key";
			goto failednode;
		    }
		}
	    }
	}

	#
	# Remember this stuff so that if we have to retry this node again
	# later, we'll know how to handle it
	#
	$reload_info{$node} = {
	    'nodeobj'  => $nodeobject,
	    'node'     => $node,
	    'mode'     => $reload_mode,
	    'func'     => $reload_func,
	    'images'   => \@allimages,
	    'osid'     => $defosid,
	    'osid_vers'=> $defvers,
	    'reboot'   => $reboot_required,
	    'wait'     => $wait_required,
	    'zerofree' => $zeronode,
	    'prepare'  => $nodeprepare,
	    'maxwait'  => $maxwait,
	    'isremote' => $isremote,
	    'isvirtnode' => $isvirtnode
	};

	print "Setting up reload for $node (mode: $reload_mode)\n";

	if (!$TESTMODE) {
	    if (&$reload_func($reload_info{$node}) < 0) {
		tberror("$node: Could not set up reload. Skipping.");
		goto failednode;
	    }
	}
	next;
	
      failednode:
	$result->{$node} = -1;
	$failures++;
    }
    
    #
    # Remove any failed nodes from the list we are going to operate on.
    #
    my @temp = ();
    foreach my $node (@nodes) {
	push(@temp, $node)
	    if (! $result->{$node});
    }
    @nodes = @temp;

    TBDebugTimeStamp("osload: database setup done");

    # Exit if not doing an actual reload.
    if ($TESTMODE) {
	print "osload: Stopping in Testmode!\n";
	goto done;
    }

    if (! @nodes) {
	tbnotice "Stopping because of previous failures!";
	goto done;
    }

    # Fire off a mass reboot and quit if not in waitmode.
    if (! $waitmode) {
	my ($reboot_nodes, $noreboot_nodes)
	    = GetNodesRequiringReboot(\%reload_info, keys(%reload_info));
	if (@$reboot_nodes) {
	    print "osload: Rebooting nodes.\n";

	    my %reboot_args     = ();
	    my %reboot_failures = ();

	    $reboot_args{'debug'}    = $debug;
	    $reboot_args{'waitmode'} = 0;
	    $reboot_args{'nodelist'} = [ @$reboot_nodes ];

	    if (nodereboot(\%reboot_args, \%reboot_failures)) {
		foreach my $node (@$reboot_nodes) {
		    if ($reboot_failures{$node}) {
			$result->{$node} = $reboot_failures{$node};
			$failures++;
		    }
		}
	    }
	}
	goto done;
    }

    #
    # The retry vector is initialized to the number of retries we allow per
    # node, afterwhich its a fatal error.
    #
    foreach my $node (@nodes) {
	$retries{$node} = $MAXRETRIES;
    }

    #
    # Callback for our event handler. We use a "closure" so it can
    # reference the list of nodes that we are currently waiting on.
    #
    my $eventnodes = undef;
    my $handler = sub {
	my ($handle, $notification, undef) = @_;
    
	my $node_id = event_notification_get_objname($handle,$notification);
	my $event   = event_notification_get_eventtype($handle,$notification);

	return
	    if (!defined($eventnodes));

	$eventnodes->{'GOTONE'} = 1;
	if (exists($eventnodes->{$node_id})) {
	    my $et = time();
	    print "osload: eventhandler: $node_id => $event @ $et\n"
		if ($debug);
	    $eventnodes->{$node_id} = $et;
	}
    };
    my $evhandle = SetupEventHandler($handler);
    if (!defined($evhandle)) {
	tbnotice "Stopping because event registration failed!";
	foreach my $node (@nodes) {
	    $result->{$node} = -1;
	    $failures++;
	}
	goto done;
    }

    while (@nodes) {
	my ($reboot_nodes, $noreboot_nodes)
	    = GetNodesRequiringReboot(\%reload_info, @nodes);
	if (@$reboot_nodes) {
	    # Reboot them all.
	    print "osload: ".
		"Issuing reboot for @$reboot_nodes and then waiting ...\n";

	    # Prime the event handler above.
	    $eventnodes = {} if (!defined($eventnodes));
	    foreach my $node (@$reboot_nodes) {
		$eventnodes->{$node} = 0;
	    }
	    TBDebugTimeStamp("osload: event handler enabled");
	    
	    my %reboot_args     = ();
	    my %reboot_failures = ();

	    $reboot_args{'debug'}    = $debug;
	    $reboot_args{'waitmode'} = 0;
	    $reboot_args{'nodelist'} = [ @$reboot_nodes ];

	    if (nodereboot(\%reboot_args, \%reboot_failures)) {
		#
		# If we get any failures in the reboot, we want to
		# alter the list of nodes accordingly for the next phase.
		# 
		my @temp = ();
		
		foreach my $node (@$reboot_nodes) {
		    if ($reboot_failures{$node}) {
			$result->{$node} = $reboot_failures{$node};
			$failures++;
		    }
		    else {
			push(@temp, $node);
		    }
		}
		@nodes = (@temp,@$noreboot_nodes);
	    }
	}

	# Now wait for them.
	my $startwait   = time;
	my @failednodes = WaitTillReloadDone($startwait,
					     $waitmode,
					     \%reload_info, 
					     $eventnodes,
					     $evhandle,
					     @nodes);
				
	@nodes=();
    
	while (@failednodes) {
	    my $node = shift(@failednodes);

	    if ($retries{$node}) {
		tbnotice "$node: Trying again ...";

		my $reload_info = $reload_info{$node};

		# Possible race with reboot?
		if (&{$reload_info->{'func'}}($reload_info) < 0) {
		    tberror("$node: Could not set up reload. Skipping.");
		    $result->{$node} = -1;
		    $failures++;
		    next;
		}
		push(@nodes, $node);

		# Retry until count hits zero.
		$retries{$node} -= 1;
	    }
	    else {
		tberror ({sublevel => -1}, 
			 "$node failed to boot too many times. Skipping!");
		$result->{$node} = -1;
		$failures++;
	    }
	}
    }
  done:
    print "osload: Done! There were $failures failures.\n";

    #
    # Since we use this in long running daemons, be sure to release
    # the event system connection, or else we stack up lots of handles
    # and socket connections to the event server. 
    #
    event_unregister($evhandle)
	if (defined($evhandle));

    if ($asyncmode) {
	#
	# We are a child. Send back the results to the parent side
	# and *exit* with status instead of returning it.
	# 
	foreach my $node (keys(%{ $result })) {
	    my $status = $result->{$node};
	    
	    print CHILD_WRITER "$node,$status\n";
	}
	close(CHILD_WRITER);
	exit($failures);
    }
    return $failures;
}

sub DumpImageInfo($)
{
    my ($image) = @_;
    
    print STDERR
	"$image: loadpart=", $image->loadpart(),
	", loadlen=", $image->loadlength(),
	", imagepath=", $image->path(),
	", imagesize=", $image->size(),
	", defosid=", $image->default_osid(),
	", maxloadwait=", $image->_maxloadwait(), "\n"
	    if ($debug);

    return 1;
}

# Wait for a reload to finish by watching its state
sub WaitTillReloadDone($$$$$@)
{
    my ($startwait, $waitmode,
	$reload_info, $eventnodes, $evhandle, @nodes) = @_;
    my %done	= ();
    my $count   = @nodes;
    my @failed  = ();

    foreach my $node ( @nodes ) {
	if ($reload_info->{$node}{'wait'} == 1) {
	    $done{$node} = 0;
	}
	else {
	    $done{$node} = 1;
	    --$count;
	    print "osload ($node): not waiting for reload of $node.\n";
	}
    }

    print STDERR "Waiting for @nodes to finish reloading\n".`date`
	if ($count && $debug);

    # Start a counter going, relative to the time we rebooted the first
    # node.
    TBDebugTimeStamp("osload: starting reload-done wait");
    my $waittime  = 0;
    my $minutes   = 0;

    #
    # Should-be-parameters:
    #
    # REBOOTWAIT: time in minutes to make a transition after reboot
    # MAXEVENTS: max events to grab in any event_poll loop
    #
    my $REBOOTWAIT = 5;
    my $MAXEVENTS = 500;

    my $ecount = 1;
    while ($count > 0) {
	# Wait first to make sure reboot is done, and so that we don't
	# wait one more time after everyone is up.
	if ($ecount > 0) {
	    sleep(5)
	}
	my $ecount = $MAXEVENTS;
	do {
	    $eventnodes->{'GOTONE'} = 0;
	    event_poll($evhandle);
	} while ($eventnodes->{'GOTONE'} && --$ecount > 0);
	if ($ecount < $MAXEVENTS) {
	    print STDERR "got ", $MAXEVENTS-$ecount, " events\n"
		if ($debug);
	}
	foreach my $node (@nodes) {
	    if (! $done{$node}) {
		my $nodeobject = Node->Lookup($node);
		my $maxwait;

		#
		# If we have to zero fill free space, then the
		# wait time has to be proportional to the disk
		# size.  In other words, a really, really, really
		# long time.  Lets assume 20MB/sec to blast zeros,
		# so 50 seconds/GB.  What the heck, lets call it
		# 1GB/minute.  Did I mention how this would take
		# a really long time?
		#
		# Else, if we have a remote node, we wait another multiplier.
		#
		if ($reload_info->{$node}{'zerofree'}) {
		    my $disksize = $nodeobject->disksize();

		    $disksize = 20
			if (!$disksize);
		    $maxwait = ($disksize * 60);
		} elsif ($reload_info->{$node}{'isremote'}) {
		    $maxwait = $reload_info->{$node}{'maxwait'} * $remote_mult;
		} else {
		    $maxwait = $reload_info->{$node}{'maxwait'};
		}

		#
		# If it's a virtnode, we need to add a bunch of time based
		# on how long the parent might take.  This is a fool's errand,
		# given how synchronous our scripts are, so give it 8 mins 
		# for now.
		#
		if ($reload_info->{$node}{'isvirtnode'}) {
		    $maxwait += 8 * 60;
		}
		
		my $query_result =
		    DBQueryWarn("select * from current_reloads ".
				"where node_id='$node'");

		#
		# There is no point in quitting if this query fails. Just
		# try again in a little bit.
		# 
		if (!$query_result) {
		    tbwarn "$node: Query failed; waiting a bit.";
		    next;
		}

		#
		# We simply wait for stated to clear the current_reloads entry.
		#
		if (!$query_result->numrows) {
		    print STDERR "osload ($node): left reloading mode at ".`date`
			if ($debug);

		    $count--;
		    $done{$node} = 1;
		    next;
		}

		#
		# All of the eventstate stuff belongs in stated. Sheesh.
		#
		my $eventstate;
		if ($nodeobject->GetEventState(\$eventstate)) {
		    print STDERR "osload ($node): Could not get event state\n";
		}
	
		# Soon we will have stated's timeouts take care of
		# rebooting once or twice if we get stuck during
		# reloading.
		$waittime = time - $startwait;
		
		# If the node doesn't made a transition within $REBOOTWAIT
		# minutes of booting, we declare it stuck.
		my $isstuck = ($minutes > $REBOOTWAIT &&
			       exists($eventnodes->{$node}) &&
			       $eventnodes->{$node} == 0);

		if ($waittime > $maxwait ||
		    $eventstate eq TBDB_NODESTATE_TBFAILED() ||
		    $eventstate eq TBDB_NODESTATE_PXEFAILED() ||
		    $eventstate eq TBDB_NODESTATE_RELOADFAILED() ||
		    $isstuck) {

		    #
		    # If we are in reloading, then we obviously missed
		    # a state transition in our handler. Probably just
		    # need to increase $MAXEVENTS above.
		    #
		    if ($isstuck &&
			$eventstate eq TBDB_NODESTATE_RELOADING()) {
			tbnotice("missed state transition to RELOADING".
				 " for $node; faking it.");
			$eventnodes->{$node} = time();
			goto okay;
		    }

		    my $t = (int ($waittime / 60));
		    tbnotice "$node appears wedged; ".
			"it has been $t minutes since it was rebooted.";

		    if ($eventstate eq TBDB_NODESTATE_TBFAILED() ||
			$eventstate eq TBDB_NODESTATE_RELOADFAILED() ||
			$eventstate eq TBDB_NODESTATE_PXEFAILED()) {
			tbnotice("  $node is stuck in $eventstate.");
		    }
		    elsif ($eventstate eq TBDB_NODESTATE_RELOADING()) {
			tbnotice("  $node did not finish reloading.");
		    }
		    elsif ($isstuck) {
			tbnotice("  $node failed to make a state ".
				 "transition after $REBOOTWAIT minutes; ".
				 "stuck in $eventstate.");
		    }
		    TBNodeConsoleTail($node, *STDERR);

		    $count--;
		    $done{$node} = $waitmode;
		    push(@failed, $node);
		    next;
		}
	      okay:
		if (int($waittime / 60) > $minutes) {
		    $minutes = int($waittime / 60);
		    print STDERR "osload ($node): still waiting; ".
			"it has been $minutes minute(s)\n";
		}
	    }
	}
    }

    if ($waitmode > 1) {
	$startwait = time;
	foreach my $node (@nodes) {
	    print STDERR
		"osload ($node): waiting for node to finish booting\n";
	    if ($done{$node} < $waitmode) {
		my $actual_state;

		if (!TBNodeStateWait($node,
				     $startwait,
				     (60*6),
				     \$actual_state,
				     (TBDB_NODESTATE_TBFAILED,
				      TBDB_NODESTATE_RELOADFAILED,
				      TBDB_NODESTATE_PXEFAILED,
				      TBDB_NODESTATE_ISUP))) {
		    $done{$node} = $waitmode;
		} else {
		    push(@failed, $node);
		}
	    }
	}
    }

    return @failed;
}

# Setup a reload. 
sub SetupReloadFrisbee($)
{
    my $reload_info   = $_[0];
    my $nodeobject    = $reload_info->{'nodeobj'};
    my $node          = $reload_info->{'node'};
    my $images        = $reload_info->{'images'};
    my $zerofree      = $reload_info->{'zerofree'};
    my $prepare       = $reload_info->{'prepare'};
    my $isvirtnode    = $reload_info->{'isvirtnode'};
    my $osid          = TBNodeDiskloadOSID($node);

    #
    # Put it in the current_reloads table so that nodes can find out which
    # OS to load. See tmcd. 
    #
    $nodeobject->ClearCurrentReload();

    my $idx = 1;
    foreach my $image (@$images) {
	my $imageid = $image->imageid();
	my $version = $image->version();

	# only prepare on first image
	my $prepare0 = $idx == 1 && $prepare ? $prepare : 0;
	# only zero on full images
	my $zerofree0 = $image->HaveFullImage() ? $zerofree : 0;

	my $query_result = 
	    DBQueryWarn("insert into current_reloads ".
			"(node_id, idx, image_id, imageid_version,".
			" mustwipe, prepare) values ".
			"('$node', $idx, '$imageid', '$version',".
			" $zerofree0, $prepare0)");
	return -1
	    if (!$query_result);
	++$idx;
    }

    #
    # We used to invoke os_select here and it checks for MODIFYINFO permission
    # on the node. Since we have already checked for LOADIMAGE permission,
    # which requires the same user privilege, we do not need to check further.
    #
    my $osimage = OSImage->Lookup($osid);
    if (!defined($osimage) ||
	$nodeobject->OSSelect($osimage, "next_boot_osid", 0)) {
	tberror "os_select $osid failed!";
	return -1;
    }

    # Need to kick virtnodes so stated picks up the next_op_mode from os_select
    if ($isvirtnode) {
	$nodeobject->SetEventState(TBDB_NODESTATE_SHUTDOWN);
    }

    return 0;
}

#
# Setup a reload, using USIP (for motes), rather than Frisbee. Note that
# this differs from a Frisbee reload in one key way - it does the reload
# right here in this code, rather than setting up a reload for later.
#
sub SetupReloadUISP($)
{
    my $reload_info   = $_[0];
    my $node          = $reload_info->{'node'};
    my $imageid       = $reload_info->{'imageid'};
    my $osid          = $reload_info->{'osid'};

    #
    # Get the path to the image
    #
    my $query_result = DBQueryFatal("select path from images " .
	"where imageid='$imageid'");
    if ($query_result->num_rows() != 1) {
	tberror "Failed to get path for $imageid!";
	return -1;
    }
    my ($path) = $query_result->fetchrow();

    #
    # Tell stated that we're about to start reloading
    #
    TBSetNodeNextOpMode($node,TBDB_NODEOPMODE_RELOADMOTE);

    #
    # The mote goes 'down', then starts to reload
    #
    TBSetNodeEventState($node,TBDB_NODESTATE_SHUTDOWN);
    TBSetNodeEventState($node,TBDB_NODESTATE_RELOADING);

    #
    # Okay, just run tbuisp with that path
    #
    my $rv = system("$TBUISP upload $path $node");
    if ($rv) {
	tberror "$node: tbuisp failed";
	return -1;
    }

    #
    # Tell stated that we've finished reloading the node
    #
    TBSetNodeEventState($node,TBDB_NODESTATE_RELOADDONE);

    system("$osselect $osid $node");
    if ($?) {
	tberror "os_select $osid failed!";
	goto failednode;
    }

    #
    # 'Reboot' the node (from stated's perspective, anyway)
    # has been shutdown, so that the os_select will take effect
    #
    TBSetNodeEventState($node,TBDB_NODESTATE_SHUTDOWN);

    return 0;
}

#
# Setup a UE (mobile handset) reload via ADB rather than Frisbee. This
# calls a script on the UE's "console" server that then pulls across
# the image (if necessary) and loads it on the specified device.
#
sub SetupReloadUE($)
{
    my $reload_info   = $_[0];
    my $nodeobject    = $reload_info->{'nodeobj'};
    my $node          = $reload_info->{'node'};
    my $image         = (@{$reload_info->{'images'}})[0];

    #
    # Clear any pending reload entries.
    #
    $nodeobject->ClearCurrentReload();

    #
    # Get some image details for setting up the reload.
    #
    my $imgpid  = $image->pid();
    my $imgname = $image->imagename();
    my $imageid = $image->imageid();
    my $version = $image->version();

    my $query_result = 
	DBQueryWarn("insert into current_reloads ".
		    "(node_id, idx, image_id, imageid_version,".
		    " mustwipe, prepare) values ".
		    "('$node', 1, '$imageid', '$version',".
		    " 0, 0)");
    return -1
	if (!$query_result);

    #
    # Tell stated that we're about to start reloading
    #
    TBSetNodeNextOpMode($node,TBDB_NODEOPMODE_RELOADUE);

    #
    # The device goes 'down', then starts to reload
    #
    TBSetNodeEventState($node,TBDB_NODESTATE_SHUTDOWN);
    TBSetNodeEventState($node,TBDB_NODESTATE_RELOADING);

    #
    # Invoke local script that calls the remote end that
    # actually does the work.  This will go into the background.
    #
    my $rv = system("$TBADB -n $node loadimage $imgpid $imgname nowait");
    if ($rv) {
	tberror "$node: tbadb failed!";
	return -1;
    }

    return 0;
}

#
# Grab the size and update the database.
#
sub GetImageSize($$)
{
    my ($image, $node) = @_;
    my $imagesize = 0;
    my $imagepath = $image->FullImageFile();

    #
    # Perform a few validity checks: imageid should have a file name
    # and that file should exist.
    #
    if (!defined($imagepath)) {
	tberror "No filename associated with $image!";
	return -1;
    }

    if (! -R $imagepath) {
	#
	# There are two reasons why a legit image might not be readable.
	# One is that we are in an elabinelab and the image has just not
	# been downloaded yet. The other is that we are attempting to
	# access a shared (via the grantimage mechanism) image which the
	# caller cannot directly access.
	#
	# For either case, making a proxy query request via frisbee will
	# tell us whether the image is accessible and, if so, its size.
	# "imageinfo" makes that call for us.
	#
	my $frisimageid = $image->pid() . "/" . $image->imagename();
	my $sizestr = `$IMAGEINFO -qs -N $node $frisimageid`;
	if ($sizestr =~ /^(\d+)$/) {
	    $imagesize = $1;
	} else {
	    tberror "$image: access not allowed or image does not exist.";
	    return -1;
	}
    } else {
	$imagesize = stat($imagepath)->size;
    }

    #
    # A zero-length image cannot be right and will result in much confusion
    # if allowed to pass: the image load will succeed, but the disk will be
    # unchanged, making it appear that os_load loaded the default image.
    #
    if ($imagesize == 0) {
	tberror "$imagepath is empty!";
	return -1;
    }
    $image->SetFullSize($imagesize);
    return 0;
}

#
# Return two array references (possbily empty) of:
# [all nodes requiring reboot, all nodes not requiring reboot]
#
sub GetNodesRequiringReboot($@) {
    my ($reload_info, @nodes) = @_;
    my (@reboot, @noreboot);
    foreach my $node (@nodes) {
	if ($reload_info->{$node}{'reboot'}) {
	    push @reboot, $node;
	} else {
	    push @noreboot, $node;
	}
    }
    return (\@reboot, \@noreboot);
}

#
# This gets called in the parent, to wait for an async osload that was
# launched earlier (asyncmode). The child will print the results back
# on the the pipe that was opened between the parent and child. They
# are stuffed into the original results array.
# 
sub osload_wait($)
{
    my ($childpid) = @_;

    if (!exists($children{$childpid})) {
	tberror "No such child pid $childpid!"; # INTERNAL
	return -1;
    }
    my ($PARENT_READER, $result) = @{ $children{$childpid}};

    #
    # Read back the results.
    # 
    while (<$PARENT_READER>) {
	chomp($_);

	if ($_ =~ /^([-\w]+),([-\d])+$/) {
	    $result->{$1} = $2;
	    print STDERR "reload ($1): child returned $2 status.\n";
	}
	else {
	    tberror "Improper response from child: $_"; # INTERNAL
	}
    }
    
    #
    # And get the actual exit status.
    # 
    waitpid($childpid, 0);
    return $? >> 8;
}

sub osload_kill($)
{
    my ($childpid) = @_;

    print STDERR "osload_kill($childpid): starting\n";
    kill('TERM', $childpid);
    waitpid($childpid, 0);
    return 0;
}

#
# Save signature files and boot partition info for all nodes in an experiment
# (or just the listed nodes).  We call this when swapping in an experiment or
# when reloading nodes in an experiment.
#
# Note that this is not strictly an os loading function, we do it on swapins
# of nodes which already have the correct OS as well.  But we stick it here
# because it is about os loading in principle.
#
sub osload_setupswapinfo($$;@)
{
    my ($pid, $eid, @nodelist) = @_;
    my %nodeinfo = ();
    my $allnodes;
    my $clause = "";

    if (!@nodelist) {
	@nodelist = ExpNodes($pid, $eid, 1, 0);
	$clause .= "r.pid='$pid' and r.eid='$eid'";
	$allnodes = 1;
    } else {
	$clause .= "r.node_id in (" . join(",", map("'$_'", @nodelist)) . ")";
	$allnodes = 0;
    }
    map { $nodeinfo{$_} = 0 } @nodelist;

    # XXX only know how to do this for local PCs right now
    $clause .= " and nt.class='pc' and nt.isremotenode=0";

    #
    # Note that we are using the def_boot_osid from the nodes table to identify
    # the image of interest.  This is because the osid field is set by stated
    # after a node has reached the BOOTING state the first time, and may be
    # set to an MFS at other times.
    #
    my $query_result = DBQueryWarn(
	"select r.node_id,r.vname,r.pid,r.eid,r.erole,n.osid,p.`partition`,".
	"       p.imageid,p.imageid_version,p.imagepid,i.imagename,".
	"       iv.loadpart,e.savedisk ".
	"from reserved as r ".
	"left join nodes as n on n.node_id=r.node_id ".
	"left join node_types as nt on nt.type=n.type ".
	"left join `partitions` as p on p.node_id=n.node_id and ".
	"          p.osid=n.def_boot_osid ".
        "left join images as i on i.imageid=p.imageid and ".
	"          i.version=p.imageid_version ".
        "left join image_versions as iv on iv.imageid=i.imageid and ".
	"          iv.version=i.version ".
        "left join experiments as e on e.pid=r.pid and e.eid=r.eid ".
	"where $clause");
    if (!$query_result) {
	return 1;
    }

    while (my ($node, $vname, $rpid, $reid, $erole, $osid, $part, $imageid,
	       $imageid_version, $imagepid, $imagename, $lpart, $savedisk) =
	   $query_result->fetchrow_array()) {

	my $nodeobject = Node->Lookup($node);

	# If the node is not imageable, skip it.
	next
	    if (! $nodeobject->imageable());
	
	my $dtype = $nodeobject->disktype();
	my $dunit = $nodeobject->bootdisk_unit();

	#
	# XXX not a disk-based OSID.  This can happen during frisbee loads
	#
	if (!defined($imageid)) {
	    print "*** swapinfo: OS $osid is not disk-based!?\n";
	    next
		if (!$allnodes);
	    return 1;
	}
	my $image = OSImage->Lookup($imageid, $imageid_version);
	if (!defined($image)) {
	    print "*** swapinfo: Image $imageid,$imageid_version not found!\n";
	    next
		if (!$allnodes);
	    return 1;
	}

	#
	# Weed out otherwise ineligible nodes:
	#	- from experiments that are not saving disk state
	#	- non-'node' role machines (i.e., delaynodes, virthosts)
	# They are removed from nodeinfo entirely so we do not complain about
	# them below.  This is the only reason we are doing this here rather
	# than as part of the above query.
	#
	if (!defined($savedisk) || $savedisk == 0 || $erole ne "node") {
	    delete $nodeinfo{$node};
	    next;
	}

	# Sanity checks
	if (!defined($nodeinfo{$node})) {
	    next
		if (!$allnodes);
	    print "*** swapinfo: Got partition info for invalid node $node!?\n";
	    return 1;
	}
	if ($nodeinfo{$node} != 0) {
	    print "*** swapinfo: Got redundant partition info for $node!?\n";
	    return 1;
	}

	my $disk = "$dtype$dunit";
	$nodeinfo{$node} =
	    [$vname, $rpid, $reid, $disk, $part, $imagepid, $imagename, $lpart];
    }

    #
    # Copy over the signature file for the image used on every node under
    # the name <vname>.sig.  Likewise, we record the partition that the
    # image resides in under <vname>.part.
    #
    # Note that we actually copy the signature over as <imagename>.sig and
    # then symlink the <vname>.sig's to it.  This not only saves space,
    # but makes it easier to determine what is loaded on each node.
    #
    # Finally note that we are using imagename rather than imageid (which
    # is a numeric UUID).  The latter is really closer to what we want, but
    # was added later and needs to be reconciled with our idea of 'unique'
    # (the signature).
    #
    my %gotsig = ();
    for my $node (keys(%nodeinfo)) {
	my $infop = $nodeinfo{$node};
	if ($infop == 0) {
	    print "*** swapinfo: WARNING: got no partition info for $node!\n";
	    next;
	}
	my ($vname, $rpid, $reid, $disk, $part, $imagepid, $imagename, $lpart) = @{$infop};

	#
	# If imageid is not "fully qualified" with the project name,
	# generate a name that is.
	#
	my $rimagename = $imagename;
	if ($rimagename !~ /^$imagepid-/) {
	    $rimagename = "$imagepid-$imagename";
	}

	# XXX backward compat
	my $infodir = "/$PROJROOT/$rpid/exp/$reid/swapinfo";
	if (! -d "$infodir" && !mkdir($infodir, 0770)) {
	    print "*** swapinfo: no swap info directory $infodir!\n";
	    next
		if (!$allnodes);
	    return 1;
	}

	#
	# First make sure we get rid of any old signature for the node
	# in case any of the following steps fail.
	#
	unlink("$infodir/$vname.sig", "$infodir/$vname.part");

	#
	# Now copy over the base signature if needed, either because
	# it doesn't exist in the swapinfo directory or is out of date.
	#
	my $mustcopy = 0;
	my ($sigdir, $signame);
	if ($imagepid eq TBOPSPID()) {
	    $sigdir = "$TB/images/sigs";
	} else {
	    $sigdir = "/$PROJROOT/$imagepid/images/sigs";
	}
	$signame = "$imagename.ndz.sig";
	$signame =~ s/^$imagepid-//;
	if (! -d $sigdir || ! -f "$sigdir/$signame") {
	    print "*** swapinfo: WARNING: ".
		"no image signature for $rimagename, ".
		"cannot save swapout state!\n";
	    next;
	}
	my $basesig = "$infodir/$rimagename.sig";
	if (! -r $basesig) {
	    $mustcopy = 1;
	} elsif (!defined($gotsig{$basesig})) {
	    my $fromtime = stat("$sigdir/$signame")->mtime;
	    my $totime = stat($basesig)->mtime;
	    if ($fromtime > $totime) {
		print "*** swapinfo: WARNING: ".
		    "$rimagename.sig out of date, updating...\n";
		$mustcopy = 1;
	    } elsif ($fromtime < $totime) {
		print "*** swapinfo: WARNING: ".
		    "$rimagename.sig newer than source $sigdir/$signame!\n";
	    }
	}
	if ($mustcopy) {
	    unlink($basesig);
	    if (system("/bin/cp -p $sigdir/$signame $basesig")) {
		print "*** swapinfo: WARNING: ".
		      "could not create signature $basesig, ".
		      "cannot save swapout state!\n";
		next;
	    }
	}
	$gotsig{$basesig} = 1;

	if (system("/bin/ln -s $rimagename.sig $infodir/$vname.sig")) {
	    print "*** swapinfo: WARNING: ".
		"could not create signature $infodir/$vname.sig, ".
		    "cannot save swapout state!\n";
	    next;
	}

	if (!open(FD, "> $infodir/$vname.part")) {
		print "*** swapinfo: WARNING: ".
		      "could not create partition file $infodir/$vname.part, ".
		      "cannot save swapout state!\n";
		unlink("$infodir/$vname.sig");
		next;
	}
	print FD "DISK=$disk ";
	print FD "LOADPART=$lpart ";
	print FD "BOOTPART=$part\n";
	close(FD);
    }

    #
    # Now get rid of usused signature files
    # Note that we can only use the gotsig hash if we are loading all nodes
    # in an experiment (else we don't know whether a sig is used or not).
    #
    if ($allnodes) {
	my $infodir = "/$PROJROOT/$pid/exp/$eid/swapinfo";
	my @allsigs = `ls $infodir/*.sig`;
	chomp(@allsigs);
	for my $sig (@allsigs) {
	    if (! -l $sig && !defined($gotsig{$sig})) {
		# untaint the file name
		if ($sig =~ /^($infodir\/[-\w\.\+]+\.sig)$/) {
		    $sig = $1;
		    print "removing unused signature file $sig ...\n";
		    unlink($sig);
		}
	    }
	}
    }
}

sub SetupEventHandler($)
{
    my ($handler) = @_;
    
    my $port = 16505;
    my $URL  = "elvin://localhost:$port";
    
    # Connect to the event system, and subscribe the the events we want
    my $EVhandle = event_register($URL, 0);
    
    if (!$EVhandle) {
	print STDERR "*** event: Unable to register with event system\n";
	return undef;
    }

    my $tuple = address_tuple_alloc();
    if (!$tuple) {
	print STDERR "*** event: Could not allocate an address tuple\n";
	return undef;
    }

    # These are the states that indicate things are happening.
    my @states = (TBDB_NODESTATE_RELOADSETUP(),
		  TBDB_NODESTATE_RELOADING());

    %$tuple = ( objtype   => TBDB_TBEVENT_NODESTATE(),
		eventtype => join(",", @states),
	      );
    
    if (!event_subscribe($EVhandle, $handler, $tuple)) {
	print STDERR "*** event: Could not subscribe to events\n";
	return undef;
    }
    return $EVhandle;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
