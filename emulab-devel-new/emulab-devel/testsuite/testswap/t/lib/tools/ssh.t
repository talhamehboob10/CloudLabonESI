#!/usr/bin/perl
#
# Copyright (c) 2009 University of Utah and the Flux Group.
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
use SemiModern::Perl;
use TBConfig;
use Tools;
use Tools::TBSSH;
use Data::Dumper;
use Test::More tests => 7;

ok(0 == [Tools::TBSSH::cmdcheckoutput($TBConfig::OPS_SERVER, "hostname", sub { $_[0] =~ /ops.emulab.net/; } )]->[0], 'ssh ops hostname');
ok(1 == [Tools::TBSSH::cmdcheckoutput($TBConfig::OPS_SERVER, "false", sub { $_[2] } )]->[0], 'ssh ops false return code');
ok(0 == [Tools::TBSSH::cmdcheckoutput($TBConfig::OPS_SERVER, "true", sub { !$_[2]} )]->[0], 'ssh ops true return code');

#test instance method
my $ssh = Tools::TBSSH::instance($TBConfig::OPS_SERVER);
ok(0 == [Tools::TBSSH::cmdcheckoutput($TBConfig::OPS_SERVER, "hostname", sub { $_[0] =~ /ops.emulab.net/; } )]->[0], 'ssh ops hostname');

#test 
ok(0 == [$ssh->cmdsuccess("hostname", sub { $_[0] =~ /ops.emulab.net/; } )]->[0], 'cmdsuccess(..) test');
ok(0 == [$ssh->cmdsuccessdump("hostname", sub { $_[0] =~ /ops.emulab.net/; } )]->[0], 'cmdsuccessdump(..) test');

ok(0 == [$ssh->cmdsuccess_stdin("python -", 'print "Hello"' )]->[0], 'python stdin Hello test');
