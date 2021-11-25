#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2021 University of Utah and the Flux Group.
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
package User;

use strict;
use Exporter;
use vars qw(@ISA);
@ISA    = "Exporter";

use emdb;
use EmulabConstants;
use libtestbed;
use libEmulab;
use Brand;
use English;
use Data::Dumper;
use File::Basename;
use overload ('""' => 'Stringify');
use vars qw($NEWUSER_FLAGS_PROJLEADER $NEWUSER_FLAGS_WIKIONLY
	    $NEWUSER_FLAGS_WEBONLY $NEWUSER_FLAGS_ARCHIVED
	    $NEWUSER_FLAGS_NOUUID $NEWUSER_FLAGS_NONLOCAL
	    $USERSTATUS_ACTIVE $USERSTATUS_FROZEN $USERSTATUS_INACTIVE
	    $USERSTATUS_UNAPPROVED $USERSTATUS_UNVERIFIED
	    $USERSTATUS_NEWUSER $USERSTATUS_ARCHIVED $USERSTATUS_NONLOCAL
            @USERSTATUS_VALIDSET
	    @EXPORT_OK);

# Configure variables
my $TB		   = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $TBOPS          = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBAPPROVAL     = "testbed-approval\@ops.cloudlab.umass.edu";
my $TBAUDIT   	   = "testbed-audit\@ops.cloudlab.umass.edu";
my $TBBASE         = "https://www.cloudlab.umass.edu";
my $TBWWW          = "<https://www.cloudlab.umass.edu/>";
my $WIKISUPPORT    = 0;
my $WITHZFS        = 1;
my $ZFS_NOEXPORT   = 1;
my $WITHAMD        = 1;
my $BOSSNODE       = "boss.cloudlab.umass.edu";
my $CONTROL	   = "ops.cloudlab.umass.edu";
my $OURDOMAIN      = "cloudlab.umass.edu";
my $PGENISUPPORT   = 1;
my $MIN_UNIX_UID   = 2000;
my $MIN_UNIX_GID   = 2000;
my $tbacct	   = "$TB/sbin/tbacct";
my $MKUSERCERT     = "$TB/sbin/mkusercert";
my $EXPIRE_PASSWORDS = 0;
my $EXPORTS_SETUP  = "$TB/sbin/exports_setup";

# Create() flags.
$NEWUSER_FLAGS_PROJLEADER	= 0x01;
$NEWUSER_FLAGS_WIKIONLY		= 0x02;
$NEWUSER_FLAGS_WEBONLY		= 0x04;
$NEWUSER_FLAGS_ARCHIVED		= 0x08;
$NEWUSER_FLAGS_NOUUID		= 0x80;
$NEWUSER_FLAGS_NONLOCAL		= 0x40;

# Status values.
$USERSTATUS_ACTIVE		= "active";
$USERSTATUS_FROZEN		= "frozen";
$USERSTATUS_UNAPPROVED		= "unapproved";
$USERSTATUS_UNVERIFIED		= "unverified";
$USERSTATUS_NEWUSER	        = "newuser";
$USERSTATUS_ARCHIVED	        = "archived";
$USERSTATUS_NONLOCAL	        = "nonlocal";
$USERSTATUS_INACTIVE	        = "inactive";
@USERSTATUS_VALIDSET            = ($USERSTATUS_ACTIVE, $USERSTATUS_FROZEN,
		 		   $USERSTATUS_ARCHIVED, $USERSTATUS_INACTIVE);

# Why, why, why?
@EXPORT_OK = qw($NEWUSER_FLAGS_PROJLEADER $NEWUSER_FLAGS_WIKIONLY
		$NEWUSER_FLAGS_WEBONLY $NEWUSER_FLAGS_ARCHIVED
		$NEWUSER_FLAGS_NOUUID
		$USERSTATUS_ACTIVE $USERSTATUS_FROZEN $USERSTATUS_INACTIVE
		$USERSTATUS_UNAPPROVED $USERSTATUS_UNVERIFIED
		$USERSTATUS_NEWUSER $USERSTATUS_ARCHIVED $USERSTATUS_NONLOCAL
                @USERSTATUS_VALIDSET);

# Protos
sub SetUserInterface($$);
sub escapeshellarg($);

# Cache of instances to avoid regenerating them.
my %users      = ();
BEGIN { use emutil; emutil::AddCache(\%users); }
my $debug      = 0;

# Little helper and debug function.
sub mysystem($)
{
    my ($command) = @_;

    print STDERR "Running '$command'\n"
	if ($debug);
    return system($command);
}

#
# Lookup by idx.
#
sub Lookup($$)
{
    my ($class, $token) = @_;
    my $status_archived = $USERSTATUS_ARCHIVED;
    my $query_result;

    # Look in cache first
    return $users{"$token"}
        if (exists($users{"$token"}));

    #
    # For backwards compatability, look to see if the token is numeric
    # or alphanumeric. If numeric, assumes its an idx, otherwise a name.
    #
    if ($token =~ /^\d+$/) {
	$query_result =
	    DBQueryWarn("select * from users where uid_idx='$token'");
    }
    elsif ($token =~ /^\w+$/) {
	#
	# When looking up by uid, only look for local non-archived users.
	# We know that those are unique in the table.
	#
	$query_result =
	    DBQueryWarn("select * from users ".
			"where uid='$token' and ".
			"      status!='$status_archived'");
    }
    else {
	return undef;
    }
    
    return undef
	if (!$query_result || !$query_result->numrows);

    my $self         = {};
    $self->{'USER'}  = $query_result->fetchrow_hashref();

    bless($self, $class);
    $self->{'BRAND'}   = Brand->Create($self->portal());
    
    # Add to cache. 
    $users{$self->{'USER'}->{'uid_idx'}} = $self;
    
    return $self;
}
# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'USER'}->{$_[1]}); }
sub uid_idx($)		{ return field($_[0], "uid_idx"); }
sub dbid($)		{ return field($_[0], "uid_idx"); }
sub uid($)		{ return field($_[0], "uid"); }
sub uuid($)		{ return field($_[0], "uid_uuid"); }
sub created($)		{ return field($_[0], "usr_created"); }
sub expires($)		{ return field($_[0], "usr_expires"); }
sub modified($)		{ return field($_[0], "usr_modified"); }
sub name($)		{ return field($_[0], "usr_name"); }
sub title($)		{ return field($_[0], "usr_title"); }
sub affil($)		{ return field($_[0], "usr_affil"); }
sub affil_abbrev($)	{ return field($_[0], "usr_affil_abbrev"); }
sub email($)		{ return field($_[0], "usr_email"); }
sub URL($)		{ return field($_[0], "usr_URL"); }
sub addr($)		{ return field($_[0], "usr_addr"); }
sub addr2($)		{ return field($_[0], "usr_addr2"); }
sub city($)		{ return field($_[0], "usr_city"); }
sub state($)		{ return field($_[0], "usr_state"); }
sub zip($)		{ return field($_[0], "usr_zip"); }
sub country($)		{ return field($_[0], "usr_country"); }
sub phone($)		{ return field($_[0], "usr_phone"); }
sub shell($)		{ return field($_[0], "usr_shell"); }
sub pswd($)		{ return field($_[0], "usr_pswd"); }
sub w_pswd($)		{ return field($_[0], "usr_w_pswd"); }
sub unix_uid($)		{ return field($_[0], "unix_uid"); }
sub status($)		{ return field($_[0], "status"); }
sub admin($)		{ return field($_[0], "admin"); }
sub foreign_admin($)	{ return field($_[0], "foreign_admin"); }
sub dbedit($)		{ return field($_[0], "dbedit"); }
sub stud($)		{ return field($_[0], "stud"); }
sub webonly($)		{ return field($_[0], "webonly"); }
sub pswd_expires($)	{ return field($_[0], "pswd_expires"); }
sub cvsweb($)		{ return field($_[0], "cvsweb"); }
sub emulab_pubkey($)	{ return field($_[0], "emulab_pubkey"); }
sub home_pubkey($)	{ return field($_[0], "home_pubkey"); }
sub adminoff($)		{ return field($_[0], "adminoff"); }
sub verify_key($)	{ return field($_[0], "verify_key"); }
sub widearearoot($)	{ return field($_[0], "widearearoot"); }
sub wideareajailroot($) { return field($_[0], "wideareajailroot"); }
sub notes($)		{ return field($_[0], "notes"); }
sub weblogin_frozen($)  { return field($_[0], "weblogin_frozen"); }
sub weblogin_failcount($){return field($_[0], "weblogin_failcount");}
sub weblogin_failstamp($){return field($_[0], "weblogin_failstamp");}
sub plab_user($)	{ return field($_[0], "plab_user"); }
sub user_interface($)	{ return field($_[0], "user_interface"); }
sub chpasswd_key($)	{ return field($_[0], "chpasswd_key"); }
sub chpasswd_expires($) { return field($_[0], "chpasswd_expires"); }
sub wikiname($)		{ return field($_[0], "wikiname"); }
sub wikionly($)		{ return field($_[0], "wikionly"); }
sub mailman_password($) { return field($_[0], "mailman_password"); }
sub initial_passphrase($) { return field($_[0], "initial_passphrase"); }
sub active($)		{ return ($_[0]->status() eq "active"   ? 1 : 0); };
sub newuser($)		{ return ($_[0]->status() eq "newuser" ? 1 : 0); };
sub archived($)		{ return ($_[0]->status() eq "archived" ? 1 : 0); };
sub frozen($)		{ return ($_[0]->status() eq "frozen" ? 1 : 0); };
sub default_project($)	{ return field($_[0], "default_project"); }
sub nocollabtools($)	{ return field($_[0], "nocollabtools"); }
sub manager_urn($)	{ return field($_[0], "manager_urn"); }
sub nonlocal_id($)	{ return field($_[0], "nonlocal_id"); }
sub nonlocal_type($)	{ return field($_[0], "nonlocal_type"); }
sub IsLocal($)		{ return (defined($_[0]->nonlocal_id()) ? 0 : 1); };
sub IsNonLocal($)	{ return (defined($_[0]->nonlocal_id()) ? 1 : 0); };
sub portal($)		{ return field($_[0], "portal"); }
sub expert_mode($)	{ return field($_[0], "expert_mode"); }
sub ga_userid($)	{ return field($_[0], "ga_userid"); }
sub Brand($)		{ return $_[0]->{'BRAND'}; }
sub isAPT($)	        { return $_[0]->Brand()->isAPT() ? 1 : 0; }
sub isCloud($)	        { return $_[0]->Brand()->isCloud() ? 1 : 0; }
sub isPNet($)	        { return $_[0]->Brand()->isPNet() ? 1 : 0; }
sub isPowder($)	        { return $_[0]->Brand()->isPowder() ? 1 : 0; }
sub isEmulab($)         { return $_[0]->Brand()->isEmulab() ? 1 : 0; }

