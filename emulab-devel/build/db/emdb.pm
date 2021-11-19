#!/usr/bin/perl -w
#
# Copyright (c) 2008-2011 University of Utah and the Flux Group.
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
package emdb;
use strict;
use File::Basename;
use English;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = "Exporter";

use emdbi;
use libtestbed;
use libtblog_simple;

# Configure variables
my $TB		= "/test";
my $DBNAME	= "tbdb";
my $SCRIPTNAME  = "Unknown";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";

# Untainted scriptname for email below.
if ($PROGRAM_NAME =~ /^([-\w\.\/]+)$/) {
    $SCRIPTNAME = basename($1);
}
else {
    $SCRIPTNAME = "Tainted";
}

@EXPORT = qw(DBQuery DBQueryFatal DBQueryWarn DBWarn DBFatal DBErr
	     NewTBDBHandle DBQueryN DBQueryFatalN DBQueryWarnN DBErrN
	     DBQuerySingleFatal DBQuerySingleFatalN TBDBDisconnect
	     DBTableExists DBSlotExists DBSlotType DBQuoteSpecial
	     DBKeyExists TBDBConnect TBDBReconnect DBNumber);
@EXPORT = (@EXPORT, @emdbi::EXPORT);

sub TBDBConnect($)	{ return emdbi::TBDBConnect($_[0], $DBNAME); }
sub TBDBReconnect($)    { return emdbi::TBDBReconnect($_[0]); }
sub TBDBDisconnect()    { return emdbi::TBDBDisconnect(); }
sub NewTBDBHandle()     { return emdbi::NewTBDBHandle($DBNAME); }
sub DBNumber()		{ return 0; }
sub DBHandle()		{ return emdbi::DBHandleN(0); }
sub DBHandleN($)	{ return emdbi::DBHandleN($_[0]); }
sub DBQueryN($$)	{ return emdbi::DBQueryN($_[0], $_[1]); }
sub DBQuery($)		{ return emdbi::DBQuery($_[0]); }
sub DBQueryFatalN($$)   { return emdbi::DBQueryFatalN($_[0], $_[1]); }
sub DBQueryFatal($)     { return emdbi::DBQueryFatal($_[0]);}
sub DBQuerySingleFatalN($$) { return emdbi::DBQuerySingleFatalN($_[0], $_[1]);}
sub DBQuerySingleFatal($)   { return emdbi::DBQuerySingleFatal($_[0]);}
sub DBQueryWarnN($$)	{ return emdbi::DBQueryWarnN($_[0], $_[1]); }
sub DBQueryWarn($)      { return emdbi::DBQueryWarn($_[0]);}
sub DBQuoteSpecial($)	{ return emdbi::DBQuoteSpecial($_[0]); }
sub DBErrN($)		{ return emdbi::DBErrN($_[0]); }
sub DBErr()		{ return emdbi::DBErr(); }
sub DBTableExists($)	{ return emdbi::DBTableExists($_[0]); }
sub DBSlotExists($$)	{ return emdbi::DBSlotExists($_[0], $_[1]); }
sub DBKeyExists($$)	{ return emdbi::DBKeyExists($_[0], $_[1]); }
sub DBSlotType($$)	{ return emdbi::DBSlotType($_[0], $_[1]); }
# These are handled differently cause of tblog stuff.
sub DBWarn($;$)		{ DBError(\&tbwarn, $_[0], $_[1]); }
sub DBFatal($;$)	{ DBError(\&tbdie, $_[0], $_[1]); }
sub DBError($$;$) 
{
    my($f, $message, $nomail) = @_;
    
    if (! defined($nomail)) {
	libtestbed::SENDMAIL($TBOPS, "DBError - $message",
			     "$message - In $SCRIPTNAME\n".
			     "$emdbi::DBErrorString\n" .
			     Carp::longmess() . "\n");
    }

    $f->({cause=>'software'}, "$message:\n$emdbi::DBErrorString");
}

# Default connection.
TBDBConnect(0);

1;
