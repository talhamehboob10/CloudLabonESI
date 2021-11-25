#!/usr/bin/perl -wT
#
# Copyright (c) 2007-2020 University of Utah and the Flux Group.
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
package OSImage;

use strict;
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use Exporter;
use vars qw(@ISA @EXPORT $AUTOLOAD %IMAGE_ARCHITECTURES);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use libdb;
use EmulabConstants;
use libtestbed;
use Image;
use NodeType;
use OSinfo;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		  = "/users/mshobana/emulab-devel/build";
my $BOSSNODE      = "boss.cloudlab.umass.edu";
my $CONTROL	  = "ops.cloudlab.umass.edu";
my $TBOPS         = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBAUDIT       = "testbed-audit\@ops.cloudlab.umass.edu";
my $TBBASE        = "https://www.cloudlab.umass.edu";
my $WWWHOST       = "www.cloudlab.umass.edu";
my $OURDOMAIN     = "cloudlab.umass.edu";
my $PGENISUPPORT  = 1;
my $DOPROVENANCE  = 1;
my $TBWWW         = "<https://www.cloudlab.umass.edu/>";

#
# Valid architectures. Short list.
#
%IMAGE_ARCHITECTURES = (
    "i386"    => "i386",
    "x86_64"  => "x86_64",
    "aarch64" => "aarch64",
    "ppc64le" => "ppc64le",
);

# Cache of instances to avoid regenerating them.
my $debug      = 0;

#
# Lookup by idx or pid,imagename[:version] depending on the args. We always 
# return highest numbered version on this path, if no version specified.
#
sub Lookup($$;$$)
{
    my ($class, $arg1, $arg2, $arg3) = @_;
    my $token = "$arg1";
    $token .= ",$arg2" if (defined($arg2));
    $token .= ",$arg3" if (defined($arg3));

    #
    # See if an image alias first.
    #
    if (!defined($arg3)) {
	my $image = OSImageAlias->Lookup($arg1, $arg2);
	return $image
	    if (defined($image));
    }

    #
    # First do the image table lookup. If we find it there, we can look
    # for the osinfo. If we do not find it, it might still be an MFS
    # which has just the osinfo.
    #
    my $image = Image->Lookup($arg1, $arg2, $arg3);

    #
    # If this is a dataset, then there is no osinfo. It is convenient
    # to allow this to work, just return the underlying image. The
    # caller always knows it is messing with a dataset.
    #
    if (defined($image) && $image->isdataset()) {
	return $image;
    }

    #
    # We only support single OS, EZID images now.
    # MFSs are osinfo objects with no image, that is okay too.
    # Generic Images are osinfo objects that point to another (nextosid).
    #
    my $osinfo;
    if (!defined($image)) {
	$osinfo = OSinfo->Lookup($arg1, $arg2, $arg3);
	if (defined($osinfo)) {
	    if (! ($osinfo->mfs() || $osinfo->IsGeneric())) {
		if (0) {
		    print STDERR
			"OSImage::Lookup($token) is not an EZID or MFS image\n";
		}
	    }
	}
	else {
	    if (0) {
		print STDERR "OSImage::Lookup($token) does not exist\n";
	    }
	    return undef;
	}
    }
    else {
	$osinfo = OSinfo->Lookup($image->imageid(), $image->version());
	#
	#
	#
	if (!defined($osinfo)) {
	    $osinfo = OSinfo->Lookup($image->pid(),
				     $image->imagename(), $image->version());
	}
    }
    if (!defined($osinfo)) {
	print STDERR "OSImage::Lookup($token): There is no OSinfo for $image\n";
	return undef;
    }
    my $self = {};
    $self->{'OSINFO'} = $osinfo;
    $self->{'IMAGE'}  = $image;
    $self->{'HASH'}   = {};    
    bless($self, $class);
    
    return $self;
}
sub image($)		{ return $_[0]->{'IMAGE'}; }
sub osinfo($)		{ return $_[0]->{'OSINFO'}; }
sub temphash($)		{ return $_[0]->{'HASH'}; }
sub isImage($)          { return defined($_[0]->image()) ? 1 : 0; }
sub isImageAlias($)	{ return 0; }

# Break circular references to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'IMAGE'}  = undef;
    $self->{'OSINFO'} = undef;
    $self->{'HASH'}   = undef;
}

sub Stringify($)
{
    my ($self) = @_;
    my $pid = $self->pid();
    
    if (defined($self->image())) {
	my $imageid   = $self->image()->imageid();
	my $version   = $self->image()->version();
	my $imagename = $self->image()->imagename();

	return "[OSImage $pid,$imagename $imageid:$version]";
    }
    else {
	my $tag    = $self->osinfo()->mfs() ? "MFS" : "Generic";
	my $osid   = $self->osinfo()->osid();
	my $osname = $self->osinfo()->osname();
	
	return "[$tag $pid,$osname $osid]";
    }
}

