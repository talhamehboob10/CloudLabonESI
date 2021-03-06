#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2010 University of Utah and the Flux Group.
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
# XXX Need to deal with locking at some point ...
#
package libArchive;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use libdb;
use libtestbed;
use Project;
use English;
use Experiment;
use Archive;
use Template;
use File::stat;
use File::Basename;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);

# Configure variables
my $TB		= "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $MAINSITE    = 0;
my $ARCHSUPPORT = 0;
my $USEARCHIVE  = $ARCHSUPPORT;
my $ZIPINFO     = "/usr/local/bin/zipinfo";
my $TAR		= "/usr/bin/tar";

sub setdebug($)
{
    my ($toggle) = @_;

    Archive::setdebug($toggle);
}

#
# Get the archive index for an experiment. The index is kept in the historical
# experiment_stats table, not the current experiments table. That is cause
# we keep the archive and its DB info around forever with the stats.
#
sub TBExperimentArchive($$$$)
{
    my ($pid, $eid, $archivep, $viewp) = @_;

    my $query_result =
	DBQueryWarn("select s.archive_idx,e.idx from experiments as e ".
		    "left join experiment_stats as s on s.exptidx=e.idx ".
		    "where e.pid='$pid' and e.eid='$eid'");

    return -1
	if (!$query_result || $query_result->numrows == 0);

    my ($archive_idx,$exptidx) = $query_result->fetchrow_array();

    # Need to deal with no archive yet!
    return 1
	if (!defined($archive_idx) || $archive_idx == 0);

    my $archive = Archive->Lookup($archive_idx);
    return -1
	if (!defined($archive));

    $$archivep = $archive
	if (defined($archivep));
    $$viewp = "$exptidx"
	if (defined($viewp));
    
    return 0;
}

#
# Grab the current tag for an experiment.
#
sub TBExperimentArchiveTag($$$)
{
    my ($pid, $eid, $tagp) = @_;

    my $query_result =
	DBQueryWarn("select r.archive_tag from experiments as e ".
		    "left join experiment_stats as s on s.exptidx=e.idx ".
		    "left join experiment_resources as r on r.idx=s.rsrcidx ".
		    "where e.pid='$pid' and e.eid='$eid'");

    return -1
	if (!$query_result || $query_result->numrows == 0);

    my ($archive_tag) = $query_result->fetchrow_array();

    # Need to deal with no archive yet!
    return 1
	if (!defined($archive_tag));

    $$tagp = $archive_tag;
    return 0;
}

#
# Create a new archive for an experiment. This has to update the
# experiment_stats table with the newly created archive index.
# Then we have to set the current tag for the experiment in the
# resources table for the experiment.
# Returns zero on success, -1 on failure.
#
sub TBCreateExperimentArchive($$)
{
    my ($pid, $eid) = @_;

    return 0
	if (!Archive::doarchiving($pid, $eid));

    my $experiment = Experiment->Lookup($pid, $eid);
    return -1
	if (!defined($experiment));
    
    my $exptidx   = $experiment->idx();
    my $rsrcidx   = $experiment->rsrcidx();
    my $group     = $experiment->GetGroup();
    my $unix_name = $group->unix_name();
    my $view      = "$exptidx";

    my $archive = Archive->Create($view, $unix_name);
    return -1
	if (!defined($archive));

    my $archive_idx = $archive->idx();

    $experiment->TableUpdate("experiment_stats",
			     "archive_idx='$archive_idx'") == 0
	or goto bad;
    
    return 0;

  bad:
    $archive->Destroy(1, $view);
    return -1;
}

#
# Add a file to an experiment archive.
#
sub TBExperimentArchiveAddFile($$$;$)
{
    my ($pid, $eid, $pathname, $exact) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->Add($pathname, $view, $exact);
}

#
# Add files picked up by NFS tracing to an experiment archive.
#
sub TBExperimentArchiveAddTracedFiles($$)
{
    return 0;
}

#
# Add all files from the experiment directory to the archive.
#
sub TBExperimentArchiveAddUserFiles($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));

    my $experiment = Experiment->Lookup($pid, $eid);
    return -1
	if (!defined($experiment));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $userdir;

    if ($experiment->IsTemplate()) {
	# XXX Fix this
	my $template = Template->LookupByPidEid($pid, $eid);

	$userdir = $template->path();
    }
    else {
	$userdir = $experiment->UserDir();
    }

    if (-e $userdir) {
	$rval = $archive->Add("$userdir/.", $view, 1, 1);

	return $rval
	    if ($rval != 0);
    }
    return 0;
}

