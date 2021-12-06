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
package Image;

use strict;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT $AUTOLOAD);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use libdb;
use EmulabConstants;
use libtestbed;
use Logfile;
use WebTask;
use English;
use Data::Dumper;
use File::Basename;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		  = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
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
my $PROJROOT      = "/proj";
my $GROUPROOT     = "/groups";

# Cache of instances to avoid regenerating them.
my %images    = ();
BEGIN { use emutil;
	emutil::AddCache(\%images); }
my $debug      = 0;

# Concat id/vers.
sub versid($)
{
    my ($self) = @_;

    return $self->imageid() . ":" . $self->version();
}
sub versname($)
{
    my ($self) = @_;

    return $self->pid() . "/" . $self->imagename() . ":" . $self->version();
}
sub urn($)
{
    my ($self) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    my $pid    = $self->pid();
    my $gid    = $self->gid();
    my $name   = $self->imagename();
    my $domain = $OURDOMAIN;

    if ($self->isdataset()) {
	$domain .= ":${pid}";
	$domain .= ":${gid}" if ($pid ne $gid);
	
	return GeniHRN::Generate($domain, "imdataset", $name);
    }
    else {
	return GeniHRN::Generate($domain, "image", $pid . "//" . $name);
    }
}    

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    print STDERR "Running '$command'\n"
	if ($debug);
    return system($command);
}

sub BlessRow($$)
{
    my ($class, $row) = @_;

    my $self           = {};
    my $imageid        = $row->{"imageid"};
    $self->{'IMAGE'}   = $row;
    $self->{'HASH'}    = {};

    bless($self, $class);

    # Grab the webtask. For images these are transient.
    if (defined($self->webtask_id())) {
	$self->{'WEBTASK'} = WebTask->Lookup($self->webtask_id());
    }
    return $self;
}

#
# Lookup by idx or pid,imagename[:version] depending on the args. We always 
# return highest numbered version on this path, if no version specified.
#
sub Lookup($$;$$)
{
    my ($class, $arg1, $arg2, $arg3) = @_;

    #
    # A single arg is either an index or "pid,imagename[:version]" or
    # "pid/imagename[:version]" string.
    #
    if (!defined($arg2)) {
	if ($arg1 =~ /^(\d*)$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid and v.version=i.version ".
			    "where i.imageid='$arg1'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	elsif ($arg1 =~ /^(\d*):(\d*)$/) {
	    #
	    # This will get deleted images, but that is okay.
	    #
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from image_versions as v ".
			    "left join images as i on ".
			    "     v.imageid=i.imageid ".
			    "where v.imageid='$1' and v.version='$2'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	elsif ($arg1 =~ /^([-\w]*),([-\w\.\+]*)$/ ||
		$arg1 =~ /^([-\w]*)\/([-\w\.\+]*)$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid and v.version=i.version ".
			    "where i.pid='$1' and i.imagename='$2'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	elsif ($arg1 =~ /^([-\w]*),([-\w\.\+]*):(\d*)$/ ||
		$arg1 =~ /^([-\w]*)\/([-\w\.\+]*):(\d*)$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid ".
			    "where i.pid='$1' and i.imagename='$2' and ".
			    "      v.version='$3'");
	    return undef
		if (!$result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref())
	}
	elsif ($arg1 =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
	    #
	    # First look to see if the uuid is for the image itself,
	    # which means current version. Otherwise look for a
	    # version with the uuid.
	    #
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid and v.version=i.version ".
			    "where i.uuid='$arg1'");
	    return undef
		if (!$result);
	    return BlessRow($class, $result->fetchrow_hashref())
		if ($result->numrows);

	    $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from image_versions as v ".
			    "left join images as i on ".
			    "     v.imageid=i.imageid ".
			    "where v.uuid='$arg1' and ".
			    "      v.deleted is null");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	return undef;
    }
    elsif (!defined($arg3)) {
	if ($arg1 =~ /^\d+$/ && $arg2 =~ /^\d+$/) {
	    #
	    # This will get deleted images, but that is okay.
	    #
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from image_versions as v ".
			    "left join images as i on ".
			    "     v.imageid=i.imageid ".
			    "where v.imageid='$arg1' and v.version='$arg2'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	elsif ($arg1 =~ /^[-\w]*$/ && $arg2 =~ /^([-\w\.\+]*):(\d+)$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid ".
			    "where i.pid='$arg1' and i.imagename='$1' and ".
			    "      v.version='$2'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	elsif ($arg1 =~ /^[-\w]*$/ && $arg2 =~ /^[-\w\.\+]*$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid and v.version=i.version ".
			    "where i.pid='$arg1' and i.imagename='$arg2'");
	    return undef
		if (! $result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
	return undef;
    }
    else {
	if ($arg1 =~ /^[-\w]*$/ &&
	    $arg2 =~ /^[-\w\.\+]*$/ && $arg3 =~ /^\d+$/) {
	    my $result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
			    "   i.metadata_url as image_metadata_url ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid ".
			    "where i.pid='$arg1' and i.imagename='$arg2' and ".
			    "      v.version='$arg3'");
	    return undef
		if (!$result || !$result->numrows);

	    return BlessRow($class, $result->fetchrow_hashref());
	}
    }
    return undef;
}

AUTOLOAD {
    my $self  = $_[0];
    my $type  = ref($self) or croak "$self is not an object";
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'IMAGE'}->{$name})) {
	# Allow update.
	if (scalar(@_) == 2) {
	    $self->{'IMAGE'}->{$name} = $_[1];
	}
	return $self->{'IMAGE'}->{$name};
    }
    # Or it is for a local storage slot.
    if ($name =~ /^_.*$/) {
	if (scalar(@_) == 2) {
	    return $self->{'HASH'}->{$name} = $_[1];
	}
	elsif (exists($self->{'HASH'}->{$name})) {
	    return $self->{'HASH'}->{$name};
	}
    }
    print STDERR Dumper($self);
    carp("No such slot '$name' field in class $type");
    return undef;
}
sub field($$) {
    my ($self, $name) = @_;
    
    if (exists($self->{'IMAGE'}->{$name})) {
	return $self->{'IMAGE'}->{$name};
    }
    return undef;
}
sub fieldExists($$) {
    my ($self, $name) = @_;

    return 1
	if (exists($self->{'IMAGE'}->{$name}));
    return 0;
}
sub fieldSet($$$) {
    my ($self, $name, $value) = @_;

    $self->{'IMAGE'}->{$name} = $value;
    return $value;
}
sub isImageAlias($)	{ return 0; }

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'IMAGE'}    = undef;
    $self->{'HASH'}     = undef;
    $self->{'WEBTASK'}  = undef;
}
sub webtask($)  { return $_[0]->{'WEBTASK'}; }

#
# Lookup by URL.
#
sub LookupByURL($$)
{
    my ($class, $url) = @_;
    my ($pid,$imagename);

    return undef
	if (! ($url =~ /^(ftp|http|https|file):/));

    my $safe_url = DBQuoteSpecial($url);

    #
    # First check for a non version specific URL (latest version).
    #
    my $query_result =
	DBQueryWarn("select pid,imagename from images ".
		    "where metadata_url=$safe_url");
    return undef
	if (!$query_result);

    if ($query_result->numrows) {
	my ($pid,$imagename) = $query_result->fetchrow_array();
	
	return Image->Lookup($pid, $imagename);
    }
    
    #
    # Then a version specific URL.
    #
    $query_result =
	DBQueryWarn("select pid,imagename,version from image_versions ".
		    "where metadata_url=$safe_url and deleted is null");
    return undef
	if (!$query_result);

    if ($query_result->numrows) {
	my ($pid,$imagename,$version) = $query_result->fetchrow_array();
	
	return Image->Lookup($pid, $imagename, $version);
    }
    else {
	#
	# If the URL points back to ourself, find the image it refers
	# to. Later phases will catch misuse of the URL (not allowed,
	# does not exist).
	#
	require URI;
	require URI::QueryParam;
	
	my $uri = URI->new($url);
	return undef
	    if (!defined($uri));
	return undef
	    if ($uri->host() ne $WWWHOST);
	my $uuid = $uri->query_param("uuid");
	return undef
	    if (!defined($uuid) || $uuid eq "");

	return Image->Lookup($uuid);
    }
    return undef;
}
# Image is local if the metadata_url is null.
sub IsLocal($)
{
    my ($self) = @_;

    return (defined($self->metadata_url()) ? 0 : 1);
}

#
# Lookup a "system" osid, meaning one in the emulab-ops project.
#
sub LookupByName($$)
{
    my ($class, $imagename) = @_;

    return Image->Lookup(TBOPSPID(), $imagename);
}

#
# Lookup by Origin UUID.
#
sub LookupByOriginUUID($$$)
{
    my ($class, $pid, $uuid) = @_;
    my $safe_uuid = DBQuoteSpecial($uuid);
    my $safe_pid = DBQuoteSpecial($pid);

    my $query_result =
	DBQueryWarn("select imageid from image_versions ".
		    "where pid=$safe_pid and ".
		    "      origin_uuid=$safe_uuid and deleted is null");
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($imageid) = $query_result->fetchrow_array();
    return Image->Lookup($imageid);
}

#
# Lookup by Origin URN.
#
sub LookupByOriginURN($$)
{
    my ($class, $urn) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    return undef
	if (!GeniHRN::IsValid($urn));
    
    my $safe_urn = DBQuoteSpecial($urn);

    my $query_result =
	DBQueryWarn("select imageid,version from image_versions ".
		    "where origin_urn=$safe_urn and deleted is null");
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($imageid,$version) = $query_result->fetchrow_array();
    return Image->Lookup($imageid, $version);
}

#
# Lookup by Authority URN. Only for datasets right now.
#
sub LookupByAuthorityURN($$)
{
    my ($class, $urn) = @_;

    return undef
	if (! $PGENISUPPORT);    

    require GeniHRN;
    return undef
	if (!GeniHRN::IsValid($urn));
    
    my $safe_urn = DBQuoteSpecial($urn);

    my $query_result =
	DBQueryWarn("select distinct imageid from image_versions ".
		    "where authority_urn=$safe_urn and deleted is null");
    return undef
	if (!$query_result || !$query_result->numrows);

    my ($imageid) = $query_result->fetchrow_array();
    return Image->Lookup($imageid);
}

