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
package TestBed::ParallelRunner::Executor::Exception;
use Moose;
  has original => ( is => 'rw');
no Moose;

package TestBed::ParallelRunner::Executor::PrerunError;
use Moose;
  extends('TestBed::ParallelRunner::Executor::Exception');
no Moose;

package TestBed::ParallelRunner::Executor::SwapinError;
use Moose;
  extends('TestBed::ParallelRunner::Executor::Exception');
no Moose;

package TestBed::ParallelRunner::Executor::RunError;
use Moose;
  extends('TestBed::ParallelRunner::Executor::Exception');
no Moose;

package TestBed::ParallelRunner::Executor::SwapoutError;
use Moose;
  extends('TestBed::ParallelRunner::Executor::Exception');
no Moose;

package TestBed::ParallelRunner::Executor::KillError;
use Moose;
  extends('TestBed::ParallelRunner::Executor::Exception');
no Moose;

package TestBed::ParallelRunner::Executor;
use TestBed::ParallelRunner::ErrorStrategy;
use SemiModern::Perl;
use TestBed::TestSuite::Experiment;
use Moose;
use Data::Dumper;

has 'e'    => ( isa => 'TestBed::TestSuite::Experiment', is => 'rw');
has 'desc' => ( isa => 'Str', is => 'rw');
has 'ns'   => ( is => 'rw');
has 'proc' => ( isa => 'CodeRef', is => 'rw');
has 'test_count' => ( isa => 'Any', is => 'rw');
has 'error_strategy' => ( is => 'rw', lazy => 1, default => sub { TestBed::ParallelRunner::ErrorStrategy->new; } );
has 'pre_result_handler' => ( isa => 'CodeRef', is => 'rw');

sub ns_text {
  my $s = shift;
  my $ns = $s->ns;
  if (ref($ns) eq 'CODE') {
    return $ns->();
  }
  return $ns;
}

sub parse_options {
  my %options = @_;

  if (defined (delete $options{retry})) {
    $options{error_strategy} = TestBed::ParallelRunner::ErrorRetryStrategy->new;
  }

  if (defined (my $params = delete $options{backoff})) {
    $options{error_strategy} = TestBed::ParallelRunner::BackoffStrategy->build($params);
    
  }
  
  if (defined (my $strategy = delete $options{strategy})) {
    $options{error_strategy} = $strategy;
  }
  
  %options;
}

sub buildt { shift; TestBed::ParallelRunner::Executor->new( parse_options(@_)); }

sub build {
  my ($e, $ns, $sub, $test_count, $desc) = (shift, shift, shift, shift, shift);
  return TestBed::ParallelRunner::Executor->new(
    'e'          => $e,
    'ns'         => $ns,
    'proc'       => $sub,
    'test_count' => $test_count,
    'desc'       => $desc,
    parse_options(@_)
  );
}

sub handleResult { 
  my ($s) = @_;
  my $prh = $s->pre_result_handler;
  $prh->(@_) if $prh;
  $s->error_strategy->handleResult( @_); 
}

sub prerun{
  my $s = shift;
  if (checkexclude('create')) {
    return +{'maximum_nodes' => 0};
  }
  my $r = eval { $s->e->create_and_get_metadata($s->ns_text); };
  die TestBed::ParallelRunner::Executor::PrerunError->new( original => $@ ) if $@;
  return $r;
}

sub checkexclude {
  my $stage = shift;
  return grep { $_ eq $stage } @{ $TBConfig::exclude_steps };
}

sub failReason {
  my $s = shift;
  sprintf("FAILURE %s: %s", $s->e->eid, shift->error_type);
}

sub execute {
  my $s = shift;
  my $e = $s->e;
  my $eid = $e->eid;

  my $run_exception;
  my $swapout_exception;

  eval { $e->swapin_wait; } unless checkexclude('swapin');
  my $swapin_exception = $@;
  die TestBed::ParallelRunner::Executor::SwapinError->new( original => $swapin_exception ) if $swapin_exception;

  eval { $s->proc->($e); } unless checkexclude('run');
  $run_exception = $@;
  die TestBed::ParallelRunner::Executor::RunError->new( original => $run_exception ) if $run_exception;

  eval { $e->swapout_wait; } unless checkexclude('swapout');
  $swapout_exception = $@;
  die TestBed::ParallelRunner::Executor::SwapoutError->new( original => $swapout_exception ) if $swapout_exception;

  eval { $e->end_wait; } unless checkexclude('end');
  my $end_exception = $@;
  die TestBed::ParallelRunner::Executor::KillError->new( original => $end_exception ) if $end_exception;

  return 1;
}

sub ensure_end {
  my $s = shift;
  my $e = $s->e;
  my $eid = $e->eid;

  eval { 
    $e->ensure_end; 
  } unless checkexclude('end');

  my $end_exception = $@;
  die TestBed::ParallelRunner::Executor::KillError->new( original => $end_exception ) if $end_exception;
}

=head1 NAME

TestBed::ParallelRunner::Executor

Represents a ParallelRunner Job

=over 4

=item C<< build($e, $ns, $sub, $test_count, $desc) >>

constructs a TestBed::ParallelRunner::Test job

=item C<< checkexclude($stage_name) >>

checks if $stage_name is in $TBConfig::exclude_steps

=item C<< $prt->ns_text >>

checks if ns_text is a CODE reference, is so execute it otherwise return ns_text

=item C<< $prt->prerun >>

executes the pre_running phase of experiment and determines min and max node counts.

=item C<< $prt->handleResult >>

handles the result using a error strategy

=item C<< $prt->execute >>

swaps in the experiment and runs the specified test
it kills the experiment unconditionaly after the test returns

=item C<< $prt->ensure_end >>

calls end on an experiment allowing for experiment doesn't exist and in transition exceptions

=item C<< $prt->parse_options >>

parses retry =>1, backoff => "\d+:\d+:\d+:\d+", strategy => '....' options
and build the appropriate error_strategy object

=item C<< $prt->buildt >>

builds a naked TestBed::ParallelRunner::Executor for testing purposes

=item C<< $prt->failReason($reason) >>

prints $eid and fail reason

=back

=cut

1;
