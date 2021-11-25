#!/usr/bin/perl -wT
#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
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

#
# Tuny helper library for Emulab rc scripts.
#
package librc;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw(fatal warning scriptname logit);

# Must come after package declaration!
use English;

#
# Turn off line buffering on output
#
$| = 1;

# Load up the paths. Done like this in case init code is needed.
BEGIN
{
    if (! -e "/etc/emulab/paths.pm") {
	die("Yikes! Could not require /etc/emulab/paths.pm!\n");
    }
    require "/etc/emulab/paths.pm";
    import emulabpaths;
}

#
# Log something to the console. The image will setup syslogd.conf so that
# local5.err goes to the console!
#
sub logit($$)
{
    my ($tag, $msg) = @_;
    
    system("logger -p local5.err -i -t $tag '$msg'");
}

#
# Fatal error. Display and die.
# 
sub fatal($)
{
    my($mesg) = $_[0];

    die("*** $0:\n".
	"    $mesg\n");
}

#
# Display warning.
# 
sub warning($)
{
    my($mesg) = $_[0];

    print("*** $0:\n".
	  "    WARNING: $mesg\n");
}

#
# Return scriptname with no path.
#
sub scriptname()
{
    my ($dirpath,$base) = ($PROGRAM_NAME =~ m#^(.*/)?(.*)#);

    return $base;
}

1;