#
# Return a list of all images of the given format for the given pid.
# If format is NULL, return all formats. If pid is NULL, return for all pids.
# List is names of the form "pid/imagename".
#
sub ListAll($$$)
{
    my ($class, $format, $pid) = @_;
    my @result = ();

    my $clause = "";
    if (defined($format) && $format =~ /^([-\w]+)$/) {
	$clause .= ($clause ? " and" : "where");
	$clause .= " format='$1'";
    }
    if (defined($pid) && $pid =~ /^([-\w]+)$/) {
	$clause .= ($clause ? " and" : "where");
	$clause .= " i.pid='$1'";
    }

    my $query_result =
	DBQueryWarn("select distinct i.pid,i.imagename from images as i ".
		    "left join image_versions as v on ".
		    "     v.imageid=i.imageid and v.version=i.version ".
		    "$clause order by i.pid,i.imagename");
    if ($query_result) {
	while (my ($pid,$name) = $query_result->fetchrow_array()) {
	    push(@result, "$pid/$name");
	}
    }
    return @result;
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
    my ($class, $format, $pid) = @_;
    my @result = ();

    my $clause = "";
    if (defined($format) && $format =~ /^([-\w]+)$/) {
	$clause .= "and v.format='$1' ";
    }
    if (defined($pid) && $pid =~ /^([-\w]+)$/) {
	$clause .= "and v.pid='$1' ";
    }

    my $query_result =
	DBQueryWarn("select v.pid,v.imagename,v.version from ".
		    "images as i, image_versions as v where ".
		    "i.imageid=v.imageid and v.deleted is null ".
		    "$clause order by v.pid,v.imagename,v.version");
    if ($query_result) {
	while (my ($pid,$name,$vers) = $query_result->fetchrow_array()) {
	    push(@result, "$pid/$name:$vers");
	}
    }
    return @result;
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $imageid = $self->imageid();
    my $version = $self->version();

    my $query_result =
	DBQueryWarn("select i.*,v.*,i.uuid as image_uuid, ".
		    "   i.metadata_url as image_metadata_url ".
		    "  from image_versions as v ".
		    "left join images as i on ".
		    "     v.imageid=i.imageid ".
		    "where v.imageid='$imageid' and v.version='$version'");
    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'IMAGE'} = $query_result->fetchrow_hashref();

    return 0;
}

#
# Create a new os_info. This installs the new record in the DB,
# and returns an instance. There is some bookkeeping along the way.
#
sub Create($$$$$$$$$$)
{
    my ($class, $project, $group, $creator, $isadmin, $lockpid,
	$imagename, $imageid, $argref, $usrerr_ref) = @_;
    require OSinfo;

    return undef
	if (ref($class) || !ref($project));

    my $isdataset = (exists($argref->{"isdataset"}) ?
		     $argref->{"isdataset"} : 0);
    my $architecture = $argref->{'architecture'}
        if (defined($argref->{'architecture'}));

    # We may ignore particular partN_osid's by deleting them.
    my @arg_slots = grep(/^part[1-4]_osid$/, keys(%{$argref}));

    # Pass-through a bunch of required slots, ignoring any extras
    # and stuff we handle explicitly.
    if (!$isdataset) {
	foreach my $key ("loadpart", "loadlength", "default_osid") {
	    if (!exists($argref->{$key})) {
		$$usrerr_ref = "Error: $key missing in Image->Create!";
		return undef;
	    }
	    push(@arg_slots, $key);
	}
    }
    # Pass-through optional slots, otherwise the DB default is used.
    foreach my $key ("path", "shared", "global", "ezid", "mbr_version",
		     "format", "metadata_url", "imagefile_url", "released",
		     "isdataset", "lba_size", "lba_low", "lba_high",
		     "origin_uuid", "origin_urn", "origin_name") {
	if (exists($argref->{$key})) {
	    push(@arg_slots, $key);
	}
    }

    my $pid     = $project->pid();
    my $pid_idx = $project->pid_idx();
    my $gid     = $group->gid();
    my $gid_idx = $group->gid_idx();
    my $uid     = $creator->uid();
    my $uid_idx = $creator->uid_idx();

    #
    # The pid/imageid has to be unique, so lock the table for the check/insert.
    # We lock the os_info tables too, for the call into Lookup.
    #
    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info as o read, os_info_versions as v read, ".
		"            emulab_indicies write")
	or return undef;

    my $query_result =
	DBQueryWarn("select imagename from images ".
		    "where pid_idx='$pid_idx' and imagename='$imagename'");

    if ($query_result->numrows) {
	DBQueryWarn("unlock tables");
	$$usrerr_ref = "Error: IMAGE $imagename in project $pid already exists!";
	return undef;
    }
    # The metadata_url also has to be unique.
    if (exists($argref->{'metadata_url'})) {
	my $metadata_url = $argref->{'metadata_url'};
	my $safe_url = DBQuoteSpecial($metadata_url);
	
	my $query_result =
	    DBQueryWarn("select imagename from image_versions ".
			"where metadata_url=$safe_url and deleted is null");

	if ($query_result->numrows) {
	    DBQueryWarn("unlock tables");
	    $$usrerr_ref = "Error: IMAGE $metadata_url already exists!";
	    return undef;
	}
    }

    # We allow providing an image descriptor index, so newimageid_ez can use
    # the same name, description, and index for both the OS and Image it makes.
    if (defined($imageid) && $imageid > 0 ) {
	# Make sure the OS descriptor for it already exists.
	if (!OSinfo->Lookup($imageid)) {
	    DBQueryWarn("unlock tables");
	    $$usrerr_ref = "Error: Missing OSinfo $imagename/$imageid in $pid!";
	    return undef;
	}
    } else {
	#
	# Grab unique ID. Table already locked.
	# 
	$imageid  = TBGetUniqueIndex("next_osid", undef, 1);
    }
    #
    # The image UUID refers to the image, current version. Then each
    # version has its own uuid so it can be referred to. 
    #
    my $image_uuid   = NewUUID();
    my $version_uuid = NewUUID();
    #
    # Some fields special cause of quoting.
    #
    my $desc  = "''";
    if (exists($argref->{'description'})) {
	$desc = DBQuoteSpecial($argref->{'description'});
    }
    my $bquery = "imagename='$imagename'";
    $bquery .= ",imageid='$imageid'";
    $bquery .= ",pid='$pid',pid_idx='$pid_idx'";
    $bquery .= ",gid='$gid',gid_idx='$gid_idx'";

    # image_versions include all the images stuff.
    my $query = "insert into image_versions set $bquery, ".
	join(",", map("$_='" . $argref->{$_} . "'", @arg_slots));
    # except for this.
    $bquery .= ",architecture='$architecture'"
	if (defined($architecture));

    # Lock directive.
    my $prelock = "";
    if (defined($lockpid)) {
	$prelock = ",locked=now(),locker_pid='$lockpid'";
    }

    $query .= ",creator='$uid',creator_idx='$uid_idx'";
    $query .= ",uuid='$version_uuid'";
    $query .= ",created=now()";
    $query .= ",description=$desc";
    $query .= ",hash=" . DBQuoteSpecial($argref->{'hash'})
	if (exists($argref->{'hash'}) && $argref->{'hash'} ne '');
    $query .= ",deltahash=" . DBQuoteSpecial($argref->{'deltahash'})
	if (exists($argref->{'deltahash'}) && $argref->{'deltahash'} ne '');
    $query .= ",size=" . DBQuoteSpecial($argref->{'size'})
	if (exists($argref->{'size'}));
    $query .= ",deltasize=" . DBQuoteSpecial($argref->{'deltasize'})
	if (exists($argref->{'deltasize'}));
    $query .= ",notes=" . DBQuoteSpecial($argref->{'notes'})
	if (exists($argref->{'notes'}) && $argref->{'notes'} ne '');

    #
    # If this is set in the environment, we use it. This allows
    # us to track actual geni users, since all of that happens
    # as geniuser. We do not bother to set this for local users.
    #
    if (exists($ENV{'REALGENIURN'}) && $ENV{'REALGENIURN'} ne "") {
	$query .= ",creator_urn=". DBQuoteSpecial($ENV{'REALGENIURN'});
    }

    # Create the main entry:
    if (! DBQueryWarn("insert into images set ".
		      " $bquery,uuid='$image_uuid' $prelock")) {
	DBQueryWarn("unlock tables");
	tberror("Error inserting new images record for $pid/$imagename!");
	return undef;
    }
    # And the other entry.
    if (! DBQueryWarn($query)) {
	DBQueryWarn("delete from images where uuid='$image_uuid'");
	DBQueryWarn("unlock tables");
	tberror("Error inserting new images record for $pid/$imagename!");
	return undef;
    }
    DBQueryWarn("unlock tables");

    my $image = Image->Lookup($imageid);
    # Create the osidtoimageid mapping.  Admins have an option to do it or not.
    my $makedefault = exists($argref->{"makedefault"}) && 
	$argref->{"makedefault"} eq "1";

    if (!$isdataset && !defined($architecture) && (!$isadmin || $makedefault)){
	#
	# Dig out the mtypes we want to turn on. The caller has already
	# sanity checked them to make sure the types actually exist, and
	# that there are nodes matching that type.
	#
	my @map_updates = ();
	foreach my $key (grep(/^mtype_/, keys(%{$argref}))) {
	    if ($argref->{$key} eq "1") {
		$key =~ s/^mtype_//;
		push(@map_updates, $key);
	    }
	}

	my @osid_array = ();
	for (my $i = 1; $i <= 4; $i++) {
	    my $func = "part${i}_osid";
	    my $foo  = $image->$func();
	    if (defined($foo)) {
		push(@osid_array, $foo);
	    }
	}

	for (my $i = 0; $i <= $#map_updates; $i++) {
	    for (my $j = 0; $j <= $#osid_array; $j++) {
		 my $query = "INSERT INTO osidtoimageid ".
			     "       (osid, type, imageid) ".
			     "VALUES ('$osid_array[$j]', ".
			     "        '$map_updates[$i]', ".
			     "        '$imageid')";
		 ##print "$query\n";
		 if (! DBQueryWarn($query)) {
		     tberror("Error inserting new ostoimageid mapping for ".
			     "$pid/$imagename!");
		     return undef;
		 }
	    }
	}
    }
    return $image;
}

