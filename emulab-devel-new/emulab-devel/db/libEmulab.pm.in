#!/usr/bin/perl -w
#
# Copyright (c) 2000-2016, 2018 University of Utah and the Flux Group.
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
package libEmulab;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = qw(Exporter);
@EXPORT = qw(SiteVarExists CreateSiteVar GetSiteVar SetSiteVar
	     GetSiteVarDesc SetSiteVarDesc NoLogins IsShutDown.
	     IsMultiPCArchitecture PCArchitectures);

use emdb;

#
# Check if a site-specific variable exists.
#
# usage: SiteVarExists($name)
#        returns 1 if variable exists;
#        returns 0 otherwise.
#
sub SiteVarExists($)
{
    my($name) = @_;

    $name = DBQuoteSpecial( $name );

    my $query_result =
	DBQueryWarn("select name from sitevariables where name=$name");

    return 0
	if (!$query_result);
    
    return $query_result->numrows;
}

#
# Create a new site variable.
#
# usage: CreateSiteVar($name, $desc, $defvalue, $value, $nsinclude)
#        All but $name and $desc are optional.
#        Returns 1 on success, 0 if sitevar exists or on failure.
#
sub CreateSiteVar($$;$$$)
{
    my ($name,$desc,$defval,$val,$nsinc) = @_;

    return 0
	if (SiteVarExists($name));
    return 0
	if (!defined($desc));

    $name = DBQuoteSpecial($name);
    $desc = DBQuoteSpecial($desc);
    if (defined($defval)) {
	$defval = DBQuoteSpecial($defval);
    } else {
	$defval = "NULL";
    }
    if (defined($val)) {
	$val = DBQuoteSpecial($val);
    } else {
	$val = "NULL";
    }
    if (defined($nsinc)) {
	$nsinc = ($nsinc != 0);
    } else {
	$nsinc = 0;
    }

    my $query_result =
	DBQueryWarn("insert into sitevariables ".
		    "(name,value,defaultvalue,description,ns_include) ".
		    "values ($name,$val,$defval,$desc,$nsinc)");

    return $query_result ? 1 : 0;
}

#
# Get site-specific variable.
# Get the value of the variable, or the default value if
# the value is undefined (NULL).
#

# usage: GetSiteVar($name, char \*rptr )
#        Without rptr: returns value if variable is defined; dies otherwise.
#        With rptr:    returns value in $rptr if variable is defined; returns
#                      zero otherwise, or any failure.
#
sub GetSiteVar($;$)
{
    my ($name, $rptr) = @_;
    my $value;

    $name = DBQuoteSpecial( $name );
    
    my $query_string =
	"select value,defaultvalue from sitevariables where name=$name";

    my $query_result;
    if (defined($rptr)) {
	#
	# I added the result parameter as an option to avoid changing every
	# call to TBGetSiteVar(). Sorry. When called in this manner, it is
	# up to the caller to decide what to do when it fails. 
	#
	$query_result = DBQueryWarn($query_string);

	return 0
	    if (! $query_result)
    }
    else {
	$query_result = DBQueryFatal($query_string);
    }

    if ($query_result->numrows > 0) {
	my ($curvalue, $defaultvalue) = $query_result->fetchrow_array();

	if (defined($curvalue)) {
	    $value = $curvalue;
	}
	elsif (defined($defaultvalue)) {
	    $value = $defaultvalue;
	}
    }
    if (defined($rptr)) {
	if (defined($value)) {
	    $$rptr = $value;
	    return 1;
	}
	return 0;
    }
    elsif (defined($value)) {
	return $value;
    }
    die("*** $0:\n".
	"    Attempted to fetch unknown site variable $name\n");
}

#
# Set a sitevar. Assumed to be a real sitevar.
#
# usage: SetSiteVar($name, $value)
#
sub SetSiteVar($$)
{
    my ($name, $value) = @_;

    $name  = DBQuoteSpecial($name);
    $value = DBQuoteSpecial($value);

    my $query_result =
	DBQueryWarn("update sitevariables set value=$value where name=$name");

    return 0
	if (!$query_result);
    return 1;
}

# usage: GetSiteVarDesc($name)
#        Returns description if variable is defined; dies otherwise.
#
sub GetSiteVarDesc($)
{
    my ($name) = @_;
    my $value;

    $name = DBQuoteSpecial( $name );
    
    my $query_string =
	"select description from sitevariables where name=$name";

    my $query_result = DBQueryFatal($query_string);
    if ($query_result->numrows > 0) {
	my ($desc) = $query_result->fetchrow_array();
	return $desc;
    }
    die("*** $0:\n".
	"    Attempted to fetch description of unknown site variable $name\n");
}

