#!/usr/bin/perl -wT
#
# Copyright (c) 2007-2021 University of Utah and the Flux Group.
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
package Logfile;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use emdb;
use emutil;
use libtestbed;
use English;
use Errno;
use Fcntl;
use POSIX;
use Data::Dumper;
use overload ('""' => 'Stringify');

# Configure variables
my $TB		  = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $TBOPS         = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBBASE        = "https://www.cloudlab.umass.edu";
my $GZIP	  = "/usr/bin/gzip";
my $GUNZIP        = "/usr/bin/gunzip";

#
# Lookup by uuid. For now, just knowing the uuid says you can read the file. 
#
sub Lookup($$)
{
    my ($class, $logid) = @_;
    my $logfile;
    my $query_result;

    #
    # Argument must be alphanumeric.
    #
    if ($logid =~ /^([\d]*)$/) {
	$query_result =
	    DBQueryWarn("select logid from logfiles where logidx='$logid'");

	return undef
	    if (!$query_result || !$query_result->numrows);

	if ($query_result->numrows > 1) {
	    print STDERR "*** More then one entry for $logid\n";
	    return undef;
	}
	($logid) = $query_result->fetchrow_array();
    }
    elsif ($logid =~ /^([\w]*)$/) {
	$logid = $1;
    }
    elsif ($logid =~ /^\/[\w\/\.]*$/) {
	$query_result =
	    DBQueryWarn("select logid from logfiles where filename='$logid'");

	return undef
	    if (!$query_result || !$query_result->numrows);

	if ($query_result->numrows > 1) {
	    print STDERR "*** More then one entry for $logid\n";
	    return undef;
	}
	($logid) = $query_result->fetchrow_array();
    }
    else {
	return undef;
    }

    $query_result =
	DBQueryWarn("select * from logfiles where logid='$logid'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my $self                = (ref($class) ? $class : {});
    $self->{'LOGFILE'}      = $query_result->fetchrow_hashref();
    $self->{'FP'}           = (ref($class) ? $class->{'FP'} : undef);
    $self->{'METADATA'}     = undef;
    # Ordered list.
    $self->{'METADATALIST'} = undef;
    my $logidx = $self->{'LOGFILE'}->{'logidx'};

    my $metadata_result =
	DBQueryWarn("select metakey,metaval from logfile_metadata ".
		    "where logidx='$logidx' order by idx");
    if ($metadata_result && $metadata_result->numrows) {
	$self->{'METADATA'} = {};
	$self->{'METADATALIST'} = [];
	my $idx = 0;

	while (my ($key,$val) = $metadata_result->fetchrow_array()) {
	    $self->{'METADATA'}->{$key} = $val;
	    $self->{"METADATALIST"}->[$idx] = [$key, $val];
	    $idx++;
	}
    }
    bless($self, $class) if (!ref($class));
    
    return $self;
}
# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'LOGFILE'}->{$_[1]}); }
sub logid($)            { return field($_[0], "logid"); }
sub logidx($)           { return field($_[0], "logidx"); }
sub filename($)         { return field($_[0], "filename"); }
sub isopen($)           { return field($_[0], "isopen"); }
sub gid_idx($)          { return field($_[0], "gid_idx"); }
sub date_created($)     { return field($_[0], "date_created"); }
sub public($)           { return field($_[0], "public"); }
sub compressed($)       { return field($_[0], "compressed"); }
sub stored($)           { return field($_[0], "stored"); }
sub filedescriptor($)	{ return $_[0]->{'FP'}; }
sub Metadata($)		{ return $_[0]->{'METADATA'}; }
sub MetadataList($)	{ return $_[0]->{'METADATALIST'}; }

#
# Return metadata value or undef
#
sub MetadataValue($$)
{
    my ($self, $key) = @_;

    return undef
	if (!$self->Metadata());

    return undef
	if (!exists($self->Metadata()->{$key}));
    
    return $self->Metadata()->{$key};
}

# Break circular reference someplace to avoid exit errors.
sub DESTROY {
    my $self = shift;

    $self->{"LOGFILE"}       = undef;
    $self->{"METADATA"}      = undef;
    $self->{"METADATALIST"}  = undef;
    $self->{"FP"}            = undef;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;

    my $filename = $self->filename();
    my $logidx   = $self->logidx();

    return "[Logfile: $logidx" .
	(defined($filename) ? ", $filename" : "") . "]";
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return 0
	if ($self->Lookup($self->logid()));

    return -1;
}

#
# Create a new logfile. We are given the optional filename, otherwise
# generate one. 
#
sub Create($$;$)
{
    my ($class, $group, $filename) = @_;
    my $gid_idx = (ref($group) ? $group->gid_idx() : $group);

    return undef
	if (ref($class));

    # Plain secret key, which is used to reference the file.
    my $logid  = TBGenSecretKey();
    my $logidx = TBGetUniqueIndex('next_logfile', 1);

    # This creates the file, so the owner/group are current user/group.
    if (!defined($filename)) {
	$filename = TBMakeLogname("logfile");
	
	# So tbops people can read the files ...
	if (!chmod(0664, $filename)) {
	    print STDERR "Could not chmod $filename to 0644: $!\n";
	    unlink($filename);
	    return undef;
	}
    }

    if (!DBQueryWarn("insert into logfiles set ".
		     "  logid='$logid', logidx='$logidx', ".
		     "  isopen=0, ".
		     "  filename='$filename', ".
		     "  gid_idx='$gid_idx', ".
		     "  date_created=now()")) {
	return undef;
    }
    return Logfile->Lookup($logid);
}

#
# Create from a string.
#
sub CreateFromString($$$)
{
    my ($class, $group, $string) = @_;
    my $logfile = Logfile->Create($group);
    return undef
	if (!defined($logfile));

    my $filename = $logfile->filename();
    if (open(LOG, ">$filename")) {
	print LOG $string;
	close(LOG);
    }
    else {
	print STDERR "Logfile::CreateFromString: Cannot write to $filename\n";
	$logfile->Delete(1);
	return undef;
    }

    return $logfile;
}

#
# Delete a logfile record. Optionally delete the logfile too.
#
sub Delete($;$)
{
    my ($self, $delete) = @_;

    return -1
	if (!ref($self));

    $delete = 0
	if (!defined($delete));

    my $logid    = $self->logid();
    my $logidx   = $self->logidx();
    my $filename = $self->filename();
    if ($delete) {
	unlink($filename);
    }
    return -1
	if (!DBQueryWarn("delete from logfile_metadata ".
			 "where logidx='$logidx'"));
    return -1
	if (!DBQueryWarn("delete from logfiles where logid='$logid'"));

    return 0;
}

#
# AccessCheck. The user needs to be a member of the group that the logfile
# was created in. 
#
sub AccessCheck($$)
{
    my ($self, $user) = @_;
    require Group;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    # Public? Anyone can look at it.
    return 1
	if ($self->public());

    # Admins do whatever they want.
    return 1
	if ($user->IsAdmin());

    my $group = Group->Lookup($self->gid_idx());
    return 0
	if (!defined($group));

    # Membership in group.
    return 1
	if (defined($group->LookupUser($user)));

    return 0;
}

#
# Mark a file open so that the web interface knows to watch it.
#
sub Open($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $logid = $self->logid();
    DBQueryWarn("update logfiles set isopen=1 where logid='$logid'")
	or return -1;
    
    return $self->Refresh();
}

#
# Mark file closed, which is used to stop the web interface from spewing.
#
sub Close($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $logid = $self->logid();
    DBQueryWarn("update logfiles set isopen=0 where logid='$logid'")
	or return -1;
    
    return $self->Refresh();
}

#
# Clean up a logfile.
#
sub Clean($)
{
    my ($self) = @_;

    my $logid = $self->logid();
    DBQueryWarn("update logfiles set isopen=0,filename=NULL ".
		"where logid='$logid'")
	or return -1;
    
    return $self->Refresh();
}

#
# Is file empty?
#
sub Empty($)
{
    my ($self) = @_;
    my $filename = $self->filename();

    return 1
	if (! -e $filename || ! -s $filename);

    return 0;
}

#
# Return a logfile URL.
#
sub URL($)
{
    my ($self) = @_;

    return "$TBBASE/spewlogfile.php3?logfile=" . $self->logid(); 
}

#
# Mark public or private.
#
sub SetPublic($$)
{
    my ($self, $public) = @_;
    $public = ($public ? 1 : 0);

    return -1
	if (!ref($self));

    my $logid = $self->logid();
    DBQueryWarn("update logfiles set public='$public' where logid='$logid'")
	or return -1;
    
    return $self->Refresh();
}

#
# Move a log file from its current location to long term storage,
# compressing on the way. Then reset its location in the DB and
# mark it as compressed. 
#
sub Store($)
{
    my ($self) = @_;

    return -1
	if (!ref($self));

    my $logid    = $self->logid();
    my $filename = $self->filename();
    my $newname  = "/usr/testbed/log/logfiles";

    # Might as well. 
    $self->Close();

    #
    # Well, what if we have metadata but the logfile is empty? The
    # metadata is still interesting in some situations, but rather
    # then compress a null file and take an inode, just set the
    # filename to null. This currently happens from the protogeni API.
    # If the size of the logfiles table gets out of control, we can
    # revisit this, but I think we just need to age out old ones
    # on a regular basis. 
    #
    if (-e $filename && -s $filename) {
	#
	# Use first two letters of the id for the subdir. 
	#
	my $dir = lc(substr($logid, 0, 2));
	$newname = "$newname/$dir/${logid}.gz";

	if (-e $newname) {
	    print STDERR "Logfile::Store ($logid) - $newname exists\n";
	    return -1;
	}
	my $output = emutil::ExecQuiet("$GZIP -c $filename > $newname");
	if ($?) {
	    SENDMAIL($TBOPS, "Logfile Store Error",
		     "Failed to store $filename to $newname\n\n".
		     "-----------------\n".
		     "$output\n", $TBOPS);
	    return -1
	}
	$newname = "'" . $newname . "'";
    }
    else {
	$newname = "NULL";
    }
    unlink($filename);
    DBQueryWarn("update logfiles set ".
		"  `stored`=1,compressed=1,filename=$newname ".
		"where logid='$logid'")
	or return -1;

    return 0;
}

#
# Set the metadata (stuff to search on) for a log. Argument is an
# array of header,value pairs
#
sub SetMetadata($$$)
{
    my ($self, $argref, $purge) = @_;
    my @inserts = ();

    return -1
	if (!ref($self));

    my $logidx  = $self->logidx();

    # Purge old data
    DBQueryWarn("delete from logfile_metadata where logidx='$logidx'")
	if ($purge);

    my $coderef = sub {
	my ($key,$val) = @_;

	#
	# Ug, the value is a tinytext and some errors are longer.
	# Changing the field to a bigger slot would churn the Mothership
	# for days cause of the number of rows (and cause boss is slow).
	# So instead, just trim it. Also need to leave room for quoting.
	# In general, whatever error lands here has also landed in the 
	# logfile itself, so we are not losing any real info. 
	#
	my $safe_key = DBQuoteSpecial($key);
	my $safe_val = DBQuoteSpecial($val);

	# Need room for (at least) beginning/end quotes added by DBQuoteSpecial
	if (length($safe_val) >= 255) {
	    my $len = 255 - (strlen($safe_val) - strlen($val));
	    $safe_val = DBQuoteSpecial(substr($val, 0, $len));
	}
	push(@inserts, "('$logidx',NULL,$safe_key,$safe_val)");
    };

    #
    # Silly choice a long time ago.
    #
    if (ref($argref) eq "ARRAY") {
	foreach my $ref (@{$argref}) {
	    &$coderef(@{$ref});
	}
    }
    else {
	foreach my $key (keys(%{$argref})) {
	    &$coderef($key, $argref->{$key});
	}
    }
    return -1
	if (!DBQueryWarn("insert into logfile_metadata values ".
			 join(",", @inserts)));
    return 0;
}

#
# Open/Close the file for reading (if its currently being written) and
# store the descriptor in the object.
#
sub OpenFile($)
{
    my ($self) = @_;

    DBQueryWarn("lock tables logfiles write, logfile_metadata write")
	or return undef;
    if ($self->Refresh()) {
	DBQueryWarn("unlock tables");
	return -1;
    }
    if (!$self->isopen()) {
	print STDERR "$self is no long open\n";
	DBQueryWarn("unlock tables");
	return -1;
    }
    my $filename = $self->filename();
    if (! -e $filename) {
	print STDERR "$self: $filename does not exist\n";
	DBQueryWarn("unlock tables");
	return -1;
    }
    local *LOG;
    if (! sysopen(LOG, $filename, O_RDONLY | O_NONBLOCK)) {
	print STDERR "$self: could not open $filename: $!\n";
	DBQueryWarn("unlock tables");
	return -1;
    }
    $self->{"FP"} = *LOG;
    DBQueryWarn("unlock tables");
    return 0;
}
sub CloseFile($)
{
    my ($self) = @_;
    return 0
	if (!defined($self->filedescriptor()));

    close($self->filedescriptor());
    $self->{"FP"} = undef;
    return 0;
}
sub ReadFile($$)
{
    my ($self, $pbuf) = @_;
    my $buf;

    return undef
	if (!defined($self->filedescriptor()));

    my $cc = sysread($self->filedescriptor(), $buf, 2048 * 4);
    if (!defined($cc)) {
	if ($!{EAGAIN}) {
	    # Nothing to read
	    return 0;
	}
	print STDERR "Closing A\n";
	$self->CloseFile();
	return undef;
    }
    if ($cc == 0) {
	# Nothing to read. 
	return 0;
    }
    $$pbuf = $buf;
    return $cc;
}
sub DumpFile($$)
{
    my ($self, $pbuf) = @_;
    my $filename = $self->filename();
    my $FP;
    my $stuff = "";

    return 0
	if (!defined($filename) || ! -r $filename);

    if ($self->compressed()) {
	if (!open(ZIP, "$GUNZIP -c $filename |")) {
	    print STDERR "Could unzip $filename for output\n";
	    return -1;
	}
	$FP = *ZIP;
    }
    else {
	if (!open(LOG, $filename)) {
	    print STDERR "Could not open $filename for output\n";
	    return -1;
	}
	$FP = *LOG;
    }
    # On this path always prine out private keys.
    my $inkey = 0;
	    
    while (<$FP>) {
	if ($_ =~ /-----BEGIN RSA PRIVATE KEY-----/) {
	    $inkey = 1;
	}
	elsif ($_ =~ /-----END RSA PRIVATE KEY-----/) {
	    $inkey = 0;
	}
	elsif ($inkey) {
	    next;
	}
	$stuff .= $_;
    }
    close($FP);
    $$pbuf = $stuff;
    return 0;
}

#
# Lock and unlock the tables we use.
#
sub LockTables($)
{
    my ($class) = @_;

    DBQueryWarn("lock tables logfiles write, logfile_metadata write")
	or return -1;
    
    return 0;
}
sub UnlockTables($)
{
    my ($class) = @_;

    DBQueryWarn("unlock tables")
	or return -1;
    
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