#
# Clone an image descriptor from the DB, bumping the version number
#
# XXX A lot of stuff in here gets skipped for datasets.
#
sub NewVersion($$$$)
{
    my ($self, $creator, $baseimage, $usrerr_ref) = @_;
    my $osid        = $self->imageid();
    my $version     = $self->version();
    my $isdataset   = $self->isdataset();
    my $tableid     = int(rand(10000000));
    my $typelist    = "";
    my $ostablename = "os_info_versions" . $tableid;
    my $imtablename = "image_versions"  . $tableid;

    #
    # This should not happen but lets make sure.
    #
    # We cannot make this test cause of image deletion; we might have
    # deleted the head version. But this code below assumes we are
    # making a copy of the highest numbered version of the image. I think
    # we can change this, but do not want to attempt that now. Needs more
    # thought
    #
    if (0 && defined($self->deleted())) {
	print STDERR "Not allowed to clone deleted image $self\n";
	return undef;
    }
    #
    # We should always be called with the latest version. $baseimage is
    # what we are actually basing the new image on.
    #
    if (!$self->IsNewest()) {
	print STDERR "Image::NewVersion: $self is not the head version\n";
	return undef;
    }
    
    #
    # Grab the current type list. Do this before table locking.
    #
    if (!$isdataset) {
	my @typelist = $self->TypeList();
	$typelist = join(",", @typelist)
	    if (@typelist);
    }

    #
    # The pid/imageid has to be unique, so lock the table for the check/insert.
    #
    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info write, os_info_versions write, ".
		"            emulab_indicies write, osidtoimageid read, ".
		"            node_types read")
	or return undef;

    my $query_result =
	DBQueryWarn("create temporary table $imtablename ".
		    "select * from image_versions ".
		    "where imageid='$osid' and version='$version'");
    goto bad
	if (!$query_result);

    if (!$isdataset) {
	$query_result =
	    DBQueryWarn("create temporary table $ostablename ".
			"select * from os_info_versions ".
			"  where osid='$osid' and vers='$version'");
	goto bad
	    if (!$query_result);

	#
	# Update the type list in the image being cloned. Better to do this
	# when the types are changed, but this works too since no one uses
	# this until the image is deleted.
	#
	DBQueryWarn("update image_versions set nodetypes='$typelist' ".
		    "where imageid='$osid' and version='$version'");
    }

    #
    # Now reset a few things in each table.
    #
    my $clone_vers  = $self->version() + 1;
    my $updater_urn = "";
    #
    # If this is set in the environment, we use it. This allows
    # us to track actual geni users, since all of that happens
    # as geniuser. We do not bother to set this for local users.
    #
    if (exists($ENV{'REALGENIURN'}) && $ENV{'REALGENIURN'} ne "") {
	$updater_urn = ",updater_urn=". DBQuoteSpecial($ENV{'REALGENIURN'});
    }

    #
    # Figure out which partition needs to be changed. EZ images only
    # at this time.
    #
    my $part_vers = "";
    if (!$isdataset) {
	for (my $i = 1; $i <= 4; $i++) {
	    my $func = "part${i}_osid";
	    if (defined($self->$func())) {
		$part_vers = "part${i}_vers='${clone_vers}',";
		last;
	    }
	}
    }
    my $uid     = $creator->uid();
    my $uid_idx = $creator->uid_idx();

    #
    # The parent of this image might be this image, if taking a snapshot
    # of a node running the image. But we also need to support making a
    # version of the image, from a node running some other image. We still
    # bump the version number, but the parent pointers are different.
    #
    # In one case, the base image is undef, which indicates a new version
    # not based on anything; we use this from the image_import with
    # update path. Not sure it is the correct approach yet.
    #
    my ($parent_imageid, $parent_version);

    if (!defined($baseimage)) {
	$parent_imageid = "NULL";
	$parent_version = "NULL";
    }
    else {
	if ($self->imageid() == $baseimage->imageid()) {
	    $parent_imageid = $self->imageid();
	    $parent_version = $self->version();
	}
	else {
	    $parent_imageid = $baseimage->imageid();
	    $parent_version = $baseimage->version();
	}
	$parent_imageid = "'$parent_imageid'";
	$parent_version = "'$parent_version'";
    }

    #
    # Fix up the path by appending the version number.
    #
    my $path = $self->path();
    if (!$self->IsDirPath()) {
	if ($path =~ /^(.*):\d+$/) {
	    $path = $1 . ":${clone_vers}";
	}
	else {
	    $path .= ":${clone_vers}";
	}
    }
    
    if (!$isdataset) {
	DBQueryWarn("update $ostablename set ".
		    "  uuid=uuid(),deleted=null, ".
		    "  vers='$clone_vers',".
		    "  parent_osid=$parent_imageid,".
		    "  parent_vers=$parent_version ".
		    "where osid='$osid'")
	    or goto bad;
    }
    DBQueryWarn("update $imtablename set ".
		"  uuid=uuid(),ready=0,path='$path',released=0,deleted=null, ".
		"  $part_vers default_vers='$clone_vers', ".
		"  version='$clone_vers',last_used=NULL, ".
		"  created=now(),nodetypes='$typelist', ".
		"  parent_imageid=$parent_imageid,".
		"  parent_version=$parent_version, ".
		"  origin_neednotify=0,origin_needupdate=0, ".
		"  origin_uuid=NULL,origin_name=NULL, ".
		"  hash=null,deltahash=null,size=0,deltasize=0, ".
		"  updater='$uid',updater_idx='$uid_idx' $updater_urn ".
		"where imageid='$osid'")
	or goto bad;

    #
    # And insert into the real table. At this point we will be
    # inconsistent if we crash before the commit is done.
    #
    if (!$isdataset) {
	DBQueryWarn("insert into os_info_versions ".
		    "select * from $ostablename")
	    or goto bad;
    }
    if (! DBQueryWarn("insert into image_versions ".
		      "select * from $imtablename")) {
	DBQueryWarn("delete from os_info_versions ".
		    "where osid='$osid' and vers='$clone_vers'")
	    if (!$isdataset);
	DBQueryWarn("delete from image_versions ".
		    "where imageid='$osid' and version='$clone_vers'");
	goto bad;
    }
    
    DBQueryWarn("unlock tables");
    return Image->Lookup($osid, $clone_vers);
  bad:
    DBQueryWarn("unlock tables");
    return undef;
}

#
# For a newly created image, set the provenance pointers back to
# the image from which it was derived.
#
sub SetProvenance($$)
{
    my ($self, $base) = @_;
    my $parent_imageid = $base->imageid();
    my $parent_version = $base->version();

    $self->Update({"parent_imageid" => $parent_imageid,
		   "parent_version" => $parent_version})
	== 0 or return -1;

    return 0;
}

#
# Highest number version, rather then what is deemed most recent by the
# images table.
#
# We must include deleted images here.
#
sub LookupMostRecent($)
{
    my ($self) = @_;

    my $imageid = $self->imageid();

    my $query_result =
	DBQueryWarn("select version from image_versions ".
		    "where imageid='$imageid' order by version desc limit 1");
    return undef
	if (!$query_result);

    my ($version) = $query_result->fetchrow_array();
    return Image->Lookup($imageid, $version);
}

#
# Return a list of all image versions.
#
sub AllVersions($$;$)
{
    my ($self, $pref, $deleted)  = @_;
    my @result  = ();
    my $imageid = $self->imageid();
    $deleted = 0 if (!defined($deleted));

    my $query_result =
	DBQueryWarn("select version from image_versions ".
		    "where imageid='$imageid' ".
		    ($deleted ? "" : "and deleted is null ") .
		    "order by version desc");
    return -1
	if (!$query_result);
    
    while (my ($version) = $query_result->fetchrow_array()) {
	my $image = Image->Lookup($imageid, $version);
	if (!defined($image)) {
	    print STDERR "Could not lookup image $imageid,$version\n";
	    return -1;
	}
	push(@result, $image);
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
    my ($self) = @_;

    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info write, os_info_versions write")
	or return -1;

    if (!$self->ready()) {
	print STDERR "Image::Release: $self is not marked ready!\n";
	goto bad;
    }
    my $imageid = $self->imageid();
    my $version = $self->version();

    #
    # Only the "head" version can be released.
    #
    my $query_result =
	DBQueryWarn("select max(version) from image_versions ".
		    "where imageid='$imageid'");
    goto bad
	if (!$query_result || !$query_result->numrows);

    my ($head) = $query_result->fetchrow_array();
    if ($head != $self->version()) {
	print STDERR "Image::Release: not the head version of $self\n";
	goto bad;
    }
    return -1
	if (! (DBQueryWarn("update os_info set version='$version' ".
			   "where osid='$imageid'") &&
	       DBQueryWarn("update images set version='$version' ".
			   "where imageid='$imageid'") &&
	       DBQueryWarn("update image_versions set released=1 ".
			   "where imageid='$imageid' and version='$version'")));
    DBQueryWarn("unlock tables");
    return 0;
  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Worker class method to edit image descriptor.
# Assumes most argument checking was done elsewhere.
#
sub EditImageid($$$$)
{
    my ($class, $image, $argref, $usrerr_ref) = @_;
    my %mods;
    my $noreport;
    require NodeType;

    my $imageid = $image->imageid();

    #
    # Now update the rest of the information in the DB.
    # (Others above already did their own updates.)
    #
    my %updates;
    foreach my $col ("description", "path", "mbr_version", "hash",
		     "notes") {
	# Copy args we want so that others can't get through.
	if (exists($argref->{$col})) {
	    $updates{$col} = $mods{$col} = $argref->{$col};
	}
    }
    my $redo_map = 0;
    my @map_updates;
    
    if (exists($argref->{"architecture"})) {
	# This is in the images table, so done separately.
	$mods{"architecture"} = $argref->{"architecture"};
    }
    else {
	# See mtype_$type args below.

	#
	# Need a list of node types. We join this over the nodes table so that
	# we get a list of just the nodes that are currently in the testbed, not
	# just in the node_types table.
	#
	my $types_result =
	    DBQueryWarn("select distinct n.type from nodes as n ".
			"left join node_type_attributes as a on a.type=n.type ".
			"where a.attrkey='imageable' and ".
			"      a.attrvalue!='0'");
	my @mtypes_array;
	while (my ($type) = $types_result->fetchrow_array()) {
	    push(@mtypes_array, $type);
	}
	#
	# Special hack to allow pcvm type -- see SetupReload in os_setup
	#
	push @mtypes_array, "pcvm";

	foreach my $type (@mtypes_array) {
	    # Remember when we get one of the mtype_$type args.  These aren't DB
	    # columns to update, but instead control re-creating the rows in the
	    # osidtoimageid table for this imageid, below.
	    my $mtype = "mtype_$type";
	    if (exists($argref->{$mtype})) {
		my $value = $argref->{$mtype};
		##printf "argref->{$mtype} %s\n", $value;
		$mods{$mtype} = $value;
		if ($value eq "1") {
		    push(@map_updates, $type);
		    $redo_map = 1;
		}
	    }
	}
    }

    if (!keys %mods) {
	if (!$noreport) {
	    # Warn the user that the submit button was pressed with no effect.
	    $$usrerr_ref = "Submit: Nothing changed";
	    return undef;
	}
    }

    if (keys(%mods) || $redo_map) {
	DBQueryWarn("lock tables images write, image_versions write, ".
		    "     images as i write, image_versions as v write, ".
		    "     os_info write, os_info_versions write, ".
		    "     osidtoimageid write");
    }
    if (keys %updates) {
	if ($image->Update(\%updates)) {
	    $$usrerr_ref = "DB: Error updating the images table";
	    DBQueryWarn("unlock tables");
	    return undef;
	}
    }
    if (exists($argref->{"architecture"})) {
	my $arch = $argref->{"architecture"};

	if (!DBQueryWarn("update images set architecture='$arch' ".
			 "where imageid='$imageid'")) {
	    $$usrerr_ref = "DB: Error updating the images table";
	    DBQueryWarn("unlock tables");
	    return undef;
	}
	if (0 &&
	    NodeType->LookupArchitectureTypes($arch) &&
	    !DBQueryWarn("delete from osidtoimageid ".
			      "where imageid='$imageid'")) {
	    $$usrerr_ref = "DB: Error updating the osidtoimageid table";
	    DBQueryWarn("unlock tables");
	    return undef;
	}
    }    
    if ($redo_map) {
	#
	# Update the osidtoimageid table too.
	# 
	# Must delete old entries first.
	DBQueryWarn("delete from osidtoimageid ".
		     "where imageid='$imageid'");

	my @osid_array;
	for (my $i = 1; $i <= 4; $i++) {
	    my $func = "part${i}_osid";
	    my $foo  = $image->$func();
	    if (defined($foo)) {
		push(@osid_array, $foo);
	    }
	}
	for (my $i = 0; $i <= $#map_updates; $i++) {
	    for (my $j = 0; $j <= $#osid_array; $j++) {
		 my $query = "REPLACE INTO osidtoimageid ".
			     "       (osid, type, imageid) ".
			     "VALUES ('$osid_array[$j]', ".
			     "        '$map_updates[$i]', ".
			     "        '$imageid')";
		 ##print "$query\n";
		 DBQueryWarn($query);
	    }
	}
    }
    if (keys(%mods) || $redo_map) {
	DBQueryWarn("unlock tables");
    }

    return 1;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $pid       = $self->pid();
    my $imageid   = $self->imageid();
    my $version   = $self->version();
    my $imagename = $self->imagename();

    return "[Image $imageid:$version $pid,$imagename]";
}

#
# Return the internal DB rowref. Used for code that has not been converted.
#
sub DBData($)
{
    my ($self) = @_;

    return undef
	if (! ref($self));

    return $self->{'IMAGE'}
}

#
# Perform some updates ...
#
sub Update($;$)
{
    my ($self, $argref, $allvers) = @_;
    $allvers = 0
	if (!defined($allvers));

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();
    my $version = $self->version();
    my @sets    = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" . (!defined($val) || $val eq "NULL" ?
				  "NULL" : DBQuoteSpecial($val)));
    }
    my $query = join(",", @sets);
    $query .= " where imageid='$imageid'";
    $query .= " and version='$version'" if (!$allvers);

    return -1
	if (! DBQueryWarn("update image_versions set $query"));
	    
    return Refresh($self);
}

