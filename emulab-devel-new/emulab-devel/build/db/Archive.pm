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
package Archive;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use libdb;
use libtestbed;
use Project;
use Experiment;
use Template;
use English;
use File::stat;
use File::Basename;
use Data::Dumper;
use POSIX qw(strftime getgid);
use Time::HiRes qw(gettimeofday);
use overload ('""' => 'Stringify');

# Configure variables
my $TB		= "/users/mshobana/emulab-devel/build";
my $MAINSITE    = 0;
my $ARCHSUPPORT = 0;
my $USEARCHIVE  = $ARCHSUPPORT;
my %ALLOWEDPID  = ("testbed" => 1);
# XXX
my $ARCHIVEDIR  = "/usr/testbed/exparchive";
my $TESTMODE    = 0;
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $ELABINELAB  = 0;
my $MD5		= "/sbin/md5";
my $MKDIR       = "/bin/mkdir";
my $CHMOD       = "/bin/chmod";
my $SUCHOWN     = "$TB/sbin/suchown";
my $CHGRP       = "/usr/bin/chgrp";
my $TAR		= "/usr/bin/tar";
my $RSYNC	= "/usr/local/bin/rsync";
my $RM		= "/bin/rm";
my $REALPATH	= "/bin/realpath";
my $ZIP         = "/usr/local/bin/zip";
my $UNZIP       = "/usr/local/bin/unzip";
my $ZIPINFO     = "/usr/local/bin/zipinfo";
my $DU          = "/usr/bin/du";
my $DIFF        = "/usr/bin/diff";
my $inittag     = 'root';
my $defaultview = 'head';
my $REPO        = "ziprepo";
my $TAGVERSION  = 1;		# 0 is from SVN.
my $debug       = 1;
my $zipopt      = ($debug ? "-v" : "-q");
my $SHAREROOT   = SHAREROOT();
my $SCRATCHROOT = SCRATCHROOT();
my %ROOTS       = (PROJROOT()  => "proj",
		   USERROOT()  => "users",
		   $SHAREROOT  => "share",
		   GROUPROOT() => "groups");
if ($SCRATCHROOT) {
    $ROOTS{$SCRATCHROOT} = "scratch";
}

# Cache of instances to avoid regenerating them.
my %archives	= ();

my $TAGTYPE_USER      = "user";
my $TAGTYPE_COMMIT    = "commit";
my $TAGTYPE_SAVEPOINT = "savepoint";
my $TAGTYPE_INTERNAL  = "internal";

#
# Set umask so that other people in the project can mess with the archive.
#
umask(0002);

# On or off
sub doarchiving($$)
{
    my ($pid, $eid) = @_;

    return 0
	if (! $USEARCHIVE);

    my $project = Project->Lookup($pid);
    return 0
	if (!defined($project));
    
    my $experiment = Experiment->Lookup($pid, $eid);
    return 0
	if (!defined($experiment));

    # The experiment might be the one underlying a template.
    my $template = Template->LookupByPidEid($pid, $eid);
    
    return 1
	if (($experiment->IsInstance() || defined($template)) && 
	    (exists($ALLOWEDPID{$pid}) || $project->allow_workbench()));
    
    return 0;
}

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    TBDebugTimeStampsOn();    

    print STDERR "Running '$command'\n"
	if ($debug);

    TBDebugTimeStamp($command);
    my $retval = system($command);
    TBDebugTimeStamp("Done");

    return $retval;
}

# Another little helper for scripts that include this library.
sub setdebug($)
{
    my ($toggle) = @_;

    if ($toggle) {
	$debug  = $toggle;
	$zipopt = "-v";
    }
    else {
	$debug  = 0;
	$zipopt = "-q";
    }
}