#
# Check for differences in the user files to see if we need a commit.
#
sub TBExperimentArchiveDiffUserFiles($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $experiment = Experiment->Lookup($pid, $eid);
    return -1
	if (!defined($experiment));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $userdir;

    if ($experiment->IsTemplate()) {
	# XXX Fix this
	my $template = Template->LookupByPidEid($pid, $eid);

	$userdir = $template->path();
    }
    else {
	$userdir = $experiment->UserDir();
    }

    if (-e $userdir) {
	$rval = $archive->Diff("$userdir/.", $view);

	return $rval
	    if ($rval != 0);
    }
    return 0;
}

#
# SavePoint an experiment archive. 
#
sub TBExperimentArchiveSavePoint($$;$)
{
    return 0;
}

#
# Setup for a swapmod. A pain in the butt!
#
sub TBExperimentArchivePreSwapMod($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $directory = $archive->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchivePreSwapMod: $directory cannot be written!\n";
	return -1;
    }
    my $checkin    = "$directory/checkins/$view";
    my $preswapdir = "${checkin}.preswapmod";

    #
    # Make a copy of the current tree, since its easier to rollback
    # if I just wait before doing a commit (until swapmod really finishes).
    #
    if (-e $preswapdir) {
	system("/bin/rm -rf $preswapdir");
	if (-e $preswapdir) {
	    print STDERR
		"ArchivePreSwapMod: Could not delete old preswap dir!\n";
	    return -1;
	}
    }
    if (! mkdir("$preswapdir", 0777)) {
	print STDERR "ArchivePreSwapMod: Could not mkdir $preswapdir: $!\n";
	return -1;
    }
    if (! chmod(0777, "$preswapdir")) {
	print STDERR "ArchivePreSwapMod: ".
	    "Could not chmod directory $preswapdir: $!\n";
	goto bad;
    }
    
    mysystem("$TAR cf - -C $checkin . | tar xf - -C $preswapdir");
    if ($?) {
	print STDERR "ArchivePreSwapMod: Could not copy to $preswapdir\n";
	goto bad;
    }
    return 0;

  bad:
    # Be sure to remove the new directory!
    if (-e $preswapdir) {
	system("/bin/rm -rf $preswapdir");
	if (-e $preswapdir) {
	    print STDERR
		"ArchivePreSwapMod: Could not delete new preswap dir!\n";
	}
    }
    return -1;
}

#
# Next phase of a swapmod; do another snapshot after the swapout completes.
#
sub TBExperimentArchiveSwapModSwapOut($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $directory = $archive->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveSwapmodswapout: $directory cannot be written!\n";
	return -1;
    }
    my $checkin    = "$directory/checkins/$view";
    my $preswapdir = "${checkin}.swapmodswapout";

    #
    # Grab the user specified files. 
    #
    if (TBExperimentArchiveAddUserFiles($pid, $eid) < 0) {
	print STDERR "ArchiveSwapmodswapout: ".
	    "Failed to add user specified files to the experiment archive!\n";
	return -1;
    }
    
    #
    # Add the files that have been detected by tracing to the archive.
    #
    if (TBExperimentArchiveAddTracedFiles($pid, $eid) < 0) {
	print STDERR "ArchiveSwapmodswapout: ".
	    "Failed to add traced files to the experiment archive!\n";
	return -1;
    }

    #
    # Make a copy of the current tree; This is the tree that will be
    # committed as the swapout if the swapmod completes okay.
    #
    if (-e $preswapdir) {
	system("/bin/rm -rf $preswapdir");
	if (-e $preswapdir) {
	    print STDERR
		"ArchiveSwapmodswapout: Could not delete old preswap dir!\n";
	    return -1;
	}
    }
    if (! mkdir("$preswapdir", 0777)) {
	print STDERR
	    "ArchiveSwapmodswapout: Could not mkdir $preswapdir: $!\n";
	return -1;
    }
    if (! chmod(0777, "$preswapdir")) {
	print STDERR "ArchiveSwapmodswapout: ".
	    "Could not chmod directory $preswapdir: $!\n";
	goto bad;
    }
    
    mysystem("$TAR cf - -C $checkin . | tar xf - -C $preswapdir");
    if ($?) {
	print STDERR "ArchiveSwapmodswapout: Could not copy to $preswapdir\n";
	goto bad;
    }
    return 0;

  bad:
    # Be sure to remove the new directory!
    if (-e $preswapdir) {
	system("/bin/rm -rf $preswapdir");
	if (-e $preswapdir) {
	    print STDERR
		"ArchiveSwapmodswapout: Could not delete new preswap dir!\n";
	}
    }
    return -1;
}

