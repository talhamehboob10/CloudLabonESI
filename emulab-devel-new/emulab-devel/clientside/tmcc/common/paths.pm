#!/usr/bin/perl -wT
#
# Copyright (c) 2000-2003, 2016 University of Utah and the Flux Group.
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
package emulabpaths;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( $BINDIR $ETCDIR $VARDIR $BOOTDIR $DBDIR $LOGDIR $LOCKDIR $BLOBDIR
              $DYNRUNDIR $STATICRUNDIR
            );

#
# This path stuff will go away when the world is consistent. Until then
# we need to be able to upgrade individual scripts to the various setups.
# I know, what a mess.
#
$BINDIR  = "";
$ETCDIR  = "";
$VARDIR  = "";
$BOOTDIR = "";
$DBDIR   = "";
$LOGDIR  = "/var/tmp";
$LOCKDIR = "/var/tmp";

if (-d "/usr/local/etc/emulab") {
    $BINDIR = "/usr/local/etc/emulab";
    unshift(@INC, "/usr/local/etc/emulab");
    if (-d "/etc/emulab") {
	$ETCDIR = "/etc/emulab";
    }
    else {
	$ETCDIR = "/usr/local/etc/emulab";
    }
    $STATICRUNDIR = "/usr/local/etc/emulab/run";
    $VARDIR  = "/var/emulab";
    $BOOTDIR = "/var/emulab/boot";
    $LOGDIR  = "/var/emulab/logs";
    $LOCKDIR = "/var/emulab/lock";
    $DBDIR   = "/var/emulab/db";
}
elsif (-d "/etc/testbed") {
    unshift(@INC, "/etc/testbed");
    $ETCDIR  = "/etc/testbed";
    $BINDIR  = "/etc/testbed";
    $VARDIR  = "/etc/testbed";
    $BOOTDIR = "/etc/testbed";
    $DBDIR   = "/etc/testbed";
    $STATICRUNDIR = "/etc/testbed/run";
}
elsif (-d "/etc/rc.d/testbed") {
    unshift(@INC, "/etc/rc.d/testbed");
    $ETCDIR  = "/etc/rc.d/testbed";
    $BINDIR  = "/etc/rc.d/testbed";
    $VARDIR  = "/etc/rc.d/testbed";
    $BOOTDIR = "/etc/rc.d/testbed";
    $DBDIR   = "/etc/rc.d/testbed";
    $STATICRUNDIR = "/etc/rc.d/testbed/run";
}
else {
    print "$0: Cannot find proper emulab paths!\n";
    exit 1;
}

$BLOBDIR = $BOOTDIR;
$DYNRUNDIR = "/var/run/emulab";

#
# Untaint path
#
$ENV{'PATH'} = "$BINDIR:/bin:/sbin:/usr/bin:/usr/sbin:".
    "/usr/local/bin:/usr/local/sbin:/usr/site/bin:/usr/site/sbin";
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

1;

