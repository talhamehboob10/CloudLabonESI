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
use inc::Module::Install;

# Define metadata
name            'tbts';
perl_version    '5.008';
author          'Testbed Developers <testbed-dev@flux.utah.edu>';
version         '0.01';

requires      'Moose'               => '0.22';
requires      'RPC::XML::Client'    => '1.24';
requires      'RPC::XML'            => '1.41';
requires      'Test::More'          => '0.86';
requires      'Time::Local'         => '1.1901';
requires      'TAP::Harness'        => '3.16';
requires      'Crypt::X509'         => '0.32';
requires      'Log::Log4perl'       => '1.20';
requires      'Data::UUID'          => '1.149';
requires      'Net::Ping'           => '2.31';
requires      'Crypt::SSLeay'       => '0.57';
requires      'Test::Class'         => '0.31';
requires      'Test::Exception'     => '';
requires      'Term::ReadKey'       => '';

=pod
#too much effort for BSD users to install for now
#required for fast SSH and Crypt::DH
requires      'bignum'              => '0.22';
requires      'Math::BigRat'        => '0.22';
requires      'Math::BigInt::GMP'   => '1.24';

requires      'Net::SSH::Perl'      => '1.34';
requires      'Net::SFTP'           => '0.10';
=cut

auto_install();

WriteAll;
