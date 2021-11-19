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
use 5.008_000;
use strict;
use warnings;

our $VERSION = '1.00';

package SemiModern::Perl;
use IO::Handle;
use Scalar::Util 'openhandle';
use Carp;

=head1 NAME

ensures perl version >= 5.008

=over 4

=item say

implements a perl5.10 like say for perl < 5.10

=cut

sub say {
    my $currfh = select();
    my $handle;
    {
        no strict 'refs';
        $handle = openhandle($_[0]) ? shift : \*$currfh;
        use strict 'refs';
    }
    @_ = $_ unless @_;
    my $warning;
    local $SIG{__WARN__} = sub { $warning = join q{}, @_ };
    my $res = print {$handle} @_, "\n";
    return $res if $res;
    $warning =~ s/[ ]at[ ].*//xms;
    croak $warning;
}

=item sayd

dumps args and prints result with say

=cut

sub sayd {
  use Data::Dumper;
  say Dumper(@_);
}

=back

=cut


if (1 || $] < 5.010) {
  *IO::Handle::say = \&say if ! defined &IO::Handle::say;
}

sub import {
  warnings->import();
  strict->import();
  if (1 || $] < 5.010) {
    no strict 'refs';
    *{caller() . '::say'} = \&say;
    *{caller() . '::sayd'} = \&sayd;
    use strict 'refs';
  }
}

1;