# Branding.
sub ApprovalEmailAddress($)  { return $_[0]->Brand()->ApprovalEmailAddress(); }
sub OpsEmailAddress($)       { return $_[0]->Brand()->OpsEmailAddress(); }
sub EmailTag($)              { return $_[0]->Brand()->EmailTag(); }
sub wwwBase($)               { return $_[0]->Brand()->wwwBase(); }

# Temporary data storage ... useful.
sub GetTempData($$) { return field($_[0], "tempdata"); } 
sub SetTempData($$) {

    my ($self, $value) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    $self->{'USER'}->{"tempdata"} = $value;

    return 0;
}

#
# Generate a URN.
#
sub urn($)
{
    my ($self) = @_;
    my $uid    = $self->uid();

    return undef
	if (!$PGENISUPPORT);
    require GeniHRN;

    return GeniHRN->new(GeniHRN::Generate($OURDOMAIN, "user", $uid));
}
sub nonlocalurn($)
{
    my ($self) = @_;
    
    return undef
	if (!$PGENISUPPORT);
    require GeniHRN;

    if ($self->IsNonLocal()) {
	return GeniHRN->new($self->nonlocal_id());
    }
    return $self->urn();
}

#
# Lookup user given a plain uid. For backwards compat.
#
sub LookupByUid($$)
{
    my ($class, $uid) = @_;

    return User->Lookup($uid);
}

