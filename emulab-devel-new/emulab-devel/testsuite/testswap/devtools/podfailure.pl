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
use Modern::Perl;
use File::Temp;
use Data::Dumper;
use IPC::Run3;
my $fn = "BOZO";

my @todos;
while(my $line = <STDIN>) {
  given($line) {
    when(/#   Failed test/) {}
    when(/#   at /) {}
    when(/^# Coverage for (\S+)/) {
      $fn = $1;
      $fn =~ s/::/\//g;
      $fn .= '.pm';
    }
    when( /Looks like you failed/) {
     next;
    }
    when( /^#\s+(\S+)/ ) {
      say "pushed $fn $1";
      push @todos, [$fn, $1];
    } 
  }
}

for (@todos) {
  my $temp = File::Temp->new();
  my $sfn = $temp->filename;
  my $fn = $_->[0];
  my $subname = $_->[1];
  $temp->print("/$subname\n");
  my $cmd = "vim lib/$fn -s $sfn";
  run3($cmd);
}

#say Dumper(\@todos);
exec 'reset';