#
# Lookup and create a class instance to return.
#
sub Lookup($$)
{
    my ($class, $archive_idx) = @_;

    # Look in cache first
    return $archives{$archive_idx}
        if (exists($archives{$archive_idx}));

    return undef
	if (! ($archive_idx =~ /^\d+$/));

    my $query_result =
	DBQueryWarn("select * from archives where idx='$archive_idx'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self            = {};
    $self->{"DBROW"}    = $query_result->fetchrow_hashref();
    $self->{"VIEWS"}    = {};
    bless($self, $class);

    # Add to cache.
    $archives{$archive_idx} = $self;
    return $self;
}
# accessors
sub field($$)  { return ((! ref($_[0])) ? -1 : $_[0]->{'DBROW'}->{$_[1]}); }
sub idx($)		{ return field($_[0], 'idx'); }
sub unix_gid($)		{ return field($_[0], 'unix_gid'); }
sub directory($)        { return field($_[0], 'directory'); }
sub date_created($)     { return field($_[0], 'date_created'); }
sub archived($)         { return field($_[0], 'archived'); }
sub date_archived($)    { return field($_[0], 'date_archived'); }

# For views.
sub View($$)
{
    my ($self, $view) = @_;

    return undef
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from archive_views ".
		    "where archive_idx='$idx' and view='$view'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}

# For revisions
sub Revision($$$)
{
    my ($self, $view, $tag) = @_;

    return undef
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from archive_revisions ".
		    "where archive_idx='$idx' and ".
		    "      view='$view' and tag='$tag'");

    return undef
	if (!$query_result || !$query_result->numrows);

    return $query_result->fetchrow_hashref();
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select * from archives where idx='$idx'");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{"DBROW"}  = $query_result->fetchrow_hashref();
    $self->{"VIEWS"}  = {};
    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $idx = $self->idx();

    return "[Archive: $idx]";
}

#
# Create a new archive. Returns -1 if any error. Otherwise return
# the new record index.
# 
sub Create($;$$)
{
    my ($class, $view, $unix_gid) = @_;
    
    my $idx;
    my $dir;

    $view = $defaultview
	if (!defined($view));
    $unix_gid = POSIX::getgid()
	if (!defined($unix_gid));

    #
    # Need to create the directory for it, once we have the index.
    # 
    my $query_result =
	DBQueryWarn("insert into archives set ".
		    "  idx=NULL, date_created=UNIX_TIMESTAMP(now())");

    return undef
	if (!$query_result);

    $idx = $query_result->insertid;
    $dir = "$ARCHIVEDIR/$idx";

    #
    # Create the directory and store the absolute path into the new record.
    # This should probably be a privledged operation at some point.
    # 
    mysystem("$MKDIR $dir") == 0 or goto bad;
    mysystem("$CHMOD 775 $dir") == 0 or goto bad;
    if (defined($unix_gid)) {
	mysystem("$CHGRP $unix_gid $dir") == 0 or goto bad;
    }

    DBQueryWarn("update archives set directory='$dir' where idx='$idx'")
	or goto bad;

    #
    # Make subdirs. One to hold the control tree, and the other
    # to hold currently checked out versions of the tree. Lastly, we
    # need a place to copyin files before they are added to the repo.
    #
    my $repodir   = "$dir/$REPO";
    my $checkouts = "$dir/checkouts";
    my $checkins  = "$dir/checkins";

    if (! mkdir("$repodir", 0777)) {
	print STDERR "ArchiveCreate: Could not mkdir $repodir: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$repodir")) {
	print STDERR "ArchiveCreate: Could not chmod $repodir: $!\n";
	goto bad;
    }
    if (! mkdir("$checkouts", 0777)) {
	print STDERR "ArchiveCreate: Could not mkdir $checkouts: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$checkouts")) {
	print STDERR "ArchiveCreate: Could not chmod $checkouts: $!\n";
	goto bad;
    }
    if (! mkdir("$checkins", 0777)) {
	print STDERR "ArchiveCreate: Could not mkdir $checkins: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$checkins")) {
	print STDERR "ArchiveCreate: Could not chmod $checkins: $!\n";
	goto bad;
    }
    if (! mkdir("$checkins/$view", 0777)) {
	print STDERR "ArchiveCreate: Could not mkdir $checkins/$view: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$checkins/$view")) {
	print STDERR "ArchiveCreate: Could not chmod $checkins/$view: $!\n";
	goto bad;
    }
    if (! mkdir("$repodir/$view", 0777)) {
	print STDERR "ArchiveCreate: Could not mkdir $checkins/$view: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$repodir/$view")) {
	print STDERR "ArchiveCreate: Could not chmod $checkins/$view: $!\n";
	goto bad;
    }
    
    # Now enter the default view (okay, branch) of this archive.
    DBQueryWarn("insert into archive_views set ".
		"  current_tag=NULL, archive_idx='$idx', view='$view', ".
		"  date_created=UNIX_TIMESTAMP(now())") or goto bad;

    return Archive->Lookup($idx);

  bad:
#    mysystem("$RM -rf $dir")
#        if (defined($dir));
    if (defined($idx)) {
	DBQueryFatal("delete from archive_views ".
		     "where view='$view' and archive_idx='$idx'");
	DBQueryFatal("delete from archives where idx='$idx'");
    }
    return undef;
}

#
# Helper function for below; Checks that a path is safe and legal.
#
sub ValidatePath($)
{
    my ($ppath)  = @_;
    # We get a pointer so we can return the new path.
    my $pathname = $$ppath;
    my $rootdir;

    # Taint check path before handing off to shell below.
    if ($pathname =~ /^([-\w\/\.\+\@,~]+)$/) {
	$pathname = $1;
    }
    else {
	print STDERR "*** ValidatePath: illegal characters in '$pathname'\n";
	return 1;
    }

    # XXX For template checkout/commit via xmlrpc interface
    $pathname =~ s/^\/q//;

    if (! -e $pathname || ! -r $pathname) {
	print STDERR "*** ValidatePath: $pathname cannot be read!\n";
	return 1;
    }

    #
    # Use realpath to check that the path does not contain links to
    # files outside the directory space the user is allowed to access.
    # We must taint check the result to keep everyone happy.
    #
    my $realpath = `$REALPATH $pathname`;
    if ($realpath =~ /^([-\w\/\.\+\@,~]+)$/) {
	$realpath = $1;
    }
    else {
	print STDERR "*** ValidatePath: ".
	    "Bad data returned by realpath: $realpath\n";
	return -1;
    }

    #
    # Strip leading /dir from the pathname. We want a relative path to
    # the rootdir so we can copy it in.
    #
    if ($realpath =~ /^[\/]+(\w+)\/(.+)$/) {
	$rootdir  = "/$1";
	$pathname = $2;
    }
    else {
	print STDERR "*** ValidatePath: ".
	    "Illegal characters in pathname: $realpath\n";
	return -1;
    }

    #
    # The file must reside in one of the Emulab "root" filesystems.
    #
    if (! exists($ROOTS{$rootdir})) {
	print STDERR "*** ValidatePath: ".
	    "$realpath does not resolve to an allowed directory!\n";
	return -1;
    }

    $$ppath = $realpath;
    return 0;
}
    