AUTOLOAD {
    my $self  = $_[0];
    my $type  = ref($self) or croak "$self is not an object";
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    #
    # There is overlap in names between Image and OSinfo. All of those can
    # come from the Images table, except this conflict. In the OSinfo table
    # it is a version string from the OS, but otherwise it is the version
    # of the Image.
    #
    if ($name eq "osversion") {
	return $self->osinfo()->field("version");
    }
    #
    # Check the images table. Might be an MFS ...
    #
    if (defined($self->image()) && $self->image()->fieldExists($name)) {
	# Allow update.
	if (scalar(@_) == 2) {
	    $self->image()->fieldSet($name, $_[1]);
	}
	return $self->image()->field($name);
    }
    
    #
    # If it is not in the Images table, look in the OSinfo for it. But some
    # of these names should no longer be used, I am going to flag these for
    # warnings.
    #
    if ($self->osinfo()->fieldExists($name)) {
	my %osinfo_warn = (
	    "vers"	    => 1,
	    "parent_osid"   => 1,
	    "parent_vers"   => 1,
	    "uuid"          => 1,
	    "old_osid"      => 1,
	    "osname"        => 1,
	);
	return $self->osinfo()->field($name);
    }
    
    # Or it is for a local storage slot. We use the image hash until
    # sure we have all the code changed. 
    if ($name =~ /^_.*$/) {
	if (scalar(@_) == 2) {
	    return $self->image()->{'HASH'}->{$name} = $_[1];
	}
	elsif (exists($self->image()->{'HASH'}->{$name})) {
	    return $self->image()->{'HASH'}->{$name};
	}
    }
    carp("No such slot '$name' field in class $type");
    return undef;
}
sub field($$) {
    my ($self, $name) = @_;

    if ($self->image()->fieldExists($name)) {
	return $self->image()->field($name);
    }
    return undef;
}

#
# Lookup by URL.
#
sub LookupByURL($$)
{
    my ($class, $url) = @_;

    my $image = Image->LookupByURL($url);
    return undef
	if (!defined($image));

    return OSImage->Lookup($image->imageid(), $image->version());
}

# Image is local if the metadata_url is null.
sub IsLocal($)
{
    return $_[0]->image()->IsLocal();
}

#
# Lookup a "system" osid, meaning one in the emulab-ops project.
#
sub LookupByName($$)
{
    my ($class, $imagename) = @_;

    #
    # Look for an image alias first.
    #
    my $image = OSImageAlias->LookupByName($imagename);
    return $image
	if (defined($image));

    $image = Image->LookupByName($imagename);
    if (!defined($image)) {
	my $osinfo = OSinfo->LookupByName($imagename);
	return undef
	    if (!defined($osinfo));

	return OSImage->Lookup($osinfo->osid(), $osinfo->vers());
    }
    return OSImage->Lookup($image->imageid(), $image->version());
}

#
# Lookup by Origin UUID.
#
sub LookupByOriginUUID($$$)
{
    my ($class, $pid, $uuid) = @_;

    my $image = Image->LookupByOriginUUID($pid, $uuid);
    return undef
	if (!defined($image));

    return OSImage->Lookup($image->imageid(), $image->version());
}

#
# Lookup by Origin URN.
#
sub LookupByOriginURN($$)
{
    my ($class, $urn) = @_;

    my $image = Image->LookupByOriginURN($urn);
    return undef
	if (!defined($image));

    return OSImage->Lookup($image->imageid(), $image->version());
}

#
# Lookup by Authority URN. Only for datasets right now.
#
sub LookupByAuthorityURN($$)
{
    my ($class, $urn) = @_;
    my $image = Image->LookupByAuthorityURN($urn);
    return undef
	if (!defined($image));

    return OSImage->Lookup($image->imageid(), $image->version());
}

sub versid($)
{
    return $_[0]->image()->versid();
}
sub versname($)
{
    return $_[0]->image()->versname();
}
sub urn($)
{
    return $_[0]->image()->urn();
}

#
# Global is odd. If an image, we use that slot. If just an OSinfo, we
# use shared.
#
sub global($)
{
    my ($self) = @_;

    return $self->image()->global()
	if (defined($self->image()));
    
    return $self->osinfo()->shared();
}

#
# Version is a bit of a pain. version() in OSinfo is an OS string we rarely
# care about (IsGeneric() does). vers() is the actual version. Normally this
# does not matter, but if the OSImage is encapsulating an OSinfo without
# an Image (which happens, think MFS), then version() will get the wrong
# thing (from the osinfo instead of the image).
#
sub version()
{
    my ($self) = @_;

    return $self->image()->version()
	if (defined($self->image()));

    return $self->osinfo()->vers();
}

#
# Return a list of all images of the given format for the given pid.
# If format is NULL, return all formats. If pid is NULL, return for all pids.
# List is names of the form "pid/imagename".
#
sub ListAll($$$)
{
    return Image->ListAll($_[1], $_[2]);
}

#
# Return a list of all versions of all images of the given format for the
# given pid.
#
# If format is NULL, return all formats. If pid is NULL, return for all pids.
# List is names of the form "pid/imagename:version".
#
sub ListAllVersions($$$)
{
    return Image->ListAllVersions($_[1], $_[2]);
}

#
# Refresh instance by reloading from the DB.
#
sub Refresh($)
{
    return -1
	if ($_[0]->image()->Refresh() || $_[0]->osinfo()->Refresh());
    
    return 0;
}

#
# Clone an image descriptor from the DB, bumping the version number
#
sub NewVersion($@)
{
    my ($self, @args) = @_;

    my $image = $self->image()->NewVersion(@args);
    return undef
	if (!defined($image));
    
    return OSImage->Lookup($image->imageid(), $image->version());
}

#
# For a newly created image, set the provenance pointers back to
# the image from which it was derived.
#
sub SetProvenance($$)
{
    my ($self, $base) = @_;

    return -1
	if ($self->image()->SetProvenance($base->image()) ||
	    $self->osinfo()->SetProvenance($base->osinfo()));

    return 0;
}