#
# Delete an image,
#
sub Delete($;$)
{
    my ($self, $purge) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $purge = 0
	if (!defined($purge));
    
    my $imageid   = $self->imageid();
    my $uuid      = $self->image_uuid();
    # Do this before table locking.
    my @typelist  = $self->TypeList();

    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info write, os_info_versions write, ".
		"            osidtoimageid write, os_submap write, ".
		"            image_permissions write, node_types read, ".
		"            web_tasks write, ".
		"            logfiles write, logfile_metadata write, ".
		"            image_notifications write, ".
		"            image_updates write")
	or return -1;

    my $query_result =
	DBQueryWarn("select logfileid from image_versions ".
		    "where imageid='$imageid' and logfileid is not null");
    goto bad
	if (!$query_result);

    while (my ($logfileid) = $query_result->fetchrow_array()) {
	my $logfile = Logfile->Lookup($logfileid);
	if ($logfile) {
	    $logfile->Delete(1);
	}
    }

    #
    # If provenance is on and not purging, then want to stash the
    # current type list so we can recall it later. 
    #
    if (!$purge && $DOPROVENANCE && !defined($self->nodetypes())) {
	if (@typelist) {
	    my $typelist = join(",", @typelist);
	    DBQueryWarn("update image_versions set nodetypes='$typelist' ".
			"where imageid='$imageid'")
	}
    }

    #
    # If this is an EZ imageid, then delete the corresponding OSID too.
    #
    DBQueryWarn("delete from osidtoimageid where imageid='$imageid'")
	or goto bad;
    DBQueryWarn("delete from images where imageid='$imageid'")
	or goto bad;
    DBQueryWarn("delete from web_tasks where object_uuid='$uuid'")
	or goto bad;
    DBQueryWarn("delete from image_notifications where imageid='$imageid'")
	or goto bad;
    DBQueryWarn("delete from image_updates where imageid='$imageid'")
	or goto bad;
    $self->webtask()->Delete()
	if (defined($self->webtask()));
    
    if ($purge || !$DOPROVENANCE) {
	goto bad
	    if (! DBQueryWarn("delete from image_versions ".
			      "where imageid='$imageid'"));
    }
    else {
	# Set deleted on all of the versions.
	DBQueryWarn("update image_versions set deleted=now() ".
		    "where imageid='$imageid'")
	    or goto bad;
    }
    if ($self->ezid()) {
	# Cannot be a child or parent if I be dead.
	DBQueryWarn("delete from os_submap where ".
		    "  osid='$imageid' or parent_osid='$imageid'")
	    or goto bad;
	# Ditto.
	DBQueryWarn("update os_info_versions set def_parentosid=null ".
		    "  where def_parentosid='$imageid' and deleted is null")
	    or goto bad;
	# Ditto
	DBQueryWarn("update os_info_versions set nextosid=null ".
		    "  where nextosid='$imageid' and deleted is null")
	    or goto bad;
	
	DBQueryWarn("delete from os_info where osid='$imageid'")
	    or goto bad;
	if ($purge || !$DOPROVENANCE) {
	    DBQueryWarn("delete from os_info_versions where osid='$imageid'")
		or goto bad;
	}
	else {
	    # Set deleted on all of the versions.
	    DBQueryWarn("update os_info_versions set deleted=now() ".
			"where osid='$imageid'")
		or goto bad;
	}
	# Kill off the imageid permissions.
	DBQueryWarn("delete from image_permissions where imageid='$imageid'")
	    or goto bad;
    }
    DBQueryWarn("unlock tables")
	or return -1;

    return 0;

  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Mark a version as deleted. Since we are allowing the head version to
# be deleted, we might have to reset the current image/osinfo pointers.
#
sub DeleteVersion($)
{
    my ($self) = @_;
    my $imageid   = $self->imageid();
    my $version   = $self->version();

    # Delete logfile before table lock.
    $self->ClearLogFile()
	if ($self->logfileid());

    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info write, os_info_versions write")
	or return -1;

    #
    # Find the new head version; the highest numbered version that
    # is not deleted,
    #
    my $query_result =
	DBQueryWarn("select max(version) from image_versions ".
		    "where imageid='$imageid' and deleted is null and ".
		    "      version!='$version'");
    goto bad
	if (!$query_result);

    if (!$query_result->numrows) {
	print STDERR "Image::DeleteVersion: Cannot find a new head version\n";
	goto bad;
    }
    my ($head) = $query_result->fetchrow_array();
    
    goto bad
	if (! (DBQueryWarn("update image_versions set deleted=now() ".
			   "where imageid='$imageid' and version='$version'") &&
	       DBQueryWarn("update os_info_versions set deleted=now() ".
			   "where osid='$imageid' and vers='$version'") &&
	       DBQueryWarn("update os_info set version='$head' ".
			   "where osid='$imageid'") &&
	       DBQueryWarn("update images set version='$head' ".
			   "where imageid='$imageid'")));

    DBQueryWarn("unlock tables")
	or return -1;
    return 0;

  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Purge a version of an image. This is not to be used, except when there
# is an error during clone, and we want to undo the creation of a new version.
#
sub PurgeVersion($)
{
    my ($self) = @_;
    my $imageid   = $self->imageid();

    # Delete logfile before table lock.
    $self->ClearLogFile()
	if ($self->logfileid());

    DBQueryWarn("lock tables images write, image_versions write, ".
		"            os_info write, os_info_versions write")
	or return -1;

    #
    # We do not allow the purge if it is not the "head" version of the
    # image_versions. Maybe later.
    #
    my $query_result =
	DBQueryWarn("select max(version) from image_versions ".
		    "where imageid='$imageid'");
    goto bad
	if (!$query_result || !$query_result->numrows);

    my ($version) = $query_result->fetchrow_array();
    if ($version != $self->version()) {
	print STDERR "Image::PurgeVersion: not the head version of $self\n";
	goto bad;
    }

    goto bad
	if (! (DBQueryWarn("delete from image_versions ".
			   "where imageid='$imageid' and version='$version'") &&
	       DBQueryWarn("delete from os_info_versions ".
			   "where osid='$imageid' and vers='$version'")));

    DBQueryWarn("unlock tables")
	or return -1;
    return 0;

  bad:
    DBQueryWarn("unlock tables");
    return -1;
}

#
# Load the project object for an image
#
sub GetProject($)
{
    my ($self) = @_;
    require Project;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $project = Project->Lookup($self->pid_idx());
    
    if (! defined($project)) {
	print("*** WARNING: Could not lookup project object for $self!\n");
	return undef;
    }
    return $project;
}

#
# Load the group object for an image
#
sub GetGroup($)
{
    my ($self) = @_;
    require Group;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    my $group = Group->Lookup($self->gid_idx());
    
    if (! defined($group)) {
	print("*** WARNING: Could not lookup group object for $self!", 1);
	return undef;
    }
    return $group;
}

#
# Load the creator object for an image
#
sub GetCreator($)
{
    my ($self) = @_;
    require User;

    my $user = User->Lookup($self->creator_idx());
    
    if (! defined($user)) {
	print("*** WARNING: Could not lookup user object for $self!\n");
	return undef;
    }
    return $user;
}

sub GetUpdater($)
{
    my ($self) = @_;
    require User;

    return undef
	if (!$self->updater_idx());

    my $user = User->Lookup($self->updater_idx());
    
    if (! defined($user)) {
	print("*** WARNING: Could not lookup user object for $self!\n");
	return undef;
    }
    return $user;
}

#
# Check permissions. Note that root may ask permission, which comes in
# as an undef user.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;
    require Group;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    if ($access_type < TB_IMAGEID_MIN || $access_type > TB_IMAGEID_MAX) {
	print "*** Invalid access type $access_type!\n";
	return 0;
    }
    my $isadmin = ((defined($user) && $user->IsAdmin()) ||
		   ($UID == 0 || $UID eq "root") ? 1 : 0);
	
    # Admins and root do whatever they want.
    return 1
	if ($isadmin);

    my $mintrust;
    
    #
    # Global ImageIDs can be read by anyone.
    #
    if ($self->global()) {
	if ($access_type == TB_IMAGEID_READINFO) {
	    return 1;
	}
	if ($access_type == TB_IMAGEID_EXPORT && $isadmin) {
	    return 1;
	}
    }

    my $project = $self->GetProject();
    return 0
	if (!defined($project));
    my $group = $self->GetGroup();
    return 0
	if (!defined($group));

    #
    # Otherwise must have proper trust in the group
    #
    if ($access_type == TB_IMAGEID_READINFO) {
	$mintrust = PROJMEMBERTRUST_USER;
        #
        # Shared imageids are readable by anyone in the project.
        #
	if ($self->shared()) {
	    $group = $project->GetProjectGroup();
	}
    }
    elsif ($access_type == TB_IMAGEID_EXPORT) {
	#
	# Owner or root in the project.
	#
	return 1
	    if ($user->uid_idx() == $self->creator_idx());

	$mintrust = PROJMEMBERTRUST_GROUPROOT;
    }
    else {
	$mintrust = PROJMEMBERTRUST_LOCALROOT;
    }

    #
    # Either proper permission in the group, or group_root in the project.
    # This lets group_roots muck with other people's experiments, including
    # those in groups they do not belong to.
    #
    return 1
	if (TBMinTrust($group->Trust($user), $mintrust) ||
	    TBMinTrust($project->Trust($user), PROJMEMBERTRUST_GROUPROOT));

    # No point in looking further; never allowed.
    return 0
	if ($access_type == TB_IMAGEID_EXPORT);

    #
    # Look in the image permissions. First look for a user permission,
    # then look for a group permission.
    #
    my $uid_idx = $user->uid_idx();
    my $imageid = $self->imageid();
    
    my $query_result = 
	DBQueryWarn("select allow_write from image_permissions ".
		    "where imageid='$imageid' and ".
		    "      permission_type='user' and ".
		    "      permission_idx='$uid_idx'");
    return 0
	if (!$query_result);
    
    if ($query_result->numrows) {
	# READINFO is read-only access to the image and its contents.
	return 1
	    if ($access_type == TB_IMAGEID_READINFO());
	
	if ($access_type == TB_IMAGEID_ACCESS()) {
	    my ($allow_write) = $query_result->fetchrow_array();

	    return 1
		if ($allow_write);
	}
    }
    my $trust_none = $Group::MemberShip::TRUSTSTRING_NONE;
    $query_result = 
	DBQueryFatal("select allow_write from group_membership as g ".
		     "left join image_permissions as p on ".
		     "     p.permission_type='group' and ".
		     "     p.permission_idx=g.gid_idx ".
		     "where g.uid_idx='$uid_idx' and ".
		     "      p.imageid='$imageid' and ".
		     "      trust!='$trust_none'");

    if ($query_result->numrows) {
	# READINFO is read-only access to the image and its contents.
	return 1
	    if ($access_type == TB_IMAGEID_READINFO());
	
	if ($access_type == TB_IMAGEID_ACCESS()) {
	    my ($allow_write) = $query_result->fetchrow_array();

	    return 1
		if ($allow_write);
	}
    }
    return 0;
}