#
# Add a file to an archive. Returns -1 if any error. Otherwise return 0.
# All this does is copy the file (and its directory structure) into the
# temporary store. Later, after all the files are in the tree, must
# commit it to the repo. 
#
sub Add($$;$$$)
{
    my ($self, $pathname, $view, $exact, $special) = @_;

    return -1
	if (! ref($self));

    $view = $defaultview
	if (!defined($view));

    $exact = 0
	if (!defined($exact));

    $special = 0
	if (!defined($special));

    # This returns a taint checked value in $pathname.
    if (ValidatePath(\$pathname) != 0) {
	print STDERR "ArchiveAdd: Could not validate pathname $pathname\n";
	return -1;
    }

    #
    # Strip leading /dir from the pathname, we need it below.
    #
    my ($rootdir, $sourcedir, $sourcefile);
    my $rsyncopt = "";
    
    if ($special) {
	#
	# What does this do? 
	# Basically, we copy the last part (directory) to / of the checkin.
	# eg: cp /proj/pid/exp/eid... /exp of the checkins.
	# This avoids pid/eid tokens in the archive.
	#
	# Last part of path must be a directory.
	#
	if (! -d $pathname) {
	    print STDERR "ArchiveAdd: Must be a directory: $pathname\n";
	    return -1;
	}
	$rootdir    = "exp";
	$sourcedir  = $pathname;
	$sourcefile = "./";
    }
    elsif ($pathname =~ /^[\/]+(\w+)\/([-\w\/\.\+\@,~]+)$/) {
	$rootdir    = $1;
	$sourcedir  = $1;
	$sourcefile = $2;
	$rsyncopt   = "-R";
    }
    else {
	print STDERR "ArchiveAdd: Illegal characters in pathname $pathname\n";
	return -1;
    }

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveAdd: $directory cannot be written!\n";
	return -1;
    }
    my $checkin   = "$directory/checkins/$view";

    #
    # If the target rootdir exists and is not writable by the current
    # user, then run a chown over the whole subdir. This will avoid
    # avoid permission problems later during the rsync/tar ops below.
    #
    if (-e "$checkin/$rootdir" && ! -o "$checkin/$rootdir") {
	mysystem("$SUCHOWN $checkin/$rootdir") == 0 or return -1
    }
    
    #
    # Copy the file in. We use tar on individual files (to retain the
    # directory structure and mode bits, etc). On a directory, use either
    # tar or rsync, depending on whether we want an exact copy (removing
    # files in the target that are not present in the source). 
    #
    if (! -e "$checkin/$rootdir") {
	mysystem("$MKDIR $checkin/$rootdir") == 0 or return -1
    }
    
    if (-f "/${sourcedir}/${sourcefile}" || !$exact) {
	mysystem("$TAR cf - -C /$sourcedir $sourcefile | ".
		 "$TAR xf - -U -C $checkin/$rootdir");
	mysystem("$CHMOD 775 $checkin/$rootdir/$sourcefile");
    }
    else {
	mysystem("cd /$sourcedir; ".
		 "$RSYNC $rsyncopt -rtgoDlz ".
		 "  --delete ${sourcefile} $checkin/$rootdir");
    }
    if ($?) {
	print STDERR "ArchiveAdd: Could not copy in $pathname\n";
	return -1;
    }
    return 0;
}

#
# Do a diff of the checkin directory against provided directory to
# determine if anything has changed.
#
sub Diff($$;$$)
{
    my ($self, $pathname, $view, @exceptions) = @_;
    my $exclude_arg = "";

    return -1
	if (! ref($self));

    $view = $defaultview
	if (!defined($view));

    # This returns a taint checked value in $pathname.
    if (ValidatePath(\$pathname) != 0) {
	print STDERR "ArchiveDiff: Could not validate pathname $pathname\n";
	return -1;
    }

    if (@exceptions) {
	foreach my $exception (@exceptions) {
	    $exclude_arg .= " '--exclude=$exception'";
	}
    }
    
    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveAdd: $directory cannot be written!\n";
	return -1;
    }
    # See Add() above for why we add "exp"
    my $checkin   = "$directory/checkins/$view/exp";

    #
    # If the target rootdir exists and is not writable by the current
    # user, then run a chown over the whole subdir. This will avoid
    # avoid permission problems later during the rsync/tar ops below.
    #
    if (-e "$checkin" && ! -o "$checkin") {
	mysystem("$SUCHOWN $checkin") == 0 or return -1
    }

    my $retval = mysystem("$DIFF -q -r $exclude_arg $checkin $pathname");
    return 0
	if ($retval == 0);
    return 1
	if ($retval >> 8 == 1);

    # A real problem.
    return -1;
}