sub SetDescription($$)
{
    my ($self, $description) = @_;
    my $args = {"description" => $description};

    return -1
	if ($self->image()->Update($args) ||
	    $self->osinfo()->Update($args));

    return 0;
}

#
# Highest number version, rather then what is deemed most recent by the
# images table.
#
sub LookupMostRecent($)
{
    my ($self) = @_;
    my $image  = $self->image()->LookupMostRecent();
    return undef
	if (!defined($image));
    return OSImage->Lookup($image->imageid(), $image->version());
}

#
# Return a list of all image versions.
#
sub AllVersions($$;$)
{
    my ($self, $pref, $deleted)  = @_;
    my $imageid = $self->image()->imageid();
    my @images  = ();
    my @result  = ();

    return -1
	if ($self->image()->AllVersions(\@images, $deleted));

    foreach my $image (@images) {
	my $version = $image->version();
	my $tmp = OSImage->Lookup($imageid, $version);
	if (!defined($tmp)) {
	    print STDERR "Could not lookup image $imageid,$version\n";
	    return -1;
	}
	push(@result, $tmp);
    }
    @$pref = @result;
    return 0;
}

#
# Release an image; all this does is make the highest numbered version
# in the image_versions table, the default version. It does this by
# updating the version number in the images table. An unreleased version
# can be used by explicitly giving the version number, but unqualified
# use always get the version that is set in the images table. 
#
sub Release($)
{
    return $_[0]->image()->Release();
}

#
# Worker class method to edit image descriptor.
# Assumes most argument checking was done elsewhere.
#
sub EditImageid($$$$)
{
    my ($class, $image, $argref, $usrerr_ref) = @_;

    return Image->EditImageid($image, $argref, $usrerr_ref);
}

#
# Return the internal DB rowref. Used for code that has not been converted.
#
sub DBData($)
{
    croak("OSImage::DBData($_[0])");
}

#
# Perform some updates ... We have to watch for updates to either the
# the underlying image or the osinfo, and redirect to the right place.
# Error if a mixed update (should not happen).
#
sub Update($;$)
{
    my ($self, $argref, $allvers) = @_;
    my $forimage  = 0;
    my $forosinfo = 0;

    foreach my $name (keys(%{ $argref })) {
	if (defined($self->image()) &&
	    $self->image()->fieldExists($name)) {
	    $forimage = 1;
	}
	elsif (defined($self->osinfo()) &&
	       $self->osinfo()->fieldExists($name)) {
	    $forosinfo = 1;
	}
    }
    if ($forimage && $forosinfo) {
	cluck("OSImage::Update: update for both image and osinfo");
	return -1;
    }
    elsif (! ($forimage || $forosinfo)) {
	cluck("OSImage::Update: update for neither image or osinfo");
	return -1;
    }
    elsif ($forimage) {
	return $self->image()->Update($argref, $allvers);
    }
    else {
	return $self->osinfo()->Update($argref, $allvers);
    }
}

#
# Delete an image,
#
sub Delete($;$)
{
    my ($self, $purge) = @_;

    return $self->image()->Delete($purge);
}

#
# Delete a version of an image. This is not to be used, except when there
# is an error during clone, and we want to undo the creation of a new version.
#
sub DeleteVersion($)
{
    my ($self) = @_;

    return $self->image()->DeleteVersion();
}
sub PurgeVersion($)
{
    my ($self) = @_;

    return $self->image()->PurgeVersion();
}

#
# Load the project object for an image
#
sub GetProject($)
{
    my ($self) = @_;

    return $self->image()->GetProject();
}

#
# Load the user object for an image
#
sub GetCreator($)
{
    my ($self) = @_;

    return $self->image()->GetCreator();
}
sub GetUpdater($)
{
    my ($self) = @_;

    return $self->image()->GetUpdater();
}

#
# Load the group object for an image
#
sub GetGroup($)
{
    my ($self) = @_;

    return $self->image()->GetGroup();
}

#
# Check permissions. Note that root may ask permission, which comes in
# as an undef user.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;

    return $self->image()->AccessCheck($user, $access_type);
}

#
# LockTables simply locks the given tables, and then refreshes the
# instance (thereby getting the data from the DB after the tables are locked).
#
sub LockTables($;$)
{
    my ($self, $spec) = @_;

    return $self->image()->LockTables($spec);
}
sub UnLockTables($)
{
    my ($self) = @_;

    return $self->image()->UnLockTables($self);
}

#
# Get the disk offset at which the image will be loaded.
# For a "whole disk" (loadpart == 0) image, it is always 0.
# For a "partition" image, it depends on the MBR type of the image.
#
# Returns -1 if the offset could not be determined (e.g., unknown MBR).
#
sub GetDiskOffset($)
{
    my ($self) = @_;

    return $self->image()->GetDiskOffset();
}

sub PartitionSize($)
{
    my ($self) = @_;

    return $self->image()->PartitionSize();
}
sub Chunks($)
{
    my ($self) = @_;

    return $self->image()->Chunks();
}

#
# Return updated time for image as a UNIX timestamp via the passed ref.
# Return 0 on success, non-zero otherwise.
#
sub GetCreate($$)
{
    my ($self,$stampp) = @_;

    return $self->image()->GetCreate($stampp);
}

#
# Return updated time for image as a UNIX timestamp via the passed ref.
# Return 0 on success, non-zero otherwise.
#
sub GetUpdate($$)
{
    my ($self,$stampp) = @_;

    return $self->image()->GetUpdate($stampp);
}