#
# Rollback from a failed swapmod.
#
sub TBExperimentArchiveRollBack($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $directory = $archive->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveRollBack: $directory cannot be written!\n";
	return -1;
    }
    my $checkin        = "$directory/checkins/$view";
    my $preswapdir     = "${checkin}.preswapmod";
    my $swapmodswapout = "${checkin}.swapmodswapout";

    # In case we bailed out really early in the swapmod path.
    return 0
	if (! -e $preswapdir);

    #
    # Restore the old (preswap) tree to the current tree.
    #
    if (-e $checkin) {
	system("/bin/rm -rf $checkin");
	if (-e $checkin) {
	    print STDERR
		"ArchiveRollBack: Could not delete $checkin!\n";
	    return -1;
	}
    }
    if (-e $swapmodswapout) {
	system("/bin/rm -rf $swapmodswapout");
	if (-e $swapmodswapout) {
	    print STDERR
		"ArchiveRollBack: Could not delete $swapmodswapout!\n";
	    return -1;
	}
    }
    system("/bin/mv -f $preswapdir $checkin");
    if ($?) {
	print STDERR "ArchiveRollBack: ".
	    "Could not mv $preswapdir to $checkin\n";
	return -1;
    }
    return 0;
}

#
# Swapmod completed okay. Need to commit the old preswap directory and
# move forward. 
#
sub TBExperimentArchiveSwapModCommit($$$)
{
    my ($pid, $eid, $swapped) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $directory = $archive->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveSwapModCommit: $directory cannot be written!\n";
	return -1;
    }
    my $checkin        = "$directory/checkins/$view";
    my $preswapdir     = "${checkin}.preswapmod";
    my $swapmodswapout = "${checkin}.swapmodswapout";

    #
    # Where we get the previous stuff depends on whether the modify is
    # of a swapped in or swapped out experiment.
    #
    my $location = ($swapped ? $preswapdir : $swapmodswapout);

    #
    # We need this below.
    #
    my $query_result =
	DBQueryWarn("select s.rsrcidx from experiments as e ".
		    "left join experiment_stats as s on e.idx=s.exptidx ".
		    "where e.pid='$pid' and e.eid='$eid'");
    if (!$query_result || !$query_result->numrows) {
	return -1;
    }
    my ($rsrcidx) = $query_result->fetchrow_array();

    #
    # Derive a useful tag.
    # 
    my ($seconds, $microseconds) = gettimeofday();
    my $newtag  = POSIX::strftime("T20%y%m%d-%H%M%S-", localtime());
    $newtag .= int($microseconds / 1000);
    $newtag .= "_preswapmod";

    print "Doing a commit on the experiment archive ...\n";
    return -1
	if ($archive->Commit($newtag, undef, undef, $view, $location) != 0);

    if (!DBQueryWarn("update experiment_resources set ".
		     "      archive_tag='$newtag' ".
		     "where idx='$rsrcidx'")) {
	return -1;
    }

    #
    # Remove the preswap dir, but if it fails keep going. Will catch it
    # next time above.
    # 
    system("/bin/rm -rf $preswapdir");
    if ($?) {
	print STDERR "*** ArchiveSwapModCommit: Could not rm $preswapdir\n";
    }
    # Ditto.
    system("/bin/rm -rf $swapmodswapout");
    if ($?) {
	print STDERR
	    "*** ArchiveSwapModCommit: Could not rm $swapmodswapout\n";
    }

    return 0;
}

#
# Commit an experiment archive. 
#
sub TBCommitExperimentArchive($$$;$$$)
{
    my ($pid, $eid, $tagext, $usertagged, $mfile, $comment) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $experiment = Experiment->Lookup($pid, $eid);
    return -1
	if (!defined($experiment));

    my $rsrcidx     = $experiment->rsrcidx();
    my $archive_idx = $archive->idx();

    #
    # Derive a tag, unless its a user specified tag. In that case it
    # has to be unique cause we are going to use the whole thing as is.
    #
    my $newtag;
    if (! $usertagged) {
	my ($seconds, $microseconds) = gettimeofday();
	$newtag  = POSIX::strftime("T20%y%m%d-%H%M%S-", localtime());
	$newtag .= int($microseconds / 1000);
	$newtag .= "_${tagext}";
    }
    else {
	$newtag = $tagext;

	my $unique = $archive->IsTagUnique($newtag, $view);
	return -1
	    if (!defined($unique));

	if (! $unique) {
	    print STDERR "*** ArchiveCommit: Duplicate user tag: $newtag\n";
	    return -1;
	}
    }

    return -1
	if ($archive->Commit($newtag, $comment, $mfile, $view) != 0);

    $experiment->TableUpdate("experiment_resources",
			     "archive_tag='$newtag'", "idx='$rsrcidx'") == 0
	or goto bad;

    # A user specified tag is updated.
    if ($usertagged) {
	my $query_result =
	    DBQueryWarn("update archive_tags set ".
			"  tagtype='$Archive::TAGTYPE_USER' ".
			"where archive_idx='$archive_idx' and ".
			"      view='$view' and tag='$newtag'");
	return -1
	    if (!$query_result);
	if (!$query_result->affectedrows) {
	    print STDERR "*** ArchiveCommit: ".
		"Could not update user tag: $newtag\n";
	}
    }
    return 0;
}