#
# Set a sitevar description. Assumed to be a real sitevar.
#
# usage: SetSiteVarDesc($name, $desc)
#
sub SetSiteVarDesc($$)
{
    my ($name, $desc) = @_;

    $name  = DBQuoteSpecial($name);
    $desc = DBQuoteSpecial($desc);

    my $query_result =
	DBQueryWarn("update sitevariables set description=$desc where name=$name");

    return 0
	if (!$query_result);
    return 1;
}

#
# Check for nologins; web interface disabled means other interfaces
# should be disabled. Not using libdb:GetSiteVar cause do not want to
# drag all that stuff in. Predicate; retun 1 if no logins is set.
#
sub NoLogins()
{
    my $shutdown = IsShutDown();
    return 1
	if ($shutdown);
    
    my $query_result =
	DBQueryWarn("select value from sitevariables ".
		    "where name='web/nologins'");

    return 1
	if (!$query_result);
    return 0
	if (!$query_result->numrows);
    my ($value) = $query_result->fetchrow_array();

    return ($value ? 1 : 0);
}

# Ditto shutdown.
sub IsShutDown()
{
    my $query_result =
	DBQueryWarn("select value from sitevariables ".
		    "where name='general/testbed_shutdown'");

    return 1
	if (!$query_result);
    return 0
	if (!$query_result->numrows);
    my ($value) = $query_result->fetchrow_array();

    return ($value ? 1 : 0);
}

#
# Lock and Unlock.
#
sub EmulabLock($)
{
    my ($name) = @_;

    EmulabCreateLock($name) == 0
	or return -1;

    my $query_result =
	DBQueryWarn("update emulab_locks set value=1 " .
		    "where name='$name' and value=0");

    if (! $query_result || $query_result->affectedrows == 0) {
	return -1;
    }
    return 0;
}

sub EmulabUnlock($)
{
    my ($name) = @_;

    DBQueryWarn("update emulab_locks set value=0 where name='$name'")
	or return -1;

    return 0;
}

sub EmulabCreateLock($)
{
    my ($name) = @_;
    
    my $query_result =
	DBQueryWarn("select * from emulab_locks where name='$name'");
    return -1
	if (! $query_result);
    if (!$query_result->numrows) {
	DBQueryWarn("lock tables emulab_locks write")
	    or return -1;

	$query_result =
	    DBQueryWarn("select * from emulab_locks where name='$name'");
	if (! $query_result) {
	    DBQueryWarn("unlock tables");
	    return -1;
	}
	if (!$query_result->numrows &&
	    !DBQueryWarn("insert into emulab_locks set ".
			 "  name='$name',value=0")) {
	    DBQueryWarn("unlock tables");
	    return -1;
	}
	DBQueryWarn("unlock tables")
	    or return -1;
    }
    return 0;
}

#
# Count up/down locking.
#
sub EmulabCountLock($$)
{
    my ($name, $count) = @_;

    EmulabCreateLock($name) == 0
	or return -1;

    my $query_result =
	DBQueryWarn("update emulab_locks set value=value+1 " .
		    "where name='$name' and value<${count}");

    if (! $query_result || $query_result->affectedrows == 0) {
	return -1;
    }
    return 0;
}

sub EmulabCountUnlock($)
{
    my ($name) = @_;

    DBQueryWarn("update emulab_locks set value=value-1 ".
		"where name='$name' and value>0")
	or return -1;

    return 0;
}

#
# Are we multi architecture (pc class only). Only consider an architecture
# if we have actual nodes for it.
#
sub IsMultiPCArchitecture()
{
    my $query_result =
	DBQueryWarn("select distinct architecture from node_types as nt ".
		    "left join nodes as n on n.type=nt.type ".
		    "where architecture is not null and class='pc' and ".
		    "   n.node_id is not null and n.role='testnode' and ".
		    "   architecture!=''");
    return $query_result->numrows > 1 ? 1 : 0;
}
sub PCArchitectures()
{
    my @results = ();
    
    my $query_result =
	DBQueryWarn("select distinct architecture from node_types as nt ".
		    "left join nodes as n on n.type=nt.type ".
		    "where architecture is not null and ".
		    "   architecture!='' and ".
		    "   class='pc' and ".
		    "   n.node_id is not null and n.role='testnode'");
    while (my ($architecture) = $query_result->fetchrow_array()) {
	push(@results, $architecture);
    }
    return @results;
}

1;