#
# Mark the update time in the record,
#
sub MarkUpdate($$;$)
{
    my ($self, $user, $stamp) = @_;

    return $self->image()->MarkUpdate($user, $stamp);
}

sub MarkDeleted($;$)
{
    my ($self, $stamp) = @_;

    return $self->image()->MarkDeleted($stamp);
}

#
# Mark the IMS update time in the record,
#
sub MarkIMSReported($)
{
    my ($self) = @_;

    return $self->image()->MarkIMSReported();
}
sub ClearIMSReported($)
{
    my ($self) = @_;

    return $self->image()->ClearIMSReported();
}
sub SetIMSNoReport($$)
{
    my ($self, $onoff) = @_;

    return $self->image()->SetIMSNoReport($onoff);
}

#
# Set the hash.
#
sub SetFullHash($$)
{
    my ($self, $hash) = @_;

    return $self->image()->Update({"hash" => $hash});
}
sub SetDeltaHash($$)
{
    my ($self, $hash) = @_;

    return $self->image()->Update({"deltahash" => $hash});
}

#
# Set the size.
#
sub SetFullSize($$)
{
    my ($self, $size) = @_;

    return $self->image()->Update({"size" => $size});
}
sub SetDeltaSize($$)
{
    my ($self, $size) = @_;

    return $self->image()->Update({"deltasize" => $size});
}

sub SetUploaderPath($$)
{
    my ($self, $path) = @_;

    return $self->image()->Update({"uploader_path" => $path});
}
sub ClearUploaderPath($)
{
    my ($self) = @_;

    return $self->image()->Update({"uploader_path" => ''});
}
sub ClearUploaderStatus($)
{
    my ($self) = @_;

    return $self->image()->Update({"uploader_status" => undef});
}

#
# Set the sector range of an image.
# Note that lba_size and reloc flag are left alone unless explicitly specified.
#
sub SetRange($$$;$$)
{
    my ($self,$start,$end,$ssize,$isreloc) = @_;

    return $self->image()->SetRange($start,$end,$ssize,$isreloc);
}

# WebTask
sub SetWebTask($$)
{
    my ($self,$webtask) = @_;

    return $self->image()->SetWebTask($webtask);
}
sub ClearWebTask($)
{
    my ($self) = @_;

    return $self->image()->ClearWebTask();
}

#
# Lock and Unlock. We lock the entire chain (all versions) of the
# image. 
#
sub Lock($)
{
    my ($self) = @_;

    return $self->image()->Lock();
}

sub Unlock($)
{
    my ($self) = @_;

    return $self->image()->Unlock();
}

sub GotLock($)
{
    my ($self) = @_;

    return $self->image()->GotLock();
}

sub TakeLock($)
{
    my ($self) = @_;

    return $self->image()->TakeLock();
}

#
# Wait to get lock.
#
sub WaitLock($$)
{
    my ($self, $seconds) = @_;

    return $self->image()->WaitLock($seconds);
}

#
# Get the type list.
#
sub TypeList($;$)
{
    my ($self, $osinfo) = @_;

    #
    # Since there are no longer any multi osid images or non-ezid images,
    # we do not need the osinfo that was passed in (from legacy code). We
    # return the type list for the image. 
    #
    return $self->image()->TypeList();
}

#
# Grant/Revoke permission to access an image.
#
sub GrantAccess($$$)
{
    my ($self, $target, $writable) = @_;

    return $self->image()->GrantAccess($target, $writable);
}

sub LookupAccess($$$$)
{
    my ($self, $target, $paccess, $pwriteable) = @_;

    return $self->image()->LookupAccess($target, $paccess, $pwriteable);
}

sub RevokeAccess($$)
{
    my ($self, $target) = @_;

    return $self->image()->RevokeAccess($target);
}

#
# Class method to record image history info. 
#
sub RecordImageHistory($$$$$$)
{
    my ($class, $experiment, $action, $log_session, $impotent, $noderef) = @_;

    return Image->RecordImageHistory($experiment, $action,
				     $log_session, $impotent, $noderef);
}

#
# Record more concise success/failure of an image each time it boots.
#
sub RecordImageStatus($$$$)
{
    my ($self, $experiment, $node, $status) = @_;

    return $self->image()->RecordImageStatus($experiment, $node, $status);
}

#
# List of images created by a user urn.
#
sub ListForURN($$)
{
    my ($class, $urn) = @_;
    my @result  = ();

    return undef
	if (! $PGENISUPPORT);

    require GeniHRN;
    return ()
	if (! GeniHRN::IsValid($urn));

    my @images = Image->ListForURN($urn);
    
    foreach my $image (@images) {
	my $imageid = $image->imageid();
	my $version = $image->version();
	my $tmp = OSImage->Lookup($imageid, $version);
	if (!defined($tmp)) {
	    print STDERR "Could not lookup image $imageid,$version\n";
	    return -1;
	}
	push(@result, $tmp);
    }
    return @result;
}

#
# List of images in a project/group
#
sub ListForGroup($$)
{
    my ($class, $group) = @_;
    my @result  = ();

    my @images = Image->ListForGroup($group);
    
    foreach my $image (@images) {
	my $imageid = $image->imageid();
	my $version = $image->version();
	my $tmp = OSImage->Lookup($imageid, $version);
	if (!defined($tmp)) {
	    print STDERR "Could not lookup image $imageid,$version\n";
	    next;
	}
	push(@result, $tmp);
    }
    return @result;
}