# Include archived users, as for checking a newuser account.
sub LookupByUidAll($$)
{
    my ($class, $uid) = @_;

    my $query_result =
	DBQueryFatal("select uid_idx from users where uid='$uid'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid_idx) = $query_result->fetchrow_array();

    return User->Lookup($uid_idx);
}

#
# Lookup user given the unix uid ($UID typically).
#
sub LookupByUnixId($$)
{
    my ($class, $unix_uid) = @_;

    my $query_result =
	DBQueryFatal("select uid,uid_idx from users ".
		     "where unix_uid='$unix_uid'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid, $uid_idx) = $query_result->fetchrow_array();

    # Sanity check against password file before returning.
    my ($pwname) = getpwuid($unix_uid) or
	die("*** $unix_uid is not in the password file!");

    if ($uid ne $pwname) {
	warn("*** WARNING: LookupByUnixId: $pwname does not match $uid\n");
	return undef
    }

    return User->Lookup($uid_idx);
}

#
# Lookup user given a wikiname. This is just to make sure the wikiname
# the user picked is unique.
#
sub LookupByWikiName($$)
{
    my ($class, $wikiname) = @_;
    my $status_archived = $USERSTATUS_ARCHIVED;
    
    my $query_result =
	DBQueryFatal("select uid_idx from users ".
		     "where wikiname='$wikiname' and ".
		     "      status!='$status_archived'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid_idx) = $query_result->fetchrow_array();

    return User->Lookup($uid_idx);
}

#
# Lookup user given an e-mail address.  This is just to make sure the
# e-mail address the user picked is unique.
#
sub LookupByEmail($$)
{
    my ($class, $email) = @_;
    my $status_archived = $USERSTATUS_ARCHIVED;

    my $query_result =
	DBQueryFatal("select uid_idx from users ".
		     "where LCASE(usr_email)=LCASE('$email') and ".
		     "      status!='$status_archived'");
		     

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid_idx) = $query_result->fetchrow_array();

    return User->Lookup($uid_idx);
}

#
# Lookup user given a UUID.  
#
sub LookupByUUID($$)
{
    my ($class, $uuid) = @_;
    my $status_archived = $USERSTATUS_ARCHIVED;
    my $safe_uuid = DBQuoteSpecial($uuid);

    my $query_result =
	DBQueryFatal("select uid_idx from users ".
		     "where uid_uuid=$safe_uuid and ".
		     "      status!='$status_archived'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid_idx) = $query_result->fetchrow_array();

    return User->Lookup($uid_idx);
}

#
# Lookup a nonlocal user.
#
sub LookupNonLocal($$)
{
    my ($class, $urn) = @_;
    my $status_archived = $USERSTATUS_ARCHIVED;
    my $safe_urn = DBQuoteSpecial($urn);

    my $query_result =
	DBQueryFatal("select uid_idx from users ".
		     "where nonlocal_id=$safe_urn and ".
		     "      status!='$status_archived'");

    return undef
	if (! $query_result || !$query_result->numrows);

    my ($uid_idx) = $query_result->fetchrow_array();

    return User->Lookup($uid_idx);
}

#
# Flush from our little cache.
#
sub Flush($)
{
    my ($self) = @_;

    delete($users{$self->uid_idx()});
}
sub FlushAll($)
{
    my ($class) = @_;
    
    %users = ();
}

#
# Class function to create new user and return object.
#
sub Create($$$$)
{
    my ($class, $uid, $flags, $argref) = @_;
    my $uuid;

    my $isleader = ($flags & $NEWUSER_FLAGS_PROJLEADER ? 1 : 0);
    my $wikionly = ($flags & $NEWUSER_FLAGS_WIKIONLY   ? 1 : 0);
    my $webonly  = ($flags & $NEWUSER_FLAGS_WEBONLY    ? 1 : 0);
    my $archived = ($flags & $NEWUSER_FLAGS_ARCHIVED   ? 1 : 0);
    my $nonlocal = ($flags & $NEWUSER_FLAGS_NONLOCAL   ? 1 : 0);
    my $nouuid   = ($flags & $NEWUSER_FLAGS_NOUUID     ? 1 : 0);

    DBQueryFatal("lock tables users write, user_stats write, ".
		 "   emulab_indicies write, ".
		 "   users as u read, users as r read")
	or return undef;

    #
    # Check for existing user. Usually a double click.
    #
    if ($uid) {
	my $query_result =
	    DBQueryWarn("select uid_idx from users ".
			"where uid='$uid' and status!='$USERSTATUS_ARCHIVED'");
	goto bad
	    if (!$query_result);

	if ($query_result->numrows) {
	    my ($other_idx) = $query_result->fetchrow_array();
	    
	    print STDERR "*** Duplicate user table entry: $other_idx\n";
	    goto bad;
	}
    }

    #
    # If no uid, we need to generate a unique one for the user.
    #
    if (! $uid) {
	#
	# Take the first 5 letters of the email to form a root. That gives
	# us 3 digits to make it unique, since unix uids are limited to 8
	# chars, sheesh!
	#
	my $email = $argref->{'usr_email'};
	my $token;

	if ($email =~ /^([-\w\+\.]+)\@([-\w\.]+)$/) {
	    $token = $1;
	}
	else {
	    goto bad;
	}
	# Squeeze out any dots or dashes.
	$token =~ s/\.//g;
	$token =~ s/\-//g;

	# Trim off any trailing numbers or +foo tokens.
	if ($token =~ /^([a-zA-Z]+)/) {
	    $token = $1;
	}
	else {
	    goto bad;
	}

	# First 5 chars, at most.
	$token = substr($token, 0, 5);

	# Grab all root matches from the DB.
	my $query_result =
	    DBQueryWarn("select uid from users where uid like '${token}%'");

	goto bad
	    if (!$query_result);

	# Easy; no matches at all!
	if (!$query_result->numrows) {
	    $uid = "$token" . "001";
	}
	else {
	    my $max = 0;
		
	    #
	    # Find unused slot. Must be a better way to do this!
	    #
	    while (my ($foo) = $query_result->fetchrow_array()) {
		my $name;
		my $number;
		
		# Split name from number
		if ($foo =~ /^([a-zA-Z]+)(\d*)$/) {
		    $name   = $1;
		    $number = $2;
		}
		else {
		    goto bad;
		}
		# Must be exact root
		next
		    if ($name ne $token);

		# Backwards compatability; might not have appended number.
		if (isset($number) && intval($number) > $max) {
		    $max = intval($number);
		}
	    }
	    $max++;
	    $uid = $token . sprintf("%03d", $max);
	}
    }
	
    #
    # Get me an unused unix id.
    #
    my $min_uid = $MIN_UNIX_UID;
    my $unix_uid = $argref->{'unix_uid'};

    #
    # allow user to request a unix id
    #
    if (defined($unix_uid)) {
        $unix_uid = int($unix_uid);                    # clean to be safe
        delete($$argref{'unix_uid'});                  # handled specially
        return(undef) if ($unix_uid < $MIN_UNIX_UID);  # out of range?
        return(undef) if (getpwuid($unix_uid));        # already in use?
    }

    #
    # Start here, and keep going if the one picked from the DB just
    # happens to be in use (in the passwd file). Actually happens!
    #
    while (! defined($unix_uid)) {
	#
	# Nice query, eh? Basically, find unused numbers by looking at
	# existing numbers plus one, and check to see if that number
	# is taken.
	#
	my $query_result =
	    DBQueryWarn("select u.unix_uid + 1 as start from users as u ".
			"left outer join users as r on ".
			"  u.unix_uid + 1 = r.unix_uid ".
			"where u.unix_uid>=$min_uid and ".
			"      u.unix_uid<60000 and ".
			"      r.unix_uid is null order by u.unix_uid limit 1");
	goto bad
	    if (! $query_result);

	if (! $query_result->numrows) {
	    print "*** WARNING: Could not find an unused unix_uid!\n";
	    goto bad;
	}

	my ($unused) = $query_result->fetchrow_array();

	if (getpwuid($unused)) {
	    # Keep going from this one.
	    $min_uid = $unused + 1;
	}
	else {
	    # Break out of loop.
	    $unix_uid = $unused;
	}
    }

    # Every user gets a new unique index. Use nolock option.
    my $uid_idx = User->NextIDX(1);

    # Initial mailman_password.
    my $mailman_password = substr(TBGenSecretKey(), 0, 10);

    # And a verification key.
    my $verify_key = TBGenSecretKey();

    # Google Analytics user id.
    my $ga_userid = substr(TBGenSecretKey(), 0, 32);

    #
    # The array of inserts is assumed to be safe already. Generate
    # a list of actual insert clauses to be joined below.
    #
    my @insert_data = (!defined($argref) ? () :
		       map("$_=" . DBQuoteSpecial($argref->{$_}),
			   keys(%{$argref})));

    if (! $nouuid) {
	# And a UUID (universally unique identifier).
	$uuid = NewUUID();
	if (!defined($uuid)) {
	    print "*** WARNING: Could not generate a UUID!\n";
	    goto bad;
	}
	push(@insert_data, "uid_uuid='$uuid'");
    }

    # Now tack on other stuff we need.
    push(@insert_data, "wikionly='1'")
	if ($wikionly);
    push(@insert_data, "webonly='1'")
	if ($webonly);

    push(@insert_data, "usr_created=now()");
    push(@insert_data, "usr_modified=now()");
    push(@insert_data, "unix_uid=$unix_uid");
    push(@insert_data, "mailman_password='$mailman_password'");
    push(@insert_data, "verify_key='$verify_key'");
    push(@insert_data, "uid_idx='$uid_idx'");
    push(@insert_data, "uid='$uid'");
    push(@insert_data, "ga_userid='$ga_userid'");
    push(@insert_data, "affiliation_updated=now()");

    if ($archived) {
	#
	# Creating an archived user; this only happens when restoring a
        # deleted user (which is to say, not often).
	#
	push(@insert_data, "status='$USERSTATUS_ARCHIVED'");
	push(@insert_data, "usr_name='$uid'");
	push(@insert_data, "pswd_expires=now()");
	push(@insert_data, "usr_pswd='*'");
	push(@insert_data, "usr_email='bouncer\@${OURDOMAIN}'");
    }
    elsif ($nonlocal) {
	if (! (exists($argref->{'nonlocal_id'}) &&
	       exists($argref->{'nonlocal_type'}))) {
	    print STDERR "*** User->Create(): ".
		"Must provide nonlocal_id and nonlocal_type!\n";
	    goto bad;
	}
	push(@insert_data, "status='$USERSTATUS_ACTIVE'");
	# No expiration, cause no passwords. 
	push(@insert_data, "pswd_expires=null");
	push(@insert_data, "usr_pswd='*'");
    }
    else {
	push(@insert_data, "status='$USERSTATUS_NEWUSER'");
	push(@insert_data, "pswd_expires=date_add(now(), interval 1 year)")
	    if ($EXPIRE_PASSWORDS);
    }

    # Insert into DB.
    DBQueryWarn("insert into users set " . join(",", @insert_data))
	or goto bad;

    # And the stats record.
    @insert_data = ();
    push(@insert_data, "uid_idx='$uid_idx'");
    push(@insert_data, "uid='$uid'");
    push(@insert_data, "uid_uuid='$uuid'")
	if (!$nouuid);

    if (! DBQueryWarn("insert into user_stats set ".join(",", @insert_data))) {
	DBQueryFatal("delete from users where uid_idx='$uid_idx'");
	goto bad;
    }
    DBQueryFatal("unlock tables");
    return User->Lookup($uid_idx);

  bad:
    DBQueryFatal("unlock tables");
    return undef;
}

#
# Delete the user from the users and user_stats tables.
#
sub Delete($)
{
    my ($self) = @_;

    return 0
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    DBQueryWarn("delete from user_credentials where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_pubkeys where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_sslcerts where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_stats where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from apt_profile_favorites where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from apt_parameter_sets where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from users where uid_idx='$uid_idx'")
	or return -1;

    return 0;
}

#
# Utility (class) function to get a new uid for a user.
#
sub NextIDX($;$)
{
    my ($class, $nolock) = @_;

    my $idx = TBGetUniqueIndex('next_uid', 1, $nolock);
    return $idx;
}

#
# Purge user from various tables, but not the user table.
#
sub Purge($)
{
    my ($self) = @_;

    return 0
	if (! ref($self));

    my $uid     = $self->uid();
    my $uid_idx = $self->uid_idx();

    DBQueryWarn("delete from group_membership where uid_idx='$uid_idx'")
	or return -1;

    #
    # Then the pubkey tables.
    # 
    DBQueryWarn("delete from user_pubkeys  where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_sfskeys  where uid_idx='$uid_idx'")
	or return -1;

    #
    # Do not delete certs; we need them around so we can generte the CRLS.
    # Just set the revoked flag for them. At some point we need to prune
    # the table.
    #
    DBQueryWarn("update user_sslcerts set revoked=now() ".
		"where uid_idx='$uid_idx' and revoked is null")
	or return -1;

    #
    # Must do widearea_accounts too.
    #
    DBQueryWarn("delete from widearea_accounts where uid_idx='$uid_idx'")
	or return -1;

    #
    # Then some other pidly tables.
    # 
    DBQueryWarn("delete from login where uid_idx='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from nodeuidlastlogin where uid='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from uidnodelastlogin where uid='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from unixgroup_membership where uid='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from userslastlogin where uid='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_policies where uid='$uid_idx'")
	or return -1;
    DBQueryWarn("delete from user_token_passwords where uid_idx='$uid_idx'")
	or return -1;

    return 0;
}

#
# Wrap above function so I do not forget to use it for the current user.
#
sub ThisUser($)
{
    return User->LookupByUnixId($UID);
}

#
# The "implied" user is the user the web interface says we are running as.
#
sub ImpliedUser($)
{
    return undef
	if (! exists($ENV{'HTTP_INVOKING_USER'}));
    
    # The lookup routine checks it argument, so no need to taint check.
    return User->Lookup($ENV{'HTTP_INVOKING_USER'});
}

#
# This will replace above once I figure out how I want to do all this.
# The idea is that the real user is for permission checks to Emulab
# resource.
#
sub RealUser($)
{
    return undef
	if (! exists($ENV{'EMULAB_REAL_USER'}));
    
    # The lookup routine checks it argument, so no need to taint check.
    return User->Lookup($ENV{'EMULAB_REAL_USER'});
}

#
# See if user is member of emulab-ops project. Must be the current user.
#
sub IsOpsGuy($)
{
    my ($self) = @_;
    require Group;

    return 0
	if (! ref($self));

    if (!$self->SameUser($self->ThisUser())) {
	print STDERR "*** IsOpsGuy: Must be invoked on current user!\n";
	return 0;
    }
    my $group = Group->Lookup(TBOPSPID(), TBOPSPID());
    if (!defined($group)) {
	print STDERR "*** IsOpsGuy: No emulab-ops project!\n";
	return 0;
    }
    return TBMinTrust($group->Trust($self), PROJMEMBERTRUST_USER());
}

#
# See if user is an admin. Must be the current user.
#
sub IsAdmin($)
{
    my ($self) = @_;

    return 0
	if (! ref($self));

    # Only current user can pass IsAdmin test.
    if (!$self->SameUser($self->ThisUser())) {
	return 0;
    }
    #
    # No one is considered an admin unless they have the magic environment
    # variable set (so that you have to be a bit more explict about wanting
    # admin privs.) Use the withadminprivs script to get this variable set.
    # Also check with HTTP_ at the front of the name, since this is required
    # to get it through suexec from the web scripts.
    #
    if (!($ENV{WITH_TB_ADMIN_PRIVS} || $ENV{HTTP_WITH_TB_ADMIN_PRIVS})) {
	return 0;
    }
    return $self->admin();
}

#
# Worker class method to change the user profile.
# Assumes most argument checking was done elsewhere.
#
sub ModUserInfo($$$$)
{
    my ($class, $this_user, $target_user, $argref, $usrerr_ref) = @_;

    my $this_uid = $this_user->uid();
    my $isadmin = $this_user->IsAdmin();

    my $target_uid = $target_user->uid();
    my $target_uid_idx = $target_user->uid_idx();
    my $target_name = $target_user->name();
    my $target_email = $target_user->email();
    my $wikionly = $target_user->wikionly();
    my $status = $target_user->status();

    my %mods;
    my $noreport;

    #
    # Only admin types can change the email address. If its different, the
    # user circumvented the form, and so its okay to blast it.
    #
    my $usr_email = $argref->{"usr_email"};
    if ($usr_email && $target_email ne $usr_email) {
	if (!$isadmin) {
	    $$usrerr_ref = "Email: ".
		"You are not allowed to change your email address";
	    return undef;
	}

	#
	# Invoke the backend to deal with this.
	#
	my $cmd = "$tbacct email $target_uid " .
		   escapeshellarg($usr_email);
	##print $cmd;
	my $cmd_out = `$cmd`;
	if ($?) {
	    chomp($cmd_out);
	    $$usrerr_ref = "Error: " . $cmd_out;
	    return undef;
	}
	$mods{"usr_email"} = $usr_email;
    }

    #
    # Now see if the user is requesting to change the password.
    #
    if (($argref->{"password1"} && $argref->{"password1"} ne "") &&
	($argref->{"password2"} && $argref->{"password2"} ne "")) {

	my $old_encoding = $target_user->pswd();
	my $new_encoding = crypt($argref->{"password1"}, $old_encoding);

	#
	# Compare. Must change it!
	# 
	if (!$isadmin && $old_encoding eq $new_encoding) {
	    $$usrerr_ref = "Error: " .
		"New password same as old password";
	    return undef;
	}

	#
	# Do it again. This ensures we use the current algorithm with a
	# new random salt, not whatever it was encoded with last time.
	#
	$new_encoding = PassWordHash($argref->{"password1"});
	my $safe_encoding = escapeshellarg($new_encoding);

	#
	# Invoke the backend to deal with this.
	#
	my $cmd = "tbacct passwd $target_uid $safe_encoding";
	##print $cmd;
	my $cmd_out = `$cmd`;
	if ($?) {
	    chomp($cmd_out);
	    $$usrerr_ref = "Error: " . $cmd_out;
	    return undef;
	}
	$noreport = 1;
    }

    #
    # See if the user is requesting to change the Windows password.
    #
    if (($argref->{"w_password1"} && $argref->{"w_password1"} ne "") &&
	($argref->{"w_password2"} && $argref->{"w_password2"} ne "")) {

	my $old_wpswd = $target_user->w_pswd();
	my $new_wpswd = $argref->{"w_password1"};

	#
	# Compare. Must change it!
	# 
	if ($old_wpswd eq $new_wpswd) {
	    $$usrerr_ref = "Error: " .
		"New Windows password same as old Windows password";
	    return undef;
	}

	#
	# Invoke the backend to deal with this.
	#
	my $cmd = "tbacct wpasswd $target_uid " . escapeshellarg($new_wpswd);
	##print $cmd;
	my $cmd_out = `$cmd`;
	if ($?) {
	    chomp($cmd_out);
	    $$usrerr_ref = "Error: " . $cmd_out;
	    return undef;
	}
	$noreport = 1;
    }

    #
    # Only admins can change the notes field. We do not bother to generate
    # any email or external updates for this.
    #
    my $notes = $argref->{"notes"};
    if (defined($notes) && $isadmin && $target_user->notes() ne $notes) {
	$target_user->SetNotes($notes);
	$noreport = 1;
    }

    #
    # Set the plab bit separately since no need to call out to the backend.
    #
    my $ui = $argref->{"user_interface"};
    if (defined($ui) && $target_user->user_interface() ne $ui) {
	$target_user->SetUserInterface($ui);
	$noreport = 1;
    }

    #
    # Now update the rest of the information in the DB.
    # (Others above already did their own updates.)
    #
    my %updates;
    foreach my $col ("usr_name", "usr_title", "usr_affil", "usr_affil_abbrev", 
		     "usr_URL",
		     "usr_addr", "usr_addr2", "usr_city", "usr_state",
		     "usr_zip", "usr_country", "usr_phone", "usr_shell") {
	# Copy args we want so that others can't get through.
	if (exists($argref->{$col})) {
	    $updates{$col} = $mods{$col} = $argref->{$col};
	}
    }
    if (keys %updates) {
	if (exists($updates{"usr_affil"})) {
	    $updates{"affiliation_updated"} = "now()";
	    #
	    # Avoid email when doing the affiliation update if it actually
	    # did not change, we are here cause the web page forced the chane
	    # so that we update affiliation_updated.
	    #
	    if ($updates{"usr_affil"} eq $target_user->affil()) {
		delete($mods{"usr_affil"});
	    }
	}
	if ($target_user->Update(\%updates)) {
	    return undef;
	}
    }

    if (!keys %mods) {
	# Nothing to do, fine.
	return 1;
    }
    else {
	# Send an audit e-mail reporting what is being changed.
	my @report = ("Name:usr_name", "Email:usr_email",
		      "Job Title:usr_title", "Affiliation:usr_affil",
		      "Affiliation Abbreviation:usr_affil_abbrev",
		      "URL:usr_URL", "Address1:usr_addr",
		      "Address2:usr_addr2", "City:usr_city",
		      "State:usr_state", "ZIP/Postal Code:usr_zip",
		      "Country:usr_country", "Phone:usr_phone",
		      "Shell:usr_shell");
	my $msg = "\n".
	    "User information for '$target_uid' changed by '$this_uid'.\n".
	     "(IDX: $target_uid_idx, $target_name, $target_email".
		 ($wikionly ? ", *WikiOnly*" : "") . ")\n\n";
	foreach my $line (@report) {
	    my ($label, $field) = split /:/, $line;
	    if (exists($mods{$field})) {
		$msg .= sprintf "%-20s%s\n", $label .":", $mods{$field};
	    }
	}
	SENDMAIL("$target_name <$target_email>",
		 "User Information for '$target_uid' Modified",
		 $msg, TBMAIL_OPS(),
		 "Bcc: " . TBMAIL_AUDIT() . "\n" .
		 "Bcc: stoller\@flux.utah.edu\n" .
		 "Errors-To: " . TBMAIL_WWW());

	#
	# "tbacct mod" updates the user gecos field (usr_name) and shell.
	# But do not want to do this if the user is unapproved, since there
	# is no account to operate on until the user is approved. Really,
	# we need a better test for actual user account.
	#
	if ($status ne $USERSTATUS_UNAPPROVED &&
	    ($mods{"usr_name"} || $mods{"usr_shell"})) {
	    my $cmd = "$tbacct mod $target_uid";
	    ##print $cmd;
	    my $cmd_out = `$cmd`;
	    if ($?) {
		chomp($cmd_out);
		$$usrerr_ref = "Error: " . $cmd_out;
		return undef;
	    }
	}
    }
    return 1;
}

#
# Refresh a class instance by reloading from the DB.
#
sub Refresh($)
{
    my ($self) = @_;

    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    
    my $query_result =
	DBQueryWarn("select * from users where uid_idx=$uid_idx");

    return -1
	if (!$query_result || !$query_result->numrows);

    $self->{'USER'} = $query_result->fetchrow_hashref();

    return 0;
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $uid     = $self->uid();
    my $uid_idx = $self->uid_idx();

    return "[User: $uid, IDX: $uid_idx]";
}

#
# Perform some updates ...
#
sub Update($$)
{
    my ($self, $argref) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    my @sets   = ();

    foreach my $key (keys(%{$argref})) {
	my $val = $argref->{$key};

	if ($val ne "NULL" && $val ne "now()") {
	    $val = DBQuoteSpecial($val);
	}
	push (@sets, "${key}=${val}");
    }
    my $query = "update users set usr_modified=now(), " . join(",", @sets) .
	" where uid_idx='$uid_idx'";

    return -1
	if (! DBQueryWarn($query));

    return Refresh($self);
}

#
# Bump usr_modified.
#
sub BumpModified($)
{
    my ($self) = @_;
    
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    return -1
	if (!DBQueryWarn("update users set usr_modified=now() ".
			 "where uid_idx='$uid_idx'"));

    return 0;
}

#
# Equality test for two users. Not strictly necessary in perl, but good form.
#
sub SameUser($$)
{
    my ($self, $other) = @_;

    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($other)));

    return $self->uid_idx() == $other->uid_idx();
}

#
# First approved project.
#
sub FirstApprovedProject($$)
{
    my ($self, $pptr) = @_;
    require Project;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select pid_idx from group_membership ".
		    "where uid_idx='$uid_idx' and pid_idx=gid_idx and ".
		    "      trust!='none' ".
		    "order by date_approved asc limit 1");

    if (! $query_result || !$query_result->numrows) {
	$$pptr = undef;
	return 0;
    }

    my ($pid_idx) = $query_result->fetchrow_array();
    my $project   = Project->Lookup($pid_idx);
    
    if (! defined($project)) {
	warn("*** User::FirstApprovedProject: ".
	     "Could not load project $pid_idx!");
	return -1;
    }
    $$pptr = $project;
    return 0;
}

