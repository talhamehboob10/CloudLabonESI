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
package TestBed::XMLRPC::Client::Pretty;
use SemiModern::Perl;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(pretty_listexp experiments_hash_to_list);
use Data::Dumper;

sub pretty_listexp {
  for my $ed (experiments_hash_to_list(@_)) {
    my ($pid, $gid, $eid,) = @{ $ed->[0] };
    my $status = $ed->[1]->{'state'};
    say "$pid :: $gid :: $eid $status";
  }
}

sub experiments_hash_to_list {
  my ($h) = @_;
  my @exper_list;
  while(my ($pk, $v) = each %$h) {
    while(my ($gk, $v) = each %$v) {
      for my $e (@$v) {
        my $eid;
        my $status = "";
        if ( ref $e && exists $e->{'name'} )  { 
          $eid = $e->{'name'};
          $status = $e->{'state'};
        }
        else { $eid = $e; }
        push @exper_list, [ [$pk, $gk, $eid], $e];
      }
    }
  }
  return wantarray ? @exper_list : \@exper_list;
}

=head1 NAME

TestBed::XMLRPC::Client::Pretty;

=over 4

=item C<pretty_listexp>

pretty prints the XMLRPC response from listexp

=item C<experiments_hash_to_list>

converts the nested explist hash to an array of [ [$pid, $gid, $pid] $e] 

=back

=cut

1;