#
# Set to use the logfile. It becomes the "current" spew.
#
sub SetLogFile($$)
{
    my ($self, $logfile) = @_;

    return $self->image()->SetLogFile($logfile);
}

# Ready bit.
sub SetReady($$)
{
    my ($self, $ready) = @_;

    return $self->image()->SetReady($ready);
}
sub MarkReady($)   { return SetReady($_[0], 1); }
sub ClearReady($) { return SetReady($_[0], 0); }
# Released bit.
sub MarkReleased($)
{
    my ($self) = @_;

    return $self->image()->MarkReleased();
}
# Last used, for datasets.
sub BumpLastUsed($)
{
    my ($self) = @_;
    
    return $self->image()->BumpLastUsed();
}

# Are two images the same.
sub SameImage($$)
{
    my ($this, $that) = @_;

    return (($this->image()->imageid() == $that->image()->imageid() &&
	     $this->image()->version() == $that->image()->version()) ? 1 : 0);
}

#
# Get the logfile.
#
sub GetLogFile($)
{
    my ($self) = @_;

    return $self->image()->GetLogFile();
}

#
# And clear it ...
#
sub ClearLogFile($)
{
    my ($self) = @_;

    return $self->image()->ClearLogFile();
}

#
# Mark an image as running on a type. I am assuming EZ images these days.
#
sub SetRunsOnNodeType($$)
{
    my ($self, $type) = @_;

    return 0
	if (!defined($self->image()));

    return $self->image()->SetRunsOnNodeType($type);
}

#
# If using the image tracker, have to notify the IMS.
#
sub SchedIMSDeletion($$)
{
    my ($self,$allversions) = @_;

    return $self->image()->SchedIMSDeletion($allversions);
}

#
# Is the image the newest version of the image.
#
sub IsNewest($)
{
    my ($self) = @_;

    return $self->image()->IsNewest();
}

#
# Grab webtask from image.
#
sub webtask($)
{
    my ($self) = @_;

    return $self->image()->webtask();
}

#
# Grab parent of an image, or undef if there is no parent. The
# parent might be an earlier revision or it might be another
# image.
#
sub Parent($)
{
    my ($self) = @_;

    return undef
	if (!defined($self->image()->parent_imageid()));

    return OSImage->Lookup($self->image()->parent_imageid(),
			   $self->image()->parent_version());
}

sub SetDelta($$)
{
    my ($self, $delta) = @_;

    return $self->image()->SetDelta($delta);
}

sub SetSize($$)
{
    my ($self, $size) = @_;

    return $self->image()->SetSize($size);
}

sub SetHash($$)
{
    my ($self, $hash) = @_;

    return $self->image()->SetHash($hash);
}

sub SetNoVersioning($$)
{
    my ($self, $value) = @_;

    return $self->image()->SetNoVersioning($value);
}

sub SetImageRelocateURN($$)
{
    my ($self, $url) = @_;

    return $self->image()->SetImageRelocateURN($url);
}

sub SetImageMetadataURL($$)
{
    my ($self, $url) = @_;

    return $self->image()->SetImageMetadataURL($url);
}

sub SetListed($$)
{
    my ($self, $onoff) = @_;

    return $self->image()->SetListed($onoff);
}

sub SetFormat($$)
{
    my ($self, $format) = @_;

    return $self->image()->SetFormat($format);
}

sub SetPath($$)
{
    my ($self, $path) = @_;

    return $self->image()->SetPath($path);
}

sub LocalURL($)
{
    my ($self) = @_;

    return $self->image()->LocalURL();
}

sub LocalVersionURL($)
{
    my ($self) = @_;
    
    return $self->image()->LocalVersionURL();
}

sub HasCredential($)
{
    my ($self) = @_;

    return $self->image()->HasCredential();
}
sub GetCredential($)
{
    my ($self) = @_;

    return $self->image()->GetCredential();
}
sub SetCredential($$)
{
    my ($self, $credstr) = @_;

    return $self->image()->SetCredential($credstr);
}

#
# Path and Directory stuff.
#
# Images are stored as directories now. Inside the directory are base
# and delta images for each version, as well as sig and sha1 files. 
#
sub IsDirPath($)
{
    my ($self) = @_;

    return $self->image()->IsDirPath();    
}
sub FullImagePath($)
{
    my ($self) = @_;

    return $self->image()->FullImagePath();
}
sub DeltaImagePath($)
{
    my ($self) = @_;

    return $self->image()->DeltaImagePath();
}
sub FullImageFile($)
{
    my ($self) = @_;
    return $self->FullImagePath();
}
sub DeltaImageFile($)
{
    my ($self) = @_;
    return $self->DeltaImagePath();
}
sub TempImageFile($)
{
    my ($self) = @_;

    return $self->image()->TempImageFile();
}
sub FullImageSHA1File($)
{
    my ($self) = @_;

    return $self->image()->FullImageSHA1File();
}
sub DeltaImageSHA1File($)
{
    my ($self) = @_;

    return $self->image()->DeltaImageSHA1File();
}
sub FullImageSigFile($)
{
    my ($self) = @_;

    return $self->image()->FullImageSigFile();
}
sub DeltaImageSigFile($)
{
    my ($self) = @_;

    return $self->image()->DeltaImageSigFile();
}
sub HaveFullImage($)
{
    my ($self) = @_;

    return $self->image()->HaveFullImage();
}
sub HaveDeltaImage($)
{
    my ($self) = @_;

    return $self->image()->HaveDeltaImage();
}
sub CreateImageDir($)
{
    my ($self) = @_;

    return $self->image()->CreateImageDir();
}
sub DeleteImageDir($)
{
    my ($self) = @_;

    return $self->image()->DeleteImageDir();
}
sub SaveDir($)
{
    my ($self) = @_;

    return $self->image()->SaveDir();
}
sub IsSystemImage($)
{
    my ($self) = @_;

    return $self->image()->IsSystemImage();
}