#
# LockTables simply locks the given tables, and then refreshes the
# instance (thereby getting the data from the DB after the tables are locked).
#
sub LockTables($;$)
{
    my ($self, $spec) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $spec = "images write"
	if (!defined($spec));
    
    DBQueryWarn("lock tables $spec")
	or return -1;
	
    return $self->Refresh();
}
sub UnLockTables($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    DBQueryWarn("unlock tables")
	or return -1;
    return 0;
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

    # XXX these should come out of the DB or not exist at all!
    my %mbr = (
	"1" => [0,   63,  6281415, 12562830, 12819870],
	"2" => [0,   63, 12305853, 24611643, 26712000],
	"3" => [0, 2048, 33556480, 39847936, 46139392]
    );

    # Must be a real reference. 
    return -1
	if (! ref($self));

    return -1
	if (! exists($mbr{$self->mbr_version()}));

    return -1
	if ($self->loadpart() > 4);

    return $mbr{$self->mbr_version()}[$self->loadpart()];
}

#
# Return created time for image as a UNIX timestamp via the passed ref.
# Return 0 on success, non-zero otherwise.
#
sub GetCreate($$)
{
    my ($self,$stampp) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid     = $self->imageid();
    my $version     = $self->version();

    my $result =
	DBQueryWarn("select UNIX_TIMESTAMP(created) from image_versions ".
		    "where imageid='$imageid' and version='$version'");
    if ($result && $result->numrows) {
	my ($stamp) = $result->fetchrow_array();
	$$stampp = $stamp;
	return 0;
    }
}

#
# Return updated time for image as a UNIX timestamp via the passed ref.
# Return 0 on success, non-zero otherwise.
#
sub GetUpdate($$)
{
    my ($self,$stampp) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid     = $self->imageid();
    my $version     = $self->version();

    my $result =
	DBQueryWarn("select UNIX_TIMESTAMP(updated) from image_versions ".
		    "where imageid='$imageid' and version='$version'");
    if ($result && $result->numrows) {
	my ($stamp) = $result->fetchrow_array();
	$$stampp = $stamp;
	return 0;
    }
}

#
# Mark the update time in the record,
#
sub MarkUpdate($$;$)
{
    my ($self, $user, $stamp) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid     = $self->imageid();
    my $version     = $self->version();
    my $updater     = "";
    my $updater_idx = "";
    my $updater_urn = "";
    if (defined($user)) {
	$updater     = ", updater='" . $user->uid() . "'";
	$updater_idx = ", updater_idx='" . $user->uid_idx() . "'";
    }
    #
    # If this is set in the environment, we use it. This allows
    # us to track actual geni users, since all of that happens
    # as geniuser. We do not bother to set this for local users.
    #
    if (exists($ENV{'REALGENIURN'}) && $ENV{'REALGENIURN'} ne "") {
	$updater_urn = ", updater_urn=". DBQuoteSpecial($ENV{'REALGENIURN'});
    }
    
    if (defined($stamp)) {
	$stamp="FROM_UNIXTIME($stamp)";
    }
    else {
	$stamp="now()";
    }

    return -1
	if (! DBQueryWarn("update image_versions set updated=$stamp " .
			  "  $updater $updater_idx $updater_urn ".
			  "where imageid='$imageid' and version='$version'"));

    return 0;
}

sub MarkDeleted($;$)
{
    my ($self, $stamp) = @_;

    my $imageid     = $self->imageid();
    my $version     = $self->version();

    if (defined($stamp)) {
	$stamp      = "FROM_UNIXTIME($stamp)";
    } else {
	$stamp      = "now()";
    }

    return -1
	if (! DBQueryWarn("update image_versions set deleted=$stamp " .
			  "where imageid='$imageid' and version='$version'"));

    return 0;
}

#
# Mark the IMS update time in the record,
#
sub MarkIMSReported($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid     = $self->imageid();
    my $version     = $self->version();

    return -1
	if (! DBQueryWarn("update image_versions set ims_reported=now() " .
			  "where imageid='$imageid' and version='$version'"));

    return 0;
}
sub ClearIMSReported($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid     = $self->imageid();
    my $version     = $self->version();

    return -1
	if (! DBQueryWarn("update image_versions set ims_reported=NULL " .
			  "where imageid='$imageid' and version='$version'"));

    return 0;
}
sub SetIMSNoReport($$)
{
    my ($self, $onoff) = @_;
    my $imageid = $self->imageid();
    my $version = $self->version();
    $onoff = ($onoff ? 1 : 0);

    return -1
	if (! DBQueryWarn("update image_versions set ims_noreport='$onoff' " .
			  "where imageid='$imageid' and version='$version'"));

    return 0;
}

#
# Set the hash.
#
sub SetFullHash($$)
{
    my ($self, $hash) = @_;

    return $self->Update({"hash" => $hash});
}
sub SetDeltaHash($$)
{
    my ($self, $hash) = @_;

    return $self->Update({"deltahash" => $hash});
}

#
# Set the size.
#
sub SetFullSize($$)
{
    my ($self, $size) = @_;

    return $self->Update({"size" => $size});
}
sub SetDeltaSize($$)
{
    my ($self, $size) = @_;

    return $self->Update({"deltasize" => $size});
}

sub SetUploaderPath($$)
{
    my ($self, $path) = @_;

    return $self->Update({"uploader_path" => $path});
}
sub ClearUploaderPath($)
{
    my ($self) = @_;

    return $self->Update({"uploader_path" => ''});
}
sub ClearUploaderStatus($)
{
    my ($self) = @_;

    return $self->Update({'uploader_status' => undef});
}

# Webtask.
sub SetWebTask($$)
{
    my ($self,$webtask) = @_;
    my $imageid = $self->imageid();

    if (defined($webtask)) {
	my $webtask_id = $webtask->task_id();
	
	DBQueryWarn("update images set webtask_id='$webtask_id' " .
		    "where imageid='$imageid'")
	    or return -1;
    }
    else {
	DBQueryWarn("update images set webtask_id=NULL " .
		    "where imageid='$imageid'")
	    or return -1;
    }
    return 0;
}
sub ClearWebTask($)
{
    my ($self) = @_;

    if (defined($self->webtask_id())) {
	my $webtask = $self->webtask();

	$webtask->Delete();
	$self->SetWebTask(undef);
    }
    return 0;
}

#
# Set the sector range of an image.
# Note that lba_size and reloc flag are left alone unless explicitly specified.
#
sub SetRange($$$;$$)
{
    my ($self,$start,$end,$ssize,$isreloc) = @_;

    my $argref = {"lba_low" => $start, "lba_high" => $end};

    if (defined($ssize)) {
	$argref->{'lba_size'} = $ssize;
    }
    if (defined($isreloc)) {
	$argref->{'relocatable'} = $isreloc;
    }
    return $self->Update($argref);
}

#
# Compute a rough approximation of the partition size needed for an image.
# Return megabytes.
#
sub PartitionSize($)
{
    my ($self) = @_;
    my $lba_size = $self->lba_size();
    my $lba_low  = $self->lba_low();
    my $lba_high = $self->lba_high();

    return undef
	if (!(defined($lba_size) && defined($lba_low) && defined($lba_high)));

    return (($lba_high - $lba_low + 1) / (1024 / $lba_size)) / 1024;
}

#
# Chunks, the amount of space needed to store the image, say in an LVM.
# Return megabytes.
#
sub Chunks($)
{
    my ($self) = @_;
    my $size   = $self->size();
    return undef
	if (!defined($size));
    
    # XXX assumes chunksize of 1MB
    my $chunks = int((($size + 1024 * 1024 - 1) / (1024 * 1024)) + 0.5);

    return $chunks;
}

#
# Lock and Unlock. We lock the entire chain (all versions) of the
# image. 
#
sub Lock($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));
    return -1
	if (!DBQueryWarn("lock tables images write"));

    my $imageid = $self->imageid();

    my $query_result =
	DBQueryWarn("update images set locked=now(),locker_pid=$PID " .
		    "where imageid='$imageid' and locked is null");

    if (! $query_result ||
	$query_result->numrows == 0) {
	DBQueryWarn("unlock tables");
	return -1;
    }
    DBQueryWarn("unlock tables");
    $self->{'IMAGE'}->{'locked'} = time();
    $self->{'IMAGE'}->{'locker_pid'} = $PID;
    return 0;
}

sub Unlock($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set locked=null,locker_pid=0 " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'locked'} = 0;
    $self->{'IMAGE'}->{'locker_pid'} = 0;
    return 0;
}

#
# Steal the lock
#
sub TakeLock($)
{
    my ($self) = @_;

    return -1
	if (!DBQueryWarn("lock tables images write"));

    my $imageid = $self->imageid();

    my $query_result =
	DBQueryWarn("update images set locker_pid=$PID " .
		    "where imageid='$imageid' and locked is not null");

    if (! $query_result ||
	$query_result->numrows == 0) {
	DBQueryWarn("unlock tables");
	return -1;
    }
    DBQueryWarn("unlock tables");
    $self->{'IMAGE'}->{'locker_pid'} = $PID;
    return 0;
}

sub GotLock($)
{
    my ($self) = @_;

    return 1
	if ($self->{'IMAGE'}->{'locked'} &&
	    $self->{'IMAGE'}->{'locker_pid'} == $PID);
    
    return 0;
}

#
# Wait to get lock.
#
sub WaitLock($$)
{
    my ($self, $seconds) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    while ($seconds > 0) {
	return 0
	    if ($self->Lock() == 0);

	# Sleep and try again.
	sleep(5);
	$seconds -= 5;
    }
    # One last try.
    return $self->Lock();
}