#
# Change the status of a user in the DB.
#
sub SetStatus($$)
{
    my ($self, $status) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    # Mark frozen with some additional info.
    my %args = ("status" => $status);
    if ($status eq USERSTATUS_FROZEN()) {
	my $this_user = User->ThisUser();
	if (defined($this_user)) {
	    $args{"frozen_by"} = $this_user->uid();
	}
	$args{"frozen_stamp"} = "now()";
    }
    elsif ($self->status() eq USERSTATUS_FROZEN() &&
	   $status eq USERSTATUS_ACTIVE()) {
	$args{"frozen_stamp"} = "NULL";
	$args{"frozen_by"}    = "NULL";
    }
    return $self->Update(\%args);
}

#
# Get user ssl certificate (pubkey). The certificate might be expired, but
# that is okay for the caller.
#
sub SSLCert($$$;$)
{
    my ($self, $encrypted, $pref, $pkey) = @_;
    $encrypted = ($encrypted ? 1 : 0);
    
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select cert,privkey from user_sslcerts ".
		    "where uid_idx='$uid_idx' and encrypted=$encrypted and ".
		    "      revoked is null");
		    
    return -1
	if (!defined($query_result) || !$query_result->numrows);

    my ($cert,$privkey) = $query_result->fetchrow_array();
    $$pref = $cert;
    $$pkey = $privkey
	if (defined($pkey));
    return 0;
}