#
# Commit the current contents of the temporary store to the archive.
# Returns -1 if any error. Otherwise return 0.
#
sub Commit($;$$$$$)
{
    my ($self, $newtag, $comment, $mfile, $view, $altdir) = @_;
    my $noactivity = 0;
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveCommit: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir   = "$directory/$REPO/$view";
    my $checkin   = (defined($altdir) ? $altdir : "$directory/checkins/$view");

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveCommit: Bad data in $cwd!\n";
	goto bad;
    }

    if (! chdir("$checkin")) {
	print STDERR "ArchiveCommit: Cannot chdir to $checkin!\n";
	goto bad;
    }

    # Get the revision and user tag for the archive/view.
    my $current_tag  = $View->{'current_tag'};
    my $oldprev_tag  = $View->{'previous_tag'};
    my $revision     = $View->{'revision'};

    # args for new records.
    my $parent_revision = (defined($revision)    ? "'$revision'"    : "NULL");
    my $previous_tag    = (defined($current_tag) ? "'$current_tag'" : "NULL");

    #
    # Message can come from a file.
    #
    my $description = "'Commit Archive'";
	
    if (defined($mfile)) {
	if (! -r $mfile) {
	    print STDERR "*** ArchiveCommit: $mfile cannot be read!\n";
	    goto bad;
	}
	$description = DBQuoteSpecial(`cat $mfile`);
    }
    elsif (defined($comment)) {
	$description = DBQuoteSpecial($comment);
    }

    #
    # Create a new revision record so I can get the revision number.
    # Need to update the tag later.
    #
    my $query_result =
	DBQueryWarn("insert into archive_revisions set revision=NULL, ".
		    "  archive_idx='$archive_idx', view='$view', ".
		    "  parent_revision=$parent_revision, ".
		    "  description=$description, ".
		    "  date_created=UNIX_TIMESTAMP(now())") or goto bad;

    my $newrevision = $query_result->insertid;
    my $zipfile     = "$repodir/$newrevision";
    $newtag         = (defined($newtag) ? $newtag : "R${newrevision}");
    
    #
    # Okay, zip up the checkin directory. This becomes a new "revision"
    #
    mysystem("$ZIP $zipopt -y -r $zipfile .") == 0 or goto bad;

    #
    # Enter new tag and revision now that we got it all.
    #
    DBQueryWarn("update archive_views set ".
		"  revision='$newrevision', ".
		"  current_tag='$newtag', ".
		"  previous_tag=$previous_tag ".
		"where archive_idx='$archive_idx' and view='$view'")
	or goto bad;

    DBQueryWarn("update archive_revisions set ".
		"  tag='$newtag' ".
		"where archive_idx='$archive_idx' and revision='$newrevision'")
	or goto bad;

    # Backwards compat
    DBQueryWarn("insert into archive_tags set idx=NULL, version=$TAGVERSION, ".
		"  tag='$newtag', view='$view', ".
		"  archive_idx='$archive_idx', ".
		"  tagtype='$TAGTYPE_COMMIT', ".
		"  date_created=UNIX_TIMESTAMP(now())")
	or goto bad;

  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    if (defined($newrevision)) {
	# args for new records.
	$revision     = (defined($revision)    ? "'$revision'"    : "NULL");
	$current_tag  = (defined($current_tag) ? "'$current_tag'" : "NULL");
	$previous_tag = (defined($oldprev_tag) ? "'$oldprev_tag'" : "NULL");
	
	DBQueryWarn("update archive_views set ".
		    "  revision=$revision, ".
		    "  current_tag=$current_tag, ".
		    "  previous_tag=$previous_tag ".
		    "where archive_idx='$archive_idx' and view='$view'");
	DBQueryFatal("update archive_revisions set ".
		     "  tag=$current_tag ".
		     "where archive_idx='$archive_idx' ".
		     "      and revision='$newrevision'");
	DBQueryWarn("delete from archive_revisions ".
		    "where revision='$newrevision' and ".
		    "      archive_idx='$archive_idx'");
    }
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# Revise is a lot like commit, except that we are changing an arbitrary
# revision, not the head of the view. 
#
sub Revise($$$$$$$)
{
    my ($self, $oldtag, $newtag, $comment, $mfile, $view, $dir) = @_;
    my $noactivity = 0;
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveRevise: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir   = "$directory/$REPO/$view";
    my $checkin   = $dir;

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveRevise: Bad data in $cwd!\n";
	goto bad;
    }

    if (! chdir("$checkin")) {
	print STDERR "ArchiveRevise: Cannot chdir to $checkin!\n";
	goto bad;
    }

    my $revision_row = $self->Revision($view, $oldtag);
    if (!defined($revision_row)) {
	print STDERR "ArchiveRevise: Could not find revision for $oldtag!\n";
	goto bad;
    }
    my $parent_revision = $revision_row->{'revision'};

    #
    # Message can come from a file.
    #
    my $description = "'Revise Archive'";
	
    if (defined($mfile)) {
	if (! -r $mfile) {
	    print STDERR "*** ArchiveRevise: $mfile cannot be read!\n";
	    goto bad;
	}
	$description = DBQuoteSpecial(`cat $mfile`);
    }
    elsif (defined($comment)) {
	$description = DBQuoteSpecial($comment);
    }

    #
    # Create a new revision record so I can get the revision number.
    # Need to update the tag later.
    #
    my $query_result =
	DBQueryWarn("insert into archive_revisions set revision=NULL, ".
		    "  archive_idx='$archive_idx', view='$view', ".
		    "  parent_revision=$parent_revision, ".
		    "  description=$description, ".
		    "  date_created=UNIX_TIMESTAMP(now())") or goto bad;

    my $newrevision = $query_result->insertid;
    my $zipfile     = "$repodir/$newrevision";
    $newtag         = (defined($newtag) ? $newtag : "R${newrevision}");
    
    #
    # Okay, zip up the checkin directory. This becomes a new "revision"
    #
    mysystem("$ZIP $zipopt -y -r $zipfile .") == 0 or goto bad;

    DBQueryWarn("update archive_revisions set ".
		"  tag='$newtag' ".
		"where archive_idx='$archive_idx' and revision='$newrevision'")
	or goto bad;

    # Backwards compat
    DBQueryWarn("insert into archive_tags set idx=NULL, version=$TAGVERSION, ".
		"  tag='$newtag', view='$view', ".
		"  archive_idx='$archive_idx', ".
		"  tagtype='$TAGTYPE_COMMIT', ".
		"  date_created=UNIX_TIMESTAMP(now())")
	or goto bad;

  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    if (defined($newrevision)) {
	DBQueryWarn("delete from archive_revisions ".
		    "where revision='$newrevision' and ".
		    "      archive_idx='$archive_idx'");
    }
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# Also like commit, but just replaces the zip archive file.
#
sub Replace($$$)
{
    my ($self, $oldtag, $view) = @_;
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveReplace: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir   = "$directory/$REPO/$view";
    my $checkin   = "$directory/checkins/$view"; 

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveReplace: Bad data in $cwd!\n";
	goto bad;
    }

    if (! chdir("$checkin")) {
	print STDERR "ArchiveReplace: Cannot chdir to $checkin!\n";
	goto bad;
    }

    my $revision_row = $self->Revision($view, $oldtag);
    if (!defined($revision_row)) {
	print STDERR "ArchiveReplace: Could not find revision for $oldtag!\n";
	goto bad;
    }
    my $revision = $revision_row->{'revision'};
    my $zipfile  = "$repodir/${revision}.zip";
    my $savefile = "$repodir/${revision}.save";

    if (-e $zipfile) {
	# print STDERR "ArchiveReplace: renaming $zipfile to $savefile\n";
if (!rename($zipfile, $savefile)) {
	    print STDERR "ArchiveReplace: Could not backup $zipfile!\n";
	    goto bad;
	}
    }
    
    #
    # Okay, zip up the checkin directory. This becomes a new "revision"
    #
    mysystem("$ZIP $zipopt -y -r $zipfile .") == 0 or goto bad;

  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    if (defined($zipfile) && -e $savefile) {
	if (!rename($savefile, $zipfile)) {
	    print STDERR "ArchiveReplace: Could not restore $zipfile!\n";
	    goto bad;
	}
    }
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# Fork an archive (okay, branch) for use in separate development.
#
sub Fork($$;$$)
{
    my ($self, $newview, $newtag, $view) = @_;
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveFork: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir     = "$directory/$REPO/$view";
    my $newrepodir  = "$directory/$REPO/$newview";
    my $checkouts   = "$directory/checkouts";
    my $checkout    = "$directory/checkouts/$view";
    my $checkin     = "$directory/checkins/$view";
    my $newcheckout = "$directory/checkouts/$newview";
    my $newcheckin  = "$directory/checkins/$newview";

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveFork: Bad data in $cwd!\n";
	goto bad;
    }

    # Get the revision and user tag for the archive/view.
    my $current_tag  = $View->{'current_tag'};
    my $revision     = $View->{'revision'};

    # Not allowed to fork an archive with no revisions
    goto bad
	if (!defined($revision));

    # Create new view directories.
    if (! mkdir("$newrepodir", 0777)) {
	print STDERR "ArchiveFork: Could not mkdir $newrepodir: $!\n";
	goto bad;
    }
    if (! mkdir("$newcheckin", 0777)) {
	print STDERR "ArchiveFork: Could not mkdir $newcheckin: $!\n";
	goto bad;
    }
    if (! chmod(0777, "$newcheckin")) {
	print STDERR "ArchiveFork: Could not chmod $newcheckin: $!\n";
	goto bad;
    }

    #
    # Create a new revision record so I can get the revision number.
    # Need to update the tag later.
    #
    my $query_result =
	DBQueryWarn("insert into archive_revisions set revision=NULL, ".
		    "  archive_idx='$archive_idx', view='$newview', ".
		    "  parent_revision='$revision',".
		    "  description='Archive Fork from $view/$revision', ".
		    "  date_created=UNIX_TIMESTAMP(now())") or goto bad;

    my $newrevision = $query_result->insertid;
    my $newzipfile  = "$newrepodir/${newrevision}.zip";
    my $oldzipfile  = "$repodir/${revision}.zip";
    $newtag         = (defined($newtag) ? $newtag : "R${newrevision}");

    # Make a copy of the zip file; this is probably silly, but at least
    # I know I've got a clean copy later. Revisit this.
    mysystem("/bin/cp -p $oldzipfile $newzipfile") == 0 or goto bad;
    
    # Now enter the newview (okay, branch) of this archive.
    DBQueryWarn("insert into archive_views set ".
		"  archive_idx='$archive_idx', current_tag='$newtag', ".
		"  view='$newview', revision='$newrevision', ".
		"  parent_view='$view', parent_revision='$revision', ".
		"  date_created=UNIX_TIMESTAMP(now())") or goto bad;

    DBQueryWarn("update archive_revisions set ".
		"  tag='$newtag' ".
		"where archive_idx='$archive_idx' and revision='$newrevision'")
	or goto bad;

    # backwards compat
    DBQueryWarn("insert into archive_tags set idx=NULL, version=$TAGVERSION, ".
		"  tag='$newtag', archive_idx='$archive_idx', ".
		"  tagtype='$TAGTYPE_INTERNAL', ".
		"  view='$newview', ".
		"  date_created=UNIX_TIMESTAMP(now())") or goto bad;

  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    if (defined($newrevision)) {
	DBQueryWarn("delete from archive_views ".
		    "where archive_idx='$archive_idx' and view='$newview'");
	DBQueryWarn("delete from archive_tags ".
		    "where archive_idx='$archive_idx' and view='$newview' ".
		    "  and tag='$newtag'");
	DBQueryWarn("delete from archive_revisions ".
		    "where revision='$newrevision' and ".
		    "      archive_idx='$archive_idx'");
    }
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# Checkout a copy of the archive, optionally at a particular view/branch.
#
sub Checkout($$;$$@)
{
    my ($self, $target, $view, $tag, @subdirs) = @_;
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    # Cannot checkout if there are no revisions.
    return -1
	if (!defined($View->{'revision'}));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveCheckout: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir = "$directory/$REPO/$view";

    #
    # We allow target to exist or not exist.
    #
    if (! -e $target) {
	if (! mkdir("$target", 0777)) {
	    print STDERR "ArchiveCheckout: Could not mkdir $target: $!\n";
	    return -1;
	}
	if (! chmod(0777, "$target")) {
	    print STDERR "ArchiveCheckout: ".
		"Could not chmod directory $target: $!\n";
	    return -1;
	}
    }

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveCheckout: Bad data in $cwd!\n";
	goto bad;
    }

    # Where to find what we want.
    my $revision;
    
    if (defined($tag)) {
	my $revision_row = $self->Revision($view, $tag);

	if (!defined($revision_row)) {
	    print STDERR "ArchiveCheckout: ".
		"Could not locate a revision for $view/$tag in $self\n";
	    goto bad;
	}
	$revision = $revision_row->{'revision'};
    }
    else {
	# Trunk, sorta.
	$revision = $View->{'revision'};
    }
    my $zipfile = "$repodir/$revision";

    # Append * to directories.
    for (my $i = 0; $i < scalar(@subdirs); $i++) {
	my $subdir = $subdirs[$i];

	if ($subdir =~ /\/$/) {
	    $subdirs[$i] .= "*";
	}
    }
    
    # Allowed to check out a set of files/dirs
    my $subdir_arg = (! @subdirs ? "" :
		      join(" ", map("'" . $_ . "'", @subdirs)));

    # unzip has a different verbose option.
    my $unzipopt = ($debug ? "" : "-q");

    # Now check it out
    if (my $rval = mysystem("cd $target; ".
			    "$UNZIP $unzipopt -o -u $zipfile $subdir_arg")) {
	# Allow for exit(11) from unzip, which says the requested files
	# where not in the archive. Not really an error.
	goto bad
	    if ($rval >> 8 != 11);
    }

  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# List contents of archive. 