#
# Get the type list. 
#
sub TypeList($;$)
{
    my ($self, $osinfo) = @_;
    my @result  = ();
    my $query_result;
    require NodeType;

    #
    # Deleted images stash a list in the descriptor.
    #
    if ($self->deleted()) {
	if ($self->nodetypes()) {
	    foreach my $type (split(",", $self->nodetypes())) {
		my $typeinfo = NodeType->Lookup($type);
		push(@result, $typeinfo)
		    if (defined($typeinfo));
	    }
	}
	return @result;
    } 
    my $imageid = $self->imageid();
   
    #
    # If there is an architecture set in the image, we use that to
    # find the matching types in the node_types table. This overrides
    # anything found in the osidtoimageid.
    #
    if ($self->architecture()) {
	$query_result =
	    DBQueryWarn("select distinct node_types.type from images ".
			# The image architecture could be a short list.
			"inner join node_types on ".
			"   FIND_IN_SET(node_types.architecture,".
			"               images.architecture) ".
			"where images.imageid='$imageid'");
    }
    else {
	my $clause  = (defined($osinfo) ?
		       "and osid='" . $osinfo->osid() . "'" : "");

	$query_result =
	    DBQueryWarn("select distinct type from osidtoimageid ".
			"where imageid='$imageid' $clause");
    }
    return undef
	if (!defined($query_result));

    while (my ($type) = $query_result->fetchrow_array()) {
	my $typeinfo = NodeType->Lookup($type);
	push(@result, $typeinfo)
	    if (defined($typeinfo));
    }
    if ($self->architecture()) {
	require OSinfo;
	my $osinfo = OSinfo->Lookup($self->imageid());
	if (defined($osinfo) && defined($osinfo->def_parentosid())) {
	    my $pcvm = NodeType->Lookup("pcvm");
	    if (defined($pcvm)) {
		push(@result, $pcvm);
	    }
	}
    }
    
    return @result;
}

#
# Grant/Revoke permission to access an image.
#
sub GrantAccess($$$)
{
    my ($self, $target, $writable) = @_;
    $writable = ($writable ? 1 : 0);

    my $imageid   = $self->imageid();
    my $imagename = $self->imagename();
    my ($perm_idx, $perm_id, $perm_type);

    if (ref($target) eq "User") {
	$perm_idx  = $target->uid_idx();
	$perm_id   = $target->uid();
	$perm_type = "user";
    }
    elsif (ref($target) eq "Group") {
	$perm_idx  = $target->gid_idx();
	$perm_id   = $target->pid() . "/" . $target->gid();
	$perm_type = "group";
    }
    elsif (ref($target) eq "Project") {
	$perm_idx  = $target->gid_idx();
	$perm_id   = $target->pid() . "/" . $target->gid();
	$perm_type = "group";
    } 

    return -1
	if (!DBQueryWarn("replace into image_permissions set ".
			 "  imageid='$imageid', imagename='$imagename', ".
			 "  permission_type='$perm_type', ".
			 "  permission_id='$perm_id', ".
			 "  permission_idx='$perm_idx', ".
			 "  allow_write='$writable'"));
    return 0;
}

sub LookupAccess($$$$)
{
    my ($self, $target, $paccess, $pwriteable) = @_;

    my $imageid   = $self->imageid();
    my $imagename = $self->imagename();
    my ($perm_idx, $perm_id, $perm_type);

    if (ref($target) eq "User") {
	$perm_idx  = $target->uid_idx();
	$perm_id   = $target->uid();
	$perm_type = "user";
    }
    elsif (ref($target) eq "Group") {
	$perm_idx  = $target->gid_idx();
	$perm_id   = $target->pid() . "/" . $target->gid();
	$perm_type = "group";
    }
    my $query_result =
	DBQueryWarn("select allow_write from image_permissions ".
		    "where imageid='$imageid' and ".
		    "      permission_type='$perm_type' and ".
		    "      permission_idx='$perm_idx'");
    return -1
	if (!$query_result);
    if (!$query_result->numrows) {
	$$paccess    = 0;
	$$pwriteable = 0 if (defined($pwriteable));
	return 0;
    }
    my ($writeable) = $query_result->fetchrow_array();
    $$paccess    = 1;
    $$pwriteable = $writeable if (defined($pwriteable));
    return 0;
}

sub RevokeAccess($$)
{
    my ($self, $target) = @_;

    my $imageid   = $self->imageid();
    my ($perm_idx, $perm_type);

    if (ref($target) eq "User") {
	$perm_idx  = $target->uid_idx();
	$perm_type = "user";
    }
    if (ref($target) eq "Group") {
	$perm_idx  = $target->gid_idx();
	$perm_type = "group";
    }

    return -1
	if (!DBQueryWarn("delete from image_permissions ".
			 "where imageid='$imageid' and ".
			 "  permission_type='$perm_type' and ".
			 "  permission_idx='$perm_idx'"));
    return 0;
}

#
# Class method to record image history info. 
#
sub RecordImageHistory($$$$$$)
{
    my ($class, $experiment, $action, $log_session, $impotent, $noderef) = @_;
    require Node;
    
    # Flush info; we want most recent.
    $experiment->Refresh();
    
    my $exptidx   = $experiment->idx();
    my $pid       = $experiment->pid();
    my $eid       = $experiment->eid();
    my $state     = $experiment->state();
    my $rsrcidx   = $experiment->rsrcidx();
    my $lastrsrc  = $experiment->lastrsrc();
    $log_session  = 'NULL' if (!defined($log_session));

    my %prev_alloc;
    my $cant_find_prev_alloc = 0;
    if ($state eq 'modify_reswap') {
	if (!defined($lastrsrc)) {
	    print STDERR "lastrsrc not set during swapmod\n";
	    return -1;
	}
	my $db_result =
	    DBQueryWarn("select node_id from image_history ".
			"where rsrcidx=$lastrsrc");
	return -1
	    if (!$db_result);
	
	if ($db_result->numrows() < 1) {
	    print STDERR "could not find previous state (rsrcidx=$lastrsrc) ".
		"in image_history table, won't be able to determine ".
		"newly allocated nodes\n";
	    $cant_find_prev_alloc = 1;
	}
	while (my $n = $db_result->fetchrow) {
	    $prev_alloc{$n} = 1;
	}
    }

    foreach my $node_id (keys(%{$noderef})) {
	my $node = Node->Lookup($node_id);
	if (! defined($node)) {
	    print STDERR "No DB record for $node_id\n";
	    next;
	}
	# Need uptodate info below.
	$node->FlushReserved();
	
	my $ref  = $noderef->{$node_id};
	my ($osinfo, $image) = @{$ref};
	my $newly_alloc      = (exists($prev_alloc{$node_id}) ? 0 : 1);
	$newly_alloc = 'NULL'
	    if ($cant_find_prev_alloc);

	my $history_result =
	    DBQueryWarn("select max(history_id) ".
			"  from node_history where node_id = '$node_id'");
	return -1
	    if (! $history_result);

	if (! $history_result->numrows) {
	  nohistory:
	    print STDERR "No node_history for $node_id, ".
		"cannot log image usage for node.\n";
	    next;
	}
	my ($node_history_id) = $history_result->fetchrow_array();
	if (!defined($node_history_id)) {
	    goto nohistory;
	}
	my $vname      = $node->vname();
	my $erole      = $node->erole();
	my $phys_type  = $node->type();

	if (!defined($vname)) {
	    print STDERR "$node is no longer reserved!\n";
	    next;
	}

	# Ick. Should go into the Node object.
	my ($virt_result) =
	    DBQueryWarn("select osname,type from virt_nodes ".
			"where exptidx='$exptidx' and vname='$vname'");
	return -1
	    if (!$virt_result);
	if (!$virt_result->numrows) {
	    print STDERR "No virt info for node $node_id ($vname)\n";
	    next;
	}
	my ($osname, $req_type) = $virt_result->fetchrow_array();
	my $req_os = defined $osname ? ($osname ? 1 : 0) : 'NULL';
	$erole = 'delay' if $erole eq 'delaynode';
	$req_type = $erole unless defined $req_type;
	my $osid      = $osinfo->osid();
	my $osid_vers = $osinfo->vers();
	my $imageid   = 0;
	my $version   = 0;
	if (defined($image)) {
	    $imageid  = $image->imageid();
	    $version  = $image->version();
	}

	next
	    if ($impotent);
	
	DBQueryWarn("insert into image_history ".
		    "(stamp, node_history_id, node_id, ".
		    " action, newly_alloc, rsrcidx, log_session, ".
		    " req_type, phys_type, req_os, ".
		    " osid, osid_vers, imageid, imageid_version) ".
		    "values(UNIX_TIMESTAMP(now()), ".
		    "       $node_history_id, '$node_id', '$action', ".
		    "       $newly_alloc, $rsrcidx, ".
		    "       $log_session, '$req_type', '$phys_type', ".
		    "       $req_os, $osid, $osid_vers, $imageid, $version)")
	    or return -1;
    }
    return 0;
}

#
# Record more concise success/failure of an image each time it boots.
#
sub RecordImageStatus($$$$)
{
    my ($self, $experiment, $node, $status) = @_;
    my $type    = $node->type();
    my $node_id = $node->node_id();
    my $rsrcidx = $experiment->rsrcidx();
    my $exptidx = $experiment->idx();
    my $imageid = $self->imageid();
    my $version = $self->version();
    
    DBQueryWarn("insert into image_boot_status ".
		    "(stamp, exptidx, rsrcidx, node_id, node_type, ".
		    " imageid, imageid_version, status) ".
		    "values(UNIX_TIMESTAMP(now()), ".
		    "       $exptidx, $rsrcidx, '$node_id', '$type', ".
		    "       $imageid, $version, '$status')")
	    or return -1;
    return 0;
}

#
# List of images created by a user urn.
#
sub ListForURN($$)
{
    my ($class, $urn) = @_;
    my @result = ();

    return undef
	if (! $PGENISUPPORT);

    require GeniHRN;
    return undef
	if (! GeniHRN::IsValid($urn));

    my $query_result =
	DBQueryWarn("select imageid,version from image_versions ".
		    "where creator_urn='$urn' and deleted is null and ".
		    "      isdataset=0 ".
		    "order by pid,imagename,version");

    while (my ($imageid,$version) = $query_result->fetchrow_array()) {
	# Want latest version.
	my $image = Image->Lookup($imageid, $version);
	next
	    if (!defined($image));

	push(@result, $image);
    }

    return @result;
}

#
# List of images for a Group
#
sub ListForGroup($$)
{
    my ($class, $group) = @_;
    my @result = ();
    my $pid_idx = $group->pid_idx();
    my $gid_idx = $group->gid_idx();

    my $query_result =
	DBQueryWarn("select imageid,version from image_versions ".
		    "where pid_idx='$pid_idx' and gid_idx='$gid_idx' and ".
		    "      deleted is null and isdataset=0 ".
		    "order by imagename,version");

    while (my ($imageid,$version) = $query_result->fetchrow_array()) {
	# Want latest version.
	my $image = Image->Lookup($imageid, $version);
	next
	    if (!defined($image));

	push(@result, $image);
    }

    return @result;
}

#
# Set to use the logfile. It becomes the "current" spew.
#
sub SetLogFile($$)
{
    my ($self, $logfile) = @_;

    return -1
	if ($self->Update({'logfileid' => $logfile->logid()}));

    # Set the metadata so we can associate logfiles with this image.
    $logfile->SetMetadata({"image_uuid"   => $self->image_uuid(),
			   "version_uuid" => $self->uuid()});

    return 0;
}

