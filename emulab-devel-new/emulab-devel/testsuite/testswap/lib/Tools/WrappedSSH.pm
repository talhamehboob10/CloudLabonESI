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
package Tools::WrappedSSH;
use SemiModern::Perl;
use Data::Dumper;
use TBConfig;
use IPC::Run3;
use Moose;

has 'host' => ( isa => 'Str', is => 'rw');
has 'user' => ( isa => 'Str', is => 'rw');

sub cmd {
  my ($ssh, $cmd, $stdin) = @_;
  my $out;
  my $err;
  my $host = $ssh->host;
  my $user = $ssh->user;
  my $sshcmd = "ssh -x -o BatchMode=yes -o StrictHostKeyChecking=no $user\@$host $cmd";
  run3($sshcmd, \$stdin, \$out, \$err);
  my $rc = $? >> 8;
  ($out, $err, $rc);
}

sub scp_worker {
  my ($ssh, @files) = @_;
  my $out;
  my $err;
  my $host = $ssh->host;
  my $user = $ssh->user;
  my $sshcmd = "scp -o BatchMode=yes -o StrictHostKeyChecking=no @files";
  run3($sshcmd, undef, \$out, \$err);
  my $rc = $? >> 8;
  ($out, $err, $rc);
}

sub saydebug {
  my $s = shift; 
  say sprintf("ssh %s@%s %s", $s->user, $s->host, "@_");
}

=head1 NAME

Tools::TBSSH

=over 4

=item C<< $ssh->cmd($cmd) >>

B<LOWLEVEL SUB> execute $cmd on $host as $user by wrapping cmdline ssh

=item C<< $ssh->scp_worker(@files) >>

B<LOWLEVEL SUB> execute $scp with $files as arguments

=item C<< $ssh->saydebug() >>

B<LOWLEVEL SUB> prints out ssh command line 

=back

=cut

1;