#
sub List($$;$$$$)
{
    my ($self, $prval, $view, $long, $tag, $subdir) = @_;
    my @filelist = ();
    my $cwd;

    return -1
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));
    $long = 0
	if (!defined($long));

    my $View = $self->View($view);
    return -1
	if (!defined($View));

    # Cannot list if there are no revisions.
    return -1
	if (!defined($View->{'revision'}));

    return -1
	if (TBScriptLock("archive_${archive_idx}_${view}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveList: $directory cannot be written!\n";
	goto bad;
    }
    my $repodir = "$directory/$REPO/$view";

    # Need to remember where we came from!
    chomp($cwd = `pwd`);
    # Must do the taint check too.
    if ($cwd =~ /^([-\w\.\/]+)$/) {
	$cwd = $1;
    }
    else {
	print STDERR "ArchiveList: Bad data in $cwd!\n";
	goto bad;
    }

    # Where to find what we want.
    my $revision;
    
    if (defined($tag)) {
	my $revision_row = $self->Revision($view, $tag);

	if (!defined($revision_row)) {
	    print STDERR "ArchiveList: ".
		"Could not locate a revision for $view/$tag in $self\n";
	    goto bad;
	}
	$revision = $revision_row->{'revision'};
    }
    else {
	# Trunk, sorta.
	$revision = $View->{'revision'};
    }
    my $zipfile = "$repodir/$revision";
    
    # Allowed to check out a particular subdir (but not a file).
    $subdir = (defined($subdir) ? "'$subdir/*'" : "");

    # Long or short listing ...
    my $zipinfoopt = ($long ? "-l" : "-1");

    #
    # Start a subprocess that does the listing, and then read it back.
    #
    if (!open(LIST, "$ZIPINFO $zipinfoopt $zipfile $subdir |")) {
	print STDERR "ArchiveList: Could not start $ZIPINFO!\n";
	goto bad;
    }
    while (<LIST>) {
	if (!defined($prval)) {
	    print $_;
	}
	else {
	    chomp($_);
	    push(@filelist, $_);
	}
    }
    goto bad
	if (! close(LIST));

    @$prval = @filelist
	if (defined($prval));
    
  okay:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return 0;

  bad:
    TBScriptUnlock();
    chdir($cwd)
	if (defined($cwd));
    return -1;
}