sub Deprecate($;$$)
{
    my ($self,$message,$iserror) = @_;

    return $self->image()->Deprecate($message, $iserror);
}
sub IsDeprecated($$;$$)
{
    my ($self,$val,$message,$iserror) = @_;

    return $self->image()->IsDeprecated($val, $message, $iserror);
}
sub DeprecatedMessage($;$)
{
    my ($self, $experiment) = @_;

    return $self->image()->DeprecatedMessage($experiment);
}
sub SendDeprecatedMail($$;$)
{
    my ($self, $user, $experiment) = @_;

    return $self->image()->SendDeprecatedMail($user, $experiment);
}

################################################################################
# This is the stuff from OSinfo.pm
################################################################################

#
# Map an osinfo and node type to the actual image.
#
sub MapToImage($$)
{
    my ($self, $type) = @_;

    #
    # If we are using architectures this is not necessary. In fact, since
    # we do not do multi-os images, I think we can flush it completely.
    #
    if (!ref($type)) {
	my $nodetype = NodeType->Lookup($type);
	if (!defined($nodetype)) {
	    print STDERR "Could not map $type to an object\n";
	    return undef;
	}
	$type = $nodetype;
    }
    return $self
	if ($self->isImage() &&
	    $self->architecture() && $type->architecture());
    
    # This returns an OSimage.
    return $self->osinfo()->MapToImage($type);
}

#
# Resolve a 'generic' OSID (ie. FBSD-STD) to a real OSID
#
# Note: It's okay to call this function with a 'real' OSID, but it would be
# waseful to do so.
#
# returns: The 'real' OSID that the OSID resolves to, or undef if there is a
#          problem (ie. unknown OSID)
#
sub ResolveNextOSID($;$)
{
    my ($self, $experiment) = @_;

    my $osinfo = $self->osinfo()->ResolveNextOSID($experiment);
    return undef
	if (!defined($osinfo));

    return OSImage->Lookup($osinfo->osid(), $osinfo->vers());
}

#
# Lookup newest version of osinfo.
#
sub LookupNewest($)
{
    my ($self) = @_;

    return $self->LookupMostRecent();
}

#
# Default reboot time. Class method.
#
sub RebootWaitTime($$)
{
    my ($class, $os) = @_;

    return OSinfo->RebootWaitTime($os);
}

#
# Class method to check the OS is legal.
#
sub ValidOS($$)
{
    my ($class, $os) = @_;

    return OSinfo->RebootWaitTime($os);
}

#
# Class method to check the OPmode is legal.
#
sub ValidOpMode($$)
{
    my ($class, $opmode) = @_;

    return OSinfo->ValidOpMode($opmode);
}

#
# Is the osinfo "generic"
#
sub IsGeneric($)
{
    my ($self)  = @_;

    return $self->osinfo()->IsGeneric();
}

sub IsNfsMfs($)
{
    my ($self)  = @_;

    return $self->osinfo()->IsNfsMfs();
}

#
# Boot command line. The caller supplies the default in $pref.
#
sub OSBootCmd($$$)
{
    my ($self, $role, $pref) = @_;

    return $self->osinfo()->OSBootCmd($role, $pref);
}

#
# Set the nextosid.
#
sub SetNextOS($$)
{
    my ($self, $nextosinfo) = @_;

    return $self->osinfo()->SetNextOS($nextosinfo);
}

sub SetParentOS($$)
{
    my ($self, $parent) = @_;

    return $self->osinfo()->SetParentOS($parent);
}

#
# Check if a particular feature is supported.
#
sub FeatureSupported($$)
{
    my ($self, $feature) = @_;

    return $self->osinfo()->FeatureSupported($feature);
}

#
# Add a feature.
#
sub AddFeature($$)
{
    my ($self, $feature) = @_;

    return $self->osinfo()->AddFeature($feature);
}

#
# Return 1 if OS is a sub OS (i.e., has a def_parentosid).
#
sub IsSubOS($)
{
    my ($self) = @_;

    return $self->osinfo()->IsSubOS();
}

#
# Return 1 if OS is a sub OS and runs on the given parent.
#
sub RunsOnParent($$)
{
    my ($self,$parent) = @_;

    return $self->osinfo()->RunsOnParent($parent);
}

#
# Really, def_parentosid mapped to the image.
#
sub DefaultParent($)
{
    my ($self) = @_;
    my $parent = $self->osinfo()->DefaultParent();
    return undef
	if (!defined($parent));

    return OSImage->Lookup($parent->osid(), $parent->vers());
}

#
# Set an entry in the submap that says it runs on a parent.
#
sub SetRunsOnParent($$)
{
    my ($self,$parent) = @_;

    return $self->osinfo()->SetRunsOnParent($parent);
}

