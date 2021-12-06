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
package Tools::PerlSSH;
use SemiModern::Perl;
use Net::SSH::Perl;
use Net::SFTP;
use Data::UUID;
use Data::Dumper;

sub uuid {
  my $ug = new Data::UUID;
  my $uuid = $ug->create_hex();
 $uuid =~ s/^0x//;
 $uuid;
}

sub path_to_last_part {
  my ($volume,$directories,$file) = File::Spec->splitpath( $_[0] );
  my @dirs = grep {/\S+/} File::Spec->splitdir( $directories );
  if ($file eq '') {
    return $dirs[$#dirs];
  }
  else {
    return $file;
  }
}

sub ssh {
  my ($host, %options) = @_;
  my $user = $options{'user'} ||= $TBConfig::EMULAB_USER;
  my $ssh = Net::SSH::Perl->new($host, protocol => "2", options => [ "ForwardAgent yes" ], use_tty => 1, %options);
  $ssh->login($user);
  return $ssh
}

sub pulldirastar {
  my ($host, $user, $dir) = @_;
  my $dirpart = path_to_last_part($dir);
  my $uuid = uuid();
  my $remotename = "U$uuid";
  my $localname = "${host}_${user}_${dirpart}.tgz";
  my $ssh = ssh($host);
  [$ssh->cmd("tar zcf $remotename $dir")]->[2] && die "tar of $dir failed";

  my $sftp = Net::SFTP->new($host);
  $sftp->get($remotename, $localname);

  [$ssh->cmd("rm $remotename")]->[2] && die "rm of remote tmp file failed";
}

=head1 NAME

Tools::PerlSSH

=over 4

=item C<uuid>

returns a uuid in hex string format

=item C< path_to_last_part($path) >

returns the directory portion of a path

=item C< ssh($host, $user, @options)>

B<LOWLEVEL SUB> return a ssh object to $host as $user

=item C<cmdcheckoutput($host, $cmd, $checker = sub { my ($out, $err, $resultcode) = @_; ... }>

executes $cmd as $TBConfig::EMULAB_USER on $host and calls checker with ($out, $err, $resultcode)

=item C<cmdsuccess($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER

=item C<cmdsuccessdump($host, $cmd)>

returns the ssh result code of executing $cmd as $TBConfig::EMULAB_USER and dumps the ssh stdout, stderr, resultcode

=item C<pulldirastar($host, $user, $dir)>

=back

=cut

1;
