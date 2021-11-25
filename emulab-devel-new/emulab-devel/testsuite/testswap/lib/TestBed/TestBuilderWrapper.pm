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
package TestBed::TestBuilderWrapper;
use Test::Builder;

sub set_test_builder_to_end_state {
  my ($test_count, %options) = @_;
  my $b = Test::Builder->new;
  $b->current_test($test_count); 
}

sub reset_test_builder {
  my ($test_count, %options) = @_;
  my $b = Test::Builder->new;
  $b->reset; 
  $b->use_numbers(0) if $options{no_numbers};
  if ($test_count) { $b->expected_tests($test_count); }
  else { $b->no_plan; }
}

sub setup_test_builder_ouputs {
  my ($out, $err) = @_;
  my $b = Test::Builder->new;
  $b->output($out);
  $b->fail_output($out);
  $b->todo_output($out);
}

1;
