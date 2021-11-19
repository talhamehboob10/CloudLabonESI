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
package TestBed::Daemonize;
use SemiModern::Perl;

sub ForkOrDie {
  my $pid;
  return $pid if (defined($pid = fork));
  die "Fork failed: $!";
}

sub daemonize {
  exit if ForkOrDie;
  die "Cannot detach from controlling Terminal" unless POSIX::setsid;
  exit if ForkOrDie;
  open(STDIN,  "+>/dev/null");
  open(STDOUT, "+>", "stdout.$$");
  open(STDERR, "+>", "stderr.$$");
}

sub email {
  my $s = eval "use Email::Stuff; Email::Stuff->new;";
  if ($@) { 
    die "Email::Stuff not installed";
  }
  return $s;
}

sub attach_text {
  use File::Basename;
  my ($s, $fn) = @_;
  my $bn = File::Basename::basename($fn) or undef;
  return $s->attach(Tools::slurp($fn), name => $bn, filename => $bn, content_type => 'text/plain');
} 

sub email_daemonize_logs {
  my ($to) = @_;
  my $s = email;
  $s->from     ('TestSwap__dont_reply@emulab.net' )
    ->to       ($to )
    ->subject  ("TestSwap run $$")
    ->text_body("TestSwap run $$");
  attach_text($s,"stdout.$$");
  attach_text($s,"stderr.$$");
  $s->send;
}
=pod

=head1 TestBed::Daemonize

=over 4

=item C<ForkOrDie>

dies if fork fails

=item C<daemonize>

daemonizes the process redirecting stdout and stderr to files

=item C<email>

generates a EMail::Stuff object

=item C<attach_text>

attaches a text file to a Email::Stuff object

=item C<email_daemonize_logs($to)>

send logs of daemon activity to $to

=back

=cut

1;