# Ready bit.
sub SetReady($$)
{
    my ($self, $ready) = @_;

    return -1
	if ($self->Update({'ready' => $ready}));

    return 0;
}
sub MarkReady($)   { return SetReady($_[0], 1); }
sub ClearReady($) { return SetReady($_[0], 0); }
# Released bit.
sub MarkReleased($)
{
    my ($self) = @_;

    return -1
	if ($self->Update({'released' => 1}));

    return 0;
}
# Last used, for datasets.
sub BumpLastUsed($)
{
    my ($self) = @_;
    my $imageid = $self->imageid();
    my $version = $self->version();

    return -1
	if (! DBQueryWarn("update image_versions set last_used=now() ".
			  "where imageid='$imageid' and version='$version'"));
    return 0;
}

# Are two images the same.
sub SameImage($$)
{
    my ($this, $that) = @_;

    return (($this->imageid() == $that->imageid() &&
	     $this->version() == $that->version()) ? 1 : 0);
}

#
# Get the logfile.
#
sub GetLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));

    # Must do this to catch updates to the logfile variables.
    return undef
	if ($self->Refresh());

    return undef
	if (! $self->logfileid());

    return Logfile->Lookup($self->logfileid());
}

#
# And clear it ...
#
sub ClearLogFile($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $logfile = $self->GetLogFile();
    return -1
	if (!defined($logfile));

    $logfile->Delete(1) == 0
	or return -1;

    my $imageid = $self->imageid();
    my $version = $self->version();
    DBQueryWarn("update image_versions set logfileid=NULL ".
		"where imageid='$imageid' and version='$version'")
	or return -1;

    $self->logfileid(undef);
    return 0;
}

#
# Mark an image as running on a type. I am assuming EZ images these days.
#
sub SetRunsOnNodeType($$)
{
    my ($self, $type) = @_;

    my $imageid = $self->imageid();

    DBQueryWarn("replace into osidtoimageid (osid, type, imageid) ".
		"values ('$imageid', '$type', '$imageid')")
	or return -1;

    return 0;
}

#
# If using the image tracker, have to notify the IMS.
#
sub SchedIMSDeletion($$)
{
    my ($self,$allversions) = @_;
    my $urn  = $self->urn();
    my $uuid = ($allversions ? $self->image_uuid() : $self->uuid());

    # The expire daemon will pick this up.
    DBQueryWarn("replace into image_deletions set ".
		" urn='$urn',image_uuid='$uuid',deleted=now()")
	or return -1;

    return 0;
}

#
# Is the image the newest version of the image.
#
# This needs to include deleted images, we only care about max version
# number right now. 
#
sub IsNewest($)
{
    my ($self)  = @_;
    my $imageid = $self->imageid();
    
    my $query_result =
	DBQueryWarn("select max(version) from image_versions ".
		    "where imageid='$imageid'");

    return -1
	if (!$query_result || !$query_result->numrows);

    my ($max) = $query_result->fetchrow_array();

    return ($max == $self->version() ? 1 : 0);
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
	if (!defined($self->parent_imageid()));

    return Image->Lookup($self->parent_imageid(), $self->parent_version());
}

sub SetDelta($$)
{
    my ($self, $delta) = @_;

    return -1
	if ($self->Update({'isdelta' => $delta}));

    return 0;
}

sub SetSize($$)
{
    my ($self, $size) = @_;

    return -1
	if ($self->Update({'size' => $size}));

    return 0;
}

sub SetHash($$)
{
    my ($self, $hash) = @_;

    return -1
	if ($self->Update({'hash' => $hash}));

    return 0;
}

sub SetNoVersioning($$)
{
    my ($self, $value) = @_;
    $value = ($value ? 1 : 0);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set noversioning='$value' " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'noversioning'} = $value;
    return 0;
}

sub SetImageMetadataURL($$)
{
    my ($self, $url) = @_;
    $url = DBQuoteSpecial($url);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set metadata_url=$url " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'image_metadata_url'} = $url;
    return 0;
}

sub SetImageFileURL($$)
{
    my ($self, $url) = @_;
    $url = DBQuoteSpecial($url);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();
    my $version = $self->version();

    DBQueryWarn("update image_versions set imagefile_url=$url ".
		"where imageid='$imageid' and version='$version'")
	or return -1;
	    
    $self->{'IMAGE'}->{'image_metadata_url'} = $url;
    return 0;
}

sub SetImageRelocateURN($$)
{
    my ($self, $urn) = @_;
    if (defined($urn)) {
	$urn = DBQuoteSpecial($urn);
    }
    else {
	$urn = "NULL";
    }

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set relocate_urn=$urn " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'relocate_urn'} = $urn;
    return 0;
}

sub SetCredential($$)
{
    my ($self, $credstr) = @_;
    if (defined($credstr)) {
	$credstr = DBQuoteSpecial($credstr);
    }
    else {
	$credstr = "NULL";
    }

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set credential_string=$credstr " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'credential_string'} = $credstr;
    return 0;
}

sub SetListed($$)
{
    my ($self, $onoff) = @_;
    $onoff = ($onoff ? 1 : 0);
    my $imageid = $self->imageid();

    return -1
	if (! DBQueryWarn("update images set listed='$onoff' " .
			  "where imageid='$imageid'"));
	    
    $self->{'IMAGE'}->{'listed'} = $onoff;
    return 0;
}

sub SetFormat($$)
{
    my ($self, $format) = @_;

    return -1
	if ($self->Update({'format' => $format}));

    return 0;
}

sub SetPath($$)
{
    my ($self, $path) = @_;

    return -1
	if ($self->Update({'path' => $path}));

    return 0;
}

sub LocalURL($)
{
    my ($self) = @_;
    my $image_uuid = $self->image_uuid();

    return "$TBBASE/image_metadata.php?uuid=$image_uuid";
}

sub LocalVersionURL($)
{
    my ($self) = @_;
    my $uuid = $self->uuid();

    return "$TBBASE/image_metadata.php?uuid=$uuid";
}

sub HasCredential($)
{
    my ($self) = @_;

    return undef
	if (! $PGENISUPPORT);

    return $self->credential_string() && $self->credential_string() ne "";
}
sub GetCredential($)
{
    my ($self) = @_;

    return undef
	if (! ($PGENISUPPORT && $self->HasCredential()));

    require GeniCredential;
    return GeniCredential->CreateFromSigned($self->credential_string());
}

#
# Deprecate an image.
#
sub Deprecate($;$$)
{
    my ($self, $message, $iserror) = @_;
    my $imageid = $self->imageid();
    if (defined($iserror)) {
	$iserror = ($iserror ? 1 : 0);
    }
    my $query = "update image_versions set deprecated=now()";
    $query .=   ",deprecated_iserror='$iserror'" if (defined($iserror));
    if (defined($message)) {
	if ($message ne "") {
	    $query .= ",deprecated_message=" . DBQuoteSpecial($message);
	}
	else {
	    $query .= ",deprecated_message=NULL";
	}
    }
    DBQueryWarn("$query where imageid='$imageid'")
	or return -1;

    return 0;
}
sub IsDeprecated($$;$$)
{
    my ($self, $pval, $pmessage, $piserror) = @_;
    my $imageid = $self->imageid();
    my $version = $self->version();

    my $query_result =
	DBQueryWarn("select deprecated,deprecated_message,deprecated_iserror ".
		    "  from image_versions ".
		    "where imageid='$imageid' and version='$version'");
    return -1
	if (! ($query_result && $query_result->numrows));

    my ($deprecated, $message, $iserror) = $query_result->fetchrow_array();
    $$pval     = $deprecated;
    $$pmessage = $message if (defined($pmessage));
    $$piserror = $iserror if (defined($piserror));
    return 0;
}

sub DeprecatedMessage($;$)
{
    my ($self, $experiment) = @_;
    my $message = $self->deprecated_message();
    my $iserror = $self->deprecated_iserror();
    my $name    = $self->pid() . "/" . $self->imagename();
    my $result;

    if ($iserror) {
	$result = "Image $name is deprecated and no longer available to use".
	    (defined($message) && $message ne "" ? ": ${message}" : "") .
	    ". " . "Please choose a different image!";
    }
    else {
	$result = "Image $name is deprecated and should no longer be used".
	    (defined($message) && $message ne "" ? ": ${message}" : "") .
	    ". " . "You can continue to use this image for now but you should ".
	    "choose a different one before this image is deleted!";
    }
    if (defined($experiment)) {
	my $pid = $experiment->pid();
	my $eid = $experiment->eid();

	$result = "Experiment $pid/$eid: $result";
    }
    return $result;
}
sub SendDeprecatedMail($$;$)
{
    my ($self, $user, $experiment) = @_;
    my $message = $self->DeprecatedMessage($experiment);
    $user->SendEmail("Deprecated Image Warning", $message);
    return 0;
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
    #
    # Does the path indicate a directory or a file.
    #
    if (!defined($self->path())) {
	print STDERR "No path is set for $self\n";
	return 0;
    }
    return 1
	if ($self->path() =~ /\/$/
	    && (!defined($self->format()) || $self->format() ne 'docker'));
    return 0;
}
sub FullImagePath($)
{
    my ($self) = @_;
    my $path   = $self->path();
    my $vers   = $self->version();
    my $name   = $self->imagename();

    #
    # Watch for an unreleased system image; in that case we want to
    # target that unreleased file in /proj. So we ignore the path in
    # the DB and construct the /proj path instead. 
    #
    if ($self->IsSystemImage() && !$self->released()) {
	$path = $self->SaveDir();
    }
    
    if ($self->IsDirPath()) {
	return $path . $name . ".ndz" . ($vers ? ":$vers" : "");
    }
    return $path;
}
sub DeltaImagePath($)
{
    my ($self) = @_;
    my $path   = $self->path();
    my $vers   = $self->version();
    my $name   = $self->imagename();
    
    #
    # Watch for an unreleased system image; in that case we want to
    # target that unreleased file in /proj. So we ignore the path in
    # the DB and construct the /proj path instead.
    #
    if ($self->IsSystemImage() && !$self->released()) {
	$path = $self->SaveDir();
    }
    
    if ($self->IsDirPath()) {
	return $path . $name . ".ddz" . ($vers ? ":$vers" : "");
    }
    return $path;
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
    my $path   = $self->path();
    my $vers   = $self->version();
    my $name   = $self->imagename();

    if ($self->IsDirPath()) {
	return $path . $name . ".ndz" . ($vers ? ":$vers" : "") . ".tmp";
    }
    return $path . ".tmp";
}
sub FullImageSHA1File($)
{
    my ($self) = @_;
    return $self->FullImagePath() . ".sha1";
}
sub DeltaImageSHA1File($)
{
    my ($self) = @_;
    return $self->DeltaImagePath() . ".sha1";
}
sub FullImageSigFile($)
{
    my ($self) = @_;
    return $self->FullImagePath() . ".sig";
}
sub DeltaImageSigFile($)
{
    my ($self) = @_;
    return $self->DeltaImagePath() . ".sig";
}
sub HaveFullImage($)
{
    my ($self) = @_;
    return $self->size() ? 1 : 0;
}
sub HaveDeltaImage($)
{
    my ($self) = @_;
    return $self->deltasize() ? 1 : 0;
}
sub IsSystemImage($)
{
    my ($self) = @_;

    # Yuck.
    return ($self->path() =~ /^\/usr\/testbed\// ? 1 : 0
	    || ($self->format() eq 'docker' && $self->global()
		&& $self->path() =~ /emulab-ops\/emulab-ops/));
}
#
# When images are stored in sub directories.
#
sub CreateImageDir($)
{
    my ($self) = @_;
    
    return 0
	if (!$self->IsDirPath());

    #
    # For system images that are written to $TB, we still need a place
    # to write new (unreleased) images in /proj. 
    #
    if ($self->IsSystemImage()) {
	return -1
	    if ($self->CreateDirectory($self->SaveDir()));

	# If we are not setuid, this will just fail. 
	my $SAVEUID = $EUID;
	$EUID = 0;
	my $rval = $self->CreateDirectory($self->path());
	$EUID = $SAVEUID;
	return -1
	    if ($rval);
    }
    else {
	return -1
	    if ($self->CreateDirectory($self->path()));
    }
    return 0;
}
#
# Delete, after failure to avoid cruft.
#
sub DeleteImageDir($)
{
    my ($self) = @_;
    
    return 0
	if (!$self->IsDirPath());

    my $directory;

    if ($self->IsSystemImage()) {
	$directory = $self->SaveDir();
    }
    else {
	$directory = $self->path();
    }
    return 0
	if (! -e $directory);

    #
    # This can lead to bad things, so lets not try too hard.  Just do a
    # rmdir, and if its not empty or not enough permission, fine. Might
    # revisit later.
    #
    rmdir($directory);
    
    return 0;
}