#
# Does user have an encrypted certificate (not revoked, not expired)
#
sub HasValidEncryptedCert($)
{
    my ($self) = @_;
    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select idx from user_sslcerts ".
		    "where uid_idx='$uid_idx' and encrypted=1 and ".
		    "      revoked is null and expires > now()");

    return -1
	if (!defined($query_result));
    return 0
	if (!$query_result->numrows);
    return 1;
}

#
# Lookup certificate by serial number,
#
sub HasCertBySerial($$)
{
    my ($self, $serial) = @_;
    my $uid_idx = $self->uid_idx();

    if ($serial !~ /^(\d+)$/) {
	return 0;
    }
    my $query_result =
	DBQueryWarn("select idx from user_sslcerts ".
		    "where uid_idx='$uid_idx' and idx='$serial' and ".
		    "      revoked is null and expires > now()");

    return 0
	if (!defined($query_result));
    return 0
	if (!$query_result->numrows);
    return 1;
}

#
# Try to regenerate encrypted SSL cert using existing passphrase, or make
# up a new passphrase if we do not have one in the DB.
#
sub GenEncryptedCert($)
{
    my ($self) = @_;
    my $uid_idx = $self->uid_idx();
    my $uid     = $self->uid();
    my $certpass;

    my $query_result =
	DBQueryWarn("select password from user_sslcerts ".
		    "where uid_idx='$uid_idx' and encrypted=1 and ".
		    "      revoked is null");
    return -1
	if (!defined($query_result));

    if ($query_result->numrows) {
	($certpass) = $query_result->fetchrow_array();
	$certpass   = escapeshellarg($certpass);
    }
    else {
	$certpass = substr(lc(emutil::GenHash()), 0, 12);
    }
    system("$MKUSERCERT -r -p $certpass $uid");
    return -1
	if ($?);
    return 0;
}

#
# Revoke ssl certificates.
#
sub RevokeSSLCerts($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    #
    # Do not delete certs; we need them around so we can generte the CRLS.
    # Just set the revoked flag for them. At some point we need to prune
    # the table.
    #
    DBQueryWarn("update user_sslcerts set revoked=now() ".
		"where uid_idx='$uid_idx' and revoked is null")
	or return -1;

    return 0;
}

#
# Get user ssh keys, but do not include the "internal" keys, which
# are the Emulab generated unencrypted keys.
#
sub GetSSHKeys($$)
{
    my ($self, $pref) = @_;
    my @result = ();
    
    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($pref)));

    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select pubkey from user_pubkeys ".
		    "where uid_idx='$uid_idx' and internal=0");

    return -1
	if (!defined($query_result));

    while (my ($key) = $query_result->fetchrow_array()) { 
	push(@result, $key);
    }    
    @$pref = @result;
    return 0;
}
sub GetAPTSSHKey($)
{
    my ($self) = @_;
    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select pubkey from user_pubkeys ".
		    "where uid_idx='$uid_idx' and isaptkey=1");

    return undef
	if (!(defined($query_result) && $query_result->numrows));

    my ($key) = $query_result->fetchrow_array();
    return $key;
}

#
# Look to see if ssh key is a current key for user. 
#
sub LookupSSHKey($$)
{
    my ($self, $sshkey) = @_;
    my $uid_idx = $self->uid_idx();

    #
    # Strip off the comment.
    #
    if ($sshkey =~ /(.+)\s+(.*)\s*$/) {
	$sshkey = $1;
    }
    my $safe_key = DBQuoteSpecial($sshkey . '%');

    my $query_result =
	DBQueryWarn("select idx from user_pubkeys ".
		    "where uid_idx='$uid_idx' and pubkey like $safe_key");
    return 0
	if (!defined($query_result));

    return $query_result->numrows;
}
sub DeleteSSLCertSSHKey($)
{
    my ($self) = @_;
    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("delete from user_pubkeys ".
		    "where uid_idx='$uid_idx' and internal=1 and ".
		    "      comment like 'sslcert:%'");
    return 0
	if (!defined($query_result));

    return $query_result->numrows;
}

#
# Delete ssh keys, except for emulab created keys.
#
sub DeleteSSHKeys($)
{
    my ($self) = @_;
    
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("delete from user_pubkeys ".
		    "where uid_idx='$uid_idx' and internal=0");

    return -1
	if (!defined($query_result));

    return 0;
}

#
# Get (hopefully) unencrypted, locally-generated user ssh keys.
#
sub GetDefaultSSHKeys($$;$)
{
    my ($self, $pref, $onlylatest) = @_;
    my @result = ();
    
    # Must be a real reference. 
    return -1
	if (! (ref($self) && ref($pref)));

    my $uid_idx = $self->uid_idx();

    my $extra = '';
    if (defined($onlylatest) && $onlylatest) {
	$extra = 'order by stamp desc limit 1';
    }

    my $query_result =
	DBQueryWarn("select pubkey from user_pubkeys ".
		    "where uid_idx='$uid_idx' and internal=1 $extra");

    return -1
	if (!defined($query_result));

    while (my ($key) = $query_result->fetchrow_array()) { 
	push(@result, $key);
    }    
    @$pref = @result;
    return 0;
}

#
# Get the passphrase for the encrypted key.
#
sub SSLPassPhrase($$$)
{
    my ($self, $encrypted, $pref) = @_;
    $encrypted = ($encrypted ? 1 : 0);
    
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select password from user_sslcerts ".
		    "where uid_idx='$uid_idx' and encrypted=$encrypted and ".
		    "      revoked is null");
    return -1
	if (!defined($query_result) || !$query_result->numrows);

    my ($password) = $query_result->fetchrow_array();
    $$pref = $password;
    return 0;
}