# Stubs for calling "libTaintStates" common taint handling code
sub GetTaintStates($)
{
    my ($self) = @_;
    
    return $self->osinfo()->GetTaintStates();
}
sub IsTainted($;$)
{
    my ($self, $taint) = @_;

    return $self->osinfo()->IsTainted($taint);
}
sub SetTaintStates($@)
{
    my ($self, @taint_states) = @_;

    return $self->osinfo()->SetTaintStates(@taint_states);
}
sub AddTaintState($$)
{
    my ($self, $taint) = @_;

    return $self->osinfo()->AddTaintState($taint);
}
sub RemoveTaintState($;$)
{
    my ($self, $taint) = @_;

    return $self->osinfo()->RemoveTaintState($taint);
}
sub InheritTaintStates($$)
{
    my ($self, $osinfo) = @_;

    return $self->osinfo()->InheritTaintStates($osinfo);
}

sub ConvertToLocal($)
{
    return $_[0]->image()->ConvertToLocal();
}

sub ConvertToImported($$)
{
    return $_[0]->image()->ConvertToImported($_[1]);
}

sub ImportImageFileSize($)
{
    return $_[0]->image()->ImportImageFileSize();
}

sub InUse($)
{
    return $_[0]->image()->InUse();
}

#############################################################################
#
# Image Aliases are groups of images that work on different architectures.
#
package OSImageAlias;
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use Exporter;
use vars qw(@ISA @EXPORT $AUTOLOAD);

@ISA    = "Exporter";
@EXPORT = qw ( );

use libtestbed;
use libdb;
use EmulabConstants;
use emutil;
use Image;
use OSinfo;
use overload ('""' => 'Stringify');

#
# No versioning on aliases. Just pid,eid. 
#
sub Lookup($$;$)
{
    my ($class, $arg1, $arg2) = @_;
    my $query_result;

    #
    # A single arg is either an index or "pid,imagename[:version]" or
    # "pid/imagename[:version]" string.
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    $query_result =
		DBQueryWarn("select * from image_aliases ".
			    "where imageid='$arg1'");
	}
	elsif ($arg1 =~ /^([-\w]*),([-\w\.\+]*)$/ ||
	       $arg1 =~ /^([-\w]*)\/([-\w\.\+]*)$/) {
	    $query_result =
		DBQueryWarn("select * from image_aliases ".
			    "where pid='$1' and imagename='$2'");
	}
    }
    elsif ($arg1 =~ /^[-\w]*$/ && $arg2 =~ /^[-\w\.\+]*$/) {
    	$query_result =
	    DBQueryWarn("select * from image_aliases ".
			"where pid='$arg1' and imagename='$arg2'");
    }
    return undef
	if (!defined($query_result) || !$query_result->numrows);

    my $self = {};
    $self->{'IMAGES'} = {};

    while (my $row = $query_result->fetchrow_hashref()) {
	
	#
	# Info about the alias, use the first row.
	#
	if (!exists($self->{'ALIAS'})) {
	    $self->{'ALIAS'} = $row;
	}
	my $target_imageid = $row->{'target_imageid'};
	my $image = OSImage->Lookup($target_imageid);
	if (!defined($image)) {
	    print STDERR "ImageAlias Lookup; $target_imageid does not exist!\n";
	    return undef;
	}
	$self->{'IMAGES'}->{$target_imageid} = $image;
    }
    bless($self, $class);
    return $self;
}
sub imagename($)    { return $_[0]->{'ALIAS'}->{'imagename'}; }
sub osname($)       { return $_[0]->{'ALIAS'}->{'imagename'}; }
sub imageid($)	    { return $_[0]->{'ALIAS'}->{'imageid'}; }
sub osid($)	    { return $_[0]->{'ALIAS'}->{'imageid'}; }
sub pid($)	    { return $_[0]->{'ALIAS'}->{'pid'}; }
sub pid_idx($)	    { return $_[0]->{'ALIAS'}->{'pid_idx'}; }
sub gid($)	    { return $_[0]->{'ALIAS'}->{'gid'}; }
sub gid_idx($)	    { return $_[0]->{'ALIAS'}->{'gid_idx'}; }
sub uuid($)	    { return $_[0]->{'ALIAS'}->{'uuid'}; }
sub imagelist($)    { return values(%{ $_[0]->{'IMAGES'} }); }
sub isImage($)      { return 0; }
sub isImageAlias($) { return 1; }
sub IsGeneric($)    { return 0; }
sub mfs($)          { return 0; }
sub path($)         { return undef; }

#
# Create a new Image Alias.
#
sub Create($$$@)
{
    my ($class, $name, $group, @targets) = @_;

    #
    # Grab unique ID. Table already locked.
    # 
    my $imageid = TBGetUniqueIndex("next_osid");
    my $uuid    = NewUUID();
    my $pid     = $group->pid();
    my $pid_idx = $group->pid_idx();
    my $gid     = $group->gid();
    my $gid_idx = $group->gid_idx();

    foreach my $target (@targets) {
	my $target_name    = $target->imagename();
	my $target_imageid = $target->imageid();

	DBQueryWarn("insert into image_aliases set ".
		    "  imagename='$name',imageid='$imageid',uuid='$uuid', ".
		    "  pid='$pid',pid_idx='$pid_idx',".
		    "  gid='$gid',gid_idx='$gid_idx',".
		    "  target_imagename='$target_name',".
		    "  target_imageid='$target_imageid'")
	    or goto bad;
    }
    return OSImageAlias->Lookup($imageid);
  bad:
    DBQueryWarn("delete from image_aliases where imageid='$imageid'");
    return -1;
}