#
# Tag an experiment archive. 
#
sub TBTagExperimentArchive($$$;$$)
{
    return 0;
}

#
# Checkout a copy of an experiment archive, optionally at a branch.
# 
sub TBCheckoutExperimentArchive($$$;$$)
{
    my ($pid, $eid, $path, $tag, $subdir) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->Checkout($path, $view, $tag, $subdir);
}

#
# Checkout a copy of an experiment archive, optionally at a branch.
# 
sub TBCheckoutExperimentArchivebyExptIDX($$;$$)
{
    my ($exptidx, $path, $tag, $subdir) = @_;

    return 0
	if (!$USEARCHIVE);

    my $query_result =
	DBQueryWarn("select archive_idx from experiment_stats ".
		    "where exptidx='$exptidx'");
    return -1
	if (!$query_result || !$query_result->numrows);
    
    my ($archive_idx) = $query_result->fetchrow_array();
    
    return 0
	if (!$archive_idx);

    my $archive = Archive->Lookup($archive_idx);
    return -1
	if (!defined($archive));

    return $archive->Checkout($path, $exptidx, $tag, $subdir);
}

#
# Archive an experiment archive to the save area.
# 
sub TBArchiveExperimentArchive($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->Archive($view);
}

#
# Delete an experiment archive. This just deletes it from the active area.
# Its historical DB state is retained.
#
sub TBDeleteExperimentArchive($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->Destroy(0, $view);
}

#
# Destroy an experiment archive. Totally flush it from the system.
#
sub TBDestroyExperimentArchive($$)
{
    my ($pid, $eid) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->Destroy(1, $view);
}

#
# Branch an experiment archive. Only an existing experiment can be
# branched, but that will probably change later. 
#
sub TBForkExperimentArchive($$$$$)
{
    my ($pid, $eid, $copypid, $copyeid, $copytag) = @_;
    my ($archive, $copyview);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($copypid, $copyeid,
				   \$archive, \$copyview);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $experiment = Experiment->Lookup($pid, $eid);
    return -1
	if (!defined($experiment));

    my $archive_idx = $archive->idx();
    my $rsrcidx     = $experiment->rsrcidx();
    my $archive_tag = "F${rsrcidx}";
    my $newview     = $experiment->idx();

    return -1
	if ($archive->Fork($newview, $archive_tag, $copyview) < 0);

    $experiment->TableUpdate("experiment_resources",
			     "archive_tag='$archive_tag'",
			     "idx='$rsrcidx'") == 0
	or goto bad;

    $experiment->TableUpdate("experiment_stats",
			     "archive_idx='$archive_idx'") == 0
	or goto bad;

    return 0;

  bad:
    # Its a shared resource, but ArchiveDestroy() checks.
    $archive->Destroy(1, $newview)
	if (defined($archive));
    return -1;
}

#
# Check that a tag is unique.
#
sub TBIsTaqUnique($$$$)
{
    my ($pid, $eid, $tag, $prval) = @_;
    my ($archive, $view);
    
    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    my $unique = $archive->IsTagUnique($tag, $view);
    return -1
	if (!defined($unique));
    $$prval = $unique;
    return 0;
}

#
# Return a list of files in a particular spot in the archive. This avoids
# having to check it out.
#
sub TBListExperimentArchive($$$;$$$)
{
    my ($pid, $eid, $prval, $long, $tag, $root, $subdir) = @_;
    my ($archive, $view);

    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->List($prval, $view, $long, $tag, $subdir);
}

#
# Return a list of files in a particular spot in the archive. This avoids
# having to check it out.
#
sub TBDUExperimentArchive($$$)
{
    my ($pid, $eid, $prval) = @_;
    my ($archive, $view);

    $$prval = 0;
    return 0
	if (!Archive::doarchiving($pid, $eid));
    
    my $rval = TBExperimentArchive($pid, $eid, \$archive, \$view);
    return 0
	if ($rval > 0);
    return -1
	if ($rval < 0);

    return $archive->DU($prval);
}

# _Always_ make sure that this 1 is at the end of the file...
1;