#
# Set password for user.
#
sub SetPassword($$;$)
{
    my ($self, $encoding, $expires) = @_;
    my $safe_encoding = DBQuoteSpecial($encoding);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    if (!defined($expires)) {
	if ($EXPIRE_PASSWORDS) {
	    $expires = "date_add(now(), interval 1 year)";
	}
	else {
	    $expires = "null";
	}
    }

    # Clear the chpasswd stuff anytime passwd is set.
    return -1
	if (! DBQueryWarn("update users set ".
			  "  usr_pswd=$safe_encoding, pswd_expires=$expires, ".
			  "  chpasswd_key=NULL,chpasswd_expires=0 ".
			  "where uid_idx='$uid_idx'"));

    return Refresh($self);
}

#
# Set Windows password for user.
#
sub SetWindowsPassword($$)
{
    my ($self, $wpswd) = @_;
    my $safe_password = DBQuoteSpecial($wpswd);

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    return -1
	if (! DBQueryWarn("update users set ".
			  "  usr_w_pswd=$safe_password ".
			  "where uid_idx='$uid_idx'"));

    return Refresh($self);
}

#
# Set notes field for user.
#
sub SetNotes($$)
{
    my ($self, $notes) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $safe_notes = DBQuoteSpecial($notes);
    my $uid_idx = $self->uid_idx();

    return -1
	if (! DBQueryWarn("update users set ".
			  "  notes=$safe_notes ".
			  "where uid_idx='$uid_idx'"));

    return Refresh($self);
}

#
# Set user interface mode for user.
#
sub SetUserInterface($$)
{
    my ($self, $interface) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    my $safe_interface = DBQuoteSpecial($interface);

    return -1
	if (! DBQueryWarn("update users set ".
			  "  user_interface=$safe_interface ".
			  "where uid_idx='$uid_idx'"));

    return Refresh($self);
}

#
# User verified; find users groups and send email.
#
sub SendVerifiedEmail($)
{
    my ($self) = @_;
    require Group;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid     = $self->uid();
    my $uid_idx = $self->uid_idx();

    my $newuser     = $USERSTATUS_NEWUSER;
    my $unapproved  = $USERSTATUS_UNAPPROVED;
    my $none        = $Group::MemberShip::TRUSTSTRING_NONE;

    # Audit email.
    SENDMAIL($TBAUDIT,
	     "User '$uid' has been verified",
	     "\n".
	     "User '$uid' has been verified.\n".	
	     "Status has been changed from '$newuser' to '$unapproved'\n",
	     "$TBAPPROVAL");

    #
    # Get the list of all project/groups this users has tried to join
    # but whose membership messages where delayed until the user verified
    # himself.
    #
    my $query_result =
	DBQueryFatal("select gid_idx from group_membership ".
		     "where uid_idx='$uid_idx' and trust='$none'");

    if (!$query_result->numrows) {
	my $url = "$TBWWW/showuser.php3?user=$uid_idx";
	
	#
	# Verified but no groups; send email to testbed ops since
	# it is unusual (probably cause of ISOLATEADMINS).
	#
	SENDMAIL($TBOPS,
		 "User '$uid' has been verified",
		 "User '$uid' has been verified, ".
		 "but is not a member of any groups.\n\n".
		 "To approve this account, an administrator must do this:\n".
		 "\n".
		 "    boss> wap tbacct -f add $uid\n".
		 "\n".
		 "If this situation arose from ISOLATEADMINS=1, then toggle\n".
		 "the user's administrator capability on this page:\n".
		 "\n".
		 "    $url\n".
		 "\n".
		 "Then the user will be able to join projects that include ".
		 "other administrators.\n",
		 $TBOPS);
	return 0;
    }

    while (my ($gid_idx) = $query_result->fetchrow_array()) {
	my $group = Group->Lookup($gid_idx);

	if (!defined($group)) {
	    print("*** User::SendApprovalEmail: ".
		  "Could not load group $gid_idx!");
	    return -1;
	}
	#
	# If a project leader is verifying himself, then we do the project
	# version of the email (sends to tbapproval).
	#
	if ($group->IsProjectGroup() && $group->IsLeader($self)) {
	    my $project = $group->GetProject();

	    $project->SendNewProjectEmail() == 0 or
		return -1;
	}
	else {
	    $group->SendJoinEmail($self) == 0 or
		return -1;
	}
    }
    return 0;
}

sub SendEmail($$$;$)
{
    my ($self, $subject, $body, $from) = @_;
    $from = $self->Brand()->OpsEmailAddress()
	if (!defined($from));

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid        = $self->uid();
    my $user_email = $self->email();
    my $user_name  = $self->name();

    return $self->Brand()->SendEmail("$user_name <$user_email>",
				     $subject, $body, $from,
				     "Bcc: $TBAUDIT");

    return 0;
}

#
# Return group membership for a user.  
#
sub GroupMembershipList($$;$)
{
    my ($self, $prval, $desired_trust) = @_;
    require Group;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx     = $self->uid_idx();
    my $none        = $Group::MemberShip::TRUSTSTRING_NONE;
    my @result      = ();
    my $trust_clause;

    if (!defined($desired_trust)) {
	$trust_clause = "and trust!='$none'"
    }
    elsif ($desired_trust eq "") {
	$trust_clause = "";
    }
    else {
	$trust_clause = "and trust='$desired_trust'"
    }

    my $query_result =
	DBQueryWarn("select distinct gid_idx from group_membership ".
		    "where uid_idx='$uid_idx' $trust_clause");

    return -1
	if (!$query_result);

    while (my ($gid_idx) = $query_result->fetchrow_array()) {
	my $group = Group->Lookup($gid_idx);

	if (!defined($group)) {
	    print("*** User::GroupMembershipList: ".
		  "Could not load group $gid_idx!");
	    return -1;
	}
	push(@result, $group);
    }
    @$prval = @result;
    return 0;
}

#
# Return project membership for a user.  
#
sub ProjectMembershipList($$;$)
{
    my ($self, $prval, $desired_trust) = @_;
    require Project;
    require Group;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx     = $self->uid_idx();
    my $none        = $Group::MemberShip::TRUSTSTRING_NONE;
    my @result      = ();
    my $trust_clause;

    if (!defined($desired_trust)) {
	$trust_clause = "and trust!='$none'"
    }
    elsif ($desired_trust eq "") {
	$trust_clause = "";
    }
    else {
	$trust_clause = "and trust='$desired_trust'"
    }

    my $query_result =
	DBQueryWarn("select distinct pid_idx from group_membership ".
		    "where uid_idx='$uid_idx' and pid_idx=gid_idx ".
		    "      $trust_clause");

    return -1
	if (!$query_result);

    while (my ($pid_idx) = $query_result->fetchrow_array()) {
	my $project = Project->Lookup($pid_idx);

	if (!defined($project)) {
	    print("*** User::ProjectMembershipList: ".
		  "Could not load project $pid_idx!");
	    return -1;
	}
	push(@result, $project);
    }
    @$prval = @result;
    return 0;
}

#
# Return project leadership for a user.  
#
sub ProjectLeaderList($$;$)
{
    my ($self, $prval) = @_;
    require Project;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx     = $self->uid_idx();
    my @result      = ();

    my $query_result =
	DBQueryFatal("select pid_idx from projects where head_idx='$uid_idx'");
    
    return -1
	if (!$query_result);

    while (my ($pid_idx) = $query_result->fetchrow_array()) {
	my $project = Project->Lookup($pid_idx);

	if (!defined($project)) {
	    print("*** User::ProjectLeaderList: ".
		  "Could not load project $pid_idx!");
	    return -1;
	}
	push(@result, $project);
    }
    @$prval = @result;
    return 0;
}

#
# Return a glist for setting user groups. The argument is the default
# group, since the list has to be reordered for perl to do the right thing. 
#
sub GList($$)
{
    my ($self, $default) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $user_uid = $self->uid();

    # Should we get this info from the DB instead of using "id?"
    my $glist = `id -G $user_uid`;
    if ($glist =~ /^([\d ]*)$/) {
	$glist = $1;
    }
    else {
	print STDERR "*** Unexpected results from 'id -G $user_uid': $glist\n";
	return undef;
    }
    return $glist
	if (!defined($default));

    #
    # Remove current group from glist, then add gid twice at the front
    # of the list Order matters here, or we won't pick up all the groups
    # we need.
    #
    if (ref($default)) {
	#
	# If we got an actual group object, we want the project unix gid
	# at the beginning and the group unix gid next.
	#
	my $pid_gid = $default->GetProject()->unix_gid();
	my $gid_gid = $default->unix_gid();

	my @glist = grep {$_ != $pid_gid && $_ != $gid_gid} split(/\s/, $glist);
	$glist = "$pid_gid $pid_gid $gid_gid @glist";
    }
    else {
	my @glist = grep {$_ != $default} split(/\s/, $glist);
	$glist = $default . " " . $default . " @glist";
    }
    return $glist;
}

#
# Return a list of the additional Unix groups a user is in. These are
# returned as plain integers.
#
sub UnixGroupList($$)
{
    my ($self, $prval) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx  = $self->uid_idx();
    my @glist    = ();
    @$prval      = ();

    my $query_result =
	DBQueryWarn("select gid from unixgroup_membership ".
		    "where uid_idx='$uid_idx'");
    return -1
	if (!defined($query_result));
    return 0
	if (!$query_result->numrows);

    while (my ($gid) = $query_result->fetchrow_array()) {
	push(@glist, $gid)
    }
    @$prval = @glist;
    return 0;
}