#
# DU contents of archive repo.
#
sub DU($$)
{
    my ($self, $prval) = @_;
    my $cwd;

    return -1
	if (! ref($self));

    #
    # See if the archive exists and if it does, get the pathname to it.
    #
    my $directory = $self->directory();
    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveList: $directory cannot be written!\n";
	return -1;
    }
    my $repo = "$directory/$REPO";

    #
    # Start a subprocess that does the du, and then read it back.
    #
    if (!open(DU, "$DU -s -k $repo |")) {
	print STDERR "ArchiveDU: Could not start du!\n";
	return -1;
    }
    my $line;
    
    while (<DU>) {
	chomp($_);
	$line = $_;
    }
    return -1
	if (! close(DU));

    if ($line =~ /^(\d+)\s+/) {
	$$prval = $1;
	return 0;
    }
    return -1;
}

#
# Archive the Archive, moving it into the expinfo directory.
# I intend this to be run only when an experiment is terminated.
# No need to have two copies.
#
sub Archive($$)
{
    my ($self, $view) = @_;

    $view = $defaultview
	if (!defined($view));

    return -1
	if (! ref($self));

    my $archive_idx  = $self->idx();
    my $target       = "$ARCHIVEDIR/Archive/$archive_idx";
    my $directory    = $self->directory();
    
    return -1
	if (TBScriptLock("archive_${archive_idx}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # Need additional check to make sure that it has not already been
    # archived.
    #
    if ($self->archived()) {
	print STDERR "ArchiveArchive: ".
	    "Archive $self already archived on ". $self->date_archived() ."\n";
	goto okay;
    }

    if (! -d $directory || ! -w $directory) {
	print STDERR "ArchiveArchive: $directory cannot be written!\n";
	goto bad;
    }

    # Is it shared? If so, certainly do not archive it!
    my $shared = $self->IsShared();
    if (! defined($shared)) {
	goto bad;
    }
    if ($shared) {
	print STDERR "ArchiveArchive: ".
	    "Archive '$archive_idx' is shared; not archiving!\n";

	#
	# Even if shared, we want to clean out the current view since
	# those files are no longer needed.
	#
	my $checkouts = "$directory/checkouts/$view";
	my $checkins  = "$directory/checkins/$view";

	#
	# If the target dir exists and is not writable by the current
	# user, then run a chown over the whole subdir. This will avoid
	# avoid permission problems during the rm.
	#
	if (-e "$checkouts" && ! -o "$checkouts") {
	    mysystem("$SUCHOWN $checkouts");
	}
	if (-e "$checkins" && ! -o "$checkins") {
	    mysystem("$SUCHOWN $checkins");
	}
	mysystem("/bin/rm -rf $checkins $checkouts");
	goto okay;
    }
    
    if (! -e $target) {
	if (! mkdir("$target", 0777)) {
	    print STDERR "ArchiveArchive: Could not mkdir $target: $!\n";
	    goto bad;
	}
	if (! chmod(0777, "$target")) {
	    print STDERR "ArchiveArchive: ".
		"Could not chmod directory $target: $!\n";
	    goto bad;
	}
    }    
    mysystem("$RSYNC -a --delete $directory/$REPO $target");
    if ($?) {
	print STDERR "ArchiveArchive: Could not copy $directory/$REPO.\n";
	goto bad;
    }

    #
    # Update its location in the DB, and remove the old directory.
    # 
    DBQueryWarn("update archives set ".
		"   directory='$target', ".
		"   archived=1, ".
		"   date_archived=UNIX_TIMESTAMP(now()) ".
		"where idx='$archive_idx'")
	or goto bad;
    
    mysystem("/bin/rm -rf $directory");
    if ($?) {
	print STDERR "ArchiveArchive: ".
	    "Could not remove contents of $directory!\n";
	goto bad;
    }

  okay:
    TBScriptUnlock();
    return 0;

  bad:
    TBScriptUnlock();
    return -1;
}

#
# Destroy an archive. The DB state is retained unless optional flag says
# to clean it.
#
sub Destroy($$;$$)
{
    my ($self, $clean, $view, $force) = @_;

    $view = $defaultview
	if (!defined($view));
    $force = 0
	if (!defined($force));

    return -1
	if (! ref($self));

    my $archive_idx  = $self->idx();
    my $directory    = $self->directory();
    
    return -1
	if (TBScriptLock("archive_${archive_idx}", 0, 600) !=
	    TBSCRIPTLOCK_OKAY());

    #
    # Need additional check to make sure that it has not already been
    # archived. Do not want to do anything, unless clean is specified.
    #
    if ($self->archived() && !$force) {
	print STDERR "ArchiveArchive: ".
	    "Archive $self archived on ". $self->date_archived() ."\n";
	goto okay;
    }
    if (! -d $directory || ! -w $directory) {
	goto okay;
    }

    # Is it shared? If so, certainly do not delete it!
    my $shared = $self->IsShared();
    if (! defined($shared)) {
	goto bad;
    }
    if (!$shared || $force) {
	mysystem("/bin/rm -rf $directory");
	if ($?) {
	    print STDERR "ArchiveDestroy: ".
		"Could not remove contents of $directory!\n";
	    goto bad;
	}
    }
    elsif ($clean) {
	my $checkout  = "$directory/checkouts/$view";
	my $checkin   = "$directory/checkins/$view";
	my $repodir   = "$directory/$REPO/$view";

	mysystem("/bin/rm -rf $checkout $checkin");
	if ($?) {
	    print STDERR "ArchiveDestroy: ".
		"Could not remove contents of $directory!\n";
	    goto bad;
	}
    }
    
    if ($clean) {
	(DBQueryWarn("delete from archive_tags ".
		     "where archive_idx='$archive_idx' and view='$view'") &&
	 DBQueryWarn("delete from archive_views ".
		     "where archive_idx='$archive_idx' and view='$view'") &&
	 DBQueryWarn("delete from archive_revisions ".
		     "where archive_idx='$archive_idx' and view='$view'"))
	    || goto bad;
	
	if (! $shared) {
	    DBQueryWarn("delete from archives ".
			"where idx='$archive_idx'") || goto bad;
	}
    }
  okay:
    TBScriptUnlock();
    return 0;

  bad:
    TBScriptUnlock();
    return -1;
}

#
# See if the archive is shared amongst more then one experiment. This
# only looks at current experiments. Once an archive is archived, not
# sure what we will do if the user want to branch from it. 
#
sub IsShared($)
{
    my ($self) = @_;

    my $idx = $self->idx();
    
    my $query_result =
	DBQueryWarn("select e.pid,e.eid,s.archive_idx from experiments as e ".
		    "left join experiment_stats as s on s.exptidx=e.idx ".
		    "where s.archive_idx='$idx'");

    return undef
	if (!$query_result);

    return ($query_result->numrows > 1);
}

#
# See if a tag is unique to the archive.
#
sub IsTagUnique($$;$)
{
    my ($self, $tag, $view) = @_;
    
    $view = $defaultview
	if (!defined($view));

    my $idx = $self->idx();

    my $query_result =
	DBQueryWarn("select revision from archive_revisions ".
		    "where archive_idx='$idx' and ".
		    "      view='$view' and tag='$tag'");
    return undef
	if (!$query_result);

    return ($query_result->numrows == 0);
}

#
# Generate a tag. Nothing special, just a convenience function.
#
sub GenerateTag($$)
{
    my ($self, $tagext) = @_;
    my $newtag;
    
    my ($seconds, $microseconds) = gettimeofday();
    $newtag  = POSIX::strftime("T20%y%m%d-%H%M%S-", localtime());
    $newtag .= int($microseconds / 1000);
    $newtag .= "_${tagext}";

    return $newtag;
}

#
# Return pointer to zip archive file.
#
sub ZipFile($;$$)
{
    my ($self, $view, $tag) = @_;

    return undef
	if (! ref($self));
    my $archive_idx  = $self->idx();

    $view = $defaultview
	if (!defined($view));

    my $View = $self->View($view);
    return undef
	if (!defined($View));

    # Cannot list if there are no revisions.
    return undef
	if (!defined($View->{'revision'}));

    my $directory = $self->directory();
    my $repodir   = "$directory/$REPO/$view";

    # Where to find what we want.
    my $revision;
    
    if (defined($tag)) {
	my $revision_row = $self->Revision($view, $tag);

	if (!defined($revision_row)) {
	    print STDERR "ArchiveList: ".
		"Could not locate a revision for $view/$tag in $self\n";
	    return undef;
	}
	$revision = $revision_row->{'revision'};
    }
    else {
	# Trunk, sorta.
	$revision = $View->{'revision'};
    }
    return "$repodir/${revision}.zip";
}


# _Always_ make sure that this 1 is at the end of the file...
1;