sub CreateDirectory($$)
{
    my ($self, $directory) = @_;

    if (! -e $directory) {
	if (!mkdir($directory, 0775)) {
	    print STDERR "Could not mkdir $directory: $!\n";
	    return -1;
	}
	if (!chmod(0775, $directory)) {
	    print STDERR "Could not chmod $directory: $!\n";
	    return -1;
	}
    }
    
    # If we are root and had to create the directory, then the owner
    # and group are going to be set wrong.
    if ($EUID == 0) {
	my $group = $self->GetGroup();
	if (!defined($group)) {
	    print STDERR "Could not get group for $self\n";
	    return -1;
	}
	my $leader = $group->GetLeader();
	if (!defined($leader)) {
	    print STDERR "Could not get leader for $group\n";
	    return -1;
	}
	my $uid = $leader->unix_uid();
	my $gid = $group->unix_gid();

        if (! chown($uid, $gid, $directory)) {
	    print STDERR "Could not chown($uid,$gid) $directory: $!\n";
	    return -1;
	}
    }
    return 0;
}

#
# Where we write the new files. 
# I think cause we do not trust the path in the descriptor since the
# user can set it. This is probably the crux; we should not let the
# user set the path.
#
sub SaveDir($)
{
    my ($self) = @_;

    my $savedir =
	($self->pid() eq $self->gid() ||
	 $self->global() || $self->IsSystemImage() ? 
	 $PROJROOT . "/" . $self->pid() . "/images/" :
	 $GROUPROOT . "/" . $self->pid() . "/" . $self->gid() . "/images/");
    
    # Add in the directory.
    $savedir .= basename($self->path()) . "/"
	if ($self->IsDirPath());

    return $savedir;
}

#
# Convert an imported image to a local image.
#
sub ConvertToLocal($)
{
    my ($self) = @_;
    
    my $args = {
	"imagefile_url"  => undef,
	"metadata_url"   => undef,
	"origin_name"    => undef,
	"origin_uuid"    => undef,
	"origin_urn"     => undef,
    };
    $self->SetNoVersioning(0);
    return $self->Update($args);
}

#
# Convert a local image to an imported image.
#
sub ConvertToImported($$)
{
    my ($self, $metadata) = @_;
    
    my $args = {
	"imagefile_url"  => $metadata->{"imagefile_url"},
	"metadata_url"   => $metadata->{"metadata_url"},
	"origin_name"    => $metadata->{"origin_name"},
	"origin_uuid"    => $metadata->{"origin_uuid"},
	"origin_urn"     => $metadata->{"origin_urn"},
    };
    return $self->Update($args);
}

#
# Get size of the file on the disk We know we are setuid when we call it.
# Use this to determine image import progress, in the "resume" case, where
# image_import is starting again to continue downloading an image where it
# left off. This is information purposes only, so we can provide feedback
# to the user.
#
# Returns KB.
#
sub ImportImageFileSize($)
{
    my ($self) = @_;
    my $filename = $self->FullImageFile() . ".new";
    my $SAVEUID  = $UID;

    $UID = 0;
    if (! -e $filename) {
	$UID = $SAVEUID;
	return 0;
    }

    my $cursize = (stat($filename))[7];
    if (!defined($cursize)) {
	$cursize = 0;
    }
    $cursize = int($cursize / 1024);
    $UID = $SAVEUID;
    return $cursize;
}

#
# Is an image in use and should not be deleted.
#
sub InUse($)
{
    my ($self) = @_;
    my $imageid = $self->imageid();
    my $version = $self->version();

    my $query_result =
	DBQueryWarn("select node_id from nodes ".
		    "where def_boot_osid='$imageid' and ".
		    "      def_boot_osid_vers='$version'");
    return 1
	if (!$query_result || $query_result->numrows);

    $query_result =
	DBQueryWarn("select * from current_reloads ".
		    "where image_id='$imageid' and imageid_version='$version'");
    return 1
	if (!$query_result || $query_result->numrows);

    $query_result =
	DBQueryWarn("select * from scheduled_reloads ".
		    "where image_id='$imageid'");
    return 1
	if (!$query_result || $query_result->numrows);

    return 0;
}

#############################################################################
#
# Pending Import support. 
#
package Image::PendingImport;
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
use overload ('""' => 'Stringify');

AUTOLOAD {
    my $self  = $_[0];
    my $type  = ref($self) or croak "$self is not an object";
    my $name  = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    # A DB row proxy method call.
    if (exists($self->{'IMPORT'}->{$name})) {
	# Allow update.
	if (scalar(@_) == 2) {
	    $self->{'IMPORT'}->{$name} = $_[1];
	}
	return $self->{'IMPORT'}->{$name};
    }
    print STDERR Dumper($self);
    carp("No such slot '$name' field in class $type");
    return undef;
}
sub field($$) {
    my ($self, $name) = @_;
    
    if (exists($self->{'IMPORT'}->{$name})) {
	return $self->{'IMPORT'}->{$name};
    }
    return undef;
}
sub fieldSet($$$) {
    my ($self, $name, $value) = @_;

    $self->{'IMPORT'}->{$name} = $value;
    return $value;
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{'IMPORT'} = undef;
}

sub Delete($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    DBQueryWarn("delete from image_pending_imports where idx='$idx'");

    return 0;
}

#
# Create, always return it locked.
#
sub Create($$)
{
    my ($class, $argref) = @_;
    my @required = ("imagename", "metadata_url");

    if (!exists($argref->{"type"})) {
	print STDERR "Image::PendingImport::Create(): missing type\n";
	return undef;
    }
    my $type = $argref->{"type"};

    #
    # Depending on the type, we have to have certain fields.
    #
    if ($type eq "import") {
	@required = (@required, "uid", "uid_idx", "pid", "pid_idx");
    }
    elsif ($type eq "relocation") {
	@required = (@required, "uid", "uid_idx", "pid", "pid_idx",
		     "gid", "gid_idx", "remote_urn");
    }
    elsif ($type eq "copyback") {
	@required = (@required, "uid", "uid_idx", "pid", "pid_idx",
		     "gid", "gid_idx", "remote_urn", "imageid", "uid_urn");
    }
    else {
	print STDERR "Image::PendingImport::Create(): bad type: $type\n";
	return undef;
    }
    foreach my $key (@required) {
	if (!exists($argref->{$key})) {
	    print STDERR "Image::PendingImport::Create(): ".
		"missing key: $key\n";
	    return undef;
	}
    }
    my @sets = ();
    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	# Treat NULL special.
	push (@sets, "${key}=" .
	      (!defined($val) || $val eq "NULL" ?
	       "NULL" : DBQuoteSpecial($val)));
    }
    push(@sets, "created=now()");
    my $query = "insert into image_pending_imports set " . join(",", @sets);

    return undef
	if (!DBQueryWarn("lock tables images write, ".
			 "            image_pending_imports write"));

    my $pending = Lookup($class, $argref->{'metadata_url'});
    if (defined($pending)) {
	DBQueryWarn("unlock tables");
	return $pending;
    }
    if (!DBQueryWarn($query)) {
	DBQueryWarn("unlock tables");
	return undef;
    }
    DBQueryWarn("unlock tables");
    return Lookup($class, $argref->{"metadata_url"});
}

#
# metadata_url is the primary key. 
#
sub Lookup($$)
{
    my ($class, $token) = @_;
    my $query_result;

    if ($token =~ /^\d+$/) {
	$query_result = DBQueryWarn("select * from image_pending_imports ".
				    "where idx='$token'");
    }
    elsif ($token =~ /^http/) {
	my $safe_token = DBQuoteSpecial($token);
	$query_result = DBQueryWarn("select * from image_pending_imports ".
				    "where metadata_url=$safe_token");
    }
    else {
	return undef;
    }
    return undef
	if (! (defined($query_result) && $query_result->numrows));
    
    my $self           = {};
    $self->{'IMPORT'}  = $query_result->fetchrow_hashref();

    bless($self, $class);
    return $self;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $idx       = $self->idx();
    my $pid       = $self->pid();
    my $imagename = $self->imagename();

    return "[Image::PendingImport idx:$idx $pid,$imagename]";
}

#
# Lock and Unlock. 
#
sub Lock($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    return -1
	if (!DBQueryWarn("lock tables images write, ".
			 "            image_pending_imports write"));

    my $query_result =
	DBQueryWarn("update image_pending_imports set ".
		    "  locked=now(),locker_pid=$PID " .
		    "where idx='$idx' and locked is null");

    if (! $query_result ||
	$query_result->numrows == 0) {
	DBQueryWarn("unlock tables");
	return -1;
    }
    DBQueryWarn("unlock tables");
    $self->fieldset("locked", time());
    $self->fieldset("locker_pid", $PID);
    return 0;
}

sub Unlock($)
{
    my ($self) = @_;
    my $idx = $self->idx();

    return -1
	if (! DBQueryWarn("update image_pending_imports set ".
			  "   locked=null,locker_pid=0 " .
			  "where idx='$idx'"));
    
    $self->fieldset("locked", 0);
    $self->fieldset("locker_pid", 0);
    return 0;
}

sub GotLock($)
{
    my ($self) = @_;

    return 1
	if ($self->locked() && $self->locker_pid() == $PID);
    return 0;
}

sub GetImage($)
{
    my ($self) = @_;
    return undef
	if (!defined($self->imageid()));

    return Image->Lookup($self->imageid());
}

sub Failed($$)
{
    my ($self, $message) = @_;
    my $safe_message = DBQuoteSpecial($message);
    my $idx = $self->idx();

    DBQueryWarn("update image_pending_imports set ".
		"  failed=now(),failure_message=$safe_message ".
		"where idx='$idx'")
	or return -1;

    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