#
# Flip to user, with the provided group as the default.
#
sub FlipTo($$)
{
    my ($self, $default_group) = @_;

    # Must be a real reference. 
    return -1
	if (! ref($self));

    # We must have been setuid to start with, and this allows us
    # to flip to a different user in the case we already flipped.
    $EUID = 0;

    my $glist = $self->GList($default_group);
    return -1
	if (!defined($glist));

    my @tmp = split(/\s/, $glist);
    my $default_gid = $tmp[0];
    
    $GID            = $default_gid;
    $EGID           = $glist;
    $EUID = $UID    = $self->unix_uid();
    $ENV{'USER'}    = $self->uid();
    $ENV{'LOGNAME'} = $self->uid();

    return 0;
}

#
# Execute a command as user and then return to original. 
#
sub ExecuteAs($$;$)
{
    my ($self, $command, $default_gid) = @_;

    my $current_uid  = $UID;
    my $current_euid = $EUID;
    my $current_gid  = $GID;
    my $current_egid = $EGID;
    my $USER         = $ENV{'USER'};
    my $LOGNAME      = $ENV{'LOGNAME'};

    $self->FlipTo($default_gid);
    my $output = emutil::ExecQuiet($command);
    my $status = $?;

    $EUID   = 0;
    $GID    = $current_gid;
    $EGID   = $current_egid;
    $UID    = $current_uid;
    $EUID   = $current_euid;
    $ENV{'USER'}    = $USER;
    $ENV{'LOGNAME'} = $LOGNAME;

    return ($status, $output);
}

#
# Update aggregate stats.
#
sub UpdateStats($$$$$)
{
    my ($self, $mode, $duration, $pnodes, $vnodes) = @_;
	
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();

    DBQueryWarn("update user_stats ".
		"set expt${mode}_count=expt${mode}_count+1, ".
		"    expt${mode}_last=now(), ".
		"    allexpt_duration=allexpt_duration+${duration}, ".
		"    allexpt_vnodes=allexpt_vnodes+${vnodes}, ".
		"    allexpt_pnodes=allexpt_pnodes+${pnodes}, ".
		"    allexpt_vnode_duration=".
		"        allexpt_vnode_duration+($vnodes * ${duration}), ".
		"    allexpt_pnode_duration=".
		"        allexpt_pnode_duration+($pnodes * ${duration}) ".
		"where uid_idx='$uid_idx'");

    $self->Refresh();

    return 0;
}

#
# Bump last activity
#
sub BumpActivity($)
{
    my ($self) = @_;
	
    # Must be a real reference. 
    return -1
	if (! ref($self));

    my $uid_idx = $self->uid_idx();
    
    DBQueryWarn("update user_stats set last_activity=now() ".
		"where uid_idx='$uid_idx'");

    return 0;
}

#
# Check permissions.
#
sub AccessCheck($$$)
{
    my ($self, $user, $access_type) = @_;

    # Must be a real reference. 
    return 0
	if (! ref($self));

    my $mintrust;

    if ($access_type < TB_USERINFO_MIN() || $access_type > TB_USERINFO_MAX()) {
	print "*** Invalid access type $access_type!\n";
	return 0;
    }
    # Admins do whatever they want!
    return 1
	if ($user->IsAdmin());

    # User can muck with his own stuff.
    return 1
	if SameUser($self, $user);

    my $auth_idx = $user->uid_idx();
    my $this_idx = $self->uid_idx();

    #
    # Only project leader in same project as user.
    #
    if ($access_type == TB_USERINFO_MODIFYINFO()) {
        #
        # This join will allow the operation if the current user is in the 
        # same project (any project) as the target user, but with root permissions.
        # 
	my $query_result =
	    DBQueryFatal("select g.trust from group_membership as g ".
			 "left join group_membership as authed on ".
			 "     g.pid_idx=authed.pid_idx and ".
			 "     g.gid_idx=authed.gid_idx and ".
			 "     g.uid_idx='$this_idx' ".
			 "where authed.uid_idx='$auth_idx' and ".
			 "      (authed.trust='project_root')");

	return $query_result->numrows;
    }
    return 0;
}

#
# Home dir for user.
#
sub HomeDir($)
{
    my ($self) = @_;

    # Must be a real reference. 
    return undef
	if (! ref($self));
    
    return USERROOT() . "/" . $self->uid();
}

sub escapeshellarg($)
{
    my ($str)  = @_;
    my @chars  = split('', $str);
    my $result = "";

    foreach my $ch (@chars) {
        if ($ch eq '\'') {
            $result = $result . "\'\\\'";
	}
	$result = $result . "$ch";
    }
    return "'$result'";
}

#
# Check to see if a uid is valid.
#
sub ValidUID($$)
{
    my ($class, $uid) = @_;

    return TBcheck_dbslot($uid, "users", "uid",
			  TBDB_CHECKDBSLOT_WARN()|
			  TBDB_CHECKDBSLOT_ERROR());
}

sub ValidEmail($$)
{
    my ($class, $email) = @_;

    return TBcheck_dbslot($email, "users", "usr_email",
			  TBDB_CHECKDBSLOT_WARN()|
			  TBDB_CHECKDBSLOT_ERROR());
}

#
# Default project. If not set in the users table, then look at the
# project membership, and if only one project then use that. 
#
sub DefaultProject($)
{
    my ($self) = @_;
    my $project = undef;
    
    require Project;
    
    if (defined($self->default_project())) {
	$project = Project->Lookup($self->default_project());
	return $project
	    if (defined($project) && $project->LookupUser($self));
    }
    return $project
	if ($self->FirstApprovedProject(\$project) == 0);
    
    return undef;
}

#
# Cross loging from an emulab peer. Create a login entry, returning
# the hash of the hash to use as a key.
#
sub CrossLogin($)
{
    my ($self) = @_;
    my $uid     = $self->uid();
    my $uid_idx = $self->uid_idx();
    my $timeout = time() + 30;
    my $opskey  = TBGenSecretKey();

    my $key=`/bin/dd if=/dev/urandom count=256 bs=1 2> /dev/null | /sbin/sha256`;
    return undef
	if ($?);
    if ($key =~ /^(\w*)$/) {
	$key = $1;
    }
    else {
	return undef;
    }

    #
    # Note that this hash (of the key) is purposely a different algorithm
    # then what is used in the normal web login path (in the php code).
    # This is to protect against the hash being stolen out of the user
    # browser and used to do an xlogin.
    #
    my $hash = `echo $key | /sbin/md5`;
    return undef
	if ($?);
    if ($hash =~ /^(\w*)$/) {
	$hash = $1;
    }
    else {
	return undef;
    }

    return undef
	if (!DBQueryWarn("replace into login set ".
			 "  uid='$uid', uid_idx='$uid_idx', ".
			 "  hashkey='$key', hashhash='$hash', ".
			 "  timeout='$timeout', adminon=0, opskey='$opskey'"));
    return $hash;
}

#
# Return user_exports info, as a plain hash.
#
sub PeerExports($$)
{
    my ($self, $pref) = @_;
    my $uid_idx = $self->uid_idx();
    my $result  = {};

    my $query_result =
	DBQueryWarn("select e.*,p.* from user_exports as e ".
		    "left join emulab_peers as p on p.name=e.peer ".
		    "where e.uid_idx='$uid_idx'");

    while (my $row = $query_result->fetchrow_hashref()) {
	my $peer = $row->{'name'};
	$result->{$peer} = $row;
    }
    $$pref = $result;
    return 0;
}

#
# Make sure user did not delete their home dir.
#
sub HomeDirOkay($;$)
{
    my ($self, $pmsg)  = @_;
    my $homedir = $self->HomeDir();

    if (! -e "$homedir/.ssl/emulab.pem") {
	$$pmsg = "Your Emulab SSL certificate is gone! Did you delete it?"
	    if (defined($pmsg));
	return -1;
    }
    if (! -e "$homedir/.ssl") {
	$$pmsg = "Your .ssl directory is gone! Did you delete it?"
	    if (defined($pmsg));
	return -1;
    }
    if (! -e "$homedir") {
	$$pmsg = "Your home directory is gone! Did you delete it?"
	    if (defined($pmsg));
	return -1;
    }
    return 0;
}

#
# Set/Get credential for a user. These are used by APT to store a speaksfor
# credential for a nonlocal user, but might also use it later to 
#
sub StoreCredential($$$$)
{
    my ($self, $cred, $expires, $cert) = @_;

    my $uid = $self->uid();
    my $uid_idx = $self->uid_idx();
    my $safe_credential = DBQuoteSpecial($cred);
    my $safe_certificate = DBQuoteSpecial($cert);

    return -1
	if (!DBQueryWarn("replace into user_credentials set ".
			 "  uid='$uid', uid_idx='$uid_idx',created=now(), ".
			 "  expires='$expires', ".
			 "  credential_string=$safe_credential, ".
			 "  certificate_string=$safe_certificate"));

    return 0;
}

