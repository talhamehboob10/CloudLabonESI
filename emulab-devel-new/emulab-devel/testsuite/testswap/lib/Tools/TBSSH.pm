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
package Tools::TBSSH;
use SemiModern::Perl;
use Data::Dumper;
use Moose;

eval{
  #force use of 'Tools::WrappedSSH'
  require BOZO;
};
if ($@) {
  extends 'Tools::WrappedSSH';
}
else {
  die
  extends 'Tools::PerlSSH';
}

sub instance {
  my ($host, %options) = @_;
  $options{'user'} ||= $TBConfig::EMULAB_USER;
  Tools::TBSSH->new('host' => $host, %options);
}

sub wrapped_ssh {
  my ($invocant, $user, $cmd, $checker, $diemessage, $stdin) = @_;
  my $ssh;
  if (ref $invocant) { $ssh = $invocant }
  else {
    $ssh = Tools::TBSSH->new('host' => $invocant, 'user' => $user);
  }
  my @results = $ssh->cmd($cmd, $stdin);
  if ($TBConfig::DEBUG_XML_CLIENT) {
    $ssh->saydebug($cmd);
    sayd @results;
  }

  if (defined $checker) {
    &$checker(@results) || die ($diemessage || "ssh checker of cmd $cmd failed " . Dumper(\@results));
  }
  ($results[2], @results);
}

sub wrapped_scp {
  my ($invocant, $user, $lfile, $rfile) = @_;
  my $ssh;
  if (ref $invocant) { $ssh = $invocant }
  else {
    $ssh = Tools::TBSSH->new('host' => $invocant, 'user' => $user);
  }
  my @results = $ssh->scp_worker($lfile, $rfile);

  ($results[2], @results);
}


sub cmdcheckoutput {
  my ($host, $cmd, $checker) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, $checker);
}

sub cmdsuccess {
  my ($host, $cmd, $diemessage) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { $_[2] == 0; }, $diemessage);
}

sub cmdsuccess_stdin {
  my ($host, $cmd, $stdin, $diemessage) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { $_[2] == 0; }, $diemessage, $stdin);
}

sub cmdoutput {
  my ($host, $cmd, $diemessage) = @_;
  my @results = wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { $_[2] == 0; }, $diemessage );
  return $results[1];
}

sub cmdmatch {
  my ($host, $cmd, $regex, $diemessage) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { $_[0] =~ $regex; }, $diemessage );
}

sub cmdsuccessdump {
  my ($host, $cmd) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { print Dumper(\@_); $_[2] == 0; } );
}

sub cmdfailure {
  my ($host, $cmd, $diemessage) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { $_[2] != 0; }, $diemessage );
}

sub cmdfailuredump {
  my ($host, $cmd) = @_;
  return wrapped_ssh($host, $TBConfig::EMULAB_USER, $cmd, sub { print Dumper(\@_); $_[2] != 0; } );
}

sub scp {
  my ($host, @files) = @_;
  return wrapped_scp($host, $TBConfig::EMULAB_USER, @files);
}

=head1 NAME

Tools::TBSSH

=over 4

=item C< instance($host, %options) >

creates a new $ssh object with $host, $user = $TBConfig::EMULAB_USER, and %options

=item C<< $ssh->wrapped_ssh($user, $cmd, $checker) >>

=item C<< $host->wrapped_ssh($user, $cmd, $checker) >>

=item C<< $ssh->wrapped_scp($user, @files) >>

=item C<< $host->wrapped_scp($user, #files) >>

=item C<< $host->scp($host, #files) >>

=item C<cmdcheckoutput($host, $cmd, $checker = sub { my ($out, $err, $resultcode) = @_; ... }>

executes $cmd as $TBConfig::EMULAB_USER on $host and calls checker with ($out, $err, $resultcode)

=item C<cmdsuccess($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER

=item C<cmdsuccess_stdin($host, $cmd, $stdin, $diemessage)>

returns the ssh result code of executing $cmd with $stdin as $TBConfig::EMULAB_USER

=item C<cmdoutput($host, $cmd, $diemessage)>>

returns the ssh stdout of executing $cmd as $TBConfig::EMULAB_USER

=item C<cmdsuccessdump($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER and dumps the ssh stdout, stderr, resultcode

=item C<cmdfailure($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER

=item C<cmdfailuredump($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER and dumps the ssh stdout, stderr, resultcode

=item C<cmdmatch($host, $cmd, $regex, $diemessage)>

executes $cmd as $TBConfig::EMULAB_USER and dies with diemessage if stdout doesn't match $regex

=back

=cut

1;