#
# Delete.
#
sub Delete($)
{
    my ($self) = @_;
    my $imageid = $self->imageid();

    return -1
	if (!DBQueryWarn("delete from image_aliases ".
			 "where imageid='$imageid'"));
    return 0;
}

#
# Lookup a "system" image, meaning one in the emulab-ops project.
#
sub LookupByName($$)
{
    my ($class, $imagename) = @_;

    return OSImageAlias->Lookup(TBOPSPID(), $imagename);
}

AUTOLOAD {
    my $self  = $_[0];
    my $type  = ref($self) or croak "$self is not an object";
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    carp("ImageAlias: wanted slot '$name' field in $self");
    return undef;
}

# Break circular references to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'ALIAS'}  = undef;
    $self->{'IMAGES'} = undef;
}

sub Stringify($)
{
    my ($self) = @_;
    my $pid  = $self->pid();
    my $name = $self->imagename();
    my $id   = $self->imageid();
    
    return "[ImageAlias $pid,$name $id]";
}

sub urn($)
{
    my ($self) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    my $pid    = $self->pid();
    my $name   = $self->imagename();
    my $domain = $OURDOMAIN;

    return GeniHRN::Generate($domain, "image", $pid . "//" . $name);
}    

#
# Given a node type, map the alias to the proper image.
# 
sub MapToImage($$)
{
    my ($self, $type) = @_;

    if (ref($type)) {
	$type = $type->type();
    }
    #
    # Look through each of the images and stop when we find one that
    # runs on this type.
    #
    foreach my $image ($self->imagelist()) {
	my @typelist = $image->TypeList();
	if (@typelist && grep {$_->type() eq $type} @typelist) {
	    return $image;
	}
    }
    return undef;
}

#
# List all aliases.
#
sub ListAll($)
{
    my ($class) = @_;
    my @result  = ();

    my $query_result =
	DBQueryWarn("select distinct imageid from image_aliases");

    while (my ($imageid) = $query_result->fetchrow_array()) {
	my $image = OSImageAlias->Lookup($imageid);
	if (!defined($image)) {
	    print STDERR "Could not lookup image aliase for $imageid\n";
	    next;
	}
	push(@result, $image);
    }
    return @result;
}

#
# Iterate over images in the list, calling function.
#
sub ImageIterate($$)
{
    my ($self, $function) = @_;
    my $retval = 0;

    foreach my $image ($self->imagelist()) {
	$retval++
	    if (&$function($image));
    }
    return $retval;
}

#
# List the images.
#
sub ShowImages($)
{
    my ($self) = @_;

    my $coderef = sub {
	print $_[0] . "\n";
	return 0;
    };
    $self->ImageIterate($coderef);
}

#
# The access check checks all of the images. It would make no sense to
# have mixed access.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;
    my $allowed = 1;
    my $coderef = sub {
	$allowed = 0
	    if (!$_[0]->AccessCheck($user, $access_type));
	return 0;
    };
    $self->ImageIterate($coderef);
    return $allowed;
}

# All images have to be shared.
sub shared($)
{
    my ($self) = @_;
    my $shared = 1;
    my $coderef = sub {
	$shared = 0
	    if (!$_[0]->shared());
	return 0;
    };
    $self->ImageIterate($coderef);
    return $shared;
}
# All images have to be global.
sub global($)
{
    my ($self) = @_;
    my $global = 1;
    my $coderef = sub {
	$global = 0
	    if (!$_[0]->global());
	return 0;
    };
    $self->ImageIterate($coderef);
    return $global;
}

#
# Get the combined type list.
#
sub TypeList($)
{
    my ($self)  = @_;

    my %types   = ();
    my $coderef = sub {
	foreach my $type ($_[0]->TypeList()) {
	    $types{$type->type()} = $type;
	}
    };
    $self->ImageIterate($coderef);
    return values(%types);
}

#
# A feature is supported if all of the images support that feature.
#
sub FeatureSupported($$)
{
    my ($self, $feature) = @_;
    my $supported = 1;
    my $coderef   = sub {
	$supported = 0
	    if (!$_[0]->FeatureSupported($feature));
	return 0;
    };
    $self->ImageIterate($coderef);
    return $supported;
}

#
# So this is a little strange. Given an image, we often want the parent
# image (as for virtnodes and subnodes). But if the image is an alias,
# what is the parent? We can't just pick one of them, that seems wrong.
#
# So lets make up an alias for the parents and see how it goes. Unless
# of course, there is only one actual parent.
#
sub DefaultParent($)
{
    my ($self) = @_;
    my %parents = ();

    foreach my $image ($self->imagelist()) {
	my $parent = $image->DefaultParent();
	return undef
	    if (!defined($parent));

	$parents{$parent->imageid()} = $parent;
    }
    my $image0 = (values(%parents))[0]->image();

    # Just return the one image.
    if (scalar(keys(%parents)) == 1) {
	return OSImage->Lookup($image0->imageid(), $image0->version());
    }

    my $parent = {};
    $parent->{'IMAGES'} = \%parents;
    $parent->{'ALIAS'}  = {
	"imagename" => "Parent of $self",
	"imageid"   => -1,
	"pid"	    => $image0->pid(),
	"pid_idx"   => $image0->pid_idx(),
	"gid"	    => $image0->gid(),
	"gid_idx"   => $image0->gid_idx(),
    };
    bless($parent, "OSImageAlias");
    return $parent;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