sub GetStoredCredential($)
{
    my ($self) = @_;

    my $uid = $self->uid();
    my $uid_idx = $self->uid_idx();

    my $query_result =
	DBQueryWarn("select credential_string,certificate_string ".
		    "  from user_credentials ".
		    "where uid_idx='$uid_idx'");

    return undef
	if (!$query_result || !$query_result->numrows);
    
    my ($cred, $cert) = $query_result->fetchrow_array();
    return ($cred, $cert);
}

#
# Do an exports setup if needed (ZFS). See exports_setup, when ZFS is on
# we do not export all users, only recently active ones. 
#
sub UpdateExports($)
{
    my ($self) = @_;
    my $uid_idx = $self->uid_idx();

    return 0
	if (! ($WITHZFS && ($ZFS_NOEXPORT || !$WITHAMD)));
    my $exports_limit = GetSiteVar("general/export_active");
    return 0
	if (!$exports_limit);

    my $query_result =
	DBQueryWarn("select UNIX_TIMESTAMP(last_activity) from user_stats ".
		    "where uid_idx='$uid_idx'");
    # Hmm.
    return 0
	if (!$query_result->numrows);

    my ($last_activity) = $query_result->fetchrow_array();

    # Always update database so exports_setup will do something,
    # and to mark activity to keep mount active.
    DBQueryWarn("update user_stats set last_activity=now() ".
		"where uid_idx='$uid_idx'")
	or return -1;
	
    if (!defined($last_activity) ||
	time() - $last_activity > ((($exports_limit * 24) - 12) * 3600)) {
	if ($ZFS_NOEXPORT) {
	    mysystem($EXPORTS_SETUP);
	}
	elsif (!$WITHAMD) {
	    mysystem($EXPORTS_SETUP . " -B");
	}
	# failed, reset the timestamp
	if ($?) {
	    my $set = (defined($last_activity) ?
		       "FROM_UNIXTIME($last_activity)" : "null");

	    DBQueryWarn("update user_stats set last_activity=$set ".
			"where uid_idx='$uid_idx'");
	    return -1;
	}
    }
    return 0;
}

#
# A simple interface to the user_token_passwords table.  This table
# holds non-login passwords for user access to various testbed
# subsystems, each associated with a user account for accounting
# purposes.  If you need a non-user oauth-like token, that will need
# another table.  When users login with these usernames/passwords, they
# should be given an oauth (or similar) token.
#
# Table fields:
#   * uid_idx - users.idx
#   * uid - users.uid
#   * subsystem - a name that identifies the subsystem/function/token issuer
#   * scope_type - the type of access being granted
#   * scope_value - the value of access being granted
#   * username - the login username provided to the authentication endpoint;
#       need not be the username!
#   * plaintext - the plaintext value of the password; only necessary if the
#       user should be able to retrieve it through some secure interface
#   * hash - the password hash to be checked at authentication
#   * expiration - the expiration time of this username/password; either an
#       int (a unix timestamp) or a string (a local mysql datetime).
#   * token_lifetime - the lifetime of each token generated for this
#       username/password
#   * token_onetime - 1 if each token generated for this username/password
#       should be a one-time-use token; 0 otherwise
#   * system - 1 if this is a system-created username necessary for an
#       infrastructure service (i.e. capturing a disk image); 0 otherwise.
#
# Obviously, not all subsystems/token issuers would require or be
# capable of using all these fields; but this should be a good set for
# supporting a variety of OAuth tokens.
#
# There is a UNIQUE KEY set:
#     UNIQUE KEY `user_token` (`subsystem`,`username`,`plaintext`)
# We want to allow a user to have multiple, same-named passwords per
# service; but they ought to have a different plaintext value.  If we
# included hash in the key, we could not the latter restriction due to
# the random bits in the salt; thus we opt to only allow one empty
# password per username.  This should be a fine compromise.
#

#
# Add a username/password, associated with an existing user account, to
# be used for token generation during authn/authz (i.e., OAuth):
#
#   $user->AddTokenPassword($target_user,$subsystem,$scope_type,$scope_value,
#       $username,$plaintext,$hash;$expiration,$token_lifetime,$token_onetime,
#       $system)
#
# where subsystem must be set; scope_type and scope_value default to ''
# if undef; username defaults to this_user or target_user if unset.  One
# of plaintext or hash must be set; if both are set,
# crypt(plaintext,hash) == hash must hold.  plaintext defaults to '' if
# undef.  expiration should be set by the caller if necessary for that
# subsystem; it defaults to NULL (never expires); token_lifetime, if
# unset, will be set to a default value by the subsystem token issuer;
# token_onetime defaults to 0 (i.e., token will be multi-user) if not
# set; system defaults to 0 if not set.
#
# This is a library function, never called based on direct input from
# the user; therefore we do not check the password strength!  We are
# zealous in escaping input ags anyway.
#
sub AddTokenPassword($$$$$$$$$;$$$$)
{
    my ($class, $this_user, $target_user, $subsystem, $scope_type, $scope_value,
	$username, $plaintext, $hash,
	$expiration, $token_lifetime, $token_onetime, $system) = @_;

    my $this_uid = $this_user->uid();
    my $isadmin = $this_user->IsAdmin();

    my $target_uid = $target_user->uid();
    my $target_uid_idx = $target_user->uid_idx();
    my $status = $target_user->status();

    return 1
	if (!defined($subsystem) || !$subsystem);
    return 1
	if ((!defined($plaintext) || !$plaintext)
	    && (!defined($hash) || !$hash));
    return 1
	if (defined($plaintext) && $plaintext ne ""
	    && defined($hash) && $hash ne ""
	    && crypt($plaintext,$hash) ne $hash);

    if (!defined($username) || !$username) {
	$username = $target_uid;
    }
    $scope_type = ""
	if (!defined($scope_type));
    $scope_value = ""
	if (!defined($scope_value));
    if (!defined($hash) || $hash eq "") {
	#$rs = join("",(".","/",0..9,"A".."Z","a".."z")[map { rand(64) } (0..15)]);
	#$hash = crypt($plaintext,"\$5\$$rs\$");
	$hash = PassWordHash($plaintext);
	return 2
	    if (!defined($hash) || $hash eq '');
    }

    my $qpt = DBQuoteSpecial($plaintext);
    my $qpw = DBQuoteSpecial($hash);
    my $exp = "NULL";
    if (defined($expiration) && $expiration ne "") {
	if ($expiration =~ /^\d+$/) {
	    $exp = "DATE_ADD(NOW(), INTERVAL $expiration SECOND)";
	}
	else {
	    $exp = DBQuoteSpecial($expiration);
	}
    }
    my ($lt,$os,$sys) = (3600,0,0);
    $lt = $token_lifetime
	if (defined($token_lifetime) && $token_lifetime ne "");
    $os = 1
	if (defined($token_onetime) && $token_onetime);
    $sys = 1
	if (defined($system) && $system);
    my $q = "insert into user_token_passwords".
	" (uid_idx,uid,subsystem,scope_type,scope_value,username,plaintext,".
	"  hash,issued,expiration,token_lifetime,token_onetime) values".
	" ('$target_uid_idx','$target_uid','$subsystem','$scope_type',".
	"  '$scope_value','$username',$qpt,$qpw,NOW(),$exp,$lt,$os)";
    return 1
	if (!DBQueryWarn($q));

    return 0;
}

sub DeleteTokenPasswords($$$$$;$)
{
    my ($class, $this_user, $target_user, $subsystem, $username,
	$plaintext) = @_;

    my $this_uid = $this_user->uid();
    my $isadmin = $this_user->IsAdmin();

    my $target_uid = $target_user->uid();
    my $target_uid_idx = $target_user->uid_idx();
    my $status = $target_user->status();

    return 1
	if (!defined($subsystem) || !$subsystem);
    if (!defined($username) || !$username) {
	$username = $target_uid;
    }

    my $q = "delete from user_token_passwords where".
	" uid_idx='$target_uid_idx' and subsystem='$subsystem'".
	"   and username='$username'";
    if (defined($plaintext)) {
	$q .= " and plaintext=" . DBQuoteSpecial($plaintext);
    }
    return 1
	if (!DBQueryWarn($q));

    return 0;
}

sub DeleteTokenPasswordByIdx($$$$)
{
    my ($class, $this_user, $target_user, $idx) = @_;

    my $this_uid = $this_user->uid();
    my $isadmin = $this_user->IsAdmin();

    my $target_uid = $target_user->uid();
    my $target_uid_idx = $target_user->uid_idx();

    return 1
	if (!defined($idx) || !$idx);

    my $q = "delete from user_token_passwords where".
	" uid_idx='$target_uid_idx' and idx=".DBQuoteSpecial($idx);
    return 1
	if (!DBQueryWarn($q));

    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;

